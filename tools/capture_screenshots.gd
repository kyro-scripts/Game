extends Node
## Dev tool: boots the real main scene, drives it through representative
## moments and saves PNG screenshots. Needs a real renderer (not --headless):
##
##   godot --path . res://tools/capture_screenshots.tscn
##   SHOT_DIR=/some/dir godot --path . res://tools/capture_screenshots.tscn
##
## Default output: user://screenshots/

const MAIN := preload("res://scenes/main/main.tscn")
const WALKER := preload("res://scenes/enemies/dummy_walker.tscn")

var _dir: String
var _main: Main


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = MAIN.instantiate() as Main
	add_child(_main)
	await _frames(40)
	var p := _main.player

	await _shot("01_spawn_speed_hall")

	Input.action_press(&"move_forward")
	await _seconds(0.9)
	p.queue_jump()
	await _seconds(0.25)
	await _shot("02_running_jump")
	Input.action_release(&"move_forward")

	_teleport(Vector3(0.0, 0.05, -26.0), 0.0)
	await _seconds(0.3)
	await _shot("03_slide_gate_and_hurdle")

	_teleport(Vector3(0.0, 2.05, -60.0), 0.0)
	await _seconds(0.3)
	await _shot("04_downhill_ramp")

	_teleport(Vector3(0.0, 0.05, -95.0), 0.0)
	await _seconds(0.4)
	await _shot("05_door_gallery")

	_teleport(Vector3(0.0, 0.05, -163.0), 0.0)
	GameState.god_mode = true
	await _seconds(1.2)
	await _shot("06_arena")

	var w := WALKER.instantiate() as DummyWalker
	w.pursue = false
	_main.level.add_child(w)
	w.global_position = p.global_position + Vector3(0.0, -0.05, -2.6)
	w.rotation.y = 0.0
	await _seconds(0.8)
	p.set_look(0.0, deg_to_rad(4.0))
	await _seconds(0.3)
	await _shot("07_face_closeup")

	p.set_look(0.0, deg_to_rad(-12.0))
	p.weapon.trigger()
	await _frames(2)
	await _shot("08_firing")

	Input.action_press(&"borrow_time")
	await _seconds(0.6)
	await _shot("09_borrow_time")
	Input.action_release(&"borrow_time")
	await _seconds(0.5)
	await _shot("10_time_debt")

	RunManager.time_remaining = 8.0
	await _seconds(0.5)
	await _shot("11_low_time")

	RunManager.end_run(&"time")
	await _seconds(0.8)
	await _shot("12_run_end")

	print("SHOTS SAVED TO ", _dir)
	get_tree().quit()


func _teleport(pos: Vector3, yaw: float) -> void:
	_main.player.global_position = pos
	_main.player.velocity = Vector3.ZERO
	_main.player.set_look(yaw, 0.0)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("saved ", path)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
