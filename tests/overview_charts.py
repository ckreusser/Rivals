from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
state=runpy.run_path(str(root/'tests/spend_chart.py'))
lua,dp=state['lua'],state['dp']
lua.execute((root/'Theme.lua').read_text(encoding='utf-8-sig'),'Rivals',dp)
lua.execute((root/'OverviewCharts.lua').read_text(encoding='utf-8'),'Rivals',dp)
lua.execute("""
local C=DP.OverviewCharts
local summary={worldBuffsRemoved={},worldBuffRemovalCount=0}
local known={[1]='Dragonslayer',[2]='Songflower'}
local record={playerGUID='self',enemies={{guid='enemy',name='Enemy',died=true,killedAt=10,
 detectedBuffs={world={{spellID=1,name='Dragonslayer',removedAt=10},{spellID=2,name='Songflower',removedAt=5}}}}},
 session={worldCombatLog={
 {event='UNIT_DIED',destGUID='enemy',t=10},
 {event='SPELL_AURA_REMOVED',spellID=1,destGUID='enemy',t=10},
 {event='SPELL_AURA_REMOVED',spellID=2,destGUID='enemy',t=5},
 {event='SPELL_DISPEL',sourceGUID='self',destGUID='enemy',removedSpellID=2,t=9.9},
 {event='SPELL_AURA_REMOVED',spellID=2,destGUID='enemy',t=9.9},
 {event='SPELL_AURA_REMOVED',spellID=1,destGUID='self',t=10}
 }}}
C.AddBuffs(summary,record,known)
assert(summary.worldBuffRemovalCount==2)
assert(summary.worldBuffsRemoved.Dragonslayer.count==1 and summary.worldBuffsRemoved.Songflower.count==1)
local zones=C.RankZones({a={name='A',kills=10,encounters=2,points={{mapID=1,x=.2,y=.4},{mapID=1,x=.8,y=.41}}},
 b={name='B',kills=5,encounters=1,points={{mapID=1,x=.4,y=.8}}}})
assert(zones[1].name=='A' and #zones==2)
local methods=getmetatable(RivalsMostKilledTooltip).__index
function methods:GetFrameLevel() return 1 end
function methods:SetFrameLevel() end
function methods:SetBackdropBorderColor(...) self.borderColor={...} end
function methods:SetScrollChild(c) self.child=c end
function methods:SetVerticalScroll(v) self.scroll=v end
function methods:SetClipsChildren(v) self.clips=v end
function methods:SetTexCoord(...) self.uv={...} end
function methods:SetPoint(...) self.anchor={...} end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
C_Map={GetMapArtLayers=function() return {{layerWidth=480,layerHeight=320,tileWidth=256,tileHeight=256}} end,
 GetMapArtLayerTextures=function() return {1,2,3,4} end}
clock=20;C.ShowZones({}, {topZones=zones})
local f=RivalsFavoriteZoneTooltip
assert(f.rows[1].target==252 and f.rows[2].target==126 and not f.rows[3].shown)
assert(f.rows[1].markers[1].shown)
clock=20.375;f:GetScript('OnUpdate')(f)
assert(f.rows[1].reveal.width==252 and f.rows[1].shade.width==126 and f.rows[2].shade.width==189)
clock=21;f:GetScript('OnUpdate')(f);assert(not f:GetScript('OnUpdate'))
C.HideZones();C.ShowZones({}, {topZones=zones});assert(f.rows[1].reveal.width==252 and f.rows[1].shade.width==252)
C.HideZones();C.ShowZones({}, {topZones={}});assert(f.empty.shown and not f:GetScript('OnUpdate'))
C.ShowBuffs({}, summary)
local b=RivalsWorldBuffTooltip
assert(b.columns[1].target==150 and b.columns[2].target==150)
clock=21.375;b:GetScript('OnUpdate')(b);assert(b.columns[1].bar.height==75)
clock=22;b:GetScript('OnUpdate')(b);assert(not b:GetScript('OnUpdate'))
C.HideBuffs();C.ShowBuffs({}, {worldBuffsRemoved={},worldBuffRemovalCount=0})
assert(b.empty.shown and not b.columns[1].shown and not b:GetScript('OnUpdate'))
""")
print('PASS world buff attribution and deduplication, zone ranks and map Xs, horizontal/vertical animations and empty states')

lua.execute("""
local C=DP.OverviewCharts
local summary={worldBuffsRemoved={
 strength={name="Sayge's Dark Fortune of Strength",spellID=23735,count=2},
 damage={name="Sayge's Dark Fortune of Damage",spellID=23768,count=3},
 armor={name="Sayge's Dark Fortune of Armor",spellID=23767,count=0},
 song={name="Songflower Serenade",spellID=15366,count=1}},worldBuffRemovalCount=6}
local columns=C.BuffColumns(summary)
assert(#columns==2 and columns[1].name=='Darkmoon Faire' and columns[1].count==5)
assert(summary.worldBuffsRemoved.strength.count==2 and summary.worldBuffRemovalCount==6)
C.ShowBuffs({},summary)
assert(RivalsWorldBuffTooltip.columns[1].target==150)
assert(not RivalsWorldBuffTooltip.columns[3] or not RivalsWorldBuffTooltip.columns[3].shown)
local zero=C.BuffColumns({worldBuffsRemoved={
 a={name="Sayge's Dark Fortune of Strength",count=0},
 b={name="Sayge's Dark Fortune of Damage",count=0}}})
assert(#zero==1 and zero[1].count==0)
""")
print('PASS consolidated DMF totals and zero-removal column')

