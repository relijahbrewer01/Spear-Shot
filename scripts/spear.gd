extends Area2D
class_name Spear

const SPEAR_VISUAL_ROTATION_OFFSET := 0.0
const ENEMY_COLLISION_MASK := 2
const SpearTrailScript := preload("res://scripts/spear_trail.gd")
const DEBUG_SHOW_SPEAR_COLLISION := false

signal state_changed(new_state: int)
signal enemy_hit(hit_position: Vector2)
signal picked_up
signal thrown
signal landed

enum State {
	HELD,
	FLYING,
	LANDED,
}

@export var spear_speed := 520.0
@export var max_range := 150.0
@export var held_distance := 14.0
@export var trail_color := Color8(223, 205, 169, 140)
@export var pickup_flash_color := Color8(255, 244, 180)
@export var landed_marker_color := Color8(255, 236, 176)
@export var landed_marker_radius := 15.0
@export var landed_marker_width := 2.0
@export var landed_marker_pulse_speed := 4.0
@export var launch_sweep_start_offset := 0.0
@export var launch_sweep_end_offset := 18.0
@export var launch_sweep_width := 4.0
@export var stopped_hit_landing_clearance := 4.0

var state: State = State.HELD
var owner_player: Player
var arena_rect := Rect2()
var held_direction := Vector2.RIGHT
var throw_direction := Vector2.RIGHT
var travelled_distance := 0.0
var active := true
var hit_enemy_ids: Dictionary = {}
var trail_points: Array[Vector2] = []
var pickup_flash_left := 0.0
var pickup_in_progress := false
var debug_launch_sweep_left := 0.0
var debug_launch_sweep_direction := Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: SpearTrailScript = $Trail
@onready var flying_damage_area: Area2D = $FlyingDamageArea
@onready var flying_damage_shape: CollisionShape2D = $FlyingDamageArea/CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	if flying_damage_area != null:
		flying_damage_area.body_entered.connect(_on_flying_damage_body_entered)
	if pickup_area != null:
		pickup_area.body_entered.connect(_on_pickup_body_entered)
	if sprite != null:
		sprite.top_level = true
	if trail != null:
		trail.trail_color = trail_color
		trail.clear_trail()
	_apply_collision_activity()
	_update_sprite_visuals()
	queue_redraw()


func setup(player_ref: Player, new_arena_rect: Rect2) -> void:
	owner_player = player_ref
	arena_rect = new_arena_rect
	_clear_trail()
	_move_to_held_position()


func reset_for_new_run(player_ref: Player, new_arena_rect: Rect2) -> void:
	owner_player = player_ref
	arena_rect = new_arena_rect
	held_direction = Vector2.RIGHT
	throw_direction = Vector2.RIGHT
	travelled_distance = 0.0
	active = true
	hit_enemy_ids.clear()
	trail_points.clear()
	pickup_flash_left = 0.0
	pickup_in_progress = false
	_set_state(State.HELD)
	_clear_trail()
	_move_to_held_position()


func set_active(is_active: bool) -> void:
	active = is_active
	_apply_collision_activity()


func is_held() -> bool:
	return state == State.HELD


func is_landed() -> bool:
	return state == State.LANDED


func get_status_text() -> String:
	match state:
		State.HELD:
			return "READY"
		State.FLYING:
			return "FLY"
		State.LANDED:
			return "FETCH"
	return "Unknown"


func try_throw(target_position: Vector2) -> bool:
	if not active or state != State.HELD or owner_player == null:
		return false

	var aim_direction := _get_direction_to(target_position)
	if aim_direction == Vector2.ZERO:
		return false

	throw_direction = aim_direction
	held_direction = aim_direction
	travelled_distance = 0.0
	hit_enemy_ids.clear()
	_clear_trail()

	global_position = _clamp_to_arena(owner_player.global_position + throw_direction * held_distance)
	_set_rotation_from_direction(throw_direction)
	_push_trail_point()
	_set_state(State.FLYING)
	thrown.emit()
	_hit_enemies_in_launch_sweep()
	return true


func _physics_process(delta: float) -> void:
	if pickup_flash_left > 0.0:
		pickup_flash_left = max(pickup_flash_left - delta, 0.0)
	if debug_launch_sweep_left > 0.0:
		debug_launch_sweep_left = maxf(debug_launch_sweep_left - delta, 0.0)

	if state == State.FLYING:
		_update_flight(delta)
	elif state == State.HELD:
		_clear_trail()
		_move_to_held_position()

	_sync_trail_visual()
	_update_sprite_visuals()
	queue_redraw()


