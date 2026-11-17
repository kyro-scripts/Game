extends Node
## Headless test runner for gameplay systems.
##
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
##
## Each suite gets a fresh flat arena + player per test. Tests drive the game
## through the same inputs a player would (Input actions, queue_jump,
## trigger) and assert on physical outcomes (speeds, timers, states).
## Exit code 0 = all checks passed.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SUITES: Array[Script] = [
	preload("res://tests/test_time_director.gd"),
	preload("res://tests/test_movement.gd"),
	preload("res://tests/test_combat_time.gd"),
]

var checks: int = 0
var failures: int = 0
var arena: Node3D
var player: Player

var _test_name: String = ""
var _failed_tests: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame
	var only := OS.get_environment("TEST_FILTER")
	for script in SUITES:
		var suite: Object = script.new()
		for m in script.get_script_method_list():
			var method_name: String = m["name"]
			if not method_name.begins_with("test_"):
				continue
			if only != "" and not method_name.contains(only):
				continue
			await _run_one(suite, method_name)
	print("")
	print("==== %d checks, %d failures ====" % [checks, failures])
	for f in _failed_tests:
		print("  FAILED: ", f)
	get_tree().quit(1 if failures > 0 else 0)


func _run_one(suite: Object, method_name: String) -> void:
	_test_name = "%s.%s" % [(suite.get_script() as Script).resource_path.get_file().get_basename(), method_name]
	print("-- ", _test_name)
	await _setup_world()
	var before := failures
	await suite.call(method_name, self)
	if failures > before:
		_failed_tests.append(_test_name)
	await _teardown_world()


# --- World ---------------------------------------------------------------------------

func _setup_world() -> void:
	_release_all_actions()
	GameState.god_mode = false
	GameState.infinite_timer = false
	GameState.borrow_time_toggle_mode = false
	TimeDirector.reset()
	RunManager.start_run()
	arena = Node3D.new()
	arena.name = "Arena"
	add_child(arena)
	add_static_box(Vector3(0.0, -0.5, 0.0), Vector3(600.0, 1.0, 600.0))
	player = PLAYER_SCENE.instantiate() as Player
	arena.add_child(player)
	player.global_position = Vector3(0.0, 0.02, 0.0)
	player.set_look(0.0, 0.0)
	await physics(4)


func _teardown_world() -> void:
	_release_all_actions()
	RunManager.reset()
	if arena != null:
		arena.queue_free()
		arena = null
	player = null
	TimeDirector.reset()
	await get_tree().process_frame
	await get_tree().process_frame


func _release_all_actions() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"slide", &"fire", &"borrow_time"]:
		Input.action_release(a)


## Static collision box (world layer). Returns the body.
func add_static_box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	arena.add_child(body)
	body.global_position = center
	return body


func add_scene(scene: PackedScene, at: Vector3, yaw: float = 0.0) -> Node3D:
	var n := scene.instantiate() as Node3D
	arena.add_child(n)
	n.global_position = at
	n.rotation.y = yaw
	return n


# --- Stepping ------------------------------------------------------------------------

func physics(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await physics(int(ceil(s * Engine.physics_ticks_per_second)))


## Step until `condition` returns true or `timeout_s` elapses. Returns success.
func until(condition: Callable, timeout_s: float) -> bool:
	var ticks := int(ceil(timeout_s * Engine.physics_ticks_per_second))
	for i in ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return bool(condition.call())


# --- Assertions ----------------------------------------------------------------------

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("   ok   ", message)
	else:
		failures += 1
		print("   FAIL ", message)


func check_near(value: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(value - expected) <= tolerance, "%s (got %.3f, want %.3f ± %.3f)" % [message, value, expected, tolerance])


func check_ge(value: float, minimum: float, message: String) -> void:
	check(value >= minimum, "%s (got %.3f, want >= %.3f)" % [message, value, minimum])


func check_le(value: float, maximum: float, message: String) -> void:
	check(value <= maximum, "%s (got %.3f, want <= %.3f)" % [message, value, maximum])
