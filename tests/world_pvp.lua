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
assert(W.SurvivalText(passive) == "no death")
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

print("PASS: World PvP contested 1v2 recognition rejects sequential passive ganks, records level-based ganks, and preserves notable-only toast policy")
