@tool
class_name CastleProps
extends RefCounted
## Builders for the castle's architecture and sparse dressing. Each returns a
## Node3D (visual only unless noted) positioned at its local origin.
## Meshes are cached so repeated pieces share GPU data.

static var _meshes: Dictionary = {}


static func _mesh(key: String, builder: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = builder.call()
	return _meshes[key]


static func _mi(mesh: Mesh, material: Material, shadows: bool = true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	if not shadows:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _box_mi(size: Vector3, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var m := _mi(bm, material)
	m.position = at
	return m


# --- Columns ------------------------------------------------------------------------

## Profile (radius, y) for a column of `height`: square-ish plinth, torus
## mouldings, a shaft with slight entasis, a bell capital and abacus.
static func _column_profile(height: float, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var base := r * 1.35
	p.append(Vector2(0.0, 0.0))
	p.append(Vector2(base, 0.0))
	p.append(Vector2(base, r * 0.35))
	p.append(Vector2(base * 0.93, r * 0.42))
	# Lower torus.
	for i in 7:
		var a := float(i) / 6.0 * PI
		p.append(Vector2(r * 1.1 + sin(a) * r * 0.16, r * 0.45 + (1.0 - cos(a)) * r * 0.14))
	p.append(Vector2(r * 1.02, r * 0.78))
	# Shaft with entasis.
	var shaft_top := height - r * 1.6
	for i in 9:
		var t := float(i) / 8.0
		var y := lerpf(r * 0.85, shaft_top, t)
		p.append(Vector2(r * (1.0 + 0.04 * sin(t * PI) - 0.08 * t), y))
	# Astragal ring.
	p.append(Vector2(r * 1.02, shaft_top + r * 0.05))
	p.append(Vector2(r * 1.02, shaft_top + r * 0.18))
	p.append(Vector2(r * 0.9, shaft_top + r * 0.22))
	# Bell capital flaring to the abacus.
	for i in 7:
		var t := float(i) / 6.0
		p.append(Vector2(lerpf(r * 0.9, r * 1.45, t * t), shaft_top + r * 0.22 + t * r * 1.0))
	p.append(Vector2(r * 1.55, height - r * 0.38))
	p.append(Vector2(r * 1.55, height))
	p.append(Vector2(0.0, height))
	return p


static func column(height: float, radius: float, material: Material = null) -> Node3D:
	var key := "column_%.2f_%.2f" % [height, radius]
	var mesh := _mesh(key, func() -> Mesh: return MeshKit.lathe(_column_profile(height, radius), 28))
	var n := Node3D.new()
	n.add_child(_mi(mesh, material if material != null else CastleMaterials.stone_dressed()))
	return n


# --- Balustrade ---------------------------------------------------------------------

static func _baluster_profile(h: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(Vector2(0.0, 0.0))
	p.append(Vector2(0.06, 0.0))
	p.append(Vector2(0.06, h * 0.08))
	p.append(Vector2(0.045, h * 0.12))
	# Vase belly.
	for i in 9:
		var t := float(i) / 8.0
		p.append(Vector2(0.03 + 0.035 * sin(t * PI * 0.9 + 0.2), h * lerpf(0.14, 0.7, t)))
	p.append(Vector2(0.025, h * 0.78))
	p.append(Vector2(0.045, h * 0.84))
	p.append(Vector2(0.055, h * 0.92))
	p.append(Vector2(0.055, h))
	p.append(Vector2(0.0, h))
	return p


## A stone balustrade along +X centred on the origin, `length` long.
static func balustrade(length: float, height: float = 0.7, depth: float = 0.5) -> Node3D:
	var n := Node3D.new()
	var mat := CastleMaterials.stone_dressed()
	var plinth_h := 0.12
	var rail_h := 0.11
	n.add_child(_box_mi(Vector3(length, plinth_h, depth), mat, Vector3(0.0, plinth_h * 0.5, 0.0)))
	n.add_child(_box_mi(Vector3(length, rail_h, depth * 0.95), mat, Vector3(0.0, height - rail_h * 0.5, 0.0)))
	var bh := height - plinth_h - rail_h
	var bmesh := _mesh("baluster_%.2f" % bh, func() -> Mesh: return MeshKit.lathe(_baluster_profile(bh), 16))
	var count := int(length / 0.32)
	for i in count:
		var x := -length * 0.5 + (float(i) + 0.5) * length / count
		var b := _mi(bmesh, mat)
		b.position = Vector3(x, plinth_h, 0.0)
		n.add_child(b)
	return n


# --- Light sources --------------------------------------------------------------------

## A church candle with a flickering flame. Returns the candle root; the
## flame node is in `flames` for FlickerLight.
static func candle(height: float, radius: float = 0.03) -> Node3D:
	var n := Node3D.new()
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(radius, 0), Vector2(radius, height * 0.95),
			Vector2(radius * 0.8, height), Vector2(radius * 0.3, height * 0.985), Vector2(0, height * 0.98)])
	n.add_child(_mi(_mesh("candle_%.2f_%.3f" % [height, radius], func() -> Mesh: return MeshKit.lathe(prof, 12)),
			CastleMaterials.wax(), false))
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.07)
	flame.mesh = q
	flame.material_override = CastleMaterials.flame()
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0.0, height + 0.03, 0.0)
	n.add_child(flame)
	return n


## Iron wall sconce with two candles and a flickering light. Mounts on a wall
## whose face points along local +Z.
static func sconce(energy: float = 1.3, light_range: float = 6.0) -> Node3D:
	var n := Node3D.new()
	var iron := CastleMaterials.iron()
	n.add_child(_box_mi(Vector3(0.12, 0.3, 0.03), iron, Vector3(0.0, 0.0, 0.015)))
	n.add_child(_box_mi(Vector3(0.03, 0.03, 0.3), iron, Vector3(0.0, -0.08, 0.16)))
	n.add_child(_box_mi(Vector3(0.36, 0.025, 0.03), iron, Vector3(0.0, -0.08, 0.3)))
	var light := FlickerLight.new()
	light.base_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.light_color = Color(1.0, 0.86, 0.68)
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.12, 0.36)
	for side: float in [-0.15, 0.15]:
		var dish := _mi(_mesh("sconce_dish", func() -> Mesh: return MeshKit.lathe(PackedVector2Array([
				Vector2(0, 0), Vector2(0.05, 0.0), Vector2(0.06, 0.02), Vector2(0.0, 0.02)]), 12)), iron)
		dish.position = Vector3(side, -0.065, 0.3)
		n.add_child(dish)
		var c := candle(0.16)
		c.position = Vector3(side, -0.045, 0.3)
		n.add_child(c)
		light.flames.append(c.get_node(^"Flame"))
	n.add_child(light)
	return n


