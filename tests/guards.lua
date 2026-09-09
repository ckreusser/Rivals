local R = DP.Rating
local function duel(id, at, won, level, opponentLevel)
    return {id = id, timestamp = at, modelVersion = 3, guardPolicy = 1,
        duelMode = "rated", status = "matched-request-history-only", won = won,
        opponent = "Bob-Realm", playerClass = "MAGE", playerLevel = level or 60,
        outcome = "knockout", duration = 15, periodId = 1,
        session = {estimatedStartAt = at - 15, identity = {guid = "Player-1-B", class = "WARRIOR", level = opponentLevel or 60}}}
end
assert(R.LevelWeight(60, 1) == 0 and R.LevelWeight(60, 50) == 0)
assert(R.LevelWeight(60, 58) == .5 and R.LevelWeight(60, 56) == .25)
assert(R.LevelWeight(1, 60) == 1 and R.LevelWeight(nil, 60) == 0)
local state = R.New()
local easy = duel(1, 100, true, 60, 1)
local decision = R.Apply(state, easy)
assert(decision.delta == 0 and state.placements == 0 and state.distinct == 0)
assert(state.wins == 1 and state.targets["Player-1-B"].wins == 1)
assert(R.Apply(state, easy) == decision and state.targets["Player-1-B"].wins == 1)
local lowerLoss = R.Apply(R.New(), duel(2, 100, false, 1, 60))
assert(lowerLoss.delta == 0)
local upset = R.Apply(R.New(), duel(3, 100, true, 1, 60))
assert(upset.delta > 0)
local partial = R.Apply(R.New(), duel(4, 100, true, 60, 58))
assert(partial.delta == 8 and partial.matchup.delta == 8)
local retreatLoss = duel(5, 100, false)
retreatLoss.outcome, retreatLoss.duration = "retreat", 1
assert(R.Apply(R.New(), retreatLoss).delta < 0, "Retreating early must not dodge a normal loss")
for _, kind in ipairs({"short", "retreat", "unknown", "recovery"}) do
    local r = duel(1, 100, true)
    if kind == "short" then r.duration = 4.99
    elseif kind == "retreat" then r.outcome = "retreat"
    elseif kind == "unknown" then r.session.identity.level = nil
    else r.provenance, r.acceptedPeerReport, r.acceptedAt = "peer-recovery", true, 101 end
    local s = R.New()
    assert(R.Apply(s, r).delta == 0 and s.placements == 0, kind)
end
-- Space wins eight days apart to isolate the lifetime streak from rolling caps.
local records, s = {}, R.New()
for i = 1, 12 do
    local r = duel(i, i * 8 * 86400, true)
    records[#records + 1] = r
    local d = R.Apply(s, r)
    assert(d.protection == (i <= 8 and 1 or i == 9 and .5 or i == 10 and .25 or i == 11 and .125 or 0))
end
local rebuilt, seasons = DP.Periods.Rebuild(records)
assert(rebuilt.rating == s.rating and rebuilt.targets["Player-1-B"].consecutiveWins == 12)
assert(seasons[1].applied[9].protection == .5 and seasons[1].applied[12].delta == 0)
-- Existing records retain their original model while seeding lifetime counters.
for _, r in ipairs(records) do r.guardPolicy = nil end
local legacy = R.Rebuild(records)
assert(legacy.applied[12].delta > 0)
local nextDuel = duel(13, 13 * 8 * 86400, true)
assert(R.Apply(legacy, nextDuel).delta == 0)
-- Weekly gain cap counts gross gains; an intentional loss cannot refund it.
local weekly, gross = R.New(), 0
for i = 1, 28 do
    local r = duel(i, i * 18000, i % 2 == 1)
    local d = R.Apply(weekly, r)
    gross = gross + math.max(0, d.delta)
end
assert(gross <= 64.0000001)
assert(weekly.applied[27].guardReason == "weekly-opponent-wins")
-- A new opponent has an independent budget, while a new season does not.
local fresh = duel(29, 29 * 18000, true)
fresh.session.identity.guid = "Player-1-C"
assert(R.Apply(weekly, fresh).delta > 0)
local seasonState = R.New()
local limited = duel(30, 30 * 18000, true)
local lifetimeDecision = R.Apply(weekly, limited)
assert(R.Apply(seasonState, limited, lifetimeDecision).delta == 0)
local expired = duel(31, 38 * 18000 + 7 * 86400, true)
assert(R.Apply(weekly, expired).delta > 0, "Weekly budgets expire without deleting lifetime evidence")
local casual = duel(32, expired.timestamp + 1, false)
casual.duelMode = "casual"
local streakBefore = weekly.targets["Player-1-B"].consecutiveWins
R.Apply(weekly, casual)
assert(weekly.targets["Player-1-B"].consecutiveWins == streakBefore, "Casual losses cannot reset rated streaks")
print("PASS: level guards, lifetime opponent streaks, weekly gross-gain and win caps, replay, legacy preservation, season inheritance and evidence gates")
