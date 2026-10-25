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
-- Widened 420 -> 760 (2026-09-20) - the standalone Guild Roster window
-- (search box, member list, profile card) got merged into this one main
-- window as the new "Roster" page, and that layout needs real room for a
-- member list column alongside a full profile pane. Every other page just
-- renders in the upper-left of the wider space now - a known, accepted
-- cosmetic trade-off, not a bug.
local CONTENT_W = 760
-- Gap-to-content term is 26, not the original formula's 12 - frame.content
-- is actually anchored 26px past the divider (see below), a later fix that
-- never got reflected here. With the old "12" in this formula, content's
-- real right edge (computed from the ACTUAL 26px anchor) landed exactly ON
-- the window's outer edge instead of 14px before it - the missing 14px of
-- right margin was silently eaten, which is what put the Home page's
-- Discord link directly on the border line (confirmed via screenshot
-- 2026-09-12, "the discord is over the line").
local FW = 14 + SIDEBAR_W + 10 + 2 + 26 + CONTENT_W + 14
-- The default content width, kept fixed: CONTENT_W itself changes whenever
-- the window is resized or rebuilt, so working the next width out from it
-- made the pages shrink a little more on every rebuild (every font, size or
-- color change) until they came back blank.
local DEFAULT_CONTENT_W = CONTENT_W
-- Bumped 560 -> 680 (2026-09-20) - the merged Roster page (search box,
-- scrollable member list, full profile card) needs real vertical room,
-- same reasoning as the original Guild Master bump.
local FH = 680

-- Resize bounds (2026-09-22, "people like to do that") - min keeps the
-- Roster page's member list + profile card from folding on top of each
-- other, max is just a sane cap, not a hard technical limit.
local MIN_FW, MIN_FH = FW - 150, 460
local MAX_FW, MAX_FH = 1400, 1000

-- Manual "selected" color toggle for link-style radio-group/tab buttons
-- (Brand.MakeTextLink has no built-in SetSelected the way the old boxed
-- Brand.MakeButton did) - only the ACTIVE section is orange, every other
-- one sits at a muted gray until selected (2026-09-20 - was accent-orange
-- for every unselected link all the time, which read as every sidebar item
-- being "on" at once instead of one clearly active page). Wires OnLeave
-- too, so hovering away doesn't strand a selected button on the generic
-- hover-fade-back color.
-- #323264, confirmed color for unselected sidebar text.
local UNSELECTED_LINK_COLOR = { 0.196, 0.196, 0.392 }
local function SetLinkSelected(btn, selected)
    local r, g, b = UNSELECTED_LINK_COLOR[1], UNSELECTED_LINK_COLOR[2], UNSELECTED_LINK_COLOR[3]
    if selected then r, g, b = Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3] end
    btn.label:SetTextColor(r, g, b, 1)
    btn.selected = selected
    btn:SetScript("OnLeave", function()
        local rr, gg, bb = UNSELECTED_LINK_COLOR[1], UNSELECTED_LINK_COLOR[2], UNSELECTED_LINK_COLOR[3]
        -- Was Brand.ACCENT (orange) here - a selected link would flip from
        -- the correct brick-red to orange the instant the mouse left it,
        -- a leftover from before the 2026-09-20 header-color rollout.
        if btn.selected then rr, gg, bb = Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3] end
        btn.label:SetTextColor(rr, gg, bb, 1)
    end)
end

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
-- dbColorTable is the LIVE Brand table (Brand.ACCENT/Brand.BG) - mutated in
-- place so the swatch and every other already-drawn element share the same
-- values. onSave only fires once the picker is actually used, writing the
-- new color into SavedVariables at that point - NOT on every page open.
--
-- This replaces the old "XRR_DB.accentColor = XRR_DB.accentColor or
-- {Brand.ACCENT...}" pattern, which captured a snapshot of the CODE default
-- into SavedVariables the instant this page was ever built, whether or not
-- the player touched the color picker. That meant every future default
-- color change silently got overridden forever by that old captured
-- snapshot - hit THREE separate times this session (bronze-gold -> indigo,
-- then indigo -> darker indigo, each needing its own one-time migration
-- hack in BrandStyle.lua just to undo the previous auto-capture). Only
-- writing to SavedVariables on a genuine, deliberate color pick closes this
-- off permanently instead of needing a new migration every time the
-- default changes again.
local function AddColorSwatch(parent, dbColorTable, anchorPoint, relTo, relPoint, x, y, onSave)
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
            if onSave then onSave(r, g, b) end
        end)
    end)

    return swatch
end

local frame
local sections = {}
local sectionButtons = {}

-- Forward-declared - the real definition lives further down (originally
-- built just for Applications), but Guild Master (defined earlier in the
-- file) needs to call it too now that its own list grew past one screen's
-- worth (2026-09-20: "hit the +8 more... you can't scroll"). Generalized
-- into a shared per-section scrollbar rather than duplicating the same
-- track+thumb code a second time.
local GetOrCreateSectionScrollbar

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
    -- Standing Discord link, not tied to any one release - lives on Home
    -- since the header itself is title+close only (confirmed brand
    -- standard). Added 2026-08-19 (brand refresh) - this addon had no
    -- in-game Discord link before.
    -- content's own right edge lands EXACTLY on the window's outer edge
    -- (CONTENT_W was sized with no margin allowance) - a bare (0,0) anchor
    -- here put the link directly on the border line instead of inside it
    -- (confirmed via screenshot 2026-09-12, "the discord is over the
    -- line"). Inset by Brand.SAFE_MARGIN, same clearance the close button
    -- gets from the window's own edge.
    local discord = Brand.MakeDiscordLink(content)
    discord:SetPoint("TOPRIGHT", content, "TOPRIGHT", -Brand.SAFE_MARGIN, 0)

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
    body:SetFont(Brand.BODY_FONT_PATH, 15, "")
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

-- The card helpers live with the Recruitment pages further down; declared here
-- so the pages above them can use them too.
local NewCard, FinishCard, GreyFS, AccentFS, ShowTextPopup

-- ── Guild Master ─────────────────────────────────────────────────────
-- Data access (this whole page) is granted to the actual Guild Master
-- (R:IsGuildMaster) AND any character the GM has linked into their own
-- Main/Alt group in this guild (R:HasGMEditAccess - confirmed 2026-08-12,
-- reuses the GM's own existing Main/Alt linking rather than separate
-- account detection). Real guild actions still live only on the Guild
-- Roster panel's profile pages and stay behind R:IsGuildMaster() alone -
-- nothing on this Options page ever performs Promote/Demote/Kick. Everyone
-- else sees a plain explanation instead of the controls.
-- "+N more" used to be dead text with the list hard-capped at 3 rows
-- (leftover from when this page was much narrower/shorter) - confirmed
-- 2026-09-20 this read as broken since nothing was clickable. Now a real
-- link that expands the list in place; resets back to collapsed each time
-- the page is freshly opened.
local showAllUnreviewed = false
local showAllRankChanges = false

-- Shared by both the Guild Master page and the Officer page (2026-09-22,
-- "an officer section right underneath the Guildmaster... basically the
-- same thing as Guildmaster, omitting the skills they cannot use") - same
-- new-members/rank-changes/officers content either way, the only real
-- difference is showBanList: banning is addon-only trust, not a real
-- Blizzard permission, and stays Guild-Master-only by explicit request
-- (confirmed both 2026-09-20 and again 2026-09-22 - "even an officer
-- shouldn't be able to ban").
-- ── Officer tools ───────────────────────────────────────────────────
-- Extra cards on the Officer page. Each one only shows when this officer's
-- rank actually has the matching permission in-game (CanEditMOTD,
-- CanEditGuildInfo, CanGuildRemove), so nobody sees a control that would just
-- be refused.
local showAllInactive = false
local INACTIVE_DAYS = 30
local UPCOMING_DAYS = 7

-- A multi-line text box that wraps, grows no further than `height`, and puts
-- the cursor wherever you click (same box as the whisper messages).
local function MakeWrapBox(card, height, text, maxLetters)
    local box = CreateFrame("Frame", nil, card)
    box:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    box:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -card.cy)
    box:SetHeight(height)
    box:EnableMouse(true)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(Brand.BG[1], Brand.BG[2], Brand.BG[3], 1)
    Brand.DrawBorder(box, 0)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(maxLetters or 0)
    edit:SetFont(Brand.BODY_FONT_PATH, 13, "")
    edit:SetTextColor(0.8, 0.8, 0.85)
    edit:SetJustifyH("LEFT")
    edit:SetText(text or "")
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    card.cy = card.cy + height + 8
    return edit
end

local function OfficerSay(msg)
    print("|cff681417Roster Roundup:|r " .. msg)
end

-- Days since each member was last on, worst first. Online members are
-- left out; the game gives the gap as years/months/days/hours.
local function GetInactiveMembers()
    local out = {}
    local myName = UnitName("player")
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then
            local years, months, days = GetGuildRosterLastOnline(i)
            if years then
                local away = years * 365 + (months or 0) * 30 + (days or 0)
                local short = name:match("^([^-]+)") or name
                if away >= INACTIVE_DAYS and short ~= myName then
                    table.insert(out, { charName = short, days = away })
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.days > b.days end)
    return out
end

-- How many days from today until the next time the month/day comes round
-- (0 = today), or nil if it never resolves.
local function DaysUntil(month, day)
    local now = time()
    local today = date("*t", now)
    local startOfToday = time({ year = today.year, month = today.month, day = today.day, hour = 0 })
    local candidate = time({ year = today.year, month = month, day = day, hour = 12 })
    if not candidate then return nil end
    if candidate < startOfToday then
        candidate = time({ year = today.year + 1, month = month, day = day, hour = 12 })
    end
    return math.floor((candidate - startOfToday) / 86400)
end

local officerSettingsView = false

-- "3m ago" style label for the sync status line.
local function AgoText(epoch)
    local diff = time() - epoch
    if diff < 60 then return "just now" end
    if diff < 3600 then return math.floor(diff / 60) .. " min ago" end
    return math.floor(diff / 3600) .. " h ago"
end

local function OfficerNumberBox(parent, w, value, onChange)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, 20)
    box:SetNumeric(true)
    box:SetAutoFocus(false)
    box:SetText(tostring(value or 0))
    box:SetScript("OnEnterPressed", function(self)
        onChange(tonumber(self:GetText()))
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self) onChange(tonumber(self:GetText())) end)
    return box
end

-- Roster Overview: the top card on both the Guild Master and Officer pages.
local function BuildOverviewCard(body, W, y)
    local card = NewCard(body, y, W, "Roster Overview")
    local ov = R:GetOverview()
    local ovLine = Brand.BodyFS(card, ("Online now: %d of %d  |  At max level: %d  |  Below max: %d")
        :format(ov.online, ov.total, ov.maxLevel, ov.below), 14)
    ovLine:SetTextColor(0.8, 0.8, 0.85)
    ovLine:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 24
    if #ov.classes > 0 then
        local parts = {}
        for _, c in ipairs(ov.classes) do table.insert(parts, c.name .. " " .. c.n) end
        local classFs = Brand.BodyFS(card, "Online by class: " .. table.concat(parts, ", "), 13)
        classFs:SetTextColor(0.6, 0.6, 0.6)
        classFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        classFs:SetWidth(W - 28)
        classFs:SetJustifyH("LEFT")
        classFs:SetWordWrap(true)
        card.cy = card.cy + classFs:GetStringHeight() + 6
    end
    y = FinishCard(card, y)
    return y
end

local function BuildOfficerToolCards(body, W, y, guild)
    local card

    -- Ready for Promotion (only if this rank can promote) -------------------------------
    if CanGuildPromote and CanGuildPromote() then
        card = NewCard(body, y, W, "Ready for Promotion")
        local candidates = R:GetPromotionCandidates(guild)
        if next(guild.promotionRules or {}) == nil then
            local msg = Brand.BodyFS(card, R:IsGuildMaster()
                and "Set how many days each rank needs in Settings (top right)."
                or "No promotion rules yet - the Guild Master sets them, and they reach you through sync.", 13)
            msg:SetTextColor(0.6, 0.6, 0.6)
            msg:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            msg:SetWidth(W - 28)
            msg:SetJustifyH("LEFT")
            msg:SetWordWrap(true)
            card.cy = card.cy + msg:GetStringHeight() + 8
        elseif #candidates == 0 then
            local msg = Brand.BodyFS(card, "Nobody is due a promotion right now.", 13)
            msg:SetTextColor(0.6, 0.6, 0.6)
            msg:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            card.cy = card.cy + 24
        else
            for i = 1, math.min(#candidates, 8) do
                local c = candidates[i]
                local nameFs = card:CreateFontString(nil, "OVERLAY")
                nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
                nameFs:SetTextColor(0.9, 0.9, 0.9)
                nameFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
                nameFs:SetText(c.charName)
                local infoFs = card:CreateFontString(nil, "OVERLAY")
                infoFs:SetFont(Brand.BODY_FONT_PATH, 12, "")
                infoFs:SetTextColor(0.55, 0.55, 0.55)
                infoFs:SetPoint("LEFT", nameFs, "RIGHT", 12, 0)
                infoFs:SetText(c.rankName .. " for " .. c.days .. " days (rule: " .. c.rule .. ")")
                local promoteBtn = Brand.MakeTextLink(card, "Promote to " .. c.targetName, function()
                    StaticPopup_Show("XRR_CONFIRM_RANK_CHANGE", c.charName, c.targetName,
                        { charName = c.charName, targetOrder = c.targetOrder })
                end)
                promoteBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -card.cy + 3)
                card.cy = card.cy + 26
            end
            if #candidates > 8 then
                local more = Brand.BodyFS(card, "+" .. (#candidates - 8) .. " more", 12)
                more:SetTextColor(0.6, 0.6, 0.6)
                more:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
                card.cy = card.cy + 22
            end
        end
        y = FinishCard(card, y)
    end

    -- Message of the Day ---------------------------------------------------
    if CanEditMOTD and CanEditMOTD() then
        card = NewCard(body, y, W, "Message of the Day")
        local current = (C_GuildInfo.GetMOTD and C_GuildInfo.GetMOTD()) or GetGuildRosterMOTD() or ""
        local edit = MakeWrapBox(card, 60, current, 255)
        local countFs = Brand.BodyFS(card, "", 12)
        countFs:SetTextColor(0.6, 0.6, 0.6)
        countFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        local function UpdateCount() countFs:SetText(#edit:GetText() .. " / 255") end
        edit:SetScript("OnTextChanged", UpdateCount)
        UpdateCount()
        local saveBtn = Brand.MakeTextLink(card, "Save", function()
            local setter = C_GuildInfo.SetMOTD or GuildSetMOTD
            if setter then
                setter(edit:GetText())
                OfficerSay("Message of the Day saved.")
            end
        end)
        saveBtn:SetPoint("LEFT", countFs, "RIGHT", 20, 0)
        card.cy = card.cy + 26
        y = FinishCard(card, y)
    end

    -- Guild Info -----------------------------------------------------------
    if CanEditGuildInfo and CanEditGuildInfo() then
        card = NewCard(body, y, W, "Guild Info")
        local current = (C_GuildInfo.GetInfoText and C_GuildInfo.GetInfoText()) or (GetGuildInfoText and GetGuildInfoText()) or ""
        local edit = MakeWrapBox(card, 90, current, 500)
        local countFs = Brand.BodyFS(card, "", 12)
        countFs:SetTextColor(0.6, 0.6, 0.6)
        countFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        local function UpdateCount() countFs:SetText(#edit:GetText() .. " / 500") end
        edit:SetScript("OnTextChanged", UpdateCount)
        UpdateCount()
        local saveBtn = Brand.MakeTextLink(card, "Save", function()
            local setter = C_GuildInfo.SetInfoText or SetGuildInfoText
            if setter then
                setter(edit:GetText())
                OfficerSay("Guild Info saved.")
            end
        end)
        saveBtn:SetPoint("LEFT", countFs, "RIGHT", 20, 0)
        card.cy = card.cy + 26
        y = FinishCard(card, y)
    end

    -- Inactive Members ---------------------------------------------------------
    card = NewCard(body, y, W, "Inactive Members")
    local inactive = GetInactiveMembers()
    local summary = Brand.BodyFS(card, #inactive .. " member" .. (#inactive == 1 and "" or "s")
        .. " haven't logged in for " .. R:GetInactiveDays() .. "+ days", 14)
    summary:SetTextColor(0.8, 0.8, 0.85)
    summary:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 26
    local canRemove = CanGuildRemove and CanGuildRemove()
    local shown = showAllInactive and #inactive or math.min(#inactive, 5)
    for i = 1, shown do
        local m = inactive[i]
        local nameFs = card:CreateFontString(nil, "OVERLAY")
        nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
        nameFs:SetTextColor(0.9, 0.9, 0.9)
        nameFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        nameFs:SetText(m.charName)
        local daysFs = card:CreateFontString(nil, "OVERLAY")
        daysFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
        daysFs:SetTextColor(0.55, 0.55, 0.55)
        daysFs:SetPoint("LEFT", nameFs, "RIGHT", 12, 0)
        daysFs:SetText(m.days .. " days")
        local checkBtn = Brand.MakeTextLink(card, "Check in", function()
            local msg = R:GetOfficerDB().checkInMessage
            msg = msg:gsub("{player}", (m.charName:gsub("%%", "%%%%")))
            msg = msg:gsub("{guild}", ((GetGuildInfo("player") or ""):gsub("%%", "%%%%")))
            local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
            send(msg:sub(1, 255), "WHISPER", nil, m.charName)
            OfficerSay("Checked in with " .. m.charName .. ".")
        end)
        checkBtn:SetPoint("LEFT", daysFs, "RIGHT", 12, 0)
        if canRemove then
            -- The same two-step confirmation the Roster page's Kick uses.
            local kickBtn = Brand.MakeTextLink(card, "Kick", function()
                StaticPopup_Show("XRR_CONFIRM_KICK", m.charName, nil, m.charName)
            end)
            kickBtn:SetPoint("LEFT", checkBtn, "RIGHT", 8, 0)
        end
        card.cy = card.cy + 26
    end
    if #inactive > shown then
        local moreBtn = Brand.MakeTextLink(card, "+" .. (#inactive - shown) .. " more", function()
            showAllInactive = true
            O:RefreshCurrentSection()
        end)
        moreBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        card.cy = card.cy + 24
    end
    y = FinishCard(card, y)

    -- Missing Info -----------------------------------------------------------------
    card = NewCard(body, y, W, "Missing Info")
    local noNote = 0
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, note = GetGuildRosterInfo(i)
        if name and (note == nil or note == "") then noNote = noNote + 1 end
    end
    local unsorted = 0
    for _, m in pairs(guild.members) do
        if R:IsUntouched(m) then unsorted = unsorted + 1 end
    end
    local line1 = Brand.BodyFS(card, noNote .. " member" .. (noNote == 1 and " has" or "s have") .. " no public note", 14)
    line1:SetTextColor(0.8, 0.8, 0.85)
    line1:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 24
    local line2 = Brand.BodyFS(card, unsorted .. " member" .. (unsorted == 1 and " hasn't" or "s haven't")
        .. " been filled in yet (red asterisk on the Roster page)", 14)
    line2:SetTextColor(0.8, 0.8, 0.85)
    line2:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 24
    y = FinishCard(card, y)

    -- Upcoming ---------------------------------------------------------------------------
    card = NewCard(body, y, W, "Upcoming")
    local upcoming = {}
    for charName in pairs(guild.members) do
        local b = R:GetBirthday(guild, charName)
        if b then
            local d = DaysUntil(b.month, b.day)
            if d and d <= UPCOMING_DAYS then
                table.insert(upcoming, { days = d, text = "Birthday: " .. charName, month = b.month, day = b.day })
            end
        end
        local joined = R:GetJoinDate(guild, charName)
        if joined then
            local jd = date("*t", joined)
            local years = date("*t").year - jd.year
            local d = DaysUntil(jd.month, jd.day)
            if years >= 1 and d and d <= UPCOMING_DAYS then
                table.insert(upcoming, {
                    days = d, month = jd.month, day = jd.day,
                    text = years .. (years == 1 and " year" or " years") .. " in the guild: " .. charName,
                })
            end
        end
    end
    table.sort(upcoming, function(a, b) return a.days < b.days end)
    if #upcoming == 0 then
        local noneFs = Brand.BodyFS(card, "Nothing in the next " .. UPCOMING_DAYS .. " days.", 13)
        noneFs:SetTextColor(0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        card.cy = card.cy + 22
    else
        local postLines = {}
        for i = 1, math.min(#upcoming, 6) do
            local u = upcoming[i]
            local when = date("%b %d", time({ year = 2000, month = u.month, day = u.day, hour = 12 }))
            table.insert(postLines, u.text .. " (" .. when .. ")")
            local fs = Brand.BodyFS(card, u.text .. "  |cff777777" .. when .. "|r", 14)
            fs:SetTextColor(0.8, 0.8, 0.85)
            fs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            card.cy = card.cy + 24
        end
        local postBtn = Brand.MakeTextLink(card, "Post to Guild Chat", function()
            local text = "Coming up: " .. table.concat(postLines, "; ")
            SendChatMessage(text:sub(1, 255), "GUILD")
        end)
        postBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -card.cy)
        card.cy = card.cy + 24
    end
    y = FinishCard(card, y)

    -- This Week -----------------------------------------------------------------------------
    card = NewCard(body, y, W, "This Week")
    local cutoff = time() - 7 * 86400
    local joins, lefts, promotes, demotes = 0, 0, 0, 0
    for _, entry in ipairs(R:GetLog(guild)) do
        if (entry.time or 0) >= cutoff then
            if entry.category == "join" then joins = joins + 1
            elseif entry.category == "left" then lefts = lefts + 1
            elseif entry.category == "promote" then promotes = promotes + 1
            elseif entry.category == "demote" then demotes = demotes + 1 end
        end
    end
    local weekFs = Brand.BodyFS(card, joins .. " joined, " .. lefts .. " left, " .. promotes .. " promoted, " .. demotes .. " demoted", 14)
    weekFs:SetTextColor(0.8, 0.8, 0.85)
    weekFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 24
    y = FinishCard(card, y)

    -- Sync and Backup ---------------------------------------------------------------------------
    card = NewCard(body, y, W, "Sync and Backup")
    local status = XRR.Sync:GetStatus()
    local syncOn = R:GetOfficerDB().syncEnabled
    local statusText
    if not syncOn then
        statusText = "Sharing with officers: off (Settings)"
    elseif status.peers > 0 then
        statusText = "Sharing with " .. status.peers .. " officer" .. (status.peers == 1 and "" or "s") .. " online now"
    else
        statusText = "Sharing with officers: on - nobody else with Roster Roundup is online right now"
    end
    local statusFs = Brand.BodyFS(card, statusText, 13)
    statusFs:SetTextColor(syncOn and 0.18 or 0.75, syncOn and 0.72 or 0.19, syncOn and 0.30 or 0.19)
    statusFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 22
    if status.lastFrom then
        local lastFs = Brand.BodyFS(card, "Last update from " .. status.lastFrom .. ", " .. AgoText(status.lastAt), 12)
        lastFs:SetTextColor(0.55, 0.55, 0.55)
        lastFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        card.cy = card.cy + 20
    end
    local exportBtn = Brand.MakeTextLink(card, "Export", function()
        ShowTextPopup({
            caption = "Export backup", readOnly = true, text = XRR.Sync:Export(),
            hint = "Ctrl+C to copy. Paste it into Import on another account to bring over notes, mains and alts, and more.",
            primary = "Close",
        })
    end)
    exportBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -card.cy)
    local importBtn = Brand.MakeTextLink(card, "Import", function()
        ShowTextPopup({
            caption = "Import backup", text = "", primary = "Import",
            hint = "Paste a backup that starts with !XRR:SYNC:1:. Anything newer than what you have is kept.",
            onPrimary = function(text)
                local applied, why = XRR.Sync:Import(text)
                if not applied then return false, why end
                O:RefreshCurrentSection()
                return true
            end,
        })
    end)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
    card.cy = card.cy + 26
    local note = Brand.BodyFS(card,
        "Edits to notes, nicknames, mains and alts, professions, birthdays, dates and strikes are shared automatically with other officers who are online, over officer chat. Backup is for moving them to another account.", 12)
    note:SetTextColor(0.55, 0.55, 0.55)
    note:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    note:SetWidth(W - 28)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    card.cy = card.cy + note:GetStringHeight() + 8
    y = FinishCard(card, y)

    return y
end

-- The Settings view shared by the Guild Master and Officer pages.
local function BuildOfficerSettingsPage(content, guild, isGM)
    local TOP = 46
    local viewportHeight = content:GetHeight() - TOP - 20

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)
    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local W = CONTENT_W - 4
    local y = 0
    local db = R:GetOfficerDB()
    local canEditRules = R:HasGMEditAccess(guild)

    -- Promotion Rules: days in a rank before someone is ready for the next.
    local card
    if canEditRules then
    card = NewCard(body, y, W, "Promotion Rules")
    local ranks = R.GetGuildRankNames()
    local nameByOrder = {}
    for _, rank in ipairs(ranks) do nameByOrder[rank.order] = rank.name end
    local anyRank = false
    for _, rank in ipairs(ranks) do
        if rank.order > 1 then
            anyRank = true
            local nameFs = Brand.BodyFS(card, rank.name, 14)
            nameFs:SetTextColor(0.8, 0.8, 0.85)
            nameFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy - 3)
            local current = (guild.promotionRules and guild.promotionRules[rank.order]) or 0
            local unitFs
            if canEditRules then
                local box = OfficerNumberBox(card, 46, current, function(n)
                    R:SetPromotionRule(guild, rank.order, n or 0)
                end)
                box:SetPoint("TOPLEFT", card, "TOPLEFT", 170, -card.cy)
                unitFs = Brand.BodyFS(card, "days, then ready for " .. (nameByOrder[rank.order - 1] or "?"), 13)
                unitFs:SetPoint("LEFT", box, "RIGHT", 8, 0)
            else
                unitFs = Brand.BodyFS(card, (current > 0 and (current .. " days") or "off")
                    .. ", then ready for " .. (nameByOrder[rank.order - 1] or "?"), 13)
                unitFs:SetPoint("TOPLEFT", card, "TOPLEFT", 170, -card.cy - 3)
            end
            unitFs:SetTextColor(0.6, 0.6, 0.6)
            card.cy = card.cy + 28
        end
    end
    if not anyRank then
        local none = Brand.BodyFS(card, "No ranks found yet - open the roster once to sync.", 13)
        none:SetTextColor(0.6, 0.6, 0.6)
        none:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        card.cy = card.cy + 24
    end
    local ruleNote = Brand.BodyFS(card, canEditRules
        and "0 turns a rank off. Officers get these through sync."
        or "Set by the Guild Master and shared with you through sync.", 12)
    ruleNote:SetTextColor(0.55, 0.55, 0.55)
    ruleNote:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 22
    y = FinishCard(card, y)
    end

    -- Check-in Message
    card = NewCard(body, y, W, "Check-in Message")
    local edit = MakeWrapBox(card, 60, db.checkInMessage, 250)
    edit:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText()
        if text:find("[\r\n]") then
            self:SetText((text:gsub("[\r\n]+", " ")))
            self:ClearFocus()
            return
        end
        if userInput then db.checkInMessage = text end
    end)
    local checkNote = Brand.BodyFS(card, "Sent by the Check in link on Inactive Members. {player} and {guild} are filled in.", 12)
    checkNote:SetTextColor(0.55, 0.55, 0.55)
    checkNote:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    card.cy = card.cy + 22
    y = FinishCard(card, y)

    -- Inactive After
    card = NewCard(body, y, W, "Inactive After")
    local inBox = OfficerNumberBox(card, 50, db.inactiveDays, function(n)
        db.inactiveDays = math.max(1, math.min(365, n or db.inactiveDays))
    end)
    inBox:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -card.cy)
    local inLbl = Brand.BodyFS(card, "days offline counts as inactive (also how long away before a return is logged)", 13)
    inLbl:SetTextColor(0.6, 0.6, 0.6)
    inLbl:SetPoint("LEFT", inBox, "RIGHT", 8, 0)
    card.cy = card.cy + 30
    y = FinishCard(card, y)

    -- Sync
    card = NewCard(body, y, W, "Sync")
    local cb = Brand.MakeCheckbox(card, 20)
    cb:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    cb:SetChecked(db.syncEnabled)
    cb.OnToggle = function(self) db.syncEnabled = self:GetChecked() end
    local cbLbl = Brand.BodyFS(card, "Share my edits with other officers and receive theirs", 14)
    cbLbl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    card.cy = card.cy + 30
    y = FinishCard(card, y)

    body:SetHeight(math.max(1, y))

    local bar = GetOrCreateSectionScrollbar()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()
    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)
    local maxScroll = math.max(0, y - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)
    if maxScroll <= 0 then
        bar:Hide()
    else
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * (viewportHeight / y)))
    end
