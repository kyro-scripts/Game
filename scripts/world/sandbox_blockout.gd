@tool
class_name SandboxBlockout
extends Node3D
## Graybox movement + combat sandbox for Phases A/B, built from code so the
## layout is easy to read, tweak and diff. Generated nodes are not saved into
## the scene (no owner), but they are visible in the editor because this is a
## @tool script.
##
## Layout (player starts at z = +4 looking toward -Z):
##   SPEED HALL   z   0 .. -100  16 m wide. Pillars every 8 m for parallax,
##                               distance markers every 10 m.
##                z -20  hurdle (right half)         -> jump
##                z -30  low gate (left half)        -> slide under
##                z -45..-80  ramp up, platform, long ramp down -> slide downhill
##                z -85..-95  low tunnel (left)      -> sustained slide
##   DOOR GALLERY z -100 .. -160  tight corridor, 4 breachable doors
##   ARENA        z -160 .. -200  40 x 40 m, dummies + pendulum clock

const HALL_HALF_WIDTH := 8.0
const HALL_END := -100.0
const CORRIDOR_HALF_WIDTH := 2.5
const CORRIDOR_HEIGHT := 4.6
const CORRIDOR_END := -160.0
const ARENA_HALF_WIDTH := 20.0
const ARENA_END := -200.0
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 3.6
const DOOR_Z := [-100.0, -115.0, -130.0, -145.0]

const DOOR_SCENE := preload("res://scenes/world/breachable_door.tscn")

@export var rebuild_in_editor: bool = false:
	set(v):
		rebuild_in_editor = false
		if v:
			build()

var _root: Node3D
var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _pillar_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D
var _red_mat: StandardMaterial3D


func _ready() -> void:
	build()


func build() -> void:
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Generated"
	add_child(_root)

	_floor_mat = Palette.lit(Color(0.07, 0.068, 0.072), 0.95)
	_wall_mat = Palette.lit(Color(0.1, 0.098, 0.104), 0.9)
	_pillar_mat = Palette.lit(Palette.BONE, 0.8)
	_line_mat = Palette.lit(Color(0.2, 0.195, 0.2), 0.9)
	_red_mat = Palette.emissive(Palette.RED, 0.9)

	_build_speed_hall()
	_build_door_gallery()
	_build_arena()


# --- Sections ------------------------------------------------------------------

