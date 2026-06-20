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
    boomer = read_text("scripts/boomer_enemy.gd")
    blast_effect = read_text("scripts/boomer_blast_effect.gd")
    player = read_text("scripts/player.gd")
    main_script = read_text("scripts/main.gd")
    director = read_text("scripts/encounter_director.gd")
    main_scene = read_text("Main.tscn")
    boomer_scene = read_text("BoomerEnemy.tscn")
    blast_effect_scene = read_text("BoomerBlastEffect.tscn")
    generator = read_text("tools/generate_sfx.py")
    asset_generator = read_text("tools/generate_phase4_assets.py")
    sprite_import = read_text("art/sprites/boomer_enemy.png.import")
    hop_import = read_text("audio/boomer_hop_prep.wav.import")
    land_import = read_text("audio/boomer_land.wav.import")
    fuse_import = read_text("audio/boomer_fuse.wav.import")
    explosion_import = read_text("audio/boomer_explosion.wav.import")
    comparison_manifest_path = ROOT / "art/dev/boomer_candidates/boomer_manifest.json"

    for relative_path in [
        "BoomerEnemy.tscn",
        "BoomerBlastEffect.tscn",
        "scripts/boomer_enemy.gd",
        "scripts/boomer_blast_effect.gd",
        "art/sprites/boomer_enemy.png",
        "art/sprites/boomer_enemy.png.import",
        "art/dev/boomer_candidates/boomer_comparison.png",
        "art/dev/boomer_candidates/boomer_manifest.json",
        "audio/boomer_hop_prep.wav",
        "audio/boomer_hop_prep.wav.import",
        "audio/boomer_land.wav",
        "audio/boomer_land.wav.import",
        "audio/boomer_fuse.wav",
        "audio/boomer_fuse.wav.import",
        "audio/boomer_explosion.wav",
        "audio/boomer_explosion.wav.import",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("class_name BoomerEnemy" in boomer and "extends Enemy" in boomer, "BoomerEnemy extends Enemy with a class name", failures)
    require(
        "enum BoomerState" in boomer
        and "HOP_PREP" in boomer
        and "HOPPING" in boomer
        and "LAND_RECOVERY" in boomer
        and "FUSE" in boomer,
        "Boomer uses the approved discrete hop-and-fuse state machine",
        failures,
    )
    require("signal hop_prepared" in boomer and "signal hop_landed" in boomer and "signal fuse_started" in boomer and "signal detonated" in boomer, "Boomer exposes the planned presentation signals", failures)
    require("func _try_contact_damage() -> void:\n\treturn" in boomer, "Boomer deals no ordinary body-overlap contact damage", failures)
    require("hop_prep_duration := 0.18" in boomer and "hop_duration := 0.24" in boomer and "hop_distance := 38.0" in boomer, "Boomer hop tuning matches the approved starting values", failures)
    require("landing_recovery_duration := 0.20" in boomer and "fuse_duration := 0.80" in boomer and "fuse_trigger_distance := 36.0" in boomer, "Boomer landing and fuse timings match the approved starting values", failures)
    require("core_blast_radius := 29.0" in boomer and "outer_shockwave_radius := 54.0" in boomer, "Boomer uses the approved core and shockwave radii", failures)
    require("_is_player_in_fuse_range()" in boomer and "_enter_fuse_state()" in boomer and "_enter_land_recovery_state()" in boomer, "Boomer checks fuse range immediately on landing", failures)
    require("_apply_landing_correction" in boomer and "_process_hop_prep" in boomer and "_process_land_recovery" in boomer, "Boomer keeps prep and recovery discrete while using only a one-time landing correction", failures)
    require("has_detonated" in boomer and "_resolve_explosion" in boomer and "queue_free()" in boomer, "Boomer guards detonation to one explosion and self-cleans without scoring", failures)
    require("Player.DAMAGE_SOURCE_EXPLOSION" in boomer and "player.try_start_forced_movement" in boomer, "Boomer routes player damage and knockback through the existing player authority", failures)
    require("landed_spear_shockwave_displacement := 20.0" in boomer, "Boomer exports the approved landed-spear shockwave displacement", failures)
    require("if player.has_shove_damage_protection():\n\t\treturn" in boomer, "Boomer core blast skips damage and replacement knockback during shove-protected forced movement", failures)
    require("other_enemy is Charger" in boomer and "other_enemy.receive_combat_hit(HIT_SOURCE_EXPLOSION" in boomer, "Boomer uses narrow per-enemy explosion responses instead of a broad combat framework", failures)

    require("class_name BoomerBlastEffect" in blast_effect, "Boomer blast effect has a class name", failures)
    require("duration := 0.24" in blast_effect and "draw_arc" in blast_effect, "Boomer blast effect is a short-lived visual-only scene", failures)
    require("score_value = 2" in boomer_scene, "Boomer safe kill score is 2", failures)
    require("body_radius = 8.0" in boomer_scene and "radius = 8.0" in boomer_scene, "Boomer body and collision radii start at 8", failures)
    require("separation_distance = 26.0" in boomer_scene and "separation_strength = 48.0" in boomer_scene, "Boomer has its own spacing tuning", failures)
    require("script = ExtResource(\"1\")" in blast_effect_scene, "Boomer blast effect scene is script-backed", failures)

    require("DAMAGE_SOURCE_EXPLOSION := &\"explosion\"" in player, "Player defines a narrow explosion damage source", failures)
    require("has_shove_damage_protection() and damage_source != DAMAGE_SOURCE_EXPLOSION" in player, "Player still keeps explosion damage generally valid while shove protection blocks other sources", failures)

    require("const BoomerScene := preload(\"res://BoomerEnemy.tscn\")" in main_script, "Main preloads BoomerEnemy", failures)
    require("const BoomerBlastEffectScene := preload(\"res://BoomerBlastEffect.tscn\")" in main_script, "Main preloads the blast effect scene", failures)
    require("DEBUG_BOOMER_SPAWN_ENABLED := true" in main_script and "_debug_spawn_boomer_enemy" in main_script and "KEY_3" in main_script, "Boomer debug spawn uses key 3", failures)
    require("boomer_unlock_time := 65.0" in main_script and "boomer_intro_target_time_min := 65.0" in main_script and "boomer_intro_target_time_max := 78.0" in main_script, "Boomer intro timing is configured in Main", failures)
    require("boomer_spawn_chance_at_unlock := 0.025" in main_script and "boomer_spawn_chance_growth_per_second := 0.00035" in main_script and "maximum_boomer_spawn_chance := 0.07" in main_script, "Boomer long-run ambient weights are configured in Main", failures)
    require("EnemyKind.BOOMER" in main_script and "boomer_intro_seen" in main_script and "debug_set_intro_target_times" in main_script, "Main integrates Boomer with the existing intro bookkeeping", failures)
    require("landed_spear_shockwave_displacement: float" in main_script and "spear.apply_landed_shockwave_nudge(" in main_script, "Main applies the one-time landed-spear shockwave nudge from the Boomer detonation callback", failures)
    require("EffectContainer" in main_scene and "BoomerHopPrepPlayer" in main_scene and "BoomerExplosionPlayer" in main_scene, "Main scene contains Boomer effect and audio nodes", failures)
    require('path="res://audio/boomer_hop_prep.wav"' in main_scene and 'path="res://audio/boomer_land.wav"' in main_scene and 'path="res://audio/boomer_fuse.wav"' in main_scene and 'path="res://audio/boomer_explosion.wav"' in main_scene, "Boomer SFX streams are assigned in Main", failures)

    require("BOOMER" in director and "boomer_hostile_cap := 1" in director and "get_boomer_hostile_count()" in director, "EncounterDirector tracks Boomer with a dedicated cap of one", failures)
    require("EnemyKind.BOOMER" not in director.split("func _build_wave_definitions", 1)[1], "Authored waves still contain no Boomer steps", failures)

    require("draw_boomer_enemy" in asset_generator and "build_boomer_variant_specs" in asset_generator and "generate_boomer_candidate_assets" in asset_generator, "Boomer sprite and concept board are reproducible locally", failures)
    require("--generate-dev-boomer-concepts" in asset_generator, "Boomer concept generation stays behind an explicit dev-workflow flag", failures)
    require("generate_boomer_hop_prep" in generator and "generate_boomer_land" in generator and "generate_boomer_fuse" in generator and "generate_boomer_explosion" in generator, "Boomer SFX are reproducible locally", failures)

    require('mipmaps/generate=false' in sprite_import, "Boomer sprite import disables mipmaps", failures)
    for import_text, label in [
        (hop_import, "Hop-prep audio import uses WAV importer"),
        (land_import, "Landing audio import uses WAV importer"),
        (fuse_import, "Fuse audio import uses WAV importer"),
        (explosion_import, "Explosion audio import uses WAV importer"),
    ]:
        require('importer="wav"' in import_text, label, failures)

    sprite_image = Image.open(ROOT / "art/sprites/boomer_enemy.png")
    comparison_image = Image.open(ROOT / "art/dev/boomer_candidates/boomer_comparison.png")
    require(sprite_image.size == (16, 18), "Boomer live sprite uses the approved small 16x18 canvas", failures)
    require(comparison_image.size == (384, 216), "Boomer comparison board renders at native arena scale", failures)

    if comparison_manifest_path.exists():
        manifest = json.loads(comparison_manifest_path.read_text(encoding="utf-8"))
        require(len(manifest.get("candidates", [])) == 3, "Boomer comparison manifest records three distinct candidates", failures)

    audit_wav("audio/boomer_hop_prep.wav", 0.14, 0.22, failures)
    audit_wav("audio/boomer_land.wav", 0.12, 0.20, failures)
    audit_wav("audio/boomer_fuse.wav", 0.74, 0.86, failures)
    audit_wav("audio/boomer_explosion.wav", 0.22, 0.32, failures)

    if failures:
        print(f"\nBoomer enemy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nBoomer enemy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
