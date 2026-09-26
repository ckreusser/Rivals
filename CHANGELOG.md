# 0.21.181-beta

- Replace the Rivals promo rotation with the current World PvP- and duel-focused set selected for the addon.
- Add a consumable-spend promo highlighting Rivals' estimate of how much gold enemy players burned during a fight.

# 0.21.180-beta

- Add curated Horde race/class portrait backfills for every playable Classic Era Horde combination: Orc, Tauren, Troll, and Undead/Forsaken. Legacy Alliance-player encounters can now use real Classic race/class character displays instead of falling through to a class icon.
- Give most Horde race/class pairs multiple curated display IDs so different rivals can receive stable, varied synthetic portraits while preserving the existing actual-captured-portrait/display-ID priority.

# 0.21.179-beta

- Normalize Items & Abilities categories before sorting/rendering so each category gets one shared section across all participants. Resolved equipment such as class/faction PvP Insignias can no longer split EQUIPMENT/COOLDOWNS into duplicate plaques.
- Fix zero/short Items & Abilities layouts by removing phantom scroll-body padding and sizing the detail window from the actual visible rows. Empty encounters now keep a normal dataframe/header area without spawning a bogus scrollbar.

# 0.21.178-beta

- Widen the World PvP Summary OPPONENTS box and its responsive plaques 12px to the right so its outer edge aligns exactly with the ENEMY BUFFS box above.
- Items & Abilities now reclaims the scrollbar lane whenever scrolling is unnecessary, widening the dataframe to the same right-side inset as the left. Short lists also pull the window footer up to a matching 20px buffer below the last row.
- Nudge the shared Character-pane History / Matchups / Rivals scrollbar one pixel right for final gutter alignment.

# 0.21.177-beta

- Recognize all five Classic Era PvP Insignia activation spells as trinket uses instead of generic ≥3 minute cooldowns.
- Resolve the exact class/faction-specific Insignia of the Alliance/Horde for Warrior, Hunter, Rogue, Priest, Mage, Warlock, Druid, Shaman, and Paladin.
- Reclassify already-recorded World PvP rows such as Druid `Immune Charm/Fear/Stun` into EQUIPMENT at display time, so existing encounter history is repaired without a data migration.

# 0.21.176-beta

- Move the shared Character-pane History/Matchups/Rivals scrollbar 4px left so its visible track sits fully inside the dark list gutter.
- Shorten the Opponents/Classes scrollbar to the five-row list height so the lower arrow aligns with the bottom visible plaque instead of hanging below it.
- Improve Items & Abilities category-divider legibility with a slightly taller plaque, larger outlined centered text, a stronger drop shadow, and a darker/less noisy rock fill.

# 0.21.175-beta

- Realign the Matchups Opponents/Classes tabs to the same horizontal guides as the plaques beneath them.
- Rebalance Character-pane list geometry around an 18px left buffer, 5px plaque-to-scrollbar gap, 18px scrollbar, and 18px right buffer.
- Nudge the shared History/Matchups/Rivals scrollbar 2px left and trim plaque width accordingly so the control sits fully between the rows and the pane border instead of riding the frame.

# 0.21.174-beta

- Class-color the Items & Abilities participant selector and its menu entries, including You, enemies, and friendly participants when class data is retained.
- Remove the currently selected value from the Items & Abilities dropdown menu so every visible option changes the filter.
- Apply the same current-selection removal to the ENEMY BUFFS dropdown while preserving its existing class-colored enemy names and level/race metadata.

# 0.21.173-beta

- Move the Items & Abilities participant selector onto the tab row and align its right edge with the ENEMY BUFFS selector above. Pull the dataframe upward into the vacated space.
- Reserve the full 18px Items & Abilities scrollbar footprint instead of drawing the dataframe underneath it; the table and scrollbar now exactly span the 610px content area with matching outer insets.
- Pull Character-pane list scrollbars 8px left so their entire arrow/track assembly remains inside the dark content inset. Shorten list plaques to stop 5px before the scrollbar, and move Matchups rows onto the same left guide as History.
- Render Items & Abilities section-plaque labels in all caps.

# 0.21.172-beta

- Rebuild the shared Rivals scrollbar endpoint geometry: the native slider remains responsible for drag/value behavior, while the visible Blizzard knob is positioned independently so it physically reaches the top/bottom arrow buttons at minimum and maximum. The touched endpoint arrow now gets an explicit highlight glow.
- Refit Character-pane History/Matchups/Rivals plaques to terminate at the visible scrollbar track instead of leaving a dead strip beside it.
- Refit Rivals-owned scroll gutters across World PvP, Duel Details, combat logs, buff grids, export, and Character-pane lists so content terminates against the visible track rather than the invisible 18px control frame.
- Replace the World PvP Items & Abilities participant filter with the compact ENEMY BUFFS selector treatment and move it into the open upper-right strip beneath the buff card.

# 0.21.171-beta

- Fix the standardized Rivals scrollbar thumb travel: the slider track now begins immediately beneath the 18px arrow buttons, eliminating the dead gap that kept the thumb from reaching the top/bottom endpoints.
- Thicken the Items & Abilities category plaque borders from the standard 8px Blizzard tooltip edge to a 12px edge, with a slightly deeper rock-texture inset so the heavier frame stays clean.

# 0.21.170-beta

- Standardize Rivals scrollbars on one Blizzard-style arrow/track/thumb treatment across Matchups/History, World PvP opponent and buff lists, World PvP Items & Abilities, combat logs, duel details, and the capture report. Endpoint arrows now stay lit when the thumb is touching that end rather than lighting the direction with remaining travel.
- Refit list gutters around the new 18px scrollbar so plaques and icon grids no longer collide with or leave arbitrary space beside the control.
- Expand the World PvP Items & Abilities dataframe from 552px to 592px so the table runs directly into the scrollbar and the combined table+scrollbar assembly keeps the same outer inset on the right as the table has on the left.
- Restyle Items & Abilities category dividers as rounded plaque rows with Blizzard `UI-Background-Rock`, centered gold labels, and a dark drop shadow.

# 0.21.169-beta

- Widen portrait/medallion opponent rows by 3px on the left while preserving the shared right guide. This compensates for transparent padding in the medallion art so portrait plaques have the same visible left/right breathing room as ordinary plaques.
- Tighten Opponents row pitch from 60px to 56px, reducing the excessive vertical dead space without changing the 47px plaque height or 56px medallion size.
- Replace the bad Human Mage legacy portrait display (3293) with a sex-aware pool of verified Human mage/portal-trainer displays. Existing legacy Human Mage rivals now vary by rival instead of all rendering the same non-Human portrait.

# 0.21.168-beta

- Keep the corner-free portrait-plaque masking from 0.21.167, but shrink the portrait occluder from the full 56px medallion to the 48px inner portrait region. This lets the rounded plaque border continue visibly beneath the medallion rim instead of stopping outside it.
- The plaque rails now overlap the outer medallion by several pixels at both the top and bottom while the actual left corners remain clipped and matted away. The occluder still follows the hover animation, so that overlap remains consistent on mouseover.

# 0.21.167-beta

- Rebuild portrait-plaque left-end masking: the rounded Blizzard border now extends 18px past the row's left edge so its true left corners are completely outside the viewport, while the top/bottom rails still continue underneath the portrait.
- Add a dedicated 16px left matte plus a full-size circular portrait matte to cover the clipped rail segment. This removes the visible square/corner stubs at rest and during hover without creating the prior gap between the plaque border and medallion.
- Preserve the rounded Blizzard tooltip corners on the visible right side and on non-portrait plaques.

# 0.21.166-beta

- Replace the square rail-built Opponents plaque with Blizzard's rounded `UI-Tooltip-Border`, matching the surrounding border box shape.
- Rebuild portrait plaque overlap around a dedicated border clip: the border itself extends left underneath the medallion while its rounded left corners live outside the visible clip and cannot peek out.
- Add a circular portrait-backed occluder that moves/scales with the medallion, hiding the underlying rail only inside the portrait silhouette so the top/bottom border lines emerge cleanly from the medallion curve even on hover.

# 0.21.165-beta

- Replace the clipped tooltip-backdrop strategy on OPPONENTS plaques with fixed one-physical-pixel rails. Portrait rows now have a true open-left border: no left rail and no left corner artwork exists to peek around the medallion.
- Start the portrait row's top/bottom rails underneath the medallion so they emerge at its right-hand curve instead of leaving the gap introduced by the clipping attempt.
- Keep NPC rows fully boxed with the same rail treatment, while hover continues to animate content/portrait only and never resizes the border.

# 0.21.164-beta

- Fix portrait-row left corners properly by clipping the left 54px of the Blizzard tooltip border instead of merely moving the border underneath the circular portrait. The left rail/corners no longer exist in the visible region, including during the portrait hover bump.
- Keep the plaque fill and row gutters unchanged, so this does not reintroduce the previous oversized left-side padding.

# 0.21.163-beta

- Fix portrait OPPONENTS plaques exposing their left tooltip-border corner again. The decorative border now starts beneath the portrait medallion center, while the plaque fill remains full-width underneath it.
- Decouple the plaque fill/hover wash from the portrait border inset so hiding the corner does not bring back the oversized left-side dead space.

# 0.21.162-beta

- Remove the inner catch-light from OPPONENTS plaques. The extra top stroke was reading like a second border line beneath the actual plaque border.
- Rebalance OPPONENTS row width and anchors so the list now uses matching left/right gutters instead of carrying a large left-side dead zone.
- Extend portrait plaques farther underneath the portrait medallion so portrait and non-portrait rows no longer have oversized left padding.

# 0.21.161-beta

- Replace the malformed Character Create corner treatment on Opponents rows with Blizzard's native `UI-Tooltip-Border`, tinted down so the roster reads as rows rather than nested dialog boxes. The border is now physically stationary during hover, so it cannot grow or flicker with the bump.
- Rework Opponents hover feedback to animate only the portrait/content highlight: a small portrait lift, two-pixel text nudge, and subtle warm wash. The plaque frame itself stays fixed.
- Make player and NPC cards use the same fixed row width and `TOPRIGHT` registration. Portrait mode only changes the buried left edge; every visible plaque terminates on the same right-hand guide at rest and on hover.

