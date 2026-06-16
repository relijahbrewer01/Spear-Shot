extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	var main_scene := load("res://Main.tscn") as PackedScene
	_require(main_scene != null, "Main scene loads for encounter integration.")
	if main_scene == null:
		get_tree().quit(1)
		return

	await _audit_pacing_and_timer_contract(main_scene)
	await _audit_encounter_integration(main_scene)

	for failure in failures:
		push_error("ENCOUNTER INTEGRATION AUDIT: %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_pacing_and_timer_contract(main_scene: PackedScene) -> void:
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var director := main.get_node("EncounterDirector") as EncounterDirector
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	spawn_timer.stop()
	main.set_process(false)

	_assert_spawn_interval(main, 0.0, 2.20, "Spawn interval starts at 2.20 seconds.")
	_assert_spawn_interval(main, 30.0, 2.02, "Spawn interval is 2.02 seconds at 30 seconds.")
	_assert_spawn_interval(main, 60.0, 1.84, "Spawn interval is 1.84 seconds at 60 seconds.")
	_assert_spawn_interval(main, 90.0, 1.66, "Spawn interval is 1.66 seconds at 90 seconds.")
	_assert_spawn_interval(main, 120.0, 1.48, "Spawn interval is 1.48 seconds at 120 seconds.")
	_assert_spawn_interval(main, 180.0, 1.12, "Spawn interval is 1.12 seconds at 180 seconds.")
	_assert_spawn_interval(main, 240.0, 0.76, "Spawn interval is about 0.76 seconds at 240 seconds.")
	_assert_spawn_interval(main, 242.0, 0.75, "Spawn interval reaches the 0.75 second floor around 242 seconds.")

	main.set("survival_time", 241.0)
	_require(float(main.call("_get_next_spawn_interval")) > 0.75, "Minimum interval is not reached before about 242 seconds.")

	director.reset_for_new_run()
	main.set("survival_time", 14.9)
	_require(
		not _is_ambient_enemy_available(main, director, EncounterDirector.EnemyKind.CHARGER),
		"Charger is unavailable before 15 seconds."
	)
	main.set("survival_time", 15.0)
	_require(
		_is_ambient_enemy_available(main, director, EncounterDirector.EnemyKind.CHARGER),
		"Charger is eligible at 15 seconds."
	)
	main.set("survival_time", 25.0)
	_require(
		_is_ambient_enemy_available(main, director, EncounterDirector.EnemyKind.SHIELDED),
		"Shielded is eligible at 25 seconds."
	)
	main.set("survival_time", 24.9)
	_require(
		not _is_ambient_enemy_available(main, director, EncounterDirector.EnemyKind.SHIELDED),
		"Shielded is unavailable before 25 seconds."
	)

	main.set("survival_time", 15.0)
	_require(
		is_equal_approx(float(main.call("_get_current_charger_spawn_chance")), 0.08),
		"Charger spawn chance starts at 0.08 at unlock."
	)
	main.set("survival_time", 25.0)
	_require(
		is_equal_approx(float(main.call("_get_current_charger_spawn_chance")), 0.09),
		"Charger spawn chance grows by 0.001 per second after unlock."
	)
	main.set("survival_time", 1000.0)
	_require(
		is_equal_approx(float(main.call("_get_current_charger_spawn_chance")), 0.22),
		"Charger spawn chance caps at 0.22."
	)
	main.set("survival_time", 25.0)
	_require(
		is_equal_approx(float(main.call("_get_current_shielded_spawn_chance")), 0.05),
		"Shielded spawn chance starts at 0.05 at unlock."
	)
	main.set("survival_time", 35.0)
	_require(
		is_equal_approx(float(main.call("_get_current_shielded_spawn_chance")), 0.056),
		"Shielded spawn chance grows by 0.0006 per second after unlock."
	)
	main.set("survival_time", 1000.0)
	_require(
		is_equal_approx(float(main.call("_get_current_shielded_spawn_chance")), 0.12),
		"Shielded spawn chance caps at 0.12."
	)

	director.reset_for_new_run()
	var first_charger := Node.new()
	main.add_child(first_charger)
	director.register_enemy(
		first_charger,
		EncounterDirector.EnemyKind.CHARGER,
		EncounterDirector.INVALID_WAVE_ID
	)
	_require(
		not director.can_spawn_enemy(EncounterDirector.EnemyKind.CHARGER, 30.0),
		"First-minute Charger effective cap still limits active Chargers to one."
	)
	_require(
		director.can_spawn_enemy(EncounterDirector.EnemyKind.CHARGER, 61.0),
		"Charger cap allows a second active Charger after the first minute."
	)
	var second_charger := Node.new()
	main.add_child(second_charger)
	director.register_enemy(
		second_charger,
		EncounterDirector.EnemyKind.CHARGER,
		EncounterDirector.INVALID_WAVE_ID
	)
	_require(
		not director.can_spawn_enemy(EncounterDirector.EnemyKind.CHARGER, 61.0),
		"Charger active cap remains two."
	)

	director.reset_for_new_run()
	for _index in range(2):
		var shielded := Node.new()
		main.add_child(shielded)
		director.register_enemy(
			shielded,
			EncounterDirector.EnemyKind.SHIELDED,
			EncounterDirector.INVALID_WAVE_ID
		)
	_require(
		not director.can_spawn_enemy(EncounterDirector.EnemyKind.SHIELDED, 60.0),
		"Current Shielded active cap remains two."
	)

	main.set_process(true)
	main.set("survival_time", 10.0)
	main.call("_set_pause_state", true)
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(is_equal_approx(float(main.get("survival_time")), 10.0), "Pause stops survival-time progression.")

	main.call("_start_resume_countdown")
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(is_equal_approx(float(main.get("survival_time")), 10.0), "Resume countdown does not advance pacing.")
	main.call("_set_pause_state", false)

	main.set("survival_time", 22.0)
	main.call("_on_player_died")
	var final_time := float(main.get("survival_time"))
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(is_equal_approx(float(main.get("survival_time")), final_time), "Game over freezes the final timer.")

	main.call("_restart_run")
	_require(is_equal_approx(float(main.get("survival_time")), 0.0), "Restart resets pacing progression to zero.")
	_require(is_equal_approx(spawn_timer.wait_time, float(main.get("base_spawn_interval"))), "Restart returns ambient timer to the base interval.")

	get_tree().paused = false
	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _audit_encounter_integration(main_scene: PackedScene) -> void:
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.set_process(false)

	var director := main.get_node("EncounterDirector") as EncounterDirector
	var telegraph := main.get_node("EncounterTelegraph") as EncounterTelegraph
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	var enemy_container := main.get_node("EnemyContainer") as Node2D
	var warning_player := main.get_node("AudioPlayers/WaveWarningPlayer") as AudioStreamPlayer

	director.first_wave_time_min = 0.0
	director.first_wave_time_max = 0.0
	director.inter_wave_interval_min = 0.0
	director.inter_wave_interval_max = 0.0
	director.reset_for_new_run()
	main.set("survival_time", 30.0)
	spawn_timer.start(10.0)

	director.advance(0.01, 30.0)
	_require(telegraph.active, "Director signal displays the world-space telegraph.")
	_require(spawn_timer.is_stopped(), "Telegraph stops ambient spawning.")
	_require(
		warning_player.stream != null and warning_player.bus == &"SFX",
		"Telegraph warning has an assigned SFX stream."
	)
	_require(warning_player.playing, "Telegraph signal starts the warning sound.")

	director.advance(2.0, 32.0)
	for step in 8:
		director.advance(0.5, 32.5 + float(step) * 0.5)
	_require(enemy_container.get_child_count() == 4, "Main instantiates the complete Rush wave.")

	for enemy in enemy_container.get_children():
		enemy.queue_free()
	await get_tree().process_frame
	director.advance(0.01, 37.0)
	_require(
		director.current_state == EncounterDirector.EncounterState.WAVE_RECOVERY,
		"Tree exits release the active wave into recovery."
	)

	director.advance(3.1, 40.1)
	_require(not spawn_timer.is_stopped(), "Ambient spawning restarts after recovery.")
	_require(
		spawn_timer.time_left > 0.0
		and is_equal_approx(spawn_timer.wait_time, main.call("_get_next_spawn_interval")),
		"Ambient restarts with a fresh current-difficulty interval."
	)

	main.call("_reset_runtime_state")
	await get_tree().process_frame
	_require(enemy_container.get_child_count() == 0, "Restart clears encounter enemies.")
	_require(
		director.current_state == EncounterDirector.EncounterState.AMBIENT,
		"Restart resets the director to ambient state."
	)
	_require(not telegraph.active, "Restart clears any encounter telegraph.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _assert_spawn_interval(main: Node, survival_time: float, expected_interval: float, message: String) -> void:
	main.set("survival_time", survival_time)
	_require(is_equal_approx(float(main.call("_get_next_spawn_interval")), expected_interval), message)


func _is_ambient_enemy_available(main: Node, director: EncounterDirector, enemy_kind: int) -> bool:
	var current_survival_time := float(main.get("survival_time"))
	match enemy_kind:
		EncounterDirector.EnemyKind.CHARGER:
			return (
				current_survival_time >= float(main.get("charger_unlock_time"))
				and director.can_spawn_enemy(enemy_kind, current_survival_time)
			)
		EncounterDirector.EnemyKind.SHIELDED:
			return (
				current_survival_time >= float(main.get("shielded_unlock_time"))
				and director.can_spawn_enemy(enemy_kind, current_survival_time)
			)

	return director.can_spawn_enemy(enemy_kind, current_survival_time)


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
