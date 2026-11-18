class_name GuestInRed
extends Node3D
## The Red Death, as a sighting (not a fight). After the reference image:
## a tall, rough-painted red hooded robe; where a face should be, a white
## analog clock whose hands run the wrong way; jagged black brushstroke forms
## around it, backlit by a low red haze.
##
## It appears far away, in the dark. It is gone if you get close, if you hold
## your gaze on it, or simply after a while. It never attacks (yet).

signal vanished

@export var vanish_distance: float = 13.0
@export var max_lifetime: float = 7.0
## Seconds of direct gaze before it is not there any more.
@export var gaze_limit: float = 1.3

var showing: bool = false

var _age: float = 0.0
var _gazed: float = 0.0
var _hand_minute: Node3D
var _hand_hour: Node3D
var _forms: Node3D
var _form_step: float = 0.0


func _ready() -> void:
	_build()
	visible = false


func appear(at: Vector3, face_toward: Vector3) -> void:
	global_position = at
	var to := face_toward - at
	rotation.y = atan2(to.x, to.z)
	showing = true
	visible = true
	_age = 0.0
	_gazed = 0.0
	AudioDirector.play(&"guest_cue", at + Vector3.UP * 2.0, -4.0, 1.0, AudioDirector.BUS_WORLD, 0.0)
	Events.guest_sighted.emit(at)
	Events.atmosphere_event.emit(&"guest")


func vanish() -> void:
	if not showing:
		return
	showing = false
	visible = false
	vanished.emit()


func _process(delta: float) -> void:
	if not showing:
		return
	var dt := TimeDirector.scaled(TimeDirector.Channel.WORLD, delta)
	_age += dt
	# The hands run backwards, faster than any clock should.
	_hand_minute.rotation.z += dt * 0.9
	_hand_hour.rotation.z += dt * 0.075
	# The black forms shift in stop-motion steps.
	_form_step -= dt
	if _form_step <= 0.0:
		_form_step = 0.18
		for c in _forms.get_children():
			(c as Node3D).rotation.z += randf_range(-0.06, 0.06)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	var eye := player.get_eye_position()
	var to := global_position + Vector3.UP * 2.0 - eye
	if to.length() < vanish_distance:
		vanish()
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null and (-cam.global_basis.z).dot(to.normalized()) > 0.985:
		_gazed += dt
	if _gazed > gaze_limit or _age > max_lifetime:
		vanish()


func _build() -> void:
	var red := CastleMaterials.robe_red()
	# Robe: tall, narrow at the shoulders, flaring into a ragged hem.
	var prof := PackedVector2Array([Vector2(0.75, 0.0), Vector2(0.66, 0.2), Vector2(0.5, 0.8),
			Vector2(0.38, 1.5), Vector2(0.32, 2.0), Vector2(0.3, 2.2), Vector2(0.22, 2.32), Vector2(0.1, 2.4), Vector2(0.0, 2.42)])
	var folds := func(a: float, y: float) -> float:
		return 1.0 + 0.1 * (1.0 - smoothstep(0.0, 1.6, y)) * sin(a * 7.0 + sin(a * 2.0) * 2.0)
	var robe := MeshInstance3D.new()
	robe.mesh = MeshKit.lathe(prof, 40, true, folds)
	robe.material_override = red
	add_child(robe)
	# Deep hood, open at the front (+Z here).
	var hood_prof := PackedVector2Array([Vector2(0.24, 2.18), Vector2(0.27, 2.32), Vector2(0.28, 2.5),
			Vector2(0.25, 2.68), Vector2(0.17, 2.8), Vector2(0.06, 2.86), Vector2(0.0, 2.87)])
	var hood := MeshInstance3D.new()
	hood.mesh = MeshKit.lathe(hood_prof, 28, true, Callable(), false, PI * 0.5 + 0.9, PI * 0.5 + TAU - 0.9)
	hood.material_override = red
	add_child(hood)
	var inner := Palette.sphere(0.2, CastleMaterials.void_black(), 16)
	inner.position = Vector3(0.0, 2.5, -0.04)
	inner.scale = Vector3(1.0, 1.25, 0.7)
	add_child(inner)

	# The clock face: white, self-lit, black ticks and hands.
	var dial_mat := CastleMaterials.light_line(Color(0.92, 0.91, 0.87), 1.6)
	var dial := Palette.cylinder(0.17, 0.02, dial_mat, 40)
	dial.rotation.x = PI * 0.5
	dial.position = Vector3(0.0, 2.5, 0.12)
	add_child(dial)
	var ink := CastleMaterials.void_black()
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var tick := Palette.box(Vector3(0.012, 0.035 if i % 3 == 0 else 0.022, 0.004), ink)
		tick.position = Vector3(sin(a) * 0.14, 2.5 + cos(a) * 0.14, 0.132)
		tick.rotation.z = -a
		add_child(tick)
	_hand_hour = Node3D.new()
	_hand_hour.position = Vector3(0.0, 2.5, 0.136)
	add_child(_hand_hour)
	var hh := Palette.box(Vector3(0.014, 0.08, 0.004), ink)
	hh.position.y = 0.035
	_hand_hour.add_child(hh)
	_hand_minute = Node3D.new()
	_hand_minute.position = Vector3(0.0, 2.5, 0.14)
	add_child(_hand_minute)
	var mh := Palette.box(Vector3(0.009, 0.125, 0.004), ink)
	mh.position.y = 0.055
	_hand_minute.add_child(mh)

	# Jagged black forms around and behind it, cut out of a red haze.
	_forms = CastleProps.jagged_cluster(7, 2.4, 1847)
	_forms.position = Vector3(0.0, 1.8, -0.9)
	add_child(_forms)
	var haze := OmniLight3D.new()
	haze.light_color = Color(1.0, 0.08, 0.05)
	haze.light_energy = 3.0
	haze.omni_range = 6.0
	haze.omni_attenuation = 1.5
	haze.position = Vector3(0.0, 2.2, -1.6)
	haze.light_volumetric_fog_energy = 4.0
	add_child(haze)
	var face_light := OmniLight3D.new()
	face_light.light_color = Color(1.0, 0.98, 0.95)
	face_light.light_energy = 0.6
	face_light.omni_range = 1.5
	face_light.position = Vector3(0.0, 2.5, 0.6)
	add_child(face_light)
