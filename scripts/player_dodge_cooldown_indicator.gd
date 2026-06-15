extends Node2D
class_name PlayerDodgeCooldownIndicator

@export var enabled := true
@export var world_offset := Vector2(8.0, -13.0)
@export var wisp_color := Color8(190, 220, 226, 210)
@export var ready_glint_color := Color8(238, 244, 218, 225)
@export var ready_glint_duration := 0.12

var cooldown_progress := 0.0
var ready_glint_left := 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	global_rotation = 0.0
	scale = Vector2.ONE
	z_index = 21
	clear_indicator()


func begin_cooldown() -> void:
	ready_glint_left = 0.0
	cooldown_progress = 1.0
	visible = enabled
	queue_redraw()


func show_ready_glint() -> void:
	if not enabled:
		clear_indicator()
		return

	cooldown_progress = 0.0
	ready_glint_left = ready_glint_duration
	visible = true
	queue_redraw()


func sync_to_player(
	player_position: Vector2,
	cooldown_left: float,
	cooldown_duration: float,
	player_active: bool,
	delta: float
) -> void:
	global_position = (player_position + world_offset).round()
	global_rotation = 0.0
	scale = Vector2.ONE

	if not enabled or not player_active:
		clear_indicator()
		return

	if cooldown_left > 0.0 and cooldown_duration > 0.0:
		cooldown_progress = clampf(cooldown_left / cooldown_duration, 0.0, 1.0)
		ready_glint_left = 0.0
		visible = true
	elif ready_glint_left > 0.0:
		ready_glint_left = maxf(ready_glint_left - delta, 0.0)
		visible = ready_glint_left > 0.0
	else:
		cooldown_progress = 0.0
		visible = false

	queue_redraw()


func clear_indicator() -> void:
	cooldown_progress = 0.0
	ready_glint_left = 0.0
	visible = false
	queue_redraw()


func _draw() -> void:
	if cooldown_progress > 0.0:
		_draw_cooldown_wisp()
	elif ready_glint_left > 0.0:
		_draw_ready_glint()


func _draw_cooldown_wisp() -> void:
	var current_color := wisp_color
	current_color.a *= 0.35 + cooldown_progress * 0.65

	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), current_color)
	if cooldown_progress > 0.34:
		draw_rect(Rect2(Vector2(-1.0, 1.0), Vector2.ONE), current_color)
	if cooldown_progress > 0.67:
		draw_rect(Rect2(Vector2(0.0, 2.0), Vector2.ONE), current_color)
		draw_rect(Rect2(Vector2(1.0, -1.0), Vector2.ONE), current_color)


func _draw_ready_glint() -> void:
	var glint_progress := ready_glint_left / maxf(ready_glint_duration, 0.001)
	var current_color := ready_glint_color
	current_color.a *= glint_progress

	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), current_color)
	if glint_progress > 0.35:
		draw_rect(Rect2(Vector2(-1.0, 0.0), Vector2.ONE), current_color)
		draw_rect(Rect2(Vector2(1.0, 0.0), Vector2.ONE), current_color)
		draw_rect(Rect2(Vector2(0.0, -1.0), Vector2.ONE), current_color)
