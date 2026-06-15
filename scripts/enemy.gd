extends CharacterBody2D
class_name Enemy

const SPRITE_BASE_OFFSET := Vector2(0.0, -2.0)

signal killed(enemy_position: Vector2, score_value: int)

@export var move_speed := 42.0
@export var score_value := 1
@export var body_radius := 8.0
@export var separation_distance := 18.0
@export var separation_strength := 48.0
@export var body_color := Color8(176, 92, 92)
@export var hit_flash_color := Color8(255, 216, 216)
@export var death_particle_color := Color8(255, 228, 182)

var player: Player
var arena_rect := Rect2()
var active := true
var is_dying := false
var hit_flash_left := 0.0
var death_left := 0.0
var visual_time := 0.0
var last_sprite_target_global_position := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemy")
	if sprite != null:
		sprite.top_level = true
	_update_sprite_visuals()
	queue_redraw()


func setup(player_ref: Player, new_arena_rect: Rect2, starting_speed: float) -> void:
	player = player_ref
	arena_rect = new_arena_rect
	move_speed = starting_speed


func set_active(is_active: bool) -> void:
	active = is_active
	if not active:
		velocity = Vector2.ZERO


func take_spear_hit() -> void:
	if is_dying:
		return

	is_dying = true
	hit_flash_left = 0.08
	death_left = 0.2
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	killed.emit(global_position, score_value)
	queue_redraw()


func _physics_process(delta: float) -> void:
	visual_time += delta

	if _update_effect_timers(delta):
		_update_sprite_visuals()
		return

	if _can_run_behavior():
		_process_alive_behavior(delta)

	_update_sprite_visuals()
	queue_redraw()


func _update_effect_timers(delta: float) -> bool:
	if hit_flash_left > 0.0:
		hit_flash_left = max(hit_flash_left - delta, 0.0)

	if is_dying:
		death_left = max(death_left - delta, 0.0)
		queue_redraw()
		if death_left == 0.0:
			queue_free()
		return true

	return false


func _can_run_behavior() -> bool:
	return active and player != null and player.is_alive()


func _process_alive_behavior(_delta: float) -> void:
	_move_with_velocity(_get_chase_velocity())
	_try_contact_damage()


func _get_chase_velocity() -> Vector2:
	var desired_velocity := _get_direction_to_player() * move_speed + _get_separation_push()
	var speed_limit := move_speed * 1.2
	if desired_velocity.length() > speed_limit:
		desired_velocity = desired_velocity.normalized() * speed_limit
	return desired_velocity


func _get_direction_to_player() -> Vector2:
	if player == null:
		return Vector2.ZERO

	var to_player := player.global_position - global_position
	if to_player.length_squared() <= 0.001:
		return Vector2.ZERO

	return to_player.normalized()


func _move_with_velocity(desired_velocity: Vector2) -> void:
	velocity = desired_velocity
	move_and_slide()
	_clamp_inside_arena()


func _try_contact_damage() -> void:
	if _is_touching_player():
		player.take_damage(global_position)


func _is_touching_player() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= body_radius + player.damage_hit_radius - 2.0


func _clamp_inside_arena() -> void:
	if arena_rect.size == Vector2.ZERO:
		return

	global_position.x = clamp(
		global_position.x,
		arena_rect.position.x + body_radius,
		arena_rect.end.x - body_radius
	)
	global_position.y = clamp(
		global_position.y,
		arena_rect.position.y + body_radius,
		arena_rect.end.y - body_radius
	)


func _get_separation_push() -> Vector2:
	var push := Vector2.ZERO
	for other_node in get_tree().get_nodes_in_group("enemy"):
		var other := other_node as Enemy
		if other == null or other == self or other.is_dying:
			continue

		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance > 0.001 and distance < separation_distance:
			var weight := (separation_distance - distance) / separation_distance
			push += offset.normalized() * weight * separation_strength

	return push


func _draw() -> void:
	var fill_color := _get_current_fill_color()
	if is_dying:
		_draw_death_effect(fill_color)
		return

	_draw_alive_body(fill_color)


func _get_current_fill_color() -> Color:
	if hit_flash_left > 0.0:
		return hit_flash_color
	return body_color


func _draw_alive_body(fill_color: Color) -> void:
	draw_circle(Vector2(0.0, 6.0), body_radius - 1.5, Color(0.0, 0.0, 0.0, 0.22))


func _draw_death_effect(fill_color: Color) -> void:
	var death_ratio := death_left / 0.2
	var radius := lerpf(2.0, body_radius, death_ratio)
	draw_circle(Vector2.ZERO, radius, fill_color)

	var particle_progress := 1.0 - death_ratio
	for index in 4:
		var angle := particle_progress * TAU + float(index) * TAU / 4.0
		var particle_offset := Vector2.RIGHT.rotated(angle) * (5.0 + particle_progress * 9.0)
		draw_circle(particle_offset, 1.5, death_particle_color)


func _update_sprite_visuals() -> void:
	if sprite == null:
		return

	sprite.visible = not is_dying
	if not sprite.visible:
		return

	last_sprite_target_global_position = _get_sprite_target_global_position()
	sprite.global_position = last_sprite_target_global_position
	sprite.global_rotation = 0.0
	sprite.scale = _get_visual_scale()

	var modulate_color := _get_current_fill_color()
	if not active:
		modulate_color = modulate_color.darkened(0.2)
	sprite.self_modulate = modulate_color


func _get_visual_offset() -> Vector2:
	var bob_phase := visual_time * 6.0 + float(get_instance_id() % 19)
	var bob_offset := roundf(sin(bob_phase))
	return SPRITE_BASE_OFFSET + Vector2(0.0, bob_offset)


func _get_visual_scale() -> Vector2:
	return Vector2.ONE


func _get_sprite_target_global_position() -> Vector2:
	return (global_position + _get_visual_offset()).round()