end

local function BuildGuildMasterBody(content, guild, showBanList)
    -- Real scrollable body, not everything drawn straight onto `content` -
    -- new members + rank changes + officers + the ban list can easily run
    -- past one screen, and there was no way to reach anything below the
    -- fold or even back out of an expanded "+N more" list (confirmed
    -- 2026-09-20 - "you can't scroll... does not allow you to back out").
    -- Same viewport/scrollbar technique as the Applications page.
    local GM_TOP = 46
    local GM_BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - GM_TOP - GM_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -GM_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    -- Every group below is its own card (the lighter fill with the thin
    -- border); card.cy is the running y position inside the card.
    local y = 0
    local W = CONTENT_W - 4
    y = BuildOverviewCard(body, W, y)

    -- Guild Discord (2026-09-22, "we don't want it sending every person that
    -- uses this addon's members to our server") - per-guild, GM-set (see
    -- R:SetGuildDiscordUrl), never a hardcoded addon-wide URL. showBanList
    -- doubles as "is this the Guild Master's own page" here: the Guild
    -- Master gets a real editable field, officers get a read-only copy of it
    -- plus a way to drop it straight into guild chat.
    local card = NewCard(body, y, W, "Guild Discord")
    if showBanList then
        local urlBox = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
        urlBox:SetSize(360, 20)
        urlBox:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -card.cy)
        urlBox:SetAutoFocus(false)
        urlBox:SetText(guild.discordUrl or "")
        local function SaveDiscordUrl(self)
            R:SetGuildDiscordUrl(guild, self:GetText())
        end
        urlBox:SetScript("OnEnterPressed", function(self)
            SaveDiscordUrl(self)
            self:ClearFocus()
        end)
        urlBox:SetScript("OnEditFocusLost", SaveDiscordUrl)
        card.cy = card.cy + 30
    elseif guild.discordUrl and guild.discordUrl ~= "" then
        local urlFs = Brand.BodyFS(card, guild.discordUrl, 13)
        urlFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)

        local copyBtn = Brand.MakeTextLink(card, "Copy", function()
            Brand.ShowCopyBox("Guild Discord", guild.discordUrl)
        end)
        copyBtn:SetPoint("LEFT", urlFs, "RIGHT", 14, 0)

        local postBtn = Brand.MakeTextLink(card, "Post to Guild Chat", function()
            SendChatMessage(guild.discordUrl, "GUILD")
        end)
        postBtn:SetPoint("LEFT", copyBtn, "RIGHT", 14, 0)
        card.cy = card.cy + 26
    else
        local noneFs = Brand.BodyFS(card, "The Guild Master hasn't set a Discord link yet.", 13)
        noneFs:SetTextColor(0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        card.cy = card.cy + 22
    end
    y = FinishCard(card, y)

    -- New members ---------------------------------------------------------
    local unreviewed = R:GetUnreviewedMembers(guild)
    -- Just seeing them here IS the review now (confirmed 2026-09-22 - "I
    -- shouldn't have to click every single one of them, just looking at
    -- them should be a review") - snapshot the list first so this one
    -- render still shows who was actually new, then mark all of them
    -- reviewed so they're gone from this list the next time it opens.
    for _, m in ipairs(unreviewed) do
        R:MarkReviewed(guild, m.charName)
    end
    card = NewCard(body, y, W, "New Members")
    local countText = card:CreateFontString(nil, "OVERLAY")
    countText:SetFont(Brand.BODY_FONT_PATH, 15, "")
    countText:SetTextColor(1, 0.53, 0)
    countText:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    countText:SetWidth(W - 28)
    countText:SetJustifyH("LEFT")
    countText:SetWordWrap(true)
    countText:SetText(#unreviewed .. " new member" .. (#unreviewed == 1 and "" or "s")
        .. " since you last opened the roster.")
    card.cy = card.cy + 26

    local unreviewedShown = showAllUnreviewed and #unreviewed or math.min(#unreviewed, 3)
    for i = 1, unreviewedShown do
        local m = unreviewed[i]
        local nameFs = card:CreateFontString(nil, "OVERLAY")
        nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
        nameFs:SetTextColor(0.9, 0.9, 0.9)
        nameFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        nameFs:SetText(m.charName)

        local welcomeBtn = Brand.MakeTextLink(card, "Send Welcome Message", function()
            ChatFrame_OpenChat("/w " .. m.charName .. " Welcome to the guild! ", DEFAULT_CHAT_FRAME)
        end)
        welcomeBtn:SetPoint("LEFT", nameFs, "RIGHT", 10, 0)
        card.cy = card.cy + 28
    end
    if #unreviewed > unreviewedShown then
        local moreBtn = Brand.MakeTextLink(card, "+" .. (#unreviewed - unreviewedShown) .. " more", function()
            showAllUnreviewed = true
            O:RefreshCurrentSection()
        end)
        moreBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        card.cy = card.cy + 24
    end
    y = FinishCard(card, y)

    -- Real live rank promotions/demotions caught since the last time this
    -- was checked - see Roster.lua's SyncFromLiveGuild for why this reads
    -- actual game rank data instead of this addon's own "isOfficer" label.
    local rankChanges = R:GetPendingRankChanges(guild)
    if #rankChanges > 0 then
        card = NewCard(body, y, W, "Rank Changes")
        local rankChangesShown = showAllRankChanges and #rankChanges or math.min(#rankChanges, 3)
        for i = 1, rankChangesShown do
            local change = rankChanges[i]
            local changeFs = card:CreateFontString(nil, "OVERLAY")
            changeFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            changeFs:SetTextColor(0.85, 0.85, 0.85)
            changeFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            changeFs:SetWidth(W - 28)
            changeFs:SetJustifyH("LEFT")
            changeFs:SetWordWrap(true)
            changeFs:SetText(change.charName .. ": " .. change.from .. " -> " .. change.to)
            card.cy = card.cy + 20
        end
        if #rankChanges > rankChangesShown then
            local moreRankBtn = Brand.MakeTextLink(card, "+" .. (#rankChanges - rankChangesShown) .. " more", function()
                showAllRankChanges = true
                O:RefreshCurrentSection()
            end)
            moreRankBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            card.cy = card.cy + 22
        end

        local dismissBtn = Brand.MakeTextLink(card, "Dismiss", function()
            R:ClearRankChanges(guild)
            O:RefreshCurrentSection()
        end)
        dismissBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        card.cy = card.cy + 28
        y = FinishCard(card, y)
    end

    -- Real, live officer status (2026-09-20) - derived straight from
    -- Blizzard's own rank permissions (the "Is Officer" checkbox in Guild
    -- Control -> Rank Permissions), refreshed every sync. No manual
    -- Add/Remove here anymore - a manual override would just get
    -- overwritten by the real data on the next sync anyway, and this way
    -- it's never out of date with what the guild's ranks actually say.
    card = NewCard(body, y, W, "Officers")
    local officers = R:GetOfficers(guild)
    if #officers == 0 then
        local noneFs = card:CreateFontString(nil, "OVERLAY")
        noneFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
        noneFs:SetTextColor(0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        noneFs:SetText("No ranks with officer permissions right now.")
        card.cy = card.cy + 22
    else
        for _, m in ipairs(officers) do
            local nameFs = card:CreateFontString(nil, "OVERLAY")
            nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
            nameFs:SetTextColor(0.9, 0.9, 0.9)
            nameFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            nameFs:SetText(m.charName .. "  |cff777777(" .. (m.rankName or "?") .. ")|r")
            card.cy = card.cy + 24
        end
    end
    y = FinishCard(card, y)

    -- Both the Guild Master and Officer pages get the officer tools (each card
    -- only shows what this rank can actually do).
    y = BuildOfficerToolCards(body, W, y, guild)

    -- Ban list - same shape as GRM's own ban feature (researched
    -- 2026-09-20): a blacklist + reason, and a warning if the name ever
    -- shows back up. It does NOT kick anyone and can't block a rejoin -
    -- Blizzard has no API for either, confirmed. GM-only - confirmed both
    -- 2026-09-20 and again 2026-09-22 that even an officer shouldn't be
    -- able to ban (kick, yes; ban, no) - hidden entirely on the Officer
    -- page via showBanList.
    if showBanList then
        card = NewCard(body, y, W, "Ban List")

        local banIntro = Brand.BodyFS(card,
            "Banning someone doesn't kick them - it flags their name so you're warned if they ever try to rejoin.", 13)
        banIntro:SetTextColor(0.6, 0.6, 0.6)
        banIntro:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        banIntro:SetWidth(W - 28)
        banIntro:SetJustifyH("LEFT")
        banIntro:SetWordWrap(true)
        card.cy = card.cy + 24

        local bannedRejoins = R:GetBannedRejoins(guild)
        if #bannedRejoins > 0 then
            local rejoinFs = card:CreateFontString(nil, "OVERLAY")
            rejoinFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
            rejoinFs:SetTextColor(Brand.ALERT_COLOR_BAN_REJOIN[1], Brand.ALERT_COLOR_BAN_REJOIN[2], Brand.ALERT_COLOR_BAN_REJOIN[3])
            rejoinFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            rejoinFs:SetWidth(W - 28)
            rejoinFs:SetJustifyH("LEFT")
            rejoinFs:SetWordWrap(true)
            local names = {}
            for _, r in ipairs(bannedRejoins) do table.insert(names, r.charName) end
            rejoinFs:SetText(table.concat(names, ", ") .. " - banned, but back in the guild.")
            card.cy = card.cy + 20

            local rejoinDismissBtn = Brand.MakeTextLink(card, "Dismiss", function()
                R:ClearBannedRejoins(guild)
                O:RefreshCurrentSection()
            end)
            rejoinDismissBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            card.cy = card.cy + 28
        end

        local banNameLabel = Brand.BodyFS(card, "Character name", 13)
        banNameLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
        local banReasonLabel = Brand.BodyFS(card, "Reason", 13)
        banReasonLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 184, -card.cy)
        card.cy = card.cy + 18

        local banNameBox = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
        banNameBox:SetSize(150, 20)
        banNameBox:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -card.cy)
        banNameBox:SetAutoFocus(false)

        local banReasonBox = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
        banReasonBox:SetSize(280, 20)
        banReasonBox:SetPoint("TOPLEFT", card, "TOPLEFT", 188, -card.cy)
        banReasonBox:SetAutoFocus(false)

        local addBanBtn = Brand.MakeTextLink(card, "+ Add Ban", function()
            local charName = banNameBox:GetText()
            if charName and charName ~= "" then
                R:AddBan(guild, charName, banReasonBox:GetText())
                banNameBox:SetText("")
                banReasonBox:SetText("")
                O:RefreshCurrentSection()
            end
        end)
        addBanBtn:SetPoint("LEFT", banReasonBox, "RIGHT", 14, 0)
        card.cy = card.cy + 32

        local bans = R:GetBans(guild)
        if #bans == 0 then
            local noneFs = Brand.BodyFS(card, "Nobody's banned right now.", 13)
            noneFs:SetTextColor(0.6, 0.6, 0.6)
            noneFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            card.cy = card.cy + 22
        else
            for _, ban in ipairs(bans) do
                local nameFs = card:CreateFontString(nil, "OVERLAY")
                nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
                nameFs:SetTextColor(0.9, 0.9, 0.9)
                nameFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
                nameFs:SetText(ban.charName)

                local metaFs = card:CreateFontString(nil, "OVERLAY")
                metaFs:SetFont(Brand.BODY_FONT_PATH, 12, "")
                metaFs:SetTextColor(0.55, 0.55, 0.55)
                metaFs:SetPoint("LEFT", nameFs, "RIGHT", 10, 0)
                local reasonText = (ban.reason and ban.reason ~= "") and (ban.reason .. " - ") or ""
                metaFs:SetText(reasonText .. "banned " .. R.FormatDate(ban.bannedAt) .. " by " .. ban.bannedBy)

                local unbanBtn = Brand.MakeTextLink(card, "Unban", function()
                    R:RemoveBan(guild, ban.charName)
                    O:RefreshCurrentSection()
                end)
                unbanBtn:SetPoint("LEFT", metaFs, "RIGHT", 14, 0)
                card.cy = card.cy + 24
            end
        end
        y = FinishCard(card, y)
    end

    -- Real final height, then wire the same shared scrollbar the
    -- Applications page uses (lives in the gap next to the sidebar divider,
    -- not inside `content` itself).
    body:SetHeight(math.max(1, y))

    local bar = GetOrCreateSectionScrollbar()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -GM_TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()

    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    local maxScroll = math.max(0, y - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)

    if maxScroll <= 0 then
        bar:Hide()
    else
        local ratio = viewportHeight / y
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * ratio))
    end
