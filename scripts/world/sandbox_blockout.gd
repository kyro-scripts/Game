@tool
class_name SandboxBlockout
extends Node3D
## The Phase A/B sandbox, rebuilt as an impossible, minimal dream-castle.
## Built from code (seeded: the run seed varies its inconsistencies), so the
## layout is easy to read, tweak and diff. Generated nodes are not saved into
## the scene but show in the editor (@tool).
##
## Black dominates. White defines the shapes you need: faces, edges, doors,
## light. Red is rare and means danger or the Red Death.
##
## Sequence (player starts in the vestibule looking toward -Z):
##   VESTIBULE     crooked, low room; a tall slit leads on
##   THE NARROWING twisting corridor that tightens, ceiling sinking  -> JUMP the beam
##   THE LONG HALL massive, empty, black. 11 identical doors leak light along
##                 one wall; a black MONOLITH with a slot (SLIDE under it);
##                 a DAIS (slide downhill); one high red window; a door
##                 nine metres up the wall; a white chair that moves when
##                 you aren't looking; the far wall has a long LOW SLOT
##   LOW CHAMBER   ceiling at 2.9 m after the hall's thirty
##   THE REPEATING CORRIDOR  four identical bays, four BREACHABLE DOORS;
##                 each bay is the same, except when it isn't
##   CLOCK CHAMBER irregular room, warped checkerboard, leaning pillars,
##                 a pillar that hangs from nothing, the pendulum clock

const DOOR_SCENE := preload("res://scenes/world/breachable_door.tscn")
const DOOR_Z := [-150.0, -165.0, -180.0, -195.0]
const GALLERY_HALF := 1.6
const GALLERY_HEIGHT := 4.0
const WALL_T := 0.5
const EDGE_ENERGY := 0.45

@export var rebuild_in_editor: bool = false:
	set(v):
		rebuild_in_editor = false
		if v:
			build()
## 0 = use the run seed.
@export var level_seed: int = 0
## Shadowed light shafts (the red window, overhead pools).
@export var window_shafts: bool = true

var _root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	build()


func build() -> void:
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Generated"
	add_child(_root)
	var seed := level_seed
	if seed == 0 and not Engine.is_editor_hint() and RunManager.run_seed != 0:
		seed = RunManager.run_seed
	_rng.seed = seed if seed != 0 else 1
	_box("Floor", Vector3(0.0, -0.5, -121.0), Vector3(44.0, 1.0, 262.0), CastleMaterials.lacquer())
	_build_vestibule()
	_build_narrowing()
	_build_long_hall()
	_build_low_chamber()
	_build_repeating_corridor()
	_build_clock_chamber()


# --- Vestibule ---------------------------------------------------------------------------

func _build_vestibule() -> void:
	var black := CastleMaterials.paint_black()
	_wall("VestBack", Vector2(-4.5, 7.5), Vector2(5.5, 7.5), 6.0, black)
	_wall("VestLeft", Vector2(-4.5, 7.5), Vector2(-3.6, -3.0), 6.0, black)
	_wall("VestRight", Vector2(5.5, 7.5), Vector2(5.0, -3.0), 6.0, black)
	# The front wall rises far above the ceiling; the slit goes all the way up.
	_wall("VestFrontL", Vector2(-3.6, -3.0), Vector2(-0.7, -3.0), 9.0, black)
	_wall("VestFrontR", Vector2(0.9, -3.0), Vector2(5.0, -3.0), 9.0, black)
	_box("VestCeiling", Vector3(0.5, 3.25, 2.65), Vector3(10.2, 0.3, 9.9), black)
	_edge_line(Vector3(-0.7, 0.0, -2.75), Vector3(-0.7, 7.5, -2.75), 0.6)
	_edge_line(Vector3(0.9, 0.0, -2.75), Vector3(0.9, 7.5, -2.75), 0.6)
	# The door you came in by is too small to have fitted through.
	var entry := CastleProps.fake_door(0.95, 1.95)
	entry.position = Vector3(1.6, 0.0, 7.25)
	entry.rotation.y = PI
	_root.add_child(entry)
	var bulb := CastleProps.bare_bulb(0.9)
	bulb.position = Vector3(-1.6, 3.1, 2.6)
	_root.add_child(bulb)


