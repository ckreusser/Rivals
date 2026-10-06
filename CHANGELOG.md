## Rivals 1.0.173

Changes since GitHub build 1.0.144.

- Preserve lifetime World PvP Overview statistics when encounters age out of the 250 unstarred-record History limit. Compact archives retain kills, deaths, solo results, rivals, streaks, favorite zones, and removed world buffs without retaining combat logs or portraits; enemy consumable spending remains counted once.
- Add duplicate-safe, one-time recovery of aged-out records from the bundled pre-trim snapshot for the matching character, without filling deliberate gaps within retained History.
- Snapshot observed opponents' Classic PvP/Honor rank index, localized title, numeric rank, and capture time in World PvP and formal-duel identity data.
- Give Current Streak and Best Streak larger dedicated values and independent hover highlights. Move Honorable Kills and Ganks into aligned record-tooltip rows.
- Expand Solo Multikills hover details with victory totals, largest solo sweep, and a 1vN victory breakdown.
- Add Duel Rating Overview tooltips for rating/status, placement progress, rated record, personal best, and latest duel.
- Refine Overview headline flourishes, bronze dividers, subdued labels, and green hover highlights; brighten Duel Details header trim.
- Refresh the in-addon rotation with 14 messages covering World PvP history, streaks, solo multikills, outnumbered victories, encounter evidence, enemy buffs, consumable costs, rival histories, and duel records.

## Rivals 1.0.146

Changes since 1.0.145.

- Replaced the in-addon promo rotation with the newly reviewed feature set centered on World PvP history, streaks, solo multikills, outnumbered victories, encounter evidence, enemy buffs, consumable cost, rival histories, and duel records.
- Omitted the two rejected promos from the review set; the rotation now contains 14 messages.

## Rivals 1.0.145

Changes since 1.0.144.

- Started snapshotting each visible opponent's Classic PvP/Honor rank index, localized title, numeric rank, and capture time into both World PvP and formal-duel encounter identity data for future features.
- Simplified the World PvP headline plaque: Honorable Kills and Ganks moved to hover details while Current Streak and Best Streak are now larger, dedicated stats.
- Rebuilt the World PvP record tooltip as aligned stat rows with no dot separators.
- Renamed Solo Multikill to Solo Multikills and expanded its tooltip with victory totals, largest solo sweep, and a 1vN victory breakdown.
- Added mouseover tooltips across the Duel Rating Overview for rating/status, placement progress, rated record, personal best, and the latest duel.

## Rivals 1.0.144

Changes since 1.0.143.

- Added animated Favorite Zone map bars using explored terrain, kill-centered crops, bright fills, and darkened unfilled lengths. Maraudon uses its approximate entrance location on the Classic Era Desolace map.
- Added World Buffs Removed image bars from the supplied screenshots, larger icons, compact spacing, and subtle bronze borders. Include zero-removal buffs without displaying zero labels.
- Consolidated Darkmoon Faire buffs into one removal column and removed the alternate-era Dragonslayer variant.
- Added PETRI as a Disengaged subcategory; retained combat and item-use evidence reclassifies qualifying existing records on reload without changing kill or death outcomes.
- Added subtle class-themed textures to Most Killed and Nemeses bars, preserving class colors and fixed-scale reveals; added text shadows for readability.
- Tightened chart headers, added matching subtle borders to Favorite Zone bars, and adjusted quadrant plaque text spacing.
- Reordered the plaque: Most Killed and Favorite Zone on the left; World Buffs Removed and Enemy Gold Spent on the right. Most Killed now shows only the opponent name.

## Rivals 1.0.143

Changes since 1.0.142.

- Added an animated Enemy Gold Spent pie chart with raised, textured slices and item-inspired colors.
- Added separate Flask of Petrification, Magic Dust, Arcane Bomb, Potions, Elixirs, Bandages, Bombs, Gadgets, and Other Consumables categories.
- Hide slices too small to see, trim the breakdown to visible categories, and preserve category totals when old encounters leave history.
- Added animated top-five Most Killed and top-three Nemeses charts with class-colored raised bars, names inside, and compact KB/death counts.
- Restart animations on every mouseover and keep chart tooltips inset from screen edges.
- Fixed duel portrait loading and fitting within its frame.
- Added FALL DAMAGE classification; lethal falls no longer credit opponents, nemeses, or solo losses.
- Added a one-time reload correction for the user-confirmed latest Coldbully fall death.

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

## Rivals 1.0.141

- Refreshed the in-addon promo rotation with current World PvP, rivalry, outnumbered-win, encounter-detail, duel, consumable-cost, and Reach-style killstreak messaging.
- Added silent `/rivals kb` testing: each use advances the in-memory killstreak exactly like a player killing blow without creating or changing World PvP encounter/history data and without printing a chat confirmation.

## 1.0.140
- Added a lightweight killstreak HUD position editor. Use **Manage Rivals > HUD & Capture > Killstreak medals > Move**, drag the live medal preview anywhere on screen, and right-click it to finish.
- Killstreak position now persists per Rivals settings across sessions.

## Rivals 1.0.139

Changes since 1.0.104.

### Opponent portraits

- Suppressed equipment particles and spell visuals that can cause orange-red, fire-like flickering over opponent portraits.
- Reapply effect suppression when portraits are prepared, reused, or displayed, and hide weapons in live-unit portraits.

### Multi-kill medals

- Added Halo: Reach-style medals and announcer sounds for rapid player killing blows, from Double Kill through Killionaire.
- Up to four medals appear in a left-side feed, with the newest medal on the left and older medals shifting right.
- Refined medal size, arrival animation, cyan captions, and fading; removed bright duplicate rings and rotation wobble.
- Added a Killstreak Medals toggle in Manage Rivals. Disabling it immediately clears the active chain and announcements.

### Minimap and navigation

- Added a draggable faction-themed minimap button. Left-click toggles Rivals; right-click opens a compact menu with Overview and Settings shortcuts.
- Added a visibility toggle in Manage Rivals and saved minimap positioning across reloads.
- Refined faction crest alignment, menu styling, hover behavior, and tooltip placement.
- Added an optional Open Rivals Overview keybinding under Keybindings > AddOns. Press it again on Overview to close Rivals.
- Added a Manage Rivals shortcut showing the current Overview binding and opening Keybindings directly.

### Settings and combat records

- Reorganized Manage Rivals into Profile Sharing, HUD & Capture, and Data & Recovery groups with clearer spacing and controls.
- Removed the redundant Overview return button and unused developer control reference.
- Added equipped-item proc attribution for Stygian Buckler's Stygian Grasp, Jagged Obsidian Shield's Silence, and Skullflame Shield's Drain Life and Flamestrike effects.

## Rivals 1.0.138

- Removed the redundant Overview return button from Manage Rivals; the primary Overview tab already provides the same navigation.
- Nudged only the Horde minimap faction crest 1 physical pixel to the right; Alliance crest positioning is unchanged.

## Rivals 1.0.137

- Gave Manage Rivals a spacing pass with consistent gaps between settings cards and more breathing room inside each group.
- Moved the Overview return button into the header, freeing the bottom of the pane so Data & Recovery no longer crowds its heading or neighboring controls.
- Increased vertical separation between HUD rows and the Overview keybind while preserving the compact settings-sheet layout.

## Rivals 1.0.136

- Rebuilt Manage Rivals as a compact settings sheet with three grouped cards instead of stacked centered headings.
- Profile Sharing is now a single privacy card with the On/Off control beside its explanation.
- Minimap, killstreak medals, screenshots, and the Overview keybind are grouped under HUD & Capture.
- Recovery and cache actions are grouped together under Data & Recovery, with one centered Overview return button at the bottom.
- Removed the stale developer-toast control reference left behind after the dev control was removed.

## Rivals 1.0.134

- Fixed the Reach medal feed animation: newest medal now appears in the left-most slot and older medals move right.
- Removed the enlarged additive medal duplicate and rotation that caused bright ghost rings / wobble during the pop.
- Older medals now retire from the right edge without jumping the remaining medals left.
- Reduced medal size and changed the arrival to a fast Reach-style snap/pop with a short rightward queue shift.

## Rivals 1.0.133

- Multi-kill medal feed: rebuilt the full presentation to behave like the classic Halo: Reach HUD rather than a centered single-medal popup. The feed now lives on the left side at the vertical midpoint, queues up to four recent medals from left to right, and left-aligns the newest medal caption directly beneath the row.
- Medal entrance now uses a fast scale/settle with a very slight rotation and a brief additive light burst after the pop, followed by a longer soft fade. Removed the old moving clipped sweep.
- Caption draw-in now scales subtly from 93% while cooling from near-white into the subdued Reach-style blue, with a restrained dark HUD shadow. Medal art is reduced to a 52px HUD-scale presentation.

## Rivals 1.0.132

- Multi-kill medals: rebuilt the caption treatment around Halo: Reach's actual HUD presentation: narrower 20px Arial Narrow, Reach-like cyan instead of gold, a restrained dark-blue shadow, tighter spacing beneath the medal, title-case medal names, and the Reach-style exclamation mark. Removed the heavy outline and gold highlight layers that made the previous pass look too large and unlike Reach.

## Rivals 1.0.131

- Multi-kill text: fixed the ARIALN font path escaping that caused invalid-font Lua warnings and taint when the announcement frame was created.


- Multi-kill medals: updated the kill text to a more Halo-like treatment with blockier sans-serif lettering, a dark shadow layer, richer gold body text, and a pale top highlight.


