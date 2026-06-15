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

    enemy_script = read_text("scripts/enemy.gd")
    charger_script = read_text("scripts/charger.gd")

    require("visual_time += delta" in charger_script, "Charger visual time advances in its custom physics loop", failures)
    require("_update_sprite_visuals()" in charger_script, "Charger physics loop updates the inherited sprite transform every frame", failures)
    require("last_sprite_target_global_position" in enemy_script, "Enemy tracks the authoritative sprite target position", failures)
    require("_get_sprite_target_global_position" in enemy_script, "Enemy exposes one authoritative sprite target calculation", failures)
    require(
        "sprite.global_position = last_sprite_target_global_position" in enemy_script,
        "Enemy sprite uses the authoritative target position assignment",
        failures,
    )
    require(
        "_update_visible_entry_state()" in charger_script and "_can_deal_contact_damage()" in charger_script,
        "Charger has visual-entry safety before dealing damage",
        failures,
    )
    require(
        "sprite.global_position.distance_to(last_sprite_target_global_position)" in charger_script,
        "Charger damage safety checks sprite/root synchronization directly",
        failures,
    )
    require(
        "sprite.global_position =" not in charger_script,
        "Charger script does not overwrite sprite position with a stale cached value",
        failures,
    )
    require(
        "_get_visual_offset()" in charger_script and "draw_offset := _get_visual_offset()" in charger_script,
        "Charger shadow and telegraph still use the shared visual offset function",
        failures,
    )

    if failures:
        print(f"\nCharger visual audit failed with {len(failures)} issue(s).")
        return 1

    print("\nCharger visual audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
