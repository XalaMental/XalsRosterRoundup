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

function R:GetGuilds()
    return ActiveStore()
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
    }
    return guild.members[charName]
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
    table.sort(mains, function(a, b) return a.charName < b.charName end)
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

    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        -- Rank index 0 is ALWAYS the Guild Master - a hard rule of WoW's
        -- rank system, not something a guild can configure away, unlike
        -- "officer" which has no equivalent universal API flag (every guild
        -- names/structures its own ranks).
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name then
            local shortName = name:match("^([^-]+)") or name
            if not guild.members[shortName] then
                R:AddMember(guild, shortName)
            end
            if rankIndex == 0 then
                guild.masterName = shortName
            end
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

-- New members ----------------------------------------------------------
-- A member counts as "reviewed" the moment their profile panel is opened -
-- no field-editing required (confirmed 2026-08-12: "reviewed as any, maybe
-- even just opening their panel").

function R:MarkReviewed(guild, charName)
    local m = guild.members[charName]
    if not m then return end
    m.reviewed = true
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

-- Officers ---------------------------------------------------------------
function R:SetOfficer(guild, charName, isOfficer)
    local m = guild.members[charName]
    if not m then return end
    m.isOfficer = isOfficer
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
