local _, DP = ...
local U = {prefix = "RivalsVersion1"}
DP.Updates = U

local NOTICE = "Fresh updates. Same grudges. Get the latest build on CurseForge."
local CHANNELS = {GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true}

local function Parse(version)
    if type(version) ~= "string" or #version > 20 then return end
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then return end
    return {tonumber(major), tonumber(minor), tonumber(patch)}
end

function U.IsNewer(candidate, current)
    local a, b = Parse(candidate), Parse(current)
    if not a or not b then return false end
    for i = 1, 3 do
        if a[i] ~= b[i] then return a[i] > b[i] end
    end
    return false
end

function U.CheckNotice()
    if U.notified or not U.settings or not U.IsNewer(U.settings.newestKnownRivalsVersion, U.version) then return end
    U.notified = true
    U.say(NOTICE)
end

local function Send(channel, query)
    if not U.available or not CHANNELS[channel] then return end
    local now = GetTime()
    local key = channel .. (query and "Q" or "V")
    local cooldown = query and 60 or 10
    if U.sentAt[key] and now - U.sentAt[key] < cooldown then return end
    U.sentAt[key] = now
    -- Announce only the installed release, never another player's claim.
    pcall(C_ChatInfo.SendAddonMessage, U.prefix, (query and "Q|" or "V|") .. U.version, channel)
end

function U.Announce()
    if IsInGuild and IsInGuild() then Send("GUILD", true) end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        Send("INSTANCE_CHAT", true)
    elseif IsInRaid and IsInRaid() then
        Send("RAID", true)
    elseif IsInGroup and IsInGroup() then
        Send("PARTY", true)
    end
end

function U.Receive(prefix, message, channel, sender)
    if not U.settings or prefix ~= U.prefix or not CHANNELS[channel] or type(sender) ~= "string" or sender == "" then return end
    if type(message) ~= "string" or #message > 22 then return end
    local kind, version = message:match("^([QV])|(.+)$")
    if not Parse(version) then return end
    if U.IsNewer(version, U.version) and
            (not Parse(U.settings.newestKnownRivalsVersion) or U.IsNewer(version, U.settings.newestKnownRivalsVersion)) then
        U.settings.newestKnownRivalsVersion = version
    end
    U.CheckNotice()
    if kind == "Q" then
        local name, realm = UnitName("player"), GetNormalizedRealmName()
        if sender ~= name and sender ~= name .. "-" .. realm then Send(channel, false) end
    end
end

function U.ScheduleAnnouncement()
    if U.pending then return end
    U.pending = true
    C_Timer.After(5, function()
        U.pending = nil
        U.CheckNotice()
        U.Announce()
    end)
end

function U.Initialize(settings, version, say)
    if U.settings or not Parse(version) then return end
    U.settings, U.version, U.say, U.sentAt = settings, version, say, {}
    if not U.IsNewer(settings.newestKnownRivalsVersion, version) then settings.newestKnownRivalsVersion = nil end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage then
        local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, U.prefix)
        U.available = ok and result ~= false
        if ok and type(result) == "number" and Enum and Enum.RegisterAddonMessagePrefixResult then
            U.available = result == Enum.RegisterAddonMessagePrefixResult.Success
        end
    end
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then U.Receive(...) else U.ScheduleAnnouncement() end
    end)
    U.frame = frame
    U.ScheduleAnnouncement()
end
