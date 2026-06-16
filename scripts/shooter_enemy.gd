extends Enemy
class_name ShooterEnemy

signal aim_started
signal dart_requested(spawn_position: Vector2, fire_direction: Vector2, burst_id: int, dart_index: int)
signal shove_used

enum ShooterState {
	REPOSITION,
	AIM,
	LOCKED,
	FIRE,
	RECOVER,
	ARC_REPOSITION,
	AIM_CANCEL_REPOSITION,
	SHOVE_WINDUP,
	SHOVE_ACTIVE,
	SHOVE_RECOVER,
}

@export var movement_speed_scale := 0.90
@export var approach_speed_scale := 1.0
@export var retreat_speed_scale := 1.15
@export var lateral_fallback_speed_scale := 0.8
@export var preferred_distance_min := 82.0
@export var preferred_distance_max := 118.0
@export var retreat_distance := 58.0
@export var resume_after_retreat_distance := 72.0
@export var attack_range_max := 126.0
@export var distance_dead_zone := 6.0
@export var direction_change_cooldown := 0.35
@export var wall_fallback_commit_duration := 0.45
@export var first_attack_delay_min := 1.0
@export var first_attack_delay_max := 1.6
@export var aim_duration := 0.48
@export var locked_duration := 0.24
@export var burst_interval := 0.17
@export var recover_duration := 0.16
@export var attack_cooldown := 0.95
@export var minimum_dart_interval := 2.4
@export var aim_retry_delay := 0.18
@export var aim_cancel_min_distance := 74.0
@export var aim_cancel_max_distance := 134.0
@export var aim_cancel_reposition_duration := 0.55
@export var aim_cancel_reposition_speed_scale := 1.12
@export var aim_cancel_reposition_sample_distance := 40.0
@export var aim_cancel_reposition_radial_correction_strength := 0.22
@export var arc_reposition_duration := 1.10
@export var arc_reposition_speed_scale := 1.35
@export var arc_reposition_side_sample_distance := 60.0
@export var arc_radial_correction_strength := 0.28
@export var shove_trigger_distance := 20.0
@export var shove_windup_duration := 0.20
@export var shove_active_duration := 0.08
@export var shove_recover_duration := 0.18
@export var shove_knockback_distance := 26.0
@export var shove_knockback_duration := 0.18
@export var shove_cooldown := 2.10
@export var shove_hit_radius := 11.0
@export var shove_hit_offset := 13.0
@export var blowgun_length := 17.0
@export var blowgun_color := Color8(132, 101, 58)
@export var blowgun_tip_color := Color8(220, 206, 158)
@export var aim_line_color := Color8(232, 221, 170, 135)
@export var locked_line_color := Color8(255, 236, 176, 210)
@export var release_puff_color := Color8(222, 218, 184, 120)

var shooter_state: ShooterState = ShooterState.REPOSITION
var state_time_left := 0.0
var first_attack_delay_left := 0.0
var attack_cooldown_left := 0.0
var minimum_dart_interval_left := 0.0
var aim_retry_left := 0.0
var shove_cooldown_left := 0.0
var direction_change_left := 0.0
var wall_fallback_left := 0.0
var wall_fallback_direction := Vector2.ZERO
var arc_reposition_left := 0.0
var arc_reposition_side := 1
var arc_reposition_reversed_for_wall := false
var last_blocked_arc_side := 0
var aim_cancel_reposition_side := 1
var aim_cancel_reposition_reversed_for_wall := false
var last_blocked_cancel_side := 0
var aim_direction := Vector2.RIGHT
var locked_direction := Vector2.RIGHT
var shove_direction := Vector2.RIGHT
var burst_shots_fired := 0
var burst_sequence := 0
var active_burst_id := 0
var facing_direction := 1
var is_retreating := false
var shove_has_attempted_hit := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	rng.randomize()
	first_attack_delay_left = rng.randf_range(first_attack_delay_min, first_attack_delay_max)
	_enter_reposition_state(false)


