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

	for failure in failures:
		push_error("ENCOUNTER INTEGRATION AUDIT: %s" % failure)
	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
