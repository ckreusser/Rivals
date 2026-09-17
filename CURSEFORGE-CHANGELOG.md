## 0.21.42-beta

### World PvP

- Added automatic open-world PvP encounter tracking, with kills, deaths, honorable kills, streaks, opponent records, and class matchups. Tracking is enabled by default and can be toggled in Manage.
- Added Outnumbered Victory and Outnumbered Escape recognition for solo 1v2+ fights. Recognition requires overlapping enemy pressure; passive or sequential kills do not count as outnumbered victories.
- Added Gank and Lowbie Gank classification using observed opponent levels. Routine encounters are recorded quietly; result popups are reserved for notable outnumbered successes.
- Added encounter maps centered on the decisive kill/death location, with explored zone art and a visible red X marker.
- Added World PvP rivalry summaries to player tooltips and the `/rivals world` command.

### History and encounter details

- Browse Duels, World PvP, or All encounters in History, with opponent names, classes, and observed levels on World PvP rows.
- Added World PvP encounter details with Summary, Items & Abilities, and Combat Log tabs, including participant filters and lifetime rivalry context.
- Added persistent duel combat logs with My actions and What happened to me views.
- Improved item identification, including opponent activations and equipped-item resolution for shared activation spells. Usage now separates Potions/Consumables, Engineering Gadgets, Equipment, and racial abilities.
- Expanded long-cooldown tracking to abilities with cooldowns of three minutes or longer.
- Added spec detection from inspected talents and combat evidence, including Classic hybrid builds. Spec evidence stays tied to the encounter instead of carrying over across later fights.
- Clarified record labels as Rivals Verified, Local Record, and Rival Report.

### Interface

- Switch between Duel Rating and World PvP through a two-page Overview carousel. Your selected page is remembered, and the Character tab follows the selected mode.
- Matchups opens in the selected Duel or World PvP context, with dedicated opponent and class views.
- Refined rating cards, paired stat panels, World PvP statistics, dropdown alignment, and encounter-detail spacing.
- Improved map crops, marker visibility, scroll bounds, and the clipped Overview swipe animation.
