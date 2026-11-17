class_name DebugMenu
extends CanvasLayer
## F1 developer menu. Pauses the game while open.
##
## Sections:
##  * Flags: god mode, infinite timer, FPS / speed readouts, Borrow toggle mode.
##  * Actions: anything registered through GameState.register_debug_action()
##    (scenes add their own: spawn dummies, restart, force debt, ...).
##  * Settings: mouse sensitivity and FOV.
##  * Live tuning: sliders generated from every ranged float / bool exported
##    by MovementTuning and BorrowTimeData. Changes apply instantly.
##    "Save tuning" writes them back to their .tres files (editor runs only).

var _player: Player
var _panel: PanelContainer
var _actions_box: VBoxContainer
var _was_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_was_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_rebuild_actions()
		get_tree().paused = true
	else:
		get_tree().paused = false
		Input.mouse_mode = _was_mouse_mode


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.035, 0.94)
	style.border_color = Palette.RED
	style.border_width_right = 2
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 4)
	scroll.add_child(box)

	box.add_child(_header("DEBUG  (F1 / Esc to close)"))
	box.add_child(_check("God mode", GameState.god_mode, func(v: bool) -> void: GameState.set_flag(&"god_mode", v)))
	box.add_child(_check("Infinite timer", GameState.infinite_timer, func(v: bool) -> void: GameState.set_flag(&"infinite_timer", v)))
	box.add_child(_check("Show FPS", GameState.show_fps, func(v: bool) -> void: GameState.set_flag(&"show_fps", v)))
	box.add_child(_check("Show speed / info (F3)", GameState.show_speed, func(v: bool) -> void: GameState.set_flag(&"show_speed", v)))
	box.add_child(_check("Borrow Time: toggle instead of hold", GameState.borrow_time_toggle_mode,
			func(v: bool) -> void: GameState.borrow_time_toggle_mode = v))
	box.add_child(_check("Engine slow-mo x0.25 (inspect frames)", false,
			func(v: bool) -> void: Engine.time_scale = 0.25 if v else 1.0))

	box.add_child(_header("ACTIONS"))
	_actions_box = VBoxContainer.new()
	box.add_child(_actions_box)

	box.add_child(_header("SETTINGS"))
	box.add_child(_slider("Mouse sensitivity", GameState.mouse_sensitivity, 0.0003, 0.008, 0.0001,
			func(v: float) -> void: GameState.mouse_sensitivity = v))
	box.add_child(_slider("Base FOV", GameState.base_fov, 70.0, 120.0, 1.0,
			func(v: float) -> void: GameState.base_fov = v))

	if _player != null:
		box.add_child(_header("LIVE TUNING: MOVEMENT"))
		_add_resource_controls(box, _player.tuning)
		box.add_child(_header("LIVE TUNING: BORROW TIME"))
		_add_resource_controls(box, _player.stopwatch.borrow)
		var save := Button.new()
		save.text = "Save tuning to .tres files"
		save.pressed.connect(_save_tuning)
		box.add_child(save)


func _rebuild_actions() -> void:
	for c in _actions_box.get_children():
		c.queue_free()
	var current_section := ""
	for entry in GameState.get_debug_actions():
		var section: String = entry["section"]
		if section != current_section:
			current_section = section
			var l := Label.new()
			l.text = section
			l.add_theme_color_override(&"font_color", Color(0.6, 0.58, 0.55))
			_actions_box.add_child(l)
		var b := Button.new()
		b.text = entry["label"]
		var action: Callable = entry["callable"]
		b.pressed.connect(func() -> void:
			toggle()
			action.call()
		)
		_actions_box.add_child(b)


func _add_resource_controls(box: VBoxContainer, res: Resource) -> void:
	if res == null:
		return
	for prop in res.get_property_list():
		var usage: int = prop["usage"]
		var pname: String = prop["name"]
		if usage & PROPERTY_USAGE_GROUP:
			var g := Label.new()
			g.text = "· " + pname
			g.add_theme_color_override(&"font_color", Color(0.55, 0.53, 0.5))
			box.add_child(g)
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var ptype: int = prop["type"]
		if ptype == TYPE_BOOL:
			box.add_child(_check(pname, bool(res.get(pname)), func(v: bool) -> void: res.set(pname, v)))
		elif ptype == TYPE_FLOAT and int(prop["hint"]) == PROPERTY_HINT_RANGE:
			var parts := String(prop["hint_string"]).split(",")
			if parts.size() < 2:
				continue
			var lo := parts[0].to_float()
			var hi := parts[1].to_float()
			var step := parts[2].to_float() if parts.size() > 2 and parts[2].is_valid_float() else 0.01
			box.add_child(_slider(pname, float(res.get(pname)), lo, hi, step, func(v: float) -> void: res.set(pname, v)))


func _save_tuning() -> void:
	if _player == null:
		return
	for res: Resource in [_player.tuning, _player.stopwatch.borrow]:
		if res.resource_path.begins_with("res://"):
			var err := ResourceSaver.save(res)
			print("Saved %s: %s" % [res.resource_path, error_string(err)])


# --- Widget helpers ------------------------------------------------------------------

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", Palette.RED_HOT)
	l.add_theme_font_size_override(&"font_size", 15)
	return l


func _check(text: String, value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(on_change)
	return c


func _slider(text: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size = Vector2(190, 0)
	name_label.clip_text = true
	name_label.add_theme_font_size_override(&"font_size", 12)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(140, 0)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.add_theme_font_size_override(&"font_size", 12)
	value_label.text = _fmt(value, step)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = _fmt(v, step)
		on_change.call(v)
	)
	return row


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(v)
	if step >= 0.1:
		return "%.1f" % v
	if step >= 0.01:
		return "%.2f" % v
	return "%.4f" % v
