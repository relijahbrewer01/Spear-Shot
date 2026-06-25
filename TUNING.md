# Spear Shot Tuning Index

`TUNING.md` is a human-readable tuning index. Runtime values are defined in the listed source files. Update this document whenever documented tuning values change.

## Run Pacing

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `base_spawn_interval` | `2.2s` | `scripts/main.gd` | Ambient spawn interval at run start. |
| `minimum_spawn_interval` | `0.75s` | `scripts/main.gd` | Floor for long-run ambient density. |
| `spawn_interval_drop_per_second` | `0.006s/s` | `scripts/main.gd` | How quickly ambient density ramps. |
| `base_enemy_speed` | `42.0px/s` | `scripts/main.gd` | Base speed passed to spawned enemies. |
| `enemy_speed_bonus_per_second` | `0.11px/s/s` | `scripts/main.gd` | Long-run enemy speed pressure. |
| `maximum_enemy_speed_bonus` | `20.0px/s` | `scripts/main.gd` | Cap on survival-time speed growth. |
| `blocked_spawn_retry_interval` | `0.5s` | `scripts/main.gd` | Retry delay when ambient spawn position or caps block a spawn. |

## Special-Enemy Introductions

| Enemy | Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- | --- |
| Charger | `charger_unlock_time` | `15.0s` | `scripts/main.gd` | First time Charger can appear through ambient selection. |
| Charger | `charger_intro_target_time_min/max` | `15.0-21.0s` | `scripts/main.gd` | Per-run randomized first-introduction guarantee target. |
| Charger | `charger_spawn_chance_at_unlock` | `0.08` | `scripts/main.gd` | Starting ambient weight once unlocked. |
| Charger | `charger_spawn_chance_growth_per_second` | `0.001` | `scripts/main.gd` | Chance growth after unlock. |
| Charger | `maximum_charger_spawn_chance` | `0.22` | `scripts/main.gd` | Long-run chance cap. |
| Charger | `charger_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated active Charger cap. |
| Charger | `first_minute_charger_cap` | `1` | `scripts/encounter_director.gd` | Early-run effective Charger cap before `60s`. |
| Shielded | `shielded_unlock_time` | `25.0s` | `scripts/main.gd` | First time Shielded can appear through ambient selection. |
| Shielded | `shielded_intro_target_time_min/max` | `25.0-30.0s` | `scripts/main.gd` | Per-run randomized first-introduction guarantee target. |
| Shielded | `shielded_spawn_chance_at_unlock` | `0.05` | `scripts/main.gd` | Starting ambient weight once unlocked. |
| Shielded | `shielded_spawn_chance_growth_per_second` | `0.0006` | `scripts/main.gd` | Chance growth after unlock. |
| Shielded | `maximum_shielded_spawn_chance` | `0.12` | `scripts/main.gd` | Long-run chance cap. |
| Shielded | `shielded_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated active Shielded cap. |
| Shooter | `shooter_unlock_time` | `42.0s` | `scripts/main.gd` | First time Shooter can appear through ambient selection. |
| Shooter | `shooter_intro_target_time_min/max` | `42.0-52.0s` | `scripts/main.gd` | Per-run randomized first-introduction guarantee target. |
| Shooter | `shooter_spawn_chance_at_unlock` | `0.04` | `scripts/main.gd` | Starting ambient weight once unlocked. |
| Shooter | `shooter_spawn_chance_growth_per_second` | `0.00045` | `scripts/main.gd` | Chance growth after unlock. |
| Shooter | `maximum_shooter_spawn_chance` | `0.10` | `scripts/main.gd` | Long-run chance cap. |
| Shooter | `shooter_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated active Shooter cap. |
| Boomer | `boomer_unlock_time` | `65.0s` | `scripts/main.gd` | First time Boomer can appear through ambient selection. |
| Boomer | `boomer_intro_target_time_min/max` | `65.0-78.0s` | `scripts/main.gd` | Per-run randomized first-introduction guarantee target. |
| Boomer | `boomer_spawn_chance_at_unlock` | `0.025` | `scripts/main.gd` | Starting ambient weight once unlocked. |
| Boomer | `boomer_spawn_chance_growth_per_second` | `0.00035` | `scripts/main.gd` | Chance growth after unlock. |
| Boomer | `maximum_boomer_spawn_chance` | `0.07` | `scripts/main.gd` | Long-run chance cap. |
| Boomer | `boomer_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated active Boomer cap. |

