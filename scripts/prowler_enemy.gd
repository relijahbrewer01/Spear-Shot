extends Enemy
class_name ProwlerEnemy

signal state_changed(new_state: int)
signal alert_started
signal hunt_pounce_hit(hit_position: Vector2, hit_stop_duration: float)

enum ProwlerState {
	STALK,
	DEFENSIVE_WINDUP,
	ALERT,
	HUNT,
	POUNCE_WINDUP,
	POUNCE,
	IMPACT_RECOIL,
	MISS_SKID,
	MISS_STUN,
	RETREAT,
	WARY_UNARMED,
}

enum PounceMode {
	NONE,
	DEFENSIVE,
	HUNT,
}

const ANIMATION_FRAME_COUNT := 4
const ANIMATION_ROW_STALK := 0
const ANIMATION_ROW_ALERT := 1
const ANIMATION_ROW_HUNT := 2
const ANIMATION_ROW_POUNCE := 3
const ANIMATION_ROW_RECOVERY := 4
const STALK_FRAME_DURATION := 0.18
const ALERT_FRAME_DURATION := 0.08
const HUNT_FRAME_DURATION := 0.10
const POUNCE_FRAME_DURATION := 0.05
const RECOVERY_FRAME_DURATION := 0.12
const ALERT_TWITCH_DURATION := 0.10
const MISS_SKID_SPEED_SCALE := 0.34
const RETREAT_END_DISTANCE := 10.0

@export var stalk_speed_scale := 0.82
@export var hunt_speed_scale := 1.48
@export var unarmed_alert_delay := 0.28
@export var stalk_distance_min := 72.0
@export var stalk_distance_max := 104.0
@export var stalk_dead_zone := 5.0
@export var stalk_lateral_commit_duration := 0.55
@export var wall_fallback_commit_duration := 0.35
@export var band_radial_correction_strength := 0.35
@export var defensive_trigger_radius := 26.0
@export var defensive_windup_duration := 0.16
@export var defensive_pounce_distance := 42.0
@export var defensive_pounce_duration := 0.18
@export var defensive_retreat_distance := 92.0
@export var defensive_retrigger_cooldown := 1.10
@export var hunt_pounce_trigger_distance := 36.0
@export var hunt_pounce_windup_duration := 0.18
@export var hunt_pounce_distance := 48.0
@export var hunt_pounce_duration := 0.18
@export var hunt_player_knockback_distance := 28.0
@export var hunt_player_knockback_duration := 0.18
@export var hunt_prowler_recoil_distance := 26.0
@export var hunt_prowler_recoil_duration := 0.16
@export var hunt_hit_stop_duration := 0.06
@export var miss_skid_duration := 0.18
@export var miss_stun_duration := 0.42

var prowler_state: ProwlerState = ProwlerState.STALK
var pounce_mode: PounceMode = PounceMode.NONE
var tracked_spear: Spear
var base_behavior_speed := 42.0
var tracked_spear_is_held := true
var hunt_pounce_available := false
var state_time_left := 0.0
var state_elapsed := 0.0
var alert_twitch_left := 0.0
var defensive_retrigger_left := 0.0
var lateral_commit_left := 0.0
var lateral_side := 1
var wall_fallback_left := 0.0
var wall_fallback_direction := Vector2.ZERO
var pounce_locked_direction := Vector2.RIGHT
var pounce_total_distance := 0.0
var pounce_total_duration := 0.0
var pounce_hit_resolved := false
var pounce_damage_accepted := false
var retreat_target := Vector2.ZERO
var recoil_direction := Vector2.ZERO
var miss_skid_direction := Vector2.ZERO
var facing_left := false


func _ready() -> void:
	super._ready()
	_set_prowler_state(ProwlerState.STALK)


func setup(player_ref: Player, new_arena_rect: Rect2, starting_speed: float) -> void:
	super.setup(player_ref, new_arena_rect, starting_speed)
	base_behavior_speed = starting_speed


func set_active(is_active: bool) -> void:
	super.set_active(is_active)
	if not is_active:
		_clear_state_timers()
		pounce_mode = PounceMode.NONE
		velocity = Vector2.ZERO


func set_tracked_spear(new_tracked_spear: Spear) -> void:
	if tracked_spear == new_tracked_spear:
		return

	_disconnect_spear_state_signal()
	tracked_spear = new_tracked_spear
	_connect_spear_state_signal()
	_apply_spear_state_immediately()


