# Spear Shot

Current milestone: `Spear Shot v0.6.0-alpha.3 - Boomer`

## Game concept

Spear Shot is a small top-down survival prototype built in Godot 4.

You only own one spear. Throwing it can clear enemies, but it also leaves you unarmed until you physically recover it. The main tension comes from deciding when it is safe to chase the landed spear while enemies close in.

## How to run it

1. Open the project folder in Godot 4.
2. Run `Main.tscn`, or use the project main scene.

If Godot is available on your command line, you can also run the project from this folder with a Godot 4 executable, for example:

```powershell
godot4 --path .
```

The game keeps a low internal resolution of `384x216` and opens at a default displayed size of `1536x864`. Rendering uses nearest-neighbor filtering with integer-scaled `16:9` presentation, so resizing preserves crisp pixels and uses letterboxing or pillarboxing instead of blurry fractional scaling.

For a human-readable snapshot of gameplay timers, distances, speeds, probabilities, caps, and damage values, see [`TUNING.md`](TUNING.md). The source code remains authoritative for runtime values.

## Controls

- `W`, `A`, `S`, `D`: move
- Right mouse button: move to the clicked destination and show a brief trap-style ground marker
- Mouse: aim
- Left mouse button or `Q`: throw spear
- `Shift`: dodge toward aim, cancel prior movement intent, and require previously held movement keys to be released before they move again
- `Spacebar`: dodge using movement direction first, then click-move direction, then aim fallback while preserving movement continuity
- `Escape` or `P`: pause, or begin the faster `3 2 1` resume countdown
- Left or right mouse button while paused: begin the faster `3 2 1` resume countdown and consume that click
- `R`: restart after death

## Development debug controls

- Temporary Shielded live-test hook: `1` debug-spawns one Shielded enemy while `DEBUG_SHIELDED_SPAWN_ENABLED` is `true` in `scripts/main.gd`
- Temporary Shooter live-test hook: `2` debug-spawns one Blowgun Shooter while `DEBUG_SHOOTER_SPAWN_ENABLED` is `true` in `scripts/main.gd`
- Temporary Boomer live-test hook: `3` debug-spawns one Boomer while `DEBUG_BOOMER_SPAWN_ENABLED` is `true` in `scripts/main.gd`
- These are intentionally separate from normal player controls and can be disabled by setting their constants to `false`

## HUD layout

- Active play keeps a small survival timer in the top-left corner and `SCORE` in the top-right corner
- Health is shown as world-space pips under Akedra in a shallow arc instead of a boxed HUD panel
- Pause uses a simple dark overlay with `PAUSED`, and game-over controls stay interactive after death

## Art direction

- The visual pass keeps the arena readable first: muted daylight tones, clear silhouettes, and bright Charger telegraphs over a medium-value floor instead of a dark moody backdrop
- The player, enemies, Charger, and spear now use small locally generated pixel sprites with lightweight bob/pulse animation instead of pure debug shapes
- Shielded enemies use a compact broad body plus visible hide/wood/bone plate primitives, keeping the protected state readable without a magical glow or boss-sized silhouette
- Blowgun Shooters use a small wiry hooded-forager silhouette with a runtime-rotated reed blowgun, keeping the body collision stable while the aimed weapon remains readable
- The approved final Shooter body uses a coherent moss-hood palette with a pale face, charcoal-brown torso, and restrained rust pouch on the roomier `16x18` canvas, keeping it small, readable, and distinct from the melee cast at `384x216`
- The Charger telegraph stays intentionally high-contrast so deaths read as timing mistakes rather than surprise collisions
- Charger visuals, shadow, and telegraph now stay synchronized to the same moving gameplay body instead of running on separate transform paths

## Combat feedback

