"""Friendly level capture with missing GUID lookup and disabled nameplates."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
lua = LuaRuntime()
lua.execute('''
W={};units={};levels={}
function UnitGUID(unit) return units[unit] end
function UnitLevel(unit) return levels[unit] end
function UnitTokenFromGUID() return nil end
C_NamePlate={GetNamePlates=function() return {} end}
function ScanVisibleEnemyBuffs() end
function ScanEnemyUnitBuffs() end
''')
start = source.index('function W.VisibleUnitForGUID(')
end = source.index('W._portraitSessionID =', start)
lua.execute(source[start:end])
start = source.index('function W.Event(')
end = source.index('\nend\n', start) + 5
lua.execute(source[start:end])
lua.execute('''
units.player='self';levels.player=60
units.party4='party-friend';levels.party4=42
units.raid40='raid-friend';levels.raid40=53
local session={playerGUID='self',playerLevel=60,enemies={},friendlies={
 ['self']={guid='self'},['party-friend']={guid='party-friend',level=-1},
 ['raid-friend']={guid='raid-friend'},['missing']={guid='missing'},
 ['old-known']={guid='old-known',level=35}}}
units.raid1='old-known';levels.raid1=60
W.RefreshFriendlyLevels(session)
assert(session.friendlies.self.level==60)
assert(session.friendlies['party-friend'].level==42)
assert(session.friendlies['raid-friend'].level==53)
assert(session.friendlies['old-known'].level==35,'known level overwritten')
assert(not session.friendlies.missing.level,'unobserved level invented')
W.active=session
units.mouseover='missing';levels.mouseover=-1
W.Event('UPDATE_MOUSEOVER_UNIT');assert(not session.friendlies.missing.level)
levels.mouseover=27;W.Event('UNIT_LEVEL','mouseover')
assert(session.friendlies.missing.level==27,'late friendly level was ignored')
session.friendlies.late={guid='late'};units.party2='late';levels.party2=48
W.Event('GROUP_ROSTER_UPDATE');assert(session.friendlies.late.level==48)
session.friendlies.plate={guid='plate'};units.nameplate87='plate';levels.nameplate87=59
W.Event('NAME_PLATE_UNIT_ADDED','nameplate87');assert(session.friendlies.plate.level==59)
print('PASS: party/raid lookup without nameplates; self level; late level/roster/nameplate events; unknown and known levels preserved')
''')
assert 'W.RefreshFriendlyLevels(session)\n    local friendlies = OrderedParticipants(session.friendlies)' in source
core = (root / 'Core.lua').read_text(encoding='utf-8-sig')
assert '"UNIT_LEVEL", "GROUP_ROSTER_UPDATE"' in core
