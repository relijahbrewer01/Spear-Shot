extends CharacterBody2D
class_name HeartRunner

const SPRITE_BASE_OFFSET := Vector2(0.0, -1.0)
const FAILSAFE_EXTRA_TIME := 2.0
const EDGE_SAMPLE_OFFSETS := [0.22, 0.5, 0.78]

signal defeated(defeat_position: Vector2, score_value: int, spawned_by_debug: bool)
signal escaped(spawned_by_debug: bool)
signal startled_started
signal state_changed(new_state: int)

enum MotionState {
	ENTERING,
	WANDERING,
	CASUAL_EXIT,
	STARTLED,
	FLEEING,
	RESOLVED,
}

@export var move_speed := 140.0
@export var calm_move_speed := 70.0
@export var score_value := 1
@export var body_radius := 6.0
@export var cleanup_margin := 12.0
@export var entry_distance := 20.0
@export var entry_min_duration := 0.45
@export var wander_duration := 8.0
@export var wander_wall_inset := 24.0
@export var wander_target_distance_min := 28.0
@export var wander_target_distance_max := 60.0
@export var wander_retarget_interval_min := 0.8
@export var wander_retarget_interval_max := 1.4
@export var wander_player_avoid_radius := 44.0
@export var casual_exit_min_route_length := 64.0
@export var flee_min_route_length := 64.0
@export var startled_duration := 0.30
@export var flee_player_route_clear_radius := 36.0
@export var exit_candidate_edge_padding := 20.0
@export var exit_corner_avoid_distance := 20.0
@export var nearest_wall_reject_distance := 18.0
@export_range(1, 4, 1) var best_route_choice_pool_size := 3

var arena_rect := Rect2()
var player_ref: Player
var tracked_spear: Spear
var runner_rng := RandomNumberGenerator.new()
var spawn_edge := Arena.SpawnEdge.LEFT
var travel_direction := Vector2.RIGHT
var exit_edge := Arena.SpawnEdge.RIGHT
var exit_threshold := 0.0
var exit_target_point := Vector2.ZERO
var current_route_length := 0.0
var motion_state: MotionState = MotionState.ENTERING
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
var entry_start_position := Vector2.ZERO
var entry_direction := Vector2.RIGHT
var entry_elapsed := 0.0
var wander_time_left := 0.0
var wander_target := Vector2.ZERO
var wander_retarget_time_left := 0.0
var startled_time_left := 0.0
var pending_startled_after_entry := false
var has_startled := false
var facing_left := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("spear_hittable")
	add_to_group("heart_runner")
	if sprite != null:
		sprite.top_level = true
	runner_rng.seed = 1
	_update_sprite_visuals()
	queue_redraw()


func setup(
	new_arena_rect: Rect2,
	entry_position: Vector2,
	new_spawn_edge: int,
	new_move_speed: float,
	new_player_ref: Player,
	new_spear_ref: Spear,
	is_debug_spawn := false,
	random_seed: int = 1
) -> void:
	arena_rect = new_arena_rect
	global_position = entry_position
	spawn_edge = new_spawn_edge
	move_speed = new_move_speed
	player_ref = new_player_ref
	tracked_spear = new_spear_ref
	spawned_by_debug = is_debug_spawn
	active = true
	is_resolved = false
	entry_start_position = entry_position
	entry_direction = _get_inward_direction_for_edge(spawn_edge)
	travel_direction = entry_direction
	wander_time_left = wander_duration
	wander_target = entry_position
	wander_retarget_time_left = 0.0
	startled_time_left = 0.0
	entry_elapsed = 0.0
	pending_startled_after_entry = _is_tracked_spear_held()
	has_startled = false
	current_route_length = 0.0
	exit_target_point = Vector2.ZERO
	exit_edge = Arena.get_opposite_spawn_edge(spawn_edge)
	facing_left = entry_direction.x < 0.0
	runner_rng.seed = maxi(random_seed, 1)
	_clear_authored_displacement()
	_connect_spear_state_signal()
	_set_motion_state(MotionState.ENTERING)
	_update_exit_threshold()
	_configure_failsafe_lifetime()
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