## Iron ring chandelier hanging from a chain of `drop` metres. Origin = the
## ceiling attachment point.
static func chandelier(radius: float, candles: int, drop: float, energy: float = 4.0,
		light_range: float = 14.0, with_spot: bool = true) -> Node3D:
	var n := Node3D.new()
	var iron := CastleMaterials.iron()
	var chain := Palette.cylinder(0.02, drop, iron, 6)
	chain.position.y = -drop * 0.5
	n.add_child(chain)
	var ring_y := -drop
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.035
	t.outer_radius = radius + 0.035
	t.rings = 48
	ring.mesh = t
	ring.material_override = iron
	ring.position.y = ring_y
	n.add_child(ring)
	for k in 4:
		var a := float(k) / 4.0 * TAU
		var arm := MeshKit.sweep(MeshKit.rect_profile(0.025, 0.025), PackedVector3Array([
				Vector3(0, ring_y + radius * 0.9, 0), Vector3(cos(a) * radius, ring_y, sin(a) * radius)]))
		n.add_child(_mi(arm, iron))
	var light := FlickerLight.new()
	light.base_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.light_color = Color(1.0, 0.88, 0.72)
	light.flicker = 0.12
	light.position.y = ring_y + 0.25
	for k in candles:
		var a := float(k) / candles * TAU
		var c := candle(0.22, 0.028)
		c.position = Vector3(cos(a) * radius, ring_y + 0.03, sin(a) * radius)
		n.add_child(c)
		light.flames.append(c.get_node(^"Flame"))
	n.add_child(light)
	if with_spot:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.9, 0.78)
		spot.light_energy = energy * 1.6
		spot.spot_range = light_range * 1.3
		spot.spot_angle = 55.0
		spot.spot_attenuation = 0.8
		spot.shadow_enabled = true
		spot.rotation.x = -PI * 0.5
		spot.position.y = ring_y - 0.05
		n.add_child(spot)
	return n


# --- Openings ------------------------------------------------------------------------

## Stone architrave around a rectangular opening (in the XY plane, opening
## bottom-centre at the origin), protruding toward +Z.
static func door_frame(width: float, height: float, depth: float = 0.14) -> Node3D:
	var n := Node3D.new()
	var prof := PackedVector2Array([Vector2(-0.16, 0.0), Vector2(0.16, 0.0), Vector2(0.16, depth * 0.6),
			Vector2(0.1, depth), Vector2(-0.12, depth), Vector2(-0.16, depth * 0.7)])
	var hw := width * 0.5 + 0.16
	var top := height + 0.16
	var path := PackedVector3Array([Vector3(-hw, 0.0, 0.0), Vector3(-hw, top, 0.0), Vector3(hw, top, 0.0), Vector3(hw, 0.0, 0.0)])
	n.add_child(_mi(MeshKit.sweep(prof, path, Vector3.BACK), CastleMaterials.stone_dressed()))
	return n


