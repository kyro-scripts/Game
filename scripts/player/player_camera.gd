class_name PlayerCamera
extends Camera3D
## First-person camera feel: speed FOV, strafe/slide roll, landing dip,
## trauma-based shake, weapon recoil. Runs on real time so feedback stays
## sharp during Borrow Time. Pitch/yaw themselves are owned by Player.

@export var max_shake_degrees: float = 2.6
@export var max_shake_offset: float = 0.06

var _player: Player
var _trauma: float = 0.0
var _fov_punch: float = 0.0
var _roll: float = 0.0
var _recoil: float = 0.0
var _land_dip: float = 0.0
var _noise := FastNoiseLite.new()
var _noise_t: float = 0.0
var _dead: bool = false


func _ready() -> void:
	_noise.seed = 1337
	_noise.frequency = 0.9
	_player = owner as Player
	fov = GameState.base_fov
	cull_mask = cull_mask & ~Palette.VIEWMODEL_LAYER


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func punch_fov(degrees: float) -> void:
	_fov_punch = maxf(_fov_punch, degrees)


func add_recoil(degrees: float) -> void:
	_recoil += deg_to_rad(degrees)


func land_impact(strength: float) -> void:
	_land_dip = maxf(_land_dip, strength * 0.22)
	add_trauma(strength * 0.25)


func on_death() -> void:
	_dead = true
	add_trauma(0.6)


func _process(delta: float) -> void:
	if _player == null:
		return
	var t: MovementTuning = _player.tuning
	_noise_t += delta * 60.0

	# Speed FOV: speed is felt more than it is read.
	var speed := _player.get_horizontal_speed()
	var k := clampf((speed - t.fov_speed_start) / maxf(t.fov_speed_full - t.fov_speed_start, 0.01), 0.0, 1.0)
	var target_fov := GameState.base_fov + t.fov_speed_bonus * k * k + _fov_punch
	fov = lerpf(fov, target_fov, 1.0 - exp(-7.0 * delta))
	_fov_punch = move_toward(_fov_punch, 0.0, 30.0 * delta)

	# Roll: lean into strafes, tilt during slides, keel over on death.
	var target_roll := -_player.get_input_vector().x * deg_to_rad(t.strafe_roll_degrees)
	if _player.is_sliding():
		target_roll += deg_to_rad(t.slide_roll_degrees)
	if _dead:
		target_roll = deg_to_rad(68.0)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-(2.0 if _dead else 10.0) * delta))

	# Recoil kicks up, then settles.
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-14.0 * delta))

	# Landing dip.
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-9.0 * delta))

	# Trauma shake (squared for a nicer falloff).
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var shake := _trauma * _trauma
	var sx := _noise.get_noise_2d(_noise_t, 0.0) * shake
	var sy := _noise.get_noise_2d(0.0, _noise_t) * shake
	var sr := _noise.get_noise_2d(_noise_t, _noise_t) * shake

	rotation = Vector3(_recoil + deg_to_rad(sx * max_shake_degrees), deg_to_rad(sy * max_shake_degrees),
			_roll + deg_to_rad(sr * max_shake_degrees))
	h_offset = sy * max_shake_offset
	v_offset = sx * max_shake_offset - _land_dip