func debug_trigger_spear_held() -> void:
	_on_tracked_spear_state_changed(Spear.State.HELD)


func debug_force_wandering() -> void:
	has_startled = false
	pending_startled_after_entry = false
	entry_elapsed = entry_min_duration
	wander_time_left = wander_duration
	_pick_next_wander_target()
	_set_motion_state(MotionState.WANDERING)


func debug_force_locked_exit(target_edge: int, target_point: Vector2, use_flee_state := true) -> void:
	_lock_exit_route({
		"edge": target_edge,
		"point": target_point,
		"distance": global_position.distance_to(target_point),
		"direction": (target_point - global_position).normalized(),
	})
	if use_flee_state:
		has_startled = true
		pending_startled_after_entry = false
		startled_time_left = 0.0
		_set_motion_state(MotionState.FLEEING)
	else:
		_set_motion_state(MotionState.CASUAL_EXIT)


func get_state_name() -> String:
	match motion_state:
		MotionState.ENTERING:
			return "ENTERING"
		MotionState.WANDERING:
			return "WANDERING"
		MotionState.CASUAL_EXIT:
			return "CASUAL_EXIT"
		MotionState.STARTLED:
			return "STARTLED"
		MotionState.FLEEING:
			return "FLEEING"
		MotionState.RESOLVED:
			return "RESOLVED"
	return "UNKNOWN"


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

	_update_displacement_timer(delta)

	match motion_state:
		MotionState.ENTERING:
			_update_entering(delta)
		MotionState.WANDERING:
			_update_wandering(delta)
		MotionState.CASUAL_EXIT:
			_update_locked_exit(delta, calm_move_speed)
		MotionState.STARTLED:
			_update_startled(delta)
		MotionState.FLEEING:
			_update_locked_exit(delta, move_speed)
		_:
			velocity = Vector2.ZERO

	_update_sprite_visuals()
	queue_redraw()


func _update_entering(delta: float) -> void:
	entry_elapsed += delta
	_move_inside_rect(delta, entry_direction, calm_move_speed, arena_rect)

	if not _has_completed_entry():
		return

	if pending_startled_after_entry:
		_enter_startled()
	else:
		_enter_wandering()


func _update_wandering(delta: float) -> void:
	wander_time_left = maxf(wander_time_left - delta, 0.0)
	wander_retarget_time_left = maxf(wander_retarget_time_left - delta, 0.0)
	if wander_target.distance_to(global_position) <= 4.0 or wander_retarget_time_left == 0.0:
		_pick_next_wander_target()

	var direction_to_target := (wander_target - global_position).normalized()
	if direction_to_target != Vector2.ZERO:
		travel_direction = direction_to_target
	_move_inside_rect(delta, travel_direction, calm_move_speed, _get_inner_wander_rect())

	if wander_time_left == 0.0:
		_begin_casual_exit()


func _update_startled(delta: float) -> void:
	startled_time_left = maxf(startled_time_left - delta, 0.0)
	_move_inside_rect(delta, Vector2.ZERO, 0.0, arena_rect)
	if startled_time_left == 0.0:
		_set_motion_state(MotionState.FLEEING)


func _update_locked_exit(delta: float, speed: float) -> void:
	if travel_direction == Vector2.ZERO and exit_target_point != Vector2.ZERO:
		travel_direction = (exit_target_point - global_position).normalized()
	_move_with_exit_resolution(delta, travel_direction, speed)


func _move_inside_rect(delta: float, direction: Vector2, speed: float, clamp_rect: Rect2) -> void:
	var movement := _get_step_movement(delta, direction, speed)
	var proposed_position := global_position + movement
	var clamped_position := _clamp_inside_rect(proposed_position, clamp_rect)
	_apply_movement_result(clamped_position, delta)


