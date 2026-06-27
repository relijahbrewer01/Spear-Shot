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


def get_node_block(scene_text: str, node_name: str) -> str:
    marker = f'[node name="{node_name}"'
    start = scene_text.find(marker)
    if start == -1:
        return ""
    next_start = scene_text.find("\n[node name=", start + len(marker))
    if next_start == -1:
        return scene_text[start:]
    return scene_text[start:next_start]


def require_wav_metadata(
    relative_path: str,
    failures: list[str],
    duration_min: float,
    duration_max: float,
) -> None:
    path = ROOT / relative_path
    with wave.open(str(path), "rb") as wav_file:
        sample_rate = wav_file.getframerate()
        channel_count = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        frame_count = wav_file.getnframes()
        duration = frame_count / float(sample_rate)
        audio_bytes = wav_file.readframes(frame_count)

    peak = 0
    for index in range(0, len(audio_bytes), 2):
        sample = int.from_bytes(audio_bytes[index : index + 2], byteorder="little", signed=True)
        peak = max(peak, abs(sample))

    require(sample_rate == 44100, f"{relative_path} uses 44.1kHz sample rate", failures)
    require(channel_count == 1, f"{relative_path} is mono", failures)
    require(sample_width == 2, f"{relative_path} uses 16-bit PCM", failures)
    require(duration_min <= duration <= duration_max, f"{relative_path} duration stays within the approved range", failures)
    require(peak > 6000, f"{relative_path} contains meaningful non-silent audio", failures)


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
    defensive_import = read_text("audio/prowler_defensive_attack.wav.import")
    hit_import = read_text("audio/prowler_pounce_hit.wav.import")

    for relative_path in [
        "ProwlerEnemy.tscn",
        "scripts/prowler_enemy.gd",
        "art/sprites/prowler_enemy.png",
        "art/sprites/prowler_enemy.png.import",
        "art/sprites/prowler_enemy_sheet.png",
        "art/sprites/prowler_enemy_sheet.png.import",
        "art/dev/prowler_candidates/prowler_variant_1.png",
        "art/dev/prowler_candidates/prowler_variant_2.png",
        "art/dev/prowler_candidates/prowler_variant_3.png",
        "art/dev/prowler_candidates/prowler_comparison.png",
        "art/dev/prowler_candidates/prowler_behavior_board.png",
        "art/dev/prowler_candidates/prowler_manifest.json",
        "audio/prowler_alert.wav",
        "audio/prowler_alert.wav.import",
        "audio/prowler_defensive_attack.wav",
        "audio/prowler_defensive_attack.wav.import",
        "audio/prowler_pounce_hit.wav",
        "audio/prowler_pounce_hit.wav.import",
        "audio/dev/prowler_candidates/prowler_audio_manifest.json",
        "audio/dev/prowler_candidates/prowler_alert_candidate_1.wav",
        "audio/dev/prowler_candidates/prowler_alert_candidate_2.wav",
        "audio/dev/prowler_candidates/prowler_alert_candidate_3.wav",
        "audio/dev/prowler_candidates/prowler_defensive_candidate_1.wav",
        "audio/dev/prowler_candidates/prowler_defensive_candidate_2.wav",
        "audio/dev/prowler_candidates/prowler_defensive_candidate_3.wav",
        "audio/dev/prowler_candidates/prowler_impact_candidate_1.wav",
        "audio/dev/prowler_candidates/prowler_impact_candidate_2.wav",
        "audio/dev/prowler_candidates/prowler_impact_candidate_3.wav",
        "tools/prowler_enemy_audit.py",
        "tools/ProwlerEnemyRuntimeAudit.tscn",
        "tools/prowler_enemy_runtime_audit.gd",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("class_name ProwlerEnemy" in prowler and "extends Enemy" in prowler, "ProwlerEnemy extends Enemy with a class name", failures)
    require(
        "signal alert_started" in prowler
        and "signal alert_voice_requested" in prowler
        and "signal defensive_pounce_committed" in prowler
        and "signal hunt_pounce_hit" in prowler,
        "Prowler exposes the alert, defensive-launch, and impact audio seams",
        failures,
    )
    require("enum ProwlerState" in prowler and "DEFENSIVE_WINDUP" in prowler and "WARY_UNARMED" in prowler, "Prowler keeps the approved state model", failures)
    require("stalk_speed_scale := 0.82" in prowler and "hunt_speed_scale := 1.48" in prowler, "Prowler preserves the approved stalking and hunting speed defaults", failures)
    require("unarmed_alert_delay := 0.28" in prowler and "alert_voice_delay := 0.06" in prowler, "Prowler keeps the approved alert timing and post-throw audio offset", failures)
    require("defensive_trigger_radius := 26.0" in prowler and "defensive_windup_duration := 0.16" in prowler and "defensive_pounce_distance := 42.0" in prowler and "defensive_retrigger_cooldown := 1.10" in prowler, "Prowler preserves the approved defensive pounce tuning", failures)
    require("hunt_pounce_trigger_distance := 36.0" in prowler and "hunt_pounce_distance := 48.0" in prowler and "miss_stun_duration := 0.42" in prowler, "Prowler preserves the approved hunting pounce and miss tuning", failures)
    require("new_is_held == tracked_spear_is_held" in prowler and "set_tracked_spear" in prowler and "_connect_spear_state_signal" in prowler, "Prowler still keys behavior off the authoritative spear state seam", failures)
    require("tracked_spear.global_position" not in prowler and "try_throw" not in prowler and "apply_landed_shockwave_nudge" not in prowler, "Prowler still reads spear state only and does not manipulate the spear object", failures)

    require('path="res://art/sprites/prowler_enemy_sheet.png"' in prowler_scene, "Prowler scene uses the live animation sheet", failures)
    require("hframes = 4" in prowler_scene and "vframes = 6" in prowler_scene, "Prowler scene configures the approved 4x6 live sheet layout", failures)
    require("score_value = 2" in prowler_scene, "Prowler score remains 2", failures)
    require("body_radius = 7.0" in prowler_scene and "radius = 7.0" in prowler_scene, "Prowler body and collision radii remain 7.0px", failures)
    require("separation_distance = 20.0" in prowler_scene and "separation_strength = 50.0" in prowler_scene, "Prowler keeps the approved separation defaults", failures)

    require('const ProwlerScene := preload("res://ProwlerEnemy.tscn")' in main_script, "Main preloads ProwlerEnemy", failures)
    require("DEBUG_PROWLER_SPAWN_ENABLED := true" in main_script and "_debug_spawn_prowler_enemy" in main_script and "KEY_5" in main_script, "Prowler debug spawn stays on key 5", failures)
    require("prowler_unlock_time := 78.0" in main_script and "prowler_intro_target_time_min := 78.0" in main_script and "prowler_intro_target_time_max := 88.0" in main_script, "Prowler intro timing remains unchanged", failures)
    require("prowler_spawn_chance_at_unlock := 0.03" in main_script and "prowler_spawn_chance_growth_per_second := 0.00030" in main_script and "maximum_prowler_spawn_chance := 0.08" in main_script, "Prowler ambient weights remain unchanged", failures)
    require("enemy.has_signal(\"alert_voice_requested\")" in main_script and "enemy.has_signal(\"defensive_pounce_committed\")" in main_script and "enemy.has_signal(\"hunt_pounce_hit\")" in main_script, "Main connects the Prowler audio gameplay hooks", failures)
    require("_on_prowler_alert_voice_requested" in main_script and "_on_prowler_defensive_pounce_committed" in main_script and "_on_prowler_hunt_pounce_hit" in main_script, "Main owns the Prowler alert, defensive, and impact playback handlers", failures)
    require("debug_get_prowler_audio_metrics" in main_script and "debug_reset_prowler_audio_metrics" in main_script, "Main exposes Prowler audio metrics for runtime validation", failures)

    alert_block = get_node_block(main_scene, "ProwlerAlertPlayer")
    defensive_block = get_node_block(main_scene, "ProwlerDefensiveAttackPlayer")
    hit_block = get_node_block(main_scene, "ProwlerPounceHitPlayer")
    require('path="res://audio/prowler_alert.wav"' in main_scene and 'path="res://audio/prowler_defensive_attack.wav"' in main_scene and 'path="res://audio/prowler_pounce_hit.wav"' in main_scene, "Main scene references the three live Prowler audio assets", failures)
    require('bus = &"SFX"' in alert_block and 'bus = &"SFX"' in defensive_block and 'bus = &"SFX"' in hit_block, "All Prowler audio players route through the SFX bus", failures)
    require("volume_db = -4.0" in alert_block and "volume_db = -4.5" in defensive_block and "volume_db = -5.0" in hit_block, "Prowler audio players keep the approved mix volumes", failures)

    require("PROWLER" in director, "EncounterDirector defines Prowler as its own hostile kind", failures)
    require("prowler_hostile_cap := 1" in director, "EncounterDirector keeps the dedicated Prowler cap at 1", failures)
    require("get_prowler_hostile_count()" in director and "get_prowler_hostile_count() < prowler_hostile_cap" in director, "EncounterDirector enforces the dedicated Prowler cap", failures)
    require("EnemyKind.PROWLER" not in director.split("func _build_wave_definitions", 1)[1], "Authored waves still contain no Prowler steps", failures)

    require("PROWLER_CANVAS_SIZE = (20, 18)" in generator, "Prowler generator records the approved 20x18 canvas", failures)
    require('PROWLER_ANIMATION_SHEET_ROWS = ["stalk", "defensive", "alert", "hunt", "hunt_pounce", "recovery"]' in generator, "Prowler generator records the approved 4x6 row contract", failures)
    require("Bonejaw Prowler" in generator and "Bristlemane Prowler" in generator and "Hollow Hound" in generator, "Prowler generator records the three stylized candidate concepts", failures)
    require('"selected_concept": "Bonejaw Prowler"' in generator, "Prowler generator records the selected Bonejaw Prowler concept", failures)
    require("draw_replacement_prowler_comparison" in generator and "draw_replacement_prowler_behavior_board" in generator, "Prowler comparison and behavior boards are reproduced locally from the stylized review pipeline", failures)

    require("PROWLER_AUDIO_DEV_DIR" in sfx_generator and "build_prowler_audio_candidate_specs" in sfx_generator, "Prowler audio generator keeps the nine review candidates locally", failures)
    require("generate_prowler_alert" in sfx_generator and "generate_prowler_defensive_attack" in sfx_generator and "generate_prowler_pounce_hit" in sfx_generator, "Prowler SFX are generated locally", failures)
    require("prowler_alert.wav" in sfx_generator and "prowler_defensive_attack.wav" in sfx_generator and "prowler_pounce_hit.wav" in sfx_generator, "Generator writes the three expected live Prowler audio filenames", failures)

    require("mipmaps/generate=false" in sprite_import, "Prowler base sprite import disables mipmaps", failures)
    require("mipmaps/generate=false" in sheet_import, "Prowler animation sheet import disables mipmaps", failures)
    require(
        'importer="wav"' in alert_import
        and 'type="AudioStreamWAV"' in alert_import
        and 'importer="wav"' in defensive_import
        and 'type="AudioStreamWAV"' in defensive_import
        and 'importer="wav"' in hit_import
        and 'type="AudioStreamWAV"' in hit_import,
        "Prowler audio files import into Godot as WAV streams",
        failures,
    )

    prowler_image = Image.open(ROOT / "art/sprites/prowler_enemy.png")
    sheet_image = Image.open(ROOT / "art/sprites/prowler_enemy_sheet.png")
    comparison_image = Image.open(ROOT / "art/dev/prowler_candidates/prowler_comparison.png")
    behavior_board = Image.open(ROOT / "art/dev/prowler_candidates/prowler_behavior_board.png")
    require(prowler_image.size == (20, 18), "Prowler live base sprite uses a 20x18 canvas", failures)
    require(sheet_image.size == (80, 108), "Prowler live animation sheet uses the approved 80x108 4x6 layout", failures)
    require(comparison_image.size == (384, 216), "Prowler comparison board renders at native arena scale", failures)
    require(behavior_board.size == (384, 216), "Prowler behavior board renders at native arena scale", failures)

    manifest = json.loads((ROOT / "art/dev/prowler_candidates/prowler_manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("active_reference_path") == str(ROOT / "art/sprites/prowler_enemy.png"), "Prowler manifest points to the live base sprite", failures)
    require(manifest.get("active_sheet_path") == str(ROOT / "art/sprites/prowler_enemy_sheet.png"), "Prowler manifest points to the live animation sheet", failures)
    require(manifest.get("selected_concept") == "Bonejaw Prowler", "Prowler manifest records the selected Bonejaw Prowler concept", failures)
    require("hooked pale jaw plate" in str(manifest.get("signature_motif", "")).lower(), "Prowler manifest records the selected jaw-hook silhouette motif", failures)
    require(manifest.get("frame_size") == [20, 18], "Prowler manifest records the new frame size", failures)
    require(manifest.get("sheet_layout") == [4, 6], "Prowler manifest records the new sheet layout", failures)
    require(len(manifest.get("candidates", [])) == 3, "Prowler manifest still records three distinct candidate concepts", failures)
    require(
        [candidate.get("title") for candidate in manifest.get("candidates", [])] == ["Bonejaw Prowler", "Bristlemane Prowler", "Hollow Hound"],
        "Prowler manifest preserves the final stylized candidate set and order",
        failures,
    )

    audio_manifest = json.loads((ROOT / "audio/dev/prowler_candidates/prowler_audio_manifest.json").read_text(encoding="utf-8"))
    require(audio_manifest.get("selected", {}).get("alert", {}).get("title") == "Bone-Throat Snarl", "Audio manifest records the selected alert cue", failures)
    require(audio_manifest.get("selected", {}).get("defensive", {}).get("title") == "Bone-Click Burst", "Audio manifest records the selected defensive cue", failures)
    require(audio_manifest.get("selected", {}).get("impact", {}).get("title") == "Bone Plate Thud", "Audio manifest records the selected impact cue", failures)
    require(len(audio_manifest.get("candidates", {}).get("alert", [])) == 3, "Audio manifest keeps three alert candidates", failures)
    require(len(audio_manifest.get("candidates", {}).get("defensive", [])) == 3, "Audio manifest keeps three defensive candidates", failures)
    require(len(audio_manifest.get("candidates", {}).get("impact", [])) == 3, "Audio manifest keeps three impact candidates", failures)

    require_wav_metadata("audio/prowler_alert.wav", failures, 0.32, 0.44)
    require_wav_metadata("audio/prowler_defensive_attack.wav", failures, 0.14, 0.24)
    require_wav_metadata("audio/prowler_pounce_hit.wav", failures, 0.10, 0.16)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_alert_candidate_1.wav", failures, 0.30, 0.40)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_alert_candidate_2.wav", failures, 0.34, 0.40)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_alert_candidate_3.wav", failures, 0.28, 0.36)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_defensive_candidate_1.wav", failures, 0.14, 0.22)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_defensive_candidate_2.wav", failures, 0.15, 0.22)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_defensive_candidate_3.wav", failures, 0.14, 0.20)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_impact_candidate_1.wav", failures, 0.10, 0.15)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_impact_candidate_2.wav", failures, 0.09, 0.14)
    require_wav_metadata("audio/dev/prowler_candidates/prowler_impact_candidate_3.wav", failures, 0.11, 0.16)

    require("Phase 4.5" in readme and "Phase 4.5" in roadmap, "README and ROADMAP document Phase 4.5", failures)
    require("Bonejaw Prowler" in readme and "Bonejaw Prowler" in tuning and "Bonejaw Prowler" in roadmap, "README, ROADMAP, and TUNING document the selected Bonejaw concept", failures)
    require("4x6" in readme and "4x6" in tuning and "20x18" in readme and "20x18" in tuning, "README and TUNING document the live frame size and sheet layout", failures)
    require("audio/prowler_defensive_attack.wav" in readme and "audio/prowler_defensive_attack.wav" in tuning, "README and TUNING document the defensive launch cue", failures)
    require("audio/dev/prowler_candidates" in readme, "README documents the kept Prowler audio candidate directory for the review pass", failures)
    require("Marsh Hound" not in readme and "Marsh Hound" not in roadmap and "Marsh Hound" not in tuning, "Docs no longer reference the superseded Marsh Hound direction", failures)
    require("does not renumber" in roadmap, "ROADMAP no longer describes Phase 4.5 as the next work item", failures)

    if failures:
        print(f"\nProwler enemy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nProwler enemy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
