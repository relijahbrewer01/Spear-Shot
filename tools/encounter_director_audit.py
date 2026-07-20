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
    readme = read_text("README.md")
    roadmap = read_text("ROADMAP.md")
    tuning = read_text("TUNING.md")
    bulwark_section = director.split("var bulwark_steps", 1)[1] if "var bulwark_steps" in director else ""

    for state_name in [
        "AMBIENT",
        "WAVE_TELEGRAPH",
        "WAVE_ACTIVE",
        "WAVE_RECOVERY",
    ]:
        require(state_name in director, f"Director defines {state_name}", failures)

    for wave_name in ["rush", "pincer", "charger_hunt", "bulwark"]:
        require(
            f'&"{wave_name}"' in director,
            f"Director defines {wave_name}",
            failures,
        )
    require('WAVE_RING' not in director, "Ring wave remains deferred", failures)

    require(
        "rush_start_population_threshold := 5" in director,
        "Rush can start at five or fewer hostiles",
        failures,
    )
    require(
        "pincer_start_population_threshold := 3" in director,
        "Pincer can start at three or fewer hostiles",
        failures,
    )
    require(
        "charger_hunt_start_population_threshold := 4" in director,
        "Charger Hunt can start at four or fewer hostiles",
        failures,
    )
    require(
        "start_population_threshold" in director
        and "living_hostiles > wave.start_population_threshold" in director,
        "Wave selection uses each wave's own pressure budget",
        failures,
    )
    require("total_hostile_cap := 10" in director, "Total hostile cap is tunable from ten", failures)
    require("normal_hostile_cap := 9" in director, "Normal cap is tunable from nine", failures)
    require("charger_hostile_cap := 2" in director, "Charger safety cap is tunable from two", failures)
    require("shielded_hostile_cap := 1" in director, "Shielded safety cap is tunable from one", failures)
    require("shooter_hostile_cap := 2" in director, "Shooter safety cap is tunable from two", failures)
    require("boomer_hostile_cap := 1" in director, "Boomer safety cap is tunable from one", failures)
    require("prowler_hostile_cap := 1" in director, "Prowler safety cap is tunable from one", failures)
    require("HEART_RUNNER" not in director, "Heart Runner remains outside EncounterDirector hostile accounting", failures)
    require(
        "first_minute_charger_cap := 1" in director,
        "First-minute Charger production is limited to one",
        failures,
    )
    require(
        "get_shielded_hostile_count() < shielded_hostile_cap" in director,
        "Shielded enemies use their own cap while still counting in total hostile cap",
        failures,
    )
    require(
        "get_shooter_hostile_count() < shooter_hostile_cap" in director,
        "Shooter enemies use their own cap while still counting in total hostile cap",
        failures,
    )
    require(
        "get_boomer_hostile_count() < boomer_hostile_cap" in director,
        "Boomer enemies use their own cap while still counting in total hostile cap",
        failures,
    )
    require(
        "get_prowler_hostile_count() < prowler_hostile_cap" in director,
        "Prowler enemies use their own cap while still counting in total hostile cap",
        failures,
    )
    require(
        director.count("WaveDefinition.new(") == 4,
        "EncounterDirector still defines exactly four authored waves after adding Bulwark",
        failures,
    )
    require(
        "EnemyKind.BOOMER" not in bulwark_section
        and "EnemyKind.PROWLER" not in bulwark_section,
        "No authored Boomer or Prowler wave membership was added with Bulwark",
        failures,
    )
    require(
        "new_lane_hint: float = -1.0" in director
        and "new_formation_bias_hint: int = -1" in director
        and "var lane_hint: float" in director
        and "var formation_bias_hint: int" in director,
        "SpawnStep exposes optional lane and formation-bias metadata",
        failures,
    )
    require(
        "requires_cap_fit_preflight: bool" in director
        and "wave.requires_cap_fit_preflight" in director,
        "Wave definitions can opt into narrow cap-fit preflight",
        failures,
    )
    require(
        "bulwark_start_population_threshold := 4" in director
        and "bulwark_earliest_time := 58.0" in director,
        "Bulwark exports the approved earliest time and pressure threshold",
        failures,
    )
    require(
        "SpawnStep.new(0.0, EnemyKind.SHIELDED, EdgeRole.PRIMARY, 0.50, Enemy.FormationBias.DIRECT)" in director
        and "SpawnStep.new(0.35, EnemyKind.SHOOTER, EdgeRole.PRIMARY, 0.62)" in director
        and "SpawnStep.new(0.85, EnemyKind.NORMAL, EdgeRole.PRIMARY, 0.34, Enemy.FormationBias.LEFT_FLANK)" in director
        and "SpawnStep.new(1.2, EnemyKind.NORMAL, EdgeRole.PRIMARY, 0.74, Enemy.FormationBias.RIGHT_FLANK)" in director,
        "Bulwark step composition, timing, lane hints, and authored formation-bias hints match the approved definition",
        failures,
    )
    require(
        "WAVE_BULWARK,\n\t\t\tbulwark_earliest_time,\n\t\t\t1.75,\n\t\t\t3.0,\n\t\t\tbulwark_start_population_threshold,\n\t\t\tfalse,\n\t\t\ttrue," in director,
        "Bulwark uses one announced edge plus cap-fit preflight while keeping the standard telegraph and recovery",
        failures,
    )
    require(
        "SpawnStep.new(0.0, EnemyKind.NORMAL, EdgeRole.PRIMARY)," in director
        and "SpawnStep.new(0.45, EnemyKind.NORMAL, EdgeRole.OPPOSITE)," in director
        and "SpawnStep.new(1.2, EnemyKind.CHARGER, EdgeRole.PRIMARY)," in director,
        "Rush, Pincer, and Charger Hunt keep their existing spawn-step definitions without accidental lane/bias metadata",
        failures,
    )
    require(
        "get_total_hostile_count() + wave.steps.size() > total_hostile_cap" in director
        and "normal_hostile_cap" in director
        and "shielded_hostile_cap" in director
        and "shooter_hostile_cap" in director,
        "Bulwark cap-fit preflight checks total, Normal, Shielded, and Shooter capacity before telegraph",
        failures,
    )
    require(
        "formation_bias_hint" in director
        and "lane_hint" in director
        and "spawn_requested.emit(" in director,
        "Resolved wave requests carry optional lane and formation-bias metadata forward to Main",
        failures,
    )
    require(
        "_find_safe_spawn_position_for_lane" in main_script
        and "find_safe_spawn_position_along_edge_lane" in arena
        and "formation_bias_hint != EncounterDirector.INVALID_FORMATION_BIAS_HINT" in main_script,
        "Main and Arena apply Bulwark lane hints and authored bias hints through the existing spawn seam",
        failures,
    )
    require(
        "_get_next_formation_bias(spawn_source == SpawnSource.DEBUG)" in main_script
        and "formation_bias_hint != EncounterDirector.INVALID_FORMATION_BIAS_HINT" in main_script,
        "Explicit Bulwark formation-bias hints do not consume the ordinary assignment sequence",
        failures,
    )
    require(
        "get_spawn_position_for_edge_lane" in arena
        and "lane_offsets.append(offset)" in arena
        and "lane_offsets.append(-offset)" in arena
        and "return INVALID_SPAWN_POSITION" in arena,
        "Lane-hinted spawn fallback stays deterministic, same-edge, and safely retryable",
        failures,
    )
    require(
        "anchor" not in director.lower()
        and "cover_hold" not in director.lower()
        and "side-peek" not in director.lower()
        and "multikill" not in director.lower(),
        "EncounterDirector does not hard-code Shooter/Shielded combat behavior or multikill logic for Bulwark",
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
        "base_spawn_interval := 2.2" in main_script
        and "minimum_spawn_interval := 0.75" in main_script
        and "spawn_interval_drop_per_second := 0.006" in main_script,
        "Ambient spawn-rate curve uses the slower density ramp",
        failures,
    )
    require(
        "charger_unlock_time := 15.0" in main_script
        and "charger_spawn_chance_at_unlock := 0.08" in main_script
        and "charger_spawn_chance_growth_per_second := 0.001" in main_script
        and "maximum_charger_spawn_chance := 0.22" in main_script,
        "Charger ambient tuning unlocks earlier but starts uncommon",
        failures,
    )
    require(
        "charger_intro_target_time_min := 15.0" in main_script
        and "charger_intro_target_time_max := 21.0" in main_script
        and "charger_intro_seen" in main_script
        and "charger_intro_target_time = rng.randf_range" in main_script,
        "Charger first intro uses a randomized per-run target",
        failures,
    )
    require(
        "shielded_unlock_time := 25.0" in main_script
        and "shielded_spawn_chance_at_unlock := 0.05" in main_script
        and "shielded_spawn_chance_growth_per_second := 0.0006" in main_script
        and "maximum_shielded_spawn_chance := 0.12" in main_script,
        "Shielded ambient tuning unlocks earlier but remains rare",
        failures,
    )
    require(
        "shielded_intro_target_time_min := 25.0" in main_script
        and "shielded_intro_target_time_max := 30.0" in main_script
        and "shielded_intro_seen" in main_script
        and "shielded_intro_target_time = rng.randf_range" in main_script,
        "Shielded first intro uses a randomized per-run target",
        failures,
    )
    require(
        "shooter_unlock_time := 42.0" in main_script
        and "shooter_spawn_chance_at_unlock := 0.04" in main_script
        and "shooter_spawn_chance_growth_per_second := 0.00045" in main_script
        and "maximum_shooter_spawn_chance := 0.10" in main_script,
        "Shooter ambient tuning arrives later and stays uncommon",
        failures,
    )
    require(
        "shooter_intro_target_time_min := 42.0" in main_script
        and "shooter_intro_target_time_max := 52.0" in main_script
        and "shooter_intro_seen" in main_script
        and "shooter_intro_target_time = rng.randf_range" in main_script,
        "Shooter first intro uses a randomized per-run target",
        failures,
    )
    require(
        "boomer_unlock_time := 65.0" in main_script
        and "boomer_spawn_chance_at_unlock := 0.025" in main_script
        and "boomer_spawn_chance_growth_per_second := 0.00035" in main_script
        and "maximum_boomer_spawn_chance := 0.07" in main_script,
        "Boomer ambient tuning stays late-run and uncommon",
        failures,
    )
    require(
        "boomer_intro_target_time_min := 65.0" in main_script
        and "boomer_intro_target_time_max := 78.0" in main_script
        and "boomer_intro_seen" in main_script
        and "boomer_intro_target_time = rng.randf_range" in main_script,
        "Boomer first intro uses a randomized per-run target",
        failures,
    )
    require(
        "prowler_unlock_time := 78.0" in main_script
        and "prowler_spawn_chance_at_unlock := 0.03" in main_script
        and "prowler_spawn_chance_growth_per_second := 0.00030" in main_script
        and "maximum_prowler_spawn_chance := 0.08" in main_script,
        "Prowler ambient tuning arrives latest and stays uncommon",
        failures,
    )
    require(
        "prowler_intro_target_time_min := 78.0" in main_script
        and "prowler_intro_target_time_max := 88.0" in main_script
        and "prowler_intro_seen" in main_script
        and "prowler_intro_target_time = rng.randf_range" in main_script,
        "Prowler first intro uses a randomized per-run target",
        failures,
    )
    require(
        "func _pick_pending_intro_enemy_kind" in main_script
        and "pending_candidates.sort_custom(_sort_intro_candidates_by_target_time)" in main_script
        and "return _pick_weighted_ambient_enemy_kind()" in main_script,
        "Pending introductions are tried before the unchanged weighted selector",
        failures,
    )
    require(
        "enum SpawnSource" in main_script
        and "SpawnSource.AMBIENT" in main_script
        and "SpawnSource.WAVE" in main_script
        and "SpawnSource.DEBUG" in main_script
        and "if spawn_source == SpawnSource.DEBUG:" in main_script,
        "Intro bookkeeping is source-aware and excludes debug spawns",
        failures,
    )
    require(
        "func debug_set_intro_target_sequence" in main_script
        and "func debug_set_ambient_roll_sequence" in main_script,
        "Intro behavior has deterministic audit hooks",
        failures,
    )
    require(
        "first_wave_time_min := 28.0" in director
        and "first_wave_time_max := 34.0" in director
        and "inter_wave_interval_min := 18.0" in director
        and "inter_wave_interval_max := 24.0" in director,
        "Wave calendar timing remains unchanged",
        failures,
    )
    require(
        "WAVE_CHARGER_HUNT,\n\t\t\t48.0,\n\t\t\t1.75,\n\t\t\t3.0," in director,
        "Charger Hunt earliest time and wave telegraph/recovery remain unchanged",
        failures,
    )
    require(
        "WAVE_BULWARK,\n\t\t\tbulwark_earliest_time,\n\t\t\t1.75,\n\t\t\t3.0," in director,
        "Bulwark earliest time and wave telegraph/recovery use the approved live values",
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
    require(
        "Bulwark" in readme
        and "Bulwark" in roadmap
        and "bulwark_earliest_time" in tuning
        and "bulwark_start_population_threshold" in tuning,
        "README, ROADMAP, and TUNING document the live Bulwark wave",
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