- Extremely close spear hits trigger a tiny hit stop to punctuate desperate point-blank throws without affecting the normal pause state
- Akedra's contact-damage footprint is slightly smaller than his movement/body footprint so near misses feel a bit fairer
- Akedra now stays upright during normal movement and faces left/right through horizontal sprite flipping instead of rotating upside down
- Dodges now read through a full body roll and a short fading afterimage trail, keeping the spear aim independent from the body animation
- Dodge movement lasts `0.20` seconds, travels `36` pixels, and uses a `2.00` second shared cooldown
- A separate `0.10` second damage-immunity grace window begins when dodge movement ends, allowing Akedra to emerge cleanly before normal contact damage resumes
- `Shift` dodges toward aim, clears click-to-move, and suppresses only the WASD keys already held until each is released
- `Spacebar` dodges along current movement and preserves held WASD or click-to-move continuity afterward
- A new right-click issued during either active dodge is buffered, replaces any earlier buffered click, and begins moving Akedra on the first normal frame after the roll
- A tiny world-space exertion wisp beside Akedra shrinks with the real cooldown and gives one restrained glint when dodge becomes ready
- A locally generated physical swoosh blends displaced air, cloth movement, body weight, and a small foot scuff once per valid dodge
- The shared dodge cooldown starts when the dodge begins, not when it ends

## Asset generation

- `art/arena/arena_floor.png`: original arena floor texture with worn off-center scuffs, dirt patches, and bright boundary stones
- `art/sprites/player_hunter.png`: hunter/player sprite
- `art/sprites/enemy_creature.png`: base enemy sprite
- `art/sprites/charger_beast.png`: Charger sprite
- `art/sprites/shielded_enemy.png`: compact broad Shielded enemy body sprite
- `art/sprites/shooter_enemy.png`: final approved Blowgun Shooter body sprite on a small `16x18` canvas using the cleaned moss-hood palette
- `art/sprites/boomer_enemy.png`: active Boomer sprite chosen from the local concept pass and kept on the same small readable scale as the rest of the special roster
- `art/sprites/spear_hunter.png`: spear sprite
- `music/quiet_hunter_loop.wav`: original calm retro loop generated locally for the MVP
- `audio/wave_warning.wav`: restrained local warning cue for authored encounter telegraphs
- `audio/shield_break.wav`: local physical crack/thud cue for Shielded shield break
- `audio/blowgun_windup.wav`: local reed/breath cue for Blowgun Shooter aiming
- `audio/blowgun_fire.wav`: local dry puff/snap cue for Blowgun Shooter dart release
- `audio/blowgun_shove.wav`: local reed/wood swish-thump cue for Blowgun Shooter shove
- `audio/boomer_hop_prep.wav`: local compressed hop-prep cue for the Boomer
- `audio/boomer_land.wav`: local physical landing cue for the Boomer
- `audio/boomer_fuse.wav`: local three-pulse fuse escalation cue for the Boomer
- `audio/boomer_explosion.wav`: local physical blast cue for the Boomer
<<<<<<< Updated upstream
=======
- `audio/heart_runner_appear.wav`: local skittering arrival cue for the Heart Runner
- `audio/heart_runner_alarm.wav`: local startled alarm cue for the Heart Runner's panic trigger
- `audio/heart_pickup_spawn.wav`: local reward-pop cue for a spawned heart pickup
- `audio/heart_pickup_collect.wav`: local recovery cue for collecting the heart pickup
- `audio/heart_pickup_expire.wav`: quiet warning cue used during the pickup's final expiration window
>>>>>>> Stashed changes
- `tools/generate_phase1_assets.py`: reproduces the arena and sprite art assets locally
- `tools/generate_phase4_assets.py`: reproduces the Shielded, Shooter, and Boomer sprites plus the temporary local comparison outputs for the Phase 4 concept passes
- `tools/generate_music.py`: synthesizes the background music loop locally as uncompressed `44.1 kHz`, `16-bit`, stereo `.wav`

## Scene/script structure

