-- GuildPanel.lua
-- Xal's Roster Roundup
--
-- The Roster page's list + profile-detail rendering. Embedded inside the
-- main Options window's "Roster" section (Options.lua draws the page
-- title/guild-info line/divider above this; GuildPanel just fills the rest:
-- search box, member list, and the selected member's profile card).
--
-- Merged into the single main window 2026-09-20 - this used to be its own
-- separate popup frame ("Guild Roster", right-click the minimap button).
-- Confirmed that day: no more standalone window, no more mid-column
-- "Alts" button/tab-switcher (Mains/Alts management is moving to its own
-- sidebar page - this list just shows the roster), and the profile card
-- was rebuilt against a reference screenshot (Last Online/Date Joined/
-- Promoted, a separate Note + Officer's Note, Custom Notes, a read-only
-- Player Alts list).
XRR = XRR or {}
XRR.GuildPanel = {}
local GP = XRR.GuildPanel
local Brand = XRR.BrandStyle
local R = XRR.Roster

-- State: which member is selected, and the live filter text for the
-- search box.
local state = {
    selectedMain = nil,
    memberSearch = "",
}

-- Current profession list (First Aid deliberately excluded - removed in
-- Battle for Azeroth, folded into Tailoring/Alchemy).
local PROFESSION_NAMES = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism",
    "Inscription", "Jewelcrafting", "Leatherworking", "Mining", "Skinning",
    "Tailoring", "Cooking", "Fishing", "Archaeology",
}

-- Fully custom live-filtering autocomplete (typing narrows a visible
-- suggestion list on every keystroke, not silent Tab-only completion).
-- getCandidates(text) returns an array of candidate strings already
-- filtered/sorted by the caller; onSelect(text) fires when a suggestion is
-- clicked. Exposed as GP.AttachAutocomplete so Options.lua's Guild Master
-- page can reuse it for its own "Add Officer" field.
local function AttachAutocomplete(editBox, getCandidates, onSelect)
    local listFrame = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2)
    listFrame:SetWidth(160)
    listFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    listFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
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
                fs:SetFont(Brand.BODY_FONT_PATH, 13, "")
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
    -- Delay the hide one frame and skip it if the mouse is still over the
    -- list, so a click on a suggestion row isn't stranded mid-timing race
    -- against OnEditFocusLost.
    editBox:HookScript("OnEditFocusLost", function()
        C_Timer.After(0, function()
            if not listFrame:IsMouseOver() then
                listFrame:Hide()
            end
        end)
    end)
end
GP.AttachAutocomplete = AttachAutocomplete

-- Real online status + "last online" text, pulled from the actual guild
-- roster (GuildRoster()/GetGuildRosterInfo/GetGuildRosterLastOnline), not
-- just "is this the character I'm logged into" - two accounts can
-- legitimately have two characters online at once.
local onlineLookup = {}
local lastOnlineLookup = {}

local function RefreshOnlineLookup()
    wipe(onlineLookup)
    wipe(lastOnlineLookup)
    if not IsInGuild() then return end
    C_GuildInfo.GuildRoster()
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            local shortName = name:match("^([^-]+)") or name
            local key = shortName:lower()
            onlineLookup[key] = online
            if online then
                lastOnlineLookup[key] = "Online"
            else
                -- GetGuildRosterLastOnline returns years/months/days/hours
                -- since last seen, most-significant-first - show only the
                -- single most meaningful unit rather than all four.
                local years, months, days, hours = GetGuildRosterLastOnline(i)
                if years and years > 0 then
                    lastOnlineLookup[key] = years .. "y ago"
                elseif months and months > 0 then
                    lastOnlineLookup[key] = months .. "mo ago"
                elseif days and days > 0 then
                    lastOnlineLookup[key] = days .. "d ago"
                elseif hours and hours > 0 then
                    lastOnlineLookup[key] = hours .. "h ago"
                else
                    lastOnlineLookup[key] = "Recently"
                end
            end
        end
    end
end

local function IsOnline(charName)
    if not charName then return false end
    return onlineLookup[charName:lower()] or false
end

local function LastOnlineText(charName)
    if not charName then return "-" end
    return lastOnlineLookup[charName:lower()] or "-"
end

