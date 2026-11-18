extends Node
## Dev tool: boots the real main scene, drives it through representative
## moments and saves PNG screenshots. Needs a real renderer (not --headless):
##
##   godot --path . res://tools/capture_screenshots.tscn
##   SHOT_DIR=/some/dir godot --path . res://tools/capture_screenshots.tscn
##
## Default output: user://screenshots/
##
## Fast, short-lived effects (muzzle flash, splinters) are photographed in
## engine slow motion, so they survive slow software renderers too.

const MAIN := preload("res://scenes/main/main.tscn")
const WALKER := preload("res://scenes/enemies/dummy_walker.tscn")

var _dir: String
var _main: Main


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = MAIN.instantiate() as Main
	add_child(_main)
	await _frames(40)
	var p := _main.player

	await _shot("01_spawn_speed_hall")

	# Running jump down the hall.
	Input.action_press(&"move_forward")
	await _seconds(0.9)
	p.queue_jump()
	await _seconds(0.25)
	await _shot("02_running_jump")
	Input.action_release(&"move_forward")

	# Slide under the low gate (left half of the hall at z = -30).
	_teleport(Vector3(-4.0, 0.05, -14.0), 0.0)
	Input.action_press(&"move_forward")
	await _seconds(0.8)
	Input.action_press(&"slide")
	Engine.time_scale = 0.1
	await _until(func() -> bool: return p.global_position.z < -27.0, 60)
	await _shot("03_slide_under_gate")
	Engine.time_scale = 1.0
	Input.action_release(&"slide")
	Input.action_release(&"move_forward")

	_teleport(Vector3(0.0, 2.05, -60.0), 0.0)
	await _seconds(0.3)
	await _shot("04_downhill_ramp")

	_teleport(Vector3(0.0, 0.05, -95.0), 0.0)
	await _seconds(0.4)
	await _shot("05_door_gallery")

	# Burst through the first door and freeze on the splinters.
	var door := _main.level.get_node_or_null(^"Blockout/Generated/Door0") as BreachableDoor
	_teleport(Vector3(0.0, 0.05, -90.0), 0.0)
	Input.action_press(&"move_forward")
	Engine.time_scale = 0.25
	if door != null:
		await _until(func() -> bool: return door.breached, 80)
	Engine.time_scale = 0.05
	await _frames(3)
	await _shot("06_door_breach")
	Engine.time_scale = 1.0
	Input.action_release(&"move_forward")

	_teleport(Vector3(0.0, 0.05, -163.0), 0.0)
	GameState.god_mode = true
	await _seconds(1.2)
	await _shot("07_arena")

	var w := WALKER.instantiate() as DummyWalker
	w.pursue = false
	_main.level.add_child(w)
	w.global_position = p.global_position + Vector3(0.0, -0.05, -1.9)
	w.rotation.y = PI
	await _seconds(0.8)
	p.set_look(0.0, deg_to_rad(2.0))
	await _seconds(0.3)
	await _shot("08_face_closeup")

	# Muzzle flash + tracer, photographed in slow motion.
	_aim_at(w.global_position + Vector3.UP * 0.9)
	Engine.time_scale = 0.02
	p.weapon.fire()
	await _frames(2)
	await _shot("09_firing")

	# Finish it: the body folds into ash, the mask drops, the clock gains time.
	Engine.time_scale = 1.0
	p.weapon.fire()
	await _frames(1)
	p.weapon.fire()
	Engine.time_scale = 0.08
	await _frames(3)
	await _shot("10_kill")
	Engine.time_scale = 1.0
	p.set_look(0.0, 0.0)

	Input.action_press(&"borrow_time")
	await _seconds(0.6)
	await _shot("11_borrow_time")
	Input.action_release(&"borrow_time")
	await _seconds(0.5)
	await _shot("12_time_debt")

	RunManager.time_remaining = 8.0
	await _seconds(0.5)
	await _shot("13_low_time")

	_main._menu.toggle()
	await _frames(3)
	await _shot("14_debug_menu")
	_main._menu.toggle()

	RunManager.end_run(&"time")
	await _seconds(0.8)
	await _shot("15_run_end")

	Engine.time_scale = 1.0
	print("SHOTS SAVED TO ", _dir)
	get_tree().quit()


func _teleport(pos: Vector3, yaw: float) -> void:
	_main.player.global_position = pos
	_main.player.velocity = Vector3.ZERO
	_main.player.set_look(yaw, 0.0)


func _aim_at(point: Vector3) -> void:
	var d := point - _main.player.get_eye_position()
	_main.player.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("saved ", path)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Wait (in rendered frames) until a condition holds, with a frame cap.
func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
