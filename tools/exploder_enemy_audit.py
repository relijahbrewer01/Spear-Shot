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
    duration = frame_count / sample_rate if sample_rate else 0.0

    require(channels == 1, f"{relative_path} is mono", failures)
    require(sample_width == 2, f"{relative_path} is 16-bit PCM", failures)
    require(sample_rate == 44100, f"{relative_path} uses 44.1 kHz", failures)
    require(min_duration <= duration <= max_duration, f"{relative_path} has the planned duration", failures)
    require(peak >= 12000, f"{relative_path} contains audible non-silent samples", failures)


def main() -> int:
    failures: list[str] = []
    exploder = read_text("scripts/exploder_enemy.gd")
    blast_effect = read_text("scripts/exploder_blast_effect.gd")
    player = read_text("scripts/player.gd")
    main_script = read_text("scripts/main.gd")
    director = read_text("scripts/encounter_director.gd")
    main_scene = read_text("Main.tscn")
    exploder_scene = read_text("ExploderEnemy.tscn")
    blast_effect_scene = read_text("ExploderBlastEffect.tscn")
    generator = read_text("tools/generate_sfx.py")
    asset_generator = read_text("tools/generate_phase4_assets.py")
    sprite_import = read_text("art/sprites/exploder_enemy.png.import")
    hop_import = read_text("audio/exploder_hop_prep.wav.import")
    land_import = read_text("audio/exploder_land.wav.import")
    fuse_import = read_text("audio/exploder_fuse.wav.import")
    explosion_import = read_text("audio/exploder_explosion.wav.import")
    comparison_manifest_path = ROOT / "art/dev/exploder_candidates/exploder_manifest.json"

    for relative_path in [
        "ExploderEnemy.tscn",
        "ExploderBlastEffect.tscn",
        "scripts/exploder_enemy.gd",
        "scripts/exploder_blast_effect.gd",
        "art/sprites/exploder_enemy.png",
        "art/sprites/exploder_enemy.png.import",
        "art/dev/exploder_candidates/exploder_comparison.png",
        "art/dev/exploder_candidates/exploder_manifest.json",
        "audio/exploder_hop_prep.wav",
        "audio/exploder_hop_prep.wav.import",
        "audio/exploder_land.wav",
        "audio/exploder_land.wav.import",
        "audio/exploder_fuse.wav",
        "audio/exploder_fuse.wav.import",
        "audio/exploder_explosion.wav",
        "audio/exploder_explosion.wav.import",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("class_name ExploderEnemy" in exploder and "extends Enemy" in exploder, "ExploderEnemy extends Enemy with a class name", failures)
    require(
        "enum ExploderState" in exploder
        and "HOP_PREP" in exploder
        and "HOPPING" in exploder
        and "LAND_RECOVERY" in exploder
        and "FUSE" in exploder,
        "Exploder uses the approved discrete hop-and-fuse state machine",
        failures,
    )
    require("signal hop_prepared" in exploder and "signal hop_landed" in exploder and "signal fuse_started" in exploder and "signal detonated" in exploder, "Exploder exposes the planned presentation signals", failures)
    require("func _try_contact_damage() -> void:\n\treturn" in exploder, "Exploder deals no ordinary body-overlap contact damage", failures)
    require("hop_prep_duration := 0.18" in exploder and "hop_duration := 0.24" in exploder and "hop_distance := 38.0" in exploder, "Exploder hop tuning matches the approved starting values", failures)
    require("landing_recovery_duration := 0.20" in exploder and "fuse_duration := 0.80" in exploder and "fuse_trigger_distance := 36.0" in exploder, "Exploder landing and fuse timings match the approved starting values", failures)
    require("core_blast_radius := 29.0" in exploder and "outer_shockwave_radius := 54.0" in exploder, "Exploder uses the approved core and shockwave radii", failures)
    require("_is_player_in_fuse_range()" in exploder and "_enter_fuse_state()" in exploder and "_enter_land_recovery_state()" in exploder, "Exploder checks fuse range immediately on landing", failures)
    require("_apply_landing_correction" in exploder and "_process_hop_prep" in exploder and "_process_land_recovery" in exploder, "Exploder keeps prep and recovery discrete while using only a one-time landing correction", failures)
    require("has_detonated" in exploder and "_resolve_explosion" in exploder and "queue_free()" in exploder, "Exploder guards detonation to one explosion and self-cleans without scoring", failures)
    require("Player.DAMAGE_SOURCE_EXPLOSION" in exploder and "player.try_start_forced_movement" in exploder, "Exploder routes player damage and knockback through the existing player authority", failures)
    require("other_enemy is Charger" in exploder and "other_enemy.receive_combat_hit(HIT_SOURCE_EXPLOSION" in exploder, "Exploder uses narrow per-enemy explosion responses instead of a broad combat framework", failures)

    require("class_name ExploderBlastEffect" in blast_effect, "Exploder blast effect has a class name", failures)
    require("duration := 0.24" in blast_effect and "draw_arc" in blast_effect, "Exploder blast effect is a short-lived visual-only scene", failures)
    require("score_value = 2" in exploder_scene, "Exploder safe kill score is 2", failures)
    require("body_radius = 8.0" in exploder_scene and "radius = 8.0" in exploder_scene, "Exploder body and collision radii start at 8", failures)
    require("separation_distance = 26.0" in exploder_scene and "separation_strength = 48.0" in exploder_scene, "Exploder has its own spacing tuning", failures)
    require("script = ExtResource(\"1\")" in blast_effect_scene, "Exploder blast effect scene is script-backed", failures)

    require("DAMAGE_SOURCE_EXPLOSION := &\"explosion\"" in player, "Player defines a narrow explosion damage source", failures)
    require("has_shove_damage_protection() and damage_source != DAMAGE_SOURCE_EXPLOSION" in player, "Shove protection no longer blocks explosion damage", failures)

    require("const ExploderScene := preload(\"res://ExploderEnemy.tscn\")" in main_script, "Main preloads ExploderEnemy", failures)
    require("const ExploderBlastEffectScene := preload(\"res://ExploderBlastEffect.tscn\")" in main_script, "Main preloads the blast effect scene", failures)
    require("DEBUG_EXPLODER_SPAWN_ENABLED := true" in main_script and "_debug_spawn_exploder_enemy" in main_script and "KEY_3" in main_script, "Exploder debug spawn uses key 3", failures)
    require("exploder_unlock_time := 65.0" in main_script and "exploder_intro_target_time_min := 65.0" in main_script and "exploder_intro_target_time_max := 78.0" in main_script, "Exploder intro timing is configured in Main", failures)
    require("exploder_spawn_chance_at_unlock := 0.025" in main_script and "exploder_spawn_chance_growth_per_second := 0.00035" in main_script and "maximum_exploder_spawn_chance := 0.07" in main_script, "Exploder long-run ambient weights are configured in Main", failures)
    require("EnemyKind.EXPLODER" in main_script and "exploder_intro_seen" in main_script and "debug_set_intro_target_times" in main_script, "Main integrates Exploder with the existing intro bookkeeping", failures)
    require("EffectContainer" in main_scene and "ExploderHopPrepPlayer" in main_scene and "ExploderExplosionPlayer" in main_scene, "Main scene contains Exploder effect and audio nodes", failures)
    require('path="res://audio/exploder_hop_prep.wav"' in main_scene and 'path="res://audio/exploder_land.wav"' in main_scene and 'path="res://audio/exploder_fuse.wav"' in main_scene and 'path="res://audio/exploder_explosion.wav"' in main_scene, "Exploder SFX streams are assigned in Main", failures)

    require("EXPLODER" in director and "exploder_hostile_cap := 1" in director and "get_exploder_hostile_count()" in director, "EncounterDirector tracks Exploder with a dedicated cap of one", failures)
    require("EnemyKind.EXPLODER" not in director.split("func _build_wave_definitions", 1)[1], "Authored waves still contain no Exploder steps", failures)

    require("draw_exploder_enemy" in asset_generator and "build_exploder_variant_specs" in asset_generator and "generate_exploder_candidate_assets" in asset_generator, "Exploder sprite and concept board are reproducible locally", failures)
    require("--generate-dev-exploder-concepts" in asset_generator, "Exploder concept generation stays behind an explicit dev-workflow flag", failures)
    require("generate_exploder_hop_prep" in generator and "generate_exploder_land" in generator and "generate_exploder_fuse" in generator and "generate_exploder_explosion" in generator, "Exploder SFX are reproducible locally", failures)

    require('mipmaps/generate=false' in sprite_import, "Exploder sprite import disables mipmaps", failures)
    for import_text, label in [
        (hop_import, "Hop-prep audio import uses WAV importer"),
        (land_import, "Landing audio import uses WAV importer"),
        (fuse_import, "Fuse audio import uses WAV importer"),
        (explosion_import, "Explosion audio import uses WAV importer"),
    ]:
        require('importer="wav"' in import_text, label, failures)

    sprite_image = Image.open(ROOT / "art/sprites/exploder_enemy.png")
    comparison_image = Image.open(ROOT / "art/dev/exploder_candidates/exploder_comparison.png")
    require(sprite_image.size == (16, 18), "Exploder live sprite uses the approved small 16x18 canvas", failures)
    require(comparison_image.size == (384, 216), "Exploder comparison board renders at native arena scale", failures)

    if comparison_manifest_path.exists():
        manifest = json.loads(comparison_manifest_path.read_text(encoding="utf-8"))
        require(len(manifest.get("candidates", [])) == 3, "Exploder comparison manifest records three distinct candidates", failures)

    audit_wav("audio/exploder_hop_prep.wav", 0.14, 0.22, failures)
    audit_wav("audio/exploder_land.wav", 0.12, 0.20, failures)
    audit_wav("audio/exploder_fuse.wav", 0.74, 0.86, failures)
    audit_wav("audio/exploder_explosion.wav", 0.22, 0.32, failures)

    if failures:
        print(f"\nExploder enemy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nExploder enemy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
