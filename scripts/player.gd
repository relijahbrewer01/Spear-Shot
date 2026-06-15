extends CharacterBody2D
class_name Player

const SPRITE_BASE_OFFSET := Vector2(0.0, -2.0)

signal health_changed(new_health: int)
signal damaged(new_health: int)
signal died

@export var move_speed := 115.0
@export var max_health := 3
@export var invulnerability_duration := 0.8
@export var destination_reach_distance := 4.0
@export var body_radius := 8.0
@export var damage_hit_radius := 7.0
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

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_pips: PlayerHealthPips = $HealthPips


func _ready() -> void:
	health = max_health
	add_to_group("player")
	if sprite != null:
		sprite.top_level = true
	_update_health_pips()
	_update_sprite_visuals(0.0)
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
	global_position = _clamp_position_to_arena(start_position)
	_update_health_pips()
	_update_health_pips_transform()
	_update_sprite_visuals(0.0)
	queue_redraw()


func set_active(is_active: bool) -> void:
	active = is_active
	if not active:
		velocity = Vector2.ZERO
		clear_move_destination()


func is_alive() -> bool:
	return health > 0


func set_move_destination(target_position: Vector2) -> void:
	move_destination = _clamp_position_to_arena(target_position)
	has_move_destination = true


func clear_move_destination() -> void:
	has_move_destination = false


func take_damage(_source_position: Vector2) -> void:
	if invulnerability_left > 0.0 or not is_alive():
		return

	health -= 1
	hurt_flash_left = 0.16
	invulnerability_left = invulnerability_duration
	_update_health_pips()
	health_changed.emit(health)
	damaged.emit(health)
	queue_redraw()

	if health <= 0:
		active = false
		velocity = Vector2.ZERO
		died.emit()


func _physics_process(delta: float) -> void:
	if invulnerability_left > 0.0:
		invulnerability_left = max(invulnerability_left - delta, 0.0)

	if hurt_flash_left > 0.0:
		hurt_flash_left = max(hurt_flash_left - delta, 0.0)

	if active:
		var move_input := _get_move_input()
		velocity = move_input * move_speed
		move_and_slide()
		_clamp_inside_arena()
		_update_aim()

	_update_sprite_visuals(delta)
	_update_health_pips_transform()
	queue_redraw()


func _clamp_inside_arena() -> void:
	if arena_rect.size == Vector2.ZERO:
		return

	global_position = _clamp_position_to_arena(global_position)


func _update_aim() -> void:
	var aim_vector := get_global_mouse_position() - global_position
	if aim_vector.length_squared() > 0.001:
		rotation = aim_vector.angle()


func _get_move_input() -> Vector2:
	var manual_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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


func _update_sprite_visuals(delta: float) -> void:
	if sprite == null:
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

	var local_offset := SPRITE_BASE_OFFSET + Vector2(0.0, bob_offset)
	sprite.global_position = (global_position + local_offset.rotated(rotation)).round()
	sprite.global_rotation = rotation
	sprite.scale = Vector2.ONE
	sprite.modulate = _get_sprite_modulate()


func _get_sprite_modulate() -> Color:
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
