extends Enemy
class_name ProwlerEnemy

signal state_changed(new_state: int)

enum ProwlerState {
	STALK,
	ALERT,
	HUNT,
}

@export var stalk_speed_scale := 0.82
@export var hunt_speed_scale := 1.48
@export var unarmed_alert_delay := 0.14
@export var alert_snap_duration := 0.10
@export var stalk_distance_min := 72.0
@export var stalk_distance_max := 104.0
@export var stalk_dead_zone := 5.0
@export var stalk_lateral_commit_duration := 0.55
@export var wall_fallback_commit_duration := 0.35
@export var band_radial_correction_strength := 0.35
@export var hunt_visual_lean := 1.0

var prowler_state: ProwlerState = ProwlerState.STALK
var tracked_spear: Spear
var base_behavior_speed := 42.0
var alert_time_left := 0.0
var alert_snap_left := 0.0
var lateral_commit_left := 0.0
var lateral_side := 1
var wall_fallback_left := 0.0
var wall_fallback_direction := Vector2.ZERO
var tracked_spear_is_held := true
var facing_left := false


func _ready() -> void:
	super._ready()
	_set_prowler_state(ProwlerState.STALK)


func setup(player_ref: Player, new_arena_rect: Rect2, starting_speed: float) -> void:
	super.setup(player_ref, new_arena_rect, starting_speed)
	base_behavior_speed = starting_speed


func set_active(is_active: bool) -> void:
	super.set_active(is_active)
	if not is_active:
		alert_time_left = 0.0
		alert_snap_left = 0.0
		velocity = Vector2.ZERO


func set_tracked_spear(new_tracked_spear: Spear) -> void:
	if tracked_spear == new_tracked_spear:
		return

	_disconnect_spear_state_signal()
	tracked_spear = new_tracked_spear
	_connect_spear_state_signal()
	_apply_spear_state_immediately()


func get_state_name() -> String:
	match prowler_state:
		ProwlerState.STALK:
			return "STALK"
		ProwlerState.ALERT:
			return "ALERT"
		ProwlerState.HUNT:
			return "HUNT"
	return "UNKNOWN"


func _exit_tree() -> void:
	_disconnect_spear_state_signal()


func _process_alive_behavior(delta: float) -> void:
	alert_snap_left = maxf(alert_snap_left - delta, 0.0)

	match prowler_state:
		ProwlerState.STALK:
			_process_stalk_state(delta)
		ProwlerState.ALERT:
			_process_alert_state(delta)
		ProwlerState.HUNT:
			_process_hunt_state()

	_try_contact_damage()


func _process_stalk_state(delta: float) -> void:
	var distance_to_player := _get_distance_to_player()
	if distance_to_player < 0.0:
		velocity = Vector2.ZERO
		return

	var stalk_speed := base_behavior_speed * stalk_speed_scale
	var direction_to_player := _get_direction_to_player()
	if direction_to_player == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	wall_fallback_left = maxf(wall_fallback_left - delta, 0.0)
	if wall_fallback_left == 0.0:
		wall_fallback_direction = Vector2.ZERO

	if distance_to_player > stalk_distance_max + stalk_dead_zone:
		lateral_commit_left = 0.0
		_move_with_velocity(_build_velocity_from_direction(direction_to_player, stalk_speed))
		_update_facing_from_reference(velocity if velocity != Vector2.ZERO else direction_to_player)
		return

	if distance_to_player < stalk_distance_min - stalk_dead_zone:
		lateral_commit_left = 0.0
		_move_with_velocity(_build_velocity_from_direction(-direction_to_player, stalk_speed))
		_update_facing_from_reference(velocity if velocity != Vector2.ZERO else -direction_to_player)
		return

	lateral_commit_left = maxf(lateral_commit_left - delta, 0.0)
	if lateral_commit_left == 0.0 and wall_fallback_left == 0.0:
		_choose_lateral_commit()

	var move_direction := _get_stalk_band_direction(distance_to_player)
	if wall_fallback_left > 0.0 and wall_fallback_direction != Vector2.ZERO:
		move_direction = wall_fallback_direction
	elif _would_direction_leave_arena(move_direction, stalk_speed):
		wall_fallback_direction = _choose_wall_fallback_direction(distance_to_player)
		wall_fallback_left = wall_fallback_commit_duration
		move_direction = wall_fallback_direction

	_move_with_velocity(_build_velocity_from_direction(move_direction, stalk_speed))
	_update_facing_from_reference(velocity if velocity != Vector2.ZERO else move_direction)


