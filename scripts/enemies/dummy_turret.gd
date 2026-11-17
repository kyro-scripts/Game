class_name DummyTurret
extends EnemyBase
## TEST DUMMY (Phase B). A stationary figure holding a red lantern that lobs
## slow projectiles. It exists to make Borrow Time's effect on PROJECTILES
## obvious. Not a canon enemy.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/projectile.tscn")

var _cooldown: float = 1.0
var _lantern: MeshInstance3D
var _lantern_light: OmniLight3D
var _lantern_mat: StandardMaterial3D


func _ready() -> void:
	super()
	_build_lantern()
	_cooldown = data.fire_interval * 0.6


func _tick_behaviour(dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	match state:
		State.IDLE:
			if target != null and distance_to_target() <= data.detection_range and can_see_target():
				change_state(State.ALERT)
		State.ALERT, State.OBSERVE:
			face_direction(flat_direction_to_target(), dt)
			if target == null or not target.alive:
				change_state(State.IDLE)
				return
			_cooldown -= dt
			if _cooldown <= 0.0 and can_see_target():
				change_state(State.ATTACK)
		State.ATTACK:
			face_direction(flat_direction_to_target(), dt)
			var k := clampf(state_time / data.attack_windup, 0.0, 1.0)
			_set_glow(0.6 + k * 5.0)
			if state_time >= data.attack_windup:
				_fire()
				_cooldown = data.fire_interval
				change_state(State.OBSERVE)
		State.STAGGER:
			if state_time >= data.stagger_time:
				change_state(State.OBSERVE)


func _enter_state(s: State) -> void:
	if s == State.ATTACK:
		face.set_expression(FaceRig.Mood.OPEN)
	else:
		face.set_expression(FaceRig.Mood.SMILE)
		_set_glow(0.6)


func _fire() -> void:
	if target == null:
		return
	var origin := _lantern.global_position
	var aim := target.get_eye_position() - Vector3.UP * 0.35
	var p := PROJECTILE_SCENE.instantiate() as Projectile
	p.velocity = (aim - origin).normalized() * data.projectile_speed
	p.damage = data.attack_damage
	p.shooter = self
	FX.scene_root().add_child(p)
	p.global_position = origin
	AudioDirector.play(&"projectile_fire", origin, -2.0, 1.0)


func _set_glow(energy: float) -> void:
	if _lantern_mat != null:
		_lantern_mat.emission_energy_multiplier = energy
	if _lantern_light != null:
		_lantern_light.light_energy = energy * 0.6


func _build_lantern() -> void:
	_lantern_mat = Palette.unique(Palette.emissive(Palette.RED_HOT, 0.6))
	_lantern = Palette.box(Vector3(0.16, 0.22, 0.16), _lantern_mat)
	_lantern.position = Vector3(0.38, 1.05, -0.25)
	visual.add_child(_lantern)
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Palette.RED_HOT
	_lantern_light.omni_range = 4.5
	_lantern_light.light_energy = 0.4
	_lantern.add_child(_lantern_light)
