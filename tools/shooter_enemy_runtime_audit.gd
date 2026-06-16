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
	await _audit_movement_ranges()
	await _audit_cancel_reposition_and_shove()
	await _audit_attack_state_machine()
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
	var root := Node2D.new()
	add_child(root)

	var player := _spawn_player(root, Vector2(120.0, 108.0))
	var shooter := _spawn_shooter(root, player, Vector2(220.0, 108.0), 46.62)
	shooter.first_attack_delay_left = 0.0
	shooter.attack_cooldown_left = 0.0
	shooter.minimum_dart_interval_left = 0.0
	var cancelled_darts := 0
	shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		cancelled_darts += 1
	)
	await _advance_physics(0.05)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM, "Shooter begins aiming once inside firing range.")
	player.global_position = Vector2(40.0, 108.0)
	var cancel_start := shooter.global_position
	await _advance_physics(0.05)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM_CANCEL_REPOSITION, "Too-far pre-lock movement cancels AIM into committed reposition.")
	await _advance_physics(0.25)
	var cancel_displacement := shooter.global_position - cancel_start
	_require(cancelled_darts == 0, "Cancelled AIM fires zero darts.")
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM_CANCEL_REPOSITION, "Shooter cannot re-enter AIM during cancellation reposition.")
	_require(absf(cancel_displacement.y) > 4.0 and absf(cancel_displacement.y) > absf(cancel_displacement.x), "Too-far cancellation repositions laterally instead of immediately sprinting straight back into AIM.")
	await _advance_physics(shooter.aim_cancel_reposition_duration + 0.10)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION, "Cancelled AIM ends in ordinary reposition after the committed travel finishes.")

	var retreat_player := _spawn_player(root, Vector2(130.0, 108.0))
	var retreat_shooter := _spawn_shooter(root, retreat_player, Vector2(220.0, 108.0))
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

	var overlap_player := _spawn_player(root, Vector2(176.0, 108.0))
	var overlap_shooter := _spawn_shooter(root, overlap_player, Vector2(178.0, 108.0))
	overlap_shooter.first_attack_delay_left = 99.0
	overlap_shooter.shove_cooldown_left = 99.0
	var overlap_health := overlap_player.health
	await _advance_physics(0.20)
	_require(overlap_player.health == overlap_health, "Shooter body overlap no longer deals ordinary contact damage.")

	var shove_player := _spawn_player(root, Vector2(250.0, 108.0))
	var shove_shooter := _spawn_shooter(root, shove_player, Vector2(234.0, 108.0))
	shove_shooter.first_attack_delay_left = 99.0
	var shove_count := 0
	shove_shooter.shove_used.connect(func() -> void:
		shove_count += 1
	)
	var shove_health := shove_player.health
	await _advance_physics(0.05)
	_require(shove_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_WINDUP, "Close-range Shooter starts shove windup instead of using body damage.")
	await _advance_physics(shove_shooter.shove_windup_duration + 0.03)
	_require(shove_count == 1, "Shooter shove fires once per close-range defense.")
	_require(shove_player.health == shove_health, "Shooter shove deals zero health damage.")
	_require(shove_player.is_in_forced_movement(), "Successful shove starts authored player forced movement.")
	var shoved_start := shove_player.global_position
	await _advance_physics(0.10)
	_require(shove_player.global_position.distance_to(shoved_start) > 4.0, "Successful shove moves the player a meaningful distance.")
	await _advance_physics(shove_shooter.shove_active_duration + shove_shooter.shove_recover_duration + 0.05)
	_require(
		shove_shooter.shooter_state == ShooterEnemy.ShooterState.ARC_REPOSITION
		or shove_shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION,
		"Shooter relocates after a shove instead of immediately restarting its burst."
	)
	_require(shove_shooter.shove_cooldown_left > 0.0, "Shooter shove cooldown is respected after use.")

	var miss_player := _spawn_player(root, Vector2(300.0, 108.0))
	var miss_shooter := _spawn_shooter(root, miss_player, Vector2(284.0, 108.0))
	miss_shooter.first_attack_delay_left = 99.0
	await _advance_physics(0.05)
	miss_player.global_position = Vector2(340.0, 108.0)
	await _advance_physics(miss_shooter.shove_windup_duration + 0.03)
	_require(not miss_player.is_in_forced_movement(), "Missed shove causes no knockback.")

	var dodge_player := _spawn_player(root, Vector2(110.0, 150.0))
	dodge_player.try_start_dodge(Vector2.RIGHT)
	var dodge_shooter := _spawn_shooter(root, dodge_player, Vector2(94.0, 150.0))
	dodge_shooter.shove_direction = Vector2.RIGHT
	dodge_shooter.call("_enter_shove_active_state")
	_require(not dodge_player.is_in_forced_movement(), "Active dodge suppresses shove knockback.")
	_require(dodge_player.health == dodge_player.max_health, "Shove stays non-damaging during active dodge.")

	var grace_player := _spawn_player(root, Vector2(110.0, 176.0))
	grace_player.dodge_exit_invulnerability_left = 0.10
	var grace_shooter := _spawn_shooter(root, grace_player, Vector2(94.0, 176.0))
	grace_shooter.shove_direction = Vector2.RIGHT
	grace_shooter.call("_enter_shove_active_state")
	_require(not grace_player.is_in_forced_movement(), "Dodge exit grace suppresses shove knockback.")

	root.queue_free()
	await get_tree().process_frame


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