func get_state_name() -> String:
	match prowler_state:
		ProwlerState.STALK:
			return "STALK"
		ProwlerState.DEFENSIVE_WINDUP:
			return "DEFENSIVE_WINDUP"
		ProwlerState.ALERT:
			return "ALERT"
		ProwlerState.HUNT:
			return "HUNT"
		ProwlerState.POUNCE_WINDUP:
			return "POUNCE_WINDUP"
		ProwlerState.POUNCE:
			return "POUNCE"
		ProwlerState.IMPACT_RECOIL:
			return "IMPACT_RECOIL"
		ProwlerState.MISS_SKID:
			return "MISS_SKID"
		ProwlerState.MISS_STUN:
			return "MISS_STUN"
		ProwlerState.RETREAT:
			return "RETREAT"
		ProwlerState.WARY_UNARMED:
			return "WARY_UNARMED"
	return "UNKNOWN"


func get_current_animation_frame_coords() -> Vector2i:
	return _get_animation_frame_coords()


func debug_get_current_pounce_mode_name() -> String:
	match pounce_mode:
		PounceMode.DEFENSIVE:
			return "DEFENSIVE"
		PounceMode.HUNT:
			return "HUNT"
	return "NONE"


func debug_get_red_eyes_active() -> bool:
	return _has_red_eyes()


func debug_has_hunt_pounce_available() -> bool:
	return hunt_pounce_available


func debug_get_locked_pounce_direction() -> Vector2:
	return pounce_locked_direction


func _exit_tree() -> void:
	_disconnect_spear_state_signal()


func apply_explosion_knockback(direction: Vector2, distance: float, duration: float) -> void:
	_interrupt_for_explosion_knockback()
	super.apply_explosion_knockback(direction, distance, duration)


func _interrupt_for_explosion_knockback() -> void:
	pounce_mode = PounceMode.NONE
	pounce_hit_resolved = false
	pounce_damage_accepted = false
	if tracked_spear_is_held:
		_enter_stalk_state(true)
	else:
		if hunt_pounce_available:
			_enter_hunt_state()
		else:
			_enter_wary_unarmed_state()


func _process_alive_behavior(delta: float) -> void:
	state_elapsed += delta
	alert_twitch_left = maxf(alert_twitch_left - delta, 0.0)
	defensive_retrigger_left = maxf(defensive_retrigger_left - delta, 0.0)
	lateral_commit_left = maxf(lateral_commit_left - delta, 0.0)
	wall_fallback_left = maxf(wall_fallback_left - delta, 0.0)
	if wall_fallback_left == 0.0:
		wall_fallback_direction = Vector2.ZERO

	match prowler_state:
		ProwlerState.STALK:
			_process_stalk_state(delta)
		ProwlerState.DEFENSIVE_WINDUP:
			_process_defensive_windup_state(delta)
		ProwlerState.ALERT:
			_process_alert_state(delta)
		ProwlerState.HUNT:
			_process_hunt_state()
		ProwlerState.POUNCE_WINDUP:
			_process_pounce_windup_state(delta)
		ProwlerState.POUNCE:
			_process_pounce_state(delta)
		ProwlerState.IMPACT_RECOIL:
			_process_impact_recoil_state(delta)
		ProwlerState.MISS_SKID:
			_process_miss_skid_state(delta)
		ProwlerState.MISS_STUN:
			_process_miss_stun_state(delta)
		ProwlerState.RETREAT:
			_process_retreat_state(delta)
		ProwlerState.WARY_UNARMED:
			_process_wary_unarmed_state()

	_try_contact_damage()


func _process_stalk_state(delta: float) -> void:
	var distance_to_player := _get_distance_to_player()
	if distance_to_player < 0.0:
		velocity = Vector2.ZERO
		return

	if (
		defensive_retrigger_left == 0.0
		and distance_to_player <= defensive_trigger_radius
	):
		_enter_defensive_windup_state()
		return

	var stalk_speed := base_behavior_speed * stalk_speed_scale
	var direction_to_player := _get_direction_to_player()
	if direction_to_player == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	if distance_to_player > stalk_distance_max + stalk_dead_zone:
		_move_with_velocity(_build_velocity_from_direction(direction_to_player, stalk_speed, 1.0))
		_update_facing_from_reference(velocity if velocity != Vector2.ZERO else direction_to_player)
		return

	if distance_to_player < stalk_distance_min - stalk_dead_zone:
		_move_with_velocity(_build_velocity_from_direction(-direction_to_player, stalk_speed, 0.65))
		_update_facing_from_reference(velocity if velocity != Vector2.ZERO else -direction_to_player)
		return

	if lateral_commit_left == 0.0 and wall_fallback_left == 0.0:
		_choose_lateral_commit()

	var move_direction := _get_stalk_band_direction(distance_to_player)
	if wall_fallback_left > 0.0 and wall_fallback_direction != Vector2.ZERO:
		move_direction = wall_fallback_direction
	elif _would_direction_leave_arena(move_direction, stalk_speed):
		wall_fallback_direction = _choose_wall_fallback_direction(distance_to_player)
		wall_fallback_left = wall_fallback_commit_duration
		move_direction = wall_fallback_direction

	_move_with_velocity(_build_velocity_from_direction(move_direction, stalk_speed, 0.85))
	_update_facing_from_reference(velocity if velocity != Vector2.ZERO else move_direction)