end

local function BuildGuildMaster(content)
    local header = Brand.FS(content, officerSettingsView and "Guild Master Settings" or "Guild Master", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local guild = R:GetCurrentGuild()

    if not guild then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("Open the Guild Roster once (right-click the minimap button) to sync your guild first.")
        return
    end

    if not R:HasGMEditAccess(guild) then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetJustifyH("LEFT")
        msg:SetWordWrap(true)
        msg:SetText("Only the Guild Master can access this page.")
        return
    end

    if officerSettingsView then
        BuildOfficerSettingsPage(content, guild, true)
    else
        local settingsLink = Brand.MakeTextLink(content, "Settings", function()
            officerSettingsView = true
            O:RefreshCurrentSection(true)
        end)
        settingsLink:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
        BuildGuildMasterBody(content, guild, true)
    end
end

-- ── Officer ──────────────────────────────────────────────────────────
-- Same content as the Guild Master page (new members, rank changes,
-- officers list), minus the Ban List - added 2026-09-22 so officers who
-- couldn't see the Guild Master page at all can actually use this addon
-- too, not just the Guild Master and their own alts.
local function BuildOfficer(content)
    local header = Brand.FS(content, officerSettingsView and "Officer Settings" or "Officer", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local guild = R:GetCurrentGuild()

    if not guild then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("Open the Guild Roster once (right-click the minimap button) to sync your guild first.")
        return
    end

    if not R:HasOfficerAccess(guild) then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetJustifyH("LEFT")
        msg:SetWordWrap(true)
        msg:SetText("Only officers and the Guild Master can access this page.")
        return
    end

    if officerSettingsView then
        BuildOfficerSettingsPage(content, guild, false)
    else
        local settingsLink = Brand.MakeTextLink(content, "Settings", function()
            officerSettingsView = true
            O:RefreshCurrentSection(true)
        end)
        settingsLink:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
        BuildGuildMasterBody(content, guild, false)
    end
end

-- ── Display ──────────────────────────────────────────────────────────
-- Changes apply after /reload, not live - colors/opacity are read once when
-- a panel/button is built, matching Quest Compass's own ElvUI-skin toggle
-- convention (confirmed 2026-08-12) rather than a much larger live-
-- re-theme-everything rebuild.
local function BuildDisplay(content)
    local header = Brand.FS(content, "Display", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    -- Color/opacity changes rebuild the window immediately (2026-09-20),
    -- no /reload needed.
    local note = Brand.BodyFS(content, "Changes apply immediately.", 13)
    note:SetTextColor(0.6, 0.6, 0.6)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -44)

    -- One card per setting, inside a scrolling body so a short window never
    -- clips the last one.
    local TOP = 70
    local BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - TOP - BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local W = CONTENT_W - 4
    local y = 0

    -- Deferred one tick (C_Timer.After(0, ...)) rather than rebuilt
    -- immediately inline - the button doing the rebuilding is itself a
    -- child of the frame Rebuild() is about to hide/destroy, so letting
    -- this OnClick handler fully return first is the safe order.
    local card = NewCard(body, y, W, "Accent Color")
    local accentSwatch = AddColorSwatch(card, Brand.ACCENT, "TOPLEFT", card, "TOPLEFT", 16, -card.cy, function(r, g, b)
        XRR_DB.accentColor = { r, g, b }
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    -- Once a color is genuinely saved, no code-side default change can ever
    -- reach it again (that's how the picker's supposed to work) - this is
    -- the actual way back, instead of eyeball-matching a hex value with the
    -- picker.
    local resetAccentBtn = Brand.MakeTextLink(card, "Reset to Default", function()
        XRR_DB.accentColor = nil
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3] =
            Brand.DEFAULT_ACCENT[1], Brand.DEFAULT_ACCENT[2], Brand.DEFAULT_ACCENT[3]
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    resetAccentBtn:SetPoint("LEFT", accentSwatch, "RIGHT", 16, 0)
    card.cy = card.cy + 34
    y = FinishCard(card, y)

    card = NewCard(body, y, W, "Background Color")
    local bgSwatch = AddColorSwatch(card, Brand.BG, "TOPLEFT", card, "TOPLEFT", 16, -card.cy, function(r, g, b)
        XRR_DB.bgColor = { r, g, b }
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    local resetBgBtn = Brand.MakeTextLink(card, "Reset to Default", function()
        XRR_DB.bgColor = nil
        Brand.BG[1], Brand.BG[2], Brand.BG[3] =
            Brand.DEFAULT_BG[1], Brand.DEFAULT_BG[2], Brand.DEFAULT_BG[3]
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    resetBgBtn:SetPoint("LEFT", bgSwatch, "RIGHT", 16, 0)
    card.cy = card.cy + 34
    y = FinishCard(card, y)

    -- OptionsSliderTemplate's Low/High/Text sub-regions are only reachable
    -- via the OLD global-name convention (_G[name.."Low"] etc) - they are
    -- NOT exposed as slider.Low/.High/.Text fields directly, confirmed
    -- 2026-08-12 rather than assumed. Needs a real name for this to work.
    card = NewCard(body, y, W, "Background Opacity")
    local slider = CreateFrame("Slider", "XRROpacitySlider", card, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -(card.cy + 22))
    slider:SetWidth(300)
    slider:SetMinMaxValues(0.3, 1)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    XRR_DB.bgOpacity = XRR_DB.bgOpacity or Brand.BG[4]
    slider:SetValue(XRR_DB.bgOpacity)
    _G["XRROpacitySliderLow"]:SetText("30%")
    _G["XRROpacitySliderHigh"]:SetText("100%")
    _G["XRROpacitySliderText"]:SetText(math.floor(XRR_DB.bgOpacity * 100) .. "%")
    -- Blizzard's OptionsSliderTemplate hardcodes these gold - doesn't read
    -- Brand.ACCENT at all, so it needs an explicit override here.
    for _, suffix in ipairs({ "Low", "High", "Text" }) do
        _G["XRROpacitySlider" .. suffix]:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    end
    slider:SetScript("OnValueChanged", function(_, value)
        XRR_DB.bgOpacity = value
        Brand.BG[4] = value
        _G["XRROpacitySliderText"]:SetText(math.floor(value * 100) .. "%")
    end)
    -- Rebuilds on mouse-up, not on every OnValueChanged tick while dragging
    -- - tearing down and rebuilding the whole window mid-drag would be both
    -- janky and expensive compared to just doing it once when the player
    -- actually lets go.
    slider:SetScript("OnMouseUp", function() C_Timer.After(0, function() O:Rebuild() end) end)
    card.cy = card.cy + 22 + 17 + 22
    y = FinishCard(card, y)

    -- Roster alert icon size (the one floating icon that covers pending
    -- applications, unreviewed members, and rank changes) - 0.5x (roughly
    -- minimap-button-sized) up to 2x the default 64px. Takes effect live via
    -- RosterAlertIcon:ApplyScale(), no rebuild needed.
    card = NewCard(body, y, W, "Alert Icon Size")
    local sizeSlider = CreateFrame("Slider", "XRRAlertSizeSlider", card, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -(card.cy + 22))
    sizeSlider:SetWidth(300)
    sizeSlider:SetMinMaxValues(0.5, 2.0)
    sizeSlider:SetValueStep(0.1)
    sizeSlider:SetObeyStepOnDrag(true)
    XRR_DB.rosterAlertIconScale = XRR_DB.rosterAlertIconScale or 1.0
    sizeSlider:SetValue(XRR_DB.rosterAlertIconScale)
    _G["XRRAlertSizeSliderLow"]:SetText("Small")
    _G["XRRAlertSizeSliderHigh"]:SetText("Large")
    _G["XRRAlertSizeSliderText"]:SetText(math.floor(XRR_DB.rosterAlertIconScale * 100) .. "%")
    for _, suffix in ipairs({ "Low", "High", "Text" }) do
        _G["XRRAlertSizeSlider" .. suffix]:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    end
    sizeSlider:SetScript("OnValueChanged", function(_, value)
        XRR_DB.rosterAlertIconScale = value
        _G["XRRAlertSizeSliderText"]:SetText(math.floor(value * 100) .. "%")
        XRR.RosterAlertIcon:ApplyScale()
    end)
    card.cy = card.cy + 22 + 17 + 22
    y = FinishCard(card, y)

    body:SetHeight(math.max(1, y))

    local bar = GetOrCreateSectionScrollbar()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()

    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    local maxScroll = math.max(0, y - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)

    if maxScroll <= 0 then
        bar:Hide()
    else
        local ratio = viewportHeight / y
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * ratio))
    end
end

-- ── Applications ─────────────────────────────────────────────────────
-- Pending guild-finder applications - Accept/Decline/Whisper act straight
-- on the real applicant via XRR.Applications (Applications.lua), same data
-- Blizzard's own Guild Finder applicant tab reads from.
local function AppLinkBtn(parent, text, r, g, bColor, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(20)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT")
    label:SetText(text)
    label:SetTextColor(r, g, bColor, 1)
    btn.label = label
    btn:SetWidth(label:GetStringWidth())
    btn:SetScript("OnEnter", function() label:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnLeave", function() label:SetTextColor(r, g, bColor, 1) end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function BuildApplicationCard(parent, entry, y, width)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    card:SetSize(width, 92)
    Brand.ApplyCardBackground(card)
    Brand.DrawBorder(card, 0)

    local r, g, b = XRR.Applications.ClassColor(entry.classID)
    local name = card:CreateFontString(nil, "OVERLAY")
    -- Real bold (bundled Inter SemiBold), not the OUTLINE flag - an outline
    -- draws a border around the glyphs, it doesn't change the font weight
    -- (same lesson as the sidebar nav text earlier this session).
    name:SetFont("Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Inter-SemiBold.ttf", 14, "")
    name:SetTextColor(r, g, b)
    name:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10)
    name:SetText(entry.name)

    local level = card:CreateFontString(nil, "OVERLAY")
    level:SetFont(Brand.BODY_FONT_PATH, 12, "")
    level:SetTextColor(0.7, 0.7, 0.7)
    level:SetPoint("LEFT", name, "RIGHT", 8, 0)
    level:SetText("Lvl " .. entry.level .. " " .. XRR.Applications.ClassName(entry.classID))

    -- entry.lastUpdatedTime is a real Unix timestamp (confirmed via
    -- Blizzard's own type annotations, not guessed) - the moment this
    -- application was last touched, which for a still-pending one is when
    -- it was submitted.
    local applied = card:CreateFontString(nil, "OVERLAY")
    applied:SetFont(Brand.BODY_FONT_PATH, 11, "")
    applied:SetTextColor(0.55, 0.55, 0.55)
    applied:SetPoint("LEFT", level, "RIGHT", 8, 0)
    applied:SetText(XRR.Applications.TimeAgo(entry.lastUpdatedTime))

    local note = card:CreateFontString(nil, "OVERLAY")
    note:SetFont(Brand.BODY_FONT_PATH, 12, "")
    note:SetTextColor(0.75, 0.75, 0.75)
    note:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -32)
    note:SetWidth(width - 20)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText((entry.message and entry.message ~= "") and entry.message or "|cff999999(no note)|r")

    -- Darker green, a real red, and the same muted color the sidebar's own
    -- unselected links use (#323264) - confirmed 2026-09-20.
    local acceptBtn = AppLinkBtn(card, "Accept", 0.1, 0.35, 0.16, function()
        XRR.Applications:Accept(entry)
        O:RefreshCurrentSection()
    end)
    acceptBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)

    local declineBtn = AppLinkBtn(card, "Decline", 1.0, 0.0, 0.0, function()
        XRR.Applications:Decline(entry)
        O:RefreshCurrentSection()
    end)
    declineBtn:SetPoint("LEFT", acceptBtn, "RIGHT", 16, 0)

    local whisperBtn = AppLinkBtn(card, "Whisper", 0.196, 0.196, 0.392, function()
        XRR.Applications:Whisper(entry)
    end)
    whisperBtn:SetPoint("LEFT", declineBtn, "RIGHT", 16, 0)

    return card
end

-- Builds (once) the track+thumb scrollbar for the applicant list, living in
-- the gap between the sidebar divider and frame.content - NOT inside
-- frame.content - so it's the addon's usual branded scrollbar (thin track,
-- accent thumb, no arrow buttons, same technique as GuildPanel's Mains list
-- and Notes box) sitting where confirmed, and scrolling the list never
-- drags the sidebar divider or the "Applications" title with it (both of
-- those visually happened - and got explicitly rejected - during earlier
-- mockup rounds).
-- Generalized 2026-09-20 (was Applications-only) - Guild Master's list grew
-- past one screen once the ban list was added, and needed the exact same
-- track+thumb scrollbar living in the same spot (the gap next to the
-- sidebar divider), so this got promoted to a shared per-section helper
-- instead of a second copy of the same code.
function GetOrCreateSectionScrollbar()
    if frame.sectionScrollbar then return frame.sectionScrollbar end

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetWidth(4)
    frame.sectionScrollbar = bar

    local track = bar
    track.tex = track:CreateTexture(nil, "ARTWORK")
    track.tex:SetAllPoints()
    track.tex:SetColorTexture(1, 1, 1, 0.06)

    local thumbSlider = CreateFrame("Slider", nil, track)
    thumbSlider:SetOrientation("VERTICAL")
    thumbSlider:SetPoint("TOP", track, "TOP", 0, 0)
    thumbSlider:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
    thumbSlider:SetWidth(4)
    thumbSlider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumbTex = thumbSlider:GetThumbTexture()
    thumbTex:SetVertexColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    thumbTex:SetWidth(4)
    bar.thumbSlider = thumbSlider

    return bar
end

local function BuildApplications(content)
    local header = Brand.FS(content, "Applications", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local refreshBtn = Brand.MakeTextLink(content, "Refresh", function()
        XRR.Applications:RequestUpdate()
    end)
    refreshBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)

    -- Everything under the header scrolls: the accept-whisper card first,
    -- then one card per pending applicant. The viewport leaves real
    -- clearance above the footer (cards were once drawing straight over the
    -- footer text).
    local LIST_TOP = 46
    local LIST_BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - LIST_TOP - LIST_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LIST_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local W = CONTENT_W - 4
    local y = 0

    -- Accept Whisper: lets an applicant know they got in and to go check
    -- their guild invites, without the Guild Master having to remember to
    -- whisper each one by hand. Same checkbox + wrapping message box +
    -- {player}/{guild}/{guildlink} Insert buttons the Recruitment whispers
    -- use.
    local card = NewCard(body, y, W, "Accept Whisper")
    local whisperCb = Brand.MakeCheckbox(card, 20)
    whisperCb:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    whisperCb:SetChecked(XRR.Applications:IsAutoWhisperEnabled())
    whisperCb.OnToggle = function(self) XRR.Applications:SetAutoWhisperEnabled(self:GetChecked()) end
    local whisperCbLbl = Brand.BodyFS(card, "Whisper applicants when accepted", 13)
    whisperCbLbl:SetPoint("LEFT", whisperCb, "RIGHT", 6, 0)
    card.cy = card.cy + 30

    local whisperBox = MakeWrapBox(card, 70, XRR.Applications:GetAcceptWhisperTemplate(), 0)
    whisperBox:SetScript("OnTextChanged", function(self, userInput)
        -- A chat message can't hold line breaks: Enter just finishes typing.
        local text = self:GetText()
        if text:find("[\r\n]") then
            self:SetText((text:gsub("[\r\n]+", " ")))
            self:ClearFocus()
            return
        end
        if userInput then XRR.Applications:SetAcceptWhisperTemplate(text) end
    end)

    local function InsertPlaceholderBtn(label, placeholder, anchor)
        local btn = Brand.MakeTextLink(card, label, function()
            whisperBox:Insert(placeholder)
            XRR.Applications:SetAcceptWhisperTemplate(whisperBox:GetText())
        end)
        if anchor then
            btn:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
        else
            btn:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
        end
        return btn
    end
    local aInsertLink = InsertPlaceholderBtn("Insert {guildlink}", "{guildlink}")
    local aInsertGuild = InsertPlaceholderBtn("Insert {guild}", "{guild}", aInsertLink)
    InsertPlaceholderBtn("Insert {player}", "{player}", aInsertGuild)
    card.cy = card.cy + 26
    y = FinishCard(card, y)

    local pending = XRR.Applications:GetPending()
    if #pending == 0 then
        local msg = body:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.6, 0.6, 0.6)
        msg:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("No pending applications right now.")
        y = y + 30
    else
        for _, entry in ipairs(pending) do
            BuildApplicationCard(body, entry, y, W)
            y = y + 102
        end
    end
    body:SetHeight(math.max(1, y))

    local bar = GetOrCreateSectionScrollbar()
    -- Centered in the 26px gap between the sidebar's vertical divider and
    -- frame.content's own left edge - matches the confirmed mockup
    -- position exactly, not the far right of the content area.
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -LIST_TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()

    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    local maxScroll = math.max(0, y - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)

    -- Thumb height reflects how much of the list is actually visible at
    -- once (same ratio technique as GuildPanel's Mains list/Notes box) -
    -- hidden entirely when everything already fits, since there's nothing
    -- to scroll.
    if maxScroll <= 0 then
        bar:Hide()
    else
        local ratio = viewportHeight / y
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * ratio))
    end
end

-- ── Text ─────────────────────────────────────────────────────────────
-- The body-text font, size and effects. The font list is every font the
-- player has: the game's own, the two bundled with this addon, and every
-- font other addons share through LibSharedMedia.
local DEFAULT_FONT_SIZE = 13 -- the size Brand's body text is drawn at before scaling

-- {key = font path, name = shown name}, sorted, each path only once.
local function GetFontChoices()
    local choices, seenPath, seenName = {}, {}, {}
    local function Add(name, path)
        if not name or not path or path == "" or seenPath[path:lower()] or seenName[name:lower()] then return end
        seenPath[path:lower()] = true
        seenName[name:lower()] = true
        table.insert(choices, { key = path, name = name, fontPath = path })
    end
    Add("Inter", "Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Inter-Regular.ttf")
    Add("Fira Sans", "Interface\\AddOns\\XalsRosterRoundup\\Fonts\\FiraSans-Medium.ttf")
    Add("Friz Quadrata", "Fonts\\FRIZQT__.TTF")
    Add("Arial Narrow", "Fonts\\ARIALN.TTF")
    Add("Skurri", "Fonts\\SKURRI.TTF")
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            Add(name, LSM:Fetch("font", name))
        end
    end
    table.sort(choices, function(a, b) return a.name:lower() < b.name:lower() end)
    return choices
end

-- True if the game can actually load this font file.
local fontProbe
local function FontLoads(path)
    fontProbe = fontProbe or UIParent:CreateFontString(nil, "OVERLAY")
    return fontProbe:SetFont(path, 12, "") and true or false
end

local function BuildText(content)
    local header = Brand.FS(content, "Text", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local note = Brand.BodyFS(content, "Changes apply immediately. Applies to body text (labels, roster names, descriptions) - not the branded window titles.", 13)
    note:SetTextColor(0.6, 0.6, 0.6)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -44)
    note:SetWidth(CONTENT_W)
    note:SetWordWrap(true)

    -- One card per setting, inside a scrolling body so a short window never
    -- clips the last one.
    local TOP = 84
    local BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - TOP - BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local W = CONTENT_W - 4
    local y = 0

    -- Font ---------------------------------------------------------------
    local card = NewCard(body, y, W, "Font")
    local choices = GetFontChoices()
    local fontDD = Brand.MakeDropdown(card, 260, { searchable = true })
    fontDD:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    fontDD:SetOptions(choices)
    local current = XRR_DB.bodyFontPath or Brand.BODY_FONT_PATH
    fontDD:SetValue(current)
    -- A saved font that isn't in the list (its addon was removed): say so.
    local found = false
    for _, c in ipairs(choices) do
        if c.key == current then found = true break end
    end
    if not found then fontDD.label:SetText("(font not found)") end
    fontDD.OnSelect = function(path)
        if not FontLoads(path) then
            print("|cff681417Roster Roundup:|r that font couldn't be loaded, so the text stays as it was.")
            fontDD:SetValue(XRR_DB.bodyFontPath or Brand.BODY_FONT_PATH)
            return
        end
        XRR_DB.bodyFontPath = path
        Brand.BODY_FONT_PATH = path
        C_Timer.After(0, function() O:Rebuild() end)
    end
    card.cy = card.cy + 34
    y = FinishCard(card, y)

    -- Font Size slider ----------------------------------------------------
    card = NewCard(body, y, W, "Font Size")
    local savedSize = XRR_DB.bodyFontSize
        or math.floor(DEFAULT_FONT_SIZE * (XRR_DB.bodySizeScale or Brand.BODY_SIZE_SCALE) + 0.5)
    local slider = CreateFrame("Slider", "XRRTextFontSizeSlider", card, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -(card.cy + 22))
    slider:SetMinMaxValues(10, 22)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(240)
    local low, high = _G["XRRTextFontSizeSliderLow"], _G["XRRTextFontSizeSliderHigh"]
    low:SetText("10")
    high:SetText("22")
    local valueText = Brand.FS(card, "", Brand.BODY_FONT_PATH, 14, "",
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    valueText:SetPoint("BOTTOM", slider, "TOP", 0, 4)
    slider:SetValue(savedSize)
    valueText:SetText("Font Size: " .. savedSize)
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        XRR_DB.bodyFontSize = value
        XRR_DB.bodySizeScale = value / DEFAULT_FONT_SIZE
        Brand.BODY_SIZE_SCALE = value / DEFAULT_FONT_SIZE
        valueText:SetText("Font Size: " .. value)
    end)
    -- The window redraws once you let go of the slider, not on every step of
    -- the drag (redrawing destroys the slider you're holding).
    slider:SetScript("OnMouseUp", function() C_Timer.After(0, function() O:Rebuild() end) end)
    card.cy = card.cy + 22 + 17 + 22
    y = FinishCard(card, y)

    -- Effects ----------------------------------------------------------------
    card = NewCard(body, y, W, "Effects")
    local outlineCb = Brand.MakeCheckbox(card, 20)
    outlineCb:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    outlineCb:SetChecked(Brand.BODY_OUTLINE ~= "")
    outlineCb.OnToggle = function(self)
        local flag = self:GetChecked() and "OUTLINE" or ""
        XRR_DB.bodyOutline = flag
        Brand.BODY_OUTLINE = flag
        C_Timer.After(0, function() O:Rebuild() end)
    end
    local outlineLbl = Brand.BodyFS(card, "Outline", 14)
    outlineLbl:SetPoint("LEFT", outlineCb, "RIGHT", 8, 0)
    card.cy = card.cy + 30

    local shadowCb = Brand.MakeCheckbox(card, 20)
    shadowCb:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
    shadowCb:SetChecked(Brand.BODY_SHADOW == true)
    shadowCb.OnToggle = function(self)
        XRR_DB.bodyShadow = self:GetChecked()
        Brand.BODY_SHADOW = self:GetChecked()
        C_Timer.After(0, function() O:Rebuild() end)
    end
    local shadowLbl = Brand.BodyFS(card, "Shadow", 14)
    shadowLbl:SetPoint("LEFT", shadowCb, "RIGHT", 8, 0)
    card.cy = card.cy + 30
    y = FinishCard(card, y)

    body:SetHeight(math.max(1, y))

    local bar = GetOrCreateSectionScrollbar()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()

    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    local maxScroll = math.max(0, y - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)

    if maxScroll <= 0 then
        bar:Hide()
    else
        local ratio = viewportHeight / y
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * ratio))
    end
end

-- ── Roster ───────────────────────────────────────────────────────────
-- The merged single-window Guild Roster page (2026-09-20) - used to be its
-- own standalone popup ("Guild Roster", right-click the minimap button).
-- This page just draws the page title/guild-info line/divider above the
-- one header divider; GuildPanel.lua fills in everything below it (search
-- box, member list, profile card) - see that file for the actual layout.
local ROSTER_HEAD_H = 56

local function BuildRoster(content)
    local guild = R:GetCurrentGuild()

    local header = Brand.FS(content, "Guild Roster", Brand.TITLE_FONT_PATH, 22, "OUTLINE",
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    if guild then
        -- Same green tone the old standalone window used for this line -
        -- now sitting in line with the "Guild Roster" title itself, above
        -- the divider, instead of below it (confirmed 2026-09-20).
        local info = Brand.FS(content,
            "<" .. guild.name .. ">  |cff999999-|r  Guild Master: " .. (guild.masterName or "unknown"),
            Brand.BODY_FONT_PATH, 15, "", 0.2, 0.9, 0.3)
        info:SetPoint("LEFT", header, "RIGHT", 14, -2)
    end

    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    if not guild then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("Log in with your guild character to sync your roster first.")
        return
    end

    local container = CreateFrame("Frame", nil, content)
    container:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -ROSTER_HEAD_H)
    container:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    XRR.GuildPanel:Build(container, CONTENT_W, content:GetHeight() - ROSTER_HEAD_H)
end

-- ── Log ──────────────────────────────────────────────────────────────
-- Same shape as GRM's own Log tab (researched 2026-09-21, read-only
-- reference, no code copied): one reverse-chronological list, a search
-- box, category filter toggles, and a total-entries footer. The real
-- entries themselves live in Roster.lua (R:AddLogEntry/R:GetLog), wired
-- into every place that actually changes something (joins, leaves,
-- promotions, demotions, notes, level-ups, ban rejoins).
local logSearchText = ""
local logActiveFilters = {
    join = true, left = true, promote = true, demote = true,
    note = true, levelup = true, banrejoin = true, ["return"] = true,
}
local LOG_FILTER_ORDER = { "join", "left", "promote", "demote", "note", "levelup", "banrejoin", "return" }
local LOG_FILTER_LABELS = {
    join = "Joins", left = "Left / Kicked", promote = "Promotions", demote = "Demotions",
    note = "Notes", levelup = "Level Ups", banrejoin = "Bans", ["return"] = "Returns",
}
local LOG_CATEGORY_COLOR = {
    join = { 0.2, 1, 0.2 },
    left = { 0.6, 0.6, 0.6 },
    promote = Brand.GOLD,
    demote = Brand.ACCENT,
    note = Brand.BODY_TEXT_COLOR,
    levelup = Brand.BODY_TEXT_COLOR,
    banrejoin = Brand.HEADER_COLOR,
    ["return"] = { 0.4, 0.8, 1 },
}