func setup(player_ref: Player, new_arena_rect: Rect2, starting_speed: float) -> void:
	super.setup(player_ref, new_arena_rect, starting_speed * movement_speed_scale)


func set_active(is_active: bool) -> void:
	super.set_active(is_active)
	if not is_active:
		_clear_attack_state()


func _physics_process(delta: float) -> void:
	visual_time += delta
	_update_shooter_timers(delta)

	if _update_effect_timers(delta):
		_update_sprite_visuals()
		return

	if _can_run_behavior():
		match shooter_state:
			ShooterState.REPOSITION:
				_process_reposition_state(delta)
			ShooterState.AIM:
				_process_aim_state(delta)
			ShooterState.LOCKED:
				_process_locked_state(delta)
			ShooterState.FIRE:
				_process_fire_state(delta)
			ShooterState.RECOVER:
				_process_recover_state(delta)
			ShooterState.ARC_REPOSITION:
				_process_arc_reposition_state(delta)
			ShooterState.AIM_CANCEL_REPOSITION:
				_process_aim_cancel_reposition_state(delta)
			ShooterState.SHOVE_WINDUP:
				_process_shove_windup_state(delta)
			ShooterState.SHOVE_ACTIVE:
				_process_shove_active_state(delta)
			ShooterState.SHOVE_RECOVER:
				_process_shove_recover_state(delta)

		_try_contact_damage()
	else:
		velocity = Vector2.ZERO

	_update_sprite_visuals()
	queue_redraw()


func _update_shooter_timers(delta: float) -> void:
	first_attack_delay_left = maxf(first_attack_delay_left - delta, 0.0)
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	minimum_dart_interval_left = maxf(minimum_dart_interval_left - delta, 0.0)
	aim_retry_left = maxf(aim_retry_left - delta, 0.0)
	shove_cooldown_left = maxf(shove_cooldown_left - delta, 0.0)
	direction_change_left = maxf(direction_change_left - delta, 0.0)
	wall_fallback_left = maxf(wall_fallback_left - delta, 0.0)
	arc_reposition_left = maxf(arc_reposition_left - delta, 0.0)


func _process_reposition_state(delta: float) -> void:
	var distance_to_player := _get_distance_to_player()
	if _should_start_shove(distance_to_player):
		_enter_shove_windup_state()
		return
	if _can_begin_attack(distance_to_player):
		_enter_aim_state()
		return

	_move_with_velocity(_get_reposition_velocity(delta, distance_to_player))


func _process_aim_state(delta: float) -> void:
	var distance_to_player := _get_distance_to_player()
	if _should_start_shove(distance_to_player):
		_enter_shove_windup_state()
		return
	if distance_to_player < aim_cancel_min_distance:
		aim_retry_left = maxf(aim_retry_left, aim_retry_delay)
		_enter_reposition_state(false)
		_move_with_velocity(_get_reposition_velocity(delta, distance_to_player))
		return
	if distance_to_player > aim_cancel_max_distance:
		_enter_aim_cancel_reposition_state()
		return

	var current_direction := _get_direction_to_player()
	if current_direction == Vector2.ZERO:
		_enter_aim_cancel_reposition_state()
		return

	aim_direction = current_direction
	_update_facing_from_direction(aim_direction)
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_locked_state()


func _process_locked_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_fire_state()


func _process_fire_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		if burst_shots_fired < 2:
			_fire_burst_dart()
			if burst_shots_fired < 2:
				state_time_left = burst_interval
				return
		_enter_recover_state()


func _process_recover_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_arc_reposition_state()


func _process_arc_reposition_state(delta: float) -> void:
	var distance_to_player := _get_distance_to_player()
	if distance_to_player <= retreat_distance:
		arc_reposition_left = 0.0
		_enter_reposition_state(false)
		_move_with_velocity(_get_reposition_velocity(delta, distance_to_player))
		return
	if arc_reposition_left == 0.0:
		_enter_reposition_state(false)
		return

	_move_with_velocity(_get_arc_reposition_velocity(delta, distance_to_player))


