DP = {}
local root = '/mnt/data/rivals115/Rivals/'
local function loadAddon(name)
  local f, err = loadfile(root..name); assert(f,err); f('Rivals',DP)
end
for _,name in ipairs({'Parser.lua','Tracker.lua','UsageCatalog.lua','Specs.lua','Usage.lua','Rating.lua','Verification.lua','Recovery.lua','Periods.lua','Theme.lua','WorldPvP.lua','Views.lua','Promos.lua','CharacterTab.lua','Inspect.lua','Tooltip.lua'}) do loadAddon(name) end
assert(loadfile(root..'tests/wow_mock.lua'))()
loadAddon('Core.lua')
assert(loadfile(root..'tests/world_pvp.lua'))()
print('PASS WORLD')
