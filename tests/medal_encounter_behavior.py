from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.execute('DP={}; now=0; earned={}; function GetTime() return now end; function DP.RecordMedal(x) earned[x]=(earned[x] or 0)+1 end')
dp = lua.globals().DP
for file in root.glob('*.lua'):
    lua.execute('assert(loadstring(...))', file.read_text(encoding='utf-8-sig'))
lua.execute(root.joinpath('MultiKill.lua').read_text(encoding='utf-8-sig'), 'Rivals', dp)
lua.execute('''
local M=DP.MultiKill
assert(not M.IsEligibleLevel(47,60) and M.IsEligibleLevel(48,60))
assert(not M.IsEligibleLevel(31,40) and M.IsEligibleLevel(32,40))
assert(not M.IsEligibleLevel(nil,60))
M.OnKillingBlow(60,60,true); now=12; M.OnKillingBlow(60,60,true)
assert(earned.DoubleKill==1 and M.GetCount()==2)
now=24.01; M.OnKillingBlow(60,60,true); assert(M.GetCount()==1)
M.Reset(); now=30; M.OnKillingBlow(60,60,true)
now=31; M.OnKillingBlow(47,60,true)
now=32; M.OnKillingBlow(60,60,true)
assert(M.GetCount()==3 and earned.DoubleKill==1 and not earned.TripleKill)
now=33; M.OnKillingBlow(60,60,true); assert(earned.DoubleKill==2)
M.Reset(); M.OnKillingBlow(); M.OnKillingBlow(); assert(earned.DoubleKill==2)
function IsInInstance() return true,'pvp' end
function UnitLevel() return 60 end
function CombatLogGetCurrentEventInfo() return 0,'PARTY_KILL',false,'Player-self',nil,nil,nil,'Player-enemy' end
M.Reset(); M.Combat('Player-self'); M.Combat('Player-self')
assert(M.GetCount()==2 and earned.DoubleKill==2)
''')
world = root.joinpath('WorldPvP.lua').read_text(encoding='utf-8-sig')
start = world.index('function W.CompletedEnemyGrace(')
end = world.index('\nlocal function MarkInteraction', start)
lua.execute('W={}; CFG={ALL_ENEMIES_DEAD_GRACE=6}')
lua.execute(world[start:end])
lua.execute('''
local s={startedElapsed=0,enemies={a={died=true,killedAt=10},b={died=true,killedAt=20}}}
assert(not W.CompletedEnemyGrace(s,25.99)); assert(W.CompletedEnemyGrace(s,26))
s.lastActivity=25.9; assert(W.CompletedEnemyGrace(s,26),'NPC activity extended fight')
s.enemies.a.died=nil; assert(not W.CompletedEnemyGrace(s,100),'resurrection closed unfinished fight')
s.enemies.a.died=true; s.playerDied=true; assert(not W.CompletedEnemyGrace(s,100),'trade became win')
for _, event in ipairs({'SPELL_RESURRECT','SPELL_CAST_SUCCESS','SWING_DAMAGE'}) do
    s.playerDied=nil; s.enemies.a={died=true,killedAt=10,killingBlow=true}
    W.ObserveEnemyRevival(s,{[2]=event,[4]='a',[8]='a'})
    assert(not s.enemies.a.died and not s.enemies.a.killingBlow)
    assert(not W.CompletedEnemyGrace(s,100))
end
s.enemies.a={died=true,killedAt=10}
for _, event in ipairs({'SPELL_PERIODIC_DAMAGE','SPELL_AURA_REMOVED','UNIT_DIED'}) do
    W.ObserveEnemyRevival(s,{[2]=event,[4]='a',[8]='a'})
    assert(s.enemies.a.died,'corpse event reopened fight')
end
''')
lua.execute(root.joinpath('LogRepair.lua').read_text(encoding='utf-8-sig'), 'Rivals', dp)
lua.execute('''
local r={id=142,timestamp=1791171493,playerGUID='Player-5066-01722C84',playerDied=true,
enemyDeaths=3,playerDiedAt=95.475,duration=102.161,endedAt=1791171595,resultKey='trade',
enemies={{guid='Player-5066-02E07E49',died=true,killingBlow=true,killedAt=26},
{guid='b',died=true,killingBlow=true,killedAt=38},{guid='c',died=true,killingBlow=true,killedAt=78.585}}}
local store={nextSequence=145,encounters={r}}
assert(DP.RepairConfirmedEncounter(store)); assert(not DP.RepairConfirmedEncounter(store))
assert(#store.encounters==1 and store.nextSequence==145)
assert(not r.playerDied and r.completedSoloSweep==3 and r.resultKey=='outnumbered_victory')
store.encounters[2]={playerGUID=r.playerGUID,repairedFromEncounterId=142,correctionSource='confirmed',enemies={{guid='Player-5066-02E07E49'}}}
assert(DP.RepairConfirmedEncounter(store)); assert(#store.encounters==1)
assert(not DP.RepairConfirmedEncounter(store))
''')
print('PASS: Lua 5.1 compilation, 12s window, level boundaries, gray chain reset, previews/BGs, completion grace, revival, idempotent log repair')
