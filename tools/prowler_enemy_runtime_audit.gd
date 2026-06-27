extends Node

const PlayerScene := preload("res://Player.tscn")
const EnemyScene := preload("res://Enemy.tscn")
const ProwlerScene := preload("res://ProwlerEnemy.tscn")
const SpearScene := preload("res://Spear.tscn")
const MainScene := preload("res://Main.tscn")
const TEST_ARENA := Rect2(Vector2(16.0, 16.0), Vector2(352.0, 184.0))
const SPAWN_SOURCE_AMBIENT := 0
const SPAWN_SOURCE_DEBUG := 2

var failures: Array[String] = []


func _ready() -> void:
	_ensure_input_actions()
	call_deferred("_run_audit")


func _run_audit() -> void:
	await _audit_stalk_and_defensive_pounce()
	await _audit_alert_hunt_and_recovery()
	await _audit_hunt_pounce_success_and_limit()
	await _audit_hunt_pounce_dodge_rejection_and_rearm()
	await _audit_death_and_score()
	await _audit_audio_hooks()
	await _audit_main_integration_and_cleanup()

	for failure in failures:
		push_error("PROWLER RUNTIME AUDIT: %s" % failure)
	print("Prowler enemy runtime audit passed." if failures.is_empty() else "Prowler enemy runtime audit failed.")
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _audit_stalk_and_defensive_pounce() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(192.0, 108.0))
	var spear := _spawn_spear(root, player)
	var prowler := _spawn_prowler(root, player, spear, Vector2(104.0, 108.0))
	var far_start_x := prowler.global_position.x
	await _advance_physics(0.30)
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.STALK, "Prowler begins in STALK while the spear is held.")
	_require(prowler.global_position.x > far_start_x + 1.0, "Prowler approaches when Akedra is beyond the stalking band.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(154.0, 108.0))
	var close_start_x := prowler.global_position.x
	await _advance_physics(0.30)
	_require(prowler.global_position.x < close_start_x - 1.0, "Prowler withdraws when Akedra crowds inside the stalking band.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(112.0, 108.0))
	await _advance_physics(0.06)
	var committed_side := prowler.lateral_side
	var stalk_start := prowler.global_position
	await _advance_physics(0.26)
	var stalk_displacement := prowler.global_position - stalk_start
	_require(stalk_displacement.length() > 2.0, "Prowler keeps moving inside the stalking band instead of freezing.")
	_require(prowler.lateral_side == committed_side, "Prowler keeps one lateral choice committed during the stalking window.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(104.0, 64.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(24.0, 64.0))
	var wall_start := prowler.global_position
	await _advance_physics(0.45)
	_require(TEST_ARENA.has_point(prowler.global_position), "Wall fallback keeps Prowler inside the arena.")
	_require(prowler.global_position.distance_to(wall_start) > 1.0, "Wall fallback still produces readable movement instead of wall vibration.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(112.0, 108.0))
	var neighbor := _spawn_normal(root, player, Vector2(118.0, 108.0))
	var initial_spacing := prowler.global_position.distance_to(neighbor.global_position)
	await _advance_physics(0.35)
	var separated_spacing := prowler.global_position.distance_to(neighbor.global_position)
	_require(separated_spacing > initial_spacing + 1.0, "Prowler participates in shared lightweight enemy separation.")
	await _free_test_root(root)

	root = Node2D.new()
	add_child(root)
	player = _spawn_player(root, Vector2(192.0, 108.0))
	spear = _spawn_spear(root, player)
	prowler = _spawn_prowler(root, player, spear, Vector2(214.0, 108.0))
	var starting_health := player.health
	await _advance_physics(0.02)
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.DEFENSIVE_WINDUP, "Crowding the armed Prowler enters DEFENSIVE_WINDUP instead of direct chase.")
	var reached_defensive_pounce := await _advance_until(
		func() -> bool:
			return prowler.prowler_state == ProwlerEnemy.ProwlerState.POUNCE and prowler.debug_get_current_pounce_mode_name() == "DEFENSIVE",
		0.30,
		"defensive pounce start"
	)
	_require(reached_defensive_pounce, "Defensive pounce begins after the short windup.")
	var reached_retreat := await _advance_until(
		func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.RETREAT,
		0.40,
		"defensive retreat"
	)
	_require(reached_retreat, "Defensive pounce crosses into RETREAT instead of stopping on top of Akedra.")
	_require(player.health == starting_health - 1, "Successful defensive pounce deals exactly 1 damage through the existing player authority.")
	player.global_position = prowler.global_position + Vector2(-6.0, 0.0)
	await _advance_physics(0.20)
	_require(prowler.prowler_state != ProwlerEnemy.ProwlerState.DEFENSIVE_WINDUP, "Defensive retrigger cooldown prevents immediate repeated armed pounces while Akedra stays crowded.")
	await _advance_until(
		func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.STALK,
		1.80,
		"defensive return to stalk"
	)
	await _free_test_root(root)


func _audit_alert_hunt_and_recovery() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(192.0, 108.0))
	var spear := _spawn_spear(root, player)
	var prowler := _spawn_prowler(root, player, spear, Vector2(220.0, 108.0))
	_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Audit setup can throw the spear to trigger the unarmed transition.")
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.ALERT, "HELD -> FLYING enters the longer one-shot ALERT state.")
	_require(prowler.debug_get_red_eyes_active(), "Alert state enables the readable red-eye visual.")
	_require(prowler.debug_has_hunt_pounce_available(), "A new armed -> unarmed transition grants one hunting pounce attempt.")
	await _advance_physics(0.06)
	var alert_time_after_tick := prowler.state_time_left
	spear.call("_enter_landed_state", Vector2(248.0, 108.0))
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.ALERT, "FLYING -> LANDED keeps the Prowler on the same unarmed escalation path.")
	_require(prowler.state_time_left <= alert_time_after_tick + 0.001, "Repeated unarmed spear states do not restart the alert timer.")

	player.global_position = spear.global_position
	spear.call("_pickup")
	_require(spear.is_held(), "Audit recovery path returns the spear to HELD.")
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.STALK, "Legitimate spear recovery cancels ALERT before any hunting pounce begins.")
	_require(not prowler.debug_get_red_eyes_active(), "Returning to HELD clears the red-eye unarmed presentation.")

	_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "A later throw can start a fresh unarmed cycle.")
	var reached_hunt := await _advance_until(
		func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.HUNT,
		0.40,
		"hunt transition"
	)
	_require(reached_hunt, "Prowler reaches HUNT after the approved 0.28-second alert.")
	await _free_test_root(root)


