extends Node2D

const EnemyScene := preload("res://Enemy.tscn")
const ChargerScene := preload("res://Charger.tscn")
const HighScoreStore := preload("res://scripts/high_score_store.gd")

enum RunState {
	RUNNING,
	PAUSED,
	RESUME_COUNTDOWN,
	GAME_OVER,
}

@export var base_spawn_interval := 2.2
@export var minimum_spawn_interval := 0.6
@export var spawn_interval_drop_per_second := 0.012
@export var base_enemy_speed := 42.0
@export var enemy_speed_bonus_per_second := 0.11
@export var maximum_enemy_speed_bonus := 20.0
@export var spawn_safe_radius := 72.0
@export var landed_spear_spawn_safe_radius := 36.0
@export var blocked_spawn_retry_interval := 0.5
@export var damage_shake_duration := 0.1
@export var damage_shake_strength := 2.4
@export var close_hit_stop_distance := 8.0
@export var close_hit_stop_duration := 0.045
@export var close_hit_stop_time_scale := 0.05
@export_range(1, 8, 1) var default_window_scale := 4
@export var charger_unlock_time := 30.0
@export var charger_spawn_chance_at_unlock := 0.12
@export var charger_spawn_chance_growth_per_second := 0.0015
@export var maximum_charger_spawn_chance := 0.28

var score := 0
var high_score := 0
var survival_time := 0.0
var pause_active := false
var run_state: RunState = RunState.RUNNING
var shake_left := 0.0
var shake_strength := 0.0
var shake_duration := 0.0
var hit_stop_active := false
var hit_stop_restore_token := 0
var hit_stop_previous_time_scale := 1.0
var rng := RandomNumberGenerator.new()

@onready var arena: Arena = $Arena
@onready var player: Player = $Player
@onready var spear: Spear = $Spear
@onready var destination_marker: DestinationMarker = $DestinationMarker
@onready var encounter_telegraph: EncounterTelegraph = $EncounterTelegraph
@onready var encounter_director: EncounterDirector = $EncounterDirector
@onready var enemy_container: Node2D = $EnemyContainer
@onready var spawn_timer: Timer = $SpawnTimer
@onready var camera: Camera2D = $Camera2D
@onready var hud: HUD = $HUD
@onready var music_player: AudioStreamPlayer = $AudioPlayers/MusicPlayer
@onready var throw_player: AudioStreamPlayer = $AudioPlayers/ThrowPlayer
@onready var enemy_hit_player: AudioStreamPlayer = $AudioPlayers/EnemyHitPlayer
@onready var enemy_death_player: AudioStreamPlayer = $AudioPlayers/EnemyDeathPlayer
@onready var pickup_player: AudioStreamPlayer = $AudioPlayers/PickupPlayer
@onready var player_hurt_player: AudioStreamPlayer = $AudioPlayers/PlayerHurtPlayer
@onready var game_over_player: AudioStreamPlayer = $AudioPlayers/GameOverPlayer
@onready var dodge_player: AudioStreamPlayer = $AudioPlayers/DodgePlayer
@onready var wave_warning_player: AudioStreamPlayer = $AudioPlayers/WaveWarningPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_input_actions()
	rng.randomize()
	high_score = HighScoreStore.load_high_score()
	_configure_window()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS

	var play_rect := arena.get_play_rect()
	player.set_arena_rect(play_rect)
	player.global_position = play_rect.get_center()
	spear.setup(player, play_rect)
	camera.position = arena.arena_size * 0.5
	encounter_telegraph.setup(play_rect)

	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	spear.enemy_hit.connect(_on_spear_enemy_hit)
	spear.picked_up.connect(_on_spear_picked_up)
	spear.thrown.connect(_on_spear_thrown)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	encounter_director.spawn_requested.connect(_on_director_spawn_requested)
	encounter_director.telegraph_started.connect(_on_wave_telegraph_started)
	encounter_director.telegraph_finished.connect(_on_wave_telegraph_finished)
	encounter_director.ambient_spawn_policy_changed.connect(
		_on_ambient_spawn_policy_changed
	)
	hud.pause_toggle_requested.connect(_on_hud_pause_toggle_requested)
	hud.pause_resume_click_requested.connect(_on_hud_pause_resume_click_requested)
	hud.resume_countdown_finished.connect(_on_resume_countdown_finished)
	hud.restart_requested.connect(_on_restart_requested)

	_reset_runtime_state()
	_start_background_music()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	_cancel_hit_stop()
	_stop_all_audio()


