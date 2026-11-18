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
var _numerals: Array[Label3D] = []
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
	for n in _numerals:
		n.modulate = _mark_mat.albedo_color

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
	# A heavy silver hunter-style pocket watch: domed crystal, enamel dial with
	# Roman numerals and a minute track, garnet charge jewels set in the bezel,
	# a knurled crown under the thumb and a chain falling out of frame.
	var silver := CastleMaterials.silver()
	_face_mat = StandardMaterial3D.new()
	_face_mat.albedo_color = Palette.PAPER
	_face_mat.roughness = 0.28
	_face_mat.clearcoat_enabled = true
	_face_mat.clearcoat = 0.7
	_face_mat.emission_enabled = true
	_face_mat.emission = Palette.PAPER * 0.18
	_mark_mat = Palette.unique(Palette.lit(Palette.BLACK, 0.5))
	_pip_on = Palette.emissive(Palette.RED_HOT, 2.4)
	_pip_off = StandardMaterial3D.new()
	_pip_off.albedo_color = Color(0.12, 0.02, 0.02)
	_pip_off.roughness = 0.15
	_pip_off.metallic = 0.3

	var body := Node3D.new()
	body.name = "Body"
	_model.add_child(body)

	# Case (lathe around Y, turned to face the camera).
	var case_profile := PackedVector2Array([Vector2(0.0, -0.013), Vector2(0.058, -0.013), Vector2(0.068, -0.01),
			Vector2(0.0735, -0.005), Vector2(0.075, 0.001), Vector2(0.0735, 0.006), Vector2(0.07, 0.0095),
			Vector2(0.066, 0.0115), Vector2(0.0, 0.0115)])
	var case_mi := _vm_mesh(MeshKit.lathe(case_profile, 48), silver)
	case_mi.rotation.x = PI * 0.5
	body.add_child(case_mi)
	var bezel := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.0615
	bt.outer_radius = 0.0695
	bt.rings = 48
	bt.ring_segments = 10
	bezel.mesh = bt
	bezel.material_override = silver
	bezel.rotation.x = PI * 0.5
	bezel.position.z = 0.0125
	body.add_child(bezel)

	var face := Palette.cylinder(0.062, 0.002, _face_mat, 48)
	face.rotation.x = PI * 0.5
	face.position.z = 0.0125
	body.add_child(face)

	# Minute track and Roman numerals.
	for i in 60:
		var a := float(i) / 60.0 * TAU
		var major := i % 5 == 0
		var mark := Palette.box(Vector3(0.0012 if not major else 0.0022, 0.004 if not major else 0.006, 0.0006), _mark_mat)
		mark.position = Vector3(sin(a) * 0.0565, cos(a) * 0.0565, 0.0137)
		mark.rotation.z = -a
		body.add_child(mark)
	var numerals := ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var l := Label3D.new()
		l.text = numerals[i]
		l.font_size = 48
		l.pixel_size = 0.00016
		l.outline_size = 0
		l.modulate = Palette.BLACK
		l.position = Vector3(sin(a) * 0.045, cos(a) * 0.045, 0.0138)
		l.rotation.z = -a
		body.add_child(l)
		_numerals.append(l)

	# Garnet charge jewels set into the bezel.
	for i in PIP_COUNT:
		var a := float(i) / PIP_COUNT * TAU
		var pip := Palette.sphere(0.0032, _pip_on, 10)
		pip.position = Vector3(sin(a) * 0.0655, cos(a) * 0.0655, 0.0158)
		body.add_child(pip)
		_pips.append(pip)

	# Minute subdial with a blued hand.
	var subdial := Palette.cylinder(0.014, 0.0008, Palette.lit(Palette.BONE.darkened(0.12), 0.4), 28)
	subdial.rotation.x = PI * 0.5
	subdial.position = Vector3(0.0, -0.024, 0.0138)
	body.add_child(subdial)
	var sub_ring := MeshInstance3D.new()
	var srt := TorusMesh.new()
	srt.inner_radius = 0.0135
	srt.outer_radius = 0.0145
	sub_ring.mesh = srt
	sub_ring.material_override = _mark_mat
	sub_ring.rotation.x = PI * 0.5
	sub_ring.position = Vector3(0.0, -0.024, 0.014)
	body.add_child(sub_ring)
	_minute_hand = Node3D.new()
	_minute_hand.position = Vector3(0.0, -0.024, 0.0148)
	body.add_child(_minute_hand)
	var mh := Palette.box(Vector3(0.0014, 0.012, 0.0006), CastleMaterials.blued_steel())
	mh.position.y = 0.005
	_minute_hand.add_child(mh)

	# The red second hand that unwinds the run, with a counterweight tail.
	_second_hand = Node3D.new()
	_second_hand.position = Vector3(0.0, 0.0, 0.0158)
	body.add_child(_second_hand)
	var sh := Palette.box(Vector3(0.0016, 0.058, 0.0006), Palette.emissive(Palette.RED, 0.9))
	sh.position.y = 0.021
	_second_hand.add_child(sh)
	var tail := Palette.box(Vector3(0.003, 0.014, 0.0006), Palette.emissive(Palette.RED, 0.9))
	tail.position.y = -0.009
	_second_hand.add_child(tail)
	var hub := Palette.cylinder(0.0028, 0.002, silver, 12)
	hub.rotation.x = PI * 0.5
	_second_hand.add_child(hub)

	# Domed crystal.
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.07)
	crystal_mat.roughness = 0.02
	crystal_mat.metallic_specular = 1.0
	var dome := PackedVector2Array([Vector2(0.0, 0.0195), Vector2(0.025, 0.0185), Vector2(0.045, 0.0165),
			Vector2(0.058, 0.0142), Vector2(0.0625, 0.0128)])
	var crystal := _vm_mesh(MeshKit.lathe(dome, 40), crystal_mat)
	crystal.rotation.x = PI * 0.5
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(crystal)

	# Complication window: the exact remaining time (prototype legibility aid).
	_readout = Label3D.new()
	_readout.font_size = 32
	_readout.pixel_size = 0.00022
	_readout.outline_size = 0
	_readout.modulate = Palette.BLACK
	_readout.position = Vector3(0.0, 0.019, 0.0139)
	_readout.text = "0:00"
	body.add_child(_readout)

	# Pendant, knurled crown and bow.
	var pendant := _vm_mesh(MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.07), Vector2(0.011, 0.07),
			Vector2(0.009, 0.078), Vector2(0.008, 0.084), Vector2(0.0, 0.084)]), 20), silver)
	body.add_child(pendant)
	var crown := _vm_mesh(MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.084), Vector2(0.0085, 0.084),
			Vector2(0.0095, 0.088), Vector2(0.0095, 0.094), Vector2(0.0085, 0.097), Vector2(0.0, 0.097)]), 18, false), silver)
	body.add_child(crown)
	var bow := MeshInstance3D.new()
	var bow_t := TorusMesh.new()
	bow_t.inner_radius = 0.0115
	bow_t.outer_radius = 0.0145
	bow_t.ring_segments = 10
	bow.mesh = bow_t
	bow.material_override = silver
	bow.rotation.x = PI * 0.5
	bow.position = Vector3(0.0, 0.106, 0.0)
	body.add_child(bow)
	# A chain hanging from the bow and falling away to the left.
	for k in 11:
		var t := float(k) / 10.0
		var link := MeshInstance3D.new()
		var lt := TorusMesh.new()
		lt.inner_radius = 0.0026
		lt.outer_radius = 0.0038
		lt.ring_segments = 6
		lt.rings = 10
		link.mesh = lt
		link.material_override = silver
		link.position = Vector3(-0.004 - t * 0.075, 0.112 - t * 0.02 - t * t * 0.09, 0.003 + t * 0.01)
		link.rotation = Vector3(PI * 0.5 * float(k % 2), 0.4, 0.9 + t * 0.6)
		link.scale = Vector3(1.0, 1.0, 1.7)
		_model.add_child(link)

	# Kid glove: palm behind, fingers curled around the left edge, thumb on
	# the crown. The velvet sleeve leads out of frame.
	var glove := CastleMaterials.glove()
	var palm := Palette.box(Vector3(0.09, 0.07, 0.03), glove)
	palm.position = Vector3(-0.01, -0.03, -0.034)
	palm.rotation.z = deg_to_rad(10.0)
	_model.add_child(palm)
	for i in 4:
		var f := Palette.capsule(0.0085, 0.05, glove)
		var y := 0.03 - float(i) * 0.019
		f.position = Vector3(-0.077, y, -0.004)
		f.rotation = Vector3(PI * 0.5, 0.0, 0.18)
		_model.add_child(f)
		var tip := Palette.capsule(0.008, 0.026, glove)
		tip.position = Vector3(-0.07, y, 0.019)
		tip.rotation = Vector3(0.0, 0.0, PI * 0.5 + 0.4)
		_model.add_child(tip)
	_thumb = Node3D.new()
	_thumb.position = Vector3(0.0, 0.098, 0.004)
	_model.add_child(_thumb)
	var thumb_mesh := Palette.capsule(0.0105, 0.055, glove)
	thumb_mesh.rotation.z = deg_to_rad(-70.0)
	thumb_mesh.position = Vector3(0.022, 0.0, 0.0)
	_thumb.add_child(thumb_mesh)
	var sleeve := Palette.cylinder(0.052, 0.4, CastleMaterials.velvet(Color(0.05, 0.045, 0.05), 0.0, 0.0), 16)
	sleeve.position = Vector3(-0.04, -0.27, 0.17)
	sleeve.rotation = Vector3(deg_to_rad(55.0), 0.0, deg_to_rad(12.0))
	_model.add_child(sleeve)


func _vm_mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	return mi