func _move_with_exit_resolution(delta: float, direction: Vector2, speed: float) -> void:
	var movement := _get_step_movement(delta, direction, speed)
	var proposed_position := global_position + movement
	if _has_crossed_exit_plane(proposed_position):
		global_position = proposed_position
		velocity = movement / maxf(delta, 0.0001)
		_resolve_escape()
		return

	var clamped_position := _clamp_inside_play_rect_except_exit_edge(proposed_position)
	_apply_movement_result(clamped_position, delta)


func _get_step_movement(delta: float, direction: Vector2, speed: float) -> Vector2:
	if displacement_time_left > 0.0:
		return displacement_velocity * delta
	return direction * speed * delta


func _apply_movement_result(target_position: Vector2, delta: float) -> void:
	var actual_movement := target_position - global_position
	global_position = target_position
	if delta > 0.0:
		velocity = actual_movement / delta
	else:
		velocity = Vector2.ZERO

	if absf(velocity.x) > 0.05:
		facing_left = velocity.x < 0.0
	elif absf(travel_direction.x) > 0.05:
		facing_left = travel_direction.x < 0.0


func _enter_wandering() -> void:
	pending_startled_after_entry = false
	wander_time_left = wander_duration
	_pick_next_wander_target()
	_set_motion_state(MotionState.WANDERING)


func _begin_casual_exit() -> void:
	var route := _choose_exit_route(false)
	if not route.get("valid", false):
		route = _build_fallback_route(Arena.get_opposite_spawn_edge(spawn_edge))
	_lock_exit_route(route)
	_set_motion_state(MotionState.CASUAL_EXIT)


func _enter_startled() -> void:
	if has_startled or not active or is_resolved:
		return

	has_startled = true
	pending_startled_after_entry = false
	startled_time_left = startled_duration
	var route := _choose_exit_route(true)
	if not route.get("valid", false):
		route = _build_fallback_route(Arena.get_opposite_spawn_edge(spawn_edge))
	_lock_exit_route(route)
	velocity = Vector2.ZERO
	_set_motion_state(MotionState.STARTLED)
	startled_started.emit()


func _pick_next_wander_target() -> void:
	var inner_rect := _get_inner_wander_rect()
	var best_candidate := _clamp_inside_rect(global_position + entry_direction * 32.0, inner_rect)
	var best_score := -INF
	for _attempt in 12:
		var distance := runner_rng.randf_range(
			wander_target_distance_min,
			wander_target_distance_max
		)
		var angle := runner_rng.randf_range(0.0, TAU)
		var candidate := global_position + Vector2.RIGHT.rotated(angle) * distance
		candidate = _clamp_inside_rect(candidate, inner_rect)
		var score := candidate.distance_to(global_position)
		if player_ref != null:
			var distance_to_player := candidate.distance_to(player_ref.global_position)
			if distance_to_player < wander_player_avoid_radius:
				score -= (wander_player_avoid_radius - distance_to_player) * 4.0
			else:
				score += minf(distance_to_player, 48.0) * 0.2
		if score > best_score:
			best_score = score
			best_candidate = candidate

	wander_target = best_candidate
	wander_retarget_time_left = runner_rng.randf_range(
		wander_retarget_interval_min,
		wander_retarget_interval_max
	)
	var direction_to_target := (wander_target - global_position).normalized()
	if direction_to_target != Vector2.ZERO:
		travel_direction = direction_to_target


func _choose_exit_route(is_fleeing: bool) -> Dictionary:
	var candidates := _build_exit_candidates(is_fleeing)
	if candidates.is_empty():
		return {
			"valid": false,
		}

	var minimum_route_length := flee_min_route_length if is_fleeing else casual_exit_min_route_length
	var long_route_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if float(candidate["distance"]) >= minimum_route_length:
			long_route_candidates.append(candidate)
	if not long_route_candidates.is_empty():
		candidates = long_route_candidates

	candidates.sort_custom(_compare_route_candidates)
	var pool_size := mini(best_route_choice_pool_size, candidates.size())
	var selected_index := runner_rng.randi_range(0, maxi(pool_size - 1, 0))
	var selected_candidate := candidates[selected_index]
	selected_candidate["valid"] = true
	return selected_candidate


