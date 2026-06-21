from __future__ import annotations

import argparse
import math
import random
import re
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_SCRIPT_PATH = ROOT / "scripts" / "main.gd"
HEART_RUNNER_SCRIPT_PATH = ROOT / "scripts" / "heart_runner.gd"
DEFAULT_TRIALS = 100_000
DEFAULT_LONG_RUN_TRIALS = 25_000
DEFAULT_SEED = 424_242
FIRST_SPAWN_MAX_TIME = 20_000.0
LONG_RUN_HORIZONS = [180.0, 300.0, 600.0]
FIRST_SPAWN_HORIZONS = [60.0, 90.0, 120.0, 180.0]


@dataclass(frozen=True)
class LiveHeartRunnerValues:
    unlock_time: float
    interval_min: float
    interval_max: float
    health_3_chance: float
    health_2_chance: float
    health_1_chance: float
    one_health_grace_duration: float
    speed: float
    cooldown: float
    pickup_lifetime: float
    calm_move_speed: float
    entry_distance: float
    entry_min_duration: float
    wander_duration: float
    startled_duration: float
    flee_min_route_length: float
    cleanup_margin: float

    def chance_for_health(self, health: int) -> float:
        if health == 3:
            return self.health_3_chance
        if health == 2:
            return self.health_2_chance
        if health == 1:
            return self.health_1_chance
        return 0.0


@dataclass(frozen=True)
class OpportunityConfig:
    unlock_time: float
    interval_min: float
    interval_max: float
    chance_by_health: dict[int, float]
    cooldown: float
    grace_seconds: float | None = None

    def chance_for_health(self, health: int) -> float:
        return self.chance_by_health.get(health, 0.0)


@dataclass(frozen=True)
class CandidateConfig:
    key: str
    label: str
    one_hp_chance: float
    grace_seconds: float | None


@dataclass(frozen=True)
class ResolutionPattern:
    key: str
    label: str
    block_duration: float
    assumption_note: str


@dataclass(frozen=True)
class FirstSpawnSummary:
    spawn_probability_by_horizon: dict[float, float]
    no_spawn_probability_by_horizon: dict[float, float]
    mean_first_spawn_time: float | None
    median_first_spawn_time: float | None
    percentile_75: float | None
    percentile_90: float | None
    percentile_95: float | None


@dataclass(frozen=True)
class LongRunSummary:
    expected_spawn_count: float
    probability_zero: float
    probability_one: float
    probability_two_or_more: float
    mean_interval_between_spawns: float | None
    median_interval_between_spawns: float | None
    percentile_90_interval: float | None


class GraceTracker:
    def __init__(self, grace_seconds: float | None) -> None:
        self.grace_seconds = grace_seconds
        self.continuous_one_hp_active_time = 0.0

    def advance(self, duration: float, health: int, running: bool) -> None:
        if self.grace_seconds is None or duration <= 0.0:
            return
        if not running:
            return
        if health == 1:
            self.continuous_one_hp_active_time += duration
        else:
            self.continuous_one_hp_active_time = 0.0

    @property
    def due(self) -> bool:
        return (
            self.grace_seconds is not None
            and self.continuous_one_hp_active_time >= self.grace_seconds
        )

    def reset_after_organic_spawn(self) -> None:
        self.continuous_one_hp_active_time = 0.0

    def reset(self) -> None:
        self.continuous_one_hp_active_time = 0.0


