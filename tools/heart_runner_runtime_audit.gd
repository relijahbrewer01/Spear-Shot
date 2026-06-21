extends Node

const MainScene := preload("res://Main.tscn")
const PlayerScene := preload("res://Player.tscn")
const SpearScene := preload("res://Spear.tscn")
const HeartRunnerScene := preload("res://HeartRunner.tscn")
const HeartPickupScene := preload("res://HeartPickup.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))
const TEST_SEED := 424242

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_opportunity_timer_lifecycle()
	await _audit_one_health_grace_accumulation_and_reset()
	await _audit_one_health_grace_fulfillment_and_deferral()
	await _audit_spawn_rules_and_debug_behavior()
	await _audit_entry_and_calm_wander_behavior()
	await _audit_spear_held_reactions()
	await _audit_flee_route_selection_and_exit_cleanup()
	await _audit_main_escape_cleanup_and_repeat_spawns()
	await _audit_pickup_heal_and_cooldown_flow()
	await _audit_boomer_displacement_and_pause_cleanup()

	for failure in failures:
		push_error("HEART RUNNER RUNTIME AUDIT: %s" % failure)
	print("Heart Runner runtime audit passed." if failures.is_empty() else "Heart Runner runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_opportunity_timer_lifecycle() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var spawn_timer := main.get_node("SpawnTimer") as Timer
	var opportunity_timer := main.get_node("OpportunityTimer") as Timer
	var player := main.get_node("Player") as Player

	spawn_timer.stop()
	player.health = 1
	main.set("survival_time", 25.0)
	main.set("heart_runner_next_eligible_time", 0.0)
	main.call("_clear_opportunities")
	main.call("debug_set_heart_runner_roll_sequence", [0.99, 0.99, 0.0])
	main.call("debug_set_heart_runner_interval_sequence", [0.05, 0.05, 0.05])
	opportunity_timer.stop()
	main.call("_start_opportunity_timer")
	_require(
		not opportunity_timer.is_stopped()
		and is_equal_approx(opportunity_timer.wait_time, 0.05),
		"Heart Runner opportunity timer starts correctly with a fresh independent interval."
	)
	var spawned_after_retries := await _advance_until(
		func() -> bool:
			return main.get("active_heart_runner") != null,
		0.35
	)
	_require(
		spawned_after_retries,
		"Heart Runner opportunity checks continue while the run is active until a later eligible roll succeeds."
	)

	main.call("_clear_opportunities")
	main.set("survival_time", 25.0)
	main.set("heart_runner_next_eligible_time", 0.0)
	main.call("debug_set_heart_runner_roll_sequence", [0.0])
	main.call("debug_set_heart_runner_interval_sequence", [0.15, 0.05])
	opportunity_timer.stop()
	main.call("_start_opportunity_timer")
	var timer_left_before_pause := opportunity_timer.time_left
	main.call("_set_pause_state", true)
	await get_tree().create_timer(0.18, true, false, true).timeout
	_require(
		absf(opportunity_timer.time_left - timer_left_before_pause) <= 0.03,
		"Pause freezes the Heart Runner opportunity timer."
	)
	main.call("_start_resume_countdown")
	await get_tree().create_timer(0.18, true, false, true).timeout
	_require(
		absf(opportunity_timer.time_left - timer_left_before_pause) <= 0.03,
		"Resume countdown keeps the Heart Runner opportunity timer frozen until gameplay resumes."
	)
	main.call("_on_resume_countdown_finished")
	var spawned_after_resume := await _advance_until(
		func() -> bool:
			return main.get("active_heart_runner") != null,
		0.30
	)
	_require(
		spawned_after_resume,
		"Heart Runner opportunity timing resumes correctly after countdown completion."
	)

	main.call("_clear_opportunities")
	main.set("survival_time", 25.0)
	main.set("heart_runner_next_eligible_time", 42.0)
	main.call("debug_set_heart_runner_roll_sequence", [0.0])
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	opportunity_timer.stop()
	main.call("_start_opportunity_timer")
	main.call("_on_player_died")
	await get_tree().process_frame
	_require(
		opportunity_timer.is_stopped(),
		"Game over stops the Heart Runner opportunity timer."
	)
	main.call("_restart_run")
	await get_tree().process_frame
	spawn_timer.stop()
	_require(
		is_equal_approx(float(main.get("heart_runner_next_eligible_time")), 0.0),
		"Restart resets Heart Runner cooldown timing to zero."
	)
	_require(
		not opportunity_timer.is_stopped(),
		"Restart starts a fresh Heart Runner opportunity timer for the new run."
	)

	await _free_audit_main(main)


func _audit_one_health_grace_accumulation_and_reset() -> void:
	var main := await _spawn_live_main_for_audit()
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	var opportunity_timer := main.get_node("OpportunityTimer") as Timer
	var player := main.get_node("Player") as Player

	spawn_timer.stop()
	opportunity_timer.stop()
	player.health = 1
	main.call("debug_set_heart_runner_one_health_grace_state", 89.92, false)
	await _advance_physics(0.16)
	_require(
		bool(main.get("heart_runner_one_health_grace_due"))
		and float(main.get("heart_runner_one_health_active_time")) >= float(main.get("heart_runner_one_health_grace_duration")),
		"Heart Runner one-health grace becomes due after 90 seconds of eligible active gameplay."
	)

	main.call("debug_set_heart_runner_one_health_grace_state", 45.0, false)
	var grace_before_pause := float(main.get("heart_runner_one_health_active_time"))
	main.call("_set_pause_state", true)
	await get_tree().create_timer(0.18, true, false, true).timeout
	_require(
		is_equal_approx(float(main.get("heart_runner_one_health_active_time")), grace_before_pause)
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"Pause freezes Heart Runner one-health grace accumulation."
	)
	main.call("_start_resume_countdown")
	await get_tree().create_timer(0.18, true, false, true).timeout
	_require(
		is_equal_approx(float(main.get("heart_runner_one_health_active_time")), grace_before_pause)
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"Resume countdown also freezes Heart Runner one-health grace accumulation."
	)
	main.call("_on_resume_countdown_finished")

	main.call("debug_set_heart_runner_one_health_grace_state", 60.0, true)
	player.health = 2
	await get_tree().physics_frame
	_require(
		is_zero_approx(float(main.get("heart_runner_one_health_active_time")))
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"Healing above one resets both accumulated and due Heart Runner grace state."
	)
	player.health = 1
	await _advance_physics(0.08)
	_require(
		float(main.get("heart_runner_one_health_active_time")) > 0.0
		and float(main.get("heart_runner_one_health_active_time")) < 1.0
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"Returning later to one health restarts Heart Runner grace accumulation from zero."
	)

	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	main.call("_restart_run")
	await get_tree().process_frame
	spawn_timer.stop()
	opportunity_timer.stop()
	_require(
		is_zero_approx(float(main.get("heart_runner_one_health_active_time")))
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"Restart resets Heart Runner grace accumulation and due state."
	)

	player = main.get_node("Player") as Player
	player.health = 1
	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	main.call("_on_player_died")
	await get_tree().process_frame
	_require(
		is_zero_approx(float(main.get("heart_runner_one_health_active_time")))
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"Game over resets Heart Runner grace accumulation and due state."
	)

	await _free_audit_main(main)


func _audit_one_health_grace_fulfillment_and_deferral() -> void:
	var main := await _spawn_live_main_for_audit()
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	var opportunity_timer := main.get_node("OpportunityTimer") as Timer
	var player := main.get_node("Player") as Player

	spawn_timer.stop()
	opportunity_timer.stop()
	player.health = 1
	main.set("survival_time", 25.0)
	main.set("heart_runner_next_eligible_time", 0.0)
	main.call("_clear_opportunities")

	main.call("debug_set_heart_runner_one_health_grace_state", 42.0, false)
	main.call("debug_set_heart_runner_roll_sequence", [0.99])
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		is_equal_approx(float(main.get("heart_runner_one_health_active_time")), 42.0)
		and not bool(main.get("heart_runner_one_health_grace_due"))
		and main.get("active_heart_runner") == null,
		"Failed ordinary one-health rolls do not reset Heart Runner grace state."
	)

	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	main.set("survival_time", 19.5)
	main.call("debug_set_heart_runner_roll_sequence", [0.99])
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		main.get("active_heart_runner") == null and bool(main.get("heart_runner_one_health_grace_due")),
		"Due Heart Runner grace cannot spawn before the 20-second unlock."
	)

	main.set("survival_time", 25.0)
	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	var debug_spawned_runner := bool(main.call("_try_spawn_heart_runner", true))
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		debug_spawned_runner
		and main.get("active_heart_runner") != null
		and bool(main.get("heart_runner_one_health_grace_due")),
		"An active Heart Runner delays a due grace opportunity without consuming it."
	)
	main.call("_clear_opportunities")

	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	_require(
		bool(main.call("_spawn_heart_pickup", TEST_ARENA.get_center(), true)),
		"Debug pickup spawn is available for one-health grace deferral coverage."
	)
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		main.get("active_heart_runner") == null
		and main.get("active_heart_pickup") != null
		and bool(main.get("heart_runner_one_health_grace_due")),
		"An active heart pickup delays a due grace opportunity without consuming it."
	)
	main.call("_clear_opportunities")

	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	main.set("heart_runner_next_eligible_time", 40.0)
	main.set("survival_time", 25.0)
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		main.get("active_heart_runner") == null
		and bool(main.get("heart_runner_one_health_grace_due"))
		and is_equal_approx(float(main.get("heart_runner_next_eligible_time")), 40.0),
		"Post-resolution cooldown delays a due grace opportunity without bypassing the normal gate."
	)
	main.set("heart_runner_next_eligible_time", 0.0)

	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	main.set("heart_runner_spawn_safe_radius", 1000.0)
	main.call("debug_set_heart_runner_roll_sequence", [0.99])
	main.call("debug_set_heart_runner_interval_sequence", [8.5])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		main.get("active_heart_runner") == null
		and bool(main.get("heart_runner_one_health_grace_due"))
		and is_equal_approx(opportunity_timer.wait_time, 8.5),
		"Safe-entry failure preserves a due Heart Runner grace opportunity for a later valid check."
	)
	main.set("heart_runner_spawn_safe_radius", 56.0)

	main.call("debug_set_heart_runner_one_health_grace_state", 90.0, true)
	main.call("debug_set_heart_runner_roll_sequence", [0.99])
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		main.get("active_heart_runner") != null
		and is_zero_approx(float(main.get("heart_runner_one_health_active_time")))
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"A successful grace-forced Heart Runner spawn consumes grace exactly once."
	)
	main.call("_clear_opportunities")
	main.call("debug_set_heart_runner_roll_sequence", [0.99])
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		main.get("active_heart_runner") == null
		and is_zero_approx(float(main.get("heart_runner_one_health_active_time")))
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"One completed grace interval cannot immediately produce a duplicate forced spawn."
	)

	main.call("debug_set_heart_runner_one_health_grace_state", 42.0, false)
	main.call("debug_set_heart_runner_roll_sequence", [0.0])
	main.call("debug_set_heart_runner_interval_sequence", [0.05])
	main.call("_run_heart_runner_opportunity_check")
	_require(
		main.get("active_heart_runner") != null
		and is_zero_approx(float(main.get("heart_runner_one_health_active_time")))
		and not bool(main.get("heart_runner_one_health_grace_due")),
		"A successful ordinary one-health Heart Runner spawn also resets the grace interval."
	)
	main.call("_clear_opportunities")

	main.call("debug_set_heart_runner_one_health_grace_state", 44.0, false)
	var debug_grace_before := float(main.get("heart_runner_one_health_active_time"))
	var debug_due_before := bool(main.get("heart_runner_one_health_grace_due"))
	_require(
		bool(main.call("_try_spawn_heart_runner", true)),
		"Debug Heart Runner spawn remains available during one-health grace bookkeeping coverage."
	)
	_require(
		is_equal_approx(float(main.get("heart_runner_one_health_active_time")), debug_grace_before)
		and bool(main.get("heart_runner_one_health_grace_due")) == debug_due_before,
		"Debug Heart Runner spawns leave all organic one-health grace state untouched."
	)

	await _free_audit_main(main)


