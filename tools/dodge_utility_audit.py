from __future__ import annotations

from pathlib import Path
import struct
import sys
import wave


ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        print(f"FAIL: {message}")
        failures.append(message)


def main() -> int:
    failures: list[str] = []

    player_script = read_text("scripts/player.gd")
    main_script = read_text("scripts/main.gd")
    main_scene = read_text("Main.tscn")
    generator_script = read_text("tools/generate_sfx.py")
    dodge_path = ROOT / "audio" / "dodge.wav"

    require("dodge_duration := 0.20" in player_script, "Dodge duration is 0.20 seconds", failures)
    require("dodge_distance := 36.0" in player_script, "Dodge distance is 36 pixels", failures)
    require("dodge_cooldown := 2.0" in player_script, "Shared dodge cooldown is 2.00 seconds", failures)
    require(
        "dodge_exit_invulnerability_duration := 0.10" in player_script
        and "dodge_exit_invulnerability_left" in player_script,
        "Post-dodge grace has a separate 0.10-second timer",
        failures,
    )
    require(
        "invulnerability_left > 0.0 or is_dodging() or dodge_exit_invulnerability_left > 0.0" in player_script,
        "Damage immunity includes hurt invulnerability, active dodge, and exit grace",
        failures,
    )
    require(
        "dodge_exit_invulnerability_left = dodge_exit_invulnerability_duration" in player_script
        and "dodge_exit_invulnerability_left = max(dodge_exit_invulnerability_left - delta, 0.0)" in player_script,
        "Exit grace starts once, counts down, and cannot refresh itself from contact",
        failures,
    )
    require(
        "func try_start_aim_dodge(direction: Vector2) -> bool:" in player_script
        and "return try_start_dodge(direction, true)" in player_script
        and "clear_move_destination()" in player_script,
        "Shift dodge clears prior click-to-move intent",
        failures,
    )
    require(
        "func _suppress_current_movement_actions() -> void:" in player_script
        and "Input.is_action_pressed(action)" in player_script,
        "Shift suppresses only movement actions held when the dodge begins",
        failures,
    )
    require(
        "func _release_suppressed_movement_actions() -> void:" in player_script
        and "suppressed_movement_actions.erase(action)" in player_script,
        "Suppressed movement actions become eligible after release",
        failures,
    )
    require(
        "func try_start_movement_dodge(direction: Vector2) -> bool:" in player_script
        and "return try_start_dodge(direction, false)" in player_script,
        "Space dodge preserves normal movement continuity",
        failures,
    )
    require(
        "suppressed_movement_actions.clear()" in player_script
        and player_script.count("suppressed_movement_actions.clear()") >= 3,
        "Restart, death, and disable clear stale-input suppression",
        failures,
    )
    require(
        "if player.try_start_aim_dodge" in main_script
        and "if player.try_start_movement_dodge" in main_script
        and main_script.count("_play_sfx(dodge_player)") == 2,
        "Dodge sound plays only after a successful Shift or Space dodge",
        failures,
    )
    require(
        'path="res://audio/dodge.wav"' in main_scene
        and '[node name="DodgePlayer" type="AudioStreamPlayer"' in main_scene
        and 'volume_db = -5.0' in main_scene
        and (
            '[node name="DodgePlayer" type="AudioStreamPlayer"'
            in main_scene
            and 'stream = ExtResource("14")\nvolume_db = -5.0\nbus = &"SFX"'
            in main_scene
        ),
        "Dodge sound is assigned modestly to the existing SFX bus",
        failures,
    )
    require(
        '"dodge.wav": generate_dodge()' in generator_script,
        "Dodge sound is reproducible through the local SFX generator",
        failures,
    )

    if dodge_path.exists():
        with wave.open(str(dodge_path), "rb") as dodge_wav:
            duration = dodge_wav.getnframes() / dodge_wav.getframerate()
            frames = dodge_wav.readframes(dodge_wav.getnframes())
            samples = struct.unpack(f"<{len(frames) // 2}h", frames)
            require(dodge_wav.getnchannels() == 1, "Dodge sound is mono", failures)
            require(dodge_wav.getsampwidth() == 2, "Dodge sound is 16-bit PCM", failures)
            require(dodge_wav.getframerate() == 44100, "Dodge sound uses 44.1 kHz", failures)
            require(0.17 <= duration <= 0.24, "Dodge sound duration is within the requested range", failures)
            require(any(sample != 0 for sample in samples), "Dodge sound contains non-silent PCM samples", failures)
    else:
        require(False, "Dodge sound file exists", failures)

    if failures:
        print(f"\nDodge utility audit failed with {len(failures)} issue(s).")
        return 1

    print("\nDodge utility audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
