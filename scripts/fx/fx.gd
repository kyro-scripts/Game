class_name FX
extends RefCounted
## Static helpers that spawn short-lived placeholder effects into the current
## scene. All visuals respect the black / white / red palette.


static func scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


## A thin beam from `from` to `to` that vanishes almost instantly.
static func tracer(from: Vector3, to: Vector3, color: Color, width: float = 0.009, life: float = 0.05) -> void:
	var root := scene_root()
	var length := from.distance_to(to)
	if root == null or length < 0.05:
		return
	var holder := TransientFX.new()
	holder.lifetime = life
	holder.shrink = false
	var beam := Palette.box(Vector3(width, width, length), Palette.emissive(color, 4.0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(beam)
	root.add_child(holder)
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	holder.global_transform = Transform3D(Basis.looking_at(dir, up), (from + to) * 0.5)


## A brief point light (muzzle flash, impact glint).
static func flash_light(at: Vector3, color: Color, energy: float, light_range: float, life: float = 0.06) -> void:
	var root := scene_root()
	if root == null:
		return
	var holder := TransientFX.new()
	holder.lifetime = life
	holder.shrink = false
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	holder.add_child(light)
	root.add_child(holder)
	holder.global_position = at


## Bullet impact on world geometry: a pale spark + a few chips.
static func impact(at: Vector3, normal: Vector3, color: Color = Palette.BONE) -> void:
	var root := scene_root()
	if root == null:
		return
	var spark := TransientFX.new()
	spark.lifetime = 0.09
	spark.add_child(Palette.sphere(0.07, Palette.emissive(color, 3.0), 8))
	root.add_child(spark)
	spark.global_position = at + normal * 0.03
	var rng := RandomNumberGenerator.new()
	for i in 4:
		var chip := Debris.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * rng.randf_range(0.02, 0.05)
		chip.mesh = box
		chip.material_override = Palette.lit(Palette.ASH)
		chip.lifetime = rng.randf_range(0.5, 0.9)
		chip.fade_time = 0.3
		chip.floor_y = at.y - 3.0
		chip.velocity = (normal + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, 0.8),
				rng.randf_range(-0.6, 0.6))) * rng.randf_range(2.0, 5.0)
		chip.angular_velocity = Vector3(rng.randf_range(-15, 15), rng.randf_range(-15, 15), rng.randf_range(-15, 15))
		root.add_child(chip)
		chip.global_position = at + normal * 0.05


## Spray chunks of `material` (door splinters, mask fragments).
static func debris_burst(at: Vector3, base_velocity: Vector3, count: int, chunk_size: Vector3,
		material: Material, floor_y: float, lifetime: float = 3.5, spread: float = 3.0) -> void:
	var root := scene_root()
	if root == null:
		return
	var rng := RandomNumberGenerator.new()
	for i in count:
		var chunk := Debris.new()
		var box := BoxMesh.new()
		box.size = chunk_size * rng.randf_range(0.5, 1.1)
		chunk.mesh = box
		chunk.material_override = material
		chunk.lifetime = lifetime * rng.randf_range(0.8, 1.2)
		chunk.floor_y = floor_y
		chunk.velocity = base_velocity * rng.randf_range(0.5, 1.05) + Vector3(
				rng.randf_range(-spread, spread), rng.randf_range(0.5, spread * 1.2), rng.randf_range(-spread, spread))
		chunk.angular_velocity = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		root.add_child(chunk)
		chunk.global_position = at + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 0.2))
