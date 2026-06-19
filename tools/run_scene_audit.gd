extends SceneTree


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		push_error("run_scene_audit.gd requires a scene path argument.")
		quit(1)
		return

	var scene_path := String(user_args[0])
	var scene_resource := load(scene_path) as PackedScene
	if scene_resource == null:
		push_error("Failed to load audit scene: %s" % scene_path)
		quit(1)
		return

	var scene_instance := scene_resource.instantiate()
	if scene_instance == null:
		push_error("Failed to instantiate audit scene: %s" % scene_path)
		quit(1)
		return

	root.add_child(scene_instance)
	current_scene = scene_instance