## Encounter Director

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `first_wave_time_min/max` | `28.0-34.0s` | `scripts/encounter_director.gd` | First authored wave timing window. |
| `inter_wave_interval_min/max` | `18.0-24.0s` | `scripts/encounter_director.gd` | Time between completed waves. |
| `telegraph_duration` | `1.75s` | `scripts/encounter_director.gd` wave definitions | Readable pre-wave warning time. |
| `recovery_duration` | `3.0s` | `scripts/encounter_director.gd` wave definitions | Post-wave ambient-spawn recovery. |
| `rush_start_population_threshold` | `5` | `scripts/encounter_director.gd` | Max living hostiles for Rush to start. |
| `pincer_start_population_threshold` | `3` | `scripts/encounter_director.gd` | Max living hostiles for Pincer to start. |
| `charger_hunt_start_population_threshold` | `4` | `scripts/encounter_director.gd` | Max living hostiles for Charger Hunt to start. |
| `total_hostile_cap` | `10` | `scripts/encounter_director.gd` | Global hostile population ceiling. |
| `normal_hostile_cap` | `9` | `scripts/encounter_director.gd` | Dedicated Normal cap. |
| `charger_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated Charger cap. |
| `shielded_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated Shielded cap. |
| `shooter_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated Shooter cap. |
| `boomer_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated Boomer cap. |
| `spawn_safe_radius` | `72.0px` | `scripts/main.gd` | Safe distance from Akedra for enemy spawns. |
| `landed_spear_spawn_safe_radius` | `36.0px` | `scripts/main.gd` | Safe distance from a landed spear for enemy spawns. |
| `spawn_retry_interval` | `0.3s` | `scripts/encounter_director.gd` | Retry delay for blocked wave spawn steps. |
| Charger Hunt `earliest_time` | `48.0s` | `scripts/encounter_director.gd` wave definitions | Earliest eligible time for Charger Hunt. |

## Player

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `move_speed` | `115.0px/s` | `scripts/player.gd` | Akedra movement speed. |
| `max_health` | `3` | `scripts/player.gd` | Player health. |
| `invulnerability_duration` | `0.8s` | `scripts/player.gd` | Ordinary hurt invulnerability after damage. |
| `body_radius` | `8.0px` | `scripts/player.gd`, `Player.tscn` | Movement/clamp body size. |
| `damage_hit_radius` | `7.0px` | `scripts/player.gd` | Contact-damage footprint. |
| `destination_reach_distance` | `4.0px` | `scripts/player.gd` | Click-move arrival tolerance. |
| `horizontal_facing_dead_zone` | `0.12` | `scripts/player.gd` | Left/right visual facing threshold. |
| `DAMAGE_SOURCE_DART` | `&"dart"` | `scripts/player.gd` | Narrow dart damage-context identity. |
| `DAMAGE_SOURCE_EXPLOSION` | `&"explosion"` | `scripts/player.gd` | Narrow explosion damage identity used by the Boomer core blast. |
| `ActionState.FORCED_MOVEMENT` | enabled | `scripts/player.gd` | Narrow authored knockback state used by Shooter shove. |
| `try_start_forced_movement(direction, distance, duration, damage_protection_source)` | authored inputs | `scripts/player.gd` | Applies knockback without clearing move intent and can optionally attach narrow shove-only protection. |
| `FORCED_MOVEMENT_PROTECTION_SHOVE` | enabled | `scripts/player.gd` | Successful Shooter shoves use this narrow protection instead of dodge or hurt invulnerability, and the Boomer core blast now respects it while that authored movement is still active. |
| Heart Runner bonus heal cap | `max_health + 1` | `scripts/player.gd` | A collected heart pickup can temporarily raise Akedra from `3` to `4` health. |

## Dodge

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `dodge_duration` | `0.20s` | `scripts/player.gd` | Active roll movement time. |
| `dodge_distance` | `36.0px` | `scripts/player.gd` | Roll travel distance. |
| `dodge_cooldown` | `2.0s` | `scripts/player.gd` | Shared cooldown for Shift and Space dodges. |
| `dodge_exit_invulnerability_duration` | `0.10s` | `scripts/player.gd` | Exit grace after dodge motion ends. |
| `dodge_trail_afterimage_count` | `4` | `scripts/player.gd` | Number of afterimages in the roll trail. |
| `dodge_trail_sample_interval` | `0.045s` | `scripts/player.gd` | Trail sampling cadence. |
| `dodge_trail_lifetime` | `0.22s` | `scripts/player.gd` | Trail fade duration. |
| `ready_glint_duration` | `0.12s` | `scripts/player_dodge_cooldown_indicator.gd` | Brief cooldown-ready sparkle. |
| Buffered click destination | `1 pending target` | `scripts/player.gd` | Right-click during dodge replaces any previous buffered move target. |
| Buffered spear throw | `1 pending target` | `scripts/main.gd` | A valid held-spear throw during dodge replaces the previous captured target and releases once after `dodge_ended`. |
| Forced-movement dodge cancel | `Shift` and `Space` if ready | `scripts/player.gd`, `scripts/main.gd` | Dodges can cancel Shooter shove knockback while preserving their normal direction rules. |