-- Module-scope (not tied to any one frame build) so these exist regardless
-- of whether the Roster page has ever been shown this session.
StaticPopupDialogs["XRR_ADD_MEMBER"] = {
    text = "Character name:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        local guild = R:GetCurrentGuild()
        if guild and name and name ~= "" then
            R:AddMember(guild, name)
            state.selectedMain = name
            GP:Refresh()
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- Real, live guild-management actions - gated in BuildProfileFields on the
-- player's own real CanGuildPromote/CanGuildDemote/CanGuildRemove
-- permission (confirmed 2026-09-21, not just R:IsGuildMaster() - officers
-- can genuinely hold these permissions depending on the guild's rank
-- setup, same as Blizzard's own Guild Roster window).
--
-- Seven real, confirmed failures before landing on the actual working
-- mechanism. The Dev-folder copy of GRM used for research all session
-- (D:\WoW_Addons\Dev\XalsGuildCouncil\) turned out to be genuinely broken -
-- a rename from GRM to XALGC changed its own `GRM = {}` table declaration
-- but never updated the thousands of `GRM.` references throughout the rest
-- of the codebase, so large parts of it (including the macro tool) could
-- never actually run as distributed there. Confirmed by reading the REAL,
-- currently-installed, working copy instead
-- (C:\...\_retail_\Interface\AddOns\Guild_Roster_Manager\, read-only
-- reference): `GRM.CreateMacro` (GRM_Core.lua) creates/updates the macro
-- with plain CreateMacro/EditMacro (matching what this file already did),
-- then calls `SetBindingMacro(keyBind, name)` - a real, dedicated Blizzard
-- API specifically for binding a key straight to a macro by name. NOT the
-- generic SetBinding(key, "MACRO name") this file tried before, which
-- registered fine (confirmed via GetBindingKey) but never actually fired
-- when pressed - SetBindingMacro is a genuinely different, more trusted
-- function for this exact purpose.
local ROSTER_MACRO_NAME = "XRRRosterAction"
local ROSTER_HOTKEY = "CTRL-SHIFT-K"

local function SetRosterMacroBody(body)
    local index = GetMacroIndexByName(ROSTER_MACRO_NAME)
    if index and index > 0 then
        EditMacro(index, ROSTER_MACRO_NAME, "INV_MISC_QUESTIONMARK", body)
    else
        CreateMacro(ROSTER_MACRO_NAME, "INV_MISC_QUESTIONMARK", body, nil)
    end
end

-- Only ever binds once - checked by looking up whatever key (if any) is
-- already bound to running this exact macro, not by blindly overwriting a
-- key every time, so it never fights a key the player already set for
-- something else in a later session.
local function EnsureRosterKeybind()
    if GetBindingKey("MACRO " .. ROSTER_MACRO_NAME) then return end
    SetBindingMacro(ROSTER_HOTKEY, ROSTER_MACRO_NAME)
    SaveBindings(GetCurrentBindingSet())
end

-- Plain informational reminder, NOT a button - there is nothing to click
-- here, see the real mechanism explained above. isDone(guild) is checked
-- on every real sync (R:OnSync, registered below) so this closes itself
-- the moment the actual change goes through, instead of
-- the player having to close it by hand.
local reminderFrame

local function GetReminderFrame()
    if reminderFrame then return reminderFrame end

    reminderFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    reminderFrame:SetSize(320, 100)
    reminderFrame:SetFrameStrata("DIALOG")
    Brand.ApplyBackground(reminderFrame)
    Brand.DrawBorder(reminderFrame, 0)

    local label = reminderFrame:CreateFontString(nil, "OVERLAY")
    label:SetFont(Brand.BODY_FONT_PATH, 13, "")
    label:SetTextColor(0.9, 0.9, 0.9)
    label:SetPoint("TOP", reminderFrame, "TOP", 0, -14)
    label:SetWidth(292)
    label:SetHeight(52)
    label:SetWordWrap(true)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("TOP")
    reminderFrame.label = label

    local closeBtn = Brand.MakeTextLink(reminderFrame, "Close", function()
        reminderFrame:Hide()
    end)
    closeBtn:SetPoint("BOTTOM", reminderFrame, "BOTTOM", 0, 10)

    return reminderFrame
end

local function CheckPendingRosterAction()
    local f = reminderFrame
    if not f or not f:IsShown() or not f.isDone then return end
    local guild = R:GetCurrentGuild()
    if guild and f.isDone(guild) then
        f:Hide()
    end
end
R:OnSync(CheckPendingRosterAction)

local function ArmKeybindAction(macroText, labelText, isDone)
    SetRosterMacroBody(macroText)
    EnsureRosterKeybind()
    local key = GetBindingKey("MACRO " .. ROSTER_MACRO_NAME) or ROSTER_HOTKEY
    local f = GetReminderFrame()
    f.isDone = isDone
    -- Shows the exact live macro command right here, not just instructions -
    -- lets you visually confirm the macro you're about to press actually
    -- has the right command in it, without digging through the Macro UI.
    f.label:SetText(labelText .. "\n\nMacro |cffb84d00" .. ROSTER_MACRO_NAME .. "|r now contains: |cff33ccff" .. macroText
        .. "|r\n\nPress |cff33ccff" .. key .. "|r to confirm.")
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:Show()
end

StaticPopupDialogs["XRR_CONFIRM_RANK_CHANGE"] = {
    text = "Change %s's rank to %s?",
    button1 = "Confirm",
    button2 = "Cancel",
    OnAccept = function(_, data)
        local guild = R:GetCurrentGuild()
        if not guild then return end
        local plan = R:GetRankSteps(guild, data.charName, data.targetOrder)
        if not plan then return end
        local verb = plan.direction == "promote" and "Promote" or "Demote"
        ArmKeybindAction("/g" .. plan.direction .. " " .. data.charName,
            string.format("%sing %s (%d step%s)", verb, data.charName, plan.steps, plan.steps == 1 and "" or "s"),
            function(g)
                local m = g.members[data.charName]
                return not m or m.rankOrder == data.targetOrder
            end)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- Kick gets a SECOND confirmation on top of the first - the most
-- destructive action gets extra friction beyond the standard single
-- confirm the others use.
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
    OnAccept = function(_, data)
        ArmKeybindAction("/gremove " .. data, "Removing " .. data .. " from the guild",
            function(g) return not g.members[data] end)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- ── Framework (embedded, not a standalone window) ───────────────────────
local frame

local function CreateFramework(container, width, height)
    frame = CreateFrame("Frame", nil, container)
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

    -- Left column: member list. Width/inset tuned for the narrower embedded
    -- layout (was 240/wide-margin in the old standalone 1000px window).
    local listWidth = 200
    frame.listWidth = listWidth

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(listWidth - 20, 20)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
    searchBox:SetAutoFocus(false)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY")
    searchPlaceholder:SetFont(Brand.BODY_FONT_PATH, 13, "")
    searchPlaceholder:SetTextColor(0.5, 0.5, 0.5)
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
    searchPlaceholder:SetText("Search members...")

    searchBox:SetScript("OnTextChanged", function(self)
        searchPlaceholder:SetShown(self:GetText() == "")
        state.memberSearch = self:GetText():lower()
        GP:Refresh()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    frame.memberSearchBox = searchBox

    local listArea = CreateFrame("Frame", nil, frame)
    listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -34)
    listArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 30)
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

    local addMemberBtn = Brand.MakeTextLink(frame, "+ Add Member", function()
        StaticPopup_Show("XRR_ADD_MEMBER")
    end)
    addMemberBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 0)
    frame.addMemberBtn = addMemberBtn

    -- Vertical divider after the list.
    local LIST_DIVIDER_GAP = 20
    local vDivider = frame:CreateTexture(nil, "ARTWORK")
    vDivider:SetColorTexture(Brand.DIVIDER_COLOR[1], Brand.DIVIDER_COLOR[2], Brand.DIVIDER_COLOR[3], 1)
    vDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", listWidth + LIST_DIVIDER_GAP, 0)
    vDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", listWidth + LIST_DIVIDER_GAP, 0)
    vDivider:SetWidth(Brand.LINE_THICKNESS)

    -- Right column: detail pane (profile card). A real scrollFrame, since a
    -- static height is never actually "enough."
    local detailX = listWidth + LIST_DIVIDER_GAP + Brand.LINE_THICKNESS + 20
    frame.detailX = detailX
    frame.detailWidth = width - detailX - 18
    frame.detailPane = CreateFrame("Frame", nil, frame)
    frame.detailPane:SetPoint("TOPLEFT", frame, "TOPLEFT", detailX, 0)
    frame.detailPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local detailScroll = CreateFrame("ScrollFrame", nil, frame.detailPane)
    detailScroll:SetPoint("TOPLEFT", frame.detailPane, "TOPLEFT", 0, 0)
    detailScroll:SetPoint("BOTTOMRIGHT", frame.detailPane, "BOTTOMRIGHT", -18, 0)

    frame.detailContent = CreateFrame("Frame", nil, detailScroll)
    frame.detailContent:SetSize(1, 1)
    frame.detailContent:SetPoint("TOPLEFT", detailScroll, "TOPLEFT", 0, 0)
    detailScroll:SetScrollChild(frame.detailContent)

    local detailTrack = CreateFrame("Frame", nil, frame.detailPane, "BackdropTemplate")
    detailTrack:SetPoint("TOPRIGHT", frame.detailPane, "TOPRIGHT", 0, 0)
    detailTrack:SetPoint("BOTTOMRIGHT", frame.detailPane, "BOTTOMRIGHT", 0, 0)
    detailTrack:SetWidth(8)
    detailTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    detailTrack:SetBackdropColor(1, 1, 1, 0.08)
    detailTrack:Hide()

    local detailThumb = CreateFrame("Slider", nil, detailTrack)
    detailThumb:SetOrientation("VERTICAL")
    detailThumb:SetPoint("TOP", detailTrack, "TOP", 0, 0)
    detailThumb:SetPoint("BOTTOM", detailTrack, "BOTTOM", 0, 0)
    detailThumb:SetWidth(8)
    detailThumb:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local detailThumbTex = detailThumb:GetThumbTexture()
    detailThumbTex:SetVertexColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    detailThumbTex:SetWidth(8)

    local suppressDetailScrollCallback = false
    detailThumb:SetScript("OnValueChanged", function(_, value)
        if suppressDetailScrollCallback then return end
        detailScroll:SetVerticalScroll(value)
    end)

    detailScroll:EnableMouseWheel(true)
    detailScroll:SetScript("OnMouseWheel", function(_, delta)
        detailThumb:SetValue(detailThumb:GetValue() - delta * 40)
    end)

    function frame.UpdateDetailScrollRange(contentHeight)
        frame.detailContent:SetSize(math.max(1, detailScroll:GetWidth()), math.max(1, contentHeight))
        local visibleHeight = detailScroll:GetHeight()
        local maxScroll = math.max(0, contentHeight - visibleHeight)
        suppressDetailScrollCallback = true
        detailThumb:SetMinMaxValues(0, maxScroll)
        detailThumb:SetValue(0)
        suppressDetailScrollCallback = false
        detailScroll:SetVerticalScroll(0)
        if maxScroll > 0 then
            detailTrack:Show()
            local ratio = math.min(1, visibleHeight / contentHeight)
            detailThumbTex:SetHeight(math.max(20, visibleHeight * ratio))
        else
            detailTrack:Hide()
        end
    end
end

-- ── Left column: member list ────────────────────────────────────────
local rowPool = {}

-- Which mains currently have their alt list dropped open - session-only,
-- same collapsed-by-default pattern as the Mains/Alts page's own
-- expandedAlts (Options.lua).
local expandedRosterAlts = {}

-- List rows use a bare clickable frame with a subtle accent-tinted
-- highlight texture (shown on hover OR when selected), not a boxed button -
-- a boxed button's SetSelected would fight the inline |cff...|r name colors
-- this list uses. A small star sits in its own fixed-width column at the
-- LEFT edge (2026-09-22) for confirmed-Main status - a separate widget, not
-- baked into the name text, so it can't ever wrap onto its own line the
-- way a "* " text prefix did when the row got too narrow. A second column
-- on the right - "N alts" - drops that Main's alts open as their own
-- selectable rows right underneath when clicked; clicking one of those
-- opens its own profile, same as any Main.
local function GetRow(i)
    if not rowPool[i] then
        local rowInset = 12
        local btn = CreateFrame("Button", nil, frame.listContent)
        btn:SetSize(frame.listRowWidth - rowInset * 2, 26)
        btn:SetPoint("TOPLEFT", frame.listContent, "TOPLEFT", rowInset, -(i - 1) * 30)

        local hl = btn:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 0.16)
        hl:Hide()
        btn.highlight = hl

        local star = btn:CreateFontString(nil, "OVERLAY")
        star:SetFont(Brand.BODY_FONT_PATH, 15 * Brand.BODY_SIZE_SCALE, "")
        star:SetTextColor(Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
        star:SetPoint("LEFT", btn, "LEFT", 10, 0)
        star:SetWidth(10)
        star:SetJustifyH("LEFT")
        btn.star = star

        local toggle = CreateFrame("Button", nil, btn)
        toggle:SetSize(50, 26)
        toggle:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
        local toggleFs = toggle:CreateFontString(nil, "OVERLAY")
        toggleFs:SetJustifyH("RIGHT")
        toggleFs:SetPoint("RIGHT", toggle, "RIGHT", 0, 0)
        toggleFs:SetFont(Brand.BODY_FONT_PATH, 12, "")
        toggleFs:SetTextColor(0.7, 0.7, 0.7)
        toggle.label = toggleFs
        toggle:Hide()
        btn.toggle = toggle

        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetJustifyH("LEFT")
        label:SetPoint("LEFT", star, "RIGHT", 2, 0)
        label:SetFont(Brand.BODY_FONT_PATH, 15 * Brand.BODY_SIZE_SCALE, Brand.BODY_OUTLINE)
        btn.label = label

        btn:SetScript("OnEnter", function(self) self.highlight:Show() end)
        btn:SetScript("OnLeave", function(self)
            if not self.selected then self.highlight:Hide() end
        end)
        function btn:SetSelected(selected)
            self.selected = selected
            self.highlight:SetShown(selected)
        end

        rowPool[i] = btn
    end
    return rowPool[i]
end

local function RenderMemberList()
    local guild = R:GetCurrentGuild()
    for _, btn in pairs(rowPool) do btn:Hide() end
    if not guild then
        frame.listContent:SetHeight(1)
        frame.UpdateListScrollRange()
        return
    end

    local mains = R:GetMains(guild)
    if state.memberSearch ~= "" then
        local filtered = {}
        for _, m in ipairs(mains) do
            local nickname = m.nickname or ""
            if m.charName:lower():find(state.memberSearch, 1, true)
                or nickname:lower():find(state.memberSearch, 1, true) then
                table.insert(filtered, m)
            end
        end
        mains = filtered
    end

    -- Name color priority (confirmed 2026-09-20): red for one of the
    -- Guild Master's own characters, orange for an officer, green for a
    -- regular member. Red wins over orange - the rarer, stronger category
    -- (a GM alt that's also flagged as an officer still reads as "this is
    -- one of your own characters" first). Shared by Main rows and alt
    -- sub-rows, so an alt gets the same real color treatment.
    local function NameColor(charName, isOfficer)
        if R:IsGuildMasterFamily(guild, charName) then
            return "|cffff3333"
        elseif isOfficer then
            return "|cffb84d00"
        end
        return "|cff33ff33"
    end

    local function SelectRow(charName)
        state.selectedMain = charName
        -- Opening a profile IS what "reviewed" means - no field-editing
        -- required.
        R:MarkReviewed(guild, charName)
        GP:Refresh()
    end

    local rowIndex = 0
    for _, member in ipairs(mains) do
        rowIndex = rowIndex + 1
        local row = GetRow(rowIndex)

        -- Rows are pooled by index, and an alt sub-row further down uses a
        -- different (indented, no right-side gap) label anchor - reset it
        -- back to the plain Main layout every render, since which pooled
        -- index holds a Main vs. an alt sub-row can change between renders.
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.star, "RIGHT", 2, 0)
        row.label:SetPoint("RIGHT", row.toggle, "LEFT", -4, 0)

        local namePart = NameColor(member.charName, member.isOfficer) .. member.charName .. "|r"
        local label = member.nickname and member.nickname ~= ""
            and (namePart .. "  |cff999999(" .. member.nickname .. ")|r")
            or namePart
        row.label:SetText(label)
        row.star:SetText(member.confirmedMain and "*" or "")
        row:SetSelected(state.selectedMain == member.charName)
        row:SetScript("OnClick", function() SelectRow(member.charName) end)

        local alts = member.confirmedMain and R:GetAlts(guild, member.charName) or {}
        if #alts > 0 then
            row.toggle.label:SetText(#alts .. (expandedRosterAlts[member.charName] and " v" or " >"))
            row.toggle:SetScript("OnClick", function()
                expandedRosterAlts[member.charName] = not expandedRosterAlts[member.charName]
                RenderMemberList()
            end)
            row.toggle:Show()
        else
            row.toggle:Hide()
        end

        row:Show()

        if #alts > 0 and expandedRosterAlts[member.charName] then
            for _, alt in ipairs(alts) do
                rowIndex = rowIndex + 1
                local altRow = GetRow(rowIndex)
                altRow.star:SetText("")
                altRow.toggle:Hide()
                altRow.label:ClearAllPoints()
                altRow.label:SetPoint("LEFT", altRow, "LEFT", 24, 0)
                altRow.label:SetPoint("RIGHT", altRow, "RIGHT", -10, 0)
                altRow.label:SetText(NameColor(alt.charName, alt.isOfficer) .. alt.charName .. "|r")
                altRow:SetSelected(state.selectedMain == alt.charName)
                altRow:SetScript("OnClick", function() SelectRow(alt.charName) end)
                altRow:Show()
            end
        end
    end

    frame.listContent:SetHeight(math.max(1, rowIndex * 30))
    frame.UpdateListScrollRange()
end

-- ── Right column: detail pane (profile card) ────────────────────────
local detailWidgets = {}

local function ClearDetailPane()
    for _, w in ipairs(detailWidgets) do w:Hide() end
    wipe(detailWidgets)
end

local function FieldLabel(parent, text, x, y)
    local fs = Brand.BodyFS(parent, text, 14)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    table.insert(detailWidgets, fs)
    return fs
end

local NOTE_FIELD_LOG_LABELS = { notes = "Note", officerNote = "Officer's Note" }

local function SmallNoteBox(parent, member, guild, field, x, y, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    box:SetAutoFocus(false)
    box:SetText(member[field] or "")
    local function Save(self)
        local newText = self:GetText()
        if newText ~= (member[field] or "") then
            member[field] = newText
            R:AddLogEntry(guild, "note", member.charName .. "'s " .. NOTE_FIELD_LOG_LABELS[field] .. " was updated.")
        end
    end
    box:SetScript("OnEnterPressed", function(self)
        Save(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", Save)
    table.insert(detailWidgets, box)
    return box
end

local function BuildProfileFields(parent, member, guild, width)
    local y = 0

    -- ── Header row: name/nickname/level/status on the left, Last Online/
    -- Date Joined/Promoted on the right, matching the reference layout
    -- confirmed 2026-09-20.
    local nameFs = parent:CreateFontString(nil, "OVERLAY")
    nameFs:SetFont(Brand.TITLE_FONT_PATH, 24, "OUTLINE")
    nameFs:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    nameFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    nameFs:SetText(member.charName)
    table.insert(detailWidgets, nameFs)
    y = y + 30

    if member.nickname and member.nickname ~= "" then
        local quote = Brand.FS(parent, '"' .. member.nickname .. '"', Brand.BODY_FONT_PATH, 14, "",
            Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
        quote:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        table.insert(detailWidgets, quote)
        y = y + 20
    end

    local subline = (member.level and ("Level " .. member.level .. (member.className and (" " .. member.className) or "")) or "")
    local statusFs = Brand.FS(parent, subline, Brand.BODY_FONT_PATH, 13, "", 0.7, 0.7, 0.7)
    statusFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    table.insert(detailWidgets, statusFs)

    local dot = parent:CreateTexture(nil, "OVERLAY")
    dot:SetSize(8, 8)
    dot:SetPoint("LEFT", statusFs, "RIGHT", 10, 1)
    dot:SetColorTexture(IsOnline(member.charName) and 0.2 or 0.4, IsOnline(member.charName) and 1 or 0.4, 0.2, 1)
    table.insert(detailWidgets, dot)
    local statusLabel = Brand.FS(parent, IsOnline(member.charName) and "Online" or "Offline",
        Brand.BODY_FONT_PATH, 13, "", 0.7, 0.7, 0.7)
    statusLabel:SetPoint("LEFT", dot, "RIGHT", 5, 0)
    table.insert(detailWidgets, statusLabel)

    -- Right-aligned stat block.
    local function StatLine(label, value, yy)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFont(Brand.BODY_FONT_PATH, 13, "")
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -yy)
        fs:SetText("|cff777777" .. label .. "  |r" .. value)
        table.insert(detailWidgets, fs)
    end

    -- Same stat line, but the value itself IS the clickable link when
    -- editable (corrected 2026-09-29 - "make the promoted, the birthday,
    -- the date joined, links themselves," confirmed this applies here on
    -- the Roster page too, not just the hover panel) - no separate "Edit"
    -- word/button next to it. Opens the same date picker the hover panel
    -- uses (HoverPanel.lua's OpenDatePicker, researched against GRM's own
    -- real manual-date-entry feature). This addon can only ever catch a
    -- promotion it's actually running and synced for at the moment it
    -- happens - one that happened while you were offline/logged out has no
    -- event for it to see at all, same real limitation GRM has, which is
    -- exactly why a manual override exists.
    local function StatLineEditable(label, value, yy, mode)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetHeight(16)
        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetFont(Brand.BODY_FONT_PATH, 13, "")
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
        -- Embedded |c color codes override SetTextColor for the spans they
        -- wrap, so hover feedback has to rebuild the string with the value
        -- portion recolored, not just call SetTextColor on the whole
        -- FontString (that would silently do nothing here).
        fs:SetText("|cff777777" .. label .. "  |r|cffb84d00" .. value .. "|r")
        btn:SetWidth(fs:GetStringWidth())
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -yy)
        btn:SetScript("OnEnter", function()
            fs:SetText("|cff777777" .. label .. "  |r|cffffffff" .. value .. "|r")
        end)
        btn:SetScript("OnLeave", function()
            fs:SetText("|cff777777" .. label .. "  |r|cffb84d00" .. value .. "|r")
        end)
        btn:SetScript("OnClick", function()
            XRR.HoverPanel:OpenDatePicker(mode, guild, member.charName, btn, function()
                GP:Refresh()
            end)
        end)
        table.insert(detailWidgets, btn)
    end

    -- Date Joined/Promoted read through R:GetJoinDate/GetPromotedDate now
    -- (not member.firstSeenTime/guild.rankChanges directly) so a manual
    -- correction shows up the same way here and on the hover panel.
    StatLine("Last Online", IsOnline(member.charName) and "Now" or LastOnlineText(member.charName), 0)
    local joinTime = R:GetJoinDate(guild, member.charName)
    local promotedTime = R:GetPromotedDate(guild, member.charName)
    local canEditDates = R:HasGMEditAccess(guild) and not R:IsOwnCharacter(member.charName)
    if canEditDates then
        StatLineEditable("Date Joined", joinTime and R.FormatDate(joinTime) or "-", 20, "join")
        StatLineEditable("Promoted", promotedTime and R.FormatDate(promotedTime) or "-", 40, "promoted")
    else
        StatLine("Date Joined", joinTime and R.FormatDate(joinTime) or "-", 20)
        StatLine("Promoted", promotedTime and R.FormatDate(promotedTime) or "-", 40)
    end

    y = y + 26
    Brand.DrawDivider(parent, 0, y, width)
    y = y + 16

    FieldLabel(parent, "Nickname", 0, y)
    y = y + 18
    local nickBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    nickBox:SetSize(220, 20)
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
    y = y + 34

    -- GM data access (notes, Officer's Note, Custom Notes): the real Guild
    -- Master, plus any character the GM has linked into their own
    -- Main/Alt group in this guild. Hidden on your own profile either way.
    if R:HasGMEditAccess(guild) and not R:IsOwnCharacter(member.charName) then
        local halfWidth = (width - 16) / 2

        FieldLabel(parent, "Note", 0, y)
        FieldLabel(parent, "Officer's Note (Guild Master only)", halfWidth + 16, y)
        y = y + 18
        SmallNoteBox(parent, member, guild, "notes", 4, y, halfWidth - 4)
        SmallNoteBox(parent, member, guild, "officerNote", halfWidth + 16, y, halfWidth - 4)
        y = y + 34

        FieldLabel(parent, "Custom Notes", 0, y)
        y = y + 18
        local customBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        customBox:SetSize(width - 8, 20)
        customBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -y)
        customBox:SetAutoFocus(false)
        customBox:SetText(member.customNotes or "")
        local function SaveCustomNotes(self)
            local newText = self:GetText()
            if newText ~= (member.customNotes or "") then
                member.customNotes = newText
                R:AddLogEntry(guild, "note", member.charName .. "'s Custom Notes were updated.")
            end
        end
        customBox:SetScript("OnEnterPressed", function(self)
            SaveCustomNotes(self)
            self:ClearFocus()
        end)
        customBox:SetScript("OnEditFocusLost", SaveCustomNotes)
        table.insert(detailWidgets, customBox)
        y = y + 34
    end

    FieldLabel(parent, "Professions", 0, y)
    -- Birthday moved here (2026-09-29, "move it to the right of
    -- professions") - the top-right stat corner (Last Online/Date Joined/
    -- Promoted) was getting crowded, and Birthday isn't a "when did
    -- something happen" stat like those two, so it reads better as its own
    -- field next to Professions instead of stacked a third line under them.
    local halfWidth = (width - 16) / 2
    FieldLabel(parent, "Birthday", halfWidth + 16, y)
    local birthday = R:GetBirthday(guild, member.charName)
    local birthdayText = birthday and R.FormatBirthday(birthday.day, birthday.month) or "-"
    if canEditDates then
        local bBtn = CreateFrame("Button", nil, parent)
        bBtn:SetHeight(16)
        local bFs = bBtn:CreateFontString(nil, "OVERLAY")
        bFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
        bFs:SetJustifyH("LEFT")
        bFs:SetPoint("LEFT", bBtn, "LEFT", 0, 0)
        -- Same embedded-color-code caveat as the Date Joined/Promoted
        -- links above - SetTextColor alone is a no-op over |c-coded text.
        bFs:SetText("|cffb84d00" .. birthdayText .. "|r")
        bBtn:SetWidth(bFs:GetStringWidth())
        bBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", halfWidth + 16 + 70, -y)
        bBtn:SetScript("OnEnter", function() bFs:SetText("|cffffffff" .. birthdayText .. "|r") end)
        bBtn:SetScript("OnLeave", function() bFs:SetText("|cffb84d00" .. birthdayText .. "|r") end)
        bBtn:SetScript("OnClick", function()
            XRR.HoverPanel:OpenDatePicker("birthday", guild, member.charName, bBtn, function()
                GP:Refresh()
            end)
        end)
        table.insert(detailWidgets, bBtn)
    else
        local bFs = Brand.FS(parent, birthdayText, Brand.BODY_FONT_PATH, 13, "", 0.8, 0.8, 0.8)
        bFs:SetPoint("TOPLEFT", parent, "TOPLEFT", halfWidth + 16 + 70, -y)
        table.insert(detailWidgets, bFs)
    end
    y = y + 18
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
    AttachAutocomplete(prof1Box, ProfessionCandidates, function(name) member.profession1 = name end)
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
    AttachAutocomplete(prof2Box, ProfessionCandidates, function(name) member.profession2 = name end)
    table.insert(detailWidgets, prof2Box)
    y = y + 32

    FieldLabel(parent, "Reason they're here", 0, y)
    y = y + 18
    member.reasons = member.reasons or {}
    local cx = 4
    local REASON_KEYS = { "Raid", "Dungeon", "Achievements", "Mounts", "Community" }
    for _, key in ipairs(REASON_KEYS) do
        local cb = Brand.MakeCheckbox(parent, 20)
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, -y)
        cb:SetChecked(member.reasons[key] or false)
        cb.OnToggle = function(self) member.reasons[key] = self:GetChecked() end
        table.insert(detailWidgets, cb)

        local lbl = Brand.BodyFS(parent, key, 14)
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        table.insert(detailWidgets, lbl)

        cx = cx + 24 + lbl:GetStringWidth() + 14
    end
    y = y + 32

    -- Player Alts - click one to open its own profile (2026-09-22 - "I
    -- can't access any of the alts because of how you have it set up").
    -- Assigning/linking mains and alts still happens on its own "Mains /
    -- Alts" sidebar page - this is just the fastest way to actually get to
    -- an alt's own profile from wherever you already are.
    if member.isMain then
        FieldLabel(parent, "Player Alts", 0, y)
        y = y + 18
        local alts = R:GetAlts(guild, member.charName)
        if #alts == 0 then
            local noneFs = Brand.FS(parent, "No alts linked yet.", Brand.BODY_FONT_PATH, 13, "", 0.6, 0.6, 0.6)
            noneFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -y)
            table.insert(detailWidgets, noneFs)
            y = y + 20
        else
            local ax = 4
            for _, alt in ipairs(alts) do
                local online = IsOnline(alt.charName)
                local chip = CreateFrame("Button", nil, parent)
                local chipFs = chip:CreateFontString(nil, "OVERLAY")
                chipFs:SetFont(Brand.BODY_FONT_PATH, 13, "")
                chipFs:SetTextColor(online and 0.2 or 0.55, online and 1 or 0.55, online and 0.2 or 0.55)
                chipFs:SetPoint("LEFT", 0, 0)
                chipFs:SetText(alt.charName)
                chip:SetSize(chipFs:GetStringWidth(), 16)
                chip:SetPoint("TOPLEFT", parent, "TOPLEFT", ax, -y)
                chip:SetScript("OnClick", function()
                    state.selectedMain = alt.charName
                    R:MarkReviewed(guild, alt.charName)
                    GP:Refresh()
                end)
                chip:SetScript("OnEnter", function() chipFs:SetTextColor(1, 1, 1) end)
                chip:SetScript("OnLeave", function()
                    chipFs:SetTextColor(online and 0.2 or 0.55, online and 1 or 0.55, online and 0.2 or 0.55)
                end)
                table.insert(detailWidgets, chip)
                ax = ax + chip:GetWidth() + 22
                if ax > width - 80 then
                    ax = 4
                    y = y + 20
                end
            end
            y = y + 24
        end
    end

    -- Real guild-management actions - gated on the player's own ACTUAL
    -- permission (CanGuildPromote/CanGuildDemote/CanGuildRemove, real
    -- Blizzard globals confirmed against the client's own GuildRoster.lua),
    -- not just R:IsGuildMaster(). Confirmed 2026-09-21: an officer's rank
    -- can genuinely hold these permissions too, same as the real Guild
    -- Roster window itself - locking this to the GM alone was wrong.
    local canPromoteOrDemote = (CanGuildPromote and CanGuildPromote()) or (CanGuildDemote and CanGuildDemote())
    local canRemove = CanGuildRemove and CanGuildRemove()
    if not R:IsOwnCharacter(member.charName) and (canPromoteOrDemote or canRemove) then
        if canPromoteOrDemote then
            FieldLabel(parent, "Rank", 0, y)
            y = y + 18

            -- Officers can only promote/demote someone to a rank BELOW
            -- their own (confirmed 2026-09-21, and matches Blizzard's own
            -- real client-side rule in GuildRoster.lua) - the Guild Master
            -- (myRankOrder 1) has no such ceiling. Filtering the list here
            -- keeps the dropdown from offering choices the server would
            -- just silently reject anyway.
            local _, _, myRankIndex = GetGuildInfo("player")
            local myRankOrder = (myRankIndex or 0) + 1
            local availableRanks = {}
            for _, rank in ipairs(R.GetGuildRankNames()) do
                if myRankOrder == 1 or rank.order > myRankOrder then
                    table.insert(availableRanks, rank)
                end
            end

            -- Our own brand-styled dropdown (Brand.MakeDropdown), not
            -- Blizzard's native one - this addon leans on our own styled
            -- widgets over Blizzard's stock ones wherever we already have
            -- one (confirmed 2026-09-22), same widget XalsQuestCompass,
            -- Reins, and Compendium already use for their own dropdowns.
            local rankDropdown = Brand.MakeDropdown(parent, 160)
            rankDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
            local rankOptions = {}
            for _, rank in ipairs(availableRanks) do
                table.insert(rankOptions, { key = rank.order, name = rank.name })
            end
            rankDropdown:SetOptions(rankOptions)
            -- Their current rank may not be in this filtered list at all
            -- (an officer only ever sees ranks below their own) - set the
            -- label to their real rank name first, then let SetValue
            -- overwrite it only if a genuine match exists in the list.
            rankDropdown.label:SetText(member.rankName or "?")
            rankDropdown:SetValue(member.rankOrder)
            rankDropdown.OnSelect = function(targetOrder)
                local rank = R.GetGuildRankNames()
                local rankName = "?"
                for _, r in ipairs(rank) do
                    if r.order == targetOrder then rankName = r.name end
                end
                StaticPopup_Show("XRR_CONFIRM_RANK_CHANGE", member.charName, rankName,
                    { charName = member.charName, targetOrder = targetOrder })
            end
            table.insert(detailWidgets, rankDropdown)
            y = y + 40
        end

        if canRemove then
            local kickBtn = Brand.MakeTextLink(parent, "Kick from Guild", function()
                StaticPopup_Show("XRR_CONFIRM_KICK", member.charName, nil, member.charName)
            end)
            kickBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
            table.insert(detailWidgets, kickBtn)
            y = y + 32
        end
    end

    return y
end

local function RenderDetailPane()
    ClearDetailPane()
    local guild = R:GetCurrentGuild()
    local parent = frame.detailContent
    if not guild or not state.selectedMain or not guild.members[state.selectedMain] then
        frame.UpdateDetailScrollRange(1)
        return
    end

    local member = guild.members[state.selectedMain]
    local contentHeight = BuildProfileFields(parent, member, guild, frame.detailWidth)
    frame.UpdateDetailScrollRange(contentHeight)
end

function GP:Refresh()
    if not frame then return end
    RefreshOnlineLookup()
    RenderMemberList()
    RenderDetailPane()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if frame and frame:IsShown() then GP:Refresh() end
end)

-- Called from Options.lua's Roster section every time it's shown. The
-- frame is built once and reused - Options' ClearContent() unparents/hides
-- every child of frame.content on each section switch, so this always
-- re-attaches and re-shows it rather than assuming it's already in place.
function GP:Build(container, width, height)
    if not frame then
        CreateFramework(container, width, height)
    else
        frame:SetParent(container)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        frame:SetSize(width, height)
        -- The detail pane itself is already anchor-stretched to frame's
        -- own edges, so it resizes for free - but frame.detailWidth (used
        -- for text-wrap/field widths inside BuildProfileFields) was only
        -- ever calculated once at creation, so it stayed stuck at the
        -- window's original size on every resize after the first
        -- (2026-09-22, "it all needs to be for auto adjusting").
        frame.detailWidth = width - frame.detailX - 18
    end
    frame:Show()
    GP:Refresh()
    return frame
end
