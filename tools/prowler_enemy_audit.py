from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

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

    prowler = read_text("scripts/prowler_enemy.gd")
    prowler_scene = read_text("ProwlerEnemy.tscn")
    main_script = read_text("scripts/main.gd")
    director = read_text("scripts/encounter_director.gd")
    generator = read_text("tools/generate_phase4_assets.py")
    readme = read_text("README.md")
    roadmap = read_text("ROADMAP.md")
    tuning = read_text("TUNING.md")
    sprite_import = read_text("art/sprites/prowler_enemy.png.import")

    for relative_path in [
        "ProwlerEnemy.tscn",
        "scripts/prowler_enemy.gd",
        "art/sprites/prowler_enemy.png",
        "art/sprites/prowler_enemy.png.import",
        "art/dev/prowler_candidates/prowler_comparison.png",
        "art/dev/prowler_candidates/prowler_manifest.json",
        "tools/prowler_enemy_audit.py",
        "tools/ProwlerEnemyRuntimeAudit.tscn",
        "tools/prowler_enemy_runtime_audit.gd",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("class_name ProwlerEnemy" in prowler and "extends Enemy" in prowler, "ProwlerEnemy extends Enemy with a class name", failures)
    require("signal state_changed" in prowler, "Prowler exposes a narrow state-change seam for runtime auditing", failures)
    require("enum ProwlerState" in prowler and "STALK" in prowler and "ALERT" in prowler and "HUNT" in prowler, "Prowler uses the approved STALK -> ALERT -> HUNT behavior model", failures)
    require("unarmed_alert_delay := 0.14" in prowler, "Prowler alert delay is 0.14 seconds", failures)
    require("stalk_speed_scale := 0.82" in prowler and "hunt_speed_scale := 1.48" in prowler, "Prowler stalking and hunting speeds match the approved defaults", failures)
    require("stalk_distance_min := 72.0" in prowler and "stalk_distance_max := 104.0" in prowler and "stalk_dead_zone := 5.0" in prowler, "Prowler stalking band matches the approved medium range", failures)
    require("stalk_lateral_commit_duration := 0.55" in prowler and "wall_fallback_commit_duration := 0.35" in prowler, "Prowler uses committed lateral movement and wall fallback timers", failures)
    require("set_tracked_spear" in prowler and "_on_tracked_spear_state_changed" in prowler and "_connect_spear_state_signal" in prowler, "Prowler tracks the authoritative spear state through a narrow direct signal seam", failures)
    require("new_state == Spear.State.HELD" in prowler and "tracked_spear_is_held" in prowler, "Prowler derives armed versus unarmed behavior from the real spear HELD state", failures)
    require("func _process_alive_behavior" in prowler and "_process_stalk_state" in prowler and "_process_alert_state" in prowler and "_process_hunt_state" in prowler, "Prowler behavior stays isolated inside the shared Enemy alive-behavior seam", failures)
    require("func receive_combat_hit" not in prowler, "Prowler keeps the ordinary one-hit spear death path from Enemy instead of adding a second combat path", failures)
    require("tracked_spear.global_position" not in prowler and "try_throw" not in prowler and "apply_landed_shockwave_nudge" not in prowler, "Prowler reads spear state only and does not manipulate the spear itself", failures)
    require("score_value = 2" in prowler_scene, "Prowler score is 2", failures)
    require("body_radius = 7.0" in prowler_scene and "radius = 7.0" in prowler_scene, "Prowler body and collision radii start at 7", failures)
    require("separation_distance = 20.0" in prowler_scene and "separation_strength = 50.0" in prowler_scene, "Prowler uses its own lightweight spacing defaults", failures)
    require("collision_layer = 2" in prowler_scene and "collision_mask = 12" in prowler_scene, "Prowler uses the ordinary hostile collision layer and mask", failures)

    require('const ProwlerScene := preload("res://ProwlerEnemy.tscn")' in main_script, "Main preloads ProwlerEnemy", failures)
    require("DEBUG_PROWLER_SPAWN_ENABLED := true" in main_script and "_debug_spawn_prowler_enemy" in main_script and "KEY_5" in main_script, "Prowler debug spawn uses key 5", failures)
    require("enemy.has_method(\"set_tracked_spear\")" in main_script, "Main passes the authoritative spear reference into enemies that request it", failures)
    require("prowler_unlock_time := 78.0" in main_script and "prowler_intro_target_time_min := 78.0" in main_script and "prowler_intro_target_time_max := 88.0" in main_script, "Prowler intro timing is configured in Main", failures)
    require("prowler_spawn_chance_at_unlock := 0.03" in main_script and "prowler_spawn_chance_growth_per_second := 0.00030" in main_script and "maximum_prowler_spawn_chance := 0.08" in main_script, "Prowler long-run ambient weights are configured in Main", failures)
    require("prowler_intro_seen" in main_script and "prowler_intro_target_time = rng.randf_range" in main_script, "Prowler reuses the randomized first-introduction guarantee path", failures)
    require("EnemyKind.PROWLER" in main_script, "Main can select the Prowler enemy kind", failures)

    require("PROWLER" in director, "EncounterDirector defines Prowler as its own hostile kind", failures)
    require("prowler_hostile_cap := 1" in director, "Prowler dedicated cap is 1", failures)
    require("get_prowler_hostile_count()" in director and "get_prowler_hostile_count() < prowler_hostile_cap" in director, "EncounterDirector enforces a dedicated Prowler cap", failures)
    require("EnemyKind.PROWLER" not in director.split("func _build_wave_definitions", 1)[1], "Authored waves still contain no Prowler steps", failures)

    require("draw_prowler_enemy" in generator and "build_prowler_variant_specs" in generator and "generate_prowler_candidate_assets" in generator, "Prowler live sprite and candidate assets are reproducible locally", failures)
    require("draw_prowler_comparison" in generator and "--generate-dev-prowler-concepts" in generator, "Prowler concept generation stays behind an explicit dev-workflow flag", failures)
    require("mipmaps/generate=false" in sprite_import, "Prowler sprite import disables mipmaps", failures)

    prowler_image = Image.open(ROOT / "art/sprites/prowler_enemy.png")
    comparison_image = Image.open(ROOT / "art/dev/prowler_candidates/prowler_comparison.png")
    require(prowler_image.size == (16, 16), "Prowler live sprite uses the approved compact 16x16 canvas", failures)
    require(comparison_image.size == (384, 216), "Prowler comparison board renders at native arena scale", failures)

    manifest = json.loads((ROOT / "art/dev/prowler_candidates/prowler_manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("active_reference_path") == str(ROOT / "art/sprites/prowler_enemy.png"), "Prowler manifest points to the live sprite", failures)
    require(len(manifest.get("candidates", [])) == 3, "Prowler manifest records three distinct candidates", failures)

    require("Prowler" in readme and "Prowler" in roadmap and "Prowler" in tuning, "Docs mention the implemented Prowler phase", failures)
    require("Phase 4.5" in readme and "Phase 4.5" in roadmap, "README and ROADMAP document Phase 4.5", failures)

    if failures:
        print(f"\nProwler enemy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nProwler enemy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
