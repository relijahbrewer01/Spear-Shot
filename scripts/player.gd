extends CharacterBody2D
class_name Player

const SPRITE_BASE_OFFSET := Vector2(0.0, -2.0)
const BODY_VISUAL_Z_INDEX := 10
const DAMAGE_SOURCE_CONTACT := &"contact"
const DAMAGE_SOURCE_DART := &"dart"
const INVALID_DART_BURST_ID := -1
const INVALID_DART_INDEX := -1
const INVALID_PROJECTILE_TOKEN := -1
const MOVEMENT_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_left",
	&"move_down",
	&"move_right",
]

enum ActionState {
	NORMAL,
	DODGING,
	FORCED_MOVEMENT,
	DISABLED,
}

signal health_changed(new_health: int)
signal damaged(new_health: int)
signal died
signal dodge_started(direction: Vector2)
signal dodge_ended
signal dodge_ready

@export var move_speed := 115.0
@export var max_health := 3
@export var invulnerability_duration := 0.8
@export var destination_reach_distance := 4.0
@export var body_radius := 8.0
@export var damage_hit_radius := 7.0
@export var dodge_duration := 0.20
@export var dodge_distance := 36.0
@export var dodge_cooldown := 2.0
@export var dodge_exit_invulnerability_duration := 0.10
@export var dodge_spin_turns := 1.0
@export_range(0.0, 1.0, 0.01) var horizontal_facing_dead_zone := 0.12
@export_range(1, 8, 1) var dodge_trail_afterimage_count := 4
@export var dodge_trail_sample_interval := 0.045
@export var dodge_trail_lifetime := 0.22
@export var dodge_trail_color := Color8(176, 212, 255, 92)
@export var body_color := Color8(111, 182, 255)
@export var hurt_color := Color8(255, 244, 180)

var health := 3
var arena_rect := Rect2()
var active := true
var invulnerability_left := 0.0
var hurt_flash_left := 0.0
var has_move_destination := false
var move_destination := Vector2.ZERO
var walk_cycle_time := 0.0
var action_state: ActionState = ActionState.NORMAL
var dodge_direction := Vector2.RIGHT
var dodge_time_left := 0.0
var dodge_cooldown_left := 0.0
var dodge_exit_invulnerability_left := 0.0
var dodge_spin_direction := 1.0
var forced_movement_direction := Vector2.ZERO
var forced_movement_distance := 0.0
var forced_movement_duration := 0.0
var forced_movement_time_left := 0.0
var forced_movement_velocity := Vector2.ZERO
var last_valid_aim_direction := Vector2.RIGHT
var facing_direction := 1
var suppressed_movement_actions: Dictionary = {}
var has_pending_post_dodge_destination := false
var pending_post_dodge_destination := Vector2.ZERO
var damaged_dart_indices_by_burst: Dictionary = {}
var accepted_dart_projectile_tokens: Dictionary = {}

@onready var body_visual: Node2D = $BodyVisual
@onready var body_sprite: Sprite2D = $BodyVisual/Sprite2D
@onready var dodge_trail: PlayerDodgeTrail = $DodgeTrail
@onready var cooldown_indicator: PlayerDodgeCooldownIndicator = $CooldownIndicator
@onready var health_pips: PlayerHealthPips = $HealthPips


func _ready() -> void:
	health = max_health
	add_to_group("player")
	rotation = 0.0
	if body_visual != null:
		body_visual.top_level = true
		body_visual.z_index = BODY_VISUAL_Z_INDEX
	if dodge_trail != null and body_sprite != null:
		dodge_trail.setup_from_sprite(
			body_sprite,
			dodge_trail_afterimage_count,
			dodge_trail_sample_interval,
			dodge_trail_lifetime,
			dodge_trail_color
		)
	_update_health_pips()
	_clear_dodge_visuals()
	_update_body_visuals(0.0)
	queue_redraw()


func set_arena_rect(new_arena_rect: Rect2) -> void:
	arena_rect = new_arena_rect


