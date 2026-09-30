-- BrandStyle.lua
-- Xal's Roster Roundup
--
-- Xal's shared visual brand. Background/accent/title treatment are from Xal's
-- Craft Courier's splash panel; the button style is from Xal's Compendium
-- (Courier's beveled "steel" buttons looked visually off - inconsistent
-- highlight/shadow read - once placed in a horizontal row, so Compendium's
-- flat button replaced it as the standard, confirmed 2026-08-09). Every
-- border/divider line is at least 2px - a 1px line can fail to render
-- reliably depending on UI scale, which is why Courier's border was already
-- 2px; dividers are brought up to match here too.
--
-- Use these helpers for splash screens, settings panels, and any other
-- custom-drawn frame. Standard interactive controls that AREN'T part of this
-- brand spec (checkboxes, sliders, edit boxes) should still use Blizzard's
-- native templates (UICheckButtonTemplate etc.) - only buttons/borders/titles
-- get the custom treatment.
XRR = XRR or {}
XRR.BrandStyle = {}
local Brand = XRR.BrandStyle

-- ── Colours (r, g, b) ─────────────────────────────────────────
-- Deep burnt-orange + dark indigo, the current family default (confirmed
-- 2026-09-02, replaces the old bronze-gold/near-black look) - was
-- { 0.72, 0.55, 0.22 } / { 0.035, 0.035, 0.035, 1 }. Changed as the DEFAULT
-- VALUE here (not a separate parallel constant like other addons use) since
-- this addon's own Options -> Display page already lets players pick a
-- live custom accent/background color that mutates these same tables in
-- place (Brand.ApplySavedTheme) - everything else (borders, titles, button
-- hover/selected color, checkbox borders, dividers) already reads from
-- these same mutable values, so that picker keeps working unchanged.
-- Confirmed 2026-09-25 ("Everything the same dark red, no exceptions"):
-- there is no separate accent-orange anymore anywhere in the family - this
-- addon's own customizable Accent Color picker (Options -> Display) now
-- just defaults to the same dark red as Brand.HEADER_COLOR instead of
-- orange. The picker itself is unchanged and still fully works - pick a
-- different color and it still drives every button/link/checkbox below,
-- same as before; only the out-of-the-box default color changed.
Brand.ACCENT = { 0.4078, 0.0784, 0.0902 }    -- dark brick red, matches Brand.HEADER_COLOR
Brand.GOLD   = { 0.60, 0.47, 0.30 }   -- secondary/body text tone
Brand.BG     = { 0.012, 0.011, 0.024, 1 } -- near-black indigo, fully opaque (#03030a) - darkened 2026-09-20, was #08070f

-- Snapshotted BEFORE ApplySavedTheme ever mutates Brand.ACCENT/Brand.BG in
-- place, so there's a real "Reset to Default" to return to on the Display
-- page - once a color is actually saved (a genuine pick, not the old
-- auto-capture bug), no code-side default change can ever reach it again,
-- so the only way back is an explicit reset the player can click.
Brand.DEFAULT_ACCENT = { 0.4078, 0.0784, 0.0902 }
Brand.DEFAULT_BG = { 0.012, 0.011, 0.024 }

-- Alert-icon glow colors - each floating alert icon gets its own distinct
-- color so which one's lit up is obvious at a glance without hovering.
-- Application alerts use Brand.ACCENT itself (the flagship/original one).
Brand.ALERT_COLOR_NEW_MEMBER = { 0.25, 0.55, 0.95 } -- blue
Brand.ALERT_COLOR_RANK_CHANGE = { 0.65, 0.30, 0.85 } -- purple
Brand.ALERT_COLOR_BAN_REJOIN = { 1.0, 0.2, 0.2 } -- red - a banned name rejoining, the most urgent of the four

-- Confirmed color for the window title, the header divider directly under
-- it, and a selected sidebar link - #681417, a dark brick red. Distinct
-- from Brand.ACCENT (used for section headers within a page and unselected
-- hover states). Was #782019, swapped 2026-09-20 for this darker try.
Brand.HEADER_COLOR = { 0.4078, 0.0784, 0.0902 }

-- Confirmed color for every OTHER divider (section dividers within a page,
-- sidebar dividers, list dividers) and panel/card edges (Applications
-- cards, etc.) - #101020, a near-black indigo. Was (0.16, 0.12, 0.05), a
-- muted brown, before this. Distinct from Brand.HEADER_COLOR (the one
-- header divider only) and Brand.ACCENT (no longer used for panel
-- borders - matches the mockup's subtle card edges instead of bright
-- orange).
Brand.DIVIDER_COLOR = { 0.0627, 0.0627, 0.1255 }
Brand.LINE_THICKNESS = 2 -- minimum for ANY border/divider - never go below this
-- Minimum gap between a panel's true outer edge and the nearest button/text
-- (close buttons especially). DrawBorder()'s line occupies out to 8px in
-- (6px inset + 2px thick) - the FIRST version of this constant was set to
-- exactly 8, which technically cleared the border but left ZERO actual
-- visual gap (content started precisely where the border line ended), so
-- it still read as crammed/touching. Bumped to 14 (a real ~6px of clear
-- space beyond the border) after seeing this live in-game - confirmed
-- 2026-08-09.
Brand.SAFE_MARGIN = 14

-- ── Customizable body text (Options -> Text page) ──────────────────────
-- Applies to regular body/label/description/row text ONLY - the big
-- branded title (Brand.Title) stays fixed on purpose, same as every other
-- addon in this family. These are read ONCE when a panel is built, not
-- live - confirmed 2026-08-12: "changes apply after /reload" is the
-- accepted tradeoff, matching Quest Compass's own ElvUI-skin toggle,
-- rather than a much larger live-re-theme-every-frame rebuild.
-- Default bumped to the bundled Inter Regular (2026-09-19, brand refresh) -
-- was Fira Sans Medium before that. The picker on the Text page
-- (Options.lua) still lets players choose a different family; this only
-- changes the OUT-OF-THE-BOX default.
Brand.BODY_FONT_PATH = "Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Inter-Regular.ttf"
Brand.BODY_SIZE_SCALE = 1.0 -- 0.85 small / 1.0 medium / 1.15 large
Brand.BODY_OUTLINE = "" -- "", "OUTLINE", or "THICKOUTLINE" - no color option
-- exists for this at the WoW API level, the engine always renders it black
-- (confirmed 2026-08-12, this is a real engine limitation, not a shortcut).
Brand.BODY_TEXT_COLOR = { 0.85, 0.85, 0.85 }

-- The OLD bronze-gold/near-black defaults, before the 2026-09-02 indigo/
-- orange refresh - the Display page's color pickers auto-save whatever
-- Brand.ACCENT/Brand.BG's value was the FIRST time that page was ever
-- opened (`XRR_DB.accentColor = XRR_DB.accentColor or {...}`), so anyone
-- who opened Display before this update has these old values permanently
-- baked into their SavedVariables - no code-level default change can ever
-- override a saved value that already exists. Confirmed in-game via
-- screenshot 2026-09-12 (still bronze-gold/near-black after the refresh,
-- on a genuinely fresh copy) - this is why, not a color that failed to
-- apply.
local OLD_ACCENT_DEFAULT = { 0.72, 0.55, 0.22 }
local OLD_BG_DEFAULT = { 0.035, 0.035, 0.035 }
-- The 2026-09-02 indigo default, superseded again 2026-09-20 by an even
-- darker near-black indigo - same stale-saved-default problem as the pair
-- above, so it needs the exact same one-time clear or anyone who already
-- opened Display since 09-02 stays stuck on the lighter indigo forever.
local OLD_BG_DEFAULT_2 = { 0.03, 0.028, 0.06 }
-- The 2026-09-02 burnt-orange default, superseded 2026-09-25 by the dark
-- red used everywhere else - same stale-saved-default problem, so anyone
-- who opened Display between 09-02 and now needs the same one-time clear
-- or they'd stay stuck on orange forever.
local OLD_ACCENT_DEFAULT_2 = { 0.72, 0.30, 0.0 }
local function IsOldDefault(saved, old)
    return saved and saved[1] == old[1] and saved[2] == old[2] and saved[3] == old[3]
end

-- Reads saved settings (XRR_DB) into the constants above, plus mutates
-- Brand.ACCENT/Brand.BG's own VALUES in place (not reassigning the tables -
-- every existing call site already holds a reference to these same tables,
-- so mutating their contents is what lets the customization reach code
-- that was written before this setting existed, with zero other changes
-- needed). Call this once at login, before any panel is ever built.
function Brand.ApplySavedTheme()
    -- One-time migration: a saved value that's EXACTLY the old stale
    -- default (never actually chosen, just auto-captured) gets cleared so
    -- the new code-level default takes over. A genuinely different custom
    -- pick is never touched.
    if IsOldDefault(XRR_DB.accentColor, OLD_ACCENT_DEFAULT) or IsOldDefault(XRR_DB.accentColor, OLD_ACCENT_DEFAULT_2) then
        XRR_DB.accentColor = nil
    end
    if IsOldDefault(XRR_DB.bgColor, OLD_BG_DEFAULT) or IsOldDefault(XRR_DB.bgColor, OLD_BG_DEFAULT_2) then
        XRR_DB.bgColor = nil
    end

    local accent = XRR_DB.accentColor
    if accent then
        Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3] = accent[1], accent[2], accent[3]
    end
    local bg = XRR_DB.bgColor
    if bg then
        Brand.BG[1], Brand.BG[2], Brand.BG[3] = bg[1], bg[2], bg[3]
    end
    if XRR_DB.bgOpacity then
        Brand.BG[4] = XRR_DB.bgOpacity
    end
    if XRR_DB.bodyFontPath then
        Brand.BODY_FONT_PATH = XRR_DB.bodyFontPath
    end
    if XRR_DB.bodySizeScale then
        Brand.BODY_SIZE_SCALE = XRR_DB.bodySizeScale
    end
    if XRR_DB.bodyOutline then
        Brand.BODY_OUTLINE = XRR_DB.bodyOutline
    end
