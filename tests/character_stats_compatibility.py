"""Exercise CSC visibility across Rivals/native tab transitions with Lua 5.1."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in root.glob('*.lua'):
    lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8-sig'))
source = (root / 'CharacterTab.lua').read_text(encoding='utf-8-sig')
helper = source[source.index('local function InstallCharacterStatsCompatibility'):source.index('function DP.InstallCharacterTab')]
lua.execute('''
local function Frame(shown)
    local f = {shown = shown, hooks = {}}
    function f:IsShown() return self.shown end
    function f:HookScript(event, fn) self.hooks[event] = fn end
    function f:Show()
        if self.shown then return end
        self.shown = true
        if self.hooks.OnShow then self.hooks.OnShow(self) end
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.hooks.OnHide then self.hooks.OnHide(self) end
    end
    return f
end
''' + helper + '''
local function Setup(installed, initiallyShown)
    local panel, stats, unrelated = Frame(false), Frame(initiallyShown), Frame(true)
    stats.leftStatsDropDown = {}; stats.rightStatsDropDown = {}
    CharacterFrame = {GetChildren = function() return unrelated, stats end}
    PaperDollFrame = Frame(true)
    UISettingsGlobal = {statsPanelHidden = false}
    CSC_HideStatsPanel = installed and function() error('must not change CSC preferences') end or nil
    InstallCharacterStatsCompatibility(panel)
    return panel, stats, unrelated
end

local panel, stats, unrelated = Setup(true, true)
PaperDollFrame:Hide(); panel:Show()
assert(not stats:IsShown() and unrelated:IsShown())
assert(not UISettingsGlobal.statsPanelHidden)
stats:Show(); assert(not stats:IsShown()) -- CSC attempts to show over Rivals
PaperDollFrame:Show(); assert(not stats:IsShown())
panel:Hide(); assert(stats:IsShown()) -- native show before Rivals hide
PaperDollFrame:Hide(); panel:Show(); panel:Hide()
assert(not stats:IsShown()) -- reputation/skills must not restore stats
PaperDollFrame:Show(); assert(stats:IsShown()) -- reverse callback order / reopen
PaperDollFrame:Hide(); panel:Show()
UISettingsGlobal.statsPanelHidden = true
panel:Hide(); PaperDollFrame:Show()
assert(not stats:IsShown() and UISettingsGlobal.statsPanelHidden)

panel, stats = Setup(true, false)
PaperDollFrame:Hide(); panel:Show(); panel:Hide(); PaperDollFrame:Show()
assert(not stats:IsShown()) -- preserve an already-hidden panel

panel, stats = Setup(false, true)
panel:Show(); assert(stats:IsShown()) -- absent CSC leaves other addons alone
panel:Hide()
CSC_HideStatsPanel = function() error('must not call API') end
panel:Show(); assert(not stats:IsShown()) -- CSC available on a later opening
print('PASS: CSC overlap, restoration, callback order, saved preferences, and optional loading')
''')
