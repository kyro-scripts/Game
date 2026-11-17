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
	FX.debris_burst(global_position + Vector3.UP * height * 0.5, flat * 0.95, 18,
			Vector3(0.45, 0.55, thickness), Palette.lit(Palette.CHARCOAL, 0.9), floor_y, 4.0, 2.5)
	FX.debris_burst(global_position + Vector3.UP * height * 0.5, flat * 0.8, 6,
			Vector3(0.5, 0.06, 0.06), Palette.lit(Palette.BONE, 0.7), floor_y, 4.0, 2.0)
	AudioDirector.play(&"door_breach", at, 3.0, 1.0)
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

	var wood := Palette.lit(Palette.CHARCOAL, 0.92)
	var trim := Palette.lit(Palette.BONE, 0.7)
	var red := Palette.emissive(Palette.RED, 0.4)
	var half := width * 0.5
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.set_meta(&"generated", true)
		hinge.position = Vector3(side * half, 0.0, 0.0)
		add_child(hinge)
		_panels.append(hinge)
		var panel_w := half - 0.015
		var cx := -side * panel_w * 0.5
		var slab := Palette.box(Vector3(panel_w, height, thickness), wood)
		slab.position = Vector3(cx, height * 0.5, 0.0)
		hinge.add_child(slab)
		# Pale inset frame lines on both faces.
		for face_z: float in [thickness * 0.5 + 0.005, -thickness * 0.5 - 0.005]:
			for y: float in [height * 0.18, height * 0.82]:
				var bar := Palette.box(Vector3(panel_w * 0.7, 0.03, 0.01), trim)
				bar.position = Vector3(cx, y, face_z)
				hinge.add_child(bar)
			var band := Palette.box(Vector3(panel_w, 0.08, 0.012), red)
			band.position = Vector3(cx, height * 0.52, face_z)
			hinge.add_child(band)
	# Only one panel carries a small pale oval at eye height. Nobody knows why.
	var oval := Palette.sphere(0.11, Palette.wax(), 12)
	oval.scale = Vector3(0.8, 1.15, 0.25)
	oval.position = Vector3((half - 0.015) * 0.5 + 0.12, 1.62, thickness * 0.5 + 0.01)
	_panels[0].add_child(oval)
