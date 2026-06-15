extends Node2D
class_name Arena

const FLOOR_TEXTURE := preload("res://art/arena/arena_floor.png")
const INVALID_SPAWN_POSITION := Vector2(INF, INF)

enum SpawnEdge {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
}

@export var arena_size := Vector2(384.0, 216.0)
@export var play_margin := 16.0
@export var floor_color := Color8(70, 84, 73)
@export var boundary_color := Color8(204, 220, 190, 170)
@export var marking_color := Color8(140, 161, 131, 150)

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	queue_redraw()


func get_play_rect() -> Rect2:
	return Rect2(
		Vector2(play_margin, play_margin),
		arena_size - Vector2.ONE * play_margin * 2.0
	)


func clamp_to_play_rect(target_position: Vector2, padding: float = 0.0) -> Vector2:
	var play_rect := get_play_rect()
	return Vector2(
		clamp(target_position.x, play_rect.position.x + padding, play_rect.end.x - padding),
		clamp(target_position.y, play_rect.position.y + padding, play_rect.end.y - padding)
	)


func get_random_spawn_edge() -> int:
	return rng.randi_range(SpawnEdge.TOP, SpawnEdge.RIGHT)


static func get_opposite_spawn_edge(spawn_edge: int) -> int:
	match spawn_edge:
		SpawnEdge.TOP:
			return SpawnEdge.BOTTOM
		SpawnEdge.BOTTOM:
			return SpawnEdge.TOP
		SpawnEdge.LEFT:
			return SpawnEdge.RIGHT
		_:
			return SpawnEdge.LEFT


func get_random_spawn_position(avoid_position: Vector2, avoid_radius: float) -> Vector2:
	var avoid_positions: Array[Vector2] = [avoid_position]
	var avoid_radii: Array[float] = [avoid_radius]
	return find_safe_spawn_position(
		get_random_spawn_edge(),
		avoid_positions,
		avoid_radii
	)


func find_safe_spawn_position(
	spawn_edge: int,
	avoid_positions: Array[Vector2],
	avoid_radii: Array[float],
	attempts: int = 24
) -> Vector2:
	if avoid_positions.size() != avoid_radii.size():
		push_warning("Spawn avoidance positions and radii must have matching sizes.")
		return INVALID_SPAWN_POSITION

	var play_rect := get_play_rect()
	for _attempt in maxi(attempts, 1):
		var spawn_position := _pick_position_for_edge(play_rect, spawn_edge)
		if _is_spawn_position_safe(spawn_position, avoid_positions, avoid_radii):
			return spawn_position

	return INVALID_SPAWN_POSITION


func _pick_position_for_edge(play_rect: Rect2, spawn_edge: int) -> Vector2:
	var edge_padding := 8.0
	match spawn_edge:
		SpawnEdge.TOP:
			return Vector2(
				rng.randf_range(play_rect.position.x + edge_padding, play_rect.end.x - edge_padding),
				play_rect.position.y + edge_padding
			)
		SpawnEdge.BOTTOM:
			return Vector2(
				rng.randf_range(play_rect.position.x + edge_padding, play_rect.end.x - edge_padding),
				play_rect.end.y - edge_padding
			)
		SpawnEdge.LEFT:
			return Vector2(
				play_rect.position.x + edge_padding,
				rng.randf_range(play_rect.position.y + edge_padding, play_rect.end.y - edge_padding)
			)
		_:
			return Vector2(
				play_rect.end.x - edge_padding,
				rng.randf_range(play_rect.position.y + edge_padding, play_rect.end.y - edge_padding)
			)


func _is_spawn_position_safe(
	spawn_position: Vector2,
	avoid_positions: Array[Vector2],
	avoid_radii: Array[float]
) -> bool:
	for index in avoid_positions.size():
		if spawn_position.distance_to(avoid_positions[index]) < avoid_radii[index]:
			return false
	return true


func _draw() -> void:
	if FLOOR_TEXTURE != null:
		draw_texture(FLOOR_TEXTURE, Vector2.ZERO)
	else:
		draw_rect(Rect2(Vector2.ZERO, arena_size), floor_color, true)

	var play_rect := get_play_rect()
	draw_rect(play_rect, boundary_color, false, 2.0)

	var center := play_rect.get_center()
	var weathered_color := marking_color
	weathered_color.a *= 0.7
	draw_line(center + Vector2(-18.0, -7.0), center + Vector2(-10.0, -5.0), weathered_color, 1.0)
	draw_line(center + Vector2(8.0, 6.0), center + Vector2(16.0, 9.0), weathered_color, 1.0)
	draw_line(center + Vector2(-2.0, 15.0), center + Vector2(3.0, 18.0), weathered_color, 1.0)
	draw_arc(center + Vector2(-11.0, 3.0), 7.0, 0.2, 1.7, 12, weathered_color, 1.0)
	draw_arc(center + Vector2(13.0, -4.0), 5.0, 3.6, 5.3, 10, weathered_color, 1.0)

	for point in [
		Vector2(play_rect.position.x + 24.0, play_rect.position.y + 24.0),
		Vector2(play_rect.end.x - 24.0, play_rect.position.y + 24.0),
		Vector2(play_rect.position.x + 24.0, play_rect.end.y - 24.0),
		Vector2(play_rect.end.x - 24.0, play_rect.end.y - 24.0),
	]:
		draw_circle(point, 2.5, marking_color)