# 0.21.160-beta

- Rebuild Opponents plaque trim with Blizzard `UI-CharacterCreate-MetalFrame-Horizontal` corner art and fixed one-physical-pixel rails. The decorative corners no longer grow with the 6% hover bump, avoiding the oversized animated-border look without returning to a tiled backdrop.
- Right-lock every Opponents plaque, including player portraits and NPC rows. Hover expansion now grows leftward into a reserved hit area so all right edges stay aligned before, during, and after the bump.

# 0.21.159-beta

- Increase opponent hover expansion from 4% to 6%, with a 45ms entrance and 60ms return.
- Replace animated tooltip-backdrop borders with untiled, fixed-thickness edge pieces and align their frame bounds to physical pixels.
- Move resting portrait rows closer to the left side of the Opponents box. Reserve room on the right for the full expansion while retaining smooth upward row reveals and clipping.

# 0.21.158-beta

- Fix obscured opponent text by keeping the fill below the border and placing text/portrait artwork in an explicit foreground frame.
- Restore the full 4% hover expansion with centered side clearance and portrait-row spacing. Resize the border at native scale while enlarging text and portraits together.
- Animate hover-triggered row reveals upward through the smooth-scroll path instead of jumping instantly.
- Shift Overview two UI units right, retaining its size and clipping bounds. Restore the original shared theme's border/texture rendering.
- Focused regressions cover animated reveal, hover containment, layer order, hover-out, carousel, pricing and portrait capture.

# 0.21.157-beta

- Restore a stable Overview carousel hierarchy; prevent independent texture snapping from breaking thin box edges at fractional UI scales. Keep existing layout and colors.
- Keep opponent hover visuals inside the list viewport. Reveal partially hidden rows on hover, with clearance for portrait rims, instead of moving them to an unclipped fullscreen overlay.
- Replace scaled hover borders with a subtle frame-height expansion at unchanged texture/font scale. Attach the plaque fill to the complete border bounds so both resize together.

# 0.21.156-beta

- Bury portrait-plaque left edges and corners beneath the medallion center.
- Center opponent plaques on their viewport and derive row widths from the actual panel width.
- Render stationary Overview pages directly to avoid ScrollFrame compositing on their box edges. Retain clipping while swiping, with the existing colors and opacity unchanged.

# 0.21.155-beta

- Extend encounter plaques behind the portrait so their left corners are exposed.
- Center both Overview pages within the visible Classic frame and clip swipes inside its stone border, excluding transparent frame padding.
- Repair empty original Consumed snapshots from retained evidence on login, including the Kazzaraxia encounter. Reconcile uses, combat-log casts and detected buffs before pricing new recordings.
- Fix the buff-name lookup scope and preserve separate Noggenfogger drinks inferred from distinct result auras.
- Freeze encounter portraits and reuse their actual captured texture during the current UI session. Opening history no longer replaces portraits with a later live appearance. Runtime render textures cannot be persisted through reloads; saved display IDs and the existing backfilled portraits remain the fallback.
- Validation: focused Lua 5.1 pricing/portrait/carousel regressions and read-only replay of saved encounter 64. In-game visual verification remains necessary; the older full suite also contains unrelated failing assertions.

# 0.21.140-beta

- Damage Exchange tooltips now show every retained ability/recovery source instead of collapsing the tail into `+N more`.
- Damage tooltips are wider and use a screen-safe side anchor whose vertical position is clamped to keep long breakdowns on-screen.
- Damage Dealt uses the same gold value color as the encounter-count/result numerals.
- Replaced `Enemy recovered` / `You recovered` in the Summary with one neutral `Recovery` sublabel while preserving the smaller green recovery value.
- OPPONENTS no longer reserves a scrollbar gutter when the roster fits. The scrollbar/track stay hidden and the opponent plaques expand across the full panel width until scrolling is actually required.

# 0.21.139-beta

- Replaced the mirrored Damage Exchange bars with compact text-first exchange rows: orange **Dealt** and red **Taken** totals, each with a smaller green recovery line beneath it. This removes the forced left/right symmetry and the red/green mixed-bar treatment while keeping recovery visible.
- Damage Exchange tooltip titles now inherit the damage direction color and include the exact gross amount in the header. Redundant headline rows were removed, and the player's recovery breakdown no longer repeats the player name before every self-heal.
- Reduced the Consumed money readout/icon scale slightly while preserving the compact centered row.

# 0.21.138-beta

- Reworked Damage Exchange bars to show each side as a share of total tracked damage instead of always normalizing the larger side to a full bar.
- Recovery now colors the recovered portion of the same damage segment, leaving the damage color as net pressure rather than drawing a competing green mini-bar.
- Condensed Damage Exchange tooltips, grouped NPC interference, limited repetitive ability rows, and bottom-anchored/clamped tall tooltips so they stay on-screen.
- Merged duplicate same-name NPCs into one Opponents plaque with a count and combined contribution.
- Compressed Consumed into a centered single-row stat and reduced the money/icon scale.

## 0.21.137-beta
- Rebuilt Damage Exchange reconstruction so older encounters can recover damage from retained combat-log names/text and opponent aggregate damage instead of displaying false zeroes when legacy GUID/amount fields are missing.
- Made the stacked Damage Exchange bars taller and switched their fills/recovery strips to Blizzard's `UI-StatusBar` texture with distinct dealt/taken/recovery tinting.
- Reworked Damage Exchange mouseovers into an opaque, alternating-row ledger with compact totals, per-player/NPC sections, ability breakdowns, and recovery sources.
- Killing Blows mouseovers now show the lethal ability, hit/critical result, damage, and overkill when retained; new encounters now persist critical/overkill metadata on the lethal hit.
- Tightened the Consumed footprint and enlarged the money readout/icons.
- Excluded conjured Mage mana gems (Mana Agate/Jade/Citrine/Ruby) from consumable gold cost while leaving their uses visible in Items & Abilities.
- Existing frozen snapshots are sanitized on encounter open so previously captured Mana Ruby entries disappear from Consumable Cost without repricing the rest of the encounter.

## 0.21.136-beta
- Rebuilt the World PvP **Summary** into an asymmetric layout: a compact **Encounter Stats** card on the left and a wider **Opponents** roster on the right. The old Enemy Players quadrant and standalone Encounter Context box are removed.
- Added stacked mirrored **Damage Exchange** bars. Damage dealt fills left-to-right, damage taken fills right-to-left, and green inset segments show health restored on the affected side. Both bars share one scale for immediate visual comparison.
- Damage mouseovers now break the exchange down by enemy/NPC source or target and by ability, then show observed health restoration and net pressure. Healing potions, bandages, Bloodthirst/Blood Craze-style heals, Crusader healing procs, and other CLEU healing are included when observed. New encounters retain overheal so the recovery bars use effective healing.
- Folded retained NPC participation into **Opponents** as distinct NPC plaques. NPC damage/healing context is shown on the plaque/tooltip and NPCs remain excluded from the PvP NvN headcount.
- Consolidated Kills, Killing Blows, Damage Exchange, and Consumable Cost into one coherent Encounter Stats card while preserving the Consumable Cost ledger mouseover.

## 0.21.135-beta
- Consumable Cost tooltip: removed the redundant frozen-price footer text, leaving only useful source/inference metadata.
- Rebalanced tooltip vertical spacing with slightly more separation below the header and additional padding beneath the footer.

## 0.21.134-beta
- Header spacing: narrowed ENEMY BUFFS from 206px to 196px so the World PvP header has matching 20px outer gutters on both sides; selector, empty-state, and five-column buff grid resize with it.
- Consumable Cost tooltip now sits 6px closer to the CONSUMED tile while retaining bottom-edge alignment.

## 0.21.133-beta

- Reduced the consumable ledger heading from the oversized large-font all-caps treatment to a quieter standard-size **Consumable Cost** header.

## 0.21.132-beta

- Strengthened the consumable ledger heading to **CONSUMABLE COST** and renamed the total row accordingly.
- Added a truly opaque black layer beneath the Blizzard tooltip skin so underlying UI/world text cannot bleed through.
- Pulled the ledger tooltip tight to the Consumed tile while preserving bottom-edge alignment.

## 0.21.131-beta

- Reworked the **Consumed** tooltip sizing around the actual rendered ledger columns. Long item names and the total row now expand the tooltip instead of ellipsizing, while short ledgers remain compact.
- Removed the redundant populated-state snapshot sub-header so the ledger begins immediately beneath **Estimated consumables**.
- Made the tooltip background fully opaque, switched its anchor so the tooltip bottom aligns with the bottom of the **Consumed** tile, and tightened the footer/bottom spacing.
- Normalized the ledger row geometry so the left and right outer padding on the participant/header rows are identical.

## 0.21.130-beta

- Fixed partial legacy consumable snapshots so the **Consumed** ledger cross-checks itself against all retained Items & Abilities evidence. Missing player spend such as Free Action Potions and bandages, missing enemy consumables, and stale one-item snapshots now self-repair instead of staying frozen.
- Hardened legacy event normalization: catalogued consumables now recover their canonical item ID from retained spell/name data even when an old record saved a bogus item ID or stale consumable flag.
- Noggenfogger legacy inference now counts distinct retained Noggenfogger result auras as separate drinks while avoiding double-counting when the original item-use cast is also present.
- Tightened the consumable ledger tooltip: quantity sits directly beside the item name, width is driven by ledger content rather than footer prose, bottom padding is reduced, and the footer is a single compact source/inference line.

## 0.21.129-beta

