"""Focused regression suite; requires lupa's Lua 5.1 runtime."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('DP={}; function loadAddon(s) assert(loadstring(s))("Rivals",DP) end')
for name in ("Parser", "Tracker", "UsageCatalog", "Specs", "Usage", "Rating",
             "Verification", "Recovery", "Periods", "Theme", "WorldPvP", "Views",
             "Promos", "CharacterTab", "Inspect", "Tooltip"):
    lua.globals().loadAddon((root / (name + ".lua")).read_text(encoding="utf-8"))
for name in ("spec", "specs", "usage", "wow_mock"):
    lua.execute((root / "tests" / (name + ".lua")).read_text(encoding="utf-8"))
lua.globals().loadAddon((root / "Core.lua").read_text(encoding="utf-8"))
lua.execute('fire("PLAYER_LOGIN")')
# Reuse the existing UI mock and panel installation independently of older
# unrelated history/leaderboard assertions later in that contract suite.
setup = (root / "tests" / "character_tab.lua").read_text(encoding="utf-8")
lua.execute(setup.split('assert(CharacterFrame.numTabs == 5,')[0])
lua.execute((root / "tests" / "encounter_fixes.lua").read_text(encoding="utf-8"))

# Exercise the production hover helper without constructing an entire detail
# window in the limited UI mock.
world = (root / "WorldPvP.lua").read_text(encoding="utf-8")
hover = world.split("local function SetSummaryCardHitArea(card, expanded)", 1)[1]
hover = "local function SetSummaryCardHitArea(card, expanded)" + hover.split("local function EnsureSummaryRivalCard", 1)[0]
lua.globals().testSummaryHover = lua.execute(
    "local W=DP.WorldPvP; local function Clamp(x,a,b) return math.max(a,math.min(b,x)) end\n"
    + hover + "\nreturn SetSummaryCardLift"
)
smooth = world.split("local function ConfigureSmoothWheelScroll", 1)[1]
smooth = "local function ConfigureSmoothWheelScroll" + smooth.split("local function DetailTooltip", 1)[0]
lua.globals().testConfigureScroll = lua.execute(
    "local function Clamp(x,a,b) return math.max(a,math.min(b,x)) end\n"
    + smooth + "\nreturn ConfigureSmoothWheelScroll"
)
lua.execute('''
local W=DP.WorldPvP
local old=W.details
local scroll=CreateFrame(); scroll:SetSize(352,196); scroll.offset=0
function scroll:GetVerticalScroll() return self.offset end
function scroll:SetVerticalScroll(n) self.offset=n end
local body=CreateFrame(); body:SetSize(352,236)
testConfigureScroll(scroll,body,30)
W.details={summaryRivalsScroll=scroll,summaryRivalsBody=body}
local card=CreateFrame(); card:SetSize(330,47); card.summaryRowTop=174
function card:GetScript(event) return self.scripts[event] end
card.visual=CreateFrame(); card.visual:SetParent(card)
card.content=CreateFrame(); card.name=CreateFrame(); card.status=CreateFrame(); card.record=CreateFrame()
card.border=CreateFrame(); card.bg=CreateFrame()
testSummaryHover(card,true)
assert(scroll.offset==0 and scroll.smoothTarget==33, "reveal must not jump")
scroll.scripts.OnUpdate(scroll,.05)
assert(scroll.offset>0 and scroll.offset<33, "list must visibly travel upward")
for i=1,20 do if scroll.scripts.OnUpdate then scroll.scripts.OnUpdate(scroll,.05) end end
assert(scroll.offset==33)
card.scripts.OnUpdate(card,.0225)
assert(math.abs(card._hoverProgress-.5)<.00001, "hover reaches half progress in 22.5ms")
card.scripts.OnUpdate(card,.0225)
assert(card.visual.parent==card and card.visual.scale==nil)
assert(card.content.scale==1 and card.visual:GetWidth()==330)
assert(card.visual.point[1]=="TOPRIGHT" and card.visual.point[3]=="TOPRIGHT", "hover must keep the right edge locked")
assert(math.abs(card.portraitFrame.scale-1.035)<.00001, "portrait supplies the hover lift without resizing the plaque")
assert(card.summaryRowTop+card:GetHeight()+8-scroll.offset<=scroll:GetHeight())
testSummaryHover(card,false); card.scripts.OnUpdate(card,.2)
assert(card.visual:GetWidth()==330 and card.content.scale==1 and card.portraitFrame.scale==1 and not card.scripts.OnUpdate)
assert(W.duelOverviewFrame.parent==W.overviewCanvas)
W.details=old
print("PASS: animated upward reveal, full contained bump with unscaled border, hover-out, stable carousel hierarchy")
''')

factory = world.split("local function EnsureSummaryRivalCard", 1)[1]
factory = "local function EnsureSummaryRivalCard" + factory.split("local function UpdateSummaryExchangeStat", 1)[0]
lua.globals().testCreateCard = lua.execute(
    "local W=DP.WorldPvP; local SetSummaryCardLift=testSummaryHover\n"
    + factory + "\nreturn EnsureSummaryRivalCard"
)
lua.execute('''
local oldCreate=CreateFrame
CreateFrame=function(kind,name,parent,template)
    local f=oldCreate(kind,name,parent,template); f.parent=parent
    local texture, font=f.CreateTexture,f.CreateFontString
    function f:CreateTexture(...) local t=texture(self,...); t.parent=self; return t end
    function f:CreateFontString(...) local t=font(self,...); t.parent=self; return t end
    return f
end
local card=testCreateCard({summaryRivalCards={},summaryRivalsBody=CreateFrame()},1)
assert(card.bg.parent==card.visual, "fill must remain below the border and content")
assert(card.borderClip.parent==card.visual)
assert(card.border.parent==card.borderClip)
assert(card.content:GetFrameLevel()>card.border:GetFrameLevel())
for _,name in ipairs({"name","status","state","record"}) do
    assert(card[name].parent==card.content, "all text must render above the plaque fill")
end
assert(card.portraitFrame.parent==card.content)
assert(card.border._rivalsBorderStyle=="tooltip-rounded")
assert(card.border._rivalsEdgeTexture=="Interface\\Tooltips\\UI-Tooltip-Border")
assert(card.portraitOccluder.parent==card.portraitFrame)
assert(card.portraitOccluder.mask==card.portraitOccluderMask)
CreateFrame=oldCreate
print("PASS: production plaque factory keeps fill, border, text and portrait in the correct layer order")
''')