lua.execute("""
local C=DP.OverviewCharts
C_Map.GetMapArtLayers=function(id)
 if id==280 or id==66 then error("Wrong Era map ID") end
 return {{layerWidth=480,layerHeight=320,tileWidth=256,tileHeight=256}}
end
C.ShowZones({}, {topZones={{name='Maraudon',kills=10,points={}}, {name='B',kills=5,points={{mapID=1,x=.4,y=.8}}}}})
local f=RivalsFavoriteZoneTooltip
assert(not f.rows[1].fallback.shown)
assert(C.ZoneMap('Maraudon')==1443 and f.rows[1].markers[1].shown)
assert(f.rows[1].map.canvas.width==252 and f.rows[2].map.canvas.width==252)
clock=clock+1;f:GetScript('OnUpdate')(f)
assert(not f.rows[1].shade.shown and f.rows[2].shade.width==126)
C_Map.GetMapArtLayerTextures=function() return {} end
C.ShowZones({}, {topZones={{name='B',kills=1,points={{mapID=1,x=.4,y=.8}}}}})
assert(f.rows[1].fallback.shown)
for _,tile in pairs(f.rows[1].map.tiles) do assert(not tile.shown) end
""")
print('PASS fixed map zoom, bright fills, unfilled shading, dungeon and missing-art fallbacks')

lua.execute("""
C_Map.GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=700,tileWidth=256,tileHeight=256}} end
C_Map.GetMapArtLayerTextures=function() return {1,2,3,4,5,6,7,8,9,10,11,12} end
DP.OverviewCharts.ShowZones({}, {topZones={{name='B',kills=2,points={{mapID=1,x=.7,y=.8}}}}})
local row=RivalsFavoriteZoneTooltip.rows[1]
assert(row.map.clips)
assert(row.map.canvas.anchor[4]==0 and row.map.canvas.anchor[5]==0)
local area=0
for _,tile in pairs(row.map.tiles) do
 if tile.shown then
  assert(tile.anchor[2]>=0 and tile.anchor[3]<=0)
  assert(tile.anchor[2]+tile.width<=252 and -tile.anchor[3]+tile.height<=30)
  assert(tile.uv[1]>=0 and tile.uv[2]<=1 and tile.uv[3]>=0 and tile.uv[4]<=1)
  area=area+tile.width*tile.height
 end
end
assert(area==252*30)
assert(row.markers[1].anchor[4]==126 and row.markers[1].anchor[5]==-15)
DP.OverviewCharts.ShowZones({}, {topZones={{name='Maraudon',kills=1,points={}}}})
assert(row.map.canvas.anchor[5]==0)
assert(row.markers[1].shown)
""")
print('PASS actual canvas offsets follow kill coordinates and Maraudon entrance')

lua.execute("""
C_MapExplorationInfo={GetExploredMapTextures=function() return {
 {textureWidth=300,textureHeight=60,offsetX=550,offsetY=530,fileDataIDs={101,102}},
 {textureWidth=300,textureHeight=60,offsetX=550,offsetY=530,fileDataIDs={103,104},isShownByMouseOver=true}
} end}
DP.OverviewCharts.ShowZones({}, {topZones={{name='B',kills=1,points={{mapID=1,x=.7,y=.8}}}}})
local overlays=RivalsFavoriteZoneTooltip.rows[1].map.overlays
assert(#overlays==2 and overlays[1].shown and overlays[2].shown)
assert(overlays[2].uv[2]==20/64 and overlays[2].uv[3]==15/64)
C_MapExplorationInfo.GetExploredMapTextures=function() return {} end
DP.OverviewCharts.ShowZones({}, {topZones={{name='B',kills=1,points={{mapID=1,x=.7,y=.8}}}}})
assert(not overlays[1].shown and not overlays[2].shown)
""")
print('PASS discovered terrain overlays, edge-file cropping, mouseover exclusion and reuse')

lua.execute("""
local list={}
for _,id in ipairs({24425,22888,23768,22817,22818,22820,15366,29534,16609}) do
 list[tostring(id)]={name=tostring(id),spellID=id,count=1}
end
DP.OverviewCharts.ShowBuffs({}, {worldBuffsRemoved=list,worldBuffRemovalCount=9})
local b=RivalsWorldBuffTooltip
assert(b.width==376)
for _,col in ipairs(b.columns) do
 assert(col.tile and col.icon.width==36 and col.bar.width==36)
 local left,right,top,bottom=DP.OverviewCharts.BuffTileCrop(col.tile,150)
 assert(left>=0 and right<=col.tile.u and top>=0 and bottom<=col.tile.v)
 assert(math.abs(((right-left)/col.tile.u)*col.tile.aspect/((bottom-top)/col.tile.v)-36/150)<.00001)
end
""")
print('PASS nine screenshot mappings, 36px icons and bars, compact spacing, proportional image crops')

lua.execute("""
DP.OverviewCharts.ShowBuffs({}, {worldBuffsRemoved={
 a={name='A',spellID=24425,count=5},b={name='B',spellID=23768,count=1},c={name='C',spellID=16609,count=0}},worldBuffRemovalCount=6})
local b=RivalsWorldBuffTooltip
clock=clock+1;b:GetScript('OnUpdate')(b)
for i=1,3 do
 local col=b.columns[i]
 assert(col.background.shown and col.background.height==150)
 local left,right,top,bottom=DP.OverviewCharts.BuffTileCrop(col.tile,150)
 assert(col.bar.uv[1]==left and col.bar.uv[2]==right)
 if col.target>0 then
  assert(math.abs(col.bar.uv[3]-(bottom-(bottom-top)*col.target/150))<.00001)
 end
end
assert(b.columns[2].bar.height==30 and not b.columns[3].bar.shown)
""")
print('PASS fixed-scale image columns, dim unfilled backgrounds, proportional fill reveal')
