from __future__ import annotations

from array import array
import hashlib
import math
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAYER_ACTION_POOLS = {
    "throw": ["throw.wav", "throw_alt_01.wav", "throw_alt_02.wav"],
    "dodge": ["dodge.wav", "dodge_alt_01.wav", "dodge_alt_02.wav"],
    "hurt": ["player_hurt.wav", "player_hurt_alt_01.wav", "player_hurt_alt_02.wav"],
}
DURATION_LIMITS = {
    "throw": (0.15, 0.21),
    "dodge": (0.16, 0.23),
    "hurt": (0.10, 0.16),
}


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        failures.append(message)
        print(f"FAIL: {message}")


def inspect_wav(path: Path) -> dict[str, float | int | bytes]:
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
            "frames": frames,
        }


def main() -> int:
    failures: list[str] = []
    main_script = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
    generator = (ROOT / "tools/generate_sfx.py").read_text(encoding="utf-8")
    main_scene = (ROOT / "Main.tscn").read_text(encoding="utf-8")

    for category, filenames in PLAYER_ACTION_POOLS.items():
        require(len(filenames) == 3, f"{category} pool contains exactly three clips", failures)
        metrics: list[dict[str, float | int | bytes]] = []
        hashes: list[str] = []
        for filename in filenames:
            path = ROOT / "audio" / filename
            import_path = Path(f"{path}.import")
            require(path.exists(), f"audio/{filename} exists", failures)
            require(import_path.exists(), f"audio/{filename}.import exists", failures)
            if not path.exists():
                continue
            metric = inspect_wav(path)
            metrics.append(metric)
            hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
            require(metric["channels"] == 1, f"audio/{filename} is mono", failures)
            require(metric["sample_width"] == 2, f"audio/{filename} is 16-bit PCM", failures)
            require(metric["sample_rate"] == 44100, f"audio/{filename} uses 44.1 kHz", failures)
            minimum, maximum = DURATION_LIMITS[category]
            require(minimum <= metric["duration"] <= maximum, f"audio/{filename} duration is appropriate", failures)
            require(metric["peak"] >= 0.45, f"audio/{filename} has audible peak samples", failures)
            require(metric["rms"] >= 0.015, f"audio/{filename} contains meaningful non-silent audio", failures)
            if import_path.exists():
                import_text = import_path.read_text(encoding="utf-8")
                require('importer="wav"' in import_text, f"audio/{filename} uses the WAV importer", failures)

        if len(hashes) == 3:
            require(len(set(hashes)) == 3, f"{category} variants are byte-distinct", failures)
        if len(metrics) == 3:
            rms_db = [20.0 * math.log10(max(float(metric["rms"]), 0.000001)) for metric in metrics]
            require(max(rms_db) - min(rms_db) <= 8.0, f"{category} variants have reasonably matched RMS loudness", failures)

    require("var audio_rng := RandomNumberGenerator.new()" in main_script, "Player-action selection owns a dedicated audio RNG", failures)
    require("rng.randomize()" in main_script and "audio_rng.randomize()" in main_script, "Gameplay and audio RNGs initialize independently", failures)
    selection_block = main_script.split("func _select_player_action_sfx_index", 1)[1].split("func _get_last_player_action_sfx_index", 1)[0]
    require("audio_rng.randi_range" in selection_block and "rng.randi_range" not in selection_block.replace("audio_rng.randi_range", ""), "Variant selection cannot consume gameplay RNG", failures)
    require("last_throw_sfx_index" in main_script and "last_dodge_sfx_index" in main_script and "last_hurt_sfx_index" in main_script, "Throw, dodge, and hurt track repetition independently", failures)
    require("selected_index == last_index" in selection_block and "pool_size > 1" in selection_block, "Selection explicitly avoids immediate repeats", failures)
    require("debug_seed_audio_rng" in main_script and "debug_select_player_action_sfx_index" in main_script, "Variant selection has a deterministic non-gameplay test seam", failures)
    require("generate_throw_variant" in generator and "generate_dodge_variant" in generator and "generate_hurt_variant" in generator, "All alternate player clips are locally reproducible", failures)
    require('volume_db = -5.0' in main_scene, "Existing dodge player mix level remains unchanged", failures)

    if failures:
        print(f"\nPlayer-action audio audit failed with {len(failures)} issue(s).")
        return 1
    print("\nPlayer-action audio audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
