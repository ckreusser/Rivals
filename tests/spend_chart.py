from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
dp = lua.table()
for file in ('UsageCatalog.lua', 'SpendChart.lua', 'RivalChart.lua'):
    lua.execute((root/file).read_text(encoding='utf-8-sig'), 'Rivals', dp)
lua.globals().DP = dp
lua.execute('''
local S=DP.SpendChart
assert(S.Category({itemID=13506})=='petrification')
assert(S.Category({itemID=2091})=='dust')
assert(S.Category({itemID=16040})=='arcane')
assert(S.Category({itemID=1251})=='bandages')
assert(S.Category({itemID=10646})=='bombs')
assert(S.Category({name='Iron Grenade'})=='bombs')
assert(S.Category({name='Love Fool'})=='gadgets')
assert(S.Category({name='Tranquil Mechanical Yeti'})=='gadgets')
assert(S.Category({name='Advanced Target Dummy'})=='gadgets')
assert(S.Category({name='Greater Arcane Elixir'})=='elixirs')
assert(S.Category({name='Crystal Basilisk Spine'})=='other')
local rows,total=S.Slices({potions=10000,dust=1,arcane=5000,bombs=5000})
assert(total==20001 and rows[1].key=='potions')
assert(rows[1].startAngle==0 and rows[#rows].endAngle==360)
local visibleTotal=0;for _,row in ipairs(rows) do visibleTotal=visibleTotal+row.copper end
assert(#rows==3)
for i,row in ipairs(rows) do
 assert(math.abs((row.endAngle-row.startAngle)-360*row.copper/visibleTotal)<1e-9)
 if i>1 then assert(row.startAngle==rows[i-1].endAngle) end
end
local tiny=S.Slices({potions=999,bandages=1})
assert(#tiny==1 and tiny[1].endAngle==360 and tiny[1].percent==99.9)
local larger=S.Slices({potions=990,bandages=10})
assert(#larger==2)
local dust=S.Slices({dust=100})[1]
assert(dust.color[1]>.9 and dust.color[2]>.9 and dust.color[3]>.85)
assert(#S.Slices({})==0)
local unknown={};for i=1,200 do unknown[tostring(i)]=1 end
assert(#S.Slices(unknown)==1)

clock=0; objects={}
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:Show() self.shown=true end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown=false end
function methods:SetShown(v) self.shown=v end
function methods:SetRotation(v) self.rotation=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetText(v) self.text=v end
function methods:GetFont() return "test",12,"" end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetVertexColor(...) self.color={...} end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetVertexOffset(i,x,y) self.vertices=self.vertices or {}; self.vertices[i]={x,y} end
function methods:SetEndPoint(...) self.endpoint={...} end
function methods:SetTexture(path,wrapX,wrapY,filter) self.filter=filter end
function methods:SetSnapToPixelGrid(v) self.snap=v end
function methods:SetTexelSnappingBias(v) self.bias=v end
function methods:CreateTexture() return CreateFrame() end
function methods:CreateLine() return CreateFrame() end
function methods:CreateFontString() return CreateFrame() end
for _,k in ipairs({'SetParent','SetFrameStrata','EnableMouse','SetClampedToScreen','SetBackdrop','SetBackdropColor','SetPoint','SetHeight','SetWidth','SetJustifyH','SetAllPoints','SetTexCoord','SetThickness','SetScale','SetTextColor','SetShadowColor','SetShadowOffset','SetFont','SetStartPoint','ClearAllPoints'}) do methods[k]=function() end end
function CreateFrame(_,name)
 local f=setmetatable({scripts={}},{__index=methods}); objects[#objects+1]=f
 if name then _G[name]=f end
 return f
end
function GetTime() return clock end
S.Show({}, {potions=100,dust=50},150)
local f=RivalsEnemySpendTooltip
assert(f.legend[1].name.text=='Potions')
assert(f.legend[1].value.text=='<1g' and f.legend[1].percent.text=='66.7%')
assert(f.background.color[4]==1)
assert(f.width==280 and f.height==369 and f.chart.width==200)
assert(not f.sweep.shown)
assert(S.Money(13563172)=='1,356g')
assert(S.Money(0)=='0g')
assert(S.Money(9630)=='<1g')
assert(S.Money(9055161)=='906g')
assert(f.total.text=='<1g' and not f.legend[1].icon)
-- Keep a bottom margin; shrink only when the screen cannot fit all rows.
local x,y,scale=S.Placement(1920,1080,200,300,150,457)
assert(y==16 and scale==1 and x==310)
x,y,scale=S.Placement(800,400,700,750,300,501)
assert(scale<1 and y>=16 and y+501*scale<=384.00001)
assert(x>=16 and x+280*scale<=784.00001)
x,y,scale=S.Placement(800,600,500,750,590,457)
assert(x==210 and y+457<=584)
for _,line in ipairs(f.separators) do assert(not line.shown,'premature separator') end
clock=.375;f:GetScript('OnUpdate')(f)
assert(math.abs(f.renderedAngle-180)<1e-9)
assert(f.sweep.shown)
assert(#f.triangles==180)
assert(f.triangles[1].filter=="LINEAR" and f.triangles[1].snap==false and f.triangles[1].bias==0)
assert(f.separators[1].filter=="LINEAR" and f.separators[1].snap==false)
-- Top boundary and clockwise motion are determined by actual vertices.
assert(f.triangles[1].vertices[3][1]==-100 and f.triangles[1].vertices[3][2]==0)
assert(f.triangles[1].vertices[4][1]>-100)
clock=f.rows[1].completedAt+.10;f:GetScript('OnUpdate')(f)
assert(f.rows[1].popOffset>2.9 and f.rows[2].popOffset==0,'pop must follow slice completion')
assert(f.separators[1].shown)
clock=1;f:GetScript('OnUpdate')(f)
assert(f.rows[1].popOffset==0 and f.rows[2].popOffset==0,'slices must settle')
assert(f.renderedAngle==360 and not f:GetScript('OnUpdate'))
assert(not f.sweep.shown)
local count=#objects
S.Hide();assert(not f.shown)
clock=1;S.Show({}, {potions=100,dust=50},150)
assert(#objects==count and f.renderedAngle==0 and f:GetScript('OnUpdate'))
S.Hide();clock=2.1;S.Show({}, {potions=100,dust=50},150)
assert(f.renderedAngle==0 and f:GetScript('OnUpdate'))
clock=2.3;f:GetScript('OnUpdate')(f)
local before=f.renderedAngle
S.Hide();clock=2.5;S.Show({}, {potions=100,dust=50},150)
f:GetScript('OnUpdate')(f)
assert(before>0 and f.renderedAngle==0)
S.Hide();clock=2.6;S.Show({}, {potions=999,bandages=1},1000)
assert(f.renderedAngle==0 and not f.legend[2].shown and f.height==347)
clock=3.4;f:GetScript('OnUpdate')(f)
assert(not f.separators[2].shown,'separator hides tiny slice')
S.Hide();S.Show({}, {potions=99999,bandages=1},100000)
assert(not f.legend[2].shown)
S.Hide();S.Show({}, {},0)
assert(f.empty.shown and not f.triangles[1].shown and not f:GetScript('OnUpdate'))
S.Hide()
''')

