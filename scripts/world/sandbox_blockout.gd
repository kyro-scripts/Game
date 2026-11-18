@tool
class_name SandboxBlockout
extends Node3D
## The Phase A/B movement + combat sandbox, dressed as a real castle interior.
## Built from code so the layout is easy to read, tweak and diff. Generated
## nodes are not saved into the scene (no owner) but show in the editor.
##
## The playable layout (collision) is unchanged from the graybox:
##   GREAT HALL   z   0 .. -100  16 m wide, marble floor, pointed stone vault,
##                               scarlet lancet windows on the left wall,
##                               sconces and drapes on the right.
##                z -20  stone balustrade (right half)     -> jump
##                z -30  half-lowered portcullis (left)     -> slide under
##                z -45..-80  ramp up to a dais, long ramp down -> slide downhill
##                z -85..-95  low passage (left)            -> sustained slide
##   DOOR GALLERY z -100 .. -160  timber-ceilinged passage, 4 breachable doors
##   BALLROOM     z -160 .. -200  40 x 40 m, columns, chandelier, tall clock

const HALL_HALF_WIDTH := 8.0
const HALL_END := -100.0
const HALL_WALL_HEIGHT := 10.0
const VAULT_RISE := 6.0
const CORRIDOR_HALF_WIDTH := 2.5
const CORRIDOR_HEIGHT := 4.6
const CORRIDOR_END := -160.0
const ARENA_HALF_WIDTH := 20.0
const ARENA_END := -200.0
const ARENA_HEIGHT := 12.0
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 3.6
const DOOR_Z := [-100.0, -115.0, -130.0, -145.0]
const HALL_WINDOW_Z := [-4.0, -20.0, -36.0, -52.0, -68.0, -84.0]

const DOOR_SCENE := preload("res://scenes/world/breachable_door.tscn")
const DRAPE_RED := Color(0.32, 0.02, 0.02)

@export var rebuild_in_editor: bool = false:
	set(v):
		rebuild_in_editor = false
		if v:
			build()
## Volumetric red light shafts through the windows (shadowed spot lights).
@export var window_shafts: bool = true

var _root: Node3D


func _ready() -> void:
	build()


func build() -> void:
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Generated"
	add_child(_root)
	_build_great_hall()
	_build_door_gallery()
	_build_ballroom()


# --- Great hall --------------------------------------------------------------------------

