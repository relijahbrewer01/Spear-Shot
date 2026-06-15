extends Node2D
class_name EncounterTelegraph

@export var marker_color := Color8(255, 225, 150)
@export var marker_shadow_color := Color8(71, 47, 31, 180)
@export var edge_inset := 5.0
@export var marker_half_length := 17.0
@export var pulse_speed := 9.0

var play_rect := Rect2()
var warning_edges: Array[int] = []
var warning_duration := 0.0
var warning_time_left := 0.0
var active := false


func _ready() -> void:
	set_process(false)


func setup(new_play_rect: Rect2) -> void:
	play_rect = new_play_rect
	queue_redraw()


func show_warning(edges: Array[int], duration: float) -> void:
	warning_edges = edges.duplicate()
	warning_duration = maxf(duration, 0.01)
	warning_time_left = warning_duration
	active = true
	set_process(true)
	queue_redraw()


func clear_warning() -> void:
	active = false
	warning_edges.clear()
	warning_time_left = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return

	warning_time_left = maxf(warning_time_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if not active or play_rect.size == Vector2.ZERO:
		return

	var elapsed := warning_duration - warning_time_left
	var pulse := (sin(elapsed * pulse_speed) + 1.0) * 0.5
	var draw_color := marker_color
	draw_color.a = 0.55 + pulse * 0.4
	var inward_offset := roundf(pulse * 3.0)

	for edge in warning_edges:
		_draw_edge_marker(edge, inward_offset, marker_shadow_color, 3.0)
		_draw_edge_marker(edge, inward_offset, draw_color, 1.5)


func _draw_edge_marker(edge: int, pulse_offset: float, color: Color, width: float) -> void:
	var center := play_rect.get_center()
	var tangent := Vector2.RIGHT
	var inward := Vector2.DOWN
	var marker_center := Vector2(center.x, play_rect.position.y + edge_inset + pulse_offset)

	match edge:
		Arena.SpawnEdge.BOTTOM:
			tangent = Vector2.RIGHT
			inward = Vector2.UP
			marker_center = Vector2(center.x, play_rect.end.y - edge_inset - pulse_offset)
		Arena.SpawnEdge.LEFT:
			tangent = Vector2.DOWN
			inward = Vector2.RIGHT
			marker_center = Vector2(play_rect.position.x + edge_inset + pulse_offset, center.y)
		Arena.SpawnEdge.RIGHT:
			tangent = Vector2.DOWN
			inward = Vector2.LEFT
			marker_center = Vector2(play_rect.end.x - edge_inset - pulse_offset, center.y)

	var left_point := marker_center - tangent * marker_half_length
	var right_point := marker_center + tangent * marker_half_length
	draw_line(left_point, right_point, color, width)
	draw_line(left_point, left_point + inward * 7.0 + tangent * 5.0, color, width)
	draw_line(right_point, right_point + inward * 7.0 - tangent * 5.0, color, width)
