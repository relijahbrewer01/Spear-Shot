# Spear Shot Roadmap

For the current numeric tuning reference, see [`TUNING.md`](TUNING.md). Runtime values remain in the listed source files.

## Phase 3 Encounter Director

- Authored `Rush`, `Pincer`, and `Charger Hunt` waves are layered over the existing ambient survival curve.
- Encounter flow now has anticipation, active pressure, recovery, and fresh ambient return states.
- Wave telegraphs use readable world-space edge markers plus one restrained locally generated warning cue.
- Wave ownership uses strict death/tree-exit cleanup, tunable population caps, wave-specific start thresholds, and safe spawn deferral.
- Ring formations remain deferred until the first three patterns have been tuned through live play.

## Phase 4 Enemy Expansion

- Phase 4.1 adds the ambient-only Shielded enemy as the first narrow enemy expansion on top of the Encounter Director.
- Shielded enemies require two committed spear interactions: the first thrown-spear hit breaks the shield and stops the spear for no score, and the second hit kills for `2` points through the existing death/scoring signal.
- Shielded enemies count toward total hostile pressure and wave-start population thresholds, but not toward Normal or Charger caps.
- Phase 4.2 adds the ambient-only Blowgun Shooter as the first ranged hostile: it maintains medium-long distance, telegraphs, locks one aim direction, fires a two-dart straight player-only burst, and then makes a longer tangential arc reposition around Akedra before preparing again.
- Distinct darts in one Shooter burst can each damage Akedra through a narrow player-owned burst context; duplicate callbacks and unrelated damage still respect ordinary invulnerability.
- Shooters die to one valid thrown-spear hit for `2` points, count toward total hostile pressure, have a dedicated cap of `2`, and do not count as Normal, Charger, or Shielded.
- Phase 4.2.2 refines the Shooter into a final hooded-forager presentation on a small `16x18` canvas, locks the approved moss-hood palette cleanup, and adds the successful-shove follow-up behavior while keeping the live gameplay size intentionally small and fair.
- Phase 4.3 adds the ambient-only Boomer as a late-run, cap-1 hopping battlefield weapon: it deals no ordinary contact damage, can be killed safely for `2` before fuse, and otherwise commits to an immediate landing-time three-pulse fuse followed by a damaging core blast and a non-damaging outer shockwave.
- Boomer self-destruction awards no direct score, but enemies killed by the blast still use their normal death/scoring pathways.
- The narrow Shooter follow-up correction in the same subphase makes `AIM` fully committed once it starts, so player distance changes no longer cancel the live wind-up.
- Rush, Pincer, and Charger Hunt remain unchanged; Shielded authored waves, Shooter authored waves, Boomer authored waves, combo scoring, and broader combat frameworks are deferred.

## Phase 4.4 Heart Runner Opportunity

- Heart Runner is now implemented as a separate opportunity system rather than a hostile enemy kind, so it does not consume EncounterDirector hostile population slots, per-type caps, or wave thresholds.
- The Runner unlocks around `20s`, rolls on its own `8-12s` timer, becomes more likely at lower player health, and still respects one-active Runner-or-pickup pressure for readability.
- At `1 HP`, the approved live tuning now uses a `15%` organic chance plus a `90s` continuous active-gameplay grace that guarantees only the next later valid opportunity, not automatic healing.
- It now enters visibly, wanders calmly for up to `8.0s` at `70px/s`, and only becomes startled once Akedra holds the spear inside the derived `134px` threat radius.
- The approved live presentation keeps the same small pulse-beast design but now plays a four-frame calm strut, a single readable `0.40s` startled hop, and a faster four-frame panic sprint.
- Once the proximity trigger fires, panic is irreversible, the fair flee route locks away from Akedra, and the Runner keeps its full `140px/s` panic speed until cleanup.
- Natural cleanup is based on crossing the exit plane assigned to the Runner's currently locked casual or panic route, preventing side-boundary despawns from Boomer shockwaves or other authored displacement.
- A valid thrown-spear hit defeats the Runner for `1` point without stopping spear flight and spawns one temporary heart pickup clamped inside the arena.
- Pickup resolution applies the opportunity cooldown exactly once, either on unharmed escape or after the defeated Runner's pickup is collected or expires.

## Phase 4 Interlude 1 — Input & Audio Polish

- One held-spear throw pressed during Akedra's dodge is buffered with the latest captured target and released exactly once through the normal throw path after `dodge_ended`.
- Spear throw, dodge, and player hurt sounds now use independent three-clip non-repeating pools driven by a dedicated audio random source that does not alter gameplay randomness.
- Legitimate landed-spear recovery now plays one dedicated ready cue after the spear is held again, including overlap-safe forced landings that use the same pickup authority.
- A second locally generated calm hunter loop alternates deterministically with the original whenever a fresh run begins through restart.
- This is a bounded polish interlude and does not replace, renumber, or expand the next Phase 4.5 enemy-development work.

## Phase 4.6 Enemy Interaction And Formation Pass

- Shielded and Shooter cooperation should come from positioning rather than a projectile-blocking behavior.
- The simplest stable model should be chosen during that pass: either Shielded screens between Akedra and Shooter, or Shooter tries to remain behind Shielded relative to Akedra.
- Shooters should later gain firing-lane repositioning around Shielded allies rather than blindly stacking behind them.
- Shooter darts should later stop when they hit a Boomer; the first dart to hit an unarmed Boomer should begin its normal fuse, while darts hitting an already fusing Boomer should stop without restarting, shortening, cancelling, or duplicating that fuse.
- Enemy formations should eventually become more coordinated, with cleaner spacing and role interaction, without turning the project into a full squad AI system.
- Final interaction and population tuning should happen after those behaviors exist, not before.

## Future Polish

- Footprints remain planned for a later movement-polish pass, likely alongside or shortly after the dodge system.
- Ordinary movement footprints should be restrained alternating tracks driven by movement distance rather than every frame.
- Dodges can later add a slightly longer disturbed-earth streak or two quick displaced prints.
- Future footprint work should fade naturally, stay pooled/limited, have no gameplay effect, and be removable through accessibility settings.
- A final visual-art overhaul and overall style review should happen during late-stage polish after gameplay systems are stable.
- Same-throw multikill scoring remains planned as a later chain-bonus system that preserves base enemy values, resolves when one throw fully ends, and can eventually surface feedback such as DOUBLE or TRIPLE.
- Longer-term progression notes include per-run records, career statistics, achievements, unlockable techniques, restrained between-run progression, and later social/platform hooks such as leaderboards, friend score comparisons, or fixed-seed challenge variants.