class OpportunityRunState:
    def __init__(self, config: OpportunityConfig) -> None:
        self.config = config
        self.grace_tracker = GraceTracker(config.grace_seconds)
        self.last_time = 0.0
        self.next_eligible_time = 0.0
        self.spawn_times: list[float] = []

    def advance_to(self, current_time: float, health: int, running: bool) -> None:
        if current_time < self.last_time:
            raise ValueError("Simulation time moved backwards.")
        self.grace_tracker.advance(current_time - self.last_time, health, running)
        self.last_time = current_time

    def process_check(
        self,
        current_time: float,
        health: int,
        roll: float,
        *,
        safe_available: bool = True,
        running: bool = True,
        resolution_block_duration: float = 0.0,
    ) -> bool:
        self.advance_to(current_time, health, running)
        if not running:
            return False
        if current_time < self.config.unlock_time:
            return False
        if current_time < self.next_eligible_time:
            return False

        should_force_spawn = health == 1 and self.grace_tracker.due
        should_spawn = should_force_spawn or (
            self.config.chance_for_health(health) > 0.0
            and roll < self.config.chance_for_health(health)
        )
        if not should_spawn:
            return False
        if not safe_available:
            return False

        self.spawn_times.append(current_time)
        self.grace_tracker.reset_after_organic_spawn()
        self.next_eligible_time = current_time + resolution_block_duration + self.config.cooldown
        return True

    def record_debug_spawn(self, current_time: float, health: int, running: bool) -> None:
        self.advance_to(current_time, health, running)

    def reset_for_restart_or_game_over(self, current_time: float, health: int, running: bool) -> None:
        self.advance_to(current_time, health, running)
        self.grace_tracker.reset()
        self.next_eligible_time = 0.0


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
        return
    print(f"FAIL: {message}")
    failures.append(message)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_export_value(script_text: str, variable_name: str) -> float:
    pattern = re.compile(
        rf"@export(?:_range\([^)]*\)\s+)? var {re.escape(variable_name)} := ([0-9.]+)"
    )
    match = pattern.search(script_text)
    if match is None:
        raise ValueError(f"Could not find exported value for {variable_name}.")
    return float(match.group(1))


def load_live_values() -> LiveHeartRunnerValues:
    main_script = read_text(MAIN_SCRIPT_PATH)
    runner_script = read_text(HEART_RUNNER_SCRIPT_PATH)
    return LiveHeartRunnerValues(
        unlock_time=parse_export_value(main_script, "heart_runner_unlock_time"),
        interval_min=parse_export_value(main_script, "heart_runner_roll_interval_min"),
        interval_max=parse_export_value(main_script, "heart_runner_roll_interval_max"),
        health_3_chance=parse_export_value(main_script, "heart_runner_health_3_spawn_chance"),
        health_2_chance=parse_export_value(main_script, "heart_runner_health_2_spawn_chance"),
        health_1_chance=parse_export_value(main_script, "heart_runner_health_1_spawn_chance"),
        one_health_grace_duration=parse_export_value(main_script, "heart_runner_one_health_grace_duration"),
        speed=parse_export_value(main_script, "heart_runner_speed"),
        cooldown=parse_export_value(main_script, "heart_runner_post_resolution_cooldown"),
        pickup_lifetime=parse_export_value(main_script, "heart_pickup_lifetime"),
        calm_move_speed=parse_export_value(runner_script, "calm_move_speed"),
        entry_distance=parse_export_value(runner_script, "entry_distance"),
        entry_min_duration=parse_export_value(runner_script, "entry_min_duration"),
        wander_duration=parse_export_value(runner_script, "wander_duration"),
        startled_duration=parse_export_value(runner_script, "startled_duration"),
        flee_min_route_length=parse_export_value(runner_script, "flee_min_route_length"),
        cleanup_margin=parse_export_value(runner_script, "cleanup_margin"),
    )


def build_candidate_configs(live_values: LiveHeartRunnerValues) -> list[CandidateConfig]:
    return [
        CandidateConfig("A", "Candidate A - previous live baseline", 0.10, None),
        CandidateConfig("B", "Candidate B - chance increase only", 0.15, None),
        CandidateConfig("C", "Candidate C - current chance plus 90s grace", 0.10, 90.0),
        CandidateConfig("D", "Candidate D - approved live configuration", 0.15, 90.0),
        CandidateConfig("E", "Candidate E - 15% chance plus 120s grace", 0.15, 120.0),
    ]


def build_live_opportunity_config(live_values: LiveHeartRunnerValues) -> OpportunityConfig:
    return OpportunityConfig(
        unlock_time=live_values.unlock_time,
        interval_min=live_values.interval_min,
        interval_max=live_values.interval_max,
        chance_by_health={
            4: 0.0,
            3: live_values.health_3_chance,
            2: live_values.health_2_chance,
            1: live_values.health_1_chance,
        },
        cooldown=live_values.cooldown,
        grace_seconds=live_values.one_health_grace_duration,
    )


