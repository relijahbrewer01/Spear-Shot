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


def audit_wave_audio(failures: list[str]) -> None:
    audio_path = ROOT / "audio" / "wave_warning.wav"
    require(audio_path.exists(), "Wave warning WAV exists", failures)
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
    require(channels == 1, "Wave warning is mono", failures)
    require(sample_width == 2, "Wave warning is 16-bit PCM", failures)
    require(sample_rate == 44100, "Wave warning uses 44.1 kHz", failures)
    require(0.30 <= duration <= 0.40, "Wave warning duration is restrained", failures)
    require(peak >= 12000, "Wave warning contains audible non-silent samples", failures)


def main() -> int:
    failures: list[str] = []
    director = read_text("scripts/encounter_director.gd")
    main_script = read_text("scripts/main.gd")
    arena = read_text("scripts/arena.gd")
    spear = read_text("scripts/Spear.gd")
    scene = read_text("Main.tscn")
    generator = read_text("tools/generate_sfx.py")

    for state_name in [
        "AMBIENT",
        "WAVE_TELEGRAPH",
        "WAVE_ACTIVE",
        "WAVE_RECOVERY",
    ]:
        require(state_name in director, f"Director defines {state_name}", failures)

    for wave_name in ["rush", "pincer", "charger_hunt"]:
        require(
            f'&"{wave_name}"' in director,
            f"Director defines {wave_name}",
            failures,
        )
    require('WAVE_RING' not in director, "Ring wave remains deferred", failures)

    require(
        "wave_start_population_threshold := 5" in director,
        "Wave start threshold is five hostiles",
        failures,
    )
    require("total_hostile_cap := 10" in director, "Total hostile cap is tunable from ten", failures)
    require("normal_hostile_cap := 9" in director, "Normal cap is tunable from nine", failures)
    require("charger_hostile_cap := 2" in director, "Charger safety cap is tunable from two", failures)
    require(
        "first_minute_charger_cap := 1" in director,
        "First-minute Charger production is limited to one",
        failures,
    )

    require(
        "_scheduled_spawn_index >= _resolved_steps.size()" in director
        and "_wave_enemy_ids.is_empty()" in director,
        "Completion requires all scheduled spawns and no living wave enemies",
        failures,
    )
    require(
        "notify_enemy_removed" in director
        and "enemy.tree_exited.connect" in main_script
        and "enemy.killed.connect" in main_script,
        "Death and tree exit both clean population records",
        failures,
    )
    require(
        "run_generation" in director and "get_run_generation" in main_script,
        "Restart generation guards stale enemy callbacks",
        failures,
    )

    require(
        "ambient_spawn_policy_changed.emit(false)" in director,
        "Telegraph pauses ambient spawning",
        failures,
    )
    require(
        "EncounterState.WAVE_ACTIVE" in director
        and "EncounterState.WAVE_RECOVERY" in director,
        "Ambient remains state-gated throughout active and recovery phases",
        failures,
    )
    require(
        "spawn_timer.wait_time = _get_next_spawn_interval()" in main_script
        and "_on_ambient_spawn_policy_changed" in main_script,
        "Ambient resumes with a fresh current-difficulty interval",
        failures,
    )

    require(
        "find_safe_spawn_position" in arena
        and "return INVALID_SPAWN_POSITION" in arena,
        "Safe spawn search has no unsafe fallback",
        failures,
    )
    require("spawn_safe_radius := 72.0" in main_script, "Player spawn clearance remains 72 pixels", failures)
    require(
        "landed_spear_spawn_safe_radius := 36.0" in main_script
        and "spear.is_landed()" in main_script
        and "func is_landed()" in spear,
        "Spawn search avoids a landed spear",
        failures,
    )

    require("EncounterTelegraph" in scene, "Main scene contains world-space edge telegraph", failures)
    require("WaveWarningPlayer" in scene, "Main scene contains one wave warning player", failures)
    require('path="res://audio/wave_warning.wav"' in scene, "Warning stream is assigned explicitly", failures)
    require('bus = &"SFX"' in scene, "Warning player uses the SFX bus", failures)
    require(
        "generate_wave_warning" in generator,
        "Wave warning remains reproducible from the local generator",
        failures,
    )
    audit_wave_audio(failures)

    if failures:
        print(f"\nEncounter director audit failed with {len(failures)} issue(s).")
        return 1

    print("\nEncounter director audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
