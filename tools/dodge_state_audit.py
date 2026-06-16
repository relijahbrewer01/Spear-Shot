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
        print(f"FAIL: {message}")
        failures.append(message)


def main() -> int:
    failures: list[str] = []

    main_script = read_text("scripts/main.gd")
    player_script = read_text("scripts/player.gd")
    spear_script = read_text("scripts/spear.gd")
    readme_text = read_text("README.md")
    roadmap_text = read_text("ROADMAP.md")

    require(
        'Current milestone: `Spear Shot v0.6.0-alpha.2 - Blowgun Shooter`' in readme_text,
        "README milestone is stamped v0.6.0-alpha.2 Blowgun Shooter",
        failures,
    )
    require("signal dodge_started" in player_script and "signal dodge_ended" in player_script and "signal dodge_ready" in player_script, "Player exposes dodge start/end/ready hooks", failures)
    require("enum ActionState" in player_script and "DODGING" in player_script, "Player defines an explicit dodge state", failures)
    require("dodge_duration := 0.20" in player_script, "Player dodge duration matches the utility tuning", failures)
    require("dodge_distance := 36.0" in player_script, "Player dodge distance matches the utility tuning", failures)
    require("dodge_cooldown := 2.0" in player_script, "Player dodge cooldown matches the final tuning", failures)
    require("dodge_cooldown_left = dodge_cooldown" in player_script, "Shift and Space share the same cooldown timer", failures)
    require("The shared dodge cooldown starts when the dodge begins" in readme_text, "README documents when dodge cooldown timing begins", failures)
    require(
        "action_state != ActionState.DODGING" in player_script
        and "action_state != ActionState.DISABLED" in player_script
        and "dodge_cooldown_left == 0.0" in player_script,
        "Dodge cannot start while already dodging, while disabled, or while cooling down.",
        failures,
    )
    require(
        "is_damage_invulnerable" in player_script
        and "invulnerability_left > 0.0 or is_dodging() or dodge_exit_invulnerability_left > 0.0" in player_script,
        "Dodge, exit grace, and normal hurt invulnerability use one damage check",
        failures,
    )
    require("func _process_dodge_motion(delta: float) -> void:" in player_script and "_clamp_position_to_arena" in player_script, "Dodge movement is clamped inside the arena deterministically", failures)
    require("dodge_cooldown_left = 0.0" in player_script and "dodge_time_left = 0.0" in player_script, "Restart/reset clears active dodge and cooldown state", failures)
    require("pickup_area" in spear_script and "_on_pickup_body_entered" in spear_script, "Landed spear pickup remains body-based and available during dodge", failures)
    require('event.is_action_pressed("dodge_aim")' in main_script and 'event.is_action_pressed("dodge_move")' in main_script, "Main handles both dodge input actions", failures)
    require("run_state != RunState.RUNNING" in main_script, "Dodge input is blocked outside the running state", failures)
    require("if player.is_dodging():\n\t\treturn" in main_script, "Throw and click-move input are blocked during active dodge", failures)
    require("player.get_last_valid_aim_direction()" in main_script, "Dodge direction fallback cannot become zero", failures)
    require('"_cancel_hit_stop()"' not in player_script, "Player dodge does not directly tamper with global hit-stop state", failures)
    require("collision_layer =" not in player_script and "collision_mask =" not in player_script, "Dodge does not rely on temporary player collision-layer rewrites", failures)
    require("multikill" in roadmap_text.lower() or "chain-bonus" in roadmap_text.lower(), "Roadmap includes future same-throw multikill scoring", failures)
    require("career statistics" in roadmap_text.lower() and "leaderboards" in roadmap_text.lower(), "Roadmap includes long-term progression and social progression notes", failures)

    if failures:
        print(f"\nDodge audit failed with {len(failures)} issue(s).")
        return 1

    print("\nDodge audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
