from __future__ import annotations

from array import array
import hashlib
import math
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TRACKS = ["quiet_hunter_loop.wav", "quiet_hunter_loop_02.wav"]


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
    generator = (ROOT / "tools/generate_music.py").read_text(encoding="utf-8")
    main_scene = (ROOT / "Main.tscn").read_text(encoding="utf-8")
    metrics: list[dict[str, float | int]] = []
    hashes: list[str] = []

    for filename in TRACKS:
        path = ROOT / "music" / filename
        import_path = Path(f"{path}.import")
        require(path.exists(), f"music/{filename} exists", failures)
        require(import_path.exists(), f"music/{filename}.import exists", failures)
        if not path.exists():
            continue
        metric = inspect_wav(path)
        metrics.append(metric)
        hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
        require(metric["channels"] == 2, f"music/{filename} is stereo", failures)
        require(metric["sample_width"] == 2, f"music/{filename} is 16-bit PCM", failures)
        require(metric["sample_rate"] == 44100, f"music/{filename} uses 44.1 kHz", failures)
        require(metric["duration"] >= 40.0, f"music/{filename} is a long-form gameplay loop", failures)
        require(metric["peak"] >= 0.60, f"music/{filename} has audible peak content", failures)
        require(metric["rms"] >= 0.01, f"music/{filename} contains meaningful waveform content", failures)
        if import_path.exists():
            import_text = import_path.read_text(encoding="utf-8")
            require('importer="wav"' in import_text, f"music/{filename} uses the WAV importer", failures)
            require("edit/loop_mode=1" in import_text, f"music/{filename} is configured for forward looping", failures)

    if len(metrics) == 2:
        require(abs(float(metrics[0]["duration"]) - float(metrics[1]["duration"])) <= 0.01, "Both loops share the same cycle duration", failures)
        peak_db = [20.0 * math.log10(max(float(metric["peak"]), 0.000001)) for metric in metrics]
        rms_db = [20.0 * math.log10(max(float(metric["rms"]), 0.000001)) for metric in metrics]
        require(abs(peak_db[0] - peak_db[1]) <= 1.0, "Both loops have closely matched peak loudness", failures)
        require(abs(rms_db[0] - rms_db[1]) <= 4.0, "Both loops have reasonably matched RMS loudness", failures)
    if len(hashes) == 2:
        require(hashes[0] != hashes[1], "The second music loop is byte-distinct from the original", failures)

    require("OUTPUT_PATH_02" in generator and "build_track_02" in generator, "Music generator reproduces both loops", failures)
    require('"res://music/quiet_hunter_loop.wav"' in main_script and '"res://music/quiet_hunter_loop_02.wav"' in main_script, "Main defines the two-track cycle explicitly", failures)
    require("current_music_track_index := 0" in main_script, "Application launch begins on track 1", failures)
    require("_advance_music_track_for_new_run()" in main_script.split("func _restart_run", 1)[1].split("func _start_screen_shake", 1)[0], "Only restart advances the fresh-run music selection", failures)
    require("current_music_track_index + 1" in main_script, "Music selection alternates deterministically without RNG", failures)
    require("_load_music_stream_or_fallback" in main_script and "return original_music_stream" in main_script, "Missing alternate music falls back to the original", failures)
    require('bus = &"Music"' in main_scene, "MusicPlayer remains routed to the Music bus", failures)

    if failures:
        print(f"\nMusic cycling audit failed with {len(failures)} issue(s).")
        return 1
    print("\nMusic cycling audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
