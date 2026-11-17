class_name EnemyBase
extends CharacterBody3D
## Shared enemy infrastructure: health, damage, stagger, death, time-channel
## integration, target acquisition and line of sight. Archetypes extend this
## and implement _tick_behaviour(). Deliberately small: a state enum plus a
## per-archetype tick, not a general AI framework.
##
## Scene contract (see scenes/enemies/*.tscn):
##   CollisionShape3D   movement capsule      (layer 3 "enemy")
##   Visual             placeholder built in code if empty
##   Visual/Head        tracks the target at constant speed
##   Visual/Head/Face   FaceRig
##   BodyHurtbox, HeadHurtbox (Hurtbox areas, layer 4)

signal died(enemy: EnemyBase)

enum State { IDLE, OBSERVE, ALERT, CHASE, ATTACK, STAGGER, DEAD }

@export var data: EnemyData

var health: float = 1.0
var state: State = State.IDLE
var state_time: float = 0.0
var target: Player

@onready var visual: Node3D = $Visual
@onready var head: Node3D = $Visual/Head
@onready var face: FaceRig = $Visual/Head/Face

var _head_yaw: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _hurtboxes: Array[Hurtbox] = []
var _gravity: float = 22.0


func _ready() -> void:
	add_to_group(&"enemies")
	if data == null:
		data = EnemyData.new()
	health = data.max_health
	collision_layer = Player.LAYER_ENEMY
	collision_mask = Player.LAYER_WORLD | Player.LAYER_PLAYER | Player.LAYER_ENEMY
	floor_snap_length = 0.3
	for child in get_children():
		if child is Hurtbox:
			(child as Hurtbox).enemy = self
			_hurtboxes.append(child)
	if visual.get_child_count() <= 1:  # only the Head anchor
		_build_placeholder_body()


func _physics_process(real_delta: float) -> void:
	if state == State.DEAD:
		return
	var dt := TimeDirector.scaled(TimeDirector.Channel.ENEMY, real_delta)
	if dt <= 0.0:
		return
	state_time += dt
	_acquire_target()
	_tick_behaviour(dt)
	_track_head(dt)
	if not is_on_floor():
		velocity.y -= _gravity * dt
	else:
		velocity.y = minf(velocity.y, 0.0)
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * dt)
	var ts := TimeDirector.get_scale(TimeDirector.Channel.ENEMY)
	var base_velocity := velocity
	velocity = (base_velocity + _knockback) * ts
	move_and_slide()
	velocity = velocity / ts - _knockback if ts > 0.0001 else base_velocity


## Override per archetype.
func _tick_behaviour(_dt: float) -> void:
	pass


func change_state(new_state: State) -> void:
	if state == new_state or state == State.DEAD:
		return
	_exit_state(state)
	state = new_state
	state_time = 0.0
	_enter_state(new_state)


func _enter_state(_s: State) -> void:
	pass


func _exit_state(_s: State) -> void:
	pass


## Returns true if this hit killed the enemy.
func take_damage(amount: float, info: Dictionary = {}) -> bool:
	if state == State.DEAD:
		return false
	health -= amount
	Events.enemy_damaged.emit(self, amount, info)
	var at: Vector3 = info.get("position", global_position + Vector3.UP * 1.5)
	AudioDirector.play(&"enemy_hit", at, -4.0, 1.0)
	if face != null:
		face.flash(Palette.RED_HOT)
	if health <= 0.0:
		die(info)
		return true
	if amount >= data.stagger_threshold:
		var dir: Vector3 = info.get("direction", Vector3.ZERO)
		_knockback = Vector3(dir.x, 0.0, dir.z).normalized() * float(info.get("knockback", 3.0))
		change_state(State.STAGGER)
	elif state == State.IDLE or state == State.OBSERVE:
		change_state(State.ALERT)
	return false


