-- GuildPanel.lua
-- Xal's Roster Roundup
--
-- The Guild Management panel (right-click on the minimap button). Three
-- columns: a condensed list of Mains on the left, a slim button column in
-- the middle (an "Alts" button appears only for Mains that actually have
-- alts linked, blank otherwise), and a detail pane on the right showing
-- whichever member/alt is currently selected. Clicking a Main's "Alts"
-- button switches the detail pane into "alts view," which shows the same
-- profile layout but with a tab strip on top to flip between that Main's
-- individual alts.
XRR = XRR or {}
XRR.GuildPanel = {}
local GP = XRR.GuildPanel
local Brand = XRR.BrandStyle
local R = XRR.Roster

-- This is a DATA panel - sized generously (1000 wide, up from 700) so the
-- layout fits what's actually in it instead of cramming content into a
-- fixed narrow width. The extra width flows into the detail pane on the
-- right (that anchors to the frame's own right edge already, so widening
-- the frame widens it automatically - no other layout math needed).
local FW, FH = 1000, 520
local frame

-- State: which guild tab is active, which member is selected, and (if in
-- alts view) which of that member's alts is the active tab.
local state = {
    guildIndex = 1,
    selectedMain = nil,
    altsView = false,
    selectedAlt = nil,
    addingAltFor = nil, -- charName of whoever's inline "+Add Alt" field is open
}

local REASON_KEYS = { "Raid", "Dungeon", "Achievements", "Mounts", "Community" }

-- Current profession list (confirmed 2026-08-12 - First Aid was removed in
-- Battle for Azeroth, folded into Tailoring/Alchemy, so it's deliberately
-- NOT in this list). Used for Tab-to-autocomplete on the Professions field.
local PROFESSION_NAMES = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism",
    "Inscription", "Jewelcrafting", "Leatherworking", "Mining", "Skinning",
    "Tailoring", "Cooking", "Fishing", "Archaeology",
}