func _build_great_hall() -> void:
	var w := HALL_HALF_WIDTH
	var stone := CastleMaterials.stone()
	var dressed := CastleMaterials.stone_dressed()
	# One floor slab under everything; marble is the default finish.
	_box("Floor", Vector3(0.0, -0.5, -100.0), Vector3(2.0 * ARENA_HALF_WIDTH + 2.0, 1.0, 220.0), CastleMaterials.marble())
	var wall_l := _box("HallWallL", Vector3(-w - 0.5, 5.0, -46.0), Vector3(1.0, 10.0, 108.0), stone)
	_box("HallWallR", Vector3(w + 0.5, 5.0, -46.0), Vector3(1.0, 10.0, 108.0), stone)
	_box("HallBack", Vector3(0.0, 5.0, 8.5), Vector3(2.0 * w + 2.0, 10.0, 1.0), stone)

	# Wall piers every 8 m with engaged columns; ribs spring from them.
	var z := 0.0
	while z >= HALL_END + 4.0:
		for side: float in [-1.0, 1.0]:
			_box("Pier", Vector3(side * (w - 0.45), 5.0, z), Vector3(0.8, 10.0, 0.8), dressed)
			var col := CastleProps.column(HALL_WALL_HEIGHT, 0.24)
			col.position = Vector3(side * (w - 0.95), 0.0, z)
			_root.add_child(col)
		var rib := MeshKit.sweep(MeshKit.rect_profile(0.42, 0.34),
				MeshKit.arch_path(2.0 * w - 0.2, HALL_WALL_HEIGHT, VAULT_RISE, z, 16), Vector3.BACK)
		_add_mesh("Rib", rib, dressed)
		z -= 8.0

	# Pointed barrel vault, ridge rib, cornice and plinth.
	var vault := MeshInstance3D.new()
	vault.name = "Vault"
	vault.mesh = MeshKit.pointed_vault(2.0 * w, HALL_WALL_HEIGHT, VAULT_RISE, 108.0, 16)
	vault.material_override = dressed
	vault.position.z = 8.0
	_root.add_child(vault)
	_add_mesh("Ridge", _straight_z(MeshKit.rect_profile(0.3, 0.3), 108.0), dressed,
			Vector3(0.0, HALL_WALL_HEIGHT + VAULT_RISE - 0.1, -46.0))
	for side: float in [-1.0, 1.0]:
		_wall_moulding(_cornice_profile(), Vector3(side * w, HALL_WALL_HEIGHT - 0.15, -46.0), 108.0, side)
		_wall_moulding(_plinth_profile(), Vector3(side * w, 0.0, -46.0), 108.0, side)

	# Scarlet lancet windows in the left wall: Poe's black chamber.
	for wz: float in HALL_WINDOW_Z:
		_lancet_window(wall_l, -w - 0.5, wz, 1.7, 3.2, 3.4, 1.7, -1.0)

	# Right wall: candle sconces between piers, scarlet drapes in some bays.
	for wz: float in HALL_WINDOW_Z:
		var s := CastleProps.sconce(1.4, 7.0)
		s.position = Vector3(w, 3.1, wz)
		s.rotation.y = -PI * 0.5
		_root.add_child(s)
	for dz: float in [-12.0, -44.0, -76.0]:
		var drape := CastleProps.curtain(2.6, 9.25, DRAPE_RED, 7.0, dz)
		drape.position = Vector3(w - 0.12, 9.4, dz)
		drape.rotation.y = -PI * 0.5
		_root.add_child(drape)

	# Three iron chandeliers hang from the vault.
	for cz: float in [-12.0, -44.0, -76.0]:
		var ch := CastleProps.chandelier(1.3, 10, 7.2, 3.2, 15.0)
		ch.position = Vector3(0.0, HALL_WALL_HEIGHT + VAULT_RISE, cz)
		_root.add_child(ch)

	# Sealed entrance doors behind the spawn point.
	var doors := CastleProps.great_doors(4.2, 4.6, 2.3)
	doors.position = Vector3(0.0, 0.0, 8.0)
	doors.rotation.y = PI
	_root.add_child(doors)
	for sx: float in [-3.4, 3.4]:
		var s := CastleProps.sconce(1.6, 7.0)
		s.position = Vector3(sx, 3.2, 8.0)
		s.rotation.y = PI
		_root.add_child(s)

	# z -20: stone balustrade across the right half (jump it).
	_collider("Hurdle", Vector3(w * 0.5, 0.35, -20.0), Vector3(w, 0.7, 0.6))
	var bal := CastleProps.balustrade(w, 0.7, 0.6)
	bal.position = Vector3(w * 0.5, 0.0, -20.0)
	_root.add_child(bal)

	# z -30: half-lowered portcullis across the left half (slide under it).
	_collider("SlideGate", Vector3(-w * 0.5, 5.6, -30.0), Vector3(w, 8.9, 1.0))
	_box("GatePier", Vector3(-0.3, 5.0, -30.0), Vector3(0.6, 10.0, 1.2), dressed)
	var gate := CastleProps.portcullis(w - 0.6, HALL_WALL_HEIGHT - 1.15)
	gate.position = Vector3(-w * 0.5 - 0.3, 1.15, -30.0)
	_root.add_child(gate)

	# z -45..-80: ramp up to a stone dais, then a long ramp down.
	_ramp("RampUp", -45.0, -55.0, 0.0, 2.0, -w, w, dressed)
	_box("Platform", Vector3(0.0, 1.0, -60.0), Vector3(2.0 * w, 2.0, 10.0), dressed)
	_ramp("RampDown", -65.0, -80.0, 2.0, 0.0, -w, w, dressed)

	# z -85..-95: low passage on the left (1.2 m) under a heavy oak lintel.
	var dark := CastleMaterials.stone_dark()
	_box("TunnelRoof", Vector3(-5.0, 5.6, -90.0), Vector3(6.0, 8.8, 10.0), dark)
	_box("TunnelDivider", Vector3(-1.75, 5.0, -90.0), Vector3(0.5, 10.0, 10.0), dark)
	for lz: float in [-84.85, -95.15]:
		_add_mesh("Lintel", _box_mesh(Vector3(6.0, 0.32, 0.36)), CastleMaterials.wood_horizontal(), Vector3(-5.0, 1.36, lz))

	var dust := TimeScaledParticles.create_dust(Vector3(w, 5.0, 52.0), 260)
	_root.add_child(dust)
	dust.position = Vector3(0.0, 5.0, -48.0)


# --- Door gallery -----------------------------------------------------------------------