end

-- ── BodyFS()  ─ a body-text FontString using the current customizable
-- family/size-scale/outline/color - use this (not a raw CreateFontString +
-- SetFont) for field labels, descriptions, row text, anything that isn't a
-- branded Morpheus title, so the Text page settings actually reach it.
function Brand.BodyFS(parent, text, baseSize)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Brand.BODY_FONT_PATH, baseSize * Brand.BODY_SIZE_SCALE, Brand.BODY_OUTLINE)
    fs:SetText(text or "")
    fs:SetTextColor(Brand.BODY_TEXT_COLOR[1], Brand.BODY_TEXT_COLOR[2], Brand.BODY_TEXT_COLOR[3], 1)
    -- Real, confirmed bug (2026-09-22): a plain FontString's own default
    -- justification is CENTER, not LEFT. Every wrapped paragraph in this
    -- addon is meant to read left-aligned under its own heading, so that
    -- default needs overriding here once, not re-set by hand at every
    -- single call site (several already forgot to).
    fs:SetJustifyH("LEFT")
    return fs
end

-- ── T()  ─ solid-colour texture rectangle.
-- x, y measured from the parent's TOP-LEFT corner (y increases downward).
-- Uses PixelUtil so every edge snaps to a whole physical screen pixel -
-- at a non-integer UI Scale (e.g. 71%), a plain SetPoint/SetSize can land
-- a 2px line on a fractional pixel, which the renderer then blurs/dims.
-- Confirmed 2026-08-09: this was making some sidebar tab borders look
-- randomly "less pronounced" than others, reproducibly, at 71% scale.
function Brand.T(parent, x, y, w, h, r, g, b, a, layer)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    PixelUtil.SetPoint(tex, "TOPLEFT", parent, "TOPLEFT", x, -y)
    PixelUtil.SetSize(tex, w, h)
    tex:SetColorTexture(r, g, b, a or 1)
    return tex
