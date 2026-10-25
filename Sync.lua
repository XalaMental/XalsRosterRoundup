-- Sync.lua
-- Xal's Roster Roundup
--
-- Shares officers' edits (nicknames, notes, mains and alts, professions,
-- birthdays, dates, strikes, and the Guild Master's promotion rules)
-- between officers who are online at the same time, over the OFFICER chat
-- addon channel - so only people who can read officer chat ever receive it.
--
-- How it works: when an officer logs in, the addon sends a short hello over
-- officer chat. Any other officer running Roster Roundup who is online
-- answers with every field that is newer than what the hello said the sender
-- already has, and sends a hello back so the sender's newer fields travel the
-- other way. There is no stored queue: someone who is offline is simply
-- brought up to date the next time you are both online.
--
-- Each field carries the time it was last edited and the newest edit wins.
-- Nothing in the rest of the addon has to know about this: edits are noticed
-- by comparing each field with what it was the last time it was looked at.
XRR = XRR or {}
XRR.Sync = {}
local S = XRR.Sync
local R = XRR.Roster

local PREFIX = "XRRSYNC"
local VERSION = 1
local SEND_INTERVAL = 0.3 -- seconds between outgoing messages (the game throttles addon chat)
local MAX_QUEUE = 3000
local Enqueue, FieldMessage, RulesText -- defined below, used by S:Flush
local MAX_VALUE_BYTES = 170
local BASELINE_TIME = 1 -- data that was here before syncing existed counts as "old": anything newer wins

local EXPORT_PREFIX = "!XRR:SYNC:1:"

S.peers = {} -- [name] = last time we heard from them
S.dirty = {} -- [name] = { [key] = true } edited here, not sent yet
S.rulesSentAt = 0
S.lastFrom, S.lastAt = nil, nil

-- Text safe to carry in one message: ^ separates fields, ; separates entries
-- in an export, and % starts an escape.
local function Esc(v)
    return (tostring(v or ""):gsub("[%%%^;\r\n]", function(ch) return ("%%%02X"):format(ch:byte()) end))
end

