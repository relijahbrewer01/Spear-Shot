extends SceneTree

const SELF_PATH := "res://tools/check_project_scripts.gd"


func _initialize() -> void:
	var script_paths := _find_script_paths("res://")
	var failures: Array[String] = []

	for script_path in script_paths:
		print("CHECK ", script_path)
		var script_resource := ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Script
		if script_resource == null:
			failures.append(script_path)
			continue
		if script_path == SELF_PATH:
			continue

		var reload_result := script_resource.reload()
		if reload_result != OK:
			failures.append(script_path)

	if failures.is_empty():
		print("All project scripts loaded successfully.")
		quit(0)
		return

	for failed_path in failures:
		push_error("Failed to load script: %s" % failed_path)
	quit(1)


func _find_script_paths(root_path: String) -> Array[String]:
	var collected_paths: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		push_error("Could not open directory: %s" % root_path)
		return collected_paths

	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue

		var entry_path := root_path.path_join(entry_name)
		if directory.current_is_dir():
			collected_paths.append_array(_find_script_paths(entry_path))
		elif entry_name.get_extension() == "gd":
			collected_paths.append(entry_path)
	directory.list_dir_end()

	collected_paths.sort()
	return collected_paths
