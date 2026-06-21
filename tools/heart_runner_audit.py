from __future__ import annotations

import json
import sys
import wave
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


def audit_wav(relative_path: str, min_duration: float, max_duration: float, failures: list[str]) -> None:
    path = ROOT / relative_path
    require(path.exists(), f"{relative_path} exists", failures)
    if not path.exists():
        return

    with wave.open(str(path), "rb") as wav_file:
        frame_count = wav_file.getnframes()
        sample_rate = wav_file.getframerate()
        channels = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        frames = wav_file.readframes(frame_count)

    samples = [
        int.from_bytes(frames[index : index + 2], "little", signed=True)
        for index in range(0, len(frames), 2)
    ]
    peak = max((abs(sample) for sample in samples), default=0)
    meaningful_samples = sum(1 for sample in samples if abs(sample) >= 512)
    duration = frame_count / sample_rate if sample_rate else 0.0

    require(channels == 1, f"{relative_path} is mono", failures)
    require(sample_width == 2, f"{relative_path} is 16-bit PCM", failures)
    require(sample_rate == 44100, f"{relative_path} uses 44.1 kHz", failures)
    require(min_duration <= duration <= max_duration, f"{relative_path} has the planned duration", failures)
    require(peak >= 12000, f"{relative_path} contains audible non-silent samples", failures)
    require(meaningful_samples > frame_count * 0.20, f"{relative_path} has meaningful waveform content", failures)


