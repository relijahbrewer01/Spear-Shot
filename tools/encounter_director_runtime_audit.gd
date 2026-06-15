extends Node

var director: EncounterDirector
var arena: Arena
var spawned_enemies: Array[Node] = []
var spawned_enemy_ids: Array[int] = []
var spawned_enemy_kinds: Array[int] = []
var spawned_wave_ids: Array[int] = []
var last_telegraph_wave_name := &""
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	director = EncounterDirector.new()
	arena = Arena.new()
	add_child(director)
	add_child(arena)
	await get_tree().process_frame

	director.first_wave_time_min = 0.0
	director.first_wave_time_max = 0.0
	director.inter_wave_interval_min = 0.0
	director.inter_wave_interval_max = 0.0
	director.spawn_requested.connect(_on_spawn_requested)
	director.telegraph_started.connect(_on_telegraph_started)
	director.reset_for_new_run()

	director.advance(0.01, 30.0)
	_require(
		director.current_state == EncounterDirector.EncounterState.WAVE_TELEGRAPH,
		"First eligible encounter enters telegraph state."
	)

	director.advance(2.0, 32.0)
	_require(
		director.current_state == EncounterDirector.EncounterState.WAVE_ACTIVE,
		"Telegraph advances into an active wave."
	)

	for step in 8:
		director.advance(0.5, 32.5 + float(step) * 0.5)

	_require(spawned_enemies.size() == 4, "Rush schedules four enemies.")
	_require(
		director.current_state == EncounterDirector.EncounterState.WAVE_ACTIVE,
		"Wave does not complete while tagged enemies remain alive."
	)

	var generation := director.get_run_generation()
	for enemy_id in spawned_enemy_ids:
		director.notify_enemy_removed(enemy_id, generation)
	for enemy in spawned_enemies:
		enemy.queue_free()
	await get_tree().process_frame

	director.advance(0.01, 37.0)
	_require(
		director.current_state == EncounterDirector.EncounterState.WAVE_RECOVERY,
		"Wave enters recovery after all tagged enemies are gone."
	)

	director.advance(3.1, 40.1)
	_require(
		director.current_state == EncounterDirector.EncounterState.AMBIENT,
		"Recovery returns to ambient play."
	)

	_clear_spawn_tracking()
	director.advance(0.01, 50.0)
	director.advance(2.0, 52.0)
	for step in 10:
		director.advance(0.5, 52.5 + float(step) * 0.5)
	_require(spawned_enemies.size() == 6, "Pincer schedules six enemies.")
	_require(
		spawned_wave_ids.all(func(wave_id: int) -> bool: return wave_id == 1),
		"Pincer uses the next unique wave ID."
	)
	_remove_tracked_enemies()
	await get_tree().process_frame
	director.advance(0.01, 58.0)
	director.advance(3.1, 61.1)

	_clear_spawn_tracking()
	director.advance(0.01, 70.0)
	director.advance(2.0, 72.0)
	for step in 8:
		director.advance(0.5, 72.5 + float(step) * 0.5)
	_require(spawned_enemies.size() == 3, "Charger Hunt schedules three enemies.")
	_require(
		spawned_enemy_kinds.count(EncounterDirector.EnemyKind.CHARGER) == 1,
		"Charger Hunt schedules exactly one Charger."
	)
	_require(
		spawned_wave_ids.all(func(wave_id: int) -> bool: return wave_id == 2),
		"Charger Hunt uses the next unique wave ID."
	)
	_remove_tracked_enemies()
	await get_tree().process_frame

	var impossible_position := arena.find_safe_spawn_position(
		Arena.SpawnEdge.TOP,
		[arena.get_play_rect().get_center()],
		[1000.0],
		8
	)
	_require(not impossible_position.is_finite(), "Unsafe spawn search returns no position.")
	await _audit_wave_specific_threshold_selection()

	for failure in failures:
		push_error("ENCOUNTER AUDIT: %s" % failure)
	if failures.is_empty():
		print("Encounter director runtime audit passed.")

	get_tree().quit(0 if failures.is_empty() else 1)


func _on_spawn_requested(
	request_id: int,
	enemy_kind: int,
	_spawn_edge: int,
	wave_id: int
) -> void:
	var enemy := Node.new()
	add_child(enemy)
	director.register_enemy(enemy, enemy_kind, wave_id)
	spawned_enemies.append(enemy)
	spawned_enemy_ids.append(enemy.get_instance_id())
	spawned_enemy_kinds.append(enemy_kind)
	spawned_wave_ids.append(wave_id)
	director.report_spawn_result(request_id, true)


func _on_telegraph_started(wave_name: StringName, _edges: Array[int], _duration: float) -> void:
	last_telegraph_wave_name = wave_name


func _audit_wave_specific_threshold_selection() -> void:
	_clear_spawn_tracking()
	await _reset_director_for_threshold_case(1, 3)
	director.advance(0.01, 50.0)
	_require(
		last_telegraph_wave_name == EncounterDirector.WAVE_PINCER,
		"Pincer starts when its preferred turn has three living hostiles."
	)

	await _reset_director_for_threshold_case(1, 4)
	director.advance(0.01, 50.0)
	_require(
		last_telegraph_wave_name == EncounterDirector.WAVE_RUSH,
		"Pincer is skipped at four hostiles and Rush can still start."
	)

	await _reset_director_for_threshold_case(2, 4)
	director.advance(0.01, 50.0)
	_require(
		last_telegraph_wave_name == EncounterDirector.WAVE_CHARGER_HUNT,
		"Charger Hunt starts when its preferred turn has four living hostiles."
	)

	await _reset_director_for_threshold_case(2, 5)
	director.advance(0.01, 50.0)
	_require(
		last_telegraph_wave_name == EncounterDirector.WAVE_RUSH,
		"Charger Hunt is skipped at five hostiles and Rush can still start."
	)


func _reset_director_for_threshold_case(completed_wave_count: int, living_hostile_count: int) -> void:
	for child in get_children():
		if child != director and child != arena:
			child.queue_free()
	await get_tree().process_frame
	director.reset_for_new_run()
	director.set("_completed_wave_count", completed_wave_count)
	last_telegraph_wave_name = &""

	for _index in range(living_hostile_count):
		var ambient_enemy := Node.new()
		add_child(ambient_enemy)
		director.register_enemy(
			ambient_enemy,
			EncounterDirector.EnemyKind.NORMAL,
			EncounterDirector.INVALID_WAVE_ID
		)


func _remove_tracked_enemies() -> void:
	var generation := director.get_run_generation()
	for enemy_id in spawned_enemy_ids:
		director.notify_enemy_removed(enemy_id, generation)
	for enemy in spawned_enemies:
		enemy.queue_free()


func _clear_spawn_tracking() -> void:
	spawned_enemies.clear()
	spawned_enemy_ids.clear()
	spawned_enemy_kinds.clear()
	spawned_wave_ids.clear()


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
