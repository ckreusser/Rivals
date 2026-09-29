"""Exercise the real smooth-scroll controller against encounter resets."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
start = source.index('local function Clamp(value, low, high)')
end = source.index('local function DetailTooltip(', start)
lua = LuaRuntime()
lua.execute(source[start:end] + '''
local scroll={offset=0,scripts={}}
function scroll:GetHeight() return 300 end
function scroll:GetVerticalScroll() return self.offset end
function scroll:SetVerticalScroll(v) self.offset=v end
function scroll:SetScript(k,fn) self.scripts[k]=fn end
function scroll:EnableMouseWheel() end
local body={height=10000}
function body:GetHeight() return self.height end
ConfigureSmoothWheelScroll(scroll,body,30)
local function settle()
 for i=1,200 do if scroll.scripts.OnUpdate then scroll.scripts.OnUpdate(scroll,.016) end end
end
scroll:ScrollTo(9000);settle();assert(scroll.offset==9000)
-- An external reset must not let an idle destination govern the next tick.
scroll:SetVerticalScroll(0)
scroll:ScrollByWheel(-1);settle();assert(scroll.offset==30)
-- Also cancel an in-flight animation when switching encounters.
scroll:ScrollTo(8500);scroll.scripts.OnUpdate(scroll,.016)
scroll:ResetScroll(0)
assert(not scroll.smoothScrolling and not scroll.scripts.OnUpdate and scroll.smoothTarget==0)
scroll:ScrollByWheel(-1);settle();assert(scroll.offset==30)
-- Consecutive ticks accumulate while an animation is genuinely in progress.
scroll:ScrollByWheel(-1);scroll:ScrollByWheel(-1);settle();assert(scroll.offset==90)
scroll:ScrollByWheel(1);settle();assert(scroll.offset==60)
body.height=310;scroll:ScrollByWheel(-1);settle();assert(scroll.offset==10)
scroll:ResetScroll(0);scroll:ScrollByWheel(1);settle();assert(scroll.offset==0)
print('PASS: stale destination, in-flight encounter reset, one-tick distance, rapid ticks, and range limits')
''')
assert 'window.logScroll:ResetScroll(0)' in source