-- "3h ago" style relative label for the log's own timestamp column - the
-- one place in this addon a relative time reads better than an absolute
-- date, since these are recent, frequent events meant to be skimmed.
local function LogTimeText(epoch)
    local diff = time() - epoch
    if diff < 60 then return "Just now" end
    if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
    if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
    return R.FormatDate(epoch)
end

local showAwayCard = false

-- A date heading for a day's card: Today, Yesterday, or "Oct 22".
local function LogDayLabel(epoch)
    local today = date("*t")
    local startOfToday = time({ year = today.year, month = today.month, day = today.day, hour = 0 })
    if epoch >= startOfToday then return "Today" end
    if epoch >= startOfToday - 86400 then return "Yesterday" end
    return date("%b %d", epoch)
end

local function BuildLog(content)
    local guild = R:GetCurrentGuild()

    local header = Brand.FS(content, "Activity Log", Brand.TITLE_FONT_PATH, 22, "OUTLINE",
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    if guild then
        local info = Brand.FS(content,
            "<" .. guild.name .. ">  |cff999999-|r  Guild Master: " .. (guild.masterName or "unknown"),
            Brand.BODY_FONT_PATH, 15, "", 0.2, 0.9, 0.3)
        info:SetPoint("LEFT", header, "RIGHT", 14, -2)

        -- GM-only (2026-09-22) - same trust-call reasoning as the Ban List,
        -- not a real Blizzard permission, just not something every officer
        -- should be able to do to shared local history.
        if R:HasGMEditAccess(guild) then
            local clearLogBtn = Brand.MakeTextLink(content, "Clear Log", function()
                R:ClearLog(guild)
                O:RefreshCurrentSection()
            end)
            clearLogBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
        end
    end

    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    if not guild then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("Log in with your guild character to sync your roster first.")
        return
    end

    -- Search and filters on one card that stays put above the scrolling
    -- days. The search applies on Enter/losing focus rather than every
    -- keystroke, so typing isn't interrupted by the page being redrawn.
    local filterCard = CreateFrame("Frame", nil, content)
    filterCard:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -42)
    filterCard:SetSize(CONTENT_W - 4, 40)
    Brand.ApplyCardBackground(filterCard)
    Brand.DrawBorder(filterCard, 0)

    local searchBox = CreateFrame("EditBox", nil, filterCard, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("LEFT", filterCard, "LEFT", 14, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetText(logSearchText)
    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY")
    searchPlaceholder:SetFont(Brand.BODY_FONT_PATH, 12, "")
    searchPlaceholder:SetTextColor(0.5, 0.5, 0.5)
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
    searchPlaceholder:SetText("Search log...")
    searchPlaceholder:SetShown(logSearchText == "")
    local function ApplySearch(self)
        logSearchText = self:GetText():lower()
        O:RefreshCurrentSection()
    end
    searchBox:SetScript("OnEnterPressed", function(self)
        ApplySearch(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEditFocusLost", ApplySearch)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Filter chips: green while on, red while off.
    local GREEN = { 0.18, 0.72, 0.30 }
    local RED = { 0.75, 0.19, 0.19 }
    local prevChip = searchBox
    for _, category in ipairs(LOG_FILTER_ORDER) do
        local chip = Brand.MakeTextLink(filterCard, LOG_FILTER_LABELS[category], function()
            logActiveFilters[category] = not logActiveFilters[category]
            O:RefreshCurrentSection()
        end)
        local c = logActiveFilters[category] and GREEN or RED
        chip.label:SetTextColor(c[1], c[2], c[3], 1)
        -- MakeTextLink fades back to the accent color on mouse-out; keep the
        -- on/off color instead.
        chip:SetScript("OnLeave", function() chip.label:SetTextColor(c[1], c[2], c[3], 1) end)
        chip:SetPoint("LEFT", prevChip, "RIGHT", 12, 0)
        prevChip = chip
    end

    local LOG_TOP = 92
    local LOG_BOTTOM_CLEARANCE = 40
    local viewportHeight = content:GetHeight() - LOG_TOP - LOG_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LOG_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local W = CONTENT_W - 4
    local y = 0

    -- While You Were Away: what the login check found had changed since the
    -- roster was last seen. Nothing goes into the Log until you add it.
    local away = guild.awayChanges or {}
    if showAwayCard and #away > 0 then
        local awayCard = NewCard(body, y, W, "While You Were Away")
        if guild.awaySince then
            local sinceFs = GreyFS(awayCard, "changes found since " .. date("%b %d, %I:%M %p", guild.awaySince), 12)
            sinceFs:SetPoint("TOPLEFT", awayCard, "TOPLEFT", 190, -11)
        end
        for i, change in ipairs(away) do
            local color = LOG_CATEGORY_COLOR[change.category] or Brand.BODY_TEXT_COLOR
            local textFs = awayCard:CreateFontString(nil, "OVERLAY")
            textFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            textFs:SetTextColor(color[1], color[2], color[3])
            textFs:SetPoint("TOPLEFT", awayCard, "TOPLEFT", 14, -awayCard.cy)
            textFs:SetWidth(W - 140)
            textFs:SetJustifyH("LEFT")
            textFs:SetText(change.text)
            local addBtn = Brand.MakeTextLink(awayCard, "Add to Log", function()
                R:AddAwayToLog(guild, i)
                O:RefreshCurrentSection()
            end)
            addBtn:SetPoint("TOPRIGHT", awayCard, "TOPRIGHT", -8, -awayCard.cy + 3)
            awayCard.cy = awayCard.cy + 26
        end
        local addAllBtn = Brand.MakeTextLink(awayCard, "Add All to Log", function()
            R:AddAllAwayToLog(guild)
            showAwayCard = false
            O:RefreshCurrentSection()
        end)
        addAllBtn:SetPoint("TOPLEFT", awayCard, "TOPLEFT", 8, -awayCard.cy)
        local dismissBtn = Brand.MakeTextLink(awayCard, "Dismiss All", function()
            R:ClearAway(guild)
            showAwayCard = false
            O:RefreshCurrentSection()
        end)
        dismissBtn:SetPoint("LEFT", addAllBtn, "RIGHT", 16, 0)
        awayCard.cy = awayCard.cy + 28
        y = FinishCard(awayCard, y)
    elseif #away == 0 then
        showAwayCard = false
    end

    -- One card per day, newest first (R:GetLog is already newest first).
    local groups, order = {}, {}
    for _, entry in ipairs(R:GetLog(guild)) do
        if logActiveFilters[entry.category]
            and (logSearchText == "" or entry.text:lower():find(logSearchText, 1, true)) then
            local label = LogDayLabel(entry.time)
            if not groups[label] then
                groups[label] = {}
                table.insert(order, label)
            end
            table.insert(groups[label], entry)
        end
    end
    -- "Today" always has a card when there's an update waiting, so the
    -- Update link has somewhere to sit.
    if #away > 0 and not groups["Today"] then
        groups["Today"] = {}
        table.insert(order, 1, "Today")
    end

    if #order == 0 then
        local noneFs = GreyFS(body, "Nothing in the log yet.", 14)
        noneFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        y = y + 30
    end

    for _, label in ipairs(order) do
        local card = NewCard(body, y, W, label)
        if label == "Today" and #away > 0 then
            local updateBtn = Brand.MakeTextLink(card, "Update (" .. #away .. ")", function()
                showAwayCard = not showAwayCard
                O:RefreshCurrentSection()
            end)
            updateBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 70, -4)
        end
        local entries = groups[label]
        if #entries == 0 then
            local noneFs = GreyFS(card, "Nothing yet today.", 13)
            noneFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            card.cy = card.cy + 24
        end
        for i, entry in ipairs(entries) do
            local color = LOG_CATEGORY_COLOR[entry.category] or Brand.BODY_TEXT_COLOR
            local textFs = card:CreateFontString(nil, "OVERLAY")
            textFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            textFs:SetTextColor(color[1], color[2], color[3])
            textFs:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -card.cy)
            textFs:SetWidth(W - 130)
            textFs:SetJustifyH("LEFT")
            textFs:SetWordWrap(true)
            textFs:SetText(entry.text)

            local timeFs = card:CreateFontString(nil, "OVERLAY")
            timeFs:SetFont(Brand.BODY_FONT_PATH, 12, "")
            timeFs:SetTextColor(0.45, 0.45, 0.45)
            timeFs:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -card.cy)
            timeFs:SetJustifyH("RIGHT")
            timeFs:SetText(LogTimeText(entry.time))

            local rowHeight = math.max(textFs:GetStringHeight(), 14) + 10
            card.cy = card.cy + rowHeight
            if i < #entries then
                Brand.DrawDivider(card, 14, card.cy - 4, W - 28)
            end
        end
        y = FinishCard(card, y)
    end
    body:SetHeight(math.max(viewportHeight, y))

    local bar = GetOrCreateSectionScrollbar()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -LOG_TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()

    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    local maxScroll = math.max(0, y - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)

    if maxScroll <= 0 then
        bar:Hide()
    else
        local ratio = viewportHeight / y
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * ratio))
    end

    local footer = content:CreateFontString(nil, "OVERLAY")
    footer:SetFont(Brand.BODY_FONT_PATH, 12, "")
    footer:SetTextColor(0.5, 0.5, 0.5)
    footer:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 4, 8)
    footer:SetText("Total Entries: " .. #R:GetLog(guild))
end

-- ── Mains / Alts ─────────────────────────────────────────────────────
-- Where mains/alts actually get assigned/linked ("it's not just listing
-- them" - the Roster page's own Player Alts list is read-only, this is the
-- real management page). The underlying data model (R:ConfirmMain,
-- R:ConvertToAlt, R:UnlinkAlt, R:GetMains, R:GetAltCandidates, R:GetAlts)
-- already existed from an earlier pass - this just builds the page.
-- Which mains currently have their alt list dropped open - session-only,
-- same pattern as showAllUnreviewed/showAllRankChanges elsewhere in this
-- file. Collapsed by default (2026-09-22: "it shouldn't be a list of the
-- alts... if you click that, the list will drop down").
local expandedAlts = {}

local function BuildMainsAlts(content)
    local guild = R:GetCurrentGuild()

    local header = Brand.FS(content, "Mains / Alts", Brand.TITLE_FONT_PATH, 22, "OUTLINE",
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    if not guild then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.85, 0.85, 0.85)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("Log in with your guild character to sync your roster first.")
        return
    end

    local MA_TOP = 46
    local MA_BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - MA_TOP - MA_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -MA_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    -- One slim card per main: star, name, the "N alts" toggle and the + Alt
    -- list on the first line, and (when dropped open) the alts running side
    -- by side underneath, wrapping to more lines. Click an alt's name for a
    -- small pop-down with Unlink.
    local W = CONTENT_W - 4
    local y = 6
    local mains = R:GetMains(guild)
    for _, main in ipairs(mains) do
        local card = CreateFrame("Frame", nil, body)
        card:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        card:SetWidth(W)
        Brand.ApplyCardBackground(card)
        Brand.DrawBorder(card, 0)
        local cy = 5

        -- Locked spec (2026-09-22): no "Confirm as Main"/"(confirmed)"
        -- text at all - a small gold star to the left of the name is the
        -- only main-status indicator. Becoming a Main happens via
        -- right-click on the name -> "Set as Main", not a visible button.
        local star = card:CreateFontString(nil, "OVERLAY")
        star:SetFont(Brand.BODY_FONT_PATH, 13, "")
        star:SetTextColor(Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
        star:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -(cy + 5))
        star:SetText(main.confirmedMain and "*" or "")

        local nameBtn = CreateFrame("Button", nil, card)
        nameBtn:SetHeight(18)
        local nameFs = nameBtn:CreateFontString(nil, "OVERLAY")
        nameFs:SetFont(Brand.BODY_FONT_PATH, 15, "")
        if R:IsGuildMasterFamily(guild, main.charName) then
            nameFs:SetTextColor(1, 0.2, 0.2)
        elseif main.isOfficer then
            nameFs:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
        else
            nameFs:SetTextColor(0.2, 1, 0.2)
        end
        nameFs:SetPoint("LEFT", 0, 0)
        nameFs:SetText(main.charName)
        nameBtn:SetWidth(nameFs:GetStringWidth())
        nameBtn:SetPoint("TOPLEFT", star, "TOPRIGHT", 4, 0)
        nameBtn:RegisterForClicks("RightButtonUp")
        if not main.confirmedMain then
            nameBtn:SetScript("OnClick", function(self)
                Brand.ShowContextMenu(self, { {
                    text = "Set as Main",
                    onClick = function()
                        R:ConfirmMain(guild, main.charName)
                        O:RefreshCurrentSection()
                    end,
                } })
            end)
        end

        local alts = R:GetAlts(guild, main.charName)
        local prevWidget = nameBtn
        if main.confirmedMain then
            if #alts > 0 then
                local toggle = CreateFrame("Button", nil, card)
                toggle:SetHeight(18)
                local toggleFs = toggle:CreateFontString(nil, "OVERLAY")
                toggleFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
                toggleFs:SetTextColor(0.8, 0.8, 0.8)
                toggleFs:SetPoint("LEFT", 0, 0)
                toggleFs:SetText((expandedAlts[main.charName] and "v " or "> ") .. #alts .. " alt" .. (#alts == 1 and "" or "s"))
                toggle:SetWidth(toggleFs:GetStringWidth())
                toggle:SetPoint("LEFT", prevWidget, "RIGHT", 10, 0)
                toggle:SetScript("OnClick", function()
                    expandedAlts[main.charName] = not expandedAlts[main.charName]
                    O:RefreshCurrentSection()
                end)
                prevWidget = toggle
            end

            -- Our own brand-styled dropdown (searchable list, wider than
            -- its small button) of everyone who can become this main's alt
            -- (see R:GetAltCandidates).
            local candidates = R:GetAltCandidates(guild, main.charName)
            if #candidates > 0 then
                local addAltDropdown = Brand.MakeDropdown(card, 70, { searchable = true, listWidth = 180 })
                addAltDropdown:SetPoint("LEFT", prevWidget, "RIGHT", 10, 0)
                addAltDropdown.label:SetText("+ Alt")
                local altOptions = {}
                for _, candidate in ipairs(candidates) do
                    table.insert(altOptions, { key = candidate.charName, name = candidate.charName })
                end
                addAltDropdown:SetOptions(altOptions)
                addAltDropdown.OnSelect = function(charName)
                    R:ConvertToAlt(guild, charName, main.charName)
                    O:RefreshCurrentSection()
                end
            end
        end
        cy = cy + 26

        if main.confirmedMain and expandedAlts[main.charName] and #alts > 0 then
            local ax, ay = 26, cy + 1
            for _, alt in ipairs(alts) do
                local chip = CreateFrame("Button", nil, card)
                chip:SetHeight(18)
                local chipFs = chip:CreateFontString(nil, "OVERLAY")
                chipFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
                chipFs:SetTextColor(0.54, 0.54, 0.63)
                chipFs:SetPoint("LEFT", 0, 0)
                chipFs:SetText(alt.charName)
                local chipW = chipFs:GetStringWidth()
                chip:SetWidth(chipW)
                if ax + chipW > W - 16 then
                    ax = 26
                    ay = ay + 20
                end
                chip:SetPoint("TOPLEFT", card, "TOPLEFT", ax, -ay)
                ax = ax + chipW + 16
                chip:SetScript("OnEnter", function() chipFs:SetTextColor(0.2, 1, 0.2) end)
                chip:SetScript("OnLeave", function() chipFs:SetTextColor(0.54, 0.54, 0.63) end)
                chip:SetScript("OnClick", function(self)
                    Brand.ShowContextMenu(self, { {
                        text = "Unlink",
                        onClick = function()
                            R:UnlinkAlt(guild, alt.charName)
                            O:RefreshCurrentSection()
                        end,
                    } })
                end)
            end
            cy = ay + 22
        end

        card:SetHeight(cy + 4)
        y = y + cy + 4 + 6
    end
    body:SetHeight(math.max(viewportHeight, y))

    local bar = GetOrCreateSectionScrollbar()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -MA_TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()

    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    local maxScroll = math.max(0, y - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)

    if maxScroll <= 0 then
        bar:Hide()
    else
        local ratio = viewportHeight / y
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * ratio))
    end
end

-- ── Recruitment ──────────────────────────────────────────────────────
-- Recruitment expands in the sidebar into Search, Ads and Stats (the real
-- mechanics live in Recruitment.lua, which does it the way GRIP does).
-- Search has its own Settings view, opened by the Settings link on its
-- header.
local recruitSettingsView = false

-- This addon's secondary text grey (#8a8a9a) - there is no white text on
-- the Search page.
local GREY = { 0.541, 0.541, 0.604 }
local INTER_SEMIBOLD = "Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Inter-SemiBold.ttf"

function GreyFS(parent, text, size)
    return Brand.FS(parent, text, Brand.BODY_FONT_PATH, size or 13, "", GREY[1], GREY[2], GREY[3])
end

function AccentFS(parent, text, size)
    return Brand.FS(parent, text, INTER_SEMIBOLD, size or 13, "", Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
end

local function SetLinkText(btn, text)
    btn.label:SetText(text)
    btn:SetWidth(math.max(40, btn.label:GetStringWidth() + 8))
end

local function RecSay(msg)
    print("|cff681417Roster Roundup:|r " .. msg)
end

-- A card: the lighter fill with the thin border (Brand.ApplyCardBackground
-- + Brand.DrawBorder, the same pair Reins and Armoire use). card.cy is the
-- running y position inside the card for whatever gets added next.
function NewCard(body, y, width, title)
    local card = CreateFrame("Frame", nil, body)
    card:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    card:SetWidth(width)
    Brand.ApplyCardBackground(card)
    Brand.DrawBorder(card, 0)
    card.cy = 10
    if title then
        local t = AccentFS(card, title, 14)
        t:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
        Brand.DrawDivider(card, 10, 30, width - 20)
        card.cy = 40
    end
    return card
end

-- Sizes the card to what was put in it and returns the y below it.
function FinishCard(card, y)
    card:SetHeight(card.cy + 10)
    return y + card.cy + 10 + 10
end

-- ── One-row-at-a-time lists ──────────────────────────────────────────
-- Each list card shows ONE row; the mouse wheel steps through the rest,
-- like the quest list in Quest Compass. The row you were on is remembered
-- across the page redrawing itself.
local ROW_H = 27
local rowIndex = { scan = 1, sent = 1, blacklist = 1, ads = 1 }

local function MakeRowScroller(card, key, x, y, width, items, buildRow, onRightClick, emptyText)
    local viewport = CreateFrame("Frame", nil, card)
    viewport:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
    viewport:SetSize(width, ROW_H)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)

    local rowFrame = CreateFrame("Frame", nil, viewport)
    rowFrame:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    rowFrame:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -8, 0)

    local emptyFs = GreyFS(viewport, emptyText or "", 13)
    emptyFs:SetPoint("LEFT", viewport, "LEFT", 6, 0)

    local track = viewport:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(0.5, 0.5, 0.6, 0.15)
    track:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", 0, 0)
    track:SetSize(4, ROW_H)

    local thumb = viewport:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    thumb:SetWidth(4)

    local function Show()
        local n = #items
        if n == 0 then
            rowFrame:Hide()
            emptyFs:Show()
            track:Hide()
            thumb:Hide()
            return
        end
        emptyFs:Hide()
        rowFrame:Show()
        rowIndex[key] = math.max(1, math.min(rowIndex[key], n))
        buildRow(rowFrame, items[rowIndex[key]])
        if n > 1 then
            local h = math.max(6, ROW_H / n)
            thumb:SetHeight(h)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", 0, -((rowIndex[key] - 1) / (n - 1)) * (ROW_H - h))
            track:Show()
            thumb:Show()
        else
            track:Hide()
            thumb:Hide()
        end
    end

    viewport:SetScript("OnMouseWheel", function(_, delta)
        rowIndex[key] = rowIndex[key] - delta
        Show()
    end)
    if onRightClick then
        viewport:SetScript("OnMouseUp", function(self, button)
            local item = items[rowIndex[key]]
            if button == "RightButton" and item then onRightClick(item, self) end
        end)
    end
    Show()
    return viewport
