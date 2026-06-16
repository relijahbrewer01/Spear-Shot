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
	shooter.dart_requested.connect(func(_spawn_position: Vector2, fire_direction: Vector2) -> void:
		fired_directions.append(fire_direction)
		fired_frames.append(Engine.get_physics_frames())
	)

	await _advance_physics(0.05)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.AIM, "Shooter starts with AIM instead of firing immediately.")

	player.global_position = Vector2(104.0, 128.0)
	await _advance_physics(0.58)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.LOCKED, "Shooter enters LOCKED after the aim telegraph.")
	var locked_direction: Vector2 = shooter.locked_direction
	player.global_position = Vector2(104.0, 60.0)
	await _advance_physics(0.55)

	_require(fired_directions.size() == 2, "Shooter fires exactly two darts for one completed attack.")
	if fired_directions.size() >= 2:
		_require(fired_directions[0].distance_to(locked_direction) < 0.001, "Dart uses the locked aim direction.")
		_require(fired_directions[1].distance_to(locked_direction) < 0.001, "Second dart uses the same locked aim direction.")
		var burst_interval := float(fired_frames[1] - fired_frames[0]) / 60.0
		_require(
			absf(burst_interval - shooter.burst_interval) <= 0.04,
			"Second dart uses the deterministic burst interval."
		)
	_require(
		shooter.shooter_state == ShooterEnemy.ShooterState.RECOVER
		or shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION,
		"Shooter enters recovery or reposition after the burst."
	)
	_require(shooter.minimum_dart_interval_left > 0.0, "Shooter starts the minimum dart interval after firing.")
	_require(fired_directions.size() <= 2, "One attack cannot produce three or more darts.")

	var position_after_burst := shooter.global_position
	await _advance_physics(shooter.recover_duration + 0.30)
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION, "Shooter returns to REPOSITION after the short burst recovery.")
	_require(shooter.global_position.distance_to(position_after_burst) > 0.5, "Shooter starts relocating after the completed burst.")

	root.queue_free()
	await get_tree().process_frame


func _audit_burst_pause_and_cancellation() -> void:
	var pause_root := Node2D.new()
	add_child(pause_root)
	var pause_player := _spawn_player(pause_root, Vector2(104.0, 108.0))
	var pause_shooter := _spawn_ready_shooter(pause_root, pause_player, Vector2(200.0, 108.0))
	var pause_fired: Array[Vector2] = []
	pause_shooter.dart_requested.connect(func(_spawn_position: Vector2, fire_direction: Vector2) -> void:
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
	cancel_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2) -> void:
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
	death_shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2) -> void:
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
	var vulnerable_dart := _spawn_dart(root, vulnerable_player, Vector2(116.0, 108.0), Vector2.RIGHT)
	vulnerable_dart.call("_on_body_entered", vulnerable_player)
	vulnerable_dart.call("_on_body_entered", vulnerable_player)
	_require(vulnerable_player.health == vulnerable_player.max_health - 1, "Vulnerable dart contact deals exactly one health.")
	_require(vulnerable_dart.has_resolved_hit, "Dart resolves after hitting vulnerable player.")

	var hurt_player := _spawn_player(root, Vector2(150.0, 108.0))
	hurt_player.invulnerability_left = 0.5
	var hurt_dart := _spawn_dart(root, hurt_player, Vector2(146.0, 108.0), Vector2.RIGHT)
	hurt_dart.call("_on_body_entered", hurt_player)
	_require(hurt_player.health == hurt_player.max_health, "Hurt invulnerability consumes the dart harmlessly.")
	_require(hurt_dart.has_resolved_hit, "Dart is destroyed after hurt-invulnerable contact.")

	var dodge_player := _spawn_player(root, Vector2(180.0, 108.0))
	dodge_player.try_start_dodge(Vector2.RIGHT)
	var dodge_dart := _spawn_dart(root, dodge_player, Vector2(176.0, 108.0), Vector2.RIGHT)
	dodge_dart.call("_on_body_entered", dodge_player)
	_require(dodge_player.health == dodge_player.max_health, "Active dodge consumes the dart harmlessly.")

	var grace_player := _spawn_player(root, Vector2(210.0, 108.0))
	grace_player.dodge_exit_invulnerability_left = 0.10
	var grace_dart := _spawn_dart(root, grace_player, Vector2(206.0, 108.0), Vector2.RIGHT)
	grace_dart.call("_on_body_entered", grace_player)
	_require(grace_player.health == grace_player.max_health, "Dodge exit grace consumes the dart harmlessly.")

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

	main.call("_spawn_dart_projectile", Vector2(200.0, 108.0), Vector2.RIGHT)
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

	var dart := _spawn_dart(root, player, Vector2(156.0, 108.0), Vector2.RIGHT)
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


func _spawn_shooter(parent: Node, player: Player, position: Vector2) -> ShooterEnemy:
	var shooter := ShooterScene.instantiate() as ShooterEnemy
	shooter.setup(player, TEST_ARENA, 42.0)
	shooter.global_position = position
	parent.add_child(shooter)
	return shooter


func _spawn_ready_shooter(parent: Node, player: Player, position: Vector2) -> ShooterEnemy:
	var shooter := _spawn_shooter(parent, player, position)
	shooter.first_attack_delay_left = 0.0
	shooter.attack_cooldown_left = 0.0
	shooter.minimum_dart_interval_left = 0.0
	return shooter


func _spawn_dart(parent: Node, player: Player, position: Vector2, direction: Vector2) -> DartProjectile:
	var dart := DartScene.instantiate() as DartProjectile
	parent.add_child(dart)
	dart.global_position = position
	dart.setup(player, TEST_ARENA, direction)
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
