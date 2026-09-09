# Rivals UI direction

Design proposal for the next layout pass; not the currently installed layout.

## Priorities

Make the rating, recent progress and next action easy to find. Keep the Classic frame, portrait, dark textured surface and restrained gold headings. Reduce red buttons to actions: selected pages and passive status should not look like more actions. Use consistent spacing and fewer full-width paragraphs.

## Navigation

One page row: Overview, History, Matchups, Profiles. Matchups contains Opponents and Classes as a local selector. Rename the local leaderboard Profiles so it does not imply an authoritative realm ladder. Put Settings and recovery in a small Manage entry, with a count when reports need review. No recovery controls on ordinary match history.

Keep one period selector in the header. Put the next-duel mode preference in Overview and Settings; during a duel show a compact status strip on every page. Preference and locked mode must remain distinct. Do not add another permanent line for every possible state.

## Overview

Top: large rating and concise placement state. Then the selected period's Rated W/L, peak and current rated streak, computed from rated records. All-duel and legacy statistics remain available in expandable record details; do not relabel existing all-duel streaks as rated.

Middle: compact rating trend. Bottom: one latest-result summary and the next-duel preference. Placement deficits appear only while provisional, with detailed weighting in a tooltip. No permanent technical disclaimers, class summary paragraph or stack of three navigation buttons.

## History

Compact period/mode filters above rows. Each row gives date, opponent, outcome and rating delta, aligned consistently. A small evidence tag distinguishes local, both-client and accepted peer reports. Mode gets a short badge rather than a third full-width text line. Full timestamps, repeat weights, duration, reasons and rating calculations stay in the tooltip.

## Matchups and profiles

Opponent/class rows align name, rating and W/L. Show the selected record scope once above the list. Detailed mode breakdown lives in the tooltip. Profiles must clearly indicate self-reported data with one concise caption; timestamp and provenance remain available on hover.

## Manage recovery

Two states: Needs review and Accepted. One request-status area and one retry action. Clicking a report opens the review dialog. The review leads with the net current rating effect and its scope; keep accept/cancel or undo/cancel in fixed positions. Keep historical duel delta distinct from current net impact. Full audit is a secondary detail.

## Implementation sequence

1. Rearrange navigation and Overview with existing functionality preserved.
2. Consolidate matchups and simplify rows/filters.
3. Move recovery and preferences into Manage, preserving clear live duel status.
4. Validate frame fit and text length in both Character and Inspect panels using the user's clients. No external testers or publication assumed.

Acceptance: no overlapping content, no duplicated navigation rows, no technical paragraph competing with the rating, and every current feature remains reachable. Existing records, rating rules and handshake behavior remain unchanged by the visual pass.
