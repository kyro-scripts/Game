extends SceneTree
## Headless project validator: loads every script, scene and resource and
## reports anything that fails to parse or load.
##
##   godot --headless --path . --script res://tools/validate_project.gd
##
## Exit code 0 = everything loaded.

const ROOTS := ["res://autoload", "res://scripts", "res://scenes", "res://data", "res://shaders", "res://tests", "res://tools"]
const EXTENSIONS := ["gd", "tscn", "tres", "gdshader"]


func _initialize() -> void:
	var files: Array[String] = []
	for root in ROOTS:
		_collect(root, files)
	var failures := 0
	for path in files:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		var ok := res != null
		if ok and res is GDScript:
			ok = (res as GDScript).can_instantiate() or (res as GDScript).is_abstract()
			if not ok:
				ok = (res as GDScript).reload() == OK
		if not ok:
			failures += 1
			printerr("VALIDATE FAIL: ", path)
	print("VALIDATE: %d files checked, %d failures" % [files.size(), failures])
	quit(1 if failures > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := dir_path.path_join(name)
			if dir.current_is_dir():
				_collect(full, out)
			elif name.get_extension() in EXTENSIONS:
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
