extends Node
class_name EncounterDirector

signal spawn_requested(
	request_id: int,
	enemy_kind: int,
	spawn_edge: int,
	wave_id: int
)
signal telegraph_started(wave_name: StringName, edges: Array[int], duration: float)
signal telegraph_finished
signal ambient_spawn_policy_changed(allowed: bool)
signal state_changed(new_state: int)
signal wave_started(wave_name: StringName, wave_id: int)
signal wave_completed(wave_name: StringName, wave_id: int)
signal recovery_started(wave_name: StringName, duration: float)

enum EncounterState {
	AMBIENT,
	WAVE_TELEGRAPH,
	WAVE_ACTIVE,
	WAVE_RECOVERY,
	DISABLED,
}

enum EnemyKind {
	NORMAL,
	CHARGER,
	SHIELDED,
	SHOOTER,
	BOOMER,
}

enum EdgeRole {
	PRIMARY,
	OPPOSITE,
}

const WAVE_RUSH := &"rush"
const WAVE_PINCER := &"pincer"
const WAVE_CHARGER_HUNT := &"charger_hunt"
const INVALID_WAVE_ID := -1

@export var first_wave_time_min := 28.0
@export var first_wave_time_max := 34.0
@export var inter_wave_interval_min := 18.0
@export var inter_wave_interval_max := 24.0
@export var rush_start_population_threshold := 5
@export var pincer_start_population_threshold := 3
@export var charger_hunt_start_population_threshold := 4
@export var total_hostile_cap := 10
@export var normal_hostile_cap := 9
@export var charger_hostile_cap := 2
@export var shielded_hostile_cap := 1
@export var shooter_hostile_cap := 2
@export var boomer_hostile_cap := 1
@export var first_minute_charger_cap := 1
@export var spawn_retry_interval := 0.3

class SpawnStep:
	extends RefCounted

	var time_offset: float
	var enemy_kind: int
	var edge_role: int

	func _init(new_time_offset: float, new_enemy_kind: int, new_edge_role: int) -> void:
		time_offset = new_time_offset
		enemy_kind = new_enemy_kind
		edge_role = new_edge_role


class WaveDefinition:
	extends RefCounted

	var wave_name: StringName
	var earliest_time: float
	var telegraph_duration: float
	var recovery_duration: float
	var start_population_threshold: int
	var uses_opposite_edge: bool
	var steps: Array[SpawnStep]

	func _init(
		new_wave_name: StringName,
		new_earliest_time: float,
		new_telegraph_duration: float,
		new_recovery_duration: float,
		new_start_population_threshold: int,
		new_uses_opposite_edge: bool,
		new_steps: Array[SpawnStep]
	) -> void:
		wave_name = new_wave_name
		earliest_time = new_earliest_time
		telegraph_duration = new_telegraph_duration
		recovery_duration = new_recovery_duration
		start_population_threshold = new_start_population_threshold
		uses_opposite_edge = new_uses_opposite_edge
		steps = new_steps


class ResolvedSpawnStep:
	extends RefCounted

	var time_offset: float
	var enemy_kind: int
	var spawn_edge: int

	func _init(new_time_offset: float, new_enemy_kind: int, new_spawn_edge: int) -> void:
		time_offset = new_time_offset
		enemy_kind = new_enemy_kind
		spawn_edge = new_spawn_edge


var current_state: EncounterState = EncounterState.DISABLED
var rng := RandomNumberGenerator.new()
var run_generation := 0

var _wave_definitions: Array[WaveDefinition] = []
var _enemy_records: Dictionary = {}
var _wave_enemy_ids: Dictionary = {}
var _current_wave: WaveDefinition
var _resolved_steps: Array[ResolvedSpawnStep] = []
var _current_wave_id := INVALID_WAVE_ID
var _next_wave_id := 0
var _current_wave_edges: Array[int] = []
var _completed_wave_count := 0
var _next_wave_eligible_time := 0.0
var _active_wave_time := 0.0
var _state_time_left := 0.0
var _spawn_retry_left := 0.0
var _next_request_id := 1
var _pending_request_id := 0
var _scheduled_spawn_index := 0


