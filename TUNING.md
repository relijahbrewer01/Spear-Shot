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
| Shielded | `shielded_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated active Shielded cap. |
| Shooter | `shooter_unlock_time` | `42.0s` | `scripts/main.gd` | First time Shooter can appear through ambient selection. |
| Shooter | `shooter_intro_target_time_min/max` | `42.0-52.0s` | `scripts/main.gd` | Per-run randomized first-introduction guarantee target. |
| Shooter | `shooter_spawn_chance_at_unlock` | `0.04` | `scripts/main.gd` | Starting ambient weight once unlocked. |
| Shooter | `shooter_spawn_chance_growth_per_second` | `0.00045` | `scripts/main.gd` | Chance growth after unlock. |
| Shooter | `maximum_shooter_spawn_chance` | `0.10` | `scripts/main.gd` | Long-run chance cap. |
| Shooter | `shooter_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated active Shooter cap. |

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
| `shielded_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated Shielded cap. |
| `shooter_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated Shooter cap. |
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
| `shielded_hostile_cap` | `2` | `scripts/encounter_director.gd` | Dedicated active Shielded cap. |

## Blowgun Shooter

| Setting | Current value | Source | Purpose / tuning effect |
| --- | --- | --- | --- |
| `score_value` | `2` | `ShooterEnemy.tscn` | Score for a killed Shooter. |
| Body sprite dimensions | `16x18px` | `art/sprites/shooter_enemy.png`, `tools/generate_phase4_assets.py` | Small wiry skirmisher presentation. |
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
| `arc_reposition_duration` | `0.65s` | `scripts/shooter_enemy.gd` | Sideways scamper after firing. |
| `arc_reposition_distance_min/max` | `24.0-36.0px` | `scripts/shooter_enemy.gd` | Space sample distance for choosing an arc side. |
| `arc_radial_correction_strength` | `0.35` | `scripts/shooter_enemy.gd` | Mild correction toward preferred range during arc movement. |
| `shooter_hostile_cap` | `1` | `scripts/encounter_director.gd` | Dedicated active Shooter cap. |
| Spawn and introduction values | `42s`, `42-52s`, `0.04`, `0.00045`, `0.10` | `scripts/main.gd` | Shooter unlock, intro target, starting chance, growth, and max chance. |

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
| `display_duration` | `0.38s` | `scripts/destination_marker.gd` | Right-click marker lifetime. |
| `base_radius` | `4.0px` | `scripts/destination_marker.gd` | Right-click marker size. |
| `pulse_distance` | `1.3px` | `scripts/destination_marker.gd` | Right-click marker pulse. |
| `resume_countdown_step_duration` | `0.7s` | `scripts/hud.gd` | Pause resume countdown cadence. |
| `damage_shake_duration` | `0.1s` | `scripts/main.gd` | Player hurt screen shake duration. |
| `damage_shake_strength` | `2.4px` | `scripts/main.gd` | Player hurt screen shake intensity. |
| `edge_inset` | `5.0px` | `scripts/encounter_telegraph.gd` | Wave marker inset from arena edge. |
| `marker_half_length` | `17.0px` | `scripts/encounter_telegraph.gd` | Wave marker length. |
| `pulse_speed` | `9.0` | `scripts/encounter_telegraph.gd` | Wave warning pulse speed. |

## Common Tuning Requests

| Request | Primary variables involved | Notes |
| --- | --- | --- |
| Make overall density rise more slowly | `base_spawn_interval`, `minimum_spawn_interval`, `spawn_interval_drop_per_second` | These live in `scripts/main.gd`; waves have separate timing. |
| Make Chargers appear earlier | `charger_unlock_time`, `charger_intro_target_time_min/max`, `charger_spawn_chance_at_unlock` | Preserve `first_minute_charger_cap` if early pressure must stay readable. |
| Make the Shooter attack faster | `aim_duration`, `locked_duration`, `burst_interval`, `attack_cooldown`, `minimum_dart_interval` | Keep one visible lock cue and one locked direction for both darts. |
| Make darts easier to avoid | `aim_duration`, `locked_duration`, `speed`, `burst_interval` | Dart speed currently stays at `145.0px/s`. |
| Reduce Shielded retrieval pressure | `stopped_hit_landing_clearance`, `stagger_duration`, `knockback_distance` | These affect how safe spear recovery feels after a shield stop. |
| Increase time between waves | `first_wave_time_min/max`, `inter_wave_interval_min/max`, `recovery_duration` | Wave composition is separate from wave cadence. |
