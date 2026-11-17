class_name FaceRig
extends Node3D
## Placeholder uncanny face. "At first glance, human. At second glance, wrong."
##
## Built from primitives when the node has no children. Wrongness here is
## deliberately subtle:
##  * the left eye sits a few millimetres higher and wider than the right,
##  * the smile is perfectly symmetrical and a touch too wide,
##  * every face in the castle blinks on the same shared clock,
##  * expressions SNAP between shapes with no in-between frames,
##  * the head tracks its target at a constant angular speed (no easing).
##
## Head tracking itself is driven by EnemyBase (it rotates Visual/Head).
## Interface for real art: keep set_expression() and flash(), replace the rest.

enum Mood { NEUTRAL, SMILE, OPEN, DEAD }

## Shared blink rhythm (world-time seconds). All faces obey it together.
const BLINK_PERIOD := 4.3
const BLINK_LENGTH := 0.11
const EYE_SCALE_Y := 0.72

var mood: Mood = Mood.SMILE
var _eyes: Array[Node3D] = []
var _mouth_smile: Node3D
var _mouth_open: Node3D
var _mask: MeshInstance3D


func _ready() -> void:
	if get_child_count() == 0:
		_build()
	set_expression(mood)


func _process(_delta: float) -> void:
	# Synchronised blinking on the shared world clock.
	var phase := fposmod(TimeDirector.world_time, BLINK_PERIOD)
	var closed := phase < BLINK_LENGTH and mood != Mood.DEAD
	for eye in _eyes:
		eye.scale.y = EYE_SCALE_Y * (0.12 if closed else 1.0)


## Instant expression change (no transition, on purpose).
func set_expression(e: Mood) -> void:
	mood = e
	if _mouth_smile == null:
		return
	_mouth_smile.visible = e == Mood.SMILE or e == Mood.NEUTRAL
	_mouth_smile.scale = Vector3(1.0, 1.0 if e == Mood.SMILE else 0.35, 1.0)
	_mouth_open.visible = e == Mood.OPEN
	for eye in _eyes:
		eye.visible = e != Mood.DEAD


## Flash the mask (hit feedback).
func flash(color: Color) -> void:
	if _mask == null:
		return
	var mat := _mask.material_override as StandardMaterial3D
	if mat == null:
		return
	var original := Palette.wax().albedo_color
	mat.albedo_color = color
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", original, 0.12)


func _build() -> void:
	var skin := Palette.unique(Palette.wax())
	_mask = Palette.sphere(0.13, skin, 20)
	# Slightly too tall, slightly too flat: a mask pretending to be a face.
	_mask.scale = Vector3(0.92, 1.14, 0.78)
	add_child(_mask)

	var eye_mat := Palette.lit(Palette.BLACK, 0.2)
	# Left eye: 4 mm higher, 3 mm further out than its partner.
	var left := Palette.sphere(0.017, eye_mat, 10)
	left.position = Vector3(-0.047, 0.032, 0.093)
	left.scale = Vector3(1.0, EYE_SCALE_Y, 0.5)
	add_child(left)
	var right := Palette.sphere(0.017, eye_mat, 10)
	right.position = Vector3(0.044, 0.028, 0.094)
	right.scale = Vector3(1.0, EYE_SCALE_Y, 0.5)
	add_child(right)
	_eyes = [left, right]

	# A smile held a fraction too wide, built from three red segments.
	var lip := Palette.lit(Palette.RED, 0.4)
	_mouth_smile = Node3D.new()
	_mouth_smile.position = Vector3(0.0, -0.05, 0.096)
	add_child(_mouth_smile)
	var mid := Palette.box(Vector3(0.06, 0.008, 0.01), lip)
	_mouth_smile.add_child(mid)
	for side in [-1.0, 1.0]:
		var corner := Palette.box(Vector3(0.036, 0.007, 0.01), lip)
		corner.position = Vector3(side * 0.044, 0.01, -0.006)
		corner.rotation.z = side * deg_to_rad(28.0)
		_mouth_smile.add_child(corner)

	_mouth_open = Node3D.new()
	_mouth_open.position = Vector3(0.0, -0.055, 0.094)
	add_child(_mouth_open)
	var hole := Palette.sphere(0.024, Palette.lit(Palette.BLACK, 0.9), 10)
	hole.scale = Vector3(0.8, 1.35, 0.4)
	_mouth_open.add_child(hole)
