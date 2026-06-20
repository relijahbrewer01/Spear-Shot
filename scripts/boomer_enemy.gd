extends Enemy
class_name BoomerEnemy

signal hop_prepared
signal hop_landed
signal fuse_started
signal detonated(
	position: Vector2,
	core_radius: float,
	outer_radius: float,
	landed_spear_shockwave_displacement: float
)

enum BoomerState {
	HOP_PREP,
	HOPPING,
	LAND_RECOVERY,
	FUSE,
}

@export var hop_prep_duration := 0.18
@export var hop_duration := 0.24
@export var hop_distance := 38.0
@export var landing_recovery_duration := 0.20
@export var fuse_trigger_distance := 36.0
@export var fuse_duration := 0.80
@export var fuse_pulse_two_offset := 0.32
@export var fuse_pulse_three_offset := 0.57
@export var pulse_flash_duration := 0.11
@export var landing_correction_limit := 6.0
@export var core_blast_radius := 29.0
@export var outer_shockwave_radius := 54.0
@export var player_knockback_distance := 28.0
@export var player_knockback_duration := 0.20
@export var landed_spear_shockwave_displacement := 20.0
@export var enemy_shockwave_knockback_distance := 18.0
@export var enemy_shockwave_knockback_duration := 0.16
@export var shooter_shockwave_knockback_distance := 22.0
@export var shooter_shockwave_knockback_duration := 0.18
@export var charger_core_knockback_distance := 30.0
@export var charger_core_knockback_duration := 0.20
@export var charger_shockwave_knockback_distance := 20.0
@export var charger_shockwave_knockback_duration := 0.16
@export var pressure_sac_color := Color8(211, 170, 118)
@export var fuse_pulse_color := Color8(255, 232, 176)
@export var fuse_mark_color := Color8(123, 78, 55)

var boomer_state: BoomerState = BoomerState.HOP_PREP
var state_time_left := 0.0
var hop_start_position := Vector2.ZERO
var hop_target_position := Vector2.ZERO
var hop_direction := Vector2.RIGHT
var fuse_flash_left := 0.0
var emitted_fuse_pulse_count := 0
var has_detonated := false


func _ready() -> void:
	super._ready()
	_enter_hop_prep_state()


func set_active(is_active: bool) -> void:
	super.set_active(is_active)
	if not is_active:
		state_time_left = 0.0
		fuse_flash_left = 0.0
		emitted_fuse_pulse_count = 0
		velocity = Vector2.ZERO
		queue_redraw()


func receive_combat_hit(
	hit_source: StringName,
	hit_position: Vector2,
	hit_direction: Vector2
) -> HitResponse:
	if is_dying or has_detonated:
		return HitResponse.IGNORED
	if hit_source != HIT_SOURCE_SPEAR:
		return HitResponse.IGNORED

	if boomer_state == BoomerState.FUSE:
		_start_detonation(hit_position, hit_direction)
		return HitResponse.DAMAGED

	return super.receive_combat_hit(hit_source, hit_position, hit_direction)


func _physics_process(delta: float) -> void:
	visual_time += delta
	fuse_flash_left = maxf(fuse_flash_left - delta, 0.0)

	if _update_effect_timers(delta):
		_update_sprite_visuals()
		return

	if _can_run_behavior():
		match boomer_state:
			BoomerState.HOP_PREP:
				_process_hop_prep(delta)
			BoomerState.HOPPING:
				_process_hopping(delta)
			BoomerState.LAND_RECOVERY:
				_process_land_recovery(delta)
			BoomerState.FUSE:
				_process_fuse(delta)
	else:
		velocity = Vector2.ZERO

	_update_sprite_visuals()
	queue_redraw()