func _audit_burst_pause_and_cancellation() -> void:
	var pause_root := Node2D.new()
	add_child(pause_root)
	var pause_player := _spawn_player(pause_root, Vector2(104.0, 108.0))
	var pause_shooter := _spawn_ready_shooter(pause_root, pause_player, Vector2(200.0, 108.0))
	var pause_fired: Array[Vector2] = []
	pause_shooter.dart_requested.connect(func(_spawn_position: Vector2, fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		pause_fired.append(fire_direction)
	)

	await _advance_until(func() -> bool: return pause_fired.size() >= 1, 1.2)
	_require(pause_fired.size() == 1, "Burst emits the first dart before the pause test.")
	get_tree().paused = true
	await get_tree().create_timer(0.30, true, false, true).timeout
	_require(pause_fired.size() == 1, "Pause between darts freezes the pending second shot.")
	get_tree().paused = false
	await _advance_until(func() -> bool: return pause_fired.size() >= 2, 0.6)
	_require(pause_fired.size() == 2, "Pending second dart resumes after unpause.")
	pause_root.queue_free()
	await get_tree().process_frame

	var cancel_root := Node2D.new()
	add_child(cancel_root)
	var cancel_player := _spawn_player(cancel_root, Vector2(104.0, 108.0))
	var cancel_shooter := _spawn_ready_shooter(cancel_root, cancel_player, Vector2(200.0, 108.0))
	var cancel_count := 0
	cancel_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		cancel_count += 1
	)

	await _advance_until(func() -> bool: return cancel_count >= 1, 1.2)
	_require(cancel_count == 1, "Burst emits the first dart before deactivation.")
	cancel_shooter.set_active(false)
	await _advance_physics(0.35)
	_require(cancel_count == 1, "Deactivation between darts cancels the second shot.")
	cancel_root.queue_free()
	await get_tree().process_frame

	var death_root := Node2D.new()
	add_child(death_root)
	var death_player := _spawn_player(death_root, Vector2(104.0, 108.0))
	var death_shooter := _spawn_ready_shooter(death_root, death_player, Vector2(200.0, 108.0))
	var death_count := 0
	death_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		death_count += 1
	)

	await _advance_until(func() -> bool: return death_count >= 1, 1.2)
	_require(death_count == 1, "Burst emits the first dart before death.")
	death_shooter.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, death_shooter.global_position, Vector2.RIGHT)
	await _advance_physics(0.35)
	_require(death_count == 1, "Death between darts cancels the second shot.")
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
	lifetime_dart.max_lifetime = 0.05
	lifetime_dart.lifetime_left = 0.05
	await _advance_physics(0.10)
	_require(lifetime_dart.has_resolved_hit, "Dart clears after lifetime expiry.")

	var bounds_dart := _spawn_dart(root, player, Vector2(380.0, 108.0), Vector2.RIGHT)
	await _advance_physics(0.10)
	_require(bounds_dart.has_resolved_hit, "Dart clears at arena bounds.")

	root.queue_free()
	await get_tree().process_frame


func _audit_shooter_death_and_score() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(96.0, 108.0))
	var shooter := _spawn_shooter(root, player, Vector2(160.0, 108.0))

	var killed_count := 0
	var killed_score := 0
	shooter.killed.connect(func(_enemy_position: Vector2, score_value: int) -> void:
		killed_count += 1
		killed_score += score_value
	)

	var response := shooter.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, shooter.global_position, Vector2.RIGHT)
	_require(response == Enemy.HitResponse.DAMAGED, "Shooter spear hit uses normal DAMAGED response.")
	_require(killed_count == 1, "Shooter death emits one killed signal.")
	_require(killed_score == 2, "Shooter death awards exactly 2 score points.")

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
	_require(director.get_shooter_hostile_count() == 1, "Director counts one active Shooter.")
	_require(not director.can_spawn_enemy(EncounterDirector.EnemyKind.SHOOTER, 45.0), "Shooter cap blocks a second active Shooter.")

	var main_player := main.get_node("Player") as Player
	var spawned_shooter := main.get_node("EnemyContainer").get_child(0) as ShooterEnemy
	main_player.global_position = Vector2(104.0, 108.0)
	spawned_shooter.global_position = Vector2(200.0, 108.0)
	spawned_shooter.first_attack_delay_left = 0.0
	spawned_shooter.attack_cooldown_left = 0.0
	spawned_shooter.minimum_dart_interval_left = 0.0
	var restart_cancel_shots := 0
	spawned_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		restart_cancel_shots += 1
	)
	await _advance_until(func() -> bool: return restart_cancel_shots >= 1, 1.2)
	_require(restart_cancel_shots == 1, "Main-spawned Shooter emits first dart before restart cancellation.")
	main.call("_restart_run")
	await _advance_physics(0.35)
	_require(restart_cancel_shots == 1, "Restart between darts cancels the pending second shot.")

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


func _advance_until(condition: Callable, timeout: float) -> void:
	var frames := int(ceil(timeout * 60.0))
	for _index in range(maxi(frames, 1)):
		if bool(condition.call()):
			return
		await get_tree().physics_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
