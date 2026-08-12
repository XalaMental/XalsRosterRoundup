-- Options.lua
-- Xal's Roster Roundup
--
-- The standalone Options window (left-click on the minimap button) - the
-- primary way into settings, per the confirmed brand pattern: header with
-- centered title + divider, a left sidebar of section buttons, content area
-- to the right, footer centered on the content area's span.
XRR = XRR or {}
XRR.Options = {}
local O = XRR.Options
local Brand = XRR.BrandStyle
local R = XRR.Roster

local SIDEBAR_W = 132
local CONTENT_W = 420
local FW = 14 + SIDEBAR_W + 10 + 2 + 12 + CONTENT_W + 14
-- Bumped from 460 - the Guild Master page (unreviewed list + officer
-- management + add-officer field) needs real vertical room (2026-08-12).
local FH = 560

-- Opens Blizzard's real color picker with a live-preview callback - exact
-- pattern already confirmed working in Quest Compass, copied rather than
-- re-derived from memory (SetupColorPickerAndShow on modern Retail, the
-- older .func/.previousValues pattern as a Classic fallback).
local function OpenColorPicker(r, g, b, onChange)
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            swatchFunc = function()
                onChange(ColorPickerFrame:GetColorRGB())
            end,
            cancelFunc = function(previousValues)
                if previousValues then
                    onChange(previousValues.r, previousValues.g, previousValues.b)
                end
            end,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = function()
            onChange(ColorPickerFrame:GetColorRGB())
        end
        ColorPickerFrame.cancelFunc = function(prev)
            if prev then onChange(prev[1], prev[2], prev[3]) end
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- A small swatch button showing the current color; click opens the picker.
-- dbColorTable is the actual saved {r,g,b} table - mutated in place.
local function AddColorSwatch(parent, dbColorTable, anchorPoint, relTo, relPoint, x, y)
    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(24, 24)
    swatch:SetPoint(anchorPoint, relTo, relPoint, x, y)

    local fill = swatch:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(dbColorTable[1], dbColorTable[2], dbColorTable[3], 1)

    -- FOUR separate thin edge textures, not one texture spanning the whole
    -- swatch - that exact mistake caused a real "solid gold block" bug
    -- elsewhere in this addon earlier this session (confirmed 2026-08-12).
    local thick = Brand.LINE_THICKNESS
    local bTop = swatch:CreateTexture(nil, "ARTWORK")
    bTop:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    bTop:SetPoint("TOPLEFT", swatch, "TOPLEFT", -thick, thick)
    bTop:SetPoint("TOPRIGHT", swatch, "TOPRIGHT", thick, thick)
    bTop:SetHeight(thick)
    local bBottom = swatch:CreateTexture(nil, "ARTWORK")
    bBottom:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    bBottom:SetPoint("BOTTOMLEFT", swatch, "BOTTOMLEFT", -thick, -thick)
    bBottom:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", thick, -thick)
    bBottom:SetHeight(thick)
    local bLeft = swatch:CreateTexture(nil, "ARTWORK")
    bLeft:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    bLeft:SetPoint("TOPLEFT", swatch, "TOPLEFT", -thick, thick)
    bLeft:SetPoint("BOTTOMLEFT", swatch, "BOTTOMLEFT", -thick, -thick)
    bLeft:SetWidth(thick)
    local bRight = swatch:CreateTexture(nil, "ARTWORK")
    bRight:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    bRight:SetPoint("TOPRIGHT", swatch, "TOPRIGHT", thick, thick)
    bRight:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", thick, -thick)
    bRight:SetWidth(thick)

    swatch:SetScript("OnClick", function()
        OpenColorPicker(dbColorTable[1], dbColorTable[2], dbColorTable[3], function(r, g, b)
            dbColorTable[1], dbColorTable[2], dbColorTable[3] = r, g, b
            fill:SetColorTexture(r, g, b, 1)
        end)
    end)

    return swatch
end

local frame
local sections = {}
local sectionButtons = {}

local function ClearContent()
    for _, child in ipairs({ frame.content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame.content:GetRegions() }) do
        region:Hide()
    end
end

