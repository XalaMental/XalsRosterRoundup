-- WhatsNew.lua
-- Xal's Roster Roundup
--
-- Shows a "what's new" splash automatically the FIRST time a player logs in
-- after the addon has been updated to a new version - never during normal,
-- unchanged play. Compares the addon's real installed version (read from the
-- .toc at runtime) against the last version this player actually saw, and
-- only pops up when they differ.
--
-- Claude already writes CHANGELOG.md by hand before every release, in Dev,
-- before Jason ever commits/pushes anything - same moment, update WHATS_NEW
-- below (the "date" field and the intro/sections content) to match. It's
-- one more file touched during normal release prep, nothing extra for Jason
-- to remember or do - same as roster_changelog.md / roster_changelog_dev.md
-- already get updated every release. A WoW addon can't read the external
-- CHANGELOG.md file live at runtime (Blizzard's addon sandbox has no file
-- access) - which is exactly why this gets written by hand at prep time
-- instead, not because it's some separate manual chore layered on top.
-- The version NUMBER shown on the splash does NOT need updating here - it's
-- read live from the real installed .toc version, same value used for the
-- update-check itself, so there's only ever one place that can go stale.
XRR = XRR or {}
XRR.WhatsNew = {}
local W = XRR.WhatsNew
local Brand = XRR.BrandStyle

-- ── Update this block every release to match CHANGELOG.md ──────
-- (no "version" field here on purpose - see note above)
W.WHATS_NEW = {
    date = "September 12, 2026",
    intro = "I hadn't touched this one's look since I first built it, and the rest of my addons have moved on to a new visual style since then - a darker indigo background and a deep orange accent instead of the old bronze-gold and swirl texture. Figured it was time to catch this one up so it actually looks like part of the same family again instead of standing out as the odd one.",
    sections = {
        { heading = "Visual refresh", items = {
            "Switched the accent color from bronze-gold to a deep burnt-orange, and the background from a dark swirl texture to a flat dark indigo - matches the current look across all of my addons.",
            "The background opacity slider on the Display page now matches the new orange accent too.",
        } },
    },
}

-- ── Version check ────────────────────────────────────────────
-- C_AddOns.GetAddOnMetadata is the current namespaced API (available on
-- Retail, MoP Classic, and Classic Era alike since Dragonflight); the bare
-- global is kept as a fallback only, same defensive pattern used elsewhere
-- in Jason's addons for other C_* namespaces.
local function GetInstalledVersion()
    local v
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        v = C_AddOns.GetAddOnMetadata("XalsRosterRoundup", "Version")
    elseif _G.GetAddOnMetadata then
        v = _G.GetAddOnMetadata("XalsRosterRoundup", "Version")
    end
    -- The .toc's "@project-version@" token only gets replaced with a real
    -- number by the packager, which only runs on an actual tagged release.
    -- Testing straight from local files (no tag pushed) leaves it as this
    -- literal, unsubstituted text - show a friendly fallback instead of the
    -- broken-looking placeholder string.
    if v == "@project-version@" then
        return "dev"
    end
    return v
end

local FW = 460
local MAX_FH = 560 -- clamp so an unusually long release note can't run off-screen

