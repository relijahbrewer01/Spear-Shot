# Spear Shot Roadmap

For the current numeric tuning reference, see [`TUNING.md`](TUNING.md). Runtime values remain in the listed source files.

## Phase 3 Encounter Director

- Authored `Rush`, `Pincer`, and `Charger Hunt` waves are layered over the existing ambient survival curve.
- Encounter flow now has anticipation, active pressure, recovery, and fresh ambient return states.
- Wave telegraphs use readable world-space edge markers plus one restrained locally generated warning cue.
- Wave ownership uses strict death/tree-exit cleanup, tunable population caps, wave-specific start thresholds, and safe spawn deferral.
- Ring formations remain deferred until the first three patterns have been tuned through live play.
- A future Heart Runner belongs to a separate opportunity system and should not consume hostile population slots.

## Phase 4 Enemy Expansion

- Phase 4.1 adds the ambient-only Shielded enemy as the first narrow enemy expansion on top of the Encounter Director.
- Shielded enemies require two committed spear interactions: the first thrown-spear hit breaks the shield and stops the spear for no score, and the second hit kills for `2` points through the existing death/scoring signal.
- Shielded enemies count toward total hostile pressure and wave-start population thresholds, but not toward Normal or Charger caps.
- Phase 4.2 adds the ambient-only Blowgun Shooter as the first ranged hostile: it maintains medium-long distance, telegraphs, locks one aim direction, fires a two-dart straight player-only burst, and then makes a longer tangential arc reposition around Akedra before preparing again.
- Distinct darts in one Shooter burst can each damage Akedra through a narrow player-owned burst context; duplicate callbacks and unrelated damage still respect ordinary invulnerability.
- Shooters die to one valid thrown-spear hit for `2` points, count toward total hostile pressure, have a dedicated cap of `2`, and do not count as Normal, Charger, or Shielded.
- Phase 4.2.2 refines the Shooter into a final hooded-forager presentation on a small `16x18` canvas, locks the approved moss-hood palette cleanup, and adds the successful-shove follow-up behavior while keeping the live gameplay size intentionally small and fair.
- Phase 4.3 adds the ambient-only Exploder as a late-run, cap-1 hopping battlefield weapon: it deals no ordinary contact damage, can be killed safely for `2` before fuse, and otherwise commits to an immediate landing-time three-pulse fuse followed by a damaging core blast and a non-damaging outer shockwave.
- Exploder self-destruction awards no direct score, but enemies killed by the blast still use their normal death/scoring pathways.
- The narrow Shooter follow-up correction in the same subphase makes `AIM` fully committed once it starts, so player distance changes no longer cancel the live wind-up.
- Rush, Pincer, and Charger Hunt remain unchanged; Shielded authored waves, Shooter authored waves, Exploder authored waves, combo scoring, and broader combat frameworks are deferred.

## Phase 4.6 Enemy Interaction And Formation Pass

- Intact Shielded enemies should eventually intercept Shooter darts cleanly while exposed Shielded enemies stop doing so.
- Shielded enemies should later learn clearer screening behavior near Akedra so the player can deliberately use them as mobile cover instead of treating interception as a random accident.
- Shooters should later gain firing-lane repositioning around intact Shielded allies rather than blindly stacking behind them.
- Enemy formations should eventually become more coordinated, with cleaner spacing and role interaction, without turning the project into a full squad AI system.
- Friendly shielding vs projectile conflicts should be resolved in one narrow pass so dart blocking, spear fairness, and enemy readability stay aligned.
- Final interaction and population tuning should happen after those behaviors exist, not before.

## Future Polish

- Footprints remain planned for a later movement-polish pass, likely alongside or shortly after the dodge system.
- Ordinary movement footprints should be restrained alternating tracks driven by movement distance rather than every frame.
- Dodges can later add a slightly longer disturbed-earth streak or two quick displaced prints.
- Future footprint work should fade naturally, stay pooled/limited, have no gameplay effect, and be removable through accessibility settings.
- A final visual-art overhaul and overall style review should happen during late-stage polish after gameplay systems are stable.
- Same-throw multikill scoring remains planned as a later chain-bonus system that preserves base enemy values, resolves when one throw fully ends, and can eventually surface feedback such as DOUBLE or TRIPLE.
- Longer-term progression notes include per-run records, career statistics, achievements, unlockable techniques, restrained between-run progression, and later social/platform hooks such as leaderboards, friend score comparisons, or fixed-seed challenge variants.