- Reworked the **Consumed** mouseover into a compact ledger: each participant and item is listed first, followed by a single **Total estimated consumables** row at the bottom. Legacy recalculation generation is bumped to 7 so previously partial backfills are rebuilt and can include the player plus every enemy with retained consumable-use/buff evidence.
- Zanza and Winterspring Juju rows now show the actual frozen replacement item inline, e.g. **Swiftness of Zanza (Blue Hakkari Bijou)** or **Juju Power (Winterfall E'ko)**.
- Replaced the addon-bronze tooltip frame with Blizzard's standard tooltip backdrop, made its width content-sensitive, increased bottom padding, and replaced the unsupported source-order arrow glyph with plain text.
- **Noggenfogger Elixir** now uses its fixed Classic Era vendor replacement cost of 7 silver each instead of TSM/Auctionator market pricing.

## 0.21.128-beta

- Fixed legacy **Consumed** backfill so a stale zero-cost snapshot can no longer block reconstruction when the encounter still has recoverable consumable evidence. Rivals now cross-checks the frozen snapshot against the same retained usage/combat-log/buff evidence used by **Items & Abilities**.
- Added an on-demand repair path when Encounter Details opens. If startup migration missed an old encounter but Items & Abilities can still recover Flask of Petrification, Magic Dust, Free Action Potion, bandages, Chronoboon, Zanzas/Jujus, etc., the Summary cost is rebuilt immediately from the player's current price snapshot and then frozen.
- Legacy migration generation bumped to 6 so existing false-zero generation-5 snapshots are re-evaluated once. Snapshots that already contain priced or explicitly unpriced items are left untouched, preserving their historical captured values.

## 0.21.127-beta

- Fixed the migration-generation bug that prevented 0.21.126 from actually re-running legacy consumable backfill. The reconstruction/proxy logic had been improved, but the saved `legacyBackfillVersion` was accidentally left at 4, so 0.21.125 snapshots were considered current and never recalculated.
- Legacy snapshots frozen by 0.21.123-0.21.126 are now recalculated once at generation 5. This makes the **Consumed** tile use the same retained potion/bandage/Magic Dust/etc. evidence already visible in **Items & Abilities**.
- The recalculation also applies the corrected one-for-one replacement proxies from 0.21.126, so existing Zanza snapshots drop the old multi-Bijou valuation and Winterspring Jujus use one corresponding E'ko.
- Centralized the legacy migration generation in `Usage.lua` and made World PvP read that exported value, preventing the snapshot writer and migration gate from silently getting out of sync again.

## 0.21.126-beta

- Corrected Zanza replacement cost to **1 Hakkari Bijou per Zanza** instead of three. Rivals still uses the cheapest currently priced interchangeable Bijou and freezes that value into the encounter snapshot.
- Added one-for-one Winterspring Juju proxies: each Juju is valued from its corresponding E'ko (for example **Juju Power = 1 Winterfall E'ko**), including retained legacy buff inference.
- Reworked legacy consumable reconstruction so old Items & Abilities rows that retained spell/name data but lost `itemID` are normalized back to their catalogued items before pricing. Repeated combat-log uses are reconciled by count instead of being blanket-deduplicated.
- Added Classic Era Chronoboon handling. The Supercharged Chronoboon aura now recovers a consumed **Chronoboon Displacer** when that is the only retained CLEU evidence, and missing Chronoboon uses are supplemented into legacy Items & Abilities. Live encounters also capture the aura fallback without double-counting a normal Charging cast.
- Added static Era mappings for the seven Winterspring Jujus plus Chronoboon/Supercharged Chronoboon use spells. Legacy backfill version is bumped again so 0.21.123-0.21.125 zero/partial snapshots are recalculated from the improved evidence.

## 0.21.125-beta

- Fixed legacy **Consumed** migration again: retained enemy elixir/flask/Juju/Zanza-style buff snapshots now contribute one inferred consumable to old encounters even when the original cast predates the fight or was never retained in `worldUsage`.
- Legacy reconstruction now merges `worldUsage`, retained combat-log casts, and retained consumable-buff evidence instead of stopping as soon as any old `worldUsage` table exists.
- Added TSM4 Classic-era (`TSMAPI_FOUR`) DBMarket support in addition to the newer `TSM_API` path, matching the market values visible in older/current Era TSM installs.
- Legacy pricing is delayed briefly after login and retried once before freezing, avoiding false zero/unpriced snapshots while TSM/Auctionator market data is still initializing.
- Reusable equipment is hard-excluded from consumable spend even when its name looks consumable; **Diamond Flask** is no longer counted as a consumed Flask.

## 0.21.124-beta

- Fixed the legacy **Consumed** backfill so it no longer depends exclusively on pre-existing `worldUsage` data. Older encounters now reconstruct consumable uses from their retained World PvP combat log, including catalogued consumable item casts and common spell reagents, then snapshot the player's current TSM DBMarket/Auctionator prices once and freeze them.
- Added a second-pass migration for the empty legacy snapshots created by 0.21.123, so users who already loaded that build are automatically retried instead of being stuck at `0c`.
- Enemy consumable buffs explicitly observed as gained during the fight can supplement missing cast records; buffs that were merely present at encounter start are intentionally not counted as spend.
- Improved legacy Consumed tooltip diagnostics to distinguish a recoverable zero-use combat log from encounters that predate retained combat-use evidence entirely.

## 0.21.123-beta

- Backfilled **Consumed** pricing for every pre-0.21.122 World PvP encounter that lacks a saved cost snapshot. Rivals takes one coherent snapshot of the player's current TSM DBMarket/Auctionator values at migration time, applies those captured values to retained legacy consumable events, and then freezes them permanently on each historical encounter.
- Legacy cost tooltips now explicitly identify the value as a one-time current-price snapshot rather than incorrectly claiming it was captured at the original encounter end.

## 0.21.122-beta

- Added an encounter-end **Consumed** estimate to World PvP Summary. The four primary tiles are now Enemy players, Consumed, Kills, and Killing blows; Honorable Kills remains secondary data outside this summary block.
- Consumable replacement cost is snapshotted permanently when the encounter ends. Rivals prefers TSM `DBMarket`, falls back to Auctionator, records the source on each item, and never reprices historical encounters.
- The Consumed mouseover groups spend by character and uses alternating item-row backgrounds for readability, with partial/unpriced disclosure when a detected consumable has no trustworthy market value.
- Expanded World PvP consumable accounting to include consumed item uses across tracked participants plus common combat reagents such as Flash Powder, Blinding Powder, Light Feathers, candles, Symbols, seeds, and Soul Shards. Zanzas use a snapshotted Hakkari Bijou replacement-cost proxy when the bind-on-pickup potion itself has no market price. Reusable equipment is excluded.

## 0.21.121-beta

- Hide the ENEMY BUFFS opponent selector entirely when no enemy in the encounter has retained buff data.
- Widen and align the selector with the BUFFS title and left edge of the icon grid.
- Added a five-column scrolling buff viewport: the first ten buffs remain visible in two rows, while larger aura sets scroll vertically with the same Blizzard track/thumb treatment used by OPPONENTS.

## 0.21.120-beta

- Increased the ENEMY BUFFS selector height again for better vertical balance.
- Rebuilt the open selector/menu chrome so it becomes one continuous Blizzard-style bordered control with no doubled seam or visual gap.
- Replaced the soft quest-row hover glow with an inset clipped highlight so hover feedback stays entirely inside its assigned opponent row.

## 0.21.119-beta

- Tightened the ENEMY BUFFS selector into the header: slightly taller control, smaller title gap, and a menu that begins directly on the selector's bottom edge.
- Switched the selector arrow to Blizzard's standard scroll-down button states and kept its native highlight visibly active on mouseover and while the menu is open.
- Reworked opponent identity rows so the class-colored name stays left-aligned while full race and con-colored enemy level stay right-aligned; removed the `Lv` prefix and race abbreviations.
- Reflowed observed buff icons left-to-right from the top-left in a five-column grid so five icons fit each row.

## 0.21.118-beta

- Fixed the ENEMY BUFFS runtime error caused by the selector label formatter being scoped inside the detail-window constructor instead of the shared refresh path.
- Reworked the multi-opponent buff header with a wider card/selector, more breathing room between the title, selector, and icons, and compact class-colored `Name Level Race` rows (for example `Mol 60 Gnome` / `Dendreavers 39 NElf`).
- Buff viewing now auto-selects the primary opponent when they have retained buffs; otherwise it prefers a buffed killing-blow/dead opponent, then any opponent with observed buffs, so useful aura data is shown immediately.
- Preserved manual opponent selection after the detail pane opens, including intentionally selecting an opponent with no observed buffs.

## 0.21.117-beta

- Rebuilt the Encounter header hierarchy so NvN is the largest line and the remaining synopsis is shown once without duplicated kill/result text.
- Renamed the aura card to ENEMY BUFFS, switching to ENEMY BUFFS REMOVED when the selected opponent died while tracked buffs were present.
- Replaced the custom BUFFS dropdown outline with Blizzard's thin slider-border asset and strengthened the native arrow hover/open highlight.
- Expanded the opponent selector to show class-colored names plus race and level, with race backfilled from GetPlayerInfoByGUID when available.
- Replaced the broken OPPONENTS up/down glyphs with the native History-style scrollbar track and thumb for 5+ opponents.

## 0.21.116-beta

- Enlarged opponent buff icons so four columns use the BUFFS card width, centered with equal left/right padding, and let the icon art extend fully beneath the border.
- Replaced the compact BUFFS selector's tiled tooltip edge with a uniform bronze rule border and made the Blizzard arrow highlight while hovered or while its menu is open.
- Enlarged the ENCOUNTER text treatment when space permits and promoted NvN/headcount text to Rivals gold for stronger hierarchy.
- Renamed Summary's OPPONENT RECORDS section to OPPONENTS.
- Simplified World PvP history-card result lines to preserve the encounter synopsis first and NvN second, leaving lower-priority stats to the clicked Summary instead of ellipsizing.

## 0.21.115-beta

- Restyled opponent buff icons with slim tooltip borders, full interior icon fill, and mouseover sweeps that finish once started.
- Replaced the BUFFS selector text glyph/global dropdown with a Blizzard-arrow compact selector and a perfectly aligned Rivals-owned menu using matching tooltip borders.
- Renamed Bubble-Hearth Escape to Bubble Hearthed throughout World PvP encounter presentation.
- Long-duration consumable buffs now use their source item tooltip in the buff viewer when Rivals can resolve the item.

## 0.21.114-beta