local function Unesc(v)
    return (v:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function Split(text, sep)
    local out = {}
    local from = 1
    while true do
        local i = text:find(sep, from, true)
        if not i then
            table.insert(out, text:sub(from))
            break
        end
        table.insert(out, text:sub(from, i - 1))
        from = i + 1
    end
    return out
end

local function Short(name)
    return (tostring(name or ""):match("^([^-]+)")) or ""
end

-- What gets shared, one entry per field: Get returns the value as text, Set
-- applies text back onto the member.
local function TableToList(t)
    local keys = {}
    for k, v in pairs(t or {}) do
        if v then table.insert(keys, k) end
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

local FIELDS = {
    nick = {
        get = function(m) return m.nickname or "" end,
        set = function(m, v) m.nickname = v end,
    },
    note = {
        get = function(m) return m.notes or "" end,
        set = function(m, v) m.notes = v end,
    },
    onote = {
        get = function(m) return m.officerNote or "" end,
        set = function(m, v) m.officerNote = v end,
    },
    cnote = {
        get = function(m) return m.customNotes or "" end,
        set = function(m, v) m.customNotes = v end,
    },
    p1 = {
        get = function(m) return m.profession1 or "" end,
        set = function(m, v) m.profession1 = v end,
    },
    p2 = {
        get = function(m) return m.profession2 or "" end,
        set = function(m, v) m.profession2 = v end,
    },
    bday = {
        get = function(m) return m.birthday and (m.birthday.day .. "," .. m.birthday.month) or "" end,
        set = function(m, v)
            local d, mo = v:match("^(%d+),(%d+)$")
            m.birthday = d and { day = tonumber(d), month = tonumber(mo) } or nil
        end,
    },
    joinov = {
        get = function(m) return m.joinDateOverride and tostring(m.joinDateOverride) or "" end,
        set = function(m, v) m.joinDateOverride = tonumber(v) end,
    },
    joinunk = {
        get = function(m) return m.joinDateUnknown and "1" or "" end,
        set = function(m, v) m.joinDateUnknown = (v == "1") or nil end,
    },
    promov = {
        get = function(m) return m.promotedOverride and tostring(m.promotedOverride) or "" end,
        set = function(m, v) m.promotedOverride = tonumber(v) end,
    },
    link = {
        -- "" = a main, otherwise the main this character is an alt of.
        get = function(m) return m.linkedMain or "" end,
        set = function(m, v)
            if v == "" then
                m.isMain, m.linkedMain, m.confirmedMain = true, nil, true
            else
                m.isMain, m.linkedMain, m.confirmedMain = false, v, false
            end
        end,
    },
    why = {
        get = function(m) return TableToList(m.reasons) end,
        set = function(m, v)
            m.reasons = {}
            for key in v:gmatch("[^,]+") do m.reasons[key] = true end
        end,
    },
    strikes = {
        get = function(m)
            local parts = {}
            for _, s in ipairs(m.strikes or {}) do
                table.insert(parts, tostring(s.at or 0) .. "\t" .. (s.text or ""))
            end
            return table.concat(parts, "\n")
        end,
        set = function(m, v)
            m.strikes = {}
            for line in v:gmatch("[^\n]+") do
                local at, text = line:match("^(%d+)\t(.*)$")
                if at then table.insert(m.strikes, { at = tonumber(at), text = text }) end
            end
        end,
    },
}
local FIELD_ORDER = {}
for key in pairs(FIELDS) do table.insert(FIELD_ORDER, key) end
table.sort(FIELD_ORDER)

-- Change detection ----------------------------------------------------------------
-- m._fv[key] is the value as of the last look, m._ft[key] when it last
-- changed. A value that differs from _fv was edited here since then.
local function ScanMember(m, now, name)
    m._fv = m._fv or {}
    m._ft = m._ft or {}
    for _, key in ipairs(FIELD_ORDER) do
        local cur = FIELDS[key].get(m)
        local last = m._fv[key]
        if last == nil then
            -- First look: whatever is here predates syncing.
            m._fv[key] = cur
            if cur ~= "" then m._ft[key] = BASELINE_TIME end
        elseif cur ~= last then
            m._fv[key] = cur
            m._ft[key] = now
            -- Edited here: queue it to go out to the other officers.
            if name then
                S.dirty[name] = S.dirty[name] or {}
                S.dirty[name][key] = true
            end
        end
    end
end

function S:Scan(guild)
    local now = time()
    for name, m in pairs(guild.members) do ScanMember(m, now, name) end
end

-- Sends the edits made here since the last look to any officer online. Runs
-- every 20 seconds, so an edit reaches them automatically.
function S:Flush()
    local guild = R:GetCurrentGuild()
    if not guild or not S.canSync(guild) then return end
    S:Scan(guild)
    for name, keys in pairs(S.dirty) do
        local m = guild.members[name]
        if m then
            for key in pairs(keys) do
                Enqueue(FieldMessage(name, key, m._ft[key], FIELDS[key].get(m)))
            end
        end
    end
    wipe(S.dirty)
    if R:IsGuildMaster() and (guild.promotionRulesAt or 0) > S.rulesSentAt then
        S.rulesSentAt = guild.promotionRulesAt
        Enqueue(table.concat({ "G", tostring(guild.promotionRulesAt), Esc(RulesText(guild)) }, "^"))
    end
end

local function MaxStamp(guild)
    local newest = guild.promotionRulesAt or 0
    for _, m in pairs(guild.members) do
        if m._ft then
            for _, t in pairs(m._ft) do
                if t > newest then newest = t end
            end
        end
    end
    return newest
end

-- Sending -----------------------------------------------------------------------------
local queue = {}
local ticker

local function SendNow(text)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return true end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "OFFICER")
    if not ok then return false end
    -- Success is 0; anything throttle-like should be retried a little later.
    if Enum and Enum.SendAddonMessageResult and result == Enum.SendAddonMessageResult.AddonMessageThrottle then
        return false
    end
    return true
end

local function StartTicker()
    if ticker then return end
    ticker = C_Timer.NewTicker(SEND_INTERVAL, function()
        if #queue == 0 then
            ticker:Cancel()
            ticker = nil
            return
        end
        if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
            return -- wait out combat / M+ / encounters
        end
        local text = queue[1]
        if SendNow(text) then table.remove(queue, 1) end
    end)
end

function Enqueue(text)
    if #queue >= MAX_QUEUE then return end
    table.insert(queue, text)
    StartTicker()
end

function FieldMessage(name, key, at, value)
    value = value or ""
    if #value > MAX_VALUE_BYTES then value = value:sub(1, MAX_VALUE_BYTES) end
    return table.concat({ "F", name, key, tostring(at), Esc(value) }, "^")
end

function RulesText(guild)
    local parts = {}
    for order, days in pairs(guild.promotionRules or {}) do
        table.insert(parts, order .. ":" .. days)
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- Everything newer than `since`.
local function QueueNewerThan(guild, since)
    S:Scan(guild)
    if (guild.promotionRulesAt or 0) > since and R:IsGuildMaster() then
        Enqueue(table.concat({ "G", tostring(guild.promotionRulesAt), Esc(RulesText(guild)) }, "^"))
    end
    for name, m in pairs(guild.members) do
        for _, key in ipairs(FIELD_ORDER) do
            local at = m._ft and m._ft[key]
            if at and at > since then
                Enqueue(FieldMessage(name, key, at, FIELDS[key].get(m)))
            end
        end
    end
end

local function CanSync(guild)
    if not guild or not IsInGuild() then return false end
    if not R:GetOfficerDB().syncEnabled then return false end
    return R:HasOfficerAccess(guild)
end
S.canSync = CanSync

-- Says hello over officer chat; any officer who answers is online and gets
-- brought up to date.
function S:Hello()
    local guild = R:GetCurrentGuild()
    if not CanSync(guild) then return end
    S:Scan(guild)
    Enqueue(table.concat({ "H", tostring(VERSION), tostring(MaxStamp(guild)) }, "^"))