def main() -> int:
    failures: list[str] = []

    main_script = read_text("scripts/main.gd")
    player_script = read_text("scripts/player.gd")
    player_health_pips = read_text("scripts/player_health_pips.gd")
    enemy_script = read_text("scripts/enemy.gd")
    spear_script = read_text("scripts/spear.gd")
    runner_script = read_text("scripts/heart_runner.gd")
    pickup_script = read_text("scripts/heart_pickup.gd")
    main_scene = read_text("Main.tscn")
    director = read_text("scripts/encounter_director.gd")
    runner_scene = read_text("HeartRunner.tscn")
    pickup_scene = read_text("HeartPickup.tscn")
    generator = read_text("tools/generate_sfx.py")
    asset_generator = read_text("tools/generate_phase4_assets.py")
    spawn_analysis = read_text("tools/heart_runner_spawn_analysis.py")
    runner_import = read_text("art/sprites/heart_runner.png.import")
    runner_sheet_import = read_text("art/sprites/heart_runner_sheet.png.import")
    pickup_import = read_text("art/sprites/heart_pickup.png.import")
    appear_import = read_text("audio/heart_runner_appear.wav.import")
    pickup_spawn_import = read_text("audio/heart_pickup_spawn.wav.import")
    pickup_collect_import = read_text("audio/heart_pickup_collect.wav.import")
    pickup_expire_import = read_text("audio/heart_pickup_expire.wav.import")
    readme = read_text("README.md")
    tuning = read_text("TUNING.md")
    roadmap = read_text("ROADMAP.md")

    defeated_block = main_script.split("func _on_heart_runner_defeated", 1)[1].split("func _on_heart_runner_escaped", 1)[0]
    escaped_block = main_script.split("func _on_heart_runner_escaped", 1)[1].split("func _on_heart_runner_tree_exited", 1)[0]
    collected_block = main_script.split("func _on_heart_pickup_collected", 1)[1].split("func _on_heart_pickup_expired", 1)[0]
    expired_block = main_script.split("func _on_heart_pickup_expired", 1)[1].split("func _on_heart_pickup_warning_started", 1)[0]

    for relative_path in [
        "HeartRunner.tscn",
        "HeartPickup.tscn",
        "scripts/heart_runner.gd",
        "scripts/heart_pickup.gd",
        "art/sprites/heart_runner.png",
        "art/sprites/heart_runner.png.import",
        "art/sprites/heart_runner_sheet.png",
        "art/sprites/heart_runner_sheet.png.import",
        "art/sprites/heart_pickup.png",
        "art/sprites/heart_pickup.png.import",
        "art/dev/heart_runner_candidates/heart_runner_comparison.png",
        "art/dev/heart_runner_candidates/heart_runner_manifest.json",
        "art/dev/heart_runner_animation/heart_runner_animation_board.png",
        "art/dev/heart_runner_animation/heart_runner_animation_manifest.json",
        "audio/heart_runner_appear.wav",
        "audio/heart_runner_appear.wav.import",
        "audio/heart_runner_alarm.wav",
        "audio/heart_pickup_spawn.wav",
        "audio/heart_pickup_spawn.wav.import",
        "audio/heart_pickup_collect.wav",
        "audio/heart_pickup_collect.wav.import",
        "audio/heart_pickup_expire.wav",
        "audio/heart_pickup_expire.wav.import",
        "tools/heart_runner_spawn_analysis.py",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("class_name HeartRunner" in runner_script and "extends CharacterBody2D" in runner_script, "HeartRunner is a dedicated CharacterBody2D opportunity scene", failures)
    require('add_to_group("spear_hittable")' in runner_script, "HeartRunner joins the explicit spear_hittable group", failures)
    require('add_to_group("heart_runner")' in runner_script, "HeartRunner has its own opportunity group", failures)
    require("enum MotionState" in runner_script and "ENTERING" in runner_script and "WANDERING" in runner_script and "CASUAL_EXIT" in runner_script and "STARTLED" in runner_script and "FLEEING" in runner_script, "HeartRunner uses the approved explicit calm/startled state model", failures)
    require("signal startled_started" in runner_script and "signal state_changed" in runner_script, "HeartRunner exposes narrow startled/state-change seams for focused testing and alarm playback", failures)
    require("receive_combat_hit" in runner_script and "Enemy.HIT_SOURCE_SPEAR" in runner_script, "HeartRunner exposes the narrow combat-hit seam for spear hits", failures)
    require("return Enemy.HitResponse.DAMAGED" in runner_script, "HeartRunner spear hits use DAMAGED so the spear keeps flying", failures)
    require(
        "tracked_spear" in runner_script
        and "_on_tracked_spear_state_changed" in runner_script
        and "armed_threat_active = new_state == Spear.State.HELD" in runner_script,
        "HeartRunner tracks a narrow armed-threat state from the real spear HELD transition without broad polling",
        failures,
    )
    require("calm_move_speed := 70.0" in runner_script, "HeartRunner calm strolling speed is 70", failures)
    require("entry_distance := 20.0" in runner_script and "entry_min_duration := 0.45" in runner_script, "HeartRunner requires visible entry before reacting", failures)
    require("wander_duration := 8.0" in runner_script, "HeartRunner calm wandering lasts 8 seconds before casual exit", failures)
    require("startled_duration := 0.40" in runner_script, "HeartRunner startled hop duration is 0.40 seconds", failures)
    require(
        "heart_runner_startle_range_margin := 16.0" in runner_script
        and "func get_startle_radius()" in runner_script
        and "tracked_spear.max_range" in runner_script,
        "HeartRunner startled radius is derived from the live spear range minus the configured margin",
        failures,
    )
    require(
        "func is_inside_startle_radius()" in runner_script
        and "_can_enter_startled_from_proximity" in runner_script
        and "_try_enter_startled_from_proximity" in runner_script,
        "HeartRunner keeps the proximity-gated panic trigger in narrow explicit helpers",
        failures,
    )
    require(
        "_try_enter_startled_from_proximity()" in runner_script and "MotionState.CASUAL_EXIT" in runner_script,
        "HeartRunner can panic from wandering or casual exit only after entering the derived threat radius",
        failures,
    )
    require(
        "ANIMATION_ROW_CALM := 0" in runner_script
        and "ANIMATION_ROW_STARTLED := 1" in runner_script
        and "ANIMATION_ROW_FLEE := 2" in runner_script
        and "CALM_FRAME_DURATION := 0.18" in runner_script
        and "FLEE_FRAME_DURATION := 0.10" in runner_script,
        "HeartRunner animation rows and calm/panic cadences are defined explicitly in the live script",
        failures,
    )
    require(
        "sprite.frame_coords = _get_animation_frame_coords()" in runner_script
        and "func get_current_animation_frame_coords()" in runner_script,
        "HeartRunner drives live presentation through explicit state-based sprite-sheet frame selection",
        failures,
    )
    require("_has_crossed_exit_plane" in runner_script and "exit_edge" in runner_script and "exit_threshold" in runner_script, "HeartRunner cleanup uses its assigned exit plane", failures)
    require(
        "_clamp_inside_play_rect_except_exit_edge" in runner_script
        and "FAILSAFE_EXTRA_TIME" in runner_script
        and "_configure_failsafe_lifetime" in runner_script,
        "HeartRunner keeps only non-exit boundary clamps and includes a bounded failsafe lifecycle guard",
        failures,
    )
    require("apply_authored_displacement" in runner_script and "debug_force_locked_exit" in runner_script, "HeartRunner preserves authored displacement support and narrow audit hooks for exit cleanup coverage", failures)
    require("collision_layer = 2" in runner_scene and "collision_mask = 0" in runner_scene, "HeartRunner is spear-detectable but has no ordinary collision mask", failures)
    require(
        'path="res://art/sprites/heart_runner_sheet.png"' in runner_scene
        and "hframes = 4" in runner_scene
        and "vframes = 3" in runner_scene,
        "HeartRunner scene uses the live 4x3 sprite sheet for calm, startled, and flee presentation",
        failures,
    )
    require("score_value = 1" in runner_script or "score_value := 1" in runner_script, "HeartRunner defeat score is 1", failures)
    require(
        ("body_radius := 6.0" in runner_script or "body_radius = 6.0" in runner_scene)
        and "radius = 6.0" in runner_scene,
        "HeartRunner body and collision radii start at 6",
        failures,
    )

    require("class_name HeartPickup" in pickup_script and "extends Area2D" in pickup_script, "HeartPickup is a dedicated Area2D pickup scene", failures)
    require("warning_duration := 1.5" in pickup_script or "warning_duration = 1.5" in pickup_scene, "Heart pickup warning duration is 1.5 seconds", failures)
    require("_clamp_inside_play_rect" in pickup_script and "pickup_radius" in pickup_script, "HeartPickup clamps itself inside the playable arena by pickup radius", failures)
    require("warning_started.emit()" in pickup_script and "destroy_pickup(DESTROY_REASON_EXPIRED)" in pickup_script, "HeartPickup has a restrained final warning before expiration", failures)
    require("collision_layer = 16" in pickup_scene and "collision_mask = 1" in pickup_scene, "HeartPickup uses the pickup layer and only masks the player", failures)
    require("radius = 10.0" in pickup_scene, "HeartPickup collision radius starts at 10", failures)

    require('add_to_group("spear_hittable")' in enemy_script, "Base hostile enemies also use the explicit spear_hittable group", failures)
    require("_is_valid_spear_hittable_body" in spear_script and 'body.is_in_group("spear_hittable")' in spear_script and 'body.has_method("receive_combat_hit")' in spear_script, "Spear only targets explicit spear-hittable combat bodies", failures)

    require("try_collect_heart_runner_pickup" in player_script, "Player has a narrow Heart Runner pickup seam", failures)
    require("health = mini(health + 1, max_health + 1)" in player_script, "Heart pickup heals by one up to a temporary fourth point", failures)
    require("health_pips.set_health_values(health, max_health, _get_bonus_health_count())" in player_script, "Player forwards bonus-heart state to the health pips", failures)
    require("bonus_pip_count" in player_health_pips and "bonus_vertical_offset" in player_health_pips, "Player health pips render a dedicated bonus pip instead of shrinking the HUD", failures)

    require('const HeartRunnerScene := preload("res://HeartRunner.tscn")' in main_script and 'const HeartPickupScene := preload("res://HeartPickup.tscn")' in main_script, "Main preloads the Heart Runner and Heart Pickup scenes", failures)
    require("DEBUG_HEART_RUNNER_SPAWN_ENABLED := true" in main_script and "KEY_4" in main_script and "_debug_spawn_heart_runner" in main_script, "Heart Runner debug spawn uses key 4", failures)
    require("heart_runner_unlock_time := 20.0" in main_script, "Heart Runner unlock time is configured in Main", failures)
    require("heart_runner_roll_interval_min := 8.0" in main_script and "heart_runner_roll_interval_max := 12.0" in main_script, "Heart Runner roll interval is configured in Main", failures)
    require("heart_runner_health_3_spawn_chance := 0.01" in main_script and "heart_runner_health_2_spawn_chance := 0.04" in main_script and "heart_runner_health_1_spawn_chance := 0.15" in main_script, "Heart Runner health-based spawn chances match the approved live values", failures)
    require("heart_runner_one_health_grace_duration := 90.0" in main_script and "heart_runner_post_resolution_cooldown := 18.0" in main_script and "heart_pickup_lifetime := 7.0" in main_script and "heart_pickup_warning_duration := 1.5" in main_script, "Heart Runner cooldown, pickup timing, and one-health grace duration live in Main", failures)
    require("active_heart_runner: HeartRunner" in main_script and "active_heart_pickup: HeartPickup" in main_script, "Main tracks one active Heart Runner and one active Heart Pickup", failures)
    require("if active_heart_runner != null or active_heart_pickup != null:" in main_script, "Heart Runner and pickup share a strict one-active opportunity limit", failures)
    require("_find_safe_heart_runner_entry_position" in main_script and '"valid": false' in main_script, "Heart Runner entry search defers instead of using an unsafe fallback", failures)
    require("debug_set_heart_runner_roll_sequence" in main_script and "debug_set_heart_runner_interval_sequence" in main_script, "Heart Runner opportunity rolls have deterministic audit hooks", failures)
    require("debug_set_heart_runner_one_health_grace_state" in main_script and "_update_heart_runner_one_health_grace" in main_script and "_is_heart_runner_one_health_grace_ready_for_forced_spawn" in main_script, "Heart Runner one-health grace uses explicit readable live state and audit hooks", failures)
    require("_consume_heart_runner_one_health_grace_after_organic_spawn" in main_script and "_reset_heart_runner_one_health_grace" in main_script, "Heart Runner one-health grace resets only through explicit organic-spawn and state-reset seams", failures)
    require(
        "DEFAULT_TRIALS = 100_000" in spawn_analysis
        and "DEFAULT_SEED = 424_242" in spawn_analysis
        and "Candidate A - previous live baseline" in spawn_analysis
        and "Candidate D - approved live configuration" in spawn_analysis
        and "build_live_opportunity_config" in spawn_analysis,
        "Heart Runner deterministic spawn analysis is reproducible with fixed seeds and marks the approved live candidate explicitly",
        failures,
    )
    require("OpportunityContainer" in main_scene and "OpportunityTimer" in main_scene, "Main scene contains dedicated opportunity nodes", failures)
    require("HeartRunnerAppearPlayer" in main_scene and "HeartRunnerAlarmPlayer" in main_scene and "HeartPickupSpawnPlayer" in main_scene and "HeartPickupCollectPlayer" in main_scene and "HeartPickupExpirePlayer" in main_scene, "Main scene contains Heart Runner audio players", failures)
    require('path="res://audio/heart_runner_appear.wav"' in main_scene and 'path="res://audio/heart_runner_alarm.wav"' in main_scene and 'path="res://audio/heart_pickup_spawn.wav"' in main_scene and 'path="res://audio/heart_pickup_collect.wav"' in main_scene and 'path="res://audio/heart_pickup_expire.wav"' in main_scene, "Heart Runner and pickup streams are assigned explicitly in Main", failures)
    require('bus = &"SFX"' in main_scene, "Heart Runner audio routes through the SFX bus", failures)

    require("_start_heart_runner_resolution_cooldown()" not in defeated_block, "Defeating a Runner does not stamp the opportunity cooldown before pickup resolution", failures)
    require("_start_heart_runner_resolution_cooldown()" in escaped_block, "Runner escape applies the opportunity cooldown", failures)
    require("_start_heart_runner_resolution_cooldown()" in collected_block and "_start_heart_runner_resolution_cooldown()" in expired_block, "Pickup collection or expiration each apply the cooldown exactly once", failures)
    require("spawned_by_debug" in defeated_block and "spawned_by_debug" in escaped_block and "spawned_by_debug" in collected_block and "spawned_by_debug" in expired_block, "Debug-spawned Runner resolution stays separate from organic cooldown bookkeeping", failures)

    require("HEART_RUNNER" not in director, "EncounterDirector does not treat Heart Runner as a hostile enemy kind", failures)

    require("generate_heart_runner_appear" in generator and "generate_heart_runner_alarm" in generator and "generate_heart_pickup_spawn" in generator and "generate_heart_pickup_collect" in generator and "generate_heart_pickup_expire" in generator, "Heart Runner audio is reproducible locally, including the startled alarm cue", failures)
    require("draw_heart_runner" in asset_generator and "draw_heart_runner_animation_sheet" in asset_generator and "draw_heart_pickup" in asset_generator and "generate_heart_runner_candidate_assets" in asset_generator and "generate_heart_runner_animation_preview" in asset_generator, "Heart Runner visuals, live animation sheet, comparison outputs, and approval-board outputs are reproducible locally", failures)
    require("--generate-dev-heart-runner-concepts" in asset_generator, "Heart Runner concept generation remains behind an explicit workflow flag", failures)
    require("--generate-dev-heart-runner-animations" in asset_generator, "Heart Runner animation preview generation remains behind an explicit approval-gate workflow flag", failures)
    require(
        "0.40s startle" in asset_generator
        and "calm -> startled hop -> landing beat -> panic sprint" in asset_generator,
        "Heart Runner animation preview tooling documents the slowed hop timing and transition strip at the approval gate",
        failures,
    )

    for import_text, label in [
        (runner_import, "Heart Runner sprite import disables mipmaps"),
        (runner_sheet_import, "Heart Runner live animation sheet import disables mipmaps"),
        (pickup_import, "Heart Pickup sprite import disables mipmaps"),
    ]:
        require('mipmaps/generate=false' in import_text, label, failures)
    for import_text, label in [
        (appear_import, "Heart Runner appear audio import uses the WAV importer"),
        (pickup_spawn_import, "Heart pickup spawn audio import uses the WAV importer"),
        (pickup_collect_import, "Heart pickup collect audio import uses the WAV importer"),
        (pickup_expire_import, "Heart pickup expire audio import uses the WAV importer"),
    ]:
        require('importer="wav"' in import_text, label, failures)

    runner_image = Image.open(ROOT / "art/sprites/heart_runner.png")
    runner_sheet_image = Image.open(ROOT / "art/sprites/heart_runner_sheet.png")
    pickup_image = Image.open(ROOT / "art/sprites/heart_pickup.png")
    comparison_image = Image.open(ROOT / "art/dev/heart_runner_candidates/heart_runner_comparison.png")
    require(runner_image.size == (16, 16), "Heart Runner base silhouette uses the approved 16x16 canvas", failures)
    require(runner_sheet_image.size == (64, 48), "Heart Runner live animation sheet uses the approved 4x3 16x16 frame layout", failures)
    require(pickup_image.size == (10, 10), "Heart pickup sprite uses the approved 10x10 canvas", failures)
    require(comparison_image.size == (384, 216), "Heart Runner comparison board renders at native arena scale", failures)

    manifest = json.loads((ROOT / "art/dev/heart_runner_candidates/heart_runner_manifest.json").read_text(encoding="utf-8"))
    require(len(manifest.get("candidates", [])) == 3, "Heart Runner manifest records three concept candidates", failures)
    require(manifest.get("comparison_path") == str(ROOT / "art/dev/heart_runner_candidates/heart_runner_comparison.png"), "Heart Runner manifest points to the comparison board", failures)
    require(manifest.get("active_reference_path") == str(ROOT / "art/sprites/heart_runner.png"), "Heart Runner concept manifest points to the approved base silhouette", failures)
    require(manifest.get("pickup_reference_path") == str(ROOT / "art/sprites/heart_pickup.png"), "Heart Runner manifest points to the pickup sprite", failures)
    animation_manifest = json.loads((ROOT / "art/dev/heart_runner_animation/heart_runner_animation_manifest.json").read_text(encoding="utf-8"))
    require(animation_manifest.get("board_path") == str(ROOT / "art/dev/heart_runner_animation/heart_runner_animation_board.png"), "Heart Runner animation manifest points to the approval-board output", failures)
    require(animation_manifest.get("active_reference_path") == str(ROOT / "art/sprites/heart_runner_sheet.png"), "Heart Runner animation manifest points to the live animation sheet", failures)
    require(animation_manifest.get("base_reference_path") == str(ROOT / "art/sprites/heart_runner.png"), "Heart Runner animation manifest still records the approved base silhouette reference", failures)
    require(animation_manifest.get("sequence_count") == 3, "Heart Runner animation manifest records the three required preview treatments", failures)
    require(set(animation_manifest.get("sequences", {}).keys()) == {"casual_strut", "panicked_sprint", "startled_hop"}, "Heart Runner animation manifest names the casual, panic, and startled preview sets", failures)

    require("Heart Runner" in readme and "Heart Runner" in tuning and "Heart Runner" in roadmap, "README, TUNING, and ROADMAP all document Heart Runner", failures)
    require("debug-spawns one Heart Runner" in readme, "README documents the key 4 debug spawn", failures)
    require("future heart runner" not in roadmap.lower(), "ROADMAP no longer describes Heart Runner as deferred future work", failures)
    require("originally assigned opposite-edge exit plane" not in readme and "originally assigned opposite-edge exit plane" not in roadmap and "originally assigned opposite-edge exit plane" not in tuning, "Heart Runner docs no longer describe a permanently assigned opposite-edge cleanup route", failures)
    require("crosses the arena from one safe edge to the opposite side" not in readme, "README no longer claims the Heart Runner always crosses directly to the opposite side", failures)
    require("currently locked route's assigned exit plane" in readme and "currently locked casual or panic route" in roadmap and "Approved panic flee speed." in tuning, "Heart Runner docs match the final locked-route cleanup and panic-speed wording", failures)
    require("15%" in readme and "90s" in readme and "guarantees an opportunity, not automatic healing" in readme, "README documents the approved one-health chance and grace behavior", failures)
    require("healing above one resets it" in readme.lower() and "debug spawning does not affect organic grace" in readme.lower(), "README documents the one-health grace reset and debug-isolation rules", failures)
    require("heart_runner_one_health_grace_duration" in tuning and "`heart_runner_health_1_spawn_chance` | `0.15`" in tuning and "`heart_runner_one_health_grace_duration` | `90.0s`" in tuning, "TUNING documents the approved live one-health chance and grace duration", failures)

    audit_wav("audio/heart_runner_appear.wav", 0.12, 0.18, failures)
    audit_wav("audio/heart_runner_alarm.wav", 0.10, 0.14, failures)
    audit_wav("audio/heart_pickup_spawn.wav", 0.14, 0.20, failures)
    audit_wav("audio/heart_pickup_collect.wav", 0.16, 0.22, failures)
    audit_wav("audio/heart_pickup_expire.wav", 0.10, 0.14, failures)

    if failures:
        print(f"\nHeart Runner audit failed with {len(failures)} issue(s).")
        return 1

    print("\nHeart Runner audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