func _audit_spawn_rules_and_debug_behavior() -> void:
	var main := await _spawn_main_for_audit()
	var director := main.get_node("EncounterDirector") as EncounterDirector
	var opportunity_timer := main.get_node("OpportunityTimer") as Timer
	var player := main.get_node("Player") as Player

	player.health = 3
	main.set("survival_time", 19.9)
	_require(
		not bool(main.call("_is_heart_runner_opportunity_eligible_for_roll")),
		"Heart Runner opportunity is unavailable before the 20-second unlock."
	)
	main.set("survival_time", 20.0)
	_require(
		bool(main.call("_is_heart_runner_opportunity_eligible_for_roll")),
		"Heart Runner opportunity becomes eligible at 20 seconds."
	)

	player.health = 3
	_require(
		is_equal_approx(float(main.call("_get_current_heart_runner_spawn_chance")), 0.01),
		"Heart Runner chance is 0.01 at three health."
	)
	player.health = 2
	_require(
		is_equal_approx(float(main.call("_get_current_heart_runner_spawn_chance")), 0.04),
		"Heart Runner chance is 0.04 at two health."
	)
	player.health = 1
	_require(
		is_equal_approx(float(main.call("_get_current_heart_runner_spawn_chance")), 0.15),
		"Heart Runner chance is 0.15 at one health."
	)
	player.health = 4
	_require(
		is_equal_approx(float(main.call("_get_current_heart_runner_spawn_chance")), 0.0),
		"Heart Runner does not roll while Akedra already has four health."
	)

	player.health = 1
	main.set("survival_time", 0.0)
	var hostile_count_before := director.get_total_hostile_count()
	var cooldown_before := float(main.get("heart_runner_next_eligible_time"))
	_require(
		bool(main.call("_try_spawn_heart_runner", true)),
		"Debug Heart Runner spawn bypasses the normal unlock gate."
	)
	_require(
		director.get_total_hostile_count() == hostile_count_before,
		"Heart Runner stays outside hostile population accounting."
	)
	_require(
		is_equal_approx(float(main.get("heart_runner_next_eligible_time")), cooldown_before),
		"Debug Heart Runner spawn does not stamp the organic opportunity cooldown."
	)
	_require(
		not bool(main.call("_try_spawn_heart_runner", true)),
		"Debug Heart Runner spawn still respects the one-active Runner or pickup limit."
	)

	var debug_runner := main.get("active_heart_runner") as HeartRunner
	_require(debug_runner != null, "Debug Heart Runner becomes the tracked active opportunity.")
	if debug_runner != null:
		debug_runner.debug_force_locked_exit(
			Arena.SpawnEdge.RIGHT,
			Vector2(TEST_ARENA.end.x - debug_runner.body_radius, TEST_ARENA.get_center().y),
			true
		)
		debug_runner.global_position = _get_pre_exit_test_position(Arena.SpawnEdge.RIGHT, debug_runner.body_radius)
	var escaped_debug_runner := await _advance_until(
		func() -> bool: return main.get("active_heart_runner") == null,
		0.35
	)
	_require(escaped_debug_runner, "Debug Heart Runner escape clears Main's active Runner reference.")
	_require(
		is_equal_approx(float(main.get("heart_runner_next_eligible_time")), cooldown_before),
		"Debug Heart Runner escape does not alter future organic cooldown timing."
	)

	main.call("_clear_opportunities")
	player.health = 1
	main.set("survival_time", 25.0)
	main.set("heart_runner_spawn_safe_radius", 1000.0)
	main.call("debug_set_heart_runner_roll_sequence", [0.0])
	main.call("debug_set_heart_runner_interval_sequence", [8.75])
	main.call("_run_heart_runner_opportunity_check")
	_require(main.get("active_heart_runner") == null, "No unsafe fallback spawn is used when no safe Heart Runner edge entry exists.")
	_require(
		is_equal_approx(float(main.get("heart_runner_next_eligible_time")), cooldown_before),
		"Safe-entry failure defers the opportunity without consuming its cooldown."
	)
	_require(
		is_equal_approx(opportunity_timer.wait_time, 8.75),
		"Safe-entry failure simply defers the Heart Runner to a later roll interval."
	)

	await _free_audit_main(main)


