extends Node

const PlayerScene := preload("res://Player.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const ChargerScene := preload("res://Charger.tscn")
const ShooterScene := preload("res://ShooterEnemy.tscn")
const BoomerScene := preload("res://BoomerEnemy.tscn")
const ProwlerScene := preload("res://ProwlerEnemy.tscn")
const MainScene := preload("res://Main.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))
const TEST_WAVE_ID := 77
const SPAWN_SOURCE_AMBIENT := 0
const SPAWN_SOURCE_WAVE := 1

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_formation_bias_assignment_and_reset()
	await _audit_formation_bias_movement()
	await _audit_authored_displacement_contract()
	await _audit_shielded_opt_in_and_pause()

	for failure in failures:
		push_error("ENEMY SYNERGY AUDIT: %s" % failure)
	if failures.is_empty():
		print("Enemy synergy runtime audit passed.")

	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_formation_bias_assignment_and_reset() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	_stop_main_runtime(main)

	var gameplay_seed := 81234
	main.rng.seed = gameplay_seed
	var expected_roll := main.rng.randi()
	main.rng.seed = gameplay_seed
	main.call("_get_next_formation_bias", false)
	var actual_roll := main.rng.randi()
	_require(expected_roll == actual_roll, "Gameplay RNG stream is unchanged by non-debug formation assignment.")

	main.rng.seed = gameplay_seed
	var debug_expected_roll := main.rng.randi()
	main.rng.seed = gameplay_seed
	main.call("_get_next_formation_bias", true)
	var debug_actual_roll := main.rng.randi()
	_require(debug_expected_roll == debug_actual_roll, "Gameplay RNG stream is unchanged by debug formation assignment.")

	main.call("_reset_runtime_state")
	await get_tree().process_frame
	_stop_main_runtime(main)
	main.call("_get_next_formation_bias", true)
	var first_non_debug_bias := _bias_name_from_value(int(main.call("_get_next_formation_bias", false)))
	_require(first_non_debug_bias == "DIRECT", "Debug formation assignment uses a separate counter and does not consume the live sequence.")
	main.call("_reset_runtime_state")
	await get_tree().process_frame
	_stop_main_runtime(main)

	var assigned_biases: Array[String] = []
	for _index in 3:
		_require(
			main.call(
				"_try_spawn_enemy",
				EncounterDirector.EnemyKind.NORMAL,
				Arena.SpawnEdge.TOP,
				EncounterDirector.INVALID_WAVE_ID,
				SPAWN_SOURCE_AMBIENT
			),
			"Normal enemy spawn succeeds for formation-bias assignment coverage."
		)
		var spawned_enemy := _get_last_enemy(main)
		assigned_biases.append(spawned_enemy.get_formation_bias_name())

	_require(
		assigned_biases == ["DIRECT", "LEFT_FLANK", "RIGHT_FLANK"],
		"All three formation bias values are assigned in a deterministic repeating sequence."
	)
	await _advance_physics(0.10)
	var persisted_biases: Array[String] = []
	for enemy_node in _get_enemy_children(main):
		persisted_biases.append((enemy_node as Enemy).get_formation_bias_name())
	_require(persisted_biases == assigned_biases, "Assigned formation bias persists for each enemy after movement frames.")

	main.call("_reset_runtime_state")
	await get_tree().process_frame
	_stop_main_runtime(main)
	var restart_biases: Array[String] = []
	for _index in 3:
		_require(
			main.call(
				"_try_spawn_enemy",
				EncounterDirector.EnemyKind.NORMAL,
				Arena.SpawnEdge.TOP,
				EncounterDirector.INVALID_WAVE_ID,
				SPAWN_SOURCE_AMBIENT
			),
			"Restarted Normal enemy spawn succeeds for deterministic reset coverage."
		)
		restart_biases.append(_get_last_enemy(main).get_formation_bias_name())

	_require(restart_biases == assigned_biases, "Restart resets the non-debug formation assignment sequence deterministically.")
	main.queue_free()
	await get_tree().process_frame


func _audit_formation_bias_movement() -> void:
	var left_case := Node2D.new()
	add_child(left_case)
	var player := _spawn_player(left_case, Vector2(176.0, 108.0))
	var direct_enemy := _spawn_enemy(left_case, EnemyScene, player, Vector2(96.0, 108.0))
	var left_enemy := _spawn_enemy(left_case, EnemyScene, player, Vector2(96.0, 108.0))
	var right_enemy := _spawn_enemy(left_case, EnemyScene, player, Vector2(96.0, 108.0))
	direct_enemy.set_formation_bias(Enemy.FormationBias.DIRECT)
	left_enemy.set_formation_bias(Enemy.FormationBias.LEFT_FLANK)
	right_enemy.set_formation_bias(Enemy.FormationBias.RIGHT_FLANK)

	var direct_direction := (player.global_position - direct_enemy.global_position).normalized()
	var direct_velocity: Vector2 = direct_enemy.call("_get_chase_velocity")
	var left_velocity: Vector2 = left_enemy.call("_get_chase_velocity")
	var right_velocity: Vector2 = right_enemy.call("_get_chase_velocity")
	var left_cross := direct_direction.cross(left_velocity.normalized())
	var right_cross := direct_direction.cross(right_velocity.normalized())

	_require(absf(left_cross) > 0.08 and absf(right_cross) > 0.08, "Left and right formation bias produce a visible tangential influence.")
	_require(left_cross * right_cross < 0.0, "Left and right formation bias bend approach in opposite directions.")
	_require(absf(direct_direction.cross(direct_velocity.normalized())) < 0.01, "Direct formation bias preserves ordinary direct pressure.")
	left_case.queue_free()
	await get_tree().process_frame

	var close_case := Node2D.new()
	add_child(close_case)
	var close_player := _spawn_player(close_case, Vector2(176.0, 108.0))
	var close_enemy := _spawn_enemy(close_case, EnemyScene, close_player, Vector2(154.0, 108.0))
	close_enemy.set_formation_bias(Enemy.FormationBias.LEFT_FLANK)
	var close_direction := (close_player.global_position - close_enemy.global_position).normalized()
	var close_velocity: Vector2 = close_enemy.call("_get_chase_velocity")
	_require(
		close_velocity.normalized().dot(close_direction) > 0.995,
		"Close-range fallback collapses biased movement back toward direct pressure."
	)
	close_case.queue_free()
	await get_tree().process_frame

	var separation_case := Node2D.new()
	add_child(separation_case)
	var separation_player := _spawn_player(separation_case, Vector2(176.0, 108.0))
	var solo_enemy := _spawn_enemy(separation_case, EnemyScene, separation_player, Vector2(96.0, 108.0))
	solo_enemy.set_formation_bias(Enemy.FormationBias.DIRECT)
	var solo_velocity: Vector2 = solo_enemy.call("_get_chase_velocity")
	var neighbor_enemy := _spawn_enemy(separation_case, EnemyScene, separation_player, Vector2(104.0, 108.0))
	neighbor_enemy.set_formation_bias(Enemy.FormationBias.DIRECT)
	var separated_velocity: Vector2 = solo_enemy.call("_get_chase_velocity")
	_require(
		separated_velocity.distance_to(solo_velocity) > 1.0,
		"Ordinary separation remains active alongside the shared crowd-flow bias."
	)
	separation_case.queue_free()
	await get_tree().process_frame

	var special_case := Node2D.new()
	add_child(special_case)
	var special_player := _spawn_player(special_case, Vector2(176.0, 108.0))
	var charger := _spawn_enemy(special_case, ChargerScene, special_player, Vector2(96.0, 108.0)) as Charger
	var shooter := _spawn_enemy(special_case, ShooterScene, special_player, Vector2(112.0, 108.0)) as ShooterEnemy
	var boomer := _spawn_enemy(special_case, BoomerScene, special_player, Vector2(128.0, 108.0)) as BoomerEnemy
	var prowler := _spawn_enemy(special_case, ProwlerScene, special_player, Vector2(144.0, 108.0)) as ProwlerEnemy
	for special_enemy in [charger, shooter, boomer, prowler]:
		special_enemy.set_formation_bias(Enemy.FormationBias.LEFT_FLANK)
		_require(not special_enemy.uses_formation_bias, "%s stays out of the shared formation movement path." % special_enemy.get_class())
		_require(
			not special_enemy.can_accept_authored_hostile_displacement(),
			"%s is not implicitly displacement-enabled through inheritance." % special_enemy.get_class()
		)
	special_case.queue_free()
	await get_tree().process_frame


func _audit_authored_displacement_contract() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(176.0, 108.0))
	var enemy := _spawn_enemy(root, EnemyScene, player, Vector2(96.0, 108.0))
	var start_position := enemy.global_position
	var killed_count := 0
	enemy.killed.connect(func(_position: Vector2, _score: int) -> void:
		killed_count += 1
	)

	_require(enemy.can_accept_authored_hostile_displacement(), "Normal enemy accepts authored hostile displacement when in ordinary locomotion.")
	_require(
		enemy.try_start_authored_hostile_displacement(&"audit", Vector2.RIGHT, 24.0, 0.24),
		"Normal enemy starts a valid authored hostile displacement request."
	)
	_require(enemy.is_in_authored_hostile_displacement(), "Normal enemy enters the authored hostile-displacement state.")
	_require(
		not enemy.try_start_authored_hostile_displacement(&"audit", Vector2.UP, 12.0, 0.12),
		"Duplicate authored hostile-displacement requests are rejected while one is active."
	)
	await _advance_physics(0.12)
	var halfway_distance := enemy.global_position.distance_to(start_position)
	_require(halfway_distance >= 10.0 and halfway_distance <= 14.0, "Authored hostile displacement advances partway through its authored travel.")
	await _advance_physics(0.16)
	var full_distance := enemy.global_position.distance_to(start_position)
	_require(not enemy.is_in_authored_hostile_displacement(), "Authored hostile displacement ends naturally after its authored duration.")
	_require(full_distance >= 22.0 and full_distance <= 25.5, "Authored hostile displacement reaches approximately the requested distance.")
	_require(player.health == player.max_health, "Authored hostile displacement does not deal player health damage.")
	_require(killed_count == 0 and not enemy.is_dying, "Authored hostile displacement does not kill, score, or emit death state changes.")

	var edge_enemy := _spawn_enemy(root, EnemyScene, player, Vector2(TEST_ARENA.end.x - 10.0, 108.0))
	var edge_start := edge_enemy.global_position
	_require(
		edge_enemy.try_start_authored_hostile_displacement(&"audit", Vector2.RIGHT, 24.0, 0.24),
		"Arena-edge authored displacement request still starts for clamp coverage."
	)
	await _advance_physics(0.28)
	_require(edge_enemy.global_position.x <= TEST_ARENA.end.x - edge_enemy.body_radius + 0.01, "Authored hostile displacement remains clamped inside the arena.")
	_require(edge_enemy.global_position.distance_to(edge_start) < 24.0, "Arena clamping can shorten authored hostile displacement travel safely.")

	var cleanup_enemy := _spawn_enemy(root, EnemyScene, player, Vector2(120.0, 108.0))
	_require(
		cleanup_enemy.try_start_authored_hostile_displacement(&"audit", Vector2.RIGHT, 24.0, 0.24),
		"Cleanup coverage starts from an active authored hostile displacement."
	)
	cleanup_enemy.take_spear_hit()
	_require(not cleanup_enemy.is_in_authored_hostile_displacement(), "Death clears authored hostile displacement immediately.")

	root.queue_free()
	await get_tree().process_frame

	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	_stop_main_runtime(main)
	_require(
		main.call(
			"_try_spawn_enemy",
			EncounterDirector.EnemyKind.NORMAL,
			Arena.SpawnEdge.TOP,
			TEST_WAVE_ID,
			SPAWN_SOURCE_WAVE
		),
		"Wave-owned Normal spawn succeeds for authored displacement ownership coverage."
	)
	var wave_enemy := _get_last_enemy(main)
	var director := main.get_node("EncounterDirector") as EncounterDirector
	var hostile_count_before := director.get_total_hostile_count()
	_require(
		wave_enemy.try_start_authored_hostile_displacement(&"audit", Vector2.RIGHT, 24.0, 0.24),
		"Wave-owned Normal accepts authored hostile displacement."
	)
	await _advance_physics(0.28)
	_require(main.score == 0, "Authored hostile displacement awards no score through Main.")
	_require(
		director.get_total_hostile_count() == hostile_count_before,
		"Authored hostile displacement does not clear hostile ownership or population tracking."
	)
	main.queue_free()
	await get_tree().process_frame


func _audit_shielded_opt_in_and_pause() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(176.0, 108.0))
	var shielded := _spawn_enemy(root, ShieldedScene, player, Vector2(96.0, 108.0)) as ShieldedEnemy
	_require(shielded.can_accept_authored_hostile_displacement(), "Shielded accepts authored hostile displacement during safe ordinary movement.")
	_require(
		shielded.try_start_authored_hostile_displacement(&"audit", Vector2.RIGHT, 24.0, 0.24),
		"Shielded can start authored hostile displacement while not staggered."
	)
	await _advance_physics(0.28)
	_require(not shielded.is_in_authored_hostile_displacement(), "Shielded authored hostile displacement completes cleanly.")

	var staggered := _spawn_enemy(root, ShieldedScene, player, Vector2(128.0, 108.0)) as ShieldedEnemy
	staggered.receive_combat_hit(
		Enemy.HIT_SOURCE_SPEAR,
		staggered.global_position - Vector2.RIGHT * staggered.body_radius,
		Vector2.RIGHT
	)
	_require(not staggered.can_accept_authored_hostile_displacement(), "Shielded rejects authored hostile displacement during shield-break stagger.")
	_require(
		not staggered.try_start_authored_hostile_displacement(&"audit", Vector2.RIGHT, 24.0, 0.24),
		"Shielded stagger rejection returns a clean failure result."
	)

	var dead_shielded := _spawn_enemy(root, ShieldedScene, player, Vector2(152.0, 108.0)) as ShieldedEnemy
	dead_shielded.take_spear_hit()
	_require(not dead_shielded.can_accept_authored_hostile_displacement(), "Dying Shielded rejects authored hostile displacement.")

	var pause_enemy := _spawn_enemy(root, EnemyScene, player, Vector2(96.0, 132.0))
	_require(
		pause_enemy.try_start_authored_hostile_displacement(&"audit", Vector2.RIGHT, 24.0, 0.24),
		"Pause coverage starts from an active authored hostile displacement."
	)
	var paused_position := pause_enemy.global_position
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(pause_enemy.global_position == paused_position, "Pause does not advance authored hostile displacement.")
	get_tree().paused = false
	await _advance_physics(0.12)
	_require(pause_enemy.global_position.x > paused_position.x, "Authored hostile displacement resumes after pause.")

	root.queue_free()
	await get_tree().process_frame