func _process_hop_prep(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_hopping_state()


func _process_hopping(delta: float) -> void:
	if hop_duration <= 0.0:
		_finish_hop()
		return

	var previous_position := global_position
	state_time_left = maxf(state_time_left - delta, 0.0)
	var hop_progress := 1.0 - state_time_left / hop_duration
	global_position = hop_start_position.lerp(hop_target_position, clampf(hop_progress, 0.0, 1.0))
	_clamp_inside_arena()
	if delta > 0.0:
		velocity = (global_position - previous_position) / delta
	else:
		velocity = Vector2.ZERO

	if state_time_left == 0.0:
		_finish_hop()


func _process_land_recovery(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_enter_hop_prep_state()


func _process_fuse(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO

	var elapsed := fuse_duration - state_time_left
	if emitted_fuse_pulse_count < 2 and elapsed >= fuse_pulse_two_offset:
		_emit_fuse_pulse()
	if emitted_fuse_pulse_count < 3 and elapsed >= fuse_pulse_three_offset:
		_emit_fuse_pulse()

	if state_time_left == 0.0:
		_start_detonation(global_position, hop_direction)


func _finish_hop() -> void:
	global_position = hop_target_position
	_apply_landing_correction()
	velocity = Vector2.ZERO
	hop_landed.emit()

	if _is_player_in_fuse_range():
		_enter_fuse_state()
		return

	_enter_land_recovery_state()


func _enter_hop_prep_state() -> void:
	boomer_state = BoomerState.HOP_PREP
	state_time_left = hop_prep_duration
	velocity = Vector2.ZERO
	hop_prepared.emit()


func _enter_hopping_state() -> void:
	boomer_state = BoomerState.HOPPING
	state_time_left = hop_duration
	hop_start_position = global_position
	hop_direction = _get_direction_to_player()
	if hop_direction == Vector2.ZERO:
		hop_direction = Vector2.RIGHT
	hop_target_position = _clamp_position_to_arena(global_position + hop_direction * hop_distance)


func _enter_land_recovery_state() -> void:
	boomer_state = BoomerState.LAND_RECOVERY
	state_time_left = landing_recovery_duration
	velocity = Vector2.ZERO


func _enter_fuse_state() -> void:
	boomer_state = BoomerState.FUSE
	state_time_left = fuse_duration
	velocity = Vector2.ZERO
	emitted_fuse_pulse_count = 0
	fuse_started.emit()
	_emit_fuse_pulse()


func _emit_fuse_pulse() -> void:
	emitted_fuse_pulse_count += 1
	fuse_flash_left = pulse_flash_duration
	queue_redraw()


func _start_detonation(_hit_position: Vector2, hit_direction: Vector2) -> void:
	if has_detonated:
		return

	has_detonated = true
	active = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_explosion_knockback()
	_resolve_explosion(hit_direction)
	detonated.emit(
		global_position,
		core_blast_radius,
		outer_shockwave_radius,
		landed_spear_shockwave_displacement
	)
	queue_free()


func _resolve_explosion(hit_direction: Vector2) -> void:
	_resolve_player_core_blast(hit_direction)

	var core_resolved_enemy_ids: Dictionary = {}
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var other_enemy := enemy_node as Enemy
		if other_enemy == null or other_enemy == self or other_enemy.is_dying:
			continue
		if not _is_enemy_within_radius(other_enemy, core_blast_radius):
			continue

		_apply_core_blast_to_enemy(other_enemy)
		core_resolved_enemy_ids[other_enemy.get_instance_id()] = true

	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var other_enemy := enemy_node as Enemy
		if other_enemy == null or other_enemy == self or other_enemy.is_dying:
			continue
		if core_resolved_enemy_ids.has(other_enemy.get_instance_id()):
			continue
		if not _is_enemy_within_radius(other_enemy, outer_shockwave_radius):
			continue

		_apply_outer_shockwave_to_enemy(other_enemy)


func _resolve_player_core_blast(hit_direction: Vector2) -> void:
	if player == null or not player.is_alive():
		return
	if not _is_point_within_radius(player.global_position, core_blast_radius, player.damage_hit_radius):
		return

	var outward_direction := (player.global_position - global_position).normalized()
	if outward_direction == Vector2.ZERO:
		outward_direction = hit_direction.normalized()
	if outward_direction == Vector2.ZERO:
		outward_direction = hop_direction
	if outward_direction == Vector2.ZERO:
		outward_direction = Vector2.RIGHT

	if player.has_shove_damage_protection():
		return

	var damage_applied := player.take_damage(global_position, Player.DAMAGE_SOURCE_EXPLOSION)
	if not damage_applied:
		return

	player.try_start_forced_movement(
		outward_direction,
		player_knockback_distance,
		player_knockback_duration
	)


func _apply_core_blast_to_enemy(other_enemy: Enemy) -> void:
	var outward_direction := _get_outward_direction(other_enemy.global_position)
	if other_enemy is Charger:
		other_enemy.apply_explosion_knockback(
			outward_direction,
			charger_core_knockback_distance,
			charger_core_knockback_duration
		)
		return

	other_enemy.receive_combat_hit(HIT_SOURCE_EXPLOSION, other_enemy.global_position, outward_direction)


func _apply_outer_shockwave_to_enemy(other_enemy: Enemy) -> void:
	var outward_direction := _get_outward_direction(other_enemy.global_position)
	if other_enemy is Charger:
		other_enemy.apply_explosion_knockback(
			outward_direction,
			charger_shockwave_knockback_distance,
			charger_shockwave_knockback_duration
		)
		return
	if other_enemy is ShooterEnemy:
		other_enemy.apply_explosion_knockback(
			outward_direction,
			shooter_shockwave_knockback_distance,
			shooter_shockwave_knockback_duration
		)
		return

	other_enemy.apply_explosion_knockback(
		outward_direction,
		enemy_shockwave_knockback_distance,
		enemy_shockwave_knockback_duration
	)


func _get_outward_direction(target_position: Vector2) -> Vector2:
	var outward_direction := (target_position - global_position).normalized()
	if outward_direction == Vector2.ZERO:
		if hop_direction != Vector2.ZERO:
			return hop_direction
		return Vector2.RIGHT
	return outward_direction


func _is_player_in_fuse_range() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= fuse_trigger_distance


func _is_enemy_within_radius(other_enemy: Enemy, radius: float) -> bool:
	return _is_point_within_radius(other_enemy.global_position, radius, other_enemy.body_radius)


func _is_point_within_radius(target_position: Vector2, radius: float, target_radius: float) -> bool:
	return global_position.distance_to(target_position) <= radius + target_radius


func _apply_landing_correction() -> void:
	var correction := Vector2.ZERO
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var other_enemy := enemy_node as Enemy
		if other_enemy == null or other_enemy == self or other_enemy.is_dying:
			continue

		var offset := global_position - other_enemy.global_position
		var distance := offset.length()
		var minimum_distance := body_radius + other_enemy.body_radius
		if distance >= minimum_distance:
			continue

		if distance <= 0.001:
			offset = Vector2.RIGHT.rotated(float(get_instance_id() % 360) * PI / 180.0)
			distance = 1.0
		correction += offset.normalized() * (minimum_distance - distance)

	if correction == Vector2.ZERO:
		return

	global_position = _clamp_position_to_arena(
		global_position + correction.limit_length(landing_correction_limit)
	)


func _clamp_position_to_arena(target_position: Vector2) -> Vector2:
	if arena_rect.size == Vector2.ZERO:
		return target_position

	return Vector2(
		clamp(target_position.x, arena_rect.position.x + body_radius, arena_rect.end.x - body_radius),
		clamp(target_position.y, arena_rect.position.y + body_radius, arena_rect.end.y - body_radius)
	)


func _try_contact_damage() -> void:
	return


func _get_current_fill_color() -> Color:
	var fill_color := super._get_current_fill_color()
	if hit_flash_left > 0.0:
		return fill_color

	var pulse_strength := _get_fuse_pulse_strength()
	if pulse_strength > 0.0:
		return fill_color.lerp(fuse_pulse_color, pulse_strength)
	if boomer_state == BoomerState.FUSE:
		return fill_color.lerp(fuse_pulse_color, 0.18)
	return fill_color


func _draw_alive_body(fill_color: Color) -> void:
	super._draw_alive_body(fill_color)
	var pulse_strength := _get_fuse_pulse_strength()
	var sac_color := pressure_sac_color
	if pulse_strength > 0.0:
		sac_color = pressure_sac_color.lerp(fuse_pulse_color, pulse_strength)

	draw_circle(Vector2(2.0, -2.0), 4.2, sac_color)
	draw_circle(Vector2(3.0, -3.0), 1.6, Color(1.0, 1.0, 1.0, 0.18 + pulse_strength * 0.20))
	draw_line(Vector2(-3.0, -1.0), Vector2(-1.0, -4.0), fuse_mark_color, 1.0)
	draw_line(Vector2(-1.0, -4.0), Vector2(1.0, -1.0), fuse_mark_color, 1.0)


func _get_fuse_pulse_strength() -> float:
	if emitted_fuse_pulse_count == 0 or pulse_flash_duration <= 0.0:
		return 0.0

	var flash_ratio := clampf(fuse_flash_left / pulse_flash_duration, 0.0, 1.0)
	var stage_strength := 0.24 + float(emitted_fuse_pulse_count - 1) * 0.20
	return clampf(stage_strength * flash_ratio, 0.0, 0.95)


func _get_visual_offset() -> Vector2:
	var draw_offset := super._get_visual_offset()

	match boomer_state:
		BoomerState.HOP_PREP:
			draw_offset += Vector2(0.0, 1.0)
		BoomerState.HOPPING:
			if hop_duration > 0.0:
				var hop_progress := 1.0 - state_time_left / hop_duration
				draw_offset.y -= roundf(sin(clampf(hop_progress, 0.0, 1.0) * PI) * 6.0)
		BoomerState.LAND_RECOVERY:
			if landing_recovery_duration > 0.0:
				var recovery_progress := 1.0 - state_time_left / landing_recovery_duration
				draw_offset.y += roundf(sin(clampf(recovery_progress, 0.0, 1.0) * PI) * 1.5)

	return draw_offset.round()


func _get_visual_scale() -> Vector2:
	match boomer_state:
		BoomerState.HOP_PREP:
			return Vector2(1.10, 0.88)
		BoomerState.HOPPING:
			return Vector2(0.92, 1.08)
		BoomerState.LAND_RECOVERY:
			return Vector2(0.96, 1.04)
		BoomerState.FUSE:
			var pulse_strength := _get_fuse_pulse_strength()
			return Vector2.ONE + Vector2.ONE * (pulse_strength * 0.06)

	return Vector2.ONE
