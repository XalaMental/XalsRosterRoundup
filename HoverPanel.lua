-- HoverPanel.lua
-- Xal's Roster Roundup
--
-- The member hover panel - shows on mouseover, both over a row in our own
-- Roster list (GuildPanel.lua) AND over a row in Blizzard's own native
-- Guild Roster window (see the CommunitiesFrame hook below). Same panel
-- either way, one shared implementation.
--
-- Layout/sizing confirmed against GRM's own real client code
-- (D:\WoW_Addons\Dev\XalsGuildCouncil\GRM_UI.lua, read-only reference,
-- 2026-09-21) rather than eyeballed from a screenshot - GRM's own
-- GRM_MemberDetailMetaData is 400x438, its Note/Officer's Note boxes are
-- 166x53 side by side, Custom Notes is 166x113 under the LEFT column only,
-- and its alt list is 170x150 under the RIGHT column only (two independent
-- columns, not one wide row under both). This panel matches those real
-- proportions - our colors/fonts, their layout, per Jason's explicit ask.
--
-- Note/Officer's Note/Custom Notes are real, editable fields here too
-- (confirmed 2026-09-21 - GRM's own panel is editable from BOTH their own
-- list and Blizzard's native window, not just a read-only preview), gated
-- on the same real GM data-access check the Roster page's own profile card
-- already uses. Everything else on the panel stays display-only.
XRR = XRR or {}
XRR.HoverPanel = {}
local HP = XRR.HoverPanel
local Brand = XRR.BrandStyle
local R = XRR.Roster

local PANEL_W = 400
local COL_W = 166
local NOTE_BOX_H = 53
local CUSTOM_BOX_H = 113
local ALT_LIST_H = 150

local frame

-- Real mechanism GRM uses to stop an in-progress edit from getting
-- clobbered (its own GRM_G.pause, GRM_Core.lua:6188) - while a note box
-- has real edit focus, the hover-tracking poll below must not reassign the
-- panel to a different member out from under you, and the panel must not
-- auto-hide just because your mouse drifted off it while typing.
local editingPaused = false

-- A right-justified label+value line that IS the clickable control when
-- editable - no separate "Edit" word/button next to it (corrected
-- 2026-09-29: "make the promoted, the birthday, the date joined, links
-- themselves"). The value itself is accent-colored and brightens to white
-- on hover, same link convention as every other clickable text in this
-- addon (Brand.MakeTextLink) - just applied to the value text in place
-- rather than a separate label. Plain muted gray, not clickable, when not
-- editable. Date Joined / Promoted / Birthday all use this, since none of
-- the three can be fully trusted from auto-tracking alone (see Roster.lua's
-- SetJoinDateOverride/SetPromotedOverride/SetBirthday, researched against
-- GRM's own real manual-date-entry feature).
local function MakeDateField(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(14)

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Brand.BODY_FONT_PATH, 12, "")
    fs:SetJustifyH("RIGHT")
    fs:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
    btn.fs = fs

    btn.editable = false
    function btn:SetLabelValue(label, value)
        self.label, self.value = label, value
        local valueColor = self.editable and "|cffb84d00" or "|cffcccccc"
        fs:SetText("|cff777777" .. label .. "|r  " .. valueColor .. value .. "|r")
        self:SetWidth(fs:GetStringWidth())
    end
    function btn:SetEditable(editable)
        self.editable = editable
        self:EnableMouse(editable)
        if self.label then self:SetLabelValue(self.label, self.value) end
    end
    -- Embedded |c color codes override SetTextColor for the spans they
    -- wrap, so hover feedback has to rebuild the string with the value
    -- portion recolored, not just call SetTextColor on the whole
    -- FontString (that would silently do nothing here).
    btn:SetScript("OnEnter", function(self)
        if self.editable and self.label then
            fs:SetText("|cff777777" .. self.label .. "|r  |cffffffff" .. self.value .. "|r")
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.editable then self:SetLabelValue(self.label, self.value) end
    end)
    btn:SetScript("OnClick", function(self)
        if self.editable and self.onEdit then self.onEdit() end
    end)
    return btn
end

local function CreatePanel()
    frame = CreateFrame("Frame", "XRRHoverPanel", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_W, 440)
    frame:SetFrameStrata("TOOLTIP")
    -- Real mouse enabled (2026-09-21, was false) - the note/officer's
    -- note/custom notes boxes are genuine EditBoxes now, so the panel has
    -- to actually accept mouse/keyboard input instead of just being a
    -- click-through display.
    frame:EnableMouse(true)
    Brand.ApplyBackground(frame)
    Brand.DrawBorder(frame, 1)
    frame:Hide()

    -- Moving onto the panel itself (to actually edit a note) shouldn't
    -- immediately close it the way leaving the row normally would - Hide()
    -- is only ever called from a deferred check (see ScheduleHide below)
    -- that first confirms the mouse isn't back over the panel.
    frame:SetScript("OnLeave", function() HP:ScheduleHide() end)

    -- Real close control (2026-09-29 - GRM's own panel locks open on a
    -- click and stays that way until you close it; ours had no way to
    -- close it at all before this, since it only ever relied on the
    -- mouse-leave auto-hide). Also clears the lock so hover tracking
    -- resumes normally afterward.
    frame.closeBtn = Brand.MakeTextLink(frame, "Close", function()
        frame.locked = false
        frame:Hide()
    end)
    frame.closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -4)

    frame.lastOnline = Brand.FS(frame, "", Brand.BODY_FONT_PATH, 12, "", 0.7, 0.7, 0.7)
    frame.lastOnline:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -22)

    -- Starts a little lower than before (-14 -> -22) so it doesn't crowd
    -- the new Close link in the same corner.
    frame.dateJoined = MakeDateField(frame)
    frame.dateJoined:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -22)

    frame.promoted = MakeDateField(frame)
    frame.promoted:SetPoint("TOPRIGHT", frame.dateJoined, "BOTTOMRIGHT", 0, -8)

    frame.birthday = MakeDateField(frame)
    frame.birthday:SetPoint("TOPRIGHT", frame.promoted, "BOTTOMRIGHT", 0, -8)

    frame.name = Brand.FS(frame, "", Brand.TITLE_FONT_PATH, 20, "OUTLINE", Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    frame.name:SetPoint("TOP", frame, "TOP", 0, -64)
    frame.name:SetJustifyH("CENTER")

    frame.quote = Brand.FS(frame, "", Brand.BODY_FONT_PATH, 13, "", Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    frame.quote:SetPoint("TOP", frame.name, "BOTTOM", 0, -4)
    frame.quote:SetJustifyH("CENTER")

    frame.subline = Brand.FS(frame, "", Brand.BODY_FONT_PATH, 13, "", 0.8, 0.8, 0.8)
    frame.subline:SetPoint("TOP", frame.quote, "BOTTOM", 0, -6)
    frame.subline:SetJustifyH("CENTER")

    local leftX = 16
    local rightX = PANEL_W - 16 - COL_W
    local colTop = -160

    frame.noteLabel = Brand.BodyFS(frame, "Note", 12)
    frame.noteLabel:SetTextColor(0.55, 0.55, 0.55)
    frame.noteLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", leftX, colTop)

    -- Real editable EditBoxes, not plain text - confirmed 2026-09-21:
    -- GRM's own hover panel lets you edit right from the panel (in
    -- Blizzard's native window too, not just their own), so this needed to
    -- actually be an edit surface, not a read-only preview. Each one saves
    -- straight to the live member record on OnEditFocusLost, same pattern
    -- as the Roster page's own profile card fields.
    local EDIT_FIELD_LOG_LABELS = { notes = "Note", officerNote = "Officer's Note", customNotes = "Custom Notes" }

    local function MakeEditableBox(parent, width, height, saveKey)
        local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        box:SetSize(width, height)
        box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        box:SetBackdropColor(1, 1, 1, 0.04)
        Brand.DrawBorder(box, 0)

        local editBox = CreateFrame("EditBox", nil, box)
        editBox:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
        editBox:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 8)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        -- Real, confirmed cause (2026-09-29, verified against GRM's own
        -- working note boxes, GRM_UI.lua): EnableMouse(true) alone isn't
        -- enough here. This panel sits over Blizzard's own native Guild
        -- Roster window, and a plain child EditBox with no explicit strata
        -- of its own doesn't win mouse-click priority over the native row
        -- buttons underneath it even though it visually draws on top - the
        -- click was going to Blizzard's row, not this box, which is why
        -- data displayed fine (a pure read) but clicking to type never
        -- worked. GRM's own note EditBoxes explicitly raise their strata
        -- for exactly this reason (GRM_UI.lua:2729/2740) - same fix here.
        editBox:SetFrameStrata("HIGH")
        editBox:SetScript("OnEditFocusGained", function() editingPaused = true end)
        editBox:SetScript("OnEditFocusLost", function(self)
            editingPaused = false
            if frame.currentMember and frame.editable then
                local newText = self:GetText()
                if newText ~= (frame.currentMember[saveKey] or "") then
                    frame.currentMember[saveKey] = newText
                    if frame.currentGuild then
                        R:AddLogEntry(frame.currentGuild, "note",
                            frame.currentMember.charName .. "'s " .. EDIT_FIELD_LOG_LABELS[saveKey] .. " was updated.")
                    end
                end
            end
        end)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        box.editBox = editBox
        return box
    end

    frame.noteBox = MakeEditableBox(frame, COL_W, NOTE_BOX_H, "notes")
    frame.noteBox:SetPoint("TOPLEFT", frame.noteLabel, "BOTTOMLEFT", 0, -5)

    frame.customLabel = Brand.BodyFS(frame, "Custom Notes", 12)
    frame.customLabel:SetTextColor(0.55, 0.55, 0.55)
    frame.customLabel:SetPoint("TOPLEFT", frame.noteBox, "BOTTOMLEFT", 0, -10)

    frame.customBox = MakeEditableBox(frame, COL_W, CUSTOM_BOX_H, "customNotes")
    frame.customBox:SetPoint("TOPLEFT", frame.customLabel, "BOTTOMLEFT", 0, -5)

    frame.officerLabel = Brand.BodyFS(frame, "Officer's Note", 12)
    frame.officerLabel:SetTextColor(0.55, 0.55, 0.55)
    frame.officerLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, colTop)

    frame.officerBox = MakeEditableBox(frame, COL_W, NOTE_BOX_H, "officerNote")
    frame.officerBox:SetPoint("TOPLEFT", frame.officerLabel, "BOTTOMLEFT", 0, -5)

    frame.altsLabel = Brand.BodyFS(frame, "Player Alts", 12)
    frame.altsLabel:SetTextColor(0.55, 0.55, 0.55)
    frame.altsLabel:SetPoint("TOPLEFT", frame.officerBox, "BOTTOMLEFT", 0, -10)

    frame.altsBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.altsBox:SetSize(COL_W + 4, ALT_LIST_H)
    frame.altsBox:SetPoint("TOPLEFT", frame.altsLabel, "BOTTOMLEFT", 0, -5)
    frame.altsBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame.altsBox:SetBackdropColor(1, 1, 1, 0.04)
    Brand.DrawBorder(frame.altsBox, 0)
    frame.altTexts = {}

    -- "+ Add Alt" (2026-09-29 - "our player alts needs to be able to add
    -- alts") - same real dropdown/candidate-list mechanism the Mains/Alts
    -- page already uses (Brand.MakeDropdown + R:GetAltCandidates/
    -- R:ConvertToAlt), just placed here too so it doesn't require leaving
    -- this panel to link an alt.
    frame.addAltDropdown = Brand.MakeDropdown(frame, COL_W)
    frame.addAltDropdown.label:SetText("+ Add Alt")
    frame.addAltDropdown:Hide()

    return frame
end

-- member may be nil (Blizzard's own roster can show someone before this
-- addon has synced them yet) - falls back to whatever liveInfo the caller
-- already has (name/level/className) rather than showing a blank panel.
function HP:ShowFor(charName, member, guild, anchorFrame, liveInfo)
    if not frame then CreatePanel() end

    local level = (member and member.level) or (liveInfo and liveInfo.level)
    local className = (member and member.className) or (liveInfo and liveInfo.className)
    local isOnline = liveInfo and liveInfo.isOnline

    frame.name:SetText(charName or "?")
    if member and member.nickname and member.nickname ~= "" then
        frame.quote:SetText('"' .. member.nickname .. '"')
        frame.quote:Show()
    else
        frame.quote:Hide()
    end

    local sublineParts = {}
    if level then table.insert(sublineParts, "Level " .. level .. (className and (" " .. className) or "")) end
    if member and member.rankName then table.insert(sublineParts, '"' .. member.rankName .. '"') end
    if isOnline ~= nil then
        table.insert(sublineParts, isOnline and "|cff33ff33Online|r" or "Offline")
    end
    frame.subline:SetText(table.concat(sublineParts, "  ·  "))

    if isOnline then
        frame.lastOnline:SetText("|cff777777Last Online|r  Now")
    elseif liveInfo and liveInfo.lastOnlineText then
        frame.lastOnline:SetText("|cff777777Last Online|r  " .. liveInfo.lastOnlineText)
    else
        frame.lastOnline:SetText("|cff777777Last Online|r  -")
    end

    -- Real, confirmed root cause (2026-09-29) of "nothing is editable even
    -- as the real Guild Master": `member` was only ever whatever the
    -- caller already had tracked - if this specific member had never been
    -- synced into guild.members for any reason (never opened our own
    -- Roster page, a sync gap, anything), `member` came in nil, which
    -- unconditionally blocked editing below regardless of real GM status -
    -- while the panel still displayed real name/level/class fine, purely
    -- from Blizzard's own live memberInfo (the OTHER data source ShowFor
    -- already falls back to), making it LOOK like data loaded correctly
    -- while editing was silently blocked underneath. Any real guild member
    -- now gets a real tracked record created here on the spot if one
    -- doesn't already exist, the same way a normal roster sync would
    -- eventually create it anyway - editing a member's note should never
    -- depend on whether this specific member happened to already be
    -- cached.
    if guild and not member and charName then
        member = guild.members[charName] or R:AddMember(guild, charName)
    end

    -- Editable only under the same real permission the Roster page's own
    -- profile card already uses (real GM data access, and never on your
    -- own profile). When not editable, the boxes stay visible but blur
    -- focus back off immediately if clicked into.
    frame.currentMember = member
    frame.currentGuild = guild
    frame.editable = guild and member and R:HasGMEditAccess(guild) and not R:IsOwnCharacter(charName)

    local joinTime = guild and member and R:GetJoinDate(guild, charName)
    frame.dateJoined:SetLabelValue("Date Joined", joinTime and R.FormatDate(joinTime) or "-")
    frame.dateJoined:SetEditable(frame.editable)
    frame.dateJoined.onEdit = function()
        HP:OpenDatePicker("join", guild, charName, frame.dateJoined)
    end

    local promotedTime = guild and member and R:GetPromotedDate(guild, charName)
    frame.promoted:SetLabelValue("Promoted", promotedTime and R.FormatDate(promotedTime) or "-")
    frame.promoted:SetEditable(frame.editable)
    frame.promoted.onEdit = function()
        HP:OpenDatePicker("promoted", guild, charName, frame.promoted)
    end

    local birthday = guild and member and R:GetBirthday(guild, charName)
    frame.birthday:SetLabelValue("Birthday", birthday and R.FormatBirthday(birthday.day, birthday.month) or "-")
    frame.birthday:SetEditable(frame.editable)
    frame.birthday.onEdit = function()
        HP:OpenDatePicker("birthday", guild, charName, frame.birthday)
    end

    -- Note/Officer's Note are permanently read-only (corrected 2026-09-29 -
    -- confirmed directly that even GRM's own real Public Note/Officer's
    -- Note can't be edited from that panel; only its Custom Public Note
    -- can). Custom Notes is the one field that's actually ours to make
    -- editable, matching GRM's own real, accepted split - not a bug to
    -- keep chasing on the other two.
    frame.noteBox.editBox:EnableMouse(false)
    frame.noteBox.editBox:SetTextColor(0.55, 0.55, 0.55)
    frame.officerBox.editBox:EnableMouse(false)
    frame.officerBox.editBox:SetTextColor(0.55, 0.55, 0.55)
    frame.customBox.editBox:EnableMouse(frame.editable)
    frame.customBox.editBox:SetTextColor(frame.editable and 0.9 or 0.55, frame.editable and 0.9 or 0.55, frame.editable and 0.9 or 0.55)
    frame.noteBox.editBox:SetText(member and member.notes or "")
    frame.customBox.editBox:SetText(member and member.customNotes or "")
    frame.officerBox.editBox:SetText((frame.editable and member and member.officerNote) or "")

    for _, btn in ipairs(frame.altTexts) do btn:Hide() end
    if guild and member and member.isMain then
        local alts = R:GetAlts(guild, charName)
        local y = -8
        for i, alt in ipairs(alts) do
            local altBtn = frame.altTexts[i]
            if not altBtn then
                -- Real clickable button now (2026-09-29 - "the player alts
                -- don't do nothing... GRM opens right above it") - clicking
                -- an alt re-shows this same panel for THAT character,
                -- matching GRM's own behavior, instead of being inert text.
                altBtn = CreateFrame("Button", nil, frame.altsBox)
                altBtn:SetHeight(16)
                local fs = altBtn:CreateFontString(nil, "OVERLAY")
                fs:SetFont(Brand.BODY_FONT_PATH, 13, "")
                fs:SetPoint("LEFT", altBtn, "LEFT", 0, 0)
                altBtn.fs = fs
                altBtn:SetScript("OnEnter", function(btn) btn.fs:SetTextColor(1, 1, 1, 1) end)
                altBtn:SetScript("OnLeave", function(btn) btn.fs:SetTextColor(0.8, 0.8, 0.8, 1) end)
                frame.altTexts[i] = altBtn
            end
            altBtn:ClearAllPoints()
            altBtn:SetPoint("TOPLEFT", frame.altsBox, "TOPLEFT", 8, y)
            altBtn.fs:SetText(alt.charName)
            altBtn.fs:SetTextColor(0.8, 0.8, 0.8, 1)
            altBtn:SetWidth(altBtn.fs:GetStringWidth())
            local altCharName = alt.charName
            altBtn:SetScript("OnClick", function()
                HP:ShowFor(altCharName, guild.members[altCharName], guild, frame.currentAnchor)
                frame.locked = true
            end)
            altBtn:Show()
            y = y - 18
        end

        -- Same gating as the Mains/Alts page's own Add Alt control -
        -- confirmed Mains only, and only for someone with real edit access.
        if member.confirmedMain and frame.editable then
            local candidates = R:GetAltCandidates(guild, charName)
            if #candidates > 0 then
                frame.addAltDropdown:ClearAllPoints()
                frame.addAltDropdown:SetPoint("TOPLEFT", frame.altsBox, "TOPLEFT", 4, y - 4)
                local altOptions = {}
                for _, candidate in ipairs(candidates) do
                    table.insert(altOptions, { key = candidate.charName, name = candidate.charName })
                end
                frame.addAltDropdown:SetOptions(altOptions)
                frame.addAltDropdown:SetValue(nil)
                frame.addAltDropdown.label:SetText("+ Add Alt")
                local mainCharName = charName
                frame.addAltDropdown.OnSelect = function(altCharName)
                    R:ConvertToAlt(guild, altCharName, mainCharName)
                    HP:ShowFor(mainCharName, guild.members[mainCharName], guild, frame.currentAnchor)
                end
                frame.addAltDropdown:Show()
            else
                frame.addAltDropdown:Hide()
            end
        else
            frame.addAltDropdown:Hide()
        end
    else
        frame.addAltDropdown:Hide()
    end

    frame.currentAnchor = anchorFrame
    HP:RepositionPanel()
    frame:SetClampedToScreen(true)
    frame:Show()
end

-- Real anchor, confirmed 2026-09-29 against GRM's own actual code:
-- Blizzard's native note/officer-note/remove/invite popup that appears on
-- a row click is CommunitiesFrame.GuildMemberDetailFrame - a real child of
-- CommunitiesFrame, not a separate/older frame system. GRM anchors its own
-- panel to THIS frame's top-right corner when it's showing, tucking in
-- right next to it, and falls back to anchoring off CommunitiesFrame's own
-- top-right corner when that native popup isn't up yet. Same two-case
-- logic here, independently implemented.
--
-- Pulled out into its own function and re-run continuously (see the
-- reposition ticker below) rather than only once when the panel opens -
-- confirmed 2026-09-29: closing Blizzard's native popup while ours stays
-- open (it's locked) needs ours to fall back to the CommunitiesFrame
-- anchor on its own, not stay frozen wherever it first opened.
function HP:RepositionPanel()
    if not frame or not frame:IsShown() then return end
    frame:ClearAllPoints()
    local nativePopup = CommunitiesFrame and CommunitiesFrame.GuildMemberDetailFrame
    if nativePopup and nativePopup:IsVisible() then
        frame:SetPoint("TOPLEFT", nativePopup, "TOPRIGHT", -4, 5)
    elseif CommunitiesFrame and CommunitiesFrame:IsVisible() then
        frame:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 34, 5)
    elseif frame.currentAnchor then
        frame:SetPoint("TOPLEFT", frame.currentAnchor, "TOPRIGHT", 12, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local repositionElapsed = 0
local repositionTickerFrame = CreateFrame("Frame")
repositionTickerFrame:SetScript("OnUpdate", function(_, elapsed)
    repositionElapsed = repositionElapsed + elapsed
    if repositionElapsed < 0.2 then return end
    repositionElapsed = 0
    HP:RepositionPanel()
end)

-- ── Manual date picker (Date Joined / Promoted / Birthday) ─────────────
-- Same interaction shape as GRM's own real date-entry popup (researched
-- 2026-09-29, live install: a set of Month/Day/[Year] selectors plus
-- Save/Unknown/Cancel) - built with our own Brand.MakeDropdown instead of
-- GRM's hand-rolled dropdown widgets, since this addon never reaches for
-- Blizzard's or another addon's widget chrome when we already have our own.
-- One shared popup, reconfigured per mode rather than three separate ones.
local pickerFrame

-- Sized and positioned generously (2026-09-29 - "can you read that? I
-- can't" - the old 260x150 popup, anchored right next to whatever link was
-- clicked, was cramped enough internally AND close enough to the panel
-- that opened it that its own dropdowns and buttons visually ran together
-- with content behind/around it). FULLSCREEN_DIALOG strata (this addon's
-- own context-menu/dropdown-list strata) instead of TOOLTIP, and always
-- opens at a fixed spot on screen rather than anchored near the click -
-- guarantees it never lands on top of another panel (ours or another
-- addon's, e.g. GRM's own hover panel, both addons genuinely running at
-- once) regardless of where in the UI it was opened from.
local function CreateDatePicker()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(320, 190)
    -- TOOLTIP, same as our own hover panel - NOT FULLSCREEN_DIALOG (a real
    -- mistake, 2026-09-29 - TOOLTIP is WoW's actual highest strata, above
    -- FULLSCREEN_DIALOG, so that put the picker BEHIND our own panel
    -- instead of in front of it, which is what was actually colliding).
    -- SetFrameLevel in OpenDatePicker below (same strata still orders by
    -- level) is what guarantees it draws on top of frame specifically.
    f:SetFrameStrata("TOOLTIP")
    Brand.ApplyBackground(f)
    Brand.DrawBorder(f, 1)
    f:EnableMouse(true)
    f:Hide()

    f.title = Brand.FS(f, "", Brand.TITLE_FONT_PATH, 14, "OUTLINE", Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
    f.title:SetPoint("TOP", f, "TOP", 0, -16)
    f.title:SetJustifyH("CENTER")

    -- Fixed left-edge layout, not offset-from-center math - the three
    -- dropdowns' widths (90+70+80=240) plus two 10px gaps come to 260,
    -- comfortably inside the now-320-wide frame with real margin on both
    -- sides, instead of the old math that left the year dropdown pressed
    -- right up against (and in practice, past) the frame's own edge.
    local ddY = -56
    f.monthDD = Brand.MakeDropdown(f, 90)
    f.monthDD:SetPoint("TOPLEFT", f, "TOPLEFT", 20, ddY)
    local monthOpts = {}
    for i, name in ipairs(R.MONTH_NAMES) do
        table.insert(monthOpts, { key = i, name = name })
    end
    f.monthDD:SetOptions(monthOpts)

    f.dayDD = Brand.MakeDropdown(f, 70)
    f.dayDD:SetPoint("LEFT", f.monthDD, "RIGHT", 10, 0)
    local dayOpts = {}
    for d = 1, 31 do
        table.insert(dayOpts, { key = d, name = tostring(d) })
    end
    f.dayDD:SetOptions(dayOpts)

    f.yearDD = Brand.MakeDropdown(f, 80)
    f.yearDD:SetPoint("LEFT", f.dayDD, "RIGHT", 10, 0)
    local yearOpts = {}
    local thisYear = tonumber(date("%Y"))
    for yr = thisYear, thisYear - 20, -1 do
        table.insert(yearOpts, { key = yr, name = tostring(yr) })
    end
    f.yearDD:SetOptions(yearOpts)

    f.errorText = Brand.FS(f, "", Brand.BODY_FONT_PATH, 11, "", 1, 0.35, 0.35)
    f.errorText:SetPoint("TOP", f, "TOP", 0, ddY - 36)
    f.errorText:SetWidth(280)
    f.errorText:SetJustifyH("CENTER")
    f.errorText:Hide()

    f.saveBtn = Brand.MakeTextLink(f, "Save", function()
        if f.onSave then f.onSave() end
    end)
    f.saveBtn:SetPoint("BOTTOM", f, "BOTTOM", -90, 18)

    f.unknownBtn = Brand.MakeTextLink(f, "Mark Unknown", function()
        if f.onUnknown then f.onUnknown() end
    end)
    f.unknownBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)

    f.cancelBtn = Brand.MakeTextLink(f, "Cancel", function()
        f:Hide()
    end)
    f.cancelBtn:SetPoint("BOTTOM", f, "BOTTOM", 90, 18)

    -- Clears the hover panel's auto-hide suppression the instant the picker
    -- itself closes, whichever way that happens (Save/Unknown both call
    -- f:Hide() indirectly via their own success path, Cancel directly).
    f:SetScript("OnHide", function()
        if frame then frame.pickerOpen = false end
    end)

    return f
end

-- mode: "join" | "promoted" | "birthday". anchorBtn is the clicked date
-- field (the popup opens right next to it). Birthday hides the Year
-- dropdown entirely (day/month only, same as GRM) rather than showing a
-- year that isn't actually tracked.
-- onSaved(charName, guild) - optional, called after a successful Save or
-- Mark Unknown. Defaults to re-showing the hover panel itself (its own
-- normal call sites), but GuildPanel.lua's Roster-page profile card
-- (2026-09-29 - "if it says promoted, I want that to be a link") passes its
-- own refresh instead, since popping the mouseover panel up on top of an
-- edit made from a completely different part of the UI would be wrong.
function HP:OpenDatePicker(mode, guild, charName, anchorBtn, onSaved)
    if not pickerFrame then pickerFrame = CreateDatePicker() end
    onSaved = onSaved or function()
        HP:ShowFor(charName, guild.members[charName], guild, frame and frame.currentAnchor)
    end
    local f = pickerFrame

    local titles = { join = "Set Date Joined", promoted = "Set Promoted", birthday = "Set Birthday" }
    f.title:SetText(titles[mode])
    f.errorText:Hide()

    local today = date("*t")
    local day, month, year = today.day, today.month, today.year
    if mode == "join" or mode == "promoted" then
        local existing = (mode == "join") and R:GetJoinDate(guild, charName) or R:GetPromotedDate(guild, charName)
        if existing then
            local t = date("*t", existing)
            day, month, year = t.day, t.month, t.year
        end
    elseif mode == "birthday" then
        local existing = R:GetBirthday(guild, charName)
        if existing then day, month = existing.day, existing.month end
    end

    f.monthDD:SetValue(month)
    f.dayDD:SetValue(day)
    if mode == "birthday" then
        f.yearDD:Hide()
    else
        f.yearDD:Show()
        f.yearDD:SetValue(year)
    end

    f.onSave = function()
        local d, m = f.dayDD:GetValue(), f.monthDD:GetValue()
        local y = (mode ~= "birthday") and f.yearDD:GetValue() or nil
        local ok
        if mode == "join" then
            ok = R:SetJoinDateOverride(guild, charName, d, m, y)
        elseif mode == "promoted" then
            ok = R:SetPromotedOverride(guild, charName, d, m, y)
        else
            ok = R:SetBirthday(guild, charName, d, m)
        end
        if not ok then
            f.errorText:SetText("Not a real date - check the day for that month.")
            f.errorText:Show()
            return
        end
        f:Hide()
        onSaved(charName, guild)
    end

    f.onUnknown = function()
        if mode == "join" then
            R:ClearJoinDateOverride(guild, charName, true)
        elseif mode == "promoted" then
            R:ClearPromotedOverride(guild, charName, true)
        else
            R:ClearBirthday(guild, charName)
        end
        f:Hide()
        onSaved(charName, guild)
    end

    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    f:SetClampedToScreen(true)
    -- Same strata as our own hover panel (TOOLTIP) draws in creation/level
    -- order, not guaranteed on top just by both being TOOLTIP - explicit
    -- level above frame's own guarantees this picker always draws over our
    -- panel specifically, regardless of which one got created first.
    f:SetFrameLevel((frame and frame:GetFrameLevel() or 0) + 10)
    if frame then frame.pickerOpen = true end
    f:Show()
end

function HP:Hide()
    if frame then frame:Hide() end
end

-- Used by every OnLeave (a row's, or the panel's own) instead of hiding
-- immediately - gives the mouse a moment to actually land on the panel
-- (to edit a note) before deciding it's genuinely done being looked at.
-- Also skipped entirely while the date picker is open (frame.pickerOpen) -
-- the picker is its own separate frame positioned outside the hover
-- panel's own bounds, so using its dropdowns moves the mouse off `frame`
-- and would otherwise auto-close the panel out from under it mid-edit.
function HP:ScheduleHide()
    if not frame then return end
    C_Timer.After(0.15, function()
        if not frame.locked and not frame.pickerOpen and not editingPaused and not frame:IsMouseOver() then
            frame:Hide()
        end
    end)
end

-- ── Blizzard's native Guild Roster window ───────────────────────────
-- Rebuilt 2026-09-29 to match GRM's real architecture (mechanism
-- researched and described in our own words/code - GRM's own source isn't
-- reproduced here, per project standard: don't copy another addon's code,
-- extract the fact not the shape). GRM does NOT run a separate floating
-- poll comparing cursor position against IsMouseOver() the way our first
-- version did - it hooks directly onto each real row button and reacts to
-- genuine Blizzard-fired events on that same button. That's the actual
-- reason its note boxes reliably receive clicks and ours didn't: opening
-- from a real click ON the row itself, and reading each row's OWN current
-- memberInfo at the moment of that real event, never has the timing/
-- overlay contention a separate polling panel can run into.
local function GetRowMemberInfo(button)
    return button.memberInfo or (button.GetMemberInfo and button:GetMemberInfo())
