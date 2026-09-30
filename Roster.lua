-- Roster.lua
-- Xal's Roster Roundup
--
-- Data model + CRUD for guild roster tracking. Supports multiple guilds
-- (tabs appear in the UI only when more than one exists) and a per-main
-- list of linked alts.
--
-- Schema (per guild):
-- {
--   name = "Guild Name",
--   members = {
--     [charName] = {
--       charName = "Playername",
--       nickname = "",
--       isMain = true/false,
--       confirmedMain = true/false, -- true only once explicitly locked via
--                                    -- the "Main" button - see ConfirmMain
--       linkedMain = "MainCharName", -- only set when isMain == false
--       profession1 = "", -- two separate fields since every character has
--       profession2 = "", -- up to two primary professions, each with its
--                          -- own independent Tab-autocomplete
--       reasons = { Raid = true, Dungeon = false, Achievements = false, Mounts = false },
--       reviewed = true/false, -- false only for a brand-new auto-synced
--                               -- member nobody has opened the profile of
--                               -- yet - see MarkReviewed
--       isOfficer = true/false, -- a label/color only, GRANTS NO extra
--                                -- addon permissions (confirmed 2026-08-12
--                                -- - only the Guild Master can edit)
--       notes = "", -- private GM-only notes, like WoW's own officer note -
--                    -- not shown to the member themselves or other players
--     },
--   },
-- }
XRR = XRR or {}
XRR.Roster = {}
local R = XRR.Roster

-- Storage scope: account-wide (XRR_DB) vs per-character (XRR_CharDB). The
-- Settings toggle flips XRR_DB.storageScope; both tables always exist so
-- switching the toggle never loses previously-entered data in either store.
XRR_DB = XRR_DB or {}
XRR_CharDB = XRR_CharDB or {}

local function ActiveStore()
    if XRR_DB.storageScope == "character" then
        XRR_CharDB.guilds = XRR_CharDB.guilds or {}
        return XRR_CharDB.guilds
    end
    XRR_DB.guilds = XRR_DB.guilds or {}
    return XRR_DB.guilds
end

-- Lets other files (the new-member/rank-change alert icons) react the
-- instant something they care about changes, instead of only on the next
-- full roster sync - a member getting reviewed or a rank-change list
-- getting dismissed both happen without a real GUILD_ROSTER_UPDATE firing.
local syncCallbacks = {}
function R:OnSync(fn)
    table.insert(syncCallbacks, fn)
end
local function NotifySync(guild)
    for _, fn in ipairs(syncCallbacks) do fn(guild) end
end

function R:GetGuilds()
    return ActiveStore()
end

-- The guild you're ACTUALLY in right now - NOT just the first entry in the
-- store. Account-wide storage can hold more than one guild (different
-- characters on the same account, or just having tested on more than one
-- guild), so `R:GetGuilds()[1]` silently reads whichever guild happened to
-- be added first, not necessarily the one you're currently logged into.
-- This is what was showing a real, large guild's "350 new members" while
-- actually logged into a small test guild - both were sitting in the same
-- account-wide store, and every page was blindly reading index 1.
function R:GetCurrentGuild()
    if not IsInGuild() then return nil end
    local guildName = GetGuildInfo("player")
    if not guildName then return nil end
    for _, g in ipairs(ActiveStore()) do
        if g.name == guildName then
            return g
        end
    end
    return nil
end

