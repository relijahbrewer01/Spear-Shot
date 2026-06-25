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
    length = int(SAMPLE_RATE * 0.20)
    samples: list[float] = []
    low_noise = 0.0
    previous_raw_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        low_noise = low_noise * 0.88 + raw_noise * 0.12
        cloth_noise = raw_noise - low_noise
        air_noise = raw_noise - previous_raw_noise
        previous_raw_noise = raw_noise

        body_frequency = 205.0 - progress * 45.0
        body_tone = math.sin(2.0 * math.pi * body_frequency * index / SAMPLE_RATE)
        foot_scuff = math.sin(2.0 * math.pi * 118.0 * index / SAMPLE_RATE)
        air_curve = math.sin(progress * math.pi)
        scuff_curve = math.exp(-((progress - 0.28) / 0.18) ** 2)
        samples.append(
            (
                cloth_noise * 0.48
                + air_noise * 0.20
                + body_tone * 0.22 * (1.0 - progress)
                + foot_scuff * 0.14 * scuff_curve
            )
            * air_curve
            * envelope(progress, 0.02, 0.58)
        )
    return samples


def generate_throw_variant(seed: int, duration: float, pitch_offset: float) -> list[float]:
    rng = random.Random(seed)
    length = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    low_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = rng.random() * 2.0 - 1.0
        low_noise = low_noise * 0.84 + raw_noise * 0.16
        air = raw_noise - low_noise
        effort_frequency = 175.0 + pitch_offset - progress * 24.0
        effort = math.sin(2.0 * math.pi * effort_frequency * index / SAMPLE_RATE)
        shaft_frequency = 390.0 + pitch_offset + progress * 250.0
        shaft_whistle = math.sin(2.0 * math.pi * shaft_frequency * index / SAMPLE_RATE)
        release_curve = math.sin(progress * math.pi) * (1.0 - progress * 0.42)
        samples.append(
            (
                air * 0.42
                + effort * 0.20 * (1.0 - progress)
                + shaft_whistle * 0.15
            )
            * release_curve
            * envelope(progress, 0.02, 0.62)
        )
    return samples


def generate_dodge_variant(seed: int, duration: float, body_pitch: float) -> list[float]:
    rng = random.Random(seed)
    length = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    low_noise = 0.0
    previous_raw_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = rng.random() * 2.0 - 1.0
        low_noise = low_noise * 0.90 + raw_noise * 0.10
        cloth_noise = raw_noise - low_noise
        air_noise = raw_noise - previous_raw_noise
        previous_raw_noise = raw_noise
        body_tone = math.sin(
            2.0 * math.pi * (body_pitch - progress * 38.0) * index / SAMPLE_RATE
        )
        foot_scuff = math.sin(2.0 * math.pi * 108.0 * index / SAMPLE_RATE)
        movement_curve = math.sin(progress * math.pi)
        scuff_curve = math.exp(-((progress - 0.34) / 0.16) ** 2)
        samples.append(
            (
                cloth_noise * 0.46
                + air_noise * 0.18
                + body_tone * 0.24 * (1.0 - progress)
                + foot_scuff * 0.15 * scuff_curve
            )
            * movement_curve
            * envelope(progress, 0.02, 0.58)
        )
    return samples


def generate_hurt_variant(seed: int, duration: float, base_pitch: float) -> list[float]:
    rng = random.Random(seed)
    length = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    low_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = rng.random() * 2.0 - 1.0
        low_noise = low_noise * 0.76 + raw_noise * 0.24
        impact_noise = raw_noise - low_noise
        reaction = math.sin(
            2.0 * math.pi * (base_pitch - progress * 46.0) * index / SAMPLE_RATE
        )
        body_impact = math.sin(2.0 * math.pi * 96.0 * index / SAMPLE_RATE)
        transient = math.exp(-progress * 18.0)
        samples.append(
            (
                reaction * 0.38
                + impact_noise * 0.42
                + body_impact * 0.20 * transient
            )
            * envelope(progress, 0.01, 0.80)
        )
    return samples


