from __future__ import annotations

from array import array
import hashlib
import math
from pathlib import Path
import sys
import wave


ROOT = Path(__file__).resolve().parents[1]
RECOVERY_PATH = ROOT / "audio" / "spear_recover.wav"


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        failures.append(message)
        print(f"FAIL: {message}")


def inspect_wav(path: Path) -> dict[str, float | int]:
    with wave.open(str(path), "rb") as wav_file:
        frames = wav_file.readframes(wav_file.getnframes())
        samples = array("h")
        samples.frombytes(frames)
        if sys.byteorder != "little":
            samples.byteswap()
        peak = max((abs(sample) for sample in samples), default=0) / 32767.0
        rms = math.sqrt(sum(sample * sample for sample in samples) / max(len(samples), 1)) / 32767.0
        return {
            "channels": wav_file.getnchannels(),
            "sample_width": wav_file.getsampwidth(),
            "sample_rate": wav_file.getframerate(),
            "duration": wav_file.getnframes() / wav_file.getframerate(),
            "peak": peak,
            "rms": rms,
        }


def main() -> int:
    failures: list[str] = []
    main_script = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
    spear_script = (ROOT / "scripts/spear.gd").read_text(encoding="utf-8")
    main_scene = (ROOT / "Main.tscn").read_text(encoding="utf-8")
    generator = (ROOT / "tools/generate_sfx.py").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    roadmap = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")
    tuning = (ROOT / "TUNING.md").read_text(encoding="utf-8")

    require(RECOVERY_PATH.exists(), "audio/spear_recover.wav exists", failures)
    require(Path(f"{RECOVERY_PATH}.import").exists(), "audio/spear_recover.wav.import exists", failures)
    if RECOVERY_PATH.exists():
        metrics = inspect_wav(RECOVERY_PATH)
        require(metrics["channels"] == 1, "Spear recovery cue is mono", failures)
        require(metrics["sample_width"] == 2, "Spear recovery cue is 16-bit PCM", failures)
        require(metrics["sample_rate"] == 44100, "Spear recovery cue uses 44.1 kHz", failures)
        require(0.12 <= metrics["duration"] <= 0.20, "Spear recovery cue has the approved short duration", failures)
        require(metrics["peak"] >= 0.45, "Spear recovery cue has audible peak content", failures)
        require(metrics["rms"] >= 0.015, "Spear recovery cue contains meaningful non-silent audio", failures)
        recovery_hash = hashlib.sha256(RECOVERY_PATH.read_bytes()).hexdigest()
        comparison_paths = [
            ROOT / "audio" / "pickup.wav",
            ROOT / "audio" / "throw.wav",
            ROOT / "audio" / "throw_alt_01.wav",
            ROOT / "audio" / "throw_alt_02.wav",
            ROOT / "audio" / "heart_pickup_collect.wav",
        ]
        comparison_hashes = {
            hashlib.sha256(path.read_bytes()).hexdigest()
            for path in comparison_paths
            if path.exists()
        }
        require(recovery_hash not in comparison_hashes, "Spear recovery cue is byte-distinct from throw and reward sounds", failures)

    require("generate_spear_recover" in generator and '"spear_recover.wav": generate_spear_recover()' in generator, "Recovery cue is reproducible through the local SFX generator", failures)
    require('path="res://audio/spear_recover.wav"' in main_scene, "PickupPlayer explicitly uses the spear recovery stream", failures)
    pickup_node = main_scene.split('[node name="PickupPlayer"', 1)[1].split("[node name=", 1)[0]
    require('bus = &"SFX"' in pickup_node, "Spear recovery cue remains on the SFX bus", failures)

    pickup_block = main_script.split("func _on_spear_picked_up", 1)[1].split("func _on_wave_telegraph_started", 1)[0]
    require("_play_sfx(pickup_player)" in pickup_block, "Main plays recovery directly from the picked_up signal", failures)
    require("audio_rng" not in pickup_block and "rng." not in pickup_block, "Recovery playback consumes no audio or gameplay RNG", failures)
    require("spear.picked_up.connect(_on_spear_picked_up)" in main_script, "Main listens to the authoritative spear pickup event", failures)

    pickup_method = spear_script.split("func _pickup()", 1)[1].split("func _push_trail_point", 1)[0]
    require("state != State.LANDED or pickup_in_progress" in pickup_method, "Pickup authority rejects non-landed and duplicate recovery callbacks", failures)
    require(pickup_method.index("_set_state(State.HELD)") < pickup_method.index("picked_up.emit()"), "Spear reaches HELD before emitting picked_up", failures)
    reset_method = spear_script.split("func reset_for_new_run", 1)[1].split("func set_active", 1)[0]
    require("picked_up.emit()" not in reset_method, "Reset/equip cannot emit the recovery event", failures)
    landed_method = spear_script.split("func _enter_landed_state", 1)[1].split("func apply_landed_shockwave_nudge", 1)[0]
    require("picked_up.emit()" not in landed_method, "FLYING to LANDED cannot emit the recovery event", failures)
    game_over_block = main_script.split("func _on_player_died", 1)[1].split("func _on_spear_thrown", 1)[0]
    require("pickup_player.stop()" in game_over_block, "Game over stops an active recovery cue", failures)
    require(main_script.count("pickup_player,") >= 2, "Restart and teardown audio cleanup include the recovery player", failures)

    require("spear-retrieval confirmation cue" in readme.lower(), "README documents the recovery-only cue", failures)
    require("spear_recover.wav" in readme, "README lists the generated recovery asset", failures)
    require(
        "legitimate landed-spear recovery" in roadmap.lower()
        and "legitimate" in tuning.lower(),
        "ROADMAP and TUNING document legitimate recovery semantics",
        failures,
    )
    require("Spear Shot v0.6.0-alpha.4.1 - Input & Audio Polish" in readme, "Milestone remains Phase 4 Interlude 1", failures)

    if failures:
        print(f"\nSpear recovery audio audit failed with {len(failures)} issue(s).")
        return 1
    print("\nSpear recovery audio audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
