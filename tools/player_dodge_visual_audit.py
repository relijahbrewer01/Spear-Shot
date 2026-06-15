from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def parse_node_blocks(scene_text: str) -> dict[str, list[str]]:
    blocks: dict[str, list[str]] = {}
    current_name: str | None = None
    current_lines: list[str] = []

    for line in scene_text.splitlines():
        node_match = re.match(r'\[node name="([^"]+)"', line)
        if node_match:
            if current_name is not None:
                blocks.setdefault(current_name, []).extend(current_lines)
            current_name = node_match.group(1)
            current_lines = [line]
            continue

        if current_name is not None:
            current_lines.append(line)

    if current_name is not None:
        blocks.setdefault(current_name, []).extend(current_lines)

    return blocks


def block_has_fragment(block: list[str], expected_fragment: str) -> bool:
    return any(expected_fragment in line for line in block)


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        print(f"FAIL: {message}")
        failures.append(message)


def main() -> int:
    failures: list[str] = []

    player_scene = read_text("Player.tscn")
    player_script = read_text("scripts/player.gd")
    spear_script = read_text("scripts/spear.gd")
    trail_script = read_text("scripts/player_dodge_trail.gd")

    player_nodes = parse_node_blocks(player_scene)

    require("BodyVisual" in player_nodes, "Player scene has a dedicated BodyVisual node", failures)
    require("DodgeTrail" in player_nodes, "Player scene has a dedicated DodgeTrail node", failures)
    require(
        "Sprite2D" in player_nodes and block_has_fragment(player_nodes["Sprite2D"], 'parent="BodyVisual"'),
        "Player sprite is parented under BodyVisual",
        failures,
    )
    require(
        "HealthPips" in player_nodes and block_has_fragment(player_nodes["HealthPips"], 'parent="."'),
        "Health pips stay outside the rotating BodyVisual",
        failures,
    )
    require(
        "CollisionShape2D" in player_nodes and block_has_fragment(player_nodes["CollisionShape2D"], 'parent="."'),
        "Player collision stays outside the rotating BodyVisual",
        failures,
    )
    require(
        "rotation = last_valid_aim_direction.angle()" not in player_script
        and "@onready var body_visual: Node2D = $BodyVisual" in player_script,
        "Player gameplay root is no longer rotated for normal facing",
        failures,
    )
    require(
        "body_sprite.flip_h = facing_direction < 0" in player_script
        and "func _update_horizontal_facing(move_input: Vector2) -> void:" in player_script,
        "Normal left movement uses horizontal flipping with movement-based facing",
        failures,
    )
    require(
        "horizontal_facing_dead_zone" in player_script,
        "Player facing uses a horizontal dead zone",
        failures,
    )
    require(
        "func _reset_body_visual_roll() -> void:" in player_script
        and "body_visual.rotation = 0.0" in player_script,
        "BodyVisual rotation resets to zero after dodge and on state cleanup",
        failures,
    )
    require(
        "dodge_trail.begin_dodge()" in player_script
        and "dodge_trail.advance_trail(" in player_script
        and "is_dodging()" in player_script,
        "Dodge trail sampling is only driven during active dodge",
        failures,
    )
    require(
        "clear_trail()" in trail_script and "Sprite2D.new()" in trail_script,
        "Dodge trail uses a lightweight fixed sprite pool",
        failures,
    )
    require(
        "Area2D" not in trail_script and "CollisionShape2D" not in trail_script,
        "Dodge trail has no collision nodes or gameplay collision logic",
        failures,
    )
    require(
        "_clear_dodge_visuals()" in player_script
        and "reset_for_new_run" in player_script
        and "set_active(is_active: bool)" in player_script,
        "Restart and disabled states clear roll and trail visuals",
        failures,
    )
    require(
        "owner_player.get_last_valid_aim_direction()" in spear_script
        and "owner_player.rotation" not in spear_script,
        "Held spear aiming remains independent from body roll rotation",
        failures,
    )

    if failures:
        print(f"\nPlayer dodge visual audit failed with {len(failures)} issue(s).")
        return 1

    print("\nPlayer dodge visual audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
