extends Enemy
class_name Charger

const BULLDOZE_DISPLACEMENT_SOURCE := &"charger_bulldoze"

enum State {
	CHASE,
	TELEGRAPH,
	DASH,
	RECOVER,
}

@export var chase_duration_min := 1.6
@export var chase_duration_max := 2.5
@export var telegraph_duration := 0.72
@export var dash_speed := 220.0
@export var dash_max_distance := 92.0
@export var recover_duration := 0.55
@export var bulldoze_probe_radius := 12.0
@export var bulldoze_distance := 14.0
@export var bulldoze_duration := 0.12
@export var telegraph_color := Color8(247, 222, 158)
@export var dash_color := Color8(232, 176, 102)
@export var telegraph_line_color := Color8(255, 247, 214)
@export var telegraph_line_length := 38.0
@export var telegraph_shake_strength := 1.4
@export var visible_entry_damage_sync_distance := 10.0

var state: State = State.CHASE
var state_time_left := 0.0
var dash_direction := Vector2.RIGHT
var telegraph_direction := Vector2.RIGHT
var dash_distance_travelled := 0.0
var has_visible_arena_entry := false
var _bulldozed_targets_this_dash: Dictionary = {}
var rng := RandomNumberGenerator.new()


func setup(player_ref: Player, new_arena_rect: Rect2, starting_speed: float) -> void:
	super.setup(player_ref, new_arena_rect, starting_speed)
	has_visible_arena_entry = false


func _ready() -> void:
	super._ready()
	rng.randomize()
	has_visible_arena_entry = false
	_clear_bulldoze_targets()
	_enter_chase_state()


func _physics_process(delta: float) -> void:
	visual_time += delta

	if _update_effect_timers(delta):
		_update_sprite_visuals()
		_update_visible_entry_state()
		queue_redraw()
		return

	if _can_run_behavior():
		if not _process_explosion_knockback(delta):
			match state:
				State.CHASE:
					_process_chase_state(delta)
				State.TELEGRAPH:
					_process_telegraph_state(delta)
				State.DASH:
					_process_dash_state(delta)
				State.RECOVER:
					_process_recover_state(delta)

	_update_sprite_visuals()
	_update_visible_entry_state()
	_try_contact_damage()
	queue_redraw()


func _process_chase_state(delta: float) -> void:
	state_time_left = max(state_time_left - delta, 0.0)
	_move_with_velocity(_get_chase_velocity())
	if state_time_left == 0.0:
		_enter_telegraph_state()


