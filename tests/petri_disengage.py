from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
s=(root/'WorldPvP.lua').read_text(encoding='utf-8')
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("W={};function GankKind() return nil end;function BubbleHearthEnemy() return nil end")
a=s.index('function W.PetriDisengage(');b=s.index('local function EncounterHeadcount(',a)
lua.execute(s[a:b].replace('local function Outcome(', 'function Outcome('))
lua.execute("""
local function Record(event)
 return {playerGUID='self',enemyCount=1,enemyDeaths=0,enemies={{guid='enemy'}},session={worldCombatLog={event}}}
end
local r=Record({event='SPELL_CAST_SUCCESS',sourceGUID='enemy',spellID=17624})
local label,key=Outcome(r);assert(key=='disengaged' and r.resultSubcategory=='petri' and label:find('PETRI',1,true))
r=Record({event='SPELL_AURA_APPLIED',destGUID='enemy',spellID=17624});assert(W.PetriDisengage(r))
r=Record({event='SPELL_CAST_SUCCESS',sourceGUID='ally',spellID=17624});assert(not W.PetriDisengage(r))
r=Record({event='SPELL_AURA_REMOVED',destGUID='enemy',spellID=17624});assert(not W.PetriDisengage(r))
r=Record({event='SPELL_CAST_SUCCESS',sourceGUID='enemy',spellID=17624});r.enemies[1].died=true;assert(not W.PetriDisengage(r))
r=Record({});r.session.worldUsage={events={{guid='enemy',itemID=13506}}};assert(W.PetriDisengage(r))
r=Record({event='SPELL_CAST_SUCCESS',sourceGUID='self',spellID=17624});r.playerDied=true;label,key=Outcome(r);assert(key=='death')
r=Record({event='SPELL_CAST_SUCCESS',sourceGUID='enemy',spellID=17624});r.enemyDeaths=1;label,key=Outcome(r);assert(key=='victory')
""")
for name in ('WorldPvP.lua','OverviewCharts.lua'):
 lua.execute('assert(loadstring(...))',(root/name).read_text(encoding='utf-8'))
print('PASS Petri evidence, participant and survival checks, preserved kill/death outcomes, Lua syntax')
