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
- This bounded polish interlude sits before the implemented Phase 4.5 enemy work and does not renumber or broaden the later interaction pass.

## Phase 4.5 Prowler

- Prowler adds a new ambient-only hostile built directly around the central one-spear loop.
- While Akedra holds the spear, the Prowler stays in a cautious stalking band with restrained lateral movement and uses a short defensive pass-through pounce only when Akedra crowds its personal space.
- While the spear is `FLYING` or `LANDED`, it gives one longer red-eye alert and then switches into a faster direct hunt until the spear is legitimately recovered.
- Each unarmed cycle grants exactly one committed hunting pounce attempt; a valid hit knocks Akedra back through the existing player authority, while a dodge or invulnerability rejection leads to a brief punishable skid/stun window.
- The approved presentation now uses the selected `Bonejaw Prowler` visual direction on a roomier `20x18` frame with a `4x6` live sheet, a hooked pale jaw silhouette, and separate hostile-alert, defensive-launch, and hunting-impact Prowler audio responsibilities.
- Prowler dies to one valid thrown-spear hit for `2` points, uses ordinary contact damage, has a dedicated active cap of `1`, and has no authored-wave membership in this phase.
- Its first organic appearance reuses the existing randomized intro-target plus persistent overdue-guarantee system rather than adding a new spawn framework.
- Phase 4.5 deliberately excludes landed-spear theft, ranged behavior, squad logic, and all broader interaction work reserved for Phase 4.6.

## Phase 4.6 Enemy Interaction And Formation Pass

- Phase 4.6.1 adds the shared enemy foundations: deterministic crowd-flow bias for ordinary Normal/Shielded locomotion plus an opt-in authored hostile-displacement seam for later Charger bulldozing.
- Phase 4.6.2 adds the first live cooperation behavior: a Shooter can use a nearby intact Shielded as temporary positional cover, hold behind it, and peek to a side lane before beginning the existing committed attack sequence.
- This cooperation remains positioning-based rather than projectile-blocking: Shielded armor still does not intercept darts or spear throws, and the Shooter still abandons cover whenever the anchor becomes unsuitable.
- Phase 4.6.3 adds one narrow authored projectile interaction: Shooter darts now stop when they hit a Boomer, start an unfused Boomer's existing normal fuse, and are still consumed harmlessly by an already-fusing Boomer without restarting, shortening, cancelling, or duplicating that fuse.
- This remains intentionally narrow rather than universal friendly fire: Shooters still aim at Akedra, darts still ignore other ordinary enemies, and Shielded projectile blocking remains deferred.
- Phase 4.6.4 adds dash-only Charger bulldozing: during the committed dash, a Charger can shove eligible ordinary hostiles out of its lane through the existing authored displacement seam.
- Bulldozing deals no damage, awards no score, does not clear enemy ownership, and does not trigger Boomer fuse by body contact; it exists purely to preserve the dash lane and break up piles.
- Phase 4.6.5 adds one authored Bulwark wave: a center-front Shielded, a slightly offset Shooter behind it, and two shallow-flank Normals on one announced edge, using narrow lane hints and authored formation-bias hints to showcase the already-live cover, peek, and crowd-flow behavior without adding squad AI.
- Phase 4.6.6 adds feedback only for direct same-throw hostile kills: one resolved flight can display `DOUBLE`, `TRIPLE`, or `QUAD` without changing any score value, multiplier, or combo rule.
- Phase 4.6.7 is the bounded final acceptance checkpoint for clean audit output, four-edge Main-backed Bulwark integration coverage, multikill lifecycle regression, documentation consolidation, and the final automated/manual review.
- Broader squad AI, ring formations, projectile interception, indirect-kill attribution, and progression remain deferred rather than expanding this interaction pass.

## Future Polish

- Footprints remain planned for a later movement-polish pass, likely alongside or shortly after the dodge system.
- Ordinary movement footprints should be restrained alternating tracks driven by movement distance rather than every frame.
- Dodges can later add a slightly longer disturbed-earth streak or two quick displaced prints.
- Future footprint work should fade naturally, stay pooled/limited, have no gameplay effect, and be removable through accessibility settings.
- A final visual-art overhaul and overall style review should happen during late-stage polish after gameplay systems are stable.
- A later progression/scoring pass remains responsible for multikill bonus points, score multipliers, timed combos or chains, per-run records, career statistics, achievements, and the attribution policy for indirect kills, Boomer chains, opportunity targets, and other special cases. Phase 4.6.6 intentionally supplies no part of those score or statistics systems.
- Longer-term progression notes include per-run records, career statistics, achievements, unlockable techniques, restrained between-run progression, and later social/platform hooks such as leaderboards, friend score comparisons, or fixed-seed challenge variants.
