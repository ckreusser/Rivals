local now, sent = 1800000000, {}
local function config(id)
    return {guid = id, now = function() return now end, enabled = function() return true end,
        nextToken = function() return "1800000000-9" end,
        send = function(message, target) sent[#sent + 1] = {message, target} end}
end
local a = {results = {}}
local b = {results = {{timestamp = now, status = "matched-request-history-only", won = true, outcome = "knockout", duelMode = "rated",
    session = {verificationToken = "1800000000-2", peerVerificationToken = "1800000000-1", identity = {name = "A-Realm", guid = "Player-1-A"}}}}}
local ra, rb = DP.Recovery.New(config("Player-1-A"), a), DP.Recovery.New(config("Player-1-B"), b)
ra:Remember({verificationToken = "1800000000-1", identity = {name = "B-Realm", guid = "Player-1-B"}})
assert(#ra:Items() == 1 and ra:Items()[1].status == "Unresolved")
ra:Request({name = "B-Realm", guid = "Player-1-B"})
rb:Receive(sent[1][1], "A-Realm")
local report = sent[2][1]
ra:Receive(report, "Stranger-Realm")
assert(ra:Items()[1].status == "Unresolved")
ra:Receive(report, "B-Realm")
assert(#a.results == 0 and #ra:Items() == 1 and ra:Items()[1].status == "Peer-reported" and not ra:Items()[1].won)
ra:Receive(report, "B-Realm")
assert(#ra:Items() == 1)
-- Persist/reload does not duplicate a recovered report.
ra = DP.Recovery.New(config("Player-1-A"), a)
ra:Request({name = "B-Realm", guid = "Player-1-B"})
ra:Receive(report, "B-Realm")
assert(#ra:Items() == 1)
-- A hard close can lose pending state; a requested peer report still survives separately.
local lost = DP.Recovery.New(config("Player-1-A"), {results = {}})
lost:Receive(report, "B-Realm"); assert(#lost:Items() == 0)
lost:Request({name = "B-Realm", guid = "Player-1-B"})
lost:Receive(report, "B-Realm"); assert(#lost:Items() == 1)
local observed = DP.Recovery.New(config("Player-1-A"), {results = {{session = {verificationToken = "1800000000-1", identity = {guid = "Player-1-B"}}}}})
observed:Request({name = "B-Realm", guid = "Player-1-B"})
observed:Receive(report, "B-Realm"); assert(#observed:Items() == 0)
now = now + 21
local missing = DP.Recovery.New(config("Player-1-A"), {results = {}})
missing:Request({name = "B-Realm", guid = "Player-1-B"})
now = now + 21
missing:Receive(report, "B-Realm"); assert(#missing:Items() == 0)
assert(not DP.Recovery.Parse(string.rep("x", 241)))
assert(not DP.Recovery.Parse(report:gsub("knockout", "invalid")))
local feedback = DP.Recovery.New(config("Player-1-A"), {results = {}})
feedback:Request({name = "B-Realm", guid = "Player-1-B"})
feedback:Receive("E|1800000000-9|Player-1-B|0", "Stranger-Realm")
assert(feedback.status:find("Requesting"))
feedback:Receive("E|1800000000-9|Player-1-B|0", "B-Realm")
assert(feedback.status:find("no recoverable results"))
assert(not DP.Recovery.Parse("E|1800000000-9|Player-1-B|999"))
feedback:Request({name = "B-Realm", guid = "Player-1-B"})
assert(feedback.status:find("Retry available"))
print("PASS: interrupted recovery, hard-close missing state, persistence, duplicates, observed-result isolation, sender and timeout checks")
local recordLater = {id = 1, modelVersion = 3, timestamp = now, status = "matched-request-history-only", won = true,
    opponent = "B-Realm", duelMode = "rated", duration = 10, playerClass = "MAGE",
    session = {estimatedStartAt = 1, verificationToken = "1800000000-40", identity = {guid = "Player-1-B", name = "B-Realm", class = "WARRIOR"}}}
local reviewItem = {token = "1800000000-30", peerToken = "1800000000-31", guid = "Player-1-B", name = "B-Realm",
    status = "Peer-reported", winner = "Player-1-B", won = false, mode = "rated", timestamp = now - 60, outcome = "knockout"}
local reviewObserver = {name = "A-Realm", nextSequence = 2, results = {recordLater}, interrupted = {reviewItem}}
local review = DP.Recovery.New(config("Player-1-A"), reviewObserver)
local preview = assert(review:Preview(reviewItem))
assert(#reviewObserver.results == 1 and not reviewItem.appliedId) -- Preview is read-only.
assert(preview.records[1] == preview.record and preview.records[2] == recordLater)
assert(preview.rating.wins == 1 and preview.rating.losses == 1 and preview.rating.effective == 2)
assert(preview.rating.applied[2].delta == -16 and preview.rating.applied[1].delta > 16)
assert(not preview.record.duration and not preview.record.periodId)
assert(DP.Verification.Label(preview.record) == "Peer-reported; accepted locally")
reviewObserver.results = preview.records
assert(not review:Preview(reviewItem))
assert(DP.Periods.Rebuild(preview.records).rating == preview.rating.rating)
print("PASS: read-only recovery preview, historical replay, honest evidence, lifetime-only fallback and duplicate rejection")