func reset_for_new_run(start_position: Vector2, new_arena_rect: Rect2) -> void:
	arena_rect = new_arena_rect
	health = max_health
	active = true
	invulnerability_left = 0.0
	hurt_flash_left = 0.0
	has_move_destination = false
	move_destination = Vector2.ZERO
	walk_cycle_time = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0
	facing_direction = 1
	action_state = ActionState.NORMAL
	dodge_direction = Vector2.RIGHT
	dodge_time_left = 0.0
	dodge_cooldown_left = 0.0
	dodge_exit_invulnerability_left = 0.0
	dodge_spin_direction = 1.0
	_clear_forced_movement_state()
	last_valid_aim_direction = Vector2.RIGHT
	global_position = _clamp_position_to_arena(start_position)
	suppressed_movement_actions.clear()
	_clear_pending_post_dodge_destination()
	_clear_dart_damage_contexts()
	_update_health_pips()
	_update_health_pips_transform()
	_clear_cooldown_indicator()
	_clear_dodge_visuals()
	_update_body_visuals(0.0)
	queue_redraw()


func set_active(is_active: bool) -> void:
	active = is_active
	if not active:
		_cancel_dodge()
		_clear_forced_movement_state()
		action_state = ActionState.DISABLED
		velocity = Vector2.ZERO
		clear_move_destination()
		dodge_exit_invulnerability_left = 0.0
		suppressed_movement_actions.clear()
		_clear_pending_post_dodge_destination()
		_clear_cooldown_indicator()
		_clear_dodge_visuals()
	elif health > 0:
		action_state = ActionState.NORMAL


func is_alive() -> bool:
	return health > 0


func is_dodging() -> bool:
	return action_state == ActionState.DODGING


func is_in_forced_movement() -> bool:
	return action_state == ActionState.FORCED_MOVEMENT


func can_start_dodge() -> bool:
	return (
		active
		and is_alive()
		and action_state != ActionState.DODGING
		and action_state != ActionState.DISABLED
		and dodge_cooldown_left == 0.0
	)


func is_damage_invulnerable() -> bool:
	return invulnerability_left > 0.0 or is_dodging() or dodge_exit_invulnerability_left > 0.0


func can_take_damage(
	damage_source: StringName = DAMAGE_SOURCE_CONTACT,
	dart_burst_id: int = INVALID_DART_BURST_ID,
	dart_index: int = INVALID_DART_INDEX,
	projectile_token: int = INVALID_PROJECTILE_TOKEN
) -> bool:
	if not is_alive():
		return false
	if is_dodging() or dodge_exit_invulnerability_left > 0.0:
		return false
	if _is_duplicate_dart_damage_context(
		damage_source,
		dart_burst_id,
		dart_index,
		projectile_token
	):
		return false
	if invulnerability_left <= 0.0:
		return true
	return _can_accept_same_burst_dart_followup(
		damage_source,
		dart_burst_id,
		dart_index,
		projectile_token
	)


func get_manual_input_direction() -> Vector2:
	var movement_input := Vector2(
		_get_available_movement_strength(&"move_right") - _get_available_movement_strength(&"move_left"),
		_get_available_movement_strength(&"move_down") - _get_available_movement_strength(&"move_up")
	)
	return movement_input.limit_length(1.0)


func has_active_move_destination() -> bool:
	if not has_move_destination:
		return false

	return move_destination.distance_to(global_position) > destination_reach_distance


func get_move_destination_direction() -> Vector2:
	if not has_active_move_destination():
		return Vector2.ZERO

	return (move_destination - global_position).normalized()


func get_buffered_move_destination_direction() -> Vector2:
	if not has_pending_post_dodge_destination:
		return Vector2.ZERO

	return (pending_post_dodge_destination - global_position).normalized()


func get_last_valid_aim_direction() -> Vector2:
	return last_valid_aim_direction


func get_facing_direction() -> int:
	return facing_direction


func get_space_dodge_direction() -> Vector2:
	var manual_direction := get_manual_input_direction()
	if manual_direction.length_squared() > 0.0:
		return manual_direction.normalized()

	var move_destination_direction := get_move_destination_direction()
	if move_destination_direction.length_squared() > 0.0:
		return move_destination_direction

	var buffered_destination_direction := get_buffered_move_destination_direction()
	if buffered_destination_direction.length_squared() > 0.0:
		return buffered_destination_direction

	return last_valid_aim_direction


