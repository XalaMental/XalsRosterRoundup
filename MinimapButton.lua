-- MinimapButton.lua
-- Xal's Roster Roundup
--
-- The minimap launcher icon, via LibDataBroker + LibDBIcon - same
-- combination Routes/Courier/Compendium use.
XRR = XRR or {}
XRR.MinimapButton = {}
local MB = XRR.MinimapButton

-- Full custom-shaped icon, not masked into Blizzard's standard circular
-- border - same technique Routes/Courier use (RemoveButtonBorder/
-- RemoveButtonBackground/SetButtonIcon, LibDBIcon rev 56+).
local MINIMAP_ICON = "Interface\\AddOns\\XalsRosterRoundup\\Textures\\MinimapIcon_Book2.png"
local MINIMAP_ICON_SIZE = 34

function MB:Register()
    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("XalsRosterRoundup", {
        type = "launcher",
        text = "Xal's Roster Roundup",
        icon = MINIMAP_ICON,
        -- Both buttons open the same single window now (2026-09-20 merge) -
        -- right-click just jumps straight to the Roster page instead of
        -- opening a separate popup, since that popup no longer exists.
        OnClick = function(_, button)
            if button == "RightButton" then
                XRR.Options:OpenToRoster()
            else
                XRR.Options:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Xal's Roster Roundup")
            tooltip:AddLine("|cff999999Left-click|r to open Options")
            tooltip:AddLine("|cff999999Right-click|r to jump to the Guild Roster")
        end,
    })

    XRR_DB.minimap = XRR_DB.minimap or { hide = false }
    local icon = LibStub("LibDBIcon-1.0")
    icon:Register("XalsRosterRoundup", ldb, XRR_DB.minimap)

    -- The size is set ONCE, at login, to the family default (34); after that
    -- it belongs to whatever resizes it (a minimap-button collector, scale
    -- tools). The picture fills the whole button, so it grows and shrinks
    -- with the button instead of staying a fixed smaller size inside it.
    if icon.SetButtonSize and icon:GetMinimapButton("XalsRosterRoundup") then
        icon:SetButtonSize("XalsRosterRoundup", MINIMAP_ICON_SIZE)
        icon:RemoveButtonBorder("XalsRosterRoundup")
        icon:RemoveButtonBackground("XalsRosterRoundup")
        icon:SetButtonIcon("XalsRosterRoundup", MINIMAP_ICON, MINIMAP_ICON_SIZE, "CENTER", 0, 0)
    end
end

-- Backing the future Settings checkbox - LibDBIcon's own Show/Hide API, not
-- a manual texture toggle.
function MB:SetShown(shown)
    XRR_DB.minimap = XRR_DB.minimap or { hide = false }
    XRR_DB.minimap.hide = not shown
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end
    if shown then
        icon:Show("XalsRosterRoundup")
    else
        icon:Hide("XalsRosterRoundup")
    end
end
