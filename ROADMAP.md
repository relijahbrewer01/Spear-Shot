# Spear Shot Roadmap

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
- Phase 4.2 adds the ambient-only Blowgun Shooter as the first ranged hostile: it maintains medium-long distance, telegraphs, locks, and fires a two-dart straight player-only burst before relocating.
- Shooters die to one valid thrown-spear hit for `2` points, count toward total hostile pressure, have a dedicated cap of `1`, and do not count as Normal, Charger, or Shielded.
- Rush, Pincer, and Charger Hunt remain unchanged; Shielded authored waves, Shooter authored waves, combo scoring, and broader combat frameworks are deferred.
- Shielded dart interception is intentionally deferred to a focused Phase 4.2.1 pass: intact shields should later block darts without taking damage, breaking, or weakening.

## Future Polish

- Footprints remain planned for a later movement-polish pass, likely alongside or shortly after the dodge system.
- Ordinary movement footprints should be restrained alternating tracks driven by movement distance rather than every frame.
- Dodges can later add a slightly longer disturbed-earth streak or two quick displaced prints.
- Future footprint work should fade naturally, stay pooled/limited, have no gameplay effect, and be removable through accessibility settings.
- A final visual-art overhaul and overall style review should happen during late-stage polish after gameplay systems are stable.
- Same-throw multikill scoring remains planned as a later chain-bonus system that preserves base enemy values, resolves when one throw fully ends, and can eventually surface feedback such as DOUBLE or TRIPLE.
- Longer-term progression notes include per-run records, career statistics, achievements, unlockable techniques, restrained between-run progression, and later social/platform hooks such as leaderboards, friend score comparisons, or fixed-seed challenge variants.