end

-- Column layout shared by the Scan and Recruit Next cards: [heading, share
-- of the row's width].
local CAND_COLS = {
    { "Name", 0.22 }, { "Lvl", 0.07 }, { "Class", 0.15 }, { "Race", 0.15 },
    { "Zone", 0.23 }, { "M+", 0.06 }, { "W", 0.06 }, { "I", 0.06 },
}
local ROW_BAR_W = 3

local function ColX(width, colIndex)
    local usable = width - 14
    local x = ROW_BAR_W + 6
    for i = 1, colIndex - 1 do x = x + usable * CAND_COLS[i][2] end
    return x
end

local function AddColumnHeaders(card, x, y, width)
    for i, col in ipairs(CAND_COLS) do
        local fs = AccentFS(card, col[1], 11)
        fs:SetPoint("TOPLEFT", card, "TOPLEFT", x + ColX(width, i), -y)
    end
end

local function ClassColor(c)
    local color = c.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.classFile]
    if color then return color.r, color.g, color.b end
    return GREY[1], GREY[2], GREY[3]
end

local function MakeCandidateRowBuilder(width, showStatus)
    return function(rowFrame, c)
        if not rowFrame.cells then
            rowFrame.bar = rowFrame:CreateTexture(nil, "ARTWORK")
            rowFrame.bar:SetWidth(ROW_BAR_W)
            rowFrame.bar:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 0, 0)
            rowFrame.bar:SetPoint("BOTTOMLEFT", rowFrame, "BOTTOMLEFT", 0, 0)
            rowFrame.cells = {}
            for i, col in ipairs(CAND_COLS) do
                local fs = GreyFS(rowFrame, "", 13)
                fs:SetPoint("LEFT", rowFrame, "LEFT", ColX(width, i), 0)
                fs:SetWidth((width - 14) * col[2] - 4)
                fs:SetWordWrap(false)
                rowFrame.cells[i] = fs
            end
        end
        local r, g, b = ClassColor(c)
        rowFrame.bar:SetColorTexture(r, g, b, 1)
        local cells = rowFrame.cells
        cells[1]:SetText(c.charName or "")
        cells[1]:SetTextColor(r, g, b)
        cells[2]:SetText(tostring(c.level or ""))
        cells[3]:SetText(c.classStr or "")
        cells[4]:SetText(c.race or "")
        cells[5]:SetText(c.area or "")
        cells[6]:SetText(c.rio and tostring(math.floor(c.rio)) or "-")
        cells[7]:SetText(showStatus and (c.whisperSent and "Y" or "-") or "")
        cells[8]:SetText(showStatus and (c.inviteSent and "Y" or "-") or "")
    end
end

-- ── Small popup with one text box (blacklist Add / Import / Export) ───
local textPopup

function ShowTextPopup(opts)
    if not textPopup then
        local f = CreateFrame("Frame", "XRRTextPopup", UIParent)
        f:SetSize(480, 150)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetClampedToScreen(true)
        table.insert(UISpecialFrames, "XRRTextPopup")
        Brand.ApplyBackground(f)
        Brand.DrawBorder(f, 1)

        f.caption = Brand.FS(f, "", Brand.TITLE_FONT_PATH, 15, nil, Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
        f.caption:SetPoint("TOP", f, "TOP", 0, -Brand.SAFE_MARGIN)

        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetHeight(22)
        box:SetPoint("TOPLEFT", f, "TOPLEFT", Brand.SAFE_MARGIN + 10, -46)
        box:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Brand.SAFE_MARGIN, -46)
        box:SetAutoFocus(false)
        box:SetMaxLetters(0)
        box:SetFontObject("GameFontHighlightSmall")
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        -- A read-only box (Export) puts its text straight back if edited.
        box:SetScript("OnTextChanged", function(self)
            if f.readOnly and not self.locked then
                self.locked = true
                self:SetText(f.lockedText or "")
                self:HighlightText()
                self.locked = false
            end
        end)
        f.box = box

        f.hint = GreyFS(f, "", 11)
        f.hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -6)
        f.hint:SetWidth(430)
        f.hint:SetJustifyH("LEFT")

        f.primary = Brand.MakeTextLink(f, "OK", function()
            if f.onPrimary then
                local ok, message = f.onPrimary(box:GetText())
                if message then f.hint:SetText(message) end
                if ok then f:Hide() end
            else
                f:Hide()
            end
        end)
        f.primary:SetPoint("BOTTOM", f, "BOTTOM", -40, Brand.SAFE_MARGIN)
        f.cancel = Brand.MakeTextLink(f, "Cancel", function() f:Hide() end)
        f.cancel:SetPoint("BOTTOM", f, "BOTTOM", 40, Brand.SAFE_MARGIN)
        textPopup = f
    end

    textPopup.readOnly = opts.readOnly
    textPopup.lockedText = opts.text
    textPopup.onPrimary = opts.onPrimary
    textPopup.caption:SetText(opts.caption or "")
    textPopup.hint:SetText(opts.hint or "")
    SetLinkText(textPopup.primary, opts.primary or "OK")
    textPopup.cancel:SetShown(not opts.readOnly)
    textPopup.box.locked = true
    textPopup.box:SetText(opts.text or "")
    textPopup.box.locked = false
    textPopup:Show()
    textPopup.box:SetFocus()
    if opts.readOnly then textPopup.box:HighlightText() end
end

local function BlacklistReasonText(entry)
    local reason = (entry.reason and entry.reason ~= "") and entry.reason or "no reason given"
    if not entry.expires then return reason end
    local left = entry.expires - time()
    local when
    if left >= 86400 then
        when = math.ceil(left / 86400) .. "d left"
    else
        when = math.max(1, math.ceil(left / 3600)) .. "h left"
    end
    return reason .. " - " .. when
end