- Multi-kill medals: restored the supplied medal artwork and changed the shrink pipeline to a prefiltered 128px texture rendered at an exact 64px size with trilinear filtering and pixel-snapped layout. Removed the runtime scale pop to avoid a second resampling pass.


- Multi-kill medals: replaced the imported medal textures with a new small-display-optimized Rivals set. The symbols are simplified, outlines are thicker, and Triple Kill was rebuilt to read cleanly at in-game size.


- Multi-kill medals: rebuilt the medal textures directly from the original PNGs for smoother edges, and changed the light sweep to a thinner feathered pass with a narrow bright core.


- Multi-kill medals: removed the incorrect circular mask that hid the medals, changed the light sweep to follow each medal's actual alpha silhouette, and rebuilt the medal textures at higher resolution for sharper rendering.


- Multi-kill medals: moved the announcement higher, masked the light sweep to the circular medal instead of a square box, and replaced the medal textures with sharper higher-resolution art.


- Multi-kill medals: moved the announcement higher again and replaced the ineffective hand-built sweep with the same clipped diagonal LightSweep system used by Rivals plaques.


- Multi-kill medals: moved higher on screen, reduced medal size by 50%, added a quick light sweep on appear, and extended the on-screen hold time before fade.


- Added the first-pass rapid multi-kill tracker using the supplied 2-10 kill medal and announcer assets.
- Added a Manage-screen DEV KB button that feeds the exact same multi-kill counter as a real player killing blow without saving fake encounter stats.

## Rivals 1.0.121

- Manage: added a live Overview keybind button that shows the current binding and opens Keybindings directly to the AddOns section.


- Keybinding: pressing Open Rivals Overview now closes Rivals when Overview is already open; from other Rivals screens it returns to Overview.
- Keybinding UI: added a blank spacer above the Rivals row to match the existing separation below it in the AddOns section.


- Keybindings: moved Open Rivals Overview into Blizzard's built-in AddOns section and removed the redundant standalone Rivals header row.


- Keybindings: fixed Classic XML warnings by letting WoW auto-load the root Bindings.xml instead of loading it as a normal TOC XML file.


- Manage: tightened Recovery/footer spacing and aligned the two bottom actions on a cleaner two-column grid.
- Keybindings: added an unbound "Open Rivals Overview" action under AddOns > Rivals. It opens Overview without changing the user-selected Duels/World PvP carousel.


- Manage: separated the minimap-button toggle into its own section above the screenshot controls.


- Minimap menu: narrowed the menu, removed the redundant Open Rivals row, and now shows only the unselected Overview carousel destination plus Settings.
- Minimap menu: added a short mouse-leave grace period before the menu closes.


- Minimap button: moved the pixel-snapped faction crest down 1px while preserving exact horizontal centering.
- Minimap menu: narrowed the panel, replaced backdrop chrome with exact 1px rails plus an inset dark-grey fill, and changed hover rows to neutral grey with gold text.


- Minimap button: rebuilt the visual geometry around a 32px pixel-snapped center so the 22px faction crest, background, highlight, and outer ring all share the same center without manual nudges.


- Minimap menu: reduced width, removed the hide action, changed row hover to a cool grey, tightened the top background inset, and made the menu open inward from the minimap button.
- Minimap button tooltip now opens toward the center of the screen based on which side the minimap is on.
- Minimap crest moved 1px left.


- Minimap button: reduced the faction crest by about 5% and nudged it 1px to the right.


- Minimap menu: changed the menu chrome to use an inset masked background so the dark fill fits the gold border cleanly.


- Minimap button: shifted the faction crest 1px left and 2px down for a better centered fit inside the ring.


- Restored the minimap faction crest to its original 23px size and shifted it one pixel right for better visual centering inside the double ring.
- Restyled the minimap right-click menu to match the compact ENEMY BUFFS dropdown chrome, attached it directly to the minimap button, and changed the header to the small outlined gold RIVALS treatment used by the 1vN toast.

## Rivals 1.0.107

- Reduced and faction-tuned the minimap crest so the emblem sits cleanly inside the standard ring; the Alliance crest is centered on the lion's face rather than the atlas bounds.
- Replaced the minimap right-click dropdown dependency with a self-contained Rivals menu so Open Rivals, World PvP, Duels, Settings, and Hide Minimap Button work reliably on Classic Era.

## Rivals 1.0.106

- Added a draggable Rivals minimap button using the gold Alliance or Horde crest from the 1vN victory toast.
- Left-click toggles the Rivals character panel; right-click opens shortcuts for Rivals, World PvP, Duels, Settings, or hiding the button.
- Added a Minimap option under Manage Rivals so a hidden button can be restored; its position is saved across reloads.

## Rivals 1.0.105

- Added Stygian Buckler's Stygian Grasp and Jagged Obsidian Shield's Silence to equipped-item proc attribution.
- Added Skullflame Shield's triggered Drain Life and Flamestrike effects, fixing missing attribution when combat logs report those effect IDs.
- Added regression coverage for shield proc item links, aura/damage/healing events, older saved records, and exclusion of same-name class abilities and NPC casts.

## Rivals 1.0.104

Changes since 1.0.101.

- Fixed CharacterStatsClassic stats overlapping the Rivals character page. Stats now hide while Rivals is open and return on the character page, without changing saved settings.
- Added `/rivals toast` to preview the animated 1v3 victory notification without changing encounter history or statistics.
- Added a once-per-login update notice when a newer Rivals release is detected through guild or group addon messages. Remembers the newest detected version across reloads; this does not check CurseForge directly.
- Verified that tracked racial abilities appear in Items & Abilities regardless of cooldown length, including when cooldown data is unavailable. Added regression coverage for duel and World PvP tracking and display; existing behavior is unchanged.

## Rivals 1.0.103

- Added a once-per-login update notice: "Rivals: Fresh updates. Same grudges. Get the latest build on CurseForge."
- Discover newer release builds through throttled guild/group addon messages and remember the newest observed version across reloads. This is peer discovery, not a live CurseForge check; builds older than this feature cannot receive these notices.

## Rivals 1.0.102

- Added `/rivals toast` to force a preview of the animated 1v3 victory notification without changing encounter history or statistics.

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

---

# 1.0.99

- Prevent World PvP encounters from splitting while an existing opponent is in Ice Block, including when a new enemy joins during the combat-state drop.
- Added a short post-Ice-Block continuity buffer to absorb Classic combat-log/regen event ordering without lengthening normal encounter grace globally.
- Retroactively merge adjacent saved encounter fragments when the first half ends with an active Ice Block and the same blocked opponent appears in the following fragment.
- Recompute merged enemy headcount, pressure, outcome, combat log, usage, and consumable snapshot from the combined encounter.

# 1.0.98

- Fixed the 1.0.97 Mind Control Cap split migration so it actually runs during World PvP initialization. Existing adjacent fragments from the same opponent can now merge retroactively; the repair version was bumped so the corrected pass is not skipped.
- Hide Supercharged Chronoboon Displacer from ENEMY BUFFS. The stored-world-buff aura is not treated as an enemy buff advantage or an in-encounter item use.
- Added mouseover help to Items & Abilities category dividers explaining what belongs in each section.
- Removed REAGENTS and its child rows from Items & Abilities. Reagent usage still contributes to the Consumable Cost ledger.
- Consumable Cost now sorts by value: higher-spend participants first, then higher-value items within each participant, with deterministic tie-breakers.

# 1.0.97

- Added a conservative retroactive repair for World PvP encounters split by a Gnomish Mind Control Cap backfire. Adjacent same-opponent records are merged only when the earlier record ended from a combat drop/inactivity and a retained Mind Control Cap signal explains the boundary.
- Merged historical records rebuild one continuous Combat Log/Items & Abilities timeline, reattribute NPC-sourced cap backfires to the player, recompute encounter outcome/headcount, and rebuild consumable cost from the combined evidence.
- Preserves stars and the later encounter result/location while removing the duplicate History entry.

# 1.0.96

- Corrected Gnomish Mind Control Cap tracking to recognize both the 13180 item effect and the actual 13181 charm aura. NPC-sourced backfires are attributed to the player who activated the cap, collapsed to one gadget use, and shown as an item hyperlink in Combat Log and Engineering Gadgets.
- Extended the same-encounter grace window after a Mind Control Cap signal to cover the full temporary charm/backfire interruption instead of allowing PLAYER_REGEN_ENABLED to split the fight.
- Removed spell 349981 (the persistent Supercharged Chronoboon aura) as item-use evidence. Old fake Chronoboon rows are hidden/repaired and consumable snapshots containing them are rebuilt. Actual Chronoboon uses remain tracked from their cast spells.

# 1.0.95

- Moved inferred/known spec before Survived/Died in the encounter combatants tooltip so the green/red outcomes align on the right edge.
- Keep a World PvP encounter continuous through Gnomish Mind Control Cap charm/backfire combat drops. Backfires are attributed to the player who used the cap, deduplicated, and rendered with the Gnomish Mind Control Cap item hyperlink.
- Stopped treating a newly visible Supercharged Chronoboon aura as an in-encounter Chronoboon use. Existing affected consumable snapshots are repaired on load.
- Set Chronoboon replacement cost to the fixed 1g vendor price.

# 1.0.94

- Replaced levels in the encounter combatants tooltip with green Survived or red Died. Kept class-colored names and known specs.
- Retain friendly deaths and recover death status from older encounter logs, excluding recorded unconscious/Feign Death transitions.

# 1.0.93

- Fixed friendly level lookup through player, party, and raid unit tokens, including when friendly nameplates are disabled.
- Retry missing/invalid friendly levels on target, mouseover, nameplate, aura, level, and roster events, with a final refresh before saving. Existing valid historical levels remain unchanged.

