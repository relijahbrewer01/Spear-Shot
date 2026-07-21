extends Node

const MainScene := preload("res://Main.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const BoomerScene := preload("res://BoomerEnemy.tscn")
const HeartRunnerScene := preload("res://HeartRunner.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	_stop_background_timers(main)

	await _audit_direct_throw_counts(main)
	await _audit_excluded_cases(main)
	await _audit_lifecycle_and_hud_timing(main)

	for failure in failures:
		push_error("MULTIKILL FEEDBACK RUNTIME AUDIT: %s" % failure)
	print("Multikill feedback runtime audit passed." if failures.is_empty() else "Multikill feedback runtime audit failed.")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_direct_throw_counts(main: Node) -> void:
	await _reset_main(main)
	var score_before: int = main.score
	var one_enemy := _spawn_registered_enemy(main, EnemyScene, Vector2(270.0, 108.0))
	var spear := main.get_node("Spear") as Spear
	var player := main.get_node("Player") as Player
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "One-kill setup begins a valid spear flight.")
	_require(spear.call("_hit_enemy_if_needed", one_enemy) == Enemy.HitResponse.DAMAGED, "Direct spear hit kills an ordinary hostile.")
	spear.call("_enter_landed_state", Vector2(320.0, 108.0))
	_require(main.score == score_before + one_enemy.score_value, "One direct Normal kill keeps its ordinary base score.")
	_require(not _multikill_label(main).visible, "One direct kill shows no multikill message.")

	for case_data in [
		{"count": 0, "message": ""},
		{"count": 2, "message": "DOUBLE"},
		{"count": 3, "message": "TRIPLE"},
		{"count": 4, "message": "QUAD"},
		{"count": 5, "message": "QUAD"},
	]:
		await _reset_main(main)
		var count: int = case_data["count"]
		var expected_message: String = case_data["message"]
		var initial_score: int = main.score
		var total_score := 0
		var enemies: Array[Enemy] = []
		for index in count:
			var enemy := _spawn_registered_enemy(main, EnemyScene, Vector2(256.0 + index * 12.0, 108.0))
			enemies.append(enemy)
			total_score += enemy.score_value
		spear = main.get_node("Spear") as Spear
		player = main.get_node("Player") as Player
		_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "%d-kill setup begins one valid throw." % count)
		for enemy in enemies:
			spear.call("_hit_enemy_if_needed", enemy)
		spear.call("_enter_landed_state", Vector2(320.0, 108.0))
		var label := _multikill_label(main)
		_require(main.score == initial_score + total_score, "%d direct kills preserve the exact sum of base scores." % count)
		_require(label.visible == (count >= 2), "%d direct kills use the expected feedback visibility threshold." % count)
		if count >= 2:
			_require(label.text == expected_message, "%d direct kills resolve to %s exactly once." % [count, expected_message])

	await _reset_main(main)
	spear = main.get_node("Spear") as Spear
	player = main.get_node("Player") as Player
	var duplicate_enemy := _spawn_registered_enemy(main, EnemyScene, Vector2(264.0, 108.0))
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "Duplicate-registration setup begins a valid throw.")
	spear.call("_hit_enemy_if_needed", duplicate_enemy)
	spear.call("_hit_enemy_if_needed", duplicate_enemy)
	_require(main.active_spear_throw_kill_ids.size() == 1, "The same enemy cannot register twice in one throw context.")
	spear.call("_enter_landed_state", Vector2(320.0, 108.0))


