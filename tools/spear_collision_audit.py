from __future__ import annotations

from pathlib import Path
import re
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

    player_scene = read_text("Player.tscn")
    enemy_scene = read_text("Enemy.tscn")
    charger_scene = read_text("Charger.tscn")
    spear_scene = read_text("Spear.tscn")
    spear_script = read_text("scripts/spear.gd")

    damage_size_match = re.search(
        r'\[node name="CollisionShape2D" type="CollisionShape2D" parent="FlyingDamageArea"\]\s*position = Vector2\(([^,]+), ([^)]+)\)\s*shape = SubResource\("1"\)',
        spear_scene,
        re.MULTILINE,
    )
    rect_size_match = re.search(r'\[sub_resource type="RectangleShape2D" id="1"\]\s*size = Vector2\(([^,]+), ([^)]+)\)', spear_scene, re.MULTILINE)
    pickup_radius_match = re.search(r'\[sub_resource type="CircleShape2D" id="2"\]\s*radius = ([^\n]+)', spear_scene, re.MULTILINE)

    require('name="FlyingDamageArea"' in spear_scene, "Spear scene includes a dedicated flying damage area", failures)
    require('name="PickupArea"' in spear_scene, "Spear scene includes a dedicated pickup area", failures)
    require(rect_size_match is not None, "Flying damage collision size is defined", failures)
    require(damage_size_match is not None, "Flying damage collision position is defined", failures)
    require(pickup_radius_match is not None, "Pickup area shape is defined", failures)
    require("RectangleShape2D.new()" in spear_script, "Release sweep uses rectangle geometry", failures)
    require("launch_sweep_width := 4.0" in spear_script, "Release sweep width is explicitly defined", failures)
    require("launch_sweep_start_offset := 0.0" in spear_script, "Release sweep begins near Akedra", failures)
    require("launch_sweep_end_offset := 18.0" in spear_script, "Release sweep reaches the full visible spear length", failures)
    require(
        "_is_valid_spear_hittable_body" in spear_script
        and 'body.is_in_group("spear_hittable")' in spear_script
        and 'body.has_method("receive_combat_hit")' in spear_script,
        "Spear uses the narrow spear_hittable combat-hit contract instead of a broad hostile-layer assumption",
        failures,
    )
    require(
        'flying_damage_area.set_deferred("monitoring", is_flying_active)' in spear_script,
        "Flying damage area is active only while flying",
        failures,
    )
    require(
        'pickup_area.set_deferred("monitoring", is_pickup_active)' in spear_script,
        "Pickup area is active only while landed",
        failures,
    )
    require("active and state == State.LANDED and not pickup_in_progress" in spear_script, "Held state leaves both pickup and damage areas inactive", failures)
    require("DEBUG_SHOW_SPEAR_COLLISION := false" in spear_script, "Collision debug visualization is disabled by default", failures)
    require("_hit_enemy_if_needed" in spear_script, "Release sweep reuses per-throw duplicate-hit tracking", failures)
    require("pickup_in_progress" in spear_script, "Duplicate pickup is explicitly guarded", failures)
    require("await get_tree().physics_frame" in spear_script and "get_overlapping_bodies()" in spear_script, "Already-overlapping pickup is handled after landing", failures)
    require('collision_mask = 20' in player_scene, "Player mask explicitly includes the pickup area layer", failures)
    require('collision_mask = 12' in enemy_scene, "Enemy mask explicitly includes the flying damage area layer", failures)
    require('collision_mask = 12' in charger_scene, "Charger mask explicitly includes the flying damage area layer", failures)

    if rect_size_match is not None:
        print(f"INFO: Flying damage collider size = {rect_size_match.group(1)} x {rect_size_match.group(2)}")
    if damage_size_match is not None:
        print(f"INFO: Flying damage collider position = ({damage_size_match.group(1)}, {damage_size_match.group(2)})")
    if pickup_radius_match is not None:
        print(f"INFO: Pickup area radius = {pickup_radius_match.group(1).strip()}")

    if failures:
        print(f"\nSpear collision audit failed with {len(failures)} issue(s).")
        return 1

    print("\nSpear collision audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
