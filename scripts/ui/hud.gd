class_name HUD
extends CanvasLayer
## Minimal HUD. The stopwatch in the left hand is the primary timer display;
## this layer only adds what cannot live in the world: crosshair + hit
## markers, a thin health line, the debt warning and a fading controls hint.

const HINT := "WASD move   SPACE jump   CTRL / SHIFT slide   LMB fire   RMB / E borrow time   F1 debug   F3 info   F5 restart"

var _player: Player
var _crosshair: Crosshair
var _health_bar: ColorRect
var _health_back: ColorRect
var _health_label: Label
var _debt_label: Label
var _hint: Label
var _hint_timer: float = 14.0


## Crosshair drawn in code: a dot and four short ticks. Hits flash red ticks,
## kills draw a small X.
class Crosshair extends Control:
	var hit_flash: float = 0.0
	var kill_flash: float = 0.0

	func _process(delta: float) -> void:
		hit_flash = maxf(hit_flash - delta * 6.0, 0.0)
		kill_flash = maxf(kill_flash - delta * 3.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var white := Color(0.93, 0.91, 0.86, 0.9)
		draw_circle(c, 1.6, white)
		var gap := 7.0
		var tick_len := 5.0
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * gap, c + d * (gap + tick_len), Color(white, 0.55), 1.5)
		if hit_flash > 0.0:
			var red := Color(0.95, 0.08, 0.05, hit_flash)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var n := (d as Vector2).normalized()
				draw_line(c + n * 9.0, c + n * 15.0, red, 2.0)
		if kill_flash > 0.0:
			var k := Color(0.95, 0.08, 0.05, kill_flash)
			var s := 18.0 + (1.0 - kill_flash) * 8.0
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), k, 2.5)
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), k, 2.5)


func setup(player: Player) -> void:
	_player = player
	_player.weapon.hit_confirmed.connect(_on_hit_confirmed)


func _ready() -> void:
	layer = 3
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.size = Vector2(64, 64)
	_crosshair.position = -_crosshair.size * 0.5
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	# Health: a thin line at the bottom centre.
	_health_back = ColorRect.new()
	_health_back.color = Color(0.1, 0.1, 0.1, 0.7)
	_health_back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_health_back.size = Vector2(260, 3)
	_health_back.position = Vector2(-130, -34)
	_health_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_health_back)
	_health_bar = ColorRect.new()
	_health_bar.color = Palette.PAPER
	_health_bar.size = Vector2(260, 3)
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_back.add_child(_health_bar)
	_health_label = _label(14, Color(Palette.PAPER, 0.7))
	_health_label.position = Vector2(0, -22)
	_health_back.add_child(_health_label)

	_debt_label = _label(18, Palette.RED_HOT)
	_debt_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_debt_label.position = Vector2(40, -64)
	root.add_child(_debt_label)

	_hint = _label(14, Color(Palette.PAPER, 0.6))
	_hint.text = HINT
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(1200, 24)
	_hint.position = Vector2(-600, 20)
	root.add_child(_hint)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var frac := clampf(_player.health / maxf(_player.max_health, 1.0), 0.0, 1.0)
	_health_bar.size.x = 260.0 * frac
	_health_bar.color = Palette.RED_HOT if frac < 0.35 else Palette.PAPER
	_health_label.text = "%d" % ceili(_player.health)

	var sw := _player.stopwatch
	if sw.debt_remaining > 0.0 and not sw.active:
		_debt_label.text = "TIME DEBT  %.1fs   x%.2f" % [sw.debt_remaining, sw.borrow.debt_drain_multiplier]
		_debt_label.visible = true
	else:
		_debt_label.visible = false

	_hint_timer -= delta
	_hint.modulate.a = clampf(_hint_timer / 3.0, 0.0, 1.0)


func _on_hit_confirmed(killed: bool, _headshot: bool) -> void:
	_crosshair.hit_flash = 1.0
	if killed:
		_crosshair.kill_flash = 1.0


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
