-- Recruitment.lua
-- Xal's Roster Roundup
--
-- Guild recruitment: scan /who for unguilded players, whisper and invite
-- them with one click (Recruit Next), watch what happens to each invite,
-- keep a blacklist so nobody gets bothered twice, and post recruitment ads
-- to Trade/General. Works the same way GRIP's recruiting does (researched
-- from its installed files, read-only, nothing copied): scan one level band
-- per click, whisper + invite together, 70 seconds to answer, temporary and
-- permanent blacklist, opt-out detection on replies.
--
-- Every API call here is a real client call, confirmed against Blizzard's
-- own source or against how GRIP uses it on this same client:
-- C_FriendList.SendWho/GetNumWhoResults/GetWhoInfo, C_GuildInfo.Invite,
-- C_ChatInfo.SendChatMessage, and the ERR_GUILD_* / ERR_CHAT_* global
-- strings the game uses for invite and whisper results.
XRR = XRR or {}
XRR.Recruitment = {}
local Rec = XRR.Recruitment

local WHO_SATURATED = 50 -- a /who answer this big is cut off by the game
local WHO_TIMEOUT = 10 -- seconds to wait for a /who answer
local NO_RESPONSE_TIMEOUT = 70 -- seconds an invite gets before it counts as ignored
local NO_RESPONSE_SECONDS = 24 * 60 * 60 -- first ignored invite: 24 hour block
local NO_RESPONSE_ESCALATE_COUNT = 7 -- this many ignored invites: full temporary block
local ACTION_COOLDOWN = 1 -- seconds between Recruit Next clicks
local MAX_CHAT_BYTES = 255 -- the game's limit for one chat message
local MAX_WHISPER_TEMPLATES = 10
Rec.MAX_WHISPER_TEMPLATES = MAX_WHISPER_TEMPLATES
Rec.MAX_CHAT_BYTES = MAX_CHAT_BYTES

local RECRUITMENT_DEFAULTS = {
    scanMin = 1,
    scanMax = 90,
    -- Level bands per scan click, low end first - the game cuts a /who
    -- answer off at about 50 names, so one huge query silently loses people.
    scanStep = 10,
    scanWait = 15, -- seconds between scan clicks (3 to 60)
    classSweep = true, -- a second pass of one class at a time after the first
    includeCurrentZone = false,
    -- Who gets scanned (empty = everyone).
    filterZones = "", -- zone names, separated by commas
    filterRaces = {}, -- [raceName] = true
    filterClasses = {}, -- [className] = true
    rioMinScore = 0, -- Raider.IO M+ score minimum, 0 = off
    -- Whispers.
    whisperTemplates = { "Hey {player}! We're recruiting for {guild}. Interested? Whisper me back!" },
    whisperRotation = "sequential", -- or "random"
    whisperIndex = 0,
    whisperEnabled = true,
    dailyWhisperCap = 200,
    -- Recruit Next.
    inviteEnabled = true,
    inviteFirst = false,
    soundInviteAccepted = true, -- a sound when someone you invited joins
    soundReply = true, -- a sound when someone you recruited whispers back
    unitMenu = true, -- Roster Roundup entries in the game's right-click player menu
    -- Blacklist.
    blacklistDays = 14,
    optOutDetection = true,
    optOutLanguages = { en = true },
    optOutAggressive = false,
    optOutCustom = "", -- the player's own phrases, one per line
    blacklist = {}, -- [charName] = { reason = "", at = epoch, expires = epoch or nil }
    noResponse = {}, -- [charName] = how many invites went unanswered
    sent = {}, -- the Recruit Next card: invited/whispered, not yet resolved
    recruited = {}, -- [charName] = when they accepted an invite from Recruit Next
    -- Ads.
    adGeneralTemplate = "{guild} is recruiting! Friendly and active - whisper me for info.",
    adTradeTemplate = "{guild} recruiting! PvE/PvP/social - whisper for details.",
    adSchedulerEnabled = false,
    adIntervalMinutes = 20,
    adMinPostSeconds = 8, -- shortest wait between posts
    adQueueMax = 20,
    statsShown = { whispers = true, invites = true, accepted = true, posts = true }, -- what the Stats cards list
    stats = {}, -- [dateStr] = { whispers=0, invites=0, posts=0, scans=0, accepted=0, declined=0, optOuts=0 }
}

local DB_SCHEMA = 11

-- Every read/write in this file and in Options.lua goes through this
-- instead of touching XRR_DB.recruitment directly. It also fills in any
-- setting a saved profile from an older version doesn't have yet.
function Rec:GetDB()
    XRR_DB.recruitment = XRR_DB.recruitment or {}
    local db = XRR_DB.recruitment
    if db._schema ~= DB_SCHEMA then
        -- The wait was filled in as 5 for one version before the default
        -- became 15; that 5 was never a choice.
        if db._schema == 6 and db.scanWait == 5 then db.scanWait = 15 end
        for k, v in pairs(RECRUITMENT_DEFAULTS) do
            if db[k] == nil then
                if type(v) == "table" then
                    db[k] = CopyTable(v)
                else
                    db[k] = v
                end
            end
        end
        db._schema = DB_SCHEMA
    end
    return db
end

local function Say(msg)
    print("|cff681417Roster Roundup:|r " .. msg)
end

local function ShortName(name)
    return (tostring(name or ""):match("^([^-]+)")) or ""
end

-- Session-only: rebuilt fresh every scan.
Rec.candidates = {}
Rec.whoQueue = {}
Rec.scanTotal = 0 -- bands in this sweep, including any class splits added mid-sweep
Rec.scanDone = 0

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

local STAT_FIELDS = { "whispers", "invites", "posts", "scans", "accepted", "declined", "optOuts" }

local function TodayStats()
    local key = TodayKey()
    local db = Rec:GetDB()
    db.stats[key] = db.stats[key] or {}
    local s = db.stats[key]
    for _, field in ipairs(STAT_FIELDS) do
        s[field] = s[field] or 0
    end
    return s
end

local function RecordStat(field)
    local s = TodayStats()
    s[field] = (s[field] or 0) + 1
end

-- Sums every day's counters within the last N days (inclusive of today).
function Rec:GetStatsTotals(days)
    local totals = {}
    for _, field in ipairs(STAT_FIELDS) do totals[field] = 0 end
    local db = Rec:GetDB()
    for i = 0, days - 1 do
        local day = db.stats[date("%Y-%m-%d", time() - i * 86400)]
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

-- Wipes every day's counts.
function Rec:ClearStats()
    wipe(Rec:GetDB().stats)
    NotifyUpdate()
end

-- Blacklist --------------------------------------------------------------
-- Two kinds: permanent (no expiry - opt-outs, people who ignore you, and
-- anyone you add by hand) and temporary (an expiry time - ignored or
-- declined invites).
local blIndex -- lowercase name -> real key, rebuilt after any change

local function BLChanged()
    blIndex = nil
end

local function BLKey(name)
    if not blIndex then
        blIndex = {}
        for key in pairs(Rec:GetDB().blacklist) do
            blIndex[key:lower()] = key
        end
    end
    return blIndex[ShortName(name):lower()]
end

-- Drops every temporary entry whose time is up.
function Rec:PurgeBlacklist()
    local bl = Rec:GetDB().blacklist
    local now = time()
    local removed = 0
    for key, info in pairs(bl) do
        if info.expires and info.expires <= now then
            bl[key] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then BLChanged() end
    return removed
