class_name StopwatchViewmodel
extends Node3D
## The analog stopwatch held in the player's off hand. It IS the run-timer
## interface: the red hand unwinds toward twelve as time runs out, the subdial
## shows minutes, and the bezel pips show Borrow Time charge.
##
##  * Borrow Time: face inverts (white -> black), the hand trembles, the thumb
##    presses the crown.
##  * Time Debt: the hand sweeps nervously and the readout burns red.
##  * Low time: louder ticks, the watch jolts each second.
##
## Placeholder geometry is built in code when the "Model" node is empty; real
## art can replace it as long as it exposes the same anchor names (see
## _bind_parts) or simply overrides this script.

const PIP_COUNT := 12

var _player: Player
var _controller: StopwatchController
var _face_mat: StandardMaterial3D
var _mark_mat: StandardMaterial3D
var _pip_on: StandardMaterial3D
var _pip_off: StandardMaterial3D
var _pips: Array[MeshInstance3D] = []
var _second_hand: Node3D
var _minute_hand: Node3D
var _thumb: Node3D
var _readout: Label3D
var _last_whole_second: int = -1
var _tick_parity: bool = false
var _jolt: float = 0.0
var _rng := RandomNumberGenerator.new()
var _base_rotation: Vector3

@onready var _model: Node3D = $Model


func setup(player: Player, controller: StopwatchController) -> void:
	_player = player
	_controller = controller


func _ready() -> void:
	_base_rotation = rotation
	if _model.get_child_count() == 0:
		_build_placeholder()
	Palette.to_viewmodel_layer(self)
	Events.time_granted.connect(_on_time_granted)


func _process(delta: float) -> void:
	if _controller == null:
		return
	var time := RunManager.time_remaining
	var blend := _controller.blend
	var in_debt := _controller.debt_remaining > 0.0 and not _controller.active
	var low := RunManager.is_low_time()

	# --- Hands: discrete mechanical ticks, nervous sweep in debt -------------
	var shown := ceilf(time) if not in_debt else time
	var angle := -(fposmod(shown, 60.0) / 60.0) * TAU
	if blend > 0.0:
		angle += sin(TimeDirector.real_time * 47.0) * 0.06 * blend
	_second_hand.rotation.z = angle
	_minute_hand.rotation.z = -(clampf(time, 0.0, 180.0) / 180.0) * TAU

	# --- Face inversion during Borrow Time --------------------------------------
	_face_mat.albedo_color = Palette.PAPER.lerp(Palette.BLACK, blend)
	_face_mat.emission = Palette.PAPER.lerp(Palette.BLACK, blend) * 0.25
	_mark_mat.albedo_color = Palette.BLACK.lerp(Palette.PAPER, blend)

	# --- Charge pips -------------------------------------------------------------
	var lit := int(ceil(_controller.charge * PIP_COUNT - 0.001))
	for i in _pips.size():
		_pips[i].material_override = _pip_on if i < lit else _pip_off

	# --- Readout ------------------------------------------------------------------
	var secs := int(ceilf(time))
	_readout.text = "%d:%02d" % [int(secs / 60.0), secs % 60]
	_readout.modulate = Palette.RED_HOT if (low or in_debt) else (Palette.PAPER if blend > 0.5 else Palette.BLACK)

	# --- Thumb on the crown ---------------------------------------------------------
	_thumb.position.y = lerpf(0.098, 0.088, blend)

	# --- Ticking -------------------------------------------------------------------
	if RunManager.active and secs != _last_whole_second:
		if _last_whole_second != -1 and secs < _last_whole_second:
			_play_tick(low, in_debt)
		_last_whole_second = secs

	# --- Jolt (low time) and idle drift ----------------------------------------------
	_jolt = lerpf(_jolt, 0.0, 1.0 - exp(-12.0 * delta))
	rotation = _base_rotation + Vector3(
		_jolt * _rng.randf_range(-0.05, 0.05),
		_jolt * _rng.randf_range(-0.05, 0.05),
		_jolt * _rng.randf_range(-0.08, 0.08) + sin(TimeDirector.real_time * 0.7) * 0.01)


func _play_tick(low: bool, in_debt: bool) -> void:
	_tick_parity = not _tick_parity
	if in_debt:
		AudioDirector.play(&"debt_tick", null, -8.0, 1.0, AudioDirector.BUS_STOPWATCH)
	elif low:
		AudioDirector.play(&"low_time_tick", null, -4.0, 1.0, AudioDirector.BUS_STOPWATCH)
		_jolt = 1.0
	else:
		AudioDirector.play(&"tick" if _tick_parity else &"tock", null, -16.0, 1.0, AudioDirector.BUS_STOPWATCH, 0.01)


func _on_time_granted(seconds: float, _reason: StringName) -> void:
	if seconds <= 0.0:
		return
	AudioDirector.play(&"time_gain", null, -9.0, 1.0, AudioDirector.BUS_STOPWATCH, 0.0)
	var label := Label3D.new()
	label.text = "+%.1f" % seconds
	label.font_size = 64
	label.pixel_size = 0.00035
	label.modulate = Palette.RED_HOT
	label.outline_size = 0
	label.no_depth_test = true
	label.layers = Palette.VIEWMODEL_LAYER
	label.position = Vector3(0.0, 0.075, 0.02)
	_model.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 0.13, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