# --- The Narrowing ------------------------------------------------------------------------

func _build_narrowing() -> void:
	var pts: Array[Vector2] = [Vector2(0.1, -2.9), Vector2(0.1, -14.0), Vector2(2.7, -26.0), Vector2(1.0, -36.3)]
	var widths: Array[float] = [3.4, 3.2, 2.9, 2.8]
	var ceilings: Array[float] = [4.5, 3.8, 3.25]
	_corridor("Narrowing", pts, widths, ceilings, CastleMaterials.paint_charcoal())
	# A beam across the corridor, edged in white: jump it.
	_box("Hurdle", Vector3(0.1, 0.35, -9.5), Vector3(3.4, 0.7, 0.5), CastleMaterials.paint_charcoal())
	_add_mesh("HurdleEdge", _box_mesh(Vector3(3.4, 0.025, 0.52)), CastleMaterials.light_line(Color(0.9, 0.89, 0.86), 1.2),
			Vector3(0.1, 0.712, -9.5))
	var b1 := CastleProps.bare_bulb(1.3)
	b1.position = Vector3(0.9, 4.45, -7.0)
	_root.add_child(b1)
	# The long middle stretch is unlit except for light leaking under a door.
	var mid := pts[1].lerp(pts[2], 0.55)
	var dir := (pts[2] - pts[1]).normalized()
	var n := Vector2(-dir.y, dir.x)
	var door_at := mid - n * (widths[1] * 0.5 - 0.01)
	var side_door := CastleProps.fake_door(0.9, 2.1)
	side_door.position = Vector3(door_at.x, 0.0, door_at.y)
	side_door.rotation.y = atan2(n.x, -n.y) + PI
	_root.add_child(side_door)
	_under_door_glow(Vector3(door_at.x, 0.05, door_at.y) - Vector3(n.x, 0.0, n.y) * -0.4)
	var b2 := CastleProps.bare_bulb(0.8, 4.0, 8.0, 0.35)
	b2.position = Vector3(1.6, 3.25, -31.0)
	_root.add_child(b2)


# --- The Long Hall ------------------------------------------------------------------------