end

-- ── FS()  ─ a FontString with a specific font/size/colour.
function Brand.FS(parent, text, fontPath, size, flags, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(fontPath, size, flags or "")
    fs:SetText(text)
    fs:SetTextColor(r, g, b, 1)
    -- Same real default-justification bug as Brand.BodyFS (2026-09-22) - a
    -- plain FontString centers itself unless told otherwise.
    fs:SetJustifyH("LEFT")
    return fs
end

-- ── Title font ────────────────────────────────────────────────
-- Bundled Cinzel Bold (SIL OFL), ships in Fonts/Cinzel-Bold.ttf - replaces
-- Fonts\CustomFont.ttf (2026-09-19, brand refresh) to match the rest of the
-- family (Quest Compass, Guild Council, etc.).
Brand.TITLE_FONT_PATH = "Interface\\AddOns\\XalsRosterRoundup\\Fonts\\Cinzel-Bold.ttf"

-- ── Title()  ─ the branded title treatment, with its drop-shadow layer,
-- in one call. Returns the visible (front) fontstring.
function Brand.Title(parent, text, size, anchorPoint, relTo, relPoint, x, y)
    local shadow = Brand.FS(parent, text, Brand.TITLE_FONT_PATH, size, "OUTLINE", 0, 0, 0)
    PixelUtil.SetPoint(shadow, anchorPoint, relTo, relPoint, x + 4, y - 4)
    shadow:SetJustifyH("CENTER")

    local title = Brand.FS(parent, text, Brand.TITLE_FONT_PATH, size, "OUTLINE",
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3])
    PixelUtil.SetPoint(title, anchorPoint, relTo, relPoint, x, y)
    title:SetJustifyH("CENTER")
    return title
end

-- ── MakeButton()  ─ Xal's Compendium's flat button (the confirmed standard,
-- verified 2026-08-09 straight from Options.lua's MakeFlatButton): thin
-- border, semi-transparent dark fill, no bevel/gradient - reads cleanly
-- even in a horizontal row, which is exactly what Courier's beveled version
-- didn't do. Border color changed 2026-08-09 from a plain light grey to the
-- same accent gold as the panel border, so buttons read as part of the same
-- branded frame instead of a mismatched grey outline. Selected vs. normal
-- state is carried by fill brightness AND label color (see SetSelected below).
-- Call btn:SetSelected(true/false) for a brighter fill + white label (tabs).
local BTN_BORDER = { Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1 }
local BTN_BORDER_SELECTED = { Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1 }
-- Was its own separate hardcoded amber-orange, distinct from Brand.ACCENT -
-- retired 2026-09-25 ("everything the same dark red, no exceptions"), same
-- fix already applied on Routes. Now just Brand.ACCENT, same as the border
-- above - one accent color, not two competing warm tones.
local BTN_LABEL_UNSELECTED = { Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3] }

