extends Node2D

const EnemyScene := preload("res://Enemy.tscn")
const ChargerScene := preload("res://Charger.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const ShooterScene := preload("res://ShooterEnemy.tscn")
const BoomerScene := preload("res://BoomerEnemy.tscn")
const HeartRunnerScene := preload("res://HeartRunner.tscn")
const HeartPickupScene := preload("res://HeartPickup.tscn")
const BoomerBlastEffectScene := preload("res://BoomerBlastEffect.tscn")
const DartProjectileScene := preload("res://DartProjectile.tscn")
const HighScoreStore := preload("res://scripts/high_score_store.gd")
const NO_AMBIENT_ENEMY_KIND := -1
const DEBUG_SHIELDED_SPAWN_ENABLED := true
const DEBUG_SHOOTER_SPAWN_ENABLED := true
const DEBUG_BOOMER_SPAWN_ENABLED := true
const DEBUG_HEART_RUNNER_SPAWN_ENABLED := true
const PLAYER_ACTION_THROW := &"throw"
const PLAYER_ACTION_DODGE := &"dodge"
const PLAYER_ACTION_HURT := &"hurt"
const THROW_SFX_PATHS: Array[String] = [
	"res://audio/throw.wav",
	"res://audio/throw_alt_01.wav",
	"res://audio/throw_alt_02.wav",
]
const DODGE_SFX_PATHS: Array[String] = [
	"res://audio/dodge.wav",
	"res://audio/dodge_alt_01.wav",
	"res://audio/dodge_alt_02.wav",
]
const HURT_SFX_PATHS: Array[String] = [
	"res://audio/player_hurt.wav",
	"res://audio/player_hurt_alt_01.wav",
	"res://audio/player_hurt_alt_02.wav",
]
const MUSIC_TRACK_PATHS: Array[String] = [
	"res://music/quiet_hunter_loop.wav",
	"res://music/quiet_hunter_loop_02.wav",
]

enum RunState {
	RUNNING,
	PAUSED,
	RESUME_COUNTDOWN,
	GAME_OVER,
}

enum SpawnSource {
	AMBIENT,
	WAVE,
	DEBUG,
}

@export var base_spawn_interval := 2.2
@export var minimum_spawn_interval := 0.75
@export var spawn_interval_drop_per_second := 0.006
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
@export var charger_unlock_time := 15.0
@export var charger_spawn_chance_at_unlock := 0.08
@export var charger_spawn_chance_growth_per_second := 0.001
@export var maximum_charger_spawn_chance := 0.22
@export var charger_intro_target_time_min := 15.0
@export var charger_intro_target_time_max := 21.0
@export var shielded_unlock_time := 25.0
@export var shielded_spawn_chance_at_unlock := 0.05
@export var shielded_spawn_chance_growth_per_second := 0.0006
@export var maximum_shielded_spawn_chance := 0.12
@export var shielded_intro_target_time_min := 25.0
@export var shielded_intro_target_time_max := 30.0
@export var shooter_unlock_time := 42.0
@export var shooter_spawn_chance_at_unlock := 0.04
@export var shooter_spawn_chance_growth_per_second := 0.00045
@export var maximum_shooter_spawn_chance := 0.10
@export var shooter_intro_target_time_min := 42.0
@export var shooter_intro_target_time_max := 52.0
@export var boomer_unlock_time := 65.0
@export var boomer_spawn_chance_at_unlock := 0.025
@export var boomer_spawn_chance_growth_per_second := 0.00035
@export var maximum_boomer_spawn_chance := 0.07
@export var boomer_intro_target_time_min := 65.0
@export var boomer_intro_target_time_max := 78.0
@export var heart_runner_unlock_time := 20.0
@export var heart_runner_roll_interval_min := 8.0
@export var heart_runner_roll_interval_max := 12.0
@export var heart_runner_health_3_spawn_chance := 0.01
@export var heart_runner_health_2_spawn_chance := 0.04
@export var heart_runner_health_1_spawn_chance := 0.15
@export var heart_runner_one_health_grace_duration := 90.0
@export var heart_runner_speed := 140.0
@export var heart_runner_spawn_safe_radius := 56.0
@export var heart_runner_landed_spear_safe_radius := 24.0
@export var heart_runner_post_resolution_cooldown := 18.0
@export var heart_pickup_lifetime := 7.0
@export var heart_pickup_warning_duration := 1.5

var score := 0
var high_score := 0
var survival_time := 0.0
var charger_intro_target_time := 15.0
var shielded_intro_target_time := 25.0
var shooter_intro_target_time := 42.0
var boomer_intro_target_time := 65.0
var charger_intro_seen := false
var shielded_intro_seen := false
var shooter_intro_seen := false
var boomer_intro_seen := false
var pause_active := false
var run_state: RunState = RunState.RUNNING
var shake_left := 0.0
var shake_strength := 0.0
var shake_duration := 0.0
var hit_stop_active := false
var hit_stop_restore_token := 0
var hit_stop_previous_time_scale := 1.0
var rng := RandomNumberGenerator.new()
var audio_rng := RandomNumberGenerator.new()
var has_buffered_spear_throw := false
var buffered_spear_throw_target := Vector2.ZERO
var throw_sfx_variants: Array[AudioStream] = []
var dodge_sfx_variants: Array[AudioStream] = []
var hurt_sfx_variants: Array[AudioStream] = []
var last_throw_sfx_index := -1
var last_dodge_sfx_index := -1
var last_hurt_sfx_index := -1
var current_music_track_index := 0
var original_music_stream: AudioStream
var debug_intro_target_sequence: Array = []
var debug_ambient_roll_sequence: Array = []
var debug_heart_runner_roll_sequence: Array = []
var debug_heart_runner_interval_sequence: Array = []
var heart_runner_next_eligible_time := 0.0
var heart_runner_one_health_active_time := 0.0
var heart_runner_one_health_grace_due := false
var active_heart_runner: HeartRunner
var active_heart_pickup: HeartPickup

@onready var arena: Arena = $Arena
@onready var player: Player = $Player
@onready var spear: Spear = $Spear
@onready var destination_marker: DestinationMarker = $DestinationMarker
@onready var encounter_telegraph: EncounterTelegraph = $EncounterTelegraph
@onready var encounter_director: EncounterDirector = $EncounterDirector
@onready var enemy_container: Node2D = $EnemyContainer
@onready var opportunity_container: Node2D = $OpportunityContainer
@onready var effect_container: Node2D = $EffectContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var spawn_timer: Timer = $SpawnTimer
@onready var opportunity_timer: Timer = $OpportunityTimer
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
@onready var shield_break_player: AudioStreamPlayer = $AudioPlayers/ShieldBreakPlayer
@onready var blowgun_windup_player: AudioStreamPlayer = $AudioPlayers/BlowgunWindupPlayer
@onready var blowgun_fire_player: AudioStreamPlayer = $AudioPlayers/BlowgunFirePlayer
@onready var blowgun_shove_player: AudioStreamPlayer = $AudioPlayers/BlowgunShovePlayer
@onready var boomer_hop_prep_player: AudioStreamPlayer = $AudioPlayers/BoomerHopPrepPlayer
@onready var boomer_land_player: AudioStreamPlayer = $AudioPlayers/BoomerLandPlayer
@onready var boomer_fuse_player: AudioStreamPlayer = $AudioPlayers/BoomerFusePlayer
@onready var boomer_explosion_player: AudioStreamPlayer = $AudioPlayers/BoomerExplosionPlayer
@onready var heart_runner_appear_player: AudioStreamPlayer = $AudioPlayers/HeartRunnerAppearPlayer
@onready var heart_runner_alarm_player: AudioStreamPlayer = $AudioPlayers/HeartRunnerAlarmPlayer
@onready var heart_pickup_spawn_player: AudioStreamPlayer = $AudioPlayers/HeartPickupSpawnPlayer
@onready var heart_pickup_collect_player: AudioStreamPlayer = $AudioPlayers/HeartPickupCollectPlayer
@onready var heart_pickup_expire_player: AudioStreamPlayer = $AudioPlayers/HeartPickupExpirePlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_input_actions()
	rng.randomize()
	audio_rng.randomize()
	high_score = HighScoreStore.load_high_score()
	_configure_window()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	original_music_stream = music_player.stream
	_load_player_action_sfx_variants()

	var play_rect := arena.get_play_rect()
	player.set_arena_rect(play_rect)
	player.global_position = play_rect.get_center()
	spear.setup(player, play_rect)
	camera.position = arena.arena_size * 0.5
	encounter_telegraph.setup(play_rect)

	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	player.dodge_ended.connect(_on_player_dodge_ended)
	spear.enemy_hit.connect(_on_spear_enemy_hit)
	spear.picked_up.connect(_on_spear_picked_up)
	spear.thrown.connect(_on_spear_thrown)
	spear.state_changed.connect(_on_spear_state_changed)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	opportunity_timer.timeout.connect(_on_opportunity_timer_timeout)
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
	_start_background_music(true)


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	_clear_buffered_spear_throw()
	_cancel_hit_stop()
	_stop_all_audio()


func _reset_runtime_state() -> void:
	var play_rect := arena.get_play_rect()

	score = 0
	survival_time = 0.0
	_reset_intro_state()
	pause_active = false
	run_state = RunState.RUNNING
	get_tree().paused = false
	camera.offset = Vector2.ZERO
	shake_left = 0.0
	shake_strength = 0.0
	shake_duration = 0.0
	_clear_buffered_spear_throw()
	_cancel_hit_stop()

	for child in enemy_container.get_children():
		child.queue_free()
	_clear_opportunities()
	_clear_transient_effects()
	_clear_projectiles()

	encounter_director.reset_for_new_run()
	encounter_telegraph.clear_warning()
	player.reset_for_new_run(play_rect.get_center(), play_rect)
	spear.reset_for_new_run(player, play_rect)
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.start()
	heart_runner_next_eligible_time = 0.0
	_reset_heart_runner_one_health_grace()
	_start_opportunity_timer()
	destination_marker.clear_marker()
	_stop_gameplay_sfx()

	hud.set_score(0)
	hud.set_survival_time(0.0)
	hud.hide_pause()
	hud.hide_game_over()


func _process(delta: float) -> void:
	if run_state == RunState.RUNNING:
		survival_time += delta
		_update_heart_runner_one_health_grace(delta)
		hud.set_survival_time(survival_time)
		encounter_director.advance(delta, survival_time)

	_update_screen_shake(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		if run_state == RunState.GAME_OVER:
			_restart_run()
		return

	if run_state != RunState.RUNNING:
		return

	if DEBUG_SHIELDED_SPAWN_ENABLED and event.is_action_pressed("debug_spawn_shielded"):
		_debug_spawn_shielded_enemy()
		return
	if DEBUG_SHOOTER_SPAWN_ENABLED and event.is_action_pressed("debug_spawn_shooter"):
		_debug_spawn_shooter_enemy()
		return
	if DEBUG_BOOMER_SPAWN_ENABLED and event.is_action_pressed("debug_spawn_boomer"):
		_debug_spawn_boomer_enemy()
		return
	if DEBUG_HEART_RUNNER_SPAWN_ENABLED and event.is_action_pressed("debug_spawn_heart_runner"):
		_debug_spawn_heart_runner()
		return

	if event.is_action_pressed("dodge_aim"):
		if player.try_start_aim_dodge(_get_shift_dodge_direction()):
			destination_marker.clear_marker()
			_play_player_action_sfx(PLAYER_ACTION_DODGE)
			return
	elif event.is_action_pressed("dodge_move"):
		if player.try_start_movement_dodge(_get_space_dodge_direction()):
			_play_player_action_sfx(PLAYER_ACTION_DODGE)
			return

	if event.is_action_pressed("move_to_cursor"):
		var move_target := arena.clamp_to_play_rect(get_global_mouse_position(), player.body_radius)
		if player.is_dodging():
			player.buffer_post_dodge_destination(move_target)
		else:
			player.set_move_destination(move_target)
		destination_marker.show_marker(move_target)
		return

	if event.is_action_pressed("throw_spear"):
		_handle_spear_throw_input(get_global_mouse_position())
		return

	if player.is_dodging():
		return


func _handle_spear_throw_input(target_position: Vector2) -> void:
	if run_state != RunState.RUNNING:
		return

	if player.is_dodging():
		if spear.is_held():
			has_buffered_spear_throw = true
			buffered_spear_throw_target = target_position
		return

	spear.try_throw(target_position)


func _on_player_dodge_ended() -> void:
	if not has_buffered_spear_throw:
		return

	var target_position := buffered_spear_throw_target
	_clear_buffered_spear_throw()
	if run_state != RunState.RUNNING or not player.active or not spear.is_held():
		return

	spear.try_throw(target_position)


func _on_spear_state_changed(new_state: int) -> void:
	if new_state != Spear.State.HELD:
		_clear_buffered_spear_throw()


func _clear_buffered_spear_throw() -> void:
	has_buffered_spear_throw = false
	buffered_spear_throw_target = Vector2.ZERO


func debug_has_buffered_spear_throw() -> bool:
	return has_buffered_spear_throw


func debug_get_buffered_spear_throw_target() -> Vector2:
	return buffered_spear_throw_target


func _spawn_enemy() -> bool:
	var enemy_kind := _pick_ambient_enemy_kind()
	if enemy_kind == NO_AMBIENT_ENEMY_KIND:
		return false

	var spawn_edge := arena.get_random_spawn_edge()
	return _try_spawn_enemy(
		enemy_kind,
		spawn_edge,
		EncounterDirector.INVALID_WAVE_ID,
		SpawnSource.AMBIENT
	)


func _try_spawn_enemy(
	enemy_kind: int,
	spawn_edge: int,
	wave_id: int,
	spawn_source: int = SpawnSource.AMBIENT
) -> bool:
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
	if enemy.has_signal("shield_broken"):
		enemy.connect(&"shield_broken", _on_shielded_enemy_shield_broken)
	if enemy.has_signal("aim_started"):
		enemy.connect(&"aim_started", _on_shooter_enemy_aim_started)
	if enemy.has_signal("dart_requested"):
		enemy.connect(&"dart_requested", _on_shooter_enemy_dart_requested)
	if enemy.has_signal("shove_used"):
		enemy.connect(&"shove_used", _on_shooter_enemy_shove_used)
	if enemy.has_signal("hop_prepared"):
		enemy.connect(&"hop_prepared", _on_boomer_enemy_hop_prepared)
	if enemy.has_signal("hop_landed"):
		enemy.connect(&"hop_landed", _on_boomer_enemy_hop_landed)
	if enemy.has_signal("fuse_started"):
		enemy.connect(&"fuse_started", _on_boomer_enemy_fuse_started)
	if enemy.has_signal("detonated"):
		enemy.connect(&"detonated", _on_boomer_enemy_detonated)
	enemy_container.add_child(enemy)
	encounter_director.register_enemy(enemy, enemy_kind, wave_id)
	_mark_intro_seen_for_spawn(enemy_kind, spawn_source)
	return true


func _debug_spawn_shielded_enemy() -> void:
	var spawned := _try_spawn_enemy(
		EncounterDirector.EnemyKind.SHIELDED,
		arena.get_random_spawn_edge(),
		EncounterDirector.INVALID_WAVE_ID,
		SpawnSource.DEBUG
	)
	if spawned:
		print("DEBUG: spawned Shielded enemy with key 1.")
	else:
		print("DEBUG: Shielded enemy spawn failed; cap or safe spawn search blocked it.")


func _debug_spawn_shooter_enemy() -> void:
	var spawned := _try_spawn_enemy(
		EncounterDirector.EnemyKind.SHOOTER,
		arena.get_random_spawn_edge(),
		EncounterDirector.INVALID_WAVE_ID,
		SpawnSource.DEBUG
	)
	if spawned:
		print("DEBUG: spawned Shooter enemy with key 2.")
	else:
		print("DEBUG: Shooter enemy spawn failed; cap or safe spawn search blocked it.")


func _debug_spawn_boomer_enemy() -> void:
	var spawned := _try_spawn_enemy(
		EncounterDirector.EnemyKind.BOOMER,
		arena.get_random_spawn_edge(),
		EncounterDirector.INVALID_WAVE_ID,
		SpawnSource.DEBUG
	)
	if spawned:
		print("DEBUG: spawned Boomer enemy with key 3.")
	else:
		print("DEBUG: Boomer enemy spawn failed; cap or safe spawn search blocked it.")


func _debug_spawn_heart_runner() -> void:
	var spawned := _try_spawn_heart_runner(true)
	if spawned:
		print("DEBUG: spawned Heart Runner with key 4.")
	else:
		print("DEBUG: Heart Runner spawn failed; an active Runner/pickup or safe entry search blocked it.")


func _on_opportunity_timer_timeout() -> void:
	if run_state != RunState.RUNNING:
		return

	_run_heart_runner_opportunity_check()


func _run_heart_runner_opportunity_check() -> void:
	if not _is_heart_runner_opportunity_eligible_for_roll():
		_start_opportunity_timer()
		return

	if _is_heart_runner_one_health_grace_ready_for_forced_spawn():
		_try_spawn_heart_runner(false)
		_start_opportunity_timer()
		return

	var spawn_chance := _get_current_heart_runner_spawn_chance()
	if spawn_chance > 0.0 and _get_heart_runner_roll() < spawn_chance:
		_try_spawn_heart_runner(false)

	_start_opportunity_timer()


func _is_heart_runner_opportunity_eligible_for_roll() -> bool:
	if run_state != RunState.RUNNING:
		return false
	if player == null or not player.is_alive():
		return false
	if active_heart_runner != null or active_heart_pickup != null:
		return false
	if survival_time < heart_runner_unlock_time:
		return false
	if survival_time < heart_runner_next_eligible_time:
		return false
	return true


func _start_opportunity_timer() -> void:
	if opportunity_timer == null:
		return

	opportunity_timer.wait_time = _get_next_heart_runner_roll_interval()
	opportunity_timer.start()


func _get_next_heart_runner_roll_interval() -> float:
	if not debug_heart_runner_interval_sequence.is_empty():
		return maxf(float(debug_heart_runner_interval_sequence.pop_front()), 0.01)

	return rng.randf_range(heart_runner_roll_interval_min, heart_runner_roll_interval_max)


func _get_heart_runner_roll() -> float:
	if not debug_heart_runner_roll_sequence.is_empty():
		return float(debug_heart_runner_roll_sequence.pop_front())

	return rng.randf()


func _get_current_heart_runner_spawn_chance() -> float:
	if player == null:
		return 0.0

	match player.health:
		4:
			return 0.0
		3:
			return heart_runner_health_3_spawn_chance
		2:
			return heart_runner_health_2_spawn_chance
		1:
			return heart_runner_health_1_spawn_chance

	return 0.0


func _update_heart_runner_one_health_grace(delta: float) -> void:
	if player == null or not player.is_alive() or player.health != 1:
		_reset_heart_runner_one_health_grace()
		return
	if heart_runner_one_health_grace_due:
		return

	heart_runner_one_health_active_time = minf(
		heart_runner_one_health_active_time + delta,
		heart_runner_one_health_grace_duration
	)
	if heart_runner_one_health_active_time >= heart_runner_one_health_grace_duration:
		heart_runner_one_health_grace_due = true


func _is_heart_runner_one_health_grace_ready_for_forced_spawn() -> bool:
	return (
		heart_runner_one_health_grace_due
		and player != null
		and player.is_alive()
		and player.health == 1
	)


func _consume_heart_runner_one_health_grace_after_organic_spawn() -> void:
	heart_runner_one_health_active_time = 0.0
	heart_runner_one_health_grace_due = false


func _reset_heart_runner_one_health_grace() -> void:
	heart_runner_one_health_active_time = 0.0
	heart_runner_one_health_grace_due = false


func _try_spawn_heart_runner(is_debug_spawn: bool) -> bool:
	if active_heart_runner != null or active_heart_pickup != null:
		return false
	if player == null or not player.is_alive():
		return false
	if not is_debug_spawn and survival_time < heart_runner_unlock_time:
		return false

	var spawn_setup := _find_heart_runner_spawn_setup()
	if not spawn_setup.get("valid", false):
		return false

	var heart_runner := HeartRunnerScene.instantiate() as HeartRunner
	if heart_runner == null:
		return false

	var play_rect := arena.get_play_rect()
	opportunity_container.add_child(heart_runner)
	heart_runner.setup(
		play_rect,
		spawn_setup["entry_position"],
		int(spawn_setup["spawn_edge"]),
		heart_runner_speed,
		player,
		spear,
		is_debug_spawn,
		rng.randi()
	)
	heart_runner.defeated.connect(_on_heart_runner_defeated)
	heart_runner.escaped.connect(_on_heart_runner_escaped)
	heart_runner.startled_started.connect(_on_heart_runner_startled)
	heart_runner.tree_exited.connect(_on_heart_runner_tree_exited.bind(heart_runner))
	active_heart_runner = heart_runner
	if not is_debug_spawn and player != null and player.health == 1:
		_consume_heart_runner_one_health_grace_after_organic_spawn()
	_play_sfx(heart_runner_appear_player)
	return true


func _find_heart_runner_spawn_setup() -> Dictionary:
	var shuffled_edges := [
		Arena.SpawnEdge.TOP,
		Arena.SpawnEdge.BOTTOM,
		Arena.SpawnEdge.LEFT,
		Arena.SpawnEdge.RIGHT,
	]
	shuffled_edges.shuffle()

	for spawn_edge in shuffled_edges:
		var entry_position := _find_safe_heart_runner_entry_position(spawn_edge)
		if not entry_position.is_finite():
			continue

		return {
			"valid": true,
			"entry_position": entry_position,
			"spawn_edge": spawn_edge,
		}

	return {
		"valid": false,
	}


func _find_safe_heart_runner_entry_position(spawn_edge: int) -> Vector2:
	var avoid_positions: Array[Vector2] = [player.global_position]
	var avoid_radii: Array[float] = [heart_runner_spawn_safe_radius]
	if spear.is_landed():
		avoid_positions.append(spear.global_position)
		avoid_radii.append(heart_runner_landed_spear_safe_radius)

	return arena.find_safe_spawn_position(spawn_edge, avoid_positions, avoid_radii)


func _spawn_heart_pickup(spawn_position: Vector2, spawned_by_debug: bool) -> bool:
	if active_heart_pickup != null:
		return false

	var heart_pickup := HeartPickupScene.instantiate() as HeartPickup
	if heart_pickup == null:
		return false

	opportunity_container.add_child(heart_pickup)
	heart_pickup.lifetime = heart_pickup_lifetime
	heart_pickup.warning_duration = heart_pickup_warning_duration
	heart_pickup.setup(player, arena.get_play_rect(), spawn_position)
	heart_pickup.collected.connect(_on_heart_pickup_collected.bind(spawned_by_debug))
	heart_pickup.expired.connect(_on_heart_pickup_expired.bind(spawned_by_debug))
	heart_pickup.warning_started.connect(_on_heart_pickup_warning_started)
	heart_pickup.tree_exited.connect(_on_heart_pickup_tree_exited.bind(heart_pickup))
	active_heart_pickup = heart_pickup
	_play_sfx(heart_pickup_spawn_player)
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
	if enemy_kind == EncounterDirector.EnemyKind.SHIELDED:
		return ShieldedScene
	if enemy_kind == EncounterDirector.EnemyKind.SHOOTER:
		return ShooterScene
	if enemy_kind == EncounterDirector.EnemyKind.BOOMER:
		return BoomerScene
	return EnemyScene


func _get_current_enemy_speed() -> float:
	return base_enemy_speed + min(maximum_enemy_speed_bonus, survival_time * enemy_speed_bonus_per_second)


func _get_next_spawn_interval() -> float:
	return max(minimum_spawn_interval, base_spawn_interval - survival_time * spawn_interval_drop_per_second)


func _pick_ambient_enemy_kind() -> int:
	var pending_intro_kind := _pick_pending_intro_enemy_kind()
	if pending_intro_kind != NO_AMBIENT_ENEMY_KIND:
		return pending_intro_kind

	return _pick_weighted_ambient_enemy_kind()


func _pick_weighted_ambient_enemy_kind() -> int:
	var normal_available := encounter_director.can_spawn_enemy(
		EncounterDirector.EnemyKind.NORMAL,
		survival_time
	)
	var charger_available := (
		survival_time >= charger_unlock_time
		and encounter_director.can_spawn_enemy(EncounterDirector.EnemyKind.CHARGER, survival_time)
	)
	var shielded_available := (
		survival_time >= shielded_unlock_time
		and encounter_director.can_spawn_enemy(EncounterDirector.EnemyKind.SHIELDED, survival_time)
	)
	var shooter_available := (
		survival_time >= shooter_unlock_time
		and encounter_director.can_spawn_enemy(EncounterDirector.EnemyKind.SHOOTER, survival_time)
	)
	var boomer_available := (
		survival_time >= boomer_unlock_time
		and encounter_director.can_spawn_enemy(EncounterDirector.EnemyKind.BOOMER, survival_time)
	)

	if (
		not normal_available
		and not charger_available
		and not shielded_available
		and not shooter_available
		and not boomer_available
	):
		return NO_AMBIENT_ENEMY_KIND

	var shielded_spawn_chance := 0.0
	if shielded_available:
		shielded_spawn_chance = _get_current_shielded_spawn_chance()

	var roll := _get_ambient_selection_roll()
	if shielded_available and roll < shielded_spawn_chance:
		return EncounterDirector.EnemyKind.SHIELDED

	var non_shield_roll := roll
	if shielded_available and shielded_spawn_chance < 1.0:
		non_shield_roll = (roll - shielded_spawn_chance) / (1.0 - shielded_spawn_chance)

	var shooter_spawn_chance := 0.0
	if shooter_available:
		shooter_spawn_chance = _get_current_shooter_spawn_chance()

	if shooter_available and non_shield_roll < shooter_spawn_chance:
		return EncounterDirector.EnemyKind.SHOOTER

	var non_shooter_roll := non_shield_roll
	if shooter_available and shooter_spawn_chance < 1.0:
		non_shooter_roll = (non_shield_roll - shooter_spawn_chance) / (1.0 - shooter_spawn_chance)

	var charger_spawn_chance := 0.0
	if charger_available:
		charger_spawn_chance = _get_current_charger_spawn_chance()

	if charger_available and non_shooter_roll < charger_spawn_chance:
		return EncounterDirector.EnemyKind.CHARGER
	var non_charger_roll := non_shooter_roll
	if charger_available and charger_spawn_chance < 1.0:
		non_charger_roll = (non_shooter_roll - charger_spawn_chance) / (1.0 - charger_spawn_chance)

	var boomer_spawn_chance := 0.0
	if boomer_available:
		boomer_spawn_chance = _get_current_boomer_spawn_chance()

	if boomer_available and non_charger_roll < boomer_spawn_chance:
		return EncounterDirector.EnemyKind.BOOMER
	if normal_available:
		return EncounterDirector.EnemyKind.NORMAL
	if boomer_available:
		return EncounterDirector.EnemyKind.BOOMER
	if charger_available:
		return EncounterDirector.EnemyKind.CHARGER
	if shooter_available:
		return EncounterDirector.EnemyKind.SHOOTER
	return EncounterDirector.EnemyKind.SHIELDED


func _pick_pending_intro_enemy_kind() -> int:
	var pending_candidates: Array[Dictionary] = []
	if _is_intro_pending_and_available(EncounterDirector.EnemyKind.CHARGER):
		pending_candidates.append({
			"enemy_kind": EncounterDirector.EnemyKind.CHARGER,
			"target_time": charger_intro_target_time,
		})
	if _is_intro_pending_and_available(EncounterDirector.EnemyKind.SHIELDED):
		pending_candidates.append({
			"enemy_kind": EncounterDirector.EnemyKind.SHIELDED,
			"target_time": shielded_intro_target_time,
		})
	if _is_intro_pending_and_available(EncounterDirector.EnemyKind.SHOOTER):
		pending_candidates.append({
			"enemy_kind": EncounterDirector.EnemyKind.SHOOTER,
			"target_time": shooter_intro_target_time,
		})
	if _is_intro_pending_and_available(EncounterDirector.EnemyKind.BOOMER):
		pending_candidates.append({
			"enemy_kind": EncounterDirector.EnemyKind.BOOMER,
			"target_time": boomer_intro_target_time,
		})

	if pending_candidates.is_empty():
		return NO_AMBIENT_ENEMY_KIND

	pending_candidates.sort_custom(_sort_intro_candidates_by_target_time)
	var first_candidate := pending_candidates[0]
	return int(first_candidate["enemy_kind"])


func _sort_intro_candidates_by_target_time(first_candidate: Dictionary, second_candidate: Dictionary) -> bool:
	return float(first_candidate["target_time"]) < float(second_candidate["target_time"])


func _is_intro_pending_and_available(enemy_kind: int) -> bool:
	match enemy_kind:
		EncounterDirector.EnemyKind.CHARGER:
			return (
				not charger_intro_seen
				and survival_time >= charger_intro_target_time
				and _is_enemy_kind_available_for_ambient(enemy_kind)
			)
		EncounterDirector.EnemyKind.SHIELDED:
			return (
				not shielded_intro_seen
				and survival_time >= shielded_intro_target_time
				and _is_enemy_kind_available_for_ambient(enemy_kind)
			)
		EncounterDirector.EnemyKind.SHOOTER:
			return (
				not shooter_intro_seen
				and survival_time >= shooter_intro_target_time
				and _is_enemy_kind_available_for_ambient(enemy_kind)
			)
		EncounterDirector.EnemyKind.BOOMER:
			return (
				not boomer_intro_seen
				and survival_time >= boomer_intro_target_time
				and _is_enemy_kind_available_for_ambient(enemy_kind)
			)

	return false


func _is_enemy_kind_available_for_ambient(enemy_kind: int) -> bool:
	match enemy_kind:
		EncounterDirector.EnemyKind.NORMAL:
			return encounter_director.can_spawn_enemy(enemy_kind, survival_time)
		EncounterDirector.EnemyKind.CHARGER:
			return (
				survival_time >= charger_unlock_time
				and encounter_director.can_spawn_enemy(enemy_kind, survival_time)
			)
		EncounterDirector.EnemyKind.SHIELDED:
			return (
				survival_time >= shielded_unlock_time
				and encounter_director.can_spawn_enemy(enemy_kind, survival_time)
			)
		EncounterDirector.EnemyKind.SHOOTER:
			return (
				survival_time >= shooter_unlock_time
				and encounter_director.can_spawn_enemy(enemy_kind, survival_time)
			)
		EncounterDirector.EnemyKind.BOOMER:
			return (
				survival_time >= boomer_unlock_time
				and encounter_director.can_spawn_enemy(enemy_kind, survival_time)
			)

	return false


func _get_current_charger_spawn_chance() -> float:
	var charger_spawn_chance := charger_spawn_chance_at_unlock + (
		(survival_time - charger_unlock_time) * charger_spawn_chance_growth_per_second
	)
	return min(charger_spawn_chance, maximum_charger_spawn_chance)


func _get_current_shielded_spawn_chance() -> float:
	var shielded_spawn_chance := shielded_spawn_chance_at_unlock + (
		(survival_time - shielded_unlock_time) * shielded_spawn_chance_growth_per_second
	)
	return min(shielded_spawn_chance, maximum_shielded_spawn_chance)


func _get_current_shooter_spawn_chance() -> float:
	var shooter_spawn_chance := shooter_spawn_chance_at_unlock + (
		(survival_time - shooter_unlock_time) * shooter_spawn_chance_growth_per_second
	)
	return min(shooter_spawn_chance, maximum_shooter_spawn_chance)


func _get_current_boomer_spawn_chance() -> float:
	var boomer_spawn_chance := boomer_spawn_chance_at_unlock + (
		(survival_time - boomer_unlock_time) * boomer_spawn_chance_growth_per_second
	)
	return min(boomer_spawn_chance, maximum_boomer_spawn_chance)


func _reset_intro_state() -> void:
	charger_intro_seen = false
	shielded_intro_seen = false
	shooter_intro_seen = false
	boomer_intro_seen = false
	_generate_intro_target_times()


func _generate_intro_target_times() -> void:
	if not debug_intro_target_sequence.is_empty():
		var target_values: Variant = debug_intro_target_sequence.pop_front()
		if target_values is Vector4:
			var target_quad: Vector4 = target_values
			charger_intro_target_time = target_quad.x
			shielded_intro_target_time = target_quad.y
			shooter_intro_target_time = target_quad.z
			boomer_intro_target_time = target_quad.w
			return
		if target_values is Vector3:
			var target_triple: Vector3 = target_values
			charger_intro_target_time = target_triple.x
			shielded_intro_target_time = target_triple.y
			shooter_intro_target_time = target_triple.z
			boomer_intro_target_time = rng.randf_range(
				boomer_intro_target_time_min,
				boomer_intro_target_time_max
			)
			return
		if target_values is Vector2:
			var target_pair: Vector2 = target_values
			charger_intro_target_time = target_pair.x
			shielded_intro_target_time = target_pair.y
			shooter_intro_target_time = rng.randf_range(
				shooter_intro_target_time_min,
				shooter_intro_target_time_max
			)
			boomer_intro_target_time = rng.randf_range(
				boomer_intro_target_time_min,
				boomer_intro_target_time_max
			)
			return
		if target_values is Array and target_values.size() >= 4:
			charger_intro_target_time = float(target_values[0])
			shielded_intro_target_time = float(target_values[1])
			shooter_intro_target_time = float(target_values[2])
			boomer_intro_target_time = float(target_values[3])
			return
		push_warning("Intro target audit values must be Vector2, Vector3, Vector4, or an Array of four floats.")
		_generate_random_intro_target_times()
		return

	_generate_random_intro_target_times()


func _generate_random_intro_target_times() -> void:
	charger_intro_target_time = rng.randf_range(
		charger_intro_target_time_min,
		charger_intro_target_time_max
	)
	shielded_intro_target_time = rng.randf_range(
		shielded_intro_target_time_min,
		shielded_intro_target_time_max
	)
	shooter_intro_target_time = rng.randf_range(
		shooter_intro_target_time_min,
		shooter_intro_target_time_max
	)
	boomer_intro_target_time = rng.randf_range(
		boomer_intro_target_time_min,
		boomer_intro_target_time_max
	)


func _mark_intro_seen_for_spawn(enemy_kind: int, spawn_source: int) -> void:
	if spawn_source == SpawnSource.DEBUG:
		return

	match enemy_kind:
		EncounterDirector.EnemyKind.CHARGER:
			charger_intro_seen = true
		EncounterDirector.EnemyKind.SHIELDED:
			shielded_intro_seen = true
		EncounterDirector.EnemyKind.SHOOTER:
			shooter_intro_seen = true
		EncounterDirector.EnemyKind.BOOMER:
			boomer_intro_seen = true


func _get_ambient_selection_roll() -> float:
	if not debug_ambient_roll_sequence.is_empty():
		return float(debug_ambient_roll_sequence.pop_front())

	return rng.randf()


func debug_set_intro_target_times(
	new_charger_intro_target_time: float,
	new_shielded_intro_target_time: float,
	new_shooter_intro_target_time: float = -1.0,
	new_boomer_intro_target_time: float = -1.0
) -> void:
	charger_intro_target_time = new_charger_intro_target_time
	shielded_intro_target_time = new_shielded_intro_target_time
	if new_shooter_intro_target_time >= 0.0:
		shooter_intro_target_time = new_shooter_intro_target_time
	if new_boomer_intro_target_time >= 0.0:
		boomer_intro_target_time = new_boomer_intro_target_time


func debug_set_intro_target_sequence(new_intro_target_sequence: Array) -> void:
	debug_intro_target_sequence = new_intro_target_sequence.duplicate()


func debug_set_ambient_roll_sequence(new_ambient_roll_sequence: Array) -> void:
	debug_ambient_roll_sequence = new_ambient_roll_sequence.duplicate()


func debug_set_heart_runner_roll_sequence(new_roll_sequence: Array) -> void:
	debug_heart_runner_roll_sequence = new_roll_sequence.duplicate()


func debug_set_heart_runner_interval_sequence(new_interval_sequence: Array) -> void:
	debug_heart_runner_interval_sequence = new_interval_sequence.duplicate()


func debug_set_heart_runner_one_health_grace_state(
	new_active_time: float,
	is_due: bool = false
) -> void:
	heart_runner_one_health_active_time = clampf(
		new_active_time,
		0.0,
		heart_runner_one_health_grace_duration
	)
	heart_runner_one_health_grace_due = is_due or (
		heart_runner_one_health_active_time >= heart_runner_one_health_grace_duration
	)


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
	var spawned := _try_spawn_enemy(enemy_kind, spawn_edge, wave_id, SpawnSource.WAVE)
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


func _on_heart_runner_defeated(
	defeat_position: Vector2,
	score_value: int,
	spawned_by_debug: bool
) -> void:
	active_heart_runner = null
	score += score_value
	hud.set_score(score)
	_spawn_heart_pickup(defeat_position, spawned_by_debug)


func _on_heart_runner_escaped(spawned_by_debug: bool) -> void:
	active_heart_runner = null
	if not spawned_by_debug:
		_start_heart_runner_resolution_cooldown()


func _on_heart_runner_startled() -> void:
	if run_state != RunState.RUNNING:
		return

	_play_sfx(heart_runner_alarm_player)


func _on_heart_runner_tree_exited(heart_runner: HeartRunner) -> void:
	if active_heart_runner == heart_runner:
		active_heart_runner = null


func _on_heart_pickup_collected(spawned_by_debug: bool) -> void:
	active_heart_pickup = null
	_play_sfx(heart_pickup_collect_player)
	if player != null and player.health != 1:
		_reset_heart_runner_one_health_grace()
	if not spawned_by_debug:
		_start_heart_runner_resolution_cooldown()


func _on_heart_pickup_expired(spawned_by_debug: bool) -> void:
	active_heart_pickup = null
	if not spawned_by_debug:
		_start_heart_runner_resolution_cooldown()


func _on_heart_pickup_warning_started() -> void:
	if run_state != RunState.RUNNING:
		return

	_play_sfx(heart_pickup_expire_player)


func _on_heart_pickup_tree_exited(heart_pickup: HeartPickup) -> void:
	if active_heart_pickup == heart_pickup:
		active_heart_pickup = null


func _start_heart_runner_resolution_cooldown() -> void:
	heart_runner_next_eligible_time = survival_time + heart_runner_post_resolution_cooldown


func _on_player_damaged(_new_health: int) -> void:
	_play_player_action_sfx(PLAYER_ACTION_HURT)
	_start_screen_shake(damage_shake_duration, damage_shake_strength)


func _on_player_died() -> void:
	if run_state == RunState.GAME_OVER:
		return

	_cancel_hit_stop()
	_reset_heart_runner_one_health_grace()
	run_state = RunState.GAME_OVER
	spawn_timer.stop()
	opportunity_timer.stop()
	encounter_director.stop_for_game_over()
	player.set_active(false)
	spear.set_active(false)
	_clear_buffered_spear_throw()
	_stop_player_action_sfx()

	for child in enemy_container.get_children():
		if child.has_method("set_active"):
			child.set_active(false)
	_clear_opportunities()
	_clear_projectiles()
	if blowgun_windup_player != null:
		blowgun_windup_player.stop()
	if boomer_fuse_player != null:
		boomer_fuse_player.stop()

	var is_new_high_score := score > high_score
	if is_new_high_score:
		high_score = score

	HighScoreStore.save_high_score(high_score)

	_set_pause_state(false)
	hud.show_game_over(score, survival_time, high_score, is_new_high_score)
	_play_sfx(game_over_player)


func _on_spear_thrown() -> void:
	_play_player_action_sfx(PLAYER_ACTION_THROW)


func _on_spear_enemy_hit(_hit_position: Vector2) -> void:
	_play_sfx(enemy_hit_player)
	_try_start_close_hit_stop(_hit_position)


func _on_shielded_enemy_shield_broken(_hit_position: Vector2) -> void:
	_play_sfx(shield_break_player)


func _on_shooter_enemy_aim_started() -> void:
	if run_state != RunState.RUNNING:
		return
	_play_sfx(blowgun_windup_player)


func _on_shooter_enemy_dart_requested(
	spawn_position: Vector2,
	fire_direction: Vector2,
	burst_id: int,
	dart_index: int
) -> void:
	if run_state != RunState.RUNNING:
		return

	_spawn_dart_projectile(spawn_position, fire_direction, burst_id, dart_index)
	_play_sfx(blowgun_fire_player)


func _on_shooter_enemy_shove_used() -> void:
	if run_state != RunState.RUNNING:
		return

	_play_sfx(blowgun_shove_player)


func _on_boomer_enemy_hop_prepared() -> void:
	if run_state != RunState.RUNNING:
		return

	_play_sfx(boomer_hop_prep_player)


func _on_boomer_enemy_hop_landed() -> void:
	if run_state != RunState.RUNNING:
		return

	_play_sfx(boomer_land_player)


func _on_boomer_enemy_fuse_started() -> void:
	if run_state != RunState.RUNNING:
		return

	_play_sfx(boomer_fuse_player)


func _on_boomer_enemy_detonated(
	position: Vector2,
	core_radius: float,
	outer_radius: float,
	landed_spear_shockwave_displacement: float
) -> void:
	if run_state != RunState.RUNNING:
		return

	if boomer_fuse_player != null:
		boomer_fuse_player.stop()
	_play_sfx(boomer_explosion_player)
	if spear != null:
		spear.apply_landed_shockwave_nudge(
			position,
			outer_radius,
			landed_spear_shockwave_displacement
		)
	if active_heart_runner != null:
		var distance_to_runner := active_heart_runner.global_position.distance_to(position)
		if distance_to_runner <= outer_radius + active_heart_runner.body_radius:
			var outward_direction := (active_heart_runner.global_position - position).normalized()
			if outward_direction == Vector2.ZERO:
				outward_direction = active_heart_runner.travel_direction
			if outward_direction == Vector2.ZERO:
				outward_direction = Vector2.RIGHT
			active_heart_runner.apply_authored_displacement(outward_direction, 18.0, 0.16)
	_spawn_boomer_blast_effect(position, core_radius, outer_radius)


func _spawn_dart_projectile(
	spawn_position: Vector2,
	fire_direction: Vector2,
	burst_id: int = Player.INVALID_DART_BURST_ID,
	dart_index: int = Player.INVALID_DART_INDEX
) -> void:
	var dart := DartProjectileScene.instantiate() as DartProjectile
	if dart == null:
		return

	projectile_container.add_child(dart)
	dart.global_position = spawn_position
	dart.setup(player, arena.get_play_rect(), fire_direction, burst_id, dart_index)


func _clear_projectiles() -> void:
	if projectile_container == null:
		return

	for projectile in projectile_container.get_children():
		if projectile.has_method("destroy_projectile"):
			projectile.call("destroy_projectile", DartProjectile.DESTROY_REASON_CLEARED)
		else:
			projectile.queue_free()


func _clear_opportunities() -> void:
	if opportunity_timer != null:
		opportunity_timer.stop()
	if opportunity_container != null:
		for child in opportunity_container.get_children():
			if child.has_method("destroy_pickup"):
				child.call("destroy_pickup", HeartPickup.DESTROY_REASON_CLEARED)
			elif child.has_method("set_active"):
				child.set_active(false)
				child.queue_free()
			else:
				child.queue_free()

	active_heart_runner = null
	active_heart_pickup = null


func _clear_transient_effects() -> void:
	if effect_container == null:
		return

	for effect in effect_container.get_children():
		effect.queue_free()


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
	_advance_music_track_for_new_run()
	_reset_runtime_state()
	_start_background_music(true)


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


func _load_player_action_sfx_variants() -> void:
	throw_sfx_variants = _load_audio_stream_pool(THROW_SFX_PATHS, throw_player.stream)
	dodge_sfx_variants = _load_audio_stream_pool(DODGE_SFX_PATHS, dodge_player.stream)
	hurt_sfx_variants = _load_audio_stream_pool(HURT_SFX_PATHS, player_hurt_player.stream)


func _load_audio_stream_pool(paths: Array[String], fallback_stream: AudioStream) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			streams.append(stream)

	if streams.is_empty() and fallback_stream != null:
		streams.append(fallback_stream)
	return streams


func _play_player_action_sfx(action_category: StringName) -> void:
	var audio_player: AudioStreamPlayer
	var variants: Array[AudioStream]
	match action_category:
		PLAYER_ACTION_THROW:
			audio_player = throw_player
			variants = throw_sfx_variants
		PLAYER_ACTION_DODGE:
			audio_player = dodge_player
			variants = dodge_sfx_variants
		PLAYER_ACTION_HURT:
			audio_player = player_hurt_player
			variants = hurt_sfx_variants
		_:
			return

	var variant_index := _select_player_action_sfx_index(action_category, variants.size())
	if variant_index < 0:
		return
	audio_player.stream = variants[variant_index]
	_play_sfx(audio_player)


func _select_player_action_sfx_index(action_category: StringName, pool_size: int) -> int:
	if pool_size <= 0:
		return -1

	var last_index := _get_last_player_action_sfx_index(action_category)
	var selected_index := audio_rng.randi_range(0, pool_size - 1)
	if pool_size > 1 and selected_index == last_index:
		selected_index = (selected_index + 1 + audio_rng.randi_range(0, pool_size - 2)) % pool_size
	_set_last_player_action_sfx_index(action_category, selected_index)
	return selected_index


func _get_last_player_action_sfx_index(action_category: StringName) -> int:
	match action_category:
		PLAYER_ACTION_THROW:
			return last_throw_sfx_index
		PLAYER_ACTION_DODGE:
			return last_dodge_sfx_index
		PLAYER_ACTION_HURT:
			return last_hurt_sfx_index
	return -1


func _set_last_player_action_sfx_index(action_category: StringName, selected_index: int) -> void:
	match action_category:
		PLAYER_ACTION_THROW:
			last_throw_sfx_index = selected_index
		PLAYER_ACTION_DODGE:
			last_dodge_sfx_index = selected_index
		PLAYER_ACTION_HURT:
			last_hurt_sfx_index = selected_index


func _stop_player_action_sfx() -> void:
	for audio_player in [throw_player, dodge_player, player_hurt_player]:
		if audio_player != null:
			audio_player.stop()


func _spawn_boomer_blast_effect(position: Vector2, core_radius: float, outer_radius: float) -> void:
	var blast_effect := BoomerBlastEffectScene.instantiate() as BoomerBlastEffect
	if blast_effect == null:
		return

	effect_container.add_child(blast_effect)
	blast_effect.global_position = position
	blast_effect.setup(core_radius, outer_radius)


func _start_background_music(restart_from_beginning := false) -> void:
	if music_player == null:
		return

	music_player.stream = _load_music_stream_or_fallback(
		MUSIC_TRACK_PATHS[current_music_track_index]
	)
	if music_player.stream == null:
		return

	if not music_player.finished.is_connected(_on_music_player_finished):
		music_player.finished.connect(_on_music_player_finished)

	if restart_from_beginning:
		music_player.stop()
	if not music_player.playing:
		music_player.play()


func _advance_music_track_for_new_run() -> void:
	if MUSIC_TRACK_PATHS.is_empty():
		current_music_track_index = 0
		return
	current_music_track_index = (current_music_track_index + 1) % MUSIC_TRACK_PATHS.size()


func _load_music_stream_or_fallback(track_path: String) -> AudioStream:
	if ResourceLoader.exists(track_path):
		var selected_stream := load(track_path) as AudioStream
		if selected_stream != null:
			return selected_stream
	return original_music_stream


func _on_music_player_finished() -> void:
	if music_player == null or music_player.stream == null:
		return

	music_player.play()


func debug_seed_audio_rng(seed_value: int) -> void:
	audio_rng.seed = seed_value
	last_throw_sfx_index = -1
	last_dodge_sfx_index = -1
	last_hurt_sfx_index = -1


func debug_select_player_action_sfx_index(action_category: StringName) -> int:
	match action_category:
		PLAYER_ACTION_THROW:
			return _select_player_action_sfx_index(action_category, throw_sfx_variants.size())
		PLAYER_ACTION_DODGE:
			return _select_player_action_sfx_index(action_category, dodge_sfx_variants.size())
		PLAYER_ACTION_HURT:
			return _select_player_action_sfx_index(action_category, hurt_sfx_variants.size())
	return -1


func debug_get_last_player_action_sfx_index(action_category: StringName) -> int:
	return _get_last_player_action_sfx_index(action_category)


func debug_get_player_action_sfx_pool_size(action_category: StringName) -> int:
	match action_category:
		PLAYER_ACTION_THROW:
			return throw_sfx_variants.size()
		PLAYER_ACTION_DODGE:
			return dodge_sfx_variants.size()
		PLAYER_ACTION_HURT:
			return hurt_sfx_variants.size()
	return 0


func debug_get_current_music_track_index() -> int:
	return current_music_track_index


func debug_get_current_music_stream_path() -> String:
	if music_player == null or music_player.stream == null:
		return ""
	return music_player.stream.resource_path


func debug_load_music_stream_for_path(track_path: String) -> AudioStream:
	return _load_music_stream_or_fallback(track_path)


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
		shield_break_player,
		blowgun_windup_player,
		blowgun_fire_player,
		blowgun_shove_player,
		boomer_hop_prep_player,
		boomer_land_player,
		boomer_fuse_player,
		boomer_explosion_player,
		heart_runner_appear_player,
		heart_runner_alarm_player,
		heart_pickup_spawn_player,
		heart_pickup_collect_player,
		heart_pickup_expire_player,
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
		shield_break_player,
		blowgun_windup_player,
		blowgun_fire_player,
		blowgun_shove_player,
		boomer_hop_prep_player,
		boomer_land_player,
		boomer_fuse_player,
		boomer_explosion_player,
		heart_runner_appear_player,
		heart_runner_alarm_player,
		heart_pickup_spawn_player,
		heart_pickup_collect_player,
		heart_pickup_expire_player,
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
	_add_key_action("debug_spawn_shielded", KEY_1)
	_add_key_action("debug_spawn_shooter", KEY_2)
	_add_key_action("debug_spawn_boomer", KEY_3)
	_add_key_action("debug_spawn_heart_runner", KEY_4)
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
	return player.get_space_dodge_direction()