## Spear

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `spear_speed` | `520.0px/s` | `scripts/spear.gd` | Flying spear speed. |
| `max_range` | `150.0px` | `scripts/spear.gd` | Throw travel distance before landing. |
| `held_distance` | `14.0px` | `scripts/spear.gd` | Spear offset while held. |
| `launch_sweep_start_offset` | `0.0px` | `scripts/spear.gd` | Close-range launch sweep start. |
| `launch_sweep_end_offset` | `18.0px` | `scripts/spear.gd` | Close-range launch sweep reach. |
| `launch_sweep_width` | `4.0px` | `scripts/spear.gd` | Close-range launch sweep thickness. |
| `landed_marker_radius` | `15.0px` | `scripts/spear.gd` | Landed spear readability marker. |
| Pickup collision radius | `10.0px` | `Spear.tscn` | Landed spear pickup area. |
| `stopped_hit_landing_clearance` | `4.0px` | `scripts/spear.gd` | Shield-stop near-side spear clearance. |
| `close_hit_stop_distance` | `8.0px` | `scripts/main.gd` | Distance threshold for point-blank hit stop. |
| `close_hit_stop_duration` | `0.045s` | `scripts/main.gd` | Hit-stop duration. |
| `close_hit_stop_time_scale` | `0.05` | `scripts/main.gd` | Temporary time scale during close hit stop. |

## Normal Enemy

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `move_speed` | `42.0px/s` before run scaling | `scripts/enemy.gd`, `scripts/main.gd` | Basic pursuit pressure. |
| `score_value` | `1` | `scripts/enemy.gd` | Score for a killed Normal. |
| `body_radius` | `8.0px` | `scripts/enemy.gd`, `Enemy.tscn` | Body and contact footprint. |
| Collision radius | `8.0px` | `Enemy.tscn` | Physics shape size. |
| `separation_distance` | `18.0px` | `scripts/enemy.gd` | Lightweight crowd spacing radius. |
| `separation_strength` | `48.0` | `scripts/enemy.gd` | Lightweight crowd spacing force. |

## Charger

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `score_value` | `3` | `Charger.tscn` | Score for a killed Charger. |
| `body_radius` | `7.0px` | `Charger.tscn` | Charger body footprint. |
| Collision radius | `7.0px` | `Charger.tscn` | Physics shape size. |
| `chase_duration_min/max` | `1.6-2.5s` | `scripts/charger.gd` | Pre-telegraph pursuit time. |
| `telegraph_duration` | `0.72s` | `scripts/charger.gd` | Dash warning duration. |
| `dash_speed` | `220.0px/s` | `scripts/charger.gd` | Committed dash speed. |
| `dash_max_distance` | `92.0px` | `scripts/charger.gd` | Max committed dash travel. |
| `recover_duration` | `0.55s` | `scripts/charger.gd` | Post-dash recovery. |
| `telegraph_line_length` | `38.0px` | `scripts/charger.gd` | Dash-line readability. |
| `telegraph_shake_strength` | `1.4px` | `scripts/charger.gd` | Telegraph motion emphasis. |
| `visible_entry_damage_sync_distance` | `10.0px` | `scripts/charger.gd` | Safety sync between visual body and damage. |