func try_start_aim_dodge(direction: Vector2) -> bool:
	return try_start_dodge(direction, true)


func try_start_movement_dodge(direction: Vector2) -> bool:
	return try_start_dodge(direction, false)


func try_start_dodge(direction: Vector2, suppress_held_movement := false) -> bool:
	if not can_start_dodge():
		return false

	if direction.length_squared() <= 0.001:
		direction = last_valid_aim_direction
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT

	_clear_forced_movement_state()
	action_state = ActionState.DODGING
	dodge_direction = direction.normalized()
	dodge_spin_direction = _get_dodge_spin_direction(dodge_direction)
	dodge_time_left = dodge_duration
	dodge_cooldown_left = dodge_cooldown
	dodge_exit_invulnerability_left = 0.0
	velocity = Vector2.ZERO
	_clear_pending_post_dodge_destination()
	if suppress_held_movement:
		clear_move_destination()
		_suppress_current_movement_actions()
	if dodge_trail != null:
		dodge_trail.begin_dodge()
	if cooldown_indicator != null:
		cooldown_indicator.begin_cooldown()
	dodge_started.emit(dodge_direction)
	queue_redraw()
	return true


func try_start_forced_movement(direction: Vector2, distance: float, duration: float) -> bool:
	if not active or not is_alive():
		return false
	if is_dodging() or dodge_exit_invulnerability_left > 0.0:
		return false
	if direction.length_squared() <= 0.001:
		return false
	if distance <= 0.0 or duration <= 0.0:
		return false

	action_state = ActionState.FORCED_MOVEMENT
	forced_movement_direction = direction.normalized()
	forced_movement_distance = distance
	forced_movement_duration = duration
	forced_movement_time_left = duration
	forced_movement_velocity = forced_movement_direction * (distance / duration)
	velocity = forced_movement_velocity
	_update_horizontal_facing(forced_movement_direction)
	queue_redraw()
	return true


func set_move_destination(target_position: Vector2) -> void:
	move_destination = _clamp_position_to_arena(target_position)
	has_move_destination = true
	_clear_pending_post_dodge_destination()


func buffer_post_dodge_destination(target_position: Vector2) -> void:
	pending_post_dodge_destination = _clamp_position_to_arena(target_position)
	has_pending_post_dodge_destination = true


func clear_move_destination() -> void:
	has_move_destination = false


func take_damage(
	_source_position: Vector2,
	damage_source: StringName = DAMAGE_SOURCE_CONTACT,
	dart_burst_id: int = INVALID_DART_BURST_ID,
	dart_index: int = INVALID_DART_INDEX,
	projectile_token: int = INVALID_PROJECTILE_TOKEN
) -> bool:
	if not can_take_damage(damage_source, dart_burst_id, dart_index, projectile_token):
		return false
	if not _record_dart_damage_context(
		damage_source,
		dart_burst_id,
		dart_index,
		projectile_token
	):
		return false

	health -= 1
	hurt_flash_left = 0.16
	invulnerability_left = invulnerability_duration
	_update_health_pips()
	health_changed.emit(health)
	damaged.emit(health)
	queue_redraw()

	if health <= 0:
		active = false
		action_state = ActionState.DISABLED
		dodge_time_left = 0.0
		dodge_exit_invulnerability_left = 0.0
		_clear_forced_movement_state()
		velocity = Vector2.ZERO
		suppressed_movement_actions.clear()
		_clear_pending_post_dodge_destination()
		_clear_cooldown_indicator()
		_clear_dodge_visuals()
		died.emit()

	return true


func _can_accept_same_burst_dart_followup(
	damage_source: StringName,
	dart_burst_id: int,
	dart_index: int,
	projectile_token: int
) -> bool:
	if not _is_valid_dart_damage_context(
		damage_source,
		dart_burst_id,
		dart_index,
		projectile_token
	):
		return false

	var damaged_indices: Dictionary = damaged_dart_indices_by_burst.get(dart_burst_id, {})
	if damaged_indices.size() != 1:
		return false
	if damaged_indices.has(dart_index):
		return false

	return damaged_indices.has(0) or damaged_indices.has(1)


