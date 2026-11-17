class_name StopwatchController
extends Node
## Owns the equipped stopwatch module. MVP module: BORROW TIME.
##
## Hold (or toggle, see GameState) the borrow_time action to slow the WORLD.
## The run timer is NOT slowed. On release the clock charges TIME DEBT: the
## RUN_TIMER channel drains faster for a few seconds, scaled by use.
##
## All timing here is real time (unaffected by the slowdown it creates).

signal activated
signal deactivated(seconds_used: float)
signal debt_changed(seconds_remaining: float)

const MOD_BORROW := &"borrow_time"
const MOD_DEBT := &"time_debt"

@export var borrow: BorrowTimeData = preload("res://data/stopwatch/borrow_time.tres")

## 0..1 stored charge.
var charge: float = 1.0
var active: bool = false
## 0..1 eased intensity of the slowdown (for visuals/audio).
var blend: float = 0.0
var debt_remaining: float = 0.0

var _player: Player
var _active_time: float = 0.0
var _recharge_delay: float = 0.0
var _reactivate_cooldown: float = 0.0
var _held_prev: bool = false
var _toggle_latched: bool = false
var _in_debt: bool = false


func setup(player: Player) -> void:
	_player = player
	Events.enemy_killed.connect(_on_enemy_killed)


func _exit_tree() -> void:
	TimeDirector.clear_modifier(MOD_BORROW)
	TimeDirector.clear_modifier(MOD_DEBT)


func _process(delta: float) -> void:
	var can_use := _player != null and _player.alive and _player.input_enabled
	var held := can_use and Input.is_action_pressed(&"borrow_time")
	var pressed := held and not _held_prev
	_held_prev = held
	if GameState.borrow_time_toggle_mode:
		if pressed:
			_toggle_latched = not _toggle_latched
		held = _toggle_latched and can_use
		pressed = held and not active and pressed

	_reactivate_cooldown = maxf(_reactivate_cooldown - delta, 0.0)

	if active:
		_active_time += delta
		charge = maxf(charge - delta / borrow.max_duration, 0.0)
		if not held or charge <= 0.0 or not can_use:
			end_borrow()
	else:
		if pressed:
			try_begin_borrow()
		if not active:
			_recharge_delay = maxf(_recharge_delay - delta, 0.0)
			if _recharge_delay <= 0.0:
				charge = minf(charge + delta / borrow.recharge_time, 1.0)

	_update_blend(delta)
	_update_debt(delta)


## Returns true if Borrow Time started.
func try_begin_borrow() -> bool:
	if active or _reactivate_cooldown > 0.0 or charge < borrow.min_charge_to_activate:
		if not active:
			AudioDirector.play(&"tock", null, -12.0, 0.7, AudioDirector.BUS_STOPWATCH)
		return false
	active = true
	_active_time = 0.0
	AudioDirector.play(&"stopwatch_click", null, -4.0, 1.0, AudioDirector.BUS_STOPWATCH)
	AudioDirector.play(&"borrow_in", null, -6.0, 1.0, AudioDirector.BUS_STOPWATCH, 0.0)
	activated.emit()
	Events.borrow_time_started.emit()
	return true


func end_borrow() -> void:
	if not active:
		return
	active = false
	_toggle_latched = false
	_recharge_delay = borrow.recharge_delay
	_reactivate_cooldown = borrow.reactivation_cooldown
	var used := _active_time
	_add_debt(used)
	AudioDirector.play(&"stopwatch_click", null, -6.0, 0.85, AudioDirector.BUS_STOPWATCH)
	AudioDirector.play(&"borrow_out", null, -7.0, 1.0, AudioDirector.BUS_STOPWATCH, 0.0)
	deactivated.emit(used)
	Events.borrow_time_ended.emit(used)


## Debug / card hook: refill.
func refill() -> void:
	charge = 1.0


## Debug / card hook: apply debt directly.
func force_debt(seconds: float) -> void:
	var was := debt_remaining
	debt_remaining = minf(debt_remaining + seconds, borrow.debt_stack_cap)
	if was <= 0.0 and debt_remaining > 0.0:
		Events.time_debt_started.emit(debt_remaining, borrow.debt_drain_multiplier)


func _add_debt(seconds_used: float) -> void:
	var duration := borrow.debt_max_duration
	if borrow.debt_scales_with_use:
		var used_fraction := clampf(seconds_used / borrow.max_duration, 0.0, 1.0)
		duration = lerpf(borrow.debt_min_duration, borrow.debt_max_duration, used_fraction)
	force_debt(duration)


func _update_blend(delta: float) -> void:
	var target := 1.0 if active else 0.0
	var ramp := borrow.ramp_in_time if active else borrow.ramp_out_time
	if ramp <= 0.0:
		blend = target
	else:
		blend = move_toward(blend, target, delta / ramp)
	if blend <= 0.0:
		TimeDirector.clear_modifier(MOD_BORROW)
		return
	var e := blend * blend * (3.0 - 2.0 * blend)  # smoothstep
	TimeDirector.set_modifier(MOD_BORROW, {
		TimeDirector.Channel.WORLD: lerpf(1.0, borrow.world_scale, e),
		TimeDirector.Channel.PLAYER: lerpf(1.0, borrow.player_scale, e),
		TimeDirector.Channel.AUDIO: lerpf(1.0, borrow.audio_scale, e),
	})


func _update_debt(delta: float) -> void:
	if debt_remaining <= 0.0:
		if _in_debt:
			_in_debt = false
			TimeDirector.clear_modifier(MOD_DEBT)
			debt_changed.emit(0.0)
			Events.time_debt_ended.emit()
		return
	_in_debt = true
	# Debt is collected only once the borrowing has stopped.
	if active:
		TimeDirector.clear_modifier(MOD_DEBT)
	else:
		debt_remaining = maxf(debt_remaining - delta, 0.0)
		TimeDirector.set_modifier(MOD_DEBT, {TimeDirector.Channel.RUN_TIMER: borrow.debt_drain_multiplier})
	debt_changed.emit(debt_remaining)


func _on_enemy_killed(_enemy: Node3D, _info: Dictionary) -> void:
	charge = minf(charge + borrow.charge_per_kill, 1.0)