def build_opportunity_config(
    live_values: LiveHeartRunnerValues,
    candidate: CandidateConfig,
) -> OpportunityConfig:
    return OpportunityConfig(
        unlock_time=live_values.unlock_time,
        interval_min=live_values.interval_min,
        interval_max=live_values.interval_max,
        chance_by_health={
            4: 0.0,
            3: live_values.health_3_chance,
            2: live_values.health_2_chance,
            1: candidate.one_hp_chance,
        },
        cooldown=live_values.cooldown,
        grace_seconds=candidate.grace_seconds,
    )


def build_resolution_patterns(live_values: LiveHeartRunnerValues) -> list[ResolutionPattern]:
    visible_entry_time = max(
        live_values.entry_min_duration,
        live_values.entry_distance / max(live_values.calm_move_speed, 0.001),
    )
    fast_panic_escape_block = (
        visible_entry_time
        + live_values.startled_duration
        + (live_values.flee_min_route_length + live_values.cleanup_margin)
        / max(live_values.speed, 0.001)
    )
    quick_collect_block = visible_entry_time + 0.60
    pickup_expire_block = quick_collect_block + live_values.pickup_lifetime

    return [
        ResolutionPattern(
            "escape",
            "Runner escapes unharmed",
            fast_panic_escape_block,
            (
                "Fast panic-escape upper bound using the live visible-entry gate, "
                "the full 0.40s startled hop, and the minimum legal flee route plus cleanup margin."
            ),
        ),
        ResolutionPattern(
            "collect_quick",
            "Runner defeated, pickup collected quickly",
            quick_collect_block,
            (
                "Conservative quick-success block using the live visible-entry gate plus a short "
                "post-entry defeat-and-collect window."
            ),
        ),
        ResolutionPattern(
            "pickup_expires",
            "Runner defeated, pickup expires",
            pickup_expire_block,
            (
                "Quick defeat followed by the full 7.0s pickup lifetime before resolution."
            ),
        ),
    ]


def percentile(sorted_values: list[float], ratio: float) -> float | None:
    if not sorted_values:
        return None
    if len(sorted_values) == 1:
        return sorted_values[0]
    clamped_ratio = min(max(ratio, 0.0), 1.0)
    index = int(math.ceil(clamped_ratio * len(sorted_values))) - 1
    return sorted_values[max(0, min(index, len(sorted_values) - 1))]


def simulate_first_spawn_times(
    config: OpportunityConfig,
    health: int,
    *,
    trials: int,
    seed: int,
) -> list[float]:
    first_spawn_times: list[float] = []
    rng = random.Random(seed)
    for trial_index in range(trials):
        next_check_time = rng.uniform(config.interval_min, config.interval_max)
        run_state = OpportunityRunState(config)
        first_spawn_time = math.inf

        while next_check_time <= FIRST_SPAWN_MAX_TIME:
            spawned = run_state.process_check(
                next_check_time,
                health,
                rng.random(),
            )
            if spawned:
                first_spawn_time = run_state.spawn_times[-1]
                break
            next_check_time += rng.uniform(config.interval_min, config.interval_max)

        if math.isfinite(first_spawn_time):
            first_spawn_times.append(first_spawn_time)

    return first_spawn_times


def summarize_first_spawn_times(
    first_spawn_times: list[float],
    trials: int,
) -> FirstSpawnSummary:
    sorted_times = sorted(first_spawn_times)
    spawn_probability_by_horizon = {
        horizon: sum(1 for time in sorted_times if time <= horizon) / trials
        for horizon in FIRST_SPAWN_HORIZONS
    }
    no_spawn_probability_by_horizon = {
        horizon: 1.0 - spawn_probability_by_horizon[horizon]
        for horizon in FIRST_SPAWN_HORIZONS
    }
    return FirstSpawnSummary(
        spawn_probability_by_horizon=spawn_probability_by_horizon,
        no_spawn_probability_by_horizon=no_spawn_probability_by_horizon,
        mean_first_spawn_time=statistics.fmean(sorted_times) if sorted_times else None,
        median_first_spawn_time=statistics.median(sorted_times) if sorted_times else None,
        percentile_75=percentile(sorted_times, 0.75),
        percentile_90=percentile(sorted_times, 0.90),
        percentile_95=percentile(sorted_times, 0.95),
    )


