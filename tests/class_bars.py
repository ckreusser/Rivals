from pathlib import Path
import runpy
from PIL import Image
root=Path(__file__).resolve().parents[1]
st=runpy.run_path(str(root/'tests/spend_chart.py'))
lua=st['lua']
lua.execute("""
local C=DP.RivalChart
local methods=getmetatable(RivalsMostKilledTooltip).__index
function methods:SetWidth(v) self.width=v end
local records={}
for i,class in ipairs({'MAGE','WARLOCK','PRIEST','PALADIN','SHAMAN','DRUID','HUNTER','ROGUE','WARRIOR'}) do
 assert(C.ClassTexture(class):find('ClassBars',1,true))
 records[i]={name=class,class=class,kills=10-i,encounters=1}
end
C.Show({}, {topMostKilled={records[1],records[2],records[3]},topNemeses={}})
clock=clock+1;RivalsMostKilledTooltip:GetScript('OnUpdate')(RivalsMostKilledTooltip)
assert(math.abs(RivalsMostKilledTooltip.rows[2].bar.width-252*8/9)<.001)
assert(C.ClassTexture('mage')==C.ClassTexture('MAGE'))
""")
for name in ('Mage','Warlock','Priest','Paladin','Shaman','Druid','Hunter','Rogue','Warrior'):
 im=Image.open(root/'Textures/ClassBars'/f'{name}.tga')
 assert im.size==(256,32) and im.mode=='RGB'
print('PASS nine class texture mappings, lowercase resolution, proportional reveals and game-compatible assets')