function R:AddGuild(guildName)
    local guilds = ActiveStore()
    table.insert(guilds, { name = guildName, members = {} })
    return guilds[#guilds]
end

function R:GetGuild(index)
    return ActiveStore()[index]
end

function R:RemoveGuild(index)
    table.remove(ActiveStore(), index)
end

-- Members --------------------------------------------------------------

function R:AddMember(guild, charName)
    guild.members[charName] = {
        charName = charName,
        nickname = "",
        isMain = true,
        -- Default sync state ONLY - not the same as an officer explicitly
        -- confirming this person as a real main. See ConfirmMain below.
        confirmedMain = false,
        linkedMain = nil,
        profession1 = "",
        profession2 = "",
        reasons = {},
        reviewed = false,
        isOfficer = false,
        notes = "",
        officerNote = "",
        customNotes = "",
        -- The moment this addon first saw them - Blizzard's API has no real
        -- join-date field, so this is an approximation (their actual guild
        -- join date if they were added before this addon ever synced them).
        -- Drives the "Date Joined" stat on their profile card.
        firstSeenTime = time(),
    }
    return guild.members[charName]
end

function R:AddAlt(guild, charName, mainCharName)
    guild.members[charName] = {
        charName = charName,
        nickname = "",
        isMain = false,
        linkedMain = mainCharName,
        profession1 = "",
        profession2 = "",
        reasons = {},
        reviewed = false,
        isOfficer = false,
        notes = "",
        officerNote = "",
        customNotes = "",
        firstSeenTime = time(),
    }
    return guild.members[charName]
end

-- "27 Apr '25" style short date, used by the profile card's Date Joined/
-- Promoted stats. WoW's Lua sandbox exposes the standard `date` global
-- (same family as `time()`, already used elsewhere in this addon).
function R.FormatDate(unixTime)
    if not unixTime then return "-" end
    return date("%d %b '%y", unixTime)
end

-- ── Manual date overrides (Date Joined / Promoted / Birthday) ──────────
-- This addon can only ever auto-track a date from the moment it first
-- witnesses something (firstSeenTime for joining, guild.rankChanges for a
-- promotion) - anyone already in the guild before the addon started
-- tracking, or a rank change that happened while it wasn't running, has no
-- real recorded date at all. GRM solves this with a manual set/clear per
-- field (researched 2026-09-29, GRM_Core.lua's SetJoinDate/SetPromoDate/
-- SetBirthdayFrameLogic, real live install) - same shape here: an override
-- value that wins over the auto-tracked one when present, plus a separate
-- "explicitly marked unknown" flag so a GM can clear a wrong auto-guess
-- without a new one immediately reappearing on the next sync.
R.MONTH_NAMES = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local DAYS_IN_MONTH = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 } -- Feb=29, leap-checked separately

local function IsLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

