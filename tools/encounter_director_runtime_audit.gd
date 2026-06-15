extends Node

var director: EncounterDirector
var arena: Arena
var spawned_enemies: Array[Node] = []
var spawned_enemy_ids: Array[int] = []
var spawned_enemy_kinds: Array[int] = []
var spawned_wave_ids: Array[int] = []
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
