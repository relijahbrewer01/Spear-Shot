extends Node2D
class_name PlayerHealthPips

@export var max_supported_pips := 4
@export var pip_radius := 2.0
@export var pip_spacing := 6.0
@export var vertical_offset := 14.0
@export var filled_color := Color8(255, 241, 186)
@export var empty_color := Color8(86, 96, 97, 190)
@export var bonus_filled_color := Color8(226, 112, 96)
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.28)
@export var bonus_vertical_offset := 6.0

var current_health := 3
var base_max_health := 3
var bonus_pip_count := 0


func _ready() -> void:
	top_level = true
	queue_redraw()


func set_health_values(
	new_current_health: int,
	new_base_max_health: int,
	new_bonus_pip_count := 0
) -> void:
	current_health = maxi(new_current_health, 0)
	base_max_health = maxi(new_base_max_health, 0)
	bonus_pip_count = clampi(new_bonus_pip_count, 0, max_supported_pips - base_max_health)
	queue_redraw()


func sync_to_player(player: Player) -> void:
	if player == null:
		return

	global_position = (player.global_position + Vector2(0.0, vertical_offset)).round()
	global_rotation = 0.0
	z_index = 20


func _draw() -> void:
	var visible_base_pips := mini(max_supported_pips, base_max_health)
	if visible_base_pips > 0:
		for pip_index in range(visible_base_pips):
			var pip_position := _get_pip_position(pip_index, visible_base_pips)
			var pip_color := filled_color if pip_index < current_health else empty_color

			draw_circle(pip_position + Vector2(0.0, 1.0), pip_radius + 0.7, shadow_color)
			draw_circle(pip_position, pip_radius, pip_color)

	if bonus_pip_count > 0 and current_health > base_max_health:
		var bonus_position := _get_bonus_pip_position()
		draw_circle(bonus_position + Vector2(0.0, 1.0), pip_radius + 0.7, shadow_color)
		draw_circle(bonus_position, pip_radius, bonus_filled_color)


func _get_pip_position(pip_index: int, visible_pips: int) -> Vector2:
	var start_x := -float(visible_pips - 1) * pip_spacing * 0.5
	var x := start_x + float(pip_index) * pip_spacing
	var y := 0.0

	match visible_pips:
		3:
			if pip_index == 1:
				y = 1.0
			else:
				y = 0.0
		4:
			if pip_index == 1 or pip_index == 2:
				y = 1.0
			else:
				y = 0.0

	return Vector2(x, y)


func _get_bonus_pip_position() -> Vector2:
	return Vector2(0.0, bonus_vertical_offset)
