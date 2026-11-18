extends Node
## Dev tool: boots the real main scene, drives it through representative
## moments and saves PNG screenshots. Needs a real renderer (not --headless):
##
##   godot --path . res://tools/capture_screenshots.tscn
##   SHOT_DIR=/some/dir godot --path . res://tools/capture_screenshots.tscn
##
## Default output: user://screenshots/
##
## Fast, short-lived effects are photographed in engine slow motion so they
## survive slow software renderers too.

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
	# Photo mode: no developer readouts or controls hint; no random events.
	GameState.show_speed = false
	GameState.show_fps = false
	GameState.god_mode = true
	for c in _main.get_children():
		if c is HUD:
			(c as HUD).hide_hint()
	_main.atmosphere.set_process(false)
	await _frames(40)
	var p := _main.player

	await _shot("01_vestibule")

	_teleport(Vector3(0.2, 0.05, -3.5), 0.0)
	Input.action_press(&"move_forward")
	await _seconds(0.45)
	p.queue_jump()
	Engine.time_scale = 0.15
	await _until(func() -> bool: return p.global_position.z < -9.2, 60)
	await _shot("02_narrowing_jump")
	Engine.time_scale = 1.0
	Input.action_release(&"move_forward")

	_teleport(Vector3(1.0, 0.05, -17.0), atan2(-2.6, 12.0))
	await _seconds(0.4)
	await _shot("03_narrowing_dark_stretch")

	_teleport(Vector3(1.0, 0.05, -38.5), 0.0)
	await _seconds(0.5)
	await _shot("04_long_hall")

	_teleport(Vector3(3.0, 0.05, -58.0), PI * 0.5 - 0.55)
	await _seconds(0.4)
	await _shot("05_repeating_doors")

	_teleport(Vector3(1.0, 0.05, -40.0), 0.0)
	Input.action_press(&"move_forward")
	await _seconds(0.6)
	Input.action_press(&"slide")
	Engine.time_scale = 0.1
	await _until(func() -> bool: return p.global_position.z < -49.5, 80)
	await _shot("06_slide_under_monolith")
	Engine.time_scale = 1.0
	Input.action_release(&"slide")
	Input.action_release(&"move_forward")

	_teleport(Vector3(-4.0, 2.05, -80.0), 0.0)
	_aim_at(Vector3(17.25, 23.0, -90.0))
	await _seconds(0.4)
	await _shot("07_red_window")

	_teleport(Vector3(1.0, 2.05, -88.0), atan2(8.0, 33.0))
	_main.atmosphere.guest.appear(Vector3(-7.0, 0.0, -121.0), p.global_position)
	await _seconds(0.5)
	await _shot("08_guest_in_red")
	_main.atmosphere.guest.vanish()

	_teleport(Vector3(-1.0, 0.05, -135.5), 0.15)
	await _seconds(0.4)
	await _shot("09_low_chamber")

	_teleport(Vector3(0.0, 0.05, -147.0), 0.0)
	await _seconds(0.4)
	await _shot("10_repeating_corridor_door")

	var door := _main.level.get_node_or_null(^"Blockout/Generated/Door0") as BreachableDoor
	_teleport(Vector3(0.0, 0.05, -141.0), 0.0)
	Input.action_press(&"move_forward")
	Engine.time_scale = 0.25
	if door != null:
		await _until(func() -> bool: return door.breached, 120)
	Engine.time_scale = 0.05
	await _frames(3)
	await _shot("11_door_breach")
	Engine.time_scale = 1.0
	Input.action_release(&"move_forward")

	_teleport(Vector3(0.0, 0.05, -153.0), 0.0)
	await _seconds(0.4)
	await _shot("12_repeating_bays")

	_teleport(Vector3(0.0, 0.05, -209.0), 0.0)
	await _seconds(1.0)
	await _shot("13_clock_chamber")

	var w := WALKER.instantiate() as DummyWalker
	w.pursue = false
	_main.level.add_child(w)
	w.global_position = p.global_position + Vector3(0.0, -0.05, -1.7)
	w.rotation.y = PI
	await _seconds(0.9)
	var head := w.get_node(^"Visual/Head") as Node3D
	_aim_at(head.global_position)
	await _seconds(0.4)
	await _shot("14_face_closeup")
	var fov_was := GameState.base_fov
	GameState.base_fov = 16.0
	await _seconds(0.6)
	await _shot("14b_face_macro")
	GameState.base_fov = fov_was
	await _seconds(0.3)

	_aim_at(w.global_position + Vector3.UP * 1.0)
	Engine.time_scale = 0.02
	p.weapon.fire()
	await _frames(2)
	await _shot("15_firing")
	Engine.time_scale = 1.0
	p.weapon.fire()
	await _frames(1)
	p.weapon.fire()
	Engine.time_scale = 0.08
	await _frames(3)
	await _shot("16_kill")
	Engine.time_scale = 1.0

	var attacker := WALKER.instantiate() as DummyWalker
	_main.level.add_child(attacker)
	attacker.global_position = p.global_position + Vector3(0.6, -0.05, -3.2)
	attacker.rotation.y = PI
	_aim_at(attacker.global_position + Vector3.UP * 1.9)
	await _until(func() -> bool: return attacker.state == EnemyBase.State.ATTACK and attacker.state_time > 0.3, 400)
	Engine.time_scale = 0.05
	_aim_at(attacker.global_position + Vector3.UP * 1.9)
	await _frames(3)
	await _shot("17_attack_windup_red_eyes")
	Engine.time_scale = 1.0
	attacker.queue_free()

	p.set_look(p.rotation.y, 0.0)
	Input.action_press(&"borrow_time")
	await _seconds(0.7)
	await _shot("18_borrow_time_watch_raised")
	Input.action_release(&"borrow_time")
	await _seconds(0.5)
	await _shot("19_time_debt")

	RunManager.time_remaining = 8.0
	await _seconds(0.5)
	await _shot("20_low_time")

	_main._menu.toggle()
	await _frames(3)
	await _shot("21_debug_menu")
	_main._menu.toggle()

	RunManager.end_run(&"time")
	await _seconds(0.8)
	await _shot("22_run_end")

	Engine.time_scale = 1.0
	print("SHOTS SAVED TO ", _dir)
	get_tree().quit()


func _teleport(pos: Vector3, yaw: float, pitch: float = 0.0) -> void:
	_main.player.global_position = pos
	_main.player.velocity = Vector3.ZERO
	_main.player.set_look(yaw, pitch)


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