## Shielded

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `score_value` | `2` | `ShieldedEnemy.tscn` | Score after exposed Shielded death. |
| `movement_speed_scale` | `0.72` | `scripts/shielded_enemy.gd` | Slow broad-body movement. |
| `stagger_duration` | `0.65s` | `scripts/shielded_enemy.gd` | Full no-contact shield-break stagger. |
| `knockback_distance` | `14.0px` | `scripts/shielded_enemy.gd` | Authored shield-break knockback. |
| `knockback_duration` | `0.12s` | `scripts/shielded_enemy.gd` | Knockback movement time. |
| `shield_break_effect_duration` | `0.22s` | `scripts/shielded_enemy.gd` | Visual shield-break flash duration. |
| `body_radius` | `9.0px` | `ShieldedEnemy.tscn` | Body footprint. |
| Collision radius | `9.0px` | `ShieldedEnemy.tscn` | Physics shape size. |
| `separation_distance` | `19.0px` | `ShieldedEnemy.tscn` | Shielded spacing radius. |
| `separation_strength` | `56.0` | `ShieldedEnemy.tscn` | Shielded spacing force. |
| `stopped_hit_landing_clearance` | `4.0px` | `scripts/spear.gd` | Spear lands on incoming side after shield stop. |
| `shielded_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated active Shielded cap. |

## Blowgun Shooter

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `score_value` | `2` | `ShooterEnemy.tscn` | Score for a killed Shooter. |
| Body sprite canvas dimensions | `16x18px` | `art/sprites/shooter_enemy.png`, `tools/generate_phase4_assets.py` | Final approved canvas with breathing room around the still-small Shooter silhouette. |
| Approved live palette | Moss hood, pale ochre face, charcoal-brown torso, restrained rust pouch | `art/sprites/shooter_enemy.png`, `tools/generate_phase4_assets.py` | Final approved palette cleanup chosen from the Stage 4.2 approval board. |
| Apparent silhouette bounds | About `10x16px` | `art/sprites/shooter_enemy.png`, `tools/generate_phase4_assets.py` | Measured non-transparent Shooter silhouette on the approved canvas. |
| Normal visual scale | `Vector2.ONE` | `scripts/shooter_enemy.gd` | Base sprite scale. |
| Aim visual scale | `Vector2(1.08, 0.92)` | `scripts/shooter_enemy.gd` | Inhale/body-compression cue. |
| Fire visual scale | `Vector2(0.96, 1.04)` | `scripts/shooter_enemy.gd` | Exhale/recoil cue. |
| `body_radius` | `7.0px` | `ShooterEnemy.tscn` | Fair body footprint, intentionally not shrunk with the sprite. |
| Collision radius | `7.0px` | `ShooterEnemy.tscn` | Physics shape size. |
| `movement_speed_scale` | `0.90` | `scripts/shooter_enemy.gd` | General repositioning speed relative to current enemy speed. |
| `approach_speed_scale` | `1.0` | `scripts/shooter_enemy.gd` | Approach speed multiplier. |
| `retreat_speed_scale` | `1.15` | `scripts/shooter_enemy.gd` | Too-close retreat speed multiplier. |
| `lateral_fallback_speed_scale` | `0.8` | `scripts/shooter_enemy.gd` | Wall fallback lateral speed multiplier. |
| `preferred_distance_min/max` | `82.0-118.0px` | `scripts/shooter_enemy.gd` | Desired firing band. |
| `retreat_distance` | `58.0px` | `scripts/shooter_enemy.gd` | Dangerous range where direct retreat overrides arc movement. |
| `resume_after_retreat_distance` | `72.0px` | `scripts/shooter_enemy.gd` | Retreat hysteresis reference. |
| `attack_range_max` | `126.0px` | `scripts/shooter_enemy.gd` | Max range for beginning attacks. |
| `blowgun_length` | `14.0px` | `scripts/shooter_enemy.gd` | Final reed blowgun length for role readability without spear-like heaviness. |
| `blowgun_shaft_width/tip_width` | `1.0px / 1.0px` | `scripts/shooter_enemy.gd` | Lighter runtime blowgun profile chosen from the visual concept pass. |
| `direction_change_cooldown` | `0.35s` | `scripts/shooter_enemy.gd` | Wall/fallback side-change restraint. |
| `wall_fallback_commit_duration` | `0.45s` | `scripts/shooter_enemy.gd` | Brief wall tangent commitment. |
| `first_attack_delay_min/max` | `1.0-1.6s` | `scripts/shooter_enemy.gd` | Prevents immediate spawn shot. |
| `aim_duration` | `0.48s` | `scripts/shooter_enemy.gd` | Tracking telegraph before lock. |
| `locked_duration` | `0.24s` | `scripts/shooter_enemy.gd` | Frozen aim warning before release. |
| `burst_interval` | `0.17s` | `scripts/shooter_enemy.gd` | Fixed gap between dart one and dart two. |
| Darts per burst | `2` | `scripts/shooter_enemy.gd` | Committed volley size. |
| `recover_duration` | `0.16s` | `scripts/shooter_enemy.gd` | Tiny stationary recoil before movement. |
| `attack_cooldown` | `0.95s` | `scripts/shooter_enemy.gd` | Post-burst cooldown, starts when the burst finishes. |
| `minimum_dart_interval` | `2.4s` | `scripts/shooter_enemy.gd` | Hard minimum between burst starts. |
| Ordinary body contact damage | disabled | `scripts/shooter_enemy.gd` | Shooter body overlap no longer damages Akedra. |
| Committed aim rule | once `AIM` begins, finish `AIM -> LOCKED -> FIRE -> RECOVER` unless cleaned up | `scripts/shooter_enemy.gd` | Player distance changes no longer cancel the live wind-up once it has started. |
| `aim_retry_delay` | `0.18s` | `scripts/shooter_enemy.gd` | Small safeguard after non-burst interruptions such as the close-range shove path. |
| `arc_reposition_duration` | `1.10s` | `scripts/shooter_enemy.gd` | Longer post-burst relocation time. |
| `arc_reposition_speed_scale` | `1.35` | `scripts/shooter_enemy.gd` | Post-burst relocation speed multiplier. |
| `arc_reposition_side_sample_distance` | `60.0px` | `scripts/shooter_enemy.gd` | Space sample distance for choosing a post-burst side. |
| `arc_radial_correction_strength` | `0.28` | `scripts/shooter_enemy.gd` | Mild correction toward preferred range during post-burst relocation. |
| `post_shove_reposition_duration` | `0.42s` | `scripts/shooter_enemy.gd` | Successful-shove movement window before the next valid attack setup. |
| `post_shove_reposition_speed_scale` | `1.45` | `scripts/shooter_enemy.gd` | Successful-shove reposition speed multiplier. |
| `post_shove_side_sample_distance` | `48.0px` | `scripts/shooter_enemy.gd` | Side-sampling distance for successful-shove follow-up reposition. |
| `post_shove_follow_up_delay` | `0.12s` | `scripts/shooter_enemy.gd` | Extra gate before a successful shove may begin the next valid AIM. |
| `shove_trigger_distance` | `20.0px` | `scripts/shooter_enemy.gd` | Close-range threshold for the defensive shove. |
| `shove_windup/active/recover_duration` | `0.20/0.08/0.18s` | `scripts/shooter_enemy.gd` | Shove state timings. |
| `shove_knockback_distance/duration` | `52.0px / 0.24s` | `scripts/shooter_enemy.gd` | Authored player knockback values for a successful shove. |
| `shove_cooldown` | `2.10s` | `scripts/shooter_enemy.gd` | Minimum time between shove attempts. |
| `shove_hit_radius` | `11.0px` | `scripts/shooter_enemy.gd` | Circular shove hit-check radius. |
| `shove_hit_offset` | `13.0px` | `scripts/shooter_enemy.gd` | Forward offset for the shove hit check. |
| Successful-shove damage protection | active for authored forced movement only | `scripts/player.gd`, `scripts/shooter_enemy.gd` | Prevents unfair chained HP loss while Akedra is being displaced by a landed shove. |
| `shooter_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated active Shooter cap. |
| Spawn and introduction values | `42s`, `42-52s`, `0.04`, `0.00045`, `0.10` | `scripts/main.gd` | Shooter unlock, intro target, starting chance, growth, and max chance. |

