## 0.20.0-beta

### Interface and animations

- Updated Inspect Duel Rating to match Overview's Zurk Maps-style header plaque, taller rating card, beveled stat cards, and spacing; moved the Inspect content up 5px.
- Added a narrow diagonal light sweep when opening Overview.
- Added independent completion highlights for 10 eligible duels and 5 distinct opponents, lighting only each section's text and progress blips.
- Added a one-time Provisional-to-Established celebration on the first Overview opening after qualifying: the card darkens, Provisional rumbles, and a light burst reveals Established.
- The promotion text grows and settles into its normal position, with five evenly spaced Zurk Maps-style glows that remain for one second after settling.
- Used a rendered text texture during resizing, then blended back to the native status label to keep the promotion aligned and smooth.
- Preserved interrupted promotion playback for the next opening and removed the development preview button.

### Fixes

- Prevented opposite-faction targets from triggering recovery whispers and duel-verification handshakes that could produce misleading player-not-found messages.
- Blocked unavailable Inspect profile requests without incorrectly reporting that the other player lacks Rivals.

### Validation

- Expanded regression checks for completion highlights, promotion timing and alignment, replay handling, and faction-aware messaging.
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