-- ── Home ─────────────────────────────────────────────────────────────
local function BuildHome(content)
    -- 144x144, matching Quest Compass's confirmed Home-page icon size - 48px
    -- and 88px were both tried there and found too small to appreciate any
    -- detail; there's no real space constraint here forcing it smaller.
    local icon = content:CreateTexture(nil, "ARTWORK")
    icon:SetSize(144, 144)
    icon:SetPoint("TOP", content, "TOP", 0, 0)
    icon:SetTexture("Interface\\AddOns\\XalsRosterRoundup\\Icon.png")

    local lead = Brand.FS(content, "Keep your guild roster straight.", "Fonts\\FRIZQT__.TTF", 20, "",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    lead:SetPoint("TOP", icon, "BOTTOM", 0, -14)
    lead:SetWidth(320)
    lead:SetJustifyH("CENTER")
    lead:SetWordWrap(true)

    local rule = Brand.T(content, (CONTENT_W - 60) / 2, 0, 60, Brand.LINE_THICKNESS,
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    rule:ClearAllPoints()
    rule:SetPoint("TOP", lead, "BOTTOM", 0, -12)

    local body = content:CreateFontString(nil, "OVERLAY")
    body:SetFont("Fonts\\ARIALN.TTF", 15, "")
    body:SetTextColor(0.85, 0.85, 0.85)
    body:SetPoint("TOP", rule, "BOTTOM", 0, -16)
    body:SetWidth(320)
    body:SetJustifyH("CENTER")
    body:SetWordWrap(true)
    body:SetText("Right-click the minimap button to open the Guild Roster - track every member's main/alt setup, professions, and why they're here, all in one place.")

    -- Dedication, same pattern as Quest Compass's (dropped to the bottom of
    -- the panel, separate from the body copy above, styled distinctly so it
    -- reads as a deliberate callout, not just another paragraph) - a
    -- one-off magenta just for "Blinky"'s name, confirmed 2026-08-12, same
    -- idea as Jo's one-off epic-purple in Quest Compass (a personal pick,
    -- not the addon's regular accent color).
    local function MagentaHighlight(text) return "|cffff33cc" .. text .. "|r" end
    local dedication = Brand.FS(content,
        "This one's for " .. MagentaHighlight('"Blinky"')
            .. " - our Guild Master, whether she asked for it or not. When our last GM walked away, she didn't hesitate, she just picked up everything and kept the guild standing. She works harder at this than anyone should have to.\nThis is my way of making some of that a little easier. Here's hoping it helps.",
        "Fonts\\FRIZQT__.TTF", 13, "", Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    dedication:SetPoint("BOTTOM", content, "BOTTOM", 0, 22)
    dedication:SetWidth(320)
    dedication:SetJustifyH("CENTER")
    dedication:SetWordWrap(true)
end

-- ── Data ─────────────────────────────────────────────────────────────
local function BuildData(content)
    local header = Brand.FS(content, "Storage", "Fonts\\MORPHEUS.TTF", 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local desc = content:CreateFontString(nil, "OVERLAY")
    desc:SetFont("Fonts\\ARIALN.TTF", 15, "")
    desc:SetTextColor(0.85, 0.85, 0.85)
    desc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
    desc:SetWidth(CONTENT_W)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText("Account-wide shares one roster across every character. Per-character keeps a separate roster tied to whichever character is logged in - use this if you officer different guilds on different characters.")

    -- Brand.MakeCheckbox, not native UICheckButtonTemplate - the native one
    -- was rendering with its bottom border missing entirely (confirmed
    -- in-game 2026-08-12), so this addon uses the same hand-drawn technique
    -- already proven reliable for buttons/panel borders. See BrandStyle.lua.
    local cb = Brand.MakeCheckbox(content, 22)
    -- Anchored to desc's own BOTTOMLEFT (not a guessed fixed y) so the real
    -- rendered height of the wrapped description text is what determines the
    -- gap - a fixed offset overlapped the checkbox onto the last line of text
    -- once it wrapped to 3 lines (caught 2026-08-12, first in-game screenshot).
    cb:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    cb:SetChecked(XRR_DB.storageScope == "character")
    local label = content:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\ARIALN.TTF", 14, "")
    label:SetTextColor(0.85, 0.85, 0.85)
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetText("Use per-character storage (instead of account-wide)")
    label:SetWordWrap(true)
    label:SetWidth(CONTENT_W - 32)
    cb.OnToggle = function(self)
        XRR_DB.storageScope = self:GetChecked() and "character" or "account"
    end
end

-- ── Guild Master ─────────────────────────────────────────────────────
-- Only meaningfully usable by the actual Guild Master (R:IsGuildMaster) -
-- confirmed 2026-08-12: "to remain safe, the only one that can actually do
-- editing... should be the Guild Master." Everyone else sees a plain
-- explanation instead of the controls.
local function BuildGuildMaster(content)
    local header = Brand.FS(content, "Guild Master", "Fonts\\MORPHEUS.TTF", 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    if not R:IsGuildMaster() then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont("Fonts\\ARIALN.TTF", 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetJustifyH("LEFT")
        msg:SetWordWrap(true)
        msg:SetText("Only the Guild Master can access this page.")
        return
    end

    local guild = R:GetGuilds()[1]
    if not guild then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont("Fonts\\ARIALN.TTF", 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("Open the Guild Roster once (right-click the minimap button) to sync your guild first.")
        return
    end

    local y = 46
    local unreviewed = R:GetUnreviewedMembers(guild)
    local countText = content:CreateFontString(nil, "OVERLAY")
    countText:SetFont("Fonts\\ARIALN.TTF", 15, "")
    countText:SetTextColor(1, 0.53, 0)
    countText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    countText:SetWidth(CONTENT_W)
    countText:SetWordWrap(true)
    countText:SetText(#unreviewed .. " new member" .. (#unreviewed == 1 and "" or "s")
        .. " since you last opened the roster.")
    y = y + 26

    -- Capped at 3 rows so this page doesn't grow past the window - open
    -- the full Guild Roster panel to review everyone.
    for i = 1, math.min(#unreviewed, 3) do
        local m = unreviewed[i]
        local nameFs = content:CreateFontString(nil, "OVERLAY")
        nameFs:SetFont("Fonts\\ARIALN.TTF", 14, "")
        nameFs:SetTextColor(0.9, 0.9, 0.9)
        nameFs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
        nameFs:SetText(m.charName)

        local welcomeBtn = Brand.MakeButton(content, "Send Welcome Message", 170, 22, function()
            ChatFrame_OpenChat("/w " .. m.charName .. " Welcome to the guild! ", DEFAULT_CHAT_FRAME)
        end)
        welcomeBtn:SetPoint("LEFT", nameFs, "RIGHT", 10, 0)
        y = y + 28
    end
    if #unreviewed > 3 then
        local moreFs = content:CreateFontString(nil, "OVERLAY")
        moreFs:SetFont("Fonts\\ARIALN.TTF", 13, "")
        moreFs:SetTextColor(0.6, 0.6, 0.6)
        moreFs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
        moreFs:SetText("+" .. (#unreviewed - 3) .. " more - open the Guild Roster to see them.")
        y = y + 22
    end
    y = y + 16

    local officerHeader = Brand.FS(content, "Officers", "Fonts\\MORPHEUS.TTF", 18, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    officerHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + 24

    local officers = R:GetOfficers(guild)
    if #officers == 0 then
        local noneFs = content:CreateFontString(nil, "OVERLAY")
        noneFs:SetFont("Fonts\\ARIALN.TTF", 13, "")
        noneFs:SetTextColor(0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
        noneFs:SetText("No officers yet.")
        y = y + 22
    else
        for _, m in ipairs(officers) do
            local nameFs = content:CreateFontString(nil, "OVERLAY")
            nameFs:SetFont("Fonts\\ARIALN.TTF", 14, "")
            nameFs:SetTextColor(0.9, 0.9, 0.9)
            nameFs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
            nameFs:SetText(m.charName)

            local removeBtn = Brand.MakeButton(content, "Remove", 80, 20, function()
                R:SetOfficer(guild, m.charName, false)
                O:RefreshCurrentSection()
            end)
            removeBtn:SetPoint("LEFT", nameFs, "RIGHT", 10, 0)
            y = y + 24
        end
    end
    y = y + 8

    local addLabel = content:CreateFontString(nil, "OVERLAY")
    addLabel:SetFont("Fonts\\ARIALN.TTF", 13, "")
    addLabel:SetTextColor(0.85, 0.85, 0.85)
    addLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    addLabel:SetText("Add Officer")
    y = y + 18

    local addBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    addBox:SetSize(200, 20)
    addBox:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
    addBox:SetAutoFocus(false)
    XRR.GuildPanel.AttachAutocomplete(addBox, function(text)
        local out = {}
        for _, m in pairs(guild.members) do
            if m.charName:lower():sub(1, #text) == text:lower() and not m.isOfficer then
                table.insert(out, m.charName)
            end
        end
        table.sort(out)
        return out
    end, function(name)
        R:SetOfficer(guild, name, true)
        O:RefreshCurrentSection()
    end)
    addBox:SetScript("OnEnterPressed", function(self)
        local name = self:GetText()
        if guild.members[name] then
            R:SetOfficer(guild, name, true)
            O:RefreshCurrentSection()
        end
    end)
end

-- ── Communication ────────────────────────────────────────────────────
-- Available to everyone, not just the Guild Master - a quick way to reach
-- the GM or an officer without digging through the full roster
-- (confirmed 2026-08-12).
local function BuildCommunication(content)
    local header = Brand.FS(content, "Communication", "Fonts\\MORPHEUS.TTF", 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local guild = R:GetGuilds()[1]
    if not guild then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont("Fonts\\ARIALN.TTF", 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("Open the Guild Roster once (right-click the minimap button) to sync your guild first.")
        return
    end

    local y = 46
    if guild.masterName then
        local gmBtn = Brand.MakeButton(content, "Message Guild Master (" .. guild.masterName .. ")", 260, 24, function()
            ChatFrame_OpenChat("/w " .. guild.masterName .. " ", DEFAULT_CHAT_FRAME)
        end)
        gmBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        y = y + 34
    end

    local officerHeader = Brand.FS(content, "Officers", "Fonts\\MORPHEUS.TTF", 18, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    officerHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + 24

    local officers = R:GetOfficers(guild)
    if #officers == 0 then
        local noneFs = content:CreateFontString(nil, "OVERLAY")
        noneFs:SetFont("Fonts\\ARIALN.TTF", 13, "")
        noneFs:SetTextColor(0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
        noneFs:SetText("No officers set yet.")
    else
        for _, m in ipairs(officers) do
            local nameFs = content:CreateFontString(nil, "OVERLAY")
            nameFs:SetFont("Fonts\\ARIALN.TTF", 14, "")
            nameFs:SetTextColor(0.9, 0.9, 0.9)
            nameFs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
            nameFs:SetText(m.charName)

            local whisperBtn = Brand.MakeButton(content, "Whisper", 90, 20, function()
                ChatFrame_OpenChat("/w " .. m.charName .. " ", DEFAULT_CHAT_FRAME)
            end)
            whisperBtn:SetPoint("LEFT", nameFs, "RIGHT", 10, 0)
            y = y + 24
        end
    end
end

-- ── Display ──────────────────────────────────────────────────────────
-- Changes apply after /reload, not live - colors/opacity are read once when
-- a panel/button is built, matching Quest Compass's own ElvUI-skin toggle
-- convention (confirmed 2026-08-12) rather than a much larger live-
-- re-theme-everything rebuild.
local function BuildDisplay(content)
    local header = Brand.FS(content, "Display", "Fonts\\MORPHEUS.TTF", 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local note = Brand.BodyFS(content, "Changes apply after /reload.", 13)
    note:SetTextColor(0.6, 0.6, 0.6)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -44)

    local accentLabel = Brand.BodyFS(content, "Accent Color", 14)
    accentLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -76)
    XRR_DB.accentColor = XRR_DB.accentColor or { Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3] }
    AddColorSwatch(content, XRR_DB.accentColor, "TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -8)

    local bgLabel = Brand.BodyFS(content, "Background Color", 14)
    bgLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -142)
    XRR_DB.bgColor = XRR_DB.bgColor or { Brand.BG[1], Brand.BG[2], Brand.BG[3] }
    AddColorSwatch(content, XRR_DB.bgColor, "TOPLEFT", bgLabel, "BOTTOMLEFT", 0, -8)

    local opacityLabel = Brand.BodyFS(content, "Background Opacity", 14)
    opacityLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -208)

    -- OptionsSliderTemplate's Low/High/Text sub-regions are only reachable
    -- via the OLD global-name convention (_G[name.."Low"] etc) - they are
    -- NOT exposed as slider.Low/.High/.Text fields directly, confirmed
    -- 2026-08-12 rather than assumed. Needs a real name for this to work.
    local slider = CreateFrame("Slider", "XRROpacitySlider", content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 4, -22)
    slider:SetWidth(300)
    slider:SetMinMaxValues(0.3, 1)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    XRR_DB.bgOpacity = XRR_DB.bgOpacity or Brand.BG[4]
    slider:SetValue(XRR_DB.bgOpacity)
    _G["XRROpacitySliderLow"]:SetText("30%")
    _G["XRROpacitySliderHigh"]:SetText("100%")
    _G["XRROpacitySliderText"]:SetText(math.floor(XRR_DB.bgOpacity * 100) .. "%")
    slider:SetScript("OnValueChanged", function(_, value)
        XRR_DB.bgOpacity = value
        _G["XRROpacitySliderText"]:SetText(math.floor(value * 100) .. "%")
    end)
end

-- ── Text ─────────────────────────────────────────────────────────────
local FONT_CHOICES = {
    { key = "FRIZQT", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "ARIALN", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "SKURRI", name = "Skurri", path = "Fonts\\SKURRI.TTF" },
}
local SIZE_CHOICES = {
    { key = "SMALL", name = "Small", scale = 0.85 },
    { key = "MEDIUM", name = "Medium", scale = 1.0 },
    { key = "LARGE", name = "Large", scale = 1.15 },
}
local OUTLINE_CHOICES = {
    { key = "NONE", name = "None", flag = "" },
    { key = "OUTLINE", name = "Outline", flag = "OUTLINE" },
    { key = "THICKOUTLINE", name = "Thick Outline", flag = "THICKOUTLINE" },
}

local function BuildText(content)
    local header = Brand.FS(content, "Text", "Fonts\\MORPHEUS.TTF", 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local note = Brand.BodyFS(content, "Changes apply after /reload. Applies to body text (labels, roster names, descriptions) - not the branded window titles.", 13)
    note:SetTextColor(0.6, 0.6, 0.6)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -44)
    note:SetWidth(CONTENT_W)
    note:SetWordWrap(true)

    local y = 96
    local fontLabel = Brand.BodyFS(content, "Font", 14)
    fontLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + 22
    local fontButtons = {}
    local fx = 0
    for _, opt in ipairs(FONT_CHOICES) do
        local btn = Brand.MakeButton(content, opt.name, 120, 24, function()
            XRR_DB.bodyFontPath = opt.path
            for _, b in ipairs(fontButtons) do b:SetSelected(b.optKey == opt.key) end
        end)
        btn.optKey = opt.key
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", fx, -y)
        btn:SetSelected((XRR_DB.bodyFontPath or Brand.BODY_FONT_PATH) == opt.path)
        table.insert(fontButtons, btn)
        fx = fx + 130
    end
    y = y + 40

    local sizeLabel = Brand.BodyFS(content, "Size", 14)
    sizeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + 22
    local sizeButtons = {}
    local sx = 0
    for _, opt in ipairs(SIZE_CHOICES) do
        local btn = Brand.MakeButton(content, opt.name, 120, 24, function()
            XRR_DB.bodySizeScale = opt.scale
            for _, b in ipairs(sizeButtons) do b:SetSelected(b.optKey == opt.key) end
        end)
        btn.optKey = opt.key
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", sx, -y)
        btn:SetSelected((XRR_DB.bodySizeScale or Brand.BODY_SIZE_SCALE) == opt.scale)
        table.insert(sizeButtons, btn)
        sx = sx + 130
    end
    y = y + 40

    local outlineLabel = Brand.BodyFS(content, "Outline", 14)
    outlineLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + 22
    local outlineButtons = {}
    local ox = 0
    for _, opt in ipairs(OUTLINE_CHOICES) do
        local btn = Brand.MakeButton(content, opt.name, 120, 24, function()
            XRR_DB.bodyOutline = opt.flag
            for _, b in ipairs(outlineButtons) do b:SetSelected(b.optKey == opt.key) end
        end)
        btn.optKey = opt.key
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", ox, -y)
        btn:SetSelected((XRR_DB.bodyOutline or Brand.BODY_OUTLINE) == opt.flag)
        table.insert(outlineButtons, btn)
        ox = ox + 130
    end
end

sections["Home"] = BuildHome
sections["Data"] = BuildData
sections["Guild Master"] = BuildGuildMaster
sections["Communication"] = BuildCommunication
sections["Text"] = BuildText
sections["Display"] = BuildDisplay

local activeSection = "Home"

local function ShowSection(name)
    activeSection = name
    for key, btn in pairs(sectionButtons) do
        btn:SetSelected(key == name)
    end
    ClearContent()
    sections[name](frame.content)
end

-- Lets a page (Guild Master's officer add/remove) redraw itself in place
-- after a click, without needing to know section-switching internals.
function O:RefreshCurrentSection()
    ShowSection(activeSection)
end

local function CreateFramework()
    frame = CreateFrame("Frame", "XRROptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FW, FH)
    -- Distinct default position (NOT identical to Guild Roster's) - a prior
    -- pass reverted both windows to plain bare "CENTER" with zero offset,
    -- which spawns them at the literal same coordinate every time, which is
    -- what was still causing full overlap (confirmed 2026-08-12, second
    -- screenshot). Freely movable afterward same as before.
    frame:SetPoint("CENTER", UIParent, "CENTER", -140, 60)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- Distinct frame strata from Guild Roster (which uses "DIALOG") - a real
    -- separate render layer, not just draw-order-by-creation-sequence, so
    -- one is guaranteed on top of the other regardless of which opened last.
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    Brand.ApplyBackground(frame)
    Brand.DrawBorder(frame, 6)

    Brand.Title(frame, "Xal's Roster Roundup", 32, "TOP", frame, "TOP", 0, -20)
    Brand.DrawDivider(frame, Brand.SAFE_MARGIN, 80, FW - Brand.SAFE_MARGIN * 2)

    local closeBtn = Brand.MakeButton(frame, "X", 24, 24, function() frame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Brand.SAFE_MARGIN, -Brand.SAFE_MARGIN)

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", Brand.SAFE_MARGIN, -88)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", Brand.SAFE_MARGIN, Brand.SAFE_MARGIN)
    sidebar:SetWidth(SIDEBAR_W)

    local vDivider = frame:CreateTexture(nil, "ARTWORK")
    vDivider:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    vDivider:SetWidth(Brand.LINE_THICKNESS)
    vDivider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    vDivider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 10, 0)

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", vDivider, "TOPRIGHT", 26, -32)
    frame.content:SetSize(CONTENT_W, FH - 88 - Brand.SAFE_MARGIN - 24 - 32)

    -- Order confirmed 2026-08-12.
    local sectionNames = { "Home", "Communication", "Text", "Display", "Guild Master", "Data" }
    local y = -32
    for _, name in ipairs(sectionNames) do
        local btn = Brand.MakeButton(sidebar, name, 116, 24, function() ShowSection(name) end)
        btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, y)
        sectionButtons[name] = btn
        y = y - 28
    end

    -- Footer, centered on the content area's span (divider to right border).
    local footer = frame:CreateFontString(nil, "OVERLAY")
    footer:SetFont("Fonts\\ARIALN.TTF", 12, "")
    footer:SetTextColor(Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    footer:SetPoint("BOTTOMLEFT", vDivider, "BOTTOMRIGHT", 12, Brand.SAFE_MARGIN)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Brand.SAFE_MARGIN, Brand.SAFE_MARGIN)
    footer:SetJustifyH("CENTER")
    footer:SetText("v1.0.0  ·  by Xal  ·  A Xal's Creation")

    ShowSection("Home")
end

function O:Open()
    if not frame then CreateFramework() end
    frame:Show()
    frame:Raise()
end

function O:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        O:Open()
    end
end