# 1.0.92

- Simplified the encounter combatants tooltip: removed YOUR SIDE, the player's (You) suffix, unknown-spec placeholders, and the footer. Added a vs. separator and singular OPPONENT for one enemy.

# 1.0.91

- Added a mouseover roster to the History detail ENCOUNTER section. Your side and opponents show class-colored names, levels colored relative to your recorded encounter level, and specs from recorded evidence. Missing levels/specs are explicitly unknown; the player appears once.
- The hover area follows the variable-height location header and covers the encounter count and outcome without replacing the location tooltip.

# 1.0.90

- Added eight distinct face/hair/skin combinations per Classic race/sex, selected consistently by player GUID. Different saved encounters and reloads keep the same player's reconstructed features stable. These are approximations; old records did not store actual customization choices.
- Prefer exact retained/live opponent bodies when available. Generic reconstructed portraits no longer all borrow the local player's face or the same single NPC display.
- Reused actors now update their base features before dressing a different player. Matching cached faces are preferred, pending bodies remain reserved for their requester, and only visible requests load models.
- Checked all 128 display mappings against race/sex/model/skin data; regression tests cover face changes on actor reuse, stable revisits/new outfits/reloads, and existing loading/camera behavior. New variants still need in-game visual validation.

# 1.0.89

- Replaced untextured bare player displays in the donor-independent path with race/sex-matched humanoid displays containing skin data. Actual Era skin and equipment composition still need in-game verification.
- Added explicit-slot equipment application when numeric TryOn is ignored. A portrait with unverified or rejected equipment no longer becomes ready just because a timer expired.
- Added persistent binding/API/per-slot equipment diagnostics, three archived session traces, a read-only report inspector, and `PORTRAIT_DEBUG_LOG.md` documenting evidence and failed assumptions.
- Preserved foreground-only loading, spinner-only waiting, camera calibration, geometry, and recorded helms.

# 1.0.88

## History portraits
- Identified a missing-body dependency in the reported trace: eight female templates existed, but the selected Human was male. No male model load started; the spinner could wait indefinitely for an addressable male player.
- Added direct race/sex player-display loading with active-player customizations when no compatible live unit exists or unit binding is rejected. A timed-out unit binding switches to this independent source on the same actor. Exact retained opponent bodies remain preferred.
- Removed the eight-race template burst on login and donor observation. Only requested portraits allocate and load shared bodies; completed bodies and outfits remain reusable.
- Preserved spinner-only loading, saved cameras, medallion geometry, masks, and recorded equipment. Fixed an out-of-scope diagnostic variable in the calibration body's missing-donor path.
- Load traces now identify the binding source/display ID and equipment readback counts.
- Lua 5.1 regressions cover all 16 race/sex combinations with only an opposite-sex player available, rejected and stalled unit bindings, selection changes, outfit reuse, and no startup model loads. These use a simulated renderer: texture correctness, customization behavior across races/sexes, and actual load speed need in-game validation of the new display path. Combat Log classification and scrolling checks also pass.

# 1.0.87

## History portraits
- Separated donor retention from portrait preparation. On observing a player, Rivals retains one hidden, paused body template for each Classic race of that sex. Selecting a different race later can activate its template after the donor has disappeared, instead of waiting for another compatible live player.
- Only selected, visible opponents activate templates and dress recorded equipment. Removed the deferred idle sweep that could miss short-lived donors and leave an entire sex unavailable.
- Discover donors at login and group changes, preserve actual nameplate tokens beyond nameplate40, and prioritize pending visible portraits when a donor appears. Body readiness starts dressing directly rather than waiting for a slow UI retry.
- Reuse rejected model bindings instead of repeatedly allocating widgets. Added distinct diagnostics for retained templates, missing donors, creation failures, and binding failures.
- Removed class-icon fallbacks. Saved portraits keep the spinner until the reconstructed portrait reveals; existing camera calibration, geometry, masking, and recorded helms are preserved.
- Automated tests cover a fleeting male donor disappearing before a later male Dwarf selection. Actual game streaming and dormant-template behavior still require in-game validation; one initial compatible donor per sex is still needed after reload.

## Combat Log
- Fixed the large jump on the first wheel tick after changing encounters: resetting the log now clears the previous smooth-scroll destination and animation, and idle wheel input starts from the visible position.
- Removed proc matching by shared names and the assumption that an unrecognized effect without a recorded cast must be a proc. NPCs cannot be attributed player equipment; old incorrect proc-item metadata is revalidated when displayed.
- Added Diamond Flask's Era activation spell ID (363880) alongside its aura/heal ID (24427). The log shows the item use first and retains the subsequent applied-aura row.
- Verified representative abilities from all nine classes, all proc-catalog rows, 72 class-signature IDs, and 354 saved-log spell ID/name pairs.

# 1.0.86

## History portraits
- Removed login, landing-pane, History-page, and whole-encounter outfit preloading. Only opponents visible in the selected encounter request portraits; scrolling releases outgoing actors before requesting incoming rows.
- Replaced the automatic four-bodies-per-race startup burst with one-at-a-time idle donor preservation. Visible History requests bypass unrelated idle work and pause further warming.
- Coalesced repeated requests onto one pending race/sex body. Added a readiness watchdog for missing model-loaded callbacks, one bounded reseed attempt for stalled bodies, and continued recovery if the engine becomes ready later.
- Cancelled abandoned dressing and reveal callbacks when switching encounters, scrolling, closing details, or changing tabs. Prepared outfits remain cached for revisits.
- Limited the loading spinner to three seconds before showing a temporary class icon; a ready reconstructed portrait replaces it automatically. This is a fallback for unavailable donors/engine stalls, not a guarantee that models load within three seconds.
- Added a bounded saved load trace and `/rivalsportrait loads` to inspect request, body, dressing, callback, attachment, and reveal stages.
- Preserved the portrait geometry, masking, recorded helms, and saved camera calibrations. Lua 5.1 scheduling/lifecycle and camera/mask regression checks pass; actual loading speed and animation still require in-game validation.

# 1.0.85

## Combat Log
- Fixed a `tonumber` base-out-of-range error when opening encounter details with equipped-item procs. Inventory lookups now capture only the item ID before numeric conversion.

# 1.0.84

## Combat Log
- Replaced the five-entry proc seed list with a broad Classic Era equipped-item proc catalog: 240 proc relationships across 238 unique weapons, rings, armor pieces, shields, and trinkets.
- Added reactive non-weapon sources including **Freezing Band**, Skullflame Shield, Demon Forged Breastplate, Wall of the Dead, Force of Will, Guardian Talisman, The Lion Horn of Stormwind, Thick Obsidian Breastplate, Naglering, Drillborer Disk, Girdle of Reprisal, Vile Protector, Truesilver Breastplate, Uther's Strength, Mark of the Chosen, The Green Tower, Crest of Retribution, and Force Reactive Disk.
- Proc spells that are shared by many Classic items (for example Rend, Shadow Bolt, Stun, Drain Life, or Thorns) are no longer assigned to an arbitrary item. Rivals resolves the source against the actor's equipment and only prints an item when the match is unique.
- New portrait/identity captures retain equipped item IDs for all inventory slots 1-19, while portrait reconstruction continues using only its existing visual slots. This gives future encounters enough gear evidence to attribute ambiguous weapon, armor, ring, shield, and trinket procs safely.
- Known proc effects keep the lavender bracket treatment even when an older encounter lacks enough saved gear data to name the exact source item.

# 1.0.83

## Combat Log
- Added equipped-item attribution for known intrinsic weapon/item procs. Proc effects can now identify the item that generated them instead of showing only the effect spell.
- Item sources render as normal quality-colored item hyperlinks, so they use Blizzard item tooltips and remain Shift-clickable in the Combat Log.
- `Glimpse of Madness` is attributed to **Dark Edge of Insanity**, producing rows such as `Zurker's [Dark Edge of Insanity] applied [Glimpse of Madness] to Orgrímmar`.
- Added the same source layer for several other unambiguous Classic proc effects, including Bonereaver's Edge, The Untamed Blade, Nightfall, and Thunderfury.
- Proc-source metadata is retained on new encounters and is also resolved at display time so supported older saved encounters gain the richer attribution automatically.

# 1.0.82

## Combat Log
- Generalized item-use ordering so the **used [Item]** row renders before either a resulting aura or an immediate item heal/damage event. This fixes Healthstones appearing after their heal while preserving reflector **used -> applied** ordering.

## Portraits
- Reverted the 1.0.81 serialized portrait-body scheduler that could strand a foreground portrait behind an initializing body and leave the spinner running for extremely long periods.
- Restored the faster 1.0.78 startup path: seed one retained body per race immediately for the player's sex, expand the pool in later passes, and start recent-History preparation at 0.55s / 1.6s / 3.2s after initialization.
- Restored deterministic one-body player warming when portrait preloading runs, so opening History immediately after `/reload` does not depend on the delayed background worker having reached the requested race first.
- Kept the zero-speed animation freeze introduced in 1.0.78 and the later encounter-switch cleanup/primary-opponent ordering.

# 1.0.81

## Combat Log
- Reordered item-use display when Classic reports the resulting self-buff first: **used [Item]** now renders before the corresponding **applied [Buff]** row without altering the captured event data.