func _reset_runtime_state() -> void:
	var play_rect := arena.get_play_rect()

	score = 0
	survival_time = 0.0
	pause_active = false
	run_state = RunState.RUNNING
	get_tree().paused = false
	camera.offset = Vector2.ZERO
	shake_left = 0.0
	shake_strength = 0.0
	shake_duration = 0.0
	_cancel_hit_stop()

	for child in enemy_container.get_children():
		child.queue_free()

	encounter_director.reset_for_new_run()
	encounter_telegraph.clear_warning()
	player.reset_for_new_run(play_rect.get_center(), play_rect)
	spear.reset_for_new_run(player, play_rect)
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.start()
	destination_marker.clear_marker()
	_stop_gameplay_sfx()

	hud.set_score(0)
	hud.hide_pause()
	hud.hide_game_over()


func _process(delta: float) -> void:
	if run_state == RunState.RUNNING:
		survival_time += delta
		encounter_director.advance(delta, survival_time)

	_update_screen_shake(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		if run_state == RunState.GAME_OVER:
			_restart_run()
		return

	if run_state != RunState.RUNNING:
		return

	if event.is_action_pressed("dodge_aim"):
		if player.try_start_aim_dodge(_get_shift_dodge_direction()):
			destination_marker.clear_marker()
			_play_sfx(dodge_player)
		return
	elif event.is_action_pressed("dodge_move"):
		if player.try_start_movement_dodge(_get_space_dodge_direction()):
			_play_sfx(dodge_player)
		return

	if event.is_action_pressed("move_to_cursor"):
		var move_target := arena.clamp_to_play_rect(get_global_mouse_position(), player.body_radius)
		if player.is_dodging():
			player.buffer_post_dodge_destination(move_target)
		else:
			player.set_move_destination(move_target)
		destination_marker.show_marker(move_target)
		return

	if player.is_dodging():
		return

	if event.is_action_pressed("throw_spear"):
		spear.try_throw(get_global_mouse_position())


func _spawn_enemy() -> bool:
	var enemy_kind := _pick_ambient_enemy_kind()
	var spawn_edge := arena.get_random_spawn_edge()
	return _try_spawn_enemy(
		enemy_kind,
		spawn_edge,
		EncounterDirector.INVALID_WAVE_ID
	)


func _try_spawn_enemy(enemy_kind: int, spawn_edge: int, wave_id: int) -> bool:
	if not encounter_director.can_spawn_enemy(enemy_kind, survival_time):
		return false

	var spawn_position := _find_safe_spawn_position(spawn_edge)
	if not spawn_position.is_finite():
		return false

	var enemy_scene := _get_enemy_scene(enemy_kind)
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return false

	enemy.setup(player, arena.get_play_rect(), _get_current_enemy_speed())
	enemy.global_position = spawn_position

	var enemy_id := enemy.get_instance_id()
	var run_generation := encounter_director.get_run_generation()
	enemy.killed.connect(_on_enemy_killed.bind(enemy_id, run_generation))
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy_id, run_generation))
	enemy_container.add_child(enemy)
	encounter_director.register_enemy(enemy, enemy_kind, wave_id)
	return true


func _find_safe_spawn_position(spawn_edge: int) -> Vector2:
	var avoid_positions: Array[Vector2] = [player.global_position]
	var avoid_radii: Array[float] = [spawn_safe_radius]
	if spear.is_landed():
		avoid_positions.append(spear.global_position)
		avoid_radii.append(landed_spear_spawn_safe_radius)

	return arena.find_safe_spawn_position(spawn_edge, avoid_positions, avoid_radii)


func _get_enemy_scene(enemy_kind: int) -> PackedScene:
	if enemy_kind == EncounterDirector.EnemyKind.CHARGER:
		return ChargerScene
	return EnemyScene


func _get_current_enemy_speed() -> float:
	return base_enemy_speed + min(maximum_enemy_speed_bonus, survival_time * enemy_speed_bonus_per_second)


func _get_next_spawn_interval() -> float:
	return max(minimum_spawn_interval, base_spawn_interval - survival_time * spawn_interval_drop_per_second)


func _pick_ambient_enemy_kind() -> int:
	if survival_time < charger_unlock_time:
		return EncounterDirector.EnemyKind.NORMAL

	var charger_spawn_chance := charger_spawn_chance_at_unlock + (
		(survival_time - charger_unlock_time) * charger_spawn_chance_growth_per_second
	)
	charger_spawn_chance = min(charger_spawn_chance, maximum_charger_spawn_chance)
	if rng.randf() < charger_spawn_chance:
		return EncounterDirector.EnemyKind.CHARGER
	return EncounterDirector.EnemyKind.NORMAL


