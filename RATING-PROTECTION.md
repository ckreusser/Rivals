# Rating protection

## Scope

Version 0.19.0 introduces guard policy 1 for new duels. Existing journal entries retain their original rules. The objective is to reduce rewards for farming a cooperative opponent, while keeping results visible and explaining rating suppression. A guard hit is not proof of intentional losing.

## Implemented defenses

- Level-based reward suppression, including zero transfer at a ten-level winner advantage.
- Lifetime consecutive Rated wins tracked separately for each opponent GUID; diminishing returns start on win nine.
- Rolling seven-day limits of twelve wins and 64 gross overall rating points per opponent. Throwing a loss does not refund either limit.
- Existing 24-hour repeat limits continue to apply, including across seasons.
- Wins by retreat, sub-five-second wins, unknown levels, and newly accepted recovery reports cannot mint rating or placements. Otherwise eligible retreat/short-duel losses still cost rating.
- Cache clearing does not affect the saved duel journal, dueled-target records, or guard counters.
- Duplicate journal IDs do not increment counters twice. Replay reconstructs the same decisions; season calculations inherit lifetime protections.

## Limits and follow-up ideas

The current evidence identifies characters, not independently verified accounts. A group can rotate characters, fabricate shared profiles, modify addon code, or delete saved data. Local enforcement cannot close those trust gaps.

Potential next steps, requiring additional design and testing:

1. **Flag concentrated gains across a small group.** Display how much recent rating comes from the top three opponents. Start with a review indicator; a hard penalty would also affect small legitimate communities.
2. **Record combat participation.** Summarize locally observed damage, healing, and active combat time to flag repeated noncompetitive encounters. Do not infer intent from zero damage alone; crowd control and one-sided matchups are legitimate.
3. **Compare repeated outcomes and timing.** Flag repeated very short duels or highly regular rematch intervals for review. Avoid automatic bans based on timing heuristics.
4. **Use a trusted service for a competitive leaderboard.** Independently accepted match IDs, durable server-side limits, and an explicit identity/trust model would be needed before presenting ratings as authoritative. Two agreeing clients alone are insufficient when both participants cooperate.

Account-wide opponent linking is deliberately absent: the existing capture and protocol do not provide a trustworthy account identifier. Peer-supplied account labels would simply create another spoofable input.

## Validation

The regression suite covers level extremes, unknown levels, reciprocal and class calculations, whole placements, the ninth-win boundary, weekly gross gains, deliberate win/loss alternation, budget expiry, Casual reset attempts, replay, season inheritance, cache clearing, and preservation of legacy calculations. Live-client validation is still needed for level capture and History presentation.