func _record_dart_damage_context(
	damage_source: StringName,
	dart_burst_id: int,
	dart_index: int,
	projectile_token: int
) -> bool:
	if damage_source != DAMAGE_SOURCE_DART:
		return true
	if not _is_valid_dart_damage_context(
		damage_source,
		dart_burst_id,
		dart_index,
		projectile_token
	):
		return false

	var damaged_indices: Dictionary = damaged_dart_indices_by_burst.get(dart_burst_id, {})
	if accepted_dart_projectile_tokens.has(projectile_token):
		return false
	if damaged_indices.has(dart_index):
		return false
	if damaged_indices.size() >= 2:
		return false

	accepted_dart_projectile_tokens[projectile_token] = true
	damaged_indices[dart_index] = true
	damaged_dart_indices_by_burst[dart_burst_id] = damaged_indices
	return true


func _is_duplicate_dart_damage_context(
	damage_source: StringName,
	dart_burst_id: int,
	dart_index: int,
	projectile_token: int
) -> bool:
	if damage_source != DAMAGE_SOURCE_DART:
		return false
	if not _is_valid_dart_damage_context(
		damage_source,
		dart_burst_id,
		dart_index,
		projectile_token
	):
		return false

	var damaged_indices: Dictionary = damaged_dart_indices_by_burst.get(dart_burst_id, {})
	return accepted_dart_projectile_tokens.has(projectile_token) or damaged_indices.has(dart_index)


func _is_valid_dart_damage_context(
	damage_source: StringName,
	dart_burst_id: int,
	dart_index: int,
	projectile_token: int
) -> bool:
	return (
		damage_source == DAMAGE_SOURCE_DART
		and dart_burst_id != INVALID_DART_BURST_ID
		and dart_index >= 0
		and dart_index <= 1
		and projectile_token != INVALID_PROJECTILE_TOKEN
	)


func _clear_dart_damage_contexts() -> void:
	damaged_dart_indices_by_burst.clear()
	accepted_dart_projectile_tokens.clear()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_release_suppressed_movement_actions()

	if invulnerability_left > 0.0:
		invulnerability_left = max(invulnerability_left - delta, 0.0)

	if hurt_flash_left > 0.0:
		hurt_flash_left = max(hurt_flash_left - delta, 0.0)

	if active:
		match action_state:
			ActionState.NORMAL:
				var move_input := _get_move_input()
				_update_horizontal_facing(move_input)
				velocity = move_input * move_speed
				move_and_slide()
				_clamp_inside_arena()
			ActionState.DODGING:
				_process_dodge_motion(minf(delta, dodge_time_left))
			ActionState.FORCED_MOVEMENT:
				_process_forced_movement(minf(delta, forced_movement_time_left))
			ActionState.DISABLED:
				velocity = Vector2.ZERO

		_update_aim()

	_update_body_visuals(delta)
	_update_dodge_trail(delta)
	_update_cooldown_indicator(delta)
	_update_health_pips_transform()
	_advance_dodge_timer(delta)
	_advance_forced_movement_timer(delta)
	queue_redraw()


func _clamp_inside_arena() -> void:
	if arena_rect.size == Vector2.ZERO:
		return

	global_position = _clamp_position_to_arena(global_position)


func _update_aim() -> void:
	var aim_vector := get_global_mouse_position() - global_position
	if aim_vector.length_squared() > 0.001:
		last_valid_aim_direction = aim_vector.normalized()


func _get_move_input() -> Vector2:
	var manual_input := get_manual_input_direction()
	if manual_input.length_squared() > 0.0:
		clear_move_destination()
		return manual_input

	if not has_move_destination:
		return Vector2.ZERO

	var to_destination := move_destination - global_position
	if to_destination.length() <= destination_reach_distance:
		clear_move_destination()
		return Vector2.ZERO

	return to_destination.normalized()