-- Fully custom live-filtering autocomplete (NOT Blizzard's native anything)
-- - confirmed 2026-08-12: typing narrows a visible suggestion list on every
-- keystroke ("I type B, all the B's cascade down, I add L, all the BL's
-- cascade down"), not silent Tab-only completion (that was tried first and
-- rejected as not matching what was asked). getCandidates(text) returns an
-- array of candidate strings already filtered/sorted by the caller;
-- onSelect(text) fires when a suggestion is clicked.
local function AttachAutocomplete(editBox, getCandidates, onSelect)
    local listFrame = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2)
    listFrame:SetWidth(160)
    listFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    listFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    -- FOUR separate thin edge textures, not one texture spanning almost the
    -- entire frame - that earlier version rendered as a solid gold block
    -- instead of a thin outline (same bug independently caught and fixed in
    -- the right-click context menu's border - this is the SAME mistake in a
    -- different piece of code, confirmed 2026-08-12: "that color scheme...
    -- you made it on every single thing that has a drop down").
    local thick = Brand.LINE_THICKNESS
    local ar, ag, ab = Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3]
    local lTop = listFrame:CreateTexture(nil, "ARTWORK")
    lTop:SetColorTexture(ar, ag, ab, 1)
    lTop:SetPoint("TOPLEFT", listFrame, "TOPLEFT", -thick, thick)
    lTop:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", thick, thick)
    lTop:SetHeight(thick)
    local lBottom = listFrame:CreateTexture(nil, "ARTWORK")
    lBottom:SetColorTexture(ar, ag, ab, 1)
    lBottom:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", -thick, -thick)
    lBottom:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", thick, -thick)
    lBottom:SetHeight(thick)
    local lLeft = listFrame:CreateTexture(nil, "ARTWORK")
    lLeft:SetColorTexture(ar, ag, ab, 1)
    lLeft:SetPoint("TOPLEFT", listFrame, "TOPLEFT", -thick, thick)
    lLeft:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", -thick, -thick)
    lLeft:SetWidth(thick)
    local lRight = listFrame:CreateTexture(nil, "ARTWORK")
    lRight:SetColorTexture(ar, ag, ab, 1)
    lRight:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", thick, thick)
    lRight:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", thick, -thick)
    lRight:SetWidth(thick)
    listFrame:SetFrameStrata("TOOLTIP")
    listFrame:Hide()

    local rowBtns = {}
    local ROW_H = 20
    local MAX_ROWS = 8

    local function UpdateList()
        local text = editBox:GetText()
        local candidates = text ~= "" and getCandidates(text) or {}
        for _, b in ipairs(rowBtns) do b:Hide() end

        if #candidates == 0 then
            listFrame:Hide()
            return
        end

        for i = 1, math.min(#candidates, MAX_ROWS) do
            local name = candidates[i]
            local btn = rowBtns[i]
            if not btn then
                btn = CreateFrame("Button", nil, listFrame)
                btn:SetHeight(ROW_H)
                btn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 3, -(i - 1) * ROW_H - 3)
                btn:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -3, -(i - 1) * ROW_H - 3)
                local fs = btn:CreateFontString(nil, "OVERLAY")
                fs:SetFont("Fonts\\ARIALN.TTF", 13, "")
                fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
                fs:SetTextColor(0.9, 0.9, 0.9)
                btn.text = fs
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(1, 1, 1, 0.15)
                rowBtns[i] = btn
            end
            btn.text:SetText(name)
            btn:SetScript("OnMouseDown", function()
                editBox:SetText(name)
                editBox:ClearFocus()
                listFrame:Hide()
                if onSelect then onSelect(name) end
            end)
            btn:Show()
        end

        listFrame:SetHeight(math.min(#candidates, MAX_ROWS) * ROW_H + 6)
        listFrame:Show()
    end

    editBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput then UpdateList() end
    end)
    -- OnMouseDown (not OnClick) on the suggestion rows fires before
    -- OnEditFocusLost hides the list, so a click actually registers instead
    -- of the list disappearing out from under the cursor first.
    editBox:HookScript("OnEditFocusLost", function() listFrame:Hide() end)
end

-- Exposed so Options.lua's Guild Master page can reuse the exact same
-- live-filtering autocomplete for its "Add Officer" field instead of
-- duplicating this component - GuildPanel.lua loads before Options.lua
-- (see the .toc), so this is safely available by the time Options builds.
GP.AttachAutocomplete = AttachAutocomplete

-- Real online status pulled from the actual guild roster (GuildRoster()/
-- GetGuildRosterInfo), not just "is this the character I'm logged into" -
-- two people can legitimately have two accounts logged in at once (or one
-- person running two accounts), so this reflects the real API state rather
-- than special-casing "only one character can be online."
local onlineLookup = {}

local function RefreshOnlineLookup()
    wipe(onlineLookup)
    if not IsInGuild() then return end
    C_GuildInfo.GuildRoster()
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            local shortName = name:match("^([^-]+)") or name
            onlineLookup[shortName:lower()] = online
        end
    end
end

local function IsOnline(charName)
    if not charName then return false end
    return onlineLookup[charName:lower()] or false
end

local function CreateFramework()
    frame = CreateFrame("Frame", "XRRGuildPanel", UIParent, "BackdropTemplate")
    frame:SetSize(FW, FH)
    -- Distinct default position (NOT identical to Options' point) - reverting
    -- both windows to plain bare "CENTER" with zero offset was the actual
    -- bug (spawns them at the literal same coordinate) - confirmed
    -- 2026-08-12. This is a fully independent, opaque, self-contained frame
    -- like any other addon window - freely movable afterward, meant to be
    -- draggable on top of Options (or vice versa) without issue.
    frame:SetPoint("CENTER", UIParent, "CENTER", 140, -60)
    -- Closes on Escape, same as Blizzard's own windows - confirmed
    -- 2026-08-12. Requires the frame to have a global name (set above via
    -- CreateFrame's 2nd arg, "XRRGuildPanel") for UISpecialFrames to find it.
    tinsert(UISpecialFrames, "XRRGuildPanel")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- Distinct frame strata from Options (which uses "HIGH") - a real,
    -- separate WoW render layer (BACKGROUND < LOW < MEDIUM < HIGH < DIALOG <
    -- FULLSCREEN < FULLSCREEN_DIALOG < TOOLTIP), not just draw-order-by-
    -- creation-sequence, so this is guaranteed to render above Options
    -- regardless of which one opened last.
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    -- Any editbox this panel opened closes with it - on OnHide, not just the
    -- close button's OnClick, so this covers every way the panel can close
    -- (X button, ESC, anything else), not just one path. Confirmed
    -- 2026-08-12: "if there's an editbox still up, it needs to close with
    -- it." Add Member is still a real StaticPopup; Add Alt is now inline
    -- (state.addingAltFor), so it just gets reset instead.
    frame:SetScript("OnHide", function()
        StaticPopup_Hide("XRR_ADD_MEMBER")
        StaticPopup_Hide("XRR_CONFIRM_PROMOTE")
        StaticPopup_Hide("XRR_CONFIRM_DEMOTE")
        StaticPopup_Hide("XRR_CONFIRM_KICK")
        StaticPopup_Hide("XRR_CONFIRM_KICK_FINAL")
        state.addingAltFor = nil
    end)

    Brand.ApplyBackground(frame)
    Brand.DrawBorder(frame, 6)

    Brand.Title(frame, "Guild Roster", 32, "TOP", frame, "TOP", 0, -20)
    Brand.DrawDivider(frame, Brand.SAFE_MARGIN, 80, FW - Brand.SAFE_MARGIN * 2)

    local closeBtn = Brand.MakeButton(frame, "X", 24, 24, function() frame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Brand.SAFE_MARGIN, -Brand.SAFE_MARGIN)

    -- Current guild + Guild Master, right under the header divider. Green
    -- (same tone as the online-status dots), not the dim grey body-text
    -- color - confirmed 2026-08-12.
    frame.guildInfoText = frame:CreateFontString(nil, "OVERLAY")
    frame.guildInfoText:SetFont("Fonts\\ARIALN.TTF", 16, "")
    frame.guildInfoText:SetTextColor(0.2, 0.9, 0.3)
    frame.guildInfoText:SetPoint("TOPLEFT", frame, "TOPLEFT", Brand.SAFE_MARGIN, -92)

    -- Guild tab row (only populated/shown when >1 guild exists). Shifted
    -- down from -96 to -122 to leave real room for the guild-info line above
    -- it instead of crowding the two together.
    -- No manual "+Add Guild" button - SyncFromLiveGuild (Roster.lua) already
    -- auto-creates/finds the guild tab for whichever real guild you're
    -- currently in every time this panel opens or the roster updates, so a
    -- manual add would just be a redundant, confusing second path to the
    -- same thing (removed 2026-08-12).
    frame.guildTabs = CreateFrame("Frame", nil, frame)
    frame.guildTabs:SetPoint("TOPLEFT", frame, "TOPLEFT", Brand.SAFE_MARGIN, -122)
    frame.guildTabs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Brand.SAFE_MARGIN, -122)
    frame.guildTabs:SetHeight(26)
    frame.guildTabButtons = {}

    -- Body top starts below the (possibly hidden) tab row.
    local bodyTop = -156

    -- Left column: Main member list. Widened from 190 to 240 for real
    -- breathing room (2026-08-12), and using the same custom thin
    -- accent-gold scrollbar technique as Quest Compass's Font section
    -- (CreateScrollableSection there) instead of Blizzard's native
    -- arrow-button scrollbar, which read visually mismatched against the
    -- rest of the brand - a native Slider drives scrolling (reliable drag
    -- physics for free), just restyled, not Blizzard's default art. Track
    -- auto-hides when the list is short enough not to need it.
    -- Extra left inset (SAFE_MARGIN + 26, not just SAFE_MARGIN) so the list
    -- has real visible clearance from the window border - SAFE_MARGIN alone
    -- read as "way too close to the left edge" in-game (2026-08-12).
    local listWidth = 240
    local listLeftInset = Brand.SAFE_MARGIN + 26
    local listArea = CreateFrame("Frame", nil, frame)
    listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", listLeftInset, bodyTop)
    listArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", listLeftInset, Brand.SAFE_MARGIN + 24)
    listArea:SetWidth(listWidth)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listArea)
    scrollFrame:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", -18, 0)

    local rowWidth = listWidth - 18
    local listContent = CreateFrame("Frame", nil, scrollFrame)
    listContent:SetSize(rowWidth, 1)
    scrollFrame:SetScrollChild(listContent)
    frame.listContent = listContent
    frame.listRowWidth = rowWidth

    local track = CreateFrame("Frame", nil, listArea, "BackdropTemplate")
    track:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", 0, 0)
    track:SetWidth(8)
    track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    track:SetBackdropColor(1, 1, 1, 0.08)
    track:Hide()

    local thumbSlider = CreateFrame("Slider", nil, track)
    thumbSlider:SetOrientation("VERTICAL")
    thumbSlider:SetPoint("TOP", track, "TOP", 0, 0)
    thumbSlider:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
    thumbSlider:SetWidth(8)
    thumbSlider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumbTex = thumbSlider:GetThumbTexture()
    thumbTex:SetVertexColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    thumbTex:SetWidth(8)

    local suppressScrollCallback = false
    thumbSlider:SetScript("OnValueChanged", function(_, value)
        if suppressScrollCallback then return end
        scrollFrame:SetVerticalScroll(value)
    end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        thumbSlider:SetValue(thumbSlider:GetValue() - delta * 40)
    end)

    function frame.UpdateListScrollRange()
        local visibleHeight = scrollFrame:GetHeight()
        local contentHeight = listContent:GetHeight()
        local maxScroll = math.max(0, contentHeight - visibleHeight)
        suppressScrollCallback = true
        thumbSlider:SetMinMaxValues(0, maxScroll)
        thumbSlider:SetValue(0)
        suppressScrollCallback = false
        scrollFrame:SetVerticalScroll(0)
        if maxScroll > 0 then
            track:Show()
            local ratio = math.min(1, visibleHeight / contentHeight)
            thumbTex:SetHeight(math.max(20, visibleHeight * ratio))
        else
            track:Hide()
        end
    end

    local addMemberBtn = Brand.MakeButton(frame, "+ Add Member", listWidth, 24, function()
        StaticPopup_Show("XRR_ADD_MEMBER")
    end)
    addMemberBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", listLeftInset, Brand.SAFE_MARGIN)
    frame.addMemberBtn = addMemberBtn

    -- Vertical divider after the list (same dim divider color as
    -- Brand.DrawDivider, just built vertically since that helper is
    -- horizontal-only). Gap bumped from 8 to 20 - the scrollbar track sits
    -- right at the list's own edge, and 8px read as crowded/touching the
    -- divider rather than clearly separated (2026-08-12).
    local LIST_DIVIDER_GAP = 20
    local vDivider1 = frame:CreateTexture(nil, "ARTWORK")
    vDivider1:SetColorTexture(0.16, 0.12, 0.05, 1)
    vDivider1:SetPoint("TOPLEFT", frame, "TOPLEFT", listLeftInset + listWidth + LIST_DIVIDER_GAP, bodyTop)
    vDivider1:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", listLeftInset + listWidth + LIST_DIVIDER_GAP, Brand.SAFE_MARGIN)
    vDivider1:SetWidth(Brand.LINE_THICKNESS)

    -- Middle column: slim per-row "Alts" button column.
    local midWidth = 46
    local midX = listLeftInset + listWidth + LIST_DIVIDER_GAP + Brand.LINE_THICKNESS + 8
    frame.midContent = CreateFrame("Frame", nil, frame)
    frame.midContent:SetPoint("TOPLEFT", frame, "TOPLEFT", midX, bodyTop)
    frame.midContent:SetSize(midWidth, FH)
    frame.midX = midX
    frame.midWidth = midWidth

    -- Vertical divider before the detail pane.
    local detailX = midX + midWidth + 8
    local vDivider2 = frame:CreateTexture(nil, "ARTWORK")
    vDivider2:SetColorTexture(0.16, 0.12, 0.05, 1)
    vDivider2:SetPoint("TOPLEFT", frame, "TOPLEFT", detailX, bodyTop)
    vDivider2:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", detailX, Brand.SAFE_MARGIN)
    vDivider2:SetWidth(Brand.LINE_THICKNESS)

    -- Right column: detail pane (alt tab strip + profile fields).
    frame.detailPane = CreateFrame("Frame", nil, frame)
    frame.detailPane:SetPoint("TOPLEFT", frame, "TOPLEFT", detailX + 12, bodyTop)
    frame.detailPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Brand.SAFE_MARGIN, Brand.SAFE_MARGIN + 24)

    StaticPopupDialogs["XRR_ADD_MEMBER"] = {
        text = "Character name:",
        button1 = "Add",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self)
            local name = self.EditBox:GetText()
            local guild = R:GetGuild(state.guildIndex)
            if guild and name and name ~= "" then
                R:AddMember(guild, name)
                state.selectedMain = name
                state.altsView = false
                GP:Refresh()
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    -- Real, live guild-management actions - GM-only (gated in the profile
    -- page UI itself via R:IsGuildMaster), never a direct one-click action.
    StaticPopupDialogs["XRR_CONFIRM_PROMOTE"] = {
        text = "Promote %s in the guild?",
        button1 = "Promote",
        button2 = "Cancel",
        OnAccept = function(_, data) C_GuildInfo.Promote(data) end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs["XRR_CONFIRM_DEMOTE"] = {
        text = "Demote %s in the guild?",
        button1 = "Demote",
        button2 = "Cancel",
        OnAccept = function(_, data) C_GuildInfo.Demote(data) end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    -- Kick gets a SECOND confirmation on top of the first (accepting this
    -- one only opens the next popup, doesn't kick anyone yet) - the most
    -- destructive action gets extra friction beyond the standard single
    -- confirm the others use (confirmed 2026-08-12).
    StaticPopupDialogs["XRR_CONFIRM_KICK"] = {
        text = "Remove %s from the guild? This cannot be undone.",
        button1 = "Kick",
        button2 = "Cancel",
        OnAccept = function(_, data)
            StaticPopup_Show("XRR_CONFIRM_KICK_FINAL", data, nil, data)
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs["XRR_CONFIRM_KICK_FINAL"] = {
        text = "Are you sure? %s will be removed from the guild immediately.",
        button1 = "Yes, Kick",
        button2 = "Cancel",
        OnAccept = function(_, data) C_GuildInfo.Uninvite(data) end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
end

local function RenderGuildInfo()
    local guild = R:GetGuild(state.guildIndex)
    if not guild then
        frame.guildInfoText:SetText("")
        return
    end
    local master = guild.masterName or "unknown"
    frame.guildInfoText:SetText("<" .. guild.name .. ">  |cff999999-|r  Guild Master: " .. master)
end

-- ── Guild tabs ───────────────────────────────────────────────────────
local function RenderGuildTabs()
    local guilds = R:GetGuilds()
    for _, btn in ipairs(frame.guildTabButtons) do btn:Hide() end

    if #guilds <= 1 then
        frame.guildTabs:Hide()
        return
    end
    frame.guildTabs:Show()

    local x = 0
    for i, guild in ipairs(guilds) do
        local btn = frame.guildTabButtons[i]
        if not btn then
            btn = Brand.MakeButton(frame.guildTabs, guild.name, 110, 24, function()
                state.guildIndex = i
                state.selectedMain = nil
                state.altsView = false
                GP:Refresh()
            end)
            btn:SetPoint("TOPLEFT", frame.guildTabs, "TOPLEFT", x, 0)
            frame.guildTabButtons[i] = btn
        else
            btn.label:SetText(guild.name)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", frame.guildTabs, "TOPLEFT", x, 0)
        end
        btn:SetSelected(i == state.guildIndex)
        btn:Show()
        x = x + 114
    end
end

-- ── Left column: member list ────────────────────────────────────────
local rowPool = {}
local midButtonPool = {}

local function GetRow(i)
    if not rowPool[i] then
        -- frame.listRowWidth accounts for the scrollbar track's own 18px so
        -- rows never sit underneath/behind it. Row itself is inset 12px on
        -- each side within that (was flush edge-to-edge) so it reads as
        -- centered in the column with real margin, not stretched wall to
        -- wall - confirmed 2026-08-12. Label keeps its own 10px text padding
        -- inside the (now narrower) button.
        local rowInset = 12
        local btn = Brand.MakeButton(frame.listContent, "", frame.listRowWidth - rowInset * 2, 26, nil)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", frame.listContent, "TOPLEFT", rowInset, -(i - 1) * 30)
        btn.label:SetJustifyH("LEFT")
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", btn, "LEFT", 10, 0)
        btn.label:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
        -- Bumped from Brand.MakeButton's default GameFontNormal (~12-14pt)
        -- for readability (2026-08-12), and follows the Text page's font
        -- family/size settings (this call runs once at row-creation, so it
        -- picks up whatever Brand.ApplySavedTheme set at login).
        btn.label:SetFont(Brand.BODY_FONT_PATH, 15 * Brand.BODY_SIZE_SCALE, Brand.BODY_OUTLINE)
        rowPool[i] = btn
    end
    return rowPool[i]
end

local function GetMidButton(i)
    if not midButtonPool[i] then
        local btn = Brand.MakeButton(frame.midContent, "Alts", 40, 26, nil)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", frame.midContent, "TOPLEFT", 0, -(i - 1) * 30)

        local dot = btn:CreateTexture(nil, "OVERLAY")
        dot:SetSize(10, 10)
        dot:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 1, 1)
        dot:SetColorTexture(0.1, 1.0, 0.1, 1)
        dot:Hide()
        btn.onlineDot = dot

        midButtonPool[i] = btn
    end
    return midButtonPool[i]
end

local function RenderMemberList()
    local guild = R:GetGuild(state.guildIndex)
    for _, btn in pairs(rowPool) do btn:Hide() end
    for _, btn in pairs(midButtonPool) do btn:Hide() end
    if not guild then
        frame.listContent:SetHeight(1)
        frame.UpdateListScrollRange()
        return
    end

    local mains = R:GetMains(guild)
    for i, member in ipairs(mains) do
        local row = GetRow(i)
        -- Name color priority: CONFIRMED main (Roster.lua's ConfirmMain)
        -- shows green - confirmed 2026-08-12, replacing an earlier
        -- star-glyph attempt that rendered as a blank box (Friz Quadrata,
        -- WoW's default UI font, has no star character). Otherwise, a
        -- brand-new UNREVIEWED member (nobody's opened their profile yet)
        -- shows orange, so new members stand out at a glance - also
        -- confirmed 2026-08-12. Reviewed, non-confirmed members stay the
        -- normal color.
        local namePart = member.charName
        if member.confirmedMain then
            namePart = "|cff33ff33" .. member.charName .. "|r"
        elseif not member.reviewed then
            namePart = "|cffff8800" .. member.charName .. "|r"
        end
        local label = member.nickname and member.nickname ~= ""
            and (namePart .. "  |cff999999(" .. member.nickname .. ")|r")
            or namePart
        row.label:SetText(label)
        row:SetSelected(state.selectedMain == member.charName)
        row:SetScript("OnClick", function()
            state.selectedMain = member.charName
            state.altsView = false
            state.selectedAlt = nil
            -- Opening a profile IS what "reviewed" means - no field-editing
            -- required (confirmed 2026-08-12).
            R:MarkReviewed(guild, member.charName)
            GP:Refresh()
        end)
        row:Show()

        local alts = R:GetAlts(guild, member.charName)
        local anyOnline = IsOnline(member.charName)
        for _, alt in ipairs(alts) do
            if IsOnline(alt.charName) then anyOnline = true end
        end

        if #alts > 0 then
            local midBtn = GetMidButton(i)
            midBtn:SetScript("OnClick", function()
                state.selectedMain = member.charName
                state.altsView = true
                state.selectedAlt = alts[1] and alts[1].charName or nil
                GP:Refresh()
            end)
            if anyOnline then midBtn.onlineDot:Show() else midBtn.onlineDot:Hide() end
            midBtn:Show()
        end
    end

    frame.listContent:SetHeight(math.max(1, #mains * 30))
    frame.UpdateListScrollRange()
end

-- ── Right column: detail pane ───────────────────────────────────────
local detailWidgets = {}

local function ClearDetailPane()
    for _, w in ipairs(detailWidgets) do w:Hide() end
    wipe(detailWidgets)
end

-- "+Add Alt" control, shared by both places it appears (a Main's own
-- profile page, and the alts-view tab strip). Clicking it opens an inline
-- text field to its RIGHT (button stays visible) with the live-filtering
-- autocomplete attached - not a popup (confirmed 2026-08-12: "it should
-- open up the text box... to the right of the add alt button instead of
-- popping it out... that way it's already inside of that character's
-- box"). state.addingAltFor tracks which main currently has this open so
-- it survives the GP:Refresh() a suggestion-click triggers.
local function CreateAddAltControl(parent, guild, mainCharName, anchorPoint, x, y)
    local btn = Brand.MakeButton(parent, "+ Add Alt", 100, 22, function()
        state.addingAltFor = mainCharName
        GP:Refresh()
    end)
    btn:SetPoint(anchorPoint, parent, anchorPoint, x, y)
    table.insert(detailWidgets, btn)

    if state.addingAltFor == mainCharName then
        local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        editBox:SetSize(140, 20)
        editBox:SetPoint("LEFT", btn, "RIGHT", 10, 0)
        editBox:SetAutoFocus(true)
        table.insert(detailWidgets, editBox)

        local function Commit(name)
            local m = guild.members[name]
            if m and m.isMain and not m.confirmedMain and name ~= mainCharName then
                R:ConvertToAlt(guild, name, mainCharName)
                state.selectedAlt = name
            end
            state.addingAltFor = nil
            GP:Refresh()
        end

        editBox:SetScript("OnEnterPressed", function(self) Commit(self:GetText()) end)
        editBox:SetScript("OnEscapePressed", function()
            state.addingAltFor = nil
            GP:Refresh()
        end)

        AttachAutocomplete(editBox, function(text)
            local out = {}
            for _, m in ipairs(R:GetAltCandidates(guild, mainCharName)) do
                if m.charName:lower():sub(1, #text) == text:lower() then
                    table.insert(out, m.charName)
                    if #out >= 8 then break end
                end
            end
            return out
        end, Commit)

        editBox:SetFocus()
    end
end

local function BuildProfileFields(parent, member, guild, yOffset)
    local y = yOffset

    -- Font bumped 20 -> 24 for readability (2026-08-12).
    local nameLabel = parent:CreateFontString(nil, "OVERLAY")
    nameLabel:SetFont("Fonts\\MORPHEUS.TTF", 24, "OUTLINE")
    nameLabel:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    nameLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    nameLabel:SetText(member.charName)
    table.insert(detailWidgets, nameLabel)

    -- "Main" button, right next to the name - explicitly confirms this
    -- character as a real Main (Roster.lua's ConfirmMain), which permanently
    -- excludes them from ever appearing as an alt candidate for anyone else.
    -- Stays visible and highlighted (SetSelected) once confirmed instead of
    -- disappearing - confirmed 2026-08-12: "it shouldn't totally disappear."
    -- Works both for promoting an existing alt back AND for locking in a
    -- plain default-synced member.
    local mainBtn = Brand.MakeButton(parent, "Main", 60, 22, function()
        R:ConfirmMain(guild, member.charName)
        GP:Refresh()
    end)
    mainBtn:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
    mainBtn:SetSelected(member.confirmedMain)
    table.insert(detailWidgets, mainBtn)
    y = y + 34

    -- Field label font bumped 13 -> 15 for readability (2026-08-12).
    local function FieldLabel(text, yy)
        local fs = Brand.BodyFS(parent, text, 15)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yy)
        table.insert(detailWidgets, fs)
        return fs
    end

    FieldLabel("Nickname", y)
    y = y + 18
    local nickBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    nickBox:SetSize(260, 20)
    nickBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -y)
    nickBox:SetAutoFocus(false)
    nickBox:SetText(member.nickname or "")
    nickBox:SetScript("OnEnterPressed", function(self)
        member.nickname = self:GetText()
        self:ClearFocus()
        GP:Refresh()
    end)
    nickBox:SetScript("OnEditFocusLost", function(self) member.nickname = self:GetText() end)
    table.insert(detailWidgets, nickBox)
    y = y + 32

    FieldLabel("Professions", y)
    y = y + 18
    -- Two independent fields (a character has up to two primary
    -- professions), each with its own live-filtering autocomplete
    -- (AttachAutocomplete) against the real profession list
    -- (PROFESSION_NAMES) - confirmed 2026-08-12.
    local function ProfessionCandidates(text)
        local out = {}
        for _, prof in ipairs(PROFESSION_NAMES) do
            if prof:lower():sub(1, #text) == text:lower() then
                table.insert(out, prof)
            end
        end
        return out
    end

    local prof1Box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    prof1Box:SetSize(125, 20)
    prof1Box:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -y)
    prof1Box:SetAutoFocus(false)
    prof1Box:SetText(member.profession1 or "")
    prof1Box:SetScript("OnEnterPressed", function(self)
        member.profession1 = self:GetText()
        self:ClearFocus()
    end)
    prof1Box:SetScript("OnEditFocusLost", function(self) member.profession1 = self:GetText() end)
    AttachAutocomplete(prof1Box, ProfessionCandidates, function(name)
        member.profession1 = name
    end)
    table.insert(detailWidgets, prof1Box)

    local prof2Box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    prof2Box:SetSize(125, 20)
    prof2Box:SetPoint("LEFT", prof1Box, "RIGHT", 12, 0)
    prof2Box:SetAutoFocus(false)
    prof2Box:SetText(member.profession2 or "")
    prof2Box:SetScript("OnEnterPressed", function(self)
        member.profession2 = self:GetText()
        self:ClearFocus()
    end)
    prof2Box:SetScript("OnEditFocusLost", function(self) member.profession2 = self:GetText() end)
    AttachAutocomplete(prof2Box, ProfessionCandidates, function(name)
        member.profession2 = name
    end)
    table.insert(detailWidgets, prof2Box)
    y = y + 32

    FieldLabel("Reason they're here", y)
    y = y + 18
    member.reasons = member.reasons or {}
    local cx = 4
    for _, key in ipairs(REASON_KEYS) do
        -- Brand.MakeCheckbox - see the note on Options.lua's storage
        -- checkbox for why this replaced native UICheckButtonTemplate.
        local cb = Brand.MakeCheckbox(parent, 20)
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, -y)
        cb:SetChecked(member.reasons[key] or false)
        cb.OnToggle = function(self) member.reasons[key] = self:GetChecked() end
        table.insert(detailWidgets, cb)

        local lbl = Brand.BodyFS(parent, key, 15)
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        table.insert(detailWidgets, lbl)

        -- Next checkbox starts after THIS label's real measured width, not a
        -- fixed guessed step - a fixed 90px step let "Achievements" (wider
        -- than that) overlap straight into "Mounts" (caught in-game
        -- 2026-08-12). 24 = checkbox width(20) + its own 2px gap + 2px
        -- breathing room before the next checkbox.
        cx = cx + 24 + lbl:GetStringWidth() + 14
    end
    y = y + 30

    -- Main/Alt + linked-main are only editable from an alt's own tab (a
    -- Main's identity as "the main" is implicit from being in the left list).
    if not member.isMain then
        FieldLabel("Linked Main", y)
        y = y + 18
        local ddText = member.linkedMain or "(none)"
        local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", parent, "TOPLEFT", -12, -y)
        UIDropDownMenu_SetWidth(dd, 220)
        UIDropDownMenu_SetText(dd, ddText)
        UIDropDownMenu_Initialize(dd, function(self, level)
            local mains = R:GetMains(guild)
            for _, m in ipairs(mains) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = m.charName
                info.func = function()
                    member.linkedMain = m.charName
                    UIDropDownMenu_SetText(dd, m.charName)
                    GP:Refresh()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        table.insert(detailWidgets, dd)
        y = y + 36
    end

    -- A Main can add their first alt directly from their own profile page -
    -- the middle-column "Alts" button only appears once at least one alt
    -- already exists, so this is the only way to create that first one.
    if member.isMain then
        CreateAddAltControl(parent, guild, member.charName, "TOPLEFT", 0, -y)
    end
    y = y + 40

    -- No Remove button - removed entirely 2026-08-12, not just fixed. It
    -- deleted the member from the guild list outright (R:RemoveMember)
    -- rather than any lesser "unset as main" action, and isn't a feature
    -- that's actually needed here.

    -- Guild Master only: private notes + real guild-management actions.
    -- Confirmed 2026-08-12: "to remain safe... the only one that can
    -- actually do editing... should be the Guild Master" - hidden entirely
    -- for everyone else, including on their OWN profile (can't kick/
    -- promote/demote yourself anyway).
    if R:IsGuildMaster() and not R:IsOwnCharacter(member.charName) then
        FieldLabel("Notes (Guild Master only)", y)
        y = y + 18
        local notesBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        notesBox:SetSize(320, 20)
        notesBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -y)
        notesBox:SetAutoFocus(false)
        notesBox:SetText(member.notes or "")
        notesBox:SetScript("OnEnterPressed", function(self)
            member.notes = self:GetText()
            self:ClearFocus()
        end)
        notesBox:SetScript("OnEditFocusLost", function(self) member.notes = self:GetText() end)
        table.insert(detailWidgets, notesBox)
        y = y + 32

        local officerBtn = Brand.MakeButton(parent,
            member.isOfficer and "Remove Officer" or "Make Officer", 130, 22, function()
                R:SetOfficer(guild, member.charName, not member.isOfficer)
                GP:Refresh()
            end)
        officerBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        table.insert(detailWidgets, officerBtn)

        local promoteBtn = Brand.MakeButton(parent, "Promote", 90, 22, function()
            StaticPopup_Show("XRR_CONFIRM_PROMOTE", member.charName, nil, member.charName)
        end)
        promoteBtn:SetPoint("LEFT", officerBtn, "RIGHT", 8, 0)
        table.insert(detailWidgets, promoteBtn)

        local demoteBtn = Brand.MakeButton(parent, "Demote", 90, 22, function()
            StaticPopup_Show("XRR_CONFIRM_DEMOTE", member.charName, nil, member.charName)
        end)
        demoteBtn:SetPoint("LEFT", promoteBtn, "RIGHT", 8, 0)
        table.insert(detailWidgets, demoteBtn)

        -- Kick keeps its double confirmation - accepting the first popup
        -- only opens the second one, doesn't kick anyone yet (confirmed
        -- 2026-08-12, the most destructive action gets extra friction).
        local kickBtn = Brand.MakeButton(parent, "Kick from Guild", 130, 22, function()
            StaticPopup_Show("XRR_CONFIRM_KICK", member.charName, nil, member.charName)
        end)
        kickBtn:SetPoint("LEFT", demoteBtn, "RIGHT", 8, 0)
        table.insert(detailWidgets, kickBtn)
    end
end

local altTabPool = {}

local function RenderDetailPane()
    ClearDetailPane()
    local guild = R:GetGuild(state.guildIndex)
    local parent = frame.detailPane
    if not guild or not state.selectedMain then
        return
    end

    local mainMember = guild.members[state.selectedMain]
    if not mainMember then return end

    if not state.altsView then
        BuildProfileFields(parent, mainMember, guild, 0)
        return
    end

    -- Alts view: tab strip across the top, same profile layout beneath for
    -- whichever alt tab is active.
    local alts = R:GetAlts(guild, state.selectedMain)
    if not state.selectedAlt and alts[1] then state.selectedAlt = alts[1].charName end

    for _, btn in ipairs(altTabPool) do btn:Hide() end
    local x = 0
    for i, alt in ipairs(alts) do
        local btn = altTabPool[i]
        if not btn then
            btn = Brand.MakeButton(parent, "", 100, 24, nil)
            altTabPool[i] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
        btn.label:SetText(alt.charName)
        btn:SetSelected(state.selectedAlt == alt.charName)
        btn:SetScript("OnClick", function()
            state.selectedAlt = alt.charName
            GP:Refresh()
        end)

        if not btn.onlineDot then
            local dot = btn:CreateTexture(nil, "OVERLAY")
            dot:SetSize(10, 10)
            dot:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 1, 1)
            dot:SetColorTexture(0.1, 1.0, 0.1, 1)
            btn.onlineDot = dot
        end
        if IsOnline(alt.charName) then btn.onlineDot:Show() else btn.onlineDot:Hide() end

        table.insert(detailWidgets, btn)
        btn:Show()
        x = x + 104
    end

    CreateAddAltControl(parent, guild, state.selectedMain, "TOPLEFT", x, 0)

    local backBtn = Brand.MakeButton(parent, "< Back to Main", 130, 24, function()
        state.altsView = false
        GP:Refresh()
    end)
    backBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    table.insert(detailWidgets, backBtn)

    local activeAlt = state.selectedAlt and guild.members[state.selectedAlt]
    if activeAlt then
        BuildProfileFields(parent, activeAlt, guild, 40)
    end
end

function GP:Refresh()
    if not frame then return end
    RenderGuildInfo()
    RenderGuildTabs()
    RenderMemberList()
    RenderDetailPane()
end

local eventFrame

-- Pulls in your real guild + roster (see Roster.lua's SyncFromLiveGuild) and
-- jumps the active tab to it if this is the first time it's been seen.
local function SyncAndSelectGuild()
    local syncedGuild = R:SyncFromLiveGuild()
    if not syncedGuild then return end
    local guilds = R:GetGuilds()
    for i, g in ipairs(guilds) do
        if g == syncedGuild then
            state.guildIndex = i
            break
        end
    end
end

function GP:Open()
    if not frame then
        CreateFramework()
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
        eventFrame:SetScript("OnEvent", function()
            RefreshOnlineLookup()
            SyncAndSelectGuild()
            if frame:IsShown() then GP:Refresh() end
        end)
    end
    RefreshOnlineLookup()
    SyncAndSelectGuild()
    GP:Refresh()
    frame:Show()
    frame:Raise()
end

function GP:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        GP:Open()
    end
end
