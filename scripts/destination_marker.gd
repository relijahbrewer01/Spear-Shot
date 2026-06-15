extends Node2D
class_name DestinationMarker

@export var enabled := true
@export var display_duration := 0.38
@export var marker_color := Color8(255, 241, 186)
@export var base_radius := 4.0
@export var jaw_length := 2.2
@export var pulse_distance := 1.3

var fade_left := 0.0


func _ready() -> void:
	visible = false


func show_marker(target_position: Vector2) -> void:
	if not enabled:
		return

	global_position = target_position.round()
	fade_left = display_duration
	visible = true
	queue_redraw()


func clear_marker() -> void:
	fade_left = 0.0
	visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if fade_left <= 0.0:
		return

	fade_left = maxf(fade_left - delta, 0.0)
	if fade_left == 0.0:
		visible = false

	queue_redraw()


func _draw() -> void:
	if fade_left <= 0.0:
		return

	var progress := fade_left / display_duration
	var pulse := (1.0 - progress) * pulse_distance
	var current_radius := base_radius + pulse
	var current_color := marker_color
	current_color.a = 0.25 + progress * 0.75

	var center_ring_color := current_color
	center_ring_color.a *= 0.45
	draw_circle(Vector2.ZERO, 0.9 + pulse * 0.4, center_ring_color)

	_draw_jaw(-1.0, current_radius, current_color)
	_draw_jaw(1.0, current_radius, current_color)


func _draw_jaw(direction: float, jaw_radius: float, jaw_color: Color) -> void:
	var outer_x := jaw_radius * direction
	var inner_x := (jaw_radius - jaw_length) * direction
	var top_outer := Vector2(outer_x, -2.1)
	var mid_outer := Vector2(outer_x, 0.0)
	var bottom_outer := Vector2(outer_x, 2.1)
	var top_inner := Vector2(inner_x, -0.8)
	var mid_inner := Vector2(inner_x + 0.4 * direction, 0.0)
	var bottom_inner := Vector2(inner_x, 0.8)

	draw_line(top_outer, top_inner, jaw_color, 1.0)
	draw_line(mid_outer, mid_inner, jaw_color, 1.0)
	draw_line(bottom_outer, bottom_inner, jaw_color, 1.0)
	draw_line(top_outer, bottom_outer, jaw_color, 1.0)