func _process_defensive_windup_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	var direction_to_player := _get_direction_to_player()
	if direction_to_player != Vector2.ZERO:
		pounce_locked_direction = direction_to_player
		_update_facing_from_reference(direction_to_player)
	if state_time_left == 0.0:
		_start_pounce(
			PounceMode.DEFENSIVE,
			pounce_locked_direction,
			defensive_pounce_distance,
			defensive_pounce_duration
		)


func _process_alert_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	var direction_to_player := _get_direction_to_player()
	if direction_to_player != Vector2.ZERO:
		_update_facing_from_reference(direction_to_player)
	if state_time_left == 0.0:
		_enter_hunt_state()


func _process_hunt_state() -> void:
	var direction_to_player := _get_direction_to_player()
	var distance_to_player := _get_distance_to_player()
	if direction_to_player == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	if hunt_pounce_available and distance_to_player <= hunt_pounce_trigger_distance:
		_enter_hunt_pounce_windup_state()
		return

	_move_with_velocity(
		_build_velocity_from_direction(direction_to_player, base_behavior_speed * hunt_speed_scale, 0.35)
	)
	_update_facing_from_reference(velocity if velocity != Vector2.ZERO else direction_to_player)


func _process_pounce_windup_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	_update_facing_from_reference(pounce_locked_direction)
	if state_time_left == 0.0:
		var distance := defensive_pounce_distance
		var duration := defensive_pounce_duration
		if pounce_mode == PounceMode.HUNT:
			distance = hunt_pounce_distance
			duration = hunt_pounce_duration
		_start_pounce(pounce_mode, pounce_locked_direction, distance, duration)


func _process_pounce_state(delta: float) -> void:
	if pounce_total_duration <= 0.0:
		_finish_pounce(false)
		return

	var motion_delta := minf(delta, state_time_left)
	var step_distance := pounce_total_distance * (motion_delta / pounce_total_duration)
	var start_position := global_position
	var target_position := _clamp_point_to_arena(start_position + pounce_locked_direction * step_distance)
	_attempt_pounce_hit(start_position, target_position)
	if prowler_state != ProwlerState.POUNCE:
		return
	global_position = target_position
	_clamp_inside_arena()

	if delta > 0.0:
		velocity = (target_position - start_position) / delta
	else:
		velocity = Vector2.ZERO
	_update_facing_from_reference(pounce_locked_direction)

	state_time_left = maxf(state_time_left - delta, 0.0)
	if state_time_left == 0.0:
		_finish_pounce(pounce_damage_accepted)


func _process_impact_recoil_state(delta: float) -> void:
	_process_direct_motion(delta, recoil_direction, hunt_prowler_recoil_distance, hunt_prowler_recoil_duration)
	_update_facing_from_reference(velocity if velocity != Vector2.ZERO else recoil_direction)
	if state_time_left == 0.0:
		_resolve_post_unarmed_state()


func _process_miss_skid_state(delta: float) -> void:
	if miss_skid_duration <= 0.0:
		_enter_miss_stun_state()
		return

	var skid_progress := 1.0 - (state_time_left / miss_skid_duration)
	var skid_speed := (hunt_pounce_distance / maxf(hunt_pounce_duration, 0.001)) * MISS_SKID_SPEED_SCALE
	var speed_scale := maxf(1.0 - skid_progress, 0.25)
	var start_position := global_position
	var target_position := _clamp_point_to_arena(
		start_position + miss_skid_direction * skid_speed * speed_scale * delta
	)
	global_position = target_position
	if delta > 0.0:
		velocity = (target_position - start_position) / delta
	else:
		velocity = Vector2.ZERO
	_update_facing_from_reference(miss_skid_direction)
	state_time_left = maxf(state_time_left - delta, 0.0)
	if state_time_left == 0.0:
		_enter_miss_stun_state()


