local files={'Parser.lua','Tracker.lua','UsageCatalog.lua','Specs.lua','Usage.lua','Rating.lua','Verification.lua','Recovery.lua','Periods.lua','Theme.lua','WorldPvP.lua','Views.lua','Promos.lua','CharacterTab.lua','Inspect.lua','Tooltip.lua','Core.lua'}
for _,f in ipairs(files) do local fn,err=loadfile(f); assert(fn, f..': '..tostring(err)) end
print('PASS LUA SYNTAX')