- Slimmed the multi-opponent BUFFS selector vertically while preserving its existing width.
- Reworked Encounter header copy into cleaner classification, outcome, result/duration, and headcount lines.
- Added slim bronze borders and a restrained hover sheen to opponent buff icons.
- Added Paladin Divine Shield -> Hearthstone detection and a dedicated Bubble-Hearth Escape outcome, including retroactive classification when an older encounter retained the required combat-log evidence.

## 0.21.113-beta

- Added primary-opponent relevance scoring for World PvP encounters. Kills/killing blows and sustained interaction now outrank incidental one-off AoE contact, so the encounter is named/defaulted to the opponent who actually defined the fight.
- Added mixed-level encounter presentation for fights containing both low-level and at-level/near-level enemies. Secondary lowbies remain recorded without hijacking the encounter identity.
- Added a meaningful-engagement display filter so a one-off incidental hit can remain encounter context without automatically inflating the displayed PvP headcount; details can show forms such as `1 vs 1 • 2 encountered`.
- Flipped the encounter header card back to LOCATION first with larger white location text. The LOCATION block takes only the height it needs, and ENCOUNTER dynamically consumes the remaining card space.
- Reworked ENCOUNTER details into a wrapped, adaptive-font block so mixed-level/type/outcome/headcount descriptions shrink as needed instead of truncating or clipping.
- Multi-opponent buff viewing now defaults to the primary opponent rather than alphabetical encounter order.

## 0.21.112-beta

- Reworked the World PvP encounter header: survival/death duration is condensed into the encounter result line, leaving the lower half of the Encounter card for Location.
- Added a BUFFS header to the opponent-aura card and moved the multi-opponent selector into that header row.
- Buff icons now form a right-to-left four-column grid beneath the header, dynamically sizing to keep the complete observed buff set inside the fixed-height card.
- Kept the BUFFS card fixed to the same top/bottom geometry as the Encounter card.

## 0.21.111-beta

- Fixed the standalone Duels/WPvP CharacterFrame tab briefly anchoring over Honor on the first Character pane open after `/reload`. The initial layout now falls back to the highest-index visible native tab when Blizzard tab coordinates are not ready, then rechecks the anchor on the next frame.

## 0.21.110-beta

- Reworked the World PvP encounter-detail header: battle survival and duration now share one compact result line, while Location moved into the bottom of the Encounter card with automatic font reduction for unusually long zone/subzone names.
- Replaced the redundant top-right Opponents list with an enemy-buff viewer. Buff icons fill from the top-right toward the left and wrap downward, and each icon exposes its normal spell tooltip on mouseover.
- Multi-enemy encounters now show a centered Blizzard-style opponent dropdown above the buff viewer; single-enemy encounters use the full buff-card height with no selector.
- Expanded enemy aura capture to retain every helpful buff Rivals can observe, including class/self buffs, blessings, protections, world buffs, elixirs, flasks, and similar long-lived effects.
- Kept short-duration consumable effects such as Free Action Potion and Limited Invulnerability Potion out of the buff viewer and in Items & Abilities; long-lived buff snapshots are no longer duplicated there.

## 0.21.109-beta

- Automatic Duel screenshots now fire only when the local player wins the duel.
- Losses, retreats where the local player loses, cancellations, unresolved duels, and stray result messages do not produce screenshots.
- Kept the result-message timing anchor and 0.20-second render delay so the victory message is visible in win captures.

## 0.21.108-beta

- Moved automatic Duel screenshots from `DUEL_FINISHED` to the localized duel-result system message, so the capture is anchored to the actual win/loss feedback shown by the client.
- Added a 0.20-second render delay after the duel result message so the “has defeated ... in a duel” text is visible in the screenshot.
- Kept cancelled/unresolved duels from producing screenshots and retained the existing screenshot toggle behavior.

## 0.21.107-beta

- Delayed automatic World PvP screenshots by 0.20 seconds after the lethal damage event so the Killing Blow / honorable-kill floating combat text has time to animate into the captured frame.
- Kept the lethal combat-log event as the timing anchor and retained PARTY_KILL / UNIT_DIED as deduplicated fallbacks when no lethal signal is available.

## 0.21.106-beta

- Moved automatic World PvP screenshots to the lethal damage combat-log event when an overkill/instakill signal is available, so capture is requested at the final floating-combat-text hit rather than waiting for PARTY_KILL / UNIT_DIED.
- Kept PARTY_KILL / UNIT_DIED as deduplicated fallbacks for deaths that do not expose an earlier lethal-damage signal.

## 0.21.105-beta

- Removed the redundant screenshot folder/filename note from the automatic screenshot checkbox tooltips.
- Restored the Rivals-only 2px close-button alignment so the red X sits correctly in the custom CharacterFrame chrome socket, while restoring Blizzard's original anchor whenever Rivals closes.
- Kept the combat-taint-safe independent Rivals tab architecture unchanged.

## 0.21.104-beta

- Replaced the Duel and World PvP screenshot toggle buttons in Manage with native-style checkboxes whose checked state is read directly from the saved settings.
- Removed the World PvP Tracking On/Off controls from Manage. Open-world PvP tracking is now always enabled, including for profiles that had previously saved it as disabled.
- Tightened the Manage layout after removing the obsolete tracking section.

## 0.21.103-beta

- Added independent Manage toggles for automatic Duel and World PvP screenshots.
- Duel screenshots fire when an active duel finishes; cancelled duel requests do not capture.
- World PvP screenshots fire once per tracked enemy death and deduplicate overlapping PARTY_KILL / UNIT_DIED signals.
- Screenshots use Blizzard's Screenshot API; the game controls the output folder and filename.

## 0.21.102-beta

- World PvP encounter details now reset to **Summary** after the detail pane is closed.
- The selected detail tab is still preserved when moving directly from one open encounter to another.

## 0.21.101-beta

- Fixed the native CharacterFrame tab remaining visually selected when the isolated Duels/WPvP Rivals tab is opened during combat. Rivals now applies the same visual-only native-tab deselection in combat that it already used out of combat.
- The combat path still leaves `CharacterFrame.selectedTab` untouched and does not call `PanelTemplates_SetTab()`, create `CharacterFrameTab6`, change `CharacterFrame.numTabs`, or register `RivalsCharacterPanel` in `CHARACTERFRAME_SUBFRAMES`.

## 0.21.100-beta

- Matched Blizzard's native CharacterFrame tab-label motion: the Rivals-owned Duels/WPvP label now rises 2px when selected and returns to the normal baseline when deselected.
- Kept the full-width overlay label and all combat-taint isolation unchanged.

## 0.21.99-beta

- The isolated Duels/WPvP CharacterFrame tab can now be opened while in combat when the Blizzard Character pane is already visible. Rivals no longer rejects the attached tab click merely because `InCombatLockdown()` is active; it still refuses to invoke Blizzard's protected CharacterFrame-opening path from addon code during combat.
- Moved the Rivals-owned Duels/WPvP tab label 2px upward to match the native Character/Reputation/Skills/Honor text baseline.
- Preserved the combat-taint isolation: no `CharacterFrameTab6`, no `CharacterFrame.numTabs` changes, and no `CHARACTERFRAME_SUBFRAMES` registration.

## 0.21.98-beta

- Fixed the independent Duels/WPvP CharacterFrame tab starting in Blizzard's selected/funnel visual state after a fresh `/reload`.
- The Rivals tab now explicitly initializes and re-shows as deselected unless the Rivals panel is actually active.
- Re-centered the Rivals-owned Duels/WPvP overlay label vertically while preserving the full readable text in the selected funnel state.
- Keeps the combat-taint isolation intact: no `CharacterFrameTab6`, no `CharacterFrame.numTabs` changes, and no `CHARACTERFRAME_SUBFRAMES` registration.

## 0.21.97-beta

- Fixed the isolated CharacterFrame launcher label still collapsing to `Du...` / `W...` when selected. The Rivals tab now keeps Blizzard's native selected-tab/funnel artwork but uses an addon-owned overlay label that is not constrained by the template's narrow selected-state text region.
- Kept the existing 64px tab geometry and native-row alignment so the readability fix does not reintroduce the previous right-edge protrusion.
- Preserved the combat-taint isolation: Rivals still never creates `CharacterFrameTab6`, changes `CharacterFrame.numTabs`, or joins `CHARACTERFRAME_SUBFRAMES`.

## 0.21.96-beta

- Fixed the isolated Rivals bottom tab still protruding past the CharacterFrame edge. It now follows Blizzard's own bottom-tab geometry by anchoring after the rightmost visible native Character tab with the standard 15px overlap instead of anchoring from the frame's right edge.
- Increased the Rivals tab's fixed absolute width from 56px to 64px so `Duels` and `WPvP` remain readable when the button is selected/disabled instead of collapsing to `...`.
- Preserved the combat-taint isolation: the Rivals button remains addon-owned and never becomes `CharacterFrameTab6`, changes `CharacterFrame.numTabs`, or joins `CHARACTERFRAME_SUBFRAMES`.

## 0.21.95-beta

- Fixed Blizzard Character/Reputation/etc. tabs losing mouseover/click behavior while the isolated Rivals pane was open. Rivals no longer places a cover button over the native selected tab; it visually deselects/re-enables that existing Blizzard tab while leaving `CharacterFrame.selectedTab` untouched.
- Fixed the Rivals bottom tab extending beyond the CharacterFrame and becoming cropped after switching Duels/World PvP overview modes. The tab now uses a compact fixed 56px width in a right-edge slot inset from the frame chrome, with its vertical baseline matched to the native tabs.
- Preserved the combat-taint fix: Rivals still does not create `CharacterFrameTab6`, modify `CharacterFrame.numTabs`, or join `CHARACTERFRAME_SUBFRAMES`.

## 0.21.94-beta

- Fixed the isolated Rivals CharacterFrame tab appearing oversized and extending past the right edge; its width is now explicitly 62px and it anchors after the last visible Blizzard tab instead of a hidden `CharacterFrameTab5`.
- Fixed the native Blizzard tab and Rivals tab both appearing selected at once. Rivals now masks only the visual selected state with its own mouse-transparent tab copy while leaving Blizzard's real `CharacterFrame.selectedTab` and native tabs untouched.
- Preserved the 0.21.93 combat-taint isolation: Rivals still does not create `CharacterFrameTab6`, change `CharacterFrame.numTabs`, or join `CHARACTERFRAME_SUBFRAMES`.