func _move_to_held_position() -> void:
	if owner_player == null:
		return

	held_direction = _get_direction_to(get_global_mouse_position())
	if held_direction == Vector2.ZERO:
		held_direction = owner_player.get_last_valid_aim_direction()
	if held_direction == Vector2.ZERO:
		held_direction = Vector2.RIGHT

	global_position = _clamp_to_arena(owner_player.global_position + held_direction * held_distance)
	_set_rotation_from_direction(held_direction)


func _update_flight(delta: float) -> void:
	if not active:
		return

	var movement := throw_direction * spear_speed * delta
	global_position += movement
	travelled_distance += movement.length()
	_set_rotation_from_direction(throw_direction)
	_push_trail_point()

	if travelled_distance >= max_range:
		_land(global_position)
		return

	if not arena_rect.has_point(global_position):
		_land(_clamp_to_arena(global_position))


func _land(final_position: Vector2) -> void:
	if state != State.FLYING:
		return

	_enter_landed_state(final_position)


func _enter_landed_state(final_position: Vector2) -> void:
	global_position = _clamp_to_arena(final_position)
	_set_rotation_from_direction(throw_direction)
	_clear_trail()
	_set_state(State.LANDED)
	_schedule_landed_pickup_overlap_check()
	landed.emit()


func apply_landed_shockwave_nudge(
	blast_center: Vector2,
	effect_radius: float,
	displacement: float
) -> bool:
	if state != State.LANDED:
		return false
	if effect_radius <= 0.0 or displacement <= 0.0:
		return false
	if global_position.distance_to(blast_center) > effect_radius:
		return false

	var outward_direction := (global_position - blast_center).normalized()
	if outward_direction == Vector2.ZERO:
		outward_direction = throw_direction.normalized()
	if outward_direction == Vector2.ZERO:
		outward_direction = Vector2.RIGHT

	global_position = _clamp_to_arena(global_position + outward_direction * displacement)
	_schedule_landed_pickup_overlap_check()
	queue_redraw()
	return true


func _pickup() -> void:
	if state != State.LANDED or pickup_in_progress or owner_player == null:
		return

	pickup_in_progress = true
	_apply_collision_activity()
	pickup_flash_left = 0.16
	_clear_trail()
	_set_state(State.HELD)
	_move_to_held_position()
	picked_up.emit()
	pickup_in_progress = false


func _push_trail_point() -> void:
	if trail_points.is_empty() or trail_points[-1].distance_to(global_position) >= 4.0:
		trail_points.append(global_position)

	while trail_points.size() > 8:
		trail_points.remove_at(0)


func _set_state(new_state: State) -> void:
	state = new_state
	_apply_collision_activity()
	state_changed.emit(state)
	queue_redraw()


func _get_direction_to(target_position: Vector2) -> Vector2:
	if owner_player == null:
		return Vector2.ZERO

	var direction := target_position - owner_player.global_position
	if direction.length_squared() < 0.001:
		return Vector2.ZERO

	return direction.normalized()


func _set_rotation_from_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return

	rotation = direction.angle() + SPEAR_VISUAL_ROTATION_OFFSET


func _clamp_to_arena(target_position: Vector2) -> Vector2:
	if arena_rect.size == Vector2.ZERO:
		return target_position

	return Vector2(
		clamp(target_position.x, arena_rect.position.x + 4.0, arena_rect.end.x - 4.0),
		clamp(target_position.y, arena_rect.position.y + 4.0, arena_rect.end.y - 4.0)
	)


func _on_flying_damage_body_entered(body: Node) -> void:
	if state != State.FLYING:
		return

	if _is_valid_spear_hittable_body(body):
		_hit_enemy_if_needed(body)
	elif body.is_in_group("arena_wall"):
		_land(global_position - throw_direction * 2.0)


func _on_pickup_body_entered(body: Node) -> void:
	if body == owner_player:
		_pickup()


func _draw() -> void:
	if DEBUG_SHOW_SPEAR_COLLISION:
		_draw_collision_debug()

	if pickup_flash_left > 0.0:
		var flash_progress := pickup_flash_left / 0.16
		var flash_color := pickup_flash_color
		flash_color.a = 0.5 * flash_progress
		draw_circle(Vector2.ZERO, 10.0 + (1.0 - flash_progress) * 8.0, flash_color)

	if state == State.LANDED:
		var pulse_phase := sin(Time.get_ticks_msec() / 1000.0 * landed_marker_pulse_speed)
		var pulse_amount := (pulse_phase + 1.0) * 0.5
		var ring_color := landed_marker_color
		ring_color.a = 0.3 + pulse_amount * 0.25
		draw_arc(
			Vector2.ZERO,
			landed_marker_radius + pulse_amount * 3.0,
			0.0,
			TAU,
			32,
			ring_color,
			landed_marker_width
		)

	if state != State.HELD:
		draw_circle(Vector2(0.0, 3.0), 5.0, Color(0.0, 0.0, 0.0, 0.16))


