extends Node

const PlayerScene := preload("res://Player.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ProwlerScene := preload("res://ProwlerEnemy.tscn")
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
	await _audit_stalking_and_state_transitions()
	await _audit_contact_damage_and_death()
	await _audit_main_integration_and_intro()
	await _audit_pause_restart_and_game_over_cleanup()

	for failure in failures:
		push_error("PROWLER RUNTIME AUDIT: %s" % failure)
	print("Prowler enemy runtime audit passed." if failures.is_empty() else "Prowler enemy runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_stalking_and_state_transitions() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(220.0, 108.0))
	var spear := _spawn_spear(root, player)
	var prowler := _spawn_prowler(root, player, spear, Vector2(80.0, 108.0))
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.STALK, "Prowler begins in STALK while the spear is held.")
	var far_start_x := prowler.global_position.x
	await _advance_physics(0.30)
	_require(prowler.global_position.x > far_start_x + 1.0, "Prowler approaches when Akedra is beyond the stalking band.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(154.0, 108.0))
	var close_start_x := prowler.global_position.x
	await _advance_physics(0.30)
	_require(prowler.global_position.x < close_start_x - 1.0, "Prowler withdraws when Akedra crowds inside the stalking band.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(112.0, 108.0))
	await _advance_physics(0.06)
	var committed_side := prowler.lateral_side
	var stalk_start := prowler.global_position
	var toward_player := (player.global_position - stalk_start).normalized()
	await _advance_physics(0.26)
	var stalk_displacement := prowler.global_position - stalk_start
	_require(stalk_displacement.length() > 2.0, "Prowler keeps moving inside the stalking band instead of freezing.")
	if stalk_displacement.length() > 0.0 and toward_player != Vector2.ZERO:
		_require(absf(stalk_displacement.normalized().dot(toward_player)) < 0.85, "Prowler stalking uses a shallow lateral track rather than pure direct chase.")
	_require(prowler.lateral_side == committed_side, "Prowler keeps one lateral choice committed during the stalking window.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(104.0, 64.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(24.0, 64.0))
	var wall_start := prowler.global_position
	await _advance_physics(0.45)
	_require(TEST_ARENA.has_point(prowler.global_position), "Wall fallback keeps Prowler inside the arena.")
	_require(prowler.global_position.distance_to(wall_start) > 1.0, "Wall fallback still produces readable movement instead of wall vibration.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(112.0, 108.0))
	var neighbor := _spawn_normal(root, player, Vector2(118.0, 108.0))
	var initial_spacing := prowler.global_position.distance_to(neighbor.global_position)
	await _advance_physics(0.35)
	var separated_spacing := prowler.global_position.distance_to(neighbor.global_position)
	_require(separated_spacing > initial_spacing + 1.0, "Prowler participates in the shared lightweight enemy separation.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(112.0, 108.0))
	_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Audit setup can throw the spear to trigger the unarmed transition.")
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.ALERT, "HELD -> FLYING enters the one-shot ALERT state.")
	await _advance_physics(0.04)
	var alert_time_after_tick := prowler.alert_time_left
	spear.call("_enter_landed_state", Vector2(248.0, 108.0))
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.ALERT, "FLYING -> LANDED keeps the Prowler on the same unarmed escalation path.")
	_require(prowler.alert_time_left <= alert_time_after_tick + 0.001, "Repeated unarmed spear states do not restart the alert timer.")
	var reached_hunt := await _advance_until(
		func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.HUNT,
		0.24,
		"prowler hunt transition"
	)
	_require(reached_hunt, "Prowler reaches HUNT after the single alert delay.")
	_require(spear.state == Spear.State.LANDED and prowler.prowler_state == ProwlerEnemy.ProwlerState.HUNT, "Landed but unrecovered spear still counts as unarmed hunting.")
	player.global_position = spear.global_position
	spear.call("_pickup")
	_require(spear.is_held(), "Audit recovery path returns the spear to HELD.")
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.STALK, "Legitimate spear recovery returns the Prowler to STALK immediately.")
	await _free_test_root(root)


func _audit_contact_damage_and_death() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(192.0, 108.0))
	var spear := _spawn_spear(root, player)
	var prowler := _spawn_prowler(root, player, spear, Vector2(179.0, 108.0))
	var starting_health := player.health
	await _advance_physics(0.12)
	_require(player.health == starting_health - 1, "Prowler body overlap uses the existing ordinary player damage path.")

	var kill_tracker := {
		"count": 0,
		"score": 0,
	}
	prowler.killed.connect(func(_enemy_position: Vector2, score_value: int) -> void:
		kill_tracker["count"] += 1
		kill_tracker["score"] = score_value
	)
	var response := prowler.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, prowler.global_position, Vector2.RIGHT)
	_require(response == Enemy.HitResponse.DAMAGED, "Prowler spear hit uses the ordinary DAMAGED response.")
	_require(prowler.is_dying, "One valid thrown-spear hit kills the Prowler.")
	_require(int(kill_tracker["count"]) == 1, "Prowler death emits exactly one killed signal.")
	_require(int(kill_tracker["score"]) == 2, "Prowler death awards exactly 2 score points.")
	await _free_test_root(root)


func _audit_main_integration_and_intro() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var director := main.get_node("EncounterDirector") as EncounterDirector
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	spawn_timer.stop()
	main.set_process(false)

	main.set("survival_time", 77.9)
	_require(
		not bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.PROWLER)),
		"Prowler is unavailable before its 78-second unlock."
	)
	main.set("survival_time", 78.0)
	_require(
		bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.PROWLER)),
		"Prowler becomes available at its 78-second unlock."
	)
	_require(is_equal_approx(float(main.call("_get_current_prowler_spawn_chance")), 0.03), "Prowler spawn chance starts at 0.03 at unlock.")
	main.set("survival_time", 88.0)
	_require(is_equal_approx(float(main.call("_get_current_prowler_spawn_chance")), 0.033), "Prowler spawn chance grows by 0.00030 per second after unlock.")
	main.set("survival_time", 1000.0)
	_require(is_equal_approx(float(main.call("_get_current_prowler_spawn_chance")), 0.08), "Prowler spawn chance caps at 0.08.")

	director.reset_for_new_run()
	main.set("survival_time", 90.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.TOP, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Prowler can be spawned through the ordinary ambient path."
	)
	_require(not director.can_spawn_enemy(EncounterDirector.EnemyKind.PROWLER, 90.0), "Prowler cap blocks a second active Prowler.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 79.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("boomer_intro_seen", true)
	main.set("prowler_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 88.0, 88.0)
	main.call("debug_set_ambient_roll_sequence", [0.0])
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.PROWLER,
		"Prowler can appear organically before its randomized target once it is unlocked and selected."
	)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.BOTTOM, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Early natural Prowler spawn succeeds in the audit setup."
	)
	_require(bool(main.get("prowler_intro_seen")), "Early organic Prowler cancels its future guarantee for the run.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 90.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("boomer_intro_seen", true)
	main.set("prowler_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 65.0, 78.0)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.PROWLER,
		"Overdue unseen Prowler intro is prioritized on the next valid ambient opportunity."
	)
	main.call("_debug_spawn_prowler_enemy")
	_require(not bool(main.get("prowler_intro_seen")), "Debug Prowler spawn does not mark the organic intro seen.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 90.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("boomer_intro_seen", true)
	main.set("prowler_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 65.0, 78.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.LEFT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Forced overdue Prowler intro can be fulfilled through the normal ambient spawn path."
	)
	_require(bool(main.get("prowler_intro_seen")), "Successful organic Prowler spawn marks the intro seen.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _audit_pause_restart_and_game_over_cleanup() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var spawn_timer := main.get_node("SpawnTimer") as Timer
	spawn_timer.stop()
	main.set_process(false)

	main.set("survival_time", 90.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Prowler can be spawned again for pause and cleanup coverage."
	)
	var prowler := _find_child_prowler(main)
	var spear := main.get_node("Spear") as Spear
	_require(prowler != null and spear != null, "Pause and cleanup audit can access the spawned Prowler and spear.")
	if prowler != null and spear != null:
		_require(spear.try_throw(Vector2(320.0, 108.0)), "Audit setup can throw the spear before testing pause and cleanup behavior.")
		_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.ALERT, "Thrown spear moves the live Prowler into ALERT before the pause test.")
		var paused_position := prowler.global_position
		var paused_alert_time := prowler.alert_time_left
		main.call("_set_pause_state", true)
		await get_tree().create_timer(0.12, true, false, true).timeout
		_require(prowler.global_position == paused_position, "Pause freezes Prowler movement.")
		_require(is_equal_approx(prowler.alert_time_left, paused_alert_time), "Pause freezes the Prowler alert timer.")
		main.call("_set_pause_state", false)

		main.call("_restart_run")
		await get_tree().process_frame
		_require(_find_child_prowler(main) == null, "Restart clears active Prowlers.")

		main.set_process(false)
		main.set("survival_time", 90.0)
		_require(
			bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.TOP, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
			"Prowler can be spawned again after restart for the game-over cleanup test."
		)
		prowler = _find_child_prowler(main)
		spear = main.get_node("Spear") as Spear
		if prowler != null and spear != null:
			_require(spear.try_throw(Vector2(320.0, 108.0)), "Audit setup can re-enter ALERT before game over cleanup.")
			main.call("_on_player_died")
			var game_over_position := prowler.global_position
			await get_tree().create_timer(0.16, true, false, true).timeout
			_require(not prowler.active, "Game over deactivates the Prowler.")
			_require(prowler.global_position == game_over_position, "Game over cleanup prevents stale Prowler movement.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


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


func _spawn_normal(parent: Node, player: Player, position: Vector2) -> Enemy:
	var enemy := EnemyScene.instantiate() as Enemy
	parent.add_child(enemy)
	enemy.setup(player, TEST_ARENA, 42.0)
	enemy.global_position = position
	return enemy


func _spawn_prowler(parent: Node, player: Player, spear: Spear, position: Vector2) -> ProwlerEnemy:
	var prowler := ProwlerScene.instantiate() as ProwlerEnemy
	parent.add_child(prowler)
	prowler.setup(player, TEST_ARENA, 42.0)
	prowler.set_tracked_spear(spear)
	prowler.global_position = position
	return prowler


func _find_child_prowler(main: Node) -> ProwlerEnemy:
	for child in main.get_node("EnemyContainer").get_children():
		if child is ProwlerEnemy:
			return child as ProwlerEnemy
	return null


func _ensure_input_actions() -> void:
	for action_name in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _advance_physics(duration: float) -> void:
	var frame_count := maxi(int(ceil(duration / (1.0 / 60.0))), 1)
	for _frame in frame_count:
		await get_tree().physics_frame


func _advance_until(predicate: Callable, timeout: float, label: String) -> bool:
	var elapsed := 0.0
	while elapsed <= timeout:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0

	push_warning("Prowler runtime audit timed out waiting for %s." % label)
	return false


func _free_test_root(root: Node) -> void:
	root.queue_free()
	await get_tree().process_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)
