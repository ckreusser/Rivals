"""Portrait effects remain suppressed after dressing/reuse; Lua 5.1 mocks."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / 'Portraits.lua').read_text(encoding='utf-8-sig')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('DP={}; _G=_G or {}')
lua.globals().T = lua.execute(source + '''
return {hold=HoldActorPortrait, lighting=SetupPortraitLighting,
 suppress=SuppressPortraitEffects}
''', 'Rivals', lua.globals().DP)
lua.execute('''
local actor={particles=1,kit=123,animations=0}
function actor:SetParticleOverrideScale(v) self.particles=v end
function actor:SetSpellVisualKit(v) self.kit=v end
function actor:SetPaused(v) self.paused=v end
function actor:SetAnimation() self.animations=self.animations+1 end
local scene={_rivalsPortraitActor=actor}
function scene:HookScript(event,fn) assert(event=='OnUpdate'); self.update=fn end
function scene:IsShown() return true end
function scene:GetAlpha() return 1 end
function scene:SetPaused(v) self.paused=v end
T.hold(actor,scene)
assert(actor.particles==0 and actor.kit==0 and actor.paused and scene.paused)
T.lighting(scene)
-- Simulate an asynchronous equipment load restoring effects after preparation.
actor.particles=1; actor.kit=456; scene:update()
assert(actor.particles==0 and actor.kit==0)
assert(actor.animations==0,'visible effects guard reset the character pose')
local legacy={}
function legacy:SetParticlesEnabled(v) self.particles=v end
T.suppress(legacy); assert(legacy.particles==false)
T.suppress({}) -- Older clients lacking the methods remain supported.
T.suppress({SetParticleOverrideScale=function() error('unsupported') end})
''')
print('PASS: actor/legacy particles, visual kits, reuse and visible asynchronous restoration')