func _build_door_gallery() -> void:
	var cw := CORRIDOR_HALF_WIDTH
	var length := HALL_END - CORRIDOR_END
	var mid_z := (HALL_END + CORRIDOR_END) * 0.5
	var dark := CastleMaterials.stone_dark()
	_wall_with_doorway("HallEnd", HALL_END, HALL_HALF_WIDTH, 10.0, CastleMaterials.stone())
	_box("CorridorWallL", Vector3(-cw - 0.5, CORRIDOR_HEIGHT * 0.5, mid_z), Vector3(1.0, CORRIDOR_HEIGHT, length), dark)
	_box("CorridorWallR", Vector3(cw + 0.5, CORRIDOR_HEIGHT * 0.5, mid_z), Vector3(1.0, CORRIDOR_HEIGHT, length), dark)
	_box("CorridorCeiling", Vector3(0.0, CORRIDOR_HEIGHT + 0.3, mid_z), Vector3(2.0 * cw + 2.0, 0.6, length), CastleMaterials.wood_horizontal())
	# Flagstones over the marble in the passage (visual skin, 1.5 cm).
	_add_mesh("Flags", _box_mesh(Vector3(2.0 * cw, 0.015, length)), dark, Vector3(0.0, 0.0075, mid_z))
	# Oak beams under the ceiling, clear of the partitions.
	var bz := HALL_END - 1.25
	while bz > CORRIDOR_END + 0.5:
		var near_partition := false
		for dz: float in DOOR_Z:
			if absf(bz - dz) < 0.7:
				near_partition = true
		if not near_partition:
			_add_mesh("Beam", _box_mesh(Vector3(2.0 * cw, 0.26, 0.24)), CastleMaterials.wood(), Vector3(0.0, CORRIDOR_HEIGHT - 0.13, bz))
		bz -= 2.5

	for i in DOOR_Z.size():
		var dz: float = DOOR_Z[i]
		if i > 0:
			_wall_with_doorway("Partition%d" % i, dz, cw, CORRIDOR_HEIGHT, dark)
		for face: float in [1.0, -1.0]:
			var frame := CastleProps.door_frame(DOOR_WIDTH, DOOR_HEIGHT)
			frame.position = Vector3(0.0, 0.0, dz + face * 0.5)
			frame.rotation.y = 0.0 if face > 0.0 else PI
			_root.add_child(frame)
		var door := DOOR_SCENE.instantiate()
		door.name = "Door%d" % i
		_root.add_child(door)
		door.position = Vector3(0.0, 0.0, dz)
		# A lantern in each bay, alternating sides.
		if i < DOOR_Z.size():
			var side := 1.0 if i % 2 == 0 else -1.0
			var s := CastleProps.sconce(1.8, 8.0)
			s.position = Vector3(side * cw, 2.7, dz - 7.5)
			s.rotation.y = -side * PI * 0.5
			_root.add_child(s)
	_omni(Vector3(0.0, 1.2, -153.0), Palette.RED_HOT, 2.2, 8.0)
	for sx: float in [-2.6, 2.6]:
		var s := CastleProps.sconce(1.8, 7.0)
		s.position = Vector3(sx, 3.0, HALL_END + 0.5)
		_root.add_child(s)


# --- Ballroom ----------------------------------------------------------------------------

