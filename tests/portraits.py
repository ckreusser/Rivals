"""Lua 5.1 behavioral tests; no claim of validating Blizzard's rendered pixels.
Run with Python + lupa. This directory is not loaded by Rivals.toc.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in ROOT.glob('*.lua'):
    lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8-sig'))
source = (ROOT / 'Portraits.lua').read_text(encoding='utf-8-sig')
exports = '''
return {P=P, pool=bodyPool, resolve=ResolveRace, prime=ScheduleBodyPrime,
 free=FindFreeBody, dress=DressActor, capture=ReadCapture, frame=HeadCameraProfile,
 waiting=pendingBodyCards, refresh=RefreshWaitingBodyCards,
 native=ReadNativePortraitTarget, requestNative=RequestNativePortraitTarget, camera=FrameActorPortrait}
'''
lua.execute('''
DP={WorldPvP={}}; now=0; tasks={}
C_Timer={After=function(delay, fn) tasks[#tasks+1]={at=now+delay, fn=fn} end}
function advance(delta)
 local stop=now+delta
 while true do
  local selected
  for i,t in ipairs(tasks) do
   if t.at<=stop and (not selected or t.at<tasks[selected].at) then selected=i end
  end
  if not selected then break end
  local task=table.remove(tasks,selected); now=task.at; task.fn()
 end
 now=stop
end
''')
lua.globals().T = lua.execute(source + exports, 'Rivals', lua.globals().DP)
lua.execute('''
local races={'Human','Orc','Dwarf','NightElf','Scourge','Tauren','Gnome','Troll'}
local cases=0
for race=1,8 do for sex=2,3 do
 local identity={raceFile=races[race],portraitSex=sex}
 local r,s=T.resolve(identity,{slotCount=2}) -- delayed captures lack unit metadata
 assert(r==race and s==sex,'identity fallback lost race/sex')
 r,s=T.resolve({}, {raceID=race,sex=sex})
 assert(r==race and s==sex)
 local key=race..':'..sex
 local scene={SetPaused=function() end}
 local actor={loaded=false,dressed=true,undresses=0}
 function actor:IsLoaded() return self.loaded end
 function actor:SetOnModelLoadedCallback(fn) self.callback=fn end
 function actor:Undress()
  self.undresses=self.undresses+1
  C_Timer.After(.02,function() self.dressed=false end)
 end
 function actor:GetActiveBoundingBox()
  if self.dressed then return -5,-5,0,5,5,9 end
  return -.4,-.3,0,.4,.3,2
 end
 local entry={actor=actor,scene=scene,raceID=race,sex=sex}
 T.pool.byKey[key]={entry}
 T.prime(entry)
 advance(.15)
 assert(not entry.ready and actor.undresses==0,'unloaded actor was measured')
 actor.loaded=true; actor.callback()
 assert(not entry.ready,'bounds captured before undress settled')
 advance(.07)
 assert(entry.ready and entry.baseBounds[6]==2,'donor equipment polluted body bounds')
 assert(actor.undresses==1)
 assert(T.free(race,sex,{name='one'})==entry)
 entry.card={}
 assert(T.free(race,sex,{name='two'})==nil,'occupied body reused')
 entry.card=nil
 advance(.5)
 assert(actor.undresses==1,'ready body was primed twice')
 local z,d=T.frame(race,entry.baseBounds,sex)
 local z2,d2=T.frame(race,{-20,-30,0,20,30,2},sex)
 assert(z==z2 and d==d2 and d>0,'gear breadth changed camera projection')
 cases=cases+1
end end
print('PASS: 16 race/sex cases: missing capture metadata, asynchronous load/undress, bounds, pool ownership')

local calls=0
-- This section isolates the legacy wait-list notification; full readiness-to-
-- dressing scheduling is exercised with renderer widgets in portrait_loading.py.
local prepareImmediate=T.P.PrepareImmediate
T.P.PrepareImmediate=function() return false end
DP.WorldPvP.ApplyOpponentPortrait=function(card, identity)
 assert(card.enemy==identity); calls=calls+1
end
local saved={raceFile='Dwarf',sex=2,portraitAppearance={slotCount=5}}
local row={enemy=saved,_portraitViewportActive=true}
T.pool.byKey['3:2'][1].ready=false
T.P.WaitForBody(row,saved); T.refresh(); advance(.02)
assert(calls==0 and T.waiting[row],'pending body retried too early')
T.pool.byKey['3:2'][1].ready=true
T.refresh(); T.refresh(); advance(.02)
assert(calls==1 and not T.waiting[row],'fallback did not upgrade when body became ready')
T.P.WaitForBody(row,saved); row._portraitViewportActive=false
T.refresh(); advance(.02); assert(calls==1 and not T.waiting[row])
row._portraitViewportActive=true; T.P.WaitForBody(row,saved); row.enemy={}
T.refresh(); advance(.02); assert(calls==1 and not T.waiting[row])
print('PASS: fallback upgrades once; hidden/recycled rows never refresh')
T.P.PrepareImmediate=prepareImmediate

local actor={outfit={},seen={}}
function actor:Undress() self.outfit={} end
function actor:TryOn(id) self.seen[#self.seen+1]=id; self.outfit[id]=true end
function actor:GetItemModifiedAppearanceID(slot) return self.expected[slot] end
local first={appearances={[3]=111,[5]=222,[1]=444},visible={[1]=false}}
actor.expected=first.appearances
local _,_,attempted,verified,expected,failed=T.dress(actor,first,{0,0,0,1,1,2})
assert(attempted==2 and verified==2 and expected==2 and failed==0)
assert(actor.outfit[111] and actor.outfit[222] and not actor.outfit[444])
local second={appearances={[3]=333}}; actor.expected=second.appearances
T.dress(actor,second,{0,0,0,1,1,2})
assert(actor.outfit[333] and not actor.outfit[111] and not actor.outfit[222])
print('PASS: different outfits remain distinct; hidden helm skipped; old gear cleared on reuse')

-- Regressions from the supplied encounter: one snapshot lacks race/sex fields,
-- but the enclosing identity contains them. Both dwarves have different outfits.
local fixtures={
 {raceFile='Dwarf',portraitSex=2,portraitAppearance={slotCount=5,
  appearances={[15]=160532,[3]=157700,[4]=157755,[5]=159432,[19]=158293}}},
 {raceFile='Dwarf',portraitSex=2,portraitAppearance={raceID=3,sex=2,slotCount=5,
  appearances={[1]=164515,[3]=164517,[4]=159766,[5]=165172,[19]=158293}}},
 {raceFile='NightElf',portraitSex=3,portraitAppearance={raceID=4,sex=3,slotCount=3,
  appearances={[5]=163145,[19]=158293,[3]=164981}}}
}
for _,identity in ipairs(fixtures) do
 local r,s=T.resolve(identity,identity.portraitAppearance)
 assert(r and s)
 actor.expected=identity.portraitAppearance.appearances
 local _,_,n,v,e,f=T.dress(actor,identity.portraitAppearance,{0,0,0,1,1,2})
 assert(n==identity.portraitAppearance.slotCount and n==v and v==e and f==0)
end
assert(fixtures[1].portraitAppearance.appearances[3]~=fixtures[2].portraitAppearance.appearances[3])
print('PASS: all three screenshot encounter outfit fixtures resolve and dress separately')

local identity={portraitFrozen=true}
local model={_rivalsPortraitPending={identity=identity,unit='target',guid='saved',allowFrozen=true}}
function model:IsGeoReady() return true end
function model:GetItemModifiedAppearanceID(slot) if slot==3 then return 123 end end
UnitGUID=function() return nil end
assert(T.capture(model) and identity.portraitAppearance.appearances[3]==123)
local saved=identity.portraitAppearance
UnitGUID=function() return 'replacement' end
assert(not T.capture(model) and identity.portraitAppearance==saved)
print('PASS: frozen encounter capture survives disappearing unit; reused unit GUID is rejected')

local made, finished=0,0
local function probe()
 local m={zoom=0}
 function m:RefreshCamera() self.zoom=0 end
 function m:SetPortraitZoom(z) self.zoom=z end
 function m:MakeCurrentCameraCustom() self.custom=true end
 function m:GetCameraTarget() assert(self.custom); return .2,0,self.zoom==1 and 1.91 or 1.1 end
 function m:GetModelFileID() return self.fileID end
 function m:SetModel(id) self.fileID=id end
 function m:ClearModel() self.fileID=nil; self.cleared=true end
 function m:Hide() self.hidden=true end
 return m
end
local p=probe(); assert(T.native(p)[3]==1.91)
p.GetCameraTarget=function() return 0,0,0 end
assert(T.native(p)==nil,'default camera accepted as head focus')
p.GetCameraTarget=function() return 0,0,1.2 end
assert(T.native(p)==nil,'unchanged full-body camera accepted as portrait camera')
local last
CreateFrame=function() made=made+1; last=probe(); return last end
local a={GetModelFileID=function() return 123456 end}
local t,pending=T.requestNative(a,function() finished=finished+1 end)
assert(not t and pending)
T.requestNative(a,function() finished=finished+1 end)
advance(.11)
assert(made==1 and finished==2 and last.hidden and last.cleared,'probe duplicated or leaked')
t,pending=T.requestNative(a,function() error('cached read should not subscribe') end)
assert(t[3]==1.91 and not pending and made==1)
CreateFrame=function()
 made=made+1; last=probe(); last.GetCameraTarget=function() return 0,0,0 end; return last
end
a.GetModelFileID=function() return 999 end
T.requestNative(a,function() finished=finished+1 end)
advance(1.1)
assert(finished==3 and last.cleared and last.hidden,'unsupported read left body pending forever')
t,pending=T.requestNative(a,function() error('failed probe should be cached') end)
assert(not t and not pending and made==2)
CreateFrame=nil

local camera={SetTarget=function(self,x,y,z) self.target={x,y,z} end}
local scene={GetActiveCamera=function() return camera end}
local actor={_rivalsBaseBounds={-.5,-.5,0,.5,.5,2},_rivalsNativePortraitTarget={.2,0,1.91}}
function actor:SetScale(s) self.scale=s end
function actor:SetUseCenterForOrigin(v) self.center=v end
T.camera(scene,actor)
assert(camera.target[3]==1.91 and scene._rivalsFraming=='native-portrait-target')
assert(math.abs(camera.target[1]-.2*math.cos(math.rad(22)))<.00001)
assert(math.abs(camera.target[2]-.2*math.sin(math.rad(22)))<.00001)
assert(actor.scale==1 and actor.center==false)
function camera:GetTarget() return unpack(self.target) end
function camera:GetRightVector() return 0,1,0 end
local card={_rivalsTest=true,portraitScene=scene,portraitActor=actor}
local baseX,baseY=camera.target[1],camera.target[2]
local ok,moved=T.P.AdjustTestCamera(card,.1,1,.25)
assert(ok and math.abs(moved.targetX-baseX)<.00001 and math.abs(moved.targetY-(baseY-.25))<.00001)
assert(math.abs(moved.targetZ-2.01)<.00001 and moved.horizontal==.25)
ok,moved=T.P.AdjustTestCamera(card,0,1,0)
assert(ok and math.abs(moved.targetY-baseY)<.00001,'reset accumulated horizontal movement')
assert(not T.P.AdjustTestCamera({portraitScene=scene,portraitActor=actor},0,1,.25),'production card was adjusted')
print('PASS: native focus replaces guessed height; yaw transform; default/unchanged cameras rejected; shared probes release and time out')

RivalsDB={}
T.pool.byKey['1:2']={}
T.pool.byKey['4:3']={{actor={IsLoaded=function() return false end},scene={},_cameraWaiting=true}}
T.P.SaveCameraReport('PLAYER_LOGOUT')
local report=RivalsDB.portraitCameraReport
assert(report.event=='PLAYER_LOGOUT' and report.entries['1:2'].count==0)
assert(report.entries['4:3'].ready==0 and report.entries['4:3'].waiting==1)
assert(report.entries['4:3'].loaded=='false')
local count=0; for _ in pairs(report.entries) do count=count+1 end
assert(count==16,'failure report must cover absent as well as initialized bodies')
print('PASS: reload report survives empty caches and unfinished model/camera initialization')
''')

world = (ROOT / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
apply = world[world.index('local function HidePortraitSpinner('):world.index('-- Only rows that are materially visible')]
lua.execute('''
W={}; reconstructed=false; preloads=0
DP.Portraits={ResetCard=function() end,
 CacheKey=function(enemy) return tostring(enemy.name or 'enemy')..'#portrait' end,
 IsPrepared=function() return reconstructed end,
 ApplyPrepared=function(card, enemy)
  if not reconstructed then return false end
  card._portraitLoading=nil; card.portraitSpinnerFrame:Hide(); return true
 end,
 PrepareImmediate=function(enemy) preloads=preloads+1; assert(enemy.portraitAppearance); return true end}
function widget()
 local methods={Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end,
  IsShown=function(self) return self.shown==true end}
 return setmetatable({}, {__index=function(_,key)
  return methods[key] or (key:match('^[A-Z]') and function() end)
 end})
end
''' + apply + '''
local enemy={name='Saved',portraitAppearance={slotCount=5}}
local row={enemy=enemy,portrait=widget(),portraitModel=widget(),portraitSpinnerFrame=widget()}
W.ApplyOpponentPortrait(row,enemy)
assert(preloads>0 and row._portraitLoading and row._portraitCommittedKey)
local before=preloads
reconstructed=true
W.ApplyOpponentPortrait(row,enemy)
assert(preloads==before and not row._portraitLoading and not row._portraitFallback)
local row2={enemy=enemy,portrait=widget(),portraitModel=widget(),portraitSpinnerFrame=widget()}
W.ApplyOpponentPortrait(row2,enemy)
assert(preloads==before and not row2._portraitFallback)
print('PASS: saved portrait shows loading state, upgrades in place, and reuses prepared cache on reopen')
''')
print('PASS: all runtime Lua files compile under Lua 5.1')

# The accepted in-game values are independent fixtures, not recomputed profiles.
import json
for key, expected in json.loads((ROOT/'tests'/'portrait_calibration.json').read_text()).items():
    race, sex = map(int,key.split(':'))
    actual=lua.execute("""
      local race,sex=...
      local camera={SetTarget=function(self,x,y,z) self.x,self.y,self.z=x,y,z end,
                    SetZoomDistance=function(self,d) self.distance=d end}
      local scene={_rivalsRaceID=race,_rivalsSex=sex,GetActiveCamera=function() return camera end}
      local actor={_rivalsBaseBounds={-20,-20,-1,20,20,50},_rivalsNativePortraitTarget={5,5,5}}
      T.camera(scene,actor)
      assert(scene._rivalsFraming=='calibrated-race-sex')
      return camera.x,camera.y,camera.z,camera.distance
    """,race,sex)
    assert all(abs(a-b)<1e-12 for a,b in zip(actual,expected)), key
print('PASS: all 16 accepted cameras reproduce saved XYZ/distance despite different donor bounds')
from PIL import Image
cover=Image.open(ROOT/'Textures'/'PortraitRoundCover_v2.tga')
# 56px overlay, 46px model viewport: square corners are at center +/- 23px.
alpha=cover.getchannel('A')
for x in (10,101):
    for y in (10,101): assert alpha.getpixel((x,y))>=250
assert alpha.getpixel((56,56))==0
assert alpha.getpixel((0,0))==0
print('PASS: circular cover hides all four model corners and leaves center/outside transparent')

import math
old_pixels_per_unit=35/(2*math.tan(.30/2))
new_fov=2*math.atan((46/35)*math.tan(.30/2))
assert abs(46/(2*math.tan(new_fov/2))-old_pixels_per_unit)<1e-10
assert '2 * math.atan((46 / 35) * math.tan(.30 / 2))' in source
print('PASS: expanded viewport retains calibrated on-screen magnification')

# Previously cropped pixels near the top/left/right are now inside the opening.
for point in ((56,19),(19,56),(92,56),(56,92)):
    assert alpha.getpixel(point)<5, ('opening remains inset',point)
print('PASS: enlarged opening exposes former top/side crop band')

for point in ((56,14),(14,56),(97,56),(56,97)):
    assert alpha.getpixel(point)<5, ('native portrait opening obstructed',point)
print('PASS: opening clears the 44px opening at top and sides')

# The 1px inset puts the AA transition beneath the rim. Check the diagonals
# where shoulder/ear spill was reported, not only the renderer's four corners.
for degrees in range(0,360,5):
    angle=math.radians(degrees)
    x=round(56+23*2*math.cos(angle))
    y=round(56+23*2*math.sin(angle))
    assert alpha.getpixel((x,y))>=250, ('rim spill',degrees)
print('PASS: opaque rim overlap at all 72 perimeter samples, including bottom-right')
