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
        "## Dart Projectile",
        "## HUD And Feedback",
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
        "aim_cancel_reposition_duration",
        "arc_reposition_duration",
        "arc_reposition_speed_scale",
        "arc_radial_correction_strength",
        "shove_cooldown",
        "PROJECTILE_KIND_DART",
        "DAMAGE_SOURCE_DART",
        "try_start_forced_movement",
    ]:
        require(variable_name in tuning, f"TUNING.md documents {variable_name}", failures)

    for approved_value in [
        "14x16px",
        "`movement_speed_scale` | `0.90`",
        "`aim_duration` | `0.48s`",
        "`locked_duration` | `0.24s`",
        "`burst_interval` | `0.17s`",
        "`attack_cooldown` | `0.95s`",
        "`aim_cancel_reposition_duration` | `0.55s`",
        "`arc_reposition_duration` | `1.10s`",
        "`arc_reposition_speed_scale` | `1.35`",
        "`arc_reposition_side_sample_distance` | `60.0px`",
        "`arc_radial_correction_strength` | `0.28`",
        "`shove_cooldown` | `2.10s`",
        "Two distinct dart indices from one `burst_id` may both damage",
    ]:
        require(approved_value in tuning, f"TUNING.md represents Shooter value {approved_value}", failures)

    require("[`TUNING.md`](TUNING.md)" in readme, "README links to TUNING.md", failures)
    require("[`TUNING.md`](TUNING.md)" in roadmap, "ROADMAP links to TUNING.md", failures)
    require("## Phase 4.6 Enemy Interaction And Formation Pass" in roadmap, "ROADMAP documents Phase 4.6 design direction", failures)

    if failures:
        print(f"\nTuning audit failed with {len(failures)} issue(s).")
        return 1

    print("\nTuning audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
