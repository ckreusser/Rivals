## Rivals 1.0.142

Changes since the GitHub release 1.0.139.

- Added a movable, saved killstreak HUD position and silent `/rivals kb` preview; refreshed promo messaging.
- Extended rapid-kill medals to a 12-second window and enabled battleground animations without persistent battleground tracking.
- Added per-character medal counts; stored multikills exclude gray-level and unknown-level victims while animations remain available.
- End completed World PvP fights after the existing resurrection grace even when NPC guards keep combat active; preserve resurrection continuity in unfinished fights and recognize qualifying solo sweeps.
- Corrected the user-confirmed Booty Bay solo sweep and removed the separate reconstructed death entry.
- Added Low-health Death for enemy-initiated encounters at 50% health or less with no enemy kills; excluded these deaths from solo-loss records.
- Increased combat logs to 2,000 events, retaining deaths, killing blows, and resurrection events beyond the ordinary limit.
- Increased item-use history to 2,000 entries; observed consumables and reagents remain recorded beyond that limit.
- Improved consumable-cost repair for missing items, preserving previously captured prices; corrected uncached engineering consumable and reusable-item classification.
- Show protection potions and recognized long class buffs from removal-only evidence; consumable buff icons now use their item icons.
- Shortened encounter labels to 1vN Victory/Escape/Fight, capitalized Mixed-Level Fight, and added distinct classification colors and compact KB/KBs counts.
- List all opponent names, placing the selected rival first in Matchups; opponent cards open that rival's Matchups while keeping encounter details open.
- Refined Matchups plaque spacing, visible-row capacity, scrollbar behavior, and full-width plaques when no scrollbar is needed.
- Aligned History filters and reordered their options; grouped legacy and unconfirmed duels under Casual without changing rating eligibility.
- Simplified the Enemy gold spent tooltip.