func _update_sprite_visuals() -> void:
	if sprite == null:
		return

	sprite.global_position = (global_position + Vector2(1.0, 0.0).rotated(rotation)).round()
	sprite.global_rotation = rotation
	sprite.scale = Vector2.ONE
	sprite.self_modulate = Color.WHITE


func _clear_trail() -> void:
	trail_points.clear()
	_sync_trail_visual()


func _sync_trail_visual() -> void:
	if trail == null:
		return

	trail.set_trail_points(trail_points)


func _hit_enemies_in_launch_sweep() -> void:
	if owner_player == null:
		return

	var sweep_length := maxf(launch_sweep_end_offset - launch_sweep_start_offset, 1.0)
	var sweep_shape := RectangleShape2D.new()
	sweep_shape.size = Vector2(sweep_length, launch_sweep_width)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = sweep_shape
	query.transform = Transform2D(
		throw_direction.angle(),
		owner_player.global_position + throw_direction * (launch_sweep_start_offset + sweep_length * 0.5)
	)
	query.collision_mask = ENEMY_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid(), owner_player.get_rid()]

	debug_launch_sweep_direction = throw_direction
	debug_launch_sweep_left = 0.15

	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 16)
	var candidates := _collect_sorted_launch_sweep_candidates(results)
	for candidate in candidates:
		if state != State.FLYING:
			return

		var enemy_body := candidate.get("enemy") as Node
		var hit_response := _hit_enemy_if_needed(enemy_body)
		if hit_response == Enemy.HitResponse.STOPPED:
			return


