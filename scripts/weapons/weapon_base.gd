class_name WeaponBase
extends Node3D
## Hitscan weapon logic plus its placeholder first-person model.
##
## Lives under the camera's ViewmodelRoot (render layer 20). Rays are cast
## from the camera centre against world geometry and enemy hurtboxes.
## Timing runs on the PLAYER time channel.
##
## To replace the placeholder model, add children to the "Model" node in the
## player scene; the code-built placeholder is only created when Model is empty.

signal fired
signal hit_confirmed(killed: bool, headshot: bool)

@export var data: WeaponData = preload("res://data/weapons/sidearm_placeholder.tres")

var _player: Player
var _camera: PlayerCamera
var _cooldown: float = 0.0
var _fire_buffer: float = 0.0
var _ammo: int = 0
var _reload_timer: float = 0.0
var _kick: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var _model: Node3D = $Model
@onready var _muzzle: Node3D = $Model/Muzzle
@onready var _flash: Node3D = $Model/Muzzle/Flash


func setup(player: Player, cam: PlayerCamera) -> void:
	_player = player
	_camera = cam
	_ammo = data.magazine_size


func _ready() -> void:
	if _model.get_child_count() <= 1:  # only the Muzzle marker
		_build_placeholder_model()
	_flash.visible = false
	Palette.to_viewmodel_layer(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"fire"):
		return
	# A click that is grabbing the mouse back must not shoot.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		return
	trigger()


## Request a shot (click). Buffered briefly so early clicks are not eaten.
func trigger() -> void:
	_fire_buffer = 0.12


func _physics_process(real_delta: float) -> void:
	var dt := TimeDirector.scaled(TimeDirector.Channel.PLAYER, real_delta)
	_cooldown = maxf(_cooldown - dt, 0.0)
	_fire_buffer = maxf(_fire_buffer - dt, 0.0)
	if _reload_timer > 0.0:
		_reload_timer -= dt
		if _reload_timer <= 0.0:
			_ammo = data.magazine_size
	if _player == null or not _player.alive or not _player.input_enabled:
		_fire_buffer = 0.0
		return
	var wants := _fire_buffer > 0.0
	if data.automatic and Input.is_action_pressed(&"fire"):
		wants = true
	if wants and _cooldown <= 0.0 and _reload_timer <= 0.0:
		_fire_buffer = 0.0
		fire()


func _process(delta: float) -> void:
	# Viewmodel kick animation (real time: this is feedback).
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-16.0 * delta))
	_model.position = Vector3(0.0, -_kick * 0.02, _kick * 0.09)
	_model.rotation = Vector3(_kick * 0.38, 0.0, 0.0)
	if _reload_timer > 0.0:
		_model.rotation.x -= 0.6


func fire() -> void:
	_cooldown = data.fire_interval
	if data.magazine_size > 0:
		_ammo -= 1
		if _ammo <= 0:
			_reload_timer = data.reload_time
	var space := get_world_3d().direct_space_state
	var origin := _camera.global_position
	var cam_basis := _camera.global_basis
	var forward := -cam_basis.z
	var muzzle_pos := _muzzle.global_position
	var any_hit := false
	var any_kill := false
	var any_head := false
	for i in data.pellets:
		var dir := _spread_direction(forward, cam_basis)
		var to := origin + dir * data.max_range
		var query := PhysicsRayQueryParameters3D.create(origin, to,
				Player.LAYER_WORLD | Player.LAYER_HURTBOX, [_player.get_rid()])
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		var end := to
		if not hit.is_empty():
			end = hit["position"]
			var collider: Object = hit["collider"]
			if collider is Hurtbox:
				var info := {
					"source": _player,
					"weapon_id": data.id,
					"direction": dir,
					"position": end,
					"knockback": data.knockback,
					"headshot_multiplier": data.headshot_multiplier,
					"player_speed": _player.get_horizontal_speed(),
				}
				var result := (collider as Hurtbox).receive_hit(data.damage, info)
				if bool(result.get("hit", false)):
					any_hit = true
					any_kill = any_kill or bool(result.get("killed", false))
					any_head = any_head or bool(result.get("headshot", false))
			else:
				var normal: Vector3 = hit["normal"]
				FX.impact(end, normal)
		FX.tracer(muzzle_pos, end, data.tracer_color)

	_kick = 1.0
	_camera.add_recoil(data.recoil_pitch_degrees)
	_camera.add_trauma(data.camera_trauma)
	FX.flash_light(muzzle_pos, Palette.PAPER, 4.0, 7.0, 0.05)
	_show_flash()
	AudioDirector.play(&"gunshot", null, -3.0, 1.0, AudioDirector.BUS_PLAYER, 0.05)
	fired.emit()
	Events.weapon_fired.emit(data.id)
	if any_hit:
		hit_confirmed.emit(any_kill, any_head)