func _build_exit_candidates(is_fleeing: bool) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var play_rect := arena_rect
	var nearest_edge := _get_nearest_arena_edge(global_position)
	var player_position := global_position
	var away_from_player := Vector2.ZERO
	if player_ref != null:
		player_position = player_ref.global_position
		away_from_player = (global_position - player_position).normalized()

	for edge in [
		Arena.SpawnEdge.TOP,
		Arena.SpawnEdge.BOTTOM,
		Arena.SpawnEdge.LEFT,
		Arena.SpawnEdge.RIGHT,
	]:
		for offset in EDGE_SAMPLE_OFFSETS:
			var jitter := runner_rng.randf_range(-0.08, 0.08)
			var sample_offset := clampf(offset + jitter, 0.12, 0.88)
			var candidate_point := _get_edge_candidate_point(play_rect, edge, sample_offset)
			var route_direction := (candidate_point - global_position).normalized()
			if route_direction == Vector2.ZERO:
				continue

			var route_distance := global_position.distance_to(candidate_point)
			var path_clearance := INF
			if player_ref != null:
				path_clearance = _distance_to_segment(player_position, global_position, candidate_point)

			var away_score := 0.0
			if away_from_player != Vector2.ZERO:
				away_score = route_direction.dot(away_from_player)

			var same_wall_penalty := 0.0
			if edge == nearest_edge and _distance_to_edge(global_position, edge) <= nearest_wall_reject_distance:
				same_wall_penalty = 40.0

			var corner_penalty := 0.0
			if _distance_to_edge_corner(candidate_point, edge) < exit_corner_avoid_distance:
				corner_penalty = 18.0

			var minimum_route_length := flee_min_route_length if is_fleeing else casual_exit_min_route_length
			var short_route_penalty := 0.0
			if route_distance < minimum_route_length:
				short_route_penalty = (minimum_route_length - route_distance) * 1.1

			var player_penalty := 0.0
			if player_ref != null and path_clearance < flee_player_route_clear_radius:
				var penalty_scale := 1.3 if is_fleeing else 0.75
				player_penalty = (flee_player_route_clear_radius - path_clearance) * penalty_scale

			var score := route_distance
			score -= same_wall_penalty
			score -= corner_penalty
			score -= short_route_penalty
			score -= player_penalty
			score += runner_rng.randf_range(0.0, 4.0)
			score += away_score * (48.0 if is_fleeing else 12.0)
			if is_fleeing and away_score < -0.15:
				score -= 32.0

			candidates.append({
				"edge": edge,
				"point": candidate_point,
				"distance": route_distance,
				"direction": route_direction,
				"score": score,
			})

	return candidates


func _build_fallback_route(target_edge: int) -> Dictionary:
	var point := _get_edge_candidate_point(arena_rect, target_edge, 0.5)
	return {
		"valid": true,
		"edge": target_edge,
		"point": point,
		"distance": global_position.distance_to(point),
		"direction": (point - global_position).normalized(),
	}


func _lock_exit_route(route: Dictionary) -> void:
	exit_edge = int(route["edge"])
	exit_target_point = route["point"]
	current_route_length = float(route["distance"])
	travel_direction = route["direction"]
	if travel_direction == Vector2.ZERO and exit_target_point != Vector2.ZERO:
		travel_direction = (exit_target_point - global_position).normalized()
	_update_exit_threshold()


func _compare_route_candidates(a: Dictionary, b: Dictionary) -> bool:
	return float(a["score"]) > float(b["score"])


