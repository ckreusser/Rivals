"""Static regression checks for Ice Block encounter continuity and retroactive merge."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
world = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')

assert 'COMBAT_SUSPENSION_MAX = 13' in world
assert 'COMBAT_SUSPENSION_POST_GRACE = 3' in world
assert 'return spellName == "Ice Block"' in world
assert 'W.UpdateCombatSuspension(session, info, boundarySpellID, boundarySpellName)' in world
assert 'local suspended = W.CombatSuspensionActive(session, now)' in world
assert 'hostileGUID and not session.enemies[hostileGUID] and not suspended' in world
assert 'not W.CombatSuspensionActive(active, now)' in world
assert 'CombatSuspensionSignalAt(first, second)' in world
assert 'RecordHasEnemy(second, guid, signal.name)' in world
assert 'return "combat-suspension"' in world
assert 'first.retroMergedCombatSuspension = true' in world
assert 'local repairVersion = 3' in world
print('PASS: Ice Block combat-drop continuity and retroactive split repair are wired')