func _spawn_player(root: Node, start_position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	root.add_child(player)
	player.reset_for_new_run(start_position, TEST_ARENA)
	return player


func _spawn_enemy(root: Node, scene: PackedScene, player: Player, start_position: Vector2) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	root.add_child(enemy)
	enemy.setup(player, TEST_ARENA, 42.0)
	enemy.global_position = start_position
	return enemy


func _advance_physics(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _stop_main_runtime(main: Node) -> void:
	main.set_process(false)
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	if spawn_timer != null:
		spawn_timer.stop()
	var opportunity_timer := main.get_node("OpportunityTimer") as Timer
	if opportunity_timer != null:
		opportunity_timer.stop()


func _get_enemy_children(main: Node) -> Array:
	var enemy_container := main.get_node("EnemyContainer") as Node2D
	return enemy_container.get_children()


func _get_last_enemy(main: Node) -> Enemy:
	var enemy_children := _get_enemy_children(main)
	return enemy_children[enemy_children.size() - 1] as Enemy


func _bias_name_from_value(bias_value: int) -> String:
	match bias_value:
		Enemy.FormationBias.LEFT_FLANK:
			return "LEFT_FLANK"
		Enemy.FormationBias.RIGHT_FLANK:
			return "RIGHT_FLANK"
	return "DIRECT"


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