## 0.21.93-beta

- Fixed combat taint that could prevent the Blizzard Character pane from opening with `C` while in combat.
- Rivals no longer creates `CharacterFrameTab6`, changes `CharacterFrame.numTabs`, or appends `RivalsCharacterPanel` to `CHARACTERFRAME_SUBFRAMES`; the Rivals tab is now visually attached but managed independently.
- Removed Rivals' native CharacterFrame tab-resizing and portrait/close-button anchor rewrites, and moved Rivals chrome onto the Rivals-owned panel to reduce Blizzard-frame taint surface.
- `/rivals` profile-opening commands now use the isolated Rivals pane opener and refuse only the Rivals pane during combat, leaving the normal Blizzard Character pane available.

## 0.21.92-beta

- Fixed Encounter Details combat-log crashes when a SWING event stored a boolean in the CLEU payload slot normally used for spell names.
- World PvP logs now only persist spell ID/name metadata for actual SPELL_* and RANGE_* events, preventing swing damage/miss payloads from being misread as spells.
- Hardened combat-log rendering and class inference so older affected encounters remain viewable and malformed non-string spell names are ignored safely.

## 0.21.91-beta

- Replaced the previous promo rotation with fifteen new PvP-focused messages centered on server villains, rival scores, post-fight proof, rogue grudges, outnumbered victories, cooldown usage, repeat opponents, matchup history, Duel Rating, and long-term PvP records.
- Added the new cluster-focused opener and updated the 1vN promo to emphasize Rivals' victory fanfare and outnumbered-record tracking.
- Kept the user-provided promo wording intact and verified every message remains within WoW chat-length limits with the CurseForge link appended.

## 0.21.90-beta

- Replaced the previous promo rotation with eleven shorter, hook-first PvP promos built around revenge, rivalry history, proof, real 1vN recognition, matchup grudges, post-fight analysis, and duel records.
- Added an aggressive "Somebody's been camping you? Start keeping score." variant to the rotation.
- Kept the copy explicit about Rivals being a Classic Era PvP addon where the message could otherwise read like ordinary chat.
- Verified every promo remains within WoW chat-length limits with the CurseForge link appended.

## 0.21.89-beta

- Reworked all eight in-game promos around Rivals' strongest PvP hooks: keeping receipts, real solo 1vN detection, rival histories, encounter evidence, outnumbered records, and Duel Rating.
- Clarified in the promo copy that Rivals is a Classic Era PvP addon where the name alone could be ambiguous in chat.
- Kept every rotating promo within WoW chat-length limits when the CurseForge link is appended.

## 0.21.88-beta

- Distinguished Encounter header opponent tooltips from Opponent Records: header rows now focus on the current fight, while Opponent Records focus on lifetime World PvP history.
- Removed the redundant Encounter header tooltip and the development 1vN toast button.
- Changed map-coordinate tooltip formatting to standard `x, y` coordinates without percent signs.
- Removed redundant per-row `World PvP` labels from World PvP Matchups to prevent subtitle clipping.


- Duel Details and World PvP Encounter Details are now mutually exclusive: opening one closes the other so the windows cannot overlap.
- Applied the World PvP-style combat-log readability treatment to Duel Details: class-colored actors, white abilities, red damage, green healing, gold cast/interrupt emphasis, muted miss text, and class inference from opponent abilities when needed.
- Expanded Encounter Details tooltips with fight-specific and lifetime opponent stats, damage exchanged, observed casts/interrupts/dispels, detected buffs, zone history, encounter-end context, and clearer solo/outnumbered explanations.
- Reworked all four Summary metric tooltips to show useful supporting detail such as opponent lists, kill/Killing Blow attribution, pressure counts, KB share, and Honorable Kill vs tracked-death context.

## 0.21.59-beta

- Added a Manage-screen development button that previews the Solo 1vN result toast without creating an encounter or changing World PvP statistics.

## 0.21.58-beta

- Reworked the encounter card footer so survival state and duration are separated cleanly instead of crowding kill text together.
- Reformatted Location to use the available header area more deliberately, with larger adaptive zone text, separate subzone styling, wrapping for long names, and a full-location tooltip.
- Added subtle up/down scroll hints to Opponents and Opponent Records while keeping both lists free of visible scrollbars.
- Replaced row-sized wheel jumps with smooth interpolated scrolling for both opponent lists; hovering an opponent row/card also preserves wheel scrolling.
- Removed the redundant World PvP History row tooltip and explicitly dismisses any tooltip when opening encounter details.
- Added contextual tooltips to the encounter card, map, location, summary metrics, encounter context, header opponent rows, and Opponent Records cards.
- Improved Summary context duration formatting to use readable minute/second values.

## 0.21.55-beta

- Moved enemy world-buff/consumable presentation entirely into Items & Abilities; Opponent Records no longer show WB/C counts or buff hover details.
- Reworked the encounter header into map/result/intel cards so Location and Opponents use the header space more deliberately.
- Items & Abilities now reads more like a dataframe with neutral alternating row shading beneath the gold section separators and a header aligned to the data width.
- Fixed detected World Buffs / Consumable Buffs ordering so those sections sort predictably with the rest of the usage dataframe.
- Increased internal spacing in Opponent Records cards so the record line no longer crowds the bottom border.

## 0.21.54-beta

- Added enemy buff intelligence for World PvP encounters. Rivals snapshots observable enemy helpful auras from target, mouseover, focus, and nameplates and continues watching aura changes during the fight.
- Tracks Classic world buffs separately from consumable buffs, including Dragonslayer, Warchief's Blessing, Spirit of Zandalar, Songflower, Dire Maul tribute buffs, Sayge fortunes, and Traces of Silithyst.
- Long-duration consumable auras are matched against the existing Usage Catalog, so flasks, elixirs, Free Action/LIP-style buffs, Juju/Zanza effects, Blasted Lands buffs, Firewater, and other detected consumables can be retained even when their original cast happened before the encounter.
- Opponent Records now show compact `WB` / `C` detection counts and expose the full detected buff list on mouseover.
- Items & Abilities now includes World Buffs Detected and Consumable Buffs Detected sections for pre-existing/observed enemy buffs.
- Added `UNIT_AURA` observation and combat-log aura apply/refresh/remove support without claiming unseen buffs were absent.

## 0.21.47-beta

- Replaced the centered dot on Most Killed with a compact `×N` kill-count treatment (for example, `Victors ×4`).
- Nemesis now shows only the rival name at a glance; the number of times they killed you is available on mouseover instead.
- Clarified Most Killed and Nemesis tooltips with separate kill/death lines.

## 0.21.46-beta

- World PvP encounters now use actual combat-state boundaries: leaving combat starts a 10-second continuity grace, a different opponent starts a new encounter immediately, and the same opponent can still resume within the grace for Classic combat-drop quirks.
- Kept the old 60-second inactivity timer only as a safety fallback, preventing sequential bot/player streams from accumulating into impossible long-running headcounts such as 22v38.
- World PvP chat headcounts now use the same contested/overlap model as History and Solo 1vN instead of raw unique participants.
- Fixed World PvP streaks to count consecutive player kills and reset only on player death; harmless disengages no longer reset the streak.
- Zone labels now prefer the player's actual zone text over continent-level map names. Existing continent-labeled records use a retained subzone as a non-destructive Favorite Zone fallback when possible.

## 0.21.45-beta

- Removed the optional Spy integration.
- Most Killed and Nemesis once again use Rivals World PvP encounter history only.
- Removed Spy as an optional dependency and restored the original rivalry-stat tooltips.

## 0.21.44-beta

- Added optional Spy integration for World PvP Most Killed and Nemesis statistics.
- Spy history is preferred when available; Rivals remains the fallback.
- Stat tooltips show the active data source and Rivals' locally recorded count for comparison.
- Added Spy as an optional dependency so its per-character PvP ledger is available when installed.

## 0.21.43-beta

- Align Duel and World PvP paired stat slabs to the main plaque edges.
- Restore the Overview Lifetime dropdown to the Prefer Rated baseline.
- Rebuild the World PvP 2x2 rundown as a raised plaque with balanced quadrants.
- Re-space the World PvP footer and Manage button.

## 0.21.43-beta

- Rebalanced the World PvP Overview lower stats into a centered four-quadrant plaque.
- Matched Duel Rating paired-stat slabs to World PvP geometry.
- Tinted paired-slab dividers to the bronze header-plaque trim.
- Improved World PvP matchup-detail record-count and footer spacing.

## 0.21.43-beta

- Reworked the World PvP Overview card around kills, streaks, solo/outnumbered accomplishments, honorable kills, and gank stats; deaths move to the card tooltip.
- Removed the Recent Encounters blip strip and redundant World History Overview button.
- Added max-level GANK and 5+ level-disparity LOWBIE GANK classification, with opponent level capture from target/mouseover/nameplates when available.
- World PvP History rows now lead with opponent name, class, and observed level.
- Character pane tab now follows the saved Overview mode: Duels or WPvP.
- Reduced the encounter-map raid X size.
- Added a framed Combat Log region and filled unused Summary space with persistent rivalry/context panels.
- Tightened the Overview carousel clip to the Character pane interior border and removed mid-swipe crossfading for a cleaner push animation.

## 0.21.43-beta

- Refactored the Character/History/Matchups refresh renderer to keep Classic Era below Lua's upvalue limit.
- No intended UI or World PvP behavior changes.

## 0.21.43-beta

- World PvP maps: rebuilt the encounter marker as a fixed viewport child, explicitly binds Blizzard's raid-target icon sheet before selecting Cross (7), raises it above the ScrollFrame, and clamps it inside the crop so the red X remains visible even near zone edges.
- World PvP Overview: expanded the main card to spell out Kills/Deaths, added encounter and unique-rival counts, and reorganized the lower statistics around streaks, honorable kills, and rivals.
- World PvP Matchups: rebuilt nested matchup-detail layout so the rivalry header, back control, and encounter rows have dedicated vertical space instead of overlapping.
- Overview carousel: changed the swipe to a 0.26s smoothstep transition with a light crossfade, tighter paginator dots, and a short post-settle delay before the selected card's lightsweep.