func _audit_hunt_pounce_success_and_limit() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(192.0, 108.0))
	var spear := _spawn_spear(root, player)
	var prowler := _spawn_prowler(root, player, spear, Vector2(220.0, 108.0))
	var hit_signal_count := 0
	prowler.hunt_pounce_hit.connect(func(_hit_position: Vector2, _hit_stop_duration: float) -> void:
		hit_signal_count += 1
	)
	var starting_health := player.health
	_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Audit setup can throw the spear before the hunting pounce success test.")
	var reached_windup := await _advance_until(
		func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.POUNCE_WINDUP,
		0.40,
		"hunt pounce windup"
	)
	_require(reached_windup, "Prowler reaches POUNCE_WINDUP while unarmed and close.")
	var locked_direction := prowler.debug_get_locked_pounce_direction()
	player.global_position += Vector2(0.0, 6.0)
	var pounce_start := prowler.global_position
	var reached_airborne := await _advance_until(
		func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.POUNCE,
		0.24,
		"hunt pounce start"
	)
	_require(reached_airborne, "Prowler begins the committed hunting pounce after its windup.")
	await _advance_physics(0.03)
	var launch_direction := (prowler.global_position - pounce_start).normalized()
	if launch_direction != Vector2.ZERO and locked_direction != Vector2.ZERO:
		_require(launch_direction.dot(locked_direction) > 0.92, "Hunting pounce movement stays locked to the pre-launch direction instead of homing mid-flight.")
	var reached_recoil_or_wary := await _advance_until(
		func() -> bool:
			return prowler.prowler_state == ProwlerEnemy.ProwlerState.IMPACT_RECOIL or prowler.prowler_state == ProwlerEnemy.ProwlerState.WARY_UNARMED,
		0.40,
		"hunt pounce resolution"
	)
	_require(reached_recoil_or_wary, "Successful hunting pounce resolves into recoil and disengagement.")
	_require(player.health == starting_health - 1, "Successful hunting pounce deals exactly 1 damage.")
	_require(player.is_in_forced_movement(), "Successful hunting pounce starts player knockback through the existing forced-movement seam.")
	_require(hit_signal_count == 1, "Successful hunting pounce emits exactly one authored hit signal for audio and hit stop.")
	_require(not prowler.debug_has_hunt_pounce_available(), "Successful hunting pounce spends the one attempt for this unarmed window.")
	await _advance_physics(0.50)
	_require(prowler.prowler_state != ProwlerEnemy.ProwlerState.POUNCE_WINDUP and prowler.prowler_state != ProwlerEnemy.ProwlerState.POUNCE, "Prowler does not begin a second hunting pounce during the same unarmed window.")
	await _free_test_root(root)