## Portraits
- Removed the remaining startup/model-loading stampede: player, target, mouseover, and nameplate donor warming now creates retained ModelScenes serially instead of seeding many race/sex actors in one frame.
- Foreground History portrait requests now pause all background body warming and background History preparation until the selected portrait has had first access to the renderer.
- Foreground cache misses create only the requested race/sex body on demand rather than implicitly warming every race.
- Sorted the selected encounter's opponents before portrait preload so the lead/primary Rival gets the first foreground body lane.
- Removed the delayed nameplate escalation to four background bodies per race; additional bodies are grown only as needed.

# 1.0.80

## Combat Log
- Fixed malformed item-quality markup that could render literally as `|c[Major Healthstone]` when Classic returned an incomplete cached item link/color state.
- Item-use rows now validate Blizzard item hyperlinks before using them and otherwise build a complete quality-colored, shift-clickable item link from Rivals' known item ID/quality.

# 1.0.79

## Combat Log
- Item activations now keep both pieces of useful information instead of collapsing the activation and resulting aura into the same line.
- On-use items render the activation as **used [Item]**, while the resulting buff/debuff remains a normal ability row such as **applied [Shadow Reflector] to Zurker**.

# 1.0.78

## World PvP
- Removed the approximation tilde from **Enemy Gold Spent**; Rivals still discloses unpriced tracked consumables in the tooltip, and price lookup continues to fall back from TSM DBMarket to Auctionator per item.
- Combat Log now resolves item activations through the Classic item-use catalog instead of a small hand list. Self-buff/on-use events render as **used [Item]** with the actual item quality color and a shift-clickable item link.
- Collapsed redundant item cast + aura rows into one item-use row where the combat log provides both events.

## Portraits
- Reworked login warming so Rivals seeds one body per race first instead of launching 32 ModelScene loads at once, then expands the pool after login settles.
- Delayed broad History background preparation so an encounter opened immediately after `/reload` gets the renderer first.
- Fully verified outfits can now leave hidden preparation early instead of always waiting the full fallback window.
- Changed reconstructed portraits from a near-zero animation speed to an actual zero-speed stand pose and disabled animation blending before pausing, targeting the remaining visible Human male / Night Elf female idle motion.

# 1.0.77

- Changed the Combat Log copy button to select the entire log instead of attempting the protected WoW clipboard API; its tooltip now instructs the user to press Ctrl+C after selection.
- Reworked portrait preparation priority so the encounter currently being viewed can preempt unrelated background portrait generation of the same race/sex.
- Reserved one retained portrait actor per race/sex for foreground History requests instead of letting background preload consume the entire four-actor pool.
- Prevented repeated foreground retries from starting duplicate preparation jobs for the same opponent.
- Released the previous encounter's portrait leases before preparing the newly selected encounter.
- Skipped the up-to-one-second native portrait-camera probe when a saved race/sex calibration already exists, since production framing immediately replaces that native camera target anyway.
- Reduced broad History preload churn that caused several same-race portraits to finish together after long waits.
- Applied the hidden post-reparent freeze/settle sequence to every race/sex combination, not only Human males, to reduce brief visible portrait animation.

# 1.0.76

- Tightened reflected-spell inference so a cast is only inferred as reflected when its intended target actually had an active engineering reflector.
- Prevented physical/self-effect abilities such as Bloodthirst and Diamond Flask from being falsely tagged as reflected.
- Preserved reflected aura ownership for periodic effects so reflected damage-over-time ticks remain attributed to the reflector until the aura ends.
- Classified Holy Strength (Crusader) as a weapon proc so its bracketed ability name uses the lavender proc treatment.
- Improved self-cast target resolution for stances, buffs, consumables, and item activations, and removed Unidentified target labels when no reliable target exists.
- New combat-log captures retain spell-school data to further guard reflection inference.

# 1.0.75

- Improved reflected-spell reconstruction when Classic omits the explicit REFLECT miss event.
- Reflected casts are marked `(REFLECTED)` on the original cast line.
- Returned reflected damage and hostile aura rows are attributed to the reflector instead of the original caster.

# 1.0.74

- Restored the Combat Log copy button with a Classic-safe TGA asset traced from the rounded overlapping-squares reference glyph.
- Engineering reflector casts now normalize to the caster as the target instead of displaying an opaque CLEU destination as `Unidentified`.
- Shadow, frost, and fire reflector activations therefore render as self-casts while reflected enemy spells continue to use the reflected-spell reconstruction logic.

# 1.0.73

- Replaced the Combat Log copy glyph with a rounded overlapping-squares icon matching the standard copy symbol more closely.
- The Combat Log copy button now performs a direct one-click clipboard write when the client permits the protected clipboard API; it no longer intentionally uses a two-step Ctrl+C workflow.
- Added reflected-spell reconstruction: reflected casts are marked `(REFLECTED)`, reflected damage/aura effects are attributed to the reflector, and the redundant REFLECT miss row is suppressed when the cast can be paired reliably.

# 1.0.72

- Removed the outer frame from Combat Log ability tooltip icons, enlarged the icon itself, and attached it directly to the tooltip edge.
- Proc effects no longer print a separate PROC label; their bracketed ability name is tinted lavender instead.
- Backspace/Delete are intercepted before the read-only Combat Log can mutate, preserving the caret position while arrow-key navigation remains available.
- Switching to another World PvP encounter while viewing Combat Log now resets the caret and scroll position to the top.
- Player killing blows retain the KILLING BLOW marker and are followed by an explicit death line; Rivals suppresses a duplicate death event when it has to synthesize that line.

# 1.0.71

- Restyled the Combat Log copy glyph to a smaller overlapping-square icon closer to the standard copy symbol.
- Kept Combat Log text immutable while preserving normal cursor navigation; attempted edits restore the original text without moving the caret.
- Combat-log ability names are now white, bracketed spell links with attached spell icons on mouseover tooltips.
- Standardized combat verbs such as cast and hit to white text while keeping damage/heal numbers color-coded.
- Added explicit PROC labeling for player-sourced non-class effects such as weapon/item procs while leaving the ability name itself white.
- Expanded class-ability recognition for Warrior abilities including Whirlwind, Charge, Rend, and Deep Wounds so they are not misclassified as item procs.
- Added renderer-side source correction for periodic class abilities when the saved source conflicts with a known player class and a recent valid caster can be identified; this repairs cases such as a Rogue being shown as the source of Rend.
- Removed literal Unknown targets from structured and legacy Combat Log display. Untargeted/self/AoE casts now omit the fake target instead.
- Preserved actual SPELL_DAMAGE / SPELL_MISSED results for direct-damage abilities; Rivals does not invent damage when Blizzard does not emit an impact event.

# 1.0.70

- Made World PvP and Duel combat-log text read-only while preserving mouse selection and Ctrl+C copying.
- Added a square-over-square Copy control to the top-right of both combat-log panes; it prepares the complete plain-text log for Ctrl+C without exposing Rivals markup.
- Made structured combat-log spell names interactive so hovering an ability shows its Blizzard spell tooltip.
- Highlighted player-sourced non-class combat effects, including weapon/item-style procs such as Glimpse of Madness, with a distinct lavender treatment.
- Added KILLING BLOW markers to lethal player-vs-player damage rows, including existing World PvP records where the stored overkill payload proves the lethal hit.
- Added SPELL_MISSED / RANGE_MISSED capture and rendering so damaging abilities that are absorbed, resisted, immune, or otherwise miss no longer appear as a cast with no result.
- Added aura refresh events to the retained World PvP log.
- New Duel combat-log captures now retain spell IDs/names so ability tooltips are available there as well.

# 1.0.69

- Made World PvP combat logs selectable with the mouse and copyable using standard keyboard shortcuts.
- Made Duel combat logs selectable and copyable as well for UI parity.
- Combat-log scrolling and existing inline formatting are preserved.

# 1.0.68

## World PvP Overview
- Replaced the standalone Nemesis plaque with **Enemy Gold Spent**, a lifetime estimate of tracked consumables used by enemy players against you.
- Enemy spending now survives the 250-encounter rolling History cap by archiving totals before old encounters are discarded.
- Moved **Nemesis** into the **Most Killed** mouseover and condensed both rival records using the same World PvP / Solo / encounter-count language used elsewhere in History.
- Replaced `g` / `s` text abbreviations on Enemy Gold Spent with WoW coin icons and simplified its tooltip.

## Opponent Portraits
- Continued rebuilding the World PvP portrait lifecycle so saved encounters reconstruct generated 3D opponent portraits instead of relying on persisted render-target handles or temporary class icons.
- Added an in-medallion loading state for reconstructable portraits while their ModelScene is being prepared.
- Added higher-priority preparation and retry handling for the encounter the user is actively viewing.
- Applied saved race/sex camera calibrations retroactively to reconstructed portraits from older encounters.
- Expanded `/rivalsportrait test` with fixed-distance camera pitch, character rotation, horizontal/vertical framing, and zoom controls.
- Portrait test previews now hide helms so headgear cannot obstruct camera calibration; normal History portraits still preserve recorded helm visibility.
- Saved portrait-test camera settings persist across relogs and are reused by production portrait reconstruction.
- Added extra hidden freeze handling for Human male portraits to reduce brief visible idle animation during reveal.
- Iterated on the portrait loading indicator with circular dots, smoother tapering, and medallion-centered placement.

## Stability
- Reduced `WorldPvP.lua` chunk-level locals after the Enemy Gold Spent work exceeded Classic Lua's 200-local main-function limit.

## Promos
- Rewrote the in-game Rivals promo rotation around the addon's current World PvP features, including encounter history, opponent records, outnumbered fights, map captures, generated portraits, enemy buffs, consumable cost, and current duel functionality.

# 1.0.67