def simulate_long_run(
    config: OpportunityConfig,
    resolution_pattern: ResolutionPattern,
    *,
    trials: int,
    seed: int,
    horizon: float,
    health: int = 1,
) -> tuple[list[int], list[float]]:
    spawn_counts: list[int] = []
    all_intervals: list[float] = []
    rng = random.Random(seed)

    for trial_index in range(trials):
        next_check_time = rng.uniform(config.interval_min, config.interval_max)
        run_state = OpportunityRunState(config)

        while next_check_time <= horizon:
            run_state.process_check(
                next_check_time,
                health,
                rng.random(),
                resolution_block_duration=resolution_pattern.block_duration,
            )
            next_check_time += rng.uniform(config.interval_min, config.interval_max)

        spawn_counts.append(len(run_state.spawn_times))
        if len(run_state.spawn_times) >= 2:
            all_intervals.extend(
                later - earlier
                for earlier, later in zip(run_state.spawn_times, run_state.spawn_times[1:])
            )

    return spawn_counts, all_intervals


def summarize_long_run(spawn_counts: list[int], intervals: list[float]) -> LongRunSummary:
    sorted_intervals = sorted(intervals)
    trial_count = len(spawn_counts)
    zero_count = sum(1 for count in spawn_counts if count == 0)
    one_count = sum(1 for count in spawn_counts if count == 1)
    two_or_more_count = sum(1 for count in spawn_counts if count >= 2)
    return LongRunSummary(
        expected_spawn_count=statistics.fmean(spawn_counts) if spawn_counts else 0.0,
        probability_zero=zero_count / trial_count if trial_count else 0.0,
        probability_one=one_count / trial_count if trial_count else 0.0,
        probability_two_or_more=two_or_more_count / trial_count if trial_count else 0.0,
        mean_interval_between_spawns=statistics.fmean(sorted_intervals) if sorted_intervals else None,
        median_interval_between_spawns=statistics.median(sorted_intervals) if sorted_intervals else None,
        percentile_90_interval=percentile(sorted_intervals, 0.90),
    )


