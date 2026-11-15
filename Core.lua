-- Xal's Roster Roundup
-- Guild member roster/profile helper for guild officers.
--
-- Core.lua creates the shared XRR table every other file attaches to,
-- and sets up SavedVariables defaults. Loaded first (see .toc).

XRR = XRR or {}

-- WoW Forever runs the modern engine with vanilla content and reports an
-- Interface number in the 16000s. Retail-only content assumptions (level cap,
-- Guild Finder) are checked against this flag.
do
    local build = select(4, GetBuildInfo())
    XRR.IsForever = (type(build) == "number" and build >= 16000 and build < 20000) and true or false
end

XRR_DB = XRR_DB or {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Must run before any panel is ever built (Options/GuildPanel are
        -- lazy-built on first Open, well after this) so saved
        -- accent/background/font customization is in place from the start.
        -- Skin first (the palette every window uses), then the saved custom
        -- colors on top of it. Someone who had already picked their own
        -- accent/background keeps that look: they start on the Crimson skin
        -- (the old default) instead of the new default.
        if XRR_DB.skin == nil then
            XRR_DB.skin = (XRR_DB.accentColor or XRR_DB.bgColor) and "current" or "ember"
        end
        XRR_DB.skin = XRR.BrandStyle.ApplySkin(XRR_DB.skin)
        XRR.BrandStyle.ApplySavedTheme()
        XRR.MinimapButton:Register()
        XRR.Options:RegisterNativePanel()
        XRR.WhatsNew:CheckAndShow()
        XRR.RosterAlertIcon:Init()
    end
end)