func _ready() -> void:
	rng.randomize()
	_wave_definitions = _build_wave_definitions()


func reset_for_new_run() -> void:
	run_generation += 1
	_enemy_records.clear()
	_wave_enemy_ids.clear()
	_current_wave = null
	_resolved_steps.clear()
	_current_wave_id = INVALID_WAVE_ID
	_next_wave_id = 0
	_current_wave_edges.clear()
	_completed_wave_count = 0
	_active_wave_time = 0.0
	_state_time_left = 0.0
	_spawn_retry_left = 0.0
	_pending_request_id = 0
	_scheduled_spawn_index = 0
	_next_wave_eligible_time = rng.randf_range(first_wave_time_min, first_wave_time_max)
	_set_state(EncounterState.AMBIENT)
	telegraph_finished.emit()


func stop_for_game_over() -> void:
	_pending_request_id = 0
	_resolved_steps.clear()
	_set_state(EncounterState.DISABLED)
	ambient_spawn_policy_changed.emit(false)
	telegraph_finished.emit()


func advance(delta: float, survival_time: float) -> void:
	_cleanup_invalid_enemy_records()

	match current_state:
		EncounterState.AMBIENT:
			_advance_ambient(survival_time)
		EncounterState.WAVE_TELEGRAPH:
			_advance_telegraph(delta)
		EncounterState.WAVE_ACTIVE:
			_advance_active_wave(delta, survival_time)
		EncounterState.WAVE_RECOVERY:
			_advance_recovery(delta, survival_time)


func is_ambient_spawning_allowed() -> bool:
	return current_state == EncounterState.AMBIENT


func can_spawn_enemy(enemy_kind: int, survival_time: float) -> bool:
	_cleanup_invalid_enemy_records()
	if get_total_hostile_count() >= total_hostile_cap:
		return false

	match enemy_kind:
		EnemyKind.NORMAL:
			return get_normal_hostile_count() < normal_hostile_cap
		EnemyKind.CHARGER:
			var effective_cap := charger_hostile_cap
			if survival_time < 60.0:
				effective_cap = mini(effective_cap, first_minute_charger_cap)
			return get_charger_hostile_count() < effective_cap
		EnemyKind.SHIELDED:
			return get_shielded_hostile_count() < shielded_hostile_cap
		EnemyKind.SHOOTER:
			return get_shooter_hostile_count() < shooter_hostile_cap
		EnemyKind.BOOMER:
			return get_boomer_hostile_count() < boomer_hostile_cap

	return false


func register_enemy(enemy: Node, enemy_kind: int, wave_id: int) -> void:
	if enemy == null:
		return

	var enemy_id := enemy.get_instance_id()
	_enemy_records[enemy_id] = {
		"reference": weakref(enemy),
		"enemy_kind": enemy_kind,
		"wave_id": wave_id,
		"generation": run_generation,
	}
	if wave_id != INVALID_WAVE_ID:
		_wave_enemy_ids[enemy_id] = wave_id


func report_spawn_result(request_id: int, succeeded: bool) -> void:
	if request_id != _pending_request_id:
		return

	_pending_request_id = 0
	if succeeded:
		_scheduled_spawn_index += 1
		_spawn_retry_left = 0.0
	else:
		_spawn_retry_left = spawn_retry_interval


func notify_enemy_removed(enemy_id: int, generation: int) -> bool:
	if generation != run_generation:
		return false
	if not _enemy_records.has(enemy_id):
		return false

	_enemy_records.erase(enemy_id)
	_wave_enemy_ids.erase(enemy_id)
	return true


func get_run_generation() -> int:
	return run_generation


func get_total_hostile_count() -> int:
	return _enemy_records.size()


func get_normal_hostile_count() -> int:
	return _get_enemy_kind_count(EnemyKind.NORMAL)


func get_charger_hostile_count() -> int:
	return _get_enemy_kind_count(EnemyKind.CHARGER)