def run_focused_self_checks() -> list[str]:
    failures: list[str] = []

    test_config = OpportunityConfig(
        unlock_time=20.0,
        interval_min=8.0,
        interval_max=12.0,
        chance_by_health={4: 0.0, 3: 0.01, 2: 0.04, 1: 0.15},
        cooldown=18.0,
        grace_seconds=90.0,
    )

    require(
        test_config.chance_for_health(4) == 0.0
        and math.isclose(test_config.chance_for_health(3), 0.01)
        and math.isclose(test_config.chance_for_health(2), 0.04)
        and math.isclose(test_config.chance_for_health(1), 0.15),
        "Focused analysis mirror uses the correct live health-specific spawn chances.",
        failures,
    )

    delayed_unlock_state = OpportunityRunState(
        OpportunityConfig(
            unlock_time=20.0,
            interval_min=8.0,
            interval_max=12.0,
            chance_by_health={1: 1.0},
            cooldown=18.0,
            grace_seconds=None,
        )
    )
    require(
        not delayed_unlock_state.process_check(18.0, 1, 0.0)
        and delayed_unlock_state.process_check(27.5, 1, 0.0)
        and delayed_unlock_state.spawn_times == [27.5],
        "The first eligible organic spawn can occur after 20s because the opportunity timer keeps its independent 8-12s cadence.",
        failures,
    )

    pause_tracker = GraceTracker(90.0)
    pause_tracker.advance(60.0, 1, True)
    pause_tracker.advance(30.0, 1, False)
    pause_tracker.advance(29.0, 1, True)
    require(
        not pause_tracker.due,
        "Paused or countdown time does not advance the one-health grace clock.",
        failures,
    )
    pause_tracker.advance(1.0, 1, True)
    require(
        pause_tracker.due,
        "Active gameplay time continues the grace clock once the run is live again.",
        failures,
    )

    reset_tracker = GraceTracker(90.0)
    reset_tracker.advance(60.0, 1, True)
    reset_tracker.advance(5.0, 2, True)
    reset_tracker.advance(89.0, 1, True)
    require(
        not reset_tracker.due,
        "Raising health above one resets the continuous one-health grace clock.",
        failures,
    )
    reset_tracker.advance(1.0, 1, True)
    require(
        reset_tracker.due,
        "A fresh full one-health duration is required after health recovery.",
        failures,
    )
    reset_tracker.reset()
    require(
        not reset_tracker.due and math.isclose(reset_tracker.continuous_one_hp_active_time, 0.0),
        "Restart or game-over style resets clear any accumulated grace state.",
        failures,
    )

    failed_roll_state = OpportunityRunState(
        OpportunityConfig(
            unlock_time=20.0,
            interval_min=8.0,
            interval_max=12.0,
            chance_by_health={1: 0.0},
            cooldown=18.0,
            grace_seconds=120.0,
        )
    )
    require(
        not failed_roll_state.process_check(50.0, 1, 0.99)
        and not failed_roll_state.process_check(100.0, 1, 0.99)
        and failed_roll_state.process_check(120.0, 1, 0.99)
        and failed_roll_state.spawn_times == [120.0],
        "Ordinary failed rolls do not reset a pending one-health grace timer.",
        failures,
    )

    safe_failure_state = OpportunityRunState(
        OpportunityConfig(
            unlock_time=20.0,
            interval_min=8.0,
            interval_max=12.0,
            chance_by_health={1: 0.0},
            cooldown=18.0,
            grace_seconds=90.0,
        )
    )
    require(
        not safe_failure_state.process_check(90.0, 1, 0.99, safe_available=False)
        and safe_failure_state.grace_tracker.due
        and safe_failure_state.process_check(100.0, 1, 0.99, safe_available=True)
        and safe_failure_state.spawn_times == [100.0],
        "A due grace spawn survives safe-entry failure and forces the next valid opportunity instead of being consumed.",
        failures,
    )

    blocked_grace_state = OpportunityRunState(
        OpportunityConfig(
            unlock_time=20.0,
            interval_min=8.0,
            interval_max=12.0,
            chance_by_health={1: 1.0},
            cooldown=18.0,
            grace_seconds=30.0,
        )
    )
    require(
        blocked_grace_state.process_check(20.0, 1, 0.0, resolution_block_duration=20.0)
        and not blocked_grace_state.process_check(50.0, 1, 0.99)
        and blocked_grace_state.process_check(60.0, 1, 0.99)
        and blocked_grace_state.spawn_times == [20.0, 60.0],
        "A due grace spawn waits through active resolution and the post-resolution cooldown before firing once eligibility returns.",
        failures,
    )

    debug_spawn_state = OpportunityRunState(
        OpportunityConfig(
            unlock_time=20.0,
            interval_min=8.0,
            interval_max=12.0,
            chance_by_health={1: 0.0},
            cooldown=18.0,
            grace_seconds=90.0,
        )
    )
    debug_spawn_state.advance_to(70.0, 1, True)
    debug_spawn_state.record_debug_spawn(70.0, 1, True)
    require(
        math.isclose(debug_spawn_state.grace_tracker.continuous_one_hp_active_time, 70.0),
        "Debug-spawn bookkeeping leaves the organic grace clock untouched.",
        failures,
    )
    require(
        debug_spawn_state.process_check(90.0, 1, 0.99)
        and debug_spawn_state.spawn_times == [90.0],
        "A later organic one-health guarantee still fires after unrelated debug coverage.",
        failures,
    )

    duplicate_grace_state = OpportunityRunState(
        OpportunityConfig(
            unlock_time=0.0,
            interval_min=8.0,
            interval_max=12.0,
            chance_by_health={1: 0.0},
            cooldown=0.0,
            grace_seconds=90.0,
        )
    )
    require(
        duplicate_grace_state.process_check(90.0, 1, 0.99)
        and not duplicate_grace_state.process_check(100.0, 1, 0.99)
        and not duplicate_grace_state.process_check(179.0, 1, 0.99)
        and duplicate_grace_state.process_check(180.0, 1, 0.99)
        and duplicate_grace_state.spawn_times == [90.0, 180.0],
        "A completed grace interval can force only one organic spawn before a fresh one-health duration accumulates.",
        failures,
    )

    cooldown_authority_state = OpportunityRunState(
        OpportunityConfig(
            unlock_time=0.0,
            interval_min=8.0,
            interval_max=12.0,
            chance_by_health={1: 0.0},
            cooldown=18.0,
            grace_seconds=10.0,
        )
    )
    require(
        cooldown_authority_state.process_check(10.0, 1, 0.99)
        and not cooldown_authority_state.process_check(20.0, 1, 0.99)
        and cooldown_authority_state.process_check(30.0, 1, 0.99)
        and cooldown_authority_state.spawn_times == [10.0, 30.0],
        "The post-resolution cooldown remains authoritative even when the one-health grace timer becomes due again sooner.",
        failures,
    )

    return failures


