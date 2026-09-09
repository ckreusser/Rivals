local _, DP = ...
local R = {}
DP.Rating = R

function R.New()
    return {rating = 1500, peak = 1500, wins = 0, losses = 0, streak = 0,
        longestWinStreak = 0, effective = 0, placements = 0, distinct = 0, opponents = {},
        classes = {}, matchups = {}, pairs = {}, applied = {}, highWater = 0}
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

    local recent = {}
    for _, timestamp in ipairs(state.pairs[key] or {}) do
        if timestamp > record.timestamp - 86400 then recent[#recent + 1] = timestamp end
    end
    local count = repeatContext and (repeatContext.pairNumber - 1) or #recent
    local weight = repeatContext and repeatContext.weight or R.Weight(count)
    recent[#recent + 1] = record.timestamp -- Include zero-impact eligible duels.
    state.pairs[key] = recent
    local before, opponentBefore = state.rating, opponent.rating
    local delta, expected = R.Delta(before, opponentBefore, record.won, weight)
    state.rating, opponent.rating = before + delta, opponentBefore - delta
    state.peak = math.max(state.peak, state.rating)
    if weight > 0 and opponent.effective == 0 then state.distinct = state.distinct + 1 end
    state.effective, opponent.effective = state.effective + weight, opponent.effective + weight
    state.placements = (state.placements or 0) + 1
    opponent.placements = (opponent.placements or 0) + 1
    decision.eligible, decision.weight, decision.pairNumber = true, weight, count + 1
    decision.delta, decision.expected = delta, expected
    decision.before, decision.after = before, state.rating
    decision.opponentBefore, decision.opponentAfter = opponentBefore, opponent.rating
    decision.reason = weight == 0 and "repeat-limit" or "local-elo"
    -- Version 2 adds an independent reciprocal class pool. Version 1 remains overall-only.
    if (record.modelVersion == 2 or record.modelVersion == 3) and validClass[class] and validClass[record.playerClass] then
        state.matchups[class] = state.matchups[class] or Matchup()
        opponent.matchups = opponent.matchups or {}
        opponent.matchups[record.playerClass] = opponent.matchups[record.playerClass] or Matchup()
        local ours, theirs = state.matchups[class], opponent.matchups[record.playerClass]
        local classBefore, otherBefore = ours.rating, theirs.rating
        local change = R.Delta(classBefore, otherBefore, record.won, weight)
        ours.rating, theirs.rating = classBefore + change, otherBefore - change
        ours.placements, theirs.placements = (ours.placements or 0) + 1, (theirs.placements or 0) + 1
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