- `Main.tscn` and `scripts/main.gd`: overall game flow, spawning, scoring, timer, restart, and screen shake
- Run restarts reset gameplay state in place so window size, position, and maximized state are preserved
- `Arena.tscn` and `scripts/arena.gd`: arena visuals, play bounds, and enemy edge spawn positions
- `Player.tscn` and `scripts/player.gd`: movement, aiming, health, invulnerability, upright facing, dodge readability visuals, and narrow authored forced movement with shove-specific temporary damage protection
- `scripts/player_dodge_trail.gd`: fixed-pool dodge afterimages sampled from Akedra's body visual
- `scripts/player_dodge_cooldown_indicator.gd`: world-space exertion wisp and brief ready glint driven by the shared dodge cooldown
- `Spear.tscn` and `scripts/spear.gd`: the single spear state loop (`HELD`, `FLYING`, `LANDED`)
- `scripts/spear_trail.gd`: non-rotating deterministic spear trail renderer
- `Enemy.tscn` and `scripts/enemy.gd`: the normal enemy, shared enemy helpers, contact damage, separation, scoring, and death feedback
- `Charger.tscn` and `scripts/charger.gd`: Charger telegraph, locked dash, recovery, and distinct visuals
- `ShieldedEnemy.tscn` and `scripts/shielded_enemy.gd`: two-hit Shielded enemy, shield-break stagger, and exposed death through the shared score path
- `ShooterEnemy.tscn` and `scripts/shooter_enemy.gd`: ranged Blowgun Shooter, range maintenance, committed aim/lock/two-dart burst, non-damaging shove, successful-shove follow-up reposition, longer post-burst relocation, and dart request signal
- `BoomerEnemy.tscn` and `scripts/boomer_enemy.gd`: ambient-only hopping Boomer, immediate landing-time fuse decision, two-radius detonation, and enemy-owned explosion resolution
- `BoomerBlastEffect.tscn` and `scripts/boomer_blast_effect.gd`: short-lived visual-only Boomer blast effect
<<<<<<< Updated upstream
=======
- `HeartRunner.tscn` and `scripts/heart_runner.gd`: non-hostile opportunity runner with visible calm entry, limited wandering, proximity-triggered panic, locked casual-or-panic exit routing, explicit spear-hit handling, authored displacement support, and currently locked route exit-plane cleanup
- `HeartPickup.tscn` and `scripts/heart_pickup.gd`: temporary pickup spawned by a defeated Runner, including final warning pulse/flicker and overlap-safe collection
>>>>>>> Stashed changes
- `DartProjectile.tscn` and `scripts/dart_projectile.gd`: player-only dart projectile with straight-line travel, burst-aware player damage context, invulnerability-safe contact, and cleanup
- `HUD.tscn` and `scripts/hud.gd`: minimal score, pause, and game-over UI
- `scripts/player_health_pips.gd`: world-space health pip display attached under the player
- `scripts/destination_marker.gd`: brief right-click destination feedback marker
- `scripts/encounter_director.gd`: authored wave scheduling, population caps, state transitions, and strict cleanup
- `scripts/encounter_telegraph.gd`: readable world-space edge warning renderer
- `scripts/high_score_store.gd`: local high-score loading and saving
- `tools/generate_sfx.py`: local retro-style placeholder sound generation
- `tools/generate_phase1_assets.py`: local pixel-art-style sprite and arena generation
- `tools/generate_music.py`: local background music generation
- `tools/bugfix_audit.py`: lightweight static audit for Phase 1 spawn wiring, scaling, minimal HUD, pause support, and audio bus setup
- `tools/encounter_director_audit.py`: static Phase 3 encounter, safety, and warning-audio audit
- `tools/EncounterDirectorRuntimeAudit.tscn`: focused runtime audit for Rush, Pincer, and Charger Hunt
- `tools/EncounterIntegrationAudit.tscn`: Main-scene telegraph, SFX, spawn, cleanup, recovery, and restart audit
- `tools/shielded_enemy_audit.py`: static Phase 4.1 Shielded enemy contract audit
- `tools/ShieldedEnemyRuntimeAudit.tscn`: runtime audit for Shielded hit ordering, STOPPED spear behavior, score, stagger, and ambient cap removal
- `tools/shooter_enemy_audit.py`: static Phase 4.2 Shooter and dart contract audit
- `tools/shooter_visual_concept_audit.py`: verifies the temporary Shooter palette-variant outputs and native-scale comparison image
- `tools/ShooterEnemyRuntimeAudit.tscn`: runtime audit for Shooter movement, aim locking, darts, damage rules, cleanup, and intro integration
- `tools/boomer_enemy_audit.py`: static Phase 4.3 Boomer contract audit
- `tools/BoomerEnemyRuntimeAudit.tscn`: runtime audit for Boomer movement, fuse, detonation, scoring, cleanup, and intro integration
- `tools/PlayerForcedMovementRuntimeAudit.tscn`: runtime audit for authored player forced movement, dodge interruption, and intent preservation
- `tools/tuning_audit.py`: lightweight static audit for the root gameplay tuning index

