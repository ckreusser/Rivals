"""Racial casts must reach Items & Abilities regardless of cooldown metadata."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('DP = {Theme = {}}; function GetTime() return 20 end')
for name in ['UsageCatalog.lua', 'ProcCatalog.lua', 'Usage.lua']:
    lua.execute((root / name).read_text(encoding='utf-8-sig'), 'Rivals', lua.globals().DP)
lua.execute('''
local U = DP.Usage
local ids = {20572, 20594, 7744, 20549, 26296, 26297, 20554, 20580, 20600, 20577, 20589}
local cases = 0
for _, cooldown in ipairs({false, 0, 10000, 60000, 120000, 179999, 180000, 600000}) do
    local value = cooldown or nil
    GetSpellBaseCooldown = function() return value end
    for _, id in ipairs(ids) do
        for _, actor in ipairs({'Player-self', 'Player-enemy'}) do
            local side = actor == 'Player-self' and 'player' or 'opponent'
            local session = {acceptedAt = 10, identity = {guid = 'Player-enemy'}}
            U.Observe(session, 'Player-self', 20, 'SPELL_CAST_SUCCESS', actor, id, 'Racial', value)
            local _, entry = next(assert(session.usage[side]))
            assert(entry and entry.kind == 'racial', 'duel racial excluded: '..id)
            local groups = U.Groups({session = session})
            assert(#groups == 1 and groups[1].key == 'racials' and #groups[1][side] == 1)

            local world = {worldPvP = true, startedElapsed = 10,
                participants = {['Player-self'] = {}, ['Player-enemy'] = {}}}
            U.WorldObserve(world, 'Player-self', {[2] = 'SPELL_CAST_SUCCESS',
                [4] = actor, [5] = 'Actor', [12] = id, [13] = 'Racial'})
            assert(world.worldUsage and #world.worldUsage.events == 1, 'world racial excluded: '..id)
            local event = world.worldUsage.events[1]
            assert(event.kind == 'racial' and event.category == 'racials')
            assert(U.Describe(event, {session = world}).category == 'racials')
            cases = cases + 1
        end
    end
    -- The exemption must not admit ordinary short-cooldown abilities.
    local session = {acceptedAt = 10, identity = {guid = 'Player-enemy'}}
    U.Observe(session, 'Player-self', 20, 'SPELL_CAST_SUCCESS', 'Player-self', 999999, 'Class Ability', value)
    local world = {worldPvP = true, startedElapsed = 10, participants = {['Player-self'] = {}}}
    U.WorldObserve(world, 'Player-self', {[2] = 'SPELL_CAST_SUCCESS',
        [4] = 'Player-self', [5] = 'Actor', [12] = 999999, [13] = 'Class Ability'})
    if not value or value < 180000 then
        assert(not session.usage and not world.worldUsage)
    else
        local _, entry = next(session.usage.player)
        assert(entry.kind == 'cooldown' and world.worldUsage.events[1].category == 'cooldowns')
    end
end
GetSpellBaseCooldown = nil
local world = {worldPvP = true, participants = {['Player-self'] = {}}}
U.WorldObserve(world, 'Player-self', {[2] = 'SPELL_CAST_SUCCESS',
    [4] = 'Player-self', [5] = 'Actor', [12] = 20589, [13] = 'Escape Artist'})
assert(world.worldUsage.events[1].category == 'racials')
print('PASS: '..cases..' racial cases across duel/world tracking and display; class cutoff preserved; missing cooldown API supported')
''')