func _process_miss_stun_state(delta: float) -> void:
	state_time_left = maxf(state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	if state_time_left == 0.0:
		_resolve_post_unarmed_state()


func _process_retreat_state(delta: float) -> void:
	var direction_to_target := retreat_target - global_position
	if direction_to_target.length() <= RETREAT_END_DISTANCE:
		global_position = _clamp_point_to_arena(retreat_target)
		velocity = Vector2.ZERO
		if tracked_spear_is_held:
			_enter_stalk_state(true)
		else:
			_resolve_post_unarmed_state()
		return

	var retreat_direction := direction_to_target.normalized()
	var retreat_speed := base_behavior_speed * hunt_speed_scale
	var start_position := global_position
	var target_position := _clamp_point_to_arena(
		start_position + retreat_direction * retreat_speed * delta
	)
	global_position = target_position
	if delta > 0.0:
		velocity = (target_position - start_position) / delta
	else:
		velocity = Vector2.ZERO
	_update_facing_from_reference(velocity if velocity != Vector2.ZERO else retreat_direction)


func _process_wary_unarmed_state() -> void:
	var direction_to_player := _get_direction_to_player()
	if direction_to_player == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	_move_with_velocity(
		_build_velocity_from_direction(direction_to_player, base_behavior_speed * hunt_speed_scale, 0.30)
	)
	_update_facing_from_reference(velocity if velocity != Vector2.ZERO else direction_to_player)


func _attempt_pounce_hit(start_position: Vector2, end_position: Vector2) -> void:
	if pounce_hit_resolved or player == null or not player.is_alive():
		return

	var hit_position := _get_player_segment_hit_position(start_position, end_position)
	if not hit_position.is_finite():
		return

	pounce_hit_resolved = true
	if pounce_mode == PounceMode.DEFENSIVE:
		player.take_damage(hit_position, Player.DAMAGE_SOURCE_CONTACT)
		return

	var accepted_damage := player.take_damage(hit_position, Player.DAMAGE_SOURCE_CONTACT)
	if not accepted_damage:
		return

	pounce_damage_accepted = true
	var knockback_direction := _get_hit_direction_from_position(hit_position)
	player.try_start_forced_movement(
		knockback_direction,
		hunt_player_knockback_distance,
		hunt_player_knockback_duration
	)
	hunt_pounce_hit.emit(hit_position, hunt_hit_stop_duration)
	global_position = _clamp_point_to_arena(hit_position - pounce_locked_direction * maxf(body_radius - 1.0, 1.0))
	recoil_direction = -pounce_locked_direction
	_enter_impact_recoil_state()


func _finish_pounce(successful_hunt_hit: bool) -> void:
	if pounce_mode == PounceMode.DEFENSIVE:
		_enter_retreat_state()
		return

	if successful_hunt_hit:
		return

	_enter_miss_skid_state()


func _enter_stalk_state(reset_commit: bool) -> void:
	pounce_mode = PounceMode.NONE
	pounce_hit_resolved = false
	pounce_damage_accepted = false
	state_time_left = 0.0
	alert_twitch_left = 0.0
	wall_fallback_left = 0.0
	wall_fallback_direction = Vector2.ZERO
	if reset_commit:
		lateral_commit_left = 0.0
	if tracked_spear_is_held:
		hunt_pounce_available = false
	_set_prowler_state(ProwlerState.STALK)


func _enter_defensive_windup_state() -> void:
	pounce_mode = PounceMode.DEFENSIVE
	pounce_locked_direction = _get_direction_to_player()
	if pounce_locked_direction == Vector2.ZERO:
		pounce_locked_direction = Vector2.LEFT if facing_left else Vector2.RIGHT
	state_time_left = defensive_windup_duration
	defensive_retrigger_left = defensive_retrigger_cooldown
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.DEFENSIVE_WINDUP)


func _enter_alert_state() -> void:
	pounce_mode = PounceMode.HUNT
	pounce_locked_direction = _get_direction_to_player()
	if pounce_locked_direction == Vector2.ZERO:
		pounce_locked_direction = Vector2.LEFT if facing_left else Vector2.RIGHT
	pounce_hit_resolved = false
	pounce_damage_accepted = false
	state_time_left = unarmed_alert_delay
	alert_twitch_left = ALERT_TWITCH_DURATION
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.ALERT)
	alert_started.emit()


func _enter_hunt_state() -> void:
	pounce_mode = PounceMode.HUNT
	state_time_left = 0.0
	alert_twitch_left = 0.0
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.HUNT)


