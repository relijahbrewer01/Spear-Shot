extends Node

const MainScene := preload("res://Main.tscn")
const PlayerScene := preload("res://Player.tscn")
const SpearScene := preload("res://Spear.tscn")
const HeartRunnerScene := preload("res://HeartRunner.tscn")
const HeartPickupScene := preload("res://HeartPickup.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_spawn_rules_and_debug_behavior()
	await _audit_spear_contract_and_exit_plane_cleanup()
	await _audit_main_escape_cleanup_and_repeat_spawns()
	await _audit_pickup_heal_and_cooldown_flow()
	await _audit_pickup_warning_pause_and_cleanup()

	for failure in failures:
		push_error("HEART RUNNER RUNTIME AUDIT: %s" % failure)
	print("Heart Runner runtime audit passed." if failures.is_empty() else "Heart Runner runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


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
		is_equal_approx(float(main.call("_get_current_heart_runner_spawn_chance")), 0.10),
		"Heart Runner chance is 0.10 at one health."
	)
	player.health = 4
	_require(
		is_equal_approx(float(main.call("_get_current_heart_runner_spawn_chance")), 0.0),
		"Heart Runner does not roll while the player already has four health."
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
		debug_runner.global_position = Vector2(TEST_ARENA.end.x - debug_runner.body_radius - 2.0, TEST_ARENA.get_center().y)
		await _advance_physics(0.18)
	_require(main.get("active_heart_runner") == null, "Debug Heart Runner escape clears Main's active Runner reference.")
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


func _audit_spear_contract_and_exit_plane_cleanup() -> void:
	var contract_root := Node2D.new()
	add_child(contract_root)

	var player := _spawn_player(contract_root, Vector2(96.0, 108.0))
	var spear := SpearScene.instantiate() as Spear
	contract_root.add_child(spear)
	spear.setup(player, TEST_ARENA)
	spear.reset_for_new_run(player, TEST_ARENA)

	var runner := HeartRunnerScene.instantiate() as HeartRunner
	contract_root.add_child(runner)
	runner.setup(
		TEST_ARENA,
		Vector2(150.0, 108.0),
		Vector2(320.0, 108.0),
		Arena.SpawnEdge.RIGHT,
		140.0
	)

	var pickup := HeartPickupScene.instantiate() as HeartPickup
	contract_root.add_child(pickup)
	pickup.setup(player, TEST_ARENA, TEST_ARENA.get_center())

	_require(
		bool(spear.call("_is_valid_spear_hittable_body", runner)),
		"Spear recognizes Heart Runner through the explicit spear_hittable contract."
	)
	_require(
		not bool(spear.call("_is_valid_spear_hittable_body", pickup)),
		"Heart pickups are not treated as spear-hittable combat targets."
	)

	_require(spear.try_throw(Vector2(320.0, 108.0)), "Spear can enter flight for the Heart Runner hit contract audit.")
	var hit_response := int(spear.call("_hit_enemy_if_needed", runner))
	_require(hit_response == Enemy.HitResponse.DAMAGED, "Heart Runner hit returns DAMAGED rather than STOPPED.")
	_require(int(spear.state) == int(Spear.State.FLYING), "Heart Runner hit does not stop spear flight.")
	await _advance_frames(2)

	contract_root.queue_free()
	await get_tree().process_frame

	var motion_root := Node2D.new()
	add_child(motion_root)

	await _audit_boundary_crossing_case(
		motion_root,
		Vector2(TEST_ARENA.position.x + 24.0, TEST_ARENA.get_center().y),
		Vector2(TEST_ARENA.end.x - 24.0, TEST_ARENA.get_center().y),
		Arena.SpawnEdge.RIGHT,
		"right"
	)
	await _audit_boundary_crossing_case(
		motion_root,
		Vector2(TEST_ARENA.end.x - 24.0, TEST_ARENA.get_center().y),
		Vector2(TEST_ARENA.position.x + 24.0, TEST_ARENA.get_center().y),
		Arena.SpawnEdge.LEFT,
		"left"
	)
	await _audit_boundary_crossing_case(
		motion_root,
		Vector2(TEST_ARENA.get_center().x, TEST_ARENA.position.y + 24.0),
		Vector2(TEST_ARENA.get_center().x, TEST_ARENA.end.y - 24.0),
		Arena.SpawnEdge.BOTTOM,
		"bottom"
	)
	await _audit_boundary_crossing_case(
		motion_root,
		Vector2(TEST_ARENA.get_center().x, TEST_ARENA.end.y - 24.0),
		Vector2(TEST_ARENA.get_center().x, TEST_ARENA.position.y + 24.0),
		Arena.SpawnEdge.TOP,
		"top"
	)

	var side_runner := HeartRunnerScene.instantiate() as HeartRunner
	motion_root.add_child(side_runner)
	side_runner.setup(
		TEST_ARENA,
		Vector2(24.0, 108.0),
		Vector2(340.0, 108.0),
		Arena.SpawnEdge.RIGHT,
		140.0
	)
	var side_escape_count := 0
	side_runner.escaped.connect(func(_spawned_by_debug: bool) -> void:
		side_escape_count += 1
	)
	side_runner.global_position = Vector2(72.0, TEST_ARENA.position.y + side_runner.body_radius + 1.0)
	_require(
		side_runner.apply_authored_displacement(Vector2.UP, 18.0, 0.16),
		"Heart Runner accepts authored displacement from external effects."
	)
	await _advance_physics(0.20)
	_require(side_escape_count == 0, "Heart Runner does not despawn just by touching a non-exit arena side during authored displacement.")
	var x_before_resume := side_runner.global_position.x
	await _advance_physics(0.10)
	_require(side_runner.global_position.x > x_before_resume + 1.0, "Heart Runner resumes its original edge-to-edge travel after authored displacement ends.")
	var resumed_escape := await _advance_until(
		func() -> bool: return side_escape_count == 1,
		3.2
	)
	_require(resumed_escape and side_escape_count == 1, "After Boomer displacement, Heart Runner still exits through its assigned destination plane exactly once.")

	motion_root.queue_free()
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
		first_runner.global_position = _get_pre_exit_test_position(int(first_runner.exit_edge), first_runner.body_radius)
	var first_escape_cleared := await _advance_until(
		func() -> bool: return main.get("active_heart_runner") == null,
		0.25
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
		second_runner.global_position = _get_pre_exit_test_position(int(second_runner.exit_edge), second_runner.body_radius)
	var second_escape_cleared := await _advance_until(
		func() -> bool: return main.get("active_heart_runner") == null,
		0.25
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


func _audit_pickup_warning_pause_and_cleanup() -> void:
	var main := await _spawn_main_for_audit()
	var opportunity_timer := main.get_node("OpportunityTimer") as Timer
	var player := main.get_node("Player") as Player
	player.health = 2
	main.set("survival_time", 50.0)

	_require(
		bool(main.call("_try_spawn_heart_runner", false)),
		"Organic Heart Runner spawn succeeds for the expiration-path audit."
	)
	var runner := main.get("active_heart_runner") as HeartRunner
	if runner != null:
		runner.global_position = TEST_ARENA.get_center()
		runner.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, runner.global_position, Vector2.RIGHT)
	await get_tree().process_frame

	var pickup := main.get("active_heart_pickup") as HeartPickup
	var warning_count := 0
	if pickup != null:
		pickup.warning_started.connect(func() -> void:
			warning_count += 1
		)
		pickup.lifetime_left = 0.08
	await _advance_physics(0.04)
	_require(warning_count == 1, "Heart pickup emits one restrained warning during the final expiration window.")
	await _advance_physics(0.10)
	var expected_expire_cooldown := 50.0 + float(main.get("heart_runner_post_resolution_cooldown"))
	_require(main.get("active_heart_pickup") == null, "Heart pickup expires cleanly after its warning window ends.")
	_require(
		is_equal_approx(float(main.get("heart_runner_next_eligible_time")), expected_expire_cooldown),
		"Pickup expiration also stamps the Heart Runner cooldown exactly once."
	)

	main.set("heart_runner_next_eligible_time", 0.0)
	_require(
		bool(main.call("_try_spawn_heart_runner", true)),
		"Debug Heart Runner spawn is available for pause and cleanup checks."
	)
	var debug_runner := main.get("active_heart_runner") as HeartRunner
	var runner_position_before_pause := debug_runner.global_position if debug_runner != null else Vector2.ZERO
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	if debug_runner != null:
		_require(debug_runner.global_position == runner_position_before_pause, "Pause freezes Heart Runner movement.")
	get_tree().paused = false
	await _advance_physics(0.10)
	if debug_runner != null:
		_require(debug_runner.global_position.distance_to(runner_position_before_pause) > 1.0, "Heart Runner movement resumes after pause.")

	main.call("_clear_opportunities")
	_require(
		bool(main.call("_spawn_heart_pickup", TEST_ARENA.get_center(), true)),
		"Heart pickup can be spawned in isolation for pause timing checks."
	)
	var pause_pickup := main.get("active_heart_pickup") as HeartPickup
	var lifetime_before_pause := pause_pickup.lifetime_left if pause_pickup != null else 0.0
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	if pause_pickup != null:
		_require(is_equal_approx(pause_pickup.lifetime_left, lifetime_before_pause), "Pause freezes Heart pickup lifetime and warning timing.")
	get_tree().paused = false
	await _advance_physics(0.05)
	if pause_pickup != null:
		_require(pause_pickup.lifetime_left < lifetime_before_pause, "Heart pickup timing resumes after pause.")

	main.call("_restart_run")
	await get_tree().process_frame
	_require(main.get("active_heart_runner") == null and main.get("active_heart_pickup") == null, "Restart clears active Heart Runner opportunities and pickups.")
	_require(opportunity_timer.time_left > 0.0, "Restart restarts the separate Heart Runner opportunity timer.")

	_require(
		bool(main.call("_spawn_heart_pickup", TEST_ARENA.get_center(), true)),
		"Heart pickup can be recreated for the game-over cleanup check."
	)
	main.call("_on_player_died")
	await get_tree().process_frame
	_require(main.get("active_heart_runner") == null and main.get("active_heart_pickup") == null, "Game over clears active Heart Runner opportunities and pickups.")
	_require(opportunity_timer.is_stopped(), "Game over stops the separate Heart Runner opportunity timer.")

	await _free_audit_main(main)


func _spawn_main_for_audit() -> Node:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	(main.get_node("SpawnTimer") as Timer).stop()
	(main.get_node("OpportunityTimer") as Timer).stop()
	return main


func _audit_boundary_crossing_case(
	parent: Node,
	entry_position: Vector2,
	target_position: Vector2,
	exit_edge: int,
	label: String
) -> void:
	var runner := HeartRunnerScene.instantiate() as HeartRunner
	parent.add_child(runner)
	runner.setup(TEST_ARENA, entry_position, target_position, exit_edge, 140.0)

	var escape_count := 0
	runner.escaped.connect(func(_spawned_by_debug: bool) -> void:
		escape_count += 1
	)

	var crossed_boundary := false
	var kept_speed := false
	for _frame in range(int(ceil(4.0 * 60.0))):
		await get_tree().physics_frame
		if not is_instance_valid(runner):
			break
		if not crossed_boundary and _is_beyond_destination_boundary(runner.global_position, exit_edge, runner.body_radius):
			crossed_boundary = true
			kept_speed = absf(runner.velocity.length() - runner.move_speed) <= 0.25
		if escape_count > 0:
			break

	await get_tree().process_frame
	_require(crossed_boundary, "Heart Runner can physically pass through the %s destination-side arena boundary." % label)
	_require(kept_speed, "Heart Runner does not stop or lose speed at the %s destination-side boundary." % label)
	_require(escape_count == 1, "Heart Runner escape emits exactly once through the %s assigned exit." % label)
	_require(not is_instance_valid(runner), "Heart Runner frees itself immediately after the %s escape resolves." % label)


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


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(TEST_ARENA)
	player.reset_for_new_run(position, TEST_ARENA)
	return player


func _advance_frames(frame_count: int) -> void:
	for _index in range(maxi(frame_count, 1)):
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


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