func _on_spawn_timer_timeout() -> void:
	if run_state != RunState.RUNNING:
		return
	if not encounter_director.is_ambient_spawning_allowed():
		return

	var spawned := _spawn_enemy()
	if spawned:
		spawn_timer.wait_time = _get_next_spawn_interval()
	else:
		spawn_timer.wait_time = blocked_spawn_retry_interval
	spawn_timer.start()


func _on_director_spawn_requested(
	request_id: int,
	enemy_kind: int,
	spawn_edge: int,
	wave_id: int
) -> void:
	var spawned := _try_spawn_enemy(enemy_kind, spawn_edge, wave_id)
	encounter_director.report_spawn_result(request_id, spawned)


func _on_enemy_killed(
	_enemy_position: Vector2,
	score_value: int,
	enemy_id: int,
	run_generation: int
) -> void:
	if not encounter_director.notify_enemy_removed(enemy_id, run_generation):
		return

	score += score_value
	hud.set_score(score)
	_play_sfx(enemy_death_player)


func _on_enemy_tree_exited(enemy_id: int, run_generation: int) -> void:
	encounter_director.notify_enemy_removed(enemy_id, run_generation)


func _on_player_damaged(_new_health: int) -> void:
	_play_sfx(player_hurt_player)
	_start_screen_shake(damage_shake_duration, damage_shake_strength)


func _on_player_died() -> void:
	if run_state == RunState.GAME_OVER:
		return

	_cancel_hit_stop()
	run_state = RunState.GAME_OVER
	spawn_timer.stop()
	encounter_director.stop_for_game_over()
	player.set_active(false)
	spear.set_active(false)

	for child in enemy_container.get_children():
		if child.has_method("set_active"):
			child.set_active(false)

	var is_new_high_score := score > high_score
	if is_new_high_score:
		high_score = score

	HighScoreStore.save_high_score(high_score)

	_set_pause_state(false)
	hud.show_game_over(score, survival_time, high_score, is_new_high_score)
	_play_sfx(game_over_player)


func _on_spear_thrown() -> void:
	_play_sfx(throw_player)


func _on_spear_enemy_hit(_hit_position: Vector2) -> void:
	_play_sfx(enemy_hit_player)
	_try_start_close_hit_stop(_hit_position)


func _on_spear_picked_up() -> void:
	_play_sfx(pickup_player)


func _on_wave_telegraph_started(
	_wave_name: StringName,
	edges: Array[int],
	duration: float
) -> void:
	encounter_telegraph.show_warning(edges, duration)
	_play_sfx(wave_warning_player)


func _on_wave_telegraph_finished() -> void:
	encounter_telegraph.clear_warning()


func _on_ambient_spawn_policy_changed(allowed: bool) -> void:
	if not allowed:
		spawn_timer.stop()
		return
	if run_state != RunState.RUNNING:
		return

	spawn_timer.wait_time = _get_next_spawn_interval()
	spawn_timer.start()


func _on_hud_pause_toggle_requested() -> void:
	match run_state:
		RunState.RUNNING:
			_set_pause_state(true)
		RunState.PAUSED:
			_start_resume_countdown()
		RunState.RESUME_COUNTDOWN:
			_cancel_resume_countdown()


func _on_hud_pause_resume_click_requested() -> void:
	if run_state == RunState.PAUSED:
		_start_resume_countdown()


func _on_resume_countdown_finished() -> void:
	if run_state != RunState.RESUME_COUNTDOWN:
		return

	get_tree().paused = false
	pause_active = false
	run_state = RunState.RUNNING
	camera.offset = Vector2.ZERO
	hud.hide_pause()


func _on_restart_requested() -> void:
	_restart_run()


func _restart_run() -> void:
	get_tree().paused = false
	_reset_runtime_state()


func _start_screen_shake(duration: float, strength: float) -> void:
	shake_left = max(shake_left, duration)
	shake_duration = max(shake_duration, duration)
	shake_strength = max(shake_strength, strength)


func _play_sfx(audio_player: AudioStreamPlayer) -> void:
	if audio_player == null:
		return
	if audio_player.stream == null:
		return

	audio_player.play()


func _start_background_music() -> void:
	if music_player == null:
		return
	if music_player.stream == null:
		return

	if not music_player.finished.is_connected(_on_music_player_finished):
		music_player.finished.connect(_on_music_player_finished)

	if not music_player.playing:
		music_player.play()


func _on_music_player_finished() -> void:
	if music_player == null or music_player.stream == null:
		return

	music_player.play()


func _stop_all_audio() -> void:
	for audio_player in [
		music_player,
		throw_player,
		enemy_hit_player,
		enemy_death_player,
		pickup_player,
		player_hurt_player,
		game_over_player,
		dodge_player,
		wave_warning_player,
	]:
		if audio_player == null:
			continue
		audio_player.stop()