function Brand.MakeButton(parent, text, w, h, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    PixelUtil.SetSize(btn, w, h)
    -- Fill only - no backdrop edge. Blizzard's backdrop-edge system computes
    -- each side's thickness independently and isn't guaranteed to come out
    -- symmetric at a non-integer UI Scale (confirmed 2026-08-09: it was
    -- rendering every button's left/right border at visibly different
    -- thickness, uniformly, at 71% scale). Border is hand-drawn below
    -- instead, using the same pixel-snapped technique as Brand.DrawBorder.
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.6)

    local thick = Brand.LINE_THICKNESS
    local borderTop = btn:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderTop, "TOPLEFT", btn, "TOPLEFT", 0, 0)
    PixelUtil.SetPoint(borderTop, "TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    PixelUtil.SetHeight(borderTop, thick)

    local borderBottom = btn:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderBottom, "BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    PixelUtil.SetPoint(borderBottom, "BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetHeight(borderBottom, thick)

    local borderLeft = btn:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderLeft, "TOPLEFT", btn, "TOPLEFT", 0, 0)
    PixelUtil.SetPoint(borderLeft, "BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    PixelUtil.SetWidth(borderLeft, thick)

    local borderRight = btn:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderRight, "TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    PixelUtil.SetPoint(borderRight, "BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetWidth(borderRight, thick)

    local function SetBorderColor(r, g, b, a)
        borderTop:SetColorTexture(r, g, b, a)
        borderBottom:SetColorTexture(r, g, b, a)
        borderLeft:SetColorTexture(r, g, b, a)
        borderRight:SetColorTexture(r, g, b, a)
    end
    SetBorderColor(BTN_BORDER[1], BTN_BORDER[2], BTN_BORDER[3], BTN_BORDER[4])

    -- Label starts in the unselected amber-orange and switches to white via
    -- SetSelected below - gives an at-a-glance read of which tab is active
    -- instead of relying on the subtle fill-brightness difference alone.
    -- Confirmed 2026-08-09.
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(BTN_LABEL_UNSELECTED[1], BTN_LABEL_UNSELECTED[2], BTN_LABEL_UNSELECTED[3], 1)
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        if not self.selected then self:SetBackdropColor(0.18, 0.18, 0.18, 0.75) end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.selected then self:SetBackdropColor(0.1, 0.1, 0.1, 0.6) end
    end)
    if onClick then btn:SetScript("OnClick", onClick) end

    function btn:SetSelected(selected)
        self.selected = selected
        if selected then
            self:SetBackdropColor(0.22, 0.22, 0.22, 0.85)
            SetBorderColor(BTN_BORDER_SELECTED[1], BTN_BORDER_SELECTED[2], BTN_BORDER_SELECTED[3], BTN_BORDER_SELECTED[4])
            label:SetTextColor(1, 1, 1, 1)
        else
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            SetBorderColor(BTN_BORDER[1], BTN_BORDER[2], BTN_BORDER[3], BTN_BORDER[4])
            label:SetTextColor(BTN_LABEL_UNSELECTED[1], BTN_LABEL_UNSELECTED[2], BTN_LABEL_UNSELECTED[3], 1)
        end
    end

    -- Exposed so call sites that need a one-off custom border color (e.g. a
    -- destructive/danger-styled button) have a real hook, same idea as
    -- SetSelected above - there should be only ONE button implementation
    -- per addon; every call site drives it through these methods rather
    -- than hand-rolling its own border.
    function btn:SetBorderColor(r, g, bC, a)
        SetBorderColor(r, g, bC, a)
    end

    return btn
end