end

-- Sends everything (the "Send everything now" link).
function S:SendEverything()
    local guild = R:GetCurrentGuild()
    if not CanSync(guild) then return false end
    QueueNewerThan(guild, 0)
    return true
end

function S:GetStatus()
    local count = 0
    local now = time()
    for name, t in pairs(S.peers) do
        if now - t < 900 then count = count + 1 else S.peers[name] = nil end
    end
    return { peers = count, lastFrom = S.lastFrom, lastAt = S.lastAt }
end

-- Receiving -----------------------------------------------------------------------------------
-- Only officers (or the Guild Master) count as a source, however the message
-- got here.
local function IsOfficerName(guild, name)
    local m = guild.members[name]
    return m ~= nil and (m.isOfficer or m.rankOrder == 1)
end

local function ApplyField(guild, name, key, at, value)
    local m = guild.members[name]
    local field = FIELDS[key]
    if not m or not field then return false end
    ScanMember(m, time(), name) -- count any unseen local edit first, so it can win
    if at > ((m._ft and m._ft[key]) or 0) then
        field.set(m, value)
        m._fv[key] = field.get(m)
        m._ft[key] = at
        return true
    end
    return false
end

local function ApplyRules(guild, at, text)
    if at <= (guild.promotionRulesAt or 0) then return false end
    local rules = {}
    for order, days in text:gmatch("(%d+):(%d+)") do rules[tonumber(order)] = tonumber(days) end
    guild.promotionRules = rules
    guild.promotionRulesAt = at
    return true
end

local function HandleMessage(sender, text, fromExport)
    local guild = R:GetCurrentGuild()
    if not guild then return end
    local kind = text:sub(1, 1)
    local parts = Split(text, "^")

    if kind == "H" or kind == "R" then
        if fromExport then return end
        local since = tonumber(parts[3]) or 0
        S.peers[sender] = time()
        QueueNewerThan(guild, since)
        if kind == "H" then
            -- Answer with our own stamp so they send back what we're missing.
            Enqueue(table.concat({ "R", tostring(VERSION), tostring(MaxStamp(guild)) }, "^"))
        end
    elseif kind == "F" then
        local name, key, at, value = parts[2], parts[3], tonumber(parts[4]), Unesc(parts[5] or "")
        if name and key and at and ApplyField(guild, name, key, at, value) then
            S.lastFrom, S.lastAt = sender, time()
            return true
        end
    elseif kind == "G" then
        -- Promotion rules are the Guild Master's: anyone else's are ignored.
        local at, rules = tonumber(parts[2]), Unesc(parts[3] or "")
        local fromMaster = fromExport or sender == guild.masterName
        if at and fromMaster and ApplyRules(guild, at, rules) then
            S.lastFrom, S.lastAt = sender, time()
            return true
        end
    end
    return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
local helloScheduled = false

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
        -- Look again every 20 seconds for edits made here (cheap), and say
        -- hello once the roster has had time to load.
        C_Timer.NewTicker(20, function() S:Flush() end)
        C_Timer.After(25, function()
            if not helloScheduled then
                helloScheduled = true
                S:Hello()
            end
        end)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix ~= PREFIX or channel ~= "OFFICER" then return end
        if type(text) ~= "string" or type(sender) ~= "string" then return end
        if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
        local guild = R:GetCurrentGuild()
        if not guild or not CanSync(guild) then return end
        local short = Short(sender)
        if short == UnitName("player") then return end
        if not IsOfficerName(guild, short) then return end
        if HandleMessage(short, text) then R:NotifyChanged(guild) end
    end
end)

-- Backup: the same fields as one pasteable line -----------------------------------------
function S:Export()
    local guild = R:GetCurrentGuild()
    if not guild then return "" end
    S:Scan(guild)
    local parts = {}
    if guild.promotionRulesAt then
        table.insert(parts, table.concat({ "G", tostring(guild.promotionRulesAt), Esc(RulesText(guild)) }, "^"))
    end
    for name, m in pairs(guild.members) do
        for _, key in ipairs(FIELD_ORDER) do
            local at = m._ft and m._ft[key]
            if at then
                local value = FIELDS[key].get(m)
                table.insert(parts, table.concat({ "F", name, key, tostring(at), Esc(value) }, "^"))
            end
        end
    end
    return EXPORT_PREFIX .. table.concat(parts, ";")
end

-- Returns how many fields were applied, or nil plus a reason.
function S:Import(text)
    local guild = R:GetCurrentGuild()
    if not guild then return nil, "log in with your guild character first" end
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, "that doesn't look like a Roster Roundup backup"
    end
    local applied = 0
    for entry in text:sub(#EXPORT_PREFIX + 1):gmatch("[^;]+") do
        if HandleMessage("import", entry, true) then applied = applied + 1 end
    end
    R:NotifyChanged(guild)
    return applied
end
