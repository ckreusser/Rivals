# Rivals

**Make every duel part of your story.** Rivals is a World of Warcraft Classic Era addon that adds a personal duel rating, match history, and opponent insights to the Character and Inspect windows.

**Current version:** 0.18.7-beta · **Client:** Classic Era (Interface 11509)

## Features

- **Your duel profile:** View your rating, personal best, rated record, and placement progress in Character → Duels.
- **Rated and Casual duels:** Choose a preference for your next duel. Rated mode requires agreement from both clients before the duel starts.
- **Detailed History:** Browse results with mode and period filters. Tooltips show rating changes, opponent estimates, and recorded item activations and long cooldowns.
- **Matchups:** Review opponents and classes by recency, with class colors, win/loss records, local rating estimates, and dedicated matchup drilldowns.
- **Lifetime and seasons:** Keep a lifetime record while starting your own local seasons. Switch periods through the interface and explore your rating graph.
- **Whole-duel placements:** Each eligible duel counts as one placement. Animated progress slots reveal accumulated gains when you open Overview.
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

## Useful commands

| Command | Action |
| --- | --- |
| `/rivals` | Open your duel profile |
| `/rivals history` | Browse recorded duels |
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

Item and cooldown tracking records observed successful casts during duels. It recognizes item-use spells learned from carried/equipped items and abilities with an available base cooldown of **10 minutes or more**. Coverage is partial, especially for unfamiliar opponent items. **N/A means no qualifying usage was recorded**, not proof that nothing was used. Older results cannot be backfilled.

Recovered peer reports are explicitly labeled. They change your record only after you accept the preview; undo recalculates affected ratings. A forced game shutdown can lose data that has not yet been saved.

## Development

Run the regression suite with Python and the `lupa` package:

```sh
python -m pip install lupa
python tests/run.py
```

The suite exercises Lua 5.1 rating, tracking, verification, recovery, usage capture, and mocked UI behavior. In-game appearance and live-client event behavior still need manual validation.

See [CHANGELOG.md](CHANGELOG.md) for version history. Rivals is currently in beta.
