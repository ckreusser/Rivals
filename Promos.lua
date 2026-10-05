local _, DP = ...
local P = {url = "https://www.curseforge.com/wow/addons/rivals"}
DP.Promos = P

P.messages = {
    "They killed you once. You killed them six times after. Rivals remembers the part that matters.",

    "World PvP has a memory now. Track every fight, every rematch, every streak, and every player who keeps showing up.",

    "DOUBLE KILL. TRIPLE KILL. Keep going. Rivals brings Reach-style killstreak medals to Classic World PvP.",

    "That 1v3 wasn't just another fight. Rivals records outnumbered victories and keeps the proof.",

    "Know exactly what they used to survive. Enemy buffs, consumables, gadgets, cooldowns, and estimated gold burned—all captured with the encounter.",

    "Some names stop being random. Rivals builds a history against the players you keep running into.",

    "You remember winning. Rivals remembers how. Open the encounter for killing blows, damage exchange, buffs, consumables, items, abilities, and the combat log.",

    "Dueling someone again? Check the receipts. See your record, previous fights, matchup history, and what happened last time.",

    "That guy again. Rivals tracks repeat opponents across World PvP so recurring enemies actually become rivals.",

    "Your best killstreak deserves more than scrolling combat text. Earn medals as the bodies pile up—and put the medal feed wherever you want it.",

    "The fight cost them more than a corpse run. Rivals estimates the gold value of consumables burned during the encounter.",

    "Classic PvP already creates rivalries. Rivals just keeps score.",

    "Won while outnumbered? Rivals knows the difference between a kill and a story worth remembering.",

    "A screenshot, the opponents, the buffs, the combat log, the result. Rivals keeps the whole encounter instead of just adding another kill to a counter.",

    "Rated duel or open-world grudge match, the history follows the player. Rivals keeps both sides of your PvP life in one place.",
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