func _audit_excluded_cases(main: Node) -> void:
	await _reset_main(main)
	var spear := main.get_node("Spear") as Spear
	var player := main.get_node("Player") as Player
	var shielded := _spawn_registered_enemy(main, ShieldedScene, Vector2(264.0, 108.0)) as ShieldedEnemy
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "Shield-break exclusion setup begins a valid throw.")
	_require(spear.call("_hit_enemy_if_needed", shielded) == Enemy.HitResponse.STOPPED, "Intact Shielded returns its ordinary STOPPED result.")
	_require(main.active_spear_throw_id == 0 and not _multikill_label(main).visible, "Shield break resolves no eligible direct kill.")

	await _reset_main(main)
	spear = main.get_node("Spear") as Spear
	player = main.get_node("Player") as Player
	shielded = _spawn_registered_enemy(main, ShieldedScene, Vector2(264.0, 108.0)) as ShieldedEnemy
	shielded.call("_break_shield", Enemy.HIT_SOURCE_SPEAR, shielded.global_position, Vector2.RIGHT)
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "Exposed Shielded setup begins a valid throw.")
	spear.call("_hit_enemy_if_needed", shielded)
	_require(main.active_spear_throw_kill_ids.size() == 1, "An exposed Shielded direct spear death is eligible exactly once.")
	spear.call("_enter_landed_state", Vector2(320.0, 108.0))

	await _reset_main(main)
	spear = main.get_node("Spear") as Spear
	player = main.get_node("Player") as Player
	var safe_boomer := _spawn_registered_enemy(main, BoomerScene, Vector2(264.0, 108.0)) as BoomerEnemy
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "Safe Boomer setup begins a valid throw.")
	spear.call("_hit_enemy_if_needed", safe_boomer)
	_require(main.active_spear_throw_kill_ids.size() == 1, "Unfused Boomer safe spear death is an eligible direct kill.")
	spear.call("_enter_landed_state", Vector2(320.0, 108.0))

	await _reset_main(main)
	spear = main.get_node("Spear") as Spear
	player = main.get_node("Player") as Player
	var fusing_boomer := _spawn_registered_enemy(main, BoomerScene, Vector2(264.0, 108.0)) as BoomerEnemy
	fusing_boomer.call("_enter_fuse_state")
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "Fusing Boomer exclusion setup begins a valid throw.")
	spear.call("_hit_enemy_if_needed", fusing_boomer)
	_require(main.active_spear_throw_kill_ids.is_empty(), "Spear-triggered fusing Boomer detonation is not a direct kill.")
	spear.call("_enter_landed_state", Vector2(320.0, 108.0))

	await _reset_main(main)
	spear = main.get_node("Spear") as Spear
	player = main.get_node("Player") as Player
	var runner := HeartRunnerScene.instantiate() as HeartRunner
	main.get_node("OpportunityContainer").add_child(runner)
	runner.setup(
		(main.get_node("Arena") as Arena).get_play_rect(),
		Vector2(264.0, 108.0),
		Arena.SpawnEdge.LEFT,
		70.0,
		player,
		spear,
		true
	)
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 140.0), "Heart Runner exclusion setup begins a valid throw.")
	spear.call("_hit_enemy_if_needed", runner)
	_require(main.active_spear_throw_kill_ids.is_empty(), "Heart Runner defeat is not eligible hostile multikill credit.")
	spear.call("_enter_landed_state", Vector2(320.0, 108.0))


func _audit_lifecycle_and_hud_timing(main: Node) -> void:
	await _reset_main(main)
	main.call("_on_spear_throw_context_started", 700)
	main.call("_on_spear_direct_hostile_killed", 700, 1)
	main.call("_on_spear_direct_hostile_killed", 700, 2)
	main.call("_on_spear_throw_context_resolved", 700)
	var hud := main.get_node("HUD") as HUD
	var label := _multikill_label(main)
	_require(label.visible and label.text == "DOUBLE", "Manual context resolution displays one transient HUD message.")
	var paused_time := hud.multikill_feedback_time_left
	get_tree().paused = true
	await get_tree().create_timer(0.10, true, false, true).timeout
	_require(is_equal_approx(hud.multikill_feedback_time_left, paused_time), "Pause freezes multikill feedback lifetime.")
	get_tree().paused = false
	await get_tree().create_timer(hud.multikill_feedback_duration + 0.10).timeout
	_require(not label.visible, "Multikill feedback clears after its presentation lifetime.")

	main.call("_on_spear_throw_context_started", 701)
	main.call("_on_spear_direct_hostile_killed", 701, 3)
	main.call("_on_spear_direct_hostile_killed", 701, 4)
	main.call("_restart_run")
	_stop_background_timers(main)
	_require(main.active_spear_throw_id == 0 and not _multikill_label(main).visible, "Restart during a pending throw clears attribution and feedback.")

	var spear := main.get_node("Spear") as Spear
	var player := main.get_node("Player") as Player
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 120.0), "Player-death cleanup setup begins a valid throw.")
	main.call("_on_player_died")
	_require(main.active_spear_throw_id == 0 and not _multikill_label(main).visible, "Player death during flight clears pending attribution and feedback.")


func _spawn_registered_enemy(main: Node, scene: PackedScene, position: Vector2) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	var player := main.get_node("Player") as Player
	var arena := main.get_node("Arena") as Arena
	var director := main.get_node("EncounterDirector") as EncounterDirector
	enemy.setup(player, arena.get_play_rect(), main.base_enemy_speed)
	enemy.global_position = position
	var enemy_id := enemy.get_instance_id()
	var generation := director.get_run_generation()
	enemy.killed.connect(main._on_enemy_killed.bind(enemy_id, generation))
	enemy.tree_exited.connect(main._on_enemy_tree_exited.bind(enemy_id, generation))
	main.get_node("EnemyContainer").add_child(enemy)
	director.register_enemy(enemy, EncounterDirector.EnemyKind.NORMAL, EncounterDirector.INVALID_WAVE_ID)
	return enemy


func _multikill_label(main: Node) -> Label:
	return main.get_node("HUD/MultikillLabel") as Label


func _reset_main(main: Node) -> void:
	get_tree().paused = false
	main.call("_restart_run")
	_stop_background_timers(main)
	await get_tree().process_frame


func _stop_background_timers(main: Node) -> void:
	(main.get_node("SpawnTimer") as Timer).stop()
	(main.get_node("OpportunityTimer") as Timer).stop()


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
