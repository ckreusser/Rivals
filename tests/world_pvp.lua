local W = DP.WorldPvP
assert(W)

COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40
COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10
COMBATLOG_OBJECT_AFFILIATION_MINE = 0x1

local now, current = 100, nil
GetTime = function() return now end
time = function() return 1700000000 + math.floor(now) end
IsInInstance = function() return false end
UnitName = function(unit) if unit == "player" then return "Alice", "Realm" end return "Unknown", "Realm" end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitGUID = function(unit) if unit == "player" then return "Player-1" end end
GetNumSubgroupMembers = function() return 0 end
GetPlayerInfoByGUID = function(guid)
    local class = guid == "Enemy-1" and "ROGUE" or guid == "Enemy-2" and "MAGE" or "WARRIOR"
    return class, class
end
CombatLogGetCurrentEventInfo = function() return unpack(current) end
DP.HasActiveDuel = function() return false end
W.ShowResultToast = function() end

-- World PvP tracking is no longer user-toggleable. Legacy profiles that had
-- the old Manage toggle saved Off must be migrated back On at initialization.
local legacyDisabledDb = {worldPvPEnabled = false}
W.Initialize({}, legacyDisabledDb, {})
assert(legacyDisabledDb.worldPvPEnabled == true and W.Enabled())

local observer, db = {}, {}
W.Initialize(observer, db, {})
local player = COMBATLOG_OBJECT_TYPE_PLAYER
local hostile = COMBATLOG_OBJECT_REACTION_HOSTILE
local friendly = COMBATLOG_OBJECT_REACTION_FRIENDLY
local function fire(event)
    current = event
    W.Combat("Player-1")
    now = now + 1
end

fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "SWING_DAMAGE", false, "Enemy-1", "Knife", player + hostile, 0,
    "Player-1", "Alice", player + friendly, 0, 220}
fire{now, "SPELL_DAMAGE", false, "Enemy-2", "Mage", player + hostile, 0,
    "Player-1", "Alice", player + friendly, 0, 456, "Frostbolt", 1, 300}
fire{now, "SPELL_CAST_SUCCESS", false, "Enemy-2", "Mage", player + hostile, 0,
    "Enemy-2", "Mage", player + hostile, 0, 11426, "Ice Barrier", 1}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-1", "Knife", player + hostile, 0}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-2", "Mage", player + hostile, 0}
W.Finish("test")

assert(#observer.worldPvP.encounters == 1)
local record = observer.worldPvP.encounters[1]
assert(record.resultKey == "outnumbered_victory")
assert(record.friendlyCount == 1 and record.enemyCount == 2)
assert(record.enemyDeaths == 2 and not record.playerDied)
local mage
for _, enemy in ipairs(record.enemies or {}) do if enemy.guid == "Enemy-2" then mage = enemy end end
if DP.Specs then assert(mage and mage.spec and mage.spec.label == "Deep Frost") end
local summary = W.Summary()
assert(summary.outnumberedVictories == 1 and summary.longestOutnumbered == 2)
local matchups = W.BuildMatchups()
assert(#matchups.Opponents == 2)
assert(W.ShouldShowResultToast(record))
assert(not W.ShouldShowResultToast({friendlyCount = 1, enemyCount = 1, enemyDeaths = 1, playerDied = false, resultKey = "victory"}))
assert(W.ShouldShowResultToast({friendlyCount = 1, enemyCount = 2, enemyDeaths = 1, playerDied = false, resultKey = "outnumbered_escape"}))
assert(not W.ShouldShowResultToast({friendlyCount = 1, enemyCount = 3, enemyDeaths = 2, playerDied = true, resultKey = "outnumbered_partial"}))
assert(record.peakContestingEnemies == 2 and record.contestingEnemyCount == 2 and record.contestingEnemyDeaths == 2)

-- Two sequential passive victims in one long session are two unique enemies,
-- but never an outnumbered fight because neither applied hostile pressure.
local observer2, db2 = {}, {}
W.Initialize(observer2, db2, {})
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-1", "Knife", player + hostile, 0}
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-2", "Mage", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-2", "Mage", player + hostile, 0}
W.Finish("passive-chain")
local passive = observer2.worldPvP.encounters[1]
assert(passive and passive.enemyCount == 2 and passive.enemyDeaths == 2)
assert(passive.peakContestingEnemies == 0 and passive.contestingEnemyCount == 0)
assert(passive.resultKey == "kills" and passive.resultLabel == "2 KILLS")
assert(W.EncounterHeadcount(passive) == "2 enemies")
assert(W.SurvivalText(passive) == "survived")
assert(W.Summary().outnumberedVictories == 0 and W.Summary().soloWins == 0)

-- Max-level downward kills are labeled GANK; 5+ levels lower are LOWBIE GANK.
local targetGUID, targetLevel
UnitGUID = function(unit) if unit == "player" then return "Player-1" elseif unit == "target" then return targetGUID end end
UnitLevel = function(unit) if unit == "player" then return 60 elseif unit == "target" then return targetLevel or 60 end return 60 end
local observer3, db3 = {}, {}
W.Initialize(observer3, db3, {})
targetGUID, targetLevel = "Enemy-1", 58
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-1", "Knife", player + hostile, 0}
W.Finish("gank")
local gank = observer3.worldPvP.encounters[1]
assert(gank and gank.enemies[1].level == 58 and gank.playerLevel == 60)
assert(gank.resultKey == "gank" and gank.resultLabel == "GANK")

local observer4, db4 = {}, {}
W.Initialize(observer4, db4, {})
targetGUID, targetLevel = "Enemy-2", 54
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-2", "Mage", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-2", "Mage", player + hostile, 0}
W.Finish("lowbie-gank")
local lowbie = observer4.worldPvP.encounters[1]
assert(lowbie and lowbie.resultKey == "lowbie_gank" and lowbie.resultLabel == "LOWBIE GANK")
assert(W.CountGanks(lowbie) == 1)

