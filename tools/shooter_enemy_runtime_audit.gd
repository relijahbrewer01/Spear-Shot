extends Node

const PlayerScene := preload("res://Player.tscn")
const ShooterScene := preload("res://ShooterEnemy.tscn")
const DartScene := preload("res://DartProjectile.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const MainScene := preload("res://Main.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))
const SPAWN_SOURCE_AMBIENT := 0
const SPAWN_SOURCE_DEBUG := 2

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	_ensure_input_actions()
	await _audit_movement_ranges()
	await _audit_cancel_reposition_and_shove()
	await _audit_attack_state_machine()
	await _audit_two_shooter_readability_and_cap()
	await _audit_burst_pause_and_cancellation()
	await _audit_dart_damage_and_invulnerability()
	await _audit_dart_motion_and_cleanup()
	await _audit_shooter_death_and_score()
	await _audit_main_spawn_intro_and_projectile_cleanup()
	await _audit_no_shielded_interception_yet()

	for failure in failures:
		push_error("SHOOTER RUNTIME AUDIT: %s" % failure)
	print("Shooter enemy runtime audit passed." if failures.is_empty() else "Shooter enemy runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_movement_ranges() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(96.0, 108.0))

	var far_shooter := _spawn_shooter(root, player, Vector2(250.0, 108.0))
	far_shooter.first_attack_delay_left = 99.0
	var far_start_x := far_shooter.global_position.x
	await _advance_physics(0.25)
	_require(far_shooter.global_position.x < far_start_x - 1.0, "Shooter approaches when too far away.")

	var close_shooter := _spawn_shooter(root, player, Vector2(130.0, 108.0))
	close_shooter.first_attack_delay_left = 99.0
	var close_start_x := close_shooter.global_position.x
	await _advance_physics(0.25)
	_require(close_shooter.global_position.x > close_start_x + 1.0, "Shooter retreats when too close.")

	var stable_shooter := _spawn_shooter(root, player, Vector2(192.0, 108.0))
	stable_shooter.first_attack_delay_left = 99.0
	var stable_start := stable_shooter.global_position
	await _advance_physics(0.25)
	_require(stable_shooter.global_position.distance_to(stable_start) < 2.0, "Shooter stays stable inside preferred range.")

	player.global_position = Vector2(342.0, 108.0)
	var wall_shooter := _spawn_shooter(root, player, Vector2(357.0, 108.0))
	wall_shooter.first_attack_delay_left = 99.0
	var wall_start_y := wall_shooter.global_position.y
	await _advance_physics(0.45)
	_require(TEST_ARENA.has_point(wall_shooter.global_position), "Wall fallback keeps Shooter inside the arena.")
	_require(absf(wall_shooter.global_position.y - wall_start_y) > 0.5, "Wall fallback slides laterally instead of jittering into the wall.")

	var arc_shooter := _spawn_shooter(root, player, Vector2(190.0, 108.0))
	player.global_position = Vector2(150.0, 108.0)
	arc_shooter.shooter_state = ShooterEnemy.ShooterState.ARC_REPOSITION
	arc_shooter.arc_reposition_left = arc_shooter.arc_reposition_duration
	arc_shooter.arc_reposition_side = 1
	var close_arc_distance := arc_shooter.global_position.distance_to(player.global_position)
	await _advance_physics(0.12)
	_require(arc_shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION, "Dangerously close player cancels arc reposition.")
	_require(arc_shooter.global_position.distance_to(player.global_position) > close_arc_distance, "Retreat overrides arc movement at dangerous range.")

	player.global_position = Vector2(120.0, 108.0)
	var long_arc_shooter := _spawn_shooter(root, player, Vector2(226.0, 108.0), 46.62)
	long_arc_shooter.shooter_state = ShooterEnemy.ShooterState.ARC_REPOSITION
	long_arc_shooter.arc_reposition_left = long_arc_shooter.arc_reposition_duration
	long_arc_shooter.arc_reposition_side = 1
	var long_arc_start := long_arc_shooter.global_position
	await _advance_physics(long_arc_shooter.arc_reposition_duration + 0.05)
	var long_arc_distance := long_arc_shooter.global_position.distance_to(long_arc_start)
	_require(long_arc_distance >= 56.0 and long_arc_distance <= 82.0, "Post-burst arc reposition covers a meaningful 60-ish pixel relocation in open space.")

	var reversing_arc_player := _spawn_player(root, Vector2(250.0, 80.0))
	var reversing_arc_shooter := _spawn_shooter(root, reversing_arc_player, Vector2(310.0, 22.0), 46.62)
	reversing_arc_shooter.shooter_state = ShooterEnemy.ShooterState.ARC_REPOSITION
	reversing_arc_shooter.arc_reposition_left = reversing_arc_shooter.arc_reposition_duration
	reversing_arc_shooter.arc_reposition_side = -1
	await _advance_physics(0.12)
	var reversed_side := reversing_arc_shooter.arc_reposition_side
	await _advance_physics(0.25)
	_require(reversing_arc_shooter.arc_reposition_side == reversed_side, "Arc reposition reverses at most once when the first side is blocked.")

	root.queue_free()
	await get_tree().process_frame


func _audit_cancel_reposition_and_shove() -> void:
	var cancel_root := Node2D.new()
	add_child(cancel_root)

	var player := _spawn_player(cancel_root, Vector2(120.0, 108.0))
	var shooter := _spawn_shooter(cancel_root, player, Vector2(220.0, 108.0), 46.62)
	shooter.first_attack_delay_left = 0.0
	shooter.attack_cooldown_left = 0.0
	shooter.minimum_dart_interval_left = 0.0
	var cancelled_dart_counter := {"count": 0}
	shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		cancelled_dart_counter["count"] += 1
	)
	await _advance_physics(0.05)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM, "Shooter begins aiming once inside firing range.")
	player.global_position = Vector2(40.0, 108.0)
	var cancel_start := shooter.global_position
	await _advance_physics(0.05)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM_CANCEL_REPOSITION, "Too-far pre-lock movement cancels AIM into committed reposition.")
	await _advance_physics(0.25)
	var cancel_displacement := shooter.global_position - cancel_start
	_require(int(cancelled_dart_counter["count"]) == 0, "Cancelled AIM fires zero darts.")
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM_CANCEL_REPOSITION, "Shooter cannot re-enter AIM during cancellation reposition.")
	_require(absf(cancel_displacement.y) > 4.0 and absf(cancel_displacement.y) > absf(cancel_displacement.x), "Too-far cancellation repositions laterally instead of immediately sprinting straight back into AIM.")
	await _advance_physics(shooter.aim_cancel_reposition_duration + 0.10)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION, "Cancelled AIM ends in ordinary reposition after the committed travel finishes.")
	await _free_test_root(cancel_root)

	var retreat_root := Node2D.new()
	add_child(retreat_root)
	var retreat_player := _spawn_player(retreat_root, Vector2(130.0, 108.0))
	var retreat_shooter := _spawn_shooter(retreat_root, retreat_player, Vector2(220.0, 108.0))
	retreat_shooter.first_attack_delay_left = 0.0
	retreat_shooter.attack_cooldown_left = 0.0
	retreat_shooter.minimum_dart_interval_left = 0.0
	await _advance_physics(0.05)
	retreat_player.global_position = retreat_shooter.global_position - Vector2.RIGHT * 30.0
	retreat_shooter.shove_cooldown_left = 1.0
	var retreat_start_x := retreat_shooter.global_position.x
	await _advance_physics(0.08)
	_require(retreat_shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION, "Too-close AIM cancellation returns to ordinary retreat when shove is unavailable.")
	_require(retreat_shooter.global_position.x > retreat_start_x + 1.0, "Too-close AIM cancellation immediately creates space.")
	await _free_test_root(retreat_root)

	var overlap_root := Node2D.new()
	add_child(overlap_root)
	var overlap_player := _spawn_player(overlap_root, Vector2(176.0, 108.0))
	var overlap_shooter := _spawn_shooter(overlap_root, overlap_player, Vector2(178.0, 108.0))
	overlap_shooter.first_attack_delay_left = 99.0
	overlap_shooter.shove_cooldown_left = 99.0
	var overlap_health := overlap_player.health
	await _advance_physics(0.20)
	_require(overlap_player.health == overlap_health, "Shooter body overlap no longer deals ordinary contact damage.")
	await _free_test_root(overlap_root)

	var shove_root := Node2D.new()
	add_child(shove_root)
	var shove_player := _spawn_player(shove_root, Vector2(250.0, 108.0))
	var shove_shooter := _spawn_shooter(shove_root, shove_player, Vector2(234.0, 108.0))
	shove_shooter.first_attack_delay_left = 0.0
	shove_shooter.attack_cooldown_left = 0.0
	shove_shooter.minimum_dart_interval_left = 0.0
	shove_shooter.preferred_distance_min = 60.0
	shove_shooter.preferred_distance_max = 140.0
	shove_shooter.attack_range_max = 160.0
	shove_shooter.aim_cancel_min_distance = 60.0
	shove_shooter.aim_cancel_max_distance = 160.0
	var shove_counter := {"count": 0}
	shove_shooter.shove_used.connect(func() -> void:
		shove_counter["count"] += 1
	)
	var shove_health := shove_player.health
	var reached_shove_windup := await _advance_until(
		func() -> bool: return shove_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_WINDUP,
		0.10,
		"successful shove windup",
		func() -> String:
			return _describe_shooter_context(shove_shooter, shove_player, int(shove_counter["count"]))
	)
	_require(reached_shove_windup and shove_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_WINDUP, "Close-range Shooter starts shove windup instead of using body damage.")
	var shove_started := await _advance_until(
		func() -> bool: return int(shove_counter["count"]) >= 1,
		shove_shooter.shove_windup_duration + 0.12,
		"successful shove emit",
		func() -> String:
			return _describe_shooter_context(shove_shooter, shove_player, int(shove_counter["count"]))
	)
	_require(shove_started and int(shove_counter["count"]) == 1, "Shooter shove fires once per close-range defense.")
	_require(shove_player.health == shove_health, "Shooter shove deals zero health damage.")
	_require(shove_player.is_in_forced_movement(), "Successful shove starts authored player forced movement.")
	_require(shove_player.has_shove_damage_protection(), "Successful shove enables shove-specific damage protection on the player.")
	var shoved_start := shove_player.global_position
	await _advance_physics(0.10)
	_require(shove_player.global_position.distance_to(shoved_start) > 4.0, "Successful shove moves the player a meaningful distance.")
	_require(not shove_player.take_damage(Vector2.ZERO), "Protected shove movement blocks ordinary contact damage.")
	shove_shooter.attack_cooldown_left = 0.35
	shove_shooter.minimum_dart_interval_left = 0.40
	var reached_post_shove := await _advance_until(
		func() -> bool: return shove_shooter.shooter_state == ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION,
		shove_shooter.shove_active_duration + 0.20,
		"successful shove post-shove reposition",
		func() -> String:
			return _describe_shooter_context(shove_shooter, shove_player, int(shove_counter["count"]))
	)
	_require(
		reached_post_shove and shove_shooter.shooter_state == ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION,
		"Successful shove enters the dedicated post-shove reposition state."
	)
	_require(reached_post_shove and shove_player.is_in_shove_forced_movement(), "Post-shove reposition can begin while shove-authored forced movement is still resolving.")
	await _advance_physics(0.08)
	_require(shove_shooter.shooter_state == ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION, "Follow-up reposition stays committed before the shove movement has fully resolved.")
	_require(shove_shooter.shooter_state != ShooterEnemy.ShooterState.AIM, "Successful shove cannot begin its follow-up AIM before forced movement ends.")
	var shove_finished := await _advance_until(
		func() -> bool: return not shove_player.is_in_shove_forced_movement(),
		0.30,
		"successful shove forced movement resolve",
		func() -> String:
			return _describe_shooter_context(shove_shooter, shove_player, int(shove_counter["count"]))
	)
	_require(shove_finished, "Successful shove-authored forced movement resolves within the authored duration.")
	_require(not shove_player.has_shove_damage_protection(), "Shove-specific damage protection ends when the authored forced movement ends.")
	await _advance_physics(0.10)
	_require(shove_shooter.shooter_state == ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION, "Attack cooldown and minimum dart interval still gate the follow-up after shove.")
	var follow_up_aim_started := await _advance_until(
		func() -> bool: return shove_shooter.shooter_state == ShooterEnemy.ShooterState.AIM,
		1.00,
		"successful shove follow-up aim",
		func() -> String:
			return _describe_shooter_context(shove_shooter, shove_player, int(shove_counter["count"]))
	)
	_require(follow_up_aim_started and shove_shooter.shooter_state == ShooterEnemy.ShooterState.AIM, "Successful shove prioritizes the next valid AIM after the protection window and attack gates clear.")
	var reached_follow_up_locked := await _advance_until(
		func() -> bool: return shove_shooter.shooter_state == ShooterEnemy.ShooterState.LOCKED,
		shove_shooter.aim_duration + 0.20,
		"successful shove follow-up locked",
		func() -> String:
			return _describe_shooter_context(shove_shooter, shove_player, int(shove_counter["count"]))
	)
	_require(reached_follow_up_locked and shove_shooter.shooter_state == ShooterEnemy.ShooterState.LOCKED, "Successful shove follow-up still pays the full locked telegraph after AIM.")
	_require(shove_shooter.shove_cooldown_left > 0.0, "Shooter shove cooldown is respected after use.")
	await _free_test_root(shove_root)

	var clamped_root := Node2D.new()
	add_child(clamped_root)
	var clamped_player := _spawn_player(clamped_root, Vector2(TEST_ARENA.end.x - 10.0, 140.0))
	var clamped_shooter := _spawn_shooter(clamped_root, clamped_player, Vector2(TEST_ARENA.end.x - 26.0, 140.0))
	clamped_shooter.first_attack_delay_left = 0.0
	clamped_shooter.attack_cooldown_left = 0.0
	clamped_shooter.minimum_dart_interval_left = 0.0
	var clamped_start := clamped_player.global_position
	var clamped_windup_started := await _advance_until(
		func() -> bool: return clamped_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_WINDUP,
		0.10,
		"clamped shove windup",
		func() -> String:
			return _describe_shooter_context(clamped_shooter, clamped_player)
	)
	_require(clamped_windup_started, "Clamped wall shove still enters shove windup.")
	await _advance_physics(clamped_shooter.shove_windup_duration + 0.03)
	await _advance_physics(0.10)
	var clamped_distance := clamped_player.global_position.distance_to(clamped_start)
	_require(clamped_player.is_in_shove_forced_movement(), "Clamped shove still counts as a successful forced-movement hit.")
	_require(clamped_player.has_shove_damage_protection(), "Clamped shove keeps the shove-specific damage protection active.")
	_require(clamped_distance < clamped_shooter.shove_knockback_distance - 8.0, "Arena clamping can shorten the intended shove travel near the wall.")
	await _advance_physics(clamped_shooter.shove_active_duration + 0.03)
	_require(clamped_shooter.shooter_state == ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION, "Clamped successful shove still enters the ordinary successful-shove follow-up path.")
	_require(clamped_shooter.shove_has_attempted_hit, "Clamped shove does not repeatedly reapply its hit attempt.")
	await _free_test_root(clamped_root)

	var miss_root := Node2D.new()
	add_child(miss_root)
	var miss_player := _spawn_player(miss_root, Vector2(300.0, 108.0))
	var miss_shooter := _spawn_shooter(miss_root, miss_player, Vector2(284.0, 108.0))
	miss_shooter.first_attack_delay_left = 99.0
	var miss_windup_started := await _advance_until(
		func() -> bool: return miss_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_WINDUP,
		0.10,
		"missed shove windup",
		func() -> String:
			return _describe_shooter_context(miss_shooter, miss_player)
	)
	_require(miss_windup_started, "Missed close-range Shooter still starts from shove windup.")
	miss_player.global_position = Vector2(340.0, 108.0)
	var reached_shove_recover := await _advance_until(
		func() -> bool: return miss_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_RECOVER,
		miss_shooter.shove_windup_duration + miss_shooter.shove_active_duration + 0.12,
		"missed shove recover",
		func() -> String:
			return _describe_shooter_context(miss_shooter, miss_player)
	)
	_require(not miss_player.is_in_forced_movement(), "Missed shove causes no knockback.")
	_require(reached_shove_recover and miss_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_RECOVER, "Missed shove stays on the ordinary shove-recover path instead of taking the successful follow-up route.")
	_require(miss_shooter.shooter_state != ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION, "Missed shove never enters the successful-shove follow-up state.")
	await _free_test_root(miss_root)

	var dodge_root := Node2D.new()
	add_child(dodge_root)
	var dodge_player := _spawn_player(dodge_root, Vector2(110.0, 150.0))
	dodge_player.try_start_dodge(Vector2.RIGHT)
	var dodge_shooter := _spawn_shooter(dodge_root, dodge_player, Vector2(94.0, 150.0))
	dodge_shooter.shove_direction = Vector2.RIGHT
	dodge_shooter.call("_enter_shove_active_state")
	_require(not dodge_player.is_in_forced_movement(), "Active dodge suppresses shove knockback.")
	_require(dodge_player.health == dodge_player.max_health, "Shove stays non-damaging during active dodge.")
	await _free_test_root(dodge_root)

	var grace_root := Node2D.new()
	add_child(grace_root)
	var grace_player := _spawn_player(grace_root, Vector2(110.0, 176.0))
	grace_player.dodge_exit_invulnerability_left = 0.10
	var grace_shooter := _spawn_shooter(grace_root, grace_player, Vector2(94.0, 176.0))
	grace_shooter.shove_direction = Vector2.RIGHT
	grace_shooter.call("_enter_shove_active_state")
	_require(not grace_player.is_in_forced_movement(), "Dodge exit grace suppresses shove knockback.")
	await _free_test_root(grace_root)


