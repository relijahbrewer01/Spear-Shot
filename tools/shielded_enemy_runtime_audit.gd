extends Node

const PlayerScene := preload("res://Player.tscn")
const SpearScene := preload("res://Spear.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ShieldedScene := preload("res://ShieldedEnemy.tscn")
const MainScene := preload("res://Main.tscn")

var play_rect := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	_ensure_input_actions()
	await _audit_launch_sweep_ordering()
	await _audit_flying_callback_invalidation()
	await _audit_second_hit_scoring()
	await _audit_held_and_edge_landing_safety()
	await _audit_stagger_contact_pause_and_clear()
	await _audit_director_counts_and_ambient_cap_removal()

	for failure in failures:
		push_error("SHIELDED AUDIT: %s" % failure)
	if failures.is_empty():
		print("Shielded enemy runtime audit passed.")

	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_launch_sweep_ordering() -> void:
	var case_root := Node2D.new()
	add_child(case_root)

	var player := _spawn_player(case_root, Vector2(96.0, 108.0))
	var spear := _spawn_spear(case_root, player)
	var near_normal := _spawn_normal(case_root, player, Vector2(120.0, 108.0))
	var shielded := _spawn_shielded(case_root, player, Vector2(145.0, 108.0))
	var far_normal := _spawn_normal(case_root, player, Vector2(170.0, 108.0))
	spear.launch_sweep_end_offset = 92.0

	var counters := {
		"near_kills": 0,
		"far_kills": 0,
		"shield_kills": 0,
		"shield_breaks": 0,
	}
	near_normal.killed.connect(func(_position: Vector2, _score: int) -> void:
		counters["near_kills"] = int(counters["near_kills"]) + 1
	)
	far_normal.killed.connect(func(_position: Vector2, _score: int) -> void:
		counters["far_kills"] = int(counters["far_kills"]) + 1
	)
	shielded.killed.connect(func(_position: Vector2, _score: int) -> void:
		counters["shield_kills"] = int(counters["shield_kills"]) + 1
	)
	shielded.shield_broken.connect(func(_position: Vector2) -> void:
		counters["shield_breaks"] = int(counters["shield_breaks"]) + 1
	)

	await get_tree().physics_frame
	var threw := spear.try_throw(player.global_position + Vector2.RIGHT * 100.0)
	_require(threw, "Launch-sweep audit throw starts successfully.")
	_require(near_normal.is_dying and int(counters["near_kills"]) == 1, "Launch sweep kills the nearer normal before the shield.")
	_require(int(counters["shield_breaks"]) == 1, "Launch sweep breaks the first intact Shielded shield.")
	_require(not shielded.is_dying and int(counters["shield_kills"]) == 0, "First Shielded hit does not kill or score.")
	_require(not far_normal.is_dying and int(counters["far_kills"]) == 0, "Launch sweep does not process enemies beyond a stopped shield.")
	_require(spear.is_landed(), "Launch sweep STOPPED response lands the spear immediately.")
	_require(not shielded.is_shield_intact(), "Shielded remains exposed after the first hit.")

	case_root.queue_free()
	await get_tree().process_frame


func _audit_flying_callback_invalidation() -> void:
	var case_root := Node2D.new()
	add_child(case_root)

	var player := _spawn_player(case_root, Vector2(88.0, 108.0))
	var spear := _spawn_spear(case_root, player)
	var shielded := _spawn_shielded(case_root, player, Vector2(142.0, 108.0))
	var far_normal := _spawn_normal(case_root, player, Vector2(166.0, 108.0))
	spear.launch_sweep_end_offset = 1.0

	var counters := {
		"shield_breaks": 0,
		"far_kills": 0,
	}
	shielded.shield_broken.connect(func(_position: Vector2) -> void:
		counters["shield_breaks"] = int(counters["shield_breaks"]) + 1
	)
	far_normal.killed.connect(func(_position: Vector2, _score: int) -> void:
		counters["far_kills"] = int(counters["far_kills"]) + 1
	)

	await get_tree().physics_frame
	_require(spear.try_throw(player.global_position + Vector2.RIGHT * 100.0), "Flying-callback audit throw starts.")
	spear.call("_on_flying_damage_body_entered", shielded)
	spear.call("_on_flying_damage_body_entered", far_normal)

	_require(not shielded.is_shield_intact() and int(counters["shield_breaks"]) == 1, "Manual flying callback breaks the shield once.")
	_require(spear.is_landed(), "STOPPED flying callback lands the spear.")
	_require(not far_normal.is_dying and int(counters["far_kills"]) == 0, "Later callbacks from the same throw observe non-flying state.")

	case_root.queue_free()
	await get_tree().process_frame


func _audit_second_hit_scoring() -> void:
	var case_root := Node2D.new()
	add_child(case_root)

	var player := _spawn_player(case_root, Vector2(96.0, 108.0))
	var shielded := _spawn_shielded(case_root, player, Vector2(132.0, 108.0))
	var counters := {
		"killed_count": 0,
		"killed_score": 0,
		"broken_count": 0,
	}
	shielded.shield_broken.connect(func(_position: Vector2) -> void:
		counters["broken_count"] = int(counters["broken_count"]) + 1
	)
	shielded.killed.connect(func(_position: Vector2, score: int) -> void:
		counters["killed_count"] = int(counters["killed_count"]) + 1
		counters["killed_score"] = score
	)

	await get_tree().physics_frame
	var first_response := int(shielded.receive_combat_hit(
		Enemy.HIT_SOURCE_SPEAR,
		shielded.global_position - Vector2.RIGHT * shielded.body_radius,
		Vector2.RIGHT
	))
	var second_response := int(shielded.receive_combat_hit(
		Enemy.HIT_SOURCE_SPEAR,
		shielded.global_position - Vector2.RIGHT * shielded.body_radius,
		Vector2.RIGHT
	))
	var third_response := int(shielded.receive_combat_hit(
		Enemy.HIT_SOURCE_SPEAR,
		shielded.global_position - Vector2.RIGHT * shielded.body_radius,
		Vector2.RIGHT
	))

	_require(first_response == Enemy.HitResponse.STOPPED, "First Shielded spear hit returns STOPPED.")
	_require(int(counters["broken_count"]) == 1, "Shield break emits exactly one shield_broken signal.")
	_require(second_response == Enemy.HitResponse.DAMAGED, "Second Shielded spear hit uses normal damage response.")
	_require(third_response == Enemy.HitResponse.IGNORED, "Duplicate exposed hit after death is ignored.")
	_require(int(counters["killed_count"]) == 1, "Exposed Shielded death emits exactly one killed signal.")
	_require(int(counters["killed_score"]) == 2, "Exposed Shielded death reports exactly 2 score points.")

	case_root.queue_free()
	await get_tree().process_frame


func _audit_held_and_edge_landing_safety() -> void:
	var held_root := Node2D.new()
	add_child(held_root)
	var held_player := _spawn_player(held_root, Vector2(96.0, 108.0))
	var held_spear := _spawn_spear(held_root, held_player)
	var held_shielded := _spawn_shielded(held_root, held_player, Vector2(124.0, 108.0))
	await get_tree().physics_frame
	held_spear.call("_on_flying_damage_body_entered", held_shielded)
	_require(held_shielded.is_shield_intact(), "Held spear callback remains harmless.")
	held_root.queue_free()
	await get_tree().process_frame

	var edge_root := Node2D.new()
	add_child(edge_root)
	var edge_player := _spawn_player(edge_root, Vector2(24.0, 30.0))
	var edge_spear := _spawn_spear(edge_root, edge_player)
	var edge_shielded := _spawn_shielded(edge_root, edge_player, Vector2(30.0, 30.0))
	edge_spear.launch_sweep_end_offset = 1.0
	await get_tree().physics_frame
	_require(edge_spear.try_throw(edge_player.global_position + Vector2.RIGHT * 100.0), "Edge landing throw starts.")
	edge_spear.call("_on_flying_damage_body_entered", edge_shielded)

	var clamped_rect := Rect2(play_rect.position + Vector2(4.0, 4.0), play_rect.size - Vector2(8.0, 8.0))
	var clear_distance := edge_spear.global_position.distance_to(edge_shielded.global_position)
	_require(edge_spear.is_landed(), "Edge shield stop still lands the spear.")
	_require(clamped_rect.has_point(edge_spear.global_position), "Forced landing is clamped inside spear bounds.")
	_require(clear_distance >= edge_shielded.body_radius + 2.0, "Forced landing does not remain centered in the Shielded body.")

	edge_root.queue_free()
	await get_tree().process_frame


func _audit_stagger_contact_pause_and_clear() -> void:
	var case_root := Node2D.new()
	add_child(case_root)

	var player := _spawn_player(case_root, Vector2(128.0, 108.0))
	var shielded := _spawn_shielded(case_root, player, Vector2(128.0, 108.0))
	await get_tree().physics_frame

	var starting_health := player.health
	var response := int(shielded.receive_combat_hit(
		Enemy.HIT_SOURCE_SPEAR,
		shielded.global_position - Vector2.RIGHT * shielded.body_radius,
		Vector2.RIGHT
	))
	shielded.call("_try_contact_damage")
	_require(response == Enemy.HitResponse.STOPPED, "Shield break starts the stagger response.")
	_require(shielded.is_staggering(), "Shielded enters stagger after shield break.")
	_require(player.health == starting_health, "Contact damage is disabled during stagger.")

	var position_before_knockback := shielded.global_position
	await get_tree().physics_frame
	_require(
		shielded.global_position.x >= position_before_knockback.x,
		"Stagger uses authored knockback instead of self-directed pursuit."
	)

	var stagger_before_pause := shielded.stagger_time_left
	get_tree().paused = true
	await get_tree().create_timer(0.08, true, false, true).timeout
	_require(
		is_equal_approx(shielded.stagger_time_left, stagger_before_pause),
		"Shielded stagger freezes while the game tree is paused."
	)
	get_tree().paused = false

	shielded.set_active(false)
	_require(shielded.stagger_time_left == 0.0, "Game-over inactive state clears Shielded stagger.")
	_require(shielded.knockback_time_left == 0.0, "Game-over inactive state clears Shielded knockback.")

	case_root.queue_free()
	await get_tree().process_frame


func _audit_director_counts_and_ambient_cap_removal() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.set_process(false)

	var director := main.get_node("EncounterDirector") as EncounterDirector
	var dummy_shielded := Node.new()
	main.add_child(dummy_shielded)
	director.register_enemy(
		dummy_shielded,
		EncounterDirector.EnemyKind.SHIELDED,
		EncounterDirector.INVALID_WAVE_ID
	)

	_require(director.get_total_hostile_count() == 1, "Shielded counts toward total hostile population.")
	_require(director.get_shielded_hostile_count() == 1, "Shielded counts toward its dedicated cap.")
	_require(director.get_normal_hostile_count() == 0, "Shielded does not count as a Normal.")
	_require(director.get_charger_hostile_count() == 0, "Shielded does not count as a Charger.")
	_require(not director.can_spawn_enemy(EncounterDirector.EnemyKind.SHIELDED, 60.0), "Shielded cap blocks additional Shielded spawns.")
	_require(director.can_spawn_enemy(EncounterDirector.EnemyKind.NORMAL, 60.0), "A capped Shielded does not block Normal eligibility.")

	main.set("survival_time", 60.0)
	main.set("charger_unlock_time", 999.0)
	var picked_kind := int(main.call("_pick_ambient_enemy_kind"))
	_require(
		picked_kind == EncounterDirector.EnemyKind.NORMAL,
		"Ambient selection removes capped Shielded and still picks a valid Normal."
	)

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(play_rect)
	player.reset_for_new_run(position, play_rect)
	return player


func _spawn_spear(parent: Node, player: Player) -> Spear:
	var spear := SpearScene.instantiate() as Spear
	parent.add_child(spear)
	spear.setup(player, play_rect)
	return spear


func _spawn_normal(parent: Node, player: Player, position: Vector2) -> Enemy:
	var enemy := EnemyScene.instantiate() as Enemy
	parent.add_child(enemy)
	enemy.setup(player, play_rect, 42.0)
	enemy.global_position = position
	return enemy


func _spawn_shielded(parent: Node, player: Player, position: Vector2) -> ShieldedEnemy:
	var shielded := ShieldedScene.instantiate() as ShieldedEnemy
	parent.add_child(shielded)
	shielded.setup(player, play_rect, 42.0)
	shielded.global_position = position
	return shielded


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)


func _ensure_input_actions() -> void:
	for action_name in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
