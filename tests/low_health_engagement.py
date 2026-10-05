from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = root.joinpath('WorldPvP.lua').read_text(encoding='utf-8-sig')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
W={}; health=400; maximum=1000
function UnitHealth() return health end
function UnitHealthMax() return maximum end
function IsPlayer(flags) return flags==1 end
function IsHostile(flags) return flags==1 end
function IsPressureEvent(event) return event=='SPELL_DAMAGE' or event=='SWING_DAMAGE' end
function GankKind() return nil end
function BubbleHearthEnemy() return nil end
''')
start = source.index('function W.CaptureEngagementHealth(')
end = source.index('function W.Start(',start)
lua.execute(source[start:end])
start = source.index('local function Outcome(')
end = source.index('local function EncounterHeadcount(',start)
lua.execute(source[start:end].replace('local function Outcome(', 'function Outcome(',1))
lua.execute('''
local function capture(damage,source,flags)
    local s={playerGUID='self'}
    W.CaptureEngagementHealth(s,{[2]='SPELL_DAMAGE',[4]=source or 'enemy',[6]=flags or 1,[8]='self',[15]=damage})
    return s
end
local s=capture(100); assert(s.engagementHealthPercent==50 and s.lowHealthEngagement)
assert(not capture(101).lowHealthEngagement,'threshold exceeded')
health=100; assert(not capture(600).lowHealthEngagement,'opening burst mistaken for low health')
assert(not capture(0,'self').lowHealthEngagement,'player-initiated encounter classified')
assert(not capture(0,'npc',2).lowHealthEngagement,'NPC encounter classified')
maximum=0; assert(not capture(0).lowHealthEngagement,'unknown max classified'); maximum=1000
local label,key=Outcome({playerDied=true,lowHealthEngagement=true,enemyDeaths=0})
assert(key=='low_health_death' and label=='LOW-HEALTH DEATH')
label,key=Outcome({playerDied=true,enemyDeaths=0}); assert(key=='death','legacy health invented')
''')
assert 'record.resultKey ~= "low_health_death" then summary.soloLosses' in source
assert 'record.resultKey ~= "low_health_death" then r.soloDeaths' in source
assert 'record.resultKey ~= "low_health_death" then entry.soloDeaths' in source
print('PASS: inclusive 50% threshold, opening-hit protection, enemy-only engagement, unknown health, classification, solo-loss exclusions')