-- ── Search page ─────────────────────────────────────────────────────
local function BuildRecruitSearch(body, width)
    local Rec = XRR.Recruitment
    local db = Rec:GetDB()
    local y = 14

    -- Stats box: just a thin border, no fill (cards are the filled things).
    local perm, temp = Rec:GetBlacklistCounts()
    local done, total = Rec:GetScanProgress()
    local box = CreateFrame("Frame", nil, body)
    box:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    box:SetSize(width, 54)
    Brand.DrawBorder(box, 0)
    local line1 = GreyFS(box, string.format("Candidates: %d  |  Blacklist: perm %d, temp %d",
        #Rec:GetCandidates(), perm, temp), 13)
    line1:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
    local capText = db.dailyWhisperCap > 0 and ("%d/%d"):format(Rec:GetDailyWhisperCount(), db.dailyWhisperCap)
        or tostring(Rec:GetDailyWhisperCount())
    local line2 = GreyFS(box, string.format("Scan: %d/%d  |  Whisper: %s  |  Daily: %s",
        done, total, db.whisperEnabled and "on" or "off", capText), 13)
    line2:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -29)
    y = y + 54 + 6

    local clearBtn = Brand.MakeTextLink(body, "Clear", function()
        Rec:ClearCandidates()
        O:RefreshCurrentSection()
    end)
    clearBtn:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -y)
    y = y + 24

    -- Scan card -----------------------------------------------------------
    local scanCard = NewCard(body, y, width, nil)
    local candidates = Rec:GetCandidates()

    local scanBtn
    local function ScanLabel()
        local cd = Rec:GetScanCooldown()
        return cd > 0 and ("Scan (" .. cd .. "s)") or "Scan"
    end
    scanBtn = Brand.MakeTextLink(scanCard, ScanLabel(), function()
        Rec:Scan()
        O:RefreshCurrentSection()
    end)
    scanBtn.label:SetFont(INTER_SEMIBOLD, 13, "")
    SetLinkText(scanBtn, ScanLabel())
    scanBtn:SetPoint("TOPLEFT", scanCard, "TOPLEFT", 6, -6)
    local progressFs = GreyFS(scanCard, ("%d/%d"):format(done, total), 13)
    progressFs:SetPoint("LEFT", scanBtn, "RIGHT", 14, 0)
    local countFs = GreyFS(scanCard, ("%d %s"):format(#candidates, #candidates == 1 and "Candidate" or "Candidates"), 13)
    countFs:SetPoint("LEFT", progressFs, "RIGHT", 18, 0)
    Brand.DrawDivider(scanCard, 10, 32, width - 20)

    -- Live countdown on the link; redraws the page the moment it's ready.
    if Rec:GetScanCooldown() > 0 then
        local ticker
        ticker = C_Timer.NewTicker(1, function()
            if not scanBtn:IsVisible() then ticker:Cancel() return end
            local cd = Rec:GetScanCooldown()
            if cd <= 0 then
                ticker:Cancel()
                O:RefreshCurrentSection()
                return
            end
            SetLinkText(scanBtn, ScanLabel())
        end)
    end

    AddColumnHeaders(scanCard, 10, 38, width - 20)
    MakeRowScroller(scanCard, "scan", 10, 56, width - 20, candidates, MakeCandidateRowBuilder(width - 20, false),
        function(c, anchor)
            Brand.ShowContextMenu(anchor, {
                { text = "Recruit", onClick = function()
                    local ok, reason = Rec:RecruitCandidate(c.charName)
                    if not ok and reason then RecSay("Couldn't recruit " .. c.charName .. ": " .. reason .. ".") end
                    O:RefreshCurrentSection()
                end },
                { text = "Whisper only", onClick = function()
                    local ok, reason = Rec:RecruitCandidate(c.charName, "whisper")
                    if not ok and reason then RecSay("Couldn't whisper " .. c.charName .. ": " .. reason .. ".") end
                    O:RefreshCurrentSection()
                end },
                { text = "Invite only", onClick = function()
                    local ok, reason = Rec:RecruitCandidate(c.charName, "invite")
                    if not ok and reason then RecSay("Couldn't invite " .. c.charName .. ": " .. reason .. ".") end
                    O:RefreshCurrentSection()
                end },
                { text = "Blacklist", onClick = function()
                    Rec:AddToBlacklist(c.charName, "manual")
                    O:RefreshCurrentSection()
                end },
                { text = "Remove from list", onClick = function()
                    Rec:RemoveCandidate(c.charName)
                    O:RefreshCurrentSection()
                end },
            })
        end, "No candidates yet. Click Scan to begin.")
    scanCard.cy = 56 + ROW_H
    y = FinishCard(scanCard, y)

    -- Recruit Next card ---------------------------------------------------
    local sent = Rec:GetSent()
    local nextCard = NewCard(body, y, width, nil)
    local nextBtn = Brand.MakeTextLink(nextCard, "Recruit Next", function()
        local ok, reason = Rec:RecruitNext()
        if not ok and reason and reason ~= "no candidates" then RecSay("Couldn't recruit: " .. reason .. ".") end
        O:RefreshCurrentSection()
    end)
    nextBtn.label:SetFont(INTER_SEMIBOLD, 13, "")
    SetLinkText(nextBtn, "Recruit Next")
    nextBtn:SetPoint("TOPLEFT", nextCard, "TOPLEFT", 6, -6)
    local replied = 0
    for _, e in ipairs(sent) do
        if e.reply then replied = replied + 1 end
    end
    local sentFs = GreyFS(nextCard, ("%d Sent"):format(#sent), 13)
    sentFs:SetPoint("LEFT", nextBtn, "RIGHT", 14, 0)
    if replied > 0 then
        local repliedFs = GreyFS(nextCard, ("%d Replied"):format(replied), 13)
        repliedFs:SetPoint("LEFT", sentFs, "RIGHT", 18, 0)
    end
    Brand.DrawDivider(nextCard, 10, 32, width - 20)
    AddColumnHeaders(nextCard, 10, 38, width - 20)
    -- The reply (if any) from whoever's row is showing, right under it.
    local replyFs = Brand.FS(nextCard, "", Brand.BODY_FONT_PATH, 13, "", 0.2, 0.9, 0.3)
    replyFs:SetPoint("TOPLEFT", nextCard, "TOPLEFT", 16, -(56 + ROW_H + 4))
    replyFs:SetWidth(width - 40)
    replyFs:SetJustifyH("LEFT")
    replyFs:SetWordWrap(true)
    local buildSentRow = MakeCandidateRowBuilder(width - 20, true)
    MakeRowScroller(nextCard, "sent", 10, 56, width - 20, sent, function(rowFrame, entry)
        buildSentRow(rowFrame, entry)
        replyFs:SetText(entry.reply and ("Reply: " .. entry.reply) or "")
    end, function(entry, anchor)
        Brand.ShowContextMenu(anchor, {
            { text = "Re-whisper", onClick = function()
                local ok, reason = Rec:Rewhisper(entry.charName)
                if not ok and reason then RecSay("Couldn't whisper " .. entry.charName .. ": " .. reason .. ".") end
                O:RefreshCurrentSection()
            end },
            { text = "Blacklist", onClick = function()
                Rec:BlacklistSent(entry.charName)
                O:RefreshCurrentSection()
            end },
            { text = "Remove from card", onClick = function()
                Rec:RemoveFromSent(entry.charName)
                O:RefreshCurrentSection()
            end },
        })
    end, "Nobody yet. Recruit Next whispers and invites the next candidate from Scan.")
    if #sent == 0 then replyFs:SetText("") end
    nextCard.cy = 56 + ROW_H + 4 + 34
    y = FinishCard(nextCard, y)

    -- Blacklist card ------------------------------------------------------
    local blCard = NewCard(body, y, width, nil)
    local blTitle = AccentFS(blCard, "Blacklist", 13)
    blTitle:SetPoint("TOPLEFT", blCard, "TOPLEFT", 10, -10)
    local blCounts = GreyFS(blCard, ("perm %d, temp %d"):format(perm, temp), 13)
    blCounts:SetPoint("LEFT", blTitle, "RIGHT", 14, 0)

    local exportBtn = Brand.MakeTextLink(blCard, "Export", function()
        ShowTextPopup({
            caption = "Export blacklist", readOnly = true, text = Rec:ExportBlacklist(),
            hint = "Ctrl+C to copy, then paste it to a friend or into another character's Import.",
            primary = "Close",
        })
    end)
    exportBtn:SetPoint("TOPRIGHT", blCard, "TOPRIGHT", -6, -4)
    local importBtn = Brand.MakeTextLink(blCard, "Import", function()
        ShowTextPopup({
            caption = "Import blacklist", text = "", primary = "Import",
            hint = "Paste a blacklist export here (it starts with !XRR:BL:1:).",
            onPrimary = function(text)
                local added, why = Rec:ImportBlacklist(text)
                if not added then return false, why end
                O:RefreshCurrentSection()
                return true
            end,
        })
    end)
    importBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
    local addBtn = Brand.MakeTextLink(blCard, "Add", function()
        ShowTextPopup({
            caption = "Add to blacklist", text = "", primary = "Add",
            hint = "Type a character name. They'll never be contacted again until you remove them.",
            onPrimary = function(text)
                text = text:gsub("^%s+", ""):gsub("%s+$", "")
                if text == "" then return false, "Type a name first." end
                Rec:AddToBlacklist(text, "manual")
                O:RefreshCurrentSection()
                return true
            end,
        })
    end)
    addBtn:SetPoint("RIGHT", importBtn, "LEFT", -6, 0)
    Brand.DrawDivider(blCard, 10, 32, width - 20)

    local entries = Rec:GetBlacklist()
    MakeRowScroller(blCard, "blacklist", 10, 40, width - 20, entries, function(rowFrame, entry)
        if not rowFrame.nameFs then
            rowFrame.nameFs = GreyFS(rowFrame, "", 13)
            rowFrame.nameFs:SetPoint("LEFT", rowFrame, "LEFT", 6, 0)
            rowFrame.reasonFs = GreyFS(rowFrame, "", 13)
            rowFrame.reasonFs:SetPoint("RIGHT", rowFrame, "RIGHT", -6, 0)
            rowFrame.reasonFs:SetJustifyH("RIGHT")
        end
        rowFrame.nameFs:SetText(entry.charName)
        rowFrame.reasonFs:SetText(BlacklistReasonText(entry))
    end, function(entry, anchor)
        local items = {}
        if entry.expires then
            table.insert(items, { text = "Make permanent", onClick = function()
                Rec:BlacklistPermanent(entry.charName, entry.reason)
                O:RefreshCurrentSection()
            end })
        end
        table.insert(items, { text = "Remove from blacklist", onClick = function()
            Rec:RemoveFromBlacklist(entry.charName)
            O:RefreshCurrentSection()
        end })
        Brand.ShowContextMenu(anchor, items)
    end, "Blacklist is empty.")
    blCard.cy = 40 + ROW_H
    y = FinishCard(blCard, y)

    return y
end

-- ── Search Settings ─────────────────────────────────────────────────
-- One card per setting group, all of it about the Search page: how the
-- scan runs and who it finds, the whisper messages, Recruit Next, and the
-- blacklist.
local whisperEditIndex = 1

local function NumberBox(parent, w, value, onChange)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, 20)
    box:SetNumeric(true)
    box:SetAutoFocus(false)
    box:SetText(tostring(value or 0))
    box:SetScript("OnEnterPressed", function(self)
        onChange(tonumber(self:GetText()))
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self) onChange(tonumber(self:GetText())) end)
    return box
end

local function CheckRow(parent, x, y, label, checked, onToggle, r, g, b)
    local cb = Brand.MakeCheckbox(parent, 18)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    cb:SetChecked(checked)
    cb.OnToggle = function(self) onToggle(self:GetChecked()) end
    local fs = Brand.FS(parent, label, Brand.BODY_FONT_PATH, 13, "", r or GREY[1], g or GREY[2], b or GREY[3])
    fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    return cb, fs
end

-- Grey wrapped note; returns its height.
local function Note(card, text, y, width)
    local fs = GreyFS(card, text, 12)
    fs:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -y)
    fs:SetWidth(width - 20)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs:GetStringHeight()
end

-- A grid of checkboxes, `cols` per row; returns the y below it.
local function CheckGrid(card, y, width, items, cols, isChecked, onToggle)
    local colW = (width - 20) / cols
    for i, item in ipairs(items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        CheckRow(card, 10 + col * colW, y + row * 24, item.name, isChecked(item.name),
            function(on) onToggle(item.name, on) end, item.r, item.g, item.b)
    end
    return y + math.ceil(#items / cols) * 24
end

local function BuildRecruitSearchSettings(body, width)
    local Rec = XRR.Recruitment
    local db = Rec:GetDB()
    local y = 14

    -- Scan Levels ---------------------------------------------------------
    local card = NewCard(body, y, width, "Scan Levels")
    local minBox = NumberBox(card, 50, db.scanMin, function() end)
    minBox:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -card.cy)
    local toFs = GreyFS(card, "to", 13)
    toFs:SetPoint("LEFT", minBox, "RIGHT", 8, 0)
    local maxBox = NumberBox(card, 50, db.scanMax, function() end)
    maxBox:SetPoint("LEFT", toFs, "RIGHT", 8, 0)
    local stepLbl = GreyFS(card, "in bands of", 13)
    stepLbl:SetPoint("LEFT", maxBox, "RIGHT", 16, 0)
    local stepBox = NumberBox(card, 40, db.scanStep, function() end)
    stepBox:SetPoint("LEFT", stepLbl, "RIGHT", 8, 0)
    local applyBtn = Brand.MakeTextLink(card, "Apply", function()
        db.scanMin = math.max(1, tonumber(minBox:GetText()) or db.scanMin)
        db.scanMax = math.max(db.scanMin, tonumber(maxBox:GetText()) or db.scanMax)
        db.scanStep = math.max(1, tonumber(stepBox:GetText()) or db.scanStep)
        Rec:ClearCandidates()
    end)
    applyBtn:SetPoint("LEFT", stepBox, "RIGHT", 16, 0)
    card.cy = card.cy + 30

    local waitLbl = GreyFS(card, "Wait between scans", 13)
    waitLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy - 3)
    local waitBox = NumberBox(card, 50, db.scanWait, function(n)
        db.scanWait = math.max(3, math.min(60, n or db.scanWait))
    end)
    waitBox:SetPoint("LEFT", waitLbl, "RIGHT", 10, 0)
    local waitUnit = GreyFS(card, "seconds (3 to 60)", 13)
    waitUnit:SetPoint("LEFT", waitBox, "RIGHT", 8, 0)
    card.cy = card.cy + 30

    CheckRow(card, 10, card.cy, "After the first pass, also sweep each class across the whole range",
        db.classSweep ~= false, function(on) db.classSweep = on end)
    card.cy = card.cy + 28

    card.cy = card.cy + Note(card,
        "Scan asks for this many levels at a time, starting from the low end. A search that comes back full (the game cuts results off at about 50) is split into smaller ones: first by class, then by race, then by zone, so nobody is cut off.",
        card.cy, width) + 4
    y = FinishCard(card, y)

    -- Current Zone ---------------------------------------------------------
    card = NewCard(body, y, width, "Current Zone")
    CheckRow(card, 10, card.cy, "Include current zone in the scan", db.includeCurrentZone,
        function(on) db.includeCurrentZone = on end)
    card.cy = card.cy + 24
    y = FinishCard(card, y)

    -- Zone filter -----------------------------------------------------------
    card = NewCard(body, y, width, "Zone Filter")
    local zoneBox = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
    zoneBox:SetHeight(20)
    zoneBox:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -card.cy)
    zoneBox:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -card.cy)
    zoneBox:SetAutoFocus(false)
    zoneBox:SetMaxLetters(0)
    zoneBox:SetText(db.filterZones or "")
    zoneBox:SetScript("OnEnterPressed", function(self)
        db.filterZones = self:GetText()
        self:ClearFocus()
    end)
    zoneBox:SetScript("OnEditFocusLost", function(self) db.filterZones = self:GetText() end)
    card.cy = card.cy + 28
    card.cy = card.cy + Note(card,
        "Only keep candidates found in these zones - type the zone names separated by commas, spelled the way the game shows them. Leave empty for every zone.",
        card.cy, width) + 4
    y = FinishCard(card, y)

    -- Race filter ---------------------------------------------------------------
    card = NewCard(body, y, width, "Race Filter")
    local races = {}
    for _, name in ipairs(Rec:GetRaceNames()) do table.insert(races, { name = name }) end
    card.cy = CheckGrid(card, card.cy, width, races, 4,
        function(name) return db.filterRaces[name] == true end,
        function(name, on) db.filterRaces[name] = on or nil end)
    card.cy = card.cy + 4 + Note(card, "Only keep these races. Leave all unchecked for every race.", card.cy + 4, width)
    y = FinishCard(card, y)

    -- Class filter --------------------------------------------------------------
    card = NewCard(body, y, width, "Class Filter")
    local classes = {}
    for _, cls in ipairs(Rec:GetClassNames()) do
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls.file]
        table.insert(classes, { name = cls.name, r = color and color.r, g = color and color.g, b = color and color.b })
    end
    card.cy = CheckGrid(card, card.cy, width, classes, 4,
        function(name) return db.filterClasses[name] == true end,
        function(name, on) db.filterClasses[name] = on or nil end)
    card.cy = card.cy + 4 + Note(card, "Only keep these classes. Leave all unchecked for every class.", card.cy + 4, width)
    y = FinishCard(card, y)

    -- Raider.IO -------------------------------------------------------------------
    card = NewCard(body, y, width, "Raider.IO Minimum")
    local rioLbl = GreyFS(card, "Minimum M+ score", 13)
    rioLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy - 3)
    local rioBox = NumberBox(card, 60, db.rioMinScore, function(n) db.rioMinScore = n or 0 end)
    rioBox:SetPoint("LEFT", rioLbl, "RIGHT", 10, 0)
    card.cy = card.cy + 28
    card.cy = card.cy + Note(card,
        Rec:IsRaiderIOAvailable()
            and "Skips candidates whose Raider.IO M+ score is below this. Candidates with no score are kept. 0 turns it off."
            or "Needs the Raider.IO addon, which isn't installed. 0 turns it off.",
        card.cy, width) + 4
    y = FinishCard(card, y)

    -- Whisper messages ----------------------------------------------------------------
    card = NewCard(body, y, width, "Whisper Messages")
    local templates = db.whisperTemplates
    if #templates == 0 then templates[1] = "" end
    whisperEditIndex = math.max(1, math.min(whisperEditIndex, #templates))

    local posFs = GreyFS(card, ("Message %d of %d"):format(whisperEditIndex, #templates), 13)
    posFs:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    local prevBtn = Brand.MakeTextLink(card, "Previous", function()
        whisperEditIndex = whisperEditIndex - 1
        if whisperEditIndex < 1 then whisperEditIndex = #templates end
        O:RefreshCurrentSection()
    end)
    prevBtn:SetPoint("LEFT", posFs, "RIGHT", 16, 0)
    local nextBtn = Brand.MakeTextLink(card, "Next", function()
        whisperEditIndex = whisperEditIndex + 1
        if whisperEditIndex > #templates then whisperEditIndex = 1 end
        O:RefreshCurrentSection()
    end)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
    local addMsgBtn = Brand.MakeTextLink(card, "Add", function()
        if #templates >= Rec.MAX_WHISPER_TEMPLATES then
            RecSay("That's the most whisper messages you can keep (" .. Rec.MAX_WHISPER_TEMPLATES .. ").")
            return
        end
        table.insert(templates, "")
        whisperEditIndex = #templates
        O:RefreshCurrentSection()
    end)
    addMsgBtn:SetPoint("LEFT", nextBtn, "RIGHT", 6, 0)
    local delBtn = Brand.MakeTextLink(card, "Delete", function()
        if #templates <= 1 then
            templates[1] = ""
        else
            table.remove(templates, whisperEditIndex)
            whisperEditIndex = math.max(1, math.min(whisperEditIndex, #templates))
        end
        O:RefreshCurrentSection()
    end)
    delBtn:SetPoint("LEFT", addMsgBtn, "RIGHT", 6, 0)
    card.cy = card.cy + 26

    -- A real multi-line box: the whole message shows at once, wraps at the
    -- edge, and a click anywhere in it puts the cursor right there. The
    -- bordered frame is the click target; the EditBox fills it.
    local MSG_BOX_H = 80
    local msgFrame = CreateFrame("Frame", nil, card)
    msgFrame:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    msgFrame:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -card.cy)
    msgFrame:SetHeight(MSG_BOX_H)
    msgFrame:EnableMouse(true)
    local msgBg = msgFrame:CreateTexture(nil, "BACKGROUND")
    msgBg:SetAllPoints()
    msgBg:SetColorTexture(Brand.BG[1], Brand.BG[2], Brand.BG[3], 1)
    Brand.DrawBorder(msgFrame, 0)

    local msgBox = CreateFrame("EditBox", nil, msgFrame)
    msgBox:SetPoint("TOPLEFT", msgFrame, "TOPLEFT", 6, -6)
    msgBox:SetPoint("BOTTOMRIGHT", msgFrame, "BOTTOMRIGHT", -6, 6)
    msgBox:SetMultiLine(true)
    msgBox:SetAutoFocus(false)
    msgBox:SetMaxLetters(0)
    msgBox:SetFont(Brand.BODY_FONT_PATH, 13, "")
    msgBox:SetTextColor(GREY[1], GREY[2], GREY[3])
    msgBox:SetJustifyH("LEFT")
    msgBox:SetText(templates[whisperEditIndex] or "")
    msgFrame:SetScript("OnMouseDown", function() msgBox:SetFocus() end)
    msgBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    card.cy = card.cy + MSG_BOX_H + 8

    local function InsertBtn(label, placeholder, anchor, gap)
        local btn = Brand.MakeTextLink(card, label, function()
            msgBox:Insert(placeholder)
            templates[whisperEditIndex] = msgBox:GetText()
        end)
        if anchor then
            btn:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
        else
            btn:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
        end
        return btn
    end
    local insLink = InsertBtn("Insert {guildlink}", "{guildlink}")
    local insGuild = InsertBtn("Insert {guild}", "{guild}", insLink, 10)
    InsertBtn("Insert {player}", "{player}", insGuild, 10)
    card.cy = card.cy + 26

    local countFs = GreyFS(card, "", 12)
    countFs:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    card.cy = card.cy + 20
    local previewFs = GreyFS(card, "", 12)
    previewFs:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    previewFs:SetWidth(width - 20)
    previewFs:SetJustifyH("LEFT")
    previewFs:SetWordWrap(true)
    local PREVIEW_H = 44
    card.cy = card.cy + PREVIEW_H

    local function UpdateMeasure()
        local bytes, filled = Rec:MeasureTemplate(msgBox:GetText())
        countFs:SetText(("%d / %d characters once filled in"):format(bytes, Rec.MAX_CHAT_BYTES))
        if bytes > Rec.MAX_CHAT_BYTES then
            countFs:SetTextColor(0.8, 0.25, 0.25)
        else
            countFs:SetTextColor(GREY[1], GREY[2], GREY[3])
        end
        previewFs:SetText("Preview: " .. filled)
    end
    msgBox:SetScript("OnTextChanged", function(self, userInput)
        -- A chat message can't hold line breaks: Enter just finishes typing.
        local text = self:GetText()
        if text:find("[\r\n]") then
            self:SetText((text:gsub("[\r\n]+", " ")))
            self:ClearFocus()
            return
        end
        if userInput then templates[whisperEditIndex] = text end
        UpdateMeasure()
    end)
    UpdateMeasure()

    local rotLbl = GreyFS(card, "Send them", 13)
    rotLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy - 5)
    local rotDD = Brand.MakeDropdown(card, 140)
    rotDD:SetPoint("LEFT", rotLbl, "RIGHT", 10, 0)
    rotDD:SetOptions({ { key = "sequential", name = "In order" }, { key = "random", name = "Random" } })
    rotDD:SetValue(db.whisperRotation)
    rotDD.OnSelect = function(key) db.whisperRotation = key end
    card.cy = card.cy + 36
    card.cy = card.cy + Note(card,
        "Up to " .. Rec.MAX_WHISPER_TEMPLATES .. " messages. Each recruit gets the next one so they don't all look the same. A message over " .. Rec.MAX_CHAT_BYTES .. " characters is cut off when sent.",
        card.cy, width) + 4
    y = FinishCard(card, y)

    -- Daily whisper cap ----------------------------------------------------------------------
    card = NewCard(body, y, width, "Daily Whisper Cap")
    local capBox = NumberBox(card, 60, db.dailyWhisperCap, function(n) db.dailyWhisperCap = n or db.dailyWhisperCap end)
    capBox:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -card.cy)
    local capLbl = GreyFS(card, "whispers a day (0 = no limit)", 13)
    capLbl:SetPoint("LEFT", capBox, "RIGHT", 10, 0)
    card.cy = card.cy + 28
    y = FinishCard(card, y)

    -- Recruit Next -------------------------------------------------------------------------------
    card = NewCard(body, y, width, "Recruit Next")
    CheckRow(card, 10, card.cy, "Send a whisper", db.whisperEnabled, function(on) db.whisperEnabled = on end)
    card.cy = card.cy + 24
    CheckRow(card, 10, card.cy, "Send a guild invite", db.inviteEnabled, function(on) db.inviteEnabled = on end)
    card.cy = card.cy + 24
    CheckRow(card, 10, card.cy, "Invite first, then whisper once the invite has gone through", db.inviteFirst,
        function(on) db.inviteFirst = on end)
    card.cy = card.cy + 24
    CheckRow(card, 10, card.cy, "Play a sound when someone you invited joins the guild", db.soundInviteAccepted,
        function(on) db.soundInviteAccepted = on end)
    card.cy = card.cy + 24
    CheckRow(card, 10, card.cy, "Play a sound when someone you recruited whispers back", db.soundReply,
        function(on) db.soundReply = on end)
    card.cy = card.cy + 24
    CheckRow(card, 10, card.cy, "Add Recruit options to the game's right-click menu on a player", db.unitMenu,
        function(on) db.unitMenu = on end)
    card.cy = card.cy + 28
    card.cy = card.cy + Note(card,
        "An invite that gets no answer in 70 seconds is blocked for 24 hours; after "
        .. "7 unanswered invites to the same person, they're blocked for the full temporary length. A declined invite takes them off the Recruit Next card.",
        card.cy, width) + 4
    y = FinishCard(card, y)

    -- Blacklist -----------------------------------------------------------------------------------
    card = NewCard(body, y, width, "Blacklist")
    local daysLbl = GreyFS(card, "Temporary block length", 13)
    daysLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy - 3)
    local daysBox = NumberBox(card, 50, db.blacklistDays, function(n)
        db.blacklistDays = math.max(1, math.min(365, n or db.blacklistDays))
    end)
    daysBox:SetPoint("LEFT", daysLbl, "RIGHT", 10, 0)
    local daysUnit = GreyFS(card, "days", 13)
    daysUnit:SetPoint("LEFT", daysBox, "RIGHT", 8, 0)
    card.cy = card.cy + 30
    CheckRow(card, 10, card.cy, "Watch replies for \"no thanks\" and block those people for good", db.optOutDetection,
        function(on) db.optOutDetection = on end)
    card.cy = card.cy + 28
    local langLbl = GreyFS(card, "Reply languages", 13)
    langLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    card.cy = card.cy + 22
    local langs = {}
    for _, lang in ipairs(Rec.OPT_OUT_LANGUAGES) do table.insert(langs, { name = lang.name, key = lang.key }) end
    local colW = (width - 20) / 4
    for i, lang in ipairs(langs) do
        CheckRow(card, 10 + (i - 1) * colW, card.cy, lang.name, db.optOutLanguages[lang.key] == true,
            function(on) db.optOutLanguages[lang.key] = on or nil end)
    end
    card.cy = card.cy + 28
    CheckRow(card, 10, card.cy, "Also treat rude replies (\"go away\" and the like) as no thanks", db.optOutAggressive,
        function(on) db.optOutAggressive = on end)
    card.cy = card.cy + 28

    -- The player's own phrases: any reply containing one of these lines
    -- counts as no thanks. A multi-line box that wraps, like the message boxes.
    local ownLbl = GreyFS(card, "Your own phrases (one per line)", 13)
    ownLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    card.cy = card.cy + 22
    local OWN_BOX_H = 80
    local ownFrame = CreateFrame("Frame", nil, card)
    ownFrame:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    ownFrame:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -card.cy)
    ownFrame:SetHeight(OWN_BOX_H)
    ownFrame:EnableMouse(true)
    local ownBg = ownFrame:CreateTexture(nil, "BACKGROUND")
    ownBg:SetAllPoints()
    ownBg:SetColorTexture(Brand.BG[1], Brand.BG[2], Brand.BG[3], 1)
    Brand.DrawBorder(ownFrame, 0)
    local ownBox = CreateFrame("EditBox", nil, ownFrame)
    ownBox:SetPoint("TOPLEFT", ownFrame, "TOPLEFT", 6, -6)
    ownBox:SetPoint("BOTTOMRIGHT", ownFrame, "BOTTOMRIGHT", -6, 6)
    ownBox:SetMultiLine(true)
    ownBox:SetAutoFocus(false)
    ownBox:SetMaxLetters(0)
    ownBox:SetFont(Brand.BODY_FONT_PATH, 13, "")
    ownBox:SetTextColor(GREY[1], GREY[2], GREY[3])
    ownBox:SetJustifyH("LEFT")
    ownBox:SetText(db.optOutCustom or "")
    ownFrame:SetScript("OnMouseDown", function() ownBox:SetFocus() end)
    ownBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ownBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then db.optOutCustom = self:GetText() end
    end)
    card.cy = card.cy + OWN_BOX_H + 8
    card.cy = card.cy + Note(card,
        "Opt-outs, people who ignore you, and names you add by hand are blocked for good. Declined or unanswered invites are blocked for the length above.",
        card.cy, width) + 4
    y = FinishCard(card, y)

    return y
