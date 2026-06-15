from __future__ import annotations

import math
import random
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "audio"
TARGET_PEAK = 0.92


def clamp_sample(value: float) -> int:
    value = max(-1.0, min(1.0, value))
    return int(value * 32767)


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    samples = apply_fade(normalize(samples))
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            sample_value = clamp_sample(sample)
            frames.extend(sample_value.to_bytes(2, byteorder="little", signed=True))
        wav_file.writeframes(frames)


def envelope(progress: float, attack: float, decay: float) -> float:
    if progress < attack:
        return progress / attack
    if progress > 1.0 - decay:
        return max((1.0 - progress) / decay, 0.0)
    return 1.0


def normalize(samples: list[float]) -> list[float]:
    peak = max((abs(sample) for sample in samples), default=0.0)
    if peak <= 0.00001:
        return samples
    gain = TARGET_PEAK / peak
    return [sample * gain for sample in samples]


def apply_fade(samples: list[float], fade_ms: float = 4.0) -> list[float]:
    fade_length = min(int(SAMPLE_RATE * fade_ms / 1000.0), len(samples) // 2)
    if fade_length <= 0:
        return samples

    faded = list(samples)
    for index in range(fade_length):
        fade_in = index / fade_length
        fade_out = (fade_length - index) / fade_length
        faded[index] *= fade_in
        faded[-index - 1] *= fade_out
    return faded


def generate_throw() -> list[float]:
    length = int(SAMPLE_RATE * 0.18)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        airy_noise = (random.random() * 2.0 - 1.0) * (1.0 - progress)
        tone = math.sin(progress * 22.0 * math.pi) * 0.22
        whistle = math.sin(2.0 * math.pi * (420.0 + progress * 220.0) * index / SAMPLE_RATE) * 0.16
        samples.append((airy_noise * 0.36 + tone + whistle) * envelope(progress, 0.02, 0.65))
    return samples


def generate_hit() -> list[float]:
    length = int(SAMPLE_RATE * 0.10)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 320.0 - progress * 120.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        noise = (random.random() * 2.0 - 1.0) * 0.45
        transient = math.sin(2.0 * math.pi * 920.0 * index / SAMPLE_RATE) * 0.18 * (1.0 - progress)
        samples.append((tone * 0.55 + noise * 0.28 + transient) * envelope(progress, 0.01, 0.82))
    return samples


def generate_enemy_death() -> list[float]:
    length = int(SAMPLE_RATE * 0.20)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 220.0 - progress * 80.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        overtone = math.sin(2.0 * math.pi * (frequency * 1.6) * index / SAMPLE_RATE) * 0.4
        noise = (random.random() * 2.0 - 1.0) * 0.25
        burst = math.sin(2.0 * math.pi * 120.0 * index / SAMPLE_RATE) * 0.3
        samples.append((tone * 0.5 + overtone * 0.25 + burst + noise * 0.32) * envelope(progress, 0.01, 0.72))
    return samples


def generate_pickup() -> list[float]:
    length = int(SAMPLE_RATE * 0.15)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 560.0 + progress * 220.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        harmonic = math.sin(2.0 * math.pi * frequency * 2.0 * index / SAMPLE_RATE) * 0.25
        sparkle = math.sin(2.0 * math.pi * (frequency * 3.0) * index / SAMPLE_RATE) * 0.12
        samples.append((tone * 0.48 + harmonic + sparkle) * envelope(progress, 0.01, 0.5))
    return samples


def generate_hurt() -> list[float]:
    length = int(SAMPLE_RATE * 0.13)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 180.0 - progress * 40.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        harsh_noise = (random.random() * 2.0 - 1.0) * 0.5
        growl = math.sin(2.0 * math.pi * 92.0 * index / SAMPLE_RATE) * 0.2
        samples.append((tone * 0.4 + harsh_noise * 0.4 + growl) * envelope(progress, 0.01, 0.82))
    return samples


def generate_game_over() -> list[float]:
    length = int(SAMPLE_RATE * 0.48)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 420.0 - progress * 240.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        undertone = math.sin(2.0 * math.pi * (frequency * 0.5) * index / SAMPLE_RATE) * 0.28
        samples.append((tone * 0.4 + undertone) * envelope(progress, 0.02, 0.22))
    return samples


def generate_dodge() -> list[float]:
    length = int(SAMPLE_RATE * 0.17)
    samples: list[float] = []
    filtered_noise = 0.0
    previous_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        high_noise = raw_noise - previous_noise
        previous_noise = raw_noise
        filtered_noise = filtered_noise * 0.72 + high_noise * 0.28
        airy_curve = math.sin(progress * math.pi)
        cloth_tone = math.sin(2.0 * math.pi * (260.0 + progress * 90.0) * index / SAMPLE_RATE)
        samples.append(
            (filtered_noise * 0.66 + cloth_tone * 0.08)
            * airy_curve
            * envelope(progress, 0.03, 0.62)
        )
    return samples


def main() -> None:
    random.seed(42)
    sounds = {
        "throw.wav": generate_throw(),
        "enemy_hit.wav": generate_hit(),
        "enemy_death.wav": generate_enemy_death(),
        "pickup.wav": generate_pickup(),
        "player_hurt.wav": generate_hurt(),
        "game_over.wav": generate_game_over(),
        "dodge.wav": generate_dodge(),
    }
    for filename, samples in sounds.items():
        write_wav(OUTPUT_DIR / filename, samples)


if __name__ == "__main__":
    main()
