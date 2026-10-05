from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
dp = lua.table()
lua.execute(root.joinpath('UsageCatalog.lua').read_text(encoding='utf-8-sig'), 'Rivals', dp)
lua.execute(root.joinpath('WorldPvP.lua').read_text(encoding='utf-8-sig'), 'Rivals', dp)
lua.globals().DP = dp
lua.execute('''
function GetItemIcon(id) return 'item-icon-'..id end
local enemy={detectedBuffs={consumables={
    ['17546']={spellID=17546,name='Greater Nature Protection Potion',itemID=13458,removedAt=78.585},
    ['6624']={spellID=6624,name='Free Action Potion'},
},all={['17546']={spellID=17546,name='Nature Protection ',removedAt=78.585}}}}
local buffs=DP.WorldPvP.GetOpponentBuffsForDetail(enemy)
assert(#buffs==1,'GNPP hidden or short potion leaked')
assert(buffs[1].spellID==17546 and buffs[1].itemID==13458 and buffs[1].removedAt==78.585)
assert(DP.WorldPvP.OpponentBuffIcon(buffs[1])=='item-icon-13458')
local classes={detectedBuffs={all={
    a={spellID=10157,name='Arcane Intellect',icon='intellect-icon',removedAt=20},
    b={spellID=21564,name='Prayer of Fortitude',removedAt=20},
    c={spellID=9885,name='Mark of the Wild',removedAt=20},
    d={spellID=10901,name='Power Word: Shield',removedAt=20},
    e={spellID=14204,name='Enrage',removedAt=20},
}}}
assert(#DP.WorldPvP.GetOpponentBuffsForDetail(classes)==3,'long class buffs missing or short effects leaked')
assert(DP.WorldPvP.OpponentBuffIcon(classes.detectedBuffs.all.a)=='intellect-icon')
GetItemIcon=nil
function GetItemInfoInstant(id) return id,'Consumable','Potion','', 'instant-item-icon' end
assert(DP.WorldPvP.OpponentBuffIcon(buffs[1])=='instant-item-icon')
GetItemInfoInstant=nil
buffs[1].icon='aura-fallback'
assert(DP.WorldPvP.OpponentBuffIcon(buffs[1])=='aura-fallback')
for id,known in pairs(DP.UsageCatalog) do
    if known.category=='potions' and known.name:find('Protection Potion',1,true) then
        local e={detectedBuffs={consumables={x={spellID=id,name=known.name,removedAt=10}}}}
        assert(#DP.WorldPvP.GetOpponentBuffsForDetail(e)==1,known.name..' hidden without duration')
    end
end
''')
print('PASS: death-removal-only GNPP and protection potion buffs visible; Free Action remains filtered')
