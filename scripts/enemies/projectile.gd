class_name Projectile
extends Node3D
## A slow enemy projectile. Movement is swept with a ray each tick (no physics
## body), on the PROJECTILE time channel, so Borrow Time visibly freezes it.

@export var lifetime: float = 6.0

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var shooter: Node3D = null

var _age: float = 0.0


func _physics_process(real_delta: float) -> void:
	var dt := TimeDirector.scaled(TimeDirector.Channel.PROJECTILE, real_delta)
	if dt <= 0.0:
		return
	_age += dt
	if _age >= lifetime:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * dt
	var exclude: Array[RID] = []
	if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject3D:
		exclude.append((shooter as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, Player.LAYER_WORLD | Player.LAYER_PLAYER, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	var collider: Object = hit["collider"]
	var at: Vector3 = hit["position"]
	if collider is Player:
		(collider as Player).take_damage(damage, self)
	FX.impact(at, hit["normal"], Palette.RED_HOT)
	FX.flash_light(at, Palette.RED_HOT, 2.0, 3.0, 0.15)
	queue_free()