func _process_alert_state(delta: float) -> void:
	alert_time_left = maxf(alert_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	var direction_to_player := _get_direction_to_player()
	if direction_to_player != Vector2.ZERO:
		_update_facing_from_reference(direction_to_player)
	if alert_time_left == 0.0:
		_enter_hunt_state()


func _process_hunt_state() -> void:
	var hunt_speed := base_behavior_speed * hunt_speed_scale
	var direction_to_player := _get_direction_to_player()
	_move_with_velocity(_build_velocity_from_direction(direction_to_player, hunt_speed))
	_update_facing_from_reference(velocity if velocity != Vector2.ZERO else direction_to_player)


func _choose_lateral_commit() -> void:
	var direction_to_player := _get_direction_to_player()
	if direction_to_player == Vector2.ZERO:
		lateral_side = 1 if int(get_instance_id()) % 2 == 0 else -1
		lateral_commit_left = stalk_lateral_commit_duration
		return

	var clockwise_direction := Vector2(direction_to_player.y, -direction_to_player.x)
	var counter_clockwise_direction := Vector2(-direction_to_player.y, direction_to_player.x)
	var clockwise_score := _score_stalk_direction(clockwise_direction)
	var counter_clockwise_score := _score_stalk_direction(counter_clockwise_direction)
	if clockwise_score > counter_clockwise_score:
		lateral_side = -1
	elif counter_clockwise_score > clockwise_score:
		lateral_side = 1
	else:
		lateral_side = 1 if int(get_instance_id()) % 2 == 0 else -1

	lateral_commit_left = stalk_lateral_commit_duration


func _get_stalk_band_direction(distance_to_player: float) -> Vector2:
	var direction_to_player := _get_direction_to_player()
	if direction_to_player == Vector2.ZERO:
		return Vector2(float(lateral_side), 0.0)

	var tangent_direction := Vector2(-direction_to_player.y, direction_to_player.x) * float(lateral_side)
	var band_center := (stalk_distance_min + stalk_distance_max) * 0.5
	var band_half_width := maxf((stalk_distance_max - stalk_distance_min) * 0.5, 1.0)
	var radial_correction := clampf(
		(distance_to_player - band_center) / band_half_width,
		-1.0,
		1.0
	)
	var move_direction := tangent_direction + direction_to_player * radial_correction * band_radial_correction_strength
	if move_direction == Vector2.ZERO:
		move_direction = tangent_direction
	if move_direction == Vector2.ZERO:
		move_direction = direction_to_player
	return move_direction.normalized()


func _score_stalk_direction(direction: Vector2) -> float:
	if direction == Vector2.ZERO or player == null:
		return -INF

	var projected_point := _clamp_point_to_arena(global_position + direction.normalized() * 18.0)
	var wall_clearance := _distance_to_nearest_wall(projected_point)
	var band_center := (stalk_distance_min + stalk_distance_max) * 0.5
	var band_distance := projected_point.distance_to(player.global_position)
	var band_penalty := absf(band_distance - band_center) * 0.6
	return wall_clearance - band_penalty


func _would_direction_leave_arena(direction: Vector2, speed: float) -> bool:
	if direction == Vector2.ZERO:
		return false

	var projected_point := global_position + direction.normalized() * maxf(speed * 0.24, 12.0)
	return projected_point.distance_to(_clamp_point_to_arena(projected_point)) > 0.1


func _choose_wall_fallback_direction(distance_to_player: float) -> Vector2:
	var horizontal_margin := 4.0
	var min_x := arena_rect.position.x + body_radius
	var max_x := arena_rect.end.x - body_radius
	var min_y := arena_rect.position.y + body_radius
	var max_y := arena_rect.end.y - body_radius
	var candidates: Array[Vector2] = []

	if global_position.x <= min_x + horizontal_margin or global_position.x >= max_x - horizontal_margin:
		candidates = [Vector2.UP, Vector2.DOWN]
	elif global_position.y <= min_y + horizontal_margin or global_position.y >= max_y - horizontal_margin:
		candidates = [Vector2.LEFT, Vector2.RIGHT]
	else:
		candidates = [
			_get_stalk_band_direction(distance_to_player),
			-_get_stalk_band_direction(distance_to_player),
		]

	var best_direction := Vector2.ZERO
	var best_score := -INF
	for candidate in candidates:
		var score := _score_stalk_direction(candidate)
		if score > best_score:
			best_score = score
			best_direction = candidate

	if best_direction == Vector2.ZERO:
		best_direction = _get_stalk_band_direction(distance_to_player)
	if best_direction == Vector2.ZERO:
		best_direction = Vector2.UP
	return best_direction.normalized()


func _build_velocity_from_direction(direction: Vector2, speed: float) -> Vector2:
	if direction == Vector2.ZERO:
		return _get_separation_push().limit_length(speed)

	var desired_velocity := direction.normalized() * speed + _get_separation_push()
	var speed_limit := speed * 1.2
	if desired_velocity.length() > speed_limit:
		desired_velocity = desired_velocity.normalized() * speed_limit
	return desired_velocity


func _get_distance_to_player() -> float:
	if player == null:
		return -1.0
	return global_position.distance_to(player.global_position)


func _update_facing_from_reference(reference: Vector2) -> void:
	if absf(reference.x) > 0.05:
		facing_left = reference.x < 0.0


func _is_tracked_spear_currently_held() -> bool:
	return tracked_spear != null and tracked_spear.state == Spear.State.HELD


func _apply_spear_state_immediately() -> void:
	tracked_spear_is_held = _is_tracked_spear_currently_held()
	if tracked_spear_is_held:
		_enter_stalk_state(true)
	else:
		_enter_alert_state()


func _connect_spear_state_signal() -> void:
	if tracked_spear == null:
		return

	var state_changed_callable := Callable(self, "_on_tracked_spear_state_changed")
	if not tracked_spear.state_changed.is_connected(state_changed_callable):
		tracked_spear.state_changed.connect(state_changed_callable)


func _disconnect_spear_state_signal() -> void:
	if tracked_spear == null:
		return

	var state_changed_callable := Callable(self, "_on_tracked_spear_state_changed")
	if tracked_spear.state_changed.is_connected(state_changed_callable):
		tracked_spear.state_changed.disconnect(state_changed_callable)


func _on_tracked_spear_state_changed(new_state: int) -> void:
	var new_is_held := new_state == Spear.State.HELD
	if new_is_held == tracked_spear_is_held:
		return

	tracked_spear_is_held = new_is_held
	if tracked_spear_is_held:
		_enter_stalk_state(true)
		return

	_enter_alert_state()


func _enter_stalk_state(reset_commit: bool) -> void:
	alert_time_left = 0.0
	alert_snap_left = 0.0
	wall_fallback_left = 0.0
	wall_fallback_direction = Vector2.ZERO
	if reset_commit:
		lateral_commit_left = 0.0
	_set_prowler_state(ProwlerState.STALK)


func _enter_alert_state() -> void:
	if prowler_state == ProwlerState.ALERT or prowler_state == ProwlerState.HUNT:
		return

	alert_time_left = unarmed_alert_delay
	alert_snap_left = alert_snap_duration
	lateral_commit_left = 0.0
	wall_fallback_left = 0.0
	wall_fallback_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.ALERT)


