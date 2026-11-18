@tool
class_name FlickerLight
extends OmniLight3D
## Candle / lantern light that gutters on WORLD time (so it steadies during
## Borrow Time). Optionally scales a flame mesh in sync.

@export var base_energy: float = 1.2
@export_range(0.0, 1.0) var flicker: float = 0.22
@export var speed: float = 1.0
var flames: Array[Node3D] = []

var _seed: float = 0.0


func _ready() -> void:
	_seed = fmod(global_position.x * 13.1 + global_position.z * 7.7, 100.0) if is_inside_tree() else randf() * 100.0


func _process(_delta: float) -> void:
	var t: float = TimeDirector.world_time if not Engine.is_editor_hint() else float(Time.get_ticks_msec()) / 1000.0
	var t2 := t * speed + _seed
	var n := sin(t2 * 7.3) * 0.5 + sin(t2 * 13.1 + 1.7) * 0.3 + sin(t2 * 23.7 + 0.3) * 0.2
	var k := 1.0 + n * flicker
	light_energy = base_energy * k
	for f in flames:
		if is_instance_valid(f):
			f.scale = Vector3(1.0, 0.85 + 0.25 * k, 1.0)
