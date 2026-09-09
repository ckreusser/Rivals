# Rivals 0.12.1-beta

## Install or update

1. Exit WoW normally. Back up your existing Rivals addon and account SavedVariables/Rivals.lua files before beta testing.
2. Extract the ZIP into World of Warcraft/_classic_era_/Interface/AddOns/. The result must be AddOns/Rivals/Rivals.toc, without a second nested Rivals directory.
3. Enable Rivals at character selection. Update both participating clients to this version.
4. Open Character > Duels or use /rivals. Rivals stores its data in the account-level RivalsDB namespace.

Targets Classic Era (Interface 11509). No external libraries are required. The archive contains addon source and documentation only; no player data or account files.

## Quick use

- The Rated/Casual button selects your preference. Rated requires agreement before combat starts; watch the countdown messages.
- /rivals verify on enables agreement and result exchange. Profile summary sharing defaults on and can be disabled in Manage or with /rivals share off.
- History filters distinguish Rated, Casual, Unconfirmed and Legacy. Both clients means outcome agreement, not proof of untampered data.
- Leaderboard lists self-reported lifetime profiles you inspected; it is not a realm-wide ladder.
- History > Interrupted lists missing-session reports. Target the connected opponent to request recovery.
- Click a peer report to review its net rating effect before applying it. Accepted reports remain labeled Peer report.
- Interrupted > Accepted shows acceptance time and saved net impact. Click an entry to preview Undo acceptance. Undo restores the report and replays subsequent ratings; it can change current repeat weights. A later acceptance receives a new record ID.
- /rivals export includes acceptance and undo audit events. Acceptances made before this beta may lack original net-impact metadata; their timestamp and accepted record remain available.

## Beta test checklist

1. With both players Rated, complete two duels, alternating challenger. Expect Rated and Both clients without toggling preferences. Repeat limits can correctly yield zero rating change.
2. Set one player Casual. Complete a duel: history updates, rating does not. Restore Rated.
3. Disable verification on one client for one duel. Expect Unconfirmed and zero rating change; re-enable verification.
4. Cancel during countdown. Expect no new W/L or rating change.
5. After Rated agreement and combat start, disconnect one client and finish the duel. Reconnect, target the opponent and check Interrupted. Expect a peer report, not automatic rating changes.
6. Preview acceptance, cancel, and verify nothing changed. Apply once, then reload: one Peer report entry persists.
7. Open Interrupted > Accepted, check timestamp/impact, preview Undo, and cancel. Then Undo: the report returns to Interrupted and the recalculated rating matches the preview. Reload and verify it persists. Reaccept once and verify no duplicates.
8. Inspect a sharing player; check leaderboard sort/filter/cache clear. These actions must not change duel history.

## Validation and limitations

Automated Lua 5.1 checks cover parser/tracker, Elo replay, seasons, handshake failures, recovery, acceptance/undo and mocked UI. Earlier live sessions exercised Rated/Casual, filters, sharing, cancellation, reload/disconnect recovery and acceptance persistence. This beta's new Undo UI still requires in-game validation.

Ratings are local estimates. Recovery is voluntary and cannot enforce penalties against modified clients. A forced process exit can lose unsaved session state. Recovery depends on a peer's saved handshake-linked result; missing season context affects lifetime only. Diagnostic captures and unknown duration are not fabricated into observations.

For a failure: note time, character, challenger, selected modes and what happened. Reload both clients to save diagnostics, then provide /rivals export output or the relevant saved logs. Logs contain character names and duel history; review before sharing publicly.

## Rollback

Exit WoW normally. Restore the addon and SavedVariables backups together if reverting to an earlier beta after changing accepted reports. Keep a separate copy of the current data first; restoring an older backup discards results recorded since that backup.
