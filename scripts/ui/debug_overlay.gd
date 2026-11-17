class_name DebugOverlay
extends CanvasLayer
## Top-left developer readout (F3 toggles). Horizontal speed is the headline
## number while movement is being tuned.

var _player: Player
var _label: Label
var _speed_label: Label
var _peak_speed: float = 0.0
var _peak_timer: float = 0.0


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_speed_label = Label.new()
	_speed_label.position = Vector2(16, 10)
	_speed_label.add_theme_font_size_override(&"font_size", 30)
	_speed_label.add_theme_color_override(&"font_color", Palette.PAPER)
	_speed_label.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speed_label)
	_label = Label.new()
	_label.position = Vector2(16, 50)
	_label.add_theme_font_size_override(&"font_size", 13)
	_label.add_theme_color_override(&"font_color", Color(0.75, 0.73, 0.7))
	_label.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_info"):
		GameState.set_flag(&"show_speed", not GameState.show_speed)


func _process(delta: float) -> void:
	_speed_label.visible = GameState.show_speed
	_label.visible = GameState.show_speed or GameState.show_fps
	if _player == null or not is_instance_valid(_player):
		_label.text = ""
		return
	var speed := _player.get_horizontal_speed()
	_peak_timer -= delta
	if speed > _peak_speed or _peak_timer <= 0.0:
		_peak_speed = speed
		_peak_timer = 1.5
	_speed_label.text = "%5.1f m/s   peak %4.1f" % [speed, _peak_speed]

	var lines: PackedStringArray = []
	if GameState.show_fps:
		lines.append("FPS %d" % Engine.get_frames_per_second())
	if GameState.show_speed:
		var sw := _player.stopwatch
		lines.append("state %s%s   grace %.2f   vy %+.1f" % [
			_player.get_state_name(), " (crouch)" if _player.is_crouched() else "",
			_player.get_landing_grace(), _player.velocity.y])
		lines.append("timer %.2f   hp %d   seed %d" % [RunManager.time_remaining, int(_player.health), RunManager.run_seed])
		lines.append("borrow %3d%%%s   debt %.1fs" % [int(sw.charge * 100.0), "  ACTIVE" if sw.active else "", sw.debt_remaining])
		lines.append(TimeDirector.describe())
		var flags: PackedStringArray = []
		if GameState.god_mode:
			flags.append("GOD")
		if GameState.infinite_timer:
			flags.append("INF-TIMER")
		if not is_equal_approx(Engine.time_scale, 1.0):
			flags.append("ENGINE x%.2f" % Engine.time_scale)
		if flags.size() > 0:
			lines.append(" ".join(flags))
	_label.text = "\n".join(lines)
