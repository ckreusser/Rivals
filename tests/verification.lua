local V = DP.Verification
local now, queue, timers, clients, changes = 0, {}, {}, {}, 0
local function make(name, guid)
    local sequence = 0
    local config = {guid = guid, now = function() return now end, timestamp = function() return 1000 + now end,
        enabled = function() return true end,
        nextToken = function() sequence = sequence + 1; return "1000-" .. sequence end,
        after = function(delay, callback) timers[#timers + 1] = {at = now + delay, fn = callback} end,
        send = function(message, target) queue[#queue + 1] = {message = message, target = target, sender = name} end,
        changed = function() changes = changes + 1 end}
    local v = V.New(config); clients[name] = v; return v
end
local function flush()
    while #queue > 0 do
        local packet = table.remove(queue, 1)
        clients[packet.target]:Receive(packet.message, packet.sender)
    end
end
local function tick(delta)
    now = now + delta
    local old = timers; timers = {}
    for _, t in ipairs(old) do if t.at <= now then t.fn() else timers[#timers + 1] = t end end
    flush()
end
local a, b = make("Alice-Realm", "Player-1-A"), make("Bob-Realm", "Player-1-B")
local function session(name, guid) return {identity = {name = name, guid = guid}} end
local sa, sb = session("Bob-Realm", "Player-1-B"), session("Alice-Realm", "Player-1-A")
a:Begin(sa); flush() -- Peer has not received its request yet; initial hello is lost.
b:Begin(sb); flush(); tick(1)
assert(a.current.peerToken and b.current.peerToken)
local function result(s, won, id)
    return {session = s, won = won, id = id or 1, modelVersion = 2, playerClass = "MAGE", duration = 3,
        outcome = "knockout", opponent = s.identity.name, timestamp = 1000 + now,
        status = "matched-request-history-only"}
end
local ra, rb = result(sa, true), result(sb, false)
sa.estimatedStartAt, sa.identity.class = 0, "MAGE"
local ratingState = DP.Rating.New()
DP.Rating.Apply(ratingState, ra)
local beforeRating, beforeWins = ratingState.rating, ratingState.wins
a:Finish(ra); flush() -- A's result arrives before B's local game result.
assert(V.Label(ra) == "Local only")
b:Finish(rb); flush()
assert(V.Label(ra) == "Confirmed by both clients" and V.Label(rb) == "Confirmed by both clients")
assert(ra.verification.matchId == rb.verification.matchId)
local beforeChanges = changes
tick(3); assert(changes == beforeChanges) -- Idempotent duplicate result reports.
assert(ratingState.rating == beforeRating and ratingState.wins == beforeWins)
local wrong = "R|" .. sa.verificationToken .. "|" .. sb.verificationToken .. "|Player-1-B|knockout"
a:Receive(wrong, "Mallory-Realm"); assert(ra.verification.status == "confirmed")
a:Receive(wrong, "Bob-Realm"); assert(ra.verification.status == "disputed")
tick(4); assert(ra.verification.status == "disputed") -- Disputes cannot silently revert.
assert(V.Parse(string.rep("x", 241)) == nil)
assert(V.Parse("R|1000-1|1000-1|Player-1-B|garbage") == nil)

local freshA, freshB = session("Bob-Realm", "Player-1-B"), session("Alice-Realm", "Player-1-A")
a:Begin(freshA); b:Begin(freshB); flush(); tick(1)
a:Receive(wrong, "Bob-Realm") -- Old packet cannot bind to the rematch.
local nextA, nextB = result(freshA, false, 2), result(freshB, true, 2)
a:Finish(nextA); b:Finish(nextB)
queue = {} -- Drop both first result packets.
tick(1)
assert(nextA.verification.status == "confirmed" and nextB.verification.status == "confirmed")
assert(nextA.verification.matchId ~= ra.verification.matchId)
local lonely = session("Bob-Realm", "Player-1-B")
a:Begin(lonely); a:Finish(result(lonely, true, 3))
local orphan = a.current.record
queue = {}; tick(16)
assert(orphan.verification.status == "local")
local cancelled = session("Bob-Realm", "Player-1-B")
a:Begin(cancelled); a:Cancel(cancelled)
assert(a.entries[cancelled.verificationToken] == nil)
assert(ratingState.rating == beforeRating and ratingState.wins == beforeWins)
print("PASS: bilateral handshake, early/lost results, duplicate suppression, disputes, rematches, timeout and cancellation")

local c, d = make("LateA-Realm", "Player-1-C"), make("LateB-Realm", "Player-1-D")
local cs, ds = session("LateB-Realm", "Player-1-D"), session("LateA-Realm", "Player-1-C")
c:Begin(cs); flush()
tick(1); tick(3); tick(6) -- All original hello retries pass before the peer can begin.
d:Begin(ds); flush()
assert(c.current.peerToken and d.current.peerToken)
local cr, dr = result(cs, true), result(ds, false)
c:Finish(cr); d:Finish(dr); flush()
assert(cr.verification.status == "confirmed" and dr.verification.status == "confirmed")
assert(cr.verification.matchId == dr.verification.matchId)
print("PASS: late peer identity after initial retry window confirms on both clients")

local function modes(left, right)
    local x, y = make("ModeA-Realm", "Player-1-E"), make("ModeB-Realm", "Player-1-F")
    local xs, ys = session("ModeB-Realm", "Player-1-F"), session("ModeA-Realm", "Player-1-E")
    xs.modePreference, ys.modePreference = left, right
    x:Begin(xs); y:Begin(ys); flush(); tick(1)
    x:ModePulse(xs); y:ModePulse(ys); flush()
    x:LockMode(xs); y:LockMode(ys)
    return xs, ys, x, y
end
local xs, ys = modes("rated", "rated")
assert(xs.duelMode == "rated" and ys.duelMode == "rated")
xs, ys = modes("rated", "casual")
assert(xs.duelMode == "casual" and ys.duelMode == "casual")
local unpaired = session("Nobody-Realm", "Player-1-9")
unpaired.modePreference = "rated"
c:LockMode(unpaired)
assert(unpaired.duelMode == "casual")
-- Packets received after the observed start cannot promote a casual duel to rated.
local late = session("LateB-Realm", "Player-1-D")
late.modePreference = "rated"
c:Begin(late); queue = {}
local entry = c.current
entry.peerToken = "2000-1"
late.estimatedStartAt = now
c:Receive("M|" .. entry.token .. "|2000-1|rated", "LateB-Realm")
c:Receive("C|" .. entry.token .. "|2000-1|rated", "LateB-Realm")
c:LockMode(late)
assert(late.duelMode == "casual")
print("PASS: bilateral Rated, Casual veto, missing peer and late mode rejection")
local retryA, retryB = make("RetryA-Realm", "Player-1-11"), make("RetryB-Realm", "Player-1-12")
local rs, rt = session("RetryB-Realm", "Player-1-12"), session("RetryA-Realm", "Player-1-11")
rs.modePreference, rt.modePreference = "rated", "rated"
retryA:Begin(rs); retryB:Begin(rt)
queue = {} -- Lose the initial hello exchange.
tick(.5); tick(.5); tick(.5)
retryA:LockMode(rs); retryB:LockMode(rt)
assert(rs.duelMode == "rated" and rt.duelMode == "rated")
local blocked = 0
retryA.config.canSend = function() return false end
retryA.config.send = function() blocked = blocked + 1 end
retryA:Send(retryA.current, {"H", retryA.current.token, "Player-1-11"})
assert(blocked == 0)
print("PASS: negotiation retries lost initial exchange without preference toggles; offline send gate")
assert(V.AgreementStatus({modePreference = "rated"}, true):find("Waiting for Rated agreement"))
assert(V.AgreementStatus({modePreference = "rated", peerMode = "rated", modeAcknowledged = true}, true):find("Rated agreement ready"))
assert(V.AgreementStatus({modeLocked = true, duelMode = "rated"}, true):find("This duel: Rated"))
assert(V.AgreementStatus({modePreference = "rated"}, false):find("Verification is disabled"))
local failedMode = session("Nobody-Realm", "Player-1-9")
failedMode.modePreference = "rated"
retryB:LockMode(failedMode)
assert(failedMode.modeFailure == "No completed handshake with opponent")
assert(V.AgreementStatus(failedMode, true):find("No completed handshake"))
print("PASS: preference, pending agreement, agreed mode and explicit failure states")