- Prioritized the portrait for the currently opened encounter so it prepares immediately instead of waiting behind broader History warming.
- Reduced cases where the loading spinner could continue for a long time on the same portraits.
- Refined the loading swirl centering and softened the leading dot highlight.
- Tightened the swirl tail so the dots shrink more quickly and smoothly behind the lead.
- Added extra hidden freeze passes for human male reconstructed portraits to reduce visible animation.

# 1.0.66

- Fixed a remaining portrait-loading deadlock where an unavailable exact live-body clone could prevent a prepared shared generated portrait from ever being used.
- Visible History portraits now prefer exact live identity when ready, but immediately fall back to the generated race/sex body pool instead of spinning indefinitely.
- Recentered the loading indicator directly on the portrait medallion.
- Reworked the spinner with circular dots and a smooth, faster exponential size/alpha taper.
- Added a hidden post-reparent hard-freeze for Human male portraits to suppress their brief idle-animation flash before reveal.
- Increased active portrait retry responsiveness.

# 1.0.65

- Fixed generated portraits sometimes remaining on the loading indicator until the encounter was reopened.
- Visible portrait requests now stay pinned in the prepared-model cache and are upgraded by cache key as soon as generation completes.
- Replaced square loading blocks with circular dots and centered the spinner on the medallion viewport.
- Increased priority retry responsiveness for a portrait the user is actively viewing.

# 1.0.64

- Reconstructed World PvP portraits now use an animated loading spinner instead of class icons while their generated portrait prepares.
- Replaced the old refresh-style spinner with a round loading swirl.
- Applied saved portrait camera calibrations to all reconstructed portraits, including old encounters loaded from History.
- Reduced portrait preparation delays and increased preload/retry aggressiveness to improve first-open portrait load times.
- The portrait calibration tool now immediately reapplies newly saved calibration values in-session.

# 1.0.63

- `/rivalsportrait test` now restores each race/sex calibration from the last saved result after relogging.
- Portrait test previews always hide head-slot gear so helms cannot obscure face/camera calibration.
- Test-only helm suppression does not modify saved encounter appearance data or production History portraits.

# 1.0.62

- Keep reconstructable World PvP portraits in an animated medallion loading state until the generated portrait is actually ready; no temporary class icon.
- Retry hidden portrait preparation while the encounter remains open, so a portrait that missed the initial body-cache warm-up appears automatically without clicking away and back.
- Keep the loading spinner visible until the frozen ModelScene is revealed, avoiding a blank transition frame.
- Expanded `/rivalsportrait test` with fixed-distance camera pitch controls and character rotation controls.
- Saved portrait test results now include camera pitch and character yaw values.

# 1.0.61

- Replaced temporary class-icon portrait fallbacks on reconstructable World PvP opponents with an in-medallion loading spinner.
- Visible encounter cards now upgrade automatically to the generated portrait the moment hidden preparation finishes, without requiring you to click away and back.
- Preserved existing portrait framing, medallion masking, and freeze behavior.

# 1.0.60

- Restyled the Most Killed / Nemesis tooltip with matching title-case gold headers.
- Replaced kill/death bullet formatting with the History opponent-record format.
- Added each rival's World PvP record, Solo record, and recorded encounter count.

# 1.0.59

- Condensed the Most Killed / Nemesis mouseover tooltip.
- Standardized section header casing and kill/death presentation.
- Shortened the encounter-relative death note.

# 1.0.58

- Replaced the Enemy Gold Spent plaque text abbreviations with coin icons.
- Removed the footer line from the Enemy Gold Spent mouseover tooltip.

# 1.0.57

- Fixed the Classic Lua `main function has more than 200 local variables` warning in `WorldPvP.lua`. Module-wide World PvP constants now live in a single configuration table, reducing chunk-level locals without changing encounter, portrait, map, or Enemy Gold Spent behavior.

# 1.0.56

- Replace the standalone **Nemesis** Overview plaque with **Enemy Gold Spent**, showing the lifetime captured value of consumables used by enemy World PvP Rivals against you.
- Preserve enemy consumable value when unstarred encounters age out of the rolling 250-encounter History cap, so the lifetime spend total keeps accumulating beyond retained History.
- Count only enemy-player spend from each encounter cost snapshot; the user's own consumables are excluded. Unpriced tracked consumables are called out in the tooltip and leave the displayed total marked approximate.
- Fold the Nemesis record into the **Most Killed** plaque tooltip, keeping both rivalry stats available without dedicating a second Overview plaque to them.

# 1.0.55

- Stop serializing `SetPortraitTexture` backing handles. Classic can expose session-local numeric render-target values that later alias unrelated spell/item icons, which caused some History portraits to reopen as random icons after `/reload`. Existing stale values are discarded on initialization.
- Start retained-body warming and recent-history portrait preparation immediately after entering the world, with staggered retries, and increase the landing-pane warm set to 24 identities.
- Protect portraits requested by the same visible History batch from evicting each other while the shared race/sex cache is preparing.
- If a first-click fallback still wins a rare startup race, upgrade that exact visible card automatically when its hidden portrait finishes instead of requiring Rivals to be closed/reopened. The old static visual remains until the frozen actor is ready, so there is no blank medallion.
- Keep a prepared ModelScene transparent for one UI tick after reparenting, reassert actor/scene pause, then reveal it. This targets the remaining one-frame idle-animation flash without delaying encounter content.
- Preserve the 1.0.54 map exploration-tile fix and all accepted portrait framing/masks/plaque geometry.

# 1.0.54

- Rebuild encounter-map exploration overlays using Blizzard's actual map-layer tile dimensions and power-of-two edge texture sizes instead of assuming 256px backing files.
- Respect exploration overlay draw-on-top and mouseover-only flags so captures such as Booty Bay no longer contain stretched/misplaced terrain rectangles.

# 1.0.53

- Remove portrait readiness and settle waits from the History click path. Encounter details now update immediately instead of disappearing while ModelScenes are attached.
- Pause both the ModelScene actor and the scene. Actor-level pause survives Classic Era reparenting more reliably and targets the remaining one/two-frame idle animation flashes.
- Never call `SetAnimation`, `StopAnimationKit`, or redundant `Show()` while attaching an already-prepared portrait to a visible plaque. Those mutations are restricted to hidden preparation; visible reassertions only preserve pause state.
- Give the four visible World PvP History rows preload priority so they can recycle stale off-page shared bodies before the user clicks them. Missing old portraits still commit a stable fallback for that opening instead of blocking the encounter or hot-swapping later.
- Leave portrait camera/framing, helm display, 46px viewport, medallion masks, plaque rail masks and border layering unchanged.

# 1.0.52

- Retain an identity-specific clone of each live World PvP opponent before generic race/sex donor warming. Newly observed encounters keep that opponent's actual face, hair, skin/body customization and then replay the saved encounter gear on that exact body for the current UI session.
- Start portrait preloading shortly after login as well as when the Rivals pane opens. A clicked History encounter gets priority and can recycle an old unleased prepared body instead of falling back simply because a race/sex cache is full.
- Gate encounter opening on hidden portrait preparation for up to a bounded wait. Reconstructable records no longer flash a default race portrait and then change into a geared portrait; if no compatible body is available, the opening commits to a neutral class icon instead of hot-swapping.
- Hide the whole details pane during the short ModelScene re-anchor settle window, re-freeze attached actors several times, then reveal the finished pane atomically. Repeated clicks on the same encounter remain a portrait no-op.
- Leave the accepted portrait camera calibration, 46px viewport, medallion masks, plaque rail masks and border layering unchanged.

# 1.0.51

- Preload recent World PvP opponent portraits off-screen when the Rivals pane opens. Visible History plaques now attach only fully dressed, framed, paused actors; no TryOn/model settling happens on the click path.
- Commit a portrait source for the lifetime of the visible encounter card. A static fallback no longer hot-swaps to a reconstructed actor when the body cache becomes ready in the background.
- Re-clicking the same History encounter is now a no-op for the portrait layer. Switching detail tabs also preserves already-attached portraits instead of releasing/rebuilding them.
- Reopen/scroll-back paths reuse a prepared frozen actor when available. Prepared actors retain their outfit while parked and are invalidated only when their donor body is deliberately reseeded or the cached opponent changes.
- Remove the 0.08-second reconstructed-portrait reveal shortcut; asynchronous model/outfit work now gets a real hidden quiet interval before any non-preloaded actor can be shown.
- Keep the accepted 46px viewport, race/sex camera calibration, medallion spill cover, plaque-border layering, and shallow rail masks unchanged.

# 1.0.50

- Inset the circular cover by one pixel to overlap the medallion rim and conceal diagonal edge spill. Retain the 46px viewport and all calibrated camera settings.
- Use a new texture filename to avoid reusing a cached cover image. Add alpha coverage checks around the full perimeter, including the lower-right diagonal.

# 1.0.49

- Match reconstructed viewports and circular openings to the 46-pixel live portrait area. Extend opaque corner patches across the full enlarged renderer.
- Preserve all calibrated camera targets, distances, and on-screen face magnification with the corresponding field-of-view compensation.
- Verify the newly exposed top/side regions and all four renderer corners in the cover texture.

# 1.0.48

- Expand reconstructed portrait viewports from 35 to 40 pixels and enlarge the circular opening to reduce the inset dark gap beneath the medallion.
- Compensate field of view for the larger viewport, preserving the face size and exact calibrated camera targets/distances. Match History and the test panel.
- Extend corner coverage for the larger viewport; verify opaque corners, clear center, and unchanged projection scale.

# 1.0.47

