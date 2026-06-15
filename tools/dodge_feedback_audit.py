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


def block_has_fragment(block: list[str], expected: str) -> bool:
    return any(expected in line for line in block)


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
    main_script = read_text("scripts/main.gd")
    main_scene = read_text("Main.tscn")
    indicator_script = read_text("scripts/player_dodge_cooldown_indicator.gd")
    trail_script = read_text("scripts/player_dodge_trail.gd")
    player_nodes = parse_node_blocks(player_scene)

    require("dodge_cooldown := 2.0" in player_script, "Shared cooldown is 2.00 seconds", failures)
    require(
        "CooldownIndicator" in player_nodes
        and block_has_fragment(player_nodes["CooldownIndicator"], 'parent="."'),
        "Cooldown indicator is a sibling of BodyVisual",
        failures,
    )
    require(
        "cooldown_left > 0.0" in indicator_script
        and "cooldown_progress = clampf(cooldown_left / cooldown_duration" in indicator_script,
        "Wisp appears only during cooldown and uses the real cooldown timer",
        failures,
    )
    require(
        "global_rotation = 0.0" in indicator_script
        and "scale = Vector2.ONE" in indicator_script
        and "CooldownIndicator" not in trail_script,
        "Wisp remains upright and is excluded from afterimages",
        failures,
    )
    require(
        "clear_indicator()" in indicator_script
        and player_script.count("_clear_cooldown_indicator()") >= 3,
        "Reset, death, and disable hide cooldown feedback",
        failures,
    )
    require(
        "show_ready_glint()" in player_script
        and "ready_glint_left = ready_glint_duration" in indicator_script,
        "Cooldown completion produces a brief ready glint",
        failures,
    )
    require(
        main_script.count("_play_sfx(dodge_player)") == 2
        and "if player.try_start_aim_dodge" in main_script
        and "if player.try_start_movement_dodge" in main_script,
        "Only successful Shift and Space dodges play the sound once",
        failures,
    )
    require(
        'volume_db = -5.0' in main_scene,
        "Heavier dodge sound plays at -5 dB",
        failures,
    )
    require(
        "clear_move_destination()" in player_script
        and "if suppress_held_movement:" in player_script,
        "Shift clears the destination that existed before dodge start",
        failures,
    )
    require(
        "func buffer_post_dodge_destination(target_position: Vector2) -> void:" in player_script
        and "player.buffer_post_dodge_destination(move_target)" in main_script,
        "Fresh right-clicks during dodge are buffered",
        failures,
    )
    require(
        "pending_post_dodge_destination = _clamp_position_to_arena(target_position)" in player_script,
        "Newest buffered click replaces the previous destination",
        failures,
    )
    require(
        "_apply_pending_post_dodge_destination()" in player_script
        and player_script.index("_apply_pending_post_dodge_destination()") < player_script.index("dodge_ended.emit()"),
        "Buffered destination is applied immediately when dodge ends",
        failures,
    )
    require(
        "var buffered_destination := pending_post_dodge_destination" in player_script
        and "_clear_pending_post_dodge_destination()" in player_script,
        "Buffered destination is cleared after consumption",
        failures,
    )
    move_input_index = main_script.index('event.is_action_pressed("move_to_cursor")')
    dodge_block_index = main_script.index("if player.is_dodging():\n\t\treturn")
    require(
        move_input_index < dodge_block_index,
        "Right-click handling runs before the active-dodge input block",
        failures,
    )
    require(
        player_script.count("_clear_pending_post_dodge_destination()") >= 5,
        "Restart, death, disable, and cancellation do not leak buffered movement",
        failures,
    )

    if failures:
        print(f"\nDodge feedback audit failed with {len(failures)} issue(s).")
        return 1

    print("\nDodge feedback audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