func _enter_hunt_pounce_windup_state() -> void:
	pounce_mode = PounceMode.HUNT
	pounce_locked_direction = _get_direction_to_player()
	if pounce_locked_direction == Vector2.ZERO:
		pounce_locked_direction = Vector2.LEFT if facing_left else Vector2.RIGHT
	state_time_left = hunt_pounce_windup_duration
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.POUNCE_WINDUP)


func _start_pounce(
	new_pounce_mode: PounceMode,
	direction: Vector2,
	distance: float,
	duration: float
) -> void:
	pounce_mode = new_pounce_mode
	pounce_locked_direction = direction.normalized()
	if pounce_locked_direction == Vector2.ZERO:
		pounce_locked_direction = Vector2.LEFT if facing_left else Vector2.RIGHT
	pounce_total_distance = distance
	pounce_total_duration = duration
	pounce_hit_resolved = false
	pounce_damage_accepted = false
	state_time_left = duration
	if pounce_mode == PounceMode.HUNT:
		hunt_pounce_available = false
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.POUNCE)


func _enter_impact_recoil_state() -> void:
	state_time_left = hunt_prowler_recoil_duration
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.IMPACT_RECOIL)


func _enter_miss_skid_state() -> void:
	state_time_left = miss_skid_duration
	miss_skid_direction = pounce_locked_direction
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.MISS_SKID)


func _enter_miss_stun_state() -> void:
	state_time_left = miss_stun_duration
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.MISS_STUN)


func _enter_retreat_state() -> void:
	var away_from_player := _get_direction_away_from_player()
	if away_from_player == Vector2.ZERO:
		away_from_player = -pounce_locked_direction
	if away_from_player == Vector2.ZERO:
		away_from_player = Vector2.LEFT if facing_left else Vector2.RIGHT
	retreat_target = _clamp_point_to_arena(global_position + away_from_player * defensive_retreat_distance)
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.RETREAT)


func _enter_wary_unarmed_state() -> void:
	pounce_mode = PounceMode.NONE
	pounce_hit_resolved = false
	pounce_damage_accepted = false
	state_time_left = 0.0
	velocity = Vector2.ZERO
	_set_prowler_state(ProwlerState.WARY_UNARMED)


func _resolve_post_unarmed_state() -> void:
	if tracked_spear_is_held:
		_enter_stalk_state(true)
		return
	if hunt_pounce_available:
		_enter_hunt_state()
		return
	_enter_wary_unarmed_state()


func _process_direct_motion(delta: float, direction: Vector2, distance: float, duration: float) -> void:
	if duration <= 0.0:
		state_time_left = 0.0
		velocity = Vector2.ZERO
		return

	var motion_delta := minf(delta, state_time_left)
	var step_distance := distance * (motion_delta / duration)
	var start_position := global_position
	var target_position := _clamp_point_to_arena(start_position + direction.normalized() * step_distance)
	global_position = target_position
	if delta > 0.0:
		velocity = (target_position - start_position) / delta
	else:
		velocity = Vector2.ZERO
	state_time_left = maxf(state_time_left - delta, 0.0)


func _choose_lateral_commit() -> void:
	var direction_to_player := _get_direction_to_player()
	if direction_to_player == Vector2.ZERO:
		lateral_side = 1 if int(get_instance_id()) % 2 == 0 else -1
		lateral_commit_left = stalk_lateral_commit_duration
		return

	var clockwise_direction := Vector2(direction_to_player.y, -direction_to_player.x)
	var counter_clockwise_direction := Vector2(-direction_to_player.y, direction_to_player.x)
	var clockwise_score := _score_stalk_direction(clockwise_direction)
	var counter_clockwise_score := _score_stalk_direction(counter_clockwise_direction)
	if clockwise_score > counter_clockwise_score:
		lateral_side = -1
	elif counter_clockwise_score > clockwise_score:
		lateral_side = 1
	else:
		lateral_side = 1 if int(get_instance_id()) % 2 == 0 else -1

	lateral_commit_left = stalk_lateral_commit_duration


func _get_stalk_band_direction(distance_to_player: float) -> Vector2:
	var direction_to_player := _get_direction_to_player()
	if direction_to_player == Vector2.ZERO:
		return Vector2(float(lateral_side), 0.0)

	var tangent_direction := Vector2(-direction_to_player.y, direction_to_player.x) * float(lateral_side)
	var band_center := (stalk_distance_min + stalk_distance_max) * 0.5
	var band_half_width := maxf((stalk_distance_max - stalk_distance_min) * 0.5, 1.0)
	var radial_correction := clampf(
		(distance_to_player - band_center) / band_half_width,
		-1.0,
		1.0
	)
	var move_direction := tangent_direction + direction_to_player * radial_correction * band_radial_correction_strength
	if move_direction == Vector2.ZERO:
		move_direction = tangent_direction
	if move_direction == Vector2.ZERO:
		move_direction = direction_to_player
	return move_direction.normalized()


