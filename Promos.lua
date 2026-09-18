local _, DP = ...
local P = {url = "https://www.curseforge.com/wow/addons/rivals"}
DP.Promos = P

P.messages = {
    "Rivals turns open-world PvP into a real record. Track kills, streaks, rivals, solo fights, ganks, outnumbered wins, and where every encounter happened.",

    "Every World PvP encounter gets a map record with the fight location, opponents, result, items, abilities, and combat log.",

    "Pull off a real 1v2 or 1v3? Rivals tracks solo 1vN victories separately from sequential kills and passive ganks.",

    "Know who has your number. Rivals builds open-world records against individual players and classes, including your most-killed rivals and nemeses.",

    "Star the fights worth remembering. Favorite duels and World PvP encounters for quick access, and preserve starred World PvP records beyond the rolling history cap.",

    "Duels and World PvP both get detailed fight records with opponents, items, abilities, cooldowns, and combat events.",

    "Turn duels into progression. Rivals adds Elo-style rating, placements, personal bests, rating history, and opponent and class matchup records.",

    "Rated or just practicing? Rivals supports Rated and Casual duels, with Rivals Verified matches when both players are running the addon.",
}

function P.Click(_, button)
    if button ~= "LeftButton" or not IsControlKeyDown or not IsShiftKeyDown or
        not IsControlKeyDown() or not IsShiftKeyDown() then return end
    if not RivalsDB or RivalsDB.schemaVersion ~= 1 or not GetChannelName or not SendChatMessage then return end
    -- Use the user's actual /4, never substitute Trade or join a channel.
    local channel = GetChannelName(4)
    if channel ~= 4 then return end
    local index = RivalsDB.nextPromo
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #P.messages then index = 1 end
    local ok, result = pcall(SendChatMessage, P.messages[index] .. " " .. P.url, "CHANNEL", nil, channel)
    if ok and result ~= false then RivalsDB.nextPromo = index % #P.messages + 1 end
end

function P.Attach(logo)
    logo:EnableMouse(true)
    logo:SetScript("OnMouseUp", P.Click)
end