# --- Placeholder construction -----------------------------------------------------

func _build_placeholder() -> void:
	var metal := Palette.lit(Palette.CHARCOAL, 0.35, 0.75)
	_face_mat = Palette.unique(Palette.lit(Palette.PAPER, 0.6))
	_face_mat.emission_enabled = true
	_face_mat.emission = Palette.PAPER * 0.25
	_mark_mat = Palette.unique(Palette.lit(Palette.BLACK, 0.7))
	_pip_on = Palette.emissive(Palette.RED_HOT, 2.2)
	_pip_off = Palette.lit(Palette.ASH, 0.6)

	var body := Node3D.new()
	body.name = "Body"
	_model.add_child(body)

	var case_mesh := Palette.cylinder(0.072, 0.024, metal, 32)
	case_mesh.rotation.x = PI * 0.5
	body.add_child(case_mesh)
	var face := Palette.cylinder(0.064, 0.003, _face_mat, 32)
	face.rotation.x = PI * 0.5
	face.position.z = 0.0125
	body.add_child(face)

	# Hour marks.
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var mark := Palette.box(Vector3(0.0035, 0.011 if i % 3 == 0 else 0.007, 0.001), _mark_mat)
		mark.position = Vector3(sin(a) * 0.054, cos(a) * 0.054, 0.0145)
		mark.rotation.z = -a
		body.add_child(mark)

	# Charge pips around the bezel.
	for i in PIP_COUNT:
		var a := float(i) / PIP_COUNT * TAU
		var pip := Palette.box(Vector3(0.007, 0.005, 0.003), _pip_on)
		pip.position = Vector3(sin(a) * 0.0685, cos(a) * 0.0685, 0.0125)
		pip.rotation.z = -a
		body.add_child(pip)
		_pips.append(pip)

	# Minute subdial.
	var subdial := Palette.cylinder(0.015, 0.001, Palette.lit(Palette.BONE.darkened(0.15), 0.7), 20)
	subdial.rotation.x = PI * 0.5
	subdial.position = Vector3(0.0, -0.026, 0.0148)
	body.add_child(subdial)
	_minute_hand = Node3D.new()
	_minute_hand.position = Vector3(0.0, -0.026, 0.0158)
	body.add_child(_minute_hand)
	var mh := Palette.box(Vector3(0.002, 0.012, 0.0008), _mark_mat)
	mh.position.y = 0.005
	_minute_hand.add_child(mh)

	# Second hand (red), pivot at the centre.
	_second_hand = Node3D.new()
	_second_hand.position = Vector3(0.0, 0.0, 0.0165)
	body.add_child(_second_hand)
	var sh := Palette.box(Vector3(0.0028, 0.06, 0.0008), Palette.emissive(Palette.RED, 0.8))
	sh.position.y = 0.022
	_second_hand.add_child(sh)
	var hub := Palette.cylinder(0.004, 0.003, Palette.emissive(Palette.RED, 0.8), 12)
	hub.rotation.x = PI * 0.5
	_second_hand.add_child(hub)

	# Digital readout (prototype legibility aid).
	_readout = Label3D.new()
	_readout.font_size = 40
	_readout.pixel_size = 0.00032
	_readout.outline_size = 0
	_readout.modulate = Palette.BLACK
	_readout.position = Vector3(0.0, 0.024, 0.0152)
	_readout.text = "0:00"
	body.add_child(_readout)

	# Crown and bow.
	var crown := Palette.cylinder(0.008, 0.016, metal, 12)
	crown.position = Vector3(0.0, 0.08, 0.0)
	body.add_child(crown)
	var bow := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.009
	torus.outer_radius = 0.013
	bow.mesh = torus
	bow.material_override = metal
	bow.rotation.x = PI * 0.5
	bow.position = Vector3(0.0, 0.098, 0.0)
	body.add_child(bow)

	# Pale hand cradling the watch, thumb on the crown.
	var palm := Palette.box(Vector3(0.1, 0.06, 0.05), Palette.wax())
	palm.position = Vector3(-0.005, -0.065, -0.012)
	palm.rotation.z = deg_to_rad(8.0)
	_model.add_child(palm)
	_thumb = Node3D.new()
	_thumb.position = Vector3(0.0, 0.098, 0.004)
	_model.add_child(_thumb)
	var thumb_mesh := Palette.capsule(0.011, 0.05, Palette.wax())
	thumb_mesh.rotation.z = deg_to_rad(-70.0)
	thumb_mesh.position = Vector3(0.02, 0.0, 0.0)
	_thumb.add_child(thumb_mesh)
	var sleeve := Palette.cylinder(0.05, 0.4, Palette.lit(Palette.BLACK, 0.95), 12)
	sleeve.position = Vector3(-0.04, -0.2, 0.18)
	sleeve.rotation = Vector3(deg_to_rad(55.0), 0.0, deg_to_rad(12.0))
	_model.add_child(sleeve)