func _audit_attack_state_machine() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(104.0, 108.0))
	var shooter := _spawn_shooter(root, player, Vector2(200.0, 108.0))
	shooter.first_attack_delay_left = 0.0
	shooter.attack_cooldown_left = 0.0
	shooter.minimum_dart_interval_left = 0.0

	var fired_directions: Array[Vector2] = []
	var fired_frames: Array[int] = []
	var fired_burst_ids: Array[int] = []
	var fired_dart_indices: Array[int] = []
	shooter.dart_requested.connect(func(_spawn_position: Vector2, fire_direction: Vector2, burst_id: int, dart_index: int) -> void:
		fired_directions.append(fire_direction)
		fired_frames.append(Engine.get_physics_frames())
		fired_burst_ids.append(burst_id)
		fired_dart_indices.append(dart_index)
	)

	await _advance_physics(0.05)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM, "Shooter starts with AIM instead of firing immediately.")

	player.global_position = Vector2(104.0, 128.0)
	await _advance_physics(shooter.aim_duration + 0.05)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.LOCKED, "Shooter enters LOCKED after the aim telegraph.")
	var locked_direction: Vector2 = shooter.locked_direction
	player.global_position = Vector2(104.0, 60.0)
	await _advance_physics(shooter.locked_duration + shooter.burst_interval + 0.12)

	_require(fired_directions.size() == 2, "Shooter fires exactly two darts for one completed attack.")
	if fired_directions.size() >= 2:
		_require(fired_directions[0].distance_to(locked_direction) < 0.001, "Dart uses the locked aim direction.")
		_require(fired_directions[1].distance_to(locked_direction) < 0.001, "Second dart uses the same locked aim direction.")
		_require(fired_burst_ids[0] == fired_burst_ids[1], "Both darts share one burst id.")
		_require(fired_dart_indices == [0, 1], "Burst darts use deterministic indices 0 and 1.")
		var burst_interval := float(fired_frames[1] - fired_frames[0]) / 60.0
		_require(
			absf(burst_interval - shooter.burst_interval) <= 0.04,
			"Second dart uses the deterministic burst interval."
		)
	_require(
		shooter.shooter_state == ShooterEnemy.ShooterState.RECOVER
		or shooter.shooter_state == ShooterEnemy.ShooterState.ARC_REPOSITION
		or shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION,
		"Shooter enters recovery or reposition after the burst."
	)
	_require(shooter.minimum_dart_interval_left > 0.0, "Shooter starts the minimum dart interval after firing.")
	_require(fired_directions.size() <= 2, "One attack cannot produce three or more darts.")

	await _advance_physics(shooter.recover_duration + 0.08)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.ARC_REPOSITION, "Shooter enters ARC_REPOSITION after the short burst recovery.")
	var arc_start := shooter.global_position
	var arc_radial := (arc_start - player.global_position).normalized()
	await _advance_physics(0.30)
	var arc_movement := shooter.global_position - arc_start
	var radial_motion := absf(arc_movement.dot(arc_radial))
	var total_motion := arc_movement.length()
	_require(total_motion > 0.5, "Shooter starts relocating after the completed burst.")
	_require(radial_motion < total_motion * 0.75, "Arc reposition is mostly tangential, not direct chase or retreat.")
	_require(fired_directions.size() == 2, "Shooter does not fire additional darts during arc reposition.")
	_require(TEST_ARENA.has_point(shooter.global_position), "Arc reposition respects arena bounds.")
	await _advance_physics(shooter.arc_reposition_duration + 0.15)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION, "Shooter returns to REPOSITION after arc repositioning.")

	root.queue_free()
	await get_tree().process_frame