func _audit_hunt_pounce_dodge_rejection_and_rearm() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(192.0, 108.0))
	var spear := _spawn_spear(root, player)
	var prowler := _spawn_prowler(root, player, spear, Vector2(220.0, 108.0))
	var hit_signal_count := 0
	prowler.hunt_pounce_hit.connect(func(_hit_position: Vector2, _hit_stop_duration: float) -> void:
		hit_signal_count += 1
	)
	var starting_health := player.health
	_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Audit setup can throw the spear before the dodge rejection test.")
	var reached_windup := await _advance_until(
		func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.POUNCE_WINDUP,
		0.40,
		"dodge rejection windup"
	)
	_require(reached_windup, "Prowler reaches hunting windup in the dodge rejection setup.")
	_require(player.try_start_movement_dodge(Vector2.DOWN), "Player can start a dodge to reject the committed hunting pounce.")
	var reached_miss_state := await _advance_until(
		func() -> bool:
			return prowler.prowler_state == ProwlerEnemy.ProwlerState.MISS_SKID or prowler.prowler_state == ProwlerEnemy.ProwlerState.MISS_STUN or prowler.prowler_state == ProwlerEnemy.ProwlerState.WARY_UNARMED,
		0.70,
		"hunt miss resolution"
	)
	_require(reached_miss_state, "Dodge-rejected hunting pounce resolves into miss skid/stun instead of a hit.")
	_require(player.health == starting_health, "Dodge-rejected hunting pounce deals no damage.")
	_require(hit_signal_count == 0, "Rejected hunting pounce does not emit the authored hit signal.")
	_require(not player.is_in_forced_movement(), "Rejected hunting pounce does not apply player knockback.")
	_require(not prowler.debug_has_hunt_pounce_available(), "Rejected hunting pounce still spends the one attempt for this unarmed window.")

	player.global_position = spear.global_position
	spear.call("_enter_landed_state", Vector2(248.0, 108.0))
	spear.call("_pickup")
	_require(prowler.prowler_state == ProwlerEnemy.ProwlerState.STALK, "Legitimate spear recovery returns the Prowler to STALK after a spent unarmed window.")
	_require(not prowler.debug_has_hunt_pounce_available(), "Returning to HELD clears the spent unarmed-window attempt state.")
	_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "A later legitimate throw can create a fresh unarmed cycle.")
	_require(prowler.debug_has_hunt_pounce_available(), "A new armed -> unarmed transition restores one hunting pounce attempt.")
	await _free_test_root(root)


