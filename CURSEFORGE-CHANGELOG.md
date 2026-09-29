## Rivals 1.0.101

Changes since 1.0.0.

### History portraits

- Added reconstructed 3D opponent portraits using captured race, sex, and equipment, with saved outfits available after reloads.
- Rebuilt loading around the selected encounter: only visible portraits load, completed portraits are reused, and switching encounters cancels abandoned work.
- Removed the dependency on finding a nearby player of the same sex, fixing prolonged waits affecting male Dwarves and other portraits.
- Improved framing, circular clipping, equipment verification, and animation freezing. A spinner remains visible while a portrait prepares.
- Added eight stable face, hair, and skin variants per race/sex. Reconstructed features are approximations; exact live appearances are preferred when available.

### Combat Log

- Added selectable, read-only logs and a Copy button that selects the log for Ctrl+C.
- Added spell tooltips, quality-colored item links, clearer proc highlighting, killing-blow markers, and additional missed/absorbed/resisted attack results.
- Expanded equipped-item proc recognition and corrected false attribution, including NPC Dazed and normal class abilities such as Disarm.
- Improved reflected-spell attribution and periodic-effect ownership.
- Item activations now appear before their resulting effects. Diamond Flask is correctly shown as an item use while retaining its applied-buff entry.
- Fixed large mousewheel jumps after switching encounters and an error when opening details containing equipped-item procs.

### Encounter tracking

- Keep fights together through Ice Block and Gnomish Mind Control Cap interruptions, including cap backfires.
- Repair eligible adjacent saved encounter fragments when retained evidence identifies one continuous fight, rebuilding their logs, results, and consumable totals.
- Added an encounter mouseover roster with class-colored names, known or inferred specs, and Survived/Died status.
- Improved friendly participant capture and death tracking without treating Feign Death as a real death.
- Fixed stretched or misplaced exploration overlays on encounter maps.

### Spending and encounter details

- Added lifetime Enemy Gold Spent to the World PvP overview, preserving accumulated spending as older encounters leave rolling History. Nemesis remains available in the Most Killed tooltip.
- Sort the consumable ledger by spending, with the largest contributors and items first.
- Added Items & Abilities category help. Reagents remain in consumable costs without separate action rows.
- Stop counting the passive Supercharged Chronoboon aura as an item use or enemy buff advantage, repair affected saved costs, and price actual Chronoboon uses at the fixed 1-gold vendor cost.