func _audit_two_shooter_readability_and_cap() -> void:
	var separation_root := Node2D.new()
	add_child(separation_root)
	var separation_player := _spawn_player(separation_root, Vector2(104.0, 108.0))
	var upper_shooter := _spawn_shooter(separation_root, separation_player, Vector2(212.0, 100.0), 46.62)
	var lower_shooter := _spawn_shooter(separation_root, separation_player, Vector2(216.0, 116.0), 46.62)
	upper_shooter.first_attack_delay_left = 99.0
	lower_shooter.first_attack_delay_left = 99.0
	var initial_distance := upper_shooter.global_position.distance_to(lower_shooter.global_position)
	await _advance_physics(0.25)
	var separated_distance := upper_shooter.global_position.distance_to(lower_shooter.global_position)
	_require(separated_distance > initial_distance + 3.0, "Two Shooters separate cleanly instead of overlapping.")
	_require(
		upper_shooter.last_sprite_target_global_position.distance_to(lower_shooter.last_sprite_target_global_position) > 10.0,
		"Two Shooter body visuals remain distinct while separating."
	)
	separation_root.queue_free()
	await get_tree().process_frame

	var telegraph_root := Node2D.new()
	add_child(telegraph_root)
	var telegraph_player := _spawn_player(telegraph_root, Vector2(104.0, 108.0))
	var telegraph_upper := _spawn_ready_shooter(telegraph_root, telegraph_player, Vector2(208.0, 86.0), 46.62)
	var telegraph_lower := _spawn_ready_shooter(telegraph_root, telegraph_player, Vector2(208.0, 130.0), 46.62)
	await _advance_physics(0.05)
	_require(
		telegraph_upper.shooter_state == ShooterEnemy.ShooterState.AIM
		and telegraph_lower.shooter_state == ShooterEnemy.ShooterState.AIM,
		"Two Shooters can enter AIM together without shared-state interference."
	)
	_require(
		telegraph_upper.aim_direction.distance_to(telegraph_lower.aim_direction) > 0.10,
		"Two simultaneous Shooter telegraphs can point independently."
	)
	telegraph_upper.shooter_state = ShooterEnemy.ShooterState.ARC_REPOSITION
	telegraph_upper.arc_reposition_left = telegraph_upper.arc_reposition_duration
	telegraph_upper.arc_reposition_side = 1
	telegraph_upper.arc_reposition_reversed_for_wall = false
	telegraph_lower.shooter_state = ShooterEnemy.ShooterState.ARC_REPOSITION
	telegraph_lower.arc_reposition_left = telegraph_lower.arc_reposition_duration
	telegraph_lower.arc_reposition_side = -1
	telegraph_lower.arc_reposition_reversed_for_wall = false
	await _advance_physics(0.25)
	_require(
		telegraph_upper.global_position.distance_to(telegraph_lower.global_position) > 12.0,
		"Two Shooters do not stack on top of each other during arc reposition."
	)
	telegraph_root.queue_free()
	await get_tree().process_frame

	var desync_root := Node2D.new()
	add_child(desync_root)
	var desync_player := _spawn_player(desync_root, Vector2(104.0, 108.0))
	var early_shooter := _spawn_shooter(desync_root, desync_player, Vector2(200.0, 90.0), 46.62)
	var late_shooter := _spawn_shooter(desync_root, desync_player, Vector2(200.0, 126.0), 46.62)
	early_shooter.first_attack_delay_left = 0.0
	early_shooter.attack_cooldown_left = 0.0
	early_shooter.minimum_dart_interval_left = 0.0
	late_shooter.first_attack_delay_left = 0.32
	late_shooter.attack_cooldown_left = 0.0
	late_shooter.minimum_dart_interval_left = 0.0
	var early_burst_tracker := {"first_frame": -1, "dart_count": 0}
	var late_burst_tracker := {"first_frame": -1, "dart_count": 0}
	early_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		early_burst_tracker["dart_count"] += 1
		if int(early_burst_tracker["first_frame"]) == -1:
			early_burst_tracker["first_frame"] = Engine.get_physics_frames()
	)
	late_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		late_burst_tracker["dart_count"] += 1
		if int(late_burst_tracker["first_frame"]) == -1:
			late_burst_tracker["first_frame"] = Engine.get_physics_frames()
	)
	var both_bursts_completed := await _advance_until(
		func() -> bool:
			return (
				int(early_burst_tracker["dart_count"]) >= 2
				and int(late_burst_tracker["dart_count"]) >= 2
			),
		2.2,
		"two-shooter desync completed first bursts",
		func() -> String:
			return "early={%s} late={%s}" % [
				_describe_shooter_context(early_shooter, desync_player, int(early_burst_tracker["dart_count"])),
				_describe_shooter_context(late_shooter, desync_player, int(late_burst_tracker["dart_count"])),
			]
	)
	var early_first_shot_frame := int(early_burst_tracker["first_frame"])
	var late_first_shot_frame := int(late_burst_tracker["first_frame"])
	_require(both_bursts_completed and early_first_shot_frame != -1 and late_first_shot_frame != -1, "Both Shooters can reach a completed first burst in the desync setup.")
	if both_bursts_completed and early_first_shot_frame != -1 and late_first_shot_frame != -1:
		_require(
			early_first_shot_frame != late_first_shot_frame,
			"Offset first-attack delays keep two Shooters from perfectly synchronized opening volleys."
		)
		_require(
			abs(early_first_shot_frame - late_first_shot_frame) >= 6,
			"Two Shooter first volleys remain visually separated by multiple physics frames."
		)
	desync_root.queue_free()
	await get_tree().process_frame

	var shove_pair_root := Node2D.new()
	add_child(shove_pair_root)
	var shove_pair_player := _spawn_player(shove_pair_root, Vector2(250.0, 152.0))
	var primary_shooter := _spawn_shooter(shove_pair_root, shove_pair_player, Vector2(234.0, 152.0))
	var support_shooter := _spawn_shooter(shove_pair_root, shove_pair_player, Vector2(188.0, 120.0))
	primary_shooter.first_attack_delay_left = 0.0
	primary_shooter.attack_cooldown_left = 0.0
	primary_shooter.minimum_dart_interval_left = 0.0
	primary_shooter.preferred_distance_min = 60.0
	primary_shooter.preferred_distance_max = 140.0
	primary_shooter.attack_range_max = 160.0
	support_shooter.first_attack_delay_left = 99.0
	support_shooter.shove_cooldown_left = 99.0
	await _advance_physics(0.05)
	await _advance_physics(primary_shooter.shove_windup_duration + primary_shooter.shove_active_duration + 0.04)
	_require(primary_shooter.shooter_state == ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION, "Only the Shooter that lands the shove enters the successful-shove follow-up state.")
	_require(support_shooter.shooter_state != ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION, "Other Shooters do not mirror the successful-shove follow-up state.")
	_require(
		primary_shooter.global_position.distance_to(support_shooter.global_position) > 14.0,
		"Two Shooters remain visually separated while one is in shove follow-up reposition."
	)
	shove_pair_root.queue_free()
	await get_tree().process_frame


