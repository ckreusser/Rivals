local _, DP = ...
local P = {url = "https://www.curseforge.com/wow/addons/rivals"}
DP.Promos = P

P.messages = {
    "Make your duels count. Rivals tracks your duel rating, match history, and rivalries in your Character window.",
    "Who's your toughest matchup? Rivals tracks your record against opponents and classes so you can follow your progress.",
    "Run it back. Rivals keeps your duel history, rating changes, and personal best in one place.",
    "Just practicing or playing for rating? Rivals supports Casual and Rated duels, with both players agreeing before a Rated match.",
    "Build your record. Rivals offers lifetime tracking, local seasons, and a rating graph for your Classic Era duels.",
    "Know your rivals. Inspect another Rivals user to see their shared duel profile alongside your own matchup record.",
    "From your first placement to your next personal best: Rivals adds duel progression to Classic Era.",
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