func _build_long_hall() -> void:
	var black := CastleMaterials.paint_black()
	var h := 34.0
	_wall("HallEntryL", Vector2(-15.5, -36.25), Vector2(-0.6, -36.25), h, black)
	_wall("HallEntryR", Vector2(2.6, -36.25), Vector2(17.5, -36.25), h, black)
	_box("HallEntryTop", Vector3(1.0, 3.25 + (h - 3.25) * 0.5, -36.25), Vector3(3.2, h - 3.25, WALL_T), black)
	var wall_l := _wall("HallLeft", Vector2(-15.25, -36.0), Vector2(-15.25, -128.5), h, black)
	var wall_r := _wall("HallRight", Vector2(17.25, -36.0), Vector2(17.25, -128.5), h, black)
	# Far wall, six metres thick, with a long low slot (slide) and a doorway.
	var ez := -131.0
	_box("HallEndA", Vector3(-12.25, h * 0.5, ez), Vector3(6.5, h, 6.0), black)
	_box("HallEndB", Vector3(-6.0, 1.2 + (h - 1.2) * 0.5, ez), Vector3(6.0, h - 1.2, 6.0), black)
	_box("HallEndC", Vector3(0.0, h * 0.5, ez), Vector3(6.0, h, 6.0), black)
	_box("HallEndD", Vector3(4.3, 4.2 + (h - 4.2) * 0.5, ez), Vector3(2.6, h - 4.2, 6.0), black)
	_box("HallEndE", Vector3(11.55, h * 0.5, ez), Vector3(11.9, h, 6.0), black)
	_edge_line(Vector3(-9.0, 1.2, -127.98), Vector3(-3.0, 1.2, -127.98), EDGE_ENERGY * 2.0)
	_edge_line(Vector3(3.0, 0.0, -127.98), Vector3(3.0, 4.2, -127.98), EDGE_ENERGY)
	_edge_line(Vector3(5.6, 0.0, -127.98), Vector3(5.6, 4.2, -127.98), EDGE_ENERGY)

	# The monolith: black, enormous, with a slot along its base. Slide under.
	_box("Monolith", Vector3(1.0, 1.15 + 24.85 * 0.5, -52.0), Vector3(7.0, 24.85, 1.6), black)
	for fz: float in [-51.19, -52.81]:
		_add_mesh("SlotEdge", _box_mesh(Vector3(7.0, 0.03, 0.02)), CastleMaterials.light_line(Color(0.9, 0.89, 0.86), 1.6),
				Vector3(1.0, 1.14, fz))

	# The dais: one solid profile (ramp up, plateau, long ramp down).
	var dais := CSGPolygon3D.new()
	dais.name = "Dais"
	dais.polygon = PackedVector2Array([Vector2(68.0, 0.0), Vector2(76.0, 2.0), Vector2(86.0, 2.0), Vector2(102.0, 0.0)])
	dais.mode = CSGPolygon3D.MODE_DEPTH
	dais.depth = 16.0
	dais.rotation.y = PI * 0.5
	dais.position = Vector3(9.0, 0.0, 0.0)
	dais.material = CastleMaterials.paint_charcoal()
	dais.use_collision = true
	dais.collision_layer = 1
	dais.collision_mask = 0
	_root.add_child(dais)
	for ex: float in [-7.0, 9.0]:
		_edge_line(Vector3(ex, 0.0, -68.0), Vector3(ex, 2.0, -76.0), EDGE_ENERGY)
		_edge_line(Vector3(ex, 2.0, -76.0), Vector3(ex, 2.0, -86.0), EDGE_ENERGY)
		_edge_line(Vector3(ex, 2.0, -86.0), Vector3(ex, 0.0, -102.0), EDGE_ENERGY)

	# Eleven identical doors along the left wall, each leaking light. One is
	# lifted off the floor, one is missing. They all lead nowhere.
	var lifted := _rng.randi_range(2, 9)
	var missing := (lifted + _rng.randi_range(2, 6)) % 11
	for i in 11:
		var z := -44.0 - float(i) * 8.0
		if i == missing:
			_add_mesh("MissingDoor", _box_mesh(Vector3(0.04, 4.4, 1.15)), CastleMaterials.void_black(), Vector3(-14.98, 2.2, z))
			continue
		var fd := CastleProps.fake_door(1.15, 4.4)
		fd.rotation.y = PI * 0.5
		var lift := 0.7 if i == lifted else 0.0
		fd.position = Vector3(-14.99, lift, z)
		_root.add_child(fd)
		_under_door_glow(Vector3(-14.6, lift + 0.05, z))

	# A door nine metres up the right wall.
	var high := CastleProps.fake_door(1.15, 2.3)
	high.rotation.y = -PI * 0.5
	high.position = Vector3(16.99, 9.0, -61.0)
	_root.add_child(high)

	# The only colour in the hall: one irregular red window, very high, with
	# jagged black forms against it and a red shaft falling across the dark.
	_red_window(wall_r, 17.25, -90.0)

	# Isolated pools of white light from far overhead; nothing in between.
	# The first pool falls behind the monolith, so it stands as a silhouette.
	var pools := [Vector3(-9.0, 32.0, -46.0), Vector3(1.0, 32.0, -58.0), Vector3(-6.5, 32.0, -70.0),
			Vector3(-3.5, 32.0, -86.0), Vector3(10.0, 32.0, -110.0), Vector3(-7.0, 32.0, -121.0)]
	for p: Vector3 in pools:
		var s := CastleProps.light_pool(p.y, 12.0, 12.0 + _rng.randf_range(-2.0, 2.0), window_shafts)
		s.position = p
		_root.add_child(s)

	# A white chair that is never where you left it.
	var chair := UnseenShifter.new()
	chair.name = "WhiteChair"
	chair.spots = PackedVector3Array([Vector3(-10.0, 0.0, -70.0), Vector3(12.0, 0.0, -96.0), Vector3(-6.0, 0.0, -118.0),
			Vector3(11.0, 0.0, -44.0), Vector3(-11.0, 0.0, -104.0)])
	chair.add_child(CastleProps.white_chair())
	_root.add_child(chair)
	chair.position = chair.spots[_rng.randi() % chair.spots.size()]
	chair.rotation.y = _rng.randf_range(-PI, PI)

	var tick := DistantClock.new()
	tick.position = Vector3(-12.0, 3.0, -126.0)
	_root.add_child(tick)
	for m: Vector3 in [Vector3(-9.0, 0.0, -122.0), Vector3(13.0, 0.0, -112.0), Vector3(-11.0, 0.0, -66.0)]:
		_marker(m)

	var dust := TimeScaledParticles.create_dust(Vector3(16.0, 10.0, 46.0), 320)
	_root.add_child(dust)
	dust.position = Vector3(1.0, 8.0, -82.0)