## Pointed-arch moulded frame for a window or doorway (XY plane, +Z out).
static func arch_frame(width: float, spring: float, rise: float, depth: float = 0.16) -> Node3D:
	var n := Node3D.new()
	var prof := PackedVector2Array([Vector2(-0.14, 0.0), Vector2(0.14, 0.0), Vector2(0.14, depth * 0.5),
			Vector2(0.06, depth), Vector2(-0.1, depth), Vector2(-0.14, depth * 0.6)])
	var hw := width * 0.5 + 0.14
	var path := PackedVector3Array([Vector3(-hw, 0.0, 0.0)])
	for p in MeshKit.pointed_arch_curve(width + 0.28, rise + 0.14, 14):
		path.append(Vector3(p.x, p.y + spring, 0.0))
	path.append(Vector3(hw, 0.0, 0.0))
	n.add_child(_mi(MeshKit.sweep(prof, path, Vector3.BACK), CastleMaterials.stone_dressed()))
	return n


## Scarlet lancet glass filling a pointed opening (XY plane). Visual only.
static func lancet_glass(width: float, spring: float, rise: float) -> MeshInstance3D:
	var key := "lancet_%.2f_%.2f_%.2f" % [width, spring, rise]
	var mesh := _mesh(key, func() -> Mesh: return MeshKit.extrude_polygon(
			MeshKit.pointed_arch_opening(width, spring, rise, 14), 0.02))
	return _mi(mesh, CastleMaterials.stained_glass(), false)


## Iron portcullis grid in the XY plane (bottom edge at y = 0), with spikes
## hanging below the bottom bar.
static func portcullis(width: float, height: float) -> Node3D:
	var n := Node3D.new()
	var iron := CastleMaterials.iron()
	var spacing := 0.3
	var cols := int(width / spacing)
	for i in cols + 1:
		var x := -width * 0.5 + float(i) * width / cols
		n.add_child(_box_mi(Vector3(0.07, height, 0.07), iron, Vector3(x, height * 0.5, 0.0)))
	var rows := int(height / 0.55)
	for j in rows + 1:
		var y := 0.04 + float(j) * (height - 0.08) / rows
		n.add_child(_box_mi(Vector3(width, 0.06, 0.05), iron, Vector3(0.0, y, 0.04)))
	return n


static func curtain(width: float, height: float, color: Color, folds: float = 6.0, seed: float = 0.0) -> MeshInstance3D:
	var key := "curtain_%.2f_%.2f_%.1f_%.1f" % [width, height, folds, seed]
	var mesh := _mesh(key, func() -> Mesh: return MeshKit.curtain(width, height, folds, 0.09, seed))
	var mi := _mi(mesh, CastleMaterials.velvet(color, 0.0, 0.03))
	return mi


## Heavy double entrance doors with a pointed head, iron straps and rings,
## set against a wall facing +Z. Decorative (sealed).
static func great_doors(width: float, spring: float, rise: float) -> Node3D:
	var n := Node3D.new()
	var outline := MeshKit.pointed_arch_opening(width, spring, rise, 16)
	var leaf := _mi(MeshKit.extrude_polygon(outline, 0.12), CastleMaterials.wood())
	leaf.position.z = 0.06
	n.add_child(leaf)
	var iron := CastleMaterials.iron()
	for y: float in [0.5, spring * 0.5, spring - 0.4]:
		n.add_child(_box_mi(Vector3(width * 0.96, 0.09, 0.03), iron, Vector3(0.0, y, 0.135)))
	n.add_child(_box_mi(Vector3(0.05, spring + rise * 0.8, 0.03), iron, Vector3(0.0, (spring + rise * 0.8) * 0.5, 0.135)))
	for side: float in [-0.35, 0.35]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.1
		t.outer_radius = 0.13
		ring.mesh = t
		ring.material_override = iron
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(side, spring * 0.45, 0.16)
		n.add_child(ring)
	n.add_child(arch_frame(width, spring, rise, 0.22))
	return n


# --- Surreal set ------------------------------------------------------------------------