func _process_aim_cancel_reposition_state(delta: float) -> void:
	var distance_to_player := _get_distance_to_player()
	if _should_start_shove(distance_to_player):
		_enter_shove_windup_state()
		return
	if distance_to_player <= retreat_distance:
		_enter_reposition_state(false)
		_move_with_velocity(_get_reposition_velocity(delta, distance_to_player))
		return

	state_time_left = maxf(state_time_left - delta, 0.0)
	_move_with_velocity(_get_aim_cancel_reposition_velocity(delta, distance_to_player))
	if state_time_left == 0.0:
		_enter_reposition_state(false)


func _process_shove_windup_state(delta: float) -> void:
	var current_direction := _get_direction_to_player()
	if current_direction != Vector2.ZERO:
		shove_direction = current_direction
		_update_facing_from_direction(shove_direction)

	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_shove_active_state()


func _process_shove_active_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_shove_recover_state()


func _process_shove_recover_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left > 0.0:
		return

	var distance_to_player := _get_distance_to_player()
	if distance_to_player <= retreat_distance:
		_enter_reposition_state(false)
		return
	_enter_arc_reposition_state()


func _get_reposition_velocity(delta: float, distance_to_player: float) -> Vector2:
	var to_player := Vector2.ZERO
	if player != null:
		to_player = player.global_position - global_position

	var direction := Vector2.ZERO
	var speed_scale := 0.0
	is_retreating = false

	if wall_fallback_left > 0.0 and wall_fallback_direction != Vector2.ZERO:
		direction = wall_fallback_direction
		speed_scale = lateral_fallback_speed_scale
	elif distance_to_player <= retreat_distance:
		direction = -to_player.normalized()
		speed_scale = retreat_speed_scale
		is_retreating = true
	elif distance_to_player < preferred_distance_min - distance_dead_zone:
		direction = -to_player.normalized()
		speed_scale = retreat_speed_scale * 0.85
		is_retreating = true
	elif distance_to_player > preferred_distance_max + distance_dead_zone:
		direction = to_player.normalized()
		speed_scale = approach_speed_scale

	var desired_velocity := direction * move_speed * speed_scale
	if direction != Vector2.ZERO and is_retreating and _motion_would_leave_arena(desired_velocity, delta):
		_begin_wall_fallback(to_player)
		desired_velocity = wall_fallback_direction * move_speed * lateral_fallback_speed_scale

	if not is_retreating:
		desired_velocity += _get_separation_push()
	else:
		desired_velocity += _get_separation_push() * 0.25

	var speed_limit := move_speed * maxf(retreat_speed_scale, approach_speed_scale)
	if desired_velocity.length() > speed_limit:
		desired_velocity = desired_velocity.normalized() * speed_limit

	if desired_velocity.length_squared() > 0.01:
		_update_facing_from_direction(desired_velocity.normalized())

	return desired_velocity


func _get_arc_reposition_velocity(delta: float, distance_to_player: float) -> Vector2:
	if player == null:
		return Vector2.ZERO

	var from_player := global_position - player.global_position
	if from_player.length_squared() <= 0.001:
		from_player = Vector2.RIGHT

	var radial_direction := from_player.normalized()
	var tangent_direction := Vector2(-radial_direction.y, radial_direction.x).normalized()
	tangent_direction *= float(arc_reposition_side)

	var radial_correction := _get_radial_correction(distance_to_player, radial_direction, arc_radial_correction_strength)
	var desired_direction := (tangent_direction + radial_correction).normalized()
	var desired_velocity := desired_direction * move_speed * arc_reposition_speed_scale

	if _motion_would_leave_arena(desired_velocity, delta) and not arc_reposition_reversed_for_wall:
		last_blocked_arc_side = arc_reposition_side
		arc_reposition_side *= -1
		arc_reposition_reversed_for_wall = true
		tangent_direction = -tangent_direction
		desired_direction = (tangent_direction + radial_correction).normalized()
		desired_velocity = desired_direction * move_speed * arc_reposition_speed_scale

	desired_velocity += _get_separation_push() * 0.2
	var speed_limit := move_speed * maxf(
	retreat_speed_scale,
	maxf(approach_speed_scale, arc_reposition_speed_scale)
)
	if desired_velocity.length() > speed_limit:
		desired_velocity = desired_velocity.normalized() * speed_limit

	if desired_velocity.length_squared() > 0.01:
		_update_facing_from_direction(desired_velocity.normalized())

	return desired_velocity


