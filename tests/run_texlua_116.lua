DP = {}
local root = '/mnt/data/rivals116/Rivals/'
local function loadAddon(name)
  local f, err = loadfile(root..name)
  assert(f, err)
  f('Rivals', DP)
end
for _,name in ipairs({'Parser.lua','Tracker.lua','UsageCatalog.lua','Specs.lua','Usage.lua','Rating.lua','Verification.lua','Recovery.lua','Periods.lua','Theme.lua','WorldPvP.lua','Views.lua','Promos.lua','CharacterTab.lua','Inspect.lua','Tooltip.lua'}) do loadAddon(name) end
for _,name in ipairs({'spec.lua','specs.lua','usage.lua','rating.lua','guards.lua','recovery.lua','wow_mock.lua'}) do assert(loadfile(root..'tests/'..name))() end
loadAddon('Core.lua')
for _,name in ipairs({'integration.lua','character_tab.lua','world_overview.lua','inspect.lua','promos.lua','world_pvp.lua'}) do assert(loadfile(root..'tests/'..name))() end
print('PASS')
