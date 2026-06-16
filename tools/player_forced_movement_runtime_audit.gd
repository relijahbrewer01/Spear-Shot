extends Node

const PlayerScene := preload("res://Player.tscn")
const MainScene := preload("res://Main.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_distance_and_duration()
	await _audit_intent_preservation_and_dodge_cancellation()
	await _audit_pause_and_clear_behavior()

	for failure in failures:
		push_error("PLAYER FORCED MOVEMENT AUDIT: %s" % failure)
	print("Player forced movement runtime audit passed." if failures.is_empty() else "Player forced movement runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_distance_and_duration() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(120.0, 108.0))
	var start_position := player.global_position

	_require(
		player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts from authored direction, distance, and duration."
	)
	_require(player.is_in_forced_movement(), "Player enters the forced-movement state.")

	await _advance_physics(0.09)
	var halfway_distance := player.global_position.distance_to(start_position)
	_require(halfway_distance >= 10.0 and halfway_distance <= 16.0, "Forced movement advances partway through its authored travel.")

	await _advance_physics(0.12)
	var full_distance := player.global_position.distance_to(start_position)
	_require(not player.is_in_forced_movement(), "Forced movement ends naturally after its authored duration.")
	_require(full_distance >= 24.0 and full_distance <= 28.0, "Forced movement follows the authored travel distance.")
	_require(player.velocity.length_squared() <= 0.01, "No stale forced velocity remains after natural completion.")

	root.queue_free()
	await get_tree().process_frame


func _audit_intent_preservation_and_dodge_cancellation() -> void:
	var root := Node2D.new()
	add_child(root)

	var resume_player := _spawn_player(root, Vector2(80.0, 108.0))
	resume_player.set_move_destination(Vector2(170.0, 108.0))
	var resume_start := resume_player.global_position
	_require(
		resume_player.try_start_forced_movement(Vector2.UP, 26.0, 0.18),
		"Forced movement can start while a click destination is active."
	)
	await _advance_physics(0.06)
	_require(resume_player.is_in_forced_movement(), "Ordinary movement does not cancel forced movement immediately.")
	_require(resume_player.global_position.y < resume_start.y - 4.0, "Forced movement follows its authored direction while active.")
	await _advance_physics(0.18)
	var x_after_forced := resume_player.global_position.x
	await _advance_physics(0.12)
	_require(resume_player.global_position.x > x_after_forced + 2.0, "Active click destination resumes automatically after forced movement ends.")

	var space_player := _spawn_player(root, Vector2(140.0, 108.0))
	space_player.set_move_destination(Vector2(140.0, 60.0))
	_require(
		space_player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts before the Space-dodge direction test."
	)
	_require(
		space_player.try_start_movement_dodge(space_player.get_space_dodge_direction()),
		"Space dodge can cancel forced movement when the dodge is available."
	)
	_require(space_player.is_dodging(), "Space dodge takes control after cancelling forced movement.")
	_require(space_player.dodge_direction.distance_to(Vector2.UP) < 0.001, "Space dodge uses click intent instead of current knockback velocity.")

	var buffered_player := _spawn_player(root, Vector2(190.0, 108.0))
	buffered_player.buffer_post_dodge_destination(Vector2(190.0, 60.0))
	_require(
		buffered_player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts before the buffered-destination direction test."
	)
	_require(
		buffered_player.get_space_dodge_direction().distance_to(Vector2.UP) < 0.001,
		"Buffered click destination survives forced movement and is used before aim fallback."
	)

	var shift_player := _spawn_player(root, Vector2(240.0, 108.0))
	_require(
		shift_player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts before the Shift-dodge cancellation test."
	)
	_require(
		shift_player.try_start_aim_dodge(Vector2.LEFT),
		"Shift dodge can cancel forced movement when available."
	)
	_require(shift_player.is_dodging(), "Shift dodge takes control after cancelling forced movement.")
	_require(shift_player.dodge_direction.distance_to(Vector2.LEFT) < 0.001, "Shift dodge preserves its authored aim direction when cancelling forced movement.")

	root.queue_free()
	await get_tree().process_frame


func _audit_pause_and_clear_behavior() -> void:
	var root := Node2D.new()
	add_child(root)
	var pause_player := _spawn_player(root, Vector2(120.0, 108.0))
	_require(
		pause_player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts before the pause test."
	)
	var paused_position := pause_player.global_position
	get_tree().paused = true
	await get_tree().create_timer(0.12, true, false, true).timeout
	_require(pause_player.global_position == paused_position, "Pause freezes active forced movement.")
	get_tree().paused = false
	await _advance_physics(0.12)
	_require(pause_player.global_position.x > paused_position.x, "Forced movement resumes after pause.")

	var death_player := _spawn_player(root, Vector2(180.0, 108.0))
	death_player.health = 1
	_require(
		death_player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts before the death-clear test."
	)
	death_player.take_damage(Vector2.ZERO)
	_require(not death_player.is_in_forced_movement(), "Death clears forced movement immediately.")
	_require(death_player.velocity.length_squared() <= 0.01, "Death clears any stale forced velocity.")

	root.queue_free()
	await get_tree().process_frame

	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	var main_player := main.get_node("Player") as Player
	_require(
		main_player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts before the restart-clear test."
	)
	main.call("_restart_run")
	_require(not main_player.is_in_forced_movement(), "Restart clears forced movement state.")
	_require(main_player.velocity.length_squared() <= 0.01, "Restart clears forced velocity.")

	_require(
		main_player.try_start_forced_movement(Vector2.RIGHT, 26.0, 0.18),
		"Forced movement starts before the game-over clear test."
	)
	main.call("_on_player_died")
	_require(not main_player.is_in_forced_movement(), "Game over clears forced movement state.")
	_require(main_player.velocity.length_squared() <= 0.01, "Game over clears forced velocity.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(TEST_ARENA)
	player.reset_for_new_run(position, TEST_ARENA)
	return player


func _advance_physics(duration: float) -> void:
	var frames := int(ceil(duration * 60.0))
	for _index in range(maxi(frames, 1)):
		await get_tree().physics_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