func _get_aim_cancel_reposition_velocity(delta: float, distance_to_player: float) -> Vector2:
	if player == null:
		return Vector2.ZERO

	var from_player := global_position - player.global_position
	if from_player.length_squared() <= 0.001:
		from_player = Vector2.RIGHT

	var radial_direction := from_player.normalized()
	var tangent_direction := Vector2(-radial_direction.y, radial_direction.x).normalized()
	tangent_direction *= float(aim_cancel_reposition_side)

	var radial_correction := _get_radial_correction(
		distance_to_player,
		radial_direction,
		aim_cancel_reposition_radial_correction_strength
	)
	var desired_direction := (tangent_direction + radial_correction).normalized()
	var desired_velocity := desired_direction * move_speed * aim_cancel_reposition_speed_scale

	if _motion_would_leave_arena(desired_velocity, delta) and not aim_cancel_reposition_reversed_for_wall:
		last_blocked_cancel_side = aim_cancel_reposition_side
		aim_cancel_reposition_side *= -1
		aim_cancel_reposition_reversed_for_wall = true
		tangent_direction = -tangent_direction
		desired_direction = (tangent_direction + radial_correction).normalized()
		desired_velocity = desired_direction * move_speed * aim_cancel_reposition_speed_scale

	desired_velocity += _get_separation_push() * 0.15
	var speed_limit := move_speed * maxf(
	retreat_speed_scale,
	maxf(approach_speed_scale, aim_cancel_reposition_speed_scale)
)  
	if desired_velocity.length() > speed_limit:
		desired_velocity = desired_velocity.normalized() * speed_limit

	if desired_velocity.length_squared() > 0.01:
		_update_facing_from_direction(desired_velocity.normalized())

	return desired_velocity


func _get_radial_correction(distance_to_player: float, radial_direction: Vector2, correction_strength: float) -> Vector2:
	if distance_to_player < preferred_distance_min:
		return radial_direction * correction_strength
	if distance_to_player > preferred_distance_max:
		return -radial_direction * correction_strength
	return Vector2.ZERO


func _begin_wall_fallback(to_player: Vector2) -> void:
	if direction_change_left > 0.0:
		return

	var away_from_player := -to_player.normalized()
	if away_from_player == Vector2.ZERO:
		away_from_player = Vector2.RIGHT

	var tangent_a := Vector2(-away_from_player.y, away_from_player.x).normalized()
	var tangent_b := -tangent_a
	if _score_lateral_direction(tangent_b) > _score_lateral_direction(tangent_a):
		wall_fallback_direction = tangent_b
	else:
		wall_fallback_direction = tangent_a

	wall_fallback_left = wall_fallback_commit_duration
	direction_change_left = direction_change_cooldown


func _score_lateral_direction(test_direction: Vector2, sample_distance: float = 24.0) -> float:
	if arena_rect.size == Vector2.ZERO:
		return 0.0

	var test_position := global_position + test_direction * sample_distance
	var clamped_position := _clamp_position_to_arena(test_position)
	var clipping_penalty := test_position.distance_to(clamped_position) * 4.0
	var player_distance_bonus := 0.0
	if player != null:
		player_distance_bonus = clamped_position.distance_to(player.global_position) * 0.05

	return 100.0 - clipping_penalty + player_distance_bonus


