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


def require_wav_metadata(relative_path: str, failures: list[str]) -> None:
    path = ROOT / relative_path
    with wave.open(str(path), "rb") as wav_file:
        sample_rate = wav_file.getframerate()
        channel_count = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        frame_count = wav_file.getnframes()
        audio_bytes = wav_file.readframes(frame_count)

    peak = 0
    for index in range(0, len(audio_bytes), 2):
        sample = int.from_bytes(audio_bytes[index : index + 2], byteorder="little", signed=True)
        peak = max(peak, abs(sample))

    require(sample_rate == 44100, f"{relative_path} uses 44.1kHz sample rate", failures)
    require(channel_count == 1, f"{relative_path} is mono", failures)
    require(sample_width == 2, f"{relative_path} uses 16-bit PCM", failures)
    require(peak > 2000, f"{relative_path} contains meaningful non-silent audio", failures)


def main() -> int:
    failures: list[str] = []

    prowler = read_text("scripts/prowler_enemy.gd")
    prowler_scene = read_text("ProwlerEnemy.tscn")
    main_script = read_text("scripts/main.gd")
    main_scene = read_text("Main.tscn")
    director = read_text("scripts/encounter_director.gd")
    generator = read_text("tools/generate_phase4_assets.py")
    sfx_generator = read_text("tools/generate_sfx.py")
    readme = read_text("README.md")
    roadmap = read_text("ROADMAP.md")
    tuning = read_text("TUNING.md")
    sprite_import = read_text("art/sprites/prowler_enemy.png.import")
    sheet_import = read_text("art/sprites/prowler_enemy_sheet.png.import")
    alert_import = read_text("audio/prowler_alert.wav.import")
    hit_import = read_text("audio/prowler_pounce_hit.wav.import")

    for relative_path in [
        "ProwlerEnemy.tscn",
        "scripts/prowler_enemy.gd",
        "art/sprites/prowler_enemy.png",
        "art/sprites/prowler_enemy.png.import",
        "art/sprites/prowler_enemy_sheet.png",
        "art/sprites/prowler_enemy_sheet.png.import",
        "art/dev/prowler_candidates/prowler_comparison.png",
        "art/dev/prowler_candidates/prowler_behavior_board.png",
        "art/dev/prowler_candidates/prowler_manifest.json",
        "audio/prowler_alert.wav",
        "audio/prowler_alert.wav.import",
        "audio/prowler_pounce_hit.wav",
        "audio/prowler_pounce_hit.wav.import",
        "tools/prowler_enemy_audit.py",
        "tools/ProwlerEnemyRuntimeAudit.tscn",
        "tools/prowler_enemy_runtime_audit.gd",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("class_name ProwlerEnemy" in prowler and "extends Enemy" in prowler, "ProwlerEnemy extends Enemy with a class name", failures)
    require("signal alert_started" in prowler and "signal hunt_pounce_hit" in prowler, "Prowler exposes the narrow alert and authored-hit signals", failures)
    require("enum ProwlerState" in prowler and "DEFENSIVE_WINDUP" in prowler and "POUNCE_WINDUP" in prowler and "WARY_UNARMED" in prowler, "Prowler uses the revised multi-state behavior model", failures)
    require("enum PounceMode" in prowler and "DEFENSIVE" in prowler and "HUNT" in prowler, "Prowler differentiates defensive and hunting pounces", failures)
    require("stalk_speed_scale := 0.82" in prowler and "hunt_speed_scale := 1.48" in prowler, "Prowler keeps the approved stalking and hunting speed defaults", failures)
    require("unarmed_alert_delay := 0.28" in prowler, "Prowler alert delay is the approved 0.28 seconds", failures)
    require("defensive_trigger_radius := 26.0" in prowler and "defensive_windup_duration := 0.16" in prowler and "defensive_pounce_distance := 42.0" in prowler and "defensive_retreat_distance := 92.0" in prowler and "defensive_retrigger_cooldown := 1.10" in prowler, "Defensive armed-state pounce tuning is present", failures)
    require("hunt_pounce_trigger_distance := 36.0" in prowler and "hunt_pounce_windup_duration := 0.18" in prowler and "hunt_pounce_distance := 48.0" in prowler and "hunt_pounce_duration := 0.18" in prowler, "Hunting pounce tuning is present", failures)
    require("hunt_player_knockback_distance := 28.0" in prowler and "hunt_player_knockback_duration := 0.18" in prowler and "hunt_prowler_recoil_distance := 26.0" in prowler and "hunt_prowler_recoil_duration := 0.16" in prowler and "hunt_hit_stop_duration := 0.06" in prowler, "Hunting pounce impact tuning is present", failures)
    require("miss_skid_duration := 0.18" in prowler and "miss_stun_duration := 0.42" in prowler, "Miss skid and stun tuning is present", failures)
    require("hunt_pounce_available" in prowler and "new_is_held == tracked_spear_is_held" in prowler, "Prowler keeps one hunting pounce per unarmed window and ignores repeated spear-state observations", failures)
    require("set_tracked_spear" in prowler and "_on_tracked_spear_state_changed" in prowler and "_connect_spear_state_signal" in prowler, "Prowler tracks the authoritative spear state through the live signal seam", failures)
    require("_get_player_segment_hit_position" in prowler and "_get_closest_point_on_segment" in prowler, "Prowler uses a swept segment hit test for committed pounces", failures)
    require("try_start_forced_movement" in prowler and "hunt_pounce_hit.emit" in prowler, "Prowler applies knockback through Player and requests authored hit stop through Main", failures)
    require('func _try_contact_damage()' in prowler and "ProwlerState.STALK, ProwlerState.HUNT, ProwlerState.WARY_UNARMED" in prowler, "Ordinary contact damage is limited to locomotion states so authored attacks do not stack damage", failures)
    require("tracked_spear.global_position" not in prowler and "try_throw" not in prowler and "apply_landed_shockwave_nudge" not in prowler, "Prowler reads spear state only and does not manipulate the spear object", failures)

    require('path="res://art/sprites/prowler_enemy_sheet.png"' in prowler_scene, "Prowler scene uses the live animation sheet", failures)
    require("hframes = 4" in prowler_scene and "vframes = 5" in prowler_scene, "Prowler scene configures the approved 4x5 live sheet layout", failures)
    require("score_value = 2" in prowler_scene, "Prowler score is 2", failures)
    require("body_radius = 7.0" in prowler_scene and "radius = 7.0" in prowler_scene, "Prowler body and collision radii remain 7.0px", failures)
    require("separation_distance = 20.0" in prowler_scene and "separation_strength = 50.0" in prowler_scene, "Prowler keeps the approved separation defaults", failures)

    require('const ProwlerScene := preload("res://ProwlerEnemy.tscn")' in main_script, "Main preloads ProwlerEnemy", failures)
    require("DEBUG_PROWLER_SPAWN_ENABLED := true" in main_script and "_debug_spawn_prowler_enemy" in main_script and "KEY_5" in main_script, "Prowler debug spawn uses key 5", failures)
    require("prowler_unlock_time := 78.0" in main_script and "prowler_intro_target_time_min := 78.0" in main_script and "prowler_intro_target_time_max := 88.0" in main_script, "Prowler intro timing remains unchanged", failures)
    require("prowler_spawn_chance_at_unlock := 0.03" in main_script and "prowler_spawn_chance_growth_per_second := 0.00030" in main_script and "maximum_prowler_spawn_chance := 0.08" in main_script, "Prowler ambient weights remain unchanged", failures)
    require("enemy.has_signal(\"alert_started\")" in main_script and "enemy.has_signal(\"hunt_pounce_hit\")" in main_script, "Main connects the revised Prowler authored-event signals", failures)
    require("_on_prowler_alert_started" in main_script and "_on_prowler_hunt_pounce_hit" in main_script and "_try_start_authored_hit_stop" in main_script, "Main owns the Prowler alert audio and authored hit-stop path", failures)
    require("ProwlerAlertPlayer" in main_scene and "ProwlerPounceHitPlayer" in main_scene, "Main scene defines dedicated Prowler audio players", failures)

    require("PROWLER" in director, "EncounterDirector defines Prowler as its own hostile kind", failures)
    require("prowler_hostile_cap := 1" in director, "EncounterDirector keeps the dedicated Prowler cap at 1", failures)
    require("get_prowler_hostile_count()" in director and "get_prowler_hostile_count() < prowler_hostile_cap" in director, "EncounterDirector enforces the dedicated Prowler cap", failures)
    require("EnemyKind.PROWLER" not in director.split("func _build_wave_definitions", 1)[1], "Authored waves still contain no Prowler steps", failures)

    require("draw_prowler_animation_sheet" in generator and "draw_prowler_behavior_board" in generator and "generate_prowler_candidate_assets" in generator, "Prowler live sheet and behavior board are reproducible locally", failures)
    require("draw_prowler_enemy" in generator and "build_prowler_variant_specs" in generator and "--generate-dev-prowler-concepts" in generator, "Prowler concept generation remains explicit and local", failures)
    require("generate_prowler_alert" in sfx_generator and "generate_prowler_pounce_hit" in sfx_generator, "New Prowler SFX are generated locally", failures)
    require("prowler_alert.wav" in sfx_generator and "prowler_pounce_hit.wav" in sfx_generator, "Generator writes the expected Prowler audio filenames", failures)

    require("mipmaps/generate=false" in sprite_import, "Prowler base sprite import disables mipmaps", failures)
    require("mipmaps/generate=false" in sheet_import, "Prowler animation sheet import disables mipmaps", failures)
    require(
        'importer="wav"' in alert_import
        and 'type="AudioStreamWAV"' in alert_import
        and 'importer="wav"' in hit_import
        and 'type="AudioStreamWAV"' in hit_import,
        "Prowler audio files imported into Godot",
        failures,
    )

    prowler_image = Image.open(ROOT / "art/sprites/prowler_enemy.png")
    sheet_image = Image.open(ROOT / "art/sprites/prowler_enemy_sheet.png")
    comparison_image = Image.open(ROOT / "art/dev/prowler_candidates/prowler_comparison.png")
    behavior_board = Image.open(ROOT / "art/dev/prowler_candidates/prowler_behavior_board.png")
    require(prowler_image.size == (16, 16), "Prowler live base sprite uses a 16x16 canvas", failures)
    require(sheet_image.size == (64, 80), "Prowler live animation sheet uses the approved 64x80 layout", failures)
    require(comparison_image.size == (384, 216), "Prowler comparison board renders at native arena scale", failures)
    require(behavior_board.size == (384, 216), "Prowler behavior board renders at native arena scale", failures)

    manifest = json.loads((ROOT / "art/dev/prowler_candidates/prowler_manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("active_reference_path") == str(ROOT / "art/sprites/prowler_enemy.png"), "Prowler manifest points to the live base sprite", failures)
    require(manifest.get("active_sheet_path") == str(ROOT / "art/sprites/prowler_enemy_sheet.png"), "Prowler manifest points to the live animation sheet", failures)
    require(manifest.get("selected_concept") == "Moss Lynx", "Prowler manifest records the selected Moss Lynx concept", failures)
    require(len(manifest.get("candidates", [])) == 3, "Prowler manifest still records three distinct candidate concepts", failures)

    require_wav_metadata("audio/prowler_alert.wav", failures)
    require_wav_metadata("audio/prowler_pounce_hit.wav", failures)

    require("Phase 4.5" in readme and "Phase 4.5" in roadmap, "README and ROADMAP document Phase 4.5", failures)
    require("Prowler" in readme and "Prowler" in roadmap and "Prowler" in tuning, "Docs mention the implemented Prowler phase", failures)

    if failures:
        print(f"\nProwler enemy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nProwler enemy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
