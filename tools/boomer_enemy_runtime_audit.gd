extends Node

const PlayerScene := preload("res://Player.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ChargerScene := preload("res://Charger.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const ShooterScene := preload("res://ShooterEnemy.tscn")
const BoomerScene := preload("res://BoomerEnemy.tscn")
const SpearScene := preload("res://Spear.tscn")
const MainScene := preload("res://Main.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))
const SPAWN_SOURCE_AMBIENT := 0
const SPAWN_SOURCE_DEBUG := 2

var failures: Array[String] = []


func _ready() -> void:
	_ensure_input_actions()
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_discrete_hop_and_immediate_fuse()
	await _audit_safe_spear_kill_and_armed_detonation()
	await _audit_explosion_responses()
	await _audit_player_and_spear_blast_exceptions()
	await _audit_main_integration_and_lifecycle()

	for failure in failures:
		push_error("BOOMER RUNTIME AUDIT: %s" % failure)
	print("Boomer enemy runtime audit passed." if failures.is_empty() else "Boomer enemy runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_discrete_hop_and_immediate_fuse() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(260.0, 108.0))
	var boomer := _spawn_boomer(root, player, Vector2(120.0, 108.0))
	var prep_position := boomer.global_position

	await _advance_physics(0.10)
	_require(boomer.boomer_state == BoomerEnemy.BoomerState.HOP_PREP, "Boomer begins in stationary hop prep.")
	_require(boomer.global_position == prep_position, "Hop prep stays positionally stationary.")

	var reached_hop := await _advance_until(
		func() -> bool: return boomer.boomer_state == BoomerEnemy.BoomerState.HOPPING,
		0.20,
		"boomer hop start"
	)
	_require(reached_hop, "Boomer enters the committed hopping state after prep.")
	var hop_start := boomer.global_position
	var launch_direction := boomer.hop_direction
	await _advance_physics(boomer.hop_duration * 0.5)
	_require(boomer.global_position.distance_to(hop_start) > 8.0, "Only the hopping state translates the Boomer.")
	player.global_position = Vector2(260.0, 40.0)
	await _advance_until(
		func() -> bool:
			return boomer.boomer_state != BoomerEnemy.BoomerState.HOPPING,
		boomer.hop_duration + 0.12,
		"boomer hop finish"
	)
	var landed_direction := (boomer.global_position - hop_start).normalized()
	_require(landed_direction.dot(launch_direction) > 0.95, "Hop direction stays locked after takeoff even if the player moves.")
	_require(boomer.boomer_state == BoomerEnemy.BoomerState.LAND_RECOVERY, "Landing outside fuse range enters stationary landing recovery.")
	var recovery_position := boomer.global_position
	await _advance_physics(0.10)
	_require(boomer.global_position == recovery_position, "Landing recovery stays positionally stationary.")
	await _advance_until(
		func() -> bool: return boomer.boomer_state == BoomerEnemy.BoomerState.HOP_PREP,
		boomer.landing_recovery_duration + 0.12,
		"boomer next prep"
	)
	_require(boomer.boomer_state == BoomerEnemy.BoomerState.HOP_PREP, "Landing recovery returns to the next hop-prep cycle.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(154.0, 108.0))
	boomer = _spawn_boomer(root, player, Vector2(120.0, 108.0))
	var reached_fuse := await _advance_until(
		func() -> bool: return boomer.boomer_state == BoomerEnemy.BoomerState.FUSE,
		boomer.hop_prep_duration + boomer.hop_duration + 0.15,
		"immediate landing fuse"
	)
	_require(reached_fuse, "Boomer enters FUSE immediately when it lands inside trigger range.")
	_require(boomer.emitted_fuse_pulse_count >= 1, "Boomer starts the first fuse pulse on the landing-to-fuse transition.")
	var fuse_position := boomer.global_position
	await _advance_physics(0.18)
	_require(boomer.global_position == fuse_position, "FUSE keeps the Boomer world position fixed until detonation.")
	await _advance_physics(0.22)
	_require(boomer.emitted_fuse_pulse_count >= 2, "Boomer emits a second escalating fuse pulse.")
	await _advance_physics(0.26)
	_require(boomer.emitted_fuse_pulse_count >= 3, "Boomer emits the urgent third fuse pulse before detonation.")
	await _free_test_root(root)


func _audit_safe_spear_kill_and_armed_detonation() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(240.0, 108.0))
	var boomer := _spawn_boomer(root, player, Vector2(120.0, 108.0))
	var killed_count := 0
	var detonated_count := 0
	boomer.killed.connect(func(_enemy_position: Vector2, _score_value: int) -> void:
		killed_count += 1
	)
	boomer.detonated.connect(func(
		_position: Vector2,
		_core_radius: float,
		_outer_radius: float,
		_landed_spear_shockwave_displacement: float
	) -> void:
		detonated_count += 1
	)
	var safe_hit_response := boomer.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, boomer.global_position, Vector2.RIGHT)
	_require(safe_hit_response == Enemy.HitResponse.DAMAGED, "Pre-fuse spear hit returns ordinary damage response.")
	await get_tree().process_frame
	_require(boomer.is_dying and not boomer.has_detonated and detonated_count == 0, "Pre-fuse spear hit kills safely without detonating.")
	_require(boomer.score_value == 2, "Safe Boomer kill keeps the approved score value of 2.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(240.0, 108.0))
	boomer = _spawn_boomer(root, player, Vector2(120.0, 108.0))
	killed_count = 0
	detonated_count = 0
	boomer.killed.connect(func(_enemy_position: Vector2, _score_value: int) -> void:
		killed_count += 1
	)
	boomer.detonated.connect(func(
		_position: Vector2,
		_core_radius: float,
		_outer_radius: float,
		_landed_spear_shockwave_displacement: float
	) -> void:
		detonated_count += 1
	)
	boomer.call("_enter_fuse_state")
	var armed_hit_response := boomer.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, boomer.global_position, Vector2.RIGHT)
	var duplicate_hit_response := boomer.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, boomer.global_position, Vector2.RIGHT)
	_require(armed_hit_response == Enemy.HitResponse.DAMAGED, "Armed spear hit keeps the spear in the ordinary damaging path.")
	_require(duplicate_hit_response == Enemy.HitResponse.IGNORED, "Duplicate armed spear callbacks are ignored after the first detonation begins.")
	await get_tree().process_frame
	_require(killed_count == 0, "Armed spear hit avoids the safe score path and awards no direct kill score.")
	_require(not is_instance_valid(boomer), "Armed detonation self-cleans the Boomer immediately after resolving.")
	await _free_test_root(root)


func _audit_explosion_responses() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(148.0, 108.0))
	var boomer := _spawn_boomer(root, player, Vector2(120.0, 108.0))
	boomer.call("_start_detonation", boomer.global_position, Vector2.RIGHT)
	_require(player.health == player.max_health - 1, "Core blast deals exactly one health to the player.")
	_require(player.is_in_forced_movement(), "Core blast applies one authored knockback to the player when damage lands.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(174.0, 108.0))
	boomer = _spawn_boomer(root, player, Vector2(120.0, 108.0))
	boomer.call("_start_detonation", boomer.global_position, Vector2.RIGHT)
	_require(player.health == player.max_health, "Outer shockwave does not damage the player.")
	_require(not player.is_in_forced_movement(), "Outer shockwave does not knock the player back.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(320.0, 160.0))
	boomer = _spawn_boomer(root, player, Vector2(120.0, 108.0))
	var normal := _spawn_normal(root, player, Vector2(146.0, 108.0))
	var shooter := _spawn_shooter(root, player, Vector2(148.0, 120.0))
	var shielded := _spawn_shielded(root, player, Vector2(150.0, 96.0))
	var charger := _spawn_charger(root, player, Vector2(154.0, 108.0))
	var outer_normal := _spawn_normal(root, player, Vector2(166.0, 108.0))
	boomer.call("_start_detonation", boomer.global_position, Vector2.RIGHT)
	_require(normal.is_dying, "Core blast kills Normal enemies.")
	_require(shooter.is_dying, "Core blast kills Shooter enemies.")
	_require(not shielded.is_shield_intact() and not shielded.is_dying, "Core blast breaks intact Shielded enemies without killing them.")
	_require(not charger.is_dying and charger.state == Charger.State.RECOVER, "Core blast interrupts Charger into recovery instead of killing it.")
	_require(outer_normal.is_in_explosion_knockback() and not outer_normal.is_dying, "Outer shockwave knocks surviving outer-ring enemies back without damage.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(320.0, 160.0))
	boomer = _spawn_boomer(root, player, Vector2(120.0, 108.0))
	shielded = _spawn_shielded(root, player, Vector2(148.0, 108.0))
	shielded.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, shielded.global_position, Vector2.RIGHT)
	boomer.call("_start_detonation", boomer.global_position, Vector2.RIGHT)
	_require(shielded.is_dying, "Core blast kills exposed Shielded enemies.")
	await _free_test_root(root)


func _audit_player_and_spear_blast_exceptions() -> void:
	var root := Node2D.new()
	add_child(root)
	var protected_player := _spawn_player(root, Vector2(148.0, 108.0))
	_require(
		protected_player.try_start_forced_movement(
			Vector2.LEFT,
			52.0,
			0.24,
			Player.FORCED_MOVEMENT_PROTECTION_SHOVE
		),
		"Shove-protected forced movement can be active before a Boomer core blast."
	)
	var protected_direction := protected_player.forced_movement_direction
	var protected_time_left := protected_player.forced_movement_time_left
	var protected_boomer := _spawn_boomer(root, protected_player, Vector2(120.0, 108.0))
	protected_boomer.call("_start_detonation", protected_boomer.global_position, Vector2.RIGHT)
	_require(protected_player.health == protected_player.max_health, "Shove-protected Akedra takes no Boomer core-blast damage.")
	_require(protected_player.has_shove_damage_protection(), "Boomer core blast does not consume shove-specific protection.")
	_require(protected_player.is_in_forced_movement(), "Boomer core blast does not replace shove-authored forced movement.")
	_require(protected_player.invulnerability_left == 0.0, "Blocked Boomer damage does not start ordinary hurt invulnerability.")
	_require(
		protected_player.forced_movement_direction.distance_to(protected_direction) < 0.001,
		"Blocked Boomer damage preserves the original shove direction instead of applying a second impulse."
	)
	_require(
		is_equal_approx(protected_player.forced_movement_time_left, protected_time_left),
		"Blocked Boomer damage leaves the shove movement timing untouched on that frame."
	)
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(300.0, 160.0))
	var spear := _spawn_spear(root, player)
	var held_position := spear.global_position
	_require(
		not spear.apply_landed_shockwave_nudge(Vector2(120.0, 108.0), 54.0, 20.0),
		"Held spear ignores the landed-shockwave helper."
	)
	_require(spear.is_held() and spear.global_position == held_position, "Held spear stays unchanged by the Boomer shockwave helper.")

	var throw_target := player.global_position + Vector2(-80.0, 0.0)
	_require(spear.try_throw(throw_target), "Flying-spear shockwave audit can start from a valid throw.")
	var flying_position := spear.global_position
	_require(
		not spear.apply_landed_shockwave_nudge(Vector2(120.0, 108.0), 54.0, 20.0),
		"Flying spear ignores the landed-shockwave helper."
	)
	_require(spear.state == Spear.State.FLYING and spear.global_position == flying_position, "Flying spear stays in flight without a Boomer shockwave displacement.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(300.0, 160.0))
	spear = _spawn_spear(root, player)
	_force_landed_spear(spear, Vector2(150.0, 108.0), Vector2.RIGHT)
	var landed_start := spear.global_position
	_require(
		spear.apply_landed_shockwave_nudge(Vector2(120.0, 108.0), 54.0, 20.0),
		"Landed spear inside the Boomer outer radius receives one shockwave nudge."
	)
	await get_tree().process_frame
	var landed_shift := spear.global_position - landed_start
	_require(spear.is_landed(), "Shockwave-nudged spear stays in the LANDED state.")
	_require(landed_shift.length() >= 19.5 and landed_shift.length() <= 20.5, "Landed spear uses the approved restrained 20-pixel shockwave displacement.")
	_require(landed_shift.normalized().dot(Vector2.RIGHT) > 0.99, "Landed spear moves directly away from the blast center.")
	player.global_position = spear.global_position
	await get_tree().physics_frame
	spear.call("_on_pickup_body_entered", player)
	await get_tree().process_frame
	_require(spear.is_held(), "Shockwave-nudged landed spear remains retrievable through the normal pickup path.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(300.0, 160.0))
	spear = _spawn_spear(root, player)
	_force_landed_spear(spear, Vector2(220.0, 108.0), Vector2.RIGHT)
	var outside_position := spear.global_position
	_require(
		not spear.apply_landed_shockwave_nudge(Vector2(120.0, 108.0), 54.0, 20.0),
		"Landed spear outside the Boomer outer radius is not moved."
	)
	_require(spear.global_position == outside_position and spear.is_landed(), "Out-of-range landed spear remains unchanged and retrievable.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(300.0, 160.0))
	spear = _spawn_spear(root, player)
	_force_landed_spear(spear, Vector2(TEST_ARENA.end.x - 6.0, 108.0), Vector2.RIGHT)
	_require(
		spear.apply_landed_shockwave_nudge(Vector2(TEST_ARENA.end.x - 32.0, 108.0), 54.0, 20.0),
		"Arena-edge landed spear still receives the Boomer shockwave nudge."
	)
	await get_tree().process_frame
	_require(
		spear.global_position.x <= TEST_ARENA.end.x - 4.0,
		"Landed spear shockwave displacement clamps safely inside the arena."
	)
	_require(spear.is_landed(), "Arena-clamped shockwave displacement keeps the spear landed.")
	await _free_test_root(root)


func _audit_main_integration_and_lifecycle() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var director := main.get_node("EncounterDirector") as EncounterDirector
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	spawn_timer.stop()
	main.set_process(false)

	main.set("survival_time", 64.9)
	_require(
		not bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.BOOMER)),
		"Boomer is unavailable before its 65-second unlock."
	)
	main.set("survival_time", 65.0)
	_require(
		bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.BOOMER)),
		"Boomer becomes available at its 65-second unlock."
	)
	_require(is_equal_approx(float(main.call("_get_current_boomer_spawn_chance")), 0.025), "Boomer spawn chance starts at 0.025 at unlock.")
	main.set("survival_time", 75.0)
	_require(is_equal_approx(float(main.call("_get_current_boomer_spawn_chance")), 0.0285), "Boomer spawn chance grows by 0.00035 per second after unlock.")
	main.set("survival_time", 1000.0)
	_require(is_equal_approx(float(main.call("_get_current_boomer_spawn_chance")), 0.07), "Boomer spawn chance caps at 0.07.")

	director.reset_for_new_run()
	main.set("survival_time", 80.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.BOOMER, Arena.SpawnEdge.TOP, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Boomer can be spawned through the ordinary ambient path."
	)
	_require(not director.can_spawn_enemy(EncounterDirector.EnemyKind.BOOMER, 80.0), "Boomer cap blocks a second active Boomer.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 79.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("boomer_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 65.0)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.BOOMER,
		"Pending Boomer intro is selected once it is overdue and all earlier intros are already seen."
	)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.BOOMER, Arena.SpawnEdge.BOTTOM, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_DEBUG)),
		"Boomer debug spawn still works through the existing debug source path."
	)
	_require(not bool(main.get("boomer_intro_seen")), "Debug Boomer spawn does not mark the organic intro seen.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 79.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("boomer_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 65.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.BOOMER, Arena.SpawnEdge.LEFT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Boomer intro can be fulfilled through a successful ambient spawn."
	)
	_require(bool(main.get("boomer_intro_seen")), "Successful ambient Boomer spawn marks the intro seen.")
	var ambient_boomer := _find_child_boomer(main)
	var detonated_count := 0
	if ambient_boomer != null:
		ambient_boomer.detonated.connect(func(
			_position: Vector2,
			_core_radius: float,
			_outer_radius: float,
			_landed_spear_shockwave_displacement: float
		) -> void:
			detonated_count += 1
		)
		ambient_boomer.call("_enter_fuse_state")
		main.call("_set_pause_state", true)
		var paused_time := ambient_boomer.state_time_left
		await get_tree().create_timer(0.12, true, false, true).timeout
		_require(is_equal_approx(ambient_boomer.state_time_left, paused_time), "Pause freezes active Boomer fuse timing.")
		main.call("_set_pause_state", false)
		main.call("_restart_run")
		await get_tree().process_frame
		await get_tree().create_timer(0.90, true, false, true).timeout
		_require(detonated_count == 0, "Restart clears pending Boomer fuse before it can detonate later.")

	main.set_process(false)
	main.set("survival_time", 79.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.BOOMER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Boomer can be spawned again after restart for the game-over cleanup test."
	)
	ambient_boomer = _find_child_boomer(main)
	detonated_count = 0
	if ambient_boomer != null:
		ambient_boomer.detonated.connect(func(
			_position: Vector2,
			_core_radius: float,
			_outer_radius: float,
			_landed_spear_shockwave_displacement: float
		) -> void:
			detonated_count += 1
		)
		ambient_boomer.call("_enter_fuse_state")
		main.call("_on_player_died")
		await get_tree().create_timer(0.90, true, false, true).timeout
		_require(detonated_count == 0, "Game over clears a pending Boomer fuse instead of allowing a stale detonation.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(TEST_ARENA)
	player.reset_for_new_run(position, TEST_ARENA)
	return player


func _ensure_input_actions() -> void:
	for action_name in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _spawn_boomer(parent: Node, player: Player, position: Vector2) -> BoomerEnemy:
	var boomer := BoomerScene.instantiate() as BoomerEnemy
	parent.add_child(boomer)
	boomer.setup(player, TEST_ARENA, 42.0)
	boomer.global_position = position
	return boomer


func _spawn_spear(parent: Node, player: Player) -> Spear:
	var spear := SpearScene.instantiate() as Spear
	parent.add_child(spear)
	spear.setup(player, TEST_ARENA)
	spear.reset_for_new_run(player, TEST_ARENA)
	return spear


func _force_landed_spear(spear: Spear, position: Vector2, direction: Vector2) -> void:
	spear.throw_direction = direction.normalized()
	if spear.throw_direction == Vector2.ZERO:
		spear.throw_direction = Vector2.RIGHT
	spear.call("_enter_landed_state", position)


func _spawn_normal(parent: Node, player: Player, position: Vector2) -> Enemy:
	var enemy := EnemyScene.instantiate() as Enemy
	parent.add_child(enemy)
	enemy.setup(player, TEST_ARENA, 42.0)
	enemy.global_position = position
	return enemy


func _spawn_charger(parent: Node, player: Player, position: Vector2) -> Charger:
	var charger := ChargerScene.instantiate() as Charger
	parent.add_child(charger)
	charger.setup(player, TEST_ARENA, 42.0)
	charger.global_position = position
	return charger


func _spawn_shielded(parent: Node, player: Player, position: Vector2) -> ShieldedEnemy:
	var shielded := ShieldedScene.instantiate() as ShieldedEnemy
	parent.add_child(shielded)
	shielded.setup(player, TEST_ARENA, 42.0)
	shielded.global_position = position
	return shielded


func _spawn_shooter(parent: Node, player: Player, position: Vector2) -> ShooterEnemy:
	var shooter := ShooterScene.instantiate() as ShooterEnemy
	parent.add_child(shooter)
	shooter.setup(player, TEST_ARENA, 42.0)
	shooter.global_position = position
	return shooter


func _find_child_boomer(main: Node) -> BoomerEnemy:
	for child in main.get_node("EnemyContainer").get_children():
		if child is BoomerEnemy:
			return child
	return null


func _advance_physics(duration: float) -> void:
	var frames := int(ceil(duration * 60.0))
	for _index in range(maxi(frames, 1)):
		await get_tree().physics_frame


func _advance_until(
	condition: Callable,
	timeout: float,
	wait_label: String = ""
) -> bool:
	var frames := int(ceil(timeout * 60.0))
	for _index in range(maxi(frames, 1)):
		if bool(condition.call()):
			return true
		await get_tree().physics_frame
	if bool(condition.call()):
		return true
	if wait_label.is_empty():
		push_warning("BOOMER RUNTIME AUDIT WAIT TIMEOUT after %.2fs." % timeout)
	else:
		push_warning("BOOMER RUNTIME AUDIT WAIT TIMEOUT: %s after %.2fs." % [wait_label, timeout])
	return false


func _free_test_root(root: Node) -> void:
	root.queue_free()
	await get_tree().process_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
