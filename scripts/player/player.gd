class_name Player
extends CharacterBody3D
## Original high-speed first-person controller (Phase A).
##
## States: GROUND, AIR, SLIDE. Crouching is a capsule flag rather than a state:
## holding slide below slide-entry speed crouch-walks, and holding it in the air
## tucks the capsule and queues a slide for landing.
##
## Time: everything here runs on the PLAYER time channel. move_and_slide()
## always integrates with the engine's physics delta, so velocity is scaled
## around the call (see _move_scaled) instead of touching Engine.time_scale.
##
## Tuning lives in a MovementTuning resource (data/movement/default_movement.tres).

signal state_changed(new_state: MoveState)
signal landed(fall_speed: float)
signal jumped(clean_hop: bool)
signal slide_started()
signal slide_ended()
signal died(cause: StringName)

enum MoveState { GROUND, AIR, SLIDE }

const LAYER_WORLD := 1
const LAYER_PLAYER := 1 << 1
const LAYER_ENEMY := 1 << 2
const LAYER_HURTBOX := 1 << 3
const FOOTSTEP_STRIDE := 2.8

@export var tuning: MovementTuning = preload("res://data/movement/default_movement.tres")

## When false the player ignores movement/combat input (menus, run over).
var input_enabled: bool = true
var state: MoveState = MoveState.AIR
var health: float = 100.0
var max_health: float = 100.0
var alive: bool = true

@onready var head: Node3D = $Head
@onready var camera: PlayerCamera = $Head/Camera
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var stopwatch: StopwatchController = $StopwatchController
@onready var weapon: WeaponBase = $Head/Camera/ViewmodelRoot/Weapon
@onready var stopwatch_view: StopwatchViewmodel = $Head/Camera/ViewmodelRoot/Stopwatch