func _audit_burst_pause_and_cancellation() -> void:
	var pause_root := Node2D.new()
	add_child(pause_root)
	var pause_player := _spawn_player(pause_root, Vector2(104.0, 108.0))
	var pause_shooter := _spawn_ready_shooter(pause_root, pause_player, Vector2(200.0, 108.0))
	var pause_fired: Array[Vector2] = []
	pause_shooter.dart_requested.connect(func(_spawn_position: Vector2, fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		pause_fired.append(fire_direction)
	)

	var pause_first_dart := await _advance_until(
		func() -> bool: return pause_fired.size() >= 1,
		1.2,
		"pause scenario first dart",
		func() -> String:
			return _describe_shooter_context(pause_shooter, pause_player, pause_fired.size())
	)
	_require(pause_first_dart and pause_fired.size() == 1, "Burst emits the first dart before the pause test.")
	get_tree().paused = true
	await get_tree().create_timer(0.30, true, false, true).timeout
	_require(pause_fired.size() == 1, "Pause between darts freezes the pending second shot.")
	get_tree().paused = false
	var pause_second_dart := await _advance_until(
		func() -> bool: return pause_fired.size() >= 2,
		0.6,
		"pause scenario second dart after unpause",
		func() -> String:
			return _describe_shooter_context(pause_shooter, pause_player, pause_fired.size())
	)
	_require(pause_second_dart and pause_fired.size() == 2, "Pending second dart resumes after unpause.")
	pause_root.queue_free()
	await get_tree().process_frame

	var cancel_root := Node2D.new()
	add_child(cancel_root)
	var cancel_player := _spawn_player(cancel_root, Vector2(104.0, 108.0))
	var cancel_shooter := _spawn_ready_shooter(cancel_root, cancel_player, Vector2(200.0, 108.0))
	var cancel_counter := {"count": 0}
	cancel_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		cancel_counter["count"] += 1
	)

	var cancel_first_dart := await _advance_until(
		func() -> bool: return int(cancel_counter["count"]) >= 1,
		1.2,
		"deactivation scenario first dart",
		func() -> String:
			return _describe_shooter_context(cancel_shooter, cancel_player, int(cancel_counter["count"]))
	)
	_require(cancel_first_dart and int(cancel_counter["count"]) == 1, "Burst emits the first dart before deactivation.")
	cancel_shooter.set_active(false)
	await _advance_physics(0.35)
	_require(int(cancel_counter["count"]) == 1, "Deactivation between darts cancels the second shot.")
	cancel_root.queue_free()
	await get_tree().process_frame

	var death_root := Node2D.new()
	add_child(death_root)
	var death_player := _spawn_player(death_root, Vector2(104.0, 108.0))
	var death_shooter := _spawn_ready_shooter(death_root, death_player, Vector2(200.0, 108.0))
	var death_counter := {"count": 0}
	death_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		death_counter["count"] += 1
	)

	var death_first_dart := await _advance_until(
		func() -> bool: return int(death_counter["count"]) >= 1,
		1.2,
		"death scenario first dart",
		func() -> String:
			return _describe_shooter_context(death_shooter, death_player, int(death_counter["count"]))
	)
	_require(death_first_dart and int(death_counter["count"]) == 1, "Burst emits the first dart before death.")
	death_shooter.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, death_shooter.global_position, Vector2.RIGHT)
	await _advance_physics(0.35)
	_require(int(death_counter["count"]) == 1, "Death between darts cancels the second shot.")
	death_root.queue_free()
	await get_tree().process_frame


