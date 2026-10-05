from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
dp=lua.table()
for name in ['UsageCatalog.lua','ProcCatalog.lua','Specs.lua','Usage.lua']:
    lua.execute(root.joinpath(name).read_text(encoding='utf-8-sig'),'Rivals',dp)
lua.globals().U=dp.Usage
source=root.joinpath('Usage.lua').read_text(encoding='utf-8-sig')
start=source.index('local function WorldUsageEvent(')
end=source.index('local function WorldUsageBase(',start)
lua.execute(source[start:end].replace('local function WorldUsageEvent(', 'function WorldUsageEvent(',1))
lua.execute('''
local s={}
for i=1,2000 do assert(WorldUsageEvent(s,{t=i,kind='cooldown'})) end
assert(not WorldUsageEvent(s,{t=2001,kind='cooldown'}))
local function use(at)
 return WorldUsageEvent(s,{guid='enemy',t=at,itemID=10646,spellID=13241,name='Goblin Sapper Charge',category='engineering'})
end
assert(use(2002),'consumable dropped at limit')
assert(not use(2002.1),'duplicate consumable counted')
assert(use(2302),'later legitimate use dropped')
assert(WorldUsageEvent(s,{guid='enemy',t=2303,itemID=17020,kind='reagent',category='reagents',consumable=true}))
assert(#s.worldUsage.events==2003 and s.worldUsage.truncated)
U.GetSnapshotPrice=function() return 100,'fixture' end
local cost=U.CaptureWorldConsumableCost(s,{skipReconstruct=true,capturedAt=2400})
assert(cost.pricedCount==3 and cost.totalCopper==300,'overflow consumables missing from costs')
''')
print('PASS: 2,000 ordinary usages, unlimited observed consumables/reagents, duplicate suppression, overflow included in costs')
