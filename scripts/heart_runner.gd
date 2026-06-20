extends CharacterBody2D
class_name HeartRunner

const SPRITE_BASE_OFFSET := Vector2(0.0, -1.0)
const FAILSAFE_EXTRA_TIME := 2.0

signal defeated(defeat_position: Vector2, score_value: int, spawned_by_debug: bool)
signal escaped(spawned_by_debug: bool)

@export var move_speed := 140.0
@export var score_value := 1
@export var body_radius := 6.0
@export var cleanup_margin := 12.0

var arena_rect := Rect2()
var travel_direction := Vector2.RIGHT
var exit_edge := Arena.SpawnEdge.RIGHT
var exit_threshold := 0.0
var active := true
var is_resolved := false
var visual_time := 0.0
var displacement_direction := Vector2.ZERO
var displacement_distance := 0.0
var displacement_duration := 0.0
var displacement_time_left := 0.0
var displacement_velocity := Vector2.ZERO
var spawned_by_debug := false
var lifetime_elapsed := 0.0
var failsafe_lifetime := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("spear_hittable")
	add_to_group("heart_runner")
	if sprite != null:
		sprite.top_level = true
	_update_sprite_visuals()
	queue_redraw()


func setup(
	new_arena_rect: Rect2,
	entry_position: Vector2,
	target_position: Vector2,
	new_exit_edge: int,
	new_move_speed: float,
	is_debug_spawn := false
) -> void:
	arena_rect = new_arena_rect
	global_position = entry_position
	exit_edge = new_exit_edge
	move_speed = new_move_speed
	travel_direction = (target_position - entry_position).normalized()
	if travel_direction == Vector2.ZERO:
		travel_direction = Vector2.RIGHT
	spawned_by_debug = is_debug_spawn
	_update_exit_threshold()
	_configure_failsafe_lifetime(entry_position)
	_update_sprite_visuals()
	queue_redraw()


func set_active(is_active: bool) -> void:
	active = is_active
	if not active:
		velocity = Vector2.ZERO
		_clear_authored_displacement()


func receive_combat_hit(
	hit_source: StringName,
	_hit_position: Vector2,
	_hit_direction: Vector2
) -> int:
	if is_resolved or not active:
		return Enemy.HitResponse.IGNORED
	if hit_source != Enemy.HIT_SOURCE_SPEAR:
		return Enemy.HitResponse.IGNORED

	_resolve_defeat()
	return Enemy.HitResponse.DAMAGED


func apply_authored_displacement(direction: Vector2, distance: float, duration: float) -> bool:
	if not active or is_resolved:
		return false
	if direction.length_squared() <= 0.001:
		return false
	if distance <= 0.0 or duration <= 0.0:
		return false

	displacement_direction = direction.normalized()
	displacement_distance = distance
	displacement_duration = duration
	displacement_time_left = duration
	displacement_velocity = displacement_direction * (distance / duration)
	return true


func _physics_process(delta: float) -> void:
	visual_time += delta

	if not active or is_resolved:
		velocity = Vector2.ZERO
		_update_sprite_visuals()
		queue_redraw()
		return

	lifetime_elapsed += delta
	if failsafe_lifetime > 0.0 and lifetime_elapsed >= failsafe_lifetime:
		push_warning("HeartRunner failsafe resolved an overlong lifetime.")
		_resolve_escape()
		return

	var movement := _get_step_movement(delta)
	var proposed_position := global_position + movement
	if _has_crossed_exit_plane(proposed_position):
		global_position = proposed_position
		velocity = movement / maxf(delta, 0.0001)
		_resolve_escape()
		return

	var clamped_position := _clamp_inside_play_rect_except_exit_edge(proposed_position)
	var actual_movement := clamped_position - global_position
	global_position = clamped_position
	if delta > 0.0:
		velocity = actual_movement / delta
	else:
		velocity = Vector2.ZERO

	_update_displacement_timer(delta)
	_update_sprite_visuals()
	queue_redraw()


func _get_step_movement(delta: float) -> Vector2:
	if displacement_time_left > 0.0:
		return displacement_velocity * delta
	return travel_direction * move_speed * delta


func _update_displacement_timer(delta: float) -> void:
	if displacement_time_left <= 0.0:
		return

	displacement_time_left = maxf(displacement_time_left - delta, 0.0)
	if displacement_time_left == 0.0:
		_clear_authored_displacement()