func _audit_entry_and_calm_wander_behavior() -> void:
	var root := Node2D.new()
	add_child(root)

	var player := _spawn_player(root, Vector2(220.0, 108.0))
	var spear := _spawn_spear(root, player)
	_set_spear_state_for_audit(spear, Spear.State.FLYING)

	var runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, TEST_ARENA.get_center().y),
		Arena.SpawnEdge.LEFT
	)
	await _advance_physics(0.22)
	_require(
		int(runner.motion_state) == int(HeartRunner.MotionState.ENTERING),
		"Heart Runner stays in ENTERING until the visible entry requirement is satisfied."
	)
	var reached_wandering := await _advance_until(
		func() -> bool:
			return int(runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	_require(reached_wandering, "Unarmed Heart Runner transitions from ENTERING into WANDERING after moving visibly into the arena.")
	_require(
		runner.sprite != null
		and runner.sprite.texture != null
		and runner.sprite.texture.resource_path == "res://art/sprites/heart_runner_sheet.png"
		and runner.sprite.hframes == 4
		and runner.sprite.vframes == 3,
		"Heart Runner live presentation uses the approved single 4x3 sprite sheet on the existing Sprite2D seam."
	)
	_require(
		runner._get_entry_progress() >= runner.entry_distance and runner.entry_elapsed >= runner.entry_min_duration,
		"Heart Runner only finishes entry after the configured distance and minimum visible time."
	)
	var calm_samples := await _sample_runner_frames(runner, 0.42)
	_require(
		_all_samples_use_row(calm_samples, HeartRunner.ANIMATION_ROW_CALM),
		"Heart Runner uses the calm animation row during visible entry and wandering behavior."
	)
	_require(
		_count_unique_frames(calm_samples) >= 2,
		"Heart Runner calm presentation cycles through the approved four-frame casual strut in live play."
	)

	var inner_rect := runner._get_inner_wander_rect()
	var direction_changes := 0
	var previous_direction := runner.travel_direction
	for _index in range(8):
		await _advance_physics(0.30)
		_require(
			runner.global_position.x >= inner_rect.position.x + runner.body_radius
			and runner.global_position.x <= inner_rect.end.x - runner.body_radius
			and runner.global_position.y >= inner_rect.position.y + runner.body_radius
			and runner.global_position.y <= inner_rect.end.y - runner.body_radius,
			"Heart Runner wandering stays inside the safe inner wander rectangle."
		)
		if previous_direction != Vector2.ZERO and runner.travel_direction != Vector2.ZERO:
			if previous_direction.angle_to(runner.travel_direction) > 0.35:
				direction_changes += 1
		previous_direction = runner.travel_direction
	_require(direction_changes >= 2, "Heart Runner calm wandering uses multiple readable targets instead of one permanent crossing line.")
	_require(
		int(runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		"Heart Runner remains in calm wandering while Akedra stays unarmed and the calm timer has not expired."
	)

	runner.wander_time_left = 0.01
	var reached_casual_exit := await _advance_until(
		func() -> bool:
			return int(runner.motion_state) == int(HeartRunner.MotionState.CASUAL_EXIT),
		0.5
	)
	_require(reached_casual_exit, "Heart Runner transitions into CASUAL_EXIT when the calm timer expires while Akedra is unarmed.")
	_require(
		runner.current_route_length >= runner.casual_exit_min_route_length,
		"Heart Runner casual exit keeps a meaningful remaining route instead of vanishing almost immediately."
	)
	_require(
		runner.get_current_animation_frame_coords().y == HeartRunner.ANIMATION_ROW_CALM,
		"Heart Runner keeps the calm strut presentation during CASUAL_EXIT."
	)

	root.queue_free()
	await get_tree().process_frame


func _audit_spear_held_reactions() -> void:
	var root := Node2D.new()
	add_child(root)

	var player := _spawn_player(root, Vector2(320.0, 108.0))
	var spear := _spawn_spear(root, player)

	var armed_spawn_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 88.0),
		Arena.SpawnEdge.LEFT,
		7001
	)
	var armed_spawn_alarm_count := 0
	armed_spawn_runner.startled_started.connect(func() -> void:
		armed_spawn_alarm_count += 1
	)
	await _advance_physics(0.20)
	_require(
		armed_spawn_alarm_count == 0 and int(armed_spawn_runner.motion_state) == int(HeartRunner.MotionState.ENTERING),
		"Armed-at-spawn Heart Runner does not trigger the startled reaction while it is still mostly entering from offscreen."
	)
	var armed_spawn_startle_radius := armed_spawn_runner.get_startle_radius()
	_require(
		is_equal_approx(
			armed_spawn_startle_radius,
			spear.max_range - armed_spawn_runner.heart_runner_startle_range_margin
		),
		"Heart Runner startled radius is derived from the live spear range minus the configured margin."
	)
	var armed_spawn_wanders_calmly := await _advance_until(
		func() -> bool:
			return int(armed_spawn_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	_require(
		armed_spawn_wanders_calmly and armed_spawn_alarm_count == 0 and armed_spawn_runner.armed_threat_active,
		"Armed-at-spawn Heart Runner finishes entry first, then stays calm while Akedra remains armed but still outside the startled radius."
	)
	var calm_stride_samples := await _sample_runner_frames(armed_spawn_runner, 0.32)
	player.global_position = armed_spawn_runner.global_position + Vector2(armed_spawn_startle_radius - 8.0, 0.0)
	var armed_spawn_startled := await _advance_until(
		func() -> bool:
			return int(armed_spawn_runner.motion_state) == int(HeartRunner.MotionState.STARTLED)
				or int(armed_spawn_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		0.35
	)
	_require(
		armed_spawn_startled and armed_spawn_alarm_count == 1,
		"Armed-at-spawn Heart Runner startles exactly once after entry completes and Akedra moves inside the derived threat radius."
	)
	var startled_samples := await _sample_runner_frames(armed_spawn_runner, 0.20)
	_require(
		_all_samples_use_row(startled_samples, HeartRunner.ANIMATION_ROW_STARTLED),
		"Heart Runner switches to the one-shot startled row when the valid spear-threat reaction begins."
	)
	_require(
		_count_unique_frames(startled_samples) >= 3,
		"Heart Runner startled presentation advances through the approved recognition, pop, and peak frames before panic."
	)
	await _advance_physics(0.30)
	_require(
		int(armed_spawn_runner.motion_state) == int(HeartRunner.MotionState.STARTLED),
		"Heart Runner keeps the slowed 0.40-second startled hop readable before the flee sprint takes over."
	)
	var armed_spawn_flee := await _advance_until(
		func() -> bool:
			return int(armed_spawn_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		0.25
	)
	_require(armed_spawn_flee, "Heart Runner enters FLEEING after the revised startled-hop timing completes.")
	var flee_samples := await _sample_runner_frames(armed_spawn_runner, 0.32)
	_require(
		_all_samples_use_row(flee_samples, HeartRunner.ANIMATION_ROW_FLEE),
		"Heart Runner begins the approved panic-sprint row only after the startled sequence completes."
	)
	_require(
		_count_unique_frames(flee_samples) >= 3,
		"Heart Runner live panic sprint uses multiple distinct flee frames rather than repeating a static pose."
	)
	_require(
		_count_frame_changes(flee_samples) > _count_frame_changes(calm_stride_samples),
		"Heart Runner panic sprint cadence stays visibly faster than the calm strut."
	)
	_set_spear_state_for_audit(spear, Spear.State.FLYING)
	await _advance_physics(0.20)
	_require(
		int(armed_spawn_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		"Throwing the spear after panic starts does not calm the Heart Runner back down."
	)
	armed_spawn_runner.queue_free()
	await get_tree().process_frame

	_set_spear_state_for_audit(spear, Spear.State.FLYING)
	player.global_position = Vector2(320.0, 108.0)
	var pending_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 108.0),
		Arena.SpawnEdge.LEFT,
		7002
	)
	var pending_alarm_count := 0
	pending_runner.startled_started.connect(func() -> void:
		pending_alarm_count += 1
	)
	await _advance_until(
		func() -> bool:
			return int(pending_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	var pending_startle_radius := pending_runner.get_startle_radius()
	_set_spear_state_for_audit(spear, Spear.State.HELD)
	await _advance_physics(0.20)
	_require(
		int(pending_runner.motion_state) == int(HeartRunner.MotionState.WANDERING)
		and pending_alarm_count == 0
		and pending_runner.armed_threat_active,
		"Picking up the spear outside the startled radius keeps the Heart Runner calm while the armed threat remains pending."
	)
	_set_spear_state_for_audit(spear, Spear.State.FLYING)
	player.global_position = pending_runner.global_position + Vector2(pending_startle_radius - 10.0, 0.0)
	await _advance_physics(0.20)
	_require(
		int(pending_runner.motion_state) == int(HeartRunner.MotionState.WANDERING)
		and pending_alarm_count == 0
		and not pending_runner.armed_threat_active,
		"Throwing the spear before entering the startled radius clears the pending armed threat and prevents panic."
	)
	_set_spear_state_for_audit(spear, Spear.State.HELD)
	var startled_from_repickup := await _advance_until(
		func() -> bool:
			return int(pending_runner.motion_state) == int(HeartRunner.MotionState.STARTLED)
				or int(pending_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		0.35
	)
	_require(
		startled_from_repickup and pending_alarm_count == 1,
		"Picking the spear up again later allows a new valid proximity trigger exactly once."
	)
	pending_runner.queue_free()
	await get_tree().process_frame

	_set_spear_state_for_audit(spear, Spear.State.FLYING)
	player.global_position = Vector2(220.0, 108.0)
	var wandering_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 120.0),
		Arena.SpawnEdge.LEFT,
		7003
	)
	var wandering_alarm_count := 0
	wandering_runner.startled_started.connect(func() -> void:
		wandering_alarm_count += 1
	)
	await _advance_until(
		func() -> bool:
			return int(wandering_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	var wandering_startle_radius := wandering_runner.get_startle_radius()
	wandering_runner.global_position = player.global_position - Vector2(wandering_startle_radius + 10.0, 0.0)
	wandering_runner.wander_target = player.global_position - Vector2(wandering_startle_radius - 12.0, 0.0)
	wandering_runner.travel_direction = (wandering_runner.wander_target - wandering_runner.global_position).normalized()
	_set_spear_state_for_audit(spear, Spear.State.HELD)
	await _advance_physics(0.10)
	_require(
		int(wandering_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		"Heart Runner continues wandering while armed but still outside the startled radius."
	)
	var startled_from_wander := await _advance_until(
		func() -> bool:
			return int(wandering_runner.motion_state) == int(HeartRunner.MotionState.STARTLED)
				or int(wandering_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		0.40
	)
	_require(
		startled_from_wander and wandering_alarm_count == 1,
		"Heart Runner wandering into the startled radius while Akedra stays armed triggers exactly one startled reaction."
	)
	wandering_runner.queue_free()
	await get_tree().process_frame

	_set_spear_state_for_audit(spear, Spear.State.FLYING)
	player.global_position = Vector2(320.0, 108.0)
	var casual_exit_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 132.0),
		Arena.SpawnEdge.LEFT,
		7004
	)
	var casual_alarm_count := 0
	casual_exit_runner.startled_started.connect(func() -> void:
		casual_alarm_count += 1
	)
	await _advance_until(
		func() -> bool:
			return int(casual_exit_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	casual_exit_runner.global_position = Vector2(64.0, 132.0)
	_set_spear_state_for_audit(spear, Spear.State.HELD)
	casual_exit_runner.wander_time_left = 0.01
	await _advance_until(
		func() -> bool:
			return int(casual_exit_runner.motion_state) == int(HeartRunner.MotionState.CASUAL_EXIT),
		0.5
	)
	await _advance_physics(0.24)
	_require(
		int(casual_exit_runner.motion_state) == int(HeartRunner.MotionState.CASUAL_EXIT)
		and casual_alarm_count == 0,
		"CASUAL_EXIT continues normally when the Runner remains outside the startled radius even while Akedra is armed."
	)
	casual_exit_runner.queue_free()
	await get_tree().process_frame

	_set_spear_state_for_audit(spear, Spear.State.FLYING)
	player.global_position = Vector2(320.0, 108.0)
	var casual_interrupt_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 144.0),
		Arena.SpawnEdge.LEFT,
		7005
	)
	var casual_interrupt_alarm_count := 0
	casual_interrupt_runner.startled_started.connect(func() -> void:
		casual_interrupt_alarm_count += 1
	)
	await _advance_until(
		func() -> bool:
			return int(casual_interrupt_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	casual_interrupt_runner.global_position = Vector2(72.0, 144.0)
	_set_spear_state_for_audit(spear, Spear.State.HELD)
	casual_interrupt_runner.wander_time_left = 0.01
	await _advance_until(
		func() -> bool:
			return int(casual_interrupt_runner.motion_state) == int(HeartRunner.MotionState.CASUAL_EXIT),
		0.5
	)
	player.global_position = casual_interrupt_runner.global_position + Vector2(
		casual_interrupt_runner.get_startle_radius() - 8.0,
		0.0
	)
	var startled_from_casual_exit := await _advance_until(
		func() -> bool:
			return int(casual_interrupt_runner.motion_state) == int(HeartRunner.MotionState.STARTLED)
				or int(casual_interrupt_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		0.40
	)
	_require(
		startled_from_casual_exit and casual_interrupt_alarm_count == 1,
		"CASUAL_EXIT is interrupted into exactly one startled reaction when the Runner enters the armed threat radius before resolving."
	)

	root.queue_free()
	await get_tree().process_frame


func _audit_flee_route_selection_and_exit_cleanup() -> void:
	var root := Node2D.new()
	add_child(root)

	var player := _spawn_player(root, Vector2(244.0, 108.0))
	var spear := _spawn_spear(root, player)
	_set_spear_state_for_audit(spear, Spear.State.FLYING)

	var route_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, TEST_ARENA.get_center().y),
		Arena.SpawnEdge.LEFT,
		7101
	)
	route_runner.debug_force_wandering()
	route_runner.global_position = Vector2(TEST_ARENA.position.x + route_runner.body_radius + 2.0, TEST_ARENA.get_center().y)
	route_runner.debug_trigger_spear_held()
	_require(
		route_runner.current_route_length >= route_runner.flee_min_route_length,
		"Heart Runner flee-route selection rejects unfair near-edge instant exits when longer routes exist."
	)
	_require(
		int(route_runner.exit_edge) != int(Arena.SpawnEdge.LEFT),
		"Heart Runner normally avoids fleeing straight back through the wall it is already standing beside."
	)
	var away_from_player := (route_runner.global_position - player.global_position).normalized()
	_require(
		route_runner.travel_direction.dot(away_from_player) > 0.25,
		"Heart Runner flee direction generally points away from Akedra instead of choosing a fully random route."
	)
	route_runner.queue_free()
	await get_tree().process_frame

	await _audit_locked_exit_case(root, Arena.SpawnEdge.RIGHT, "right")
	await _audit_locked_exit_case(root, Arena.SpawnEdge.LEFT, "left")
	await _audit_locked_exit_case(root, Arena.SpawnEdge.BOTTOM, "bottom")
	await _audit_locked_exit_case(root, Arena.SpawnEdge.TOP, "top")

	root.queue_free()
	await get_tree().process_frame


func _audit_main_escape_cleanup_and_repeat_spawns() -> void:
	var main := await _spawn_main_for_audit()
	var opportunity_container := main.get_node("OpportunityContainer") as Node2D
	var player := main.get_node("Player") as Player
	player.health = 1
	main.set("survival_time", 30.0)

	_require(
		bool(main.call("_try_spawn_heart_runner", false)),
		"Organic Heart Runner spawn succeeds for the escape cleanup audit."
	)
	var first_runner := main.get("active_heart_runner") as HeartRunner
	_require(first_runner != null, "Main tracks the organically spawned Heart Runner before escape.")
	if first_runner != null:
		first_runner.debug_force_locked_exit(
			Arena.SpawnEdge.RIGHT,
			Vector2(TEST_ARENA.end.x - first_runner.body_radius, TEST_ARENA.get_center().y),
			true
		)
		first_runner.global_position = _get_pre_exit_test_position(Arena.SpawnEdge.RIGHT, first_runner.body_radius)
	var first_escape_cleared := await _advance_until(
		func() -> bool: return main.get("active_heart_runner") == null,
		0.35
	)
	_require(first_escape_cleared, "Main clears its active Runner reference after a natural organic escape.")
	_require(opportunity_container.get_child_count() == 0, "Natural escape leaves no lingering Runner nodes behind.")
	_require(
		is_equal_approx(
			float(main.get("heart_runner_next_eligible_time")),
			30.0 + float(main.get("heart_runner_post_resolution_cooldown"))
		),
		"Natural organic escape applies the Heart Runner cooldown exactly once."
	)

	main.call("debug_set_heart_runner_roll_sequence", [0.0])
	main.call("debug_set_heart_runner_interval_sequence", [9.0])
	main.set("survival_time", float(main.get("heart_runner_next_eligible_time")) - 0.1)
	main.call("_run_heart_runner_opportunity_check")
	_require(main.get("active_heart_runner") == null, "Heart Runner does not respawn before its organic post-resolution cooldown ends.")
	_require(opportunity_container.get_child_count() == 0, "Pre-cooldown opportunity checks do not accumulate hidden offscreen nodes.")

	main.call("debug_set_heart_runner_roll_sequence", [0.0])
	main.call("debug_set_heart_runner_interval_sequence", [9.0])
	main.set("survival_time", float(main.get("heart_runner_next_eligible_time")) + 0.1)
	main.call("_run_heart_runner_opportunity_check")
	var second_runner := main.get("active_heart_runner") as HeartRunner
	_require(second_runner != null, "A later Heart Runner can spawn again after the cooldown expires.")
	if second_runner != null:
		second_runner.debug_force_locked_exit(
			Arena.SpawnEdge.LEFT,
			Vector2(TEST_ARENA.position.x + second_runner.body_radius, TEST_ARENA.get_center().y),
			true
		)
		second_runner.global_position = _get_pre_exit_test_position(Arena.SpawnEdge.LEFT, second_runner.body_radius)
	var second_escape_cleared := await _advance_until(
		func() -> bool: return main.get("active_heart_runner") == null,
		0.35
	)
	_require(second_escape_cleared, "Repeated later Heart Runner escapes also clear Main's active Runner reference.")
	_require(opportunity_container.get_child_count() == 0, "Repeated Heart Runner opportunities do not accumulate hidden offscreen nodes.")

	await _free_audit_main(main)


func _audit_pickup_heal_and_cooldown_flow() -> void:
	var main := await _spawn_main_for_audit()
	var director := main.get_node("EncounterDirector") as EncounterDirector
	var player := main.get_node("Player") as Player
	var play_rect := (main.get_node("Arena") as Arena).get_play_rect()
	player.health = 3
	main.set("survival_time", 30.0)

	var hostile_count_before := director.get_total_hostile_count()
	_require(
		bool(main.call("_try_spawn_heart_runner", false)),
		"Organic Heart Runner spawn succeeds once its separate unlock has passed."
	)
	_require(
		director.get_total_hostile_count() == hostile_count_before,
		"Organic Heart Runner spawn still does not consume hostile population slots."
	)

	var runner := main.get("active_heart_runner") as HeartRunner
	_require(runner != null, "Organic Heart Runner becomes active through the opportunity system.")
	if runner != null:
		runner.global_position = play_rect.position + Vector2(1.0, 1.0)
		runner.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, runner.global_position, Vector2.RIGHT)
	await get_tree().process_frame

	_require(int(main.get("score")) == 1, "Defeating the Heart Runner awards exactly one score point.")
	_require(
		is_equal_approx(float(main.get("heart_runner_next_eligible_time")), 0.0),
		"Defeating the Heart Runner does not stamp cooldown before pickup resolution."
	)

	var pickup := main.get("active_heart_pickup") as HeartPickup
	_require(pickup != null, "Defeated Heart Runner spawns exactly one temporary heart pickup.")
	if pickup != null:
		_require(
			pickup.global_position.x >= play_rect.position.x + pickup.pickup_radius
			and pickup.global_position.y >= play_rect.position.y + pickup.pickup_radius
			and pickup.global_position.x <= play_rect.end.x - pickup.pickup_radius
			and pickup.global_position.y <= play_rect.end.y - pickup.pickup_radius,
			"Heart pickup is clamped inside the playable arena by its pickup radius."
		)
		player.global_position = pickup.global_position
		pickup.call("_on_body_entered", player)
	await get_tree().process_frame

	var expected_collect_cooldown := 30.0 + float(main.get("heart_runner_post_resolution_cooldown"))
	_require(player.health == 4, "Collecting the heart pickup heals Akedra to a temporary fourth health point.")
	_require(
		is_equal_approx(float(main.get("heart_runner_next_eligible_time")), expected_collect_cooldown),
		"Heart Runner cooldown is stamped once when the defeated Runner's pickup is collected."
	)
	var health_pips := player.get_node("HealthPips") as PlayerHealthPips
	_require(health_pips != null and health_pips.bonus_pip_count == 1, "Player health pips display one dedicated bonus heart after collection.")

	_require(
		bool(main.call("_spawn_heart_pickup", play_rect.get_center(), true)),
		"Debug pickup spawn is available for isolated four-health collection coverage."
	)
	var bonus_cap_pickup := main.get("active_heart_pickup") as HeartPickup
	if bonus_cap_pickup != null:
		player.global_position = bonus_cap_pickup.global_position
		bonus_cap_pickup.call("_on_body_entered", player)
	await get_tree().process_frame
	_require(player.health == 4, "Collecting another heart at four health does not exceed the temporary maximum.")

	await _free_audit_main(main)


func _audit_boomer_displacement_and_pause_cleanup() -> void:
	var root := Node2D.new()
	add_child(root)

	var player := _spawn_player(root, Vector2(220.0, 108.0))
	var spear := _spawn_spear(root, player)
	_set_spear_state_for_audit(spear, Spear.State.FLYING)

	var wander_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 108.0),
		Arena.SpawnEdge.LEFT,
		7201
	)
	await _advance_until(
		func() -> bool:
			return int(wander_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	var wander_position_before := wander_runner.global_position
	_require(
		wander_runner.apply_authored_displacement(Vector2.UP, 18.0, 0.16),
		"Heart Runner accepts Boomer-authored displacement during wandering."
	)
	await _advance_physics(0.20)
	_require(
		int(wander_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		"Heart Runner remains in WANDERING after authored displacement instead of changing to an incorrect state."
	)
	_require(
		wander_runner.get_current_animation_frame_coords().y == HeartRunner.ANIMATION_ROW_CALM,
		"Boomer displacement during wandering keeps the live calm animation row intact."
	)
	await _advance_physics(0.14)
	_require(
		wander_runner.global_position.distance_to(wander_position_before) > 6.0,
		"Heart Runner resumes normal calm movement after a wandering-state Boomer displacement."
	)

	var displaced_startle_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 92.0),
		Arena.SpawnEdge.LEFT,
		72015
	)
	var displaced_startle_alarm_count := 0
	displaced_startle_runner.startled_started.connect(func() -> void:
		displaced_startle_alarm_count += 1
	)
	await _advance_until(
		func() -> bool:
			return int(displaced_startle_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	var displaced_startle_radius := displaced_startle_runner.get_startle_radius()
	displaced_startle_runner.global_position = player.global_position - Vector2(displaced_startle_radius + 12.0, 0.0)
	displaced_startle_runner.wander_target = displaced_startle_runner.global_position
	displaced_startle_runner.travel_direction = Vector2.ZERO
	_set_spear_state_for_audit(spear, Spear.State.HELD)
	_require(
		displaced_startle_runner.apply_authored_displacement(Vector2.RIGHT, 18.0, 0.16),
		"Heart Runner accepts Boomer-authored displacement that can move it into the armed startled radius."
	)
	var startled_from_displacement := await _advance_until(
		func() -> bool:
			return int(displaced_startle_runner.motion_state) == int(HeartRunner.MotionState.STARTLED)
				or int(displaced_startle_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		0.35
	)
	_require(
		startled_from_displacement and displaced_startle_alarm_count == 1,
		"Boomer-authored displacement into the startled radius triggers exactly one panic reaction while Akedra remains armed."
	)
	displaced_startle_runner.queue_free()
	await get_tree().process_frame

	_set_spear_state_for_audit(spear, Spear.State.FLYING)
	var casual_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 132.0),
		Arena.SpawnEdge.LEFT,
		7202
	)
	await _advance_until(
		func() -> bool:
			return int(casual_runner.motion_state) == int(HeartRunner.MotionState.WANDERING),
		1.0
	)
	casual_runner.debug_force_locked_exit(
		Arena.SpawnEdge.RIGHT,
		_get_exit_target_point(Arena.SpawnEdge.RIGHT),
		false
	)
	casual_runner.global_position = Vector2(92.0, TEST_ARENA.position.y + casual_runner.body_radius + 1.0)
	_require(
		casual_runner.apply_authored_displacement(Vector2.UP, 18.0, 0.16),
		"Heart Runner accepts Boomer-authored displacement during CASUAL_EXIT."
	)
	await _advance_physics(0.20)
	_require(
		not casual_runner.is_resolved,
		"Sideways Boomer displacement does not trigger premature cleanup through a non-exit side during CASUAL_EXIT."
	)
	var x_before_resume := casual_runner.global_position.x
	await _advance_physics(0.12)
	_require(
		casual_runner.global_position.x > x_before_resume + 1.0,
		"Heart Runner resumes its locked casual exit route after displacement ends."
	)

	_set_spear_state_for_audit(spear, Spear.State.HELD)
	player.global_position = Vector2(168.0, 84.0)
	var startled_runner := _spawn_runner(
		root,
		player,
		spear,
		Vector2(TEST_ARENA.position.x + 8.0, 84.0),
		Arena.SpawnEdge.LEFT,
		7203
	)
	var startled_alarm_count := 0
	startled_runner.startled_started.connect(func() -> void:
		startled_alarm_count += 1
	)
	await _advance_until(
		func() -> bool:
			return int(startled_runner.motion_state) == int(HeartRunner.MotionState.STARTLED),
		1.0
	)
	var startled_time_before_pause := startled_runner.startled_time_left
	var visual_time_before_pause := startled_runner.visual_time
	var startled_position_before_pause := startled_runner.global_position
	var startled_frame_before_pause := startled_runner.get_current_animation_frame_coords()
	_require(
		startled_runner.apply_authored_displacement(Vector2.UP, 18.0, 0.16),
		"Heart Runner accepts Boomer-authored displacement during the startled hop."
	)
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(
		is_equal_approx(startled_runner.startled_time_left, startled_time_before_pause)
		and is_equal_approx(startled_runner.visual_time, visual_time_before_pause)
		and startled_runner.global_position == startled_position_before_pause
		and startled_runner.get_current_animation_frame_coords() == startled_frame_before_pause,
		"Pause freezes Heart Runner timers, live animation frame state, and movement."
	)
	get_tree().paused = false
	var reached_flee_after_pause := await _advance_until(
		func() -> bool:
			return int(startled_runner.motion_state) == int(HeartRunner.MotionState.FLEEING),
		0.8
	)
	_require(reached_flee_after_pause and startled_alarm_count == 1, "Heart Runner resumes the startled reaction correctly after pause and still enters FLEEING exactly once.")
	_require(
		startled_runner.apply_authored_displacement(Vector2.UP, 18.0, 0.16),
		"Heart Runner accepts Boomer-authored displacement during FLEEING."
	)
	var flee_x_before_resume := startled_runner.global_position.x
	await _advance_physics(0.22)
	_require(
		int(startled_runner.motion_state) == int(HeartRunner.MotionState.FLEEING)
		and startled_runner.global_position.x > flee_x_before_resume - 1.0
		and startled_runner.get_current_animation_frame_coords().y == HeartRunner.ANIMATION_ROW_FLEE,
		"Heart Runner resumes its locked flee route and panic animation after a fleeing-state Boomer displacement."
	)

	root.queue_free()
	await get_tree().process_frame

	var main := await _spawn_main_for_audit()
	var main_player := main.get_node("Player") as Player
	var main_spear := main.get_node("Spear") as Spear
	_set_spear_state_for_audit(main_spear, Spear.State.FLYING)
	main_player.health = 1
	main.set("survival_time", 30.0)
	_require(
		bool(main.call("_try_spawn_heart_runner", true)),
		"Debug Heart Runner spawn is available for restart/game-over cleanup coverage."
	)
	var pause_runner := main.get("active_heart_runner") as HeartRunner
	var pause_runner_timer := pause_runner.wander_time_left if pause_runner != null else 0.0
	var pause_runner_visual := pause_runner.visual_time if pause_runner != null else 0.0
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	if pause_runner != null:
		_require(
			is_equal_approx(pause_runner.wander_time_left, pause_runner_timer)
			and is_equal_approx(pause_runner.visual_time, pause_runner_visual),
			"Pause also freezes the calm wandering timer and animation timing on the Main scene path."
		)
	get_tree().paused = false
	main.call("_restart_run")
	await get_tree().process_frame
	_require(main.get("active_heart_runner") == null and main.get("active_heart_pickup") == null, "Restart clears active Heart Runner opportunities and pickups cleanly.")

	_require(
		bool(main.call("_try_spawn_heart_runner", true)),
		"Heart Runner can be recreated for the game-over cleanup check."
	)
	main.call("_on_player_died")
	await get_tree().process_frame
	_require(main.get("active_heart_runner") == null and main.get("active_heart_pickup") == null, "Game over clears active Heart Runner opportunities and pickups cleanly.")

	await _free_audit_main(main)


func _audit_locked_exit_case(parent: Node, exit_edge: int, label: String) -> void:
	var player := _spawn_player(parent, TEST_ARENA.get_center())
	var spear := _spawn_spear(parent, player)
	var entry_edge := Arena.get_opposite_spawn_edge(exit_edge)
	var runner := _spawn_runner(
		parent,
		player,
		spear,
		_get_entry_position_for_edge(entry_edge),
		entry_edge,
		7300 + exit_edge
	)
	var exit_target_point := _get_exit_target_point(exit_edge)
	runner.debug_force_locked_exit(exit_edge, exit_target_point, true)

	var escape_count := 0
	runner.escaped.connect(func(_spawned_by_debug: bool) -> void:
		escape_count += 1
	)
	runner.global_position = _get_pre_exit_test_position(exit_edge, runner.body_radius)
	var crossed_boundary := false
	var kept_speed := false
	for _frame in range(int(ceil(1.5 * 60.0))):
		await get_tree().physics_frame
		if not is_instance_valid(runner):
			break
		if not crossed_boundary and _is_beyond_destination_boundary(runner.global_position, exit_edge, runner.body_radius):
			crossed_boundary = true
			kept_speed = absf(runner.velocity.length() - runner.move_speed) <= 0.25
		if escape_count > 0:
			break

	await get_tree().process_frame
	_require(crossed_boundary, "Heart Runner can physically pass through the %s assigned exit boundary during the refined cleanup flow." % label)
	_require(kept_speed, "Heart Runner does not stop or lose speed at the %s destination-side boundary during locked escape cleanup." % label)
	_require(escape_count == 1, "Heart Runner escape emits exactly once through the %s assigned exit." % label)
	_require(not is_instance_valid(runner), "Heart Runner frees itself immediately after the %s escape resolves." % label)

	player.queue_free()
	spear.queue_free()
	await get_tree().process_frame


func _spawn_main_for_audit() -> Node:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	(main.get_node("SpawnTimer") as Timer).stop()
	(main.get_node("OpportunityTimer") as Timer).stop()
	return main


func _spawn_live_main_for_audit() -> Node:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	return main


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(TEST_ARENA)
	player.reset_for_new_run(position, TEST_ARENA)
	return player


func _spawn_spear(parent: Node, player: Player) -> Spear:
	var spear := SpearScene.instantiate() as Spear
	parent.add_child(spear)
	spear.setup(player, TEST_ARENA)
	spear.reset_for_new_run(player, TEST_ARENA)
	return spear


func _spawn_runner(
	parent: Node,
	player: Player,
	spear: Spear,
	entry_position: Vector2,
	spawn_edge: int,
	random_seed: int = TEST_SEED
) -> HeartRunner:
	var runner := HeartRunnerScene.instantiate() as HeartRunner
	parent.add_child(runner)
	runner.setup(
		TEST_ARENA,
		entry_position,
		spawn_edge,
		140.0,
		player,
		spear,
		false,
		random_seed
	)
	return runner


func _set_spear_state_for_audit(spear: Spear, new_state: int) -> void:
	spear.set_active(false)
	spear.call("_set_state", new_state)


func _get_entry_position_for_edge(edge: int) -> Vector2:
	match edge:
		Arena.SpawnEdge.TOP:
			return Vector2(TEST_ARENA.get_center().x, TEST_ARENA.position.y + 8.0)
		Arena.SpawnEdge.BOTTOM:
			return Vector2(TEST_ARENA.get_center().x, TEST_ARENA.end.y - 8.0)
		Arena.SpawnEdge.LEFT:
			return Vector2(TEST_ARENA.position.x + 8.0, TEST_ARENA.get_center().y)
		_:
			return Vector2(TEST_ARENA.end.x - 8.0, TEST_ARENA.get_center().y)


func _get_exit_target_point(edge: int) -> Vector2:
	match edge:
		Arena.SpawnEdge.TOP:
			return Vector2(TEST_ARENA.get_center().x, TEST_ARENA.position.y + 6.0)
		Arena.SpawnEdge.BOTTOM:
			return Vector2(TEST_ARENA.get_center().x, TEST_ARENA.end.y - 6.0)
		Arena.SpawnEdge.LEFT:
			return Vector2(TEST_ARENA.position.x + 6.0, TEST_ARENA.get_center().y)
		_:
			return Vector2(TEST_ARENA.end.x - 6.0, TEST_ARENA.get_center().y)


func _is_beyond_destination_boundary(position: Vector2, exit_edge: int, body_radius: float) -> bool:
	match exit_edge:
		Arena.SpawnEdge.TOP:
			return position.y < TEST_ARENA.position.y + body_radius
		Arena.SpawnEdge.BOTTOM:
			return position.y > TEST_ARENA.end.y - body_radius
		Arena.SpawnEdge.LEFT:
			return position.x < TEST_ARENA.position.x + body_radius
		_:
			return position.x > TEST_ARENA.end.x - body_radius


func _get_pre_exit_test_position(exit_edge: int, body_radius: float) -> Vector2:
	match exit_edge:
		Arena.SpawnEdge.TOP:
			return Vector2(TEST_ARENA.get_center().x, TEST_ARENA.position.y + body_radius + 2.0)
		Arena.SpawnEdge.BOTTOM:
			return Vector2(TEST_ARENA.get_center().x, TEST_ARENA.end.y - body_radius - 2.0)
		Arena.SpawnEdge.LEFT:
			return Vector2(TEST_ARENA.position.x + body_radius + 2.0, TEST_ARENA.get_center().y)
		_:
			return Vector2(TEST_ARENA.end.x - body_radius - 2.0, TEST_ARENA.get_center().y)


func _free_audit_main(main: Node) -> void:
	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _advance_until(condition: Callable, timeout: float) -> bool:
	var frames := int(ceil(timeout * 60.0))
	for _index in range(maxi(frames, 1)):
		if bool(condition.call()):
			return true
		await get_tree().physics_frame
	return bool(condition.call())


func _advance_physics(duration: float) -> void:
	var frames := int(ceil(duration * 60.0))
	for _index in range(maxi(frames, 1)):
		await get_tree().physics_frame


func _sample_runner_frames(runner: HeartRunner, duration: float) -> Array[Vector2i]:
	var samples: Array[Vector2i] = []
	var frames := int(ceil(duration * 60.0))
	for _index in range(maxi(frames, 1)):
		await get_tree().physics_frame
		if not is_instance_valid(runner) or runner.sprite == null:
			break
		samples.append(runner.get_current_animation_frame_coords())
	return samples


func _all_samples_use_row(samples: Array[Vector2i], row: int) -> bool:
	if samples.is_empty():
		return false
	for frame_coords in samples:
		if frame_coords.y != row:
			return false
	return true


func _count_unique_frames(samples: Array[Vector2i]) -> int:
	var seen_frames := {}
	for frame_coords in samples:
		seen_frames[frame_coords] = true
	return seen_frames.size()


func _count_frame_changes(samples: Array[Vector2i]) -> int:
	if samples.size() <= 1:
		return 0
	var change_count := 0
	var previous_frame := samples[0]
	for index in range(1, samples.size()):
		var frame_coords := samples[index]
		if frame_coords != previous_frame:
			change_count += 1
		previous_frame = frame_coords
	return change_count


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