## Enemy behavior

- Normal enemy: slow direct pursuit, worth `1` point
- Charger: unlocks early but starts uncommon, chases briefly, telegraphs with a visible dash line, commits to one dash direction, then recovers, worth `3` points
- Shielded: compact ambient-only armored enemy, first thrown-spear hit breaks the shield and stops the spear for no score, second hit kills for `2` points
- Shielded starts at `body_radius = 9.0`, `separation_distance = 19.0`, and `stopped_hit_landing_clearance = 4.0` so the stopped spear lands close but outside the reduced body footprint
- Blowgun Shooter: small ambient-only ranged enemy, tries to hold medium-long distance, visibly aims before locking one dart direction, fires a two-dart straight player-only burst, then performs a longer tangential relocation around Akedra, and dies to one spear hit for `2` points
- The two darts use the same locked direction with a deterministic `0.17` second burst interval, so one successful sidestep can avoid the whole committed volley
- Once a Shooter begins `AIM`, that wind-up is committed through the ordinary `AIM -> LOCKED -> FIRE -> RECOVER` sequence unless the Shooter dies or is cleaned up
- Shooter body overlap no longer deals ordinary enemy contact damage
- At very close range, the Shooter can use a short non-damaging shove that knocks Akedra back through the existing movement authority, grants shove-only temporary damage protection while that authored displacement resolves, and then quickly repositions into a normal readable follow-up shot
- Darts travel at `145` pixels per second for up to `1.8` seconds, damage Akedra only through the existing player damage authority, and are consumed harmlessly by active dodge or dodge exit grace
- A narrow burst context lets two distinct darts from the same Shooter volley each deal one damage, while duplicate callbacks from either individual dart and unrelated damage sources still respect normal invulnerability
- Darts currently do not collide with the spear, enemies, or Shielded enemies; Phase 4.6 cooperation is planned around positioning-based Shielded/Shooter screening rather than projectile blocking
- Boomer: ambient-only late-run hopping hazard with no ordinary contact damage, one active cap, safe pre-fuse spear kill for `2`, and a committed three-pulse fuse that starts immediately when it lands inside range
- The Boomer only translates during its hop; hop prep, landing recovery, and fuse stay positionally stationary apart from visual-only squash, settle, and pulse cues
- An armed Boomer detonates into a damaging core blast plus a non-damaging outer shockwave, can be triggered early by a valid thrown-spear hit during fuse, and awards no direct score for self-destruction
- If Akedra is currently in shove-protected forced movement from a successful Shooter shove, the Boomer core blast deals no health damage and does not replace that authored movement with a second knockback impulse
- A Boomer outer shockwave can lightly nudge an already landed spear by `20` pixels, keeping it in `LANDED`/`FETCH`, clamping it inside the arena, and preserving normal retrieval behavior

<<<<<<< Updated upstream
=======
## Opportunity behavior

