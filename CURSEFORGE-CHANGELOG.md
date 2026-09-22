## Rivals 0.21.88-beta

Changes since 0.21.45-beta:

- Improved World PvP encounter separation: leaving combat starts a 10-second grace period, while a new opponent after combat ends starts a separate encounter. This prevents unrelated fights from inflating encounter headcounts.
- Refined friendly headcounts to count players who actively attack an encounter enemy. Chat summaries now use the same contested-fight counts as History and Solo 1vN tracking.
- Fixed kill streaks to continue through harmless disengages and reset on player death. Improved zone detection and Favorite Zone handling for older records with continent-level locations.
- Added detection of observable enemy world buffs and consumable buffs, including buffs already active when an enemy is seen. Detected buffs appear in dedicated Items & Abilities sections.
- Redesigned Solo 1vN result notifications with animated presentation, opponent details, and lifetime rivalry tooltips.
- Reworked Encounter Details with clearer map, outcome, location, and opponent panels; improved long-location wrapping, readable durations, and smooth scrolling for opponent lists.
- Expanded Summary and opponent tooltips with damage exchanged, observed actions, kill attribution, detected buffs, encounter context, and lifetime rivalry records.
- Improved Duel and World PvP combat-log readability with class-colored names, distinct damage/healing colors, highlighted abilities and interrupts, and broader class inference from observed abilities.
- Duel Details and World PvP Encounter Details now close each other when opened, preventing overlapping detail windows.
- Cleaned up Matchups labels, map-coordinate formatting, and Most Killed/Nemesis displays.
