-- .luacheckrc
-- Xal's Roster Roundup
--
-- Scoped to the actual WoW API calls and globals this addon uses (not a
-- copy-pasted full addon's config) - add to `globals`/`read_globals` as new
-- API calls get added, rather than pulling in a giant generic list.
std = "lua51"

-- This addon's own cross-file globals (declared in Core.lua, attached to by
-- every other file).
globals = {
    "XRR",
    "XRR_DB",
    "XRR_CharDB",
    "StaticPopupDialogs", -- a real mutable table addons add popup entries to
    "ColorPickerFrame", -- Blizzard's own color picker, fields set directly on it
    "SLASH_XRRAPPS1", -- this addon's own slash-command name global
    "SlashCmdList", -- Blizzard's own table, addons add entries to it directly
}

-- Read-only: real WoW client API/globals + the bundled libs' own globals.
read_globals = {
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "UnitName",
    "IsInGuild",
    "C_GuildInfo",
    "GetGuildInfo",
    "GetNumGuildMembers",
    "GetGuildRosterInfo",
    "StaticPopup_Show",
    "StaticPopup_Hide",
    "PixelUtil",
    "LibStub",
    "wipe",
    "tinsert",
    "UISpecialFrames",
    "ChatFrame_OpenChat",
    "DEFAULT_CHAT_FRAME",
    "C_Timer",
    "ChatFontNormal",
    "C_AddOns",
    "GetAddOnMetadata",
    "C_Club",
    "C_ClubFinder",
    "C_CreatureInfo",
    "RAID_CLASS_COLORS",
    "Enum",
    "print",
    "CommunitiesFrame",
    "time",
    "date",
    "GetGuildRosterLastOnline",
    "GuildControlGetRankName",
    "GuildControlGetNumRanks",
    "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_SetText",
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton",
    "CanGuildPromote",
    "CanGuildDemote",
    "CanGuildRemove",
    "CanGuildInvite",
    "C_FriendList",
    "GetChannelList",
    "GetRealZoneText",
    "SendChatMessage",
    "Clamp",
    "CreateMacro",
    "EditMacro",
    "GetMacroIndexByName",
    "SetBindingMacro",
    "GetBindingKey",
    "SaveBindings",
    "GetCurrentBindingSet",
    "ConcatinateServerNameToPlayerName",
    "UnitFullName",
    "GetCursorPosition",
    "CopyTable",
    "GetNormalizedRealmName",
    "GetTime",
    "C_ChatInfo",
    "issecretvalue",
    "C_AlliedRaces",
    "InCombatLockdown",
    "FriendsFrame",
    "GetClubFinderLink",
    "ClubFinderGetCurrentClubListingInfo",
    "HideUIPanel",
    "PlaySound",
    "Settings",
    "SettingsPanel",
    "InterfaceOptions_AddCategory",
    "UnitName",
    "GetMaxLevelForPlayerExpansion",
    "CanEditMOTD",
    "CanEditGuildInfo",
    "GetGuildRosterMOTD",
    "GetGuildInfoText",
    "SetGuildInfoText",
    "GuildSetMOTD",
    "Menu",
    "UnitIsPlayer",
    "UnitIsUnit",
    "UnitIsInMyGuild",
    "UnitExists",
    "UnitClass",
    "UnitLevel",
    "UnitRace",
    "OptionsSliderTemplate",
    "SOUNDKIT",
}

-- Textures/backdrop tables and long chained SetPoint calls read as "unused
-- variable"/line-length noise in generated UI code like this - not real bugs.
max_line_length = false
unused_args = false