- Apply all 16 user-calibrated race/sex camera targets and distances to reconstructed History portraits and the test preview. Use the saved absolute values so donor geometry cannot change the accepted framing.
- Add a circular opaque cover between reconstructed models and their medallion rings to conceal the model viewport's square corners. Keep the accepted camera scale and leave generic/live texture portraits uncovered.
- Preserve test results. Preview controls now adjust from the calibrated baseline.
- Verify all accepted camera values against saved fixtures and check cover alpha at all four model corners.

# 1.0.46

- Add Move left/Move right controls to the portrait test window. Horizontal movement follows the camera's screen-right vector and is included in saved diagnostic results.
- Reset clears both offsets. Add regression checks for horizontal direction, saving, reset, and isolation from production portraits.

# 1.0.45

- Add `/rivalsportrait test`: an enlarged History-style reconstructed portrait, all eight races and both sexes, automatic saved-outfit samples, aim/zoom controls, reset, retry, and diagnostic result saving.
- Keep camera adjustments isolated to the preview. Closing the window releases its cached body and cancels delayed operations. Unavailable bodies are labeled rather than replaced with generic portraits.
- Add controller tests for preview controls, immutable encounters, result saving, missing bodies, retry, and close/reopen behavior. Production camera settings are unchanged.

# 1.0.44

- Save portrait camera diagnostics on addon initialization and logout/reload, including empty pools, unloaded actors, and pending camera reads. Previously the report existed only after successful body priming, leaving failures unrecorded.
- Add regression coverage for missing bodies and unfinished initialization. No camera offsets changed.

# 1.0.43

- Attempt native model portrait-camera targeting instead of estimating head height from body bounds. Rotate the returned focus with the portrait actor and normalize actor origin/scale.
- Share one off-screen camera probe per model file per session; clear it after reading, reject default/unchanged camera values, and time out after one second. Retain the previous framing if the client cannot supply a usable native target.
- Delay cached-body availability while its camera probe is pending. Keep saved-equipment reconstruction and body-ready fallback retries.
- Record bounded numeric camera evidence for all observed race/sex pairs in SavedVariables, allowing investigation without relying only on screenshots.
- Add regression coverage for native target selection, coordinate rotation, invalid getter results, shared probe cleanup and timeout. In-game camera readback and visual composition remain unverified.

# 1.0.42

- Remove donor equipment after model loading and wait for geometry to settle before measuring cached portrait bodies. Skip unloaded actors and duplicate priming callbacks.
- Retry visible saved-gear portraits when the needed body finishes loading or becomes free. Discard retries for scrolled-out or recycled rows.
- Revert speculative 1.0.41 focal-point increases while correcting the underlying body measurements. Exact in-game framing remains unverified.
- Add development-only Lua 5.1 regression tests for all eight races and both sexes, asynchronous loading, saved outfits, fallback upgrades, stale callbacks, and capture concealment. Tests are not loaded by the addon.

# 1.0.41

- Add female-specific Human and Night Elf head framing, raising the focal point from chest/shoulders to the head and allowing slightly more vertical headroom.
- Raise the Dwarf focal point for the chest-only crop shown on Uriko. Keep other race profiles and Human/Night Elf male framing unchanged.
- Carry saved sex into camera selection during body priming and every lease, preventing pooled scenes from inheriting an unrelated sex profile.
- Retain the off-screen capture fix. Camera changes require in-game comparison; no claim of completed visual QA.

# 1.0.40

- Move all background equipment-capture DressUpModels fully off-screen and independently set their model-render alpha to zero. Reassert concealment before showing, after SetUnit, and on model load so capture models cannot appear as miniature fighters at screen center.
- Keep asynchronous gear capture and encounter-finalization retries intact. Portraits2.mp4 still shows unresolved reconstruction framing; this build does not claim to fix those camera issues.

# 1.0.39

- Replace the whole-body width/depth camera-distance heuristic with race-specific vertical head spans and focal points. Distance follows the portrait field of view, so broad body bounds no longer shrink the face.
- Lower the reconstructed head focal point for Human/Dwarf and other affected races, retaining separate Gnome proportions and horn/ear allowance.
- Reset pooled camera pan offsets before applying the profile. Retain the 22-degree turn, elevated camera, actor cache, saved gear, and reveal/release safeguards.
- Camera profiles are a visual QA candidate based on Portraits1.mp4; exact crop and containment still require in-game confirmation.

# 1.0.38

- Deploy the 1.0.37 native-composition baseline to the active addon directory; the nested Rivals_work copy had not replaced the installed 1.0.36 build.
- Invalidate pending portrait operations on direct pool release, clear model-loaded callbacks, and check both actor ownership and card references before delayed dressing/reveal.
- Prevent repeat reveals and dressing after a portrait becomes visible. Fully verified pooled outfits may reveal after the first 80ms quiet interval instead of always undergoing repeated dressing and a 360ms wait.
- Synchronize capture-report and addon versions. Runtime visual QA is still required for composition, containment, Gnome framing, and first-frame stability; these are not declared solved.

# 1.0.37

- Match reconstructed opponent portraits to Blizzard's native portrait composition instead of a straight-on mugshot: actors now use a mild 22-degree three-quarter turn and the portrait camera sits about 6 degrees above the face.
- Fix the Gnome framing regression from 1.0.36. Gnome body bounds use a much lower focal point and normal headshot distance; the camera no longer looks above the character and leaves only the top of the head at the bottom of the medallion.
- Remove the temporary synthetic race/class portrait shown while a reconstructable 3D portrait settles. Reconstructed rows now reveal once, eliminating the obvious generic-portrait flash before the real Rival appears.
- Shorten the hidden dress/settle path while keeping all retries invisible. A pooled portrait should populate sooner without exposing the intermediate TryOn/model-load motion.

# 1.0.36

- Contain the square ModelScene render target fully beneath the circular medallion ring. Production portraits now use a 35px viewport instead of 40px, eliminating the shoulder pixels that could protrude below the ring even though the child frame itself was clipped.
- Add race-proportion camera compensation. Gnome portraits back off substantially so their oversized heads fit, with additional headroom/distance compensation for Tauren horns, Troll tusks/hair, Night Elf ears, Orcs, Dwarves, and Undead while leaving Human framing essentially unchanged.
- Remove the visible blank/populate delay when opening an encounter. A static race/class portrait is shown immediately while the retained body is redressed and frozen transparently, then replaced only after the ModelScene has settled.
- Extend the hidden settle window and never reveal on the same tick as the last `Undress`/`TryOn` pass. This hides the brief animation/model twitch that could still leak through in 1.0.35.
- Keep final gear retries in the hidden path; the visible portrait is no longer redressed after reveal.

# 1.0.35

- Normalize retained bodies to a neutral stand pose before reading any camera bounds. 1.0.34 was still capturing `GetActiveBoundingBox` from arbitrary donor idle frames, which made same-race portraits use different zooms and vertical placement.
- Share one framing profile across every retained variant of the same race/sex. Donor diversification can change face/hair/skin, but it can no longer change portrait scale or camera position. Camera X/Y now stays on the player-model root instead of following customization-dependent bounding-box centers.
- Remove the last visible ModelScene lifecycle flash. Pooled scenes stay shown but alpha-zero while they are reparented, redressed, paused and framed; they become opaque only on the following UI frame after the final pause.
- Reduce the reconstructed 3D viewport from 44px to 40px while keeping the 56px gold medallion. The square ModelScene corners now sit under the circular ring instead of visibly protruding below/beside it.
- Restore the tighter 1.0.33 camera distance after the 1.0.34 headroom experiment made several portraits read too small.

# 1.0.34

- Fix the inconsistent production portrait crop exposed by switching between the tested 1v3 and newer encounters. Retained pool entries now preserve the naked body bounds captured only after the donor model is fully loaded; opening another Rival no longer overwrites those stable bounds with the previous Rival's still-stale dressed bounding box immediately after `Undress()`.
- Never lease a body entry while a donor diversification reseed is still loading. Only fully primed entries with stable base bounds can be attached to an opponent card.
- Keep a reconstructed ModelScene hidden while saved gear is being reapplied and the first camera pass settles, then reveal it already paused. This removes the visible donor/idle/reposition flash that could still occur on individual cards such as the Night Elf test case.
- Camera retries after the initial frame now redress/freeze only; they do not repeatedly recompute camera framing from transient model state.
- Add a small amount of headroom to the reconstructed headshot crop while preserving the 1.0.32/1.0.33 medallion viewport and ring layering.

# 1.0.33

- Eliminate the last visible portrait motion on history-open. Every production ModelScene is now paused before it is first shown, retained body scenes are re-paused before attachment, and the saved-gear/camera retry path no longer unpauses the scene between retries.
- Keep hidden donor reseeding free to animate/load off-screen, but guarantee a body is frozen again before any opponent plaque can display it.
- Preserve the 1.0.32 medallion clipping, ring layering, flattened portrait camera, and head-line framing unchanged.

# 1.0.32

- Fix the production medallion failures visible in the 1.0.31 1v3 test. Reconstructed ModelScene actors now render inside a clipped 44px child viewport, are centered on the medallion, and the gold ring is raised well above the 3D scene so shoulders/chests cannot draw below or over the ring.
- Use Classic Era's actual `ModelScene:SetPaused(true, false)` API after forcing a neutral stand pose. This replaces the ineffective speed-zero-only freeze and stops retained portraits from idling after reload.
- Reframe reconstructed portraits around the eye/head line instead of the neck/chest line, with small race-specific headroom adjustments for Tauren, Night Elf, Troll, Gnome, and Dwarf proportions.
- Reduce camera FOV from 0.68 to 0.30 and compensate camera distance to preserve crop size. This flattens perspective so reconstructed models read much closer to Blizzard's static portrait render instead of a miniature 3D character-preview camera.
- Slightly flatten portrait lighting so facial features remain readable at 44px without exaggerated 3D shading.