func _audit_death_and_score() -> void:
	var root := Node2D.new()
	add_child(root)
	var player := _spawn_player(root, Vector2(192.0, 108.0))
	var spear := _spawn_spear(root, player)
	var prowler := _spawn_prowler(root, player, spear, Vector2(220.0, 108.0))
	var kill_tracker := {
		"count": 0,
		"score": 0,
	}
	prowler.killed.connect(func(_enemy_position: Vector2, score_value: int) -> void:
		kill_tracker["count"] += 1
		kill_tracker["score"] = score_value
	)
	var response := prowler.receive_combat_hit(Enemy.HIT_SOURCE_SPEAR, prowler.global_position, Vector2.RIGHT)
	_require(response == Enemy.HitResponse.DAMAGED, "Prowler spear hit uses the ordinary DAMAGED response.")
	_require(prowler.is_dying, "One valid thrown-spear hit kills the Prowler.")
	_require(int(kill_tracker["count"]) == 1, "Prowler death emits exactly one killed signal.")
	_require(int(kill_tracker["score"]) == 2, "Prowler death awards exactly 2 score points.")
	await _free_test_root(root)


func _audit_audio_hooks() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var spawn_timer := main.get_node("SpawnTimer") as Timer
	spawn_timer.stop()
	main.set_process(false)

	var alert_player := main.get_node("AudioPlayers/ProwlerAlertPlayer") as AudioStreamPlayer
	var defensive_player := main.get_node("AudioPlayers/ProwlerDefensiveAttackPlayer") as AudioStreamPlayer
	var impact_player := main.get_node("AudioPlayers/ProwlerPounceHitPlayer") as AudioStreamPlayer
	var player := main.get_node("Player") as Player
	var spear := main.get_node("Spear") as Spear

	main.call("_stop_all_audio")
	main.call("debug_reset_prowler_audio_metrics")
	var startup_metrics := main.call("debug_get_prowler_audio_metrics") as Dictionary
	_require(int(startup_metrics.get("alert", -1)) == 0, "Main startup does not play the Prowler alert cue.")
	_require(int(startup_metrics.get("defensive", -1)) == 0, "Main startup does not play the Prowler defensive cue.")
	_require(int(startup_metrics.get("impact", -1)) == 0, "Main startup does not play the Prowler impact cue.")

	main.set("survival_time", 90.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Audio audit can spawn a Prowler through the ordinary ambient path."
	)
	var prowler := _find_child_prowler(main)
	_require(prowler != null and player != null and spear != null, "Audio audit can access the spawned Prowler, player, and spear.")
	if prowler != null and player != null and spear != null:
		player.global_position = Vector2(192.0, 108.0)
		prowler.global_position = Vector2(220.0, 108.0)
		spear.reset_for_new_run(player, TEST_ARENA)
		main.call("_stop_all_audio")
		main.call("debug_reset_prowler_audio_metrics")

		_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Audio audit can throw the spear to start the hostile alert cue.")
		await _advance_physics(0.04)
		var early_alert_metrics := main.call("debug_get_prowler_audio_metrics") as Dictionary
		_require(int(early_alert_metrics.get("alert", -1)) == 0, "Prowler alert cue does not fire before the small authored delay.")
		var alert_started := await _advance_until(
			func() -> bool:
				return int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("alert", 0)) == 1,
			0.20,
			"prowler alert cue"
		)
		_require(alert_started, "Prowler alert cue fires exactly once after a real HELD-to-unheld transition.")
		_require(alert_player != null and alert_player.playing, "Prowler alert AudioStreamPlayer enters playback after the real hostile transition.")
		var alert_count_before_landed := int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("alert", 0))
		spear.call("_enter_landed_state", Vector2(248.0, 108.0))
		await _advance_physics(0.12)
		_require(int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("alert", 0)) == alert_count_before_landed, "FLYING to LANDED does not replay the Prowler alert cue.")
		player.global_position = spear.global_position
		spear.call("_pickup")
		await _advance_physics(0.02)
		_require(not alert_player.playing, "Legitimate spear recovery stops any still-playing alert cue cleanly.")

		main.call("_restart_run")
		await get_tree().process_frame
		var restart_metrics := main.call("debug_get_prowler_audio_metrics") as Dictionary
		_require(int(restart_metrics.get("alert", -1)) == 0 and int(restart_metrics.get("defensive", -1)) == 0 and int(restart_metrics.get("impact", -1)) == 0, "Restart resets the Prowler audio metrics without replaying any cue.")

		main.set_process(false)
		main.set("survival_time", 90.0)
		_require(
			bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
			"Audio audit can spawn a second Prowler for defensive-cue coverage."
		)
		prowler = _find_child_prowler(main)
		player = main.get_node("Player") as Player
		spear = main.get_node("Spear") as Spear
		if prowler != null and player != null and spear != null:
			player.global_position = Vector2(192.0, 108.0)
			prowler.global_position = Vector2(214.0, 108.0)
			spear.reset_for_new_run(player, TEST_ARENA)
			main.call("_stop_all_audio")
			main.call("debug_reset_prowler_audio_metrics")
			var defensive_started := await _advance_until(
				func() -> bool:
					return int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("defensive", 0)) == 1,
				0.40,
				"prowler defensive cue"
			)
			_require(defensive_started, "Prowler defensive cue fires once when the defensive pounce commits.")
			_require(defensive_player != null and defensive_player.playing, "Prowler defensive AudioStreamPlayer enters playback on the committed defensive launch.")
			_require(int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("defensive", 0)) == 1, "Committed defensive pounce does not duplicate its cue.")

		main.call("_restart_run")
		await get_tree().process_frame
		main.set_process(false)
		main.set("survival_time", 90.0)
		main.call("debug_reset_prowler_audio_metrics")
		_require(
			bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
			"Audio audit can spawn a third Prowler for cancelled-windup coverage."
		)
		prowler = _find_child_prowler(main)
		player = main.get_node("Player") as Player
		spear = main.get_node("Spear") as Spear
		if prowler != null and player != null and spear != null:
			player.global_position = Vector2(192.0, 108.0)
			prowler.global_position = Vector2(214.0, 108.0)
			spear.reset_for_new_run(player, TEST_ARENA)
			var entered_defensive_windup := await _advance_until(
				func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.DEFENSIVE_WINDUP,
				0.12,
				"defensive windup before cancellation"
			)
			_require(entered_defensive_windup, "Audio audit can reach DEFENSIVE_WINDUP before cancelling it.")
			_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Throwing during defensive windup can cancel the defensive launch.")
			await _advance_physics(0.24)
			_require(int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("defensive", 0)) == 0, "Cancelled defensive windup does not play the defensive cue.")

		main.call("_restart_run")
		await get_tree().process_frame
		main.set_process(false)
		main.set("survival_time", 90.0)
		main.call("debug_reset_prowler_audio_metrics")
		_require(
			bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
			"Audio audit can spawn a fourth Prowler for hunting-impact coverage."
		)
		prowler = _find_child_prowler(main)
		player = main.get_node("Player") as Player
		spear = main.get_node("Spear") as Spear
		if prowler != null and player != null and spear != null:
			player.global_position = Vector2(192.0, 108.0)
			prowler.global_position = Vector2(220.0, 108.0)
			spear.reset_for_new_run(player, TEST_ARENA)
			main.call("_stop_all_audio")
			main.call("debug_reset_prowler_audio_metrics")
			_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Audio audit can re-enter the unarmed cycle for hunting-impact coverage.")
			var impact_started := await _advance_until(
				func() -> bool:
					return int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("impact", 0)) == 1,
				0.80,
				"prowler impact cue"
			)
			_require(impact_started, "Successful hunting pounce impact plays the dedicated impact cue once.")
			_require(impact_player != null and impact_player.playing, "Prowler impact AudioStreamPlayer enters playback on a valid hunting-pounce hit.")

		main.call("_restart_run")
		await get_tree().process_frame
		main.set_process(false)
		main.set("survival_time", 90.0)
		main.call("debug_reset_prowler_audio_metrics")
		_require(
			bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
			"Audio audit can spawn a fifth Prowler for hunting-miss coverage."
		)
		prowler = _find_child_prowler(main)
		player = main.get_node("Player") as Player
		spear = main.get_node("Spear") as Spear
		if prowler != null and player != null and spear != null:
			player.global_position = Vector2(192.0, 108.0)
			prowler.global_position = Vector2(220.0, 108.0)
			spear.reset_for_new_run(player, TEST_ARENA)
			main.call("_stop_all_audio")
			main.call("debug_reset_prowler_audio_metrics")
			_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Audio audit can re-enter the unarmed cycle for hunting-miss coverage.")
			var reached_windup := await _advance_until(
				func() -> bool: return prowler.prowler_state == ProwlerEnemy.ProwlerState.POUNCE_WINDUP,
				0.40,
				"hunt windup before dodge"
			)
			_require(reached_windup, "Audio audit can reach hunting windup before the dodge rejection.")
			_require(player.try_start_movement_dodge(Vector2.DOWN), "Player can dodge the hunting pounce during the audio miss audit.")
			await _advance_physics(0.70)
			_require(int((main.call("debug_get_prowler_audio_metrics") as Dictionary).get("impact", 0)) == 0, "Dodged hunting pounce miss does not play the impact cue.")

		main.call("_stop_all_audio")
		await _advance_physics(0.02)
		_require(not alert_player.playing and not defensive_player.playing and not impact_player.playing, "Explicit audio cleanup stops all active Prowler playback.")

	main.queue_free()
	await get_tree().process_frame


