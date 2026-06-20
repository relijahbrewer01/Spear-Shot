extends Area2D
class_name HeartPickup

const DESTROY_REASON_COLLECTED := &"collected"
const DESTROY_REASON_EXPIRED := &"expired"
const DESTROY_REASON_CLEARED := &"cleared"

signal collected
signal expired
signal warning_started

@export var pickup_radius := 10.0
@export var lifetime := 7.0
@export var warning_duration := 1.5
@export var bob_amplitude := 1.0
@export var bob_speed := 4.0
@export var warning_pulse_speed := 10.0

var player: Player
var arena_rect := Rect2()
var lifetime_left := 0.0
var visual_time := 0.0
var has_started_warning := false
var is_resolved := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	body_entered.connect(_on_body_entered)
	add_to_group("heart_pickup")
	if sprite != null:
		sprite.top_level = true
	_update_sprite_visuals()
	queue_redraw()


func setup(player_ref: Player, new_arena_rect: Rect2, spawn_position: Vector2) -> void:
	player = player_ref
	arena_rect = new_arena_rect
	lifetime_left = lifetime
	has_started_warning = false
	is_resolved = false
	global_position = _clamp_inside_play_rect(spawn_position)
	monitoring = true
	monitorable = false
	if collision_shape != null:
		collision_shape.disabled = false
	_schedule_overlap_check()
	_update_sprite_visuals()
	queue_redraw()


func set_active(is_active: bool) -> void:
	if not is_active:
		destroy_pickup(DESTROY_REASON_CLEARED)


func _physics_process(delta: float) -> void:
	if is_resolved:
		return

	visual_time += delta
	lifetime_left = maxf(lifetime_left - delta, 0.0)
	if not has_started_warning and lifetime_left <= warning_duration:
		has_started_warning = true
		warning_started.emit()

	if lifetime_left == 0.0:
		destroy_pickup(DESTROY_REASON_EXPIRED)
		return

	_update_sprite_visuals()
	queue_redraw()


func destroy_pickup(reason: StringName = DESTROY_REASON_CLEARED) -> void:
	if is_resolved:
		return

	is_resolved = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	match reason:
		DESTROY_REASON_COLLECTED:
			collected.emit()
		DESTROY_REASON_EXPIRED:
			expired.emit()

	queue_free()


func _on_body_entered(body: Node) -> void:
	if is_resolved:
		return
	if body != player:
		return

	_try_collect()


func _try_collect() -> void:
	if is_resolved or player == null:
		return
	if not player.try_collect_heart_runner_pickup():
		return

	destroy_pickup(DESTROY_REASON_COLLECTED)


func _schedule_overlap_check() -> void:
	call_deferred("_check_player_overlap")


func _check_player_overlap() -> void:
	if _try_collect_overlapping_player():
		return

	await get_tree().physics_frame
	_try_collect_overlapping_player()


func _try_collect_overlapping_player() -> bool:
	if is_resolved or not monitoring:
		return false

	for body in get_overlapping_bodies():
		if body == player:
			_try_collect()
			return true

	return false


func _clamp_inside_play_rect(target_position: Vector2) -> Vector2:
	if arena_rect.size == Vector2.ZERO:
		return target_position

	return Vector2(
		clamp(
			target_position.x,
			arena_rect.position.x + pickup_radius,
			arena_rect.end.x - pickup_radius
		),
		clamp(
			target_position.y,
			arena_rect.position.y + pickup_radius,
			arena_rect.end.y - pickup_radius
		)
	)


func _draw() -> void:
	draw_circle(Vector2(0.0, 3.5), pickup_radius * 0.35, Color(0.0, 0.0, 0.0, 0.15))


func _update_sprite_visuals() -> void:
	if sprite == null:
		return

	var warning_strength := _get_warning_strength()
	var bob_offset := roundf(sin(visual_time * bob_speed) * bob_amplitude)
	sprite.global_position = (global_position + Vector2(0.0, -2.0 + bob_offset)).round()
	sprite.global_rotation = 0.0
	sprite.scale = Vector2.ONE * (1.0 + warning_strength * 0.06)

	var modulate_color := Color.WHITE
	if warning_strength > 0.0 and int(visual_time * warning_pulse_speed) % 2 == 0:
		modulate_color.a = 0.68
	sprite.self_modulate = modulate_color


func _get_warning_strength() -> float:
	if not has_started_warning or warning_duration <= 0.0:
		return 0.0
	return clampf(1.0 - lifetime_left / warning_duration, 0.0, 1.0)