# 1.0.31

- Continue portrait production QA rather than treating the retained-body proof as final. The session cache now keeps four bodies per race/sex, enough for every materially visible OPPONENTS row at once.
- Release 3D body leases from opponent rows that are clipped out of the scroll viewport and reacquire them when those rows become visible. Long 1vN histories no longer consume bodies for off-screen plaques.
- Diversify the four stable body variants automatically as distinct same-sex players are observed. New donors replace only duplicate, currently-free variants, so repeated reconstructed rivals no longer all inherit the first donor's face/hair palette. Rival GUID/name hashing gives each opponent a stable preferred variant whenever it is available.
- Frame reconstructed portraits from the undressed player-body bounds captured before saved gear is applied. Oversized shoulders, helms and cloaks no longer zoom the camera away from the face or make the same race use wildly different crops.
- Freeze retained ModelScene actors on a neutral stand frame and clear stale model-loaded callbacks before pooled actors are reseeded, preventing distracting idle motion and old-card gear callbacks from leaking into a newly seeded body.
- Add `/rivalsportrait pool detail` to report each race's total/free bodies and unique donor-variant count for male and female caches.

# 1.0.30

- Promoted the retained race/sex portrait body cache to the final production path after verifying simultaneous male/female opponent plaques borrow the expected cached bodies after `/reload`.
- Removed the experimental portrait lab, offline matrices, actor-info/display-ID/texture probes, prototype preview UI, capture debug payloads, and their diagnostic SavedVariables.
- Kept only `/rivalsportrait pool` and `/rivalsportrait pool warm` as lightweight cache diagnostics; portrait capture and reconstruction remain automatic.

# 1.0.29-portrait-finalize-capture-fix

- Fix the production opponent portrait snapshot race revealed by the 1.0.28 body-pool test. Encounter finalization marked opponents `portraitFrozen` immediately, which caused the bounded `.1/.4/1.0s` DressUpModel loading retries to abort before saved gear could be retained. Forced finalization captures may now finish against their already-bound model after the identity is frozen.
- Allow a bound finalization model to finish if its nameplate/target token disappears; abort only if the token is recycled to a different GUID.
- Give simultaneous enemies independent bounded capture models during finalization. The previous single shared model let later enemies overwrite earlier pending retries, so a multi-opponent encounter could retain gear only for the last participant.
- Keep the 1.0.28 retained male/female race-body pool unchanged. Once a new encounter actually retains `portraitAppearance`, its History plaque now has the data required to borrow one cached body, dress the saved appearances, and hold that body while the plaque is visible.

# 1.0.28-portrait-session-body-cache

- Promote the proven 1.0.27 same-sex donor path into the real World PvP portrait renderer. One live player seeds retained player-body actors for all eight Classic races of that sex; saved numeric gear is then dressed onto those bodies without needing the donor again.
- Seed two retained bodies per race/sex for simultaneous opponent plaques. The player automatically seeds their own sex after entering the world; target, mouseover, nameplate, and encounter capture events opportunistically seed the other sex.
- Real opponent cards now borrow/release those retained ModelScene bodies instead of requiring a same-sex unit every time the History pane redraws. Hidden/unused summary cards release their borrowed body back to the session pool.
- Keep the exact live `SetPortraitTexture` capture as first priority for same-session fidelity. The retained body pool is the reload/session fallback when the baked portrait is no longer available.
- This is intentionally session-only: Era 1.15.9 proved live player bodies expose `displayID=0`, raw player model files replay untextured, and actor-info/custom-race APIs needed for donor-free persistence are absent.

# 1.0.27-portrait-donor-race-matrix

- Added `/rivalsportrait donor` to prove the practical Classic Era reconstruction path: one live player supplies the body sex while `ModelSceneActor:SetModelByUnit(..., customRaceID)` supplies each of the eight Classic races.
- The matrix reapplies the same saved gear to every race and reports the normal Rivals portrait diagnostics/gear verification.
- Added `/rivalsportrait donor retained` to re-show the already-built actors without calling `SetModelByUnit` again, for a same-session retention check after clearing/losing the donor target.
- This follows the 1.0.26 result that live player `GetDisplayInfo()` is `0` and the raw player model file replays white/untextured, so the live unit body itself is the useful primitive on Era.

## 1.0.26 - Portrait live display-ID persistence probe

- The 1.0.25 runtime probe proved this 1.15.9 Era client uses the old Classic `DressUpModelFrame` architecture; `DressUpFrame.ModelScene` is nil, and the ModelScene actor/scene database is not a viable player-body source here.
- Add `/rivalsportrait display` to capture the actual live Classic `DressUpModel:SetUnit()` body's `GetDisplayInfo()`, `GetModelFileID()`, and visible numeric appearance IDs.
- Compare direct display-ID replay, display-ID + saved gear, player-seeded display replay, player-seeded display + gear, and raw model-file + gear.
- Persist only primitive IDs so `/rivalsportrait display saved` can repeat the same reconstruction after `/reload`.

## 1.0.24 - Portrait actor custom-race matrix

- Test `SetCustomRace(raceID, gender)` on the **ModelSceneActor** itself, distinct from the already-failed DressUpModel API.
- Test the same call on Blizzard/Narcissus Classic dressing-room **ModelScene 290** if that scene exists on the live Era client.
- Preserve the known-good player-backed control and saved gear verification.

# 1.0.19-portrait-texture-persistence-probe

- Added `/rivalsportrait texture` to test whether Classic Era's exact baked `SetPortraitTexture` output exposes a serializable texture value/file ID/path.
- Saves only primitive texture metadata plus `UnitCreatureDisplayID`; `/rivalsportrait texture saved` replays those values after `/reload`.
- Adds a five-column comparison: live unit portrait, `GetTexture()` replay, file-ID replay, file-path replay, and `SetPortraitTextureFromCreatureDisplayID`.
- This probe does not replace the normal opponent portrait path yet. It is intended to determine whether exact face/gear portraits can be persisted directly instead of reconstructed.

## 1.0.17-portrait-glue-donor-matrix
- The 1.0.16 live Era test definitively showed that `DressUpModel:SetCustomRace` is absent on this client, so remove it from the active offline experiment.
- Add a focused `ModelSceneActor:SetPlayerModelFromGlues` matrix. Classic Era exposes this actor API with both a character index and `customRaceID`; the experiment tests whether it remains usable while logged in and whether a real character-select body can lend sex/customization while the saved opponent race and gear are replayed.
- Compare the known-good wrong-sex player control against the selected character and character slots 1-4. Diagnostics now report the resulting model file, inferred body sex, requested sex, and saved-gear verification count.

## 1.0.16-portrait-customrace-matrix
- Replace the exhausted white-body offline matrix with a focused Classic `DressUpModel:SetCustomRace` matrix. The 1.0.15 result proved raw display/model-file bodies are either untextured or cannot retain the outfit; the remaining promising path is the real DressUpModel race+sex API.
- Compare four initialization/order variants against the known-good wrong-sex ModelScene control: direct `SetCustomRace -> gear`, `player -> SetCustomRace -> gear`, `player -> gear -> SetCustomRace`, and `none -> SetCustomRace -> gear`. Saved WoW `UnitSex` values are normalized to the `SetCustomRace` 0/1 gender convention.
- Keep this diagnostic-only until one column is both textured, the requested sex, and still verifies the saved appearance IDs.

## 1.0.15-portrait-offline-synthetic
- Preserve up to 24 opponent portrait prototype samples in a plain SavedVariables archive so later self-tests cannot erase the only offline reconstruction sample. Named `/rivalsportrait offline <name>` lookup now checks this archive before World PvP history.
- Add `/rivalsportrait offline synthetic <raceID> <sex>` so the donor-free renderer can be tested with an arbitrary Classic race/sex using already-saved gear. This does not require finding the opponent again; e.g. Undead male is `5 2`. `/rivalsportrait offline synthetic` defaults to the player's race and opposite sex.
- Expand the offline matrix with a fifth `player seed -> raw model file` candidate.
- Give a precise diagnostic when an older prototype sample is genuinely gone instead of implying the named history lookup itself is broken.

## 1.0.14-portrait-offline-lab-fix
- Fix a syntax error in `PortraitLab.lua` that prevented the diagnostic lab from loading. Because the slash handler checks for `DP.PortraitLab`, `/rivalsportrait offline` was silently falling through to the normal capture path and overwriting the sample with the player.
- Preserve the latest non-self portrait sample separately from self tests.
- `/rivalsportrait offline` now prefers the saved opponent sample and can recover the newest opponent with portrait data from World PvP history. `/rivalsportrait offline <name>` selects a specific historical opponent, e.g. `/rivalsportrait offline Johnbasilone`.
- Hide the normal preview when opening the offline matrix so the two diagnostics cannot be confused.

# 1.0.11-portrait-front-facing

- Corrected the reconstructed ModelScene actor facing from `pi` to `0` after the 1.0.10 live test proved `pi` was showing the back of the character on Classic Era.
- Retains the tight race-aware bust framing, manual/template OrbitCamera setup, saved appearance replay, and diagnostic yaw/bounds output from the prior prototype.

# 1.0.10-portrait-tight-bust

