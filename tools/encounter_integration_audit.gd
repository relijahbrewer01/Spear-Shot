extends Node

const SPAWN_SOURCE_AMBIENT := 0
const SPAWN_SOURCE_WAVE := 1

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
	await _audit_randomized_intro_contract(main_scene)
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
	main.set("survival_time", 42.0)
	_require(
		_is_ambient_enemy_available(main, director, EncounterDirector.EnemyKind.SHOOTER),
		"Shooter is eligible at 42 seconds."
	)
	main.set("survival_time", 41.9)
	_require(
		not _is_ambient_enemy_available(main, director, EncounterDirector.EnemyKind.SHOOTER),
		"Shooter is unavailable before 42 seconds."
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
	main.set("survival_time", 42.0)
	_require(
		is_equal_approx(float(main.call("_get_current_shooter_spawn_chance")), 0.04),
		"Shooter spawn chance starts at 0.04 at unlock."
	)
	main.set("survival_time", 52.0)
	_require(
		is_equal_approx(float(main.call("_get_current_shooter_spawn_chance")), 0.0445),
		"Shooter spawn chance grows by 0.00045 per second after unlock."
	)
	main.set("survival_time", 1000.0)
	_require(
		is_equal_approx(float(main.call("_get_current_shooter_spawn_chance")), 0.10),
		"Shooter spawn chance caps at 0.10."
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
	director.reset_for_new_run()
	var shooter := Node.new()
	main.add_child(shooter)
	director.register_enemy(
		shooter,
		EncounterDirector.EnemyKind.SHOOTER,
		EncounterDirector.INVALID_WAVE_ID
	)
	_require(
		not director.can_spawn_enemy(EncounterDirector.EnemyKind.SHOOTER, 60.0),
		"Shooter active cap remains one."
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


func _audit_randomized_intro_contract(main_scene: PackedScene) -> void:
	await _audit_early_natural_intro_cancels_guarantee(main_scene)
	await _audit_pending_intro_forces_next_valid_ambient_attempt(main_scene)
	await _audit_intro_defers_through_waves(main_scene)
	await _audit_intro_defers_through_caps(main_scene)
	await _audit_intro_defers_after_safe_spawn_failure(main_scene)
	await _audit_debug_spawn_does_not_count_as_intro(main_scene)
	await _audit_overdue_intros_resolve_one_at_a_time(main_scene)
	await _audit_wave_spawn_counts_as_organic_intro(main_scene)
	await _audit_intro_restart_sequence(main_scene)


func _audit_early_natural_intro_cancels_guarantee(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)

	main.call("debug_set_intro_target_times", 21.0, 30.0)
	main.call("debug_set_ambient_roll_sequence", [0.0])
	main.set("survival_time", 16.0)
	var early_charger_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(
		early_charger_kind == EncounterDirector.EnemyKind.CHARGER,
		"Charger can appear randomly after unlock but before its target."
	)
	_require(
		_try_spawn_for_audit(main, early_charger_kind, SPAWN_SOURCE_AMBIENT),
		"Early random Charger can be spawned organically."
	)
	_require(bool(main.get("charger_intro_seen")), "Early organic Charger cancels its guarantee.")

	main.call("debug_set_ambient_roll_sequence", [0.99])
	main.set("survival_time", 22.0)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.NORMAL,
		"Seen Charger returns to ordinary weighted selection after its target."
	)

	await _free_intro_audit_main(main)

	main = await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_times", 15.0, 30.0)
	main.set("charger_intro_seen", true)
	main.call("debug_set_ambient_roll_sequence", [0.0])
	main.set("survival_time", 26.0)
	var early_shielded_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(
		early_shielded_kind == EncounterDirector.EnemyKind.SHIELDED,
		"Shielded can appear randomly after unlock but before its target."
	)
	_require(
		_try_spawn_for_audit(main, early_shielded_kind, SPAWN_SOURCE_AMBIENT),
		"Early random Shielded can be spawned organically."
	)
	_require(bool(main.get("shielded_intro_seen")), "Early organic Shielded cancels its guarantee.")

	main.call("debug_set_ambient_roll_sequence", [0.99])
	main.set("survival_time", 31.0)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.NORMAL,
		"Seen Shielded returns to ordinary weighted selection after its target."
	)

	await _free_intro_audit_main(main)


func _audit_pending_intro_forces_next_valid_ambient_attempt(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.call("debug_set_ambient_roll_sequence", [0.99])
	main.set("survival_time", 22.0)
	var pending_charger_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(
		pending_charger_kind == EncounterDirector.EnemyKind.CHARGER,
		"Pending Charger is forced on the next valid ambient attempt after its target."
	)
	_require(
		_try_spawn_for_audit(main, pending_charger_kind, SPAWN_SOURCE_AMBIENT),
		"Forced Charger intro successfully spawns."
	)
	_require(bool(main.get("charger_intro_seen")), "Successful forced Charger marks the intro seen.")
	await _free_intro_audit_main(main)

	main = await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.set("charger_intro_seen", true)
	main.call("debug_set_ambient_roll_sequence", [0.99])
	main.set("survival_time", 35.0)
	var pending_shielded_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(
		pending_shielded_kind == EncounterDirector.EnemyKind.SHIELDED,
		"Pending Shielded remains overdue after its nominal range and is forced later."
	)
	_require(
		_try_spawn_for_audit(main, pending_shielded_kind, SPAWN_SOURCE_AMBIENT),
		"Forced Shielded intro successfully spawns."
	)
	_require(bool(main.get("shielded_intro_seen")), "Successful forced Shielded marks the intro seen.")
	await _free_intro_audit_main(main)


func _audit_intro_defers_through_waves(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	var director := main.get_node("EncounterDirector") as EncounterDirector
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	var enemy_container := main.get_node("EnemyContainer") as Node2D

	director.first_wave_time_min = 0.0
	director.first_wave_time_max = 0.0
	director.inter_wave_interval_min = 0.0
	director.inter_wave_interval_max = 0.0
	director.reset_for_new_run()
	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.set("charger_intro_seen", true)
	main.set("survival_time", 30.0)
	spawn_timer.start(10.0)

	director.advance(0.01, 30.0)
	_require(spawn_timer.is_stopped(), "Wave telegraph blocks ambient intro attempts.")
	main.call("_on_spawn_timer_timeout")
	_require(not bool(main.get("shielded_intro_seen")), "Wave telegraph does not consume pending Shielded intro.")

	director.advance(2.0, 32.0)
	for step in 8:
		director.advance(0.5, 32.5 + float(step) * 0.5)
	_require(not bool(main.get("shielded_intro_seen")), "Active wave does not consume pending Shielded intro.")

	for enemy in enemy_container.get_children():
		enemy.queue_free()
	await get_tree().process_frame
	director.advance(0.01, 37.0)
	_require(not bool(main.get("shielded_intro_seen")), "Wave recovery does not consume pending Shielded intro.")

	director.advance(3.1, 40.1)
	main.call("debug_set_ambient_roll_sequence", [0.99])
	main.set("survival_time", 40.1)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.SHIELDED,
		"Pending Shielded intro retries when ambient spawning resumes."
	)
	await _free_intro_audit_main(main)


func _audit_intro_defers_through_caps(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	var director := main.get_node("EncounterDirector") as EncounterDirector
	var blocking_charger := Node.new()
	main.add_child(blocking_charger)
	director.register_enemy(
		blocking_charger,
		EncounterDirector.EnemyKind.CHARGER,
		EncounterDirector.INVALID_WAVE_ID
	)

	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.call("debug_set_ambient_roll_sequence", [0.99])
	main.set("survival_time", 30.0)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) != EncounterDirector.EnemyKind.CHARGER,
		"First-minute Charger cap defers pending Charger intro."
	)
	_require(not bool(main.get("charger_intro_seen")), "Cap-deferred Charger intro remains unseen.")

	director.reset_for_new_run()
	main.call("debug_set_ambient_roll_sequence", [0.99])
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.CHARGER,
		"Cap-deferred Charger intro retries once the cap clears."
	)
	await _free_intro_audit_main(main)


