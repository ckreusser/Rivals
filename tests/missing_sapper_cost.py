from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
dp=lua.table()
for name in ['UsageCatalog.lua','ProcCatalog.lua','Specs.lua','Usage.lua']:
    lua.execute(root.joinpath(name).read_text(encoding='utf-8-sig'),'Rivals',dp)
lua.globals().DP=dp
lua.execute('''
local U=DP.Usage
local r={playerGUID='self',enemies={{guid='enemy',name='Harambae'}},session={worldUsage={events={
 {guid='enemy',actorName='Harambae',itemID=13458,spellID=17546,name='Greater Nature Protection Potion',category='potions',t=1},
 {guid='enemy',actorName='Harambae',itemID=10646,spellID=13241,name='Goblin Sapper Charge',category='engineering',t=74.8},
}}},consumableCost={captureModelVersion=4,pricedCount=1,unpricedCount=0,actors={
 {guid='enemy',items={{itemID=13458,name='Greater Nature Protection Potion',count=1,unitCopper=60143,priceSource='original'}}}
}}}
assert(U.NeedsLegacyConsumableBackfill(r),'nonempty missing sapper snapshot not repaired')
U.GetSnapshotPrice=function(id) assert(id==10646,'old price was queried again');return 74944,'test market' end
local cost=U.CaptureLegacyWorldConsumableCost(r,100,{},true)
assert(cost.totalCopper==135087 and cost.pricedCount==2)
local found={}
for _,actor in ipairs(cost.actors) do for _,item in ipairs(actor.items) do found[item.itemID]=item end end
assert(found[10646].count==1 and found[10646].unitCopper==74944)
assert(found[13458].unitCopper==60143 and found[13458].priceSource=='original')
r.consumableCost=cost;assert(not U.NeedsLegacyConsumableBackfill(r),'repair not stable')
assert(not U.IsConsumableWorldEvent({itemID=20130,spellID=363880,category='equipment',name='Diamond Flask'}))
for _,id in ipairs({10587,11825}) do
 assert(not U.IsConsumableWorldEvent({itemID=id,category='engineering',name='Bomb'}),'reusable bomb counted')
end
for _,id in ipairs({4395,4390,10646,16040,4366}) do
 assert(U.IsConsumableWorldEvent({itemID=id,category='engineering'}),'uncached expendable missed')
end
for spell,known in pairs(DP.UsageCatalog) do
 if known.category=='potions' then
  assert(U.IsConsumableWorldEvent({spellID=spell,itemID=known.itemID,name=known.name,category=known.category}))
 end
end
U.GetSnapshotPrice=function(id) if id==10646 then return nil end; return 100,'fixture' end
local duplicate={playerGUID='self',session={worldCombatLog={
 {t=1,event='SPELL_CAST_SUCCESS',sourceGUID='self',spellID=17546,spellName='Nature Protection'},
 {t=1.1,event='SPELL_AURA_APPLIED',sourceGUID='self',destGUID='self',spellID=17546,spellName='Nature Protection'},
 {t=130,event='SPELL_CAST_SUCCESS',sourceGUID='self',spellID=17546,spellName='Nature Protection'},
},worldUsage={events={{t=5,guid='enemy',spellID=13241,itemID=10646,name='Goblin Sapper Charge',category='engineering'}}}}}
local c=U.CaptureLegacyWorldConsumableCost(duplicate,200,{},true)
assert(c.pricedCount==2 and c.totalCopper==200,'cast/aura duplicated or legitimate second use lost')
assert(c.unpricedCount==1 and c.partial,'unpriced sapper was silently lost')
''')
print('PASS: missing sapper repaired in nonempty snapshot, prior price preserved, one charge counted, stable repair, reusable gear excluded')
