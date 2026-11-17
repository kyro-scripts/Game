class_name Debris
extends MeshInstance3D
## A cheap flying chunk with no physics body. It integrates its own motion on
## a TimeDirector channel, so door splinters and mask fragments hang in the
## air during Borrow Time like everything else in the castle.

var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
## Chunks bounce and settle on this world height (no collision queries).
var floor_y: float = -1000.0
var lifetime: float = 3.0
var gravity: float = 22.0
var bounce: float = 0.25
var ground_friction: float = 7.0
## Seconds at the end of lifetime spent shrinking away.
var fade_time: float = 0.6
## TimeDirector.Channel value driving this chunk.
var time_channel: int = TimeDirector.Channel.WORLD

var _age: float = 0.0
var _rest_offset: float = 0.05
var _start_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	_start_scale = scale
	var aabb := get_aabb()
	_rest_offset = minf(aabb.size.x, minf(aabb.size.y, aabb.size.z)) * 0.5 * _start_scale.y


func _physics_process(real_delta: float) -> void:
	var dt := TimeDirector.scaled(time_channel, real_delta)
	if dt <= 0.0:
		return
	_age += dt
	velocity.y -= gravity * dt
	var pos := global_position + velocity * dt
	if pos.y <= floor_y + _rest_offset:
		pos.y = floor_y + _rest_offset
		if velocity.y < -1.0:
			velocity.y = -velocity.y * bounce
			angular_velocity *= 0.6
		else:
			velocity.y = 0.0
			var h := Vector2(velocity.x, velocity.z)
			h = h.move_toward(Vector2.ZERO, ground_friction * dt)
			velocity.x = h.x
			velocity.z = h.y
			angular_velocity = angular_velocity.move_toward(Vector3.ZERO, 12.0 * dt)
	global_position = pos
	if angular_velocity.length_squared() > 0.0001:
		rotate(angular_velocity.normalized(), angular_velocity.length() * dt)
	if _age > lifetime - fade_time:
		var k := clampf((lifetime - _age) / maxf(fade_time, 0.001), 0.0, 1.0)
		scale = _start_scale * k
	if _age >= lifetime:
		queue_free()