-- ── DrawBorder()  ─ single clean line around a frame, in Brand.DIVIDER_COLOR
-- (not Brand.ACCENT - 2026-09-20, matches the mockup's subtle card edges
-- instead of a bright orange border on every panel/card). Deliberately
-- simple - no corner ornaments or tick marks. Each side is anchored to BOTH
-- ends of that edge (not a fixed x/y/w/h), so it auto-stretches if the
-- frame resizes later - important for anything that grows or shrinks at
-- runtime (a list that adds/removes rows, etc.), not just fixed-size
-- splash screens.
function Brand.DrawBorder(f, inset)
    inset = inset or 6
    local thick = Brand.LINE_THICKNESS
    local r, g, b = Brand.DIVIDER_COLOR[1], Brand.DIVIDER_COLOR[2], Brand.DIVIDER_COLOR[3]

    local top = f:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(top, "TOPLEFT", f, "TOPLEFT", inset, -inset)
    PixelUtil.SetPoint(top, "TOPRIGHT", f, "TOPRIGHT", -inset, -inset)
    PixelUtil.SetHeight(top, thick)
    top:SetColorTexture(r, g, b, 1)

    local bottom = f:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(bottom, "BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset)
    PixelUtil.SetPoint(bottom, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    PixelUtil.SetHeight(bottom, thick)
    bottom:SetColorTexture(r, g, b, 1)

    local left = f:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(left, "TOPLEFT", f, "TOPLEFT", inset, -inset)
    PixelUtil.SetPoint(left, "BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset)
    PixelUtil.SetWidth(left, thick)
    left:SetColorTexture(r, g, b, 1)

    local right = f:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(right, "TOPRIGHT", f, "TOPRIGHT", -inset, -inset)
    PixelUtil.SetPoint(right, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    PixelUtil.SetWidth(right, thick)
    right:SetColorTexture(r, g, b, 1)

    return top, bottom, left, right
end

-- ── DrawDivider()  ─ the thin section-separator line used between content
-- blocks (feature lists, header bars, etc.)
function Brand.DrawDivider(parent, x, y, width)
    return Brand.T(parent, x, y, width, Brand.LINE_THICKNESS,
        Brand.DIVIDER_COLOR[1], Brand.DIVIDER_COLOR[2], Brand.DIVIDER_COLOR[3], 1)
end

-- ── DrawHeaderDivider()  ─ same as DrawDivider, but in Brand.HEADER_COLOR -
-- used ONLY for the single divider directly under a window's main title,
-- never for section dividers within a page (those stay the muted tone
-- above).
function Brand.DrawHeaderDivider(parent, x, y, width)
    return Brand.T(parent, x, y, width, Brand.LINE_THICKNESS,
        Brand.HEADER_COLOR[1], Brand.HEADER_COLOR[2], Brand.HEADER_COLOR[3], 1)
end

-- ── ApplyBackground()  ─ the standard opaque near-black frame background.
function Brand.ApplyBackground(f)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(Brand.BG[1], Brand.BG[2], Brand.BG[3], Brand.BG[4])
    return bg
end

-- ── ApplyBackgroundImage()  ─ the shared dark-swirl texture art, sitting on
-- top of the flat background color (BORDER layer, below everything else -
-- border/dividers/text all draw at ARTWORK/OVERLAY, above this). Call AFTER
-- ApplyBackground so the flat color shows through anywhere the image
-- doesn't cover. Returns the texture so callers can hide/show it without
-- hunting for it again. Added 2026-08-19 (brand refresh) - this addon had
-- no background image at all before.
function Brand.ApplyBackgroundImage(f)
    local img = f:CreateTexture(nil, "BORDER")
    img:SetAllPoints(f)
    img:SetTexture("Interface\\AddOns\\XalsRosterRoundup\\Textures\\PanelBackground.jpg")
    return img
end

-- ── Discord link ──────────────────────────────────────────────
-- A permanent, standing text link (not a per-release thing) meant to live on
-- the What's New splash and the main Settings page. Added 2026-08-19 (brand
-- refresh) - this addon had no in-game Discord link before.
Brand.DISCORD_URL = "https://discord.gg/9SwrQDJeCe"

function Brand.MakeDiscordLink(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(130, 20)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT")
    label:SetText("Join us on Discord")
    label:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    btn.label = label
    btn:SetWidth(label:GetStringWidth())

    btn:SetScript("OnEnter", function() label:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnLeave", function()
        label:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    end)
    btn:SetScript("OnClick", function()
        Brand.ShowCopyBox("Join us on Discord", Brand.DISCORD_URL)
    end)

    return btn
end

-- Logo-only Discord link (no text label) - the sidebar's own bottom-pinned
-- Discord entry (confirmed 2026-09-20: "just the logo, no separate text"),
-- distinct from the text link above which stays where it already is (the
-- About page). Real Discord blurple wordmark art (Discord's own official
-- logo file, not hand-drawn) - shipped pre-resized to 280x42 (not the huge
-- 2647x400 original relying on the GPU to minify it at render time), same
-- lesson as the minimap icon technique: an extreme downscale of a huge
-- source looks blurry/soft regardless of source quality (confirmed
-- 2026-09-20 - "doesn't look crisp and clean" on the un-resized version).
Brand.DISCORD_LOGO_ICON = "Interface\\AddOns\\XalsRosterRoundup\\Textures\\DiscordLogo.png"
local DISCORD_LOGO_ASPECT = 42 / 280

-- No hardcoded guild Discord URL anymore (removed 2026-09-22) - this addon
-- is meant for other guilds too, not just mine, and a URL baked into the
-- addon itself would send every single person who ever installs it
-- straight to MY server, not their own guild's. The real URL now comes
-- from each guild's own SavedVariables (guild.discordUrl in Roster.lua,
-- set via a real field on the Guild Master page) and gets pushed into this
-- button with SetDiscordURL - the button hides itself entirely until one
-- has actually been set, rather than pointing at a default that isn't
-- theirs.
function Brand.MakeDiscordLogoLink(parent, width)
    width = width or 140
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, width * DISCORD_LOGO_ASPECT)

    local logo = btn:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture(Brand.DISCORD_LOGO_ICON)
    logo:SetAlpha(0.9)
    btn.logo = logo

    btn:SetScript("OnEnter", function() logo:SetAlpha(1) end)
    btn:SetScript("OnLeave", function() logo:SetAlpha(0.9) end)
    btn:SetScript("OnClick", function()
        if btn.url and btn.url ~= "" then
            Brand.ShowCopyBox("Join our guild's Discord", btn.url)
        end
    end)

    function btn:SetDiscordURL(url)
        btn.url = url
        btn:SetShown(url ~= nil and url ~= "")
    end
    btn:SetDiscordURL(nil)

    return btn
end

-- ── MakeTextLink() / MakeCloseButton() ───────────────────────────
-- Text-link style controls (accent gold, brightening to white on hover)
-- instead of boxed buttons - the confirmed current standard (Routes,
-- 2026-08-16: "it doesn't create such a visual blemish"), applied here
-- 2026-08-19. Neither sets its own anchor point; every call site anchors it
-- itself, same convention as Brand.MakeButton.
function Brand.MakeTextLink(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(20)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    btn.label = label
    btn:SetWidth(math.max(40, label:GetStringWidth() + 8))

    btn:SetScript("OnEnter", function() label:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnLeave", function()
        label:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 1)
    end)
    btn:SetScript("OnClick", onClick)

    return btn
end

function Brand.MakeCloseButton(parent, onClick)
    return Brand.MakeTextLink(parent, "Close", onClick or function() parent:Hide() end)
end

-- ── ShowContextMenu()  ─ a small one-off right-click menu, brand-styled
-- like Brand.MakeDropdown's own option list (same fill/border/highlight),
-- but not tied to any persistent dropdown button - built fresh and shown
-- at a point each time it's needed (Mains/Alts' right-click "Set as Main").
-- Usage: Brand.ShowContextMenu(anchorFrame, {{text=, onClick=fn}, ...})
local ctxMenu, ctxCatcher

local function GetContextMenu()
    if ctxMenu then return ctxMenu end

    ctxMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ctxMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    Brand.ApplyBackground(ctxMenu)
    Brand.DrawBorder(ctxMenu, 0)
    ctxMenu:Hide()

    ctxCatcher = CreateFrame("Frame", nil, UIParent)
    ctxCatcher:SetAllPoints(UIParent)
    ctxCatcher:SetFrameStrata("FULLSCREEN")
    ctxCatcher:EnableMouse(true)
    ctxCatcher:Hide()
    ctxCatcher:SetScript("OnMouseDown", function()
        ctxMenu:Hide()
        ctxCatcher:Hide()
    end)

    ctxMenu.rows = {}
    return ctxMenu
end

function Brand.ShowContextMenu(anchorFrame, items)
    local menu = GetContextMenu()
    local ROW_HEIGHT = 22
    local width = 60
    for _, item in ipairs(items) do
        width = math.max(width, 40 + 12 * #item.text)
    end

    for i, item in ipairs(items) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(ROW_HEIGHT)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 0.25)
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 10, 0)
            text:SetPoint("RIGHT", -10, 0)
            text:SetJustifyH("LEFT")
            row.text = text
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", -2, 0)
        row.text:SetText(item.text)
        row:SetScript("OnClick", function()
            menu:Hide()
            ctxCatcher:Hide()
            item.onClick()
        end)
        row:Show()
    end
    for i = #items + 1, #menu.rows do
        menu.rows[i]:Hide()
    end

    menu:SetSize(width, #items * ROW_HEIGHT + 4)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -2)
    menu:Show()
    ctxCatcher:Show()
end

-- ── ShowCopyBox() ────────────────────────────────────────────────
-- Our own copy-a-URL window, replacing Blizzard's StaticPopup so it carries
-- the addon's background, border and fonts like every other frame here.
-- Also sidesteps the editBox/EditBox field-name churn entirely.
local copyFrame

function Brand.ShowCopyBox(caption, url)
    if not url or url == "" then return end

    if not copyFrame then
        local f = CreateFrame("Frame", "XalsRosterRoundupCopyBox", UIParent)
        f:SetSize(360, 130)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetClampedToScreen(true)
        tinsert(UISpecialFrames, "XalsRosterRoundupCopyBox")

        -- Flat color only, no swirl image - confirmed 2026-09-02 brand refresh.
        -- No outer border either (2026-09-20) - every window in the addon is
        -- borderless now, matching the Options window's cleaner look
        -- against the darker background.
        -- Outer border restored (2026-09-20) - same fix as every other
        -- window in the addon.
        Brand.ApplyBackground(f)
        Brand.DrawBorder(f, 1)

        f.caption = Brand.FS(f, "", Brand.TITLE_FONT_PATH, 15, nil,
            Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])
        f.caption:SetPoint("TOP", f, "TOP", 0, -Brand.SAFE_MARGIN)

        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetHeight(22)
        box:SetPoint("TOPLEFT", f, "TOPLEFT", Brand.SAFE_MARGIN + 10, -46)
        box:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Brand.SAFE_MARGIN, -46)
        box:SetAutoFocus(true)
        box:SetFontObject("GameFontHighlightSmall")
        -- Reselect rather than allow edits: this is for copying, not typing.
        box:SetScript("OnTextChanged", function(self)
            if self.locked then return end
            self.locked = true
            self:SetText(f.url or "")
            self:HighlightText()
            self.locked = false
        end)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        f.box = box

        local hint = Brand.FS(f, "Ctrl+C to copy", Brand.BODY_FONT_PATH, 11, nil, 0.6, 0.6, 0.6)
        hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -6)

        local close = Brand.MakeCloseButton(f, function() f:Hide() end)
        close:SetPoint("BOTTOM", f, "BOTTOM", 0, Brand.SAFE_MARGIN)

        copyFrame = f
    end

    copyFrame.url = url
    copyFrame.caption:SetText(caption or "Copy this link")
    copyFrame.box.locked = true
    copyFrame.box:SetText(url)
    copyFrame.box.locked = false
    copyFrame:Show()
    copyFrame.box:SetFocus()
    copyFrame.box:HighlightText()