func _update_horizontal_facing(move_input: Vector2) -> void:
	if move_input.x >= horizontal_facing_dead_zone:
		facing_direction = 1
	elif move_input.x <= -horizontal_facing_dead_zone:
		facing_direction = -1


func _get_available_movement_strength(action: StringName) -> float:
	if suppressed_movement_actions.has(action):
		return 0.0
	return Input.get_action_strength(action)


func _suppress_current_movement_actions() -> void:
	for action in MOVEMENT_ACTIONS:
		if Input.is_action_pressed(action):
			suppressed_movement_actions[action] = true


func _release_suppressed_movement_actions() -> void:
	for action in MOVEMENT_ACTIONS:
		if suppressed_movement_actions.has(action) and not Input.is_action_pressed(action):
			suppressed_movement_actions.erase(action)


func _clamp_position_to_arena(target_position: Vector2) -> Vector2:
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


func _draw() -> void:
	var shadow_alpha := 0.2
	if health <= 0:
		shadow_alpha = 0.12

	var shadow_color := body_color.darkened(0.8)
	shadow_color.a = shadow_alpha
	draw_circle(Vector2(0.0, 6.0), body_radius - 2.0, shadow_color)


func _update_body_visuals(delta: float) -> void:
	if body_visual == null or body_sprite == null:
		return

	if active and velocity.length_squared() > 1.0:
		walk_cycle_time += delta * 10.0
	else:
		walk_cycle_time += delta * 4.0

	var speed_ratio := 0.0
	if move_speed > 0.0:
		speed_ratio = clampf(velocity.length() / move_speed, 0.0, 1.0)

	var bob_strength := lerpf(0.0, 1.0, speed_ratio)
	var bob_offset := roundf(sin(walk_cycle_time) * bob_strength)

	body_visual.global_position = (global_position + SPRITE_BASE_OFFSET + Vector2(0.0, bob_offset)).round()
	body_visual.rotation = _get_body_visual_rotation()
	body_visual.scale = Vector2.ONE

	body_sprite.position = Vector2.ZERO
	body_sprite.rotation = 0.0
	body_sprite.scale = Vector2.ONE
	body_sprite.flip_h = facing_direction < 0
	body_sprite.modulate = _get_body_sprite_modulate()


func _get_body_visual_rotation() -> float:
	if not is_dodging() or dodge_duration <= 0.0:
		return 0.0

	var dodge_progress := clampf(1.0 - (dodge_time_left / dodge_duration), 0.0, 1.0)
	return dodge_spin_direction * dodge_progress * TAU * dodge_spin_turns


func _get_body_sprite_modulate() -> Color:
	if health <= 0:
		return Color(0.58, 0.58, 0.6, 1.0)
	if hurt_flash_left > 0.0:
		return hurt_color.lerp(Color.WHITE, 0.55)
	if invulnerability_left > 0.0 and int(invulnerability_left * 18.0) % 2 == 0:
		return Color(1.0, 1.0, 1.0, 0.42)
	return Color.WHITE


func _update_health_pips() -> void:
	if health_pips == null:
		return

	health_pips.set_health_values(health, max_health)


func _update_health_pips_transform() -> void:
	if health_pips == null:
		return

	health_pips.sync_to_player(self)


func _update_cooldown_indicator(delta: float) -> void:
	if cooldown_indicator == null:
		return

	cooldown_indicator.sync_to_player(
		global_position,
		dodge_cooldown_left,
		dodge_cooldown,
		active and is_alive(),
		delta
	)


func _update_dodge_trail(delta: float) -> void:
	if dodge_trail == null or body_visual == null or body_sprite == null:
		return

	if not active or not is_alive():
		dodge_trail.clear_trail()
		return

	dodge_trail.advance_trail(
		delta,
		is_dodging(),
		body_visual.global_position,
		body_visual.global_rotation,
		body_sprite.flip_h
	)


func _update_timers(delta: float) -> void:
	if dodge_cooldown_left > 0.0:
		var previous_cooldown_left := dodge_cooldown_left
		dodge_cooldown_left = max(dodge_cooldown_left - delta, 0.0)
		if previous_cooldown_left > 0.0 and dodge_cooldown_left == 0.0:
			dodge_ready.emit()
			if cooldown_indicator != null:
				cooldown_indicator.show_ready_glint()

	if dodge_exit_invulnerability_left > 0.0:
		dodge_exit_invulnerability_left = max(dodge_exit_invulnerability_left - delta, 0.0)