func _red_window(wall: CSGBox3D, wall_x: float, z: float) -> void:
	var width := 3.0
	var sill := 18.0
	var outline := MeshKit.irregular_arch_opening(width, 9.0, 3.2, 0.4, 0.25, 12)
	var cut := CSGPolygon3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.polygon = outline
	cut.mode = CSGPolygon3D.MODE_DEPTH
	cut.depth = 2.0
	# The wall is a rotated box: express the cut in the wall's local frame.
	var world := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(wall_x + 1.0, sill, z))
	cut.transform = wall.transform.affine_inverse() * world
	wall.add_child(cut)
	var glass := MeshInstance3D.new()
	glass.mesh = MeshKit.extrude_polygon(outline, 0.02)
	glass.material_override = CastleMaterials.stained_glass()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.rotation.y = PI * 0.5
	glass.position = Vector3(wall_x + 0.1, sill, z)
	_root.add_child(glass)
	var forms := CastleProps.jagged_cluster(6, 3.2, _rng.randi())
	forms.rotation.y = -PI * 0.5
	forms.position = Vector3(wall_x - 0.3, sill + 4.5, z)
	_root.add_child(forms)
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(1.0, 0.1, 0.06)
	shaft.light_energy = 22.0
	shaft.spot_range = 60.0
	shaft.spot_angle = 7.0
	shaft.spot_attenuation = 0.3
	shaft.shadow_enabled = window_shafts
	shaft.light_volumetric_fog_energy = 3.0
	_root.add_child(shaft)
	shaft.look_at_from_position(Vector3(wall_x + 10.0, sill + 14.0, z + 1.0), Vector3(-4.0, 0.0, z - 3.0), Vector3.UP)


# --- Low chamber ----------------------------------------------------------------------------

func _build_low_chamber() -> void:
	var black := CastleMaterials.paint_black()
	_wall("LowLeft", Vector2(-10.25, -134.0), Vector2(-10.25, -146.5), 4.6, black)
	_wall("LowRight", Vector2(7.25, -134.0), Vector2(7.25, -146.5), 4.6, black)
	_wall("LowFrontL", Vector2(-10.5, -146.25), Vector2(-GALLERY_HALF, -146.25), 4.6, black)
	_wall("LowFrontR", Vector2(GALLERY_HALF, -146.25), Vector2(7.5, -146.25), 4.6, black)
	_box("LowCeiling", Vector3(-1.5, 3.05, -140.1), Vector3(17.8, 0.3, 12.5), black)
	# A pillar far too thin for the weight it seems to carry.
	_cylinder_collider("ThinPillar", Vector3(-4.6, 1.45, -139.5), 0.2, 2.9)
	_add_mesh("ThinPillar", _cyl_mesh(0.17, 2.9), CastleMaterials.paint_white(), Vector3(-4.6, 1.45, -139.5))
	var bulb := CastleProps.bare_bulb(0.55)
	bulb.position = Vector3(2.4, 2.9, -140.5)
	_root.add_child(bulb)


