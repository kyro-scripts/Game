class_name DummyWalker
extends EnemyBase
## TEST DUMMY (Phase B). Not a canon enemy: a proving ground for the shared
## enemy base, Borrow Time and the run-timer kill reward. Walks at the player,
## telegraphs, lunges. The future Rusher will reuse this skeleton.
##
## IDLE -> (sees player) ALERT -> CHASE -> ATTACK(windup, strike, recover)
##                                  ^-------- STAGGER <--- heavy hit

## If false the dummy stands still (pure target practice) but still watches.
@export var pursue: bool = true

const LUNGE_SPEED := 9.0
const LUNGE_TIME := 0.16
const ALERT_TIME := 0.35

var _struck: bool = false
var _arm_l: Node3D
var _arm_r: Node3D


func _ready() -> void:
	super()
	_arm_l = visual.get_node_or_null(^"ArmL") as Node3D
	_arm_r = visual.get_node_or_null(^"ArmR") as Node3D


func _tick_behaviour(dt: float) -> void:
	match state:
		State.IDLE:
			_halt(dt)
			if target != null and distance_to_target() <= data.detection_range and can_see_target():
				change_state(State.ALERT)
		State.ALERT:
			_halt(dt)
			face_direction(flat_direction_to_target(), dt)
			if state_time >= ALERT_TIME:
				change_state(State.CHASE if pursue else State.OBSERVE)
		State.OBSERVE:
			_halt(dt)
			face_direction(flat_direction_to_target(), dt * 0.4)
		State.CHASE:
			if target == null or not target.alive:
				change_state(State.IDLE)
				return
			var dir := flat_direction_to_target()
			face_direction(dir, dt)
			var desired := dir * data.move_speed
			var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, data.acceleration * dt)
			velocity.x = hv.x
			velocity.z = hv.z
			if distance_to_target() <= data.attack_range:
				change_state(State.ATTACK)
		State.ATTACK:
			_tick_attack(dt)
		State.STAGGER:
			_halt(dt)
			if state_time >= data.stagger_time:
				change_state(State.CHASE if pursue else State.OBSERVE)


func _tick_attack(dt: float) -> void:
	var windup := data.attack_windup
	if state_time < windup:
		_halt(dt)
		face_direction(flat_direction_to_target(), dt * 1.5)
		var k := state_time / windup
		_set_arms(lerpf(0.0, -2.4, k))
	elif state_time < windup + LUNGE_TIME:
		var fwd := -global_basis.z
		velocity.x = fwd.x * LUNGE_SPEED
		velocity.z = fwd.z * LUNGE_SPEED
		_set_arms(-1.2)
		if not _struck and target != null and target.alive:
			var to := target.global_position - global_position
			to.y = 0.0
			if to.length() <= data.attack_range + 0.6 and fwd.dot(to.normalized()) > 0.5:
				_struck = true
				target.take_damage(data.attack_damage, self)
	elif state_time < windup + LUNGE_TIME + data.attack_recover:
		_halt(dt)
		_set_arms(lerpf(-1.2, 0.0, (state_time - windup - LUNGE_TIME) / data.attack_recover))
	else:
		change_state(State.CHASE if pursue else State.OBSERVE)


func _enter_state(s: State) -> void:
	match s:
		State.ATTACK:
			_struck = false
			face.set_expression(FaceRig.Mood.OPEN)
			AudioDirector.play(&"enemy_windup", eye_position(), -6.0, 1.0)
		State.STAGGER:
			face.set_expression(FaceRig.Mood.NEUTRAL)
		_:
			face.set_expression(FaceRig.Mood.SMILE)


func _exit_state(s: State) -> void:
	if s == State.ATTACK:
		_set_arms(0.0)


func _halt(dt: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, data.acceleration * 2.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.z


func _set_arms(angle: float) -> void:
	if _arm_l != null:
		_arm_l.rotation.x = angle
	if _arm_r != null:
		_arm_r.rotation.x = angle