## A bare bulb on a long black cord. Origin = ceiling attachment. The light is
## short-ranged so it makes an island in the dark rather than lighting a room.
static func bare_bulb(cord: float, energy: float = 4.5, light_range: float = 8.5, flicker: float = 0.04) -> Node3D:
	var n := Node3D.new()
	var wire := Palette.cylinder(0.004, cord, CastleMaterials.void_black(), 5)
	wire.position.y = -cord * 0.5
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(wire)
	var glass := Palette.sphere(0.045, CastleMaterials.bulb(), 12)
	glass.scale = Vector3(1.0, 1.25, 1.0)
	glass.position.y = -cord - 0.05
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(glass)
	var light := FlickerLight.new()
	light.base_energy = energy
	light.flicker = flicker
	light.speed = 0.6
	light.omni_range = light_range
	light.omni_attenuation = 1.5
	light.light_color = Color(1.0, 0.98, 0.95)
	light.shadow_enabled = false
	light.position.y = -cord - 0.12
	light.add_to_group(&"atmo_light")
	n.add_child(light)
	return n


## A tight, hard-edged pool of white light falling from far overhead.
static func light_pool(height: float, energy: float = 16.0, angle: float = 13.0, shadows: bool = true) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = Color(1.0, 0.99, 0.97)
	s.light_energy = energy
	s.spot_range = height + 4.0
	s.spot_angle = angle
	s.spot_angle_attenuation = 0.35
	s.spot_attenuation = 0.2
	s.shadow_enabled = shadows
	s.light_volumetric_fog_energy = 0.7
	s.rotation.x = -PI * 0.5
	s.add_to_group(&"atmo_light")
	return s


## A door that leads nowhere: a black recess in a thin chalk frame, with a
## sliver of light underneath. Faces +Z. The sliver material is unique so the
## atmosphere can turn it red.
static func fake_door(width: float, height: float) -> Node3D:
	var n := Node3D.new()
	n.add_to_group(&"fake_door")
	var recess := _box_mi(Vector3(width, height, 0.05), CastleMaterials.void_black(), Vector3(0.0, height * 0.5, -0.02))
	n.add_child(recess)
	var white := CastleMaterials.paint_white()
	var t := 0.06
	n.add_child(_box_mi(Vector3(t, height + t, 0.05), white, Vector3(-width * 0.5 - t * 0.5, (height + t) * 0.5, 0.01)))
	n.add_child(_box_mi(Vector3(t, height + t, 0.05), white, Vector3(width * 0.5 + t * 0.5, (height + t) * 0.5, 0.01)))
	n.add_child(_box_mi(Vector3(width + 2.0 * t, t, 0.05), white, Vector3(0.0, height + t * 0.5, 0.01)))
	var sliver_mat := StandardMaterial3D.new()
	sliver_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sliver_mat.albedo_color = Color(0.95, 0.94, 0.9)
	sliver_mat.emission_enabled = true
	sliver_mat.emission = Color(0.95, 0.94, 0.9)
	sliver_mat.emission_energy_multiplier = 5.0
	var sliver := _box_mi(Vector3(width - 0.04, 0.02, 0.02), sliver_mat, Vector3(0.0, 0.012, 0.012))
	sliver.name = "Sliver"
	sliver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(sliver)
	n.set_meta(&"sliver", sliver_mat)
	return n


## A plain white chair. Nobody sits in it.
static func white_chair() -> Node3D:
	var n := Node3D.new()
	var white := CastleMaterials.paint_white()
	n.add_child(_box_mi(Vector3(0.46, 0.04, 0.44), white, Vector3(0.0, 0.46, 0.0)))
	n.add_child(_box_mi(Vector3(0.46, 0.62, 0.04), white, Vector3(0.0, 0.79, -0.2)))
	for c: Vector2 in [Vector2(-0.2, -0.19), Vector2(0.2, -0.19), Vector2(-0.2, 0.19), Vector2(0.2, 0.19)]:
		n.add_child(_box_mi(Vector3(0.035, 0.46, 0.035), white, Vector3(c.x, 0.23, c.y)))
	return n


## A cluster of jagged black brushstroke forms (unlit), for framing openings
## and the Red Death. Faces +Z.
static func jagged_cluster(count: int, size: float, seed: int) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var w := size * rng.randf_range(0.4, 1.0)
		var h := size * rng.randf_range(0.7, 1.6)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.jagged_shard(w, h, seed * 31 + i, rng.randi_range(10, 18))
		mi.material_override = CastleMaterials.void_black()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-size, size) * 0.6, rng.randf_range(-size, size) * 0.5, rng.randf_range(-0.2, 0.2))
		mi.rotation.z = rng.randf_range(-0.8, 0.8)
		n.add_child(mi)
	return n
