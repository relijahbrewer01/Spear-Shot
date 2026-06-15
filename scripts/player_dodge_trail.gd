extends Node2D
class_name PlayerDodgeTrail

@export_range(1, 8, 1) var afterimage_count := 4
@export var sample_interval := 0.045
@export var afterimage_lifetime := 0.22
@export var afterimage_tint := Color8(176, 212, 255, 92)

var sample_timer := 0.0
var source_texture: Texture2D
var source_centered := true
var source_offset := Vector2.ZERO
var source_texture_filter := CanvasItem.TEXTURE_FILTER_NEAREST
var snapshots: Array[Dictionary] = []
var afterimage_sprites: Array[Sprite2D] = []


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	rotation = 0.0
	z_index = 9
	_rebuild_afterimage_pool()
	clear_trail()


func setup_from_sprite(
	source_sprite: Sprite2D,
	new_afterimage_count: int,
	new_sample_interval: float,
	new_afterimage_lifetime: float,
	new_afterimage_tint: Color
) -> void:
	afterimage_count = maxi(new_afterimage_count, 1)
	sample_interval = maxf(new_sample_interval, 0.001)
	afterimage_lifetime = maxf(new_afterimage_lifetime, 0.01)
	afterimage_tint = new_afterimage_tint

	if source_sprite != null:
		source_texture = source_sprite.texture
		source_centered = source_sprite.centered
		source_offset = source_sprite.offset
		source_texture_filter = source_sprite.texture_filter

	_rebuild_afterimage_pool()
	clear_trail()


func begin_dodge() -> void:
	sample_timer = sample_interval


func advance_trail(
	delta: float,
	should_sample: bool,
	sampled_position: Vector2,
	sampled_rotation: float,
	sampled_flip_h: bool
) -> void:
	_age_snapshots(delta)

	if should_sample:
		var effective_interval := maxf(sample_interval, 0.001)
		sample_timer += delta
		while sample_timer >= effective_interval:
			sample_timer -= effective_interval
			_store_snapshot(sampled_position, sampled_rotation, sampled_flip_h)
	else:
		sample_timer = 0.0

	_sync_afterimage_sprites()


func clear_trail() -> void:
	sample_timer = 0.0
	snapshots.clear()
	for afterimage_sprite in afterimage_sprites:
		afterimage_sprite.visible = false


func _age_snapshots(delta: float) -> void:
	for snapshot in snapshots:
		snapshot["age"] = minf(float(snapshot["age"]) + delta, afterimage_lifetime)

	var remaining_snapshots: Array[Dictionary] = []
	for snapshot in snapshots:
		if float(snapshot["age"]) < afterimage_lifetime:
			remaining_snapshots.append(snapshot)

	snapshots = remaining_snapshots


func _store_snapshot(sampled_position: Vector2, sampled_rotation: float, sampled_flip_h: bool) -> void:
	var snapped_position := sampled_position.round()
	if not snapshots.is_empty():
		var latest_snapshot := snapshots[0]
		if latest_snapshot["position"] == snapped_position \
		and is_equal_approx(float(latest_snapshot["rotation"]), sampled_rotation) \
		and bool(latest_snapshot["flip_h"]) == sampled_flip_h:
			return

	snapshots.insert(0, {
		"position": snapped_position,
		"rotation": sampled_rotation,
		"flip_h": sampled_flip_h,
		"age": 0.0,
	})

	while snapshots.size() > afterimage_count:
		snapshots.pop_back()


func _sync_afterimage_sprites() -> void:
	for afterimage_index in range(afterimage_sprites.size()):
		var afterimage_sprite := afterimage_sprites[afterimage_index]
		if afterimage_index >= snapshots.size():
			afterimage_sprite.visible = false
			continue

		var snapshot := snapshots[afterimage_index]
		var life_progress := 1.0 - (float(snapshot["age"]) / afterimage_lifetime)
		if life_progress <= 0.0:
			afterimage_sprite.visible = false
			continue

		var afterimage_color := afterimage_tint
		afterimage_color.a *= life_progress
		afterimage_sprite.visible = true
		afterimage_sprite.position = snapshot["position"]
		afterimage_sprite.rotation = float(snapshot["rotation"])
		afterimage_sprite.flip_h = bool(snapshot["flip_h"])
		afterimage_sprite.modulate = afterimage_color


func _rebuild_afterimage_pool() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	afterimage_sprites.clear()

	for _afterimage_index in range(afterimage_count):
		var afterimage_sprite := Sprite2D.new()
		afterimage_sprite.texture = source_texture
		afterimage_sprite.centered = source_centered
		afterimage_sprite.offset = source_offset
		afterimage_sprite.texture_filter = source_texture_filter
		afterimage_sprite.visible = false
		afterimage_sprite.scale = Vector2.ONE
		add_child(afterimage_sprite)
		afterimage_sprites.append(afterimage_sprite)
