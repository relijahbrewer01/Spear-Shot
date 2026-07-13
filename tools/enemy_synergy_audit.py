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

    enemy = read_text("scripts/enemy.gd")
    shielded = read_text("scripts/shielded_enemy.gd")
    main_script = read_text("scripts/main.gd")
    enemy_scene = read_text("Enemy.tscn")
    shielded_scene = read_text("ShieldedEnemy.tscn")
    charger_scene = read_text("Charger.tscn")
    shooter_scene = read_text("ShooterEnemy.tscn")
    boomer_scene = read_text("BoomerEnemy.tscn")
    prowler_scene = read_text("ProwlerEnemy.tscn")
    director = read_text("scripts/encounter_director.gd")
    tuning = read_text("TUNING.md")

    require((ROOT / "tools" / "EnemySynergyRuntimeAudit.tscn").exists(), "Enemy synergy runtime audit scene exists", failures)
    require((ROOT / "tools" / "enemy_synergy_runtime_audit.gd").exists(), "Enemy synergy runtime audit script exists", failures)

    require(
        "enum FormationBias" in enemy
        and "DIRECT" in enemy
        and "LEFT_FLANK" in enemy
        and "RIGHT_FLANK" in enemy,
        "Enemy defines the three-value formation bias enum",
        failures,
    )
    require("uses_formation_bias := false" in enemy, "Enemy keeps formation bias opt-in by default", failures)
    require(
        "formation_bias_angle_degrees := 18.0" in enemy,
        "Enemy exports the conservative 18-degree formation bias angle",
        failures,
    )
    require(
        "formation_direct_pressure_distance := 28.0" in enemy,
        "Enemy exports the close-range direct-pressure fallback distance",
        failures,
    )
    require(
        "formation_wall_fallback_padding := 8.0" in enemy,
        "Enemy exports the minimal wall fallback padding",
        failures,
    )
    require("accepts_authored_hostile_displacement := false" in enemy, "Enemy keeps authored hostile displacement opt-in by default", failures)
    require(
        "func set_formation_bias" in enemy
        and "func get_formation_bias_name" in enemy,
        "Enemy exposes narrow formation-bias assignment helpers",
        failures,
    )
    require(
        "func can_accept_authored_hostile_displacement" in enemy
        and "func try_start_authored_hostile_displacement" in enemy
        and "func _process_authored_hostile_displacement" in enemy
        and "func _clear_authored_hostile_displacement" in enemy,
        "Enemy exposes the authored hostile-displacement contract and lifecycle",
        failures,
    )
    require(
        "if not _process_authored_hostile_displacement(delta):" in enemy,
        "Enemy processes authored hostile displacement before ordinary alive behavior",
        failures,
    )
    require(
        "_get_formation_biased_direction" in enemy
        and "_would_biased_direction_risk_arena_clamp" in enemy,
        "Enemy keeps crowd-flow bias and wall fallback inside the shared base movement seam",
        failures,
    )
    require(
        "if uses_formation_bias:" in enemy and "formation_bias == FormationBias.DIRECT" in enemy,
        "Enemy applies the bias only through the explicit opt-in chase path",
        failures,
    )

    require("uses_formation_bias = true" in enemy_scene, "Normal enemy scene opts into formation bias", failures)
    require(
        "accepts_authored_hostile_displacement = true" in enemy_scene,
        "Normal enemy scene opts into authored hostile displacement",
        failures,
    )
    require("uses_formation_bias = true" in shielded_scene, "Shielded scene opts into formation bias", failures)
    require(
        "accepts_authored_hostile_displacement = true" in shielded_scene,
        "Shielded scene opts into authored hostile displacement",
        failures,
    )

    for scene_name, scene_text in [
        ("Charger", charger_scene),
        ("Shooter", shooter_scene),
        ("Boomer", boomer_scene),
        ("Prowler", prowler_scene),
    ]:
        require(
            "uses_formation_bias = true" not in scene_text,
            f"{scene_name} does not opt into shared formation bias in this checkpoint",
            failures,
        )
        require(
            "accepts_authored_hostile_displacement = true" not in scene_text,
            f"{scene_name} does not opt into authored hostile displacement in this checkpoint",
            failures,
        )

    require(
        "func can_accept_authored_hostile_displacement() -> bool:" in shielded
        and "is_staggering()" in shielded
        and "knockback_time_left > 0.0" in shielded,
        "Shielded narrows authored displacement eligibility to safe ordinary movement only",
        failures,
    )
    require(
        "cancel_authored_hostile_displacement()" in shielded,
        "Shield break clears any authored hostile displacement before stagger begins",
        failures,
    )

    require(
        "FORMATION_BIAS_SEQUENCE" in main_script
        and "formation_bias_assignment_index" in main_script
        and "debug_formation_bias_assignment_index" in main_script,
        "Main tracks formation assignment through isolated counters instead of gameplay RNG",
        failures,
    )
    require(
        "_assign_enemy_formation_bias(enemy, enemy_kind, spawn_source)" in main_script
        and "_enemy_kind_uses_formation_bias" in main_script
        and "_get_next_formation_bias" in main_script,
        "Main assigns formation bias through the existing spawn seam",
        failures,
    )
    helper_block = main_script.split("func _get_next_formation_bias", 1)[1].split("func ", 1)[0]
    require("rng." not in helper_block, "Formation bias sequencing does not consume the gameplay RNG stream", failures)
    require(
        "enemy_kind == EncounterDirector.EnemyKind.NORMAL" in main_script
        and "enemy_kind == EncounterDirector.EnemyKind.SHIELDED" in main_script,
        "Main limits automatic formation-bias assignment to Normal and Shielded enemies",
        failures,
    )
    require("FORMATION_BIAS_SEQUENCE[sequence_index % FORMATION_BIAS_SEQUENCE.size()]" in main_script, "Formation bias assignment is deterministic and repeatable", failures)

    require("FormationBias" not in director and "Bulwark" not in director, "EncounterDirector remains unchanged for this checkpoint", failures)

    for documented_value in [
        "formation_bias_angle_degrees",
        "formation_direct_pressure_distance",
        "formation_wall_fallback_padding",
        "`formation_bias_angle_degrees` | `18.0`",
        "`formation_direct_pressure_distance` | `28.0px`",
        "`formation_wall_fallback_padding` | `8.0px`",
    ]:
        require(documented_value in tuning, f"TUNING.md documents {documented_value}", failures)

    if failures:
        print(f"\nEnemy synergy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nEnemy synergy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