func get_shielded_hostile_count() -> int:
	return _get_enemy_kind_count(EnemyKind.SHIELDED)


func get_shooter_hostile_count() -> int:
	return _get_enemy_kind_count(EnemyKind.SHOOTER)


func get_boomer_hostile_count() -> int:
	return _get_enemy_kind_count(EnemyKind.BOOMER)


func _advance_ambient(survival_time: float) -> void:
	if survival_time < _next_wave_eligible_time:
		return

	var next_wave := _choose_next_wave(survival_time)
	if next_wave == null:
		return

	_begin_wave_telegraph(next_wave)


func _advance_telegraph(delta: float) -> void:
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	if _state_time_left > 0.0:
		return

	telegraph_finished.emit()
	_active_wave_time = 0.0
	_set_state(EncounterState.WAVE_ACTIVE)
	wave_started.emit(_current_wave.wave_name, _current_wave_id)


func _advance_active_wave(delta: float, survival_time: float) -> void:
	_active_wave_time += delta
	_spawn_retry_left = maxf(_spawn_retry_left - delta, 0.0)

	if _pending_request_id == 0 and _scheduled_spawn_index < _resolved_steps.size():
		var next_step := _resolved_steps[_scheduled_spawn_index]
		if _active_wave_time >= next_step.time_offset and _spawn_retry_left <= 0.0:
			if can_spawn_enemy(next_step.enemy_kind, survival_time):
				_request_wave_spawn(next_step)
			else:
				_spawn_retry_left = spawn_retry_interval

	if (
		_scheduled_spawn_index >= _resolved_steps.size()
		and _pending_request_id == 0
		and _wave_enemy_ids.is_empty()
	):
		_complete_active_wave()


func _advance_recovery(delta: float, survival_time: float) -> void:
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	if _state_time_left > 0.0:
		return

	_completed_wave_count += 1
	_current_wave = null
	_resolved_steps.clear()
	_current_wave_id = INVALID_WAVE_ID
	_current_wave_edges.clear()
	_scheduled_spawn_index = 0
	_active_wave_time = 0.0
	_next_wave_eligible_time = survival_time + rng.randf_range(
		inter_wave_interval_min,
		inter_wave_interval_max
	)
	_set_state(EncounterState.AMBIENT)
	ambient_spawn_policy_changed.emit(true)


func _begin_wave_telegraph(wave: WaveDefinition) -> void:
	_current_wave = wave
	_current_wave_id = _next_wave_id
	_next_wave_id += 1
	_current_wave_edges = _choose_wave_edges(wave)
	_resolved_steps = _resolve_steps(wave, _current_wave_edges)
	_scheduled_spawn_index = 0
	_pending_request_id = 0
	_spawn_retry_left = 0.0
	_state_time_left = wave.telegraph_duration
	_set_state(EncounterState.WAVE_TELEGRAPH)
	ambient_spawn_policy_changed.emit(false)
	telegraph_started.emit(wave.wave_name, _current_wave_edges, wave.telegraph_duration)


func _complete_active_wave() -> void:
	var completed_name := _current_wave.wave_name
	var completed_id := _current_wave_id
	wave_completed.emit(completed_name, completed_id)
	_state_time_left = _current_wave.recovery_duration
	_set_state(EncounterState.WAVE_RECOVERY)
	recovery_started.emit(completed_name, _current_wave.recovery_duration)


func _request_wave_spawn(step: ResolvedSpawnStep) -> void:
	_pending_request_id = _next_request_id
	_next_request_id += 1
	spawn_requested.emit(
		_pending_request_id,
		step.enemy_kind,
		step.spawn_edge,
		_current_wave_id
	)