## 0.21.43-beta

- World PvP: passive ganks are now labeled neutrally as `1 KILL` / `N KILLS` instead of `VICTORY` or `SURVIVED`; a 1v1 Victory now requires observed hostile pressure from the opponent.
- World PvP maps: changed History and Details to a consistent 3.25x local crop around the recorded terminal kill/death position.
- World PvP maps: moved the encounter marker to a dedicated overlay and now use Blizzard's raid-target Cross helper for a reliable red X above all map layers.
- World PvP History: prevented the timestamp/location line from wrapping outside its encounter card.
- World PvP details: headcount copy now distinguishes simultaneous contested fights from multiple enemy players encountered sequentially.

## 0.21.43-beta

- Tightened Outnumbered Victory recognition: unique enemy names no longer imply a 1v2+. Rivals now requires two or more enemy players to apply overlapping hostile pressure to the player, and full Outnumbered Victory requires every contesting enemy to die while the player survives. Saved 0.21.x encounters are reclassified on load when their stored combat log contains enough pressure evidence.
- Passive/sequential ganks no longer add Solo 1v1 or Outnumbered accomplishments; the long 60-second CC/disengage timeout remains, while already-dead enemy chains settle after a shorter 6-second grace period.
- Encounter locations now prefer the terminal kill/death position so the map marker represents the decisive fight location instead of an averaged travel path.
- Moved the red X raid marker onto the visible map viewport, above the explored-map layers, with a dark offset shadow so it cannot disappear behind the scrolled map canvas.
- Added the same gold diagonal light sweep used by Duel Rating to the World PvP card.
- Added a ten-encounter Recent strip to the World PvP card so the main card has useful visual history instead of an empty lower band.
- Fixed the Overview paginator so selected/unselected dots keep identical font size and baseline, and tightened their spacing.

## 0.21.43-beta

- Changed World PvP map thumbnails to aspect-preserving cover crops centered on the recorded encounter location, eliminating letterboxing while keeping the fight marker meaningful.
- Replaced the gold plus encounter marker with Blizzard's red X raid-target marker.
- Inset Encounter Details scroll regions so Blizzard scroll controls stay fully inside the fixed details frame.
- Reworked the Summary tab into a denser encounter/rivalry readout with metric cards and per-enemy lifetime World PvP records.
- History now defaults to `All encounters` when the Rivals pane is opened.
- Matchups now defaults to Duel or World PvP based on the currently selected Overview carousel page whenever the top-level Matchups tab is opened.

## 0.21.43-beta

- Fixed World PvP encounter maps so they composite Blizzard's explored-area textures over the fogged base map, matching the character's actual World Map exploration state.
- Encounter Details now keeps a fixed outer window size across Summary, Items & Abilities, and Combat Log. The usage dataframe still sizes to its actual contents inside that fixed pane.

## 0.21.43-beta

- Centered the Overview paginator on the actual Duel Rating / World PvP card rather than the wider Overview frame.
- Made both page dots true cycle controls: clicking the illuminated dot advances to the other page, while clicking the unlit dot selects its page; repeatedly clicking either physical dot cycles the carousel.
- Changed post-encounter notifications to notable-only. Routine 1v1s, deaths, trades, group fights and disengages are recorded without a center-screen plaque.
- Reserved the World PvP result plaque for solo 1v2+ successes: Outnumbered Victories and kill-and-escape Outnumbered Escapes.

## 0.21.43-beta

- Rebuilt the Duel/World Overview swipe inside a clipped ScrollFrame viewport so moving page content cannot bleed outside the Rivals pane.
- Made Prefer Rated and the Overview Lifetime/Season dropdown true children of the Duel page, so they travel with Duel Rating instead of popping off/on after a swipe.
- Split the Overview period dropdown from the shared History/Matchups period control to avoid reparenting native Blizzard dropdowns between views.
- Removed page-dot tooltips, tightened the two-dot paginator styling, and kept it stationary between the rating card and stat slabs.
- Added a swipe interaction shield and shortened/eased the transition so outgoing controls cannot be clicked mid-animation.
- Preserved the selected Duel/World Overview page across closing the Character pane and reloads.

## 0.21.43-beta

- Cleaned up the World PvP Overview: Duel-only `Prefer Rated` and `Lifetime` controls are hidden while the World PvP page is selected.
- Moved the Duel/World page dots into the gutter directly below the main rating card so they no longer crowd the placement progress bars.
- Restored the Duel placement bars to their original vertical position.
- Switching between Duel Rating and World PvP now refreshes the shared Overview controls immediately.

## 0.21.43-beta

### Overview navigation

- Replaced the large Duels / World PvP Overview tabs with a two-dot page indicator centered at the bottom of the rating card; the illuminated dot marks the active page.
- World PvP now occupies the same Overview geometry as Duel Rating instead of opening as an opaque pane over it.
- Switching between Duel Rating and World PvP uses a short left/right horizontal swipe.
- The rating-card plaque changes from `Duel Rating` to `World PvP` with the selected page.
- The selected Overview page is saved in RivalsDB and survives closing/reopening the Character pane and UI reloads.

## 0.21.43-beta

### World PvP

- Added automatic open-world PvP encounter tracking without changing Duel Rating or Rated/Casual duel rules.
- Encounters remain active through long Classic Era resets and crowd control, closing after 60 seconds without PvP activity; terminal kill/death states settle after a shorter grace period for follow-up actions.
- Added explicit player-participation headcounts and special recognition for successful solo 1v2+ fights, including Outnumbered Victory, Outnumbered Escape, partial outnumbered fights, trades, deaths and disengages.
- Added location capture with Blizzard zone-map art and an encounter marker in World PvP History cards and encounter details.
- Added World PvP summaries for kills/deaths, solo 1v1 record, honorable kills, streaks, outnumbered victories and largest outnumbered win.
- Added persistent World PvP opponent/class matchup records and target-tooltip rivalry summaries.
- Reused Rivals combat evidence to infer specs independently for each enemy in an encounter without carrying combat-inferred specs across later fights.
- Added a short post-fight result plaque, with longer emphasis for Outnumbered Victories.

### Interface

- Kept the existing Overview / History / Matchups / Rivals top navigation; World PvP is folded into those views rather than added as a fifth top-level tab.
- Added Duels / World PvP context tabs inside Overview.
- Added All encounters / Duels / World PvP filtering to History; mixed History interleaves duel and World PvP records chronologically.
- Added Duel matchups / World PvP source selection to Matchups while preserving the existing Opponents / Classes tabs.
- Added World PvP tracking On/Off controls to Manage; tracking is enabled by default.
- Added a dedicated World PvP encounter-details presentation with Summary, Items & Abilities and Combat Log tabs.
- Reworked multi-participant item/ability usage into a vertical Time / Player / Used / Target dataframe grouped by meaningful categories. Empty categories are omitted, participants can be filtered, and the frame grows only to the content limit before scrolling.

### Validation

- Parsed every Lua file successfully after integration.
- Added a combat-log smoke test confirming a simulated solo 1v2 with two enemy deaths is stored as an Outnumbered Victory with correct headcount, kill totals, summary statistics and opponent aggregates.

## 0.20.0-beta

### Interface and animations

- Updated Inspect Duel Rating to match Overview's Zurk Maps-style header plaque, taller rating card, beveled stat cards, and spacing; moved the Inspect content up 5px.
- Added a narrow diagonal light sweep when opening Overview.
- Added independent completion highlights for 10 eligible duels and 5 distinct opponents, lighting only each section's text and progress blips.
- Added a one-time Provisional-to-Established celebration on the first Overview opening after qualifying: the card darkens, Provisional rumbles, and a light burst reveals Established.
- The promotion text grows and settles into its normal position, with five evenly spaced Zurk Maps-style glows that remain for one second after settling.
- Used a rendered text texture during resizing, then blended back to the native status label to keep the promotion aligned and smooth.
- Preserved interrupted promotion playback for the next opening and removed the development preview button.
- Reworked History duel usage into a three-column Category / You / Rival table; the mouseover now sizes itself to the longest displayed item or ability while Duel Details remains fixed-width.
- Replaced the Duel Details title rectangle with the exact Zurk Maps / Duel Rating plaque construction and inset the rock background so it stays inside the outer frame corners.
- Renamed Potions to Potions/Consumables and Engineering Gizmos to Engineering Gadgets, and lowered tracked long cooldowns from 10 minutes to 3 minutes.
- Added persistent per-duel combat-log tabs to Duel Details for My actions and What happened to me.

### Fixes

- Prevented opposite-faction targets from triggering recovery whispers and duel-verification handshakes that could produce misleading player-not-found messages.
- Blocked unavailable Inspect profile requests without incorrectly reporting that the other player lacks Rivals.

### Validation

- Expanded regression checks for completion highlights, promotion timing and alignment, replay handling, faction-aware messaging, three-minute cooldown capture, and duel combat-log persistence.
- Passed the full Lua 5.1 and mocked-client regression suite.

## 0.19.0-beta

### Rating protection

- Added level-disparity penalties: rewards halve for every two levels of winner advantage and reach zero at a ten-level gap. Unknown levels cannot award rating.
- Added diminishing returns after eight consecutive Rated wins against the same opponent: wins 9–11 receive 50%, 25%, and 12.5%; win 12 onward receives zero.
- Added rolling seven-day limits of 12 rewarded wins and 64 gross overall rating points per opponent. Losses do not refund these budgets.
- Preserved opponent history and guard counters independently of the visible profile cache. Seasons inherit lifetime protections.
- Prevented retreat wins, wins under five seconds, and newly accepted peer-recovered results from awarding rating or placement credit. Results remain in history; otherwise eligible retreat and short-duel losses still cost rating.
- Added explanations for protection decisions to History tooltips. Existing results retain their original rating calculations.

### Interface

