class_name DummySpawner
extends Marker3D
## Sandbox helper: keeps one enemy alive at this spot, respawning it a few
## seconds after it dies so movement/combat testing never runs dry.

@export var enemy_scene: PackedScene
@export var respawn_delay: float = 4.0
## Applied to DummyWalker instances (false = stationary target).
@export var pursue: bool = true

var _current: EnemyBase


func _ready() -> void:
	call_deferred(&"spawn")


func spawn() -> EnemyBase:
	if enemy_scene == null:
		return null
	var e := enemy_scene.instantiate() as EnemyBase
	if e is DummyWalker:
		(e as DummyWalker).pursue = pursue
	get_parent().add_child(e)
	e.global_transform = global_transform
	e.died.connect(_on_died)
	_current = e
	return e


func _on_died(_enemy: EnemyBase) -> void:
	_current = null
	get_tree().create_timer(respawn_delay, false).timeout.connect(spawn)
