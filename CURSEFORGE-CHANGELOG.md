## Rivals 1.0.104

Changes since 1.0.101.

- Fixed CharacterStatsClassic stats overlapping the Rivals character page. Stats now hide while Rivals is open and return on the character page, without changing saved settings.
- Added `/rivals toast` to preview the animated 1v3 victory notification without changing encounter history or statistics.
- Added a once-per-login update notice when a newer Rivals release is detected through guild or group addon messages. Remembers the newest detected version across reloads; this does not check CurseForge directly.
- Verified that tracked racial abilities appear in Items & Abilities regardless of cooldown length, including when cooldown data is unavailable. Added regression coverage for duel and World PvP tracking and display; existing behavior is unchanged.
