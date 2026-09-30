-- RosterAlertIcon.lua
-- Xal's Roster Roundup
--
-- ONE floating icon (not one per alert type) that shows up whenever
-- anything needs your attention, with its glow tinted to whichever kind of
-- thing it is - orange for a pending application, blue for an unreviewed
-- new member, purple for a real in-game rank change. Built on
-- Brand.MakeAlertIcon (BrandStyle.lua).
--
-- Priority when more than one is true at once (only one glow shows at a
-- time): applications first (they need an actual decision), then new
-- members, then rank changes (informational). The tooltip always lists
-- everything currently pending, not just whichever one is driving the
-- glow color.
XRR = XRR or {}
XRR.RosterAlertIcon = XRR.RosterAlertIcon or {}
local Alert = XRR.RosterAlertIcon
local Brand = XRR.BrandStyle
local Apps = XRR.Applications
local R = XRR.Roster

local ICON_PATH = "Interface\\AddOns\\XalsRosterRoundup\\Textures\\MinimapIcon_Book1.png"

local function CurrentGuild()
    return R:GetCurrentGuild()
end

-- Each entry: a name, its own glow color, how to count it, and what
-- clicking should open. Ordered by priority - first one with count > 0 wins
-- the glow color and the left-click destination. Banned rejoin is first/
-- most urgent - see Roster.lua's ban list.
local ALERT_TYPES = {
    {
        key = "bannedRejoins",
        color = Brand.ALERT_COLOR_BAN_REJOIN,
        getCount = function()
            local guild = CurrentGuild()
            return guild and #R:GetBannedRejoins(guild) or 0
        end,
        openTo = function() XRR.Options:OpenToGuildMaster() end,
        label = function(n) return n .. " banned name" .. (n == 1 and "" or "s") .. " rejoined the guild" end,
    },
    {
        key = "applications",
        color = Brand.ACCENT,
        getCount = function() return #Apps:GetPending() end,
        openTo = function() XRR.Options:OpenToApplications() end,
        label = function(n) return n .. " pending application" .. (n == 1 and "" or "s") end,
    },
    {
        key = "newMembers",
        color = Brand.ALERT_COLOR_NEW_MEMBER,
        getCount = function()
            local guild = CurrentGuild()
            return guild and #R:GetUnreviewedMembers(guild) or 0
        end,
        openTo = function() XRR.Options:OpenToGuildMaster() end,
        label = function(n) return n .. " new member" .. (n == 1 and "" or "s") .. " to review" end,
    },
    {
        key = "rankChanges",
        color = Brand.ALERT_COLOR_RANK_CHANGE,
        getCount = function()
            local guild = CurrentGuild()
            return guild and #R:GetPendingRankChanges(guild) or 0
        end,
        openTo = function() XRR.Options:OpenToGuildMaster() end,
        label = function(n) return n .. " rank change" .. (n == 1 and "" or "s") end,
    },
}

-- Which alert is currently driving the glow color/click target - re-picked
-- every time UpdateVisibility runs, not cached, so it always reflects
-- what's actually true right now.
local activeType

local controller = Brand.MakeAlertIcon({
    frameName = "XRRRosterAlertIcon",
    iconPath = ICON_PATH,
    -- Placeholder until UpdateVisibility picks the real one on first show -
    -- Brand.MakeAlertIcon reads glowColor once at build time, so the real
    -- color gets applied via SetGlowColor below instead.
    glowColor = Brand.ACCENT,
    posDBKey = "rosterAlertIconPos",
    scaleDBKey = "rosterAlertIconScale",
    defaultX = -250,
    defaultY = 260,
    tooltipTitle = "Xal's Roster Roundup",
    buildTooltip = function(tooltip)
        for _, t in ipairs(ALERT_TYPES) do
            local n = t.getCount()
            if n > 0 then
                tooltip:AddLine(t.label(n))
            end
        end
        tooltip:AddLine("|cff999999Left-click:|r review")
        tooltip:AddLine("|cff999999Right-click:|r refresh")
    end,
    onLeftClick = function()
        if activeType then activeType.openTo() end
    end,
    onRightClick = function()
        Apps:RequestUpdate()
    end,
})

function Alert:UpdateVisibility()
    activeType = nil
    for _, t in ipairs(ALERT_TYPES) do
        if t.getCount() > 0 then
            activeType = t
            break
        end
    end

    if not activeType then
        controller:SetActive(false)
        return
    end

    controller:SetGlowColor(activeType.color)
    controller:SetActive(true)
end

function Alert:ApplyScale()
    controller:ApplyScale()
end

function Alert:Init()
    Apps:OnUpdate(function() Alert:UpdateVisibility() end)
    R:OnSync(function() Alert:UpdateVisibility() end)
    Alert:UpdateVisibility()
end