func _collect_sorted_launch_sweep_candidates(results: Array[Dictionary]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var collected_enemy_ids: Dictionary = {}
	for result in results:
		var collider_variant: Variant = result.get("collider")
		if not (collider_variant is Node):
			continue

		var collider := collider_variant as Node
		if not _is_valid_spear_hittable_body(collider):
			continue

		var enemy_id := collider.get_instance_id()
		if collected_enemy_ids.has(enemy_id):
			continue

		var enemy_node := collider as Node2D
		if enemy_node == null:
			continue

		collected_enemy_ids[enemy_id] = true
		var projected_distance := (enemy_node.global_position - owner_player.global_position).dot(
			throw_direction
		)
		candidates.append({
			"enemy": collider,
			"distance": projected_distance,
		})

	candidates.sort_custom(_sort_launch_sweep_candidates)
	return candidates


func _sort_launch_sweep_candidates(left: Dictionary, right: Dictionary) -> bool:
	return float(left.get("distance", 0.0)) < float(right.get("distance", 0.0))


func _hit_enemy_if_needed(enemy_body: Node) -> int:
	if state != State.FLYING:
		return Enemy.HitResponse.IGNORED
	if enemy_body == null:
		return Enemy.HitResponse.IGNORED

	var enemy_id := enemy_body.get_instance_id()
	if hit_enemy_ids.has(enemy_id):
		return Enemy.HitResponse.IGNORED

	hit_enemy_ids[enemy_id] = true
	var hit_position := _get_enemy_near_side_hit_position(enemy_body)
	var stopped_landing_position := _get_stopped_hit_landing_position(enemy_body)
	var hit_response := Enemy.HitResponse.IGNORED

	if enemy_body.has_method("receive_combat_hit"):
		hit_response = int(enemy_body.receive_combat_hit(
			Enemy.HIT_SOURCE_SPEAR,
			hit_position,
			throw_direction
		))
	elif enemy_body.has_method("take_spear_hit"):
		enemy_body.take_spear_hit()
		hit_response = Enemy.HitResponse.DAMAGED

	if hit_response != Enemy.HitResponse.IGNORED and enemy_body is Node2D:
		var enemy_node := enemy_body as Node2D
		enemy_hit.emit(enemy_node.global_position)

	if hit_response == Enemy.HitResponse.STOPPED:
		_land(stopped_landing_position)

	return hit_response


func _get_enemy_near_side_hit_position(enemy_body: Node) -> Vector2:
	var enemy_node := enemy_body as Node2D
	if enemy_node == null:
		return global_position

	var body_radius := _get_enemy_body_radius(enemy_body)
	return _clamp_to_arena(enemy_node.global_position - throw_direction * body_radius)


func _get_stopped_hit_landing_position(enemy_body: Node) -> Vector2:
	var enemy_node := enemy_body as Node2D
	if enemy_node == null:
		return _clamp_to_arena(global_position)

	var body_radius := _get_enemy_body_radius(enemy_body)
	var desired_distance := body_radius + stopped_hit_landing_clearance
	var minimum_clear_distance := body_radius + maxf(stopped_hit_landing_clearance, 2.0)
	var incoming_side := -throw_direction
	var tangent := Vector2(-throw_direction.y, throw_direction.x)
	var raw_candidates: Array[Vector2] = [
		enemy_node.global_position + incoming_side * desired_distance,
		enemy_node.global_position + incoming_side * minimum_clear_distance,
		enemy_node.global_position + incoming_side * body_radius + tangent * minimum_clear_distance,
		enemy_node.global_position + incoming_side * body_radius - tangent * minimum_clear_distance,
	]

	var best_position := _clamp_to_arena(raw_candidates[0])
	var best_distance := best_position.distance_to(enemy_node.global_position)
	for raw_candidate in raw_candidates:
		var candidate := _clamp_to_arena(raw_candidate)
		var distance := candidate.distance_to(enemy_node.global_position)
		if distance >= minimum_clear_distance:
			return candidate
		if distance > best_distance:
			best_position = candidate
			best_distance = distance

	return best_position


func _get_enemy_body_radius(enemy_body: Node) -> float:
	if enemy_body is Enemy:
		var enemy := enemy_body as Enemy
		return enemy.body_radius
	var body_radius_variant: Variant = enemy_body.get("body_radius")
	if body_radius_variant is float or body_radius_variant is int:
		return float(body_radius_variant)

	return 8.0


func _is_valid_spear_hittable_body(body: Node) -> bool:
	return (
		body != null
		and body.is_in_group("spear_hittable")
		and body.has_method("receive_combat_hit")
	)


func _apply_collision_activity() -> void:
	var is_flying_active := active and state == State.FLYING
	var is_pickup_active := active and state == State.LANDED and not pickup_in_progress

	if flying_damage_area != null:
		flying_damage_area.set_deferred("monitoring", is_flying_active)
		flying_damage_area.set_deferred("monitorable", is_flying_active)
	if flying_damage_shape != null:
		flying_damage_shape.set_deferred("disabled", not is_flying_active)

	if pickup_area != null:
		pickup_area.set_deferred("monitoring", is_pickup_active)
		pickup_area.set_deferred("monitorable", is_pickup_active)
	if pickup_shape != null:
		pickup_shape.set_deferred("disabled", not is_pickup_active)


func _schedule_landed_pickup_overlap_check() -> void:
	call_deferred("_check_landed_pickup_overlap")


func _check_landed_pickup_overlap() -> void:
	if _try_pickup_overlapping_player():
		return

	await get_tree().physics_frame
	_try_pickup_overlapping_player()


func _try_pickup_overlapping_player() -> bool:
	if state != State.LANDED or pickup_in_progress or pickup_area == null or not pickup_area.monitoring:
		return false

	for body in pickup_area.get_overlapping_bodies():
		if body == owner_player:
			_pickup()
			return true

	if _is_owner_player_inside_pickup_query():
		_pickup()
		return true

	return false


func _is_owner_player_inside_pickup_query() -> bool:
	if owner_player == null or pickup_shape == null or pickup_shape.shape == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = pickup_shape.shape
	query.transform = pickup_shape.global_transform
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results := get_world_2d().direct_space_state.intersect_shape(query, 8)
	for result in results:
		if result.get("collider") == owner_player:
			return true

	return false


func _draw_collision_debug() -> void:
	var collision_rect := _get_flying_collision_rect()
	if collision_rect.size != Vector2.ZERO and state == State.FLYING:
		draw_rect(collision_rect, Color(0.2, 0.9, 1.0, 0.22), true)
		draw_rect(collision_rect, Color(0.2, 0.9, 1.0, 0.8), false, 1.0)

	if debug_launch_sweep_left > 0.0:
		var sweep_rect := Rect2(
			Vector2(launch_sweep_start_offset, -launch_sweep_width * 0.5),
			Vector2(launch_sweep_end_offset - launch_sweep_start_offset, launch_sweep_width)
		)
		draw_set_transform(Vector2.ZERO, debug_launch_sweep_direction.angle(), Vector2.ONE)
		draw_rect(sweep_rect, Color(1.0, 0.85, 0.2, 0.18), true)
		draw_rect(sweep_rect, Color(1.0, 0.85, 0.2, 0.85), false, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_flying_collision_rect() -> Rect2:
	if flying_damage_shape == null:
		return Rect2()

	var rectangle_shape := flying_damage_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return Rect2()

	return Rect2(
		flying_damage_shape.position - rectangle_shape.size * 0.5,
		rectangle_shape.size
	)
