extends Node

const REPORT_PATH := "C:/Users/Elijah/Documents/Spear Shot/tools/bugfix_audit_report.txt"

var report_lines: Array[String] = []
var spawn_timeout_count := 0
var spawned_enemy_events: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_project()
	_write_report()
	get_tree().quit()


func _audit_project() -> void:
	_audit_project_audio_layout_path()

	var main_scene := load("res://Main.tscn") as PackedScene
	if main_scene == null:
		report_lines.append("FAILED main_scene_load")
		return

	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout

	var spawn_timer := main.get_node_or_null("SpawnTimer") as Timer
	var enemy_container := main.get_node_or_null("EnemyContainer") as Node2D
	var hud := main.get_node_or_null("HUD")
	var play_rect := Rect2()
	if main.has_node("Arena"):
		var arena = main.get_node("Arena")
		if arena.has_method("get_play_rect"):
			play_rect = arena.call("get_play_rect")

	report_lines.append("spawn_timer_exists=%s" % (spawn_timer != null))
	report_lines.append("enemy_container_exists=%s" % (enemy_container != null))
	report_lines.append("hud_exists=%s" % (hud != null))

	if spawn_timer == null or enemy_container == null:
		return

	spawn_timer.timeout.connect(_on_audit_spawn_timeout)
	enemy_container.child_entered_tree.connect(_on_enemy_child_entered_tree)

	report_lines.append("spawn_timer_wait_time=%s" % spawn_timer.wait_time)
	report_lines.append("spawn_timer_one_shot=%s" % spawn_timer.one_shot)
	report_lines.append("spawn_timer_autostart=%s" % spawn_timer.autostart)
	report_lines.append("spawn_timer_is_stopped_initial=%s" % spawn_timer.is_stopped())
	report_lines.append("spawn_timer_time_left_initial=%s" % spawn_timer.time_left)
	report_lines.append(
		"spawn_timer_connected_to_main=%s" % spawn_timer.timeout.is_connected(
			Callable(main, "_on_spawn_timer_timeout")
		)
	)

	_audit_hud_mouse_filters(hud)
	_audit_enemy_scene_instantiation(play_rect)

	await get_tree().create_timer(2.6).timeout
	report_lines.append("spawn_timeout_count_after_2_6s=%s" % spawn_timeout_count)
	report_lines.append("enemy_count_after_2_6s=%s" % enemy_container.get_child_count())
	_record_enemy_positions(enemy_container, play_rect, "after_2_6s")

	await get_tree().create_timer(2.6).timeout
	report_lines.append("spawn_timeout_count_after_5_2s=%s" % spawn_timeout_count)
	report_lines.append("enemy_count_after_5_2s=%s" % enemy_container.get_child_count())
	_record_enemy_positions(enemy_container, play_rect, "after_5_2s")

	var before_manual_spawn := enemy_container.get_child_count()
	main.call("_on_spawn_timer_timeout")
	await get_tree().process_frame
	report_lines.append("enemy_count_before_manual_spawn=%s" % before_manual_spawn)
	report_lines.append("enemy_count_after_manual_spawn=%s" % enemy_container.get_child_count())
	_record_enemy_positions(enemy_container, play_rect, "after_manual_spawn")

	for event_line in spawned_enemy_events:
		report_lines.append(event_line)

	main.queue_free()


func _audit_project_audio_layout_path() -> void:
	var layout_path = ProjectSettings.get_setting("audio/buses/default_bus_layout", "")
	report_lines.append("audio_bus_layout_setting=%s" % String(layout_path))


func _audit_hud_mouse_filters(hud: Node) -> void:
	if hud == null:
		report_lines.append("FAILED hud_missing_for_mouse_audit")
		return

	for node_path in [
		"TimeLabel",
		"ScoreLabel",
		"PauseBackdrop",
		"PauseLabel",
		"GameOverBackdrop",
		"GameOverPanel",
		"GameOverPanel/RestartButton",
	]:
		var control := hud.get_node_or_null(node_path) as Control
		if control == null:
			report_lines.append("FAILED hud_node_missing=%s" % node_path)
			continue

		report_lines.append(
			"hud_mouse_filter %s=%s focus_mode=%s" % [
				node_path,
				control.mouse_filter,
				control.focus_mode,
			]
		)


func _audit_enemy_scene_instantiation(play_rect: Rect2) -> void:
	for scene_path in ["res://Enemy.tscn", "res://Charger.tscn"]:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			report_lines.append("FAILED enemy_scene_load=%s" % scene_path)
			continue

		var instance := scene.instantiate()
		report_lines.append("scene_instantiated=%s node=%s" % [scene_path, instance.name])
		instance.queue_free()

	report_lines.append("play_rect=%s" % play_rect)


func _record_enemy_positions(enemy_container: Node2D, play_rect: Rect2, label: String) -> void:
	var enemy_positions: Array[String] = []
	for child in enemy_container.get_children():
		var enemy := child as Node2D
		if enemy == null:
			continue
		enemy_positions.append(
			"%s pos=%s inside_play_rect=%s" % [
				enemy.name,
				enemy.global_position,
				play_rect.has_point(enemy.global_position),
			]
		)

	report_lines.append("%s_positions=%s" % [label, " | ".join(enemy_positions)])


func _on_audit_spawn_timeout() -> void:
	spawn_timeout_count += 1


func _on_enemy_child_entered_tree(node: Node) -> void:
	var node_2d := node as Node2D
	if node_2d == null:
		spawned_enemy_events.append("enemy_child_entered_tree=%s" % node.name)
		return

	spawned_enemy_events.append(
		"enemy_child_entered_tree=%s pos=%s visible=%s" % [
			node.name,
			node_2d.global_position,
			node_2d.visible,
		]
	)


func _write_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return

	for line in report_lines:
		file.store_line(line)