- Tightened reconstructed player portraits from a waist-up view to a face-dominant head-and-shoulders crop.
- Raised the camera target using the actor's real active bounds and reduced race-aware camera distance while preserving width/depth guards for broad/tall races.
- Added framing mode to `/rivalsportrait` diagnostics.

# 1.0.7-portrait-camera-init

- Fixed the Classic Era portrait prototype crash in `OrbitCameraMixin:UpdateCameraOrientationAndPosition` by initializing `panningXOffset` and `panningYOffset` on both template-provided and Rivals-created OrbitCameras.
- Hardened partially initialized Era cameras with default input-mode and camera-info state before the ModelScene starts updating.
- Diagnostic camera source now distinguishes the template OrbitCamera from a Rivals-created manual OrbitCamera.

# 1.0.6-portrait-actor-camera

- Fix the blank ModelScene reconstruction shown by the 1.0.5 diagnostics. The actor was loaded, shown, and accepting 4/4 saved appearance IDs, but Classic Era had no active camera because Mainline dress-up scene 596 is not guaranteed to exist even though the transition API does.
- Build and activate a Classic OrbitCamera directly when the scene preset provides none, add explicit portrait lighting/camera clips/FOV, and frame the bust from the actor's live bounding box so Orcs, Tauren, Gnomes, etc. do not depend on one hard-coded human camera.
- Stop treating a successful TransitionToModelSceneID pcall as proof that scene 596 exists; validate its scene data/camera first. `/rivalsportrait` now reports camera source, zoom, target Z, and actor bounds.

# 1.0.5-portrait-actor-framing

- Fix the ModelScene portrait prototype rendering blank despite a successful exact-unit actor and 4/4 saved appearance readback. The reconstruction itself was working; 1.0.4 was placing the diagnostic scene in the center of the window and forcing the dress-up camera to 2.35, which can put the camera inside the character.
- Anchor the ModelScene directly to the existing portrait-model slot, prefer Blizzard's TransitionToModelSceneID(596) setup path, explicitly show the actor, preserve the authored camera distance, and derive a conservative portrait zoom from that distance instead of hard-coding an unsafe value.
- Add actor loaded/shown state and the chosen camera zoom to `/rivalsportrait` diagnostics so any remaining client-side render problem is immediately distinguishable from gear reconstruction.

# 1.0.4-portrait-actor-reconstruction

- Replace the failed plain DressUpModel custom-race path with a dressing-room ModelScene actor using SetModelByUnit(..., customRaceID), preserving a live opponent's exact unit appearance when the unit is still addressable and otherwise borrowing a same-sex player body before applying the saved race and gear.
- Replay and verify the saved appearance IDs on the actor; the actual OPPONENTS portrait path now uses the same reconstruction before legacy display/class fallbacks.

# 1.0.3-portrait-reconstruction

- Rework offline portrait reconstruction to use the Classic custom-race initialization order that old DressUpModel code expects: `SetUnit("none")` first, then `SetCustomRace(raceID, gender)`, with the previous player-seeded route retained only as a fallback. The `/rivalsportrait base` result already proved the saved numeric outfit IDs are valid; this change targets the character-base initialization that was still failing in 1.0.2.
- Expand `/rivalsportrait` diagnostics so a failed reconstruction reports which base/custom-race call failed instead of only saying that no model was available.

# 1.0.2-portrait-reconstruction

- Promote saved opponent outfits from diagnostics into the World PvP OPPONENTS portraits after reload. Reconstruction now seeds a real player-character DressUpModel, switches it to the saved opponent race/sex with SetCustomRace, then replays the captured numeric appearance IDs with TryOn. This follows the in-game `base` result: player-backed numeric replay verified 4/4 saved IDs while both NPC-backed variants verified 0/4.
- Capture and persist race ID, sex, and per-slot visibility alongside the saved appearance IDs. Druid/other shapeshift captures request the native player form so the retained outfit is based on the character rather than the temporary form.
- Keep the exact in-session Blizzard portrait as highest priority. After reload the reconstructed race/sex/outfit now takes priority over the old creature-display and curated race/class fallbacks.
- Make reconstructed models self-refresh on model load, reassert the saved race/sex, and verify saved appearance IDs on bounded delayed reads without changing the stored encounter.

## 1.0.1-portrait-prototype (local experiment)

- Capture observed head, shoulder, chest, cloak, shirt, and tabard appearance/item IDs in encounter data using one throttled DressUpModel, without inspect requests or external software.
- Attempt saved-gear portrait reconstruction after the exact session texture is unavailable. Existing records without gear evidence retain their previous fallback.
- Add `/rivalsportrait` for a live/saved-gear comparison and `/rivalsportrait saved` for replaying the saved sample after reload.
- This is an unverified in-game prototype, not exact image persistence. Enemy gear availability, offline model materials, and framing require Classic client testing. Face/hair customization and helm/cloak visibility preferences are not captured.

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

# 0.21.189-beta

- Remove the star control from Duel Details. Duels can still be starred from History; the expanded detail window no longer carries a favorite control.
- Replace the unsupported Unicode rating arrow in Duel Details with an ASCII `>` separator so Classic fonts no longer render a missing-glyph square between before/after ratings.

# 0.21.188-beta

- Rebuild Duel Details around the World PvP Encounter Details layout: the same 650px window, three-tab Summary / Items & Abilities / Combat Log navigation, 20px content guides, rock background, plaque framing, and Rivals scrollbar treatment.
- Replace the old stacked duel usage + separate “My actions / What happened to me” combat-log layout with a single chronological Items & Abilities dataframe and one merged chronological combat log. Duel usage now records first-use time and target identity for new captures when CLEU provides them.
- Add a Duel Summary page with rating before/after/delta, class-matchup rating, lifetime/rated/opponent-class records, Rivals verification state, duration/date, and a consumable-spend comparison/ledger using the same frozen price engine as World PvP.
- Add an ENEMY BUFFS card to Duel Details. New duels retain opponent buffs observed from target/mouseover at request/countdown/start and during combat, with the same five-minute spam floor; Lightning Shield stays excluded. Buffs are prioritized World Buffs > Flasks > Zanzas > Elixirs > Protection Potions > Class Buffs > miscellaneous/Noggenfogger-style effects.
- Expand duel opponent identity capture with race, sex, faction and creature display ID. Duel Details reuses the World PvP portrait resolver, so newly captured duels can show the real Blizzard display and older records fall back safely to the existing race/class portrait system when enough identity was retained.
- Add a compact class-colored participant filter to Duel Items & Abilities; the currently selected filter is omitted from the open menu, matching the World PvP selector behavior.
- Add a star control directly to Duel Details so memorable duels can be added to/removed from the existing starred History archive without returning to the Character pane.

# 0.21.187-beta

- Make Rivals-generated duel and World PvP screenshots silent on Classic by temporarily unregistering both Blizzard screenshot-notification frames (`ActionStatus` and `ScreenshotStatus`) from the screenshot status events. Their exact prior registration state is restored immediately after `SCREENSHOT_SUCCEEDED`/`SCREENSHOT_FAILED`, so normal manual screenshots remain unchanged.
- Hide any fading screenshot status before an automatic capture so an earlier manual `Screen Captured` message cannot leak into a Rivals screenshot.
- Add a five-second safety restore if the client fails to return a screenshot completion event. The engine-level screenshot/file-write hitch is unchanged because addons cannot make `Screenshot()` asynchronous.

# 0.21.186-beta

- Move Zanza buffs ahead of normal elixirs in ENEMY BUFFS. The priority is now World Buffs > Flasks > Zanzas > Elixirs > Protection Potions > Class Buffs > Noggenfogger/miscellaneous effects.

# 0.21.185-beta

- Remove Lightning Shield from the curated long-duration class buffs shown in World PvP ENEMY BUFFS.
- Reorder ENEMY BUFFS by PvP significance: World Buffs > Flasks > Elixirs > Protection Potions > Class Buffs > Noggenfogger/miscellaneous long-duration consumable effects. Noggenfogger is explicitly kept out of the normal Elixir tier.

# 0.21.184-beta

- Expand the World PvP ENEMY BUFFS card with curated long-duration class buffs. Fortitude/Spirit/Shadow Protection, Mark/Gift of the Wild, long Paladin blessings, mage armors/intellect, warlock armors, Lightning Shield, and similar tracked class buffs now appear when the captured aura duration is at least five minutes. Short in-fight effects, forms, stances, HoTs, shields, and short emergency blessings remain excluded.
- Keep the five-minute rule data-driven from the aura snapshot, so existing encounters that retained aura metadata can render these class buffs without a migration.
- Make Summary, Items & Abilities, and Combat Log use the same 480px World PvP detail-window height. Items & Abilities and Combat Log now scroll inside the same 20px side guides/footprint as Summary instead of growing the detail window to 600px.
- Remove the Combat Log's artificial 200px scroll-child minimum so short logs do not create phantom scroll range inside the Summary-sized pane.

# 0.21.183-beta

- Ignore CLEU death events flagged `unconsciousOnDeath`. Hunter Feign Death can intentionally masquerade as `UNIT_DIED`; it no longer marks the Hunter dead, advances kill stats, or arms a kill screenshot.
- Treat unconscious death events as encounter continuity in the retained combat log instead of recording a real death.

# 0.21.182-beta

- Fix premature World PvP kill screenshots against shapeshifting Druids (and similar health-form transitions). A lethal-looking damage payload now records killing-blow detail only; Rivals waits for PARTY_KILL or UNIT_DIED to confirm the opponent is actually dead before scheduling the screenshot.
- Keep the 0.20-second post-death delay so the corpse and Killing Blow/HK UI have time to settle into the captured frame.

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