- Heart Runner: separate from the hostile population system, unlocks around `20` seconds, rolls on its own `8-12` second opportunity timer, and becomes more likely at lower player health
- At `1 HP`, the organic Heart Runner chance is now `15%`, and `90s` of continuous active one-health gameplay guarantees one later valid opportunity check if ordinary rolls never succeed
- It makes a visible calm entry, wanders for up to `8.0` seconds at `70px/s`, and then chooses a calm timeout exit if it never panics
- Akedra only threatens it while holding the spear inside the derived `134px` startle radius (`150px` max throw range minus a `16px` margin)
- Picking up the spear outside that radius keeps the Runner calm until either Akedra, the Runner, or a Boomer displacement carries it inside range; throwing the spear first clears that pending threat
- A valid proximity trigger plays one `0.40s` startled hop plus alarm cue, then locks into an irreversible `140px/s` panic sprint along a fair flee route away from Akedra
- It enters visibly, then later locks either a calm exit route or a panic flee route; cleanup happens only after it crosses that currently locked route's assigned exit plane plus the cleanup margin, so Boomer displacement through another boundary does not count as escape
- A valid thrown-spear hit defeats it for `1` point without stopping spear flight
- Defeating it spawns one temporary heart pickup clamped inside the playable arena, healing Akedra by `1` up to a temporary `4` health maximum
- The one-health grace guarantees an opportunity, not automatic healing: it pauses with gameplay, healing above one resets it, any successful organic one-health Runner spawn also resets the interval, and an active Runner, active pickup, the normal cooldown, or safe-entry failure can still defer a due guarantee
- Debug spawning does not affect organic grace time, due-state, cooldown, or later eligibility
- Only one Heart Runner or heart pickup may exist at a time, and the whole opportunity system stays outside hostile caps, wave thresholds, and encounter pressure bookkeeping

>>>>>>> Stashed changes
## Encounter director

- Ambient survival spawning now gives way to temporary authored events after roughly `28-34` seconds
- Ambient density ramps slowly from a `2.20` second spawn interval toward a `0.75` second floor reached after roughly four minutes
- A bright world-space edge bracket and one restrained warning sound announce each wave for `1.75` seconds
- Ambient spawning pauses during the telegraph, active wave, and `3.0` second recovery window
- Ambient resumes afterward with a fresh interval calculated from the current survival-time difficulty
- `Rush` sends four Normals from one announced edge
- `Pincer` alternates six Normals between two opposite announced edges
- `Charger Hunt` sends two Normals followed by one Charger from one announced edge
- Each wave has its own start pressure budget: `Rush` at five or fewer hostiles, `Charger Hunt` at four or fewer, and `Pincer` at three or fewer
- Tunable safety caps begin at `10` total hostiles, `9` Normals, and `2` Chargers
- Shielded enemies count toward total hostile pressure, have a dedicated cap of `1`, and do not count as Normals or Chargers
- Shooter enemies count toward total hostile pressure, have a dedicated cap of `2`, and do not count as Normals, Chargers, or Shielded
- Boomers count toward total hostile pressure, have a dedicated cap of `1`, and do not count as Normals, Chargers, Shielded, or Shooters
- Charger ambient spawns unlock around `15` seconds with a small capped weight
- Shielded ambient spawns unlock around `25` seconds with a smaller capped weight, and capped/locked Shielded candidates are removed before choosing among remaining ambient types
- Shooter ambient spawns unlock around `42` seconds with an even smaller capped weight, and capped/locked Shooter candidates are removed before choosing among remaining ambient types
- Boomer ambient spawns unlock around `65` seconds with the smallest capped weight, and capped/locked Boomer candidates are removed before choosing among remaining ambient types
- Each run also rolls first-introduction targets: Charger between `15-21` seconds, Shielded between `25-30` seconds, Shooter between `42-52` seconds, and Boomer between `65-78` seconds
- Before a target, specials can appear naturally through the existing weights; after an unseen target is overdue, the next valid ambient opportunity prioritizes that enemy until it successfully appears
- After each special enemy has appeared once through organic play, it permanently returns to its ordinary long-term weighted selection for that run
- The first minute uses an effective one-Charger limit so the ceiling of two does not become the design target
- Wave spawns stay at least `72` pixels from Akedra and `36` pixels from a landed spear
- If no fair edge point is available, the spawn waits and retries instead of using an unsafe fallback
- A wave completes only after all scheduled spawns occurred and every enemy tagged to that wave died or exited the tree

