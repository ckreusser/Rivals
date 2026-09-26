## Rivals 1.0.0

Rivals is out of beta! Changes since 0.21.181-beta:

### Duel Details
- Rebuilt Duel Details with Summary, Items & Abilities, and Combat Log tabs matching the World PvP detail window.
- Added rating before/after and change, class-matchup rating, lifetime/rated/class records, verification status, and duel date/duration to Summary.
- Added a consumable-spend comparison and itemized ledger using frozen encounter pricing.
- Added an Enemy Buffs card for newly recorded duels and improved opponent identity capture and portrait fallbacks.
- Combined duel actions into one chronological combat log and added a participant filter to Items & Abilities. New captures retain first-use timing and target identity when available.
- Fixed the unsupported rating-change arrow. Duels can still be starred from History.

### Enemy Buffs and Layout
- Expanded eligible long-duration class buffs, with a five-minute minimum duration to reduce short-effect clutter. Lightning Shield is excluded.
- Prioritized World Buffs, Flasks, Zanzas, Elixirs, Protection Potions, Class Buffs, then miscellaneous effects.
- Kept all World PvP detail tabs at a consistent window height and removed phantom scrolling from short combat logs.

### Screenshot and Kill-Tracking Fixes
- World PvP kill screenshots now wait for confirmed death, preventing premature captures during Druid shapeshifts and similar health transitions.
- Hunter Feign Death no longer counts as a real death, advances kill statistics, or triggers a kill screenshot.
- Automatic Rivals screenshots now suppress Blizzard's screenshot-status messages and clear lingering notices before capture. Normal manual screenshot notifications are restored afterward, with a safety timeout.

### Release
- Graduated Rivals from beta to version 1.0.0 and synchronized addon, capture-report, and README version information.
