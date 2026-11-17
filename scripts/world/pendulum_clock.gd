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
@export_range(0.0, 1.0, 0.01) var swing_amplitude: float = 0.38
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

	var face_mat := Palette.lit(Palette.PAPER, 0.75)
	var ink := Palette.lit(Palette.BLACK, 0.6)
	var face := Palette.cylinder(face_radius, 0.12, face_mat, 48)
	face.rotation.x = PI * 0.5
	root.add_child(face)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = face_radius
	torus.outer_radius = face_radius + 0.18
	torus.rings = 48
	rim.mesh = torus
	rim.material_override = ink
	rim.rotation.x = PI * 0.5
	root.add_child(rim)
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var mark := Palette.box(Vector3(0.09, 0.35 if i % 3 == 0 else 0.2, 0.02), ink)
		mark.position = Vector3(sin(a), cos(a), 0.0) * (face_radius - 0.3) + Vector3(0.0, 0.0, 0.07)
		mark.rotation.z = -a
		root.add_child(mark)

	_hour_hand = Node3D.new()
	_hour_hand.position.z = 0.09
	root.add_child(_hour_hand)
	var hh := Palette.box(Vector3(0.12, face_radius * 0.5, 0.02), ink)
	hh.position.y = face_radius * 0.22
	_hour_hand.add_child(hh)

	_minute_hand = Node3D.new()
	_minute_hand.position.z = 0.11
	root.add_child(_minute_hand)
	var mh := Palette.box(Vector3(0.07, face_radius * 0.82, 0.02), Palette.emissive(Palette.RED, 0.6))
	mh.position.y = face_radius * 0.36
	_minute_hand.add_child(mh)

	_pendulum = Node3D.new()
	_pendulum.position = Vector3(0.0, -face_radius - 0.1, 0.0)
	root.add_child(_pendulum)
	var rod := Palette.box(Vector3(0.06, pendulum_length, 0.06), ink)
	rod.position.y = -pendulum_length * 0.5
	_pendulum.add_child(rod)
	var bob := Palette.cylinder(0.45, 0.08, Palette.lit(Palette.BONE, 0.4, 0.6), 32)
	bob.rotation.x = PI * 0.5
	bob.position.y = -pendulum_length
	_pendulum.add_child(bob)