-- A full combat drop followed by a different opponent must split the record
-- immediately, even though the old hard inactivity timeout is 60 seconds.
local observer5, db5 = {}, {}
W.Initialize(observer5, db5, {})
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "SWING_DAMAGE", false, "Enemy-1", "Knife", player + hostile, 0,
    "Player-1", "Alice", player + friendly, 0, 220}
W.Event("PLAYER_REGEN_ENABLED")
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-2", "Mage", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "SWING_DAMAGE", false, "Enemy-2", "Mage", player + hostile, 0,
    "Player-1", "Alice", player + friendly, 0, 220}
W.Finish("split-test")
assert(#observer5.worldPvP.encounters == 2)
assert(observer5.worldPvP.encounters[1].enemyCount == 1 and observer5.worldPvP.encounters[2].enemyCount == 1)
assert(observer5.worldPvP.encounters[1].enemies[1].guid == "Enemy-1")
assert(observer5.worldPvP.encounters[2].enemies[1].guid == "Enemy-2")

-- The same opponent may resume during the short combat-end grace. This keeps
-- Vanish/Feign/CC combat flicker from fragmenting one real fight.
local observer6, db6 = {}, {}
W.Initialize(observer6, db6, {})
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500}
W.Event("PLAYER_REGEN_ENABLED")
now = now + 5
fire{now, "SWING_DAMAGE", false, "Enemy-1", "Knife", player + hostile, 0,
    "Player-1", "Alice", player + friendly, 0, 220}
