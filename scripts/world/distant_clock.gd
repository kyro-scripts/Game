class_name DistantClock
extends Node3D
## A clock somewhere in the dark, ticking slightly slower than a second, so it
## drifts in and out of step with the stopwatch. Runs on WORLD time.

@export var interval: float = 1.06
@export var volume_db: float = -20.0

var _t: float = 0.0
var _silenced: float = 0.0


func _ready() -> void:
	add_to_group(&"distant_clock")
	_t = randf() * interval


func silence(seconds: float) -> void:
	_silenced = maxf(_silenced, seconds)


func _process(delta: float) -> void:
	var dt := TimeDirector.scaled(TimeDirector.Channel.WORLD, delta)
	if _silenced > 0.0:
		_silenced -= dt
		return
	_t -= dt
	if _t <= 0.0:
		_t += interval
		AudioDirector.play(&"distant_tick", global_position, volume_db, 1.0, AudioDirector.BUS_WORLD, 0.02)