def format_seconds(value: float | None) -> str:
    if value is None:
        return "N/A"
    return f"{value:.1f}s"


def format_percent(value: float) -> str:
    return f"{value * 100.0:.1f}%"


def print_first_spawn_report(
    label: str,
    summary: FirstSpawnSummary,
) -> None:
    print(f"\n{label}")
    print(
        "  by 60s/90s/120s/180s: "
        + " / ".join(
            format_percent(summary.spawn_probability_by_horizon[horizon])
            for horizon in FIRST_SPAWN_HORIZONS
        )
    )
    print(
        "  no spawn by 60s/90s/120s/180s: "
        + " / ".join(
            format_percent(summary.no_spawn_probability_by_horizon[horizon])
            for horizon in FIRST_SPAWN_HORIZONS
        )
    )
    print(
        "  first-spawn mean/median/p75/p90/p95: "
        + " / ".join(
            [
                format_seconds(summary.mean_first_spawn_time),
                format_seconds(summary.median_first_spawn_time),
                format_seconds(summary.percentile_75),
                format_seconds(summary.percentile_90),
                format_seconds(summary.percentile_95),
            ]
        )
    )


def print_long_run_report(
    candidate_label: str,
    resolution_pattern: ResolutionPattern,
    horizon: float,
    summary: LongRunSummary,
) -> None:
    print(
        f"  {candidate_label} | {resolution_pattern.label} | {int(horizon)}s"
        f" -> expected {summary.expected_spawn_count:.2f}, "
        f"P0 {format_percent(summary.probability_zero)}, "
        f"P1 {format_percent(summary.probability_one)}, "
        f"P2+ {format_percent(summary.probability_two_or_more)}, "
        f"interval mean/median/p90 "
        f"{format_seconds(summary.mean_interval_between_spawns)} / "
        f"{format_seconds(summary.median_interval_between_spawns)} / "
        f"{format_seconds(summary.percentile_90_interval)}"
    )