# --- The repeating corridor -------------------------------------------------------------------

func _build_repeating_corridor() -> void:
	var black := CastleMaterials.paint_charcoal()
	var gw := GALLERY_HALF
	var z0 := -146.25
	var z1 := -206.5
	_wall("GalleryL", Vector2(-gw - WALL_T * 0.5, z0), Vector2(-gw - WALL_T * 0.5, z1), GALLERY_HEIGHT + 0.4, black)
	_wall("GalleryR", Vector2(gw + WALL_T * 0.5, z0), Vector2(gw + WALL_T * 0.5, z1), GALLERY_HEIGHT + 0.4, black)
	_box("GalleryCeiling", Vector3(0.0, GALLERY_HEIGHT + 0.2, (z0 + z1) * 0.5), Vector3(2.0 * gw + 1.0, 0.4, z0 - z1), black)
	for side: float in [-1.0, 1.0]:
		_edge_line(Vector3(side * (gw - 0.02), 0.0, z0), Vector3(side * (gw - 0.02), 0.0, z1), EDGE_ENERGY)

	# Four bays, identical... except one has its light on the wrong side and
	# guttering, one is dark, one has its side door on the other wall, and
	# one door has a face on it.
	var wrong_light := _rng.randi_range(0, 3)
	var dark_bay := (wrong_light + 1 + _rng.randi_range(0, 2)) % 4
	var wrong_door := _rng.randi_range(0, 3)
	var face_door := _rng.randi_range(1, 3)
	for i in DOOR_Z.size():
		var dz: float = DOOR_Z[i]
		_box("Partition%dL" % i, Vector3(-gw + 0.05, GALLERY_HEIGHT * 0.5, dz), Vector3(0.1, GALLERY_HEIGHT, 0.5), black)
		_box("Partition%dR" % i, Vector3(gw - 0.05, GALLERY_HEIGHT * 0.5, dz), Vector3(0.1, GALLERY_HEIGHT, 0.5), black)
		_box("Partition%dTop" % i, Vector3(0.0, 3.6 + (GALLERY_HEIGHT - 3.6) * 0.5, dz), Vector3(2.0 * gw, GALLERY_HEIGHT - 3.6, 0.5), black)
		var door := DOOR_SCENE.instantiate() as BreachableDoor
		door.name = "Door%d" % i
		door.face_on_door = i == face_door
		_root.add_child(door)
		door.position = Vector3(0.0, 0.0, dz)
		# Chalk outline around the opening on both faces.
		for face: float in [0.27, -0.27]:
			_edge_line(Vector3(-1.5, 0.0, dz + face), Vector3(-1.5, 3.6, dz + face), 0.7)
			_edge_line(Vector3(1.5, 0.0, dz + face), Vector3(1.5, 3.6, dz + face), 0.7)
			_edge_line(Vector3(-1.5, 3.6, dz + face), Vector3(1.5, 3.6, dz + face), 0.7)
		if i != dark_bay:
			var lx := 0.0 if i != wrong_light else 1.1
			var bulb := CastleProps.bare_bulb(1.0, 4.5, 8.5, 0.45 if i == wrong_light else 0.03)
			bulb.position = Vector3(lx, GALLERY_HEIGHT, dz - 6.5)
			_root.add_child(bulb)
		var side := -1.0 if i != wrong_door else 1.0
		var fd := CastleProps.fake_door(0.85, 2.0)
		fd.position = Vector3(side * (gw - 0.01), 0.0, dz - 10.0)
		fd.rotation.y = -side * PI * 0.5
		_root.add_child(fd)
		_under_door_glow(Vector3(side * (gw - 0.4), 0.05, dz - 10.0))
	_marker(Vector3(0.0, 0.0, -204.0))


