extends Node

const PlayerScene := preload("res://Player.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const ChargerScene := preload("res://Charger.tscn")
const ShooterScene := preload("res://ShooterEnemy.tscn")
const BoomerScene := preload("res://BoomerEnemy.tscn")
const ProwlerScene := preload("res://ProwlerEnemy.tscn")
const DartProjectileScene := preload("res://DartProjectile.tscn")
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
	await _audit_shielded_shooter_cooperation()
	await _audit_shooter_dart_boomer_interaction()

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


func _audit_shielded_shooter_cooperation() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(86.0, 108.0))
	var shielded := _spawn_enemy(root, ShieldedScene, player, Vector2(152.0, 108.0)) as ShieldedEnemy
	var shooter := _spawn_enemy(root, ShooterScene, player, Vector2(208.0, 108.0)) as ShooterEnemy
	shooter.first_attack_delay_left = 99.0
	shooter.attack_cooldown_left = 0.0
	shooter.minimum_dart_interval_left = 0.0
	shooter.shove_cooldown_left = 99.0

	var dart_count := 0
	shooter.dart_requested.connect(func(_spawn_position: Vector2, _fire_direction: Vector2, _burst_id: int, _dart_index: int) -> void:
		dart_count += 1
	)

	var anchored := await _advance_until(func() -> bool:
		return shooter.anchor_shielded == shielded
	, 0.50)
	_require(anchored, "Shooter acquires a valid intact Shielded anchor.")
	_require(shooter.shooter_state == ShooterEnemy.ShooterState.COVER_HOLD, "Anchored Shooter enters cover hold during ordinary movement.")

	var behind_alignment := (shooter.global_position - shielded.global_position).normalized().dot(
		(shielded.global_position - player.global_position).normalized()
	)
	_require(behind_alignment > 0.75, "Anchored Shooter moves behind Shielded relative to Akedra.")
	shooter.first_attack_delay_left = 0.0

	var saw_cover_hold := false
	var saw_cover_peek := false
	var aim_started_with_clear_lane := false
	for _index in 90:
		if shooter.shooter_state == ShooterEnemy.ShooterState.COVER_HOLD:
			saw_cover_hold = true
		if shooter.shooter_state == ShooterEnemy.ShooterState.COVER_PEEK:
			saw_cover_peek = true
		if shooter.shooter_state == ShooterEnemy.ShooterState.AIM:
			var tangent := Vector2(
				-(shielded.global_position - player.global_position).normalized().y,
				(shielded.global_position - player.global_position).normalized().x
			)
			var side_distance := absf((shooter.global_position - shielded.global_position).dot(tangent))
			aim_started_with_clear_lane = side_distance >= 8.0 and bool(
				shooter.call("_has_clear_anchor_lane", shooter.global_position, shielded)
			)
			break
		await get_tree().physics_frame

	_require(saw_cover_hold, "Anchored Shooter uses a dedicated cover-hold phase during ordinary movement.")
	_require(saw_cover_peek, "Anchored Shooter peeks to a side before beginning its committed attack.")
	_require(aim_started_with_clear_lane, "Shooter does not begin AIM from directly behind Shielded without a clear lane.")

	var finished_burst := await _advance_until(func() -> bool:
		return dart_count == 2
	, 1.50)
	_require(finished_burst and dart_count == 2, "Once anchored AIM begins, the existing committed two-dart attack still finishes normally.")

	shielded.receive_combat_hit(
		Enemy.HIT_SOURCE_SPEAR,
		shielded.global_position - Vector2.RIGHT * shielded.body_radius,
		Vector2.RIGHT
	)
	await _advance_physics(0.05)
	_require(shooter.anchor_shielded == null, "Shooter abandons the anchor immediately when Shielded loses its shield.")

	player.global_position = Vector2(110.0, 108.0)
	shooter.global_position = Vector2(162.0, 108.0)
	shooter.first_attack_delay_left = 99.0
	await _advance_physics(0.18)
	_require(
		shooter.shooter_state == ShooterEnemy.ShooterState.REPOSITION,
		"Shooter returns to ordinary behavior when no valid Shielded anchor exists."
	)

	root.queue_free()
	await get_tree().process_frame

	var death_root := Node2D.new()
	add_child(death_root)
	var death_player := _spawn_player(death_root, Vector2(86.0, 108.0))
	var death_shielded := _spawn_enemy(death_root, ShieldedScene, death_player, Vector2(152.0, 108.0)) as ShieldedEnemy
	var death_shooter := _spawn_enemy(death_root, ShooterScene, death_player, Vector2(208.0, 108.0)) as ShooterEnemy
	death_shooter.first_attack_delay_left = 99.0
	var death_anchor_ready := await _advance_until(func() -> bool:
		return death_shooter.anchor_shielded == death_shielded
	, 0.50)
	_require(death_anchor_ready, "Shooter can acquire a second intact Shielded anchor for cleanup coverage.")
	death_shielded.take_spear_hit()
	await _advance_physics(0.05)
	_require(death_shooter.anchor_shielded == null, "Shooter abandons the anchor when Shielded dies or leaves the live contract.")
	death_root.queue_free()
	await get_tree().process_frame

	var two_root := Node2D.new()
	add_child(two_root)
	var two_player := _spawn_player(two_root, Vector2(86.0, 108.0))
	var shared_shielded := _spawn_enemy(two_root, ShieldedScene, two_player, Vector2(152.0, 108.0)) as ShieldedEnemy
	var primary_shooter := _spawn_enemy(two_root, ShooterScene, two_player, Vector2(208.0, 98.0)) as ShooterEnemy
	primary_shooter.first_attack_delay_left = 99.0
	var primary_anchor_ready := await _advance_until(func() -> bool:
		return primary_shooter.anchor_shielded == shared_shielded and primary_shooter.preferred_cover_side != 0
	, 0.50)
	_require(primary_anchor_ready, "Primary Shooter anchors before the shared-anchor side-preference check.")
	var support_shooter := _spawn_enemy(two_root, ShooterScene, two_player, Vector2(212.0, 118.0)) as ShooterEnemy
	support_shooter.first_attack_delay_left = 99.0
	var support_anchor_ready := await _advance_until(func() -> bool:
		return support_shooter.anchor_shielded == shared_shielded and support_shooter.preferred_cover_side != 0
	, 0.60)
	_require(support_anchor_ready, "Second Shooter also acquires the shared Shielded anchor.")
	_require(
		support_anchor_ready and primary_anchor_ready and primary_shooter.preferred_cover_side == -support_shooter.preferred_cover_side,
		"Two Shooters sharing one Shielded prefer opposite cover or peek sides when possible."
	)
	var initial_primary_side := primary_shooter.preferred_cover_side
	var initial_support_side := support_shooter.preferred_cover_side
	await _advance_physics(0.55)
	_require(
		primary_shooter.preferred_cover_side == initial_primary_side and support_shooter.preferred_cover_side == initial_support_side,
		"Shared-anchor Shooter side choices stay stable instead of endlessly swapping."
	)
	_require(
		primary_shooter.global_position.distance_to(support_shooter.global_position) > 10.0,
		"Two Shooters sharing one Shielded do not permanently overlap while holding cover."
	)
	two_root.queue_free()
	await get_tree().process_frame

	var shove_root := Node2D.new()
	add_child(shove_root)
	var shove_player := _spawn_player(shove_root, Vector2(86.0, 108.0))
	var shove_shielded := _spawn_enemy(shove_root, ShieldedScene, shove_player, Vector2(152.0, 108.0)) as ShieldedEnemy
	var shove_shooter := _spawn_enemy(shove_root, ShooterScene, shove_player, Vector2(208.0, 108.0)) as ShooterEnemy
	shove_shooter.first_attack_delay_left = 99.0
	var shove_anchor_ready := await _advance_until(func() -> bool:
		return shove_shooter.anchor_shielded == shove_shielded
	, 0.50)
	_require(shove_anchor_ready, "Anchored Shooter setup succeeds before close-range shove coverage.")
	shove_player.global_position = Vector2(166.0, 108.0)
	var shove_started := await _advance_until(func() -> bool:
		return shove_shooter.shooter_state == ShooterEnemy.ShooterState.SHOVE_WINDUP
	, 0.25)
	_require(shove_started, "Close-range shove still takes priority over anchored cover behavior.")
	_require(shove_shooter.anchor_shielded == null, "Shove path abandons the anchor instead of keeping stale cover state.")
	shove_root.queue_free()
	await get_tree().process_frame

	var cleanup_root := Node2D.new()
	add_child(cleanup_root)
	var cleanup_player := _spawn_player(cleanup_root, Vector2(86.0, 108.0))
	var cleanup_shielded := _spawn_enemy(cleanup_root, ShieldedScene, cleanup_player, Vector2(152.0, 108.0)) as ShieldedEnemy
	var cleanup_shooter := _spawn_enemy(cleanup_root, ShooterScene, cleanup_player, Vector2(208.0, 108.0)) as ShooterEnemy
	cleanup_shooter.first_attack_delay_left = 99.0
	var cleanup_anchor_ready := await _advance_until(func() -> bool:
		return cleanup_shooter.anchor_shielded == cleanup_shielded
	, 0.50)
	_require(cleanup_anchor_ready, "Cleanup coverage acquires an anchor before deactivation.")
	cleanup_shooter.set_active(false)
	_require(cleanup_shooter.anchor_shielded == null, "Deactivate or restart-style cleanup clears stale Shooter anchor references.")
	cleanup_root.queue_free()
	await get_tree().process_frame