end

local function PutBlacklist(name, reason, expires)
    local short = ShortName(name)
    if short == "" then return end
    local bl = Rec:GetDB().blacklist
    local existingKey = BLKey(short)
    local existing = existingKey and bl[existingKey]
    if existing then
        -- Never downgrade a permanent entry, never shorten a temporary one.
        if not existing.expires then return end
        if expires and existing.expires >= expires then return end
        bl[existingKey] = nil
    end
    bl[short] = { reason = reason or "", at = time(), expires = expires }
    BLChanged()
    NotifyUpdate()
end

function Rec:BlacklistPermanent(name, reason)
    PutBlacklist(name, reason, nil)
end

function Rec:BlacklistForSeconds(name, seconds, reason)
    PutBlacklist(name, reason, time() + seconds)
end

function Rec:Blacklist(name, days, reason)
    days = math.max(1, math.min(365, tonumber(days) or Rec:GetDB().blacklistDays))
    PutBlacklist(name, reason, time() + days * 86400)
end

-- The "Add" link on the Blacklist card: always permanent.
function Rec:AddToBlacklist(charName, reason)
    if not charName or charName == "" then return end
    Rec:BlacklistPermanent(charName, reason or "manual")
    Rec:RemoveCandidate(charName)
end

function Rec:RemoveFromBlacklist(charName)
    local key = BLKey(charName)
    if key then
        Rec:GetDB().blacklist[key] = nil
        BLChanged()
        NotifyUpdate()
    end
end

function Rec:IsBlacklisted(charName)
    local key = BLKey(charName)
    if not key then return false end
    local info = Rec:GetDB().blacklist[key]
    if info and info.expires and info.expires <= time() then
        Rec:GetDB().blacklist[key] = nil
        BLChanged()
        return false
    end
    return true
end

function Rec:GetBlacklist()
    Rec:PurgeBlacklist()
    local out = {}
    for charName, info in pairs(Rec:GetDB().blacklist) do
        table.insert(out, {
            charName = charName, reason = info.reason, at = info.at, expires = info.expires,
        })
    end
    table.sort(out, function(a, b) return a.charName:lower() < b.charName:lower() end)
    return out
end

function Rec:GetBlacklistCounts()
    local perm, temp = 0, 0
    for _, info in ipairs(Rec:GetBlacklist()) do
        if info.expires then temp = temp + 1 else perm = perm + 1 end
    end
    return perm, temp
end

-- Import/export is one line of text you can paste to a friend: a prefix
-- plus name,reason,expiry for each entry. Only permanent entries and the
-- time left on temporary ones travel.
local EXPORT_PREFIX = "!XRR:BL:1:"

local function CleanField(s)
    return (tostring(s or ""):gsub("[,;|\n\r]", " "))
end

function Rec:ExportBlacklist()
    local parts = {}
    for _, info in ipairs(Rec:GetBlacklist()) do
        table.insert(parts, string.format("%s,%s,%d", CleanField(info.charName), CleanField(info.reason), info.expires or 0))
    end
    return EXPORT_PREFIX .. table.concat(parts, ";")
end