func _stop_gameplay_sfx() -> void:
	for audio_player in [
		throw_player,
		enemy_hit_player,
		enemy_death_player,
		pickup_player,
		player_hurt_player,
		game_over_player,
		dodge_player,
		wave_warning_player,
	]:
		if audio_player == null:
			continue
		audio_player.stop()

func _configure_window() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var internal_size := Vector2i(int(arena.arena_size.x), int(arena.arena_size.y))
	get_window().size = internal_size * default_window_scale


func _update_screen_shake(delta: float) -> void:
	if shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		return

	shake_left = max(shake_left - delta, 0.0)
	var strength_scale := 1.0
	if shake_duration > 0.0:
		strength_scale = shake_left / shake_duration

	var current_strength := shake_strength * strength_scale
	camera.offset = Vector2(
		roundf(randf_range(-current_strength, current_strength)),
		roundf(randf_range(-current_strength, current_strength))
	)

func _set_pause_state(should_pause: bool) -> void:
	if pause_active == should_pause:
		return
	if run_state == RunState.GAME_OVER and should_pause:
		return

	pause_active = should_pause
	get_tree().paused = should_pause
	camera.offset = Vector2.ZERO

	if pause_active:
		run_state = RunState.PAUSED
		hud.show_pause()
	else:
		if run_state != RunState.GAME_OVER:
			run_state = RunState.RUNNING
		hud.hide_pause()


func _start_resume_countdown() -> void:
	if run_state != RunState.PAUSED:
		return

	run_state = RunState.RESUME_COUNTDOWN
	hud.start_resume_countdown()


func _cancel_resume_countdown() -> void:
	if run_state != RunState.RESUME_COUNTDOWN:
		return

	run_state = RunState.PAUSED
	hud.cancel_resume_countdown()


func _try_start_close_hit_stop(hit_position: Vector2) -> void:
	if run_state != RunState.RUNNING:
		return
	if hit_stop_active:
		return
	if close_hit_stop_duration <= 0.0:
		return
	if player == null:
		return
	if player.global_position.distance_to(hit_position) > close_hit_stop_distance:
		return

	hit_stop_active = true
	hit_stop_restore_token += 1
	hit_stop_previous_time_scale = Engine.time_scale
	Engine.time_scale = min(close_hit_stop_time_scale, hit_stop_previous_time_scale)
	_restore_close_hit_stop_async(hit_stop_restore_token)


func _restore_close_hit_stop_async(restore_token: int) -> void:
	await get_tree().create_timer(close_hit_stop_duration, true, false, true).timeout
	if restore_token != hit_stop_restore_token:
		return
	_cancel_hit_stop()


func _cancel_hit_stop() -> void:
	if hit_stop_active:
		Engine.time_scale = hit_stop_previous_time_scale
		hit_stop_active = false
		return

	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


func _ensure_input_actions() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_right", KEY_D)
	_add_key_action("throw_spear", KEY_Q)
	_add_key_action("dodge_aim", KEY_SHIFT)
	_add_key_action("dodge_move", KEY_SPACE)
	_remove_mouse_button_action("throw_spear", MOUSE_BUTTON_RIGHT)
	_add_mouse_button_action("throw_spear", MOUSE_BUTTON_LEFT)
	_add_mouse_button_action("move_to_cursor", MOUSE_BUTTON_RIGHT)
	_remove_mouse_button_action("move_to_cursor", MOUSE_BUTTON_LEFT)
	_add_key_action("restart", KEY_R)
	_add_key_action("pause_game", KEY_ESCAPE)
	_add_key_action("pause_game", KEY_P)


func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)


func _add_mouse_button_action(action_name: StringName, mouse_button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == mouse_button:
			return

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = mouse_button
	InputMap.action_add_event(action_name, mouse_event)


func _remove_mouse_button_action(action_name: StringName, mouse_button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		return

	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == mouse_button:
			InputMap.action_erase_event(action_name, event)


func _get_shift_dodge_direction() -> Vector2:
	var aim_direction := get_global_mouse_position() - player.global_position
	if aim_direction.length_squared() > 0.001:
		return aim_direction.normalized()

	return player.get_last_valid_aim_direction()


func _get_space_dodge_direction() -> Vector2:
	var manual_direction := player.get_manual_input_direction()
	if manual_direction.length_squared() > 0.0:
		return manual_direction.normalized()

	var move_destination_direction := player.get_move_destination_direction()
	if move_destination_direction.length_squared() > 0.0:
		return move_destination_direction

	return player.get_last_valid_aim_direction()