func _audit_shooter_dart_boomer_interaction() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(320.0, 160.0))
	var boomer := _spawn_enemy(root, BoomerScene, player, Vector2(160.0, 108.0)) as BoomerEnemy
	var first_dart := _spawn_dart(root, player, Vector2(145.0, 108.0), Vector2.RIGHT)
	var first_hit := await _advance_until(func() -> bool:
		return boomer.boomer_state == BoomerEnemy.BoomerState.FUSE and not is_instance_valid(first_dart)
	, 0.20)
	_require(first_hit, "A Shooter dart consumed by an unfused Boomer starts the existing normal fuse.")
	_require(boomer.emitted_fuse_pulse_count == 1, "Boomer keeps its normal fuse pulse sequence when triggered by a dart.")
	var detonated_count := 0
	boomer.detonated.connect(func(
		_position: Vector2,
		_core_radius: float,
		_outer_radius: float,
		_landed_spear_shockwave_displacement: float
	) -> void:
		detonated_count += 1
	)

	await _advance_physics(0.12)
	var fuse_time_before_second_dart := boomer.state_time_left
	var second_dart := _spawn_dart(root, player, Vector2(145.0, 108.0), Vector2.RIGHT)
	var second_hit := await _advance_until(func() -> bool:
		return not is_instance_valid(second_dart)
	, 0.20)
	_require(second_hit, "A second Shooter dart is still consumed by an already-fusing Boomer.")
	_require(boomer.boomer_state == BoomerEnemy.BoomerState.FUSE, "An already-fusing Boomer stays on its existing fuse path after another dart.")
	_require(boomer.state_time_left < fuse_time_before_second_dart, "A second Shooter dart does not restart, extend, or otherwise refresh the fuse timer.")

	var single_detonation := await _advance_until(func() -> bool:
		return detonated_count == 1
	, boomer.fuse_duration + 0.20)
	_require(single_detonation and detonated_count == 1, "Repeated Shooter darts do not schedule duplicate Boomer detonations.")
	root.queue_free()
	await get_tree().process_frame

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(320.0, 160.0))
	boomer = _spawn_enemy(root, BoomerScene, player, Vector2(160.0, 108.0)) as BoomerEnemy
	var paused_dart := _spawn_dart(root, player, Vector2(145.0, 108.0), Vector2.RIGHT)
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(boomer.boomer_state == BoomerEnemy.BoomerState.HOP_PREP, "Pause freezes the Boomer before an in-flight dart can trigger its fuse.")
	_require(is_instance_valid(paused_dart), "Pause also freezes the in-flight Shooter dart instead of resolving the Boomer interaction early.")
	get_tree().paused = false
	var resumed_hit := await _advance_until(func() -> bool:
		return boomer.boomer_state == BoomerEnemy.BoomerState.FUSE and not is_instance_valid(paused_dart)
	, 0.20)
	_require(resumed_hit, "The same in-flight Shooter dart resumes into the normal Boomer fuse after pause ends.")
	root.queue_free()
	await get_tree().process_frame

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(320.0, 160.0))
	boomer = _spawn_enemy(root, BoomerScene, player, Vector2(160.0, 108.0)) as BoomerEnemy
	boomer.set_active(false)
	var inactive_dart := _spawn_dart(root, player, Vector2(145.0, 108.0), Vector2.RIGHT)
	var passed_inactive_boomer := await _advance_until(func() -> bool:
		return inactive_dart.global_position.x >= boomer.global_position.x + boomer.body_radius + 12.0 or not is_instance_valid(inactive_dart)
	, 0.25)
	_require(passed_inactive_boomer and boomer.boomer_state == BoomerEnemy.BoomerState.HOP_PREP, "Cleanup-style Boomer deactivation disables the dart trigger instead of leaving a stale fuse target.")
	_require(is_instance_valid(inactive_dart), "An inactive Boomer does not consume later Shooter darts.")
	if is_instance_valid(inactive_dart):
		inactive_dart.destroy_projectile()
	await get_tree().process_frame
	root.queue_free()
	await get_tree().process_frame

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(176.0, 108.0))
	var player_dart := _spawn_dart(root, player, Vector2(152.0, 108.0), Vector2.RIGHT)
	var player_hit := await _advance_until(func() -> bool:
		return not is_instance_valid(player_dart)
	, 0.20)
	_require(player_hit and player.health == player.max_health - 1, "Shooter darts still damage Akedra through the existing player authority when no Boomer absorbs them.")
	root.queue_free()
	await get_tree().process_frame

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(320.0, 160.0))
	var normal := _spawn_enemy(root, EnemyScene, player, Vector2(160.0, 72.0))
	var shielded := _spawn_enemy(root, ShieldedScene, player, Vector2(160.0, 96.0)) as ShieldedEnemy
	var shooter := _spawn_enemy(root, ShooterScene, player, Vector2(160.0, 120.0)) as ShooterEnemy
	shooter.first_attack_delay_left = 99.0
	var prowler := _spawn_enemy(root, ProwlerScene, player, Vector2(160.0, 144.0)) as ProwlerEnemy
	for test_case in [
		{"enemy": normal, "start": Vector2(145.0, 72.0), "label": "Normal"},
		{"enemy": shielded, "start": Vector2(145.0, 96.0), "label": "Shielded"},
		{"enemy": shooter, "start": Vector2(145.0, 120.0), "label": "Shooter"},
		{"enemy": prowler, "start": Vector2(145.0, 144.0), "label": "Prowler"},
	]:
		var enemy := test_case["enemy"] as Enemy
		var test_dart := _spawn_dart(root, player, test_case["start"], Vector2.RIGHT)
		var cleared_enemy_body := await _advance_until(func() -> bool:
			return test_dart.global_position.x >= enemy.global_position.x + enemy.body_radius + 12.0 or not is_instance_valid(test_dart)
		, 0.25)
		_require(cleared_enemy_body and not enemy.is_dying, "Shooter darts do not damage or kill %s enemies." % String(test_case["label"]))
		_require(is_instance_valid(test_dart), "%s enemies do not consume Shooter darts in this checkpoint." % String(test_case["label"]))
		if is_instance_valid(test_dart):
			test_dart.destroy_projectile()
		await get_tree().process_frame
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


func _spawn_dart(root: Node, player: Player, start_position: Vector2, fire_direction: Vector2) -> DartProjectile:
	var dart := DartProjectileScene.instantiate() as DartProjectile
	root.add_child(dart)
	dart.global_position = start_position
	dart.setup(player, TEST_ARENA, fire_direction)
	return dart


func _advance_physics(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _advance_until(condition: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if bool(condition.call()):
			return true
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	return bool(condition.call())


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
