-- Applications.lua
-- Xal's Roster Roundup
--
-- Pulls pending guild-finder applications (the ones waiting for a Guild
-- Master/officer to accept or decline) via the real Blizzard Club Finder
-- API - confirmed against the live client source (Gethe/wow-ui-source,
-- Blizzard_APIDocumentationGenerated/ClubFinderDocumentation.lua) rather
-- than guessed, since this whole feature is worthless if the field names
-- are wrong.
--
-- The server itself is what actually gates this - a player with no
-- permission to view guild applicants just gets an empty list back from
-- C_ClubFinder, so there's no separate permission check needed here (same
-- as how the Guild Finder's own applicant tab behaves).
XRR = XRR or {}
XRR.Applications = {}
local A = XRR.Applications

local updateCallbacks = {}

-- ClubFinderApplicantInfo.classID is a numeric class ID, not a class name -
-- C_CreatureInfo.GetClassInfo(classID) resolves it, then RAID_CLASS_COLORS
-- (Blizzard's own class-color table) gives the real in-game class color.
function A.ClassColor(classID)
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo(classID)
    if info and info.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.classFile] then
        local c = RAID_CLASS_COLORS[info.classFile]
        return c.r, c.g, c.b
    end
    return 0.9, 0.9, 0.9
end

function A.ClassName(classID)
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo(classID)
    return info and info.className or ""
end

-- lastUpdatedTime is a real Unix timestamp (confirmed via Blizzard's own
-- type annotations - "BigInteger ... (unix time)"), not guessed. time() is
-- WoW's own current-Unix-time global.
function A.TimeAgo(unixTime)
    if not unixTime or unixTime == 0 then return "" end
    local seconds = time() - unixTime
    if seconds < 60 then
        return "applied just now"
    elseif seconds < 3600 then
        return "applied " .. math.floor(seconds / 60) .. "m ago"
    elseif seconds < 86400 then
        return "applied " .. math.floor(seconds / 3600) .. "h ago"
    else
        return "applied " .. math.floor(seconds / 86400) .. "d ago"
    end
end

-- Kicks off the server request - the actual list only refreshes once
-- CLUB_FINDER_APPLICATIONS_UPDATED fires back (see the event frame below).
--
-- Blizzard's own Guild & Communities window lives in a separate, lazily
-- loaded addon (Blizzard_Communities) that normally only loads the instant
-- a player opens that window. Until it's loaded, C_ClubFinder's applicant
-- data stays stale/incomplete - confirmed live: with it unloaded, this
-- addon was only seeing 2 old already-resolved applicant records instead
-- of the real 6 pending ones Blizzard's own window showed. Several
-- established addons (NDui, ElvUI's guild datatext module, others) force
-- this same load for this exact reason, so this force-loads it too instead
-- of depending on the player having opened the real Guild window first.
--
-- REMOVED (2026-09-21): this used to also manually fire
-- CLUB_FINDER_APPLICATIONS_UPDATED directly at Blizzard's own
-- CommunitiesFrame ("CommunitiesFrame:OnEvent(...)") to force it to
-- reprocess fresh data. Confirmed live that this taints Blizzard's own
-- Communities UI - the game started throwing ADDON_ACTION_BLOCKED errors
-- for the protected function SetAvatarTexture() deep inside
-- CommunitiesList.lua every time the guild member list redrew, entirely
-- because our addon had run code inside Blizzard's own protected event
-- handler. Forcing Blizzard's own window to break is a worse problem than
-- this addon's list occasionally taking a beat longer to update - the
-- retry-on-GUILD_ROSTER_UPDATE and the delayed retry below still cover the
-- "didn't refresh yet" case without touching CommunitiesFrame directly.
function A:RequestUpdate()
    if C_AddOns and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_Communities") then
        C_AddOns.LoadAddOn("Blizzard_Communities")
    end
    if not (C_ClubFinder and C_ClubFinder.RequestApplicantList) then return end
    C_ClubFinder.RequestApplicantList(Enum.ClubFinderRequestType.Guild)
end

-- Only the applications actually still waiting on a response - closed
-- entries (already accepted/declined/expired) stay in Blizzard's own list
-- for a while after being resolved, so this filters those out.
--
-- Uses ReturnClubApplicantList, NOT ReturnPendingClubApplicantList - the
-- "Pending" one is a different, narrower function that isn't the real
-- applicant list Blizzard's own UI reads from. Confirmed straight from
-- Blizzard's own client source (CommunitiesFrame.lua calls
-- ReturnClubApplicantList) after ReturnPendingClubApplicantList kept
-- returning the exact same two stale, already-resolved records no matter
-- what else got fixed around it.
function A:GetPending()
    if not (C_Club and C_Club.GetGuildClubId and C_ClubFinder and C_ClubFinder.ReturnClubApplicantList) then
        return {}
    end
    local clubId = C_Club.GetGuildClubId()
    if not clubId then return {} end

    local list = C_ClubFinder.ReturnClubApplicantList(clubId) or {}
    local pending = {}
    for _, info in ipairs(list) do
        -- info.closed is a NUMBER (0 = not closed), not a boolean - `not
        -- info.closed` is always false in Lua for a real number (only nil/
        -- false are falsy), so that check was silently rejecting every
        -- single applicant regardless of real data. This was the actual
        -- reason the list stayed empty even with real pending applicants.
        if info.closed == 0 and info.requestStatus == Enum.PlayerClubRequestStatus.Pending then
            table.insert(pending, info)
        end
    end
    return pending
