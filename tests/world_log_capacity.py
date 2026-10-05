"""Exercise real capture code across the ordinary budget and lifecycle overflow."""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = root.joinpath('WorldPvP.lua').read_text(encoding='utf-8-sig')
lua = LuaRuntime()
lua.execute('''
DP={}; W={}; now=0
function GetTime() return now end
function ShortName(name) return name or 'Unknown' end
function CombatSpellInfo(info) return info[12],info[13] end
function IsUnconsciousDeathEvent(info) return false end
function IsPlayer(flags) return true end
function W.IsMindControlCapSpell() return false end
''')
budget = int(re.search(r'MAX_WORLD_LOG = (\d+)', source).group(1))
assert budget == 2000
lua.execute(f'CFG={{MAX_WORLD_LOG={budget}}}')
start = source.index('local function AppendWorldLog(')
end = source.index('\nlocal function LevelGap(', start)
lua.execute(source[start:end].replace('local function AppendWorldLog(', 'function AppendWorldLog(', 1))
lua.execute('''
local s={startedElapsed=0}
local function emit(event, at)
    now=at
    AppendWorldLog(s,{[2]=event,[4]='Player-a',[5]='Alice',[6]=1,
        [8]='Player-b',[9]='Bob',[10]=1,[12]=20484,[13]='Rebirth',[14]=1,[15]=10,[16]=-1})
end
for i=1,2000 do emit('SPELL_DAMAGE',i) end
assert(#s.worldCombatLog==2000 and not s.worldCombatTruncated)
emit('SPELL_DAMAGE',2001)
assert(#s.worldCombatLog==2000 and s.worldCombatTruncated)
for i,event in ipairs({'PARTY_KILL','UNIT_DIED','SPELL_RESURRECT','UNIT_DESTROYED'}) do
    emit(event,2001+i)
    assert(#s.worldCombatLog==2000+i and s.worldCombatLog[2000+i].event==event)
    assert(s.worldCombatLog[2000+i].t==2001+i)
end
assert(s.worldCombatLog[2003].text=='Alice resurrected Bob with Rebirth')
emit('SPELL_DAMAGE',2006); assert(#s.worldCombatLog==2004)
local old={startedElapsed=0,worldCombatLog={},worldCombatTruncated=true}
for i=1,160 do old.worldCombatLog[i]={event='SPELL_DAMAGE',t=i} end
AppendWorldLog(old,{[2]='UNIT_DIED',[8]='Player-b',[9]='Bob'})
assert(#old.worldCombatLog==161 and old.worldCombatTruncated,'prior omission flag lost')
''')
print('PASS: 2,000 ordinary events, lifecycle events retained beyond cap, resurrection text, chronological order, omission flag preserved')