## Boomer

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `score_value` | `2` safe kill | `BoomerEnemy.tscn` | Guaranteed score for a pre-fuse spear kill. |
| Self-detonation direct score | none | `scripts/boomer_enemy.gd`, `scripts/main.gd` | Boomer self-destruction awards no direct points. |
| Body sprite canvas dimensions | `16x18px` | `art/sprites/boomer_enemy.png`, `tools/generate_phase4_assets.py` | Small readable live canvas chosen from the local concept pass. |
| Apparent silhouette bounds | About `13x13px` | `art/sprites/boomer_enemy.png`, `tools/generate_phase4_assets.py` | Compact spring-loaded hopper silhouette. |
| `body_radius` | `8.0px` | `BoomerEnemy.tscn` | Fair body footprint. |
| Collision radius | `8.0px` | `BoomerEnemy.tscn` | Physics shape size. |
| `separation_distance` | `26.0px` | `BoomerEnemy.tscn` | Lightweight spawn/landing spacing radius. |
| `separation_strength` | `48.0` | `BoomerEnemy.tscn` | Lightweight spawn/landing spacing force. |
| Ordinary body contact damage | disabled | `scripts/boomer_enemy.gd` | Boomer body overlap never damages Akedra. |
| `hop_prep_duration` | `0.18s` | `scripts/boomer_enemy.gd` | Stationary visible compression before takeoff. |
| `hop_duration` | `0.24s` | `scripts/boomer_enemy.gd` | Committed leap travel time. |
| `hop_distance` | `38.0px` | `scripts/boomer_enemy.gd` | One-hop travel distance. |
| `landing_recovery_duration` | `0.20s` | `scripts/boomer_enemy.gd` | Stationary settle before the next hop when still out of range. |
| Fuse start timing | immediate on landing inside range | `scripts/boomer_enemy.gd` | Landing checks the player distance before any recovery delay. |
| `fuse_trigger_distance` | `36.0px` | `scripts/boomer_enemy.gd` | Center-distance threshold for starting the fuse. |
| `fuse_duration` | `0.80s` | `scripts/boomer_enemy.gd` | Total reaction window from landing pulse to blast. |
| `fuse_pulse_two_offset` | `0.32s` | `scripts/boomer_enemy.gd` | Second fuse pulse timing. |
| `fuse_pulse_three_offset` | `0.57s` | `scripts/boomer_enemy.gd` | Third fuse pulse timing. |
| `core_blast_radius` | `29.0px` | `scripts/boomer_enemy.gd` | Damaging core blast radius. |
| `outer_shockwave_radius` | `54.0px` | `scripts/boomer_enemy.gd` | Non-damaging crowd-rearrangement radius. |
| `player_knockback_distance/duration` | `28.0px / 0.20s` | `scripts/boomer_enemy.gd` | Authored player knockback when the core blast damage lands. |
| `landed_spear_shockwave_displacement` | `20.0px` | `scripts/boomer_enemy.gd` | One-time outward nudge applied to a spear that is already landed inside the Boomer outer shockwave. |
| `enemy_shockwave_knockback_distance/duration` | `18.0px / 0.16s` | `scripts/boomer_enemy.gd` | Default outer-ring enemy knockback. |
| `shooter_shockwave_knockback_distance/duration` | `22.0px / 0.18s` | `scripts/boomer_enemy.gd` | Slightly stronger outer-ring Shooter knockback. |
| `charger_core_knockback_distance/duration` | `30.0px / 0.20s` | `scripts/boomer_enemy.gd` | Core-blast Charger interruption and recovery setup. |
| `charger_shockwave_knockback_distance/duration` | `20.0px / 0.16s` | `scripts/boomer_enemy.gd` | Outer-ring Charger knockback. |
| `boomer_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated active Boomer cap. |
| Spawn and introduction values | `65s`, `65-78s`, `0.025`, `0.00035`, `0.07` | `scripts/main.gd` | Boomer unlock, intro target, starting chance, growth, and max chance. |

## Heart Runner Opportunity

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `heart_runner_unlock_time` | `20.0s` | `scripts/main.gd` | First time the separate Heart Runner opportunity may roll. |
| `heart_runner_roll_interval_min/max` | `8.0-12.0s` | `scripts/main.gd` | Time between Heart Runner opportunity checks. |
| `heart_runner_health_3_spawn_chance` | `0.01` | `scripts/main.gd` | Runner chance while Akedra still has `3` health. |
| `heart_runner_health_2_spawn_chance` | `0.04` | `scripts/main.gd` | Runner chance while Akedra is at `2` health. |
| `heart_runner_health_1_spawn_chance` | `0.15` | `scripts/main.gd` | Runner chance while Akedra is at `1` health before any grace guarantee is due. |
| `heart_runner_one_health_grace_duration` | `90.0s` | `scripts/main.gd` | Continuous active one-health gameplay needed to guarantee the next later valid Heart Runner opportunity check. |
| `heart_runner_speed` | `140.0px/s` | `scripts/main.gd`, `scripts/heart_runner.gd` | Approved panic flee speed. |
| `calm_move_speed` | `70.0px/s` | `scripts/heart_runner.gd` | Calm entry, wandering, and timeout-exit pace before panic begins. |
| `entry_distance` / `entry_min_duration` | `20.0px / 0.45s` | `scripts/heart_runner.gd` | Visible calm entry requirement before any startle check is allowed. |
| `wander_duration` | `8.0s` | `scripts/heart_runner.gd` | Maximum calm wandering time before the Runner chooses a casual exit. |
| `heart_runner_spawn_safe_radius` | `56.0px` | `scripts/main.gd` | Minimum safe distance from Akedra for edge entry. |
| `heart_runner_landed_spear_safe_radius` | `24.0px` | `scripts/main.gd` | Extra safe-entry clearance from a landed spear. |
| `heart_runner_post_resolution_cooldown` | `18.0s` | `scripts/main.gd` | Cooldown applied once after escape or pickup resolution. |
| One-health grace behavior | Pauses with gameplay, resets above `1 HP`, resets after any successful organic one-health Runner spawn, and can be deferred by an active Runner, active pickup, cooldown, or safe-entry failure | `scripts/main.gd` | Guarantees an opportunity rather than a heal while preserving the ordinary one-active and cooldown rules. |
| `heart_runner_startle_range_margin` | `16.0px` | `scripts/heart_runner.gd` | Subtracted from the live spear max range to derive the Runner's threat radius. |
| Derived startle radius | `134.0px` | `scripts/heart_runner.gd`, `scripts/spear.gd` | Current proximity trigger using `150px - 16px`; the Runner only startles inside this armed threat range. |
| `startled_duration` | `0.40s` | `scripts/heart_runner.gd` | Total one-shot startled hop covering recognition, pop, peak, and brief landing beat. |
| Calm animation cadence | `4 frames @ 0.18s/frame` | `scripts/heart_runner.gd`, `art/sprites/heart_runner_sheet.png` | Approved casual strut used for `ENTERING`, `WANDERING`, and `CASUAL_EXIT`. |
| Panic animation cadence | `4 frames @ 0.10s/frame` | `scripts/heart_runner.gd`, `art/sprites/heart_runner_sheet.png` | Faster panic sprint cadence with stronger lean and wider stride during `FLEEING`. |
| `score_value` | `1` | `HeartRunner.tscn`, `scripts/heart_runner.gd` | Score for defeating the Runner before it escapes. |
| `body_radius` | `6.0px` | `HeartRunner.tscn`, `scripts/heart_runner.gd` | Small readable Runner footprint. |
| Collision radius | `6.0px` | `HeartRunner.tscn` | Heart Runner collision shape size. |
| Live animation sheet layout | `4x3` frames on `64x48px` | `HeartRunner.tscn`, `art/sprites/heart_runner_sheet.png` | Single Sprite2D sheet for calm, startled, and panic rows without changing collision size. |
| `cleanup_margin` | `12.0px` | `scripts/heart_runner.gd` | Extra distance beyond the currently locked casual or panic route's assigned exit plane before natural cleanup. |
| `pickup_radius` | `10.0px` | `HeartPickup.tscn`, `scripts/heart_pickup.gd` | Pickup body radius used for overlap collection and arena clamping. |
| `heart_pickup_lifetime` | `7.0s` | `scripts/main.gd`, `scripts/heart_pickup.gd` | Time before an uncollected heart pickup expires. |
| `heart_pickup_warning_duration` | `1.5s` | `scripts/main.gd`, `scripts/heart_pickup.gd` | Final warning pulse/flicker window before expiration. |

## Dart Projectile

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| Damage per dart | `1 health` | `scripts/player.gd`, `scripts/dart_projectile.gd` | Each valid dart hit deals one damage through `Player.take_damage`. |
| `speed` | `145.0px/s` | `scripts/dart_projectile.gd` | Dart travel speed. |
| Visual dimensions | About `8x2px` | `scripts/dart_projectile.gd` | Readable non-magical projectile. |
| Collision radius | `3.0px` | `DartProjectile.tscn` | Forgiving projectile contact shape. |
| `max_lifetime` | `1.8s` | `scripts/dart_projectile.gd` | Projectile lifetime cleanup. |
| `bounds_padding` | `8.0px` | `scripts/dart_projectile.gd` | Arena cleanup padding. |
| `PROJECTILE_KIND_DART` | `&"dart"` | `scripts/dart_projectile.gd` | Projectile identity for future narrow interactions. |
| Burst damage rule | Two distinct dart indices from one `burst_id` may both damage | `scripts/player.gd` | Dart two can pierce dart one's hurt window without weakening normal invulnerability. |
| Collision targets | Player layer only | `DartProjectile.tscn` | Darts do not hit spear, enemies, or Shielded yet. |

## HUD And Feedback

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `pip_spacing` | `6.0px` | `scripts/player_health_pips.gd` | Health pip spacing. |
| `vertical_offset` | `14.0px` | `scripts/player_health_pips.gd` | Health pip position below Akedra. |
| `bonus_vertical_offset` | `6.0px` | `scripts/player_health_pips.gd` | Offset for the temporary fourth heart pip. |
| `bonus_filled_color` | `Color8(226, 112, 96)` | `scripts/player_health_pips.gd` | Distinct color for the temporary bonus heart pip. |
| `display_duration` | `0.38s` | `scripts/destination_marker.gd` | Right-click marker lifetime. |
| `base_radius` | `4.0px` | `scripts/destination_marker.gd` | Right-click marker size. |
| `pulse_distance` | `1.3px` | `scripts/destination_marker.gd` | Right-click marker pulse. |
| `resume_countdown_step_duration` | `0.7s` | `scripts/hud.gd` | Pause resume countdown cadence. |
| `damage_shake_duration` | `0.1s` | `scripts/main.gd` | Player hurt screen shake duration. |
| `damage_shake_strength` | `2.4px` | `scripts/main.gd` | Player hurt screen shake intensity. |
| `edge_inset` | `5.0px` | `scripts/encounter_telegraph.gd` | Wave marker inset from arena edge. |
| `marker_half_length` | `17.0px` | `scripts/encounter_telegraph.gd` | Wave marker length. |
| `pulse_speed` | `9.0` | `scripts/encounter_telegraph.gd` | Wave warning pulse speed. |

## Input And Audio Polish

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| Player-action SFX pool size | `3` per action | `scripts/main.gd` | Throw, dodge, and hurt each retain the original clip plus two local alternates. |
| Spear recovery cue | `1` clip, `0.16s` | `scripts/spear.gd`, `scripts/main.gd` | Plays only after legitimate `LANDED -> HELD` recovery; initial equip, reset, and landing alone remain silent. |
| Immediate SFX repeat | disabled per category | `scripts/main.gd` | Each action remembers its own last variant without coupling histories. |
| Audio random source | dedicated `audio_rng` | `scripts/main.gd` | Player sound variation cannot consume gameplay RNG state. |
| Dodge player mix | `-5.0dB` | `Main.tscn` | Preserves the existing restrained dodge level on the SFX bus. |
| SFX bus mix | `-4.0dB` | `default_bus_layout.tres` | Shared sound-effect bus level remains unchanged. |
| Music bus mix | `-13.0dB` | `default_bus_layout.tres` | Both calm loops retain the existing background-music level. |
| Music run cycle | `track 1, track 2, repeat` | `scripts/main.gd` | Launch starts on the original; each in-place restart advances once and starts the selected loop from the beginning. |
| Music loop format | `44.1kHz`, `16-bit`, stereo | `tools/generate_music.py` | Both locally generated tracks share format, duration, loop configuration, and similar loudness. |

## Common Tuning Requests

| Request | Primary variables involved | Notes |
| --- | --- | --- |
| Make overall density rise more slowly | `base_spawn_interval`, `minimum_spawn_interval`, `spawn_interval_drop_per_second` | These live in `scripts/main.gd`; waves have separate timing. |
| Make Chargers appear earlier | `charger_unlock_time`, `charger_intro_target_time_min/max`, `charger_spawn_chance_at_unlock` | Preserve `first_minute_charger_cap` if early pressure must stay readable. |
| Make the Shooter attack faster | `aim_duration`, `locked_duration`, `burst_interval`, `attack_cooldown`, `minimum_dart_interval` | Keep one visible lock cue and one locked direction for both darts. |
| Make darts easier to avoid | `aim_duration`, `locked_duration`, `speed`, `burst_interval` | Dart speed currently stays at `145.0px/s`. |
| Make Boomers less oppressive | `hop_distance`, `fuse_trigger_distance`, `fuse_duration`, `core_blast_radius`, `outer_shockwave_radius` | Preserve the discrete hop-and-stop rhythm and one-active cap while tuning fairness. |
| Make Heart Runner opportunities more generous or rarer | `heart_runner_roll_interval_min/max`, `heart_runner_health_3_spawn_chance`, `heart_runner_health_2_spawn_chance`, `heart_runner_health_1_spawn_chance`, `heart_runner_one_health_grace_duration`, `heart_runner_post_resolution_cooldown` | The opportunity system is separate from hostile caps and wave timing. |
| Reduce Shielded retrieval pressure | `stopped_hit_landing_clearance`, `stagger_duration`, `knockback_distance` | These affect how safe spear recovery feels after a shield stop. |
| Increase time between waves | `first_wave_time_min/max`, `inter_wave_interval_min/max`, `recovery_duration` | Wave composition is separate from wave cadence. |
