class_name RunEndScreen
extends CanvasLayer
## Shown when the run ends (clock stopped or body failed). Ranking arrives in
## Phase G; for now it shows the raw numbers RunManager collected.

signal restart_requested

var _panel: Control
var _title: Label
var _body: Label
var _shown_at: float = 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	(_panel as ColorRect).color = Color(0.0, 0.0, 0.0, 0.82)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(640, 0)
	box.position = Vector2(-320, -180)
	box.add_theme_constant_override(&"separation", 18)
	_panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 54)
	_title.add_theme_color_override(&"font_color", Palette.RED_HOT)
	box.add_child(_title)
	_body = Label.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override(&"font_size", 18)
	_body.add_theme_color_override(&"font_color", Palette.PAPER)
	box.add_child(_body)
	var hint := Label.new()
	hint.text = "R or click to try again"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", 14)
	hint.add_theme_color_override(&"font_color", Color(0.6, 0.58, 0.55))
	box.add_child(hint)
	_panel.visible = false
	Events.run_ended.connect(_on_run_ended)


func _on_run_ended(result: Dictionary) -> void:
	var reason: StringName = result.get("reason", &"")
	match reason:
		&"time":
			_title.text = "THE CLOCK STOPPED"
		&"wounds":
			_title.text = "YOU WERE CAUGHT"
		_:
			_title.text = "THE MASQUE ENDS"
	_body.text = "\n".join(PackedStringArray([
		"survived  %.1f s" % float(result.get("elapsed", 0.0)),
		"kills  %d   (headshots %d)" % [int(result.get("kills", 0)), int(result.get("headshot_kills", 0))],
		"time stolen back  %.1f s" % float(result.get("time_gained", 0.0)),
		"doors breached  %d" % int(result.get("doors_breached", 0)),
		"top speed  %.1f m/s   average %.1f m/s" % [float(result.get("top_speed", 0.0)), float(result.get("average_speed", 0.0))],
		"borrowed  %d times, %.1f s" % [int(result.get("borrow_uses", 0)), float(result.get("borrow_seconds", 0.0))],
		"damage taken  %d" % int(result.get("damage_taken", 0.0)),
		"",
		"rank: (Phase G)",
	]))
	_panel.visible = true
	_shown_at = TimeDirector.real_time
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	# Short lockout so a held fire button doesn't skip the screen instantly.
	if TimeDirector.real_time - _shown_at < 0.6:
		return
	var wants := false
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
		wants = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		wants = true
	if wants:
		get_viewport().set_input_as_handled()
		restart_requested.emit()