## Scoring and high score

- Normal enemy score: `1`
- Shielded score: `2`
- Blowgun Shooter score: `2`
- Boomer safe kill score: `2`
- Boomer self-detonation score: `0` direct points; any enemies killed by the blast still use their ordinary score values
- Charger score: `3`
- High score is saved locally in `user://highscore.save`
- Invalid or missing save data falls back safely to `0`
- The game-over screen shows the saved high score and marks a new record clearly

## Main adjustable values

See [`TUNING.md`](TUNING.md) for current values and tuning intent. This list is a quick source-location index.

- `scripts/player.gd`
  - `move_speed`
  - `destination_reach_distance`
  - `invulnerability_duration`
  - `damage_hit_radius`
  - `dodge_duration`
  - `dodge_distance`
  - `dodge_cooldown`
  - `dodge_exit_invulnerability_duration`
  - `dodge_spin_turns`
  - `horizontal_facing_dead_zone`
  - `dodge_trail_afterimage_count`
  - `dodge_trail_sample_interval`
  - `dodge_trail_lifetime`
  - `try_start_forced_movement`
- `scripts/player_dodge_cooldown_indicator.gd`
  - `enabled`
  - `world_offset`
  - `wisp_color`
  - `ready_glint_color`
  - `ready_glint_duration`
- `scripts/spear.gd`
  - `spear_speed`
  - `max_range`
  - `held_distance`
  - `stopped_hit_landing_clearance`
  - `landed_marker_radius`
  - `landed_marker_pulse_speed`
- `scripts/enemy.gd`
  - `move_speed`
  - `score_value`
  - `separation_distance`
  - `separation_strength`
- `scripts/charger.gd`
  - `chase_duration_min`
  - `chase_duration_max`
  - `telegraph_duration`
  - `dash_speed`
  - `dash_max_distance`
  - `recover_duration`
  - `telegraph_line_length`
  - `telegraph_shake_strength`
- `scripts/shielded_enemy.gd`
  - `movement_speed_scale`
  - `stagger_duration`
  - `knockback_distance`
  - `knockback_duration`
  - `shield_break_effect_duration`
- `scripts/main.gd`
  - `base_spawn_interval`
  - `minimum_spawn_interval`
  - `spawn_interval_drop_per_second`
  - `base_enemy_speed`
  - `enemy_speed_bonus_per_second`
  - `maximum_enemy_speed_bonus`
  - `close_hit_stop_distance`
  - `close_hit_stop_duration`
  - `close_hit_stop_time_scale`
  - `charger_unlock_time`
  - `charger_spawn_chance_at_unlock`
  - `charger_spawn_chance_growth_per_second`
  - `maximum_charger_spawn_chance`
  - `charger_intro_target_time_min`
  - `charger_intro_target_time_max`
  - `shielded_unlock_time`
  - `shielded_spawn_chance_at_unlock`
  - `shielded_spawn_chance_growth_per_second`
  - `maximum_shielded_spawn_chance`
  - `shielded_intro_target_time_min`
  - `shielded_intro_target_time_max`
  - `shooter_unlock_time`
  - `shooter_spawn_chance_at_unlock`
  - `shooter_spawn_chance_growth_per_second`
  - `maximum_shooter_spawn_chance`
  - `shooter_intro_target_time_min`
  - `shooter_intro_target_time_max`
  - `boomer_unlock_time`
  - `boomer_spawn_chance_at_unlock`
  - `boomer_spawn_chance_growth_per_second`
  - `maximum_boomer_spawn_chance`
  - `boomer_intro_target_time_min`
  - `boomer_intro_target_time_max`
<<<<<<< Updated upstream
=======
  - `heart_runner_unlock_time`
  - `heart_runner_roll_interval_min`
  - `heart_runner_roll_interval_max`
  - `heart_runner_health_3_spawn_chance`
  - `heart_runner_health_2_spawn_chance`
  - `heart_runner_health_1_spawn_chance`
  - `heart_runner_one_health_grace_duration`
  - `heart_runner_speed`
  - `heart_runner_spawn_safe_radius`
  - `heart_runner_landed_spear_safe_radius`
  - `heart_runner_post_resolution_cooldown`
  - `heart_pickup_lifetime`
  - `heart_pickup_warning_duration`
