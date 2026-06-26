from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
        return
    print(f"FAIL: {message}")
    failures.append(message)


def main() -> int:
    failures: list[str] = []
    tuning_path = ROOT / "TUNING.md"
    require(tuning_path.exists(), "TUNING.md exists at the project root", failures)
    if not tuning_path.exists():
        return 1

    tuning = read_text("TUNING.md")
    readme = read_text("README.md")
    roadmap = read_text("ROADMAP.md")

    for section in [
        "## Run Pacing",
        "## Special-Enemy Introductions",
        "## Encounter Director",
        "## Player",
        "## Dodge",
        "## Spear",
        "## Normal Enemy",
        "## Charger",
        "## Shielded",
        "## Blowgun Shooter",
        "## Boomer",
        "## Prowler",
        "## Heart Runner Opportunity",
        "## Dart Projectile",
        "## HUD And Feedback",
        "## Input And Audio Polish",
        "## Common Tuning Requests",
    ]:
        require(section in tuning, f"TUNING.md includes {section}", failures)

    for variable_name in [
        "base_spawn_interval",
        "minimum_spawn_interval",
        "spawn_interval_drop_per_second",
        "enemy_speed_bonus_per_second",
        "blocked_spawn_retry_interval",
        "charger_unlock_time",
        "shielded_unlock_time",
        "shooter_unlock_time",
        "boomer_unlock_time",
        "prowler_unlock_time",
        "heart_runner_unlock_time",
        "heart_runner_roll_interval_min/max",
        "heart_runner_health_3_spawn_chance",
        "heart_runner_health_2_spawn_chance",
        "heart_runner_health_1_spawn_chance",
        "heart_runner_one_health_grace_duration",
        "heart_runner_speed",
        "calm_move_speed",
        "entry_distance",
        "entry_min_duration",
        "wander_duration",
        "heart_runner_spawn_safe_radius",
        "heart_runner_landed_spear_safe_radius",
        "heart_runner_post_resolution_cooldown",
        "heart_runner_startle_range_margin",
        "startled_duration",
        "heart_pickup_lifetime",
        "heart_pickup_warning_duration",
        "first_wave_time_min/max",
        "inter_wave_interval_min/max",
        "rush_start_population_threshold",
        "total_hostile_cap",
        "first_minute_charger_cap",
        "move_speed",
        "invulnerability_duration",
        "dodge_duration",
        "dodge_cooldown",
        "spear_speed",
        "launch_sweep_width",
        "close_hit_stop_duration",
        "stagger_duration",
        "knockback_distance",
        "aim_duration",
        "locked_duration",
        "burst_interval",
        "aim_retry_delay",
        "arc_reposition_duration",
        "arc_reposition_speed_scale",
        "arc_radial_correction_strength",
        "post_shove_reposition_duration",
        "post_shove_side_sample_distance",
        "post_shove_follow_up_delay",
        "shove_cooldown",
        "hop_prep_duration",
        "hop_duration",
        "hop_distance",
        "landing_recovery_duration",
        "fuse_trigger_distance",
        "core_blast_radius",
        "outer_shockwave_radius",
        "landed_spear_shockwave_displacement",
        "unarmed_alert_delay",
        "stalk_speed_scale",
        "hunt_speed_scale",
        "stalk_distance_min",
        "stalk_distance_max",
        "stalk_lateral_commit_duration",
        "wall_fallback_commit_duration",
        "defensive_trigger_radius",
        "defensive_windup_duration",
        "defensive_pounce_distance",
        "defensive_retreat_distance",
        "defensive_retrigger_cooldown",
        "hunt_pounce_trigger_distance",
        "hunt_pounce_windup_duration",
        "hunt_pounce_distance",
        "hunt_player_knockback_distance",
        "hunt_prowler_recoil_distance",
        "hunt_hit_stop_duration",
        "miss_skid_duration",
        "miss_stun_duration",
        "DAMAGE_SOURCE_EXPLOSION",
        "PROJECTILE_KIND_DART",
        "DAMAGE_SOURCE_DART",
        "FORCED_MOVEMENT_PROTECTION_SHOVE",
        "try_start_forced_movement",
        "Buffered spear throw",
        "Spear recovery cue",
        "audio_rng",
        "Music run cycle",
    ]:
        require(variable_name in tuning, f"TUNING.md documents {variable_name}", failures)

    for approved_value in [
        "16x18px",
        "`movement_speed_scale` | `0.90`",
        "`blowgun_length` | `14.0px`",
        "`aim_duration` | `0.48s`",
        "`locked_duration` | `0.24s`",
        "`burst_interval` | `0.17s`",
        "`attack_cooldown` | `0.95s`",
        "`arc_reposition_duration` | `1.10s`",
        "`arc_reposition_speed_scale` | `1.35`",
        "`arc_reposition_side_sample_distance` | `60.0px`",
        "`arc_radial_correction_strength` | `0.28`",
        "`post_shove_reposition_duration` | `0.42s`",
        "`shove_knockback_distance/duration` | `52.0px / 0.24s`",
        "`shove_cooldown` | `2.10s`",
        "`boomer_unlock_time` | `65.0s`",
        "`hop_distance` | `38.0px`",
        "`fuse_duration` | `0.80s`",
        "`core_blast_radius` | `29.0px`",
        "`outer_shockwave_radius` | `54.0px`",
        "`landed_spear_shockwave_displacement` | `20.0px`",
        "`prowler_unlock_time` | `78.0s`",
        "`unarmed_alert_delay` | `0.28s`",
        "`stalk_speed_scale` | `0.82`",
        "`hunt_speed_scale` | `1.48`",
        "`stalk_distance_min/max` | `72.0-104.0px`",
        "`defensive_trigger_radius` | `26.0px`",
        "`defensive_pounce_distance/duration` | `42.0px / 0.18s`",
        "`defensive_retreat_distance` | `92.0px`",
        "`hunt_pounce_distance/duration` | `48.0px / 0.18s`",
        "`hunt_player_knockback_distance/duration` | `28.0px / 0.18s`",
        "`hunt_prowler_recoil_distance/duration` | `26.0px / 0.16s`",
        "`hunt_hit_stop_duration` | `0.06s`",
        "`miss_stun_duration` | `0.42s`",
        "Live animation sheet layout | `4x5` frames on `64x80px`",
        "`heart_runner_unlock_time` | `20.0s`",
        "`heart_runner_roll_interval_min/max` | `8.0-12.0s`",
        "`heart_runner_health_3_spawn_chance` | `0.01`",
        "`heart_runner_health_2_spawn_chance` | `0.04`",
        "`heart_runner_health_1_spawn_chance` | `0.15`",
        "`heart_runner_one_health_grace_duration` | `90.0s`",
        "`calm_move_speed` | `70.0px/s`",
        "`wander_duration` | `8.0s`",
        "`heart_runner_startle_range_margin` | `16.0px`",
        "Derived startle radius | `134.0px`",
        "`startled_duration` | `0.40s`",
        "Live animation sheet layout | `4x3` frames on `64x48px`",
        "`heart_runner_post_resolution_cooldown` | `18.0s`",
        "`heart_pickup_lifetime` | `7.0s`",
        "`heart_pickup_warning_duration` | `1.5s`",
        "Two distinct dart indices from one `burst_id` may both damage",
    ]:
        require(approved_value in tuning, f"TUNING.md documents approved value {approved_value}", failures)

    require("[`TUNING.md`](TUNING.md)" in readme, "README links to TUNING.md", failures)
    require("[`TUNING.md`](TUNING.md)" in roadmap, "ROADMAP links to TUNING.md", failures)
    require("## Phase 4.6 Enemy Interaction And Formation Pass" in roadmap, "ROADMAP documents Phase 4.6 design direction", failures)
    require("Heart Runner" in readme and "Heart Runner" in roadmap, "Docs mention the implemented Heart Runner opportunity", failures)
    require("Prowler" in readme and "Prowler" in roadmap, "Docs mention the implemented Prowler phase", failures)
    require("positioning" in roadmap.lower() and "boomer" in roadmap.lower(), "ROADMAP frames Phase 4.6 around positioning-based cooperation and Boomer interactions", failures)
    require("shielded dart interception" not in readme.lower() and "intercept shooter darts" not in roadmap.lower(), "Docs no longer describe Shielded dart interception as the plan", failures)
    require("## Phase 4 Interlude 1 — Input & Audio Polish" in roadmap, "ROADMAP documents the bounded input/audio interlude", failures)
    require("Phase 4.5" in roadmap and "does not replace" in roadmap, "ROADMAP keeps Phase 4.5 reserved for enemy development", failures)
    require("quiet_hunter_loop_02.wav" in readme and "dedicated `audio_rng`" in tuning, "README and TUNING document the new local audio behavior", failures)
    require("spear_recover.wav" in readme and "legitimate landed-spear recovery" in roadmap.lower(), "Input/audio docs include the recovery-only spear cue", failures)

    if failures:
        print(f"\nTuning audit failed with {len(failures)} issue(s).")
        return 1

    print("\nTuning audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
