# Equipped proc catalog notes

`ProcCatalog.lua` maps exact combat-log spell IDs to possible equipped items.
Names alone are insufficient: class abilities can share a name with item effects.
Passive equip spells may trigger a different spell; follow that link to capture
the actual damage, healing, or debuff event. This catalog is curated, not a
guarantee of exhaustive Classic Era item coverage.

## Shield additions in 1.0.105

| Item | Passive trigger | Combat-log effect |
| --- | --- | --- |
| [Stygian Buckler (23238)](https://classicdb.ch/?item=23238) | [29162](https://classicdb.ch/?spell=29162) | [Stygian Grasp (29164)](https://classicdb.ch/?spell=29164) |
| [Jagged Obsidian Shield (22198)](https://classicdb.ch/?item=22198) | [27561](https://classicdb.ch/?spell=27561) | [Silence (27559)](https://classicdb.ch/?spell=27559) |
| [Skullflame Shield (1168)](https://classicdb.ch/?item=1168) | [18815](https://classicdb.ch/?spell=18815) | [Drain Life (18817)](https://classicdb.ch/?spell=18817) |
| Skullflame Shield | [18816](https://classicdb.ch/?spell=18816) | [Flamestrike (18818)](https://classicdb.ch/?spell=18818) |

Checked against ClassicDB's item-to-trigger-to-effect links on 2026-09-30.
These are Classic Era item IDs; Season of Discovery variants are outside this check.
The preexisting Skullflame 18815 mapping is retained for compatibility.

`tests/combat_item_classification.py` exercises these effects through the actual
resolver and combat-log formatter, including NPC and same-name class exclusions.
Old records containing these spell IDs can resolve the newly cataloged sources
at display time; events that were never recorded cannot be reconstructed.
