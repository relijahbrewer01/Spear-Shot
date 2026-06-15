extends SceneTree

const FRAMES_TO_RUN := 180
const CLEANUP_FRAMES_TO_WAIT := 10

var frame_count := 0
var main_instance: Node
var cleanup_started := false
var cleanup_frame_count := 0
var main_scene_resource: PackedScene


func _initialize() -> void:
	main_scene_resource = load("res://Main.tscn") as PackedScene
	if main_scene_resource == null:
		push_error("Failed to load res://Main.tscn")
		quit(1)
		return

	main_instance = main_scene_resource.instantiate()
	root.add_child(main_instance)
	current_scene = main_instance


func _process(_delta: float) -> bool:
	if cleanup_started:
		cleanup_frame_count += 1
		if cleanup_frame_count >= CLEANUP_FRAMES_TO_WAIT:
			quit(0)
			return true
		return false

	frame_count += 1
	if frame_count < FRAMES_TO_RUN:
		return false

	_stop_audio_players()
	_free_main_scene()
	main_scene_resource = null
	cleanup_started = true
	cleanup_frame_count = 0
	return false


func _stop_audio_players() -> void:
	if main_instance == null:
		return

	var audio_root := main_instance.get_node_or_null("AudioPlayers")
	if audio_root == null:
		return

	for child in audio_root.get_children():
		var audio_player := child as AudioStreamPlayer
		if audio_player == null:
			continue
		audio_player.stop()
		audio_player.stream = null


func _free_main_scene() -> void:
	if main_instance == null:
		return

	if main_instance.get_parent() != null:
		main_instance.get_parent().remove_child(main_instance)
	main_instance.free()
	main_instance = null
	current_scene = null