end

local function ShowPanelForRow(button)
    local memberInfo = GetRowMemberInfo(button)
    if not (memberInfo and memberInfo.name) then return end

    local shortName = memberInfo.name:match("^([^-]+)") or memberInfo.name
    local guild = R:GetCurrentGuild()
    local member = guild and guild.members[shortName]
    local classInfo = memberInfo.classID and C_CreatureInfo.GetClassInfo(memberInfo.classID)
    HP:ShowFor(shortName, member, guild, button, {
        level = memberInfo.level,
        className = classInfo and classInfo.className,
        isOnline = memberInfo.presence ~= nil and memberInfo.presence ~= Enum.ClubMemberPresence.Offline,
    })
end

-- Each row button gets hooked at most once (button.xrrHooked guards
-- against the same list rebuilding/scrolling and handing this function
-- the same button object again) - real click opens/updates the panel for
-- that row's real, current member; real hover (while the panel is already
-- open) keeps it in sync as you move between rows, using the row's own
-- genuine OnEnter event rather than polling for it. A recycled button
-- doesn't break this - whichever member is actually assigned to a button
-- when its OnClick/OnEnter genuinely fires is read fresh at that moment,
-- never cached from an earlier assignment.
local function HookMemberListButtons()
    local memberList = CommunitiesFrame and CommunitiesFrame.MemberList
    if not (memberList and memberList.ScrollBox) then return end
    memberList.ScrollBox:ForEachFrame(function(button)
        if button.xrrHooked then return end
        button.xrrHooked = true
        -- Click LOCKS the panel open on this member, matching GRM's real
        -- behavior (2026-09-29 - "GRM locks it when you click, ours
        -- doesn't... it'll close if you don't quickly transition to the
        -- panel"). While locked: hovering other rows doesn't switch it
        -- (you have to click again to change who it's showing), and it
        -- won't auto-close from the mouse leaving - only the panel's own
        -- Close link, or clicking a row again, changes that.
        button:HookScript("OnClick", function(self)
            ShowPanelForRow(self)
            if frame then frame.locked = true end
        end)
        button:HookScript("OnEnter", function(self)
            if not editingPaused and not (frame and frame.locked) then
                ShowPanelForRow(self)
            end
        end)
        button:HookScript("OnLeave", function()
            if not (frame and frame.locked) then HP:ScheduleHide() end
        end)
    end)
end

local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
hookFrame:SetScript("OnEvent", HookMemberListButtons)
if CommunitiesFrame then
    CommunitiesFrame:HookScript("OnShow", HookMemberListButtons)
    -- Closing the whole Guild Roster window needs to take our panel with
    -- it (2026-09-29 - confirmed via screenshot: closing Blizzard's roster
    -- left ours floating over the game world on its own). It's locked once
    -- opened via a click, so nothing else was closing it for this case.
    CommunitiesFrame:HookScript("OnHide", function()
        if frame then
            frame.locked = false
            frame:Hide()
        end
    end)
end
-- Covers the case CommunitiesFrame is already open (or Blizzard_Communities
-- only just finished loading) at the moment this file runs.
C_Timer.After(1, HookMemberListButtons)
