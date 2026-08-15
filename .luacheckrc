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
}

-- Textures/backdrop tables and long chained SetPoint calls read as "unused
-- variable"/line-length noise in generated UI code like this - not real bugs.
max_line_length = false
unused_args = false