def generate_spear_recover() -> list[float]:
    rng = random.Random(4401)
    length = int(SAMPLE_RATE * 0.16)
    samples: list[float] = []
    wood_body = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = rng.random() * 2.0 - 1.0
        wood_body = wood_body * 0.80 + raw_noise * 0.20

        handling_hit = math.exp(-((progress - 0.10) / 0.075) ** 2)
        wood_knock = math.sin(2.0 * math.pi * 188.0 * index / SAMPLE_RATE)
        metal_click = math.sin(2.0 * math.pi * 1120.0 * index / SAMPLE_RATE)

        ready_progress = max((progress - 0.43) / 0.57, 0.0)
        ready_envelope = math.sin(ready_progress * math.pi) if ready_progress > 0.0 else 0.0
        ready_tone = math.sin(
            2.0 * math.pi * (430.0 + ready_progress * 95.0) * index / SAMPLE_RATE
        )
        samples.append(
            (
                wood_knock * 0.42 * handling_hit
                + wood_body * 0.30 * handling_hit
                + metal_click * 0.18 * handling_hit
                + ready_tone * 0.16 * ready_envelope
            )
            * envelope(progress, 0.01, 0.40)
        )
    return samples


def generate_wave_warning() -> list[float]:
    length = int(SAMPLE_RATE * 0.34)
    samples: list[float] = []
    resonant_body = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        resonant_body = resonant_body * 0.91 + raw_noise * 0.09
        knock = math.sin(2.0 * math.pi * (112.0 - progress * 18.0) * index / SAMPLE_RATE)
        horn_breath = math.sin(2.0 * math.pi * 168.0 * index / SAMPLE_RATE)
        knock_decay = math.exp(-progress * 9.0)
        breath_curve = math.sin(progress * math.pi) ** 1.5
        samples.append(
            (
                knock * 0.62 * knock_decay
                + resonant_body * 0.34 * knock_decay
                + horn_breath * 0.12 * breath_curve
            )
            * envelope(progress, 0.015, 0.48)
        )
    return samples


def generate_shield_break() -> list[float]:
    length = int(SAMPLE_RATE * 0.24)
    samples: list[float] = []
    wood_body = 0.0
    previous_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        wood_body = wood_body * 0.84 + raw_noise * 0.16
        crack_noise = raw_noise - previous_noise
        previous_noise = raw_noise

        low_thud = math.sin(2.0 * math.pi * (92.0 - progress * 18.0) * index / SAMPLE_RATE)
        snap = math.sin(2.0 * math.pi * (620.0 + progress * 180.0) * index / SAMPLE_RATE)
        first_crack = math.exp(-((progress - 0.08) / 0.035) ** 2)
        second_crack = math.exp(-((progress - 0.23) / 0.055) ** 2)
        rattle_decay = math.exp(-progress * 7.0)
        samples.append(
            (
                low_thud * 0.55 * rattle_decay
                + wood_body * 0.42 * rattle_decay
                + crack_noise * 0.32 * (first_crack + second_crack)
                + snap * 0.22 * first_crack
            )
            * envelope(progress, 0.008, 0.48)
        )
    return samples


def generate_blowgun_windup() -> list[float]:
    length = int(SAMPLE_RATE * 0.34)
    samples: list[float] = []
    reed_body = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        reed_body = reed_body * 0.9 + raw_noise * 0.1
        pressure_tone = math.sin(2.0 * math.pi * (240.0 + progress * 90.0) * index / SAMPLE_RATE)
        hollow_tone = math.sin(2.0 * math.pi * 118.0 * index / SAMPLE_RATE)
        build_curve = progress ** 1.6
        samples.append(
            (
                reed_body * 0.30
                + pressure_tone * 0.18 * build_curve
                + hollow_tone * 0.10 * build_curve
            )
            * envelope(progress, 0.04, 0.18)
        )
    return samples


def generate_blowgun_fire() -> list[float]:
    length = int(SAMPLE_RATE * 0.14)
    samples: list[float] = []
    previous_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        air_snap = raw_noise - previous_noise
        previous_noise = raw_noise
        puff = math.exp(-progress * 12.0)
        reed_click = math.sin(2.0 * math.pi * (520.0 - progress * 120.0) * index / SAMPLE_RATE)
        tiny_whistle = math.sin(2.0 * math.pi * (820.0 + progress * 120.0) * index / SAMPLE_RATE)
        samples.append(
            (
                air_snap * 0.34 * puff
                + reed_click * 0.28 * puff
                + tiny_whistle * 0.08 * math.sin(progress * math.pi)
            )
            * envelope(progress, 0.008, 0.62)
        )
    return samples