func _clear_authored_displacement() -> void:
	displacement_direction = Vector2.ZERO
	displacement_distance = 0.0
	displacement_duration = 0.0
	displacement_time_left = 0.0
	displacement_velocity = Vector2.ZERO


func _resolve_defeat() -> void:
	if is_resolved:
		return

	is_resolved = true
	active = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_authored_displacement()
	defeated.emit(global_position, score_value, spawned_by_debug)
	queue_free()


func _resolve_escape() -> void:
	if is_resolved:
		return

	is_resolved = true
	active = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_authored_displacement()
	escaped.emit(spawned_by_debug)
	queue_free()


func _configure_failsafe_lifetime(entry_position: Vector2) -> void:
	lifetime_elapsed = 0.0
	var distance_to_exit_threshold := maxf(_get_distance_to_exit_threshold(entry_position), 0.0)
	if distance_to_exit_threshold <= 0.0:
		distance_to_exit_threshold = maxf(arena_rect.size.x, arena_rect.size.y) + cleanup_margin

	failsafe_lifetime = (distance_to_exit_threshold / maxf(move_speed, 1.0)) + FAILSAFE_EXTRA_TIME


func _get_distance_to_exit_threshold(entry_position: Vector2) -> float:
	match exit_edge:
		Arena.SpawnEdge.TOP:
			return entry_position.y - exit_threshold
		Arena.SpawnEdge.BOTTOM:
			return exit_threshold - entry_position.y
		Arena.SpawnEdge.LEFT:
			return entry_position.x - exit_threshold
		_:
			return exit_threshold - entry_position.x


func _update_exit_threshold() -> void:
	match exit_edge:
		Arena.SpawnEdge.TOP:
			exit_threshold = arena_rect.position.y - cleanup_margin
		Arena.SpawnEdge.BOTTOM:
			exit_threshold = arena_rect.end.y + cleanup_margin
		Arena.SpawnEdge.LEFT:
			exit_threshold = arena_rect.position.x - cleanup_margin
		_:
			exit_threshold = arena_rect.end.x + cleanup_margin


func _has_crossed_exit_plane(target_position: Vector2) -> bool:
	match exit_edge:
		Arena.SpawnEdge.TOP:
			return target_position.y <= exit_threshold
		Arena.SpawnEdge.BOTTOM:
			return target_position.y >= exit_threshold
		Arena.SpawnEdge.LEFT:
			return target_position.x <= exit_threshold
		_:
			return target_position.x >= exit_threshold


func _clamp_inside_play_rect_except_exit_edge(target_position: Vector2) -> Vector2:
	if arena_rect.size == Vector2.ZERO:
		return target_position

	var min_x := arena_rect.position.x + body_radius
	var max_x := arena_rect.end.x - body_radius
	var min_y := arena_rect.position.y + body_radius
	var max_y := arena_rect.end.y - body_radius
	var resolved_position := target_position

	match exit_edge:
		Arena.SpawnEdge.TOP:
			resolved_position.x = clamp(resolved_position.x, min_x, max_x)
			resolved_position.y = min(resolved_position.y, max_y)
		Arena.SpawnEdge.BOTTOM:
			resolved_position.x = clamp(resolved_position.x, min_x, max_x)
			resolved_position.y = max(resolved_position.y, min_y)
		Arena.SpawnEdge.LEFT:
			resolved_position.x = min(resolved_position.x, max_x)
			resolved_position.y = clamp(resolved_position.y, min_y, max_y)
		_:
			resolved_position.x = max(resolved_position.x, min_x)
			resolved_position.y = clamp(resolved_position.y, min_y, max_y)

	return resolved_position


func _draw() -> void:
	draw_circle(Vector2(0.0, 4.5), body_radius - 1.7, Color(0.0, 0.0, 0.0, 0.18))


func _update_sprite_visuals() -> void:
	if sprite == null:
		return

	sprite.global_position = _get_sprite_target_global_position()
	sprite.global_rotation = 0.0
	sprite.scale = _get_visual_scale()
	sprite.flip_h = travel_direction.x < 0.0
	sprite.self_modulate = Color.WHITE


func _get_sprite_target_global_position() -> Vector2:
	var run_bob := roundf(sin(visual_time * 18.0) * 1.0)
	return (global_position + SPRITE_BASE_OFFSET + Vector2(0.0, run_bob)).round()


func _get_visual_scale() -> Vector2:
	if displacement_time_left > 0.0:
		return Vector2(1.04, 0.96)
	return Vector2.ONE
