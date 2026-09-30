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

-- ── Data ─────────────────────────────────────────────────────────────
local function BuildData(content)
    local header = Brand.FS(content, "Storage", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local desc = content:CreateFontString(nil, "OVERLAY")
    desc:SetFont(Brand.BODY_FONT_PATH, 15, "")
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
    label:SetFont(Brand.BODY_FONT_PATH, 14, "")
    label:SetTextColor(0.85, 0.85, 0.85)
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetText("Use per-character storage (instead of account-wide)")
    label:SetWordWrap(true)
    label:SetWidth(CONTENT_W - 32)
    cb.OnToggle = function(self)
        XRR_DB.storageScope = self:GetChecked() and "character" or "account"
    end

    -- Confirmed 2026-08-12: switching to per-character storage silos each
    -- character's roster copy, which also breaks the Guild Master's linked
    -- alts from getting GM data access (R:HasGMEditAccess in Roster.lua) -
    -- that only works when every character on the account is reading the
    -- same shared roster.
    local warn = content:CreateFontString(nil, "OVERLAY")
    warn:SetFont(Brand.BODY_FONT_PATH, 12, "")
    warn:SetTextColor(0.9, 0.55, 0.3)
    warn:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -10)
    warn:SetWidth(CONTENT_W - 8)
    warn:SetJustifyH("LEFT")
    warn:SetWordWrap(true)
    warn:SetText("Note: if you're the Guild Master, turning this on also removes your linked alts' account-wide access to the Guild Master editing tools (notes, nicknames, etc.) - that access only works when every character on your account shares the same roster.")
