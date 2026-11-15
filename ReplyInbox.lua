-- ReplyInbox.lua
-- Xal's Roster Roundup
--
-- A small chat box for recruiting only: the whispers Recruit Next sends, and
-- the answers people give, in one place. Names are real chat links, so a
-- right-click on one opens the game's own player menu (Whisper, Invite to
-- Guild, and so on) exactly as it does in chat. Your normal whisper window
-- or addon still gets every whisper too - this is an extra view, not a
-- replacement.
XRR = XRR or {}
XRR.ReplyInbox = {}
local I = XRR.ReplyInbox
local Brand = XRR.BrandStyle

local MAX_KEPT = 60 -- lines remembered between sessions
local frame, log

local function Store()
    XRR_DB.replyInboxLog = XRR_DB.replyInboxLog or {}
    return XRR_DB.replyInboxLog
end

local function ClassHex(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then
        return ("%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
    end
    return "ffffff"
end

local function Line(item)
    local who = item.fullName or item.name
    local link = ("|Hplayer:%s|h|cff%s[%s]|r|h"):format(who, ClassHex(item.classFile), item.name)
    local stamp = date("%H:%M", item.at or time())
    if item.out then
        return ("|cff8c8c99%s  You whispered|r %s|cff8c8c99:  %s|r"):format(stamp, link, item.text)
    end
    return ("|cff8c8c99%s|r  %s: |cffe8e8ee%s|r"):format(stamp, link, item.text)
end

local function Build()
    local f = CreateFrame("Frame", "XRRReplyInbox", UIParent, "BackdropTemplate")
    f:SetSize(380, 210)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        XRR_DB.replyInboxPoint = { point, relPoint, x, y }
    end)
    local pos = XRR_DB.replyInboxPoint
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 24, 240)
    end
    Brand.ApplyBackground(f)
    Brand.DrawBorder(f, 1)
    f:Hide()

    local title = Brand.FS(f, "Recruit Replies", Brand.TITLE_FONT_PATH, 15, "",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)

    local close = Brand.MakeCloseButton(f, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    local clear = Brand.MakeTextLink(f, "Clear", function()
        wipe(Store())
        log:Clear()
    end)
    clear:SetPoint("RIGHT", close, "LEFT", -4, 0)

    log = CreateFrame("ScrollingMessageFrame", nil, f)
    log:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
    log:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 26)
    log:SetFont(Brand.BODY_FONT_PATH, 13, "")
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(200)
    log:SetHyperlinksEnabled(true)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    -- The same call the chat window makes: a right-click on a player link
    -- opens the game's player menu, left-click on it starts a whisper.
    log:SetScript("OnHyperlinkClick", function(self, link, text, button)
        SetItemRef(link, text, button, self)
    end)

    local hint = Brand.FS(f, "Right-click a name > Invite to Guild", Brand.BODY_FONT_PATH, 11, "",
        Brand.DESC_COLOR[1], Brand.DESC_COLOR[2], Brand.DESC_COLOR[3])
    hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)

    for _, item in ipairs(Store()) do
        log:AddMessage(Line(item))
    end
    frame = f
    return f
end

local function Add(item)
    local store = Store()
    table.insert(store, item)
    while #store > MAX_KEPT do table.remove(store, 1) end
    if not frame then Build() end
    log:AddMessage(Line(item))
end

-- Something Recruit Next sent.
function I:Sent(entry, text)
    if not entry or not text then return end
    Add({ name = entry.charName, fullName = entry.fullName, classFile = entry.classFile,
        text = text, out = true, at = time() })
end

-- Somebody answered. Pops the box up unless that's turned off.
function I:Reply(entry, text, popup)
    if not entry or not text then return end
    Add({ name = entry.charName, fullName = entry.fullName, classFile = entry.classFile,
        text = text, at = time() })
    if popup then frame:Show() end
end

function I:Toggle()
    if not frame then Build() end
    frame:SetShown(not frame:IsShown())
end

SLASH_XRRREPLIES1 = "/rrreplies"
SlashCmdList["XRRREPLIES"] = function() I:Toggle() end
