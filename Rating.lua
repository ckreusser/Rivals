local _, DP = ...
local R = {}
DP.Rating = R

function R.New()
    return {rating = 1500, peak = 1500, wins = 0, losses = 0, streak = 0,
        longestWinStreak = 0, effective = 0, placements = 0, distinct = 0, opponents = {},
        classes = {}, matchups = {}, pairs = {}, targets = {}, applied = {}, highWater = 0}
end

-- Lifetime evidence is independent of the visible shared-profile cache. Replaying
-- the journal also restores these counters after reload and during recovery.
local function Target(state, key, record)
    local target = state.targets[key] or {wins = 0, losses = 0, consecutiveWins = 0, recent = {}}
    state.targets[key] = target
    target.name, target.lastAt = record.opponent, record.timestamp
    local recent, wins, gain = {}, 0, 0
    for _, entry in ipairs(target.recent) do
        if entry.at > record.timestamp - 7 * 86400 then
            recent[#recent + 1] = entry
            wins = wins + (entry.won and 1 or 0)
            gain = gain + entry.gain
        end
    end
    target.recent = recent
    target.wins = target.wins + (record.won and 1 or 0)
    target.losses = target.losses + (record.won and 0 or 1)
    target.consecutiveWins = record.won and target.consecutiveWins + 1 or 0
    return target, wins, gain
end

function R.LevelWeight(winner, loser)
    if type(winner) ~= "number" or type(loser) ~= "number" or
        winner < 1 or loser < 1 or winner > 60 or loser > 60 or
        winner % 1 ~= 0 or loser % 1 ~= 0 then return 0 end
    local gap = math.max(0, winner - loser)
    if gap >= 10 then return 0 end
    return 2 ^ (-gap / 2)
end

local function Protection(record, target, weeklyWins, weeklyGain)
    if record.guardPolicy ~= 1 then return 1, nil end
    -- Reports without locally observed level/start evidence cannot award rating.
    if record.provenance == "peer-recovery" then return 0, "recovered-evidence-incomplete" end
    local other = record.session.identity.level
    local ours = record.playerLevel
    local winnerLevel, loserLevel = ours, other
    if not record.won then winnerLevel, loserLevel = other, ours end
    local level = R.LevelWeight(winnerLevel, loserLevel)
    if level == 0 then return 0, "level-disparity-or-unknown" end
    -- Suppress rewards, not ordinary losses: retreating must not become a
    -- free escape from an otherwise rating-eligible loss.
    if record.won and record.outcome == "retreat" then return 0, "retreat-no-rating" end
    if record.won and (not record.duration or record.duration < 5) then return 0, "short-duel" end
    local factor, reason = level, level < 1 and "level-disparity" or nil
    if record.won then
        local streak = target.consecutiveWins
        if streak > 8 then
            factor = factor * (streak >= 12 and 0 or 2 ^ (8 - streak))
            reason = "opponent-win-streak"
        end
        if weeklyWins >= 12 then return 0, "weekly-opponent-wins" end
        if weeklyGain >= 64 then return 0, "weekly-opponent-gain" end
    end
    return factor, reason
end

local validClass = {WARRIOR=true, MAGE=true, ROGUE=true, PRIEST=true, WARLOCK=true,
    HUNTER=true, DRUID=true, SHAMAN=true, PALADIN=true}

local function Matchup()
    return {rating = 1500, effective = 0, placements = 0, distinct = 0, opponents = {}}
end

function R.PlacementCount(state)
    return math.floor(state.placements or state.effective or 0)
end

function R.MatchupProvisional(matchup)
    return not matchup or R.PlacementCount(matchup) < 10 or matchup.distinct < 3
end

function R.Weight(count)
    if count < 3 then return 1 elseif count < 5 then return 0.5
    elseif count < 7 then return 0.25 else return 0 end
end

function R.Delta(a, b, won, weight)
    local expected = 1 / (1 + 10 ^ ((b - a) / 400))
    return 32 * weight * ((won and 1 or 0) - expected), expected
end

local function Record(stats, won)
    stats.wins = stats.wins + (won and 1 or 0)
    stats.losses = stats.losses + (won and 0 or 1)
end

-- Rebuilt from the ordered journal. Old diagnostic records have no modelVersion.
function R.Apply(state, record, repeatContext)
    if state.applied[record.id] then return state.applied[record.id] end
    local decision = {eligible = false, delta = 0, reason = "diagnostic-capture"}
    state.applied[record.id] = decision
    if record.modelVersion ~= 1 and record.modelVersion ~= 2 and record.modelVersion ~= 3 then return decision end
    if record.status ~= "matched-request-history-only" then
        decision.reason = record.status
        return decision
    end
    local s = record.session
    local identity = s and s.identity
    -- Qualified names remain useful for records, but rating requires captured GUID evidence.
    local key = identity and identity.guid or (s and s.opponent) or record.opponent
    local opponent = state.opponents[key]
    if not opponent then
        opponent = {rating = 1500, wins = 0, losses = 0, effective = 0,
            name = identity and identity.name or record.opponent}
        state.opponents[key] = opponent
    end
    Record(state, record.won)
    Record(opponent, record.won) -- Personal W/L against this opponent, not their W/L.
    opponent.lastAt = record.timestamp
    local class = identity and identity.class or "UNKNOWN"
    state.classes[class] = state.classes[class] or {wins = 0, losses = 0, opponents = {}, distinct = 0}
    Record(state.classes[class], record.won)
    local classStats = state.classes[class]
    if not classStats.opponents[key] then
        classStats.opponents[key] = true
        classStats.distinct = classStats.distinct + 1
    end
    if record.won then state.streak = math.max(0, state.streak) + 1
    else state.streak = math.min(0, state.streak) - 1 end
    state.longestWinStreak = math.max(state.longestWinStreak, state.streak)
    state.last = record

    local previousTime = state.highWater
    state.highWater = math.max(previousTime, record.timestamp)
    if record.modelVersion == 3 and record.duelMode ~= "rated" then decision.reason = "casual-or-unconfirmed-mode"; return decision end
    if repeatContext and not repeatContext.eligible then decision.reason = repeatContext.reason; return decision end
    if not identity or not identity.guid then decision.reason = "opponent-guid-unknown"; return decision end
    local acceptedRecovery = record.provenance == "peer-recovery" and record.acceptedPeerReport == true and record.acceptedAt ~= nil
    if not acceptedRecovery and (not s.estimatedStartAt or not record.duration) then decision.reason = "start-not-observed"; return decision end
    if record.timestamp < previousTime then decision.reason = "clock-moved-backward"; return decision end

    local target, weeklyWins, weeklyGain = Target(state, key, record)
    local protection, guardReason = Protection(record, target, weeklyWins, weeklyGain)
    if repeatContext then protection, guardReason = repeatContext.protection or 1, repeatContext.guardReason end

    local recent = {}
    for _, timestamp in ipairs(state.pairs[key] or {}) do
        if timestamp > record.timestamp - 86400 then recent[#recent + 1] = timestamp end
    end
    local count = repeatContext and (repeatContext.pairNumber - 1) or #recent
    local weight = repeatContext and repeatContext.weight or R.Weight(count)
    if not repeatContext then weight = weight * protection end
    recent[#recent + 1] = record.timestamp -- Include zero-impact eligible duels.
    state.pairs[key] = recent
    local before, opponentBefore = state.rating, opponent.rating
    local delta, expected = R.Delta(before, opponentBefore, record.won, weight)
    local gainCap = record.guardPolicy == 1 and record.won and math.max(0, 64 - weeklyGain) or nil
    if repeatContext then gainCap = repeatContext.gainCap end
    if gainCap and delta > gainCap then delta = gainCap; guardReason = "weekly-opponent-gain" end
    target.recent[#target.recent + 1] = {at = record.timestamp, won = record.won, gain = math.max(0, delta)}
    state.rating, opponent.rating = before + delta, opponentBefore - delta
    state.peak = math.max(state.peak, state.rating)
    if weight > 0 and opponent.effective == 0 then state.distinct = state.distinct + 1 end
    state.effective, opponent.effective = state.effective + weight, opponent.effective + weight
    local placement = protection > 0 and (not gainCap or gainCap > 0) and 1 or 0
    state.placements = (state.placements or 0) + placement
    opponent.placements = (opponent.placements or 0) + placement
    decision.protection, decision.guardReason, decision.gainCap = protection, guardReason, gainCap
    decision.eligible, decision.weight, decision.pairNumber = true, weight, count + 1
    decision.delta, decision.expected = delta, expected
    decision.before, decision.after = before, state.rating
    decision.opponentBefore, decision.opponentAfter = opponentBefore, opponent.rating
    decision.reason = guardReason or (weight == 0 and "repeat-limit" or "local-elo")
    -- Version 2 adds an independent reciprocal class pool. Version 1 remains overall-only.
    if (record.modelVersion == 2 or record.modelVersion == 3) and validClass[class] and validClass[record.playerClass] then
        state.matchups[class] = state.matchups[class] or Matchup()
        opponent.matchups = opponent.matchups or {}
        opponent.matchups[record.playerClass] = opponent.matchups[record.playerClass] or Matchup()
        local ours, theirs = state.matchups[class], opponent.matchups[record.playerClass]
        local classBefore, otherBefore = ours.rating, theirs.rating
        local change = R.Delta(classBefore, otherBefore, record.won, weight)
        if gainCap then change = math.min(change, gainCap) end
        ours.rating, theirs.rating = classBefore + change, otherBefore - change
        ours.placements, theirs.placements = (ours.placements or 0) + placement, (theirs.placements or 0) + placement
        ours.effective, theirs.effective = ours.effective + weight, theirs.effective + weight
        if weight > 0 and not ours.opponents[key] then
            ours.opponents[key] = true; ours.distinct = ours.distinct + 1
        end
        -- The reciprocal opponent estimate is learned only against this observing character.
        if weight > 0 then theirs.distinct = 1 end
        decision.matchup = {class = class, playerClass = record.playerClass, before = classBefore,
            after = ours.rating, opponentBefore = otherBefore, opponentAfter = theirs.rating, delta = change}
    end
    return decision
end

function R.Rebuild(records)
    local state = R.New()
    for _, record in ipairs(records) do
        if record.modelVersion and record.modelVersion ~= 1 and record.modelVersion ~= 2 and record.modelVersion ~= 3 then return nil, "Unsupported rating model" end
        R.Apply(state, record)
    end
    return state
end

function R.Provisional(state)
    return R.PlacementCount(state) < 10 or state.distinct < 5
end