lua.execute('''
local C=DP.RivalChart
RAID_CLASS_COLORS={MAGE={r=.25,g=.78,b=.92},ROGUE={r=1,g=.96,b=.41}}
local stats={}
for i=1,8 do stats[tostring(i)]={name='Enemy'..i,class=i==1 and 'ROGUE' or 'MAGE',kills=i,deaths=9-i,encounters=i,lastAt=100} end
local killed,nemeses=C.Rank(stats)
assert(#killed==5 and killed[1].name=='Enemy8' and killed[5].kills==4)
assert(#nemeses==3 and nemeses[1].name=='Enemy1' and nemeses[3].deaths==6)
clock=10;C.Show({}, {topMostKilled=killed,topNemeses=nemeses})
local f=RivalsMostKilledTooltip
assert(f.width==280 and f.rows[1].target==252 and f.rows[6].count.text=='8 deaths')
assert(f.rows[1].name.text=='Enemy8' and f.rows[1].count.text=='8 KBs')
assert(f.rows[1].bar.color[1]==.25 and f.rows[6].bar.color[1]==1)
assert(not f.sections[1].shown and f.sections[2].text=='NEMESES')
assert(f.rows[1].track and f.rows[1].height==26 and f.rows[1].rule.height==1)
clock=10.375;f:GetScript('OnUpdate')(f)
clock=10.75;f:GetScript('OnUpdate')(f)
assert(not f:GetScript('OnUpdate'))
C.Hide();clock=11;C.Show({}, {topMostKilled=killed,topNemeses=nemeses})
assert(f:GetScript('OnUpdate') and not f.rows[1].bar.shown)
C.Hide();C.Show({}, {topMostKilled={},topNemeses={}})
assert(f.empty.shown and f.height==82 and not f:GetScript('OnUpdate'))
C.Hide()
''')

source=(root/'WorldPvP.lua').read_text(encoding='utf-8-sig')
start=source.index('local function EnemyConsumableSpend(record)')
end=source.index('local function TrimEncounterStore(store)',start)
lua.execute('''
function ShortName(name) return name and name:match('^[^-]+') end
''' + source[start:end] + '''
local record={enemies={{guid='enemy',name='Harambae-Realm'}},consumableCost={actors={
 {guid='self',totalCopper=9999,items={{name='Free Action Potion',totalCopper=9999}}},
 {guid='enemy',name='Harambae',totalCopper=600,pricedCount=3,items={
  {itemID=10646,totalCopper=300}, {itemID=2091,unitCopper=100,count=2},
  {name='Healing Potion',totalCopper=100}}}
}}}
local total,partial,priced,unpriced,categories=EnemyConsumableSpend(record)
assert(total==600 and priced==3 and not partial and unpriced==0)
assert(categories.bombs==300 and categories.dust==200 and categories.potions==100)
local store={}
ArchiveEnemyConsumableSpend(store,record)
ArchiveEnemyConsumableSpend(store,record)
assert(store.enemyGoldArchivedCopper==1200 and store.enemyGoldArchivedCategories.bombs==600)
assert(EnemyConsumableSpend({})==0)
local old={enemies={{name='Harambae'}},consumableCost={actors={{name='Harambae',totalCopper=900}}}}
local copper,_,_,_,buckets=EnemyConsumableSpend(old)
assert(copper==900 and buckets.other==900)
''')
assert 'SpendChart.lua\nRivalChart.lua\nOverviewCharts.lua\nOverviewArchive.lua\nOverviewRecovery.lua\nWorldPvP.lua' in (root/'Rivals.toc').read_text()
assert (root/'Textures/SpendPieSurface.tga').exists()
print('PASS spending categories, enemy-only totals, archive accumulation, exact angles, textured geometry, slice pops, animation, gold-only display, screen placement, every-hover restart and reuse')