end

-- ── Ads page ─────────────────────────────────────────────────────────
-- Same shape as Search: a stats box and a card that shows one row at a
-- time (here, the ads waiting in the queue), with its own Settings view.
local adsSettingsView = false

local function NextBatchText(Rec)
    local secs = Rec:GetNextBatchSeconds()
    if not secs then return "Scheduler: off" end
    local db = Rec:GetDB()
    local left = secs >= 60 and (math.ceil(secs / 60) .. "m") or (secs .. "s")
    return ("Scheduler: on, every %d min  |  Next batch in %s"):format(db.adIntervalMinutes, left)
end

local function BuildRecruitAds(body, width)
    local Rec = XRR.Recruitment
    local y = 14

    local queue = Rec:GetAdQueue()
    local box = CreateFrame("Frame", nil, body)
    box:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    box:SetSize(width, 54)
    Brand.DrawBorder(box, 0)
    local line1 = GreyFS(box, ("Posts: %d  |  Queue: %d"):format(Rec:GetTodayStats().posts, #queue), 13)
    line1:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
    local line2 = GreyFS(box, NextBatchText(Rec), 13)
    line2:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -29)
    y = y + 54 + 10

    local card = NewCard(body, y, width, nil)
    local postBtn
    local function PostLabel()
        local wait = Rec:GetPostCooldown()
        return wait > 0 and ("Post Ad (" .. wait .. "s)") or "Post Ad"
    end
    postBtn = Brand.MakeTextLink(card, PostLabel(), function()
        local ok, reason = Rec:PostNext()
        if not ok and reason then RecSay("Couldn't post: " .. reason .. ".") end
        O:RefreshCurrentSection()
    end)
    postBtn.label:SetFont(INTER_SEMIBOLD, 13, "")
    SetLinkText(postBtn, PostLabel())
    postBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)
    local queuedFs = GreyFS(card, ("%d Queued"):format(#queue), 13)
    queuedFs:SetPoint("LEFT", postBtn, "RIGHT", 14, 0)
    Brand.DrawDivider(card, 10, 32, width - 20)

    -- Live countdowns: the Post Ad wait and the next scheduled batch.
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        if not postBtn:IsVisible() then ticker:Cancel() return end
        SetLinkText(postBtn, PostLabel())
        line2:SetText(NextBatchText(Rec))
    end)

    MakeRowScroller(card, "ads", 10, 40, width - 20, queue, function(rowFrame, task)
        if not rowFrame.chanFs then
            rowFrame.chanFs = AccentFS(rowFrame, "", 13)
            rowFrame.chanFs:SetPoint("LEFT", rowFrame, "LEFT", 6, 0)
            rowFrame.msgFs = GreyFS(rowFrame, "", 13)
            rowFrame.msgFs:SetPoint("LEFT", rowFrame, "LEFT", 70, 0)
            rowFrame.msgFs:SetWidth(width - 20 - 70 - 14)
            rowFrame.msgFs:SetWordWrap(false)
        end
        rowFrame.chanFs:SetText(task.channel == "trade" and "Trade" or "General")
        rowFrame.msgFs:SetText(task.msg)
    end, nil, "Queue is empty. Post Ad builds a General and a Trade ad when you click it.")
    card.cy = 40 + ROW_H
    y = FinishCard(card, y)

    return y
end

-- ── Ads Settings ─────────────────────────────────────────────────────
-- A General and a Trade message box (multi-line, wraps, click to place the
-- cursor - same box as the whisper message), the scheduler, and the limits.
local function AdMessageCard(body, y, width, title, dbKey)
    local Rec = XRR.Recruitment
    local db = Rec:GetDB()
    local card = NewCard(body, y, width, title)

    local MSG_BOX_H = 80
    local msgFrame = CreateFrame("Frame", nil, card)
    msgFrame:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    msgFrame:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -card.cy)
    msgFrame:SetHeight(MSG_BOX_H)
    msgFrame:EnableMouse(true)
    local msgBg = msgFrame:CreateTexture(nil, "BACKGROUND")
    msgBg:SetAllPoints()
    msgBg:SetColorTexture(Brand.BG[1], Brand.BG[2], Brand.BG[3], 1)
    Brand.DrawBorder(msgFrame, 0)

    local msgBox = CreateFrame("EditBox", nil, msgFrame)
    msgBox:SetPoint("TOPLEFT", msgFrame, "TOPLEFT", 6, -6)
    msgBox:SetPoint("BOTTOMRIGHT", msgFrame, "BOTTOMRIGHT", -6, 6)
    msgBox:SetMultiLine(true)
    msgBox:SetAutoFocus(false)
    msgBox:SetMaxLetters(0)
    msgBox:SetFont(Brand.BODY_FONT_PATH, 13, "")
    msgBox:SetTextColor(GREY[1], GREY[2], GREY[3])
    msgBox:SetJustifyH("LEFT")
    msgBox:SetText(db[dbKey] or "")
    msgFrame:SetScript("OnMouseDown", function() msgBox:SetFocus() end)
    msgBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    card.cy = card.cy + MSG_BOX_H + 8

    local function InsertBtn(label, placeholder, anchor)
        local btn = Brand.MakeTextLink(card, label, function()
            msgBox:Insert(placeholder)
            db[dbKey] = msgBox:GetText()
        end)
        if anchor then
            btn:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
        else
            btn:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
        end
        return btn
    end
    local insLink = InsertBtn("Insert {guildlink}", "{guildlink}")
    local insGuild = InsertBtn("Insert {guild}", "{guild}", insLink)
    InsertBtn("Insert {player}", "{player}", insGuild)
    card.cy = card.cy + 26

    local countFs = GreyFS(card, "", 12)
    countFs:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    card.cy = card.cy + 20

    local function UpdateMeasure()
        local bytes = Rec:MeasureTemplate(msgBox:GetText(), "")
        countFs:SetText(("%d / %d characters once filled in"):format(bytes, Rec.MAX_CHAT_BYTES))
        if bytes > Rec.MAX_CHAT_BYTES then
            countFs:SetTextColor(0.8, 0.25, 0.25)
        else
            countFs:SetTextColor(GREY[1], GREY[2], GREY[3])
        end
    end
    msgBox:SetScript("OnTextChanged", function(self, userInput)
        -- A chat message can't hold line breaks: Enter just finishes typing.
        local text = self:GetText()
        if text:find("[\r\n]") then
            self:SetText((text:gsub("[\r\n]+", " ")))
            self:ClearFocus()
            return
        end
        if userInput then db[dbKey] = text end
        UpdateMeasure()
    end)
    UpdateMeasure()

    return FinishCard(card, y)
end

local function BuildRecruitAdsSettings(body, width)
    local Rec = XRR.Recruitment
    local db = Rec:GetDB()
    local y = 14

    y = AdMessageCard(body, y, width, "General Channel Message", "adGeneralTemplate")
    y = AdMessageCard(body, y, width, "Trade Channel Message", "adTradeTemplate")

    -- Scheduler -------------------------------------------------------------
    local card = NewCard(body, y, width, "Scheduler")
    local cb, cbFs = CheckRow(card, 10, card.cy, "Add a General and a Trade ad to the queue every", db.adSchedulerEnabled,
        function(on)
            db.adSchedulerEnabled = on
            Rec:ResetSchedule()
        end)
    local minBox = NumberBox(card, 50, db.adIntervalMinutes, function(n)
        db.adIntervalMinutes = math.max(1, math.min(180, n or db.adIntervalMinutes))
        Rec:ResetSchedule()
    end)
    minBox:SetPoint("LEFT", cbFs, "RIGHT", 10, 0)
    local minLbl = GreyFS(card, "minutes", 13)
    minLbl:SetPoint("LEFT", minBox, "RIGHT", 8, 0)
    cb:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy)
    card.cy = card.cy + 28
    card.cy = card.cy + Note(card,
        "Posting itself always needs your click on Post Ad - the game blocks automatic channel messages. The scheduler only fills the queue (1 to 180 minutes).",
        card.cy, width) + 4
    y = FinishCard(card, y)

    -- Posting limits ------------------------------------------------------------
    card = NewCard(body, y, width, "Posting Limits")
    local waitLbl = GreyFS(card, "Wait at least", 13)
    waitLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy - 3)
    local waitBox = NumberBox(card, 50, db.adMinPostSeconds, function(n)
        db.adMinPostSeconds = math.max(3, math.min(120, n or db.adMinPostSeconds))
    end)
    waitBox:SetPoint("LEFT", waitLbl, "RIGHT", 10, 0)
    local waitUnit = GreyFS(card, "seconds between posts (3 to 120)", 13)
    waitUnit:SetPoint("LEFT", waitBox, "RIGHT", 8, 0)
    card.cy = card.cy + 30
    local keepLbl = GreyFS(card, "Keep up to", 13)
    keepLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -card.cy - 3)
    local keepBox = NumberBox(card, 50, db.adQueueMax, function(n)
        db.adQueueMax = math.max(1, math.min(50, n or db.adQueueMax))
    end)
    keepBox:SetPoint("LEFT", keepLbl, "RIGHT", 10, 0)
    local keepUnit = GreyFS(card, "ads in the queue", 13)
    keepUnit:SetPoint("LEFT", keepBox, "RIGHT", 8, 0)
    card.cy = card.cy + 30
    y = FinishCard(card, y)

    return y
end

-- Everything a Stats card can list, in display order: {label, key}. Accept
-- rate isn't counted - it's worked out from Accepted and Invites.
local STAT_CHOICES = {
    { "Whispers", "whispers" }, { "Invites", "invites" }, { "Accepted", "accepted" },
    { "Declined", "declined" }, { "Opt-outs", "optOuts" }, { "Posts", "posts" },
    { "Accept rate", "acceptRate" },
}

local function StatValue(stats, key)
    if key == "acceptRate" then
        local invites = stats.invites or 0
        if invites == 0 then return "-" end
        return ("%d%%"):format(math.floor((stats.accepted or 0) / invites * 100 + 0.5))
    end
    return tostring(stats[key] or 0)
end

local statsSettingsView = false

local function BuildRecruitStatsSettings(body, width)
    local Rec = XRR.Recruitment
    local db = Rec:GetDB()
    local y = 14

    local card = NewCard(body, y, width, "Stats Shown")
    local items, keyByName = {}, {}
    for _, row in ipairs(STAT_CHOICES) do
        table.insert(items, { name = row[1] })
        keyByName[row[1]] = row[2]
    end
    card.cy = CheckGrid(card, card.cy, width, items, 4,
        function(name) return db.statsShown[keyByName[name]] == true end,
        function(name, on) db.statsShown[keyByName[name]] = on or nil end)
    card.cy = card.cy + 4 + Note(card, "Pick what each card lists. Accept rate is Accepted out of Invites.", card.cy + 4, width)
    y = FinishCard(card, y)

    card = NewCard(body, y, width, "Reset")
    local clearBtn = Brand.MakeTextLink(card, "Clear all stats", function()
        StaticPopup_Show("XRR_CLEAR_RECRUIT_STATS")
    end)
    clearBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -card.cy)
    card.cy = card.cy + 28
    card.cy = card.cy + Note(card, "Wipes every day's counts. Asks you to confirm first.", card.cy, width) + 4
    y = FinishCard(card, y)

    return y
end

StaticPopupDialogs["XRR_CLEAR_RECRUIT_STATS"] = {
    text = "Clear all recruitment stats? Every day's whispers, invites, accepted, declined, opt-outs and posts are wiped. This can't be undone.",
    button1 = "Clear",
    button2 = "Cancel",
    OnAccept = function()
        XRR.Recruitment:ClearStats()
        O:RefreshCurrentSection()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function BuildRecruitStats(body, width)
    local Rec = XRR.Recruitment
    local y = 14
    local gap = 10
    local colW = (width - gap * 2) / 3
    local shown = Rec:GetDB().statsShown
    local ROWS = {}
    for _, row in ipairs(STAT_CHOICES) do
        if shown[row[2]] then table.insert(ROWS, row) end
    end
    local periods = {
        { "Today", Rec:GetTodayStats() },
        { "Last 7 Days", Rec:GetStatsTotals(7) },
        { "Last 30 Days", Rec:GetStatsTotals(30) },
    }
    local height = 40 + #ROWS * 24 + 6
    for i, period in ipairs(periods) do
        local card = CreateFrame("Frame", nil, body)
        card:SetPoint("TOPLEFT", body, "TOPLEFT", (i - 1) * (colW + gap), -y)
        card:SetSize(colW, height)
        Brand.ApplyCardBackground(card)
        Brand.DrawBorder(card, 0)
        local title = AccentFS(card, period[1], 14)
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
        Brand.DrawDivider(card, 10, 30, colW - 20)
        for r, row in ipairs(ROWS) do
            local rowY = 40 + (r - 1) * 24
            local label = GreyFS(card, row[1], 13)
            label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -rowY)
            local value = GreyFS(card, StatValue(period[2], row[2]), 13)
            value:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -rowY)
            value:SetJustifyH("RIGHT")
        end
    end
    return y + height + 10
end

-- The page shell for Search / Ads / Stats: the header and divider stay put,
-- everything under them scrolls. Search's header carries the Settings link
-- that swaps the page for the Search Settings cards.
local function BuildRecruitPage(content, pageName)
    local settingsView = (pageName == "Search" and recruitSettingsView) or (pageName == "Ads" and adsSettingsView)
        or (pageName == "Stats" and statsSettingsView)
    local title = settingsView and (pageName .. " Settings") or pageName
    local header = Brand.FS(content, title, Brand.TITLE_FONT_PATH, 22, "OUTLINE",
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    if not settingsView and pageName ~= nil then
        local settingsLink = Brand.MakeTextLink(content, "Settings", function()
            if pageName == "Search" then
                recruitSettingsView = true
            elseif pageName == "Ads" then
                adsSettingsView = true
            else
                statsSettingsView = true
            end
            O:RefreshCurrentSection(true)
        end)
        settingsLink:SetPoint("TOPRIGHT", content, "TOPRIGHT", -Brand.SAFE_MARGIN, 2)
    end

    local SUB_TOP = 46
    local SUB_BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - SUB_TOP - SUB_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -SUB_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local finalY
    if pageName == "Ads" then
        finalY = settingsView and BuildRecruitAdsSettings(body, CONTENT_W) or BuildRecruitAds(body, CONTENT_W)
    elseif pageName == "Stats" then
        finalY = settingsView and BuildRecruitStatsSettings(body, CONTENT_W) or BuildRecruitStats(body, CONTENT_W)
    elseif settingsView then
        finalY = BuildRecruitSearchSettings(body, CONTENT_W)
    else
        finalY = BuildRecruitSearch(body, CONTENT_W)
    end
    body:SetHeight(math.max(1, finalY))

    local bar = GetOrCreateSectionScrollbar()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.vDivider, "TOPRIGHT", 11, -SUB_TOP)
    bar:SetHeight(viewportHeight)
    bar:Show()

    local thumbSlider = bar.thumbSlider
    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    local maxScroll = math.max(0, finalY - viewportHeight)
    suppressScrollCallback = true
    thumbSlider:SetMinMaxValues(0, maxScroll)
    thumbSlider:SetValue(0)
    suppressScrollCallback = false
    scrollFrame:SetVerticalScroll(0)

    if maxScroll <= 0 then
        bar:Hide()
    else
        local ratio = viewportHeight / finalY
        thumbSlider:GetThumbTexture():SetHeight(math.max(20, viewportHeight * ratio))
    end
end

local function BuildRecruitSearchPage(content) BuildRecruitPage(content, "Search") end
local function BuildRecruitAdsPage(content) BuildRecruitPage(content, "Ads") end
local function BuildRecruitStatsPage(content) BuildRecruitPage(content, "Stats") end

sections["About"] = BuildHome
sections["Guild Master"] = BuildGuildMaster
sections["Officer"] = BuildOfficer
sections["Search"] = BuildRecruitSearchPage
sections["Ads"] = BuildRecruitAdsPage
sections["Stats"] = BuildRecruitStatsPage
sections["Applications"] = BuildApplications
sections["Roster"] = BuildRoster
sections["Log"] = BuildLog
sections["Mains / Alts"] = BuildMainsAlts
sections["Text"] = BuildText
sections["Display"] = BuildDisplay

local activeSection = "Guild Master"

-- Recruitment is a sidebar group: its three pages show under it while one
-- of them is open.
local RECRUIT_PAGES = { Search = true, Ads = true, Stats = true }
local LayoutSidebar -- assigned once the sidebar buttons exist (CreateFramework)

local function ShowSection(name, keepScroll)
    -- A redraw of the page you're already on (background refresh, a click
    -- inside the page) puts you back where you were scrolled to instead of
    -- snapping to the top. Read before the scrollbar gets hidden below.
    local savedScroll
    local bar = frame.sectionScrollbar
    if keepScroll and name == activeSection and bar and bar:IsShown() then
        savedScroll = bar.thumbSlider:GetValue()
    end
    activeSection = name
    for key, btn in pairs(sectionButtons) do
        SetLinkSelected(btn, key == name or (key == "Recruitment" and RECRUIT_PAGES[name] == true))
    end
    if LayoutSidebar then LayoutSidebar() end
    ClearContent()
    -- The Applications scrollbar lives in the gap between the sidebar
    -- divider and frame.content, NOT inside frame.content itself (so
    -- scrolling the list never drags the sidebar divider or the page
    -- title with it) - which means ClearContent() never touches it. Hide
    -- it here on every switch; BuildApplications re-shows/repositions it
    -- only when there's actually something to scroll.
    if frame.sectionScrollbar then frame.sectionScrollbar:Hide() end
    sections[name](frame.content)
    local newBar = frame.sectionScrollbar
    if savedScroll and newBar and newBar:IsShown() then
        newBar.thumbSlider:SetValue(savedScroll)
    end