end

-- ── MakeCheckbox()  ─ hand-drawn checkbox, same reason/technique as
-- MakeButton's hand-drawn border: Blizzard's native UICheckButtonTemplate
-- was found rendering incomplete (missing its bottom edge entirely, not
-- just uneven thickness) in a real in-game screenshot - confirmed
-- 2026-08-12 on Roster Roundup's Options window. Rather than chase why the
-- native template's art is unreliable, this uses the exact same
-- pixel-snapped 4-texture border technique already proven reliable for
-- Brand.MakeButton/DrawBorder, so it can't have a side silently fail to
-- render. This is now the brand standard for checkboxes - stop using
-- UICheckButtonTemplate in new code.
--
-- Usage differs slightly from a native CheckButton: set `cb.OnToggle =
-- function(self) ... end` instead of `cb:SetScript("OnClick", ...)`, since
-- OnClick is used internally to flip the checked state before your handler
-- runs (matching the native behavior where GetChecked() already reflects
-- the NEW state inside OnClick).
function Brand.MakeCheckbox(parent, size)
    size = size or 22
    local cb = CreateFrame("Button", nil, parent)
    PixelUtil.SetSize(cb, size, size)

    local bg = cb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)

    local thick = Brand.LINE_THICKNESS
    local r, g, b = Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3]

    local borderTop = cb:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderTop, "TOPLEFT", cb, "TOPLEFT", 0, 0)
    PixelUtil.SetPoint(borderTop, "TOPRIGHT", cb, "TOPRIGHT", 0, 0)
    PixelUtil.SetHeight(borderTop, thick)
    borderTop:SetColorTexture(r, g, b, 1)

    local borderBottom = cb:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderBottom, "BOTTOMLEFT", cb, "BOTTOMLEFT", 0, 0)
    PixelUtil.SetPoint(borderBottom, "BOTTOMRIGHT", cb, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetHeight(borderBottom, thick)
    borderBottom:SetColorTexture(r, g, b, 1)

    local borderLeft = cb:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderLeft, "TOPLEFT", cb, "TOPLEFT", 0, 0)
    PixelUtil.SetPoint(borderLeft, "BOTTOMLEFT", cb, "BOTTOMLEFT", 0, 0)
    PixelUtil.SetWidth(borderLeft, thick)
    borderLeft:SetColorTexture(r, g, b, 1)

    local borderRight = cb:CreateTexture(nil, "ARTWORK")
    PixelUtil.SetPoint(borderRight, "TOPRIGHT", cb, "TOPRIGHT", 0, 0)
    PixelUtil.SetPoint(borderRight, "BOTTOMRIGHT", cb, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetWidth(borderRight, thick)
    borderRight:SetColorTexture(r, g, b, 1)

    -- Texture, not a FontString "X" - a font glyph's CENTER anchor centers
    -- against the font's full line-height box (ascender/descender padding
    -- included), not the glyph's actual ink, so it visually drifts off-true-
    -- center. Blizzard's own checkmark texture centers exactly where told,
    -- no font-metrics guesswork. Ported from Quest Compass 2026-08-19
    -- (brand refresh) - this addon was flagged as still having the old
    -- FontString version and likely the same off-center bug.
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetVertexColor(r, g, b, 1)
    PixelUtil.SetSize(check, size - 4, size - 4)
    check:SetPoint("CENTER", cb, "CENTER", 0, 0)
    check:Hide()

    cb.checked = false
    function cb:SetChecked(state)
        self.checked = state and true or false
        if self.checked then check:Show() else check:Hide() end
    end
    function cb:GetChecked()
        return self.checked
    end

    cb:SetScript("OnEnter", function() bg:SetColorTexture(0.18, 0.18, 0.18, 0.75) end)
    cb:SetScript("OnLeave", function() bg:SetColorTexture(0.1, 0.1, 0.1, 0.6) end)
    cb:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if self.OnToggle then self.OnToggle(self) end
    end)

    return cb