func _is_tracked_spear_held() -> bool:
	return tracked_spear != null and tracked_spear.is_held()


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
	if new_state != Spear.State.HELD:
		return
	if not active or is_resolved or has_startled:
		return

	match motion_state:
		MotionState.ENTERING:
			pending_startled_after_entry = true
		MotionState.WANDERING, MotionState.CASUAL_EXIT:
			_enter_startled()


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
	motion_state = MotionState.RESOLVED
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_authored_displacement()
	_disconnect_spear_state_signal()
	defeated.emit(global_position, score_value, spawned_by_debug)
	queue_free()


func _resolve_escape() -> void:
	if is_resolved:
		return

	is_resolved = true
	active = false
	motion_state = MotionState.RESOLVED
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_authored_displacement()
	_disconnect_spear_state_signal()
	escaped.emit(spawned_by_debug)
	queue_free()


func _configure_failsafe_lifetime() -> void:
	lifetime_elapsed = 0.0
	var longest_crossing := arena_rect.size.length()
	var calm_travel_time := longest_crossing / maxf(calm_move_speed, 1.0)
	var flee_travel_time := longest_crossing / maxf(move_speed, 1.0)
	failsafe_lifetime = (
		entry_min_duration
		+ wander_duration
		+ startled_duration
		+ calm_travel_time
		+ flee_travel_time
		+ FAILSAFE_EXTRA_TIME
	)


func _get_inward_direction_for_edge(target_spawn_edge: int) -> Vector2:
	match target_spawn_edge:
		Arena.SpawnEdge.TOP:
			return Vector2.DOWN
		Arena.SpawnEdge.BOTTOM:
			return Vector2.UP
		Arena.SpawnEdge.LEFT:
			return Vector2.RIGHT
		_:
			return Vector2.LEFT


func _has_completed_entry() -> bool:
	return entry_elapsed >= entry_min_duration and _get_entry_progress() >= entry_distance


func _get_entry_progress() -> float:
	return maxf((global_position - entry_start_position).dot(entry_direction), 0.0)


func _get_inner_wander_rect() -> Rect2:
	var inner_rect := arena_rect.grow(-wander_wall_inset)
	if inner_rect.size.x <= body_radius * 2.0 + 8.0 or inner_rect.size.y <= body_radius * 2.0 + 8.0:
		return arena_rect.grow(-8.0)
	return inner_rect


func _get_edge_candidate_point(play_rect: Rect2, edge: int, offset: float) -> Vector2:
	var min_x := play_rect.position.x + body_radius
	var max_x := play_rect.end.x - body_radius
	var min_y := play_rect.position.y + body_radius
	var max_y := play_rect.end.y - body_radius
	var safe_min_x := min_x + exit_candidate_edge_padding
	var safe_max_x := max_x - exit_candidate_edge_padding
	var safe_min_y := min_y + exit_candidate_edge_padding
	var safe_max_y := max_y - exit_candidate_edge_padding

	match edge:
		Arena.SpawnEdge.TOP:
			return Vector2(lerpf(safe_min_x, safe_max_x, offset), min_y)
		Arena.SpawnEdge.BOTTOM:
			return Vector2(lerpf(safe_min_x, safe_max_x, offset), max_y)
		Arena.SpawnEdge.LEFT:
			return Vector2(min_x, lerpf(safe_min_y, safe_max_y, offset))
		_:
			return Vector2(max_x, lerpf(safe_min_y, safe_max_y, offset))


func _get_nearest_arena_edge(position: Vector2) -> int:
	var distances := {
		Arena.SpawnEdge.TOP: absf(position.y - (arena_rect.position.y + body_radius)),
		Arena.SpawnEdge.BOTTOM: absf((arena_rect.end.y - body_radius) - position.y),
		Arena.SpawnEdge.LEFT: absf(position.x - (arena_rect.position.x + body_radius)),
		Arena.SpawnEdge.RIGHT: absf((arena_rect.end.x - body_radius) - position.x),
	}
	var best_edge := Arena.SpawnEdge.TOP
	var best_distance := INF
	for edge in distances.keys():
		var distance := float(distances[edge])
		if distance < best_distance:
			best_distance = distance
			best_edge = edge
	return best_edge