func _score_stalk_direction(direction: Vector2) -> float:
	if direction == Vector2.ZERO or player == null:
		return -INF

	var projected_point := _clamp_point_to_arena(global_position + direction.normalized() * 18.0)
	var wall_clearance := _distance_to_nearest_wall(projected_point)
	var band_center := (stalk_distance_min + stalk_distance_max) * 0.5
	var band_distance := projected_point.distance_to(player.global_position)
	var band_penalty := absf(band_distance - band_center) * 0.6
	return wall_clearance - band_penalty


func _would_direction_leave_arena(direction: Vector2, speed: float) -> bool:
	if direction == Vector2.ZERO:
		return false

	var projected_point := global_position + direction.normalized() * maxf(speed * 0.24, 12.0)
	return projected_point.distance_to(_clamp_point_to_arena(projected_point)) > 0.1


func _choose_wall_fallback_direction(distance_to_player: float) -> Vector2:
	var horizontal_margin := 4.0
	var min_x := arena_rect.position.x + body_radius
	var max_x := arena_rect.end.x - body_radius
	var min_y := arena_rect.position.y + body_radius
	var max_y := arena_rect.end.y - body_radius
	var candidates: Array[Vector2] = []

	if global_position.x <= min_x + horizontal_margin or global_position.x >= max_x - horizontal_margin:
		candidates = [Vector2.UP, Vector2.DOWN]
	elif global_position.y <= min_y + horizontal_margin or global_position.y >= max_y - horizontal_margin:
		candidates = [Vector2.LEFT, Vector2.RIGHT]
	else:
		candidates = [
			_get_stalk_band_direction(distance_to_player),
			-_get_stalk_band_direction(distance_to_player),
		]

	var best_direction := Vector2.ZERO
	var best_score := -INF
	for candidate in candidates:
		var score := _score_stalk_direction(candidate)
		if score > best_score:
			best_score = score
			best_direction = candidate

	if best_direction == Vector2.ZERO:
		best_direction = _get_stalk_band_direction(distance_to_player)
	if best_direction == Vector2.ZERO:
		best_direction = Vector2.UP
	return best_direction.normalized()


func _build_velocity_from_direction(direction: Vector2, speed: float, separation_scale: float) -> Vector2:
	if direction == Vector2.ZERO:
		return (_get_separation_push() * separation_scale).limit_length(speed)

	var desired_velocity := direction.normalized() * speed + _get_separation_push() * separation_scale
	var speed_limit := speed * 1.2
	if desired_velocity.length() > speed_limit:
		desired_velocity = desired_velocity.normalized() * speed_limit
	return desired_velocity


func _get_distance_to_player() -> float:
	if player == null:
		return -1.0
	return global_position.distance_to(player.global_position)


func _get_direction_away_from_player() -> Vector2:
	if player == null:
		return Vector2.ZERO
	var away := global_position - player.global_position
	if away.length_squared() <= 0.001:
		return Vector2.ZERO
	return away.normalized()


func _get_player_segment_hit_position(start_position: Vector2, end_position: Vector2) -> Vector2:
	if player == null:
		return Vector2.INF

	var closest_point := _get_closest_point_on_segment(player.global_position, start_position, end_position)
	var hit_radius := body_radius + player.damage_hit_radius - 1.0
	if closest_point.distance_to(player.global_position) > hit_radius:
		return Vector2.INF
	return closest_point


func _get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return segment_start

	var projection := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return segment_start + segment * projection


func _get_hit_direction_from_position(hit_position: Vector2) -> Vector2:
	if player == null:
		return pounce_locked_direction

	var push_direction := player.global_position - hit_position
	if push_direction.length_squared() <= 0.001:
		push_direction = pounce_locked_direction
	if push_direction.length_squared() <= 0.001:
		push_direction = Vector2.LEFT if facing_left else Vector2.RIGHT
	return push_direction.normalized()


func _update_facing_from_reference(reference: Vector2) -> void:
	if absf(reference.x) > 0.05:
		facing_left = reference.x < 0.0


func _is_tracked_spear_currently_held() -> bool:
	return tracked_spear != null and tracked_spear.state == Spear.State.HELD


func _apply_spear_state_immediately() -> void:
	tracked_spear_is_held = _is_tracked_spear_currently_held()
	hunt_pounce_available = not tracked_spear_is_held
	if tracked_spear_is_held:
		_enter_stalk_state(true)
	else:
		_enter_alert_state()