func _choose_next_wave(survival_time: float) -> WaveDefinition:
	if _wave_definitions.is_empty():
		return null

	var living_hostiles := get_total_hostile_count()
	var preferred_name := WAVE_RUSH
	match _completed_wave_count % 3:
		1:
			preferred_name = WAVE_PINCER
		2:
			preferred_name = WAVE_CHARGER_HUNT

	for wave in _wave_definitions:
		if (
			wave.wave_name == preferred_name
			and survival_time >= wave.earliest_time
			and living_hostiles <= wave.start_population_threshold
		):
			return wave

	for wave in _wave_definitions:
		if survival_time >= wave.earliest_time and living_hostiles <= wave.start_population_threshold:
			return wave

	return null


func _choose_wave_edges(wave: WaveDefinition) -> Array[int]:
	var primary_edge := rng.randi_range(Arena.SpawnEdge.TOP, Arena.SpawnEdge.RIGHT)
	var edges: Array[int] = [primary_edge]
	if wave.uses_opposite_edge:
		edges.append(Arena.get_opposite_spawn_edge(primary_edge))
	return edges


func _resolve_steps(wave: WaveDefinition, edges: Array[int]) -> Array[ResolvedSpawnStep]:
	var resolved: Array[ResolvedSpawnStep] = []
	var primary_edge := edges[0]
	var opposite_edge := primary_edge
	if edges.size() > 1:
		opposite_edge = edges[1]

	for step in wave.steps:
		var resolved_edge := primary_edge
		if step.edge_role == EdgeRole.OPPOSITE:
			resolved_edge = opposite_edge
		resolved.append(ResolvedSpawnStep.new(step.time_offset, step.enemy_kind, resolved_edge))

	return resolved


func _get_enemy_kind_count(enemy_kind: int) -> int:
	var count := 0
	for record_variant in _enemy_records.values():
		var record := record_variant as Dictionary
		if int(record.get("enemy_kind", -1)) == enemy_kind:
			count += 1
	return count


func _cleanup_invalid_enemy_records() -> void:
	var stale_ids: Array[int] = []
	for enemy_id_variant in _enemy_records:
		var enemy_id := int(enemy_id_variant)
		var record := _enemy_records[enemy_id] as Dictionary
		var enemy_reference := record.get("reference") as WeakRef
		if enemy_reference == null or enemy_reference.get_ref() == null:
			stale_ids.append(enemy_id)

	for enemy_id in stale_ids:
		_enemy_records.erase(enemy_id)
		_wave_enemy_ids.erase(enemy_id)


func _set_state(new_state: EncounterState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(current_state)


func _build_wave_definitions() -> Array[WaveDefinition]:
	var definitions: Array[WaveDefinition] = []

	var rush_steps: Array[SpawnStep] = [
		SpawnStep.new(0.0, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(0.4, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(0.8, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(1.2, EnemyKind.NORMAL, EdgeRole.PRIMARY),
	]
	definitions.append(
		WaveDefinition.new(
			WAVE_RUSH,
			28.0,
			1.75,
			3.0,
			rush_start_population_threshold,
			false,
			rush_steps
		)
	)

	var pincer_steps: Array[SpawnStep] = [
		SpawnStep.new(0.0, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(0.45, EnemyKind.NORMAL, EdgeRole.OPPOSITE),
		SpawnStep.new(0.9, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(1.35, EnemyKind.NORMAL, EdgeRole.OPPOSITE),
		SpawnStep.new(1.8, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(2.25, EnemyKind.NORMAL, EdgeRole.OPPOSITE),
	]
	definitions.append(
		WaveDefinition.new(
			WAVE_PINCER,
			28.0,
			1.75,
			3.0,
			pincer_start_population_threshold,
			true,
			pincer_steps
		)
	)

	var charger_hunt_steps: Array[SpawnStep] = [
		SpawnStep.new(0.0, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(0.55, EnemyKind.NORMAL, EdgeRole.PRIMARY),
		SpawnStep.new(1.2, EnemyKind.CHARGER, EdgeRole.PRIMARY),
	]
	definitions.append(
		WaveDefinition.new(
			WAVE_CHARGER_HUNT,
			48.0,
			1.75,
			3.0,
			charger_hunt_start_population_threshold,
			false,
			charger_hunt_steps
		)
	)

	return definitions
