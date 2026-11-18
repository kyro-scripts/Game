class_name FaceRig
extends Node3D
## A glazed porcelain mask. "At first glance, human. At second glance, wrong."
##
## Sculpted procedurally (MeshKit.mask_mesh) when the node has no children.
## Wrongness here is deliberately subtle:
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


## Instant expression change (no transition, on purpose): the mask mesh is
## swapped wholesale, so the smile is simply there, then simply gone.
func set_expression(e: Mood) -> void:
	mood = e
	if _mask == null:
		return
	_mask.mesh = mesh_for(e)
	for eye in _eyes:
		eye.visible = e != Mood.DEAD


## Flash the mask (hit feedback).
func flash(color: Color) -> void:
	if _mask == null:
		return
	var mat := _mask.material_override as StandardMaterial3D
	if mat == null:
		return
	var original := CastleMaterials.porcelain().albedo_color
	mat.albedo_color = color
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", original, 0.12)


static var _meshes: Dictionary = {}


## Shared sculpted mask meshes, one per mood.
static func mesh_for(m: Mood) -> Mesh:
	if not _meshes.has(m):
		match m:
			Mood.OPEN:
				_meshes[m] = MeshKit.mask_mesh(0.25, 1.0)
			Mood.NEUTRAL:
				_meshes[m] = MeshKit.mask_mesh(0.35, 0.0)
			_:
				_meshes[m] = MeshKit.mask_mesh(1.0, 0.0)
	return _meshes[m]


func _build() -> void:
	_mask = MeshInstance3D.new()
	_mask.mesh = mesh_for(mood)
	_mask.material_override = Palette.unique(CastleMaterials.porcelain())
	add_child(_mask)

	# Wet black eyes set in the sockets. The left sits 3 mm high.
	var eye_mat := CastleMaterials.black_glass()
	var left := Palette.sphere(0.0105, eye_mat, 12)
	left.position = Vector3(-0.0285, 0.0235, 0.08)
	left.scale = Vector3(1.0, EYE_SCALE_Y, 0.6)
	add_child(left)
	var right := Palette.sphere(0.0105, eye_mat, 12)
	right.position = Vector3(0.0285, 0.0205, 0.08)
	right.scale = Vector3(1.0, EYE_SCALE_Y, 0.6)
	add_child(right)
	_eyes = [left, right]