func _motion_would_leave_arena(desired_velocity: Vector2, delta: float) -> bool:
	if arena_rect.size == Vector2.ZERO or desired_velocity == Vector2.ZERO:
		return false

	var target_position := global_position + desired_velocity * delta
	var clamped_position := _clamp_position_to_arena(target_position)
	return target_position.distance_to(clamped_position) > 0.25


func _can_begin_attack(distance_to_player: float) -> bool:
	return (
		first_attack_delay_left == 0.0
		and attack_cooldown_left == 0.0
		and minimum_dart_interval_left == 0.0
		and aim_retry_left == 0.0
		and distance_to_player >= preferred_distance_min
		and distance_to_player <= attack_range_max
	)


func _should_start_shove(distance_to_player: float) -> bool:
	return shove_cooldown_left == 0.0 and distance_to_player <= shove_trigger_distance


func _enter_reposition_state(start_cooldown: bool) -> void:
	shooter_state = ShooterState.REPOSITION
	state_time_left = 0.0
	burst_shots_fired = 0
	shove_has_attempted_hit = false
	if start_cooldown:
		attack_cooldown_left = attack_cooldown


func _enter_aim_state() -> void:
	shooter_state = ShooterState.AIM
	state_time_left = aim_duration
	aim_direction = _get_direction_to_player()
	if aim_direction == Vector2.ZERO:
		aim_direction = locked_direction
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	_update_facing_from_direction(aim_direction)
	aim_started.emit()


func _enter_locked_state() -> void:
	shooter_state = ShooterState.LOCKED
	state_time_left = locked_duration
	locked_direction = aim_direction
	if locked_direction == Vector2.ZERO:
		locked_direction = Vector2.RIGHT
	_update_facing_from_direction(locked_direction)


func _enter_fire_state() -> void:
	shooter_state = ShooterState.FIRE
	state_time_left = burst_interval
	burst_shots_fired = 0
	active_burst_id = _get_next_burst_id()
	velocity = Vector2.ZERO
	_fire_burst_dart()


func _enter_recover_state() -> void:
	shooter_state = ShooterState.RECOVER
	state_time_left = recover_duration
	attack_cooldown_left = attack_cooldown
	velocity = Vector2.ZERO


func _enter_arc_reposition_state() -> void:
	shooter_state = ShooterState.ARC_REPOSITION
	state_time_left = 0.0
	burst_shots_fired = 0
	arc_reposition_left = arc_reposition_duration
	arc_reposition_reversed_for_wall = false
	arc_reposition_side = _choose_arc_reposition_side()
	velocity = Vector2.ZERO


func _enter_aim_cancel_reposition_state() -> void:
	shooter_state = ShooterState.AIM_CANCEL_REPOSITION
	state_time_left = aim_cancel_reposition_duration
	aim_retry_left = maxf(aim_retry_left, aim_retry_delay)
	aim_cancel_reposition_reversed_for_wall = false
	aim_cancel_reposition_side = _choose_cancel_reposition_side()
	velocity = Vector2.ZERO


func _enter_shove_windup_state() -> void:
	shooter_state = ShooterState.SHOVE_WINDUP
	state_time_left = shove_windup_duration
	aim_retry_left = maxf(aim_retry_left, aim_retry_delay)
	shove_has_attempted_hit = false
	shove_direction = _get_direction_to_player()
	if shove_direction == Vector2.ZERO:
		shove_direction = Vector2(float(facing_direction), 0.0)
	_update_facing_from_direction(shove_direction)
	velocity = Vector2.ZERO


func _enter_shove_active_state() -> void:
	shooter_state = ShooterState.SHOVE_ACTIVE
	state_time_left = shove_active_duration
	shove_cooldown_left = shove_cooldown
	velocity = Vector2.ZERO
	shove_used.emit()
	_perform_shove_hit_check()


func _enter_shove_recover_state() -> void:
	shooter_state = ShooterState.SHOVE_RECOVER
	state_time_left = shove_recover_duration
	velocity = Vector2.ZERO