func _connect_spear_state_signal() -> void:
	if tracked_spear == null:
		return

	var state_changed_callable := Callable(self, "_on_tracked_spear_state_changed")
	if not tracked_spear.state_changed.is_connected(state_changed_callable):
		tracked_spear.state_changed.connect(state_changed_callable)


func _disconnect_spear_state_signal() -> void:
	if tracked_spear == null:
		return

	var state_changed_callable := Callable(self, "_on_tracked_spear_state_changed")
	if tracked_spear.state_changed.is_connected(state_changed_callable):
		tracked_spear.state_changed.disconnect(state_changed_callable)


func _on_tracked_spear_state_changed(new_state: int) -> void:
	var new_is_held := new_state == Spear.State.HELD
	if new_is_held == tracked_spear_is_held:
		return

	tracked_spear_is_held = new_is_held
	if tracked_spear_is_held:
		hunt_pounce_available = false
		if prowler_state == ProwlerState.POUNCE:
			return
		_enter_stalk_state(true)
		return

	hunt_pounce_available = true
	if prowler_state == ProwlerState.POUNCE:
		return
	if prowler_state == ProwlerState.RETREAT:
		return
	_enter_alert_state()


func _set_prowler_state(new_state: ProwlerState) -> void:
	if prowler_state == new_state:
		return

	prowler_state = new_state
	state_elapsed = 0.0
	state_changed.emit(prowler_state)


func _clear_state_timers() -> void:
	state_time_left = 0.0
	state_elapsed = 0.0
	alert_twitch_left = 0.0
	defensive_retrigger_left = 0.0
	lateral_commit_left = 0.0
	wall_fallback_left = 0.0
	wall_fallback_direction = Vector2.ZERO


func _clamp_point_to_arena(target_position: Vector2) -> Vector2:
	if arena_rect.size == Vector2.ZERO:
		return target_position

	return Vector2(
		clamp(
			target_position.x,
			arena_rect.position.x + body_radius,
			arena_rect.end.x - body_radius
		),
		clamp(
			target_position.y,
			arena_rect.position.y + body_radius,
			arena_rect.end.y - body_radius
		)
	)


func _distance_to_nearest_wall(target_position: Vector2) -> float:
	if arena_rect.size == Vector2.ZERO:
		return 0.0

	var left_distance := target_position.x - (arena_rect.position.x + body_radius)
	var right_distance := (arena_rect.end.x - body_radius) - target_position.x
	var top_distance := target_position.y - (arena_rect.position.y + body_radius)
	var bottom_distance := (arena_rect.end.y - body_radius) - target_position.y
	return minf(minf(left_distance, right_distance), minf(top_distance, bottom_distance))


func _try_contact_damage() -> void:
	match prowler_state:
		ProwlerState.STALK, ProwlerState.HUNT, ProwlerState.WARY_UNARMED:
			if _is_touching_player():
				player.take_damage(global_position, Player.DAMAGE_SOURCE_CONTACT)
		_:
			return


func _draw_alive_body(fill_color: Color) -> void:
	super._draw_alive_body(fill_color)
	if _has_red_eyes():
		var eye_offset_x := -1.0 if facing_left else 1.0
		draw_circle(_get_visual_offset() + Vector2(eye_offset_x, -2.0), 0.8, Color8(255, 82, 82))


func _has_red_eyes() -> bool:
	return (
		prowler_state == ProwlerState.ALERT
		or prowler_state == ProwlerState.HUNT
		or prowler_state == ProwlerState.WARY_UNARMED
		or (prowler_state == ProwlerState.POUNCE_WINDUP and pounce_mode == PounceMode.HUNT)
		or (prowler_state == ProwlerState.POUNCE and pounce_mode == PounceMode.HUNT)
		or prowler_state == ProwlerState.IMPACT_RECOIL
	)


