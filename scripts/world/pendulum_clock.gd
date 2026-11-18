@tool
class_name PendulumClock
extends Node3D
## A large white wall clock with a swinging pendulum. Its hands run on WORLD
## time, too fast, so Borrow Time is visible at a glance across a room. It
## chimes whenever its minute hand passes twelve (emits Events.clock_chimed;
## Bellkeepers will listen for this in Phase D).

@export var face_radius: float = 2.2:
	set(v):
		face_radius = v
		_rebuild()
@export var pendulum_length: float = 3.6:
	set(v):
		pendulum_length = v
		_rebuild()
## World-seconds for the minute hand to complete one revolution.
@export var minute_period: float = 60.0
## World-seconds per full pendulum swing (there and back).
@export var swing_period: float = 2.2
@export_range(0.0, 1.0, 0.01) var swing_amplitude: float = 0.2
@export var chime_enabled: bool = true

var _minute_hand: Node3D
var _hour_hand: Node3D
var _pendulum: Node3D
var _last_revolution: int = 0


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _minute_hand == null:
		return
	var t := TimeDirector.world_time
	_minute_hand.rotation.z = -fposmod(t / minute_period, 1.0) * TAU
	_hour_hand.rotation.z = -fposmod(t / (minute_period * 12.0), 1.0) * TAU
	_pendulum.rotation.z = sin(t / swing_period * TAU) * swing_amplitude
	var rev := int(floor(t / minute_period))
	if chime_enabled and rev > _last_revolution:
		_last_revolution = rev
		AudioDirector.play(&"chime", global_position, 4.0, 1.0, AudioDirector.BUS_WORLD, 0.0)
		Events.clock_chimed.emit()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	var root := Node3D.new()
	root.set_meta(&"generated", true)
	add_child(root)

	var wood := CastleMaterials.wood()
	var brass := CastleMaterials.brass()
	var ink := Palette.lit(Palette.BLACK, 0.5)
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(0.9, 0.88, 0.83)
	enamel.roughness = 0.3
	enamel.clearcoat_enabled = true
	enamel.clearcoat = 0.6
	var fz := 0.32  # dial plane, in front of the case

	# Tall oak case with a pointed pediment, standing on the floor.
	var case_w := face_radius * 2.0 + 1.0
	var case_h := 8.0 + face_radius + 1.2
	var outline := MeshKit.pointed_arch_opening(case_w, case_h - 1.6, 1.6, 12)
	var case_mi := MeshInstance3D.new()
	case_mi.mesh = MeshKit.extrude_polygon(outline, 0.34)
	case_mi.material_override = wood
	case_mi.position = Vector3(0.0, -8.0, 0.1)
	root.add_child(case_mi)
	# Glazed door over the pendulum: dark glass in a moulded frame.
	var door_h := pendulum_length + 0.9
	var glass := Palette.box(Vector3(2.6, door_h, 0.02), CastleMaterials.black_glass())
	glass.position = Vector3(0.0, -face_radius - 0.25 - door_h * 0.5, fz + 0.14)
	glass.transparency = 0.55
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glass)
	var frame := CastleProps.door_frame(2.6, door_h, 0.08)
	frame.position = Vector3(0.0, -face_radius - 0.25 - door_h, fz + 0.08)
	root.add_child(frame)

	# Enamel dial, brass bezel, minute track and Roman numerals.
	var face := Palette.cylinder(face_radius, 0.06, enamel, 64)
	face.rotation.x = PI * 0.5
	face.position.z = fz
	root.add_child(face)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = face_radius - 0.02
	torus.outer_radius = face_radius + 0.16
	torus.rings = 64
	rim.mesh = torus
	rim.material_override = brass
	rim.rotation.x = PI * 0.5
	rim.position.z = fz + 0.02
	root.add_child(rim)
	for i in 60:
		var a := float(i) / 60.0 * TAU
		var major := i % 5 == 0
		var mark := Palette.box(Vector3(0.025 if not major else 0.06, 0.12 if not major else 0.22, 0.01), ink)
		mark.position = Vector3(sin(a), cos(a), 0.0) * (face_radius - 0.12) + Vector3(0.0, 0.0, fz + 0.035)
		mark.rotation.z = -a
		root.add_child(mark)
	var numerals := ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var l := Label3D.new()
		l.text = numerals[i]
		l.font_size = 120
		l.pixel_size = 0.0035
		l.modulate = Color(0.06, 0.06, 0.07)
		l.outline_size = 0
		l.shaded = true
		l.position = Vector3(sin(a), cos(a), 0.0) * (face_radius - 0.55) + Vector3(0.0, 0.0, fz + 0.036)
		l.rotation.z = -a
		root.add_child(l)

	_hour_hand = Node3D.new()
	_hour_hand.position.z = fz + 0.05
	root.add_child(_hour_hand)
	var hh := Palette.box(Vector3(0.11, face_radius * 0.5, 0.02), ink)
	hh.position.y = face_radius * 0.22
	_hour_hand.add_child(hh)
	var spade := Palette.box(Vector3(0.24, 0.24, 0.02), ink)
	spade.rotation.z = PI * 0.25
	spade.position.y = face_radius * 0.45
	_hour_hand.add_child(spade)

	_minute_hand = Node3D.new()
	_minute_hand.position.z = fz + 0.07
	root.add_child(_minute_hand)
	var mh := Palette.box(Vector3(0.06, face_radius * 0.84, 0.02), Palette.emissive(Palette.RED, 0.5))
	mh.position.y = face_radius * 0.36
	_minute_hand.add_child(mh)
	var boss := Palette.cylinder(0.1, 0.06, brass, 20)
	boss.rotation.x = PI * 0.5
	boss.position.z = fz + 0.09
	root.add_child(boss)

	_pendulum = Node3D.new()
	_pendulum.position = Vector3(0.0, -face_radius - 0.1, fz + 0.02)
	root.add_child(_pendulum)
	var rod := Palette.box(Vector3(0.04, pendulum_length, 0.04), brass)
	rod.position.y = -pendulum_length * 0.5
	_pendulum.add_child(rod)
	var bob := Palette.cylinder(0.42, 0.06, brass, 40)
	bob.rotation.x = PI * 0.5
	bob.position.y = -pendulum_length
	_pendulum.add_child(bob)
