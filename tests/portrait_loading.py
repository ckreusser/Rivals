"""Demand-loading regressions using real Lua 5.1 controller code and a fake renderer.

These tests exercise scheduling/ownership, not Blizzard streaming or rendered pixels.
"""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'Portraits.lua').read_text(encoding='utf-8-sig')
world = (ROOT / 'WorldPvP.lua').read_text(encoding='utf-8-sig')


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
DP={WorldPvP={}}; RivalsDB={}; now=0; tasks={}; loads=0; loadDelay=.6
units={player={sex=2,guid='self'}}
function GetTime() return now end
C_Timer={After=function(delay,fn) tasks[#tasks+1]={at=now+delay,fn=fn} end}
function advance(delta)
 local stop=now+delta
 while true do
  local selected
  for i,t in ipairs(tasks) do
   if t.at<=stop and (not selected or t.at<tasks[selected].at) then selected=i end
  end
  if not selected then break end
  local t=table.remove(tasks,selected); now=t.at; t.fn()
 end
 now=stop
end
function UnitExists(unit) return units[unit]~=nil end
function UnitIsPlayer() return true end
function UnitSex(unit) return units[unit] and units[unit].sex end
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitRace() return 'Human','Human',1 end
function identity(name,race,sex)
 return {guid=name,name=name,class='WARRIOR',portraitAppearance={raceID=race or 1,sex=sex or 2,
  slotCount=1,appearances={[1]=123}}}
end
function widget()
 local methods={}
 function methods:IsShown() return self.shown~=false end
 function methods:Show() self.shown=true end
 function methods:Hide() self.shown=false end
 function methods:SetAlpha(a) self.alpha=a end
 function methods:SetParent(p) self.parent=p end
 function methods:GetFrameLevel() return 1 end
 return setmetatable({shown=true},{__index=function(_,key) return methods[key] or (key:match("^[A-Z]") and function() end) end})
end
function card(enemy)
 return {enemy=enemy,portrait=widget(),portraitModel=widget(),portraitSpinnerFrame=widget(),
  _portraitViewportActive=true,IsShown=function() return true end}
end
''')
    lua.execute(source + '''
-- Mock only rendering. The real pool, prime watchdog, reservations, dressing,
-- attachment, cancellation, and timer code all run unchanged.
CreateFrame=function() return widget() end
UIParent=widget()
EnsurePortraitScene=function()
 local scene=widget()
 local actor={outfit={}}
 function actor:SetModelByUnit()
  loads=loads+1
  if rejectBinding then return false end
  self.loadedAt=now+loadDelay
  return true
 end
 function actor:SetModelByCreatureDisplayID(id,customizations)
  assert(customizations==false,'textured displays must retain their own skin')
  loads=loads+1
  if rejectDisplayBinding then return false end
  self.displayID=id; self.loadedAt=now+(displayLoadDelay or loadDelay)
  return true
 end
 function actor:IsLoaded() return now>=self.loadedAt end
 function actor:SetOnModelLoadedCallback(fn) self.callback=fn end
 function actor:Undress() self.outfit={} end
 function actor:TryOn(id) if not ignoreTryOn then self.outfit[1]=id end end
 function actor:GetItemModifiedAppearanceID(slot) return self.outfit[slot] end
 function actor:GetActiveBoundingBox() return -.4,-.3,0,.4,.3,2 end
 function actor:SetPaused(paused) self.paused=paused end
 function actor:SetAnimation() self.poses=(self.poses or 0)+1 end
 return scene,actor
end
FrameActorPortrait=function() end
T={P=P,pool=bodyPool,prime=ScheduleBodyPrime}
function activeCount()
 local count=0
 for _,entry in ipairs(bodyPool.entries) do if entry._primeGeneration then count=count+1 end end
 return count
end
''', 'Rivals', lua.globals().DP)
    return lua


for race, displays in enumerate([(1294, 3292), (1374, 1360), (3053, 1286), (1706, 1937), (1599, 1592), (2103, 3820), (3055, 3108), (4242, 4231)],1):
    for sex, display in zip((2,3),displays):
        lua = runtime()
        lua.execute(f'''
units.player.sex={5-sex}
local enemy=identity('opposite-sex-first-click',{race},{sex}); local row=card(enemy)
T.P.WantPrepared(row,enemy);T.P.PrepareImmediate(enemy,true)
assert(loads==1 and #T.pool.entries==1)
assert(T.pool.entries[1].actor.displayID==T.P.BodyDisplay(enemy,{race},{sex}))
advance(.9)
assert(T.P.IsPrepared(enemy),'direct race/sex request did not prepare')
assert(T.P.ApplyPrepared(row,enemy));advance(.1)
assert(row.portraitScene.alpha==1 and row.portraitActor.outfit[1]==123)
''')
print('PASS: all 16 race/sex requests prepare and reveal saved gear without a matching-sex unit')

fixture = json.loads((ROOT / 'tests/portrait_body_displays.json').read_text())
lua = runtime()
for race in range(1,9):
    for sex in (2,3):
        rows = [r for r in fixture['bodies'] if r['race']==race and r['sex']==sex]
        assert len(rows)==8 and len({tuple(r['features']) for r in rows})==8
        assert all(r['extraID']>0 and r['texture'] for r in rows)
        assert len({r['modelID'] for r in rows})==1
        chosen=set()
        for i in range(64):
            ident=lua.table_from({'guid':f'Player-5066-{i:08X}'})
            chosen.add(lua.globals().T.P.BodyDisplay(ident,race,sex))
        assert chosen=={r['displayID'] for r in rows}
print('PASS: 128 skinned displays match the source race/sex and provide eight distinct feature sets per pair')

lua = runtime()
lua.execute('''
local a=identity('Player-5066-00000001');local b
for i=2,32 do
 local candidate=identity('Player-5066-'..i)
 if T.P.BodyDisplay(candidate,1,2)~=T.P.BodyDisplay(a,1,2) then b=candidate;break end
end
assert(b)
local displayA,displayB=T.P.BodyDisplay(a,1,2),T.P.BodyDisplay(b,1,2)
local row=card(a)
T.P.WantPrepared(row,a);T.P.PrepareImmediate(a,true);advance(.9)
assert(T.P.ApplyPrepared(row,a));advance(.1)
assert(row.portraitActor.displayID==displayA)
T.P.ReleaseBody(row);row.enemy=b
T.P.WantPrepared(row,b);T.P.PrepareImmediate(b,true);advance(.9)
assert(T.P.ApplyPrepared(row,b));advance(.1)
assert(row.portraitActor.displayID==displayB and loads==2 and #T.pool.entries==1,
 'recycled actor retained previous face or allocated unrelated variants')
T.P.ReleaseBody(row);row.enemy=a
T.P.WantPrepared(row,a);T.P.PrepareImmediate(a,true);advance(.9)
assert(T.P.ApplyPrepared(row,a));advance(.1)
assert(row.portraitActor.displayID==displayA and loads==3)
local copy=identity(a.guid);copy.name='Renamed';copy.portraitAppearance.appearances[1]=999
assert(T.P.BodyDisplay(copy,1,2)==displayA,'name/outfit changed the same player face')
print('PASS: different players change recycled actor faces; revisits and new outfits retain stable features')
''')
other = runtime()
assert lua.globals().T.P.BodyDisplay(lua.table_from({'guid':'Player-5066-00000001'}),1,2) == other.globals().T.P.BodyDisplay(other.table_from({'guid':'Player-5066-00000001'}),1,2)
print('PASS: feature choice survives a fresh Lua session without donor or click-order dependence')

lua = runtime()
lua.execute('''
ignoreTryOn=true;units.player.sex=3
RivalsDB.portraitLoadTrace={version='1.0.88',events={{event='previous-failure'}}}
local enemy=identity('silent-rejection');local row=card(enemy)
T.P.WantPrepared(row,enemy);T.P.PrepareImmediate(enemy,true);advance(2)
assert(not T.P.IsPrepared(enemy) and not T.P.ApplyPrepared(row,enemy),
 'zero verified gear was exposed as a completed portrait')
for i=1,10 do T.P.PrepareImmediate(enemy,true);advance(.05) end
assert(loads==1 and #T.pool.entries==1,'rejected outfit allocated replacement actors')
assert(RivalsDB.portraitLoadTraceArchive[1].events[1].event=='previous-failure')
local failure
for _,event in ipairs(RivalsDB.portraitLoadTrace.events) do
 if event.event=='dress-failed' then failure=event end
 assert(event.event~='prepared' and event.event~='revealed')
end
assert(failure and failure.details.gear[1].expected==123 and not failure.details.gear[1].actual)
assert(failure.details.tryOn and not failure.details.setItemInfo)
-- Simulate Era's explicit-slot API accepting an outfit after numeric TryOn did nothing.
local actor=T.pool.entries[1].actor
function actor:SetItemTransmogInfo(info,slot) self.outfit[slot]=info.appearanceID;return 0 end
advance(2);T.P.PrepareImmediate(enemy,true);advance(.3)
assert(T.P.IsPrepared(enemy),'explicit slot API did not recover silent TryOn failure')
assert(T.P.ApplyPrepared(row,enemy));advance(.1)
assert(row.portraitScene.alpha==1 and loads==1)
print('PASS: silent gear rejection never reveals; bounded retry; slot API recovery; persistent failure evidence')
''')

lua = runtime()
lua.execute('''
rejectBinding=true
local enemy=identity('rejected-live-unit');local row=card(enemy)
units.player.guid=enemy.guid
T.P.WantPrepared(row,enemy);T.P.PrepareImmediate(enemy,true)
assert(loads==2 and #T.pool.entries==1 and T.pool.entries[1].bodySource=='display',
 'rejected live binding did not immediately use direct display on the same actor')
advance(.9);assert(T.P.IsPrepared(enemy))
print('PASS: live binding rejection immediately switches to direct display')
''')

lua = runtime()
lua.execute('''
loadDelay=10000;displayLoadDelay=.1
local enemy=identity('stalled-live-unit');local row=card(enemy)
units.player.guid=enemy.guid
T.P.WantPrepared(row,enemy);T.P.PrepareImmediate(enemy,true)
advance(8.5);T.P.PrepareImmediate(enemy,true);advance(.4)
assert(loads==2 and #T.pool.entries==1 and T.pool.entries[1].bodySource=='display')
assert(T.P.IsPrepared(enemy),'timed-out unit did not recover through independent display source')
print('PASS: stalled live binding recovers through direct display without allocating another actor')
''')

lua = runtime()
lua.execute('''
rejectBinding=true;rejectDisplayBinding=true
local enemy=identity('temporarily-unready'); local row=card(enemy)
T.P.WantPrepared(row,enemy); T.P.PrepareImmediate(enemy,true)
for i=1,20 do advance(.1);T.P.PrepareImmediate(enemy,true) end
assert(#T.pool.entries==1 and T.pool.entries[1].bindFailed,'rejected binding allocated replacement widgets')
assert(loads<10,'rejected binding was retried every spinner tick')
rejectBinding=false;rejectDisplayBinding=false;advance(1.1);T.P.PrepareImmediate(enemy,true);advance(.9)
assert(T.P.IsPrepared(enemy) and #T.pool.entries==1,'retained failed binding did not recover')
print('PASS: rejected model binding is throttled and recovers on the same widget')
''')

lua = runtime()
lua.execute('''
units.player.sex=3
units.nameplate47={sex=2,guid='brief-male'}
IsUnitModelReadyForUI=function() return false end -- advisory preflight must not block binding
C_NamePlate={GetNamePlates=function() return {{namePlateUnitToken='nameplate47'}} end}
T.P.DiscoverDonors()
assert(#T.pool.entries==0 and loads==0,'startup must not bind unrelated race models')
-- The briefly observed male is gone before the first History click.
units.nameplate47=nil; C_NamePlate.GetNamePlates=function() return {} end
advance(.7)
local dwarf=identity('male-dwarf',3,2); local row=card(dwarf)
T.P.WantPrepared(row,dwarf); T.P.PrepareImmediate(dwarf,true)
advance(.9)
assert(T.P.IsPrepared(dwarf),'a later male Dwarf still depended on another live male donor')
assert(activeCount()==1 and loads==1,'first click bound unrelated models')
assert(T.pool.entries[1].bodySource=='display' and T.pool.entries[1].actor.displayID==T.P.BodyDisplay(dwarf,3,2))
assert(T.P.ApplyPrepared(row,dwarf));advance(.09)
assert(row.portraitScene.alpha==1)
print('PASS: first male Dwarf click starts directly with only a female player available; no startup burst')
''')

lua = runtime()
lua.execute('''
local enemy=identity('selected',4)
local row=card(enemy)
T.P.WantPrepared(row,enemy)
T.P.ObserveUnit('player',4)
assert(loads==1 and activeCount()==1 and T.pool.entries[1].raceID==4,'donor observation did not serve the selected race first')
for i=1,40 do T.P.PrepareImmediate(enemy,true) end
assert(loads==1 and #T.pool.entries==1 and activeCount()==1,'retry activated unrelated templates')
assert(T.pool.entries[1].raceID==4,'foreground warmed unrelated races')
advance(.8) -- no OnModelLoaded callback is delivered
assert(T.pool.entries[1].ready,'missed callback stranded loaded actor')
assert(T.P.PrepareImmediate(enemy,true))
advance(.09)
assert(T.P.IsPrepared(enemy))
assert(T.P.ApplyPrepared(row,enemy))
assert(row.portraitScene.alpha==0,'attached actor revealed before settling')
advance(.09)
assert(row.portraitScene.alpha==1 and row.portraitActor.paused)
advance(8)
assert(loads==1 and activeCount()==1,'unselected templates activated while viewing History')
T.P.ReleaseBody(row); row._portraitViewportActive=false
assert(T.P.IsPrepared(enemy),'releasing lost prepared outfit')
local other=card(enemy); assert(T.P.ApplyPrepared(other,enemy)); advance(.09)
assert(loads==1 and activeCount()==1,'cache hit restarted model binding')
print('PASS: selected race only; 40 retries coalesce; lost callback recovered; hidden settle; warm cache hit')
''')

lua = runtime()
lua.execute('''
T.P.ObserveUnit('player',4)
assert(loads==0 and activeCount()==0,'donor observation must not load the catalog')
advance(10)
assert(activeCount()==0,'dormant templates activated without a request')
local enemy=identity('selected',8); local row=card(enemy)
T.P.WantPrepared(row,enemy); T.P.PrepareImmediate(enemy,true)
assert(loads==1 and activeCount()==1 and not T.pool.byKey['8:2'][1].dormant)
advance(5)
assert(activeCount()==1,'unselected templates activated alongside foreground')
print('PASS: observing players causes no model loads; only selected race activates')
''')

lua = runtime()
lua.execute('''
local a,b=identity('old'),identity('new')
b.guid=a.guid -- same player, different saved outfit
b.portraitAppearance.appearances[1]=456
local row=card(a)
T.P.WantPrepared(row,a); T.P.PrepareImmediate(a,true); advance(.8)
T.P.PrepareImmediate(a,true)
T.P.ReleaseBody(row); row.enemy=b
assert(not T.pool.entries[1].preparing,'abandoned hidden preparation was not cancelled')
T.P.WantPrepared(row,b); T.P.PrepareImmediate(b,true)
advance(.4)
assert(not T.P.IsPrepared(a) and T.P.IsPrepared(b),'stale dress callback overwrote new selection')
assert(loads==1 and T.pool.entries[1].actor.outfit[1]==456)
assert(T.P.ApplyPrepared(row,b))
T.P.ReleaseBody(row)
advance(.04)
assert(T.P.ApplyPrepared(row,b))
advance(.05)
assert(row.portraitScene.alpha==0,'old reveal callback exposed a new attachment early')
advance(.04)
assert(row.portraitScene.alpha==1 and row.portraitActor.outfit[1]==456)
print('PASS: rapid switch cancels abandoned dressing; release/reacquire preserves ownership')
''')

lua = runtime()
lua.execute('''
local a,b=identity('first'),identity('second')
local ca,cb=card(a),card(b)
T.P.WantPrepared(ca,a); T.P.PrepareImmediate(a,true); advance(.8)
T.P.PrepareImmediate(a,true)
T.P.WantPrepared(cb,b); T.P.PrepareImmediate(b,true)
assert(loads==2,'second visible same-race card needs its own body')
advance(.8); T.P.PrepareImmediate(b,true); advance(.1)
assert(T.P.IsPrepared(a) and T.P.IsPrepared(b),'visible request was evicted')
assert(T.P.ApplyPrepared(ca,a) and T.P.ApplyPrepared(cb,b))
assert(ca._portraitBodyEntry~=cb._portraitBodyEntry)
print('PASS: simultaneous visible same-race cards retain distinct protected outfits')
''')

lua = runtime()
lua.execute('''
loadDelay=10000
local enemy=identity('slow'); local row=card(enemy)
T.P.WantPrepared(row,enemy); T.P.PrepareImmediate(enemy,true)
advance(8.5); T.P.PrepareImmediate(enemy,true)
assert(loads==2,'timed-out widget did not get one recovery attempt')
advance(9)
for i=1,100 do T.P.PrepareImmediate(enemy,true); advance(.1) end
assert(loads==2 and #T.pool.entries==1,'stalled renderer grew an unbounded pool')
T.pool.entries[1].actor.loadedAt=now
T.P.PrepareImmediate(enemy,true); advance(.1); T.P.PrepareImmediate(enemy,true); advance(.1)
assert(T.P.IsPrepared(enemy),'late readiness after watchdog timeout was lost')
print('PASS: bounded stalled-load recovery; no retry allocation storm; late readiness remains recoverable')
''')

lua = runtime()
lua.execute('''
loadDelay=10000
T.P.ObserveUnit('player'); advance(20)
assert(loads==0 and activeCount()==0,'observation loaded unrelated templates')
local enemy=identity('foreground',8); local row=card(enemy)
T.P.WantPrepared(row,enemy); T.P.PrepareImmediate(enemy,true)
assert(loads==1 and activeCount()==1,'foreground did not start its own body')
print('PASS: slow dormant templates do not block selected activation')
''')

lua = runtime()
lua.execute('''
local enemy=identity('female',4,3); local row=card(enemy)
T.P.WantPrepared(row,enemy); T.P.PrepareImmediate(enemy,true)
assert(loads==1 and T.pool.entries[1].bodySource=='display','missing donor did not start a direct load')
units.target={sex=3,guid='donor'}
T.P.ObserveUnit('target'); T.P.PrepareImmediate(enemy,true)
assert(loads==1 and activeCount()==1 and T.pool.entries[1].sex==3,'new donor restarted an active direct load')
for i=1,200 do T.P.TraceLoad('test','key') end
assert(#RivalsDB.portraitLoadTrace.events==120)
print('PASS: absent donor starts direct load; subsequent donor does not restart it; diagnostics bounded')
''')

# Exercise the real visible-row and spinner controller independently of window construction.
lua = runtime()
start = world.index('local function HidePortraitSpinner(')
end = world.index('function W.SetSummaryCardPortraitMode(', start)
lua.execute('W=DP.WorldPvP; window=nil; CLASS_ICON_TCOORDS={WARRIOR={0,1,0,1}}')
lua.execute(world[start:end])
lua.execute('''
loadDelay=10000
local enemy=identity('stall'); local row=card(enemy)
W.ApplyOpponentPortrait(row,enemy)
assert(row._portraitLoading and not row.portrait:IsShown() and row.portraitSpinnerFrame:IsShown(),
 'saved portrait must show only the spinner immediately')
advance(3.2)
assert(row._portraitLoading and not row._portraitTemporaryFallback and not row.portrait:IsShown())
assert(row.portraitSpinnerFrame:IsShown(),'spinner disappeared while portrait was still loading')
T.pool.entries[1].actor.loadedAt=now
advance(1.5)
assert(row._portraitReconstructed and row.portraitScene.alpha==1)
assert(not row.portrait:IsShown(),'placeholder remained above reconstructed portrait')
assert(loads==1,'attaching restarted model loading during reveal delay')
local before=loads
T.P.ReleaseBody(row); row._portraitViewportActive=false; advance(5)
assert(loads==before,'released card kept retrying')
print('PASS: spinner only, no timed icon replacement; automatic reveal; release stops retry loop')

loadDelay=.1
local original=identity('callback',3)
local copy=identity('callback',3)
local shown=card(copy)
window={summaryRivalCards={shown},IsShown=function() return true end}
W.ApplyOpponentPortrait(shown,copy)
advance(.4)
T.P.PrepareImmediate(original,true)
advance(.4)
assert(shown._portraitReconstructed and shown.portraitScene.alpha==1,
 'prepared callback failed to match equivalent saved identity by cache key')
T.P.ReleaseBody(shown); shown._portraitViewportActive=false
print('PASS: completion callback matches cache keys across distinct identity tables')

local requested,released={},{}
W.ApplyOpponentPortrait=function(c,e) requested[#requested+1]=e.guid; c._portraitViewportActive=true; c._portraitCommittedKey=T.P.CacheKey(e) end
DP.Portraits.ReleaseBody=function(c) released[#released+1]=c.enemy.guid end
local detail={summaryRivalCards={},activeTab='summary'}
detail.summaryRivalsScroll={GetVerticalScroll=function() return 0 end,GetHeight=function() return 196 end}
for i=1,100 do
 local c=card(identity(tostring(i))); c.kind='player'; c._portraitViewportActive=false
 c.summaryRowTop=8+(i-1)*47; c.GetHeight=function() return 47 end
 detail.summaryRivalCards[i]=c
end
W.RefreshVisibleOpponentPortraits(detail)
assert(#requested==4,'off-screen rows requested portraits')
detail.summaryRivalsScroll.GetVerticalScroll=function() return 470 end
W.RefreshVisibleOpponentPortraits(detail)
assert(#released==4 and #requested==8)
W.ApplyOpponentPortrait=function(c,e)
 assert(#released>=8,'upward scroll requested rows before releasing outgoing leases')
 requested[#requested+1]=e.guid; c._portraitViewportActive=true; c._portraitCommittedKey=T.P.CacheKey(e)
end
detail.summaryRivalsScroll.GetVerticalScroll=function() return 0 end
W.RefreshVisibleOpponentPortraits(detail)
assert(#released==8 and #requested==12)
detail.activeTab='log'; W.RefreshVisibleOpponentPortraits(detail)
assert(#released==12,'hidden Summary retained visible leases')
print('PASS: 100 opponents request only four visible portraits; scroll/tab changes release leases')
''')

for path in ROOT.glob('*.lua'):
    lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8-sig'))
print('PASS: all runtime files compile under Lua 5.1')