W.Finish("same-opponent-grace")
assert(#observer6.worldPvP.encounters == 1)
assert(observer6.worldPvP.encounters[1].enemyCount == 1)

-- Streaks are consecutive kills, not consecutive encounter records. A
-- disengage with no death preserves the streak; a player death resets it.
local observer7, db7 = {}, {}
W.Initialize(observer7, db7, {})
observer7.worldPvP.encounters = {
    {enemyDeaths = 3, playerDied = false, enemies = {}, friendlies = {}, friendlyCount = 1, enemyCount = 1},
    {enemyDeaths = 0, playerDied = false, enemies = {}, friendlies = {}, friendlyCount = 1, enemyCount = 1},
    {enemyDeaths = 2, playerDied = false, enemies = {}, friendlies = {}, friendlyCount = 1, enemyCount = 1},
}
local streakSummary = W.Summary()
assert(streakSummary.currentStreak == 5 and streakSummary.longestStreak == 5)
observer7.worldPvP.encounters[#observer7.worldPvP.encounters + 1] =
    {enemyDeaths = 1, playerDied = true, enemies = {}, friendlies = {}, friendlyCount = 1, enemyCount = 1}
observer7.worldPvP.encounters[#observer7.worldPvP.encounters + 1] =
    {enemyDeaths = 4, playerDied = false, enemies = {}, friendlies = {}, friendlyCount = 1, enemyCount = 1}
streakSummary = W.Summary()
assert(streakSummary.currentStreak == 4 and streakSummary.longestStreak == 6)

-- Never present a continent as the Favorite Zone. Existing continent-labeled
-- records can fall back to their retained subzone, while new captures prefer
-- GetZoneText over a continent-level best-map name.
observer7.worldPvP.encounters = {
    {enemyDeaths = 4, playerDied = false, enemies = {}, friendlies = {}, friendlyCount = 1, enemyCount = 1,
        location = {zone = "Kalimdor", subzone = "Feralas"}},
}
local zoneSummary = W.Summary()
assert(zoneSummary.favoriteZone == "Feralas" and zoneSummary.favoriteZoneKills == 4)

C_Map = {
    GetBestMapForUnit = function() return 12 end,
    GetPlayerMapPosition = function() return {GetXY = function() return .42, .58 end} end,
    GetMapInfo = function() return {name = "Kalimdor", mapType = 2} end,
}
GetZoneText = function() return "Feralas" end
GetSubZoneText = function() return "The High Wilderness" end
local observer8, db8 = {}, {}
W.Initialize(observer8, db8, {})
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-1", "Knife", player + hostile, 0}
W.Finish("zone-test")
assert(observer8.worldPvP.encounters[1].location.zone == "Feralas")

-- Enemy aura snapshots retain world buffs and long-duration consumables that
-- were already active before the combat log could see their application.
local observer9, db9 = {}, {}
W.Initialize(observer9, db9, {})
targetGUID, targetLevel = "Enemy-1", 60
UnitBuff = function(unit, index)
    if unit ~= "target" then return nil end
    if index == 1 then return "Rallying Cry of the Dragonslayer", nil, "rally-icon", nil, 7200, now + 7200, nil, nil, nil, 22888 end
    if index == 2 then return "Elixir of the Mongoose", nil, "mongoose-icon", nil, 3600, now + 3600, nil, nil, nil, 17538 end
    if index == 3 then return "Blessing of Kings", nil, "kings-icon", nil, 300, now + 300, nil, nil, nil, 20217 end
    if index == 4 then return "Free Action Potion", nil, "fap-icon", nil, 30, now + 30, nil, nil, nil, 6615 end
    return nil
end
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500}
W.Finish("buff-snapshot-test")
local buffed = observer9.worldPvP.encounters[1] and observer9.worldPvP.encounters[1].enemies[1]
assert(buffed and buffed.detectedBuffs and buffed.detectedBuffs.scanned)
assert(buffed.detectedBuffs.world["22888"] and buffed.detectedBuffs.world["22888"].activeAtEngagement)
assert(buffed.detectedBuffs.consumables["17538"] and buffed.detectedBuffs.consumables["17538"].activeAtEngagement)
assert(buffed.detectedBuffs.all["22888"] and buffed.detectedBuffs.all["22888"].icon == "rally-icon")
assert(buffed.detectedBuffs.all["17538"] and buffed.detectedBuffs.all["17538"].duration == 3600)
assert(buffed.detectedBuffs.all["20217"] and buffed.detectedBuffs.all["20217"].name == "Blessing of Kings")
assert(buffed.detectedBuffs.all["6615"] and buffed.detectedBuffs.all["6615"].duration == 30)
local visibleBuffs = W.GetOpponentBuffsForDetail(buffed)
local visibleNames, visibleByName = {}, {}
for _, aura in ipairs(visibleBuffs) do visibleNames[aura.name] = true; visibleByName[aura.name] = aura end
assert(visibleNames["Rallying Cry of the Dragonslayer"] and visibleNames["Elixir of the Mongoose"] and visibleNames["Blessing of Kings"])
assert(visibleByName["Elixir of the Mongoose"].itemID == 13452)
assert(not visibleNames["Free Action Potion"])
UnitBuff = nil

-- A Paladin who successfully uses Divine Shield and then Hearthstone inside
-- the bubble window is a specific escape outcome, not a generic disengage.
local observerBH, dbBH = {}, {}
W.Initialize(observerBH, dbBH, {})
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-Paladin", "Golden", player + hostile, 0, 123, "Mortal Strike", 1, 200, -1}
fire{now, "SPELL_AURA_APPLIED", false, "Enemy-Paladin", "Golden", player + hostile, 0,
    "Enemy-Paladin", "Golden", player + hostile, 0, 642, "Divine Shield", 2, "BUFF"}
fire{now, "SPELL_CAST_SUCCESS", false, "Enemy-Paladin", "Golden", player + hostile, 0,
    "Enemy-Paladin", "Golden", player + hostile, 0, 8690, "Hearthstone", 1}
W.Finish("combat-ended")
local bubbled = observerBH.worldPvP.encounters[1]
assert(bubbled and bubbled.resultKey == "bubble_hearth" and bubbled.resultLabel == "BUBBLE HEARTHED")
assert(bubbled.bubbleHearthEnemyGUID == "Enemy-Paladin")
assert(W.BubbleHearthEnemy(bubbled) and W.BubbleHearthEnemy(bubbled).name == "Golden")
assert(W.SurvivalText(bubbled) == "survived")

-- Older records can be reclassified from their retained combat log even if the
-- live session flag did not exist when they were recorded.
bubbled.bubbleHearthEnemyGUID = nil
for _, enemy in ipairs(bubbled.enemies or {}) do enemy.bubbleHearthed = nil end
bubbled.resultKey, bubbled.resultLabel, bubbled.outcomeModelVersion = "disengaged", "DISENGAGED", 3
W.Initialize(observerBH, dbBH, {})
assert(bubbled.resultKey == "bubble_hearth" and bubbled.bubbleHearthEnemyGUID == "Enemy-Paladin")

-- Automatic screenshots should use the lethal damage event as the timing
-- anchor, but wait briefly for the Killing Blow / HK combat text to animate in.
-- PARTY_KILL / UNIT_DIED remain fallback-only and must not race the pending timer.
local screenshotCalls, screenshotTimers = {}, {}
DP.TakeRivalsScreenshot = function(kind, subject)
    screenshotCalls[#screenshotCalls + 1] = {kind = kind, subject = subject, event = current and current[2]}
    return true
end
local oldCTimer = C_Timer
C_Timer = {
    After = function(delay, callback)
        screenshotTimers[#screenshotTimers + 1] = {delay = delay, callback = callback, event = current and current[2]}
    end,
}
local observer10, db10 = {}, {}
W.Initialize(observer10, db10, {})
targetGUID, targetLevel = "Enemy-1", 60
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 300, -1}
assert(#screenshotCalls == 0 and #screenshotTimers == 0)
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0, 123, "Mortal Strike", 1, 500, 42}
assert(#screenshotCalls == 0 and #screenshotTimers == 1)
assert(screenshotTimers[1].delay == 0.20 and screenshotTimers[1].event == "SPELL_DAMAGE")
fire{now, "PARTY_KILL", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-1", "Knife", player + hostile, 0}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-1", "Knife", player + hostile, 0}
assert(#screenshotCalls == 0)
screenshotTimers[1].callback()
assert(#screenshotCalls == 1 and screenshotCalls[1].subject == "Knife")

-- If no lethal overkill signal is available, the later death event still
-- captures immediately instead of waiting for a timer that was never armed.
targetGUID = "Enemy-2"
fire{now, "SPELL_DAMAGE", false, "Player-1", "Alice", player + friendly, 0,
    "Enemy-2", "Mage", player + hostile, 0, 123, "Mortal Strike", 1, 200, -1}
fire{now, "UNIT_DIED", false, nil, nil, 0, 0, "Enemy-2", "Mage", player + hostile, 0}
assert(#screenshotCalls == 2 and screenshotCalls[2].event == "UNIT_DIED")
C_Timer = oldCTimer
DP.TakeRivalsScreenshot = nil

-- History rows reserve compact space for the synopsis and NvN before lower-priority stats.
local historyLine = W.HistoryResultLine({friendlyCount = 1, enemyCount = 2, enemyDeaths = 1,
    resultKey = "outnumbered_escape", resultLabel = "OUTNUMBERED ESCAPE",
    enemies = {{name = "Mol-Realm", class = "MAGE", level = 60, died = true},
        {name = "Other-Realm", class = "ROGUE", level = 60}}})
assert(historyLine:find("OUTNUMBERED ESCAPE", 1, true) and historyLine:find("1 vs 2", 1, true))
assert(not historyLine:find("kill", 1, true) and not historyLine:find("...", 1, true))

print("PASS: World PvP pressure, combat-boundary splitting, kill streaks, zone labels, ganks, bubble-hearth escapes, notable-only toast policy, complete enemy buff snapshots, and delayed lethal-hit screenshots")
