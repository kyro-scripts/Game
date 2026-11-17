extends Node
## Centralised time service (autoload "TimeDirector").
##
## The game never slows itself through Engine.time_scale. Instead every system
## asks this service for the scale of the time *channel* it belongs to, and
## multiplies its own real delta by it. That lets a stopwatch power slow the
## world while the player stays responsive and the run timer keeps draining.
##
## Channels:
##   WORLD       master scale for everything "in the castle".
##   ENEMY       enemy thinking + locomotion      (effective = WORLD * ENEMY)
##   PROJECTILE  enemy projectiles / hazards      (effective = WORLD * PROJECTILE)
##   ANIMATION   ambient animation, faces, props  (effective = WORLD * ANIMATION)
##   PLAYER      player locomotion + weapon timing (independent of WORLD)
##   AUDIO       pitch/tempo of world-sourced sounds (independent)
##   RUN_TIMER   run-timer drain rate (independent; Time Debt raises it)
##
## Effects push named *modifiers*: {Channel: multiplier}. Multipliers from all
## active modifiers multiply together, so future stopwatch modules can stack
## with Borrow Time without knowing about it.

signal scales_changed

enum Channel { WORLD, ENEMY, PROJECTILE, ANIMATION, PLAYER, AUDIO, RUN_TIMER }

const CHANNEL_NAMES: PackedStringArray = [
	"world", "enemy", "projectile", "animation", "player", "audio", "run_timer",
]

## Channels whose effective value is multiplied by WORLD.
const WORLD_CHILDREN := [Channel.ENEMY, Channel.PROJECTILE, Channel.ANIMATION]

## Accumulated world-scaled seconds since the scene started. Use this as a
## shared clock for synchronised uncanny behaviour (e.g. group blinking).
var world_time: float = 0.0
## Accumulated real seconds (pausable).
var real_time: float = 0.0

var _modifiers: Dictionary = {}  # StringName -> Dictionary[int, float]
var _scales: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_scales.resize(Channel.size())
	_recompute()


func _process(delta: float) -> void:
	real_time += delta
	world_time += delta * _scales[Channel.WORLD]


## Effective scale of a channel (already combined with WORLD where relevant).
func get_scale(channel: int) -> float:
	return _scales[channel]


## Convenience: real delta converted into a channel's local delta.
func scaled(channel: int, real_delta: float) -> float:
	return real_delta * _scales[channel]


## Add or replace a named modifier. `scales` maps Channel -> multiplier.
## Missing channels are treated as 1.0. Calling every frame is fine (cheap).
func set_modifier(id: StringName, scales: Dictionary) -> void:
	_modifiers[id] = scales
	_recompute()


func clear_modifier(id: StringName) -> void:
	if _modifiers.erase(id):
		_recompute()


func has_modifier(id: StringName) -> bool:
	return _modifiers.has(id)


func get_modifier_ids() -> Array:
	return _modifiers.keys()


## Remove every modifier (run restart, scene change).
func reset() -> void:
	_modifiers.clear()
	world_time = 0.0
	real_time = 0.0
	_recompute()


func describe() -> String:
	var parts: PackedStringArray = []
	for c in Channel.size():
		parts.append("%s %.2f" % [CHANNEL_NAMES[c].substr(0, 4), _scales[c]])
	return "  ".join(parts)


func _recompute() -> void:
	var raw := PackedFloat32Array()
	raw.resize(Channel.size())
	raw.fill(1.0)
	for id: StringName in _modifiers:
		var mod: Dictionary = _modifiers[id]
		for key: Variant in mod:
			var channel := int(key)
			if channel >= 0 and channel < raw.size():
				raw[channel] *= maxf(float(mod[key]), 0.0)
	for c in Channel.size():
		var value: float = raw[c]
		if c in WORLD_CHILDREN:
			value *= raw[Channel.WORLD]
		_scales[c] = value
	scales_changed.emit()