func _build_speed_hall() -> void:
	var w := HALL_HALF_WIDTH
	# Floor spans the hall; a single slab under everything avoids seams.
	_box("Floor", Vector3(0.0, -0.5, -100.0), Vector3(2.0 * ARENA_HALF_WIDTH + 2.0, 1.0, 220.0), _floor_mat)
	_box("HallWallL", Vector3(-w - 0.5, 5.0, -46.0), Vector3(1.0, 10.0, 108.0), _wall_mat)
	_box("HallWallR", Vector3(w + 0.5, 5.0, -46.0), Vector3(1.0, 10.0, 108.0), _wall_mat)
	_box("HallBack", Vector3(0.0, 5.0, 8.5), Vector3(2.0 * w + 2.0, 10.0, 1.0), _wall_mat)

	# Pale pillars every 8 m sell speed through parallax.
	var z := 0.0
	while z >= HALL_END + 4.0:
		for side in [-1.0, 1.0]:
			_box("Pillar", Vector3(side * (w - 0.45), 5.0, z), Vector3(0.8, 10.0, 0.8), _pillar_mat)
		z -= 8.0

	# Floor grid lines every 4 m + a red centre line.
	z = 4.0
	while z >= HALL_END:
		_box("GridLine", Vector3(0.0, 0.004, z), Vector3(2.0 * w, 0.01, 0.06), _line_mat, false)
		z -= 4.0
	_box("CentreLine", Vector3(0.0, 0.006, -46.0), Vector3(0.1, 0.01, 104.0), _red_mat, false)
	for i in range(1, 10):
		_floor_label("%d m" % (i * 10), Vector3(-w + 1.6, 0.02, -float(i) * 10.0))

	# z -20: hurdle across the right half (jump it).
	_box("Hurdle", Vector3(w * 0.5, 0.35, -20.0), Vector3(w, 0.7, 0.6), _wall_mat)
	_box("HurdleStripe", Vector3(w * 0.5, 0.71, -20.0), Vector3(w, 0.02, 0.62), _red_mat, false)
	_floor_label("JUMP", Vector3(w * 0.5, 0.02, -17.0))

	# z -30: low gate across the left half (slide under, 1.15 m clearance).
	_box("SlideGate", Vector3(-w * 0.5, 5.6, -30.0), Vector3(w, 8.9, 1.0), _wall_mat)
	_box("SlideGateEdge", Vector3(-w * 0.5, 1.13, -29.48), Vector3(w, 0.06, 0.04), _red_mat, false)
	_floor_label("SLIDE", Vector3(-w * 0.5, 0.02, -26.0))

	# z -45..-80: ramp up to a 2 m platform, then a long ramp down.
	_ramp("RampUp", -45.0, -55.0, 0.0, 2.0, -w, w)
	_box("Platform", Vector3(0.0, 1.0, -60.0), Vector3(2.0 * w, 2.0, 10.0), _wall_mat)
	_ramp("RampDown", -65.0, -80.0, 2.0, 0.0, -w, w)
	_floor_label("SLIDE DOWNHILL", Vector3(0.0, 2.02, -62.0))

	# z -85..-95: low tunnel on the left (1.2 m ceiling) for sustained slides.
	_box("TunnelRoof", Vector3(-5.0, 5.6, -90.0), Vector3(6.0, 8.8, 10.0), _wall_mat)
	_box("TunnelDivider", Vector3(-1.75, 5.0, -90.0), Vector3(0.5, 10.0, 10.0), _wall_mat)
	_box("TunnelEdge", Vector3(-5.0, 1.17, -84.98), Vector3(6.0, 0.06, 0.04), _red_mat, false)

	# Harsh pools of white light.
	z = -4.0
	while z >= HALL_END + 4.0:
		_spot(Vector3(0.0, 9.6, z), 3.2, 15.0, 38.0, Palette.PAPER, true)
		z -= 16.0
	_omni(Vector3(-w * 0.5, 1.0, -28.0), Palette.RED_HOT, 1.2, 6.0)
	_omni(Vector3(-5.0, 0.8, -84.0), Palette.RED_HOT, 1.0, 5.0)

	var dust := TimeScaledParticles.create_dust(Vector3(w, 4.0, 50.0), 220)
	_root.add_child(dust)
	dust.position = Vector3(0.0, 4.0, -50.0)


func _build_door_gallery() -> void:
	var cw := CORRIDOR_HALF_WIDTH
	var length := HALL_END - CORRIDOR_END
	var mid_z := (HALL_END + CORRIDOR_END) * 0.5
	# Hall end wall with a doorway.
	_wall_with_doorway("HallEnd", HALL_END, HALL_HALF_WIDTH, 10.0)
	_box("CorridorWallL", Vector3(-cw - 0.5, CORRIDOR_HEIGHT * 0.5, mid_z), Vector3(1.0, CORRIDOR_HEIGHT, length), _wall_mat)
	_box("CorridorWallR", Vector3(cw + 0.5, CORRIDOR_HEIGHT * 0.5, mid_z), Vector3(1.0, CORRIDOR_HEIGHT, length), _wall_mat)
	_box("CorridorCeiling", Vector3(0.0, CORRIDOR_HEIGHT + 0.3, mid_z), Vector3(2.0 * cw + 2.0, 0.6, length), _wall_mat)
	for i in DOOR_Z.size():
		var dz: float = DOOR_Z[i]
		if i > 0:
			_wall_with_doorway("Partition%d" % i, dz, cw, CORRIDOR_HEIGHT)
		var door := DOOR_SCENE.instantiate()
		door.name = "Door%d" % i
		_root.add_child(door)
		door.position = Vector3(0.0, 0.0, dz)
		if i < DOOR_Z.size() - 1:
			_omni(Vector3(0.0, CORRIDOR_HEIGHT - 0.4, dz - 7.5), Palette.PAPER, 2.0, 8.0)
	_omni(Vector3(0.0, 2.0, -152.0), Palette.RED_HOT, 2.0, 9.0)