def generate_blowgun_shove() -> list[float]:
    length = int(SAMPLE_RATE * 0.18)
    samples: list[float] = []
    previous_noise = 0.0
    body_resonance = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        swish_noise = raw_noise - previous_noise
        previous_noise = raw_noise
        body_resonance = body_resonance * 0.86 + raw_noise * 0.14

        swish_curve = math.exp(-((progress - 0.26) / 0.17) ** 2)
        thump_curve = math.exp(-((progress - 0.54) / 0.13) ** 2)
        reed_tone = math.sin(2.0 * math.pi * (310.0 - progress * 90.0) * index / SAMPLE_RATE)
        body_thump = math.sin(2.0 * math.pi * 132.0 * index / SAMPLE_RATE)
        samples.append(
            (
                swish_noise * 0.24 * swish_curve
                + reed_tone * 0.22 * swish_curve
                + body_thump * 0.34 * thump_curve
                + body_resonance * 0.20 * thump_curve
            )
            * envelope(progress, 0.01, 0.55)
        )
    return samples


def generate_boomer_hop_prep() -> list[float]:
    length = int(SAMPLE_RATE * 0.18)
    samples: list[float] = []
    body_resonance = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        body_resonance = body_resonance * 0.88 + raw_noise * 0.12
        compression = math.sin(2.0 * math.pi * (132.0 - progress * 24.0) * index / SAMPLE_RATE)
        creak = math.sin(2.0 * math.pi * (286.0 + progress * 34.0) * index / SAMPLE_RATE)
        squash_curve = progress ** 1.4
        samples.append(
            (
                compression * 0.34 * squash_curve
                + creak * 0.18 * squash_curve
                + body_resonance * 0.24 * squash_curve
            )
            * envelope(progress, 0.03, 0.28)
        )
    return samples


def generate_boomer_land() -> list[float]:
    length = int(SAMPLE_RATE * 0.16)
    samples: list[float] = []
    body_resonance = 0.0
    previous_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        impact_noise = raw_noise - previous_noise
        previous_noise = raw_noise
        body_resonance = body_resonance * 0.85 + raw_noise * 0.15
        thud = math.sin(2.0 * math.pi * (108.0 - progress * 20.0) * index / SAMPLE_RATE)
        shell_rattle = math.sin(2.0 * math.pi * 248.0 * index / SAMPLE_RATE)
        impact_curve = math.exp(-progress * 8.0)
        samples.append(
            (
                thud * 0.46 * impact_curve
                + body_resonance * 0.26 * impact_curve
                + impact_noise * 0.24 * impact_curve
                + shell_rattle * 0.12 * impact_curve
            )
            * envelope(progress, 0.006, 0.58)
        )
    return samples


def generate_boomer_fuse() -> list[float]:
    length = int(SAMPLE_RATE * 0.80)
    samples: list[float] = []
    body_noise = 0.0
    pulse_centers = [0.06, 0.38, 0.68]
    pulse_widths = [0.07, 0.06, 0.05]
    pulse_gains = [0.42, 0.54, 0.68]
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        body_noise = body_noise * 0.91 + raw_noise * 0.09
        base_tone = math.sin(2.0 * math.pi * (154.0 + progress * 28.0) * index / SAMPLE_RATE)
        pressure_tone = math.sin(2.0 * math.pi * (242.0 + progress * 82.0) * index / SAMPLE_RATE)
        pulse_energy = 0.0
        for pulse_center, pulse_width, pulse_gain in zip(pulse_centers, pulse_widths, pulse_gains):
            pulse_energy += math.exp(-((progress - pulse_center) / pulse_width) ** 2) * pulse_gain
        samples.append(
            (
                base_tone * 0.10
                + pressure_tone * 0.08 * pulse_energy
                + body_noise * 0.18 * (0.25 + pulse_energy)
            )
            * envelope(progress, 0.02, 0.14)
        )
    return samples


def generate_boomer_explosion() -> list[float]:
    length = int(SAMPLE_RATE * 0.28)
    samples: list[float] = []
    body_resonance = 0.0
    previous_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        blast_noise = raw_noise - previous_noise
        previous_noise = raw_noise
        body_resonance = body_resonance * 0.83 + raw_noise * 0.17
        thump = math.sin(2.0 * math.pi * (96.0 - progress * 18.0) * index / SAMPLE_RATE)
        crack = math.sin(2.0 * math.pi * (510.0 - progress * 130.0) * index / SAMPLE_RATE)
        air_burst = math.sin(2.0 * math.pi * 164.0 * index / SAMPLE_RATE)
        blast_curve = math.exp(-progress * 5.2)
        samples.append(
            (
                thump * 0.56 * blast_curve
                + body_resonance * 0.30 * blast_curve
                + blast_noise * 0.32 * blast_curve
                + crack * 0.14 * blast_curve
                + air_burst * 0.10 * blast_curve
            )
            * envelope(progress, 0.004, 0.44)
        )
    return samples