func _audit_main_integration_and_cleanup() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var director := main.get_node("EncounterDirector") as EncounterDirector
	var spawn_timer := main.get_node("SpawnTimer") as Timer
	spawn_timer.stop()
	main.set_process(false)

	main.set("survival_time", 77.9)
	_require(
		not bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.PROWLER)),
		"Prowler is unavailable before its 78-second unlock."
	)
	main.set("survival_time", 78.0)
	_require(
		bool(main.call("_is_enemy_kind_available_for_ambient", EncounterDirector.EnemyKind.PROWLER)),
		"Prowler becomes available at its 78-second unlock."
	)
	_require(is_equal_approx(float(main.call("_get_current_prowler_spawn_chance")), 0.03), "Prowler spawn chance starts at 0.03 at unlock.")
	main.set("survival_time", 88.0)
	_require(is_equal_approx(float(main.call("_get_current_prowler_spawn_chance")), 0.033), "Prowler spawn chance grows by 0.00030 per second after unlock.")
	main.set("survival_time", 1000.0)
	_require(is_equal_approx(float(main.call("_get_current_prowler_spawn_chance")), 0.08), "Prowler spawn chance caps at 0.08.")

	director.reset_for_new_run()
	main.set("survival_time", 90.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.TOP, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Prowler can be spawned through the ordinary ambient path."
	)
	_require(not director.can_spawn_enemy(EncounterDirector.EnemyKind.PROWLER, 90.0), "Prowler cap blocks a second active Prowler.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 90.0)
	main.set("charger_intro_seen", true)
	main.set("shielded_intro_seen", true)
	main.set("shooter_intro_seen", true)
	main.set("boomer_intro_seen", true)
	main.set("prowler_intro_seen", false)
	main.call("debug_set_intro_target_times", 15.0, 25.0, 42.0, 65.0, 78.0)
	_require(
		int(main.call("_pick_ambient_enemy_kind")) == EncounterDirector.EnemyKind.PROWLER,
		"Overdue unseen Prowler intro is prioritized on the next valid ambient opportunity."
	)
	main.call("_debug_spawn_prowler_enemy")
	_require(not bool(main.get("prowler_intro_seen")), "Debug Prowler spawn does not mark the organic intro seen.")
	main.call("_restart_run")
	await get_tree().process_frame

	main.set_process(false)
	main.set("survival_time", 90.0)
	_require(
		bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.RIGHT, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
		"Prowler can be spawned again for hit-stop and cleanup coverage."
	)
	var prowler := _find_child_prowler(main)
	var player := main.get_node("Player") as Player
	var spear := main.get_node("Spear") as Spear
	_require(prowler != null and player != null and spear != null, "Main audit can access the spawned Prowler, player, and spear.")
	if prowler != null and player != null and spear != null:
		main.call("_stop_all_audio")
		player.global_position = Vector2(192.0, 108.0)
		prowler.global_position = Vector2(220.0, 108.0)
		spear.reset_for_new_run(player, TEST_ARENA)
		_require(spear.try_throw(player.global_position + Vector2(120.0, 0.0)), "Main audit can trigger the unarmed transition for authored hit-stop coverage.")
		var hit_stop_started := await _advance_until(
			func() -> bool: return bool(main.get("hit_stop_active")),
			0.70,
			"main prowler hit stop"
		)
		_require(hit_stop_started, "Main starts the authored hit-stop path when the hunting pounce lands.")

		main.call("_restart_run")
		await get_tree().process_frame
		_require(_find_child_prowler(main) == null, "Restart clears active Prowlers.")

		main.set_process(false)
		main.set("survival_time", 90.0)
		_require(
			bool(main.call("_try_spawn_enemy", EncounterDirector.EnemyKind.PROWLER, Arena.SpawnEdge.TOP, EncounterDirector.INVALID_WAVE_ID, SPAWN_SOURCE_AMBIENT)),
			"Prowler can be spawned again after restart for pause and game-over cleanup."
		)
		prowler = _find_child_prowler(main)
		spear = main.get_node("Spear") as Spear
		if prowler != null and spear != null:
			prowler.global_position = Vector2(220.0, 108.0)
			_require(spear.try_throw(Vector2(320.0, 108.0)), "Audit setup can re-enter ALERT before testing pause cleanup.")
			var paused_position := prowler.global_position
			var paused_state_time := prowler.state_time_left
			main.call("_set_pause_state", true)
			await get_tree().create_timer(0.12, true, false, true).timeout
			_require(prowler.global_position == paused_position, "Pause freezes Prowler movement.")
			_require(is_equal_approx(prowler.state_time_left, paused_state_time), "Pause freezes the active Prowler state timer.")
			main.call("_set_pause_state", false)

			main.call("_on_player_died")
			var game_over_position := prowler.global_position
			await get_tree().create_timer(0.16, true, false, true).timeout
			_require(not prowler.active, "Game over deactivates the Prowler.")
			_require(prowler.global_position == game_over_position, "Game over cleanup prevents stale Prowler movement.")

	main.call("_stop_all_audio")
	main.queue_free()
	await get_tree().process_frame


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PlayerScene.instantiate() as Player
	parent.add_child(player)
	player.set_arena_rect(TEST_ARENA)
	player.reset_for_new_run(position, TEST_ARENA)
	return player


func _spawn_spear(parent: Node, player: Player) -> Spear:
	var spear := SpearScene.instantiate() as Spear
	parent.add_child(spear)
	spear.setup(player, TEST_ARENA)
	spear.reset_for_new_run(player, TEST_ARENA)
	return spear


func _spawn_normal(parent: Node, player: Player, position: Vector2) -> Enemy:
	var enemy := EnemyScene.instantiate() as Enemy
	parent.add_child(enemy)
	enemy.setup(player, TEST_ARENA, 42.0)
	enemy.global_position = position
	return enemy


func _spawn_prowler(parent: Node, player: Player, spear: Spear, position: Vector2) -> ProwlerEnemy:
	var prowler := ProwlerScene.instantiate() as ProwlerEnemy
	parent.add_child(prowler)
	prowler.setup(player, TEST_ARENA, 42.0)
	prowler.set_tracked_spear(spear)
	prowler.global_position = position
	return prowler


func _find_child_prowler(main: Node) -> ProwlerEnemy:
	for child in main.get_node("EnemyContainer").get_children():
		if child is ProwlerEnemy:
			return child as ProwlerEnemy
	return null


func _ensure_input_actions() -> void:
	for action_name in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _advance_physics(duration: float) -> void:
	var frame_count := maxi(int(ceil(duration / (1.0 / 60.0))), 1)
	for _frame in frame_count:
		await get_tree().physics_frame


func _advance_until(predicate: Callable, timeout: float, label: String) -> bool:
	var elapsed := 0.0
	while elapsed <= timeout:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0

	push_warning("Prowler runtime audit timed out waiting for %s." % label)
	return false


func _free_test_root(root: Node) -> void:
	root.queue_free()
	await get_tree().process_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)