func _perform_shove_hit_check() -> void:
	if shove_has_attempted_hit:
		return

	shove_has_attempted_hit = true
	if player == null or not player.is_alive():
		return

	var hit_center := global_position + shove_direction.normalized() * shove_hit_offset
	var hit_distance := player.global_position.distance_to(hit_center)
	if hit_distance > shove_hit_radius + player.body_radius:
		return

	player.try_start_forced_movement(
		shove_direction,
		shove_knockback_distance,
		shove_knockback_duration
	)


func _fire_burst_dart() -> void:
	if burst_shots_fired >= 2:
		return
	if not active or is_dying or player == null or not player.is_alive():
		return

	var dart_index := burst_shots_fired
	burst_shots_fired += 1
	if burst_shots_fired == 1:
		minimum_dart_interval_left = minimum_dart_interval

	dart_requested.emit(_get_dart_spawn_position(), locked_direction, active_burst_id, dart_index)


func _get_next_burst_id() -> int:
	burst_sequence += 1
	return int(get_instance_id()) * 100000 + burst_sequence


func _choose_arc_reposition_side() -> int:
	var random_side := 1 if rng.randf() >= 0.5 else -1
	var alternate_side := -random_side
	if random_side == last_blocked_arc_side:
		random_side = alternate_side

	var random_score := _score_arc_side(random_side)
	var alternate_score := _score_arc_side(alternate_side)
	if alternate_score > random_score + 4.0:
		return alternate_side
	return random_side


func _score_arc_side(side: int) -> float:
	if player == null:
		return 0.0

	var from_player := global_position - player.global_position
	if from_player.length_squared() <= 0.001:
		from_player = Vector2.RIGHT
	var tangent := Vector2(-from_player.y, from_player.x).normalized() * float(side)
	return _score_lateral_direction(tangent, arc_reposition_side_sample_distance)


func _choose_cancel_reposition_side() -> int:
	var random_side := 1 if rng.randf() >= 0.5 else -1
	var alternate_side := -random_side
	if random_side == last_blocked_cancel_side:
		random_side = alternate_side

	var random_score := _score_cancel_side(random_side)
	var alternate_score := _score_cancel_side(alternate_side)
	if alternate_score > random_score + 4.0:
		return alternate_side
	return random_side


func _score_cancel_side(side: int) -> float:
	if player == null:
		return 0.0

	var from_player := global_position - player.global_position
	if from_player.length_squared() <= 0.001:
		from_player = Vector2.RIGHT
	var tangent := Vector2(-from_player.y, from_player.x).normalized() * float(side)
	return _score_lateral_direction(tangent, aim_cancel_reposition_sample_distance)


func _clear_attack_state() -> void:
	shooter_state = ShooterState.REPOSITION
	state_time_left = 0.0
	attack_cooldown_left = 0.0
	minimum_dart_interval_left = 0.0
	aim_retry_left = 0.0
	shove_cooldown_left = 0.0
	wall_fallback_left = 0.0
	wall_fallback_direction = Vector2.ZERO
	arc_reposition_left = 0.0
	arc_reposition_side = 1
	arc_reposition_reversed_for_wall = false
	aim_cancel_reposition_side = 1
	aim_cancel_reposition_reversed_for_wall = false
	burst_shots_fired = 0
	active_burst_id = 0
	shove_has_attempted_hit = false
	velocity = Vector2.ZERO
	queue_redraw()


func _get_distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)


func _get_dart_spawn_position() -> Vector2:
	var fire_direction := locked_direction
	if fire_direction == Vector2.ZERO:
		fire_direction = Vector2.RIGHT
	return _clamp_position_to_arena(global_position + fire_direction * (body_radius + blowgun_length - 2.0))


func _clamp_position_to_arena(target_position: Vector2) -> Vector2:
	if arena_rect.size == Vector2.ZERO:
		return target_position

	return Vector2(
		clamp(target_position.x, arena_rect.position.x + body_radius, arena_rect.end.x - body_radius),
		clamp(target_position.y, arena_rect.position.y + body_radius, arena_rect.end.y - body_radius)
	)


