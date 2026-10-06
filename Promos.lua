local _, DP = ...
local P = {url = "https://www.curseforge.com/wow/addons/rivals"}
DP.Promos = P

P.messages = {
    "You remember the name. Rivals remembers the score. Track every World PvP encounter, every rematch, every streak, and every player who keeps coming back.",

    "World PvP finally has a history. Rivals records who you fought, who won, what happened, and how the rivalry develops over time.",

    "That wasn’t just a kill. It was the start of a rivalry. Build a permanent record against the players you encounter in the open world.",

    "How long can you keep it going? Track your current and best World PvP killstreaks—and get Reach-inspired medals as the bodies pile up.",

    "Winning a 1v1 is expected. Winning a 1v3 gets remembered. Rivals tracks solo multikills and your best outnumbered victories.",

    "Rivals knows when the fight wasn’t fair—and when you won anyway. Track outnumbered World PvP victories, ganks, streaks, and repeat opponents.",

    "The fight ends. The evidence doesn’t. Review damage exchange, killing blows, abilities, items, enemy buffs, consumables, and the full combat log after the encounter.",

    "Wonder what they had running when you fought them? Rivals snapshots enemy buffs so you can see exactly what you were up against.",

    "How expensive was that fight? Rivals tracks consumables used in World PvP and estimates what they cost at the time of the encounter.",

    "Some players are random encounters. Others become Rivals. See who you fight most, who keeps killing you, and who keeps showing up in your history.",

    "Your World PvP résumé writes itself. Streaks, encounters, solo multikills, outnumbered wins, rival history, and detailed fight records—all captured automatically.",

    "Settle it again. Rivals keeps the receipts. Track your duel record against individual players and see exactly how the matchup has gone over time.",

    "Rivals Verified means both sides were there. When both duelists run Rivals, the match becomes part of a shared competitive record.",

    "Whether it happens outside Orgrimmar or somewhere you absolutely weren’t supposed to survive, Rivals remembers it. World PvP and duels become a searchable history instead of another forgotten combat log.",
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