func _build_ballroom() -> void:
	var aw := ARENA_HALF_WIDTH
	var depth := CORRIDOR_END - ARENA_END
	var mid_z := (CORRIDOR_END + ARENA_END) * 0.5
	var stone := CastleMaterials.stone()
	_wall_with_doorway("ArenaFront", CORRIDOR_END, aw, ARENA_HEIGHT, stone, CORRIDOR_HALF_WIDTH * 2.0, CORRIDOR_HEIGHT)
	var wall_l := _box("ArenaWallL", Vector3(-aw - 0.5, 6.0, mid_z), Vector3(1.0, ARENA_HEIGHT, depth), stone)
	var wall_r := _box("ArenaWallR", Vector3(aw + 0.5, 6.0, mid_z), Vector3(1.0, ARENA_HEIGHT, depth), stone)
	_box("ArenaBack", Vector3(0.0, 6.0, ARENA_END - 0.5), Vector3(2.0 * aw + 2.0, ARENA_HEIGHT, 1.0), stone)
	for p: Vector2 in [Vector2(-8.0, -172.0), Vector2(8.0, -172.0), Vector2(-8.0, -188.0), Vector2(8.0, -188.0)]:
		_cylinder_collider("ArenaPillar", Vector3(p.x, ARENA_HEIGHT * 0.5, p.y), 0.72, ARENA_HEIGHT)
		var col := CastleProps.column(ARENA_HEIGHT, 0.6)
		col.position = Vector3(p.x, 0.0, p.y)
		_root.add_child(col)

	for wz: float in [-170.0, -190.0]:
		_lancet_window(wall_l, -aw - 0.5, wz, 2.2, 3.4, 5.0, 2.0, -1.0)
		_lancet_window(wall_r, aw + 0.5, wz, 2.2, 3.4, 5.0, 2.0, 1.0)
	for side: float in [-1.0, 1.0]:
		_wall_moulding(_plinth_profile(), Vector3(side * aw, 0.0, mid_z), depth, side)
		_wall_moulding(_cornice_profile(), Vector3(side * aw, ARENA_HEIGHT - 0.2, mid_z), depth, side)

	# Dark coffered timber ceiling.
	_add_mesh("Ceiling", _box_mesh(Vector3(2.0 * aw, 0.2, depth)), CastleMaterials.wood_horizontal(),
			Vector3(0.0, ARENA_HEIGHT + 0.1, mid_z))
	var cx := -aw + 4.0
	while cx < aw:
		_add_mesh("CeilBeam", _box_mesh(Vector3(0.35, 0.45, depth)), CastleMaterials.wood(), Vector3(cx, ARENA_HEIGHT - 0.22, mid_z))
		cx += 4.0
	var cz := CORRIDOR_END - 4.0
	while cz > ARENA_END:
		_add_mesh("CeilBeam", _box_mesh(Vector3(2.0 * aw, 0.35, 0.3)), CastleMaterials.wood(), Vector3(0.0, ARENA_HEIGHT - 0.17, cz))
		cz -= 4.0

	# Scarlet drapes flanking the entrance.
	for sx: float in [-5.2, 5.2]:
		var drape := CastleProps.curtain(3.0, 11.0, DRAPE_RED, 8.0, sx)
		drape.position = Vector3(sx, 11.2, CORRIDOR_END - 0.6)
		drape.rotation.y = PI
		_root.add_child(drape)

	var chandelier := CastleProps.chandelier(2.6, 18, 4.5, 6.0, 24.0)
	chandelier.position = Vector3(0.0, ARENA_HEIGHT, -180.0)
	_root.add_child(chandelier)

	var clock := PendulumClock.new()
	clock.name = "PendulumClock"
	_root.add_child(clock)
	clock.position = Vector3(0.0, 8.0, ARENA_END + 0.15)
	var clock_light := SpotLight3D.new()
	clock_light.light_color = Palette.PAPER
	clock_light.light_energy = 7.0
	clock_light.spot_range = 16.0
	clock_light.spot_angle = 20.0
	_root.add_child(clock_light)
	clock_light.position = Vector3(0.0, 11.0, ARENA_END + 10.0)
	clock_light.look_at_from_position(clock_light.position, Vector3(0.0, 8.0, ARENA_END), Vector3.UP)
	_omni(Vector3(0.0, 0.6, ARENA_END + 3.0), Palette.RED_HOT, 2.5, 9.0)

	var dust := TimeScaledParticles.create_dust(Vector3(aw, 5.0, depth * 0.5), 260)
	_root.add_child(dust)
	dust.position = Vector3(0.0, 5.0, mid_z)


# --- Architectural helpers ------------------------------------------------------------------

## A pointed window cut through `wall` (a CSGBox3D spanning x around wall_x),
## filled with scarlet glass, framed in stone on the inside, with a red shaft
## of light falling in from outside. `side` = -1 left wall, +1 right wall.
func _lancet_window(wall: CSGBox3D, wall_x: float, z: float, width: float, sill: float,
		straight: float, rise: float, side: float) -> void:
	var cut := CSGPolygon3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.polygon = MeshKit.pointed_arch_opening(width, straight, rise, 14)
	cut.mode = CSGPolygon3D.MODE_DEPTH
	cut.depth = 2.0
	cut.rotation.y = PI * 0.5
	cut.position = Vector3(wall_x + 1.0, sill, z) - wall.position
	wall.add_child(cut)
	# Invisible pane so nothing passes through the opening.
	_collider("WindowPane", Vector3(wall_x, sill + (straight + rise) * 0.5, z), Vector3(0.1, straight + rise, width))
	var glass := CastleProps.lancet_glass(width, straight, rise)
	glass.rotation.y = PI * 0.5
	glass.position = Vector3(wall_x - side * 0.2, sill, z)
	_root.add_child(glass)
	var frame := CastleProps.arch_frame(width, straight, rise)
	frame.rotation.y = -side * PI * 0.5
	frame.position = Vector3(wall_x - side * 0.5, sill, z)
	_root.add_child(frame)
	_add_mesh("Sill", _box_mesh(Vector3(0.36, 0.12, width + 0.5)), CastleMaterials.stone_dressed(),
			Vector3(wall_x - side * 0.62, sill - 0.06, z))
	if window_shafts:
		var shaft := SpotLight3D.new()
		shaft.light_color = Color(1.0, 0.12, 0.08)
		shaft.light_energy = 9.0
		shaft.spot_range = 30.0
		shaft.spot_angle = 14.0
		shaft.spot_attenuation = 0.5
		shaft.shadow_enabled = true
		shaft.light_volumetric_fog_energy = 2.5
		_root.add_child(shaft)
		var from := Vector3(wall_x + side * 6.0, sill + straight + rise + 4.0, z + 1.0)
		var to := Vector3(wall_x - side * 7.0, 0.0, z - 1.0)
		shaft.look_at_from_position(from, to, Vector3.UP)