>>>>>>> Stashed changes
  - `landed_spear_spawn_safe_radius`
  - `blocked_spawn_retry_interval`
  - `default_window_scale`
- `scripts/encounter_director.gd`
  - `first_wave_time_min`
  - `first_wave_time_max`
  - `inter_wave_interval_min`
  - `inter_wave_interval_max`
  - `rush_start_population_threshold`
  - `pincer_start_population_threshold`
  - `charger_hunt_start_population_threshold`
  - `total_hostile_cap`
  - `normal_hostile_cap`
  - `charger_hostile_cap`
  - `shielded_hostile_cap`
  - `shooter_hostile_cap`
  - `boomer_hostile_cap`
  - `first_minute_charger_cap`
  - `spawn_retry_interval`
- `scripts/shooter_enemy.gd`
  - `movement_speed_scale`
  - `approach_speed_scale`
  - `retreat_speed_scale`
  - `lateral_fallback_speed_scale`
  - `preferred_distance_min`
  - `preferred_distance_max`
  - `retreat_distance`
  - `resume_after_retreat_distance`
  - `attack_range_max`
  - `aim_duration`
  - `locked_duration`
  - `burst_interval`
  - `recover_duration`
  - `attack_cooldown`
  - `minimum_dart_interval`
  - `aim_retry_delay`
  - `arc_reposition_duration`
  - `arc_reposition_speed_scale`
  - `arc_reposition_side_sample_distance`
  - `arc_radial_correction_strength`
  - `shove_trigger_distance`
  - `shove_windup_duration`
  - `shove_active_duration`
  - `shove_recover_duration`
  - `shove_knockback_distance`
  - `shove_knockback_duration`
  - `shove_cooldown`
  - `shove_hit_radius`
  - `shove_hit_offset`
- `scripts/boomer_enemy.gd`
  - `hop_prep_duration`
  - `hop_duration`
  - `hop_distance`
  - `landing_recovery_duration`
  - `fuse_trigger_distance`
  - `fuse_duration`
  - `core_blast_radius`
  - `outer_shockwave_radius`
  - `player_knockback_distance`
  - `player_knockback_duration`
  - `landed_spear_shockwave_displacement`
  - `enemy_shockwave_knockback_distance`
  - `enemy_shockwave_knockback_duration`
  - `shooter_shockwave_knockback_distance`
  - `shooter_shockwave_knockback_duration`
  - `charger_core_knockback_distance`
  - `charger_core_knockback_duration`
  - `charger_shockwave_knockback_distance`
  - `charger_shockwave_knockback_duration`
- `scripts/dart_projectile.gd`
  - `speed`
  - `max_lifetime`
  - `bounds_padding`
- `scripts/player_health_pips.gd`
  - `max_supported_pips`
  - `vertical_offset`
  - `pip_spacing`
- `scripts/destination_marker.gd`
  - `display_duration`
  - `base_radius`
  - `pulse_distance`
- `scripts/arena.gd`
  - `play_margin`
  - `boundary_color`
  - `marking_color`
- `default_bus_layout.tres`
  - `Music` bus volume
  - `SFX` bus volume

## Known limitations

- There are currently five enemy types, all using intentionally simple movement logic
- Art and music are intentionally simple local placeholder assets rather than a full content pipeline
- Enemy avoidance is intentionally lightweight and not full pathfinding

## Features intentionally left for later

- More enemy types
- Phase 4.6 enemy interaction work focused on positioning-based Shielded/Shooter cooperation and Shooter-dart/Boomer interactions
- Ring encounter formations
- Opportunity encounters such as a Heart Runner, kept separate from hostile population slots
- Wave reward selection driven by encounter completion signals
- Upgrades or progression systems
- Menus outside the in-game restart flow
- Additional arenas or level structure
