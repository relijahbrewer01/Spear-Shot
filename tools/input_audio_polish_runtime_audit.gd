extends Node

const MainScene := preload("res://Main.tscn")
const ACTION_THROW := &"throw"
const ACTION_DODGE := &"dodge"
const ACTION_HURT := &"hurt"
const TRACK_01 := "res://music/quiet_hunter_loop.wav"
const TRACK_02 := "res://music/quiet_hunter_loop_02.wav"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	_stop_background_timers(main)

	_audit_initial_music(main)
	_audit_audio_pools_and_non_repetition(main)
	_audit_audio_rng_isolation(main)
	await _audit_player_sound_lifecycle(main)
	await _audit_music_cycling(main)

	for failure in failures:
		push_error("INPUT AUDIO POLISH AUDIT: %s" % failure)
	print("Input/audio polish runtime audit passed." if failures.is_empty() else "Input/audio polish runtime audit failed.")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_initial_music(main: Node) -> void:
	_require(main.call("debug_get_current_music_track_index") == 0, "Application startup selects track 1 without advancing twice.")
	_require(main.call("debug_get_current_music_stream_path") == TRACK_01, "Application startup uses the original music loop.")


func _audit_audio_pools_and_non_repetition(main: Node) -> void:
	for action_category in [ACTION_THROW, ACTION_DODGE, ACTION_HURT]:
		_require(
			main.call("debug_get_player_action_sfx_pool_size", action_category) == 3,
			"%s action pool contains the original plus two alternates." % action_category
		)

	main.call("debug_seed_audio_rng", 44101)
	for action_category in [ACTION_THROW, ACTION_DODGE, ACTION_HURT]:
		var previous_index := -1
		for _selection in range(40):
			var selected_index: int = main.call(
				"debug_select_player_action_sfx_index",
				action_category
			)
			_require(selected_index >= 0 and selected_index < 3, "%s selection stays inside its pool." % action_category)
			_require(selected_index != previous_index, "%s selection never immediately repeats." % action_category)
			previous_index = selected_index

	main.call("debug_seed_audio_rng", 44102)
	main.call("debug_select_player_action_sfx_index", ACTION_THROW)
	_require(
		main.call("debug_get_last_player_action_sfx_index", ACTION_DODGE) == -1
		and main.call("debug_get_last_player_action_sfx_index", ACTION_HURT) == -1,
		"Throw selection does not alter dodge or hurt repetition history."
	)
	main.call("debug_select_player_action_sfx_index", ACTION_DODGE)
	_require(
		main.call("debug_get_last_player_action_sfx_index", ACTION_HURT) == -1,
		"Dodge selection does not alter hurt repetition history."
	)


func _audit_audio_rng_isolation(main: Node) -> void:
	main.rng.seed = 55201
	var expected_gameplay_roll := main.rng.randi()
	main.rng.seed = 55201
	main.call("debug_seed_audio_rng", 55202)
	for _selection in range(24):
		main.call("debug_select_player_action_sfx_index", ACTION_THROW)
		main.call("debug_select_player_action_sfx_index", ACTION_DODGE)
		main.call("debug_select_player_action_sfx_index", ACTION_HURT)
	var actual_gameplay_roll := main.rng.randi()
	_require(
		actual_gameplay_roll == expected_gameplay_roll,
		"Player-action audio selection does not consume gameplay RNG state."
	)


func _audit_player_sound_lifecycle(main: Node) -> void:
	var throw_player := main.get_node("AudioPlayers/ThrowPlayer") as AudioStreamPlayer
	var dodge_player := main.get_node("AudioPlayers/DodgePlayer") as AudioStreamPlayer
	var hurt_player := main.get_node("AudioPlayers/PlayerHurtPlayer") as AudioStreamPlayer

	main.call("_play_player_action_sfx", ACTION_THROW)
	main.call("_play_player_action_sfx", ACTION_DODGE)
	main.call("_play_player_action_sfx", ACTION_HURT)
	main.call("_restart_run")
	_stop_background_timers(main)
	_require(
		not throw_player.playing and not dodge_player.playing and not hurt_player.playing,
		"Restart stops all player-action sounds without leaving overlap."
	)

	main.call("_play_player_action_sfx", ACTION_THROW)
	main.call("_play_player_action_sfx", ACTION_DODGE)
	main.call("_play_player_action_sfx", ACTION_HURT)
	main.call("_on_player_died")
	_require(
		not throw_player.playing and not dodge_player.playing and not hurt_player.playing,
		"Game over stops all player-action sounds without leaving overlap."
	)
	await get_tree().process_frame


func _audit_music_cycling(main: Node) -> void:
	main.call("_restart_run")
	_stop_background_timers(main)
	main.call("_restart_run")
	_stop_background_timers(main)
	_require(main.call("debug_get_current_music_track_index") == 1, "Audit setup returns music to track 2 deterministically.")
	main.call("_restart_run")
	_stop_background_timers(main)
	_require(main.call("debug_get_current_music_track_index") == 0, "Run cycling returns to track 1 after track 2.")
	_require(main.call("debug_get_current_music_stream_path") == TRACK_01, "Track 1 uses the original loop path.")

	var music_player := main.get_node("AudioPlayers/MusicPlayer") as AudioStreamPlayer
	var audio_players := main.get_node("AudioPlayers")
	var music_player_count := 0
	for child in audio_players.get_children():
		if child.name == &"MusicPlayer":
			music_player_count += 1
	_require(music_player_count == 1, "Cycling uses exactly one MusicPlayer.")
	_require(music_player.playing, "Initial/current run music is playing.")

	var paused_index: int = main.call("debug_get_current_music_track_index")
	var paused_path: String = main.call("debug_get_current_music_stream_path")
	get_tree().paused = true
	await get_tree().process_frame
	get_tree().paused = false
	_require(
		main.call("debug_get_current_music_track_index") == paused_index
		and main.call("debug_get_current_music_stream_path") == paused_path,
		"Pause and resume leave the selected track unchanged."
	)

	main.call("_on_player_died")
	_require(
		main.call("debug_get_current_music_track_index") == paused_index,
		"Game over does not advance music selection."
	)

	main.call("_restart_run")
	_stop_background_timers(main)
	_require(main.call("debug_get_current_music_track_index") == 1, "First next run selects track 2.")
	_require(main.call("debug_get_current_music_stream_path") == TRACK_02, "Track 2 uses the new sibling loop path.")
	_require(music_player.playing and music_player.get_playback_position() < 0.15, "Restart begins track 2 from its beginning.")
	main.call("_restart_run")
	_stop_background_timers(main)
	_require(main.call("debug_get_current_music_track_index") == 0, "Second next run returns to track 1.")
	_require(main.call("debug_get_current_music_stream_path") == TRACK_01, "Second restart restores the original loop.")

	var fallback_stream: AudioStream = main.call(
		"debug_load_music_stream_for_path",
		"res://music/missing_interlude_track.wav"
	)
	_require(
		fallback_stream != null and fallback_stream.resource_path == TRACK_01,
		"Missing alternate music safely falls back to the original track."
	)


func _stop_background_timers(main: Node) -> void:
	(main.get_node("SpawnTimer") as Timer).stop()
	(main.get_node("OpportunityTimer") as Timer).stop()


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
