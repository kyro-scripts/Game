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
		mask_drop.mesh = FaceRig.mesh_for(FaceRig.Mood.SMILE)
		mask_drop.material_override = CastleMaterials.porcelain()
		mask_drop.rotation.x = -PI * 0.5  # lands face up
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
	# A masque guest: a heavy hooded velvet robe that brushes the floor (they
	# glide; no legs are ever seen), bell sleeves, pale kid gloves, a red cord.
	var robe_mat := CastleMaterials.velvet(Color(0.07, 0.062, 0.068), 1.6, 0.02)
	visual.add_child(_mesh_node(_robe_mesh(), robe_mat))
	var cord := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.255
	torus.outer_radius = 0.285
	cord.mesh = torus
	cord.material_override = Palette.lit(Palette.RED, 0.6)
	cord.position.y = 1.08
	cord.scale = Vector3(1.0, 1.0, 0.85)
	visual.add_child(cord)
	var tassel := Palette.cylinder(0.012, 0.35, Palette.lit(Palette.RED, 0.6), 6)
	tassel.position = Vector3(0.12, 0.9, -0.22)
	visual.add_child(tassel)
	var hood := _mesh_node(_hood_mesh(), robe_mat)
	head.add_child(hood)
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0.0 else "ArmR"
		arm.position = Vector3(side * 0.3, 1.5, 0.0)
		arm.rotation.z = side * 0.06
		visual.add_child(arm)
		arm.add_child(_mesh_node(_sleeve_mesh(), robe_mat))
		var hand := _glove(side)
		hand.position = Vector3(0.0, -0.74, -0.02)
		arm.add_child(hand)


static var _robe_cache: Mesh
static var _hood_cache: Mesh
static var _sleeve_cache: Mesh


static func _robe_mesh() -> Mesh:
	if _robe_cache != null:
		return _robe_cache
	var prof := PackedVector2Array([Vector2(0.43, 0.0), Vector2(0.4, 0.25), Vector2(0.34, 0.65),
			Vector2(0.29, 0.95), Vector2(0.26, 1.1), Vector2(0.27, 1.3), Vector2(0.255, 1.45),
			Vector2(0.21, 1.54), Vector2(0.12, 1.6), Vector2(0.07, 1.64)])
	var folds := func(a: float, y: float) -> float:
		var fold_amp := 0.07 * (1.0 - smoothstep(0.0, 1.15, y))
		var shoulders := 0.2 * smoothstep(1.2, 1.5, y) * (1.0 - smoothstep(1.53, 1.64, y))
		var c := cos(a)
		return (1.0 + fold_amp * sin(a * 9.0 + sin(a * 3.0) * 1.5)) * (1.0 + shoulders * c * c) * (1.0 - 0.12 * absf(sin(a)) * smoothstep(0.9, 1.4, y))
	_robe_cache = MeshKit.lathe(prof, 48, true, folds)
	return _robe_cache


## Hood around the head pivot, open at the front (enemy front is -Z).
static func _hood_mesh() -> Mesh:
	if _hood_cache != null:
		return _hood_cache
	var prof := PackedVector2Array([Vector2(0.15, -0.24), Vector2(0.17, -0.16), Vector2(0.19, -0.05),
			Vector2(0.195, 0.05), Vector2(0.18, 0.14), Vector2(0.13, 0.21), Vector2(0.06, 0.25), Vector2(0.0, 0.26)])
	var drape := func(a: float, y: float) -> float:
		return 1.0 + 0.04 * sin(a * 5.0 + y * 8.0)
	_hood_cache = MeshKit.lathe(prof, 30, true, drape, false, -PI / 6.0, PI + PI / 6.0)
	return _hood_cache


static func _sleeve_mesh() -> Mesh:
	if _sleeve_cache != null:
		return _sleeve_cache
	var prof := PackedVector2Array([Vector2(0.12, -0.72), Vector2(0.1, -0.6), Vector2(0.075, -0.35),
			Vector2(0.07, -0.1), Vector2(0.08, 0.04), Vector2(0.0, 0.07)])
	var folds := func(a: float, y: float) -> float:
		return 1.0 + 0.08 * sin(a * 5.0) * smoothstep(-0.3, -0.72, y)
	_sleeve_cache = MeshKit.lathe(prof, 20, true, folds)
	return _sleeve_cache


## Pale kid glove with long fingers that hang a little too straight.
func _glove(side: float) -> Node3D:
	var n := Node3D.new()
	var mat := CastleMaterials.glove()
	var palm := Palette.box(Vector3(0.075, 0.09, 0.032), mat)
	palm.position.y = -0.03
	n.add_child(palm)
	for i in 4:
		var finger := Palette.capsule(0.009, 0.1 + 0.012 * float(i % 3), mat)
		finger.position = Vector3(-0.027 + float(i) * 0.018, -0.115, 0.0)
		n.add_child(finger)
	var thumb := Palette.capsule(0.01, 0.07, mat)
	thumb.position = Vector3(-side * 0.045, -0.05, -0.012)
	thumb.rotation.z = side * 0.6
	n.add_child(thumb)
	return n


func _mesh_node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	return mi
