extends Node

const MainScene := preload("res://Main.tscn")

var failures: Array[String] = []
var throw_count := 0
var thrown_physics_frame := -1
var dodge_end_physics_frame := -1


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	_stop_background_timers(main)

	var player := main.get_node("Player") as Player
	var spear := main.get_node("Spear") as Spear
	spear.thrown.connect(_on_spear_thrown)
	player.dodge_ended.connect(_on_dodge_ended)

	await _audit_latest_target_and_single_release(main, player, spear)
	await _audit_unavailable_spear_does_not_buffer(main, player, spear)
	await _audit_restart_and_game_over_clear(main, player, spear)
	await _audit_deactivation_clears(main, player, spear)
	await _audit_pause_preserves_buffer(main, player, spear)
	await _audit_forced_movement_and_ordinary_throw(main, player, spear)

	for failure in failures:
		push_error("PLAYER THROW BUFFER AUDIT: %s" % failure)
	print("Player throw buffer runtime audit passed." if failures.is_empty() else "Player throw buffer runtime audit failed.")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_latest_target_and_single_release(main: Node, player: Player, spear: Spear) -> void:
	await _reset_main(main)
	_reset_signal_counters()
	var first_target := player.global_position + Vector2(120.0, -20.0)
	var latest_target := player.global_position + Vector2(-110.0, 35.0)
	_require(player.try_start_dodge(Vector2.RIGHT), "Audit dodge starts for buffered throw coverage.")
	main.call("_handle_spear_throw_input", first_target)
	main.call("_handle_spear_throw_input", latest_target)

	_require(main.call("debug_has_buffered_spear_throw"), "Throw input during dodge creates one pending request.")
	_require(
		main.call("debug_get_buffered_spear_throw_target").is_equal_approx(latest_target),
		"Latest valid throw input replaces the earlier captured target."
	)
	_require(spear.is_held(), "Spear remains held throughout the active dodge.")
	_require(throw_count == 0, "Buffered input does not throw before dodge completion.")

	await _advance_physics(player.dodge_duration + 0.05)
	_require(throw_count == 1, "Exactly one throw releases after the dodge ends.")
	_require(spear.state == Spear.State.FLYING, "Buffered release uses the normal flying spear state.")
	_require(not main.call("debug_has_buffered_spear_throw"), "Release attempt consumes the buffer exactly once.")
	_require(
		thrown_physics_frame == dodge_end_physics_frame,
		"Buffered throw releases on the same first valid physics frame as dodge_ended."
	)
	var expected_direction := (latest_target - player.global_position).normalized()
	_require(
		spear.throw_direction.dot(expected_direction) >= 0.999,
		"Released throw uses the most recently captured target instead of tracking the mouse."
	)
	await _advance_physics(0.08)
	_require(throw_count == 1, "Multiple buffered presses cannot produce a second automatic throw.")


func _audit_unavailable_spear_does_not_buffer(main: Node, player: Player, spear: Spear) -> void:
	await _reset_main(main)
	_reset_signal_counters()
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 100.0), "Setup throw makes the spear unavailable.")
	_require(player.try_start_dodge(Vector2.UP), "Dodge starts while the spear is unavailable.")
	main.call("_handle_spear_throw_input", player.global_position + Vector2.DOWN * 80.0)
	_require(not main.call("debug_has_buffered_spear_throw"), "No buffer is created while the spear is not held.")


func _audit_restart_and_game_over_clear(main: Node, player: Player, spear: Spear) -> void:
	await _reset_main(main)
	_reset_signal_counters()
	_require(player.try_start_dodge(Vector2.RIGHT), "Restart-clear dodge starts.")
	main.call("_handle_spear_throw_input", player.global_position + Vector2.UP * 80.0)
	main.call("_restart_run")
	_stop_background_timers(main)
	_require(not main.call("debug_has_buffered_spear_throw"), "Restart clears the pending throw.")
	_require(spear.is_held() and throw_count == 0, "Restart cannot leak an automatic throw.")

	_require(player.try_start_dodge(Vector2.LEFT), "Game-over-clear dodge starts.")
	main.call("_handle_spear_throw_input", player.global_position + Vector2.DOWN * 80.0)
	main.call("_on_player_died")
	_require(not main.call("debug_has_buffered_spear_throw"), "Game over clears the pending throw.")
	_require(spear.is_held() and throw_count == 0, "Game over cannot release the buffered throw.")


func _audit_deactivation_clears(main: Node, player: Player, spear: Spear) -> void:
	await _reset_main(main)
	_reset_signal_counters()
	_require(player.try_start_dodge(Vector2.RIGHT), "Deactivation-clear dodge starts.")
	main.call("_handle_spear_throw_input", player.global_position + Vector2.UP * 90.0)
	player.set_active(false)
	_require(not main.call("debug_has_buffered_spear_throw"), "Player deactivation clears the pending throw.")
	_require(spear.is_held() and throw_count == 0, "Player deactivation cannot release a throw.")


func _audit_pause_preserves_buffer(main: Node, player: Player, spear: Spear) -> void:
	await _reset_main(main)
	_reset_signal_counters()
	_require(player.try_start_dodge(Vector2.RIGHT), "Pause coverage dodge starts.")
	main.call("_handle_spear_throw_input", player.global_position + Vector2.UP * 100.0)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	_require(main.call("debug_has_buffered_spear_throw"), "Pause preserves the buffered throw.")
	_require(spear.is_held() and throw_count == 0, "Pause cannot prematurely consume the buffer.")
	get_tree().paused = false
	await _advance_physics(player.dodge_duration + 0.05)
	_require(throw_count == 1, "Buffered throw releases only after the resumed dodge finishes.")


func _audit_forced_movement_and_ordinary_throw(main: Node, player: Player, spear: Spear) -> void:
	await _reset_main(main)
	_reset_signal_counters()
	_require(
		player.try_start_forced_movement(Vector2.RIGHT, 18.0, 0.18),
		"Forced movement starts for exclusion coverage."
	)
	main.call("_handle_spear_throw_input", player.global_position + Vector2.UP * 100.0)
	_require(not main.call("debug_has_buffered_spear_throw"), "Forced movement does not use the dodge-only buffer.")
	_require(throw_count == 1 and spear.state == Spear.State.FLYING, "Forced movement keeps ordinary immediate throwing behavior.")

	await _reset_main(main)
	_reset_signal_counters()
	main.call("_handle_spear_throw_input", player.global_position + Vector2.LEFT * 100.0)
	_require(throw_count == 1 and spear.state == Spear.State.FLYING, "Ordinary non-dodge throwing remains immediate and unchanged.")
	_require(not main.call("debug_has_buffered_spear_throw"), "Ordinary throwing does not create a pending request.")


func _reset_main(main: Node) -> void:
	get_tree().paused = false
	main.call("_restart_run")
	_stop_background_timers(main)
	await get_tree().physics_frame


func _stop_background_timers(main: Node) -> void:
	(main.get_node("SpawnTimer") as Timer).stop()
	(main.get_node("OpportunityTimer") as Timer).stop()


func _reset_signal_counters() -> void:
	throw_count = 0
	thrown_physics_frame = -1
	dodge_end_physics_frame = -1


func _on_spear_thrown() -> void:
	throw_count += 1
	thrown_physics_frame = Engine.get_physics_frames()


func _on_dodge_ended() -> void:
	dodge_end_physics_frame = Engine.get_physics_frames()


func _advance_physics(seconds: float) -> void:
	var frames := ceili(seconds * 60.0) + 2
	for _frame in range(frames):
		await get_tree().physics_frame


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