func _update_facing_from_direction(direction: Vector2) -> void:
	if direction.x > 0.08:
		facing_direction = 1
	elif direction.x < -0.08:
		facing_direction = -1


func _try_contact_damage() -> void:
	return


func _draw_alive_body(fill_color: Color) -> void:
	super._draw_alive_body(fill_color)
	_draw_blowgun()
	_draw_attack_cue()


func _draw_blowgun() -> void:
	var draw_offset := _get_visual_offset()
	var visual_direction := _get_visual_aim_direction()
	var side_offset := Vector2(-visual_direction.y, visual_direction.x) * -1.0
	var start_point := draw_offset + visual_direction * 3.0 + side_offset
	var end_point := start_point + visual_direction * blowgun_length

	draw_line(start_point + Vector2(0.0, 1.0), end_point + Vector2(0.0, 1.0), Color(0.0, 0.0, 0.0, 0.22), 3.0)
	draw_line(start_point, end_point, blowgun_color, 3.0)
	draw_line(end_point - visual_direction * 2.0, end_point, blowgun_tip_color, 2.0)


func _draw_attack_cue() -> void:
	if shooter_state != ShooterState.AIM and shooter_state != ShooterState.LOCKED and shooter_state != ShooterState.FIRE:
		return

	var draw_offset := _get_visual_offset()
	var visual_direction := _get_visual_aim_direction()
	var cue_color := aim_line_color
	var cue_length := 20.0
	if shooter_state == ShooterState.LOCKED or shooter_state == ShooterState.FIRE:
		cue_color = locked_line_color
		cue_length = 26.0

	var cue_start := draw_offset + visual_direction * 9.0
	var cue_end := cue_start + visual_direction * cue_length
	draw_line(cue_start, cue_end, cue_color, 1.0)
	if shooter_state == ShooterState.FIRE:
		var puff_center := cue_start + visual_direction * 10.0
		draw_circle(puff_center, 2.5, release_puff_color)


func _get_visual_aim_direction() -> Vector2:
	if shooter_state == ShooterState.AIM:
		return aim_direction.normalized()
	if shooter_state == ShooterState.LOCKED or shooter_state == ShooterState.FIRE:
		return locked_direction.normalized()
	if shooter_state == ShooterState.SHOVE_WINDUP or shooter_state == ShooterState.SHOVE_ACTIVE or shooter_state == ShooterState.SHOVE_RECOVER:
		return shove_direction.normalized()

	return Vector2(float(facing_direction), 0.28).normalized()


func _get_visual_offset() -> Vector2:
	var base_offset := super._get_visual_offset()
	var visual_direction := _get_visual_aim_direction()

	match shooter_state:
		ShooterState.AIM:
			base_offset -= visual_direction * 1.0
		ShooterState.LOCKED:
			base_offset -= visual_direction * 0.5
		ShooterState.FIRE:
			base_offset -= visual_direction * 2.0
		ShooterState.SHOVE_WINDUP:
			base_offset -= visual_direction * 1.2
		ShooterState.SHOVE_ACTIVE:
			base_offset += visual_direction * 1.6
		ShooterState.SHOVE_RECOVER:
			base_offset -= visual_direction * 0.8
		_:
			if velocity.length_squared() > 1.0:
				base_offset += velocity.normalized() * 1.0

	return base_offset.round()


func _get_visual_scale() -> Vector2:
	match shooter_state:
		ShooterState.AIM:
			return Vector2(1.08, 0.92)
		ShooterState.FIRE:
			return Vector2(0.96, 1.04)
		ShooterState.SHOVE_WINDUP:
			return Vector2(1.05, 0.95)
		ShooterState.SHOVE_ACTIVE:
			return Vector2(0.92, 1.08)
	return Vector2.ONE


func _update_sprite_visuals() -> void:
	super._update_sprite_visuals()
	if sprite != null and sprite.visible:
		sprite.flip_h = facing_direction < 0