var _yaw: float = 0.0
var _pitch: float = 0.0
var _capsule: CapsuleShape3D
var _stand_probe: CapsuleShape3D
var _crouched: bool = false
var _slide_held: bool = false
var _slide_held_prev: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer: float = 0.0
var _landing_grace: float = 0.0
var _slide_boost_cooldown: float = 0.0
var _just_jumped: bool = false
var _footstep_distance: float = 0.0
var _slide_sound: Node = null
var _last_wish: Vector3 = Vector3.ZERO
var _input_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(&"player")
	if tuning == null:
		tuning = MovementTuning.new()
	_capsule = (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	collision.shape = _capsule
	_stand_probe = CapsuleShape3D.new()
	_apply_capsule(false)
	head.position.y = tuning.stand_eye_height
	_yaw = rotation.y
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = false
	max_slides = 6
	max_health = RunManager.rules.player_max_health
	health = max_health
	weapon.setup(self, camera)
	stopwatch.setup(self)
	stopwatch_view.setup(self, stopwatch)


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := GameState.mouse_sensitivity
		_yaw -= motion.relative.x * sens
		var dy := motion.relative.y * sens * (-1.0 if GameState.invert_y else 1.0)
		_pitch = clampf(_pitch - dy, deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation.y = _yaw
		head.rotation.x = _pitch
	elif input_enabled and event.is_action_pressed(&"jump"):
		queue_jump()


## Request a jump; it fires on the next tick it is legal (jump buffer).
func queue_jump() -> void:
	_jump_buffer = tuning.jump_buffer_time


## Set view angles directly (spawn points, tests).
func set_look(yaw: float, pitch: float = 0.0) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	rotation.y = _yaw
	head.rotation.x = _pitch


# --- Simulation -----------------------------------------------------------------

func _physics_process(real_delta: float) -> void:
	var ts := TimeDirector.get_scale(TimeDirector.Channel.PLAYER)
	var dt := real_delta * ts
	if dt <= 0.0:
		return
	_tick_timers(dt)

	var wish := _read_wish_direction()
	_slide_held = input_enabled and alive and Input.is_action_pressed(&"slide")
	var slide_pressed := _slide_held and not _slide_held_prev
	_slide_held_prev = _slide_held

	# Starting a slide from the ground is an explicit press at speed.
	if state == MoveState.GROUND and slide_pressed and _horizontal_speed() >= tuning.slide_min_entry_speed:
		_start_slide(true)

	match state:
		MoveState.GROUND:
			if _landing_grace > 0.0:
				_air_accelerate(wish, dt)  # bhop window: momentum untouched
			else:
				_ground_move(wish, dt)
		MoveState.AIR:
			_apply_gravity(dt)
			_air_accelerate(wish, dt)
		MoveState.SLIDE:
			_slide_move(wish, dt)

	_just_jumped = false
	_try_jump()

	var pre_velocity := velocity
	_move_scaled(ts)
	_handle_slide_collisions(pre_velocity)
	_update_state_after_move(pre_velocity)
	_update_capsule()
	_update_eye_height(dt)
	_update_footsteps(dt)
	RunManager.report_speed(_horizontal_speed())


func _tick_timers(dt: float) -> void:
	_jump_buffer = maxf(_jump_buffer - dt, 0.0)
	_landing_grace = maxf(_landing_grace - dt, 0.0)
	_slide_boost_cooldown = maxf(_slide_boost_cooldown - dt, 0.0)
	if not is_on_floor():
		_coyote_timer = maxf(_coyote_timer - dt, 0.0)


func _read_wish_direction() -> Vector3:
	if not input_enabled or not alive:
		_input_vector = Vector2.ZERO
		_last_wish = Vector3.ZERO
		return Vector3.ZERO
	_input_vector = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var b := global_basis
	var wish := b.x * _input_vector.x + b.z * _input_vector.y
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	_last_wish = wish
	return wish


func _ground_move(wish: Vector3, dt: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	var max_speed := tuning.crouch_speed if _crouched else tuning.ground_max_speed
	if wish.is_zero_approx():
		# Quake-family friction: crisp stop, proportional to speed.
		if speed > 0.0:
			var control := maxf(speed, tuning.stop_speed)
			var new_speed := maxf(speed - control * tuning.ground_friction * dt, 0.0)
			hv *= new_speed / speed
	elif speed > max_speed + 0.01:
		# Carrying excess momentum (hop chain, slide exit). Let it bleed off
		# gradually and steer it, unless the player is actively braking.
		var dir := hv / speed
		if dir.dot(wish) < -0.3:
			hv = hv.move_toward(wish * max_speed, tuning.ground_accel * dt)
		else:
			dir = _rotate_toward(dir, wish, tuning.overspeed_turn_rate * dt)
			speed = maxf(speed - tuning.overspeed_decel * dt, max_speed)
			hv = dir * speed
	else:
		hv = hv.move_toward(wish * max_speed, tuning.ground_accel * dt)
	velocity.x = hv.x
	velocity.z = hv.z


func _apply_gravity(dt: float) -> void:
	var g := tuning.gravity
	if velocity.y < 0.0:
		g *= tuning.fall_gravity_multiplier
	velocity.y = maxf(velocity.y - g * dt, -tuning.terminal_velocity)


func _air_accelerate(wish: Vector3, dt: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if not wish.is_zero_approx():
		# Only add speed while velocity along the wish direction is under a
		# small cap: holding forward at speed adds nothing, while strafing
		# + turning curves the path and can gain a little speed.
		var along := hv.dot(wish)
		var add := clampf(tuning.air_wish_speed_cap - along, 0.0, tuning.air_accel * dt)
		hv += wish * add
		# Gentle steer: rotate existing velocity toward the wish direction
		# without changing its magnitude (scaled by how aligned they are).
		var speed := hv.length()
		if speed > 0.5 and tuning.air_steer_rate > 0.0:
			var dir := hv / speed
			var align := dir.dot(wish)
			if align > 0.0:
				hv = _rotate_toward(dir, wish, tuning.air_steer_rate * align * dt) * speed
	var s := hv.length()
	if s > tuning.air_max_speed:
		hv *= move_toward(s, tuning.air_max_speed, 12.0 * dt) / s
	velocity.x = hv.x
	velocity.z = hv.z


func _slide_move(wish: Vector3, dt: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if is_on_floor():
		# Gravity component along the floor plane: downhill speeds up.
		var n := get_floor_normal()
		var along_floor := (Vector3.DOWN * tuning.gravity).slide(n)
		hv += Vector3(along_floor.x, 0.0, along_floor.z) * tuning.slide_gravity_factor * dt
	else:
		_apply_gravity(dt)
	var speed := hv.length()
	speed = clampf(speed - tuning.slide_friction * dt, 0.0, tuning.slide_max_speed)
	var dir := hv.normalized() if hv.length_squared() > 0.0001 else _flat_forward()
	if not wish.is_zero_approx():
		dir = _rotate_toward(dir, wish, tuning.slide_steer_rate * dt)
	hv = dir * speed
	velocity.x = hv.x
	velocity.z = hv.z
	if not _slide_held or speed < tuning.slide_min_speed:
		_end_slide()


func _try_jump() -> void:
	var wants := _jump_buffer > 0.0 or (tuning.auto_bhop and input_enabled and Input.is_action_pressed(&"jump"))
	if not wants or not alive or not input_enabled:
		return
	var grounded := state != MoveState.AIR or _coyote_timer > 0.0
	if not grounded:
		return
	if _crouched and state != MoveState.SLIDE and _ceiling_blocked():
		return
	var from_slide := state == MoveState.SLIDE
	var clean_hop := (state == MoveState.GROUND and _landing_grace > 0.0) or from_slide
	_jump_buffer = 0.0
	_coyote_timer = 0.0
	_landing_grace = 0.0
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	if speed > 0.1:
		var bonus := tuning.slide_jump_bonus if from_slide else (tuning.hop_chain_bonus if clean_hop else 0.0)
		if bonus > 0.0 and speed < tuning.hop_bonus_cap:
			var new_speed := minf(speed + bonus, tuning.hop_bonus_cap)
			hv *= new_speed / speed
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = tuning.jump_velocity
	if from_slide:
		_stop_slide_sound()
		slide_ended.emit()
	_set_state(MoveState.AIR)
	_just_jumped = true
	jumped.emit(clean_hop)
	AudioDirector.play(&"jump", null, -14.0, 1.0, AudioDirector.BUS_PLAYER, 0.1)


func _move_scaled(ts: float) -> void:
	# move_and_slide() integrates with the engine physics delta; scale velocity
	# around the call so the PLAYER channel controls effective speed.
	if is_equal_approx(ts, 1.0):
		move_and_slide()
		return
	velocity *= ts
	move_and_slide()
	velocity /= ts


func _handle_slide_collisions(pre_velocity: Vector3) -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other == null or not (other is Node) or not (other as Node).is_in_group(&"breachable"):
			continue
		var door := other as Node
		var into := -col.get_normal()
		into.y = 0.0
		if into.length_squared() < 0.0001:
			continue
		into = into.normalized()
		var impact := Vector3(pre_velocity.x, 0.0, pre_velocity.z).dot(into)
		if impact >= tuning.breach_min_speed:
			if door.call(&"breach", pre_velocity, col.get_position(), self):
				# The door is gone; give back the momentum the collision ate.
				var kept := pre_velocity * tuning.breach_momentum_retain
				velocity.x = kept.x
				velocity.z = kept.z
				camera.add_trauma(0.5)
				camera.punch_fov(7.0)
		elif door.has_method(&"push_open"):
			door.call(&"push_open", self)


func _update_state_after_move(pre_velocity: Vector3) -> void:
	if is_on_floor():
		_coyote_timer = tuning.coyote_time
		if state == MoveState.AIR and not _just_jumped:
			_land(pre_velocity)
	elif state != MoveState.AIR:
		# Walked or slid off an edge.
		if state == MoveState.SLIDE:
			_stop_slide_sound()
		_set_state(MoveState.AIR)


func _land(pre_velocity: Vector3) -> void:
	var fall_speed := maxf(-pre_velocity.y, 0.0)
	_landing_grace = tuning.landing_grace_time
	camera.land_impact(clampf(fall_speed / 22.0, 0.0, 1.0))
	if fall_speed > 4.0:
		AudioDirector.play(&"land", null, lerpf(-16.0, -5.0, clampf(fall_speed / 20.0, 0.0, 1.0)),
				1.0, AudioDirector.BUS_PLAYER, 0.08)
	landed.emit(fall_speed)
	if _slide_held and _horizontal_speed() >= tuning.slide_min_speed:
		_start_slide(true)  # carry the fall straight into a slide
	else:
		_set_state(MoveState.GROUND)


func _start_slide(allow_boost: bool) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	var dir := hv / speed if speed > 0.1 else _flat_forward()
	if allow_boost and _slide_boost_cooldown <= 0.0 and speed < tuning.slide_boost_cap:
		speed = minf(speed + tuning.slide_entry_boost, tuning.slide_boost_cap)
		_slide_boost_cooldown = tuning.slide_boost_cooldown
		camera.punch_fov(3.5)
	hv = dir * speed
	velocity.x = hv.x
	velocity.z = hv.z
	_set_crouched(true)
	_set_state(MoveState.SLIDE)
	if _slide_sound == null:
		_slide_sound = AudioDirector.play_loop(&"slide_loop", null, -12.0, AudioDirector.BUS_PLAYER)
	slide_started.emit()


func _end_slide() -> void:
	_stop_slide_sound()
	_set_state(MoveState.GROUND if is_on_floor() else MoveState.AIR)
	slide_ended.emit()


func _stop_slide_sound() -> void:
	if _slide_sound != null and is_instance_valid(_slide_sound):
		_slide_sound.queue_free()
	_slide_sound = null


func _set_state(new_state: MoveState) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(new_state)


# --- Capsule / crouch -----------------------------------------------------------

func _update_capsule() -> void:
	var want_crouch := state == MoveState.SLIDE or _slide_held
	_set_crouched(want_crouch)


## Returns false if standing up is blocked by geometry.
func _set_crouched(want: bool) -> bool:
	if want == _crouched:
		return true
	if not want and _ceiling_blocked():
		return false
	_apply_capsule(want)
	return true


func _apply_capsule(crouched: bool) -> void:
	_crouched = crouched
	var h := tuning.crouch_height if crouched else tuning.stand_height
	_capsule.radius = tuning.capsule_radius
	_capsule.height = maxf(h, tuning.capsule_radius * 2.0)
	collision.position = Vector3(0.0, _capsule.height * 0.5, 0.0)


func _ceiling_blocked() -> bool:
	if not is_inside_tree():
		return false
	_stand_probe.radius = tuning.capsule_radius * 0.95
	_stand_probe.height = tuning.stand_height - 0.06
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _stand_probe
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (tuning.stand_height * 0.5 + 0.04))
	params.collision_mask = LAYER_WORLD
	params.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _update_eye_height(dt: float) -> void:
	var target := tuning.crouch_eye_height if _crouched else tuning.stand_eye_height
	if not alive:
		target = 0.35
	var k := 1.0 - exp(-tuning.eye_height_sharpness * dt)
	head.position.y = lerpf(head.position.y, target, k)


func _update_footsteps(dt: float) -> void:
	if state != MoveState.GROUND or _crouched:
		_footstep_distance = 0.0
		return
	_footstep_distance += _horizontal_speed() * dt
	if _footstep_distance >= FOOTSTEP_STRIDE:
		_footstep_distance = 0.0
		AudioDirector.play(&"footstep", null, -20.0, 1.0, AudioDirector.BUS_PLAYER, 0.15)


# --- Health ----------------------------------------------------------------------

func take_damage(amount: float, source: Node = null) -> void:
	if not alive or amount <= 0.0 or GameState.god_mode:
		return
	health = maxf(health - amount, 0.0)
	camera.add_trauma(clampf(amount / 40.0, 0.2, 0.7))
	AudioDirector.play(&"player_hurt", null, -3.0, 1.0, AudioDirector.BUS_PLAYER)
	Events.player_damaged.emit(amount, source)
	if health <= 0.0:
		die(&"wounds")


func die(cause: StringName) -> void:
	if not alive:
		return
	alive = false
	input_enabled = false
	_stop_slide_sound()
	camera.on_death()
	died.emit(cause)
	Events.player_died.emit(cause)


# --- Queries ---------------------------------------------------------------------

func get_horizontal_speed() -> float:
	return _horizontal_speed()


func is_sliding() -> bool:
	return state == MoveState.SLIDE


func is_crouched() -> bool:
	return _crouched


func get_input_vector() -> Vector2:
	return _input_vector


func get_landing_grace() -> float:
	return _landing_grace


func get_eye_position() -> Vector3:
	return camera.global_position


func get_state_name() -> String:
	return MoveState.keys()[state]


func _horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _flat_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


## Rotate a horizontal unit vector toward another by at most `max_angle` rad.
static func _rotate_toward(from_dir: Vector3, to_dir: Vector3, max_angle: float) -> Vector3:
	var a := Vector2(from_dir.x, from_dir.z)
	var b := Vector2(to_dir.x, to_dir.z)
	if a.length_squared() < 0.0001 or b.length_squared() < 0.0001:
		return from_dir
	var angle := a.angle_to(b)
	var step := clampf(angle, -max_angle, max_angle)
	var r := a.normalized().rotated(step)
	return Vector3(r.x, 0.0, r.y)
