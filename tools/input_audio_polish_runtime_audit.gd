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
	await _audit_spear_recovery_audio(main)

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
	var recovery_player := main.get_node("AudioPlayers/PickupPlayer") as AudioStreamPlayer
	_require(not recovery_player.playing, "Application startup does not play the spear recovery cue.")


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


func _audit_spear_recovery_audio(main: Node) -> void:
	main.call("_restart_run")
	_stop_background_timers(main)
	var player := main.get_node("Player") as Player
	var spear := main.get_node("Spear") as Spear
	var recovery_player := main.get_node("AudioPlayers/PickupPlayer") as AudioStreamPlayer
	var pickup_counter := {"count": 0}
	spear.picked_up.connect(func() -> void:
		pickup_counter["count"] = int(pickup_counter["count"]) + 1
	)

	_require(not recovery_player.playing, "Restart/reset does not play the spear recovery cue.")
	_require(
		spear.try_throw(player.global_position + Vector2.RIGHT * 100.0),
		"Recovery audit begins with an ordinary valid throw."
	)
	var landing_position := player.global_position + Vector2.RIGHT * 96.0
	spear.call("_enter_landed_state", landing_position)
	await get_tree().process_frame
	_require(spear.is_landed(), "Flying spear reaches the LANDED state for recovery coverage.")
	_require(not recovery_player.playing, "FLYING to LANDED does not play the recovery cue.")
	_require(int(pickup_counter["count"]) == 0, "Landing alone does not emit a pickup event.")

	main.rng.seed = 66101
	var expected_gameplay_roll := main.rng.randi()
	main.rng.seed = 66101
	main.audio_rng.seed = 66102
	var expected_audio_roll := main.audio_rng.randi()
	main.audio_rng.seed = 66102

	player.global_position = landing_position
	spear.call("_on_pickup_body_entered", player)
	_require(int(pickup_counter["count"]) == 1, "Legitimate landed-spear collection emits one pickup event.")
	_require(spear.is_held(), "Spear is held and re-armed when the recovery cue begins.")
	_require(recovery_player.playing, "Legitimate LANDED to HELD recovery plays the cue once.")
	_require(main.rng.randi() == expected_gameplay_roll, "Recovery playback does not consume gameplay RNG.")
	_require(main.audio_rng.randi() == expected_audio_roll, "Recovery playback does not consume player-action audio RNG.")

	spear.call("_on_pickup_body_entered", player)
	spear.call("_on_pickup_body_entered", player)
	_require(int(pickup_counter["count"]) == 1, "Duplicate overlap callbacks cannot replay the recovery cue.")

	var paused_position := recovery_player.get_playback_position()
	get_tree().paused = true
	await get_tree().create_timer(0.05, true, false, true).timeout
	var paused_position_after_wait := recovery_player.get_playback_position()
	get_tree().paused = false
	_require(
		absf(paused_position_after_wait - paused_position) <= 0.02,
		"Pause freezes the short recovery cue instead of advancing or queuing another play."
	)
	_require(
		spear.try_throw(player.global_position + Vector2.UP * 100.0),
		"Recovered spear is immediately throwable while the cue is active."
	)

	main.call("_restart_run")
	_stop_background_timers(main)
	_require(not recovery_player.playing, "Restart stops an active recovery cue.")

	_require(
		spear.try_throw(player.global_position + Vector2.RIGHT * 100.0),
		"Game-over cleanup setup begins with a valid throw."
	)
	landing_position = player.global_position + Vector2.RIGHT * 96.0
	spear.call("_enter_landed_state", landing_position)
	player.global_position = landing_position
	spear.call("_on_pickup_body_entered", player)
	_require(recovery_player.playing, "Game-over cleanup setup starts the recovery cue.")
	main.call("_on_player_died")
	_require(not recovery_player.playing, "Game over stops an active recovery cue.")
	main.call("_stop_all_audio")
	_require(not recovery_player.playing, "Teardown audio cleanup leaves no recovery cue active.")


func _stop_background_timers(main: Node) -> void:
	(main.get_node("SpawnTimer") as Timer).stop()
	(main.get_node("OpportunityTimer") as Timer).stop()


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