func get_ammo_text() -> String:
	if data.magazine_size <= 0:
		return "∞"
	return "%d/%d" % [maxi(_ammo, 0), data.magazine_size]


func _spread_direction(forward: Vector3, cam_basis: Basis) -> Vector3:
	if data.spread_degrees <= 0.0:
		return forward
	var r := deg_to_rad(data.spread_degrees) * sqrt(_rng.randf())
	var theta := _rng.randf() * TAU
	return (forward + cam_basis.x * tan(r) * cos(theta) + cam_basis.y * tan(r) * sin(theta)).normalized()


func _show_flash() -> void:
	_flash.visible = true
	_flash.rotation.z = _rng.randf() * TAU
	_flash.scale = Vector3.ONE * _rng.randf_range(0.8, 1.2)
	get_tree().create_timer(0.045, false).timeout.connect(_hide_flash)


func _hide_flash() -> void:
	if is_instance_valid(_flash):
		_flash.visible = false


func _build_placeholder_model() -> void:
	# An old, heavy flintlock-pattern pistol: octagonal blued barrel with a
	# brass muzzle swell, walnut stock with a bird's-head grip, lock plate,
	# cock and frizzen, brass trigger guard. Held in a pale kid glove.
	var steel := CastleMaterials.blued_steel()
	var brass := CastleMaterials.brass()
	var walnut := CastleMaterials.wood_held()

	# Barrel along -Z (lathe axis Y rotated to -Z), eight flat facets.
	var barrel_prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0135, 0.0), Vector2(0.0135, 0.015),
			Vector2(0.0122, 0.03), Vector2(0.0112, 0.29), Vector2(0.0, 0.29)])
	var barrel := _mesh(MeshKit.lathe(barrel_prof, 8, false), steel)
	barrel.rotation.x = -PI * 0.5
	barrel.position = Vector3(0.0, 0.0, 0.03)
	_model.add_child(barrel)
	var swell := _mesh(MeshKit.lathe(PackedVector2Array([Vector2(0.0085, 0.0), Vector2(0.0145, 0.0),
			Vector2(0.0158, 0.008), Vector2(0.0145, 0.018), Vector2(0.0085, 0.018)]), 20), brass)
	swell.rotation.x = -PI * 0.5
	swell.position = Vector3(0.0, 0.0, -0.245)
	_model.add_child(swell)
	var bore := Palette.cylinder(0.0075, 0.004, Palette.lit(Palette.BLACK, 1.0), 12)
	bore.rotation.x = PI * 0.5
	bore.position = Vector3(0.0, 0.0, -0.264)
	_model.add_child(bore)

	# Stock: side profile (u = toward the shooter, v = up), extruded sideways.
	var stock_profile := PackedVector2Array([
		Vector2(-0.2, -0.011), Vector2(0.0, -0.002), Vector2(0.03, 0.013), Vector2(0.085, 0.012),
		Vector2(0.1, -0.008), Vector2(0.11, -0.045), Vector2(0.115, -0.085), Vector2(0.12, -0.115),
		Vector2(0.105, -0.138), Vector2(0.078, -0.135), Vector2(0.066, -0.11), Vector2(0.055, -0.075),
		Vector2(0.038, -0.044), Vector2(0.0, -0.03), Vector2(-0.2, -0.025)])
	var stock := _mesh(MeshKit.extrude_polygon(stock_profile, 0.03), walnut)
	stock.rotation.y = -PI * 0.5
	_model.add_child(stock)
	var butt_cap := Palette.sphere(0.02, brass, 14)
	butt_cap.scale = Vector3(0.85, 0.7, 1.2)
	butt_cap.position = Vector3(0.0, -0.137, 0.094)
	_model.add_child(butt_cap)

	# Lock: plate, cock (hammer) and frizzen on the right side.
	var plate := Palette.box(Vector3(0.004, 0.024, 0.07), steel)
	plate.position = Vector3(0.0165, 0.0, 0.045)
	_model.add_child(plate)
	var cock := Palette.box(Vector3(0.006, 0.032, 0.011), steel)
	cock.position = Vector3(0.012, 0.024, 0.07)
	cock.rotation.x = deg_to_rad(-28.0)
	_model.add_child(cock)
	var jaw := Palette.box(Vector3(0.008, 0.008, 0.016), steel)
	jaw.position = Vector3(0.012, 0.04, 0.062)
	_model.add_child(jaw)
	var frizzen := Palette.box(Vector3(0.006, 0.026, 0.005), steel)
	frizzen.position = Vector3(0.012, 0.018, 0.03)
	frizzen.rotation.x = deg_to_rad(12.0)
	_model.add_child(frizzen)

	# Brass trigger guard and trigger.
	var guard := MeshInstance3D.new()
	var gt := TorusMesh.new()
	gt.inner_radius = 0.018
	gt.outer_radius = 0.0215
	gt.ring_segments = 8
	guard.mesh = gt
	guard.material_override = brass
	guard.rotation.z = PI * 0.5
	guard.scale = Vector3(1.0, 1.0, 1.45)
	guard.position = Vector3(0.0, -0.038, 0.04)
	_model.add_child(guard)
	var trig := Palette.box(Vector3(0.004, 0.022, 0.004), steel)
	trig.position = Vector3(0.0, -0.033, 0.045)
	trig.rotation.x = deg_to_rad(-15.0)
	_model.add_child(trig)

	# Gloved hand around the grip, index finger along the guard.
	var glove := CastleMaterials.glove()
	var palm := Palette.box(Vector3(0.05, 0.075, 0.06), glove)
	palm.position = Vector3(0.012, -0.075, 0.1)
	palm.rotation.x = deg_to_rad(-22.0)
	_model.add_child(palm)
	for i in 3:
		var f := Palette.capsule(0.0095, 0.05, glove)
		f.position = Vector3(-0.012, -0.06 - float(i) * 0.02, 0.07 + float(i) * 0.006)
		f.rotation.z = PI * 0.5
		_model.add_child(f)
	var index := Palette.capsule(0.009, 0.05, glove)
	index.position = Vector3(-0.004, -0.035, 0.045)
	index.rotation.x = PI * 0.5
	_model.add_child(index)
	var thumb := Palette.capsule(0.0095, 0.05, glove)
	thumb.position = Vector3(-0.02, -0.03, 0.085)
	thumb.rotation.x = deg_to_rad(70.0)
	_model.add_child(thumb)
	var sleeve := Palette.cylinder(0.05, 0.4, CastleMaterials.velvet(Color(0.05, 0.045, 0.05), 0.0, 0.0), 16)
	sleeve.position = Vector3(0.02, -0.25, 0.3)
	sleeve.rotation = Vector3(deg_to_rad(60.0), 0.0, deg_to_rad(-8.0))
	_model.add_child(sleeve)

	# Muzzle flash: a pale star of two crossed quads around a red core.
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(1.0, 0.85, 0.65)
	for k in 5:
		var q := Palette.sphere(0.009 + 0.004 * float(k % 3), flash_mat, 8)
		q.scale = Vector3(1.0, 1.0, 1.8 + float(k) * 0.5)
		q.position = Vector3(sin(k * 2.4) * 0.005, cos(k * 2.4) * 0.005, -0.012 - float(k) * 0.008)
		_flash.add_child(q)
	var core := Palette.sphere(0.012, Palette.unshaded(Palette.RED_HOT), 8)
	_flash.add_child(core)


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	return mi