func _cornice_profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, -0.4), Vector2(0.05, -0.36), Vector2(0.07, -0.22),
			Vector2(0.15, -0.12), Vector2(0.24, -0.02), Vector2(0.28, 0.08), Vector2(0.3, 0.15), Vector2(0.0, 0.15)])


func _plinth_profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.22),
			Vector2(0.1, 0.3), Vector2(0.06, 0.34), Vector2(0.0, 0.36)])


## Run a moulding along a wall that lies along Z at x = at.x, facing the
## hall interior (side -1 = left wall facing +X, +1 = right wall facing -X).
func _wall_moulding(profile: PackedVector2Array, at: Vector3, length: float, side: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.straight_moulding(profile, length)
	mi.material_override = CastleMaterials.stone_dressed()
	mi.position = at
	mi.rotation.y = -side * PI * 0.5
	_root.add_child(mi)


func _straight_z(profile: PackedVector2Array, length: float) -> ArrayMesh:
	return MeshKit.sweep(profile, PackedVector3Array([Vector3(0, 0, length * 0.5), Vector3(0, 0, -length * 0.5)]), Vector3.UP)


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _add_mesh(node_name: String, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	_root.add_child(mi)
	return mi


# --- Collision + geometry primitives -------------------------------------------------------

func _box(node_name: String, center: Vector3, size: Vector3, material: Material, collide: bool = true) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = center
	b.material = material
	b.use_collision = collide
	b.collision_layer = 1
	b.collision_mask = 0
	_root.add_child(b)
	return b


## Invisible world collision (for pieces whose visuals are separate meshes).
func _collider(node_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_root.add_child(body)
	return body


func _cylinder_collider(node_name: String, center: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	body.position = center
	_root.add_child(body)
	return body


## A wall across the Z axis spanning [-half_width, half_width] with a centred
## opening of `opening_width` x `opening_height`.
func _wall_with_doorway(node_name: String, z: float, half_width: float, wall_height: float, material: Material,
		opening_width: float = DOOR_WIDTH, opening_height: float = DOOR_HEIGHT) -> void:
	var ow := opening_width * 0.5
	var side_w := half_width - ow
	if side_w > 0.0:
		_box(node_name + "L", Vector3(-ow - side_w * 0.5, wall_height * 0.5, z), Vector3(side_w, wall_height, 1.0), material)
		_box(node_name + "R", Vector3(ow + side_w * 0.5, wall_height * 0.5, z), Vector3(side_w, wall_height, 1.0), material)
	var top_h := wall_height - opening_height
	if top_h > 0.0:
		_box(node_name + "Top", Vector3(0.0, opening_height + top_h * 0.5, z), Vector3(opening_width, top_h, 1.0), material)


## Solid ramp along -Z from (z0, y0) to (z1, y1) spanning x0..x1.
func _ramp(node_name: String, z0: float, z1: float, y0: float, y1: float, x0: float, x1: float, material: Material) -> void:
	var thickness := 0.5
	var dz := z0 - z1
	var dy := y1 - y0
	var length := sqrt(dz * dz + dy * dy)
	var angle := atan2(dy, dz)
	var normal := Vector3(0.0, cos(angle), sin(angle))
	var top_mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var b := _box(node_name, top_mid - normal * thickness * 0.5, Vector3(x1 - x0, thickness, length), material)
	b.rotation.x = angle
	# The wedge beneath the ramp is sealed by the hall walls and the platform.


func _omni(at: Vector3, color: Color, energy: float, omni_range: float) -> void:
	var o := OmniLight3D.new()
	o.position = at
	o.light_color = color
	o.light_energy = energy
	o.omni_range = omni_range
	o.shadow_enabled = false
	_root.add_child(o)