# --- Clock chamber ------------------------------------------------------------------------------

func _build_clock_chamber() -> void:
	var black := CastleMaterials.paint_black()
	var poly: Array[Vector2] = [Vector2(-GALLERY_HALF - 0.25, -206.5), Vector2(-12.0, -209.0), Vector2(-19.5, -221.0),
			Vector2(-16.0, -240.0), Vector2(-4.0, -248.0), Vector2(9.0, -247.0), Vector2(20.0, -233.0),
			Vector2(17.0, -213.0), Vector2(GALLERY_HALF + 0.25, -206.5)]
	for i in poly.size() - 1:
		_wall("Chamber%d" % i, poly[i], poly[i + 1], 16.0, black)
	# Warped checkerboard: the tiles slowly swell and drift out of true.
	_add_mesh("ChamberFloor", _box_mesh(Vector3(42.0, 0.01, 44.0)), CastleMaterials.lacquer_checker(1.6), Vector3(0.5, 0.005, -227.0))

	# Pillars of the wrong sizes; one leans; one hangs from nothing.
	var pillars := [[Vector2(-7.0, -224.0), 0.35, 0.0], [Vector2(8.0, -222.0), 0.95, 0.0], [Vector2(-3.0, -238.0), 0.55, 0.06]]
	for p: Array in pillars:
		var at: Vector2 = p[0]
		var r: float = p[1]
		var lean: float = p[2]
		_cylinder_collider("Pillar", Vector3(at.x, 8.0, at.y), r + 0.05, 16.0)
		var vis := _add_mesh("Pillar", _cyl_mesh(r, 16.0), CastleMaterials.paint_charcoal(), Vector3(at.x, 8.0, at.y))
		vis.rotation.z = lean
	var hanging := _add_mesh("HangingPillar", _cyl_mesh(0.6, 13.0), CastleMaterials.paint_white(), Vector3(7.0, 3.2 + 6.5, -237.0))
	hanging.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# The clock on the far wall, framed by jagged black forms in a hard light.
	var clock := PendulumClock.new()
	clock.name = "PendulumClock"
	_root.add_child(clock)
	clock.position = Vector3(2.5, 8.0, -247.0)
	clock.rotation.y = -0.077
	var forms := CastleProps.jagged_cluster(8, 4.5, _rng.randi())
	forms.position = Vector3(2.5, 9.5, -247.15)
	_root.add_child(forms)
	var clock_light := SpotLight3D.new()
	clock_light.light_color = Color(1.0, 0.99, 0.97)
	clock_light.light_energy = 12.0
	clock_light.spot_range = 22.0
	clock_light.spot_angle = 24.0
	clock_light.shadow_enabled = window_shafts
	clock_light.add_to_group(&"atmo_light")
	_root.add_child(clock_light)
	clock_light.look_at_from_position(Vector3(2.0, 15.0, -232.0), Vector3(2.5, 8.0, -247.0), Vector3.UP)
	var centre := CastleProps.light_pool(18.0, 14.0, 24.0, window_shafts)
	centre.position = Vector3(0.5, 18.0, -227.0)
	_root.add_child(centre)
	# Red lives only near the clock: the Red Death keeps time here.
	var red := OmniLight3D.new()
	red.light_color = Palette.RED_HOT
	red.light_energy = 2.0
	red.omni_range = 7.0
	red.position = Vector3(2.5, 0.6, -244.5)
	_root.add_child(red)

	var outside := DistantClock.new()
	outside.interval = 0.93
	outside.volume_db = -24.0
	outside.position = Vector3(1.0, 3.0, -262.0)
	_root.add_child(outside)
	for m: Vector3 in [Vector3(-12.0, 0.0, -243.0), Vector3(15.0, 0.0, -217.0)]:
		_marker(m)


