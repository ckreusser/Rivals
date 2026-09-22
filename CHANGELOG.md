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
