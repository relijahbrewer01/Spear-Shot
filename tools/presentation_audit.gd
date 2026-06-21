extends SceneTree

const TEXTURE_PATHS := [
	"res://art/arena/arena_floor.png",
	"res://art/sprites/player_hunter.png",
	"res://art/sprites/enemy_creature.png",
	"res://art/sprites/charger_beast.png",
	"res://art/sprites/shielded_enemy.png",
	"res://art/sprites/shooter_enemy.png",
	"res://art/sprites/boomer_enemy.png",
	"res://art/sprites/heart_runner.png",
	"res://art/sprites/heart_runner_sheet.png",
	"res://art/sprites/heart_pickup.png",
	"res://art/sprites/spear_hunter.png",
]

const AUDIO_PATHS := [
	"res://music/quiet_hunter_loop.wav",
	"res://audio/dodge.wav",
	"res://audio/wave_warning.wav",
	"res://audio/shield_break.wav",
	"res://audio/blowgun_windup.wav",
	"res://audio/blowgun_fire.wav",
	"res://audio/blowgun_shove.wav",
	"res://audio/boomer_hop_prep.wav",
	"res://audio/boomer_land.wav",
	"res://audio/boomer_fuse.wav",
	"res://audio/boomer_explosion.wav",
	"res://audio/heart_runner_appear.wav",
	"res://audio/heart_pickup_spawn.wav",
	"res://audio/heart_pickup_collect.wav",
	"res://audio/heart_pickup_expire.wav",
]

const SCENE_SPRITES := {
	"res://Player.tscn": "BodyVisual/Sprite2D",
	"res://Enemy.tscn": "Sprite2D",
	"res://Charger.tscn": "Sprite2D",
	"res://ShieldedEnemy.tscn": "Sprite2D",
	"res://ShooterEnemy.tscn": "Sprite2D",
	"res://BoomerEnemy.tscn": "Sprite2D",
	"res://HeartRunner.tscn": "Sprite2D",
	"res://HeartPickup.tscn": "Sprite2D",
	"res://Spear.tscn": "Sprite2D",
}

const REPORT_PATH := "res://tools/presentation_audit_report.txt"


func _initialize() -> void:
	var failures := 0
	var report_lines: Array[String] = []

	for texture_path in TEXTURE_PATHS:
		failures += _audit_texture(texture_path, report_lines)

	for audio_path in AUDIO_PATHS:
		failures += _audit_audio_stream(audio_path, report_lines)

	for scene_path in SCENE_SPRITES.keys():
		failures += _audit_scene_sprite(scene_path, SCENE_SPRITES[scene_path], report_lines)

	failures += _audit_main_scene_audio(report_lines)
	_write_report(report_lines)
	quit(failures)


func _audit_texture(path: String, report_lines: Array[String]) -> int:
	var resource := load(path)
	if not (resource is Texture2D):
		push_error("AUDIT: failed to load texture %s" % path)
		report_lines.append("FAILED texture %s" % path)
		return 1

	var texture := resource as Texture2D
	report_lines.append("texture=%s size=%s" % [path, texture.get_size()])
	return 0


func _audit_audio_stream(path: String, report_lines: Array[String]) -> int:
	var resource := load(path)
	if resource == null:
		push_error("AUDIT: failed to load audio stream %s" % path)
		report_lines.append("FAILED audio %s" % path)
		return 1

	report_lines.append("audio=%s class=%s" % [path, resource.get_class()])
	return 0


