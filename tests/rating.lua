local R = DP.Rating
local function near(a, b) assert(math.abs(a - b) < 0.000001, tostring(a) .. " != " .. tostring(b)) end
local function result(id, at, key, won)
    return {id = id, modelVersion = 1, timestamp = at, won = won, duration = 3,
        status = "matched-request-history-only", opponent = key,
        session = {estimatedStartAt = 10, identity = {guid = key, name = key, class = "MAGE"}}}
end
near(R.Delta(1500, 1500, true, 1), 16)
near(R.Delta(1500, 1700, true, 1), 24.311901652735)
local state, journal = R.New(), {}
for i, weight in ipairs({1, 1, 1, .5, .5, .25, .25, 0, 0}) do
    local r = result(i, 1000 + i, "Bob", i % 2 == 1)
    journal[#journal + 1] = r
    local d = R.Apply(state, r)
    near(d.weight, weight)
    near(state.rating + state.opponents.Bob.rating, 3000)
    local before = state.rating
    R.Apply(state, r)
    near(state.rating, before)
end
assert(state.wins == 5 and state.losses == 4 and state.distinct == 1)
near(state.effective, 4.5)
assert(state.placements == 9, "Each eligible duel counts once, including repeat-limited ones")
assert(R.Provisional(state))
local rebuilt = R.Rebuild(journal)
near(rebuilt.rating, state.rating)
assert(rebuilt.placements == state.placements)
assert(rebuilt.wins == state.wins and rebuilt.streak == state.streak)
-- Exactly 24 hours old expires; more recent eligible zero-weight entries remain.
local boundary = R.Apply(state, result(10, 87401, "Bob", true))
assert(boundary.pairNumber == 9 and boundary.weight == 0)
assert(R.Apply(state, result(11, 173802, "Bob", true)).weight == 1)
assert(R.Apply(state, result(12, 100, "New", true)).reason == "clock-moved-backward")
local before = state.rating
local old = result(13, 200000, "Bob", true); old.modelVersion = nil
assert(R.Apply(state, old).reason == "diagnostic-capture")
near(state.rating, before)
local missing = result(14, 200001, "Unknown", false); missing.session.identity = nil
assert(R.Apply(state, missing).reason == "opponent-guid-unknown")
local noStart = result(15, 200002, "Bob", false); noStart.session.estimatedStartAt = nil
assert(R.Apply(state, noStart).reason == "start-not-observed")
local conflict = result(16, 200003, "Bob", false); conflict.status = "identity-conflict"
local losses = state.losses
R.Apply(state, conflict); assert(state.losses == losses)
local placed = R.New()
for i = 1, 10 do R.Apply(placed, result(i, i, "opponent" .. ((i % 5) + 1), true)) end
assert(not R.Provisional(placed) and placed.distinct == 5)
assert(placed.longestWinStreak == 10 and placed.classes.MAGE.wins == 10)
assert(R.Rebuild({{id = 1, modelVersion = 99}}) == nil)
print("PASS: Elo symmetry, repeats, placement diversity, replay, exclusions and clock rollback")

local mixed, overallOnly, replay = R.New(), R.New(), {}
for i = 1, 15 do
    local key = "Warrior" .. ((i % 3) + 1)
    local duel = result(i, i + 100, key, i % 2 == 0)
    duel.modelVersion, duel.playerClass, duel.session.identity.class = 2, "MAGE", "WARRIOR"
    replay[#replay + 1] = duel
    local oldModel = result(i, i + 100, key, i % 2 == 0)
    local d = R.Apply(mixed, duel)
    R.Apply(overallOnly, oldModel)
    near(mixed.rating, overallOnly.rating)
    assert(d.matchup.class == "WARRIOR" and d.matchup.playerClass == "MAGE")
    near(d.matchup.before + d.matchup.opponentBefore, d.matchup.after + d.matchup.opponentAfter)
    near(d.matchup.delta, R.Delta(d.matchup.before, d.matchup.opponentBefore, duel.won, d.weight))
    local beforeMatchup = mixed.matchups.WARRIOR.rating
    R.Apply(mixed, duel)
    near(mixed.matchups.WARRIOR.rating, beforeMatchup)
end
assert(not R.MatchupProvisional(mixed.matchups.WARRIOR))
assert(mixed.matchups.WARRIOR.distinct == 3)
near(R.Rebuild(replay).matchups.WARRIOR.rating, mixed.matchups.WARRIOR.rating)
assert(overallOnly.matchups.WARRIOR == nil)
local unknown = result(16, 200, "New", true)
unknown.modelVersion, unknown.playerClass = 2, "MAGE"
unknown.session.identity.class = nil
local unknownDecision = R.Apply(mixed, unknown)
assert(unknownDecision.eligible and unknownDecision.matchup == nil)
local isolated = result(17, 201, "Rogue", true)
isolated.modelVersion, isolated.playerClass, isolated.session.identity.class = 2, "MAGE", "ROGUE"
local warriorRating = mixed.matchups.WARRIOR.rating
local rogueDecision = R.Apply(mixed, isolated)
near(rogueDecision.matchup.delta, 16)
near(mixed.matchups.WARRIOR.rating, warriorRating)
assert(R.MatchupProvisional(mixed.matchups.ROGUE))
local repeated = R.New()
for i = 1, 8 do
    local r = result(i, i, "Bob", true)
    r.modelVersion, r.playerClass = 2, "WARRIOR"
    local d = R.Apply(repeated, r)
    if i == 8 then near(d.matchup.delta, 0) end
end
near(repeated.matchups.MAGE.effective, 4.5)
assert(repeated.matchups.MAGE.distinct == 1 and R.MatchupProvisional(repeated.matchups.MAGE))
local summary = DP.Views.MatchupSummary(mixed)
assert(summary:find("Most%-tested"))
mixed.classes.ROGUE = {wins = 10, losses = 0, distinct = 3}
summary = DP.Views.MatchupSummary(mixed)
assert(summary:find("Best: ROGUE", 1, true) and summary:find("Worst: WARRIOR", 1, true))
print("PASS: reciprocal class Elo, independent overall replay, class diversity, repeats, unknown classes and matchup summaries")

local periodRecords = {}
for i = 1, 9 do
    local r = result(i, 100 + i, "Bob", true)
    if i >= 4 then r.periodId = i <= 7 and 1 or 2 end
    periodRecords[#periodRecords + 1] = r
end
local life, periods = DP.Periods.Rebuild(periodRecords)
near(life.rating, R.Rebuild(periodRecords).rating)
assert(periods[1].wins == 4 and periods[2].wins == 2)
near(periods[1].applied[4].weight, .5)
near(periods[1].applied[4].delta, 8) -- Fresh ratings, existing repeat limit.
near(periods[2].rating, 1500)
near(periods[2].effective, 0)
assert(periods[2].applied[8].weight == 0)
local points = DP.Periods.Points(periodRecords, periods[1])
assert(#points == 5 and points[1].value == 1500 and points[5].value == periods[1].rating)
local long = {}
for i = 1, 150 do long[i] = result(i, i, "Opponent" .. i, true) end
local recentPoints = DP.Periods.Points(long, R.Rebuild(long))
assert(#recentPoints == 101 and recentPoints[1].match == 50 and recentPoints[101].match == 150)
print("PASS: independent seasons, cross-season repeat limits, replay and bounded graph points")

local modeState = R.New()
local casual = result(1, 10, "Bob", true)
casual.modelVersion, casual.duelMode, casual.playerClass = 3, "casual", "WARRIOR"
local cd = R.Apply(modeState, casual)
assert(not cd.eligible and modeState.wins == 1 and modeState.effective == 0 and not modeState.pairs.Bob)
local rated = result(2, 11, "Bob", true)
rated.modelVersion, rated.duelMode, rated.playerClass = 3, "rated", "WARRIOR"
local rd = R.Apply(modeState, rated)
assert(rd.eligible and rd.pairNumber == 1 and rd.delta == 16 and rd.matchup)
near(R.Rebuild({casual, rated}).rating, modeState.rating)
local unknownMode = result(3, 12, "Bob", false); unknownMode.modelVersion = 3
assert(not R.Apply(modeState, unknownMode).eligible)
print("PASS: model-3 Casual history, Rated Elo, repeat eligibility and replay")
