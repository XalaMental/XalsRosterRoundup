-- Backup.lua
-- Xal's Roster Roundup
--
-- Safety copies of everything the addon tracks per guild (members, notes,
-- log, bans, rank changes). Forever's beta has been known to skip loading
-- saved addon data at login, and a bad roster read can leave a guild's
-- record wrong - a copy to go back to makes either one harmless.
--   - Automatic: one copy a day, taken shortly after login.
--   - Manual: "Back up now" on the Backup page.
--   - Before any restore or import, the current data is copied first.
--   - Export/Import: the whole thing as one line of text, for moving it
--     between Retail and Forever or between computers.
XRR = XRR or {}
XRR.Backup = {}
local B = XRR.Backup

local MAX_BACKUPS = 5
local AUTO_EVERY = 20 * 3600
local PREFIX = "!XRR:BK:1:"

local function List()
    XRR_DB.backups = XRR_DB.backups or {}
    return XRR_DB.backups
end

function B:GetList()
    return List()
end

function B:Describe(backup)
    local guilds, members = 0, 0
    for _, g in ipairs(backup.data or {}) do
        guilds = guilds + 1
        for _ in pairs(g.members or {}) do members = members + 1 end
    end
    return guilds, members
end

function B:Create(label, auto)
    local list = List()
    table.insert(list, 1, { at = time(), label = label or "Manual", auto = auto and true or nil,
        data = CopyTable(XRR_DB.guilds or {}) })
    while #list > MAX_BACKUPS do table.remove(list) end
    return list[1]
end

function B:Restore(index)
    local backup = List()[index]
    if not backup then return false end
    local data = CopyTable(backup.data or {})
    B:Create("Before restore")
    XRR_DB.guilds = data
    return true
end

-- Export / import -----------------------------------------------------------
local function Serialize(v, out)
    local t = type(v)
    if t == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            out[#out + 1] = "["
            Serialize(k, out)
            out[#out + 1] = "]="
            Serialize(val, out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    elseif t == "string" then
        local s = string.format("%q", v):gsub("\\\n", "\\n"):gsub("\r", "\\r")
        out[#out + 1] = s
    elseif t == "number" or t == "boolean" then
        out[#out + 1] = tostring(v)
    else
        out[#out + 1] = "nil"
    end
end

function B:Export()
    local out = {}
    Serialize(XRR_DB.guilds or {}, out)
    return PREFIX .. table.concat(out)
end

-- Returns true, or false and the reason.
function B:Import(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #PREFIX) ~= PREFIX then
        return false, "That doesn't look like a Roster Roundup export (it should start with " .. PREFIX .. ")."
    end
    local fn = loadstring("return " .. text:sub(#PREFIX + 1))
    if not fn then return false, "That export is damaged - part of it is missing." end
    setfenv(fn, {})
    local ok, data = pcall(fn)
    if not ok or type(data) ~= "table" then return false, "That export couldn't be read." end
    for _, g in ipairs(data) do
        if type(g) ~= "table" or type(g.name) ~= "string" or type(g.members) ~= "table" then
            return false, "That export doesn't hold guild data."
        end
    end
    B:Create("Before import")
    XRR_DB.guilds = data
    return true
end

-- One automatic copy a day, a little after login so the rest of the addon
-- has finished loading first.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(30, function()
        if not XRR_DB.guilds or #XRR_DB.guilds == 0 then return end
        for _, b in ipairs(List()) do
            if b.auto and time() - (b.at or 0) < AUTO_EVERY then return end
        end
        B:Create("Automatic", true)
    end)
end)