end

-- Lets a page (Guild Master's officer add/remove) redraw itself in place
-- after a click, without needing to know section-switching internals. Keeps
-- the scroll position unless resetScroll is passed (switching to a different
-- view of the page, like its Settings).
function O:RefreshCurrentSection(resetScroll)
    ShowSection(activeSection, not resetScroll)
end

local function CreateFramework()
    frame = CreateFrame("Frame", "XRROptionsFrame", UIParent, "BackdropTemplate")
    -- Restores whatever size was last saved (see the resize grip below),
    -- clamped to the real bounds in case those bounds ever change between
    -- versions - falls back to the original default size on a fresh
    -- install. CONTENT_W is recalculated to match immediately after, so
    -- every page renders at the right width from the very first Show,
    -- not just after the next manual resize.
    local savedSize = XRR_DB.optionsWindowSize
    local startW = savedSize and Clamp(savedSize[1], MIN_FW, MAX_FW) or FW
    local startH = savedSize and Clamp(savedSize[2], MIN_FH, MAX_FH) or FH
    frame:SetSize(startW, startH)
    CONTENT_W = startW - (FW - DEFAULT_CONTENT_W)
    -- Closes on Escape like any other real Blizzard window - the standard
    -- mechanism for this is just listing a global frame name here, not a
    -- custom key handler (confirmed 2026-09-22, "our panel needs to close
    -- when someone hits the escape button").
    table.insert(UISpecialFrames, "XRROptionsFrame")
    -- Distinct default position (NOT identical to Guild Roster's) - a prior
    -- pass reverted both windows to plain bare "CENTER" with zero offset,
    -- which spawns them at the literal same coordinate every time, which is
    -- what was still causing full overlap (confirmed 2026-08-12, second
    -- screenshot). Freely movable afterward same as before.
    -- Only used the first time - once dragged, its real position is
    -- remembered permanently (XRR_DB.optionsWindowPoint), same as every
    -- mature addon's window (a collision can only ever happen once before
    -- the player moves it and it's fixed for good).
    -- 604x560 - anchored to the TOP edge (all 4 corners are already
    -- claimed by other Xal's addons' big settings windows - see the
    -- "Default window position" rule in the shared brand-style memory).
    local savedPoint = XRR_DB.optionsWindowPoint
    if savedPoint then
        frame:SetPoint(savedPoint[1], UIParent, savedPoint[2], savedPoint[3], savedPoint[4])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -40)
    end
    -- Real, confirmed bug (2026-09-22, via screenshot - still happening
    -- after the first attempt at this fix): converting to a corner anchor
    -- reactively, in the same instant a resize starts, wasn't enough -
    -- StartSizing right after ClearAllPoints/SetPoint in that same tick
    -- could still jump, likely because the engine hadn't actually settled
    -- the new anchor yet. Normalizing to a real TOPLEFT anchor here
    -- instead, once, well before the window is ever shown or touched,
    -- means it's never anchored by a center point at resize time at all -
    -- nothing reactive needed anymore.
    do
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
    end
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        XRR_DB.optionsWindowPoint = { point, relPoint, x, y }
    end)

    -- Real resizable window (2026-09-22, "bottom right corner resize...
    -- people like to do that"). Real, confirmed bug: SetMinResize/
    -- SetMaxResize (the older pair) don't exist as callable methods on the
    -- current client at all - "attempt to call a nil value" in-game.
    -- SetResizeBounds(minW, minH, maxW, maxH) is the real current one,
    -- confirmed via Blizzard's own EditModeSystemTemplates.lua.
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_FW, MIN_FH, MAX_FW, MAX_FH)

    -- Small corner grip, bottom-right - Blizzard's own standard resize
    -- texture (same one the default chat frame uses), not hand-drawn.
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    -- Same exact mousedown/mouseup pattern as Compendium's own working
    -- resize grip (Options.lua) - no anchor conversion needed here at all,
    -- because the frame was already normalized to a real TOPLEFT corner
    -- anchor once, back where its position gets set, same as Compendium's
    -- own window is corner-anchored from the start.
    resizeGrip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        XRR_DB.optionsWindowSize = { frame:GetWidth(), frame:GetHeight() }
        -- Every page's layout reads CONTENT_W as a plain upvalue rather
        -- than the frame's live width, so it only actually reflows when
        -- re-rendered - refreshing once here (not on every OnSizeChanged
        -- tick while dragging) is what makes the content catch up to the
        -- new size without redrawing the whole page dozens of times a
        -- second mid-drag.
        CONTENT_W = frame.content:GetWidth()
        O:RefreshCurrentSection()
    end)
    -- Distinct frame strata from Guild Roster (which uses "DIALOG") - a real
    -- separate render layer, not just draw-order-by-creation-sequence, so
    -- one is guaranteed on top of the other regardless of which opened last.
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    -- Flat color only, no swirl image - confirmed 2026-09-02 brand refresh.
    -- Brand.ApplyBackgroundImage still exists but is no longer called for
    -- the default look.
    -- Outer border restored (2026-09-20) - in Brand.DIVIDER_COLOR (already
    -- DrawBorder's default), matching every divider/panel edge instead of
    -- the old orange it used to be before this same border got briefly
    -- removed entirely. Sits right at the window's true outer edge (inset
    -- 1, not the old orange border's 6px inset) - it's a new, distinct
    -- edge treatment, not just a recolor of where the old one sat.
    Brand.ApplyBackground(frame)
    Brand.DrawBorder(frame, 1)

    Brand.Title(frame, "Xal's Roster Roundup", 32, "TOP", frame, "TOP", 0, -20)
    -- Anchor-stretched left-to-right instead of Brand.DrawHeaderDivider's
    -- fixed pixel width, so it actually spans the full header on resize
    -- instead of staying pinned at the window's original default width.
    local headerDivider = frame:CreateTexture(nil, "ARTWORK")
    headerDivider:SetColorTexture(Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3], 1)
    headerDivider:SetHeight(Brand.LINE_THICKNESS)
    headerDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", Brand.SAFE_MARGIN, -80)
    headerDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Brand.SAFE_MARGIN, -80)

    local closeBtn = Brand.MakeCloseButton(frame, function() frame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Brand.SAFE_MARGIN, -Brand.SAFE_MARGIN)

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", Brand.SAFE_MARGIN, -88)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", Brand.SAFE_MARGIN, Brand.SAFE_MARGIN)
    sidebar:SetWidth(SIDEBAR_W)

    -- Muted tone, not accent orange (2026-09-20) - matches the header
    -- divider and every other divider in the addon (GuildPanel's two list
    -- dividers were already this color); this was the one spot still using
    -- full bright orange for a divider line.
    local vDivider = frame:CreateTexture(nil, "ARTWORK")
    vDivider:SetColorTexture(Brand.DIVIDER_COLOR[1], Brand.DIVIDER_COLOR[2], Brand.DIVIDER_COLOR[3], 1)
    vDivider:SetWidth(Brand.LINE_THICKNESS)
    vDivider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    vDivider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 10, 0)
    frame.vDivider = vDivider

    -- Real anchor-based sizing, not a fixed SetSize (2026-09-22, "it all
    -- needs to be for auto adjusting") - content's bottom-right edge tracks
    -- the window's own bottom-right edge directly, so it grows/shrinks
    -- along with the frame instead of staying pinned at whatever size it
    -- was created at. Same bottom clearance the old fixed-height formula
    -- worked out to (24 + SAFE_MARGIN above the footer).
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", vDivider, "TOPRIGHT", 26, -32)
    frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Brand.SAFE_MARGIN, Brand.SAFE_MARGIN + 24)

    -- Order confirmed 2026-09-20: Guild Master first (the primary reason
    -- most players open this at all), then Applications/Roster/Mains-Alts
    -- as the other guild-management pages, then the addon's own
    -- Display/Text/Data settings, with About moved to the very bottom
    -- (renamed from Home - it's the "about this addon" splash, not a
    -- landing page anymore now that Guild Master leads).
    local sectionNames = {
        "Guild Master", "Officer", "Recruitment", "Search", "Ads", "Stats", "Applications", "Roster", "Log",
        "Mains / Alts", "Display", "Text", "About",
    }
    local y = -32
    for _, name in ipairs(sectionNames) do
        local btn = Brand.MakeTextLink(sidebar, name, function()
            -- Recruitment opens its first page; clicking Search always
            -- lands on the page itself, not its Settings view.
            if name == "Recruitment" or name == "Search" then
                recruitSettingsView = false
                ShowSection("Search")
            elseif name == "Ads" then
                adsSettingsView = false
                ShowSection("Ads")
            elseif name == "Stats" then
                statsSettingsView = false
                ShowSection("Stats")
            elseif name == "Guild Master" or name == "Officer" then
                officerSettingsView = false
                ShowSection(name)
            else
                ShowSection(name)
            end
        end)
        btn.isRecruitPage = RECRUIT_PAGES[name] == true
        -- Bumped from the default GameFontHighlightSmall (2026-09-20) - the
        -- sidebar nav text was reading too small next to everything else.
        -- Uses the bundled Inter SemiBold (not Brand.BODY_FONT_PATH's
        -- Regular weight) for real bold - the OUTLINE flag only draws an
        -- outline around the glyphs, it doesn't change the font weight.
        btn.label:SetFont("Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Inter-SemiBold.ttf", btn.isRecruitPage and 14 or 15, "")
        -- Left-justified, flush to a fixed x - was centered within each
        -- button's own (text-length-dependent) width, which staggered
        -- every entry sideways instead of lining them all up under "Home"
        -- (confirmed via screenshot 2026-09-20). A fixed sidebar-width
        -- button with a left-anchored label guarantees the same start
        -- position regardless of how long each name is.
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", btn, "LEFT", btn.isRecruitPage and 14 or 0, 0)
        btn.label:SetJustifyH("LEFT")
        btn:SetWidth(SIDEBAR_W - 8)
        btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, y)
        sectionButtons[name] = btn

        -- Pending-application count badge, straight from the approved
        -- mockup - solid orange pill, white number, sitting next to
        -- "Applications" in the sidebar regardless of which page is
        -- currently open (not just when Applications itself is selected).
        if name == "Applications" then
            local badge = CreateFrame("Frame", nil, btn)
            badge:SetHeight(15)
            badge:SetPoint("LEFT", btn.label, "RIGHT", 6, 0)

            -- An oval, not a box. Every previous attempt used the OLD
            -- single-argument texture:SetMask(path) API, which does not
            -- actually mask anything on current retail regardless of which
            -- file is passed - confirmed by checking Blizzard's own live
            -- client source (Gethe/wow-ui-source): their own UI masks
            -- textures with a real MaskTexture object
            -- (frame:CreateMaskTexture() + texture:AddMaskTexture(mask)),
            -- using the real atlas "talents-node-circle-mask" for a round
            -- shape. That's the actual current API - SetMask(path) is
            -- legacy and wasn't doing anything here.
            local bg = badge:CreateTexture(nil, "ARTWORK")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)

            -- Switched from the "talents-node-circle-mask" atlas to this
            -- file - the talent one is a small fixed-resolution game icon
            -- mask that visibly pixelates once stretched into a wider oval
            -- (confirmed via screenshot); this one is built to scale
            -- cleanly to any size.
            local mask = badge:CreateMaskTexture(nil, "ARTWORK")
            mask:SetAllPoints(bg)
            mask:SetTexture("Interface\\Masks\\CircleMaskScalable")
            bg:AddMaskTexture(mask)

            local badgeText = badge:CreateFontString(nil, "OVERLAY")
            badgeText:SetFont("Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Inter-SemiBold.ttf", 11, "")
            badgeText:SetTextColor(1, 1, 1, 1)
            badgeText:SetPoint("CENTER")

            local function UpdateBadge()
                local count = #XRR.Applications:GetPending()
                if count > 0 then
                    badgeText:SetText(tostring(count))
                    badge:SetWidth(math.max(20, badgeText:GetStringWidth() + 14))
                    badge:Show()
                else
                    badge:Hide()
                end
            end
            XRR.Applications:OnUpdate(UpdateBadge)
            UpdateBadge()

            -- Real fix (2026-09-21) for a genuine bug, not a timing
            -- coincidence: BuildApplications only ever read
            -- XRR.Applications:GetPending() once, at the exact moment the
            -- page was built. If the real applicant data hadn't finished
            -- loading yet at that moment (Blizzard's own club-finder cache
            -- needs a force-refresh poke that isn't instant - see
            -- Applications.lua's RequestUpdate), the page just froze on
            -- whatever it saw first and never redrew itself once the real
            -- data actually arrived - only the sidebar badge above was
            -- wired to react to that. Now the page itself re-renders
            -- whenever new applicant data comes in, but only while it's
            -- actually the page you're looking at.
            XRR.Applications:OnUpdate(function()
                if activeSection == "Applications" then
                    ShowSection("Applications", true)
                end
            end)
        end

        y = y - 30
    end

    -- Lines every button up top to bottom; the three Recruitment pages only
    -- take up room while one of them is open.
    LayoutSidebar = function()
        local expanded = RECRUIT_PAGES[activeSection] == true
        local ly = -32
        for _, name in ipairs(sectionNames) do
            local btn = sectionButtons[name]
            if btn.isRecruitPage and not expanded then
                btn:Hide()
            else
                btn:Show()
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, ly)
                ly = ly - (btn.isRecruitPage and 26 or 30)
            end
        end
    end
    LayoutSidebar()

    -- Same live-refresh idea for Recruitment - a scan's results (or the
    -- sweep's next band becoming available) should show up on the page
    -- without needing to leave and come back. Not while Search Settings is
    -- open: redrawing it would wipe whatever is being typed.
    XRR.Recruitment:OnUpdate(function()
        local editing = (activeSection == "Search" and recruitSettingsView) or (activeSection == "Ads" and adsSettingsView)
        if RECRUIT_PAGES[activeSection] and not editing then
            ShowSection(activeSection, true)
        end
    end)

    -- Same real bug as Applications, same fix (2026-09-21): Guild Master's
    -- "new members"/rank-changes lists only ever redrew when you actually
    -- switched tabs to it, not the instant something changed - confirmed
    -- via screenshot ("still says 8" after reviewing every profile on the
    -- Roster page, until switching tabs away and back a second time).
    -- Roster.lua's R:OnSync already fires on exactly this kind of change
    -- (R:MarkReviewed calls it) - Guild Master and Roster both just needed
    -- to actually listen for it instead of only rendering once per visit.
    R:OnSync(function()
        -- Deferred one tick - R:MarkReviewed (Roster page's own row click)
        -- fires this synchronously from inside its own click handler, and
        -- ShowSection rebuilds that same page's content immediately -
        -- letting the click handler actually finish first avoids tearing
        -- down the frame it's still running inside of.
        if activeSection == "Guild Master" or activeSection == "Officer" or activeSection == "Roster" or activeSection == "Log" then
            local sectionAtCallTime = activeSection
            C_Timer.After(0, function()
                if activeSection == sectionAtCallTime then
                    ShowSection(sectionAtCallTime, true)
                end
            end)
        end
    end)

    -- Logo-only Discord link, pinned to the sidebar's own bottom edge so it
    -- stays put regardless of how many sections get added later - confirmed
    -- 2026-09-20 ("just the logo, no separate text"), same idea as Guild
    -- Council's own sidebar Discord entry. Distinct from the text-style
    -- Discord link that already lives on the About page.
    local discordLogo = Brand.MakeDiscordLogoLink(sidebar, SIDEBAR_W - 16)
    discordLogo:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 8, 0)
    -- Pulls the URL from the current guild's own real setting (never a
    -- hardcoded one) and hides itself until the Guild Master has actually
    -- set one - refreshed on every sync so it catches a change without
    -- needing the window reopened.
    local function RefreshDiscordLogo()
        local guild = R:GetCurrentGuild()
        discordLogo:SetDiscordURL(guild and guild.discordUrl)
    end
    RefreshDiscordLogo()
    R:OnSync(RefreshDiscordLogo)

    -- Footer, centered on the content area's span (divider to right border).
    -- Version read live from the real installed .toc (same pattern already
    -- confirmed working in Quest Compass) instead of a hand-typed string -
    -- caught 2026-09-12 via screenshot still showing "v1.0.0" while the
    -- addon was actually on 1.1.0, a real stale-string bug, not a display
    -- bug - this addon is now on its 5th real version and the footer had
    -- never been updated since the addon's initial release.
    local function GetFooterVersion()
        local v
        if C_AddOns and C_AddOns.GetAddOnMetadata then
            v = C_AddOns.GetAddOnMetadata("XalsRosterRoundup", "Version")
        elseif _G.GetAddOnMetadata then
            v = _G.GetAddOnMetadata("XalsRosterRoundup", "Version")
        end
        if v == "@project-version@" then return "dev" end
        return v or "dev"
    end
    local installedVersion = GetFooterVersion()
    local versionLabel = (installedVersion == "dev") and "dev build" or ("v" .. installedVersion)

    local footer = frame:CreateFontString(nil, "OVERLAY")
    footer:SetFont(Brand.BODY_FONT_PATH, 12, "")
    footer:SetTextColor(Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    footer:SetPoint("BOTTOMLEFT", vDivider, "BOTTOMRIGHT", 12, Brand.SAFE_MARGIN)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Brand.SAFE_MARGIN, Brand.SAFE_MARGIN)
    footer:SetJustifyH("CENTER")
    footer:SetText(versionLabel .. "  ·  by Xal  ·  A Xal's Creation")

    ShowSection("Guild Master")
end

-- Tears down and rebuilds the whole window from scratch, so a color/font
-- change actually shows immediately instead of needing a real /reload.
-- Every title/border/divider/text color is set once at creation time from
-- whatever Brand.ACCENT/Brand.BG/Brand.BODY_FONT_PATH happen to be at that
-- moment - patching each of those dozens of already-drawn elements
-- individually would be much more fragile than just rebuilding the window
-- fresh against the CURRENT values, the same way it already builds fresh
-- the very first time it's ever opened.
function O:Rebuild()
    local wasOpen = frame and frame:IsShown()
    local wasSection = activeSection
    if frame then
        frame:Hide()
        frame:SetParent(nil)
        frame = nil
    end
    if wasOpen then
        CreateFramework()
        frame:Show()
        frame:Raise()
        ShowSection(wasSection)
    end
end

function O:Open()
    if not frame then CreateFramework() end
    frame:Show()
    frame:Raise()
end

-- Jumps straight to the Applications tab - used by the floating alert icon
-- so clicking it doesn't land you back on Home every time.
function O:OpenToApplications()
    O:Open()
    ShowSection("Applications")
end

-- Same idea, for the new-member and rank-change alert icons - both point
-- here since the Guild Master page is where both lists live.
function O:OpenToGuildMaster()
    O:Open()
    ShowSection("Guild Master")
end

-- Used by the minimap button's right-click - used to open the standalone
-- Guild Roster window directly, now jumps straight to this window's Roster
-- page instead (2026-09-20 merge).
function O:OpenToRoster()
    O:Open()
    ShowSection("Roster")
end

function O:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        O:Open()
    end
end

-- ── Native AddOns list entry ─────────────────────────────────────────
-- Escape -> Options -> AddOns -> Xal's Roster Roundup: the standing rule for
-- every addon in the family - a small canvas panel with a button that opens
-- the real window, registered with Settings.RegisterCanvasLayoutCategory.
function O:RegisterNativePanel()
    if O.category then return end
    local panel = CreateFrame("Frame")
    panel.name = "Xal's Roster Roundup"

    local title = Brand.FS(panel, panel.name, Brand.BODY_FONT_PATH, 22, nil,
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)

    local blurb = Brand.FS(panel,
        "Guild roster, mains and alts, notes, recruitment, applications, and officer tools in one window.",
        Brand.BODY_FONT_PATH, 14, nil, Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    blurb:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    blurb:SetJustifyH("LEFT")
    blurb:SetWordWrap(true)

    local openBtn = Brand.MakeButton(panel, "Open Xal's Roster Roundup", 240, 28, function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
        O:Open()
    end)
    openBtn:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -20)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
        O.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
