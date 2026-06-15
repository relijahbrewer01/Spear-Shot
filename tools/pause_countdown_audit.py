from __future__ import annotations

from pathlib import Path
import sys


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

    main_script = read_text("scripts/main.gd")
    hud_script = read_text("scripts/hud.gd")

    require("enum RunState" in main_script, "Main defines explicit run states", failures)
    for state_name in ["RUNNING", "PAUSED", "RESUME_COUNTDOWN", "GAME_OVER"]:
        require(state_name in main_script, f"Run state {state_name} exists", failures)

    require("signal pause_toggle_requested" in hud_script, "HUD exposes pause key signal", failures)
    require("signal pause_resume_click_requested" in hud_script, "HUD exposes pause click signal", failures)
    require("signal resume_countdown_finished" in hud_script, "HUD exposes countdown completion signal", failures)
    require("resume_countdown_step_duration := 0.7" in hud_script, "HUD countdown step duration is shortened to 0.7 seconds", failures)
    require("COUNTDOWN_STEP_COUNT := 3" in hud_script, "HUD countdown still uses the 3 2 1 sequence", failures)
    require("Time.get_ticks_msec()" in hud_script, "HUD countdown uses real-time ticking", failures)
    require("hud.start_resume_countdown()" in main_script, "Main starts countdown through HUD", failures)
    require("hud.cancel_resume_countdown()" in main_script, "Main can cancel countdown", failures)
    require("hud.resume_countdown_finished.connect(_on_resume_countdown_finished)" in main_script, "Main listens for countdown completion", failures)
    require("get_tree().paused = should_pause" in main_script, "Pause uses SceneTree pause", failures)
    require("get_tree().paused = false" in main_script, "Countdown completion clears SceneTree pause", failures)
    require("pause_backdrop.visible and event is InputEventMouseButton" in hud_script, "Pause clicks are consumed by HUD", failures)

    if failures:
        print(f"\nPause countdown audit failed with {len(failures)} issue(s).")
        return 1

    print("\nPause countdown audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