func _enter_hunt_state() -> void:
	alert_time_left = 0.0
	alert_snap_left = 0.0
	wall_fallback_left = 0.0
	wall_fallback_direction = Vector2.ZERO
	lateral_commit_left = 0.0
	_set_prowler_state(ProwlerState.HUNT)


func _set_prowler_state(new_state: ProwlerState) -> void:
	if prowler_state == new_state:
		return

	prowler_state = new_state
	state_changed.emit(prowler_state)


func _clamp_point_to_arena(target_position: Vector2) -> Vector2:
	if arena_rect.size == Vector2.ZERO:
		return target_position

	return Vector2(
		clamp(
			target_position.x,
			arena_rect.position.x + body_radius,
			arena_rect.end.x - body_radius
		),
		clamp(
			target_position.y,
			arena_rect.position.y + body_radius,
			arena_rect.end.y - body_radius
		)
	)


func _distance_to_nearest_wall(target_position: Vector2) -> float:
	if arena_rect.size == Vector2.ZERO:
		return 0.0

	var left_distance := target_position.x - (arena_rect.position.x + body_radius)
	var right_distance := (arena_rect.end.x - body_radius) - target_position.x
	var top_distance := target_position.y - (arena_rect.position.y + body_radius)
	var bottom_distance := (arena_rect.end.y - body_radius) - target_position.y
	return minf(minf(left_distance, right_distance), minf(top_distance, bottom_distance))


func _get_visual_offset() -> Vector2:
	var bob_speed := 4.0
	var bob_amplitude := 1.0
	var x_bias := 0.0
	var y_bias := 1.0

	match prowler_state:
		ProwlerState.ALERT:
			bob_speed = 7.0
			bob_amplitude = 1.0
			x_bias = -1.0 if facing_left else 1.0
			y_bias = -1.0
		ProwlerState.HUNT:
			bob_speed = 10.0
			bob_amplitude = 2.0
			x_bias = (-hunt_visual_lean) if facing_left else hunt_visual_lean
			y_bias = -1.0

	var bob_phase := visual_time * bob_speed + float(get_instance_id() % 17)
	var bob_offset := roundf(sin(bob_phase) * bob_amplitude)
	var base_offset := SPRITE_BASE_OFFSET + Vector2(x_bias, y_bias + bob_offset)
	if alert_snap_left > 0.0:
		base_offset += Vector2(-1.0 if facing_left else 1.0, -1.0)
	return base_offset.round()


func _get_visual_scale() -> Vector2:
	match prowler_state:
		ProwlerState.ALERT:
			return Vector2(1.06, 0.94)
		ProwlerState.HUNT:
			return Vector2(1.08, 0.92)
	return Vector2(1.02, 0.95)


func _update_sprite_visuals() -> void:
	super._update_sprite_visuals()
	if sprite != null and sprite.visible:
		sprite.flip_h = facing_left
