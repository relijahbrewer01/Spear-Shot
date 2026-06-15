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


def block_has_line(block: list[str], expected: str) -> bool:
    return any(line.strip() == expected for line in block)


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        print(f"FAIL: {message}")
        failures.append(message)


def parse_bus_values(layout_text: str) -> dict[str, dict[str, str]]:
    buses: dict[str, dict[str, str]] = {}
    current_bus: str | None = None

    for line in layout_text.splitlines():
        name_match = re.match(r'bus/(\d+)/name = &"([^"]+)"', line)
        if name_match:
            current_bus = name_match.group(2)
            buses[current_bus] = {}
            continue

        value_match = re.match(r'bus/\d+/(mute|volume_db|solo|bypass_fx|send) = (.+)', line)
        if current_bus is not None and value_match:
            buses[current_bus][value_match.group(1)] = value_match.group(2)

    return buses


def main() -> int:
    failures: list[str] = []

    main_scene = read_text("Main.tscn")
    hud_scene = read_text("HUD.tscn")
    player_scene = read_text("Player.tscn")
    spear_scene = read_text("Spear.tscn")
    enemy_scene = read_text("Enemy.tscn")
    charger_scene = read_text("Charger.tscn")
    hud_script = read_text("scripts/hud.gd")
    main_script = read_text("scripts/main.gd")
    player_script = read_text("scripts/player.gd")
    enemy_script = read_text("scripts/enemy.gd")
    spear_script = read_text("scripts/spear.gd")
    spear_trail_script = read_text("scripts/spear_trail.gd")
    bus_layout = read_text("default_bus_layout.tres")
    project_text = read_text("project.godot")
    arena_import_text = read_text("art/arena/arena_floor.png.import")
    player_import_text = read_text("art/sprites/player_hunter.png.import")
    enemy_import_text = read_text("art/sprites/enemy_creature.png.import")
    charger_import_text = read_text("art/sprites/charger_beast.png.import")
    spear_import_text = read_text("art/sprites/spear_hunter.png.import")

    main_nodes = parse_node_blocks(main_scene)
    hud_nodes = parse_node_blocks(hud_scene)
    player_nodes = parse_node_blocks(player_scene)
    spear_nodes = parse_node_blocks(spear_scene)
    enemy_nodes = parse_node_blocks(enemy_scene)
    charger_nodes = parse_node_blocks(charger_scene)
    buses = parse_bus_values(bus_layout)

    require("SpawnTimer" in main_nodes, "Main scene has SpawnTimer node", failures)
    if "SpawnTimer" in main_nodes:
        require(block_has_line(main_nodes["SpawnTimer"], "one_shot = true"), "SpawnTimer is one_shot", failures)

    require(
        'spawn_timer.timeout.connect(_on_spawn_timer_timeout)' in main_script,
        "Main script connects SpawnTimer timeout",
        failures,
    )
    require(
        'spawn_timer.start()' in main_script,
        "Main script starts the spawn timer",
        failures,
    )
    require(
        'const EnemyScene := preload("res://Enemy.tscn")' in main_script,
        "Main script preloads Enemy scene",
        failures,
    )
    require(
        'const ChargerScene := preload("res://Charger.tscn")' in main_script,
        "Main script preloads Charger scene",
        failures,
    )

    require("Sprite2D" in enemy_nodes, "Enemy scene has Sprite2D node", failures)
    require("Sprite2D" in charger_nodes, "Charger scene has Sprite2D node", failures)
    require("Trail" in spear_nodes, "Spear scene has dedicated Trail node", failures)

    gameplay_ignore_nodes = [
        "ScoreLabel",
        "PauseBackdrop",
        "PauseLabel",
        "GameOverBackdrop",
    ]
    for node_name in gameplay_ignore_nodes:
        block = hud_nodes.get(node_name, [])
        require(bool(block), f"HUD contains {node_name}", failures)
        if block:
            require(
                block_has_line(block, "mouse_filter = 2"),
                f"{node_name} uses MOUSE_FILTER_IGNORE",
                failures,
            )

    for removed_node_name in [
        "LeftHudPanel",
        "RightHudPanel",
        "HealthLabel",
        "SpearLabel",
        "TimeLabel",
        "HighScoreLabel",
    ]:
        require(
            removed_node_name not in hud_nodes,
            f"HUD removed {removed_node_name} for the Phase 1 minimal overlay",
            failures,
        )

    for node_name in ["GameOverPanel", "RestartButton"]:
        block = hud_nodes.get(node_name, [])
        require(bool(block), f"HUD contains {node_name}", failures)
        if block:
            require(
                block_has_line(block, "mouse_filter = 0"),
                f"{node_name} remains interactive",
                failures,
            )

    require("DestinationMarker" in main_nodes, "Main scene has DestinationMarker node", failures)
    require("HealthPips" in player_nodes, "Player scene has world-space HealthPips node", failures)
    require('texture_filter = 1' in player_scene, "Player sprite uses nearest filtering", failures)
    require('texture_filter = 1' in enemy_scene, "Enemy sprite uses nearest filtering", failures)
    require('texture_filter = 1' in charger_scene, "Charger sprite uses nearest filtering", failures)
    require('texture_filter = 1' in spear_scene, "Spear sprite uses nearest filtering", failures)

    for bus_name in ["Master", "Music", "SFX"]:
        require(bus_name in buses, f"{bus_name} bus exists", failures)
        if bus_name in buses:
            require(buses[bus_name].get("mute") == "false", f"{bus_name} bus is unmuted", failures)

    require(buses.get("Master", {}).get("volume_db") == "0.0", "Master bus volume is 0 dB", failures)
    require(buses.get("Music", {}).get("volume_db") == "-13.0", "Music bus volume is -13 dB", failures)
    require(buses.get("SFX", {}).get("volume_db") == "-4.0", "SFX bus volume is -4 dB", failures)

    require('bus = &"Music"' in main_scene, "MusicPlayer uses Music bus", failures)
    require(main_scene.count('bus = &"SFX"') == 7, "Seven gameplay SFX players use the SFX bus", failures)
    require('process_mode = Node.PROCESS_MODE_PAUSABLE' in main_script, "Main script is pausable for real SceneTree pause", failures)
    require('hud.process_mode = Node.PROCESS_MODE_ALWAYS' in main_script, "HUD stays responsive while paused", failures)
    require('music_player.process_mode = Node.PROCESS_MODE_ALWAYS' in main_script, "Music player keeps processing while paused", failures)
    require('signal pause_toggle_requested' in hud_script, "HUD exposes a pause key signal", failures)
    require('signal pause_resume_click_requested' in hud_script, "HUD exposes a pause click signal", failures)
    require('signal resume_countdown_finished' in hud_script, "HUD exposes a countdown completion signal", failures)
    require('hud.pause_toggle_requested.connect(_on_hud_pause_toggle_requested)' in main_script, "Main listens for HUD pause key requests", failures)
    require('hud.pause_resume_click_requested.connect(_on_hud_pause_resume_click_requested)' in main_script, "Main listens for HUD pause click requests", failures)
    require('hud.resume_countdown_finished.connect(_on_resume_countdown_finished)' in main_script, "Main listens for countdown completion", failures)
    require('destination_marker.show_marker(move_target)' in main_script, "Right-click movement shows a destination marker", failures)
    require(
        '_set_pause_state(true)' in main_script
        and '_start_resume_countdown()' in main_script
        and '_cancel_resume_countdown()' in main_script,
        "Pause input transitions between paused and countdown states",
        failures,
    )
    require('get_viewport().set_input_as_handled()' in hud_script, "HUD consumes pause/unpause input", failures)
    require('_restart_run()' in main_script, "Main uses in-place run restart", failures)
    require('reload_current_scene' not in main_script, "Scene reload restart path is removed", failures)
    require(
        '_add_key_action("pause_game", KEY_ESCAPE)' in main_script
        and '_add_key_action("pause_game", KEY_P)' in main_script,
        "Pause action is bound to Escape and P",
        failures,
    )
    require('reset_for_new_run' in player_script, "Player has an in-place reset method", failures)
    require('reset_for_new_run' in spear_script, "Spear has an in-place reset method", failures)
    require('resume_countdown_step_duration := 0.7' in hud_script, "HUD countdown step duration is shortened", failures)
    require('COUNTDOWN_STEP_COUNT := 3' in hud_script, "HUD preserves the 3 2 1 countdown sequence", failures)
    require('Time.get_ticks_msec()' in hud_script, "HUD countdown uses real-time ticking", failures)
    require('health_pips.set_health_values(health, max_health)' in player_script, "Player updates health pip values", failures)
    require('health_pips.sync_to_player(self)' in player_script, "Player keeps health pips synced under the sprite", failures)
    require(
        '_hit_enemies_in_launch_sweep' in spear_script,
        "Spear performs a throw-start launch sweep",
        failures,
    )
    require(
        'trail.set_trail_points(trail_points)' in spear_script and 'to_local(global_points' in spear_trail_script,
        "Spear trail uses a non-rotating node with global-to-local conversion",
        failures,
    )
    require(
        'body_visual.top_level = true' in player_script
        and 'body_visual.global_position' in player_script
        and 'body_visual.scale = Vector2.ONE' in player_script
        and 'sprite.top_level = true' in enemy_script
        and 'sprite.top_level = true' in spear_script,
        "Key gameplay visuals use snapped top-level rendering",
        failures,
    )
    require(
        'roundf(randf_range' in main_script,
        "Screen shake offset is snapped to whole pixels",
        failures,
    )
    require(
        'trail_points[segment_index] - global_position' not in spear_script,
        "Old spear-local trail conversion is removed",
        failures,
    )
    require(
        spear_script.count("_clear_trail()") >= 4,
        "Spear trail is cleared when it should not persist",
        failures,
    )
    require("FlyingDamageArea" in spear_nodes, "Spear scene has a dedicated flying damage area", failures)
    require("PickupArea" in spear_nodes, "Spear scene has a dedicated landed pickup area", failures)
    require("pickup_in_progress" in spear_script, "Spear guards against duplicate pickup events", failures)
    require("_check_landed_pickup_overlap" in spear_script, "Spear performs a landed overlap pickup check", failures)
    require(
        'collision_mask = 20' in player_scene,
        "Player collision mask explicitly includes the pickup area layer",
        failures,
    )
    require(
        'collision_mask = 12' in enemy_scene and 'collision_mask = 12' in charger_scene,
        "Enemies explicitly include the flying damage area layer in their masks",
        failures,
    )
    require(
        not (ROOT / "scripts" / "debug_log.gd").exists(),
        "Temporary spawn debug helper script is removed",
        failures,
    )
    require('DEBUG_SFX_TEST_ENABLED' not in main_script, "Temporary SFX debug key system is removed", failures)
    require('_play_debug_sfx' not in main_script, "Temporary SFX debug helper is removed", failures)
    require('_try_handle_debug_sfx_input' not in main_script, "Temporary SFX debug input handling is removed", failures)
    require('DebugLog' not in main_script, "Spawn debug logging is removed from Main", failures)
    require('DebugPixelPattern' not in main_scene, "Runtime pixel test helper is removed from Main", failures)
    require(
        not (ROOT / "scripts" / "debug_pixel_pattern.gd").exists(),
        "Runtime pixel test helper script is removed",
        failures,
    )

    require('window/stretch/mode="viewport"' in project_text, "Project uses viewport stretch mode", failures)
    require('window/stretch/aspect="keep"' in project_text, "Project preserves 16:9 aspect ratio", failures)
    require('window/stretch/scale_mode="integer"' in project_text, "Project uses integer scaling for crisp pixels", failures)
    require(
        'textures/canvas_textures/default_texture_filter=0' in project_text,
        "Project keeps nearest-neighbor texture filtering",
        failures,
    )
    for import_name, import_text in [
        ("arena floor", arena_import_text),
        ("player sprite", player_import_text),
        ("enemy sprite", enemy_import_text),
        ("charger sprite", charger_import_text),
        ("spear sprite", spear_import_text),
    ]:
        require(f"mipmaps/generate=false" in import_text, f"{import_name} import disables mipmaps", failures)

    if failures:
        print(f"\nAudit failed with {len(failures)} issue(s).")
        return 1

    print("\nAudit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
