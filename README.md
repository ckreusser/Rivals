# Rivals

**Make every fight part of your story.** Rivals is a World of Warcraft Classic Era addon that adds a personal duel rating, duel history, open-world PvP encounters, and opponent insights to the Character and Inspect windows.

**Current version:** 0.21.45-beta · **Client:** Classic Era (Interface 11509)

## Features

- **Your duel profile:** View your rating, personal best, rated record, and placement progress in Character → Duels.
- **Rated and Casual duels:** Choose a preference for your next duel. Rated mode requires agreement from both clients before the duel starts.
- **Detailed History:** Browse duels and World PvP encounters in one chronological record. Duel filters preserve mode and season browsing; World PvP cards include Blizzard zone-map art and the recorded fight marker.
- **Matchups:** Review opponents and classes by recency, with class colors, win/loss records, local rating estimates, and dedicated matchup drilldowns.
- **World PvP:** Automatically record open-world player fights without changing Duel Rating. Rivals tracks player headcounts, kills/deaths, honorable kills, location, item/cooldown use, combat events, and encounter-scoped spec evidence.
- **Outnumbered fights:** Solo 1v2+ successes receive dedicated Outnumbered Victory recognition, while partial kills, escapes, trades and deaths keep the actual fight context.
- **Lifetime and seasons:** Keep a lifetime record while starting your own local seasons. Switch periods through the interface and explore your rating graph.
- **Whole-duel placements:** Each eligible duel counts as one placement. Animated progress slots reveal accumulated gains when you open Overview. Completing each requirement highlights its text and blips, and graduation to Established receives a one-time celebration.
- **Inspect other players:** See shared Rivals profiles alongside your own local matchup record. Profile sharing is enabled by default and can be turned off in Manage.
- **Interrupted-duel recovery:** Request a connected opponent's saved report, preview its impact, and choose whether to accept it. Acceptance can be undone, with the original report preserved.

## Getting started

1. Put the `Rivals` folder in `_classic_era_/Interface/AddOns/`. The file `Rivals.toc` must sit directly inside that folder.
2. Enable Rivals on the character-selection AddOns screen.
3. Open **Character → Duels**, or type `/rivals`.
4. Choose Rated or Casual before a duel. Both players need Rivals and must agree to Rated for a newly recorded rated duel.

When installing from GitHub's source ZIP, rename the extracted `Rivals-main` folder to `Rivals` before copying it into AddOns. Existing users should back up `WTF` before replacing addon files.

## How ratings work

Ratings begin at **1500** and use a local Elo model. Repeat matches against the same opponent within 24 hours have diminishing rating impact. Eligible duels still count as whole placements; establishing an overall rating requires **10 eligible duels against at least 5 distinct opponents**.

Rivals keeps separate rated, casual, unconfirmed, and legacy records. Local class-matchup ratings have their own placement requirements. Starting a season does not erase your lifetime history.

### Rating protection (0.19.0 and later)

New results use the following guards in addition to the existing 24-hour repeat limit. Earlier results retain their original rating rules, while their recorded rated encounters seed the opponent counters.

| Guard | Rule |
| --- | --- |
| Level advantage | Rewards halve for every two levels the winner is above the loser: 2 levels = 50%, 4 = 25%, 8 = 6.25%, and 10 or more = zero. Beating a higher-level player receives the normal multiplier. The same multiplier applies to the loser's loss and local reciprocal estimates. |
| Consecutive wins against one character | The first eight have no additional streak penalty; wins 9, 10, and 11 receive 50%, 25%, and 12.5%. Win 12 and subsequent wins receive zero. Wins against other opponents and Casual losses do not reset this opponent's Rated streak. |
| Seven-day wins | After 12 wins against one character within a rolling seven days, further wins award zero until older wins expire. A deliberate loss does not refund this budget. |
| Seven-day rating gains | At most 64 overall rating points can be gained from one character in a rolling seven days. This counts gross gains, so losses do not refund the budget. |
| Observable evidence | Unknown levels and newly accepted peer-recovered results transfer no rating or placement credit. Wins by retreat or in duels under five seconds award no rating or placement credit; otherwise eligible losses still cost rating, so retreating cannot dodge a normal loss. W/L history remains available. |

Multipliers combine; they never increase the existing repeat allowance. Fully suppressed protection results also provide no placement or opponent-diversity credit. Seasons inherit lifetime guard decisions, so changing seasons does not reset the limits. History tooltips explain protection decisions.

Opponent identities and guard counters are stored with the character's saved duel journal, independently of the visible Rivals profile cache. **Clear Rivals cache** removes shared profiles, not duel history or rating protection. The journal rebuilds the counters after reloads and accepted recovery changes.

These are conservative reward rules, not accusations of cheating: a legitimate fast win can also receive no rating. Rivals records character GUIDs, not verified account identities. Local saved data and addon code can be edited or deleted, so these guards cannot make self-reported ratings tamper-proof or reliably identify alternate characters owned by one person. See [RATING-PROTECTION.md](RATING-PROTECTION.md) for the threat model and potential follow-up guards.

## Useful commands

| Command | Action |
| --- | --- |
| `/rivals` | Open your duel profile |
| `/rivals history` | Browse recorded encounters |
| `/rivals world` | Open the World PvP overview |
| `/rivals graph` | View rating history |
| `/rivals opponents` | Browse opponent matchups |
| `/rivals classes` | Browse class matchups |
| `/rivals mode rated` | Prefer Rated for your next duel |
| `/rivals mode casual` | Prefer Casual for your next duel |
| `/rivals lifetime` | Select your lifetime record |
| `/rivals season` | Select the active local season |
| `/rivals season start` | Start a new local season |
| `/rivals share on` / `/rivals share off` | Control profile sharing |
| `/rivals interrupted` | Open interrupted-duel recovery |
| `/rivals export` | Open a diagnostic export |
| `/rivals status` | Show capture status |

## What the data means

Rivals is a **local record**, not a Blizzard rating service or a realm-wide leaderboard. Opponent ratings are estimates learned from your recorded duels. Shared profiles are self-reported, and client agreement is not proof against tampering.

World PvP is a **history and rivalry system, not an Elo rating**. Encounters close after 60 seconds without PvP activity so long Classic Era crowd-control/reset sequences remain one fight. Map markers use the player position Rivals observed during the encounter; participant headcounts are reconstructed from combat-log involvement and are not a claim about every nearby player.

Item and cooldown tracking records observed successful casts during duels and tracked World PvP encounters. It recognizes item-use spells learned from carried/equipped items and abilities with an available base cooldown of **3 minutes or more**. Coverage is partial, especially for unfamiliar opponent items. **N/A means no qualifying usage was recorded**, not proof that nothing was used. Older results cannot be backfilled.

Recovered peer reports are explicitly labeled. They change your record only after you accept the preview; undo recalculates affected ratings. A forced game shutdown can lose data that has not yet been saved.

## Development

Run the regression suite with Python and the `lupa` package:

```sh
python -m pip install lupa
python tests/run.py
```

The suite exercises Lua 5.1 rating, tracking, verification, recovery, usage capture, and mocked UI behavior. In-game appearance and live-client event behavior still need manual validation.

See [CHANGELOG.md](CHANGELOG.md) for version history. Rivals is currently in beta.
