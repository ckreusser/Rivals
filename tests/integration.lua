fire("PLAYER_LOGIN")
fire("COMBAT_LOG_EVENT_UNFILTERED") -- Idle combat must not touch an out-of-scope player.
local o = RivalsDB.observers["Player-1-A"]
assert(o and #o.results == 0)
SlashCmdList.RIVALS("trace on")
fire("DUEL_REQUESTED", "Bob")
fire("CHAT_MSG_SYSTEM", "Duel starting: 1")
advance(1)
local savedCombatLog, savedBaseCooldown = CombatLogGetCurrentEventInfo, GetSpellBaseCooldown
function CombatLogGetCurrentEventInfo()
    return GetTime(), "SPELL_CAST_SUCCESS", false, "Player-1-A", "Alice", 0, 0, "Player-1-A", "Alice", 0, 0, 999901, "Test long cooldown"
end
function GetSpellBaseCooldown() return 180000 end
fire("COMBAT_LOG_EVENT_UNFILTERED")
CombatLogGetCurrentEventInfo, GetSpellBaseCooldown = savedCombatLog, savedBaseCooldown
fire("DUEL_FINISHED")
advance(1)
fire("CHAT_MSG_SYSTEM", "Alice has defeated Bob in a duel.")
assert(#o.results == 1 and o.results[1].won)
assert(o.results[1].session.usage.player["999901"].count == 1)
assert(#o.results[1].session.combatLog.myActions == 1 and #o.results[1].session.combatLog.toMe == 0)
fire("COMBAT_LOG_EVENT_UNFILTERED")
advance(3)
assert(#o.activity == 0)
fire("CHAT_MSG_SYSTEM", "Alice has defeated Bob in a duel.")
assert(#o.results == 1)
fire("CHAT_MSG_SYSTEM", "Charlie has defeated Bob in a duel.")
assert(#o.results == 1)
hooks.StartDuel("target")
fire("CHAT_MSG_SYSTEM", ERR_DUEL_REQUESTED)
assert(o.pending.identity.guid == "Player-1-B")
fire("DUEL_FINISHED")
advance(4)
assert(#o.results == 1 and o.activity[#o.activity].status == "no-result-unresolved")
fire("DUEL_REQUESTED", "Bob")
fire("CHAT_MSG_SYSTEM", "Charlie has defeated Alice in a duel.")
assert(o.results[2].status == "identity-conflict")
fire("DUEL_TO_THE_DEATH_REQUESTED", "Bob")
fire("CHAT_MSG_SYSTEM", "Alice has defeated Bob in a duel.")
assert(o.results[3].status == "excluded-duel-type")
for i = 1, 1050 do fire("UI_INFO_MESSAGE", 1, "test") end
assert(#o.trace == 1000)
SlashCmdList.RIVALS("export")
assert(DP.window.edit.text:find("RECENT RESULTS", 1, true))
assert(DP.window.edit.text:find("CLIENT FORMATS", 1, true))
SlashCmdList.RIVALS("trace off")
local count = #o.trace
fire("UI_INFO_MESSAGE", 1, "not stored")
assert(#o.trace == count)
fire("DUEL_REQUESTED", "Bob")
fire("PLAYER_LOGOUT")
assert(o.pending.opponent == "Bob")
-- Simulate login initialization against saved pending data.
fire("PLAYER_LOGIN")
assert(o.pending == nil and o.activity[#o.activity].status == "reload-unresolved")
fire("DUEL_REQUESTED", "Bob")
fire("CHAT_MSG_SYSTEM", "Alice has fled from Bob in a duel.")
assert(o.results[#o.results].winner == "Bob" and not o.results[#o.results].won)
assert(o.results[#o.results].outcome == "retreat")
print("PASS: mocked client lifecycle, persistence, trace bounds and report UI")

local previous = #o.results
hooks.StartDuel("target")
fire("UI_INFO_MESSAGE", 391, "Duel cancelled.")
fire("DUEL_FINISHED")
advance(4)
assert(#o.results == previous and o.activity[#o.activity].status == "cancelled")
assert(o.pending == nil)
hooks.StartDuel("target")
fire("CHAT_MSG_SYSTEM", "Duel starting: 3")
advance(1)
fire("CHAT_MSG_SYSTEM", "Duel starting: 2")
advance(1)
fire("CHAT_MSG_SYSTEM", "Duel starting: 1")
advance(4.008)
fire("DUEL_FINISHED")
fire("CHAT_MSG_SYSTEM", "Bob has defeated Alice in a duel.")
local r = o.results[#o.results]
assert(r.durationQuality == "estimated" and math.abs(r.duration - 3.008) < 0.0001)
assert(not r.ratingEligible and r.ratingDecision.delta == 0 and r.duelMode == "casual")
assert(r.modelVersion == 3 and r.playerClass == "MAGE")
local beforeReload = 1500
fire("PLAYER_LOGIN")
SlashCmdList.RIVALS("export")
assert(DP.window.edit.text:find(string.format("%.1f", beforeReload), 1, true))
print("PASS: cancellation and countdown dispatch")

SlashCmdList.RIVALS("season start")
assert(o.activeSeason == 1 and #o.seasons == 1)
fire("DUEL_REQUESTED", "Bob")
SlashCmdList.RIVALS("season start")
assert(o.activeSeason == 1) -- Never split an active session.
fire("CHAT_MSG_SYSTEM", "Duel starting: 1")
advance(3)
fire("CHAT_MSG_SYSTEM", "Alice has defeated Bob in a duel.")
assert(o.results[#o.results].periodId == 1 and o.results[#o.results].seasonDecision)
SlashCmdList.RIVALS("season start")
assert(o.activeSeason == 2 and o.seasons[1].endedAt)
fire("PLAYER_LOGIN")
assert(o.activeSeason == 2 and #o.seasons == 2)
SlashCmdList.RIVALS("lifetime")
assert(DP.DisplayPeriodName() == "Lifetime")
DP.CyclePeriod(); assert(DP.DisplayPeriodName() == "Season 1")
DP.CyclePeriod(); assert(DP.DisplayPeriodName() == "Season 2")
DP.CyclePeriod(); assert(DP.DisplayPeriodName() == "Lifetime")
print("PASS: season commands, duel locking, persisted periods and archive selection")
local request, exists, connected = DP.Recovery.Request, UnitExists, UnitIsConnected
local requested = {}
DP.Recovery.Request = function(_, identity) requested[#requested + 1] = identity end
UnitExists = function(unit) return unit ~= "target" and exists(unit) end
DP.RetryRecovery()
assert(#requested == 0) -- Saved opponents must not be queried when no live target exists.
UnitExists = exists
UnitIsConnected = function() return false end
DP.RetryRecovery(); assert(#requested == 0)
UnitIsConnected = function() return true end
DP.RetryRecovery()
assert(#requested == 1 and requested[1].guid == UnitGUID("target"))
local oldFaction = UnitFactionGroup
UnitFactionGroup = function(unit) return unit == "player" and "Alliance" or "Horde" end
fire("PLAYER_TARGET_CHANGED")
DP.RetryRecovery()
assert(#requested == 1, "Enemy targeting and manual retry must not send recovery requests")
UnitFactionGroup = function() return "Alliance" end
DP.RetryRecovery()
assert(#requested == 2, "Same-faction recovery remains available")
UnitFactionGroup = oldFaction
DP.Recovery.Request, UnitIsConnected = request, connected
print("PASS: recovery skips historical and disconnected targets, requests only current live player")
UnitExists = function(unit) return unit == "player" end
fire("DUEL_REQUESTED", "Bob-Realm")
assert(not o.pending.identity)
fire("CHAT_MSG_ADDON", DP.Verification.prefix, "H|1800000000-99|Player-1-B", "WHISPER", "Stranger-Realm")
assert(not o.pending.identity)
fire("CHAT_MSG_ADDON", DP.Verification.prefix, "H|1800000000-99|Player-1-B", "WHISPER", "Bob-Realm")
assert(o.pending.identity.guid == "Player-1-B" and o.pending.verificationToken)
UnitExists = exists
fire("UI_INFO_MESSAGE", 0, "Duel cancelled.")
print("PASS: matching peer hello supplies missing target identity; unrelated sender rejected")

local savedFaction, savedChat = UnitFactionGroup, C_ChatInfo
local blockedSends = 0
C_ChatInfo = {SendAddonMessage = function() blockedSends = blockedSends + 1 end}
UnitFactionGroup = function(unit) return unit == "player" and "Alliance" or "Horde" end
fire("DUEL_REQUESTED", "Bob-Realm")
assert(o.pending.identity.whisperBlocked)
assert(blockedSends == 0, "Enemy duel handshake must not whisper")
fire("UI_INFO_MESSAGE", 0, "Duel cancelled.")
UnitFactionGroup, C_ChatInfo = savedFaction, savedChat
print("PASS: opposite-faction targets skip recovery and duel handshake transport")