func _audit_intro_defers_after_safe_spawn_failure(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.set("survival_time", 22.0)
	main.set("spawn_safe_radius", 1000.0)

	var pending_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(pending_kind == EncounterDirector.EnemyKind.CHARGER, "Pending Charger is selected before a safe-spawn failure.")
	_require(
		not _try_spawn_for_audit(main, pending_kind, SPAWN_SOURCE_AMBIENT),
		"Failed safe-position search blocks the intro spawn."
	)
	_require(not bool(main.get("charger_intro_seen")), "Failed intro spawn does not mark Charger seen.")

	main.set("spawn_safe_radius", 72.0)
	main.call("debug_set_ambient_roll_sequence", [0.99])
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.CHARGER,
		"Safe-spawn failure leaves Charger intro pending for retry."
	)
	await _free_intro_audit_main(main)


func _audit_debug_spawn_does_not_count_as_intro(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.set("charger_intro_seen", true)
	main.set("survival_time", 30.0)
	main.call("_debug_spawn_shielded_enemy")
	_require(not bool(main.get("shielded_intro_seen")), "Debug Shielded spawn does not mark Shielded intro seen.")
	await _free_intro_audit_main(main)


func _audit_overdue_intros_resolve_one_at_a_time(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.call("debug_set_ambient_roll_sequence", [0.99, 0.99])
	main.set("survival_time", 61.0)

	var first_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(
		first_kind == EncounterDirector.EnemyKind.CHARGER,
		"Two overdue intros prefer the earlier target time first."
	)
	_require(_try_spawn_for_audit(main, first_kind, SPAWN_SOURCE_AMBIENT), "First overdue intro spawns one enemy.")

	var second_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(
		second_kind == EncounterDirector.EnemyKind.SHIELDED,
		"Second overdue intro remains pending for a later ambient opportunity."
	)
	_require(_try_spawn_for_audit(main, second_kind, SPAWN_SOURCE_AMBIENT), "Second overdue intro spawns later.")
	_require(
		bool(main.get("charger_intro_seen")) and bool(main.get("shielded_intro_seen")),
		"Both overdue intros are seen only after their own successful spawns."
	)
	await _free_intro_audit_main(main)


func _audit_wave_spawn_counts_as_organic_intro(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_times", 15.0, 25.0)
	main.set("survival_time", 50.0)
	_require(
		_try_spawn_for_audit(main, EncounterDirector.EnemyKind.CHARGER, SPAWN_SOURCE_WAVE),
		"Wave-source Charger spawn succeeds in the audit setup."
	)
	_require(bool(main.get("charger_intro_seen")), "Wave-source Charger counts as an organic intro.")
	await _free_intro_audit_main(main)


func _audit_intro_restart_sequence(main_scene: PackedScene) -> void:
	var main := await _spawn_main_for_intro_audit(main_scene)
	main.call("debug_set_intro_target_sequence", [Vector2(16.0, 26.0), Vector2(18.0, 28.0)])

	main.call("_restart_run")
	_require(
		is_equal_approx(float(main.get("charger_intro_target_time")), 16.0)
		and is_equal_approx(float(main.get("shielded_intro_target_time")), 26.0),
		"Restart can use deterministic intro targets for auditing."
	)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.call("_restart_run")
	_require(
		is_equal_approx(float(main.get("charger_intro_target_time")), 18.0)
		and is_equal_approx(float(main.get("shielded_intro_target_time")), 28.0),
		"Restart generates fresh intro targets."
	)
	_require(
		not bool(main.get("charger_intro_seen")) and not bool(main.get("shielded_intro_seen")),
		"Restart clears intro seen state."
	)
	await _free_intro_audit_main(main)


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
		EncounterDirector.EnemyKind.SHOOTER:
			return (
				current_survival_time >= float(main.get("shooter_unlock_time"))
				and director.can_spawn_enemy(enemy_kind, current_survival_time)
			)

	return director.can_spawn_enemy(enemy_kind, current_survival_time)


func _spawn_main_for_intro_audit(main_scene: PackedScene) -> Node:
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	spawn_timer.stop()
	return main


func _free_intro_audit_main(main: Node) -> void:
	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _try_spawn_for_audit(main: Node, enemy_kind: int, spawn_source: int) -> bool:
	return bool(main.call(
		"_try_spawn_enemy",
		enemy_kind,
		Arena.SpawnEdge.TOP,
		EncounterDirector.INVALID_WAVE_ID,
		spawn_source
	))


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
