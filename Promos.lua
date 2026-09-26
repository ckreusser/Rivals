local _, DP = ...
local P = {url = "https://www.curseforge.com/wow/addons/rivals"}
DP.Promos = P

P.messages = {
    "World PvP finally gets a match history. Rivals records who you fought, where it happened, who participated, the result, and your history against every opponent.",

    "Was it really a 1v3? Rivals remembers. Track solo fights, outnumbered victories, streaks, ganks, repeat opponents, and the wins that were worth more than one HK.",

    "The corpse is gone. The fight isn’t. Rivals saves World PvP combat logs, opponents, items, consumables, engineering, long cooldowns, racials, and other fight details for later.",

    "Know what they actually used against you. Rivals records observed gear activations, PvP trinkets, potions, engineering gadgets, major cooldowns, racials, and enemy buffs in World PvP encounters.",

    "Every realm has names you remember. Rivals remembers the record. See your kills, encounters, solo results, Most Killed rivals, Nemesis, and complete history against repeat opponents.",

    "Put a face to the rivalry. Rivals builds World PvP opponent records with character details, encounter portraits, class information, and your history against that player.",

    "Remember where it happened. Rivals keeps the zone, encounter location, map marker, opponents, and result for your World PvP fights instead of reducing them to another HK.",

    "Someone used everything they had to kill you. Check the receipts. Rivals keeps detailed Items & Abilities and combat-log records for both World PvP and duels.",

    "Watch them spend gold to lose. Rivals estimates the value of consumables your opponent—or an entire enemy group—burned during the fight, so you can see exactly how much gold they spent just to end up dead.",

    "Classic dueling with an actual record. Rivals adds Elo-style rating, placements, personal bests, Rated and Casual duels, detailed match history, and class and opponent matchups.",

    "“I’m up on you” doesn’t have to be a debate. Rivals tracks your duel record against individual players, rating changes, matchup history, and the details of every recorded duel.",

    "When both players run Rivals, Rated duels can be Rivals Verified. Build a duel rating backed by recorded matches instead of screenshots and memory.",

    "Inspect another Rivals player and see the record. Shared duel profiles bring rating, record, and matchup history into the normal WoW Inspect window.",

    "Classic PvP creates rivalries. Rivals keeps them. World PvP encounters, duels, opponent histories, combat logs, items, cooldowns, matchups, and the fights you actually want to remember.",
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
