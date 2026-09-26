## Rivals 0.21.181-beta

Changes since the last GitHub push, 0.21.88-beta:

- Added frozen per-encounter consumable-cost estimates using TSM DBMarket with Auctionator fallback, a participant/item ledger, and explicit unpriced-item information. Added reagent accounting, Zanza/Juju replacement proxies, fixed Noggenfogger vendor pricing, and historical-record repairs; reusable equipment and conjured mana gems are excluded from spend.
- Redesigned World PvP Summary with compact encounter stats, damage dealt/taken and recovery breakdowns, detailed killing-blow tooltips, and a wider opponent roster. Retained NPC participation is shown separately from PvP headcounts, with duplicate NPCs grouped.
- Expanded Enemy Buffs to observable helpful auras with a scrolling icon grid, item/spell tooltips, and class-colored opponent selection. Improved primary-opponent selection, mixed-level encounter descriptions, and filtering of incidental hits from displayed headcounts. Added Bubble Hearthed outcome detection.
- Improved Items & Abilities with participant filters, unified category sections, clearer category plaques, adaptive window sizing, and correct class/faction PvP Insignia classification, including older records.
- Added independent automatic screenshot settings for duel wins and tracked World PvP enemy deaths, with delayed capture so result text can appear and duplicate death signals suppressed. World PvP tracking is now always enabled.
- Isolated the Rivals Character pane tab from Blizzard's native tab bookkeeping to address combat taint. Refined tab positioning, labels, selection behavior, and access while the Character pane is already open in combat.
- Standardized scrollbars and corrected endpoint travel, list gutters, clipping, empty states, and short-list spacing throughout the interface. Refined Overview transitions and opponent portrait plaques, layering, and hover behavior.
- Preserved captured encounter portraits during the current session and expanded stable legacy portrait fallbacks, including curated Horde race/class combinations and varied Human Mage displays.
- Hardened combat-log rendering against malformed legacy swing-event metadata and improved reconstruction of historical damage and consumable evidence. Encounter Details resets to Summary after closing.
- Refreshed the World PvP and duel promo rotation, including consumable-spend messaging.