func die(info: Dictionary = {}) -> void:
	if state == State.DEAD:
		return
	_exit_state(state)
	state = State.DEAD
	for hb in _hurtboxes:
		hb.set_deferred(&"monitorable", false)
		hb.set_deferred(&"collision_layer", 0)
	$CollisionShape3D.set_deferred(&"disabled", true)
	var killer_speed: float = info.get("player_speed", 0.0)
	var distance := global_position.distance_to(target.global_position) if target != null else -1.0
	Events.enemy_killed.emit(self, {
		"id": data.id,
		"tags": data.tags,
		"time_reward": data.time_reward,
		"position": global_position,
		"headshot": bool(info.get("headshot", false)),
		"killer_speed": killer_speed,
		"distance": distance,
	})
	died.emit(self)
	_death_effect(info)


## Placeholder death: no gore. The body folds into ash-coloured fragments and
## the mask drops, face up, still smiling.
func _death_effect(info: Dictionary) -> void:
	AudioDirector.play(&"enemy_death", global_position + Vector3.UP * 1.4, -3.0, 1.0)
	var dir: Vector3 = info.get("direction", Vector3.ZERO)
	FX.debris_burst(global_position + Vector3.UP * 1.1, dir * 4.0, 10, Vector3(0.14, 0.14, 0.14),
			Palette.lit(Palette.ASH), global_position.y, 2.5, 2.0)
	if face != null:
		var mask_drop := Debris.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.26
		mask_drop.mesh = mesh
		mask_drop.material_override = Palette.wax()
		mask_drop.scale = Vector3(0.92, 0.3, 1.14)
		mask_drop.lifetime = 8.0
		mask_drop.floor_y = global_position.y
		mask_drop.velocity = dir * 2.0 + Vector3.UP * 2.5
		var root := FX.scene_root()
		if root != null:
			root.add_child(mask_drop)
			mask_drop.global_position = face.global_position
	queue_free()


# --- Senses ----------------------------------------------------------------------

func _acquire_target() -> void:
	if target != null and is_instance_valid(target):
		return
	target = get_tree().get_first_node_in_group(&"player") as Player


func distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)


func flat_direction_to_target() -> Vector3:
	if target == null:
		return Vector3.ZERO
	var d := target.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO


func eye_position() -> Vector3:
	return head.global_position if head != null else global_position + Vector3.UP * 1.6


## Unobstructed line from our eyes to the player's eyes.
func can_see_target() -> bool:
	if target == null or not target.alive:
		return false
	var from := eye_position()
	var to := target.get_eye_position()
	var q := PhysicsRayQueryParameters3D.create(from, to, Player.LAYER_WORLD, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Turn the whole body toward a direction at data.turn_speed.
func face_direction(dir: Vector3, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, data.turn_speed * dt)


func _track_head(dt: float) -> void:
	if head == null:
		return
	var desired := 0.0
	if target != null and state != State.IDLE:
		var to := target.get_eye_position() - head.global_position
		var local := global_basis.inverse() * to
		desired = clampf(atan2(-local.x, -local.z), deg_to_rad(-110.0), deg_to_rad(110.0))
	# Constant angular speed, no easing: deliberately too smooth.
	_head_yaw = move_toward(_head_yaw, desired, data.head_track_speed * dt)
	head.rotation.y = _head_yaw


func _build_placeholder_body() -> void:
	# Tall, narrow, slightly too still. Dark robe, pale mask, a thin red sash.
	var robe := Palette.lit(Palette.CHARCOAL, 0.9)
	var body := Palette.capsule(0.26, 1.5, robe)
	body.position.y = 0.78
	visual.add_child(body)
	var shoulders := Palette.box(Vector3(0.6, 0.1, 0.24), robe)
	shoulders.position.y = 1.48
	visual.add_child(shoulders)
	var neck := Palette.cylinder(0.05, 0.22, robe, 10)
	neck.position.y = 1.6
	visual.add_child(neck)
	var sash := Palette.box(Vector3(0.54, 0.05, 0.28), Palette.emissive(Palette.RED, 0.35))
	sash.position.y = 1.02
	visual.add_child(sash)
	for side in [-1.0, 1.0]:
		var arm := Palette.capsule(0.06, 0.78, robe)
		arm.name = "ArmL" if side < 0.0 else "ArmR"
		arm.position = Vector3(side * 0.33, 1.08, 0.0)
		visual.add_child(arm)