func _audit_scene_sprite(scene_path: String, sprite_path: String, report_lines: Array[String]) -> int:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("AUDIT: failed to load scene %s" % scene_path)
		report_lines.append("FAILED scene %s" % scene_path)
		return 1

	var instance := scene.instantiate()
	var sprite := instance.get_node_or_null(sprite_path) as Sprite2D
	if sprite == null:
		push_error("AUDIT: missing sprite node %s in %s" % [sprite_path, scene_path])
		report_lines.append("FAILED sprite node %s in %s" % [sprite_path, scene_path])
		instance.queue_free()
		return 1
	if sprite.texture == null:
		push_error("AUDIT: sprite node %s has no texture in %s" % [sprite_path, scene_path])
		report_lines.append("FAILED sprite texture %s in %s" % [sprite_path, scene_path])
		instance.queue_free()
		return 1

	if scene_path == "res://HeartRunner.tscn":
		if sprite.hframes != 4 or sprite.vframes != 3:
			push_error("AUDIT: HeartRunner sprite sheet is not configured for a 4x3 live animation layout")
			report_lines.append("FAILED HeartRunner sprite sheet layout")
			instance.queue_free()
			return 1

	report_lines.append(
		"scene=%s sprite=%s texture=%s hframes=%s vframes=%s" % [
			scene_path,
			sprite_path,
			sprite.texture.resource_path,
			sprite.hframes,
			sprite.vframes,
		]
	)
	instance.queue_free()
	return 0


func _audit_main_scene_audio(report_lines: Array[String]) -> int:
	var scene := load("res://Main.tscn") as PackedScene
	if scene == null:
		push_error("AUDIT: failed to load Main.tscn")
		report_lines.append("FAILED Main.tscn")
		return 1

	var main := scene.instantiate()
	root.add_child(main)

	var failures := 0
	for bus_name in ["Master", "Music", "SFX"]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index == -1:
			push_error("AUDIT: missing bus %s" % bus_name)
			report_lines.append("FAILED bus %s" % bus_name)
			failures += 1
			continue

		report_lines.append(
			"bus=%s mute=%s volume_db=%s" % [
				bus_name,
				AudioServer.is_bus_mute(bus_index),
				AudioServer.get_bus_volume_db(bus_index),
			]
		)

	for player_path in [
		"AudioPlayers/MusicPlayer",
		"AudioPlayers/ThrowPlayer",
		"AudioPlayers/EnemyHitPlayer",
		"AudioPlayers/EnemyDeathPlayer",
		"AudioPlayers/PickupPlayer",
		"AudioPlayers/PlayerHurtPlayer",
		"AudioPlayers/GameOverPlayer",
		"AudioPlayers/DodgePlayer",
		"AudioPlayers/WaveWarningPlayer",
		"AudioPlayers/ShieldBreakPlayer",
		"AudioPlayers/BlowgunWindupPlayer",
		"AudioPlayers/BlowgunFirePlayer",
		"AudioPlayers/BlowgunShovePlayer",
		"AudioPlayers/BoomerHopPrepPlayer",
		"AudioPlayers/BoomerLandPlayer",
		"AudioPlayers/BoomerFusePlayer",
		"AudioPlayers/BoomerExplosionPlayer",
		"AudioPlayers/HeartRunnerAppearPlayer",
		"AudioPlayers/HeartPickupSpawnPlayer",
		"AudioPlayers/HeartPickupCollectPlayer",
		"AudioPlayers/HeartPickupExpirePlayer",
	]:
		var player := main.get_node_or_null(player_path) as AudioStreamPlayer
		if player == null:
			push_error("AUDIT: missing player %s" % player_path)
			report_lines.append("FAILED player %s" % player_path)
			failures += 1
			continue
		if player.stream == null:
			push_error("AUDIT: player %s is missing a stream" % player_path)
			report_lines.append("FAILED missing stream %s" % player_path)
			failures += 1
			continue

		report_lines.append(
			"player=%s bus=%s stream=%s volume_db=%s" % [
				player_path,
				player.bus,
				player.stream.resource_path,
				player.volume_db,
			]
		)

	main.queue_free()
	return failures


func _write_report(report_lines: Array[String]) -> void:
	var report_path := ProjectSettings.globalize_path(REPORT_PATH)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		return

	for line in report_lines:
		file.store_line(line)
