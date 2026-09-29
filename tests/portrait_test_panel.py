"""Exercise the real test-panel controller without claiming rendered UI validation."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
buttons={}; resets=0; applied=0; available=true; shown=true
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetText(t) self.text=t end
function methods:SetSize(w,h) self.w,self.h=w,h end
function methods:SetScale(s) self.scale=s end
function methods:SetPoint(...) self.point={...} end
function methods:GetFrameLevel() return 1 end
function methods:IsShown() return self.shown~=false end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:CreateTexture() return CreateFrame() end
function methods:CreateFontString() return CreateFrame() end
function CreateFrame(kind,name,parent)
 local f=setmetatable({scripts={},parent=parent}, {__index=function(_,k)
  if methods[k] then return methods[k] end
  if k:match('^[A-Z]') then return function() end end
 end})
 if name then _G[name]=f end
 if kind=='Button' then buttons[#buttons+1]=f end
 return f
end
function click(text)
 for _,b in ipairs(buttons) do if b.text==text then b.scripts.OnClick(); return end end
 error('button missing: '..text)
end
function EnsureSavedPortraitCalibrations() end
UIParent=CreateFrame(); C_Timer={After=function(_,fn) fn() end}
local sample={name='fixture',race='Human',portraitSex=3,portraitAppearance={raceID=1,sex=3,slotCount=1,appearances={[3]=123}}}
RivalsDB={observers={one={worldPvP={encounters={{enemies={sample}}}}}}}
DP={Portraits={}}
P=DP.Portraits
function P.ResetCard(card) resets=resets+1; card.portraitScene=nil; card._rivalsPortraitReady=nil end
function P.TestBodyAvailable() return available end
function P.Apply(card,identity)
 applied=applied+1; assert(card._rivalsTest and card._rivalsUsePortraitBodyPool)
 assert(identity.portraitAppearance~=sample.portraitAppearance,'historical snapshot mutated')
 card.portraitScene={}; return true
end
function P.AdjustTestCamera(card,v,z,h,pitch,rotation)
 if not card.portraitScene then return false end
 return true,{baseZ=1,targetZ=1+v,vertical=v,horizontal=h,zoom=z,distance=z,framing='test',
  pitchDeltaDegrees=pitch or 0,rotationDeltaDegrees=rotation or 0,
  cameraPitchDegrees=-6+(pitch or 0),actorYawDegrees=22+(rotation or 0)}
end
function P.ObserveUnit() end
function P.AddPortraitCover(parent) return CreateFrame(nil,nil,parent) end
''')
source=(root/'Portraits.lua').read_text(encoding='utf-8')
source=source.split('-- BEGIN PORTRAIT TEST PANEL\n',1)[1].split('-- END PORTRAIT TEST PANEL',1)[0]
lua.execute(source, 'Rivals',lua.globals().DP)
lua.execute('''
P.OpenTest(); assert(applied==1)
click('Aim up'); click('Save result')
assert(RivalsDB.portraitTestResults['1:3'].vertical==.025)
click('Move right'); click('Save result'); assert(RivalsDB.portraitTestResults['1:3'].horizontal==.025)
click('Move left'); click('Move left'); click('Save result'); assert(RivalsDB.portraitTestResults['1:3'].horizontal==-.025)
click('Camera up'); click('Save result'); assert(RivalsDB.portraitTestResults['1:3'].pitchDeltaDegrees==-1)
click('Rotate right'); click('Save result'); assert(RivalsDB.portraitTestResults['1:3'].rotationDeltaDegrees==2)
assert(RivalsDB.observers.one.worldPvP.encounters[1].enemies[1].portraitAppearance.raceID==1)
click('Reset'); click('Save result'); assert(RivalsDB.portraitTestResults['1:3'].vertical==0)
assert(RivalsDB.portraitTestResults['1:3'].horizontal==0)
assert(RivalsDB.portraitTestResults['1:3'].pitchDeltaDegrees==0 and RivalsDB.portraitTestResults['1:3'].rotationDeltaDegrees==0)
available=false; click('Male'); local prior=applied
click('Save result'); assert(not RivalsDB.portraitTestResults['1:2'])
available=true; click('Retry'); assert(applied==prior+1)
local before=resets; RivalsPortraitTest:Hide(); assert(resets==before+1 and not RivalsPortraitTest.result)
P.OpenTest(); assert(RivalsPortraitTest:IsShown())
print('PASS: preview-only controls; immutable encounter; reset/save; unavailable-body handling; retry; close/reopen releases')
''')
