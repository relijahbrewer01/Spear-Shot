extends Node2D
class_name ExploderBlastEffect

@export var duration := 0.24
@export var core_flash_color := Color8(255, 230, 188)
@export var shockwave_color := Color8(214, 176, 122, 180)
@export var dust_color := Color8(115, 90, 64, 120)

var time_left := 0.0
var core_radius := 29.0
var outer_radius := 54.0


func _ready() -> void:
	time_left = duration
	queue_redraw()


func setup(new_core_radius: float, new_outer_radius: float) -> void:
	core_radius = new_core_radius
	outer_radius = new_outer_radius
	time_left = duration
	queue_redraw()


func _process(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	queue_redraw()
	if time_left == 0.0:
		queue_free()


func _draw() -> void:
	if duration <= 0.0:
		return

	var progress := clampf(1.0 - time_left / duration, 0.0, 1.0)
	var core_progress := minf(progress * 1.25, 1.0)
	var current_core_radius := lerpf(6.0, core_radius, core_progress)
	var current_outer_radius := lerpf(10.0, outer_radius, progress)

	var core_color := core_flash_color
	core_color.a = clampf(1.0 - progress * 1.2, 0.0, 1.0)
	draw_circle(Vector2.ZERO, current_core_radius, core_color)

	var shock_color := shockwave_color
	shock_color.a *= clampf(1.0 - progress, 0.0, 1.0)
	draw_arc(Vector2.ZERO, current_outer_radius, 0.0, TAU, 28, shock_color, 3.0)

	var dust_ring_color := dust_color
	dust_ring_color.a *= clampf(1.0 - progress * 0.85, 0.0, 1.0)
	draw_arc(Vector2.ZERO, current_outer_radius - 5.0, 0.0, TAU, 28, dust_ring_color, 2.0)