# --- Building blocks ----------------------------------------------------------------------------

## A wall from a to b (XZ plane; Vector2.y is world Z), centred on the line.
func _wall(node_name: String, a: Vector2, b: Vector2, height: float, material: Material,
		thickness: float = WALL_T, base_y: float = 0.0) -> CSGBox3D:
	var d := b - a
	var length := d.length()
	var mid := (a + b) * 0.5
	var box := _box(node_name, Vector3(mid.x, base_y + height * 0.5, mid.y), Vector3(length + thickness, height, thickness), material)
	box.rotation.y = atan2(-d.y, d.x)
	return box


## A corridor along a centreline with per-vertex widths (mitred joints) and
## per-segment ceilings, each tilted a few degrees off true.
func _corridor(prefix: String, pts: Array[Vector2], widths: Array[float], ceilings: Array[float], material: Material) -> void:
	var left: Array[Vector2] = []
	var right: Array[Vector2] = []
	for i in pts.size():
		var d_in := (pts[i] - pts[i - 1]).normalized() if i > 0 else (pts[1] - pts[0]).normalized()
		var d_out := (pts[i + 1] - pts[i]).normalized() if i < pts.size() - 1 else d_in
		var n_in := Vector2(-d_in.y, d_in.x)
		var n_avg := (n_in + Vector2(-d_out.y, d_out.x)).normalized()
		var miter := (widths[i] * 0.5 + WALL_T * 0.5) / maxf(n_avg.dot(n_in), 0.5)
		left.append(pts[i] + n_avg * miter)
		right.append(pts[i] - n_avg * miter)
	for i in pts.size() - 1:
		_wall("%sL%d" % [prefix, i], left[i], left[i + 1], 6.0, material)
		_wall("%sR%d" % [prefix, i], right[i], right[i + 1], 6.0, material)
		var d := pts[i + 1] - pts[i]
		var mid := (pts[i] + pts[i + 1]) * 0.5
		var w := maxf(widths[i], widths[i + 1]) + 1.2
		var c := _box("%sCeil%d" % [prefix, i], Vector3(mid.x, ceilings[i] + 0.2, mid.y), Vector3(w, 0.4, d.length() + 1.0), material)
		c.rotation = Vector3(0.0, atan2(d.x, d.y), _rng.randf_range(-0.07, 0.07))
		# Faint chalk line where floor meets wall, so the shape reads at speed.
		for side: float in [-1.0, 1.0]:
			var nn := Vector2(-d.normalized().y, d.normalized().x) * side
			var o0 := pts[i] + nn * (widths[i] * 0.5 - 0.03)
			var o1 := pts[i + 1] + nn * (widths[i + 1] * 0.5 - 0.03)
			_edge_line(Vector3(o0.x, 0.0, o0.y), Vector3(o1.x, 0.0, o1.y), EDGE_ENERGY)


## A thin line of light between two points (navigation at speed, graphic edges).
func _edge_line(a: Vector3, b: Vector3, energy: float) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(Vector3(0.025, 0.012, length))
	mi.material_override = CastleMaterials.light_line(Color(0.88, 0.87, 0.84), energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	var dir := (b - a) / length
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5 + Vector3.UP * 0.006)


func _under_door_glow(at: Vector3) -> void:
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.98, 0.95)
	o.light_energy = 0.7
	o.omni_range = 1.8
	o.omni_attenuation = 2.0
	o.position = at
	o.add_to_group(&"atmo_light")
	_root.add_child(o)


func _marker(at: Vector3) -> void:
	var m := Marker3D.new()
	m.position = at
	m.add_to_group(&"guest_sighting")
	_root.add_child(m)


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl_mesh(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 20
	return c


func _add_mesh(node_name: String, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	_root.add_child(mi)
	return mi


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