func _distance_to_edge(position: Vector2, edge: int) -> float:
	match edge:
		Arena.SpawnEdge.TOP:
			return absf(position.y - (arena_rect.position.y + body_radius))
		Arena.SpawnEdge.BOTTOM:
			return absf((arena_rect.end.y - body_radius) - position.y)
		Arena.SpawnEdge.LEFT:
			return absf(position.x - (arena_rect.position.x + body_radius))
		_:
			return absf((arena_rect.end.x - body_radius) - position.x)


func _distance_to_edge_corner(point: Vector2, edge: int) -> float:
	var min_x := arena_rect.position.x + body_radius
	var max_x := arena_rect.end.x - body_radius
	var min_y := arena_rect.position.y + body_radius
	var max_y := arena_rect.end.y - body_radius
	match edge:
		Arena.SpawnEdge.TOP, Arena.SpawnEdge.BOTTOM:
			return minf(absf(point.x - min_x), absf(point.x - max_x))
		_:
			return minf(absf(point.y - min_y), absf(point.y - max_y))


func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return point.distance_to(segment_start)

	var projection := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	var closest_point := segment_start + segment * projection
	return point.distance_to(closest_point)


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


func _clamp_inside_rect(target_position: Vector2, clamp_rect: Rect2) -> Vector2:
	if clamp_rect.size == Vector2.ZERO:
		return target_position

	var min_x := clamp_rect.position.x + body_radius
	var max_x := clamp_rect.end.x - body_radius
	var min_y := clamp_rect.position.y + body_radius
	var max_y := clamp_rect.end.y - body_radius
	return Vector2(
		clamp(target_position.x, min_x, max_x),
		clamp(target_position.y, min_y, max_y)
	)


func _set_motion_state(new_state: MotionState) -> void:
	if motion_state == new_state:
		return

	motion_state = new_state
	state_changed.emit(motion_state)


func _draw() -> void:
	draw_circle(Vector2(0.0, 4.5), body_radius - 1.7, Color(0.0, 0.0, 0.0, 0.18))


func _update_sprite_visuals() -> void:
	if sprite == null:
		return

	sprite.global_position = _get_sprite_target_global_position()
	sprite.global_rotation = 0.0
	sprite.scale = _get_visual_scale()
	sprite.flip_h = facing_left
	sprite.self_modulate = Color.WHITE


func _get_sprite_target_global_position() -> Vector2:
	var offset := SPRITE_BASE_OFFSET
	match motion_state:
		MotionState.STARTLED:
			offset.y += _get_startled_hop_offset()
		MotionState.FLEEING:
			offset.y += roundf(sin(visual_time * 22.0) * 1.5)
		_:
			offset.y += roundf(sin(visual_time * 8.0) * 1.0)
	return (global_position + offset).round()


func _get_visual_scale() -> Vector2:
	if motion_state == MotionState.STARTLED:
		var progress := 1.0 - (startled_time_left / maxf(startled_duration, 0.001))
		if progress < 0.22:
			return Vector2(1.08, 0.92)
		if progress < 0.68:
			return Vector2(0.95, 1.05)
		return Vector2(1.03, 0.97)
	if motion_state == MotionState.FLEEING:
		return Vector2(1.05, 0.95)
	if displacement_time_left > 0.0:
		return Vector2(1.04, 0.96)
	return Vector2.ONE


func _get_startled_hop_offset() -> float:
	var progress := 1.0 - (startled_time_left / maxf(startled_duration, 0.001))
	if progress < 0.18:
		return lerpf(0.0, 1.5, progress / 0.18)
	if progress < 0.48:
		return lerpf(1.5, -5.0, (progress - 0.18) / 0.30)
	if progress < 0.76:
		return lerpf(-5.0, -1.0, (progress - 0.48) / 0.28)
	return lerpf(-1.0, 0.0, (progress - 0.76) / 0.24)
