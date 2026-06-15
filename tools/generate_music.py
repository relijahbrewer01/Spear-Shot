from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT / "music" / "quiet_hunter_loop.wav"
SAMPLE_RATE = 44100
BPM = 82
BEAT = 60.0 / BPM
BARS = 16
DURATION = BARS * 4 * BEAT
TARGET_PEAK = 0.78


NOTE_OFFSETS = {
    "C": 0,
    "C#": 1,
    "Db": 1,
    "D": 2,
    "D#": 3,
    "Eb": 3,
    "E": 4,
    "F": 5,
    "F#": 6,
    "Gb": 6,
    "G": 7,
    "G#": 8,
    "Ab": 8,
    "A": 9,
    "A#": 10,
    "Bb": 10,
    "B": 11,
}


def note_frequency(name: str) -> float:
    pitch = name[:-1]
    octave = int(name[-1])
    midi = 12 * (octave + 1) + NOTE_OFFSETS[pitch]
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def envelope(length: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(length, dtype=np.float32)
    attack_count = max(1, int(length * attack))
    release_count = max(1, int(length * release))
    env[:attack_count] = np.linspace(0.0, 1.0, attack_count, dtype=np.float32)
    env[-release_count:] *= np.linspace(1.0, 0.0, release_count, dtype=np.float32)
    return env


def sine_wave(freq: float, t: np.ndarray, phase: float = 0.0) -> np.ndarray:
    return np.sin((2.0 * math.pi * freq * t) + phase)


def triangle_wave(freq: float, t: np.ndarray) -> np.ndarray:
    cycle = (freq * t) % 1.0
    return 1.0 - (4.0 * np.abs(cycle - 0.5))


def soft_pulse_wave(freq: float, t: np.ndarray) -> np.ndarray:
    cycle = (freq * t) % 1.0
    square = np.where(cycle < 0.42, 1.0, -1.0)
    return (square * 0.55) + (triangle_wave(freq, t) * 0.45)


def add_voice(
    buffer: np.ndarray,
    start_time: float,
    duration: float,
    frequencies: list[float],
    amplitude: float,
    voice: str,
    pan: float,
    attack: float,
    release: float,
) -> None:
    start_index = int(start_time * SAMPLE_RATE)
    sample_count = int(duration * SAMPLE_RATE)
    end_index = min(start_index + sample_count, buffer.shape[1])
    sample_count = end_index - start_index
    if sample_count <= 0:
        return

    t = np.arange(sample_count, dtype=np.float32) / SAMPLE_RATE
    wave_data = np.zeros(sample_count, dtype=np.float32)

    for note_index, frequency in enumerate(frequencies):
        if voice == "triangle":
            wave_data += triangle_wave(frequency, t) * (0.9 - note_index * 0.12)
        elif voice == "pulse":
            wave_data += soft_pulse_wave(frequency, t) * (0.8 - note_index * 0.1)
        else:
            wave_data += sine_wave(frequency, t, note_index * 0.12) * (0.85 - note_index * 0.15)

    wave_data /= max(len(frequencies), 1)
    wave_data *= envelope(sample_count, attack, release) * amplitude

    left_gain = math.cos(pan * math.pi * 0.5)
    right_gain = math.sin(pan * math.pi * 0.5)
    buffer[0, start_index:end_index] += wave_data * left_gain
    buffer[1, start_index:end_index] += wave_data * right_gain


def build_track() -> np.ndarray:
    total_samples = int(DURATION * SAMPLE_RATE)
    mix = np.zeros((2, total_samples), dtype=np.float32)

    progression = [
        ["D3", "A3", "B3", "E4"],
        ["G2", "D3", "A3", "E4"],
        ["Bb2", "F3", "A3", "D4"],
        ["C3", "G3", "D4", "E4"],
        ["D3", "A3", "C4", "E4"],
        ["G2", "D3", "E3", "B3"],
        ["Bb2", "F3", "A3", "D4"],
        ["A2", "E3", "G3", "D4"],
    ]

    melody_bars = [
        ["A4", None, "B4", "F4"],
        ["G4", None, "E4", None],
        ["F4", "A4", None, "D4"],
        ["E4", None, "G4", None],
        ["A4", None, "C5", "B4"],
        ["G4", None, "E4", None],
        ["F4", "D4", None, "A4"],
        ["E4", None, "D4", None],
    ]

    for bar in range(BARS):
        chord = progression[bar % len(progression)]
        bar_start = bar * 4 * BEAT

        add_voice(
            mix,
            bar_start,
            4 * BEAT,
            [note_frequency(note) for note in chord],
            amplitude=0.13,
            voice="sine",
            pan=0.5,
            attack=0.08,
            release=0.1,
        )

        bass_root = note_frequency(chord[0])
        for beat_index in range(4):
            add_voice(
                mix,
                bar_start + beat_index * BEAT,
                BEAT * 0.95,
                [bass_root],
                amplitude=0.12 if beat_index == 0 else 0.08,
                voice="triangle",
                pan=0.42,
                attack=0.03,
                release=0.2,
            )

        eighth_notes = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]
        arp_pattern = [0, 2, 1, 3, 2, 1, 0, 1]
        for slot, chord_index in zip(eighth_notes, arp_pattern):
            add_voice(
                mix,
                bar_start + (slot * BEAT),
                BEAT * 0.42,
                [note_frequency(chord[chord_index])],
                amplitude=0.075,
                voice="pulse",
                pan=0.28,
                attack=0.04,
                release=0.35,
            )

        melody = melody_bars[bar % len(melody_bars)]
        if bar >= 8:
            melody = melody[-1:] + melody[:-1]

        for beat_index, note_name in enumerate(melody):
            if note_name is None:
                continue
            add_voice(
                mix,
                bar_start + beat_index * BEAT,
                BEAT * 1.35,
                [note_frequency(note_name)],
                amplitude=0.085,
                voice="sine",
                pan=0.72,
                attack=0.08,
                release=0.3,
            )

    peak = np.max(np.abs(mix))
    if peak > 0:
        mix *= TARGET_PEAK / peak

    fade_samples = int(SAMPLE_RATE * 0.02)
    fade = np.linspace(0.0, 1.0, fade_samples, dtype=np.float32)
    mix[:, :fade_samples] *= fade
    mix[:, -fade_samples:] *= fade[::-1]
    return mix


def write_wav(path: Path, mix: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    interleaved = np.empty(mix.shape[1] * 2, dtype=np.int16)
    clipped = np.clip(mix.T, -1.0, 1.0)
    interleaved[0::2] = (clipped[:, 0] * 32767.0).astype(np.int16)
    interleaved[1::2] = (clipped[:, 1] * 32767.0).astype(np.int16)

    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(interleaved.tobytes())


def main() -> None:
    write_wav(OUTPUT_PATH, build_track())


if __name__ == "__main__":
    main()
