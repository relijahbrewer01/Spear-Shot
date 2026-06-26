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

    require("close_hit_stop_distance := 8.0" in main_script, "Close hit-stop distance threshold is defined", failures)
    require("close_hit_stop_duration := 0.045" in main_script, "Close hit-stop duration is bounded to a tiny value", failures)
    require("close_hit_stop_time_scale := 0.05" in main_script, "Close hit-stop uses a near-stop time scale", failures)
    require("hit_stop_active := false" in main_script, "Hit-stop active state is tracked centrally", failures)
    require("hit_stop_restore_token" in main_script, "Hit-stop restore requests are tokenized", failures)
    require("_try_start_close_hit_stop" in main_script, "Main has a centralized hit-stop trigger", failures)
    require("_restore_hit_stop_async" in main_script, "Main restores hit stop through an asynchronous real-time timer", failures)
    require("_cancel_hit_stop()" in main_script, "Main has a shared hit-stop cancellation path", failures)
    require("if hit_stop_active:" in main_script, "Stacked hit-stop requests are ignored", failures)
    require("create_timer(hit_stop_duration, true, false, true)" in main_script, "Hit-stop restore timer ignores time scale", failures)
    require("if run_state != RunState.RUNNING:" in main_script, "Hit stop only starts during the normal running state", failures)
    require("_cancel_hit_stop()" in main_script and "func _on_player_died()" in main_script, "Game over cancels hit stop safely", failures)
    require("_cancel_hit_stop()" in main_script and "func _reset_runtime_state()" in main_script, "Restart/reset clears pending hit stop state", failures)
    require("Engine.time_scale = hit_stop_previous_time_scale" in main_script, "Hit stop restores the previous time scale exactly", failures)

    if failures:
        print(f"\nHit-stop audit failed with {len(failures)} issue(s).")
        return 1

    print("\nHit-stop audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
