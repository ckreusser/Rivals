local _, DP = ...
local P = {url = "https://www.curseforge.com/wow/addons/rivals"}
DP.Promos = P

P.messages = {
    "World PvP finally gets a history. Rivals records the players you fight, the result, the location, the map position, and your record against every repeat opponent.",

    "Every realm has names you remember. Rivals keeps the score: your record against each player, Most Killed, Nemesis, streaks, solo fights, ganks, and repeat encounters.",

    "Was it really a 1v3? Rivals remembers. World PvP encounters keep the actual headcount, kills, deaths, escapes, trades, and outnumbered victories instead of reducing the fight to an HK.",

    "Check the receipts. Rivals tracks enemy buffs, consumables, engineering, major cooldowns, and an estimated gold value for what enemy players used against you in World PvP.",

    "Remember where the fight happened. Rivals saves the zone, map capture, fight marker, opponents, and result for World PvP encounters, with favorites that can stay in your history permanently.",

    "Put a face to the rivalry. Rivals builds opponent plaques with reconstructed character portraits, class details, and your World PvP history against that player.",

    "For both World PvP and duels, Rivals keeps the details people forget: items, consumables, engineering, major cooldowns, combat events, and opponent history.",

    "Classic dueling with an actual rating. Rivals adds Rated and Casual duels, Elo-style progression, placements, personal bests, rating history, and opponent and class matchups.",

    "If both players run Rivals, Rated duels can be Rivals Verified. Inspect another Rivals player to see their shared duel profile, rating, record, and your matchup history.",

    "Classic PvP creates rivalries. Rivals gives them a record: World PvP encounters, duels, opponent histories, map captures, portraits, combat logs, cooldowns, and the fights you actually want to remember.",
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