-- year may be nil (Birthday has no tracked year) - Feb 29 is allowed either
-- way (treated as a leap year when no specific year is given, matching
-- GRM's own Birthday behavior of always allowing Feb 29).
function R.IsValidDate(day, month, year)
    if not day or not month then return false end
    if month < 1 or month > 12 then return false end
    local maxDay = DAYS_IN_MONTH[month]
    if month == 2 and year and not IsLeapYear(year) then
        maxDay = 28
    end
    return day >= 1 and day <= maxDay
end

function R:SetJoinDateOverride(guild, charName, day, month, year)
    local m = guild.members[charName]
    if not m or not R.IsValidDate(day, month, year) then return false end
    m.joinDateOverride = time({ year = year, month = month, day = day, hour = 12 })
    m.joinDateUnknown = false
    return true
end

function R:ClearJoinDateOverride(guild, charName, markUnknown)
    local m = guild.members[charName]
    if not m then return end
    m.joinDateOverride = nil
    m.joinDateUnknown = markUnknown and true or false
end

-- The override wins when set; otherwise falls back to the auto-tracked
-- firstSeenTime UNLESS it's been explicitly marked unknown (a GM clearing a
-- wrong auto-guess shouldn't just have it reappear).
function R:GetJoinDate(guild, charName)
    local m = guild.members[charName]
    if not m then return nil end
    if m.joinDateOverride then return m.joinDateOverride end
    if m.joinDateUnknown then return nil end
    return m.firstSeenTime
end

-- Same auto-vs-override split as Date Joined, but the "auto" side is
-- whatever's most recently recorded in guild.rankChanges for this member
-- (already tracked elsewhere for the activity log) rather than a field on
-- the member itself.
function R:GetAutoPromotedTime(guild, charName)
    local latest
    for _, change in ipairs(guild.rankChanges or {}) do
        if change.charName == charName and change.time then
            latest = change.time
        end
    end
    return latest
end

function R:SetPromotedOverride(guild, charName, day, month, year)
    local m = guild.members[charName]
    if not m or not R.IsValidDate(day, month, year) then return false end
    m.promotedOverride = time({ year = year, month = month, day = day, hour = 12 })
    m.promotedUnknown = false
    return true
end

function R:ClearPromotedOverride(guild, charName, markUnknown)
    local m = guild.members[charName]
    if not m then return end
    m.promotedOverride = nil
    m.promotedUnknown = markUnknown and true or false
end

function R:GetPromotedDate(guild, charName)
    local m = guild.members[charName]
    if not m then return nil end
    if m.promotedOverride then return m.promotedOverride end
    if m.promotedUnknown then return nil end
    return R:GetAutoPromotedTime(guild, charName)
end

-- Birthday has no real source at all (Blizzard tracks nothing like it) -
-- always manual, day/month only, same as GRM.
function R:SetBirthday(guild, charName, day, month)
    local m = guild.members[charName]
    if not m or not R.IsValidDate(day, month, nil) then return false end
    m.birthday = { day = day, month = month }
    return true
end

function R:ClearBirthday(guild, charName)
    local m = guild.members[charName]
    if not m then return end
    m.birthday = nil
end

function R:GetBirthday(guild, charName)
    local m = guild.members[charName]
    return m and m.birthday or nil
end

function R.FormatBirthday(day, month)
    if not day or not month then return "-" end
    return day .. " " .. (R.MONTH_NAMES[month] or "?")
end

-- Re-flags an EXISTING member (already synced in as a Main, per
-- SyncFromLiveGuild) as an alt linked to mainCharName - this is how "Add
-- Alt" actually works now, not creating a brand-new typed entry. Since this
-- is a guild roster, anyone eligible to be someone's alt is already a
-- tracked member by definition (confirmed 2026-08-12: "if they aren't in
-- the guild, they wouldn't be in the guild roster"). Their own profile data
-- (nickname/professions/reasons) is preserved, not wiped.
function R:ConvertToAlt(guild, charName, mainCharName)
    local m = guild.members[charName]
    if not m then return end
    m.isMain = false
    m.linkedMain = mainCharName
end

-- Breaks the link, back to the plain default "Main, not yet confirmed"
-- state - same as a member who's never been touched by any of this.
-- Deliberately NOT the same as ConfirmMain: this doesn't lock them in or
-- swap anyone else's link, it just undoes the Add Alt that created this
-- link in the first place, leaving them free to be linked to someone else.
function R:UnlinkAlt(guild, charName)
    local m = guild.members[charName]
    if not m then return end
    m.isMain = true
    m.linkedMain = nil
    m.confirmedMain = false
end

-- What the "Main" button does - whether promoting an existing alt back, or
-- explicitly confirming a plain default-synced member. This EXPLICIT
-- confirmation is what permanently excludes them from ever showing up as
-- an alt candidate for anyone else, distinct from the default sync state
-- (confirmed 2026-08-12): a member who's simply sitting at the default
-- isMain=true from auto-sync is still a valid alt candidate for someone
-- else until an officer deliberately locks them in via this button.
--
-- If charName was someone's alt, this is a real SWAP, not just a promotion
-- - the character they were linked to becomes THEIR alt instead, rather
-- than being left standing alone as a second confirmed main. This is what
-- actually lets someone switch which character is "the main" over a season
-- (confirmed 2026-08-12: "there are certain people that start off a season
-- as a healer main and end up a tank main... they need to be able to
-- switch their mains").
function R:ConfirmMain(guild, charName)
    local m = guild.members[charName]
    if not m then return end
    local previousMain = m.linkedMain

    m.isMain = true
    m.linkedMain = nil
    m.confirmedMain = true

    if previousMain and previousMain ~= charName then
        local oldMain = guild.members[previousMain]
        if oldMain then
            oldMain.isMain = false
            oldMain.linkedMain = charName
            oldMain.confirmedMain = false
        end
    end
end

function R:RemoveMember(guild, charName)
    guild.members[charName] = nil
    -- Any alts pointing at this member as their main are orphaned - clear
    -- their link rather than leaving a dangling reference.
    for _, m in pairs(guild.members) do
        if m.linkedMain == charName then
            m.linkedMain = nil
        end
    end
end

-- Returns only Main entries, for the condensed left-column list. This
-- includes BOTH confirmed and unconfirmed Mains - the left list just shows
-- who's currently a Main, it isn't about alt-eligibility.
function R:GetMains(guild)
    local mains = {}
    for _, m in pairs(guild.members) do
        if m.isMain then
            table.insert(mains, m)
        end
    end
    -- Confirmed Mains sort to the top (2026-09-29 - "any character with a
    -- main should be on top of the list, so I don't have to keep scrolling
    -- down after I set a main"), alphabetical within each group.
    table.sort(mains, function(a, b)
        if a.confirmedMain ~= b.confirmedMain then
            return a.confirmedMain
        end
        return a.charName < b.charName
    end)
    return mains
end

-- Who's actually eligible to become someone's alt: a Main that has NOT
-- been explicitly confirmed via ConfirmMain (see above). A confirmed Main
-- is permanently excluded from every other Main's candidate pool.
function R:GetAltCandidates(guild, excludeCharName)
    local candidates = {}
    for _, m in pairs(guild.members) do
        if m.isMain and not m.confirmedMain and m.charName ~= excludeCharName then
            table.insert(candidates, m)
        end
    end
    table.sort(candidates, function(a, b) return a.charName < b.charName end)
    return candidates
end

-- Finds-or-creates a guild entry matching the character's REAL current
-- guild, and adds any live guild-roster member who isn't already tracked -
-- without touching data already entered for members that exist. This is
-- what actually populates the left-column list from your real guild instead
-- of starting empty and requiring "+Add Member" once per person by hand
-- (caught 2026-08-12: the panel had no auto-population at all, which read
-- as "broken" since a fresh install just shows nothing).
-- Real, live-from-the-API officer status (2026-09-20) - NOT a manual label
-- anymore. Confirmed against Blizzard's own client source
-- (Blizzard_GuildControlUI.xml/.lua): the Rank Permissions panel's "Is
-- Officer" master checkbox is CheckButton id="22", and its OnShow handler
-- reads it straight off `flags[self.OfficerCheckbox:GetID()]` - i.e. flag
-- index 22 in whatever C_GuildInfo.GuildControlGetRankFlags(rankOrder)
-- returns. rankOrder is 1-based (rank 0 from GetGuildRosterInfo = rankOrder
-- 1), hence the +1.
local function IsOfficerRank(rankIndex)
    if not (C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags) then return false end
    local ok, flags = pcall(C_GuildInfo.GuildControlGetRankFlags, rankIndex + 1)
    if not ok or not flags then return false end
    return flags[22] == true
end

-- Every real, editable guild rank in order, for the Roster page's rank
-- dropdown (confirmed 2026-09-21: promote/demote needs to be "pick a rank
-- from a list," not two single-step buttons - matches how GRM's own member
-- panel does it, and how Blizzard's real client-side rank rules actually
-- work: you can only move one step at a time, so jumping straight to a
-- rank several tiers away needs several Promote/Demote calls chained
-- together, which single-step buttons can't do in one click).
-- GuildControlGetRankName/GuildControlGetNumRanks are real, freely-callable
-- globals (not namespaced under C_GuildInfo) - confirmed against Blizzard's
-- own GuildRoster.lua and GuildControlUI.lua, which both call these with no
-- special permission check. rankOrder starts at 2 - order 1 is always the
-- Guild Master's own rank, which isn't a real "promote someone to" target
-- (that's a separate, much bigger "transfer guild leadership" action).
function R.GetGuildRankNames()
    local out = {}
    if not (GuildControlGetNumRanks and GuildControlGetRankName) then return out end
    local numRanks = GuildControlGetNumRanks()
    for order = 2, numRanks do
        table.insert(out, { order = order, name = GuildControlGetRankName(order) })
    end
    return out
end

-- Pure calculation only - NOT an execution function. Three straight wrong
-- attempts to actually perform a rank change from plain Lua all threw a
-- real ADDON_ACTION_FORBIDDEN (2026-09-21/22): chaining Promote/Demote
-- calls with a timer between them, chaining them with no delay at all, and
-- finally a single C_GuildInfo.SetGuildRankOrder call straight from a
-- StaticPopup's own OnAccept. All three are real user-triggered code paths
-- in the everyday sense, but none of them satisfy Blizzard's actual
-- "AllowedWhenUntainted" requirement for these functions - that apparently
-- needs a genuine secure-template click, not just any click handler.
-- GRM itself never calls C_GuildInfo.Promote/Demote/SetGuildRankOrder
-- directly either - GRM_Macro_Tool.lua builds real macros using the native
-- /gpromote and /gdemote slash commands and has the officer physically
-- click them. GuildPanel.lua does the same now: this function only works
-- out the direction and how many real clicks it'll take, the actual click
-- happens on a real secure macro button there.
function R:GetRankSteps(guild, charName, targetOrder)
    local m = guild.members[charName]
    if not m or not m.rankOrder then return nil end
    local diff = targetOrder - m.rankOrder
    if diff == 0 then return nil end
    return { direction = diff < 0 and "promote" or "demote", steps = math.abs(diff) }
end

function R:SyncFromLiveGuild()
    if not IsInGuild() then return nil end
    local guildName = GetGuildInfo("player")
    if not guildName then return nil end

    local guilds = ActiveStore()
    local guild
    for _, g in ipairs(guilds) do
        if g.name == guildName then
            guild = g
            break
        end
    end
    if not guild then
        guild = R:AddGuild(guildName)
    end

    -- "Sync" means the roster actually matches the live guild - added AND
    -- removed, not just added. Before this fix, a member who left (kicked,
    -- quit, or a stale test character) stayed in guild.members forever,
    -- which is exactly what was inflating "unreviewed" counts with people
    -- no longer even in the guild (confirmed via screenshot - a guild with
    -- a handful of real members was showing 350+ "new" members).
    -- Real WoW rank changes (someone got promoted/demoted by an officer),
    -- NOT this addon's own "isOfficer" flag - that flag is just a label the
    -- Guild Master types in on this addon's own Guild Master page, stored
    -- only in THIS player's own SavedVariables, with no connection to
    -- another officer's own separate copy of the addon or to the game's
    -- real rank system. It genuinely can't detect what another player did.
    -- Live rank names, read straight from GetGuildRosterInfo, are real
    -- shared server state every player's client can see - that's the only
    -- thing an addon can actually compare across logins to catch a change.
    guild.rankChanges = guild.rankChanges or {}
    guild.bans = guild.bans or {}
    guild.bannedRejoins = guild.bannedRejoins or {}

    local seen = {}
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        -- Rank index 0 is ALWAYS the Guild Master - a hard rule of WoW's
        -- rank system, not something a guild can configure away, unlike
        -- "officer" which has no equivalent universal API flag (every guild
        -- names/structures its own ranks).
        -- 5th return is the LOCALIZED class name ("Druid"), not a file
        -- token - confirmed against the real API signature, not guessed
        -- (classFileName is a separate, later return this addon doesn't
        -- need since this string is already display-ready). 17th and last
        -- return is the member's real GUID (confirmed against the real API
        -- signature) - needed for C_GuildInfo.SetGuildRankOrder, the same
        -- function Blizzard's own rank dropdown uses.
        local name, rankName, rankIndex, level, className, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        -- Confirmed real Blizzard client bug (GRM's own code names it
        -- directly, GRM_ScanRoster.lua: "This started happening in 12.0.1
        -- shortly after logging in... subsequent scans seem to show the
        -- proper guild member") - the roster read right after login can
        -- come back with a real-looking entry count but a blank/wrong GUID
        -- on some rows, and that unreliability isn't limited to the GUID
        -- field alone. This was the actual cause of the mass "X joined the
        -- guild" burst on every login (confirmed via screenshot, ~70 false
        -- entries) - real existing members briefly not matching their own
        -- already-tracked record on that first bad pass. Skipping any
        -- entry with no real GUID this pass - not logging anything for it,
        -- not even marking it seen - means it just gets picked up cleanly
        -- on the next throttled pass once the client has real data, same
        -- as GRM's own guard.
        if name and guid and guid ~= "" then
            local shortName = name:match("^([^-]+)") or name
            seen[shortName] = true
            local m = guild.members[shortName]
            if not m then
                -- Before treating this as a genuine new member: the same
                -- real person can already be tracked under a different key
                -- if their name string ever came back formatted
                -- differently between sessions (realm suffix present one
                -- login and not the next, etc.) - their GUID doesn't
                -- change, so a GUID match elsewhere in guild.members means
                -- "re-key this existing record," not "log a new join."
                local existingKey
                for key, existing in pairs(guild.members) do
                    if existing.guid and existing.guid == guid then
                        existingKey = key
                        break
                    end
                end
                if existingKey and existingKey ~= shortName then
                    m = guild.members[existingKey]
                    guild.members[existingKey] = nil
                    guild.members[shortName] = m
                    m.charName = shortName
                    m.rankName = rankName
                else
                    m = R:AddMember(guild, shortName)
                    m.rankName = rankName
                    -- A banned name showing up as a brand-new member is
                    -- exactly what the ban list exists to catch - same
                    -- shape as GRM's own ban feature (confirmed
                    -- 2026-09-20): banning never blocks a rejoin (no
                    -- Blizzard API for that), it just warns you when it
                    -- happens.
                    if guild.bans[shortName] then
                        table.insert(guild.bannedRejoins, { charName = shortName, time = time() })
                        R:AddLogEntry(guild, "banrejoin", shortName .. " just rejoined the guild - they're on your ban list.")
                        print("|cffff3333[Roster Roundup]|r " .. shortName .. " just rejoined the guild - they're on your ban list.")
                    else
                        R:AddLogEntry(guild, "join", shortName .. " joined the guild.")
                    end
                end
            elseif m.rankName and m.rankName ~= rankName then
                table.insert(guild.rankChanges,
                    { charName = shortName, from = m.rankName, to = rankName, time = time() })
                -- Lower rankOrder = higher rank (the Guild Master is always
                -- 1) - m.rankOrder is still last sync's value here, it only
                -- gets updated below. No "by so-and-so" attribution: Blizzard
                -- gives no way to know who actually did it unless it went
                -- through this addon's own rank dropdown, and this same
                -- generic line covers both cases without guessing.
                local wasPromoted = (rankIndex + 1) < m.rankOrder
                R:AddLogEntry(guild, wasPromoted and "promote" or "demote",
                    string.format("%s was %s from %s to %s.", shortName,
                        wasPromoted and "promoted" or "demoted", m.rankName, rankName))
                m.rankName = rankName
            elseif not m.rankName then
                -- First sync since this field existed - record the current
                -- rank without treating it as a "change" from nothing.
                m.rankName = rankName
            end
            -- Level/class refreshed on every sync (unlike firstSeenTime,
            -- these actually change over time) - drives the profile card's
            -- "Level 80 Troll Druid" line.
            if m.level and level and level > m.level then
                R:AddLogEntry(guild, "levelup", shortName .. " leveled up to " .. level .. ".")
            end
            m.level = level
            m.className = className
            m.guid = guid
            -- Officer status refreshed live from the real rank permission
            -- every sync, replacing the old manual Add/Remove Officer UI
            -- entirely (confirmed 2026-09-20: "it's in the guild ranks, is
            -- officer" - Blizzard already exposes this, no reason to make
            -- someone maintain a separate list by hand).
            m.isOfficer = IsOfficerRank(rankIndex)
            -- 1-based, matching GuildControlGetRankName/GetRankFlags'
            -- convention - drives the Roster page's rank dropdown and the
            -- step-by-step promote/demote walk above.
            m.rankOrder = rankIndex + 1
            if rankIndex == 0 then
                guild.masterName = shortName
            end
        end
    end

    -- Real, confirmed bug (2026-09-21), and it took three more attempts to
    -- actually kill it. First two were home-grown heuristics that both
    -- still let a bad login-window read through. Third was GRM's own real
    -- mechanism for this (Scan.RosterDiscrepancyPassed in
    -- GRM_ScanRoster.lua, read-only reference, no code copied) - a read
    -- only earns the right to prune anyone if it isn't empty AND isn't
    -- more than a 50% drop from what this addon already has tracked - but
    -- copied WITH GRM's own "give up after 3 tries and trust it anyway"
    -- escape hatch, which turned out to be exactly what kept wiping
    -- everyone: if the real roster genuinely takes longer than the ~15
    -- seconds those 3 tries cover (or the server just throttles the
    -- re-requests), it reliably gave up and trusted a bad read every
    -- single time. Fixed by dropping the escape hatch entirely - a
    -- suspicious read just skips pruning this round, full stop, no matter
    -- how many times in a row that happens. Real departures still get
    -- caught the moment a genuinely good read comes in; nothing forces
    -- this to resolve on any particular timer.
    local trackedCount = 0
    for _ in pairs(guild.members) do
        trackedCount = trackedCount + 1
    end
    local discrepancyPassed = numMembers > 0
        and (trackedCount == 0 or (numMembers / trackedCount) >= 0.5)

    if not discrepancyPassed then
        C_Timer.After(5, function()
            if IsInGuild() then
                C_GuildInfo.GuildRoster()
            end
        end)
        return guild
    end

    for charName in pairs(guild.members) do
        if not seen[charName] then
            -- No way to tell kicked apart from quit-on-their-own from
            -- roster data alone - Blizzard doesn't expose that.
            R:AddLogEntry(guild, "left", charName .. " left the guild.")
            guild.members[charName] = nil
        end
    end

    return guild
end

-- Returns every alt linked to the given main's charName.
function R:GetAlts(guild, mainCharName)
    local alts = {}
    for _, m in pairs(guild.members) do
        if not m.isMain and m.linkedMain == mainCharName then
            table.insert(alts, m)
        end
    end
    table.sort(alts, function(a, b) return a.charName < b.charName end)
    return alts
end

-- Permission ---------------------------------------------------------------
-- Confirmed 2026-08-12: "to remain safe, the only one that can actually do
-- editing... should be the Guild Master." Officer is a color/label only
-- (see isOfficer in the schema above), grants no extra addon permissions.

function R:IsGuildMaster()
    if not IsInGuild() then return false end
    local _, _, rankIndex = GetGuildInfo("player")
    return rankIndex == 0
end

function R:IsOwnCharacter(charName)
    if not charName then return false end
    local myName = UnitName("player")
    return myName ~= nil and charName:lower() == myName:lower()
end

-- The Main/Alt group a member belongs to: themselves if they ARE the Main,
-- otherwise whoever they're linked to.
local function GroupAnchor(guild, charName)
    local m = guild.members[charName]
    if not m then return charName end
    if m.isMain then return charName end
    return m.linkedMain or charName
end

-- Account-wide GM data access: true for the real Guild Master (rank 0, via
-- R:IsGuildMaster), AND for any other character the GM has linked into the
-- same Main/Alt group in THIS guild - confirmed 2026-08-12: this reuses the
-- Main/Alt linking the GM already sets up (no separate account-detection
-- needed). A character in a different guild never appears in this guild's
-- roster at all, so it can never match here - that exclusion is automatic.
--
-- Only covers addon-only data (notes, nicknames, the Officer list). Real
-- guild actions (Promote/Demote/Kick) go through Blizzard's own API, which
-- the server itself gates on actual in-game GM rank - no addon can grant
-- those to an alt that doesn't hold the rank. Those stay behind
-- R:IsGuildMaster() alone, never this function.
function R:HasGMEditAccess(guild)
    if R:IsGuildMaster() then return true end
    if not guild or not guild.masterName then return false end
    local myName = UnitName("player")
    if not myName or not guild.members[myName] then return false end
    return GroupAnchor(guild, myName) == GroupAnchor(guild, guild.masterName)
end

-- Gate for the Officer page (2026-09-22) - anyone with real GM edit access,
-- OR any real officer (Blizzard's own "Is Officer" rank permission, same
-- flag R:IsOfficerRank checks during sync - not this addon's own label,
-- which is just descriptive and grants nothing). Uses the synced copy of
-- the viewer's own member record rather than re-deriving it, since sync
-- already refreshes isOfficer for every member, including yourself, every
-- time.
function R:HasOfficerAccess(guild)
    if R:HasGMEditAccess(guild) then return true end
    if not guild then return false end
    local myName = UnitName("player")
    local m = myName and guild.members[myName]
    return (m and m.isOfficer) or false
end

-- Is this member one of the Guild Master's own characters (the GM's Main,
-- or any alt linked into the GM's own Main/Alt group)? Drives the roster
-- list's red name color (confirmed 2026-09-20: "RED is guildmaster all MY
-- chars will appear red") - same group-membership check HasGMEditAccess
-- already uses for the logged-in player, just applied to an arbitrary
-- member instead of always "me".
function R:IsGuildMasterFamily(guild, charName)
    if not guild or not guild.masterName or not charName then return false end
    if not guild.members[charName] then return false end
    return GroupAnchor(guild, charName) == GroupAnchor(guild, guild.masterName)
end

-- New members ----------------------------------------------------------
-- A member counts as "reviewed" the moment their profile panel is opened -
-- no field-editing required (confirmed 2026-08-12: "reviewed as any, maybe
-- even just opening their panel").

function R:MarkReviewed(guild, charName)
    local m = guild.members[charName]
    if not m then return end
    m.reviewed = true
    NotifySync(guild)
end

-- Count/list of members nobody has looked at yet - this IS "how many new
-- members since last time you visited" (no separate timestamp needed,
-- since opening a profile is exactly what marks something reviewed).
function R:GetUnreviewedMembers(guild)
    local out = {}
    for _, m in pairs(guild.members) do
        if not m.reviewed then
            table.insert(out, m)
        end
    end
    table.sort(out, function(a, b) return a.charName < b.charName end)
    return out
end

-- Rank changes -------------------------------------------------------------
-- Real live WoW rank promotions/demotions caught since the last time this
-- was checked - see the comment in SyncFromLiveGuild for why this reads
-- actual game rank data instead of the addon's own "isOfficer" label.
function R:GetPendingRankChanges(guild)
    return guild.rankChanges or {}
end

function R:ClearRankChanges(guild)
    guild.rankChanges = {}
    NotifySync(guild)
end

-- Guild's own Discord invite link (2026-09-22) - GM-set, per-guild, stored
-- here rather than a hardcoded addon-wide constant. This addon is meant for
-- other guilds to use too, not just this one - baking one specific
-- Discord's URL into the addon itself would send every person who ever
-- installs it to the WRONG server. Empty/nil until the Guild Master
-- actually sets it - the sidebar logo link stays hidden until then.
function R:SetGuildDiscordUrl(guild, url)
    guild.discordUrl = url
    NotifySync(guild)
end

-- Ban list -----------------------------------------------------------------
-- Same shape as GRM's own ban feature (researched 2026-09-20, confirmed as
-- the model to build against): a blacklist flag + reason + a warning if the
-- name ever shows back up, NOT a real enforced ban - Blizzard has no API
-- for that at all, so this can never actually block a rejoin. Keyed by
-- charName rather than tied to a guild.members entry, since a banned
-- person may not currently be in the guild at all (that's the whole
-- point - most bans happen right after a kick, or for someone who's
-- already gone).
function R:AddBan(guild, charName, reason)
    if not charName or charName == "" then return end
    guild.bans = guild.bans or {}
    guild.bans[charName] = {
        reason = reason or "",
        bannedBy = UnitName("player") or "",
        bannedAt = time(),
    }
    NotifySync(guild)
end

function R:RemoveBan(guild, charName)
    if not guild.bans then return end
    guild.bans[charName] = nil
    NotifySync(guild)
end

function R:IsBanned(guild, charName)
    return guild.bans and guild.bans[charName] ~= nil
end

function R:GetBans(guild)
    local out = {}
    for charName, info in pairs(guild.bans or {}) do
        table.insert(out, { charName = charName, reason = info.reason, bannedBy = info.bannedBy, bannedAt = info.bannedAt })
    end
    table.sort(out, function(a, b) return a.charName < b.charName end)
    return out
end

-- Rejoin alerts - a banned name that actually showed back up in the guild,
-- caught during SyncFromLiveGuild.
function R:GetBannedRejoins(guild)
    return guild.bannedRejoins or {}
end

function R:ClearBannedRejoins(guild)
    guild.bannedRejoins = {}
    NotifySync(guild)
end

-- Activity log - same shape as GRM's own Log tab (researched 2026-09-21,
-- read-only reference, no code copied): one entry per real guild event,
-- newest first, with a category so the Log page can filter on it.
-- Capped so a long-lived guild's SavedVariables file can't grow forever.
local MAX_LOG_ENTRIES = 500

function R:AddLogEntry(guild, category, text)
    guild.log = guild.log or {}
    table.insert(guild.log, { category = category, text = text, time = time() })
    while #guild.log > MAX_LOG_ENTRIES do
        table.remove(guild.log, 1)
    end
    NotifySync(guild)
end

-- Newest first - callers don't have to know the storage order.
function R:GetLog(guild)
    local out = {}
    for i = #(guild.log or {}), 1, -1 do
        table.insert(out, guild.log[i])
    end
    return out
end

function R:ClearLog(guild)
    guild.log = {}
    NotifySync(guild)
end

function R:GetOfficers(guild)
    local out = {}
    for _, m in pairs(guild.members) do
        if m.isOfficer then
            table.insert(out, m)
        end
    end
    table.sort(out, function(a, b) return a.charName < b.charName end)
    return out
end

-- Keeps the roster synced even if the Guild Roster panel is never opened -
-- previously SyncFromLiveGuild only ever ran from inside GuildPanel.lua's
-- own event handling, so the new-members and rank-change alert icons would
-- have stayed permanently empty for anyone who never opened that panel.
--
-- Real, confirmed bug found 2026-09-22 after the discrepancy-check fix
-- above STILL let a mass wipe-and-recreate through: GUILD_ROSTER_UPDATE can
-- fire many times in rapid succession right after login, and this used to
-- run a full SyncFromLiveGuild pass - discrepancy check and all - on every
-- single one of them, no throttle at all. GRM never does that - it has its
-- own explicit flow control (Scan.NoLivecheck/CurrentlyScanning/
-- DefaultMinScanTime in GRM_ScanRoster.lua, read-only reference) capping a
-- real scan pass to once every 5 seconds, specifically because - in their
-- own words - "a mass stream of joins and quits... can trigger an
-- inconsistent result in the scanning." That's exactly this bug. Added the
-- same real throttle here: rapid bursts of the event collapse into a
-- single sync pass at most once every 5 seconds, always using whatever the
-- latest data is by the time that pass actually runs.
local MIN_SYNC_INTERVAL = 5
local lastSyncPass = 0
local syncPending = false

local function RunSync()
    syncPending = false
    lastSyncPass = time()
    local guild = R:SyncFromLiveGuild()
    if not guild then return end
    NotifySync(guild)
end

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
syncFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
syncFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" and IsInGuild() then
        -- Actively ask the server for a fresh roster the moment we log in,
        -- the same way Blizzard's own Guild & Communities window does,
        -- instead of just waiting on whatever GUILD_ROSTER_UPDATE happens
        -- to fire on its own - gets the real full data in sooner.
        C_GuildInfo.GuildRoster()
    end

    local elapsed = time() - lastSyncPass
    if elapsed >= MIN_SYNC_INTERVAL then
        RunSync()
    elseif not syncPending then
        syncPending = true
        C_Timer.After(MIN_SYNC_INTERVAL - elapsed, RunSync)
    end
end)
