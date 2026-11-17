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
	if event.is_action_pressed(&"fire"):
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
	# A plain, heavy, old-fashioned sidearm silhouette in black with a red
	# band at the muzzle, held by a pale hand. Proportions are placeholder.
	var metal := Palette.lit(Palette.CHARCOAL, 0.45, 0.6)
	var barrel := Palette.box(Vector3(0.036, 0.042, 0.34), metal)
	barrel.position = Vector3(0.0, 0.0, -0.13)
	_model.add_child(barrel)
	var band := Palette.box(Vector3(0.044, 0.05, 0.018), Palette.emissive(Palette.RED, 0.6))
	band.position = Vector3(0.0, 0.0, -0.285)
	_model.add_child(band)
	var frame := Palette.box(Vector3(0.042, 0.06, 0.12), metal)
	frame.position = Vector3(0.0, -0.01, 0.06)
	_model.add_child(frame)
	var grip := Palette.box(Vector3(0.04, 0.13, 0.055), Palette.lit(Palette.BLACK, 0.8))
	grip.position = Vector3(0.0, -0.085, 0.1)
	grip.rotation.x = deg_to_rad(-18.0)
	_model.add_child(grip)
	var hammer := Palette.box(Vector3(0.012, 0.03, 0.02), metal)
	hammer.position = Vector3(0.0, 0.04, 0.115)
	_model.add_child(hammer)
	var hand := Palette.box(Vector3(0.07, 0.075, 0.09), Palette.wax())
	hand.position = Vector3(0.006, -0.09, 0.11)
	hand.rotation.x = deg_to_rad(-18.0)
	_model.add_child(hand)
	var sleeve := Palette.cylinder(0.05, 0.4, Palette.lit(Palette.BLACK, 0.95), 12)
	sleeve.position = Vector3(0.03, -0.17, 0.3)
	sleeve.rotation = Vector3(deg_to_rad(62.0), 0.0, deg_to_rad(-8.0))
	_model.add_child(sleeve)
	# Muzzle flash: a pale star of two crossed quads.
	var flash_mat := Palette.unshaded(Palette.PAPER)
	for k in 2:
		var q := Palette.box(Vector3(0.16, 0.025, 0.001), flash_mat)
		q.rotation.z = k * PI * 0.5
		_flash.add_child(q)
	var core := Palette.box(Vector3(0.05, 0.05, 0.001), Palette.unshaded(Palette.RED_HOT))
	_flash.add_child(core)