local function BuildFrame(installedVersion)
    local f = CreateFrame("Frame", "XalsRosterRoundupWhatsNewFrame", UIParent)
    f:SetSize(FW, 360) -- placeholder height; set for real below once content is laid out
    -- Distinct default offset + SetToplevel + saved position, per the suite-wide
    -- window rule: a bare SetPoint("CENTER") makes this land on top of another
    -- Xal's addon's window whenever two are open at once. (-220, 180) isn't
    -- used by any existing Xal's addon window (checked against the full
    -- registry in project_addon_visual_brand.md).
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        XRR_DB.whatsNewPoint = { point, relPoint, x, y }
    end)
    f:SetClampedToScreen(true)

    local pos = XRR_DB.whatsNewPoint
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -220, 180)
    end

    -- Flat color only, no swirl image - confirmed 2026-09-02 brand refresh.
    -- No outer border either (2026-09-20) - every window in the addon is
    -- borderless now, matching the Options window's cleaner look against
    -- the darker background.
    -- Outer border restored (2026-09-20) - same fix as Options/GuildPanel.
    Brand.ApplyBackground(f)
    Brand.DrawBorder(f, 1)

    local data = W.WHATS_NEW
    Brand.Title(f, "What's New", 26, "TOP", f, "TOP", 0, -24)

    local discord = Brand.MakeDiscordLink(f)
    discord:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Brand.SAFE_MARGIN, -Brand.SAFE_MARGIN)

    -- "installedVersion" is the REAL live version (from CheckAndShow), not a
    -- hand-typed field - it always matches whatever actually got tagged.
    local verLine = Brand.FS(f, "Version " .. installedVersion .. (data.date and ("  ·  " .. data.date) or ""),
        Brand.BODY_FONT_PATH, 12, "", Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3])
    verLine:SetPoint("TOP", f, "TOP", 0, -58)
    verLine:SetJustifyH("CENTER")

    Brand.DrawDivider(f, 30, 78, FW - 60)

    -- Real, in-game-confirmed fix, ported point-for-point from
    -- Xal's-Common-Tongue/WhatsNew.lua (which hit this identical bug and
    -- fixed it - "the GetStringHeight approach returned wrapped heights one
    -- line short here and stacked every bullet on top of itself in-game").
    -- Two earlier attempts on THIS addon (a hidden-frame-0-height theory,
    -- then a set-width-before-text theory) were both guesses that didn't
    -- hold up in-game (confirmed still broken via screenshot 2026-09-12).
    -- This version doesn't call GetStringHeight() at all: each element
    -- anchors its TOPLEFT to the PREVIOUS element's real BOTTOMLEFT, so the
    -- game's own layout engine (which knows the true wrapped height once it
    -- actually draws the string) positions the next line - no manual height
    -- math to get wrong.
    local function WrappedFS(text, width, size, r, g, b)
        local fs = Brand.FS(f, "", Brand.BODY_FONT_PATH, size, "", r, g, b)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text)
        return fs
    end

    local prev, prevIndent = nil, 30
    local function place(elem, indent, gap)
        if prev then
            elem:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", indent - prevIndent, -gap)
        else
            elem:SetPoint("TOPLEFT", f, "TOPLEFT", indent, -92)
        end
        prev, prevIndent = elem, indent
    end

    if data.intro and data.intro ~= "" then
        place(WrappedFS(data.intro, FW - 60, 12, 0.85, 0.85, 0.85), 30, 0)
    end

    for _, section in ipairs(data.sections or {}) do
        local head = Brand.FS(f, section.heading, Brand.BODY_FONT_PATH, 13, "OUTLINE",
            Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
        place(head, 30, 16)

        for _, item in ipairs(section.items or {}) do
            place(WrappedFS("-  " .. item, FW - 76, 12, Brand.GOLD[1], Brand.GOLD[2], Brand.GOLD[3]), 36, 8)
        end
    end

    local closeBtn = Brand.MakeCloseButton(f, function() f:Hide() end)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)

    -- Relative anchors only resolve to real screen positions after the first
    -- draw - measure one frame after Show() (via OnShow + C_Timer.After(0))
    -- and size the frame from the last element's TRUE bottom, instead of any
    -- pre-computed height guess.
    local function FitHeight()
        local top = f:GetTop()
        local lastBottom = prev and prev:GetBottom()
        if top and lastBottom then
            f:SetHeight(math.min(math.max((top - lastBottom) + 64, 180), MAX_FH))
        end
    end
    f:SetScript("OnShow", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, FitHeight)
        else
            FitHeight()
        end
    end)

    return f
end

-- Call this from Core's login handler - checks the version and shows the
-- splash only when it's genuinely changed since this player last saw it.
function W:CheckAndShow()
    local installed = GetInstalledVersion()
    if not installed then return end -- metadata unavailable, don't error, just skip

    -- Uses the addon's account-wide DB - XRR_DB - same table every other
    -- saved setting lives in, so no extra SavedVariables entry needs
    -- registering in the .toc.
    if XRR_DB.lastSeenVersion ~= installed then
        XRR_DB.lastSeenVersion = installed
        -- pcall so a bad edit to WHATS_NEW (typo, missing field) can never
        -- break the rest of the addon's login - worst case, the splash just
        -- silently doesn't show that one time.
        local ok, frame = pcall(BuildFrame, installed)
        if ok and frame then frame:Show() end
    end
end
