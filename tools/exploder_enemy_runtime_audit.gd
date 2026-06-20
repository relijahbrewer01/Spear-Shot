extends Node

const PlayerScene := preload("res://Player.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ChargerScene := preload("res://Charger.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const ShooterScene := preload("res://ShooterEnemy.tscn")
const ExploderScene := preload("res://ExploderEnemy.tscn")
const MainScene := preload("res://Main.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))
const SPAWN_SOURCE_AMBIENT := 0
const SPAWN_SOURCE_DEBUG := 2

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_discrete_hop_and_immediate_fuse()
	await _audit_safe_spear_kill_and_armed_detonation()
	await _audit_explosion_responses()
	await _audit_main_integration_and_lifecycle()

	for failure in failures:
		push_error("EXPLODER RUNTIME AUDIT: %s" % failure)
	print("Exploder enemy runtime audit passed." if failures.is_empty() else "Exploder enemy runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_discrete_hop_and_immediate_fuse() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(260.0, 108.0))
	var exploder := _spawn_exploder(root, player, Vector2(120.0, 108.0))
	var prep_position := exploder.global_position

	await _advance_physics(0.10)
	_require(exploder.exploder_state == ExploderEnemy.ExploderState.HOP_PREP, "Exploder begins in stationary hop prep.")
	_require(exploder.global_position == prep_position, "Hop prep stays positionally stationary.")

	var reached_hop := await _advance_until(
		func() -> bool: return exploder.exploder_state == ExploderEnemy.ExploderState.HOPPING,
		0.20,
		"exploder hop start"
	)
	_require(reached_hop, "Exploder enters the committed hopping state after prep.")
	var hop_start := exploder.global_position
	var launch_direction := exploder.hop_direction
	await _advance_physics(exploder.hop_duration * 0.5)
	_require(exploder.global_position.distance_to(hop_start) > 8.0, "Only the hopping state translates the Exploder.")
	player.global_position = Vector2(260.0, 40.0)
	await _advance_until(
		func() -> bool:
			return exploder.exploder_state != ExploderEnemy.ExploderState.HOPPING,
		exploder.hop_duration + 0.12,
		"exploder hop finish"
	)
	var landed_direction := (exploder.global_position - hop_start).normalized()
	_require(landed_direction.dot(launch_direction) > 0.95, "Hop direction stays locked after takeoff even if the player moves.")
	_require(exploder.exploder_state == ExploderEnemy.ExploderState.LAND_RECOVERY, "Landing outside fuse range enters stationary landing recovery.")
	var recovery_position := exploder.global_position
	await _advance_physics(0.10)
	_require(exploder.global_position == recovery_position, "Landing recovery stays positionally stationary.")
	await _advance_until(
		func() -> bool: return exploder.exploder_state == ExploderEnemy.ExploderState.HOP_PREP,
		exploder.landing_recovery_duration + 0.12,
		"exploder next prep"
	)
	_require(exploder.exploder_state == ExploderEnemy.ExploderState.HOP_PREP, "Landing recovery returns to the next hop-prep cycle.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(154.0, 108.0))
	exploder = _spawn_exploder(root, player, Vector2(120.0, 108.0))
	var reached_fuse := await _advance_until(
		func() -> bool: return exploder.exploder_state == ExploderEnemy.ExploderState.FUSE,
		exploder.hop_prep_duration + exploder.hop_duration + 0.15,
		"immediate landing fuse"
	)
	_require(reached_fuse, "Exploder enters FUSE immediately when it lands inside trigger range.")
	_require(exploder.emitted_fuse_pulse_count >= 1, "Exploder starts the first fuse pulse on the landing-to-fuse transition.")
	var fuse_position := exploder.global_position
	await _advance_physics(0.18)
	_require(exploder.global_position == fuse_position, "FUSE keeps the Exploder world position fixed until detonation.")
	await _advance_physics(0.22)
	_require(exploder.emitted_fuse_pulse_count >= 2, "Exploder emits a second escalating fuse pulse.")
	await _advance_physics(0.26)
	_require(exploder.emitted_fuse_pulse_count >= 3, "Exploder emits the urgent third fuse pulse before detonation.")
	await _free_test_root(root)


func _audit_safe_spear_kill_and_armed_detonation() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(240.0, 108.0))
	var exploder := _spawn_exploder(root, player, Vector2(120.0, 108.0))
	var killed_count := 0
	var detonated_count := 0
	exploder.killed.connect(func(_enemy_position: Vector2, _score_value: int) -> void:
		killed_count += 1
	)
	exploder.detonated.connect(func(_position: Vector2, _core_radius: float, _outer_radius: float) -> void:
		detonated_count += 1
	)
	var safe_hit_response := exploder.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, exploder.global_position, Vector2.RIGHT)
	_require(safe_hit_response == Enemy.HitResponse.DAMAGED, "Pre-fuse spear hit returns ordinary damage response.")
	_require(killed_count == 1 and detonated_count == 0, "Pre-fuse spear hit kills safely without detonating.")
	_require(exploder.score_value == 2, "Safe Exploder kill keeps the approved score value of 2.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(240.0, 108.0))
	exploder = _spawn_exploder(root, player, Vector2(120.0, 108.0))
	killed_count = 0
	detonated_count = 0
	exploder.killed.connect(func(_enemy_position: Vector2, _score_value: int) -> void:
		killed_count += 1
	)
	exploder.detonated.connect(func(_position: Vector2, _core_radius: float, _outer_radius: float) -> void:
		detonated_count += 1
	)
	exploder.call("_enter_fuse_state")
	var armed_hit_response := exploder.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, exploder.global_position, Vector2.RIGHT)
	var duplicate_hit_response := exploder.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, exploder.global_position, Vector2.RIGHT)
	_require(armed_hit_response == Enemy.HitResponse.DAMAGED, "Armed spear hit keeps the spear in the ordinary damaging path.")
	_require(duplicate_hit_response == Enemy.HitResponse.IGNORED, "Duplicate armed spear callbacks are ignored after the first detonation begins.")
	_require(detonated_count == 1 and killed_count == 0, "Armed spear hit detonates exactly once without taking the safe score path.")
	await get_tree().process_frame
	_require(not is_instance_valid(exploder), "Armed detonation self-cleans the Exploder immediately after resolving.")
	await _free_test_root(root)


func _audit_explosion_responses() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(148.0, 108.0))
	var exploder := _spawn_exploder(root, player, Vector2(120.0, 108.0))
	exploder.call("_start_detonation", exploder.global_position, Vector2.RIGHT)
	_require(player.health == player.max_health - 1, "Core blast deals exactly one health to the player.")
	_require(player.is_in_forced_movement(), "Core blast applies one authored knockback to the player when damage lands.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(174.0, 108.0))
	exploder = _spawn_exploder(root, player, Vector2(120.0, 108.0))
	exploder.call("_start_detonation", exploder.global_position, Vector2.RIGHT)
	_require(player.health == player.max_health, "Outer shockwave does not damage the player.")
	_require(not player.is_in_forced_movement(), "Outer shockwave does not knock the player back.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(320.0, 160.0))
	exploder = _spawn_exploder(root, player, Vector2(120.0, 108.0))
	var normal := _spawn_normal(root, player, Vector2(146.0, 108.0))
	var shooter := _spawn_shooter(root, player, Vector2(148.0, 120.0))
	var shielded := _spawn_shielded(root, player, Vector2(150.0, 96.0))
	var charger := _spawn_charger(root, player, Vector2(154.0, 108.0))
	var outer_normal := _spawn_normal(root, player, Vector2(166.0, 108.0))
	exploder.call("_start_detonation", exploder.global_position, Vector2.RIGHT)
	_require(normal.is_dying, "Core blast kills Normal enemies.")
	_require(shooter.is_dying, "Core blast kills Shooter enemies.")
	_require(not shielded.is_shield_intact() and not shielded.is_dying, "Core blast breaks intact Shielded enemies without killing them.")
	_require(not charger.is_dying and charger.state == Charger.State.RECOVER, "Core blast interrupts Charger into recovery instead of killing it.")
	_require(outer_normal.is_in_explosion_knockback() and not outer_normal.is_dying, "Outer shockwave knocks surviving outer-ring enemies back without damage.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(320.0, 160.0))
	exploder = _spawn_exploder(root, player, Vector2(120.0, 108.0))
	shielded = _spawn_shielded(root, player, Vector2(148.0, 108.0))
	shielded.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, shielded.global_position, Vector2.RIGHT)
	exploder.call("_start_detonation", exploder.global_position, Vector2.RIGHT)
	_require(shielded.is_dying, "Core blast kills exposed Shielded enemies.")
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
		not bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.EXPLODER)),
		"Exploder is unavailable before its 65-second unlock."
	)
	main.set("survival_time", 65.0)
	_require(
		bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.EXPLODER)),
		"Exploder becomes available at its 65-second unlock."
	)
	_require(is_equal_approx(float(main.call("_get_current_exploder_spawn_chance")), 0.025), "Exploder spawn chance starts at 0.025 at unlock.")
	main.set("survival_time", 75.0)
	_require(is_equal_approx(float(main.call("_get_current_exploder_spawn_chance")), 0.0285), "Exploder spawn chance grows by 0.00035 per second after unlock.")
	main.set("survival_time", 1000.0)
	_require(is_equal_approx(float(main.call("_get_current_exploder_spawn_chance")), 0.07), "Exploder spawn chance caps at 0.07.")

	director.reset_for_new_run()
	main.set("survival_time", 80.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.EXPLODER, Arena.SpawnEdge.TOP, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Exploder can be spawned through the ordinary ambient path."
	)
	_require(not director.can_spawn_enemy(EncounterDirector.EnemyKind.EXPLODER, 80.0), "Exploder cap blocks a second active Exploder.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 79.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("exploder_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 65.0)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.EXPLODER,
		"Pending Exploder intro is selected once it is overdue and all earlier intros are already seen."
	)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.EXPLODER, Arena.SpawnEdge.BOTTOM, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_DEBUG)),
		"Exploder debug spawn still works through the existing debug source path."
	)
	_require(not bool(main.get("exploder_intro_seen")), "Debug Exploder spawn does not mark the organic intro seen.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 79.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("exploder_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 65.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.EXPLODER, Arena.SpawnEdge.LEFT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Exploder intro can be fulfilled through a successful ambient spawn."
	)
	_require(bool(main.get("exploder_intro_seen")), "Successful ambient Exploder spawn marks the intro seen.")
	var ambient_exploder := _find_child_exploder(main)
	var detonated_count := 0
	if ambient_exploder != null:
		ambient_exploder.detonated.connect(func(_position: Vector2, _core_radius: float, _outer_radius: float) -> void:
			detonated_count += 1
		)
		ambient_exploder.call("_enter_fuse_state")
		main.call("_set_pause_state", true)
		var paused_time := ambient_exploder.state_time_left
		await get_tree().create_timer(0.12, true, false, true).timeout
		_require(is_equal_approx(ambient_exploder.state_time_left, paused_time), "Pause freezes active Exploder fuse timing.")
		main.call("_set_pause_state", false)
		main.call("_restart_run")
		await get_tree().process_frame
		await get_tree().create_timer(0.90, true, false, true).timeout
		_require(detonated_count == 0, "Restart clears pending Exploder fuse before it can detonate later.")

	main.set_process(false)
	main.set("survival_time", 79.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.EXPLODER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Exploder can be spawned again after restart for the game-over cleanup test."
	)
	ambient_exploder = _find_child_exploder(main)
	detonated_count = 0
	if ambient_exploder != null:
		ambient_exploder.detonated.connect(func(_position: Vector2, _core_radius: float, _outer_radius: float) -> void:
			detonated_count += 1
		)
		ambient_exploder.call("_enter_fuse_state")
		main.call("_on_player_died")
		await get_tree().create_timer(0.90, true, false, true).timeout
		_require(detonated_count == 0, "Game over clears a pending Exploder fuse instead of allowing a stale detonation.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(TEST_ARENA)
	player.reset_for_new_run(position, TEST_ARENA)
	return player


func _spawn_exploder(parent: Node, player: Player, position: Vector2) -> ExploderEnemy:
	var exploder := ExploderScene.instantiate() as ExploderEnemy
	parent.add_child(exploder)
	exploder.setup(player, TEST_ARENA, 42.0)
	exploder.global_position = position
	return exploder


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


func _find_child_exploder(main: Node) -> ExploderEnemy:
	for child in main.get_node("EnemyContainer").get_children():
		if child is ExploderEnemy:
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
		push_warning("EXPLODER RUNTIME AUDIT WAIT TIMEOUT after %.2fs." % timeout)
	else:
		push_warning("EXPLODER RUNTIME AUDIT WAIT TIMEOUT: %s after %.2fs." % [wait_label, timeout])
	return false


func _free_test_root(root: Node) -> void:
	root.queue_free()
	await get_tree().process_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
