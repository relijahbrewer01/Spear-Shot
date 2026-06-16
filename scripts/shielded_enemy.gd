extends Enemy
class_name ShieldedEnemy

signal shield_broken(hit_position: Vector2)

@export var movement_speed_scale := 0.72
@export var stagger_duration := 0.65
@export var knockback_distance := 14.0
@export var knockback_duration := 0.12
@export var shield_break_effect_duration := 0.22
@export var shield_plate_color := Color8(139, 103, 66)
@export var shield_plate_shadow_color := Color8(72, 51, 34)
@export var exposed_body_color := Color8(137, 113, 105)

var shield_intact := true
var stagger_time_left := 0.0
var knockback_time_left := 0.0
var shield_break_effect_left := 0.0
var knockback_direction := Vector2.RIGHT


func setup(player_ref: Player, new_arena_rect: Rect2, starting_speed: float) -> void:
	super.setup(player_ref, new_arena_rect, starting_speed * movement_speed_scale)


func set_active(is_active: bool) -> void:
	super.set_active(is_active)
	if not is_active:
		stagger_time_left = 0.0
		knockback_time_left = 0.0
		shield_break_effect_left = 0.0
		queue_redraw()


func is_shield_intact() -> bool:
	return shield_intact


func is_staggering() -> bool:
	return stagger_time_left > 0.0


func receive_combat_hit(
	hit_source: StringName,
	hit_position: Vector2,
	hit_direction: Vector2
) -> HitResponse:
	if is_dying:
		return HitResponse.IGNORED
	if hit_source != HIT_SOURCE_SPEAR and hit_source != HIT_SOURCE_EXPLOSION:
		return HitResponse.IGNORED

	if shield_intact:
		_break_shield(hit_source, hit_position, hit_direction)
		if hit_source == HIT_SOURCE_SPEAR:
			return HitResponse.STOPPED
		return HitResponse.DAMAGED

	return super.receive_combat_hit(hit_source, hit_position, hit_direction)


func _physics_process(delta: float) -> void:
	visual_time += delta
	_update_shield_effect_timers(delta)

	if _update_effect_timers(delta):
		_update_sprite_visuals()
		return

	if _can_run_behavior():
		if is_staggering():
			_process_stagger(delta)
		else:
			_process_alive_behavior(delta)

	_update_sprite_visuals()
	queue_redraw()


func _break_shield(
	_hit_source: StringName,
	hit_position: Vector2,
	hit_direction: Vector2
) -> void:
	shield_intact = false
	hit_flash_left = 0.12
	stagger_time_left = stagger_duration
	knockback_time_left = knockback_duration
	shield_break_effect_left = shield_break_effect_duration
	knockback_direction = hit_direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = _get_direction_to_player() * -1.0
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT

	velocity = Vector2.ZERO
	shield_broken.emit(hit_position)
	queue_redraw()


func _update_shield_effect_timers(delta: float) -> void:
	if shield_break_effect_left > 0.0:
		shield_break_effect_left = maxf(shield_break_effect_left - delta, 0.0)

	if stagger_time_left > 0.0:
		stagger_time_left = maxf(stagger_time_left - delta, 0.0)
		if stagger_time_left == 0.0:
			knockback_time_left = 0.0


func _process_stagger(delta: float) -> void:
	if knockback_time_left > 0.0 and knockback_duration > 0.0:
		var motion_delta := minf(delta, knockback_time_left)
		var step_distance := knockback_distance * (motion_delta / knockback_duration)
		global_position += knockback_direction * step_distance
		_clamp_inside_arena()
		if delta > 0.0:
			velocity = knockback_direction * step_distance / delta
		else:
			velocity = Vector2.ZERO
		knockback_time_left = maxf(knockback_time_left - delta, 0.0)
		return

	velocity = Vector2.ZERO


func _try_contact_damage() -> void:
	if is_staggering():
		return

	super._try_contact_damage()


func _get_current_fill_color() -> Color:
	if hit_flash_left > 0.0:
		return hit_flash_color
	if shield_intact:
		return body_color
	return exposed_body_color


func _draw_alive_body(fill_color: Color) -> void:
	super._draw_alive_body(fill_color)
	if shield_intact:
		_draw_shield_plates()
	if shield_break_effect_left > 0.0:
		_draw_shield_break_fragments()


func _draw_shield_plates() -> void:
	var plate_points: Array[Vector2] = [
		Vector2(-6.5, -5.5),
		Vector2(0.0, -7.0),
		Vector2(6.5, -5.5),
		Vector2(8.0, 0.0),
		Vector2(4.0, 5.5),
		Vector2(-4.0, 5.5),
		Vector2(-8.0, 0.0),
	]

	for index in plate_points.size():
		var point := plate_points[index]
		var next_point := plate_points[(index + 1) % plate_points.size()]
		var mid_point := (point + next_point) * 0.5
		var outward := mid_point.normalized()
		if outward == Vector2.ZERO:
			outward = Vector2.UP

		var plate_size := Vector2(4.0, 2.5)
		var plate_center := mid_point + outward * 1.2
		draw_circle(plate_center + Vector2(0.0, 1.0), 2.4, shield_plate_shadow_color)
		draw_rect(
			Rect2(plate_center - plate_size * 0.5, plate_size),
			shield_plate_color,
			true
		)


func _draw_shield_break_fragments() -> void:
	var progress := 1.0 - shield_break_effect_left / shield_break_effect_duration
	var fragment_color := shield_plate_color
	fragment_color.a = 1.0 - progress
	for index in 6:
		var angle := float(index) * TAU / 6.0 + progress * 0.7
		var offset := Vector2.RIGHT.rotated(angle) * (6.5 + progress * 6.5)
		draw_rect(Rect2(offset - Vector2.ONE, Vector2(2.0, 2.0)), fragment_color, true)