end

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

    local y = 0

    -- Guild Discord link (2026-09-22, "we don't want it sending every
    -- person that uses this addon's members to our server") - per-guild,
    -- GM-set (see R:SetGuildDiscordUrl), never a hardcoded addon-wide URL.
    -- showBanList doubles as "is this the Guild Master's own page" here -
    -- same GM-only audience as the Ban List, so no separate flag needed:
    -- the Guild Master gets a real editable field, officers get a
    -- read-only copy of it plus a way to drop it straight into guild chat.
    local discordHeader = Brand.FS(body, "Guild Discord", Brand.TITLE_FONT_PATH, 16, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    discordHeader:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    y = y + 22

    if showBanList then
        local urlBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
        urlBox:SetSize(360, 20)
        urlBox:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
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
        y = y + 30
    elseif guild.discordUrl and guild.discordUrl ~= "" then
        local urlFs = Brand.BodyFS(body, guild.discordUrl, 13)
        urlFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)

        local copyBtn = Brand.MakeTextLink(body, "Copy", function()
            Brand.ShowCopyBox("Guild Discord", guild.discordUrl)
        end)
        copyBtn:SetPoint("LEFT", urlFs, "RIGHT", 14, 0)

        local postBtn = Brand.MakeTextLink(body, "Post to Guild Chat", function()
            SendChatMessage(guild.discordUrl, "GUILD")
        end)
        postBtn:SetPoint("LEFT", copyBtn, "RIGHT", 14, 0)
        y = y + 26
    else
        local noneFs = Brand.BodyFS(body, "The Guild Master hasn't set a Discord link yet.", 13)
        noneFs:SetTextColor(0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        y = y + 22
    end
    y = y + 14

    local unreviewed = R:GetUnreviewedMembers(guild)
    -- Just seeing them here IS the review now (confirmed 2026-09-22 - "I
    -- shouldn't have to click every single one of them, just looking at
    -- them should be a review") - snapshot the list first so this one
    -- render still shows who was actually new, then mark all of them
    -- reviewed so they're gone from this list the next time it opens.
    for _, m in ipairs(unreviewed) do
        R:MarkReviewed(guild, m.charName)
    end
    local countText = body:CreateFontString(nil, "OVERLAY")
    countText:SetFont(Brand.BODY_FONT_PATH, 15, "")
    countText:SetTextColor(1, 0.53, 0)
    countText:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    countText:SetWidth(CONTENT_W)
    countText:SetJustifyH("LEFT")
    countText:SetWordWrap(true)
    countText:SetText(#unreviewed .. " new member" .. (#unreviewed == 1 and "" or "s")
        .. " since you last opened the roster.")
    y = y + 26

    local unreviewedShown = showAllUnreviewed and #unreviewed or math.min(#unreviewed, 3)
    for i = 1, unreviewedShown do
        local m = unreviewed[i]
        local nameFs = body:CreateFontString(nil, "OVERLAY")
        nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
        nameFs:SetTextColor(0.9, 0.9, 0.9)
        nameFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        nameFs:SetText(m.charName)

        local welcomeBtn = Brand.MakeTextLink(body, "Send Welcome Message", function()
            ChatFrame_OpenChat("/w " .. m.charName .. " Welcome to the guild! ", DEFAULT_CHAT_FRAME)
        end)
        welcomeBtn:SetPoint("LEFT", nameFs, "RIGHT", 10, 0)
        y = y + 28
    end
    if #unreviewed > unreviewedShown then
        local moreBtn = Brand.MakeTextLink(body, "+" .. (#unreviewed - unreviewedShown) .. " more", function()
            showAllUnreviewed = true
            O:RefreshCurrentSection()
        end)
        moreBtn:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        y = y + 24
    end
    y = y + 16

    -- Real live rank promotions/demotions caught since the last time this
    -- was checked - see Roster.lua's SyncFromLiveGuild for why this reads
    -- actual game rank data instead of this addon's own "isOfficer" label.
    local rankChanges = R:GetPendingRankChanges(guild)
    if #rankChanges > 0 then
        local rankHeader = Brand.FS(body, "Rank Changes", Brand.TITLE_FONT_PATH, 18, "OUTLINE",
            Brand.ALERT_COLOR_RANK_CHANGE[1], Brand.ALERT_COLOR_RANK_CHANGE[2], Brand.ALERT_COLOR_RANK_CHANGE[3])
        rankHeader:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = y + 24

        local rankChangesShown = showAllRankChanges and #rankChanges or math.min(#rankChanges, 3)
        for i = 1, rankChangesShown do
            local change = rankChanges[i]
            local changeFs = body:CreateFontString(nil, "OVERLAY")
            changeFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            changeFs:SetTextColor(0.85, 0.85, 0.85)
            changeFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
            changeFs:SetWidth(CONTENT_W - 8)
            changeFs:SetJustifyH("LEFT")
            changeFs:SetWordWrap(true)
            changeFs:SetText(change.charName .. ": " .. change.from .. " -> " .. change.to)
            y = y + 20
        end
        if #rankChanges > rankChangesShown then
            local moreRankBtn = Brand.MakeTextLink(body, "+" .. (#rankChanges - rankChangesShown) .. " more", function()
                showAllRankChanges = true
                O:RefreshCurrentSection()
            end)
            moreRankBtn:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
            y = y + 22
        end

        local dismissBtn = Brand.MakeTextLink(body, "Dismiss", function()
            R:ClearRankChanges(guild)
            O:RefreshCurrentSection()
        end)
        dismissBtn:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        y = y + 28
    end
    y = y + 8

    -- Real, live officer status (2026-09-20) - derived straight from
    -- Blizzard's own rank permissions (the "Is Officer" checkbox in Guild
    -- Control -> Rank Permissions), refreshed every sync. No manual
    -- Add/Remove here anymore - a manual override would just get
    -- overwritten by the real data on the next sync anyway, and this way
    -- it's never out of date with what the guild's ranks actually say.
    local officerHeader = Brand.FS(body, "Officers", Brand.TITLE_FONT_PATH, 18, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    officerHeader:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    y = y + 24

    local officers = R:GetOfficers(guild)
    if #officers == 0 then
        local noneFs = body:CreateFontString(nil, "OVERLAY")
        noneFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
        noneFs:SetTextColor(0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        noneFs:SetText("No ranks with officer permissions right now.")
        y = y + 22
    else
        for _, m in ipairs(officers) do
            local nameFs = body:CreateFontString(nil, "OVERLAY")
            nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
            nameFs:SetTextColor(0.9, 0.9, 0.9)
            nameFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
            nameFs:SetText(m.charName .. "  |cff777777(" .. (m.rankName or "?") .. ")|r")
            y = y + 24
        end
    end
    y = y + 8

    -- Ban list - same shape as GRM's own ban feature (researched
    -- 2026-09-20): a blacklist + reason, and a warning if the name ever
    -- shows back up. It does NOT kick anyone and can't block a rejoin -
    -- Blizzard has no API for either, confirmed. GM-only - confirmed both
    -- 2026-09-20 and again 2026-09-22 that even an officer shouldn't be
    -- able to ban (kick, yes; ban, no) - hidden entirely on the Officer
    -- page via showBanList.
    if showBanList then
        local banHeader = Brand.FS(body, "Ban List", Brand.TITLE_FONT_PATH, 18, "OUTLINE",
            Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
        banHeader:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = y + 24

        local banIntro = Brand.BodyFS(body,
            "Banning someone doesn't kick them - it flags their name so you're warned if they ever try to rejoin.", 13)
        banIntro:SetTextColor(0.6, 0.6, 0.6)
        banIntro:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        banIntro:SetWidth(CONTENT_W)
        banIntro:SetJustifyH("LEFT")
        banIntro:SetWordWrap(true)
        y = y + 24

        local bannedRejoins = R:GetBannedRejoins(guild)
        if #bannedRejoins > 0 then
            local rejoinFs = body:CreateFontString(nil, "OVERLAY")
            rejoinFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
            rejoinFs:SetTextColor(Brand.ALERT_COLOR_BAN_REJOIN[1], Brand.ALERT_COLOR_BAN_REJOIN[2], Brand.ALERT_COLOR_BAN_REJOIN[3])
            rejoinFs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            rejoinFs:SetWidth(CONTENT_W)
            rejoinFs:SetJustifyH("LEFT")
            rejoinFs:SetWordWrap(true)
            local names = {}
            for _, r in ipairs(bannedRejoins) do table.insert(names, r.charName) end
            rejoinFs:SetText(table.concat(names, ", ") .. " - banned, but back in the guild.")
            y = y + 20

            local rejoinDismissBtn = Brand.MakeTextLink(body, "Dismiss", function()
                R:ClearBannedRejoins(guild)
                O:RefreshCurrentSection()
            end)
            rejoinDismissBtn:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
            y = y + 28
        end

        local banNameLabel = Brand.BodyFS(body, "Character name", 13)
        banNameLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        local banReasonLabel = Brand.BodyFS(body, "Reason", 13)
        banReasonLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 170, -y)
        y = y + 18

        local banNameBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
        banNameBox:SetSize(150, 20)
        banNameBox:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        banNameBox:SetAutoFocus(false)

        local banReasonBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
        banReasonBox:SetSize(280, 20)
        banReasonBox:SetPoint("TOPLEFT", body, "TOPLEFT", 174, -y)
        banReasonBox:SetAutoFocus(false)

        local addBanBtn = Brand.MakeTextLink(body, "+ Add Ban", function()
            local charName = banNameBox:GetText()
            if charName and charName ~= "" then
                R:AddBan(guild, charName, banReasonBox:GetText())
                banNameBox:SetText("")
                banReasonBox:SetText("")
                O:RefreshCurrentSection()
            end
        end)
        addBanBtn:SetPoint("LEFT", banReasonBox, "RIGHT", 14, 0)
        y = y + 32

        local bans = R:GetBans(guild)
        if #bans == 0 then
            local noneFs = Brand.BodyFS(body, "Nobody's banned right now.", 13)
            noneFs:SetTextColor(0.6, 0.6, 0.6)
            noneFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        else
            for _, ban in ipairs(bans) do
                local nameFs = body:CreateFontString(nil, "OVERLAY")
                nameFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
                nameFs:SetTextColor(0.9, 0.9, 0.9)
                nameFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
                nameFs:SetText(ban.charName)

                local metaFs = body:CreateFontString(nil, "OVERLAY")
                metaFs:SetFont(Brand.BODY_FONT_PATH, 12, "")
                metaFs:SetTextColor(0.55, 0.55, 0.55)
                metaFs:SetPoint("LEFT", nameFs, "RIGHT", 10, 0)
                local reasonText = (ban.reason and ban.reason ~= "") and (ban.reason .. " - ") or ""
                metaFs:SetText(reasonText .. "banned " .. R.FormatDate(ban.bannedAt) .. " by " .. ban.bannedBy)

                local unbanBtn = Brand.MakeTextLink(body, "Unban", function()
                    R:RemoveBan(guild, ban.charName)
                    O:RefreshCurrentSection()
                end)
                unbanBtn:SetPoint("LEFT", metaFs, "RIGHT", 14, 0)
                y = y + 24
            end
        end
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
    local header = Brand.FS(content, "Guild Master", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
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

    BuildGuildMasterBody(content, guild, true)
end

-- ── Officer ──────────────────────────────────────────────────────────
-- Same content as the Guild Master page (new members, rank changes,
-- officers list), minus the Ban List - added 2026-09-22 so officers who
-- couldn't see the Guild Master page at all can actually use this addon
-- too, not just the Guild Master and their own alts.
local function BuildOfficer(content)
    local header = Brand.FS(content, "Officer", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
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

    BuildGuildMasterBody(content, guild, false)
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

    -- No longer true (2026-09-20) - color/opacity changes rebuild the
    -- window immediately now instead of needing a real /reload.
    local note = Brand.BodyFS(content, "Changes apply immediately.", 13)
    note:SetTextColor(0.6, 0.6, 0.6)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -44)

    -- Chained off a running y-offset from here on, not fixed magic-number
    -- positions per element - a hardcoded absolute y for "Alert Icon Size"
    -- (was -260) didn't actually account for the real height the opacity
    -- slider block above it takes up (its value text, track, AND Low/High
    -- labels), so it landed on top of it (confirmed via screenshot
    -- 2026-09-20). SLIDER_BLOCK_H is a real measured height for one
    -- label+slider+Low/High group, with its own buffer already included.
    local SWATCH_BLOCK_H = 66
    local SLIDER_BLOCK_H = 90
    local y = 76

    -- Deferred one tick (C_Timer.After(0, ...)) rather than rebuilt
    -- immediately inline - the button doing the rebuilding is itself a
    -- child of the frame Rebuild() is about to hide/destroy, so letting
    -- this OnClick handler fully return first is the safe order.
    local accentLabel = Brand.BodyFS(content, "Accent Color", 14)
    accentLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    AddColorSwatch(content, Brand.ACCENT, "TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -8, function(r, g, b)
        XRR_DB.accentColor = { r, g, b }
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    -- Once a color is genuinely saved, no code-side default change can ever
    -- reach it again (that's how the picker's supposed to work) - this is
    -- the actual way back, instead of eyeball-matching a hex value with the
    -- picker.
    local resetAccentBtn = Brand.MakeTextLink(content, "Reset to Default", function()
        XRR_DB.accentColor = nil
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3] =
            Brand.DEFAULT_ACCENT[1], Brand.DEFAULT_ACCENT[2], Brand.DEFAULT_ACCENT[3]
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    resetAccentBtn:SetPoint("TOPLEFT", accentLabel, "TOPRIGHT", 12, 0)
    y = y + SWATCH_BLOCK_H

    local bgLabel = Brand.BodyFS(content, "Background Color", 14)
    bgLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    AddColorSwatch(content, Brand.BG, "TOPLEFT", bgLabel, "BOTTOMLEFT", 0, -8, function(r, g, b)
        XRR_DB.bgColor = { r, g, b }
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    local resetBgBtn = Brand.MakeTextLink(content, "Reset to Default", function()
        XRR_DB.bgColor = nil
        Brand.BG[1], Brand.BG[2], Brand.BG[3] =
            Brand.DEFAULT_BG[1], Brand.DEFAULT_BG[2], Brand.DEFAULT_BG[3]
        C_Timer.After(0, function() O:Rebuild() end)
    end)
    resetBgBtn:SetPoint("TOPLEFT", bgLabel, "TOPRIGHT", 12, 0)
    y = y + SWATCH_BLOCK_H

    local opacityLabel = Brand.BodyFS(content, "Background Opacity", 14)
    opacityLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)

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
    -- Blizzard's OptionsSliderTemplate hardcodes these gold - doesn't read
    -- Brand.ACCENT at all, so the 2026-09-02 orange refresh needs an
    -- explicit override here, the one native slider this addon has.
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
    y = y + SLIDER_BLOCK_H

    -- Roster alert icon size (the one floating icon that covers pending
    -- applications, unreviewed members, and rank changes) - 0.5x (roughly
    -- minimap-button-sized) up to 2x the default 64px. Unlike the color/
    -- opacity settings above, this one takes effect live via
    -- RosterAlertIcon:ApplyScale() instead of needing a /reload, since it's
    -- just a size change with no theme-wide re-read.
    local sizeLabel = Brand.BodyFS(content, "Alert Icon Size", 14)
    sizeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)

    local sizeSlider = CreateFrame("Slider", "XRRAlertSizeSlider", content, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 4, -22)
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
    card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    card:SetBackdropColor(1, 1, 1, 0.04)
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

    -- Auto-whisper-on-accept setting - lets an applicant know they got in
    -- and to go check their guild invites, without the Guild Master having
    -- to remember to whisper each one by hand every time. Same checkbox +
    -- editable {player}/{guild} template pattern Recruitment's own whisper
    -- template already uses, so it doesn't feel like a new, different kind
    -- of control.
    local whisperCb = Brand.MakeCheckbox(content, 20)
    whisperCb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -42)
    whisperCb:SetChecked(XRR.Applications:IsAutoWhisperEnabled())
    whisperCb.OnToggle = function(self) XRR.Applications:SetAutoWhisperEnabled(self:GetChecked()) end
    local whisperCbLbl = Brand.BodyFS(content, "Whisper applicants when accepted", 13)
    whisperCbLbl:SetPoint("LEFT", whisperCb, "RIGHT", 6, 0)

    local whisperBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    whisperBox:SetSize(CONTENT_W - 8, 20)
    whisperBox:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -68)
    whisperBox:SetAutoFocus(false)
    whisperBox:SetText(XRR.Applications:GetAcceptWhisperTemplate())
    whisperBox:SetScript("OnEnterPressed", function(self)
        XRR.Applications:SetAcceptWhisperTemplate(self:GetText())
        self:ClearFocus()
    end)
    whisperBox:SetScript("OnEditFocusLost", function(self)
        XRR.Applications:SetAcceptWhisperTemplate(self:GetText())
    end)

    -- Same "Insert {x}" placeholder buttons as everywhere else a template
    -- gets filled (Recruitment's Settings/Ads pages) - "anywhere I'm going
    -- to be sending out a text, a whisper, an ad" (2026-09-29).
    local function InsertPlaceholderBtn(label, placeholder, x)
        local btn = Brand.MakeTextLink(content, label, function()
            whisperBox:Insert(placeholder)
            XRR.Applications:SetAcceptWhisperTemplate(whisperBox:GetText())
        end)
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, -94)
        return btn
    end
    local aInsertLink = InsertPlaceholderBtn("Insert {guildlink}", "{guildlink}", 4)
    local aInsertGuild = InsertPlaceholderBtn("Insert {guild}", "{guild}", aInsertLink:GetWidth() + 20)
    InsertPlaceholderBtn("Insert {player}", "{player}", aInsertLink:GetWidth() + aInsertGuild:GetWidth() + 36)

    local pending = XRR.Applications:GetPending()
    if #pending == 0 then
        local msg = content:CreateFontString(nil, "OVERLAY")
        msg:SetFont(Brand.BODY_FONT_PATH, 15, "")
        msg:SetTextColor(0.6, 0.6, 0.6)
        msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -132)
        msg:SetWidth(CONTENT_W)
        msg:SetWordWrap(true)
        msg:SetText("No pending applications right now.")
        return
    end

    -- List starts at the same y=46 the old fixed layout used (right below
    -- the header/divider), but now lives inside a real ScrollFrame instead
    -- of just spilling past the window's bottom edge uncapped (confirmed
    -- via screenshot: 6 real applicants ran straight through the footer).
    -- content's own calculated height leaves only a few px of real clearance
    -- above the footer (nothing else in this window draws all the way down
    -- to content's true bottom edge, so this tightness was never visible
    -- until now) - LIST_BOTTOM_CLEARANCE reserves real, visible separation
    -- instead of letting the scroll area's clip rect run right up against
    -- the footer text (confirmed via screenshot - cards were drawing
    -- straight over "v1.1.0 - by Xal - A Xal's Creation").
    -- Pushed down from the old fixed 46 (2026-09-29) - the auto-whisper
    -- checkbox, template box, and insert-placeholder buttons above now take
    -- real room the list's own scroll area needs to start below, not
    -- overlap.
    local LIST_TOP = 128
    local LIST_BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - LIST_TOP - LIST_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LIST_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(scrollChild)

    local y = 0
    for _, entry in ipairs(pending) do
        BuildApplicationCard(scrollChild, entry, y, CONTENT_W)
        y = y + 100
    end
    scrollChild:SetHeight(math.max(viewportHeight, y))

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
    local header = Brand.FS(content, "Text", Brand.TITLE_FONT_PATH, 24, "OUTLINE",
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local note = Brand.BodyFS(content, "Changes apply immediately. Applies to body text (labels, roster names, descriptions) - not the branded window titles.", 13)
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
        local btn = Brand.MakeTextLink(content, opt.name, function()
            XRR_DB.bodyFontPath = opt.path
            Brand.BODY_FONT_PATH = opt.path
            for _, b in ipairs(fontButtons) do SetLinkSelected(b, b.optKey == opt.key) end
            C_Timer.After(0, function() O:Rebuild() end)
        end)
        btn.optKey = opt.key
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", fx, -y)
        SetLinkSelected(btn, (XRR_DB.bodyFontPath or Brand.BODY_FONT_PATH) == opt.path)
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
        local btn = Brand.MakeTextLink(content, opt.name, function()
            XRR_DB.bodySizeScale = opt.scale
            Brand.BODY_SIZE_SCALE = opt.scale
            for _, b in ipairs(sizeButtons) do SetLinkSelected(b, b.optKey == opt.key) end
            C_Timer.After(0, function() O:Rebuild() end)
        end)
        btn.optKey = opt.key
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", sx, -y)
        SetLinkSelected(btn, (XRR_DB.bodySizeScale or Brand.BODY_SIZE_SCALE) == opt.scale)
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
        local btn = Brand.MakeTextLink(content, opt.name, function()
            XRR_DB.bodyOutline = opt.flag
            Brand.BODY_OUTLINE = opt.flag
            for _, b in ipairs(outlineButtons) do SetLinkSelected(b, b.optKey == opt.key) end
            C_Timer.After(0, function() O:Rebuild() end)
        end)
        btn.optKey = opt.key
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", ox, -y)
        SetLinkSelected(btn, (XRR_DB.bodyOutline or Brand.BODY_OUTLINE) == opt.flag)
        table.insert(outlineButtons, btn)
        ox = ox + 130
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
    note = true, levelup = true, banrejoin = true,
}
local LOG_FILTER_ORDER = { "join", "left", "promote", "demote", "note", "levelup", "banrejoin" }
local LOG_FILTER_LABELS = {
    join = "Joins", left = "Left / Kicked", promote = "Promotions", demote = "Demotions",
    note = "Notes", levelup = "Level Ups", banrejoin = "Bans",
}
local LOG_CATEGORY_COLOR = {
    join = { 0.2, 1, 0.2 },
    left = { 0.6, 0.6, 0.6 },
    promote = Brand.GOLD,
    demote = Brand.ACCENT,
    note = Brand.BODY_TEXT_COLOR,
    levelup = Brand.BODY_TEXT_COLOR,
    banrejoin = Brand.HEADER_COLOR,
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

    -- Search box - applies on Enter/losing focus rather than every
    -- keystroke, same as every other text field on a page that gets fully
    -- rebuilt on refresh (Recruitment's settings fields work the same way)
    -- so typing doesn't get interrupted by the box being recreated out
    -- from under the cursor.
    local searchBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -42)
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

    -- Filter chips - plain toggle links, active ones in the accent color,
    -- inactive ones dimmed, same idea as the mockup's pill chips.
    local prevChip = searchBox
    for _, category in ipairs(LOG_FILTER_ORDER) do
        local active = logActiveFilters[category]
        local chip = Brand.MakeTextLink(content, LOG_FILTER_LABELS[category], function()
            logActiveFilters[category] = not logActiveFilters[category]
            O:RefreshCurrentSection()
        end)
        if not active then
            chip.label:SetTextColor(0.5, 0.5, 0.5, 1)
        end
        chip:SetPoint("LEFT", prevChip, "RIGHT", 12, 0)
        prevChip = chip
    end

    local LOG_TOP = 72
    local LOG_BOTTOM_CLEARANCE = 40
    local viewportHeight = content:GetHeight() - LOG_TOP - LOG_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LOG_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local allEntries = R:GetLog(guild)
    local y = 0
    for _, entry in ipairs(allEntries) do
        if logActiveFilters[entry.category]
            and (logSearchText == "" or entry.text:lower():find(logSearchText, 1, true)) then
            local color = LOG_CATEGORY_COLOR[entry.category] or Brand.BODY_TEXT_COLOR
            local textFs = body:CreateFontString(nil, "OVERLAY")
            textFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            textFs:SetTextColor(color[1], color[2], color[3])
            textFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
            textFs:SetWidth(CONTENT_W - 130)
            textFs:SetJustifyH("LEFT")
            textFs:SetWordWrap(true)
            textFs:SetText(entry.text)

            local timeFs = body:CreateFontString(nil, "OVERLAY")
            timeFs:SetFont(Brand.BODY_FONT_PATH, 12, "")
            timeFs:SetTextColor(0.45, 0.45, 0.45)
            timeFs:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -y)
            timeFs:SetJustifyH("RIGHT")
            timeFs:SetText(LogTimeText(entry.time))

            local rowHeight = math.max(textFs:GetStringHeight(), 14) + 10
            Brand.DrawDivider(body, 4, y + rowHeight - 2, CONTENT_W - 8)
            y = y + rowHeight
        end
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
    footer:SetText("Total Entries: " .. #allEntries)
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

    -- Starts with real clearance, not 0 - the native dropdown's own button
    -- graphic is taller than the row it sits in and bleeds upward past its
    -- anchor point, which clipped straight off on the very first row when
    -- it had nothing above it inside the scroll area (confirmed via
    -- screenshot 2026-09-22).
    local y = 14
    local mains = R:GetMains(guild)
    for _, main in ipairs(mains) do
        -- Locked spec (2026-09-22): no "Confirm as Main"/"(confirmed)"
        -- text at all - a small gold star to the left of the name is the
        -- only main-status indicator. Becoming a Main happens via
        -- right-click on the name -> "Set as Main", not a visible button.
        local star = body:CreateFontString(nil, "OVERLAY")
        star:SetFont(Brand.BODY_FONT_PATH, 13, "")
        star:SetTextColor(Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
        star:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        star:SetText(main.confirmedMain and "*" or "")

        local nameBtn = CreateFrame("Button", nil, body)
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

        local prevWidget = nameBtn
        if main.confirmedMain then
            local alts = R:GetAlts(guild, main.charName)
            if #alts > 0 then
                local toggle = CreateFrame("Button", nil, body)
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

            -- Our own brand-styled dropdown, same as the Roster page's
            -- rank picker - lists everyone currently eligible to become
            -- this main's alt (any other unconfirmed Main, see
            -- R:GetAltCandidates). Shifts over one slot once an alt count
            -- appears, but always sits right after whatever's before it -
            -- never pushed to the far right.
            local candidates = R:GetAltCandidates(guild, main.charName)
            if #candidates > 0 then
                local addAltDropdown = Brand.MakeDropdown(body, 140)
                addAltDropdown:SetPoint("LEFT", prevWidget, "RIGHT", 10, 0)
                addAltDropdown.label:SetText("+ Add Alt")
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
        y = y + 26

        if main.confirmedMain and expandedAlts[main.charName] then
            local alts = R:GetAlts(guild, main.charName)
            if #alts > 0 then
                local boxHeight = #alts * 22 + 8
                local altBox = CreateFrame("Frame", nil, body, "BackdropTemplate")
                altBox:SetSize(220, boxHeight)
                altBox:SetPoint("TOPLEFT", body, "TOPLEFT", 24, -y)
                altBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                altBox:SetBackdropColor(1, 1, 1, 0.04)
                Brand.DrawBorder(altBox, 0)

                local altY = 4
                for _, alt in ipairs(alts) do
                    local altFs = altBox:CreateFontString(nil, "OVERLAY")
                    altFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
                    altFs:SetTextColor(0.8, 0.8, 0.8)
                    altFs:SetPoint("TOPLEFT", altBox, "TOPLEFT", 8, -altY)
                    altFs:SetText(alt.charName)

                    local unlinkBtn = Brand.MakeTextLink(altBox, "Unlink", function()
                        R:UnlinkAlt(guild, alt.charName)
                        O:RefreshCurrentSection()
                    end)
                    unlinkBtn:SetPoint("TOPRIGHT", altBox, "TOPRIGHT", -8, -altY + 3)
                    altY = altY + 22
                end
                y = y + boxHeight + 8
            end
        end
        y = y + 6
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
-- Scan/whisper/invite/post, same shape as GRIP (researched 2026-09-21,
-- read-only reference - the real mechanics live in Recruitment.lua). This
-- page has its own internal Home/Settings/Ads/Stats tab strip, since the
-- feature has too much in it for one flat page.
local recruitSubTab = "Home"

local function RecFieldLabel(parent, text, x, y)
    local fs = Brand.BodyFS(parent, text, 13)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    return fs
end

local function BuildRecruitHome(body, width)
    local Rec = XRR.Recruitment
    local db = Rec:GetDB()
    -- Real clearance, not 0 - same fix as the Mains/Alts list (2026-09-22),
    -- never actually applied to any of the four Recruitment sub-tabs, so
    -- every one of them had its first row's own graphic bleeding upward
    -- into the scroll area's top clip with nothing above it to catch it.
    local y = 14

    local statFs = body:CreateFontString(nil, "OVERLAY")
    statFs:SetFont(Brand.BODY_FONT_PATH, 14, "")
    statFs:SetTextColor(0.85, 0.85, 0.85)
    statFs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    statFs:SetWidth(width)
    local blacklistCount = #Rec:GetBlacklist()
    statFs:SetText(string.format("Candidates: %d   |   Blacklist: %d   |   Whispers today: %d/%d",
        #Rec:GetCandidates(), blacklistCount, Rec:GetDailyWhisperCount(), db.dailyWhisperCap))
    y = y + 30

    local scanBtn = Brand.MakeTextLink(body, "Scan", function()
        Rec:Scan()
    end)
    scanBtn:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)

    local nextBtn = Brand.MakeTextLink(body, "Recruit Next", function()
        Rec:RecruitNext()
        O:RefreshCurrentSection()
    end)
    nextBtn:SetPoint("LEFT", scanBtn, "RIGHT", 20, 0)

    local clearBtn = Brand.MakeTextLink(body, "Clear", function()
        Rec:ClearCandidates()
        O:RefreshCurrentSection()
    end)
    clearBtn:SetPoint("LEFT", nextBtn, "RIGHT", 20, 0)
    y = y + 26

    -- Real sweep progress - Scan only sends ONE band per click (same as
    -- GRIP's own plain Scan, confirmed 2026-09-22), so without this it
    -- would look like the button just isn't finding everyone.
    local queueLen = Rec:GetScanQueueLength()
    local cooldown = Rec:GetScanCooldown()
    local statusParts = {}
    if queueLen > 0 then
        table.insert(statusParts, queueLen .. " band" .. (queueLen == 1 and "" or "s")
            .. " left in this sweep - click Scan again for the next one")
    end
    if cooldown > 0 then
        table.insert(statusParts, "next scan available in " .. cooldown .. "s")
    end
    if #statusParts > 0 then
        local sweepFs = Brand.FS(body, table.concat(statusParts, "  -  "), Brand.BODY_FONT_PATH, 12, "", 0.6, 0.6, 0.6)
        sweepFs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        sweepFs:SetWidth(width)
        sweepFs:SetJustifyH("LEFT")
        sweepFs:SetWordWrap(true)

        -- Real countdown, not a static snapshot of whatever the cooldown
        -- was the instant this page was drawn (2026-09-29 - "it does not
        -- count down"). Self-canceling: stops ticking, then does one real
        -- refresh, the moment it actually hits 0 - not a background timer
        -- left running forever if you navigate away without ever coming
        -- back to see it finish.
        if cooldown > 0 then
            local remaining = cooldown
            local ticker
            ticker = C_Timer.NewTicker(1, function()
                remaining = remaining - 1
                if remaining <= 0 then
                    ticker:Cancel()
                    O:RefreshCurrentSection()
                    return
                end
                local parts = {}
                if queueLen > 0 then
                    table.insert(parts, queueLen .. " band" .. (queueLen == 1 and "" or "s")
                        .. " left in this sweep - click Scan again for the next one")
                end
                table.insert(parts, "next scan available in " .. remaining .. "s")
                sweepFs:SetText(table.concat(parts, "  -  "))
            end)
        end
        y = y + 20
    end
    y = y + 10

    local colWidth = (width - 30) / 2

    -- Left column: candidates.
    RecFieldLabel(body, "Candidates (right-click a row for Invite/Blacklist)", 0, y)
    local candY = y + 22
    local candidates = Rec:GetCandidates()
    if #candidates == 0 then
        local noneFs = Brand.FS(body, "No potential candidates yet. Click Scan to begin.",
            Brand.BODY_FONT_PATH, 13, "", 0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -candY)
        candY = candY + 22
    else
        for _, c in ipairs(candidates) do
            local rowFs = body:CreateFontString(nil, "OVERLAY")
            rowFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            rowFs:SetTextColor(0.9, 0.9, 0.9)
            rowFs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -candY)
            rowFs:SetText(c.charName .. "  |cff777777Lvl " .. c.level .. " " .. c.classStr .. " - " .. c.area .. "|r")

            local whisperBtn = Brand.MakeTextLink(body, "Whisper", function()
                Rec:WhisperCandidate(c.charName, c.fullName)
                O:RefreshCurrentSection()
            end)
            whisperBtn:SetPoint("TOPLEFT", body, "TOPLEFT", colWidth - 130, -candY)

            local inviteBtn = Brand.MakeTextLink(body, "Invite", function()
                Rec:InviteCandidate(c.charName, c.fullName)
                O:RefreshCurrentSection()
            end)
            inviteBtn:SetPoint("LEFT", whisperBtn, "RIGHT", 10, 0)
            candY = candY + 20
        end
    end

    -- Right column: blacklist.
    local blX = colWidth + 30
    RecFieldLabel(body, "Blacklist", blX, y)
    local blY = y + 22
    local bans = Rec:GetBlacklist()
    if #bans == 0 then
        local noneFs = Brand.FS(body, "Blacklist is empty.", Brand.BODY_FONT_PATH, 13, "", 0.6, 0.6, 0.6)
        noneFs:SetPoint("TOPLEFT", body, "TOPLEFT", blX + 4, -blY)
        blY = blY + 22
    else
        for _, b in ipairs(bans) do
            local rowFs = body:CreateFontString(nil, "OVERLAY")
            rowFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            rowFs:SetTextColor(0.85, 0.85, 0.85)
            rowFs:SetPoint("TOPLEFT", body, "TOPLEFT", blX + 4, -blY)
            rowFs:SetWidth(colWidth - 70)
            rowFs:SetJustifyH("LEFT")
            rowFs:SetWordWrap(true)
            rowFs:SetText(b.charName .. "  |cff777777" .. (b.reason ~= "" and b.reason or "no reason given") .. "|r")

            local removeBtn = Brand.MakeTextLink(body, "Remove", function()
                Rec:RemoveFromBlacklist(b.charName)
                O:RefreshCurrentSection()
            end)
            removeBtn:SetPoint("TOPLEFT", body, "TOPLEFT", blX + colWidth - 60, -blY)
            blY = blY + 20
        end
    end

    return math.max(candY, blY)
end

local function BuildRecruitSettings(body, width)
    local db = XRR.Recruitment:GetDB()
    local y = 14 -- same top-clearance fix as BuildRecruitHome above

    RecFieldLabel(body, "Scan Levels", 0, y)
    y = y + 20

    local minBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    minBox:SetSize(50, 20)
    minBox:SetPoint("TOPLEFT", body, "TOPLEFT", 40, -y)
    minBox:SetNumeric(true)
    minBox:SetAutoFocus(false)
    minBox:SetText(tostring(db.scanMin))

    local toFs = Brand.BodyFS(body, "to", 13)
    toFs:SetPoint("LEFT", minBox, "RIGHT", 8, 0)

    local maxBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    maxBox:SetSize(50, 20)
    maxBox:SetPoint("LEFT", toFs, "RIGHT", 8, 0)
    maxBox:SetNumeric(true)
    maxBox:SetAutoFocus(false)
    maxBox:SetText(tostring(db.scanMax))

    local stepLbl = Brand.BodyFS(body, "in bands of", 13)
    stepLbl:SetPoint("LEFT", maxBox, "RIGHT", 16, 0)

    local stepBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    stepBox:SetSize(40, 20)
    stepBox:SetPoint("LEFT", stepLbl, "RIGHT", 8, 0)
    stepBox:SetNumeric(true)
    stepBox:SetAutoFocus(false)
    stepBox:SetText(tostring(db.scanStep))

    local applyBtn = Brand.MakeTextLink(body, "Apply", function()
        db.scanMin = tonumber(minBox:GetText()) or db.scanMin
        db.scanMax = tonumber(maxBox:GetText()) or db.scanMax
        db.scanStep = tonumber(stepBox:GetText()) or db.scanStep
        XRR.Recruitment:ClearCandidates()
    end)
    applyBtn:SetPoint("LEFT", stepBox, "RIGHT", 16, 0)
    y = y + 24

    local stepHint = Brand.BodyFS(body,
        "Scan queries this many levels at a time, starting from the low end - low-level characters are the most likely to still be unguilded, and one huge query either buries them or gets cut off by the game's own result cap.", 12)
    stepHint:SetTextColor(0.55, 0.55, 0.55)
    stepHint:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    stepHint:SetWidth(width)
    stepHint:SetJustifyH("LEFT")
    stepHint:SetWordWrap(true)
    y = y + 34

    local zoneCb = Brand.MakeCheckbox(body, 20)
    zoneCb:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    zoneCb:SetChecked(db.includeCurrentZone)
    zoneCb.OnToggle = function(self) db.includeCurrentZone = self:GetChecked() end
    local zoneLbl = Brand.BodyFS(body, "Include current zone in the scan", 13)
    zoneLbl:SetPoint("LEFT", zoneCb, "RIGHT", 6, 0)
    y = y + 40

    RecFieldLabel(body, "Whisper Template", 0, y)
    y = y + 20

    local whisperBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    whisperBox:SetSize(width - 8, 20)
    whisperBox:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
    whisperBox:SetAutoFocus(false)
    whisperBox:SetText(db.whisperTemplates[1] or "")
    whisperBox:SetScript("OnEnterPressed", function(self)
        db.whisperTemplates[1] = self:GetText()
        self:ClearFocus()
    end)
    whisperBox:SetScript("OnEditFocusLost", function(self) db.whisperTemplates[1] = self:GetText() end)
    y = y + 26

    -- Drops the placeholder in at the cursor instead of making Jason type
    -- the braces by hand - EditBox:Insert(text) is a real Blizzard EditBox
    -- method (confirmed against GRM's own real client code,
    -- GRM_Core.lua:21335, which uses this exact call for the same
    -- insert-at-cursor purpose). Saves immediately after inserting, same as
    -- typing it in and clicking away.
    local function InsertPlaceholderBtn(parent, label, placeholder, x)
        local btn = Brand.MakeTextLink(parent, label, function()
            whisperBox:Insert(placeholder)
            db.whisperTemplates[1] = whisperBox:GetText()
        end)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
        return btn
    end
    local insertGuildLink = InsertPlaceholderBtn(body, "Insert {guildlink}", "{guildlink}", 4)
    local insertGuild = InsertPlaceholderBtn(body, "Insert {guild}", "{guild}", insertGuildLink:GetWidth() + 20)
    InsertPlaceholderBtn(body, "Insert {player}", "{player}", insertGuildLink:GetWidth() + insertGuild:GetWidth() + 36)
    y = y + 26

    local capLabel = Brand.BodyFS(body, "Daily whisper cap", 13)
    capLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    local capBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    capBox:SetSize(60, 20)
    capBox:SetPoint("LEFT", capLabel, "RIGHT", 10, 0)
    capBox:SetNumeric(true)
    capBox:SetAutoFocus(false)
    capBox:SetText(tostring(db.dailyWhisperCap))
    capBox:SetScript("OnEnterPressed", function(self)
        db.dailyWhisperCap = tonumber(self:GetText()) or db.dailyWhisperCap
        self:ClearFocus()
    end)
    capBox:SetScript("OnEditFocusLost", function(self)
        db.dailyWhisperCap = tonumber(self:GetText()) or db.dailyWhisperCap
    end)
    y = y + 30

    return y
end

local function BuildRecruitAds(body, width)
    local Rec = XRR.Recruitment
    local db = Rec:GetDB()
    local y = 14 -- same top-clearance fix as BuildRecruitHome above

    local schedCb = Brand.MakeCheckbox(body, 20)
    schedCb:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    schedCb:SetChecked(db.adSchedulerEnabled)
    schedCb.OnToggle = function(self) db.adSchedulerEnabled = self:GetChecked() end
    local schedLbl = Brand.BodyFS(body, "Remind me to post every interval (posting itself always needs a real click - Blizzard blocks automated channel messages)", 13)
    schedLbl:SetPoint("LEFT", schedCb, "RIGHT", 6, 0)
    schedLbl:SetWidth(width - 30)
    schedLbl:SetJustifyH("LEFT")
    schedLbl:SetWordWrap(true)
    y = y + 40

    local intervalLbl = Brand.BodyFS(body, "Interval (minutes)", 13)
    intervalLbl:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    local intervalBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    intervalBox:SetSize(50, 20)
    intervalBox:SetPoint("LEFT", intervalLbl, "RIGHT", 10, 0)
    intervalBox:SetNumeric(true)
    intervalBox:SetAutoFocus(false)
    intervalBox:SetText(tostring(db.adIntervalMinutes))
    intervalBox:SetScript("OnEnterPressed", function(self)
        db.adIntervalMinutes = tonumber(self:GetText()) or db.adIntervalMinutes
        self:ClearFocus()
    end)
    intervalBox:SetScript("OnEditFocusLost", function(self)
        db.adIntervalMinutes = tonumber(self:GetText()) or db.adIntervalMinutes
    end)
    y = y + 34

    if Rec:IsPostDue() then
        local dueFs = Brand.FS(body, "A post is due - click Post below when you're ready.",
            Brand.BODY_FONT_PATH, 13, "", 1, 0.6, 0.2)
        dueFs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = y + 24
    end

    -- Same "Insert {x}" placeholder buttons as the Settings page's whisper
    -- template (2026-09-29) - drops the placeholder in at the cursor
    -- instead of typing braces by hand. Same three placeholders everywhere
    -- a template gets filled, ads included, even though {player} isn't
    -- addressed to anyone here - keeps every template box in this addon
    -- consistent rather than only some of them getting the shortcut.
    local function InsertPlaceholderBtn(parent, targetBox, saveKey, label, placeholder, x, rowY)
        local btn = Brand.MakeTextLink(parent, label, function()
            targetBox:Insert(placeholder)
            db[saveKey] = targetBox:GetText()
        end)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -rowY)
        return btn
    end

    RecFieldLabel(body, "General Channel Message", 0, y)
    y = y + 20
    local generalBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    generalBox:SetSize(width - 100, 20)
    generalBox:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
    generalBox:SetAutoFocus(false)
    generalBox:SetText(db.adGeneralTemplate)
    generalBox:SetScript("OnEnterPressed", function(self)
        db.adGeneralTemplate = self:GetText()
        self:ClearFocus()
    end)
    generalBox:SetScript("OnEditFocusLost", function(self) db.adGeneralTemplate = self:GetText() end)
    local postGeneralBtn = Brand.MakeTextLink(body, "Post to General", function()
        Rec:PostAd("general")
        O:RefreshCurrentSection()
    end)
    postGeneralBtn:SetPoint("LEFT", generalBox, "RIGHT", 12, 0)
    y = y + 26
    local gInsertLink = InsertPlaceholderBtn(body, generalBox, "adGeneralTemplate", "Insert {guildlink}", "{guildlink}", 4, y)
    local gInsertGuild = InsertPlaceholderBtn(body, generalBox, "adGeneralTemplate", "Insert {guild}", "{guild}", gInsertLink:GetWidth() + 20, y)
    InsertPlaceholderBtn(body, generalBox, "adGeneralTemplate", "Insert {player}", "{player}", gInsertLink:GetWidth() + gInsertGuild:GetWidth() + 36, y)
    y = y + 26

    RecFieldLabel(body, "Trade Channel Message", 0, y)
    y = y + 20
    local tradeBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    tradeBox:SetSize(width - 100, 20)
    tradeBox:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
    tradeBox:SetAutoFocus(false)
    tradeBox:SetText(db.adTradeTemplate)
    tradeBox:SetScript("OnEnterPressed", function(self)
        db.adTradeTemplate = self:GetText()
        self:ClearFocus()
    end)
    tradeBox:SetScript("OnEditFocusLost", function(self) db.adTradeTemplate = self:GetText() end)
    local postTradeBtn = Brand.MakeTextLink(body, "Post to Trade", function()
        Rec:PostAd("trade")
        O:RefreshCurrentSection()
    end)
    postTradeBtn:SetPoint("LEFT", tradeBox, "RIGHT", 12, 0)
    y = y + 26
    local tInsertLink = InsertPlaceholderBtn(body, tradeBox, "adTradeTemplate", "Insert {guildlink}", "{guildlink}", 4, y)
    local tInsertGuild = InsertPlaceholderBtn(body, tradeBox, "adTradeTemplate", "Insert {guild}", "{guild}", tInsertLink:GetWidth() + 20, y)
    InsertPlaceholderBtn(body, tradeBox, "adTradeTemplate", "Insert {player}", "{player}", tInsertLink:GetWidth() + tInsertGuild:GetWidth() + 36, y)
    y = y + 26

    return y
end

local function BuildRecruitStats(body, width)
    local Rec = XRR.Recruitment
    local y = 14 -- same top-clearance fix as BuildRecruitHome above
    local colWidth = (width - 40) / 3

    local function StatCard(title, stats, x)
        local head = Brand.FS(body, title, Brand.TITLE_FONT_PATH, 15, "OUTLINE",
            Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
        head:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
        local rowY = y + 24
        for _, row in ipairs({
            { "Whispers", stats.whispers }, { "Invites", stats.invites },
            { "Posts", stats.posts }, { "Scans", stats.scans },
        }) do
            local fs = body:CreateFontString(nil, "OVERLAY")
            fs:SetFont(Brand.BODY_FONT_PATH, 13, "")
            fs:SetTextColor(0.85, 0.85, 0.85)
            fs:SetPoint("TOPLEFT", body, "TOPLEFT", x, -rowY)
            fs:SetText(row[1] .. ":  |cffe6e6e6" .. row[2] .. "|r")
            rowY = rowY + 20
        end
        return rowY
    end

    local endY = StatCard("Today", Rec:GetTodayStats(), 0)
    StatCard("Last 7 Days", Rec:GetStatsTotals(7), colWidth + 20)
    StatCard("Last 30 Days", Rec:GetStatsTotals(30), (colWidth + 20) * 2)

    return endY
end

local RECRUIT_SUBTABS = { "Home", "Settings", "Ads", "Stats" }

local function BuildRecruitment(content)
    local header = Brand.FS(content, "Recruitment", Brand.TITLE_FONT_PATH, 22, "OUTLINE",
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    Brand.DrawDivider(content, 0, 30, CONTENT_W)

    local x = 0
    for _, name in ipairs(RECRUIT_SUBTABS) do
        local btn = Brand.MakeTextLink(content, name, function()
            recruitSubTab = name
            O:RefreshCurrentSection()
        end)
        SetLinkSelected(btn, recruitSubTab == name)
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, -46)
        x = x + 90
    end

    local SUB_TOP = 76
    local SUB_BOTTOM_CLEARANCE = 20
    local viewportHeight = content:GetHeight() - SUB_TOP - SUB_BOTTOM_CLEARANCE

    local scrollFrame = CreateFrame("ScrollFrame", nil, content)
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -SUB_TOP)
    scrollFrame:SetSize(CONTENT_W, viewportHeight)

    local body = CreateFrame("Frame", nil, scrollFrame)
    body:SetWidth(CONTENT_W)
    scrollFrame:SetScrollChild(body)

    local finalY
    if recruitSubTab == "Settings" then
        finalY = BuildRecruitSettings(body, CONTENT_W)
    elseif recruitSubTab == "Ads" then
        finalY = BuildRecruitAds(body, CONTENT_W)
    elseif recruitSubTab == "Stats" then
        finalY = BuildRecruitStats(body, CONTENT_W)
    else
        finalY = BuildRecruitHome(body, CONTENT_W)
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

sections["About"] = BuildHome
sections["Data"] = BuildData
sections["Guild Master"] = BuildGuildMaster
sections["Officer"] = BuildOfficer
sections["Recruitment"] = BuildRecruitment
sections["Applications"] = BuildApplications
sections["Roster"] = BuildRoster
sections["Log"] = BuildLog
sections["Mains / Alts"] = BuildMainsAlts
sections["Text"] = BuildText
sections["Display"] = BuildDisplay

local activeSection = "Guild Master"

local function ShowSection(name)
    activeSection = name
    for key, btn in pairs(sectionButtons) do
        SetLinkSelected(btn, key == name)
    end
    ClearContent()
    -- The Applications scrollbar lives in the gap between the sidebar
    -- divider and frame.content, NOT inside frame.content itself (so
    -- scrolling the list never drags the sidebar divider or the page
    -- title with it) - which means ClearContent() never touches it. Hide
    -- it here on every switch; BuildApplications re-shows/repositions it
    -- only when there's actually something to scroll.
    if frame.sectionScrollbar then frame.sectionScrollbar:Hide() end
    sections[name](frame.content)
end

-- Lets a page (Guild Master's officer add/remove) redraw itself in place
-- after a click, without needing to know section-switching internals.
function O:RefreshCurrentSection()
    ShowSection(activeSection)
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
    CONTENT_W = startW - (FW - CONTENT_W)
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
        "Guild Master", "Officer", "Recruitment", "Applications", "Roster", "Log", "Mains / Alts",
        "Display", "Text", "Data", "About",
    }
    local y = -32
    for _, name in ipairs(sectionNames) do
        local btn = Brand.MakeTextLink(sidebar, name, function() ShowSection(name) end)
        -- Bumped from the default GameFontHighlightSmall (2026-09-20) - the
        -- sidebar nav text was reading too small next to everything else.
        -- Uses the bundled Inter SemiBold (not Brand.BODY_FONT_PATH's
        -- Regular weight) for real bold - the OUTLINE flag only draws an
        -- outline around the glyphs, it doesn't change the font weight.
        btn.label:SetFont("Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Inter-SemiBold.ttf", 15, "")
        -- Left-justified, flush to a fixed x - was centered within each
        -- button's own (text-length-dependent) width, which staggered
        -- every entry sideways instead of lining them all up under "Home"
        -- (confirmed via screenshot 2026-09-20). A fixed sidebar-width
        -- button with a left-anchored label guarantees the same start
        -- position regardless of how long each name is.
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", btn, "LEFT", 0, 0)
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
                    ShowSection("Applications")
                end
            end)
        end

        y = y - 30
    end

    -- Same live-refresh idea for Recruitment - a scan's results (or the
    -- sweep's next band becoming available) should show up on the page
    -- without needing to leave and come back.
    XRR.Recruitment:OnUpdate(function()
        if activeSection == "Recruitment" then
            ShowSection("Recruitment")
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
                    ShowSection(sectionAtCallTime)
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
