local _, DP = ...
local Tracker = {}
Tracker.__index = Tracker
DP.Tracker = Tracker

function Tracker.New(playerName, emit)
    return setmetatable({playerName = playerName, emit = emit, generation = 0}, Tracker)
end

function Tracker:Close(reason, now)
    if not self.session then return end
    local session = self.session
    self.session = nil
    self.emit({kind = "activity", status = reason, session = session, observedAt = now})
end

function Tracker:Request(opponent, direction, excluded, now, identity)
    -- Multiple request signals should enrich, not replace, a pending request.
    local s = self.session
    if s and s.state == "requested" and s.direction == direction and
        DP.Parser.SameName(s.opponent, opponent) and now - s.requestedAt < 2 then
        s.excluded = s.excluded or excluded
        s.identity = identity or s.identity
        return s.id
    end
    self:Close("superseded-unresolved", now)
    self.generation = self.generation + 1
    self.session = {id = self.generation, opponent = opponent, direction = direction,
        excluded = excluded, requestedAt = now, state = "requested", identity = identity}
    return self.generation
end

function Tracker:Finished(now)
    if self.session then
        self.session.state = "awaiting-result"
        self.session.finishedAt = now
        return self.session.id
    end
end

function Tracker:Countdown(seconds, now)
    local s = self.session
    if not s or s.state == "awaiting-result" or s.excluded then return false end
    if s.lastCountdown and seconds >= s.lastCountdown then return false end
    s.state = "countdown-observed"
    s.lastCountdown = seconds
    s.estimatedStartAt = now + seconds
    return true
end

function Tracker:Expire(id, now)
    if self.session and self.session.id == id then self:Close("no-result-unresolved", now) end
end

function Tracker:Result(winner, loser, outcome, now)
    local won = DP.Parser.SameName(winner, self.playerName)
    local lost = DP.Parser.SameName(loser, self.playerName)
    if won == lost then return false, "unrelated-or-ambiguous" end
    local opponent = won and loser or winner
    local s = self.session
    local fingerprint = winner .. "\031" .. loser .. "\031" .. outcome
    -- Allow a real rapid rematch with a new request, suppress repeated result signals.
    if not s and self.last and self.last.key == fingerprint and now - self.last.at < 5 then
        return false, "duplicate"
    end
    local status = "recovered-history-only"
    if s then
        if s.excluded then status = "excluded-duel-type"
        elseif not DP.Parser.SameName(s.opponent, opponent) then status = "identity-conflict"
        else status = "matched-request-history-only" end
    end
    local duration
    if status == "matched-request-history-only" and s.estimatedStartAt then
        local endedAt = s.finishedAt or now
        if endedAt >= s.estimatedStartAt then duration = endedAt - s.estimatedStartAt end
    end
    self.emit({kind = "result", status = status, winner = winner, loser = loser,
        opponent = opponent, outcome = outcome, won = won, observedAt = now,
        session = s, ratingEligible = false, duration = duration,
        durationQuality = duration and "estimated" or "unknown",
        provenance = "local", identityQuality = "name-match"})
    self.session = nil
    self.last = {key = fingerprint, at = now}
    return true, status
end
