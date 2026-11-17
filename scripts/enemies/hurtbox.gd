class_name Hurtbox
extends Area3D
## A damageable region of an enemy. Hitscan rays hit these (layer 4), not the
## enemy's movement capsule, so heads and bodies can be told apart.

## The enemy that owns this hurtbox (must implement take_damage()).
@export var enemy: Node
## Head hits use the weapon's headshot multiplier.
@export var is_head: bool = false


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 0
	monitoring = false
	monitorable = true
	if enemy == null:
		enemy = _find_enemy()


## Returns {hit: bool, killed: bool, headshot: bool}.
func receive_hit(damage: float, info: Dictionary) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method(&"take_damage"):
		return {"hit": false, "killed": false, "headshot": false}
	var hit_info := info.duplicate()
	hit_info["headshot"] = is_head
	var multiplier: float = info.get("headshot_multiplier", 1.0) if is_head else 1.0
	var killed: bool = enemy.call(&"take_damage", damage * multiplier, hit_info)
	return {"hit": true, "killed": killed, "headshot": is_head}


func _find_enemy() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method(&"take_damage"):
			return n
		n = n.get_parent()
	return null