func _audit_dart_damage_and_invulnerability() -> void:
	var root := Node2D.new()
	add_child(root)

	var vulnerable_player := _spawn_player(root, Vector2(120.0, 108.0))
	var vulnerable_dart := _spawn_dart(root, vulnerable_player, Vector2(116.0, 108.0), Vector2.RIGHT, 1001, 0)
	vulnerable_dart.call("_on_body_entered", vulnerable_player)
	vulnerable_dart.call("_on_body_entered", vulnerable_player)
	_require(vulnerable_player.health == vulnerable_player.max_health - 1, "Vulnerable dart contact deals exactly one health.")
	_require(vulnerable_dart.has_resolved_hit, "Dart resolves after hitting vulnerable player.")

	var burst_player := _spawn_player(root, Vector2(136.0, 108.0))
	var burst_dart_one := _spawn_dart(root, burst_player, Vector2(132.0, 108.0), Vector2.RIGHT, 2001, 0)
	var burst_dart_two := _spawn_dart(root, burst_player, Vector2(132.0, 108.0), Vector2.RIGHT, 2001, 1)
	burst_dart_one.call("_on_body_entered", burst_player)
	burst_dart_two.call("_on_body_entered", burst_player)
	_require(burst_player.health == burst_player.max_health - 2, "Two distinct darts from one burst can deal exactly two total damage.")
	var burst_dart_three := _spawn_dart(root, burst_player, Vector2(132.0, 108.0), Vector2.RIGHT, 2001, 1)
	burst_dart_three.call("_on_body_entered", burst_player)
	_require(burst_player.health == burst_player.max_health - 2, "A third callback or duplicate dart index cannot add extra burst damage.")

	var second_only_player := _spawn_player(root, Vector2(142.0, 108.0))
	var second_only_dart := _spawn_dart(root, second_only_player, Vector2(138.0, 108.0), Vector2.RIGHT, 2002, 1)
	second_only_dart.call("_on_body_entered", second_only_player)
	_require(second_only_player.health == second_only_player.max_health - 1, "A missed first dart does not prevent dart two from dealing one damage.")

	var first_only_player := _spawn_player(root, Vector2(148.0, 108.0))
	var first_only_dart := _spawn_dart(root, first_only_player, Vector2(144.0, 108.0), Vector2.RIGHT, 2003, 0)
	first_only_dart.call("_on_body_entered", first_only_player)
	_require(first_only_player.health == first_only_player.max_health - 1, "A missed second dart leaves the first hit at one damage.")

	var unrelated_player := _spawn_player(root, Vector2(154.0, 108.0))
	unrelated_player.take_damage(Vector2.ZERO)
	unrelated_player.take_damage(Vector2.ZERO)
	_require(unrelated_player.health == unrelated_player.max_health - 1, "Unrelated enemy damage still respects ordinary hurt invulnerability.")

	var hurt_player := _spawn_player(root, Vector2(150.0, 108.0))
	hurt_player.invulnerability_left = 0.5
	var hurt_dart := _spawn_dart(root, hurt_player, Vector2(146.0, 108.0), Vector2.RIGHT, 3001, 0)
	hurt_dart.call("_on_body_entered", hurt_player)
	_require(hurt_player.health == hurt_player.max_health, "Hurt invulnerability consumes the dart harmlessly.")
	_require(hurt_dart.has_resolved_hit, "Dart is destroyed after hurt-invulnerable contact.")

	var dodge_player := _spawn_player(root, Vector2(180.0, 108.0))
	dodge_player.try_start_dodge(Vector2.RIGHT)
	var dodge_dart := _spawn_dart(root, dodge_player, Vector2(176.0, 108.0), Vector2.RIGHT, 4001, 0)
	dodge_dart.call("_on_body_entered", dodge_player)
	_require(dodge_player.health == dodge_player.max_health, "Active dodge consumes the dart harmlessly.")
	var dodge_dart_two := _spawn_dart(root, dodge_player, Vector2(176.0, 108.0), Vector2.RIGHT, 4001, 1)
	dodge_dart_two.call("_on_body_entered", dodge_player)
	_require(dodge_player.health == dodge_player.max_health, "Active dodge can negate both darts in a burst.")

	var grace_player := _spawn_player(root, Vector2(210.0, 108.0))
	grace_player.dodge_exit_invulnerability_left = 0.10
	var grace_dart := _spawn_dart(root, grace_player, Vector2(206.0, 108.0), Vector2.RIGHT, 5001, 0)
	grace_dart.call("_on_body_entered", grace_player)
	_require(grace_player.health == grace_player.max_health, "Dodge exit grace consumes the dart harmlessly.")
	var grace_dart_two := _spawn_dart(root, grace_player, Vector2(206.0, 108.0), Vector2.RIGHT, 5001, 1)
	grace_dart_two.call("_on_body_entered", grace_player)
	_require(grace_player.health == grace_player.max_health, "Dodge exit grace can negate both darts in a burst.")

	var shoved_player := _spawn_player(root, Vector2(236.0, 108.0))
	_require(
		shoved_player.try_start_forced_movement(
			Vector2.RIGHT,
			52.0,
			0.24,
			Player.FORCED_MOVEMENT_PROTECTION_SHOVE
		),
		"Protected forced movement starts before the shove-protection dart test."
	)
	var shoved_dart := _spawn_dart(root, shoved_player, Vector2(232.0, 108.0), Vector2.RIGHT, 6001, 0)
	shoved_dart.call("_on_body_entered", shoved_player)
	var shoved_dart_two := _spawn_dart(root, shoved_player, Vector2(232.0, 108.0), Vector2.RIGHT, 6001, 1)
	shoved_dart_two.call("_on_body_entered", shoved_player)
	_require(shoved_player.health == shoved_player.max_health, "Shove-specific protection consumes both burst darts harmlessly during authored knockback.")
	_require(shoved_dart.has_resolved_hit and shoved_dart_two.has_resolved_hit, "Protected shove movement still consumes contacting darts cleanly.")

	root.queue_free()
	await get_tree().process_frame