- Added a compact, normal-case “Duel Rating” header plaque attached to the rating card.
- Refined Overview spacing, including the status, counters, and progress blips.
- Replaced the shared stat-box background with mirrored beveled slabs, masked interiors, and a plain center divider.
- Widened the Lifetime dropdown to mirror the Prefer Rated button.
- Refined close-button alignment while preserving the matching frame textures and other tabs' button positions.
- Added the Zurk-style Rivals icon to the in-game addon selection menu.
- Confirmed the sharing button uses https://www.curseforge.com/wow/addons/rivals.

### Validation

- Expanded regression coverage for rating protections and UI behavior.
- Updated documentation with protection rules, limitations, and possible future anti-boosting measures.

## 0.18.7-beta

- Updated the README with current features, installation instructions, commands, and data limitations; refreshed UI test fixtures for the current layout and Inspect presence protocol.
- Shifted the Inspect Duels layout upward to use the previously empty header space.
- Matchup headings now use normal case and switch to “Your matchups” after a prior recorded duel.
- Added an addon-presence acknowledgement so sharing-off can be distinguished from no Rivals response.
- If Rivals is not detected on the inspected player, the Duels tab collapses to a single button that whispers the CurseForge Rivals link.

# 0.18.0-beta

- Replace the Lifetime/Season and History mode cycle buttons with native Blizzard drop-down menus using `UIDropDownMenuTemplate`, including checked current selections and the stock in-game arrow/menu artwork.
- Keep the period drop-down in one consistent top-right slot across History and Matchups while preserving the Overview/Details/Graph placement.
- Give Inspect > Duels another visual pass: mirror the owner Overview geometry more closely, add a dedicated class-colored YOUR MATCHUP card, and split your local record/estimate into matching tiles.
- Add current streak and best win streak tiles to inspected Rival profiles while keeping the self-reported/verification caveat in a muted footer.
- Preserve default-on profile sharing, joined On/Off controls, contiguous Opponents/Classes controls, and Matchups-local drilldowns from 0.17.0.

# 0.17.0-beta

- Make shared profile summaries enabled by default while preserving an explicit saved opt-out; add a Profile Sharing On/Off segmented toggle to the new Manage screen.
- Rebuild the Inspect > Duels profile view to mirror the owner Overview: rating card, placement progress, rated record, personal best, and your local matchup against the inspected player.
- Align the Lifetime/Season cycle control to the same top-right position on History and Matchups; add a visible chevron affordance to cycle controls.
- Turn Opponents / Classes into a contiguous segmented Matchups selector.
- Keep opponent/class drilldowns inside Matchups with a dedicated detail view and back control instead of switching the active tab to History.

# 0.16.0-beta

- Reveal queued placement gains as sequential whole-blip pops with a brief expansion and sheen, rather than a horizontal fill. Both categories retain catch-up and interrupted-view handling.
- Count each rating-eligible duel as one placement, including eligible repeat-limited duels. Keep opponent diversity requirements and Elo repeat weights unchanged.
- Rebuild integer placement counts from saved history for Lifetime, seasons and class matchups. Update progress, qualification, details and shared-profile presentation to whole placements.
- Tests cover repeat-weight separation, replay and sequential all-or-nothing reveals.

# 0.15.6-beta

- Queue unviewed placement progress per character and period, including across reloads.
- Reveal accumulated duel/opponent progress only on visible Overview, with a short anticipation pause, coordinated sequential fill and stronger closing sheen.
- Scale catch-up duration with progress gained; closing early preserves the pending reveal. Completed progress does not replay.
- Seed pre-existing records as viewed on upgrade. Tests cover hidden gains, opening, interruption, completion and repeated refresh.

# 0.15.5-beta

- Restore equal horizontal spans for ten duel sockets and five wider opponent sockets, keeping exact pixel gaps in both rows.
- Add bronze chamfered rims and dark inner bevels for a Warcraft-style recessed socket; preserve animated blue/violet raised fills.
- Balance row centers and outer margins within the rating card, raising labels and slots slightly for bottom breathing room.

# 0.15.4-beta

- Replace flat placement marks with identical rectangular recessed sockets, aligned to a shared physical-pixel grid using the Zurk Maps border approach.
- Use blue/violet beveled fills, including fractional effective-duel credit. Center both groups under their existing labels.
- Animate new visible progress over 0.55 seconds with an eased fill and brief sheen. Initial display, period changes and unchanged refreshes do not replay animations; hiding stops active updates.
- Add regression checks for matching sizes/gaps, fractional fill, animation completion and replay prevention.

# 0.15.3-beta

- Rename the addon and user-facing commands from the development name to **Rivals**, including the addon folder, TOC, SavedVariables namespace, UI globals, Inspect panel and addon-message prefixes.
- Add the RIVALS relief wordmark to the native Character pane header. The texture contains only engraved edge shading so the Blizzard stone pane remains visible through the carving.
- Remove redundant rating-value, client-confirmation and agreement wording from History tooltips; capitalize mode values.
- Display rating changes in separate labeled blocks with muted previous values, bright new values and colored signed deltas in parentheses.
- Rephrase repeat count as the duel number against this opponent within 24 hours.
- Apply known class colors to tooltip opponent names and localized matchup class names.

# 0.15.2-beta

- Fix combat-log handler referencing initialization-local `player`: use the live player GUID and skip processing without an active session.
- Add actual event-dispatch coverage for idle combat and a successful long-cooldown cast persisted on the duel result.

# 0.15.1-beta

- Sort opponent and class matchups by most recent duel, with deterministic ties.
- Add distinct History tooltip sections for duel summary, rating changes and item/long-cooldown usage. Display N/A for missing usage.
- Move general verification/coverage caveats into muted History/Matchups footers.
- Increase left padding and lower row subtext; reserve footer space below the five visible records.
- Automated checks include recency over duel count and existing usage/rating behavior.

# 0.15.0-beta

- Use a narrow scrollbar thumb with dedicated clearance outside history rows.
- Center separate progress labels over their own blip groups, remove redundant decimal zeroes, and raise progress/status content to leave bottom padding.
- Begin local observation of successful item-use casts and abilities with base cooldowns of at least 10 minutes during matched duels. Save counts by participant on the original record and show them in History tooltips.
- Item recognition uses item-spell IDs discovered from carried/equipped items. No inference from ordinary ability names, proc auras, failed casts or bystander actions. Coverage is partial, particularly for unfamiliar opponent items or unavailable base cooldowns.
- Existing and peer-recovered records do not gain invented usage data. Collection does not affect ratings or verification. Tooltip lists are bounded; complete counts remain saved on the record.
- Automated tests cover threshold, actor and duel-time gates, counting and older records; in-game item/cooldown capture still needs validation.

# 0.14.8-beta

- Trim four UI units from the navigation/background right edge while preserving its flush left edge.
- Restore down/up button artwork and a subtle one-unit pressed label movement; active selection remains gold text and underline.
- Offset the portrait one unit right/down while Duels is open, restoring its original anchors on exit.

# 0.14.7-beta

- Mark active navigation with gold text and an overlay underline, leaving normal mouse press/release behavior unlocked.
- Extend navigation and its background four UI units on each side to meet the interior edges.
- Draw window chrome on the BORDER layer above the native BACKGROUND portrait, allowing its circular rim to frame the portrait correctly without changing its size or position.
- Automated navigation checks cover unlocked selection; in-game appearance requires reload.

# 0.14.6-beta

- Lower the Overview rating number by 4 UI units from its original position; remove the decorative divider beneath it and preserve the placement progress blips.

- Remove the custom chrome offset so the portrait surround aligns with native CharacterFrame coordinates, preserving the native portrait size.
- Vertically center the record, personal-best and recent-status text within their full card bounds.
- Strengthen DUEL RATING with larger warm-gold lettering and balanced ornamental rules.
- Keep button text at the same position when pressed; selection shading remains.
- Automated Lua checks cover chrome origin and zero pressed-text offset; visual confirmation requires reload.

# 0.14.5-beta

- Center all interior content on the background midpoint; fill the full interior width with the top navigation bar.
- Keep the selected tab pressed and release inactive tabs while retaining normal behavior for other controls.
- Pair History's mode and period filters; use centered headings and framed empty states with guidance.
- Replace the wide Matchups toggle with explicit Opponents/Classes controls and move its period selector to the footer.
- Separate record counts from footer controls and color History outcomes for scanning.
- Automated Lua checks pass, including selected/inactive navigation and matchup switching. In-game rendering remains a manual check.

# 0.14.4-beta

- Center DUEL RATING and the divider between the record/personal-best cards.
- Give the rating card a symmetrical double gold border, shaded blue field and centered ornament; remove the red faction stripe.
- Preserve button end-cap widths instead of stretching their borders. Keep the history filter compact.
- Keep selected navigation buttons enabled and release their pressed state; selection uses the gold indicator.
- Match Manage's Overview button to Graph/Details in size and position, with explanatory text above the footer.
- Automated Lua checks pass, including repeated navigation clicks and back-button alignment. In-game appearance requires reload.

# 0.14.3-beta

- Restore the Classic window border and portrait surround removed in 0.14.2. Attach chrome to the CharacterFrame background layer so it stays behind the native portrait/title, and show it only while Duels is selected.
- Preserve the redesigned interior. Regression checks cover chrome visibility when switching native tabs; live rendering requires reload.

# 0.14.2-beta

- Remove duplicate full-frame artwork that covered the native portrait and title; restrict the custom background to the pane interior.
- Use warm tooltip-style borders inspired by Zurk Maps celebrations, textured buttons, and full-width control groups.
- Align period selection with list headings; separate filters and empty states. Add Overview navigation to Manage and keep its footer clear of record counts.
- Color known opponent/class names by class. Align ratings on the right of opponent, class and shared-profile rows.
- Add bordered Overview sections and a compact two-column Record details view. Record details opens on click; Graph has an Overview button.
- Preserve rating, verification and recovery behavior; automated Lua regression checks cover navigation, empty-state spacing and class colors. Live rendering still requires an in-game reload.

# 0.14.0-beta