func _get_visual_offset() -> Vector2:
	var bob_speed := 4.0
	var bob_amplitude := 1.0
	var x_bias := 0.0
	var y_bias := 1.0

	match prowler_state:
		ProwlerState.DEFENSIVE_WINDUP:
			bob_speed = 6.5
			x_bias = -1.0 if facing_left else 1.0
			y_bias = 2.0
		ProwlerState.ALERT:
			bob_speed = 8.0
			x_bias = -1.0 if facing_left else 1.0
			y_bias = -1.0
		ProwlerState.HUNT, ProwlerState.WARY_UNARMED:
			bob_speed = 11.0
			bob_amplitude = 2.0
			x_bias = -2.0 if facing_left else 2.0
			y_bias = 0.0
		ProwlerState.POUNCE_WINDUP:
			bob_speed = 8.0
			x_bias = -1.0 if facing_left else 1.0
			y_bias = 2.0
		ProwlerState.POUNCE:
			x_bias = -2.0 if facing_left else 2.0
			y_bias = -1.0
		ProwlerState.IMPACT_RECOIL:
			x_bias = 1.0 if facing_left else -1.0
			y_bias = 1.0
		ProwlerState.MISS_SKID:
			x_bias = -1.0 if facing_left else 1.0
			y_bias = 1.0
		ProwlerState.MISS_STUN:
			y_bias = 2.0
		ProwlerState.RETREAT:
			bob_speed = 9.0
			x_bias = 1.0 if facing_left else -1.0
			y_bias = 0.0

	var bob_phase := visual_time * bob_speed + float(get_instance_id() % 23)
	var bob_offset := roundf(sin(bob_phase) * bob_amplitude)
	var base_offset := SPRITE_BASE_OFFSET + Vector2(x_bias, y_bias + bob_offset)
	if alert_twitch_left > 0.0:
		base_offset += Vector2(-1.0 if facing_left else 1.0, -1.0)
	return base_offset.round()


func _get_visual_scale() -> Vector2:
	match prowler_state:
		ProwlerState.DEFENSIVE_WINDUP, ProwlerState.POUNCE_WINDUP:
			return Vector2(0.94, 1.08)
		ProwlerState.ALERT:
			return Vector2(1.06, 0.94)
		ProwlerState.HUNT, ProwlerState.WARY_UNARMED:
			return Vector2(1.08, 0.92)
		ProwlerState.POUNCE:
			return Vector2(1.12, 0.88)
		ProwlerState.IMPACT_RECOIL:
			return Vector2(0.96, 1.04)
		ProwlerState.MISS_SKID:
			return Vector2(1.04, 0.96)
		ProwlerState.MISS_STUN:
			return Vector2(0.98, 1.02)
	return Vector2(1.02, 0.96)


func _update_sprite_visuals() -> void:
	super._update_sprite_visuals()
	if sprite != null and sprite.visible:
		sprite.flip_h = facing_left
		sprite.frame_coords = _get_animation_frame_coords()


func _get_animation_frame_coords() -> Vector2i:
	match prowler_state:
		ProwlerState.STALK, ProwlerState.RETREAT:
			return Vector2i(_get_looping_frame(STALK_FRAME_DURATION), ANIMATION_ROW_STALK)
		ProwlerState.DEFENSIVE_WINDUP:
			return Vector2i(mini(int(floor(_get_finite_state_progress(defensive_windup_duration) * 4.0)), 3), ANIMATION_ROW_ALERT)
		ProwlerState.ALERT:
			return Vector2i(mini(int(floor(_get_finite_state_progress(unarmed_alert_delay) * 4.0)), 3), ANIMATION_ROW_ALERT)
		ProwlerState.HUNT, ProwlerState.WARY_UNARMED:
			return Vector2i(_get_looping_frame(HUNT_FRAME_DURATION), ANIMATION_ROW_HUNT)
		ProwlerState.POUNCE_WINDUP:
			return Vector2i(mini(int(floor(_get_finite_state_progress(hunt_pounce_windup_duration) * 2.0)), 1), ANIMATION_ROW_POUNCE)
		ProwlerState.POUNCE:
			return Vector2i(2 + mini(int(floor(_get_finite_state_progress(pounce_total_duration) * 2.0)), 1), ANIMATION_ROW_POUNCE)
		ProwlerState.IMPACT_RECOIL:
			return Vector2i(3, ANIMATION_ROW_POUNCE)
		ProwlerState.MISS_SKID:
			return Vector2i(_get_looping_frame(RECOVERY_FRAME_DURATION), ANIMATION_ROW_RECOVERY)
		ProwlerState.MISS_STUN:
			return Vector2i(2 + mini(int(floor(_get_finite_state_progress(miss_stun_duration) * 2.0)), 1), ANIMATION_ROW_RECOVERY)
	return Vector2i.ZERO


func _get_looping_frame(frame_duration: float) -> int:
	if frame_duration <= 0.0:
		return 0
	return int(floor(state_elapsed / frame_duration)) % ANIMATION_FRAME_COUNT


func _get_finite_state_progress(total_duration: float) -> float:
	if total_duration <= 0.0:
		return 1.0
	return clampf(state_elapsed / total_duration, 0.0, 1.0)