func _build_arena() -> void:
	var aw := ARENA_HALF_WIDTH
	var depth := CORRIDOR_END - ARENA_END
	var mid_z := (CORRIDOR_END + ARENA_END) * 0.5
	_wall_with_doorway("ArenaFront", CORRIDOR_END, aw, 12.0, CORRIDOR_HALF_WIDTH * 2.0, CORRIDOR_HEIGHT)
	_box("ArenaWallL", Vector3(-aw - 0.5, 6.0, mid_z), Vector3(1.0, 12.0, depth), _wall_mat)
	_box("ArenaWallR", Vector3(aw + 0.5, 6.0, mid_z), Vector3(1.0, 12.0, depth), _wall_mat)
	_box("ArenaBack", Vector3(0.0, 6.0, ARENA_END - 0.5), Vector3(2.0 * aw + 2.0, 12.0, 1.0), _wall_mat)
	for p in [Vector2(-8.0, -172.0), Vector2(8.0, -172.0), Vector2(-8.0, -188.0), Vector2(8.0, -188.0)]:
		_box("ArenaPillar", Vector3(p.x, 6.0, p.y), Vector3(1.5, 12.0, 1.5), _pillar_mat)

	var clock := PendulumClock.new()
	clock.name = "PendulumClock"
	_root.add_child(clock)
	clock.position = Vector3(0.0, 8.0, ARENA_END + 0.15)

	_spot(Vector3(0.0, 11.5, -180.0), 4.0, 16.0, 55.0, Palette.PAPER, true)
	_omni(Vector3(0.0, 4.0, ARENA_END + 2.0), Palette.RED_HOT, 2.5, 12.0)
	_omni(Vector3(-15.0, 9.0, -175.0), Palette.PAPER, 1.4, 14.0)
	_omni(Vector3(15.0, 9.0, -185.0), Palette.PAPER, 1.4, 14.0)

	var dust := TimeScaledParticles.create_dust(Vector3(aw, 5.0, depth * 0.5), 260)
	_root.add_child(dust)
	dust.position = Vector3(0.0, 5.0, mid_z)


# --- Helpers -------------------------------------------------------------------------

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


## A wall across the Z axis spanning [-half_width, half_width] with a centred
## opening of `opening_width` x `opening_height`.
func _wall_with_doorway(node_name: String, z: float, half_width: float, wall_height: float,
		opening_width: float = DOOR_WIDTH, opening_height: float = DOOR_HEIGHT) -> void:
	var ow := opening_width * 0.5
	var side_w := half_width - ow
	if side_w > 0.0:
		_box(node_name + "L", Vector3(-ow - side_w * 0.5, wall_height * 0.5, z), Vector3(side_w, wall_height, 1.0), _wall_mat)
		_box(node_name + "R", Vector3(ow + side_w * 0.5, wall_height * 0.5, z), Vector3(side_w, wall_height, 1.0), _wall_mat)
	var top_h := wall_height - opening_height
	if top_h > 0.0:
		_box(node_name + "Top", Vector3(0.0, opening_height + top_h * 0.5, z), Vector3(opening_width, top_h, 1.0), _wall_mat)
	_box(node_name + "Lintel", Vector3(0.0, opening_height - 0.03, z + 0.52), Vector3(opening_width, 0.06, 0.04), _red_mat, false)


## Solid ramp along -Z from (z0, y0) to (z1, y1) spanning x0..x1.
func _ramp(node_name: String, z0: float, z1: float, y0: float, y1: float, x0: float, x1: float) -> void:
	var thickness := 0.5
	var dz := z0 - z1  # positive: ramp runs toward -Z
	var dy := y1 - y0
	var length := sqrt(dz * dz + dy * dy)
	var angle := atan2(dy, dz)
	var normal := Vector3(0.0, cos(angle), sin(angle))
	var top_mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var b := _box(node_name, top_mid - normal * thickness * 0.5, Vector3(x1 - x0, thickness, length), _wall_mat)
	b.rotation.x = angle
	# The wedge beneath the ramp is sealed by the hall walls and the platform.


func _floor_label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.01
	l.modulate = Color(0.55, 0.53, 0.5)
	l.outline_size = 0
	l.rotation.x = -PI * 0.5
	l.position = at
	_root.add_child(l)


func _spot(at: Vector3, energy: float, spot_range: float, angle_deg: float, color: Color, shadows: bool) -> void:
	var s := SpotLight3D.new()
	s.position = at
	s.rotation.x = -PI * 0.5
	s.light_color = color
	s.light_energy = energy
	s.spot_range = spot_range
	s.spot_angle = angle_deg
	s.spot_attenuation = 0.6
	s.shadow_enabled = shadows
	_root.add_child(s)


func _omni(at: Vector3, color: Color, energy: float, omni_range: float) -> void:
	var o := OmniLight3D.new()
	o.position = at
	o.light_color = color
	o.light_energy = energy
	o.omni_range = omni_range
	o.shadow_enabled = false
	_root.add_child(o)
