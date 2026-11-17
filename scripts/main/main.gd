class_name Main
extends Node3D
## Entry point. Builds a run: level + player + UI layers, starts the clock.
##
## Phase A/B: the level is the graybox movement/combat sandbox. From Phase C
## the CastleGenerator will produce the level here instead.

@export var level_scene: PackedScene = preload("res://scenes/sandbox/movement_sandbox.tscn")
@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var run_rules: RunRulesData

const WALKER_SCENE := preload("res://scenes/enemies/dummy_walker.tscn")
const TURRET_SCENE := preload("res://scenes/enemies/dummy_turret.tscn")

var player: Player
var level: Node3D

var _menu: DebugMenu
var _pause_layer: CanvasLayer
var _paused: bool = false
var _ambience: Node


func _ready() -> void:
	# Main keeps listening while the tree is paused; gameplay children don't.
	process_mode = Node.PROCESS_MODE_ALWAYS
	TimeDirector.reset()
	Engine.time_scale = 1.0

	level = level_scene.instantiate() as Node3D
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)

	player = player_scene.instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	var spawn := level.get_node_or_null(^"PlayerSpawn") as Node3D
	if spawn != null:
		player.global_position = spawn.global_position
		player.set_look(spawn.global_rotation.y)

	var post := PostProcess.new()
	post.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(post)
	var hud := HUD.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.setup(player)
	var overlay := DebugOverlay.new()
	overlay.setup(player)
	add_child(overlay)
	_menu = DebugMenu.new()
	_menu.setup(player)
	add_child(_menu)
	var end_screen := RunEndScreen.new()
	add_child(end_screen)
	end_screen.restart_requested.connect(restart)
	_build_pause_layer()
	_register_debug_actions()

	Events.run_ended.connect(_on_run_ended)
	RunManager.start_run(run_rules)
	_ambience = AudioDirector.play_loop(&"room_tone", null, -10.0, AudioDirector.BUS_AMBIENCE)
	_capture_mouse()


func _exit_tree() -> void:
	if _ambience != null and is_instance_valid(_ambience):
		_ambience.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and RunManager.active and not _paused and not _menu_open():
		set_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart_run"):
		restart()
		get_viewport().set_input_as_handled()
		return
	if _menu_open() or not RunManager.active:
		return
	if event.is_action_pressed(&"pause"):
		set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if _paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# The click that grabs the mouse must not also fire the weapon.
			set_paused(false)
			get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	_pause_layer.visible = value
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture_mouse()


func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	RunManager.reset()
	get_tree().reload_current_scene()


func _on_run_ended(_result: Dictionary) -> void:
	player.input_enabled = false
	# The castle nearly stops: a held tableau behind the results.
	TimeDirector.set_modifier(&"run_over", {TimeDirector.Channel.WORLD: 0.08})


func _menu_open() -> bool:
	return _menu != null and _menu.is_open()


func _capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_pause_layer() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 30
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(shade)
	var label := Label.new()
	label.text = "PAUSED\n\nclick to resume   ·   F1 debug   ·   F5 restart"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.size = Vector2(600, 100)
	label.position = Vector2(-300, -50)
	label.add_theme_color_override(&"font_color", Palette.PAPER)
	label.add_theme_font_size_override(&"font_size", 20)
	_pause_layer.add_child(label)
	_pause_layer.visible = false
	add_child(_pause_layer)


func _register_debug_actions() -> void:
	GameState.register_debug_action("Run", "Restart run (F5)", restart)
	GameState.register_debug_action("Run", "Add 10 s to the clock", func() -> void: RunManager.grant_time(10.0, &"debug"))
	GameState.register_debug_action("Run", "End run now", func() -> void: RunManager.end_run(&"debug"))
	GameState.register_debug_action("Stopwatch", "Refill Borrow Time", func() -> void: player.stopwatch.refill())
	GameState.register_debug_action("Stopwatch", "Force 4 s Time Debt", func() -> void: player.stopwatch.force_debt(4.0))
	GameState.register_debug_action("Spawn", "Walker dummy (pursues)", func() -> void: _spawn_in_front(WALKER_SCENE, true))
	GameState.register_debug_action("Spawn", "Walker dummy (static target)", func() -> void: _spawn_in_front(WALKER_SCENE, false))
	GameState.register_debug_action("Spawn", "Lantern turret dummy", func() -> void: _spawn_in_front(TURRET_SCENE, true))
	GameState.register_debug_action("Events", "Trigger clock chime", func() -> void:
		AudioDirector.play(&"chime", null, -2.0, 1.0, AudioDirector.BUS_WORLD, 0.0)
		Events.clock_chimed.emit()
	)
	var teleports := level.get_node_or_null(^"Teleports")
	if teleports != null:
		for marker in teleports.get_children():
			if marker is Node3D:
				var m := marker as Node3D
				GameState.register_debug_action("Teleport", String(m.name), func() -> void: _teleport(m))


func _spawn_in_front(scene: PackedScene, pursue: bool) -> void:
	var e := scene.instantiate() as EnemyBase
	if e is DummyWalker:
		(e as DummyWalker).pursue = pursue
	level.add_child(e)
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	e.global_position = player.global_position + fwd.normalized() * 8.0
	e.look_at(player.global_position, Vector3.UP)
	e.rotation.x = 0.0
	e.rotation.z = 0.0


func _teleport(marker: Node3D) -> void:
	player.global_position = marker.global_position
	player.velocity = Vector3.ZERO
	player.set_look(marker.global_rotation.y)
