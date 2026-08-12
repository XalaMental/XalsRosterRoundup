-- Xal's Roster Roundup
-- Guild member roster/profile helper for guild officers.
--
-- Core.lua creates the shared XRR table every other file attaches to,
-- and sets up SavedVariables defaults. Loaded first (see .toc).

XRR = XRR or {}

XRR_DB = XRR_DB or {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Must run before any panel is ever built (Options/GuildPanel are
        -- lazy-built on first Open, well after this) so saved
        -- accent/background/font customization is in place from the start.
        XRR.BrandStyle.ApplySavedTheme()
        XRR.MinimapButton:Register()
    end
end)