end

-- Default message for the auto-whisper-on-accept feature below - same
-- {player}/{guild} placeholder convention Recruitment.lua's whisper
-- templates already use.
local DEFAULT_ACCEPT_WHISPER = "Congrats {player}, your application to {guild} was accepted! Check your guild invites to join."

local function FillTemplate(template, charName)
    local guildName = GetGuildInfo("player") or ""
    return (template:gsub("{player}", charName):gsub("{guild}", guildName))
end

function A:GetAcceptWhisperTemplate()
    return XRR_DB.acceptWhisperTemplate or DEFAULT_ACCEPT_WHISPER
end

function A:SetAcceptWhisperTemplate(text)
    XRR_DB.acceptWhisperTemplate = text
end

function A:IsAutoWhisperEnabled()
    if XRR_DB.autoWhisperOnAccept == nil then return true end
    return XRR_DB.autoWhisperOnAccept
end

function A:SetAutoWhisperEnabled(enabled)
    XRR_DB.autoWhisperOnAccept = enabled
end

function A:Accept(entry)
    C_ClubFinder.RespondToApplicant(entry.clubFinderGUID, entry.playerGUID, true,
        Enum.ClubFinderRequestType.Guild, entry.name, false)

    -- C_ClubFinder has no way to send a CUSTOM whisper body (its own
    -- SendChatWhisper/ChatFrameUtil.SendTell just pre-fill the chat editbox
    -- for the player to type into and hit Enter themselves - confirmed via
    -- Blizzard's real client source, Blizzard_Communities/
    -- ClubFinderApplicantList.lua + ChatFrameUtil.lua). A real SendChatMessage
    -- whisper is the only way to actually send text automatically. Uses
    -- ConcatinateServerNameToPlayerName(entry.playerGUID) rather than
    -- entry.name for the target - entry.name isn't guaranteed to include
    -- "-Realm", and this is the exact same realm-resolution helper
    -- Blizzard's own whisper button uses (GetPlayerInfoByGUID under the
    -- hood), not a guess.
    if A:IsAutoWhisperEnabled() and ConcatinateServerNameToPlayerName then
        local fullName = ConcatinateServerNameToPlayerName(entry.playerGUID)
        if fullName and fullName ~= "" then
            SendChatMessage(FillTemplate(A:GetAcceptWhisperTemplate(), entry.name), "WHISPER", nil, fullName)
        end
    end
end

function A:Decline(entry)
    C_ClubFinder.RespondToApplicant(entry.clubFinderGUID, entry.playerGUID, false,
        Enum.ClubFinderRequestType.Guild, entry.name, false)
end

function A:Whisper(entry)
    if C_ClubFinder.SendChatWhisper then
        C_ClubFinder.SendChatWhisper(entry.clubFinderGUID, entry.playerGUID,
            Enum.ClubFinderRequestType.Guild, entry.name)
    end
end

-- The Applications settings page and the floating alert icon both need to
-- know the instant the list changes - each registers itself here instead of
-- both hanging their own separate event frame off the same Blizzard event.
function A:OnUpdate(fn)
    table.insert(updateCallbacks, fn)
end

-- Confirmed real Blizzard bug (see the "Guild Applicants Fix" addon and its
-- linked Blizzard bug-report threads): C_ClubFinder.RequestApplicantList
-- silently fails to fire CLUB_FINDER_APPLICATIONS_UPDATED back for some
-- guilds, so the applicant data never actually loads into memory unless
-- something else prompts it again. Rather than depend on that one event
-- ever firing, this also re-requests on GUILD_ROSTER_UPDATE (a much more
-- frequent, reliable event) and does one delayed retry after login, so a
-- guild hit by the bug still gets its applicant list populated within a
-- few seconds instead of staying permanently empty.
-- Temporary diagnostic command - prints exactly what the game is actually
-- returning at each step, so a "still nothing showing" report can be
-- pinned down to a real cause instead of guessed at again. Safe to remove
-- once the applications feature is confirmed working reliably.
SLASH_XRRAPPS1 = "/rrapps"
SlashCmdList["XRRAPPS"] = function()
    print("|cffff8800[Roster Roundup]|r Applications diagnostic:")
    if not (C_Club and C_Club.GetGuildClubId) then
        print("  C_Club.GetGuildClubId not available on this client.")
        return
    end
    local clubId = C_Club.GetGuildClubId()
    print("  clubId: " .. tostring(clubId))
    if not clubId then
        print("  No guild club ID - are you actually in a guild right now?")
        return
    end
    if not (C_ClubFinder and C_ClubFinder.ReturnClubApplicantList) then
        print("  C_ClubFinder.ReturnClubApplicantList not available on this client.")
        return
    end
    local list = C_ClubFinder.ReturnClubApplicantList(clubId) or {}
    print("  raw entries returned: " .. #list)
    for i, info in ipairs(list) do
        print(string.format("  [%d] name=%s closed=%s requestStatus=%s",
            i, tostring(info.name), tostring(info.closed), tostring(info.requestStatus)))
    end
    local pending = A:GetPending()
    print("  entries after filtering: " .. #pending)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("CLUB_FINDER_APPLICATIONS_UPDATED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        A:RequestUpdate()
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                A:RequestUpdate()
                for _, fn in ipairs(updateCallbacks) do fn() end
            end)
        end
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then
        A:RequestUpdate()
    end
    for _, fn in ipairs(updateCallbacks) do fn() end
end)