-- Returns how many entries were added, or nil plus a reason.
function Rec:ImportBlacklist(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, "that doesn't look like a blacklist export"
    end
    local added = 0
    for entry in text:sub(#EXPORT_PREFIX + 1):gmatch("[^;]+") do
        local name, reason, expires = entry:match("^([^,]*),([^,]*),(%d+)$")
        if name and name ~= "" then
            expires = tonumber(expires) or 0
            if expires == 0 then
                PutBlacklist(name, reason, nil)
                added = added + 1
            elseif expires > time() then
                PutBlacklist(name, reason, expires)
                added = added + 1
            end
        end
    end
    NotifyUpdate()
    return added
end

-- Who gets scanned ----------------------------------------------------------
-- Raider.IO is optional - only used when its addon is installed.
function Rec:IsRaiderIOAvailable()
    return _G.RaiderIO ~= nil and type(_G.RaiderIO.GetProfile) == "function"
end

local function GetRaiderIOScore(fullName)
    if not Rec:IsRaiderIOAvailable() then return nil end
    local name, realm = fullName:match("^([^%-]+)%-(.+)$")
    if not name then
        name = fullName
        realm = GetNormalizedRealmName()
    end
    if not name or not realm then return nil end
    local ok, profile = pcall(_G.RaiderIO.GetProfile, name, realm)
    if not ok or not profile then return nil end
    local mkp = profile.mythicKeystoneProfile
    if not mkp or not mkp.hasRenderableData then return nil end
    return mkp.currentScore
end

local function AnyTrue(t)
    for _, v in pairs(t or {}) do
        if v == true then return true end
    end
    return false
end

-- Every class name the game knows, in the player's own language - the same
-- spelling /who results and the c-"Class" search use.
function Rec:GetClassNames()
    local out = {}
    -- IDs 1-13 are the playable classes; the game's table also holds
    -- non-player entries like Adventurer and Traveler after that.
    for id = 1, 13 do
        local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo(id)
        if info and info.className then
            table.insert(out, { name = info.className, file = info.classFile })
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Playable races, localized. The game's race table also holds mount and
-- creature forms, so only the real playable race IDs are read (Pandaren,
-- Dracthyr and Earthen each have more than one ID; the name list drops
-- the repeats).
local PLAYABLE_RACE_IDS = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 35, 36, 37,
    52, 70, 84, 85,
}

function Rec:GetRaceNames()
    local out, seen = {}, {}
    local function Add(info)
        if info and info.raceName and info.raceName ~= "" and not seen[info.raceName] then
            seen[info.raceName] = true
            table.insert(out, info.raceName)
        end
    end
    for _, id in ipairs(PLAYABLE_RACE_IDS) do
        Add(C_CreatureInfo and C_CreatureInfo.GetRaceInfo(id))
    end
    -- Every allied race the game knows (including ones newer than the IDs
    -- above, like Haranir) answers C_AlliedRaces; creature forms don't.
    if C_AlliedRaces and C_AlliedRaces.GetRaceInfoByID then
        for id = 1, 120 do
            local ok, allied = pcall(C_AlliedRaces.GetRaceInfoByID, id)
            if ok and allied then Add(C_CreatureInfo.GetRaceInfo(id)) end
        end
    end
    table.sort(out)
    return out
end

local function PassesFilters(info)
    local db = Rec:GetDB()

    local zoneList = db.filterZones or ""
    if zoneList:match("%S") then
        local area = (info.area or ""):lower()
        local match = false
        for zone in zoneList:gmatch("[^,]+") do
            zone = zone:gsub("^%s+", ""):gsub("%s+$", ""):lower()
            if zone ~= "" and zone == area then
                match = true
                break
            end
        end
        if not match then return false end
    end

    if AnyTrue(db.filterRaces) and not db.filterRaces[info.race or ""] then return false end
    if AnyTrue(db.filterClasses) and not db.filterClasses[info.classStr or ""] then return false end

    if (db.rioMinScore or 0) > 0 and info.rio and info.rio < db.rioMinScore then
        return false
    end
    return true
end

-- Scan (/who) ------------------------------------------------------------
-- Each click sends ONE search from the queue (a search needs a real click),
-- spaced by the "wait between scans" setting. The first pass is level bands.
-- Any search that comes back full (about 50 names, the game's cut-off) is
-- split into smaller ones, and those go to the front of the queue so nobody
-- gets cut off:
--   a level band     -> one search per class
--   a level + class  -> one search per race
--   a level+class+race -> one search per zone seen so far
-- When the first pass is done, a second pass sweeps each class across the
-- whole level range (a full class is split into level bands), which picks
-- up people who logged in after the first pass went by.
local lastScanTime = 0
local pendingWho -- { q =, filter =, sentAt = } while we wait for the answer
local queuedKeys = {} -- searches already queued this sweep, so none repeats
Rec.seenZones = {} -- zone names that have come back in results this session
Rec.nextPass = 1

local SCAN_WAIT_MIN, SCAN_WAIT_MAX = 3, 60

-- Our searches never need the Friends window's Who tab, so if the game
-- opens it anyway it gets closed again (not during combat - the window is
-- protected there).
local function HideFriendsWho()
    if InCombatLockdown() then return end
    if FriendsFrame and FriendsFrame:IsShown() then HideUIPanel(FriendsFrame) end
end

-- A search is { lo =, hi =, class =, race =, zone = }; this is its /who text.
local function QueryString(q)
    local s = ("%d-%d"):format(q.lo, q.hi)
    if q.class then s = s .. (' c-"%s"'):format(q.class) end
    if q.race then s = s .. (' r-"%s"'):format(q.race) end
    if q.zone then s = s .. (' z-"%s"'):format(q.zone) end
    return s
end

local function CurrentZoneOrNil(db)
    if not db.includeCurrentZone then return nil end
    local z = GetRealZoneText()
    if z and z ~= "" then return z end
    return nil
end

-- Pass 1: level bands, low end first.
local function BuildBandQueue(db)
    local queue = {}
    local step = math.max(1, db.scanStep or 10)
    local zone = CurrentZoneOrNil(db)
    local lo = db.scanMin
    while lo <= db.scanMax do
        local hi = math.min(lo + step - 1, db.scanMax)
        table.insert(queue, { lo = lo, hi = hi, zone = zone })
        lo = hi + 1
    end
    return queue
end

-- Pass 2: one search per class across the whole range.
local function BuildClassSweepQueue(db)
    local queue = {}
    local zone = CurrentZoneOrNil(db)
    local picked = AnyTrue(db.filterClasses)
    for _, cls in ipairs(Rec:GetClassNames()) do
        if (not picked) or db.filterClasses[cls.name] then
            table.insert(queue, { lo = db.scanMin, hi = db.scanMax, class = cls.name, zone = zone })
        end
    end
    return queue
end

-- Seconds between searches (3 to 60, default 15).
function Rec:GetScanWait()
    return math.max(SCAN_WAIT_MIN, math.min(SCAN_WAIT_MAX, tonumber(Rec:GetDB().scanWait) or 15))
end

-- How many seconds until Scan can actually send the next search.
function Rec:GetScanCooldown()
    return math.max(0, math.ceil(Rec:GetScanWait() - (GetTime() - lastScanTime)))
end

-- Searches sent so far / searches in the sweep (the "2/9" on the Scan card).
function Rec:GetScanProgress()
    return Rec.scanDone, Rec.scanTotal
end

function Rec:GetScanQueueLength()
    return #Rec.whoQueue
end

local function EnqueueScan(q, atFront, position)
    local key = QueryString(q)
    if queuedKeys[key] then return false end
    queuedKeys[key] = true
    if atFront then
        table.insert(Rec.whoQueue, position or 1, q)
    else
        table.insert(Rec.whoQueue, q)
    end
    return true
end

local function StartSweep(db)
    wipe(queuedKeys)
    local pass = Rec.nextPass or 1
    local queue
    if pass == 2 then
        queue = BuildClassSweepQueue(db)
    else
        pass = 1
        queue = BuildBandQueue(db)
    end
    Rec.whoQueue = {}
    for _, q in ipairs(queue) do EnqueueScan(q) end
    Rec.scanTotal = #Rec.whoQueue
    Rec.scanDone = 0
    -- After pass 1 comes the class sweep (if it's turned on); after that, a
    -- fresh pass 1.
    Rec.nextPass = (pass == 1 and db.classSweep ~= false) and 2 or 1
end

local function SendQuery(q)
    local filter = QueryString(q)
    lastScanTime = GetTime()
    pendingWho = { q = q, filter = filter, sentAt = GetTime() }
    -- Keep the Friends window from popping open for our searches: the
    -- results go to us, not the window, and the search is labelled as
    -- coming from an addon.
    if C_FriendList.SetWhoToUi then C_FriendList.SetWhoToUi(false) end
    HideFriendsWho()
    C_FriendList.SendWho(filter, Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Addon or 1)
    HideFriendsWho()
    RecordStat("scans")

    C_Timer.After(WHO_TIMEOUT, function()
        if pendingWho and pendingWho.filter == filter and (GetTime() - pendingWho.sentAt) >= WHO_TIMEOUT then
            -- No answer just means nothing came back (a search with nobody
            -- to show doesn't always send a result), so it simply counts as
            -- done and the next click moves on.
            pendingWho = nil
            NotifyUpdate()
        end
    end)
end

function Rec:Scan()
    if Rec:GetScanCooldown() > 0 then return end
    if pendingWho and (GetTime() - pendingWho.sentAt) < WHO_TIMEOUT then return end

    local db = Rec:GetDB()
    if #Rec.whoQueue == 0 then StartSweep(db) end
    local q = table.remove(Rec.whoQueue, 1)
    if not q then return end

    Rec.scanDone = Rec.scanDone + 1
    SendQuery(q)
    NotifyUpdate()
end

-- Splits a full search into smaller ones (see the top of this section).
local function SplitFullQuery(q)
    local db = Rec:GetDB()
    local step = math.max(1, db.scanStep or 10)
    local added = 0
    local function Add(sub)
        if EnqueueScan(sub, true, 1 + added) then added = added + 1 end
    end

    if q.hi - q.lo + 1 > step then
        -- Too wide a level range: cut it into level bands.
        local lo = q.lo
        while lo <= q.hi do
            local hi = math.min(lo + step - 1, q.hi)
            Add({ lo = lo, hi = hi, class = q.class, race = q.race, zone = q.zone })
            lo = hi + 1
        end
    elseif not q.class then
        local picked = AnyTrue(db.filterClasses)
        for _, cls in ipairs(Rec:GetClassNames()) do
            if (not picked) or db.filterClasses[cls.name] then
                Add({ lo = q.lo, hi = q.hi, class = cls.name, zone = q.zone })
            end
        end
    elseif not q.race then
        local picked = AnyTrue(db.filterRaces)
        for _, race in ipairs(Rec:GetRaceNames()) do
            if (not picked) or db.filterRaces[race] then
                Add({ lo = q.lo, hi = q.hi, class = q.class, race = race, zone = q.zone })
            end
        end
    elseif not q.zone then
        -- Only zones that have shown up in results are known.
        local zones = {}
        for zone in pairs(Rec.seenZones) do table.insert(zones, zone) end
        table.sort(zones)
        for i = 1, math.min(#zones, 40) do
            Add({ lo = q.lo, hi = q.hi, class = q.class, race = q.race, zone = zones[i] })
        end
    end
    Rec.scanTotal = Rec.scanTotal + added
    -- The splits replace this search, so the one just sent no longer counts
    -- as finished work when it was split.
end

local function MaybeSplit(q, numWhos, total)
    if numWhos < WHO_SATURATED and (total or 0) < WHO_SATURATED then return end
    SplitFullQuery(q)
end

local function InSent(name)
    local short = ShortName(name):lower()
    for _, e in ipairs(Rec:GetDB().sent) do
        if e.charName:lower() == short then return true end
    end
    return false
end

local function HaveCandidate(shortName)
    for _, c in ipairs(Rec.candidates) do
        if c.charName == shortName then return true end
    end
    return false
end

local function ProcessWhoResults()
    local a, b = C_FriendList.GetNumWhoResults()
    local numWhos, total = tonumber(a) or 0, tonumber(b) or 0
    -- Some clients hand these back swapped.
    if total > 0 and numWhos > total then numWhos, total = total, numWhos end

    -- Remember every zone that shows up, for splitting full searches by zone.
    for i = 1, numWhos do
        local zoneInfo = C_FriendList.GetWhoInfo(i)
        if zoneInfo and zoneInfo.area and zoneInfo.area ~= "" then Rec.seenZones[zoneInfo.area] = true end
    end
    if pendingWho and pendingWho.q then MaybeSplit(pendingWho.q, numWhos, total) end

    Rec:PurgeBlacklist()
    for i = 1, numWhos do
        local info = C_FriendList.GetWhoInfo(i)
        -- Unguilded only - fullGuildName is an empty string for someone
        -- with no guild.
        if info and info.fullName and (not info.fullGuildName or info.fullGuildName == "") then
            local shortName = ShortName(info.fullName)
            if not Rec:IsBlacklisted(shortName) and not InSent(shortName) and not HaveCandidate(shortName) then
                -- The real whisper/invite target. info.fullName already
                -- carries "-Realm" for a cross-realm result; a bare
                -- cross-realm short name is what produced "That player is
                -- not currently playing" even though the scan had just
                -- found them. Same-realm results get the player's own realm
                -- appended so the target is always whisper-ready.
                local fullName = info.fullName
                if not fullName:find("-", 1, true) then
                    local _, realm = UnitFullName("player")
                    if realm and realm ~= "" then fullName = fullName .. "-" .. realm end
                end
                local entry = {
                    charName = shortName,
                    fullName = fullName,
                    level = info.level,
                    classStr = info.classStr,
                    classFile = info.filename,
                    race = info.raceStr,
                    area = info.area,
                }
                if PassesFilters({ area = entry.area, race = entry.race, classStr = entry.classStr, rio = GetRaiderIOScore(fullName) }) then
                    entry.rio = GetRaiderIOScore(fullName)
                    table.insert(Rec.candidates, entry)
                end
            end
        end
    end
    -- Lowest level first - the people most likely to still be unguilded.
    table.sort(Rec.candidates, function(x, y) return (x.level or 0) < (y.level or 0) end)
    pendingWho = nil
    HideFriendsWho()
    NotifyUpdate()
end

function Rec:GetCandidates()
    return Rec.candidates
end

function Rec:RemoveCandidate(charName)
    for i, c in ipairs(Rec.candidates) do
        if c.charName == charName then
            table.remove(Rec.candidates, i)
            NotifyUpdate()
            return true
        end
    end
    return false
end

function Rec:ClearCandidates()
    wipe(Rec.candidates)
    wipe(Rec.whoQueue)
    Rec.scanTotal = 0
    Rec.scanDone = 0
    NotifyUpdate()
end

-- Whisper ------------------------------------------------------------------
-- {guildlink} is the guild's real Guild Finder link from Blizzard (the
-- clickable one that opens your guild's listing), the same one GRIP uses.
-- It only exists if the guild is listed in Guild Finder, and the game needs
-- a moment to hand it over, so it's looked up several ways and remembered
-- for ten minutes. {guild} is the guild's name and {player} the person
-- being messaged.
local GUILD_LINK_TTL = 600

local function TryLoadClubFinder()
    if _G.GetClubFinderLink then return true end
    if InCombatLockdown() then return false end
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn then
        if not C_AddOns.IsAddOnLoaded("Blizzard_ClubFinder") then
            pcall(C_AddOns.LoadAddOn, "Blizzard_ClubFinder")
        end
    end
    return _G.GetClubFinderLink ~= nil
end

-- Asks the game for the guild's listing; the answer arrives a moment later.
local function PrimeGuildLink()
    if not IsInGuild() or not (C_Club and C_Club.GetGuildClubId) then return end
    local ok, clubId = pcall(C_Club.GetGuildClubId)
    if ok and clubId and C_ClubFinder and C_ClubFinder.RequestPostingInformationFromClubId then
        pcall(C_ClubFinder.RequestPostingInformationFromClubId, clubId)
    end
end

-- Returns the link, or "" if the game can't give it yet.
function Rec:GetGuildFinderLink()
    if not IsInGuild() then
        Rec:GetDB().guildLinkCache = nil
        return ""
    end
    local db = Rec:GetDB()
    local guildName = GetGuildInfo("player") or ""
    local cache = db.guildLinkCache
    if cache and cache.link and cache.guild == guildName and cache.at and (time() - cache.at) < GUILD_LINK_TTL then
        return cache.link
    end
    if not (C_Club and C_Club.GetGuildClubId) then return "" end
    local ok, clubId = pcall(C_Club.GetGuildClubId)
    if not ok or not clubId then return "" end

    TryLoadClubFinder()
    local getLink = _G.GetClubFinderLink

    local function Found(link, guid, name)
        db.guildLinkCache = { link = link, guid = guid, name = name, guild = guildName, at = time() }
        return link
    end
    local function Build(guid, name)
        if not (getLink and guid and name) then return nil end
        local okLink, link = pcall(getLink, guid, name)
        if okLink and type(link) == "string" and link ~= "" then return link end
        return nil
    end

    -- 1: the Guild Finder data the game already holds.
    if C_ClubFinder and C_ClubFinder.GetRecruitingClubInfoFromClubID then
        local ok1, info = pcall(C_ClubFinder.GetRecruitingClubInfoFromClubID, clubId)
        if ok1 and info and info.clubFinderGUID then
            local name = info.name or guildName
            local link = Build(info.clubFinderGUID, name)
            if link then return Found(link, info.clubFinderGUID, name) end
        end
    end
    -- 2: the listing the Communities window loads.
    local listingFn = _G.ClubFinderGetCurrentClubListingInfo
    if listingFn then
        local ok2, listing = pcall(listingFn, clubId)
        if ok2 and listing and listing.clubFinderGUID and listing.name then
            local link = Build(listing.clubFinderGUID, listing.name)
            if link then return Found(link, listing.clubFinderGUID, listing.name) end
        end
    end
    -- 3: the guild's ID remembered from an earlier lookup.
    if cache and cache.guid and cache.guild == guildName then
        local link = Build(cache.guid, cache.name or guildName)
        if link then return Found(link, cache.guid, cache.name or guildName) end
    end
    -- 4: nothing yet - ask the game, so the next try works.
    PrimeGuildLink()
    return ""
end

local warnedNoGuildLink
local MAX_BYTES_FOR_FILL = MAX_CHAT_BYTES

-- Fills in {guildlink}, {guild} and {player}. When the result is over the
-- chat limit, the text before the link is trimmed so the link stays whole
-- (pass noTruncate to measure the full length instead).
local function FillTemplate(template, charName, noTruncate)
    local guildName = GetGuildInfo("player") or ""
    local link = ""
    if template:find("{guildlink}", 1, true) then
        link = Rec:GetGuildFinderLink()
        if link == "" then
            -- Not available yet (or the guild isn't listed): use the name.
            link = guildName ~= "" and guildName or "your guild"
            if not noTruncate and not warnedNoGuildLink then
                warnedNoGuildLink = true
                Say("{guildlink} couldn't find your Guild Finder link, so your guild's name is used instead. "
                    .. "Open the Communities window (J) once, and make sure your guild is listed in Guild Finder.")
            end
        end
    end
    -- {guildlink} first: {guild} is a piece of it.
    template = template:gsub("{guildlink}", (link:gsub("%%", "%%%%")))
    template = template:gsub("{guild}", (guildName:gsub("%%", "%%%%")))
    template = template:gsub("{player}", (ShortName(charName):gsub("%%", "%%%%")))
    template = template:gsub("[\r\n]+", " ")

    if not noTruncate and #template > MAX_BYTES_FOR_FILL and link ~= "" then
        local lastPos
        local pos = template:find(link, 1, true)
        while pos do
            lastPos = pos
            pos = template:find(link, pos + 1, true)
        end
        if lastPos then
            local tail = template:sub(lastPos)
            if #tail <= MAX_BYTES_FOR_FILL then
                template = template:sub(1, math.max(0, MAX_BYTES_FOR_FILL - #tail)):gsub("%s+$", "") .. tail
            end
        end
    end
    return template
end
Rec.FillTemplate = function(_, template, charName) return FillTemplate(template, charName) end

-- Cuts a message down to the game's byte limit without splitting a letter.
local function TruncateChat(msg)
    if #msg <= MAX_CHAT_BYTES then return msg end
    msg = msg:sub(1, MAX_CHAT_BYTES)
    local last = msg:byte(#msg) or 0
    while #msg > 0 and last >= 0x80 and last < 0xC0 do
        msg = msg:sub(1, #msg - 1)
        last = msg:byte(#msg) or 0
    end
    if last >= 0xC0 then msg = msg:sub(1, #msg - 1) end
    return msg
end

-- How long a template is once its {placeholders} are filled in (using the
-- player's own name as the example, or the name given) - what the message
-- cards show.
function Rec:MeasureTemplate(template, name)
    local filled = FillTemplate(template or "", name or UnitName("player") or "Player", true)
    return #filled, filled
end

-- Next whisper text: round-robin, or random if that's what's picked.
function Rec:PickWhisperTemplate()
    local db = Rec:GetDB()
    local usable = {}
    for _, t in ipairs(db.whisperTemplates) do
        if t and t:match("%S") then table.insert(usable, t) end
    end
    if #usable == 0 then return "" end
    if #usable == 1 then return usable[1] end
    if db.whisperRotation == "random" then
        return usable[math.random(1, #usable)]
    end
    db.whisperIndex = (db.whisperIndex or 0) + 1
    if db.whisperIndex > #usable then db.whisperIndex = 1 end
    return usable[db.whisperIndex]
end

function Rec:GetDailyWhisperCount()
    return TodayStats().whispers
end

local function ChatLocked()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        return C_ChatInfo.InChatMessagingLockdown() and true or false
    end
    return false
end

local function SendWhisper(entry)
    local msg = TruncateChat(FillTemplate(Rec:PickWhisperTemplate(), entry.charName))
    if not msg:match("%S") then return false end
    if ChatLocked() then return false end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, entry.fullName)
    else
        SendChatMessage(msg, "WHISPER", nil, entry.fullName)
    end
    entry.whisperSent = true
    RecordStat("whispers")
    return true
end

-- The Recruit Next card ----------------------------------------------------
function Rec:GetSent()
    return Rec:GetDB().sent
end

local function RemoveSent(entry)
    local sent = Rec:GetDB().sent
    for i, e in ipairs(sent) do
        if e == entry then
            table.remove(sent, i)
            NotifyUpdate()
            return true
        end
    end
    return false
end

-- Matches a name from a game message ("Name" or "Name-Realm") to somebody
-- on the card.
local function FindSent(name)
    local short = ShortName(name):lower()
    if short == "" then return nil end
    for _, e in ipairs(Rec:GetDB().sent) do
        if e.charName:lower() == short then return e end
    end
    return nil
end

local function OnlyPendingInvite()
    local found
    for _, e in ipairs(Rec:GetDB().sent) do
        if e.inviteSent then
            if found then return nil end
            found = e
        end
    end
    return found
end

-- The 70 seconds are up and the invite got no answer: block for 24 hours,
-- or a full temporary block once it has happened seven times.
local function OnNoResponse(entry)
    if not RemoveSent(entry) then return end
    local db = Rec:GetDB()
    if db.inviteEnabled then
        local count = (db.noResponse[entry.charName] or 0) + 1
        db.noResponse[entry.charName] = count
        if count >= NO_RESPONSE_ESCALATE_COUNT then
            Rec:Blacklist(entry.charName, db.blacklistDays, "no response")
        else
            Rec:BlacklistForSeconds(entry.charName, NO_RESPONSE_SECONDS, "no response")
        end
    end
end

local function StartTimeout(entry, seconds)
    C_Timer.After(seconds, function() OnNoResponse(entry) end)
end

-- Whisper + guild invite for one candidate, then they move from the Scan
-- card to the Recruit Next card. Must come from a real click: the guild
-- invite is a protected action.
-- mode: nil = what the settings say (whisper and/or invite), "whisper" =
-- whisper only, "invite" = invite only (the Scan row's right-click menu).
function Rec:RecruitCandidate(charName, mode)
    local db = Rec:GetDB()
    local idx
    for i, c in ipairs(Rec.candidates) do
        if c.charName == charName then idx = i break end
    end
    if not idx then return false, "no candidates" end

    local doWhisper, doInvite = db.whisperEnabled, db.inviteEnabled
    if mode == "whisper" then
        doWhisper, doInvite = true, false
    elseif mode == "invite" then
        doWhisper, doInvite = false, true
    end

    if not IsInGuild() then return false, "you're not in a guild" end
    if not doWhisper and not doInvite then
        return false, "whispers and invites are both turned off in Search Settings"
    end
    if doInvite and not Rec:CanInvite() then
        return false, "you don't have permission to invite to the guild"
    end
    if ChatLocked() then return false, "chat is locked right now (combat, M+ or an encounter)" end
    -- A click inside the one-second gap just does nothing (no message).
    if GetTime() < (Rec.actionCooldownUntil or 0) then return false end

    local c = Rec.candidates[idx]
    if Rec:IsBlacklisted(c.charName) then
        table.remove(Rec.candidates, idx)
        NotifyUpdate()
        return false, "blacklisted"
    end
    if doWhisper and db.dailyWhisperCap > 0 and Rec:GetDailyWhisperCount() >= db.dailyWhisperCap then
        return false, "daily whisper cap reached"
    end

    table.remove(Rec.candidates, idx)
    Rec.actionCooldownUntil = GetTime() + ACTION_COOLDOWN
    local entry = {
        charName = c.charName, fullName = c.fullName, level = c.level, classStr = c.classStr,
        classFile = c.classFile, race = c.race, area = c.area, rio = c.rio, at = time(),
    }
    table.insert(db.sent, entry)

    if doWhisper and not (db.inviteFirst and doInvite) then SendWhisper(entry) end
    if doInvite then
        C_GuildInfo.Invite(entry.fullName)
        entry.inviteSent = true
        RecordStat("invites")
    else
        -- Whisper only: nothing to wait on, so block them for next time now.
        Rec:Blacklist(entry.charName, db.blacklistDays, "whispered")
    end
    StartTimeout(entry, NO_RESPONSE_TIMEOUT)
    NotifyUpdate()
    return true
end

-- Recruits somebody who isn't on the Scan list - a player right-clicked in
-- chat, on a unit frame, anywhere in the game's own menus. They're put on
-- the Scan list first so everything after is the normal recruit path.
function Rec:RecruitPlayer(name, info, mode)
    local short = ShortName(name)
    if short == "" then return false, "no name" end
    if InSent(short) then return false, "they're already on the Recruit Next card" end
    if Rec:IsBlacklisted(short) then return false, "they're on your blacklist" end
    local fullName = name
    if not fullName:find("-", 1, true) then
        local _, realm = UnitFullName("player")
        if realm and realm ~= "" then fullName = fullName .. "-" .. realm end
    end
    local found
    for _, c in ipairs(Rec.candidates) do
        if c.charName == short then found = true break end
    end
    if not found then
        info = info or {}
        table.insert(Rec.candidates, 1, {
            charName = short, fullName = fullName, level = info.level, classStr = info.classStr,
            classFile = info.classFile, race = info.race, area = info.area,
        })
    end
    return Rec:RecruitCandidate(short, mode)
end

-- Sends another whisper (the next message in your rotation) to someone on
-- the Recruit Next card.
function Rec:Rewhisper(charName)
    local entry = FindSent(charName)
    if not entry then return false, "they're not on the Recruit Next card" end
    local db = Rec:GetDB()
    if ChatLocked() then return false, "chat is locked right now (combat, M+ or an encounter)" end
    if db.dailyWhisperCap > 0 and Rec:GetDailyWhisperCount() >= db.dailyWhisperCap then
        return false, "daily whisper cap reached"
    end
    if not SendWhisper(entry) then return false, "the whisper message is empty" end
    NotifyUpdate()
    return true
end

-- Takes someone off the Recruit Next card without blocking them.
function Rec:RemoveFromSent(charName)
    local entry = FindSent(charName)
    if entry then RemoveSent(entry) end
end

-- Blocks someone on the card for good and takes them off it.
function Rec:BlacklistSent(charName)
    local entry = FindSent(charName)
    Rec:BlacklistPermanent(charName, "manual")
    if entry then RemoveSent(entry) end
end

function Rec:RecruitNext()
    local first = Rec.candidates[1]
    if not first then return false, "no candidates" end
    return Rec:RecruitCandidate(first.charName)
end

function Rec:CanInvite()
    return CanGuildInvite ~= nil and CanGuildInvite()
end

-- Results from the game's own messages -----------------------------------
local function OnInviteSent(name)
    local entry = FindSent(name)
    if not entry then return end
    local db = Rec:GetDB()
    -- Invite-first: the whisper goes out once the invite has gone through.
    if db.inviteFirst and db.whisperEnabled and not entry.whisperSent then
        SendWhisper(entry)
        NotifyUpdate()
    end
end

local function OnJoined(name)
    local entry = FindSent(name)
    if not entry then return end
    RecordStat("accepted")
    Rec:GetDB().recruited[entry.charName] = time()
    Rec:GetDB().noResponse[entry.charName] = nil
    Say(entry.charName .. " accepted your invite and joined the guild.")
    if Rec:GetDB().soundInviteAccepted and PlaySound and SOUNDKIT then
        PlaySound(SOUNDKIT.READY_CHECK, "Master")
    end
    RemoveSent(entry)
end

local function OnInviteFailed(name, reason)
    local entry = name and FindSent(name) or OnlyPendingInvite()
    if not entry then return end
    local db = Rec:GetDB()
    if reason == "declined" then
        RecordStat("declined")
        Rec:Blacklist(entry.charName, db.blacklistDays, "declined")
    elseif reason ~= "not_found" and reason ~= "guild_full" then
        Rec:Blacklist(entry.charName, db.blacklistDays, reason)
    end
    if reason == "guild_full" then Say("Your guild is full - the invite didn't go through.") end
    RemoveSent(entry)
end

local function OnWhisperIgnored(name)
    local entry = name and FindSent(name)
    if not entry then return end
    Rec:BlacklistPermanent(entry.charName, "ignored")
    RemoveSent(entry)
end

local function OnWhisperNotFound(name)
    local entry = FindSent(name)
    if not entry then return end
    RemoveSent(entry)
end

-- Patterns are built from the game's own global strings, so they work in
-- any language the client is in; the English text is a backup.
local function GSPattern(gs)
    if type(gs) ~= "string" or gs == "" then return nil end
    gs = gs:gsub("|3%-%d+%(%%s%)", "%%s")
    local out = gs:gsub("%%%d?%$?[sd]", "\001")
    out = out:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    out = out:gsub("\001", "(.+)")
    return "^" .. out .. "$"
end

local PAT = {}
local function BuildPatterns()
    if PAT.built then return end
    PAT.built = true
    PAT.invited = GSPattern(_G.ERR_GUILD_INVITE_S)
    PAT.joined = GSPattern(_G.ERR_GUILD_JOIN_S)
    PAT.declined = { GSPattern(_G.ERR_GUILD_DECLINE_S), GSPattern(_G.ERR_GUILD_DECLINED_S), GSPattern(_G.ERR_GUILD_INVITE_DECLINED_S) }
    PAT.alreadyIn = GSPattern(_G.ERR_ALREADY_IN_GUILD_S)
    PAT.alreadyInvited = GSPattern(_G.ERR_ALREADY_INVITED_TO_GUILD_S)
    PAT.guildNotFound = GSPattern(_G.ERR_GUILD_PLAYER_NOT_FOUND_S)
    PAT.chatNotFound = GSPattern(_G.ERR_CHAT_PLAYER_NOT_FOUND_S)
    PAT.chatIgnored = GSPattern(_G.ERR_CHAT_PLAYER_IGNORED_S)
    PAT.whoCount = GSPattern(_G.WHO_NUM_RESULTS)
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function OnSystemMessage(msg)
    if type(msg) ~= "string" or Secret(msg) then return end
    BuildPatterns()

    -- A search with nobody in it only produces "0 players total" - no
    -- WHO_LIST_UPDATE - so it has to be finished from this message.
    if pendingWho and PAT.whoCount then
        local count = msg:match(PAT.whoCount)
        if count and tonumber(count) == 0 then
            ProcessWhoResults()
            return
        end
    end

    if #Rec:GetDB().sent == 0 then return end

    local who
    if PAT.invited then
        who = msg:match(PAT.invited)
        if who then OnInviteSent(who) return end
    end
    who = (PAT.joined and msg:match(PAT.joined)) or msg:match("^(.+) has joined the guild%.?$")
    if who then OnJoined(who) return end

    for _, pat in ipairs(PAT.declined) do
        who = msg:match(pat)
        if who then break end
    end
    who = who or msg:match("^(.+) declines your guild invitation%.?$")
    if who then OnInviteFailed(who, "declined") return end

    who = (PAT.alreadyIn and msg:match(PAT.alreadyIn)) or msg:match("^(.+) is already in a guild%.?$")
    if who then OnInviteFailed(who, "already in a guild") return end
    who = PAT.alreadyInvited and msg:match(PAT.alreadyInvited)
    if who then OnInviteFailed(who, "already invited") return end
    who = PAT.guildNotFound and msg:match(PAT.guildNotFound)
    if who then OnInviteFailed(who, "not_found") return end

    who = PAT.chatIgnored and msg:match(PAT.chatIgnored)
    if who then OnWhisperIgnored(who) return end
    if _G.ERR_CHAT_PLAYER_IGNORED_S == nil and (msg:lower():find("is ignoring you", 1, true)) then
        who = msg:match("^(.+) is ignoring you")
        if who then OnWhisperIgnored(who) return end
    end

    who = (PAT.chatNotFound and msg:match(PAT.chatNotFound))
        or msg:match("^No player named '(.+)' is currently playing%.?$")
    if who then
        -- The same message answers a failed whisper or a failed invite.
        OnWhisperNotFound(who)
        return
    end

    if _G.ERR_GUILD_IS_FULL and msg == _G.ERR_GUILD_IS_FULL then
        OnInviteFailed(nil, "guild_full")
    end
end

-- Opt-out detection --------------------------------------------------------
-- A reply to one of our whispers that says no thanks puts that player on
-- the permanent blacklist. Safe phrases match anywhere in the reply; the
-- short risky words only count as a whole word ("no" must not match
-- "know").
local OPT_OUT = {
    en = {
        safe = { "no thanks", "no thank you", "no ty", "not interested", "no interest", "don't want",
            "dont want", "leave me alone", "don't whisper", "dont whisper", "don't message",
            "dont message", "don't contact", "dont contact", "already in a guild", "already guilded",
            "have a guild", "got a guild", "i'm in a guild", "im in a guild", "reported",
            "reporting you", "blocked", "nty", "i'll pass", "ill pass", "not for me",
            "thanks but no thanks", "just looking",
            "no thank u", "no thx", "no, thanks", "i'm good", "im good", "all good", "i'm set", "im set",
            "not looking", "happy where i am", "happy with my guild", "staying in my guild",
            "i have my own guild", "i run a guild", "i lead a guild", "leader of my own guild",
            "please stop", "stop messaging", "stop whispering", "stop spamming", "quit spamming",
            "don't invite", "dont invite", "do not invite", "no invite", "don't need", "dont need",
            "pass on this", "no need", "no guilds" },
        risky = { "stop", "spam", "no", "pass", "nope", "nah" },
        aggressive = { "go away", "fuck off", "piss off", "bugger off", "screw off", "sod off" },
    },
    fr = {
        safe = { "non merci", "pas intéressé", "pas intéressée", "déjà dans une guilde", "non ça va",
            "laisse moi tranquille", "ça m'intéresse pas" },
        risky = { "nope" },
    },
    de = {
        safe = { "nein danke", "nicht interessiert", "hab schon ne gilde", "bin bereits in einer gilde",
            "lass mich in ruhe", "bin nicht interessiert", "danke nein" },
        risky = { "nein" },
    },
    es = {
        safe = { "no gracias", "no me interesa", "ya tengo gremio", "no tengo tiempo",
            "no estoy interesado", "no estoy interesada", "déjame en paz" },
        risky = {},
    },
}
Rec.OPT_OUT_LANGUAGES = {
    { key = "en", name = "English" }, { key = "fr", name = "French" },
    { key = "de", name = "German" }, { key = "es", name = "Spanish" },
}

local function MatchWholeWord(text, word)
    local escaped = word:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    return text:find("^" .. escaped .. "$") or text:find("^" .. escaped .. "%W")
        or text:find("%W" .. escaped .. "$") or text:find("%W" .. escaped .. "%W")
end

local function IsOptOut(text)
    local db = Rec:GetDB()
    local low = text:lower()
    for lang, on in pairs(db.optOutLanguages) do
        local set = on and OPT_OUT[lang]
        if set then
            for _, phrase in ipairs(set.safe) do
                if low:find(phrase, 1, true) then return true end
            end
            for _, word in ipairs(set.risky) do
                if MatchWholeWord(low, word) then return true end
            end
            if db.optOutAggressive and set.aggressive then
                for _, phrase in ipairs(set.aggressive) do
                    if low:find(phrase, 1, true) then return true end
                end
            end
        end
    end
    -- The player's own phrases, one per line.
    for line in (db.optOutCustom or ""):gmatch("[^\r\n]+") do
        local phrase = line:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if phrase ~= "" and low:find(phrase, 1, true) then return true end
    end
    return false
end

local function OnWhisperReceived(msg, sender)
    if type(msg) ~= "string" or Secret(msg) or Secret(sender) then return end
    local entry = FindSent(sender)
    if not entry then return end
    local db = Rec:GetDB()
    if db.optOutDetection and IsOptOut(msg) then
        RecordStat("optOuts")
        Rec:BlacklistPermanent(entry.charName, "opt-out")
        Say(entry.charName .. " said no thanks - they won't be contacted again.")
        RemoveSent(entry)
        return
    end
    -- Any other answer is a reply: kept on their Recruit Next row, with a
    -- sound so you notice.
    entry.reply = TruncateChat(msg)
    entry.replyAt = time()
    if db.soundReply and PlaySound and SOUNDKIT then
        PlaySound(SOUNDKIT.UI_BNET_TOAST or SOUNDKIT.TELL_MESSAGE, "Master")
    end
    NotifyUpdate()
end

-- Events -----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("WHO_LIST_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("INITIAL_CLUBS_LOADED")
eventFrame:RegisterEvent("CLUB_FINDER_RECRUITMENT_POST_RETURNED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "WHO_LIST_UPDATE" then
        -- Only our own searches - never one the player typed by hand.
        if pendingWho then ProcessWhoResults() end
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage((...))
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        OnWhisperReceived(msg, sender)
    elseif event == "INITIAL_CLUBS_LOADED" then
        PrimeGuildLink()
    elseif event == "CLUB_FINDER_RECRUITMENT_POST_RETURNED" then
        -- The game just delivered the listing: look the link up now so it's
        -- remembered before the first whisper needs it.
        Rec:GetGuildFinderLink()
    elseif event == "PLAYER_LOGIN" then
        Rec:PurgeBlacklist()
        -- The 70 second timers don't survive a reload: finish the ones that
        -- ran out and restart the ones that haven't.
        local sent = Rec:GetDB().sent
        for i = #sent, 1, -1 do
            local entry = sent[i]
            local left = NO_RESPONSE_TIMEOUT - (time() - (entry.at or 0))
            if left <= 0 then
                table.remove(sent, i)
            else
                StartTimeout(entry, left)
            end
        end
    end
end)

-- Ads (Trade/General posts) -------------------------------------------------
-- Works like GRIP's post queue: the scheduler adds one General and one
-- Trade ad to a queue every N minutes, and each click on Post Ad sends the
-- FIRST ad in the queue. A channel post needs a genuine click behind it -
-- the game blocks programmatic sends to CHANNEL chat - so nothing here can
-- post by itself.
local AD_INTERVAL_MIN, AD_INTERVAL_MAX = 1, 180 -- minutes
local AD_GAP_MIN, AD_GAP_MAX = 3, 120 -- seconds between posts
local AD_QUEUE_MAX_LIMIT = 50

Rec.adQueue = {} -- session-only: { channel = "general"|"trade", msg = "..." }
local nextBatchAt
local lastPostSentAt = 0

local function AdClamp(v, lo, hi)
    return math.max(lo, math.min(hi, tonumber(v) or lo))
end

function Rec:GetAdQueue()
    return Rec.adQueue
end

-- Seconds between scheduled batches.
local function BatchInterval()
    return AdClamp(Rec:GetDB().adIntervalMinutes, AD_INTERVAL_MIN, AD_INTERVAL_MAX) * 60
end

-- Restarts the wait for the next scheduled batch (after the interval or the
-- on/off switch changes).
function Rec:ResetSchedule()
    nextBatchAt = Rec:GetDB().adSchedulerEnabled and (GetTime() + BatchInterval()) or nil
end

-- Seconds until the next scheduled batch, or nil when the scheduler is off.
function Rec:GetNextBatchSeconds()
    if not Rec:GetDB().adSchedulerEnabled then return nil end
    if not nextBatchAt then Rec:ResetSchedule() end
    return math.max(0, math.ceil(nextBatchAt - GetTime()))
end

-- Seconds until Post Ad can send again.
function Rec:GetPostCooldown()
    local gap = AdClamp(Rec:GetDB().adMinPostSeconds, AD_GAP_MIN, AD_GAP_MAX)
    return math.max(0, math.ceil(gap - (GetTime() - lastPostSentAt)))
end

local function Enqueue(channel, template)
    local db = Rec:GetDB()
    if #Rec.adQueue >= AdClamp(db.adQueueMax, 1, AD_QUEUE_MAX_LIMIT) then return false end
    if not template or not template:match("%S") then return false end
    local msg = TruncateChat(FillTemplate(template, ""))
    if not msg:match("%S") then return false end
    table.insert(Rec.adQueue, { channel = channel, msg = msg })
    return true
end

-- One General and one Trade ad.
local function QueueCycle()
    local db = Rec:GetDB()
    local a = Enqueue("general", db.adGeneralTemplate)
    local b = Enqueue("trade", db.adTradeTemplate)
    if a or b then NotifyUpdate() end
end

-- Finds a joined channel by name. For Trade, the plain Trade channel wins
-- over "Trade (Services)".
local function FindChannelIndex(token)
    local channels = { GetChannelList() }
    local fallback
    for i = 1, #channels, 3 do
        local id, chanName = channels[i], channels[i + 1]
        if type(id) == "number" and type(chanName) == "string" then
            local lname = chanName:lower()
            if lname:find(token, 1, true) then
                if token == "trade" and lname:find("services", 1, true) then
                    fallback = fallback or id
                else
                    return id
                end
            end
        end
    end
    return fallback
end

-- Sends the first ad in the queue. Must come from a real click. Returns
-- true, or false plus a reason.
function Rec:PostNext()
    if InCombatLockdown() then return false, "you can't post to public channels in combat" end
    if ChatLocked() then return false, "chat is locked right now (combat, M+ or an encounter)" end

    if #Rec.adQueue == 0 then QueueCycle() end
    if #Rec.adQueue == 0 then return false, "there's no ad to post - write the General and Trade messages in Ads Settings" end

    local wait = Rec:GetPostCooldown()
    if wait > 0 then return false, "wait " .. wait .. " more seconds between posts" end

    local task = Rec.adQueue[1]
    local channelId = FindChannelIndex(task.channel)
    if not channelId then
        return false, "you're not in the " .. (task.channel == "trade" and "Trade" or "General") .. " channel"
    end

    table.remove(Rec.adQueue, 1)
    lastPostSentAt = GetTime()
    SendChatMessage(task.msg, "CHANNEL", nil, channelId)
    RecordStat("posts")
    NotifyUpdate()
    return true
end

-- The scheduler only fills the queue.
C_Timer.NewTicker(1, function()
    local db = Rec:GetDB()
    if not db.adSchedulerEnabled then
        nextBatchAt = nil
        return
    end
    if not nextBatchAt then Rec:ResetSchedule() end
    if GetTime() >= nextBatchAt then
        QueueCycle()
        nextBatchAt = GetTime() + BatchInterval()
    end
end)


-- Right-click menu --------------------------------------------------------------
-- Adds entries to the game's own right-click menu on a player (chat names,
-- unit frames, /who and party lists), through Menu.ModifyMenu. The tags are
-- the unit menus the game registers; contextData.name / .server are filled in
-- by the game (server is nil for a same-realm player).
local MENU_TAGS = {
    "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND",
    "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS", "MENU_UNIT_COMMUNITIES_WOW_MEMBER", "MENU_UNIT_RECENT_ALLY",
}

local function MenuTargetName(contextData)
    local name = contextData and contextData.name
    if type(name) ~= "string" or name == "" then return nil end
    if Secret(name) then return nil end
    local server = contextData.server
    if type(server) == "string" and server ~= "" and not name:find("-", 1, true) then
        local myRealm = GetNormalizedRealmName and GetNormalizedRealmName()
        if server ~= myRealm then name = name .. "-" .. server end
    end
    return name
end

local function MenuShouldShow(contextData)
    if not Rec:GetDB().unitMenu then return false end
    if not IsInGuild() or not Rec:CanInvite() then return false end
    local unit = contextData and contextData.unit
    if unit then
        if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
        if UnitIsInMyGuild(unit) then return false end
    end
    local name = MenuTargetName(contextData)
    if not name or ShortName(name) == UnitName("player") then return false end
    return true
end

local function AddRecruitMenu(_, rootDescription, contextData)
    if not MenuShouldShow(contextData) then return end
    local name = MenuTargetName(contextData)
    local unit = contextData.unit
    local info
    if unit and UnitExists(unit) then
        local className, classFile = UnitClass(unit)
        info = { level = UnitLevel(unit), classStr = className, classFile = classFile, race = UnitRace(unit) }
    end

    rootDescription:CreateDivider()
    -- Welcome Wagon has its own plain "Invite to Guild"; showing it twice
    -- would be clutter.
    local wagon = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("XalsWelcomeWagon")
    if not wagon then
        rootDescription:CreateButton("Invite to Guild", function()
            C_GuildInfo.Invite(name)
        end)
    end
    rootDescription:CreateButton("Recruit (whisper and invite)", function()
        local ok, reason = Rec:RecruitPlayer(name, info)
        if not ok and reason then Say("Couldn't recruit " .. ShortName(name) .. ": " .. reason .. ".") end
    end)
    rootDescription:CreateButton("Add to Recruit Blacklist", function()
        Rec:AddToBlacklist(ShortName(name), "manual")
    end)
end

local menuFrame = CreateFrame("Frame")
menuFrame:RegisterEvent("PLAYER_LOGIN")
menuFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not (Menu and Menu.ModifyMenu) then return end
    for _, tag in ipairs(MENU_TAGS) do
        Menu.ModifyMenu(tag, AddRecruitMenu)
    end
end)