def classify_drought(probability_no_spawn_by_90s: float) -> str:
    if probability_no_spawn_by_90s >= 0.10:
        return "common"
    if probability_no_spawn_by_90s >= 0.03:
        return "uncommon"
    return "rare"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Deterministic Heart Runner spawn-path analysis and candidate comparison. "
            "This mirrors the live opportunity cadence in authoritative active-run time."
        )
    )
    parser.add_argument("--trials", type=int, default=DEFAULT_TRIALS)
    parser.add_argument("--long-run-trials", type=int, default=DEFAULT_LONG_RUN_TRIALS)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    args = parser.parse_args()

    live_values = load_live_values()
    candidates = build_candidate_configs(live_values)
    resolution_patterns = build_resolution_patterns(live_values)

    print("Heart Runner spawn analysis")
    print("==========================")
    print(f"First-spawn trials per configuration: {args.trials}")
    print(f"Long-run trials per configuration: {args.long_run_trials}")
    print(f"Base seed: {args.seed}")
    print(
        "Authoritative active-run inputs: "
        f"unlock={live_values.unlock_time:.1f}s, "
        f"interval={live_values.interval_min:.1f}-{live_values.interval_max:.1f}s, "
        f"chances(3/2/1 HP)={live_values.health_3_chance:.2f}/{live_values.health_2_chance:.2f}/{live_values.health_1_chance:.2f}, "
        f"cooldown={live_values.cooldown:.1f}s."
    )
    print(
        "Active-run note: this analysis uses the same authoritative time base as `survival_time`, "
        "so pause and resume countdown contribute zero simulated time."
    )

    focused_failures = run_focused_self_checks()
    if focused_failures:
        print(f"\nFocused analysis checks failed with {len(focused_failures)} issue(s).")
        return 1

    current_config = build_live_opportunity_config(live_values)

    print("\nCurrent live system by fixed health")
    print("---------------------------------")
    for health in [4, 3, 2, 1]:
        first_spawn_times = simulate_first_spawn_times(
            current_config,
            health,
            trials=args.trials,
            seed=args.seed + health * 100_000,
        )
        summary = summarize_first_spawn_times(first_spawn_times, args.trials)
        label = f"{health} HP"
        print_first_spawn_report(label, summary)

    current_one_hp_times = simulate_first_spawn_times(
        current_config,
        1,
        trials=args.trials,
        seed=args.seed + 999_999,
    )
    current_one_hp_summary = summarize_first_spawn_times(current_one_hp_times, args.trials)
    drought_probability = current_one_hp_summary.no_spawn_probability_by_horizon[90.0]
    print(
        "\nInterpretation: a 90-second continuous 1 HP drought under the current live system is "
        f"{classify_drought(drought_probability)} ({format_percent(drought_probability)} of seeded trials)."
    )
    print(
        "Unlock note: because the separate Heart Runner timer starts at run start and keeps its own "
        "8-12 second cadence, the first eligible check happens on the first timeout after 20.0s, not exactly at 20.0s."
    )
    print(
        "Live configuration note: the shipped model now matches Candidate D "
        f"({live_values.health_1_chance:.2f} at 1 HP with a {live_values.one_health_grace_duration:.0f}s continuous active one-health grace)."
    )

    print("\nOne-health candidate comparison")
    print("-----------------------------")
    candidate_summaries: dict[str, FirstSpawnSummary] = {}
    for candidate_index, candidate in enumerate(candidates):
        config = build_opportunity_config(live_values, candidate)
        first_spawn_times = simulate_first_spawn_times(
            config,
            1,
            trials=args.trials,
            seed=args.seed + (candidate_index + 1) * 1_000_000,
        )
        summary = summarize_first_spawn_times(first_spawn_times, args.trials)
        candidate_summaries[candidate.key] = summary
        print_first_spawn_report(
            f"{candidate.label} | 1 HP chance={candidate.one_hp_chance:.2f} | "
            f"grace={'none' if candidate.grace_seconds is None else f'{candidate.grace_seconds:.0f}s'}",
            summary,
        )

    print("\nLong-run one-health generosity")
    print("----------------------------")
    for pattern in resolution_patterns:
        print(f"{pattern.label}: {pattern.assumption_note} Block duration={pattern.block_duration:.2f}s")
    for candidate_index, candidate in enumerate(candidates):
        config = build_opportunity_config(live_values, candidate)
        for pattern_index, pattern in enumerate(resolution_patterns):
            for horizon in LONG_RUN_HORIZONS:
                spawn_counts, intervals = simulate_long_run(
                    config,
                    pattern,
                    trials=args.long_run_trials,
                    seed=args.seed + (candidate_index + 1) * 1_000_000 + pattern_index * 100_000 + int(horizon),
                    horizon=horizon,
                )
                summary = summarize_long_run(spawn_counts, intervals)
                print_long_run_report(candidate.label, pattern, horizon, summary)

    return 0


if __name__ == "__main__":
    sys.exit(main())