end

-- ── MakeDropdown()  ─ brand-styled dropdown, used instead of Blizzard's
-- native UIDropDownMenuTemplate (confirmed 2026-09-22 - this addon should
-- lean on our own styled widgets over Blizzard's stock ones wherever we
-- already have one, not the other way around). Ported from
-- XalsQuestCompass's BrandStyle.lua, which already uses this same widget
-- for its Font/Outline pickers, same as Reins and Compendium.
-- Usage: dd = Brand.MakeDropdown(parent, width); dd:SetOptions({{key=,
-- name=}, ...}); dd:SetValue(key); dd.OnSelect = function(key) ... end.
-- The option list is its own top-level frame (not a child of the dropdown
-- button) so it can draw above a scrollable page's own clipping, same
-- reason Blizzard's native dropdowns also float above everything.
function Brand.MakeDropdown(parent, width)
    local height = 26
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    PixelUtil.SetSize(dd, width, height)
    dd:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    dd:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    Brand.DrawBorder(dd, 0)

    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 10, 0)
    label:SetPoint("RIGHT", -22, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.9, 0.9, 0.9)
    dd.label = label

    local arrow = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    arrow:SetTextColor(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3])

    dd:SetScript("OnEnter", function(self) self:SetBackdropColor(0.18, 0.18, 0.18, 0.75) end)
    dd:SetScript("OnLeave", function(self) self:SetBackdropColor(0.1, 0.1, 0.1, 0.6) end)

    -- List panel: sized to exactly fit its own rows (no fixed height that
    -- could either clip a long list or leave dead space on a short one).
    -- Built once, rows added/reused as SetOptions is called.
    local list = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    Brand.ApplyBackground(list)
    Brand.DrawBorder(list, 0)
    list:Hide()

    -- Invisible full-screen catcher so clicking anywhere outside the list
    -- closes it - the standard way an addon fakes a native dropdown's
    -- click-away-to-close behavior.
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:EnableMouse(true)
    catcher:Hide()

    local function CloseList()
        list:Hide()
        catcher:Hide()
    end
    catcher:SetScript("OnMouseDown", CloseList)

    dd.options = {}
    dd.rows = {}

    local ROW_HEIGHT = 22
    function dd:SetOptions(options)
        self.options = options
        for _, row in ipairs(self.rows) do row:Hide() end
        for i, opt in ipairs(options) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, list)
                row:SetHeight(ROW_HEIGHT)
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(Brand.ACCENT[1], Brand.ACCENT[2], Brand.ACCENT[3], 0.25)
                local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                text:SetPoint("LEFT", 8, 0)
                text:SetPoint("RIGHT", -8, 0)
                text:SetJustifyH("LEFT")
                row.text = text
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", -2, 0)
            row.text:SetText(opt.name)
            row:SetScript("OnClick", function()
                dd:SetValue(opt.key)
                CloseList()
                if dd.OnSelect then dd.OnSelect(opt.key) end
            end)
            row:Show()
        end
        list:SetHeight(#options * ROW_HEIGHT + 4)
    end

    function dd:SetValue(key)
        self.value = key
        for _, opt in ipairs(self.options) do
            if opt.key == key then
                label:SetText(opt.name)
                return
            end
        end
    end

    function dd:GetValue()
        return self.value
    end

    dd:SetScript("OnClick", function(self)
        if list:IsShown() then
            CloseList()
            return
        end
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        list:SetWidth(width)
        list:Show()
        catcher:Show()
    end)

    return dd
end

-- ── MakeAlertIcon()  ─ shared floating attention-icon widget, factored out
-- of the original ApplicationAlertIcon.lua once a second and third alert
-- icon were needed (new members, rank changes) - same glow/drag/tooltip/
-- scale behavior for all of them, just a different glow color, icon
-- texture, saved position key, and click behavior per instance.
--
-- config fields:
--   frameName    - unique global frame name
--   iconPath     - texture shown inside the icon
--   glowColor    - {r, g, b} tint for the pulsing glow (this is the "per-
--                  alert glow color" - each alert type gets its own)
--   posDBKey     - XRR_DB key this icon's dragged position is saved under
--   scaleDBKey   - XRR_DB key this icon's size scale is saved under
--   defaultX/Y   - default screen offset the first time it ever shows
--   onLeftClick / onRightClick - click handlers, (self) -> nil
--   tooltipTitle - the line shown in white/accent at the top of the tooltip
--   buildTooltip - function(tooltip) that adds the rest of the tooltip's lines
--
-- Returns a controller: { frame = <Button>, SetActive = function(self, isActive) end,
-- ApplyScale = function(self) end }.
local ICON_SIZE_BASE = 64
function Brand.MakeAlertIcon(config)
    local controller = {}
    local icon
    -- Mutable, not just config.glowColor directly - lets a caller with more
    -- than one alert type (RosterAlertIcon.lua) change which color is
    -- showing at runtime via controller:SetGlowColor(), not just fix one
    -- color for the icon's whole lifetime.
    local currentColor = config.glowColor

    local function build()
        if icon then return icon end
        local f = CreateFrame("Button", config.frameName, UIParent)
        f:SetSize(ICON_SIZE_BASE, ICON_SIZE_BASE)
        f:SetFrameStrata("MEDIUM")
        f:SetToplevel(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local pos = XRR_DB[config.posDBKey]
        if pos and pos.x then
            f:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", config.defaultX, config.defaultY)
        end

        local glow = f:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture("Interface\\Cooldown\\star4")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER")
        glow:SetVertexColor(currentColor[1], currentColor[2], currentColor[3])
        f.glow = glow

        local glowAnim = glow:CreateAnimationGroup()
        glowAnim:SetLooping("BOUNCE")
        local glowAlpha = glowAnim:CreateAnimation("Alpha")
        glowAlpha:SetFromAlpha(0.35)
        glowAlpha:SetToAlpha(0.85)
        glowAlpha:SetDuration(1.1)
        glowAlpha:SetSmoothing("IN_OUT")
        f.glowAnim = glowAnim

        local tex = f:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(config.iconPath)

        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local cx, cy = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            XRR_DB[config.posDBKey] = { x = cx - ux, y = cy - uy }
        end)

        f:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if config.onRightClick then config.onRightClick(self) end
            else
                if config.onLeftClick then config.onLeftClick(self) end
            end
        end)

        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(config.tooltipTitle, currentColor[1], currentColor[2], currentColor[3])
            if config.buildTooltip then config.buildTooltip(GameTooltip) end
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)

        icon = f
        controller.frame = f
        controller:ApplyScale()
        return f
    end

    function controller:SetGlowColor(color)
        currentColor = color
        if icon then
            icon.glow:SetVertexColor(color[1], color[2], color[3])
        end
    end

    function controller:ApplyScale()
        if not icon then return end
        local scale = XRR_DB[config.scaleDBKey] or 1.0
        local size = ICON_SIZE_BASE * scale
        icon:SetSize(size, size)
        icon.glow:SetSize(size * 1.875, size * 1.875)
    end

    function controller:SetActive(isActive)
        if not isActive then
            if icon then icon:Hide() end
            return
        end
        local f = build()
        f:Show()
        if not f.glowAnim:IsPlaying() then f.glowAnim:Play() end
    end

    return controller
end
