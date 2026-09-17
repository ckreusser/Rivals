local _, DP = ...
local P = {url = "https://www.curseforge.com/wow/addons/rivals"}
DP.Promos = P

P.messages = {
    "Turn every duel into a record. Rivals adds an Elo-style duel rating, placements, personal bests, rating history, and protections against artificial boosting.",

    "See what actually happened in every duel. Rivals records items, engineering gadgets, long cooldowns, inferred specs, and a timestamped combat log.",

    "Your duel history should be more than a vague memory. Rivals keeps detailed match records with rating changes, Rival estimates, used gear, cooldowns, specs, and combat events.",

    "Find out who you can beat and who has your number. Rivals tracks opponent and class matchups, lifetime results, local seasons, and rating progression.",

    "Rated or just practicing? Rivals supports Rated and Casual duels. When both players run Rivals, Rated matches can be Rivals Verified before the fight.",

    "Inspect another Rivals player to see their shared duel profile, rating, record, and your matchup history against them—all inside the Character and Inspect panes.",

    "Classic Era dueling, with progression. Rivals turns your duels into a rating, detailed history, matchup profile, and a record you can actually build over time.",
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
