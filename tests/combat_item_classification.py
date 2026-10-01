"""Regression fixtures from the reported Era combat-log IDs, rendered by real code."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
DP={Theme={}}; player='Player-5066-01722C84'; npc='Creature-0-5178-1-43-3296-000039C158'
function ShortName(name) return (name or 'Unknown'):match('^[^-]+') end
function HasFlag(value, flag) return math.floor(value/flag)%2==1 end
function DP.Theme.ClassName(name) return name end
function DP.Theme.SpellTextLink(id,name,color) return color..'['..name..']|r' end
function DP.Theme.ItemTextLink(id,name,quality) return '|cff0070dd|Hitem:'..id..'|h['..name..']|h|r' end
function entry(id,name,event,source,t)
 return {spellID=id,spellName=name,event=event,sourceGUID=source or player,sourceName=source==npc and 'Orgrimmar Grunt' or 'Zurker',
  destGUID=player,destName='Zurker',t=t or 1}
end
function record(rows)
 return {playerGUID=player,playerClass='WARRIOR',session={playerGUID=player,participants={[player]={name='Zurker',class='WARRIOR'}},worldCombatLog=rows}}
end
''')
for name in ['UsageCatalog.lua', 'ProcCatalog.lua', 'Specs.lua', 'Usage.lua']:
    lua.execute((root / name).read_text(encoding='utf-8-sig'), 'Rivals', lua.globals().DP)
source = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
lua.execute(source, 'Rivals', lua.globals().DP)
start = source.index('        local participants = record.session', source.index('    elseif tab == "log" then'))
end = source.index('        local changedRecord = window._combatLogCursorRecord', start)
lua.execute('local W=DP.WorldPvP\nfunction Render(record)\nlocal window={}\n' + source[start:end] + '\nreturn logText, displayEntries\nend')
lua.execute('''
local U=DP.Usage
assert(not U.ResolveProcItem(1604,'Dazed',nil,npc))
assert(not U.ResolveProcItem(13496,'Dazed',nil,npc),'even an exact item-effect ID does not establish NPC gear')
assert(not U.IsKnownProcEffect(676,'Disarm',player))
assert(not U.IsKnownProcEffect(15571,'Dazed',player))
assert(not U.IsKnownProcEffect(nil,'Disarm',player))
assert(not U.IsKnownProcEffect(nil,'Holy Strength',player))
assert(U.ResolveProcItem(13496,'Dazed',nil,player).itemID==4090,'actual Mug proc must still resolve')
assert(U.ResolveCombatItem(363880,nil,player,'Diamond Flask',record({})).itemID==20130)
local bad=entry(1604,'Dazed','SPELL_AURA_APPLIED',npc)
bad.procItemID=4090; bad.procItemName="Mug O' Hurt" -- erroneous metadata from an old build
local text=Render(record({bad}))
assert(not text:find('Mug',1,true) and not text:find('c7a0ff',1,true))
assert(text:find('Orgrimmar Grunt applied',1,true))

local aura=entry(24427,'Diamond Flask','SPELL_AURA_APPLIED',player,27.1)
local use=entry(363880,'Diamond Flask','SPELL_CAST_SUCCESS',player,27.1)
local text,rows=Render(record({aura,use}))
assert(rows[1]==use and rows[2]==aura,'item activation must precede resulting aura')
assert(text:find('Zurker used |cff0070dd|Hitem:20130',1,true))
assert(text:find('Zurker applied |cffffffff[Diamond Flask]',1,true))
assert(not text:find('cast',1,true))
print('PASS: NPC Dazed attribution repaired, including saved metadata; Diamond Flask uses item link before aura')

local abilities={
 {'WARRIOR',676,'Disarm'}, {'WARRIOR',772,'Rend'},
 {'PALADIN',853,'Hammer of Justice'}, {'HUNTER',5116,'Concussive Shot'},
 {'ROGUE',2094,'Blind'}, {'PRIEST',589,'Shadow Word: Pain'},
 {'SHAMAN',403,'Lightning Bolt'}, {'MAGE',116,'Frostbolt'},
 {'WARLOCK',686,'Shadow Bolt'}, {'DRUID',339,'Entangling Roots'},
}
for _,row in ipairs(abilities) do
 for _,event in ipairs({'SPELL_CAST_SUCCESS','SPELL_AURA_APPLIED','SPELL_DAMAGE','SPELL_PERIODIC_DAMAGE','SPELL_AURA_REMOVED'}) do
  local spell=entry(row[2],row[3],event);spell.amount=100
  local rec=record({spell});rec.session.participants[player].class=row[1]
  local text=Render(rec)
  assert(not text:find('c7a0ff',1,true),row[1]..' '..row[3]..' was colored as an item proc')
 end
end
local unknown=entry(999999,'Unknown class effect','SPELL_AURA_APPLIED')
unknown.destGUID='Player-target'
assert(not Render(record({unknown})):find('c7a0ff',1,true),'missing cast/class evidence must not imply proc')
local proc=entry(13496,'Dazed','SPELL_AURA_APPLIED')
local text=Render(record({proc}))
assert(text:find('Mug O',1,true) and text:find('|cffc7a0ff[Dazed]',1,true))
for _,candidate in ipairs(DP.ProcCatalog) do
 assert(U.IsKnownProcEffect(candidate[1],candidate[4],player),'catalog effect lost exact-ID classification')
 assert(not U.IsKnownProcEffect(candidate[1],candidate[4],npc),'NPC classified as item proc')
end
print('PASS: all nine classes, missing cast events, unknown effects, and every proc-catalog row')

local shields = {
 {29164,23238,'Stygian Grasp','Stygian Buckler',{'SPELL_AURA_APPLIED','SPELL_AURA_REFRESH'}},
 {27559,22198,'Silence','Jagged Obsidian Shield',{'SPELL_AURA_APPLIED','SPELL_AURA_REFRESH'}},
 {18817,1168,'Drain Life','Skullflame Shield',{'SPELL_DAMAGE','SPELL_HEAL'}},
 {18818,1168,'Flamestrike','Skullflame Shield',{'SPELL_DAMAGE'}},
}
for _,row in ipairs(shields) do
 for _,event in ipairs(row[5]) do
  local proc=entry(row[1],row[3],event); proc.amount=35
  local rec=record({proc})
  rec.session.participants[player].portraitAppearance={items={[17]=row[2]}}
  local resolved=U.ResolveProcItem(row[1],row[3],nil,player,rec)
  assert(resolved and resolved.itemID==row[2],row[4]..' not resolved')
  local text=Render(rec)
  assert(text:find('|Hitem:'..row[2]..'|',1,true),row[4]..' missing item link')
  assert(text:find('|cffc7a0ff['..row[3]..']',1,true),'proc color missing')
  -- Old records with an exact unique spell ID must also render without gear snapshots.
  assert(Render(record({proc})):find('|Hitem:'..row[2]..'|',1,true))
  assert(not U.ResolveProcItem(row[1],row[3],nil,npc,rec))
 end
end
for _,row in ipairs({{15487,'Silence'},{689,'Drain Life'},{2120,'Flamestrike'}}) do
 assert(not U.IsKnownProcEffect(row[1],row[2],player),'class spell mistaken for shield proc')
 assert(not U.ResolveProcItem(row[1],row[2],nil,player))
end
print('PASS: Stygian Buckler, Jagged Obsidian Shield, both Skullflame procs, saved records, and same-name class exclusions')
''')
