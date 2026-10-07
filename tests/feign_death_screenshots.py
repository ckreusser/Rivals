"""Exercise Feign Death guards and delayed captures with the real Lua helpers."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
lua = LuaRuntime()
lua.execute('assert(loadstring(...))', source)
lua.execute('''
W = {}; DP = {}; now = 10; visible = true; feigning = false
captures = 0; timers = {}
function GetTime() return now end
function W.VisibleUnitForGUID(guid) if visible and guid == 'hunter' then return 'target' end end
function UnitIsFeignDeath(unit) return feigning end
function DP.TakeRivalsScreenshot(kind, name) captures = captures + 1; return true end
C_Timer = {After = function(delay, callback) timers[#timers + 1] = callback end}
function Flush() local pending = timers; timers = {}; for _, callback in ipairs(pending) do callback() end end
function Reset()
    now = 10; visible = true; feigning = false; captures = 0; timers = {}
    enemy = {guid = 'hunter', name = 'Hunter', died = true}
    session = {enemies = {hunter = enemy}}; W.active = session
end
function Event(event, spellID)
    return {[2] = event, [4] = 'hunter', [8] = 'hunter', [12] = spellID}
end
''')
helpers = source[source.index('function W.IsFeigningDeath('):source.index('\nlocal function CombatSpellInfo(')]
capture = source[source.index('local function ScreenshotEnemyDeath('):source.index('\n-- Damage events are still useful')]
lua.execute(helpers + '\n' + capture + '''
-- Classic death without an unconscious flag, but the visible unit is feigning.
Reset(); feigning = true
assert(IsUnconsciousDeathEvent(Event('UNIT_DIED')))
ScreenshotEnemyDeath(session, enemy, .2); Flush(); assert(captures == 0)

-- Target disappears after the cast/aura. CLEU tracking still rejects it.
Reset(); visible = false
W.ObserveFeignDeath(session, Event('SPELL_CAST_SUCCESS', 5384))
assert(IsUnconsciousDeathEvent(Event('UNIT_DIED')))
W.ObserveFeignDeath(session, Event('SPELL_AURA_APPLIED', 5384))
now = 30; assert(W.IsFeigningDeath(session, 'hunter'))
ScreenshotEnemyDeath(session, enemy, .2); Flush(); assert(captures == 0)

-- A late aura cancels a death capture that was already queued.
Reset(); ScreenshotEnemyDeath(session, enemy, .2)
W.ObserveFeignDeath(session, Event('SPELL_AURA_APPLIED', 5384))
Flush(); assert(captures == 0)

-- Recheck live unit state when the callback fires, even without an aura event.
Reset(); ScreenshotEnemyDeath(session, enemy, .2); feigning = true
Flush(); assert(captures == 0 and not session.rivalsScreenshotDeaths.hunter)

-- A real death after Feign Death ends captures once, despite duplicate events.
Reset(); W.ObserveFeignDeath(session, Event('SPELL_AURA_APPLIED', 5384))
W.ObserveFeignDeath(session, Event('SPELL_AURA_REMOVED', 5384))
assert(not IsUnconsciousDeathEvent(Event('UNIT_DIED')))
ScreenshotEnemyDeath(session, enemy, .2); ScreenshotEnemyDeath(session, enemy, .2)
Flush(); assert(captures == 1)

-- Failed/resisted cast expires; a confirmed kill clears stale tracked feign.
Reset(); visible = false
W.ObserveFeignDeath(session, Event('SPELL_CAST_SUCCESS', 5384))
now = 12.1; assert(not W.IsFeigningDeath(session, 'hunter'))
W.ObserveFeignDeath(session, Event('SPELL_AURA_APPLIED', 5384))
W.ObserveFeignDeath(session, Event('PARTY_KILL'))
ScreenshotEnemyDeath(session, enemy, .2); Flush(); assert(captures == 1)

-- Explicit unconscious flags and revival during the delay remain safe.
Reset(); local death = Event('UNIT_DIED'); death[13] = true
assert(IsUnconsciousDeathEvent(death))
local kill = Event('PARTY_KILL'); kill[16] = 1
assert(IsUnconsciousDeathEvent(kill))
ScreenshotEnemyDeath(session, enemy, .2); enemy.died = nil
Flush(); assert(captures == 0)
''')
print('PASS: Feign Death state, missing flags, lost targets, delayed cancellation, real kills, duplicates, and revival')