func _process_telegraph_state(delta: float) -> void:
	state_time_left = max(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO

	var current_direction := _get_direction_to_player()
	if current_direction != Vector2.ZERO:
		telegraph_direction = current_direction

	if state_time_left == 0.0:
		_enter_dash_state()


func _process_dash_state(_delta: float) -> void:
	var start_position := global_position
	velocity = dash_direction * dash_speed
	move_and_slide()
	var hit_wall := is_on_wall()
	_clamp_inside_arena()
	_try_bulldoze_hostiles(start_position, global_position)

	var moved_distance := start_position.distance_to(global_position)
	dash_distance_travelled += moved_distance
	if hit_wall or moved_distance <= 0.01 or dash_distance_travelled >= dash_max_distance:
		_enter_recover_state()


func _process_recover_state(delta: float) -> void:
	state_time_left = max(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_chase_state()


func _enter_chase_state() -> void:
	state = State.CHASE
	state_time_left = rng.randf_range(chase_duration_min, chase_duration_max)
	_clear_bulldoze_targets()


func _enter_telegraph_state() -> void:
	state = State.TELEGRAPH
	state_time_left = telegraph_duration
	telegraph_direction = _get_direction_to_player()
	if telegraph_direction == Vector2.ZERO:
		telegraph_direction = dash_direction


func _enter_dash_state() -> void:
	state = State.DASH
	dash_distance_travelled = 0.0
	dash_direction = telegraph_direction
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT
	_clear_bulldoze_targets()


func _enter_recover_state() -> void:
	state = State.RECOVER
	state_time_left = recover_duration
	velocity = Vector2.ZERO
	_clear_bulldoze_targets()


func apply_explosion_knockback(direction: Vector2, distance: float, duration: float) -> void:
	_enter_recover_state()
	super.apply_explosion_knockback(direction, distance, duration)


func set_active(is_active: bool) -> void:
	super.set_active(is_active)
	if not is_active:
		_clear_bulldoze_targets()


func take_spear_hit() -> void:
	_clear_bulldoze_targets()
	super.take_spear_hit()


func _exit_tree() -> void:
	_clear_bulldoze_targets()


func _clear_bulldoze_targets() -> void:
	_bulldozed_targets_this_dash.clear()


func _try_bulldoze_hostiles(segment_start: Vector2, segment_end: Vector2) -> void:
	if state != State.DASH:
		return
	if segment_start == segment_end:
		return

	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var target := enemy_node as Enemy
		if not _is_valid_bulldoze_target(target):
			continue

		var target_id := target.get_instance_id()
		if _bulldozed_targets_this_dash.has(target_id):
			continue

		var closest_point := _get_closest_point_on_segment(target.global_position, segment_start, segment_end)
		var hit_radius := bulldoze_probe_radius + target.body_radius
		if closest_point.distance_to(target.global_position) > hit_radius:
			continue

		var bulldoze_direction := _get_bulldoze_direction_for(target, segment_start, segment_end)
		if bulldoze_direction == Vector2.ZERO:
			continue

		if target.try_start_authored_hostile_displacement(
			BULLDOZE_DISPLACEMENT_SOURCE,
			bulldoze_direction,
			bulldoze_distance,
			bulldoze_duration
		):
			_bulldozed_targets_this_dash[target_id] = true


func _is_valid_bulldoze_target(target: Enemy) -> bool:
	if target == null or target == self or target.is_dying:
		return false
	if target is Charger or target is BoomerEnemy or target is ShooterEnemy or target is ProwlerEnemy:
		return false
	return target.can_accept_authored_hostile_displacement()


func _get_bulldoze_direction_for(target: Enemy, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var closest_point := _get_closest_point_on_segment(target.global_position, segment_start, segment_end)
	var away_from_path := target.global_position - closest_point
	if away_from_path.length_squared() > 0.001:
		return away_from_path.normalized()

	var away_from_charger := target.global_position - global_position
	if away_from_charger.length_squared() > 0.001:
		return away_from_charger.normalized()

	return dash_direction.orthogonal().normalized()


func _get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return segment_start

	var projection := (point - segment_start).dot(segment) / segment_length_squared
	return segment_start + segment * clampf(projection, 0.0, 1.0)


func _get_current_fill_color() -> Color:
	if hit_flash_left > 0.0:
		return hit_flash_color

	if state == State.DASH:
		return dash_color

	if state == State.TELEGRAPH:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 16.0)
		return body_color.lerp(telegraph_color, pulse)

	return body_color


func _draw_alive_body(fill_color: Color) -> void:
	var shadow_color := fill_color.darkened(0.85)
	shadow_color.a = 0.24
	draw_circle(Vector2(0.0, 6.5), body_radius, shadow_color)

	var draw_offset := _get_visual_offset()
	if state == State.TELEGRAPH:
		var aim_direction := telegraph_direction
		if aim_direction == Vector2.ZERO:
			aim_direction = Vector2.RIGHT

		var telegraph_end := (draw_offset + aim_direction.normalized() * telegraph_line_length).round()
		var ring_color := telegraph_line_color
		ring_color.a = 0.4

		draw_arc(draw_offset, body_radius + 3.0, 0.0, TAU, 24, ring_color, 1.5)
		draw_line(draw_offset, telegraph_end, telegraph_line_color, 3.0)
		draw_circle(telegraph_end, 2.5, telegraph_line_color)


func _get_visual_offset() -> Vector2:
	var draw_offset := super._get_visual_offset()
	if state == State.TELEGRAPH:
		var shake_phase := Time.get_ticks_msec() / 1000.0 * 28.0
		draw_offset += Vector2(
			roundf(sin(shake_phase) * telegraph_shake_strength),
			roundf(cos(shake_phase * 1.3) * telegraph_shake_strength)
		)
	elif state == State.DASH:
		draw_offset += Vector2(
			roundf(dash_direction.x * 2.0),
			roundf(dash_direction.y * 2.0)
		)
	return draw_offset.round()


func _get_visual_scale() -> Vector2:
	return Vector2.ONE


func _try_contact_damage() -> void:
	if not _can_deal_contact_damage():
		return

	super._try_contact_damage()


func _update_visible_entry_state() -> void:
	if has_visible_arena_entry or arena_rect.size == Vector2.ZERO or sprite == null or not sprite.visible:
		return

	if arena_rect.has_point(last_sprite_target_global_position):
		has_visible_arena_entry = true


func _can_deal_contact_damage() -> bool:
	if not active or player == null or not player.is_alive():
		return false
	if is_in_explosion_knockback():
		return false
	if not has_visible_arena_entry:
		return false
	if sprite == null or not sprite.visible:
		return false

	return sprite.global_position.distance_to(last_sprite_target_global_position) <= visible_entry_damage_sync_distance