func _audit_dart_motion_and_cleanup() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(96.0, 108.0))

	var moving_dart := _spawn_dart(root, player, Vector2(160.0, 108.0), Vector2.RIGHT)
	var start_x := moving_dart.global_position.x
	await _advance_physics(0.12)
	_require(moving_dart.global_position.x > start_x + 10.0, "Dart travels straight at readable speed.")

	var lifetime_dart := _spawn_dart(root, player, Vector2(180.0, 108.0), Vector2.RIGHT)
	var lifetime_dart_id := lifetime_dart.get_instance_id()
	lifetime_dart.max_lifetime = 0.05
	lifetime_dart.lifetime_left = 0.05
	await _advance_physics(0.10)
	var lifetime_cleared := not _has_child_with_instance_id(root, lifetime_dart_id)
	if not lifetime_cleared and is_instance_valid(lifetime_dart):
		lifetime_cleared = lifetime_dart.has_resolved_hit
	_require(lifetime_cleared, "Dart clears after lifetime expiry.")

	var bounds_dart := _spawn_dart(root, player, Vector2(380.0, 108.0), Vector2.RIGHT)
	var bounds_dart_id := bounds_dart.get_instance_id()
	await _advance_physics(0.10)
	var bounds_dart_cleared := not _has_child_with_instance_id(root, bounds_dart_id)
	if not bounds_dart_cleared and is_instance_valid(bounds_dart):
		bounds_dart_cleared = bounds_dart.has_resolved_hit
	_require(bounds_dart_cleared, "Dart clears at arena bounds.")

	root.queue_free()
	await get_tree().process_frame


