from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        failures.append(message)
        print(f"FAIL: {message}")


def main() -> int:
    failures: list[str] = []
    spear = read_text("scripts/spear.gd")
    main_script = read_text("scripts/main.gd")
    hud = read_text("scripts/hud.gd")
    hud_scene = read_text("HUD.tscn")
    readme = read_text("README.md")
    roadmap = read_text("ROADMAP.md")
    tuning = read_text("TUNING.md")

    require("var next_throw_id := 0" in spear and "var active_throw_id := 0" in spear, "Spear owns a stable monotonic throw context", failures)
    require("throw_context_started" in spear and "throw_context_resolved" in spear, "Spear exposes narrow flight-start and flight-end context signals", failures)
    require("direct_hostile_killed" in spear and "enemy.is_dying" in spear, "Spear registers only confirmed direct hostile deaths", failures)
    require("hit_enemy_ids.has(enemy_id)" in spear, "Existing per-throw hit guard prevents duplicate registration", failures)
    require("active_throw_id = 0" in spear.split("func reset_for_new_run", 1)[1].split("func set_active", 1)[0], "Run reset clears the active spear throw context", failures)
    require("if not active:\n\t\tactive_throw_id = 0" in spear, "Spear deactivation clears pending flight attribution", failures)

    require("active_spear_throw_kill_ids" in main_script, "Main owns the per-flight eligible kill set", failures)
    require("spear.direct_hostile_killed.connect(_on_spear_direct_hostile_killed)" in main_script, "Main listens to explicit spear direct-kill attribution", failures)
    require("score += score_value" in main_script and "multikill" not in main_script.split("func _on_enemy_killed", 1)[1].split("func _on_enemy_tree_exited", 1)[0].lower(), "Existing score accumulation stays independent of multikill feedback", failures)
    require('hud.show_multikill_feedback("DOUBLE")' in main_script and 'hud.show_multikill_feedback("TRIPLE")' in main_script and 'hud.show_multikill_feedback("QUAD")' in main_script, "DOUBLE, TRIPLE, and QUAD mappings exist with four-or-more folded into QUAD", failures)
    require("eligible_kill_count < 2" in main_script, "Zero and one direct kill produce no feedback", failures)
    require("_clear_spear_throw_context()" in main_script, "Restart, death, and teardown clear pending throw feedback", failures)

    require('name="MultikillLabel"' in hud_scene, "HUD scene contains one transient multikill label", failures)
    require("multikill_feedback_duration := 0.75" in hud, "HUD has the named feedback lifetime tuning value", failures)
    require("get_tree().paused" in hud and "_update_multikill_feedback" in hud, "HUD feedback lifetime freezes while gameplay is paused", failures)
    require("clear_multikill_feedback" in hud and "show_multikill_feedback" in hud, "HUD supports replacement and explicit cleanup without stacking labels", failures)
    require("AudioStreamPlayer" not in hud and "audio/" not in hud, "Multikill feedback adds no audio", failures)

    for forbidden_term in ["multiplier", "combo_timer", "multikill_stat", "achievement"]:
        require(forbidden_term not in main_script.lower(), f"Main adds no {forbidden_term} system", failures)

    require("direct same-throw hostile kills" in readme.lower() and "does not add bonus score" in tuning, "README and TUNING describe feedback-only behavior", failures)
    require("Phase 4.6.6 adds feedback only" in roadmap and "multikill bonus points" in roadmap and "timed combos" in roadmap, "Roadmap keeps the full scoring and statistics expansion deferred", failures)

    if failures:
        print(f"\nMultikill feedback audit failed with {len(failures)} issue(s).")
        return 1
    print("\nMultikill feedback audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