def generate_heart_runner_appear() -> list[float]:
    length = int(SAMPLE_RATE * 0.14)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 540.0 + progress * 180.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        body = math.sin(2.0 * math.pi * 210.0 * index / SAMPLE_RATE) * 0.18
        samples.append((tone * 0.34 + body * (1.0 - progress)) * envelope(progress, 0.01, 0.52))
    return samples


def generate_heart_runner_alarm() -> list[float]:
    length = int(SAMPLE_RATE * 0.12)
    samples: list[float] = []
    previous_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        chirp_noise = raw_noise - previous_noise
        previous_noise = raw_noise
        chirp_frequency = 760.0 + progress * 220.0
        chirp = math.sin(2.0 * math.pi * chirp_frequency * index / SAMPLE_RATE)
        gasp = math.sin(2.0 * math.pi * (320.0 + progress * 40.0) * index / SAMPLE_RATE)
        scramble_curve = math.exp(-((progress - 0.28) / 0.18) ** 2)
        samples.append(
            (
                chirp * 0.28
                + gasp * 0.14 * (1.0 - progress)
                + chirp_noise * 0.18 * scramble_curve
            )
            * envelope(progress, 0.008, 0.54)
        )
    return samples


def generate_heart_pickup_spawn() -> list[float]:
    length = int(SAMPLE_RATE * 0.16)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 360.0 + progress * 220.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        harmonic = math.sin(2.0 * math.pi * frequency * 2.0 * index / SAMPLE_RATE) * 0.18
        samples.append((tone * 0.38 + harmonic) * envelope(progress, 0.01, 0.44))
    return samples


def generate_heart_pickup_collect() -> list[float]:
    length = int(SAMPLE_RATE * 0.18)
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 480.0 + progress * 300.0
        tone = math.sin(2.0 * math.pi * frequency * index / SAMPLE_RATE)
        sparkle = math.sin(2.0 * math.pi * frequency * 2.5 * index / SAMPLE_RATE) * 0.16
        samples.append((tone * 0.42 + sparkle) * envelope(progress, 0.01, 0.38))
    return samples


def generate_heart_pickup_expire() -> list[float]:
    length = int(SAMPLE_RATE * 0.12)
    samples: list[float] = []
    previous_noise = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        raw_noise = random.random() * 2.0 - 1.0
        whisper = raw_noise - previous_noise
        previous_noise = raw_noise
        tone = math.sin(2.0 * math.pi * (410.0 - progress * 120.0) * index / SAMPLE_RATE)
        samples.append((tone * 0.18 + whisper * 0.16) * envelope(progress, 0.01, 0.60))
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
        "wave_warning.wav": generate_wave_warning(),
        "shield_break.wav": generate_shield_break(),
        "blowgun_windup.wav": generate_blowgun_windup(),
        "blowgun_fire.wav": generate_blowgun_fire(),
        "blowgun_shove.wav": generate_blowgun_shove(),
        "boomer_hop_prep.wav": generate_boomer_hop_prep(),
        "boomer_land.wav": generate_boomer_land(),
        "boomer_fuse.wav": generate_boomer_fuse(),
        "boomer_explosion.wav": generate_boomer_explosion(),
        "heart_runner_appear.wav": generate_heart_runner_appear(),
        "heart_pickup_spawn.wav": generate_heart_pickup_spawn(),
        "heart_pickup_collect.wav": generate_heart_pickup_collect(),
        "heart_pickup_expire.wav": generate_heart_pickup_expire(),
        "heart_runner_alarm.wav": generate_heart_runner_alarm(),
    }
    sounds.update(
        {
            "throw_alt_01.wav": generate_throw_variant(4101, 0.17, -18.0),
            "throw_alt_02.wav": generate_throw_variant(4102, 0.19, 24.0),
            "dodge_alt_01.wav": generate_dodge_variant(4201, 0.18, 188.0),
            "dodge_alt_02.wav": generate_dodge_variant(4202, 0.21, 224.0),
            "player_hurt_alt_01.wav": generate_hurt_variant(4301, 0.12, 164.0),
            "player_hurt_alt_02.wav": generate_hurt_variant(4302, 0.14, 198.0),
            "spear_recover.wav": generate_spear_recover(),
        }
    )
    for filename, samples in sounds.items():
        write_wav(OUTPUT_DIR / filename, samples)


if __name__ == "__main__":
    main()
