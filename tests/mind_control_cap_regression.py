"""Static regression checks for the reported Mind Control Cap/Chronoboon sequence."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
world = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
usage = (root / 'Usage.lua').read_text(encoding='utf-8-sig')
catalog = (root / 'UsageCatalog.lua').read_text(encoding='utf-8-sig')

assert 'id == 13180 or id == 13181' in world
assert 'MIND_CONTROL_GRACE = 45' in world
assert 'mindControlCapUse' in world
assert 'Gnomish Mind Control Cap' in world
assert 'BACKFIRED' in world
assert 'W.MindControlUseInfo(logEntry, participants)' in world
assert 'local repairVersion = 3' in world
assert 'W.RepairMindControlSplitEncounters(observer.worldPvP)' in world
assert '[13181] = {itemID=10726, name="Gnomish Mind Control Cap"' in catalog

assert 'tonumber(spellID) == 13180 or tonumber(spellID) == 13181' in usage
assert 'if spellID == 349981 then return nil end' in usage
assert '[349981] = {itemID=184938' not in catalog
assert 'if usageSpellID == 349981 then return false end' in world
assert 'captureModelVersion=4' in usage
assert 'LEGACY_CONSUMABLE_BACKFILL_VERSION = 12' in usage
print('PASS: Mind Control Cap 13181/backfire continuity and passive Chronoboon cleanup are wired')
