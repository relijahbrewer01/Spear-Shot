from __future__ import annotations

import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
        return
    print(f"FAIL: {message}")
    failures.append(message)


def audit_shield_break_audio(failures: list[str]) -> None:
    audio_path = ROOT / "audio" / "shield_break.wav"
    require(audio_path.exists(), "Shield break WAV exists", failures)
    if not audio_path.exists():
        return

    with wave.open(str(audio_path), "rb") as wav_file:
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
    meaningful_samples = sum(1 for sample in samples if abs(sample) >= 512)

    require(channels == 1, "Shield break is mono", failures)
    require(sample_width == 2, "Shield break is 16-bit PCM", failures)
    require(sample_rate == 44100, "Shield break uses 44.1 kHz", failures)
    require(0.20 <= duration <= 0.28, "Shield break duration is short and physical", failures)
    require(peak >= 12000, "Shield break contains audible peak samples", failures)
    require(meaningful_samples > frame_count * 0.15, "Shield break is meaningfully non-silent", failures)


def main() -> int:
    failures: list[str] = []

    enemy = read_text("scripts/enemy.gd")
    shielded = read_text("scripts/shielded_enemy.gd")
    spear = read_text("scripts/spear.gd")
    main_script = read_text("scripts/main.gd")
    director = read_text("scripts/encounter_director.gd")
    shielded_scene = read_text("ShieldedEnemy.tscn")
    main_scene = read_text("Main.tscn")
    generator = read_text("tools/generate_sfx.py")

    for relative_path in [
        "ShieldedEnemy.tscn",
        "scripts/shielded_enemy.gd",
        "art/sprites/shielded_enemy.png",
        "audio/shield_break.wav",
        "tools/generate_phase4_assets.py",
    ]:
        require((ROOT / relative_path).exists(), f"{relative_path} exists", failures)

    require("const HIT_SOURCE_SPEAR := &\"spear\"" in enemy, "Enemy exposes spear hit source", failures)
    require(
        "const HIT_SOURCE_EXPLOSION := &\"explosion\"" in enemy,
        "Enemy exposes future explosion hit source",
        failures,
    )
    for response_name in ["IGNORED", "DAMAGED", "STOPPED"]:
        require(response_name in enemy, f"HitResponse includes {response_name}", failures)
    require("func receive_combat_hit" in enemy, "Base enemy implements combat-hit interface", failures)

    require("class_name ShieldedEnemy" in shielded, "ShieldedEnemy has a class name", failures)
    require("extends Enemy" in shielded, "ShieldedEnemy extends Enemy", failures)
    require("score_value = 2" in shielded_scene, "Shielded scene score value is 2", failures)
    require("body_radius = 9.0" in shielded_scene, "Shielded body radius starts at 9", failures)
    require("separation_distance = 19.0" in shielded_scene, "Shielded separation footprint starts at 19", failures)
    require("movement_speed_scale := 0.72" in shielded, "Shielded movement scale starts at 72%", failures)
    require("stagger_duration := 0.65" in shielded, "Shielded stagger starts at 0.65 seconds", failures)
    require("knockback_distance := 14.0" in shielded, "Shielded knockback starts around 14 pixels", failures)
    require("knockback_duration := 0.12" in shielded, "Shielded knockback starts around 0.12 seconds", failures)
    require("shield_intact = false" in shielded, "Shield break permanently exposes the enemy", failures)
    require("return HitResponse.STOPPED" in shielded, "Intact spear hit returns STOPPED", failures)
    require("killed.emit" not in shielded, "Shield break has no separate killed/scoring path", failures)
    require("super.receive_combat_hit" in shielded, "Exposed Shielded death reuses base enemy scoring path", failures)
    require("super._try_contact_damage()" in shielded, "Contact damage resumes only through inherited path", failures)

    require(
        "_collect_sorted_launch_sweep_candidates" in spear
        and "candidates.sort_custom(_sort_launch_sweep_candidates)" in spear,
        "Launch sweep gathers and sorts candidates before processing",
        failures,
    )
    require(
        "projected_distance" in spear
        and ".dot(" in spear
        and "owner_player.global_position" in spear,
        "Launch sweep ordering uses projected distance from the throw origin",
        failures,
    )
    require(
        "if state != State.FLYING:" in spear
        and "return Enemy.HitResponse.IGNORED" in spear
        and "_land(stopped_landing_position)" in spear,
        "STOPPED immediately lands the spear and later callbacks observe non-flying state",
        failures,
    )
    require(
        "_get_stopped_hit_landing_position" in spear
        and "incoming_side := -throw_direction" in spear
        and "_clamp_to_arena(raw_candidate)" in spear,
        "Forced shield-stop landing uses incoming-side candidates clamped to spear bounds",
        failures,
    )
    require(
        "stopped_hit_landing_clearance := 4.0" in spear
        and "minimum_clear_distance := body_radius + maxf(stopped_hit_landing_clearance, 2.0)" in spear,
        "Forced shield-stop landing uses the reduced body radius plus a small clearance",
        failures,
    )
    require(
        "func _enter_landed_state" in spear
        and "_try_pickup_overlapping_player" in spear
        and "_is_owner_player_inside_pickup_query" in spear,
        "Normal and forced landing share landed setup with explicit already-overlapping pickup safety",
        failures,
    )

    require(
        'const ShieldedScene := preload("res://ShieldedEnemy.tscn")' in main_script,
        "Main preloads Shielded scene",
        failures,
    )
    require("ShieldBreakPlayer" in main_scene, "Main scene has a ShieldBreakPlayer", failures)
    require('path="res://audio/shield_break.wav"' in main_scene, "Shield break stream path is assigned", failures)
    require('bus = &"SFX"' in main_scene, "Shield break routes through SFX bus", failures)
    require("shield_broken" in main_script, "Main listens for shield break events", failures)
    require("_on_enemy_killed" in main_script and "score += score_value" in main_script, "Score remains single-source in Main", failures)

    require("SHIELDED" in director, "EncounterDirector has a Shielded enemy kind", failures)
    require("shielded_hostile_cap := 2" in director, "Shielded cap starts at 2", failures)
    require("get_total_hostile_count() >= total_hostile_cap" in director, "Shielded counts under total hostile cap", failures)
    require("get_shielded_hostile_count() < shielded_hostile_cap" in director, "Shielded has a dedicated cap", failures)
    require(
        "EnemyKind.SHIELDED" not in director.split("func _build_wave_definitions", 1)[1],
        "Rush, Pincer, and Charger Hunt contain no Shielded steps",
        failures,
    )
    require("shielded_unlock_time := 25.0" in main_script, "Shielded unlocks around 25 seconds", failures)
    require("shielded_spawn_chance_at_unlock := 0.05" in main_script, "Shielded starts at 0.05 ambient weight", failures)
    require("shielded_spawn_chance_growth_per_second := 0.0006" in main_script, "Shielded growth is 0.0006 per second", failures)
    require("maximum_shielded_spawn_chance := 0.12" in main_script, "Shielded max ambient weight is 0.12", failures)
    require("shielded_intro_target_time_min := 25.0" in main_script, "Shielded intro target starts at 25 seconds", failures)
    require("shielded_intro_target_time_max := 30.0" in main_script, "Shielded intro target ends at 30 seconds", failures)
    require("not shielded_intro_seen" in main_script, "Shielded intro remains pending while unseen", failures)
    require("spawn_source == SpawnSource.DEBUG" in main_script, "Debug Shielded spawn is excluded from intro bookkeeping", failures)
    require(
        "shielded_available := (" in main_script
        and "encounter_director.can_spawn_enemy(EncounterDirector.EnemyKind.SHIELDED" in main_script,
        "Ambient selection removes Shielded when locked or capped",
        failures,
    )

    require("generate_shield_break" in generator, "Shield break sound is reproducible locally", failures)
    audit_shield_break_audio(failures)

    if failures:
        print(f"\nShielded enemy audit failed with {len(failures)} issue(s).")
        return 1

    print("\nShielded enemy audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
