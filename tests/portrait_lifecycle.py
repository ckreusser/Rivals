from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in root.glob('*.lua'):
    lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8-sig'))
source = (root/'Portraits.lua').read_text(encoding='utf-8-sig')
conceal = source[source.index('local function ConcealCaptureModel('):source.index('local function NewCaptureModel(')]
lua.execute('''
UIParent={}; reads=0
local function Call(o,m,...) if o[m] then return o[m](o,...) end end
local function ReadCapture() reads=reads+1 end
'''+conceal+'''
local model={}
function model:SetClampedToScreen(v) self.clamped=v end
function model:SetAlpha(v) self.alpha=v end
function model:SetModelAlpha(v) self.modelAlpha=v end
function model:EnableMouse(v) self.mouse=v end
function model:ClearAllPoints() self.point=nil end
function model:SetPoint(...) self.point={...} end
function model:SetSize() end
function model:Hide() end
function model:SetKeepModelOnHide() end
function model:SetScript(_,fn) self.loaded=fn end
ConfigureCaptureModel(model)
assert(model.point[1]=='TOPRIGHT' and model.point[3]=='BOTTOMLEFT')
assert(model.point[4]<-64 and model.point[5]<-64 and not model.clamped)
assert(model.alpha==0 and model.modelAlpha==0 and not model.mouse)
model.alpha=1; model.modelAlpha=1; model.loaded(model)
assert(model.alpha==0 and model.modelAlpha==0 and reads==1)
print('PASS: capture viewport off-screen, renderer alpha cleared and model-load capture preserved')
''')
release = source[source.index('local function ReleaseBodyEntry('):source.index('P.ReleaseBody = ReleaseBodyEntry')]
apply = source[source.index('local function ApplyActor('):source.index('local function ApplyLegacyDressUp(')]
lua.execute('''
RefreshWaitingBodyCards=function() end
P={ReleaseWanted=function() end}; queue={}; dressCount=0; revealCount=0; parked=0
scene={SetAlpha=function(self,a) self.alpha=a; if a==1 then revealCount=revealCount+1 end end,
 SetPaused=function(self,p) assert(p==true); self.paused=p end, Show=function() end}
actor={SetOnModelLoadedCallback=function(self,f) self.callback=f end}
entry={scene=scene,actor=actor,baseBounds={1,2,3,4,5,6}}
GetTime=function() return 0 end
ParkBodyEntry=function() parked=parked+1 end
FindBodyDonors=function() end
AcquireBodyEntry=function(card)
 entry.card=card; card._portraitBodyEntry=entry; card.portraitScene=scene; card.portraitActor=actor
 return scene,actor,entry
end
FrameActorPortrait=function() end
FreezeActorPortrait=function(a,s) s:SetPaused(true,false) end
DressActor=function() dressCount=dressCount+1; return 'verified','',4,4,4,0 end
C_Timer={After=function(delay,fn) queue[#queue+1]={delay,fn} end}
'''+release+'\n'+apply+'''
P.release=ReleaseBodyEntry; P.apply=ApplyActor
''')
lua.execute('''
local card={_rivalsUsePortraitBodyPool=true}
assert(P.apply(card,{}, {},1,2)); assert(dressCount==1 and revealCount==0)
queue[1][2](); queue[2][2](); assert(revealCount==0 and scene.paused)
queue[3][2](); assert(dressCount==1 and revealCount==1)
queue={}; assert(P.apply(card,{}, {},1,2))
local stale=queue
P.release(card)
assert(not entry.card and not card.portraitScene and parked==1 and actor.callback==nil)
local second={_rivalsUsePortraitBodyPool=true}
queue={}; assert(P.apply(second,{}, {},1,2))
local beforeDress,beforeReveal=dressCount,revealCount
for _,cb in ipairs(stale) do cb[2]() end
assert(dressCount==beforeDress and revealCount==beforeReveal,'released callbacks touched reused actor')
queue[1][2](); queue[2][2](); queue[3][2](); assert(revealCount==beforeReveal+1)
local beforePark=parked
card._portraitBodyEntry=entry
assert(not P.release(card) and parked==beforePark and entry.card==second,'stale card parked another lease')
P.release(second)
for i=1,100 do
 local row={_rivalsUsePortraitBodyPool=true}; queue={}
 assert(P.apply(row,{}, {},1,2)); P.release(row)
 for _,cb in ipairs(queue) do cb[2]() end
 assert(not entry.card and not row._portraitBodyEntry)
end
print('PASS: quiet-interval reveal; no post-reveal redress; stale callback cancellation; ownership guard; 100 acquire/release cycles')
''')
print('PASS: all active runtime Lua files compile under Lua 5.1')
