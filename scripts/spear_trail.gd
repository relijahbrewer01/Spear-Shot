extends Node2D
class_name SpearTrail

@export var trail_color := Color8(223, 205, 169, 140)
@export var line_width := 2.0

var global_points: Array[Vector2] = []


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	global_rotation = 0.0
	z_index = 8
	visible = false


func set_trail_points(new_points: Array[Vector2]) -> void:
	global_points.clear()
	for point in new_points:
		global_points.append(point.round())
	visible = global_points.size() > 1
	queue_redraw()


func clear_trail() -> void:
	global_points.clear()
	visible = false
	queue_redraw()


func _draw() -> void:
	if global_points.size() <= 1:
		return

	for segment_index in range(global_points.size() - 1):
		var start_point := to_local(global_points[segment_index])
		var end_point := to_local(global_points[segment_index + 1])
		var segment_alpha := float(segment_index + 1) / float(global_points.size())
		var segment_color := trail_color
		segment_color.a *= segment_alpha
		draw_line(start_point, end_point, segment_color, line_width)
