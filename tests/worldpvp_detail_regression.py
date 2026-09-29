"""Static checks for World PvP detail presentation rules."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
world = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')

assert 'local function IsIgnoredEnemyBuff(entry)' in world
assert 'spellID == 349981 or itemID == 184938 or name == "Supercharged Chronoboon Displacer"' in world
assert 'if category ~= "reagents" then' in world
assert 'CATEGORY_TOOLTIP' in world
assert 'header.categoryKey = category' in world
assert 'SortedConsumableActors(snapshot, record)' in world
assert 'SortedConsumableItems(actor)' in world
assert 'if av ~= bv then return av > bv end' in world
print('PASS: World PvP detail filters, category help, and value sorting are wired')
