@tool
class_name BreachableDoor
extends StaticBody3D
## A double door you burst through rather than open.
##
## Hitting it with enough horizontal speed (MovementTuning.breach_min_speed)
## shatters it into splinters that fly along your path; your momentum is mostly
## preserved by the Player. Touching it slowly makes it creak open on its own,
## taking long enough to feel like a penalty (and preventing soft-locks).
##
## Placeholder visuals are generated in _ready (also in the editor).

signal breached_by(body: Node3D, impact_speed: float)

@export var width: float = 3.0:
	set(v):
		width = v
		_rebuild()
@export var height: float = 3.6:
	set(v):
		height = v
		_rebuild()
@export var thickness: float = 0.2:
	set(v):
		thickness = v
		_rebuild()
## If false the door can only creak open (future: locked/event doors).
@export var breachable: bool = true
## Real seconds for a slow push to swing it open.
@export var creak_open_time: float = 1.4
## A face fixed to one leaf at eye height (set by the level, rarely).
@export var face_on_door: bool = false:
	set(v):
		face_on_door = v
		_rebuild()

var breached: bool = false

var _panels: Array[Node3D] = []
var _shape: CollisionShape3D
var _opening: bool = false
var _open_t: float = 0.0
var _open_sign: float = 1.0


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"breachable")
	collision_layer = 1
	collision_mask = 0


func _physics_process(real_delta: float) -> void:
	if Engine.is_editor_hint() or not _opening:
		return
	_open_t = minf(_open_t + TimeDirector.scaled(TimeDirector.Channel.WORLD, real_delta) / creak_open_time, 1.0)
	var e := 1.0 - pow(1.0 - _open_t, 3.0)
	if _panels.size() == 2:
		_panels[0].rotation.y = -_open_sign * deg_to_rad(105.0) * e
		_panels[1].rotation.y = _open_sign * deg_to_rad(105.0) * e
	if _open_t >= 0.45 and not breached:
		breached = true
		_shape.set_deferred(&"disabled", true)
	if _open_t >= 1.0:
		_opening = false


## Called by the Player on a fast impact. Returns true if the door gave way.
func breach(impact_velocity: Vector3, at: Vector3, by: Node3D) -> bool:
	if breached or not breachable:
		return false
	breached = true
	_opening = false
	_shape.set_deferred(&"disabled", true)
	for p in _panels:
		p.visible = false
	var floor_y := global_position.y
	var flat := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	var impact_speed := flat.length()
	FX.debris_burst(global_position + Vector3.UP * height * 0.5, flat * 0.95, 16,
			Vector3(0.16, 0.7, thickness), CastleMaterials.paint_charcoal(), floor_y, 4.0, 2.5)
	FX.debris_burst(global_position + Vector3.UP * height * 0.5, flat * 0.85, 8,
			Vector3(0.12, 0.5, thickness), CastleMaterials.paint_white(), floor_y, 4.0, 2.5)
	AudioDirector.play(&"door_breach", at, 3.0, 1.0)
	# A burst of dust-lit light so the splinters read even in a dark passage.
	FX.flash_light(global_position + Vector3.UP * height * 0.6 + flat.normalized() * 0.8,
			Color(1.0, 0.92, 0.82), 7.0, 7.0, 0.35)
	breached_by.emit(by, impact_speed)
	Events.door_breached.emit(self, impact_speed)
	return true


## Called by the Player when touching the door below breach speed.
func push_open(by: Node3D) -> void:
	if breached or _opening:
		return
	_opening = true
	var local := to_local(by.global_position)
	_open_sign = 1.0 if local.z > 0.0 else -1.0
	AudioDirector.play(&"door_creak", global_position + Vector3.UP * height * 0.5, -2.0, 1.0)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	_panels.clear()

	_shape = CollisionShape3D.new()
	_shape.set_meta(&"generated", true)
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness)
	_shape.shape = box
	_shape.position = Vector3(0.0, height * 0.5, 0.0)
	add_child(_shape)

	# Minimal: two matte black leaves, and a hairline of white light where
	# they meet, as if something bright waits on the other side.
	var leaf_mat := CastleMaterials.paint_black()
	var half := width * 0.5
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.set_meta(&"generated", true)
		hinge.position = Vector3(side * half, 0.0, 0.0)
		add_child(hinge)
		_panels.append(hinge)
		var panel_w := half - 0.012
		var cx := -side * panel_w * 0.5
		var slab := _box(Vector3(panel_w, height, thickness), leaf_mat)
		slab.position = Vector3(cx, height * 0.5, 0.0)
		hinge.add_child(slab)
		# The gap light belongs to a leaf so it vanishes when the door does.
		var gap := _box(Vector3(0.012, height - 0.1, thickness + 0.004), CastleMaterials.light_line(Color(0.95, 0.94, 0.9), 2.5))
		gap.position = Vector3(-side * (panel_w + 0.006), height * 0.5, 0.0)
		gap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hinge.add_child(gap)
		var under := _box(Vector3(panel_w - 0.06, 0.012, thickness + 0.01), CastleMaterials.light_line(Color(0.95, 0.94, 0.9), 2.0))
		under.position = Vector3(cx, 0.006, 0.0)
		under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hinge.add_child(under)
	if face_on_door:
		var face := MeshInstance3D.new()
		face.mesh = MeshKit.face_mesh(1.0, 0.0, 26, 32)
		face.material_override = CastleMaterials.skin()
		face.position = Vector3((half - 0.012) * 0.5, 1.68, thickness * 0.5 + 0.02)
		face.scale = Vector3(1.0, 1.0, 0.45)
		_panels[0].add_child(face)


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	return mi
