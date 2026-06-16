from __future__ import annotations

import sys
import wave
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def read_optional_text(relative_path: str) -> str:
    path = ROOT / relative_path
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


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
    main_script = read_text("scripts/main.gd")
    director = read_text("scripts/encounter_director.gd")
    shooter = read_text("scripts/shooter_enemy.gd")
    dart = read_text("scripts/dart_projectile.gd")
    player = read_text("scripts/player.gd")
    main_scene = read_text("Main.tscn")
    shooter_scene = read_text("ShooterEnemy.tscn")
    dart_scene = read_text("DartProjectile.tscn")
    project = read_text("project.godot")
    shooter_import = read_text("art/sprites/shooter_enemy.png.import")
    windup_import = read_text("audio/blowgun_windup.wav.import")
    fire_import = read_text("audio/blowgun_fire.wav.import")
    shove_import = read_optional_text("audio/blowgun_shove.wav.import")
    generator = read_text("tools/generate_sfx.py")
    asset_generator = read_text("tools/generate_phase4_assets.py")

    for relative_path in [
        "ShooterEnemy.tscn",
        "DartProjectile.tscn",
        "scripts/shooter_enemy.gd",
        "scripts/dart_projectile.gd",
        "art/sprites/shooter_enemy.png",
        "art/sprites/shooter_enemy.png.import",
        "audio/blowgun_windup.wav",
        "audio/blowgun_windup.wav.import",
        "audio/blowgun_fire.wav",
        "audio/blowgun_fire.wav.import",
        "audio/blowgun_shove.wav",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("class_name ShooterEnemy" in shooter, "ShooterEnemy has a class name", failures)
    require("extends Enemy" in shooter, "ShooterEnemy extends Enemy", failures)
    require("score_value = 2" in shooter_scene, "Shooter score is 2", failures)
    require("body_radius = 7.0" in shooter_scene, "Shooter body radius starts at 7", failures)
    require("radius = 7.0" in shooter_scene, "Shooter collision radius starts at 7", failures)
    require("separation_distance = 24.0" in shooter_scene, "Shooter separation distance starts at 24", failures)
    require("separation_strength = 52.0" in shooter_scene, "Shooter separation strength starts at 52", failures)
    require("movement_speed_scale := 0.90" in shooter, "Shooter movement scale is refined to 0.90", failures)
    require("preferred_distance_min := 82.0" in shooter, "Shooter preferred minimum distance is 82", failures)
    require("preferred_distance_max := 118.0" in shooter, "Shooter preferred maximum distance is 118", failures)
    require("retreat_distance := 58.0" in shooter, "Shooter retreat threshold is 58", failures)
    require("wall_fallback_commit_duration := 0.45" in shooter, "Shooter has a committed wall fallback", failures)
    require(
        "enum ShooterState" in shooter
        and "LOCKED" in shooter
        and "ARC_REPOSITION" in shooter
        and "AIM_CANCEL_REPOSITION" in shooter
        and "SHOVE_WINDUP" in shooter
        and "SHOVE_ACTIVE" in shooter
        and "SHOVE_RECOVER" in shooter,
        "Shooter uses explicit attack, reposition, and shove states",
        failures,
    )
    require("aim_duration := 0.48" in shooter and "locked_duration := 0.24" in shooter, "Shooter refined telegraph timing is explicit", failures)
    require("burst_interval := 0.17" in shooter, "Shooter two-dart burst interval is refined to 0.17 seconds", failures)
    require("recover_duration := 0.16" in shooter, "Shooter post-burst recovery is short", failures)
    require("attack_cooldown := 0.95" in shooter, "Shooter attack cooldown is refined to 0.95 seconds", failures)
    require("aim_retry_delay := 0.18" in shooter, "Shooter keeps an explicit aim retry safeguard", failures)
    require("aim_cancel_min_distance := 74.0" in shooter and "aim_cancel_max_distance := 134.0" in shooter, "Shooter has explicit pre-lock cancel thresholds", failures)
    require("aim_cancel_reposition_duration := 0.55" in shooter and "aim_cancel_reposition_speed_scale := 1.12" in shooter, "Shooter has a committed cancel-reposition", failures)
    require("aim_cancel_reposition_sample_distance := 40.0" in shooter and "aim_cancel_reposition_radial_correction_strength := 0.22" in shooter, "Shooter cancel-reposition has dedicated side sampling and radial correction", failures)
    require("arc_reposition_duration := 1.10" in shooter, "Shooter has a longer post-burst arc reposition duration", failures)
    require("arc_reposition_speed_scale := 1.35" in shooter and "arc_reposition_side_sample_distance := 60.0" in shooter, "Shooter arc reposition has dedicated travel and side-sampling values", failures)
    require("arc_radial_correction_strength := 0.28" in shooter, "Shooter has updated arc radial correction", failures)
    require("shove_trigger_distance := 20.0" in shooter and "shove_cooldown := 2.10" in shooter, "Shooter has close-range shove tuning values", failures)
    require("shove_knockback_distance := 26.0" in shooter and "shove_knockback_duration := 0.18" in shooter, "Shooter shove exports authored player knockback values", failures)
    require("signal shove_used" in shooter and "player.try_start_forced_movement" in shooter, "Shooter shove uses the narrow player forced-movement seam", failures)
    require("minimum_dart_interval := 2.4" in shooter, "Shooter has a minimum dart interval", failures)
    require("dart_requested.emit" in shooter and "active_burst_id" in shooter, "Shooter asks Main to spawn burst-identified darts", failures)
    require("burst_shots_fired >= 2" in shooter and "burst_shots_fired < 2" in shooter, "Shooter fire state is capped to two darts", failures)
    require("func _try_contact_damage() -> void:\n\treturn" in shooter, "Shooter no longer deals ordinary body-overlap contact damage", failures)

    require("class_name DartProjectile" in dart, "DartProjectile has a class name", failures)
    require("PROJECTILE_KIND_DART := &\"dart\"" in dart, "Dart has a narrow identity constant", failures)
    require("destroy_projectile" in dart, "Dart has one clean destruction method", failures)
    require("has_resolved_hit" in dart, "Dart prevents duplicate hits", failures)
    require("speed := 145.0" in dart, "Dart speed starts at 145", failures)
    require("max_lifetime := 1.8" in dart, "Dart lifetime starts at 1.8", failures)
    require("collision_layer = 32" in dart_scene, "Dart uses the EnemyProjectile layer", failures)
    require("collision_mask = 1" in dart_scene, "Dart only masks the Player layer", failures)
    require("radius = 3.0" in dart_scene, "Dart collision radius is 3", failures)
    require("take_damage" in dart and "Player.DAMAGE_SOURCE_DART" in dart, "Dart uses the player damage authority with dart context", failures)
    require("burst_id" in dart and "dart_index" in dart and "projectile_token" in dart, "Dart carries burst id, dart index, and projectile token", failures)
    require("DAMAGE_SOURCE_DART := &\"dart\"" in player, "Player defines a narrow dart damage source", failures)
    require("damaged_dart_indices_by_burst" in player, "Player tracks accepted dart indices by burst", failures)
    require("accepted_dart_projectile_tokens" in player, "Player blocks duplicate dart projectile tokens", failures)
    require("FORCED_MOVEMENT" in player and "try_start_forced_movement" in player, "Player exposes the narrow forced-movement state used by shove", failures)
    require("ShieldedEnemy" not in dart and "receive_combat_hit" not in dart, "Dart does not implement Shielded interception yet", failures)

    require("EnemyProjectile" in project, "Project names the EnemyProjectile physics layer", failures)
    require("const ShooterScene := preload(\"res://ShooterEnemy.tscn\")" in main_script, "Main preloads Shooter", failures)
    require("const DartProjectileScene := preload(\"res://DartProjectile.tscn\")" in main_script, "Main preloads DartProjectile", failures)
    require("ProjectileContainer" in main_scene, "Main scene has a projectile container", failures)
    require("DEBUG_SHOOTER_SPAWN_ENABLED := true" in main_script, "Shooter debug spawn has its own enable constant", failures)
    require("_debug_spawn_shooter_enemy" in main_script and "KEY_2" in main_script, "Shooter debug spawn uses key 2", failures)
    require("SpawnSource.DEBUG" in main_script and "spawn_source == SpawnSource.DEBUG" in main_script, "Debug spawns are excluded from intro bookkeeping", failures)
    require("shooter_unlock_time := 42.0" in main_script, "Shooter unlocks at 42 seconds", failures)
    require("shooter_intro_target_time_min := 42.0" in main_script, "Shooter intro target starts at 42 seconds", failures)
    require("shooter_intro_target_time_max := 52.0" in main_script, "Shooter intro target ends at 52 seconds", failures)
    require("shooter_spawn_chance_at_unlock := 0.04" in main_script, "Shooter starts at 0.04 ambient chance", failures)
    require("shooter_spawn_chance_growth_per_second := 0.00045" in main_script, "Shooter chance growth is 0.00045", failures)
    require("maximum_shooter_spawn_chance := 0.10" in main_script, "Shooter chance caps at 0.10", failures)
    require("shooter_intro_seen" in main_script and "shooter_intro_target_time = rng.randf_range" in main_script, "Shooter reuses randomized intro targets", failures)
    require("EnemyKind.SHOOTER" in main_script, "Main can select Shooter enemy kind", failures)

    require("SHOOTER" in director, "EncounterDirector defines Shooter kind", failures)
    require("shooter_hostile_cap := 1" in director, "Shooter cap is 1", failures)
    require("get_shooter_hostile_count() < shooter_hostile_cap" in director, "Shooter has a dedicated cap", failures)
    require("get_total_hostile_count() >= total_hostile_cap" in director, "Shooter still counts under total hostile cap", failures)
    require("EnemyKind.SHOOTER" not in director.split("func _build_wave_definitions", 1)[1], "Authored waves contain no Shooter steps", failures)

    require("BlowgunWindupPlayer" in main_scene and "BlowgunFirePlayer" in main_scene and "BlowgunShovePlayer" in main_scene, "Main has Shooter SFX players", failures)
    require('path="res://audio/blowgun_windup.wav"' in main_scene, "Wind-up stream is assigned", failures)
    require('path="res://audio/blowgun_fire.wav"' in main_scene, "Fire stream is assigned", failures)
    require('path="res://audio/blowgun_shove.wav"' in main_scene, "Shove stream is assigned", failures)
    require('bus = &"SFX"' in main_scene, "Shooter sounds route through SFX", failures)
    require("generate_blowgun_windup" in generator, "Wind-up SFX is reproducible", failures)
    require("generate_blowgun_fire" in generator, "Fire SFX is reproducible", failures)
    require("generate_blowgun_shove" in generator, "Shove SFX is reproducible", failures)
    require("draw_shooter_enemy" in asset_generator, "Shooter sprite is reproducible", failures)
    require("mipmaps/generate=false" in shooter_import, "Shooter sprite import disables mipmaps", failures)
    shooter_image = Image.open(ROOT / "art/sprites/shooter_enemy.png")
    require(shooter_image.size == (14, 16), "Shooter sprite is reduced to 14x16 pixels", failures)
    require('importer="wav"' in windup_import, "Wind-up audio import uses WAV importer", failures)
    require('importer="wav"' in fire_import, "Fire audio import uses WAV importer", failures)
    if shove_import:
        require('importer="wav"' in shove_import, "Shove audio import uses WAV importer", failures)
    else:
        print("NOTE: blowgun_shove.wav.import was not generated in this environment; startup/runtime checks validate the raw WAV path instead.")
    audit_wav("audio/blowgun_windup.wav", 0.28, 0.38, failures)
    audit_wav("audio/blowgun_fire.wav", 0.10, 0.16, failures)
    audit_wav("audio/blowgun_shove.wav", 0.14, 0.22, failures)

    if failures:
        print(f"\nShooter enemy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nShooter enemy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
