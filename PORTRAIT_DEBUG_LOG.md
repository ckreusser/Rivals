# Portrait investigation journal

Read this before changing portrait loading. Keep evidence and hypotheses separate.
Do not describe passing simulated-renderer tests as proof of in-game rendering.

## Latest evidence: 1.0.89 confirmed, 1.0.90 adds feature variation

User confirmed that portraits loaded much more quickly and flushed a second reload. SavedVariables written 2026-09-29 10:12:28 contains a 1.0.89 session on Era 1.15.9. Its retained 120 events include 19 completed outfits, all reporting full gear-ID verification, and zero retained failures. Eighteen request/reveal pairs measure 0.202–0.403 seconds. These measurements cover retained trace events, not every encounter or cold client startup. Human male 1294, Dwarf male 3053 and Gnome male 3055 direct displays all verified gear successfully. User then reported identical facial features within race/sex pairs.

1.0.90 adds eight feature-distinct textured displays per race/sex, mapped by a deterministic player-GUID hash. GUID overrides name and outfit, so copied records/reloads keep the same choice. Finite variants can repeat between different players; they are approximate faces, not recovered historical customization. Exact retained/live opponent bodies remain preferred. Generic donor borrowing is skipped for identity-driven requests, otherwise all same-sex portraits inherit the local player's face again.

Actor reuse must compare selected display with the actor's bound display BEFORE dressing. Rebind the existing actor if necessary, reserve it for the requesting cache key while it loads, and preserve outgoing-card cancellation. Do not preload the 128-model catalog. Matching available faces are preferred to avoid unnecessary rebinding. New display mappings were checked against source race/sex/model/skin and five customization fields; their individual Era renders have not yet been visually checked. Loading, face-reuse, reload-stability, camera and lifecycle regression scripts pass.

## 2026-09-29: observed failures through 1.0.88

- 1.0.87 trace: female templates `1:3` through `8:3` were retained; a request for male Human `1:2` then waited. No compatible body load started. Waiting for a live player of matching sex was an unbounded dependency.
- 1.0.88 removed startup template loading and added direct bare ChrRaces display IDs with `useActivePlayerCustomizations=true`.
- User reports first portrait loaded quickly and correctly, but subsequent portraits appeared as white silhouettes. Screenshot: `C:/Users/Ckreu/AppData/Local/Temp/codex-clipboard-c58517ca-5df2-4d92-9e43-4ca0f7a1c6af.png`.
- User's 10:05 trace: Gnome male display 1563 started at 611266.01, body ready .06, dress started .08, prepared .36 with **0/5 verified**, revealed .51. Human male later prepared with **0/4 verified** and revealed. This is an invalid completed portrait, not simply slow streaming.
- Bare display rows have no CreatureDisplayInfoExtra skin. The assumption that the active-player customization argument supplies a usable opposite-sex/race skin on Era was wrong. API availability and model bounds were insufficient evidence.
- The old preparation code unconditionally called FinishPrepare after .28 seconds. It displayed models even when all equipment failed verification.
- Previous test actors always accepted numeric TryOn, so they could not reproduce this failure. They test scheduling, not engine skin composition or actual dressability.

## 1.0.89 changes and remaining uncertainty

- Direct loading now uses humanoid displays with nonzero CreatureDisplayInfoExtra skin data, joined and checked for all 16 race/sex pairs. See `tests/portrait_body_displays.json` for source rows. These are approximate base faces, not serialized opponent customizations.
- Pass false for active-player customizations so the display retains its own skin data. Keep successful live-player and exact retained-body paths.
- When numeric TryOn does not apply an expected appearance, try SetItemTransmogInfo with an explicit slot. Record both calls and the actual readback.
- Never mark a prepared History portrait ready with missing expected appearance IDs or rejected gear calls. Poll readback without resetting the outfit; failed attempts remain hidden and retry on the same actor after a delay.
- No startup model burst, no class icons, no whole-pane waits. Preserve cameras, 46px viewport, 56px ring, masks, and recorded helms.
- **Not yet verified in game:** whether Era textured humanoid actors accept all recorded gear, whether their original baked clothing is fully replaced, whether skin remains textured after Undress/TryOn, and actual load times. If gear rejects again, inspect method results before another speculative rendering change. Do not reintroduce bare display IDs or unconditional reveal.

## Automatic evidence and how to inspect it

`RivalsDB.portraitLoadTrace` stores the current session's last 120 events plus a separate last-20-failures list, so ordinary successes do not erase the failures. `portraitLoadTraceArchive` preserves three preceding session/version traces rather than deleting evidence on reload. Each body event identifies the source, display, body instance, model file, load/geometry readiness, binding returns, supported equipment APIs, per-slot requested/actual appearance IDs, and gear API returns/errors. Dressing failures have a distinct event. Logs are bounded and do not dump every frame to chat.

WoW writes SavedVariables on reload/logout. After a test, a second `/reload` flushes the tested session to disk; that session may then be in the archive. Do not overwrite or edit SavedVariables while the game is running.

Read-only inspector:

```powershell
& 'C:/Users/Ckreu/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' 'C:/Program Files (x86)/World of Warcraft/_classic_era_/Interface/AddOns/Rivals/tests/inspect_portrait_log.py'
```

It chooses the newest account SavedVariables file, prints its disk timestamp, then the archived/current traces with binding and gear details. An explicit file path may be supplied. If the report still says 1.0.88, the new session has not been flushed; do not claim it contains results of 1.0.89.

Primary API reference: https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorBaseDocumentation.lua

## Checks

The regression suite must exercise silently ignored TryOn, rejected calls, explicit-slot recovery, no reveal with unverified equipment, archive preservation, all race/sex mappings, same-actor retries, selection cancellation, and no unrelated body loads. Run the existing camera/lifecycle and Combat Log checks as appropriate. Append actual game evidence here after the next test.

All six regression scripts passed on this revision. The new read-only inspector also ran successfully against the account's persisted data; the latest file was written at 10:03:25 and contained 1.0.87, not results of 1.0.89. No current-build in-game success has been observed yet.
