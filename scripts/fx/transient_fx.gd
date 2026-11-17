class_name TransientFX
extends Node3D
## Fades a short-lived effect (flash light, tracer, spark) and frees it.
## Uses real time by default: muzzle flashes and tracers are the player's
## feedback and must stay crisp during Borrow Time.

var lifetime: float = 0.08
## -1 = real time, otherwise a TimeDirector.Channel value.
var time_channel: int = -1
var shrink: bool = true

var _age: float = 0.0
var _lights: Array[Light3D] = []
var _light_energy: Array[float] = []
var _start_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	_start_scale = scale
	for child in get_children():
		if child is Light3D:
			_lights.append(child)
			_light_energy.append((child as Light3D).light_energy)


func _process(delta: float) -> void:
	var dt := delta if time_channel < 0 else TimeDirector.scaled(time_channel, delta)
	_age += dt
	var k := clampf(1.0 - _age / maxf(lifetime, 0.001), 0.0, 1.0)
	for i in _lights.size():
		_lights[i].light_energy = _light_energy[i] * k
	if shrink:
		scale = _start_scale * maxf(k, 0.001)
	if _age >= lifetime:
		queue_free()
