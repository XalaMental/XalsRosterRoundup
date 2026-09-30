-- Recruitment.lua
-- Xal's Roster Roundup
--
-- Guild recruitment: scan /who for unguilded players, whisper them from a
-- template, invite them straight to the guild, and post recruitment ads to
-- Trade/General - plus a blacklist and basic stats. Same shape as GRIP
-- (researched 2026-09-21, read-only reference, no code copied): scan ->
-- whisper -> invite -> post, with a blacklist gate and a daily whisper cap
-- so this doesn't turn into spam.
--
-- Every API call here was verified against Blizzard's own real client
-- source (Gethe/wow-ui-source) before being used, not guessed:
-- C_FriendList.SendWho/GetNumWhoResults/GetWhoInfo (the real /who search
-- API), C_GuildInfo.Invite (the real guild-invite call - the old bare
-- "GuildInvite" global is just an alias for this exact function), and
-- SendChatMessage for both whispers and channel posts.
XRR = XRR or {}
XRR.Recruitment = {}
local Rec = XRR.Recruitment

local RECRUITMENT_DEFAULTS = {
    scanMin = 1,
    scanMax = 90,
    -- Scans the configured range in bands this many levels wide, low end
    -- first (confirmed 2026-09-22 - low-level characters are the ones most
    -- likely to still be unguilded, and a single query across the whole
    -- range either hits Blizzard's ~50-result cap and silently truncates,
    -- or otherwise buries them). Same real mechanism GRIP uses
    -- (Recruit/Who.lua's BuildWhoQueue/scanStep), just defaulting to 10
    -- instead of GRIP's own default of 5 - both are user-configurable there
    -- and here for the same reason.
    scanStep = 10,
    includeCurrentZone = false,
    whisperTemplates = { "Hey {player}! We're recruiting for {guild}. Interested? Whisper me back!" },
    whisperIndex = 1,
    dailyWhisperCap = 200,
    adGeneralTemplate = "{guild} is recruiting! Friendly and active - whisper me for info.",
    adTradeTemplate = "{guild} recruiting! PvE/PvP/social - whisper for details.",
    adSchedulerEnabled = false,
    adIntervalMinutes = 20,
    blacklist = {}, -- [charName] = { reason = "", at = epoch }
    stats = {}, -- [dateStr] = { whispers=0, invites=0, posts=0, scans=0 }
}

-- Every read/write in this file and in Options.lua goes through this
-- instead of touching XRR_DB.recruitment directly, so the settings table
-- is guaranteed to exist no matter what order things end up loading in.
function Rec:GetDB()
    if not XRR_DB.recruitment then
        XRR_DB.recruitment = {}
        for k, v in pairs(RECRUITMENT_DEFAULTS) do
            XRR_DB.recruitment[k] = v
        end
    end
    return XRR_DB.recruitment
end
Rec:GetDB()

-- Transient, session-only - never saved, rebuilt fresh every scan.
Rec.candidates = {}

local updateCallbacks = {}
function Rec:OnUpdate(fn)
    table.insert(updateCallbacks, fn)
end
local function NotifyUpdate()
    for _, fn in ipairs(updateCallbacks) do fn() end
end

-- Stats ----------------------------------------------------------------
local function TodayKey()
    return date("%Y-%m-%d")
end

local function TodayStats()
    local key = TodayKey()
    local db = Rec:GetDB()
    db.stats[key] = db.stats[key] or { whispers = 0, invites = 0, posts = 0, scans = 0 }
    return db.stats[key]
end

local function RecordStat(field)
    local s = TodayStats()
    s[field] = (s[field] or 0) + 1
end

-- Sums every day's counters within the last N days (inclusive of today) -
-- used for the "Last 7 Days"/"Last 30 Days" stat cards.
function Rec:GetStatsTotals(days)
    local totals = { whispers = 0, invites = 0, posts = 0, scans = 0 }
    local db = Rec:GetDB()
    for i = 0, days - 1 do
        local key = date("%Y-%m-%d", time() - i * 86400)
        local day = db.stats[key]
        if day then
            for field in pairs(totals) do
                totals[field] = totals[field] + (day[field] or 0)
            end
        end
    end
    return totals
end

function Rec:GetTodayStats()
    return TodayStats()
end

-- Blacklist --------------------------------------------------------------
function Rec:AddToBlacklist(charName, reason)
    if not charName or charName == "" then return end
    Rec:GetDB().blacklist[charName] = { reason = reason or "", at = time() }
    NotifyUpdate()
end

function Rec:RemoveFromBlacklist(charName)
    Rec:GetDB().blacklist[charName] = nil
    NotifyUpdate()
end

function Rec:IsBlacklisted(charName)
    return charName and Rec:GetDB().blacklist[charName] ~= nil
end

function Rec:GetBlacklist()
    local out = {}
    for charName, info in pairs(Rec:GetDB().blacklist) do
        table.insert(out, { charName = charName, reason = info.reason, at = info.at })
    end
    table.sort(out, function(a, b) return a.charName < b.charName end)
    return out
end

-- Scan (/who) ------------------------------------------------------------
-- Same real mechanism as GRIP's Recruit/Who.lua (confirmed 2026-09-22,
-- read-only reference, no code copied): the configured level range is
-- split into scanStep-wide bands, low end first, and each click of Scan
-- sends the NEXT band in the queue rather than one single query across the
-- whole range or an automatic full sweep - GRIP only auto-chains bands in
-- its opt-in "Ghost Mode" automation, plain Scan is one real click per
-- band there too. 15 seconds between queries is Blizzard's own real /who
-- throttle (confirmed via GRIP's MIN_WHO_INTERVAL, not guessed).
local MIN_SCAN_INTERVAL = 15
local lastScanTime = 0
Rec.whoQueue = {}

local function BuildWhoQueue(db)
    local queue = {}
    local step = math.max(1, db.scanStep or 10)
    local lo = db.scanMin
    while lo <= db.scanMax do
        local hi = math.min(lo + step - 1, db.scanMax)
        table.insert(queue, { lo, hi })
        lo = hi + 1
    end
    return queue
end

-- How many seconds until Scan can actually send the next band - lets the
-- UI show a real countdown instead of a click that silently does nothing.
function Rec:GetScanCooldown()
    return math.max(0, MIN_SCAN_INTERVAL - (time() - lastScanTime))
end

-- Bands left to query THIS sweep, including the one about to be sent -
-- lets the UI show real sweep progress ("Band 3 of 9").
function Rec:GetScanQueueLength()
    return #Rec.whoQueue
end

function Rec:Scan()
    if Rec:GetScanCooldown() > 0 then return end

    local db = Rec:GetDB()
    if #Rec.whoQueue == 0 then
        -- Starting a fresh sweep - low end of the range first.
        Rec.whoQueue = BuildWhoQueue(db)
    end
    local band = table.remove(Rec.whoQueue, 1)
    if not band then return end

    lastScanTime = time()
    local query = band[1] .. "-" .. band[2]
    if db.includeCurrentZone then
        query = query .. " " .. GetRealZoneText()
    end
    C_FriendList.SendWho(query, Enum.SocialWhoOrigin.Chat)
    RecordStat("scans")
    NotifyUpdate()
end

local whoFrame = CreateFrame("Frame")
whoFrame:RegisterEvent("WHO_LIST_UPDATE")
whoFrame:SetScript("OnEvent", function()
    -- Merges this band's results into the running list instead of wiping
    -- it - each /who query's response replaces the client's OWN cache, so
    -- without this, every band after the first would erase the ones before
    -- it (same real problem GRIP's AddPotential merge-by-name solves).
    local numWhos = C_FriendList.GetNumWhoResults()
    for i = 1, numWhos do
        local info = C_FriendList.GetWhoInfo(i)
        -- Unguilded only - fullGuildName is an empty string for someone
        -- with no guild (confirmed against the real WhoInfo structure).
        if info and (not info.fullGuildName or info.fullGuildName == "") then
            local shortName = info.fullName:match("^([^-]+)") or info.fullName
            if not Rec:IsBlacklisted(shortName) then
                local alreadyHave = false
                for _, c in ipairs(Rec.candidates) do
                    if c.charName == shortName then
                        alreadyHave = true
                        break
                    end
                end
                if not alreadyHave then
                    -- The real target for whispering/inviting - kept
                    -- separate from charName (used for blacklist
                    -- matching/display). info.fullName already includes
                    -- "-Realm" for a cross-realm result (confirmed against
                    -- the real WhoInfo structure) - stripping that down to
                    -- shortName for the whisper/invite target was the
                    -- actual cause of "That player is not currently
                    -- playing" even though the scan had just found them: a
                    -- bare cross-realm short name doesn't resolve.
                    -- Also appends the player's own realm when fullName has
                    -- NO "-Realm" at all (a same-realm result) - matches
                    -- GRIP's own real behavior exactly (confirmed against
                    -- its installed Recruit code, GRIP:BuildNameKeyVariants,
                    -- Core/Utils.lua) rather than assuming Blizzard's raw
                    -- fullName is always whisper-ready as-is.
                    local fullName = info.fullName
                    if not fullName:find("-") then
                        local _, realm = UnitFullName("player")
                        if realm and realm ~= "" then
                            fullName = fullName .. "-" .. realm
                        end
                    end
                    table.insert(Rec.candidates, {
                        charName = shortName,
                        fullName = fullName,
                        level = info.level,
                        classStr = info.classStr,
                        area = info.area,
                    })
                end
            end
        end
    end
    -- Lowest level first, matching the low-to-high sweep order - the
    -- people most likely to still be unguilded stay at the top of the list
    -- regardless of which band they were actually found in.
    table.sort(Rec.candidates, function(a, b) return (a.level or 0) < (b.level or 0) end)
    NotifyUpdate()
end)

function Rec:GetCandidates()
    return Rec.candidates
end

function Rec:ClearCandidates()
    wipe(Rec.candidates)
    wipe(Rec.whoQueue)
    NotifyUpdate()
end

-- Whisper ------------------------------------------------------------------
-- {guildlink} is the guild's own Discord invite link (set by the Guild
-- Master on the Guild Master page, see Roster.lua's guild.discordUrl) -
-- lets a recruitment message include a real, clickable invite instead of
-- the recruiter having to paste it in by hand every time. Empty string if
-- the Guild Master hasn't set one yet, same "hides itself until set"
-- behavior as the sidebar's own Discord logo link.
local function FillTemplate(template, charName)
    local guildName = GetGuildInfo("player") or ""
    local guild = XRR.Roster and XRR.Roster:GetCurrentGuild()
    local guildLink = (guild and guild.discordUrl) or ""
    return (template:gsub("{player}", charName):gsub("{guild}", guildName):gsub("{guildlink}", guildLink))
end

function Rec:BuildWhisperMessage(charName)
    local db = Rec:GetDB()
    local template = db.whisperTemplates[db.whisperIndex] or db.whisperTemplates[1] or ""
    return FillTemplate(template, charName)
end

function Rec:GetDailyWhisperCount()
    return TodayStats().whispers
end

-- Returns true on success, false plus a reason string if it refused to
-- send (daily cap, blacklisted). fullName is the real whisper target
-- ("Name-Realm" for a cross-realm candidate) - falls back to charName when
-- not given (same-realm candidates, or any older/direct call site), but
-- Rec.candidates entries always carry a real fullName now (see the
-- WHO_LIST_UPDATE handler above).
function Rec:WhisperCandidate(charName, fullName)
    local db = Rec:GetDB()
    if Rec:IsBlacklisted(charName) then return false, "blacklisted" end
    if Rec:GetDailyWhisperCount() >= db.dailyWhisperCap then return false, "daily cap reached" end
    SendChatMessage(Rec:BuildWhisperMessage(charName), "WHISPER", nil, fullName or charName)
    RecordStat("whispers")
    NotifyUpdate()
    return true
end

-- Whispers the next candidate in the list and removes them from it - the
-- Home page's "Recruit Next" button. Whisper only, not an automatic
-- invite - inviting is its own deliberate action per candidate (see
-- InviteCandidate), same as GRIP's own who -> whisper -> invite pipeline
-- keeps each step separate.
function Rec:RecruitNext()
    local candidate = table.remove(Rec.candidates, 1)
    if not candidate then return false, "no candidates" end
    local ok, reason = Rec:WhisperCandidate(candidate.charName, candidate.fullName)
    NotifyUpdate()
    return ok, reason
end

-- Invite -------------------------------------------------------------------
function Rec:CanInvite()
    return CanGuildInvite ~= nil and CanGuildInvite()
end

-- Same fullName-vs-charName split as WhisperCandidate above - a bare
-- cross-realm short name is exactly as unreliable for C_GuildInfo.Invite as
-- it is for SendChatMessage.
function Rec:InviteCandidate(charName, fullName)
    if not Rec:CanInvite() then return false, "no permission" end
    if Rec:IsBlacklisted(charName) then return false, "blacklisted" end
    C_GuildInfo.Invite(fullName or charName)
    RecordStat("invites")
    NotifyUpdate()
    return true
end

-- Ads (Trade/General posts) -------------------------------------------------
-- Real Blizzard restriction (confirmed via GRIP's own research): a channel
-- post needs a genuine user-initiated click behind it - Blizzard blocks
-- programmatic sends to CHANNEL-type chat that aren't triggered by a real
-- hardware event. Whispers don't have this restriction, channel posts do.
-- So "Send Next Post" only ever fires from a real button click (see
-- Options.lua) - there's no way to make this genuinely automatic, and
-- trying to would just silently fail.
local function FindChannelIndex(nameToken)
    local channels = { GetChannelList() }
    for i = 1, #channels, 3 do
        local id, chanName = channels[i], channels[i + 1]
        if chanName and chanName:lower():find(nameToken, 1, true) then
            return id
        end
    end
    return nil
end

-- channelType: "general" or "trade".
function Rec:PostAd(channelType)
    local db = Rec:GetDB()
    local template = (channelType == "trade") and db.adTradeTemplate or db.adGeneralTemplate
    local channelIndex = FindChannelIndex(channelType)
    if not channelIndex then return false, "channel not found" end
    SendChatMessage(FillTemplate(template, ""), "CHANNEL", nil, channelIndex)
    RecordStat("posts")
    Rec:GetDB().lastPostTime = time()
    NotifyUpdate()
    return true
end

-- The scheduler only tracks WHEN a post is due - it can't send the post
-- itself (see the real restriction above), so it just flags "due" for the
-- Ads page to show, and Options.lua's own button click does the actual
-- send.
function Rec:IsPostDue()
    local db = Rec:GetDB()
    if not db.adSchedulerEnabled then return false end
    return (time() - (db.lastPostTime or 0)) >= (db.adIntervalMinutes * 60)
end