- Replace red interior controls with a consistent slate/gold theme and selected-navigation underline.
- Move navigation below the portrait, period selection into a dedicated toolbar, and mode preference onto Overview.
- Compose Overview into a rating card, aligned Rated record/personal-best band and recent-result section.
- Replace list pagination with mouse-wheel/scrollbar browsing. Keep fixed-size row pooling, aligned history deltas and compact mode/evidence labels.
- Restyle graph grid/markers and Inspect/recovery actions. Automated scrolling and existing behavior checks pass; in-game visual verification remains.

# 0.13.0-beta

- Simplify Overview to rating, Rated record, peak and recent result. Move detailed mode totals, placements and matchup summary to Record details.
- Consolidate navigation into Overview, History, Matchups and Profiles. Matchups switches between opponents/classes; existing slash commands remain compatible.
- Move recovery access to Overview > Manage. Remove the recovery button from normal History.
- Preserve all rating rules and saved records. This is the first layout cleanup pass; the in-game appearance has not yet been verified.

# 0.12.2-beta

- Rename mode preference to Prefer Rated/Prefer Casual and disable changes during an active duel.
- Show live agreement state on Overview and explain failed agreement using saved failure details in Overview, history tooltips and chat.
- Keep recovery request status visible with populated lists; use four rows in Interrupted to preserve spacing.
- No changes to Darkmoon Faire behavior or game input handling.

# 0.12.1-beta

- Add Interrupted > Accepted with acceptance time and original net lifetime impact when available.
- Preview and undo acceptance, replaying current ratings and restoring the original report for later review. Record IDs are never reused.
- Preserve acceptance/undo audit events with timestamp and before/after lifetime rating; include them in diagnostic exports.
- Bundle installation instructions and beta test checklist. Undo has automated coverage; in-game validation remains.

# 0.12.0

- Click a peer-reported Interrupted entry to review its net lifetime rating effect and explicitly apply it locally.
- Insert accepted results at their historical timestamp and replay ratings, repeat weighting and assigned seasons. Refresh stored rating decisions for later results.
- Keep accepted records labeled Peer report; never forward them as independently observed results or fabricate duration. Missing saved season assignment means lifetime-only.
- Block application during an active duel and reject duplicate, unresolved or conflicting reports. Network receipt alone never changes rating.

# 0.11.4

- Allow a matching active opponent's hello to supply missing identity and start the handshake before target-based detection.
- Retain bounded verification and blocked-addon diagnostics even when general tracing is off; record mode-lock inputs.
- The intermittent live agreement failure remains under investigation; this build adds evidence and covers late identity acquisition.

# 0.11.3

- Retry handshake/mode exchange before duel start without changing the selected preference or permitting late agreement.
- Show recovery status when hovering or clicking Retry even with recovered entries already listed.
- Skip verification sends to a visibly disconnected opponent and stop further retries after a matching server offline error.

# 0.11.2

- Show recovery request, cooldown, missing-target and timeout status in the empty Interrupted view.
- Reply explicitly when no recoverable handshake-linked results exist, instead of silently returning nothing.

# 0.11.1

- Stop recovery whispers to saved historical opponents, which caused offline-player errors in chat. Resolve only the current connected player target at send time.

# 0.11.0

- Persist peer handshake tokens and retain saved interrupted sessions as unresolved entries.
- Request recent participant-specific results on reconnect or manual retry, including when a hard close lost local pending state.
- Add History > Interrupted for clearly labeled peer-reported outcomes; preserve local rating and record calculations.
- Bound recovery traffic and retention; reject unsolicited/mismatched reports and suppress duplicate or already observed results.
- Test saved and missing pending state, repeated recovery after reload, sender validation and timeouts.

# 0.10.0

- Cycle History between All, Rated, Casual, Unconfirmed and Legacy, including opponent/class histories.
- Show Rated/Casual records on opponent and class rows, with all mode totals in tooltips.
- Add Established-only and Clear-cache leaderboard controls. Clearing shared profiles preserves duel records, ratings and the live self entry.
- Check filtering, pagination and cache isolation alongside existing cancellation, timeout and lost-message regression coverage.

# 0.9.1

- Raise the shared list footer to clear the bottom frame border in History, Opponents, Classes and Leaderboard.

# 0.9.0

- Label history by Rated, Casual, Unconfirmed, or Legacy while preserving independent outcome evidence.
- Separate overview mode totals and show remaining placement requirements without changing ratings or historical results.
- Add a local leaderboard of opt-in Inspect lifetime summaries, with provisional labels, receipt timestamps, seven-day expiry and a 100-profile bound. No automatic broadcasting or realm-wide ranking.
- Add regression checks for mode totals, legacy handling, placement deficits, shared-profile sorting, expiry and unsolicited-response rejection.

# 0.8.0

- Added Rated/Casual preference beside the period selector and via slash commands.
- Negotiate preferences during the pre-duel handshake; lock at the observed start. Missing agreement falls back to Casual.
- Added lifetime/seasonal expected-impact previews and agreement notices during countdown.
- New records preserve mode under rating model 3. Casual remains in records without affecting ratings, placements or rating-eligible repeat counts.
- Old records retain their existing rating rules; result confirmation remains independent of rating application.
- Added mode-negotiation and eligibility regression tests. Both clients require 0.8.0 for Rated agreement.

# 0.7.1

- Fixed asymmetric handshake setup when the second client starts after the first client's initial hello retries. A matching hello now restarts the missing half of the exchange.
- Retry opponent identity resolution on countdown messages.
- Added handshake/send/receive/transport diagnostics to opt-in traces and local-only reasons to history hover/export.
- Added a delayed-peer regression test confirming both clients reach agreement. Live cause of the reported 0.7.0 failure still needs the new trace if it persists.

# 0.7.0

- Added session handshake and independent duel-result reports between the two participants.
- History and export distinguish Confirmed by both clients, Local only and Disputed outcomes.
- Added bounded retries, sender/identity/session correlation, disagreement retention and cancellation cleanup.
- Result exchange defaults on and can be disabled with `/rivals verify off`, independently of profile sharing.
- Evidence changes never alter local results or apply rating twice. Prior saved duels remain local unless already confirmed.
- Added two-client simulation tests; live protocol validation remains pending.

# 0.6.0

- Added an in-pane rating graph with hover points and a bounded recent-duel window.
- Added lifetime/season selection across profile views, history and graphs.
- Added manually started numbered seasons (`/rivals season start`) with archived periods preserved.
- Seasonal overall/class ratings and placements restart independently while lifetime continues. Repeat limits carry across all seasons.
- Active duel sessions block season creation; ordered journal replay rebuilds both projections after reload.
- Export and notifications distinguish seasonal and lifetime changes. Inspect remains a lifetime profile.
- Regression tests cover season transitions, replay, cross-season repeat limits and graph/view behavior.

# 0.5.0

- Added independent per-class Elo with reciprocal opponent matchup estimates and the existing repeat-opponent multiplier.
- New records snapshot both classes; older records retain their overall ratings and W/L without retroactive class rating changes.
- Classes displays matchup rating/status; hover shows placement progress toward 10 effective duels against 3 opponents.
- History hover/export includes per-duel matchup changes. Overall Elo remains unchanged.
- Overview adds sample-gated best/worst class win-rate summaries, with explicit most-tested/tied states.
- Lua 5.1 tests cover mixed-version replay, reciprocal transfers, sample thresholds, repeat limits and unknown classes.

# 0.4.1

- Fixed the duplicate/oversized border and portrait artwork in Inspect > Duels by using the native Inspect frame with an inset background.
- Centered profile content and anchored the refresh button/footer inside the Inspect window.
- Added player tooltip records for known opponents: your W/L, local rating estimate with sample count, and last duel. Hovering does not send addon messages.
- Added regression coverage for the single inset background, tooltip duplicate protection and no-network behavior. Existing rating and communication tests continue to pass.

# 0.4.0

- Added Duels after Honor in the normal player Inspect window.
- Shows your local record/estimate separately from a requested self-reported profile summary.
- Added opt-in summary sharing (`/rivals share on`, off by default), bounded addon whisper packets, request correlation and throttling.
- Missing replies display an unavailable/timeout state. Changing inspected players discards pending and displayed remote data.
- Remote summaries never alter rating history. Detailed remote history is not transmitted in this release.
- Automated protocol and Inspect-tab contract tests added; live two-client validation remains pending.

# 0.3.0

- Added Overview, History, Opponents and Classes navigation inside Character > Duels.
- Added five-row paging, newest-first history and hover details for rating impact, repeat value and estimated duration.
- Opponent and class rows open filtered history, with an All history action to clear the filter.
- Match history and history/opponents/classes slash commands now open the corresponding in-pane view. Diagnostic export remains available separately.
- Corrected singular win/loss wording. Existing rating calculations and saved records are unchanged.
- Lua 5.1 regression and mocked UI navigation tests pass; new views await in-game visual validation.

# 0.2.0

- Added the Duels tab immediately after Honor in the Character pane, with local rating, record, streaks, peak, placements and last result.
- Added local Elo from 1500, updating both participants' estimates in the observer's database.
- Added rolling 24-hour repeat-opponent weights, effective-match placements and opponent diversity requirements.
- Added W/L, opponent and class aggregates, durable model-versioned rating decisions and deterministic replay on login.
- Kept old diagnostic captures outside the new record and rating pool. Missing opponent GUID/start evidence remains history-only.
- History/export includes rating changes, opponent estimates and repeat impact. Mocked Character-frame integration and Lua 5.1 regression tests pass; in-game visual validation is pending.

# 0.1.1

- Recognize explicit duel cancellation UI messages; retain cancelled activity without creating a win or loss.
- Parse localized countdown messages and estimate duration from the projected start to the finish event (or result if finish has not arrived).
- Include estimated durations and the cancellation client constant in exports.
- Keep the captured opponent when outgoing request acknowledgement arrives after a target change.
- Add regression coverage for the supplied Classic Era trace: two cancellations followed by Zurk's knockout loss to Vitoarcanjo-Whitemane. Countdown-based duration for that trace is approximately 3.01 seconds, not the challenge-to-result interval.

Existing saved captures remain unchanged. Ratings remain disabled. Incoming requests and live forfeits still need in-game validation.

# 0.1.0

- Initial local capture prototype, localized result parsing, saved diagnostic history, optional bounded traces and copyable reports.