func _advance_dodge_timer(delta: float) -> void:
	if not is_dodging():
		return

	dodge_time_left = max(dodge_time_left - delta, 0.0)
	if dodge_time_left == 0.0:
		_finish_dodge()


func _process_dodge_motion(delta: float) -> void:
	var dodge_speed := _get_dodge_speed()
	var target_position := _clamp_position_to_arena(global_position + dodge_direction * dodge_speed * delta)
	var actual_movement := target_position - global_position
	global_position = target_position

	if delta > 0.0:
		velocity = actual_movement / delta
	else:
		velocity = Vector2.ZERO


func _process_forced_movement(delta: float) -> void:
	var target_position := _clamp_position_to_arena(global_position + forced_movement_velocity * delta)
	var actual_movement := target_position - global_position
	global_position = target_position

	if delta > 0.0:
		velocity = actual_movement / delta
	else:
		velocity = Vector2.ZERO

	if velocity.length_squared() > 0.0:
		_update_horizontal_facing(velocity.normalized())


func _get_dodge_speed() -> float:
	if dodge_duration <= 0.0:
		return 0.0

	return dodge_distance / dodge_duration


func _get_dodge_spin_direction(direction: Vector2) -> float:
	if direction.x >= horizontal_facing_dead_zone:
		return 1.0
	if direction.x <= -horizontal_facing_dead_zone:
		return -1.0
	return float(facing_direction)


func _finish_dodge() -> void:
	if not is_dodging():
		return

	action_state = ActionState.NORMAL if active and is_alive() else ActionState.DISABLED
	dodge_time_left = 0.0
	dodge_exit_invulnerability_left = dodge_exit_invulnerability_duration
	velocity = Vector2.ZERO
	_reset_body_visual_roll()
	_apply_pending_post_dodge_destination()
	dodge_ended.emit()
	queue_redraw()


func _finish_forced_movement() -> void:
	if not is_in_forced_movement():
		return

	_clear_forced_movement_state()
	action_state = ActionState.NORMAL if active and is_alive() else ActionState.DISABLED
	velocity = Vector2.ZERO
	queue_redraw()


func _cancel_dodge() -> void:
	if is_dodging():
		dodge_ended.emit()

	dodge_time_left = 0.0
	dodge_exit_invulnerability_left = 0.0
	velocity = Vector2.ZERO
	dodge_spin_direction = 1.0
	_clear_pending_post_dodge_destination()
	if active and is_alive():
		action_state = ActionState.NORMAL
	_clear_dodge_visuals()
	queue_redraw()


func _clear_forced_movement_state() -> void:
	forced_movement_direction = Vector2.ZERO
	forced_movement_distance = 0.0
	forced_movement_duration = 0.0
	forced_movement_time_left = 0.0
	forced_movement_velocity = Vector2.ZERO


func _reset_body_visual_roll() -> void:
	if body_visual != null:
		body_visual.rotation = 0.0


func _clear_dodge_visuals() -> void:
	_reset_body_visual_roll()
	if dodge_trail != null:
		dodge_trail.clear_trail()


func _apply_pending_post_dodge_destination() -> void:
	if not has_pending_post_dodge_destination:
		return

	var buffered_destination := pending_post_dodge_destination
	_clear_pending_post_dodge_destination()
	set_move_destination(buffered_destination)


func _clear_pending_post_dodge_destination() -> void:
	has_pending_post_dodge_destination = false
	pending_post_dodge_destination = Vector2.ZERO


func _clear_cooldown_indicator() -> void:
	if cooldown_indicator != null:
		cooldown_indicator.clear_indicator()


func _advance_forced_movement_timer(delta: float) -> void:
	if not is_in_forced_movement():
		return

	forced_movement_time_left = max(forced_movement_time_left - delta, 0.0)
	if forced_movement_time_left == 0.0:
		_finish_forced_movement()