func _audit_shooter_death_and_score() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(96.0, 108.0))
	var shooter := _spawn_shooter(root, player, Vector2(160.0, 108.0))

	var kill_tracker := {"count": 0, "score": 0}
	shooter.killed.connect(func(_enemy_position: Vector2, score_value: int) -> void:
		kill_tracker["count"] += 1
		kill_tracker["score"] += score_value
	)

	var response := shooter.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, shooter.global_position, Vector2.RIGHT)
	var killed_received := await _advance_until(
		func() -> bool: return int(kill_tracker["count"]) >= 1,
		0.10,
		"shooter death killed signal",
		func() -> String:
			return _describe_shooter_context(shooter, player, int(kill_tracker["count"]))
	)
	_require(response == Enemy.HitResponse.DAMAGED, "Shooter spear hit uses normal DAMAGED response.")
	_require(killed_received and int(kill_tracker["count"]) == 1, "Shooter death emits one killed signal.")
	_require(killed_received and int(kill_tracker["score"]) == 2, "Shooter death awards exactly 2 score points.")

	root.queue_free()
	await get_tree().process_frame


func _audit_main_spawn_intro_and_projectile_cleanup() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	var director := main.get_node("EncounterDirector") as EncounterDirector
	var projectile_container := main.get_node("ProjectileContainer") as Node2D

	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("survival_time", 45.0)
	main.call("debug_set_ambient_roll_sequence", [0.99])
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.SHOOTER,
		"Overdue Shooter intro is selected before random weighting."
	)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.SHOOTER, Arena.SpawnEdge.TOP, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Organic Shooter spawn succeeds in the audit setup."
	)
	_require(bool(main.get("shooter_intro_seen")), "Organic Shooter spawn marks Shooter intro seen.")
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.SHOOTER, Arena.SpawnEdge.BOTTOM, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Second Shooter spawn succeeds while the new cap still has room."
	)
	_require(director.get_shooter_hostile_count() == 2, "Director counts two active Shooters under the new cap.")
	_require(not director.can_spawn_enemy(EncounterDirector.EnemyKind.SHOOTER, 45.0), "Shooter cap blocks a third active Shooter.")

	var main_player := main.get_node("Player") as Player
	var spawned_shooter := main.get_node("EnemyContainer").get_child(0) as ShooterEnemy
	var support_shooter := main.get_node("EnemyContainer").get_child(1) as ShooterEnemy
	main_player.global_position = Vector2(104.0, 108.0)
	spawned_shooter.global_position = Vector2(200.0, 108.0)
	spawned_shooter.first_attack_delay_left = 0.0
	spawned_shooter.attack_cooldown_left = 0.0
	spawned_shooter.minimum_dart_interval_left = 0.0
	support_shooter.first_attack_delay_left = 99.0
	var restart_counter := {"count": 0}
	spawned_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		restart_counter["count"] += 1
	)
	var restart_first_dart := await _advance_until(
		func() -> bool: return int(restart_counter["count"]) >= 1,
		1.2,
		"main restart scenario first dart",
		func() -> String:
			return _describe_shooter_context(spawned_shooter, main_player, int(restart_counter["count"]))
	)
	_require(restart_first_dart and int(restart_counter["count"]) == 1, "Main-spawned Shooter emits first dart before restart cancellation.")
	main.call("_restart_run")
	await _advance_physics(0.35)
	_require(int(restart_counter["count"]) == 1, "Restart between darts cancels the pending second shot.")

	main.call("_spawn_dart_projectile", Vector2(200.0, 108.0), Vector2.RIGHT, 9001, 0)
	await get_tree().process_frame
	_require(projectile_container.get_child_count() == 1, "Main spawns darts into ProjectileContainer.")

	var dart := projectile_container.get_child(0) as DartProjectile
	var paused_position := dart.global_position
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(dart.global_position == paused_position, "Pause freezes active dart motion.")
	get_tree().paused = false

	main.call("_restart_run")
	await get_tree().process_frame
	_require(projectile_container.get_child_count() == 0, "Restart clears active darts.")

	main.call("_reset_runtime_state")
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("survival_time", 45.0)
	main.call("_debug_spawn_shooter_enemy")
	_require(not bool(main.get("shooter_intro_seen")), "Debug Shooter spawn does not mark Shooter intro seen.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _audit_no_shielded_interception_yet() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(96.0, 108.0))
	var shielded := ShieldedScene.instantiate() as ShieldedEnemy
	shielded.setup(player, TEST_ARENA, 42.0)
	shielded.global_position = Vector2(160.0, 108.0)
	root.add_child(shielded)

	var dart := _spawn_dart(root, player, Vector2(156.0, 108.0), Vector2.RIGHT, 9101, 0)
	dart.call("_on_body_entered", shielded)
	_require(not dart.has_resolved_hit, "Darts do not collide with or resolve against Shielded enemies in Phase 4.2.")
	_require(shielded.is_shield_intact(), "Darts do not break Shielded shields in Phase 4.2.")

	root.queue_free()
	await get_tree().process_frame


func _ensure_input_actions() -> void:
	for action_name in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _has_child_with_instance_id(parent: Node, instance_id: int) -> bool:
	for child in parent.get_children():
		if child.get_instance_id() == instance_id:
			return true
	return false


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(TEST_ARENA)
	player.reset_for_new_run(position, TEST_ARENA)
	return player


func _spawn_shooter(parent: Node, player: Player, position: Vector2, starting_speed: float = 42.0) -> ShooterEnemy:
	var shooter := ShooterScene.instantiate() as ShooterEnemy
	shooter.setup(player, TEST_ARENA, starting_speed)
	shooter.global_position = position
	parent.add_child(shooter)
	return shooter


func _spawn_ready_shooter(parent: Node, player: Player, position: Vector2, starting_speed: float = 42.0) -> ShooterEnemy:
	var shooter := _spawn_shooter(parent, player, position, starting_speed)
	shooter.first_attack_delay_left = 0.0
	shooter.attack_cooldown_left = 0.0
	shooter.minimum_dart_interval_left = 0.0
	return shooter


func _spawn_dart(
	parent: Node,
	player: Player,
	position: Vector2,
	direction: Vector2,
	burst_id: int = 1,
	dart_index: int = 0
) -> DartProjectile:
	var dart := DartScene.instantiate() as DartProjectile
	parent.add_child(dart)
	dart.global_position = position
	dart.setup(player, TEST_ARENA, direction, burst_id, dart_index)
	return dart


func _advance_physics(duration: float) -> void:
	var frames := int(ceil(duration * 60.0))
	for _index in range(maxi(frames, 1)):
		await get_tree().physics_frame


func _advance_until(
	condition: Callable,
	timeout: float,
	wait_label: String = "",
	context_provider: Callable = Callable()
) -> bool:
	var frames := int(ceil(timeout * 60.0))
	for _index in range(maxi(frames, 1)):
		if bool(condition.call()):
			return true
		await get_tree().physics_frame
	if bool(condition.call()):
		return true
	var diagnostic := ""
	if not context_provider.is_null():
		diagnostic = str(context_provider.call())
	if wait_label.is_empty():
		push_warning("SHOOTER RUNTIME AUDIT WAIT TIMEOUT after %.2fs. %s" % [timeout, diagnostic])
	else:
		push_warning("SHOOTER RUNTIME AUDIT WAIT TIMEOUT: %s after %.2fs. %s" % [wait_label, timeout, diagnostic])
	return false


func _free_test_root(root: Node) -> void:
	root.queue_free()
	await get_tree().process_frame


func _describe_shooter_context(shooter: ShooterEnemy, player: Player, dart_count: int = -1) -> String:
	var shooter_state_name := "freed"
	var player_state_name := "freed"
	var active_text := "freed"
	var attack_timer_text := "freed"
	var cooldown_text := "freed"
	var first_attack_delay_text := "freed"
	var dart_text := "n/a" if dart_count < 0 else str(dart_count)

	if is_instance_valid(shooter):
		shooter_state_name = _get_shooter_state_name(shooter.shooter_state)
		active_text = str(shooter.active and not shooter.is_dying)
		attack_timer_text = str(snappedf(shooter.state_time_left, 0.001))
		cooldown_text = "%s/%s/%s/%s" % [
			str(snappedf(shooter.attack_cooldown_left, 0.001)),
			str(snappedf(shooter.minimum_dart_interval_left, 0.001)),
			str(snappedf(shooter.aim_retry_left, 0.001)),
			str(snappedf(shooter.shove_cooldown_left, 0.001)),
		]
		first_attack_delay_text = str(snappedf(shooter.first_attack_delay_left, 0.001))

	if is_instance_valid(player):
		player_state_name = _get_player_state_name(player.action_state)

	return "shooter_state=%s player_state=%s state_time=%s cooldowns=%s first_delay=%s active=%s darts=%s player_forced=%s player_shove_protection=%s" % [
		shooter_state_name,
		player_state_name,
		attack_timer_text,
		cooldown_text,
		first_attack_delay_text,
		active_text,
		dart_text,
		str(is_instance_valid(player) and player.is_in_forced_movement()),
		str(is_instance_valid(player) and player.has_shove_damage_protection()),
	]


func _get_shooter_state_name(state: int) -> String:
	match state:
		ShooterEnemy.ShooterState.REPOSITION:
			return "REPOSITION"
		ShooterEnemy.ShooterState.AIM:
			return "AIM"
		ShooterEnemy.ShooterState.LOCKED:
			return "LOCKED"
		ShooterEnemy.ShooterState.FIRE:
			return "FIRE"
		ShooterEnemy.ShooterState.RECOVER:
			return "RECOVER"
		ShooterEnemy.ShooterState.ARC_REPOSITION:
			return "ARC_REPOSITION"
		ShooterEnemy.ShooterState.POST_SHOVE_REPOSITION:
			return "POST_SHOVE_REPOSITION"
		ShooterEnemy.ShooterState.AIM_CANCEL_REPOSITION:
			return "AIM_CANCEL_REPOSITION"
		ShooterEnemy.ShooterState.SHOVE_WINDUP:
			return "SHOVE_WINDUP"
		ShooterEnemy.ShooterState.SHOVE_ACTIVE:
			return "SHOVE_ACTIVE"
		ShooterEnemy.ShooterState.SHOVE_RECOVER:
			return "SHOVE_RECOVER"
	return "UNKNOWN_%s" % state


func _get_player_state_name(state: int) -> String:
	match state:
		Player.ActionState.NORMAL:
			return "NORMAL"
		Player.ActionState.DODGING:
			return "DODGING"
		Player.ActionState.FORCED_MOVEMENT:
			return "FORCED_MOVEMENT"
		Player.ActionState.DISABLED:
			return "DISABLED"
	return "UNKNOWN_%s" % state


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
