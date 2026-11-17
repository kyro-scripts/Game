extends Node
## Owns the run timer, run statistics and the run start/end lifecycle
## (autoload "RunManager").
##
## The timer drains by real time multiplied by the RUN_TIMER time channel, so
## Borrow Time does NOT pause it and Time Debt makes it drain faster.
## Kills add time (EnemyData.time_reward). When the clock hits zero the run ends.

signal time_changed(time_remaining: float)

const DEFAULT_RULES: RunRulesData = preload("res://data/run/default_run_rules.tres")

var rules: RunRulesData = DEFAULT_RULES
var time_remaining: float = 0.0
var active: bool = false
var run_seed: int = 0
var last_result: Dictionary = {}

## Raw statistics for this run. Phase G turns these into a rank breakdown.
var stats: Dictionary = {}


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.door_breached.connect(_on_door_breached)
	Events.borrow_time_started.connect(_on_borrow_started)
	Events.borrow_time_ended.connect(_on_borrow_ended)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.player_died.connect(_on_player_died)


func start_run(rules_override: RunRulesData = null, seed_override: int = -1) -> void:
	rules = rules_override if rules_override != null else DEFAULT_RULES
	run_seed = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system()) ^ randi()
	time_remaining = rules.starting_time
	active = true
	last_result = {}
	stats = {
		"elapsed": 0.0,
		"kills": 0,
		"headshot_kills": 0,
		"damage_taken": 0.0,
		"doors_breached": 0,
		"borrow_uses": 0,
		"borrow_seconds": 0.0,
		"shots_fired": 0,
		"time_gained": 0.0,
		"top_speed": 0.0,
		"speed_samples": 0,
		"speed_accum": 0.0,
	}
	Events.run_started.emit(run_seed)
	time_changed.emit(time_remaining)


func _process(delta: float) -> void:
	if not active:
		return
	stats["elapsed"] = float(stats["elapsed"]) + delta
	if GameState.infinite_timer:
		return
	time_remaining -= delta * TimeDirector.get_scale(TimeDirector.Channel.RUN_TIMER)
	if time_remaining <= 0.0:
		time_remaining = 0.0
		time_changed.emit(time_remaining)
		end_run(&"time")
		return
	time_changed.emit(time_remaining)


## Add seconds to the clock (capped at rules.max_time).
func grant_time(seconds: float, reason: StringName) -> void:
	if not active or seconds == 0.0:
		return
	var before := time_remaining
	time_remaining = clampf(time_remaining + seconds, 0.0, rules.max_time)
	var gained := time_remaining - before
	stats["time_gained"] = float(stats["time_gained"]) + gained
	Events.time_granted.emit(gained, reason)
	time_changed.emit(time_remaining)


func is_low_time() -> bool:
	return active and time_remaining <= rules.low_time_warning


## Players report their horizontal speed each physics tick for stats.
func report_speed(speed: float) -> void:
	if not active:
		return
	stats["top_speed"] = maxf(float(stats["top_speed"]), speed)
	stats["speed_samples"] = int(stats["speed_samples"]) + 1
	stats["speed_accum"] = float(stats["speed_accum"]) + speed


func end_run(reason: StringName) -> void:
	if not active:
		return
	active = false
	var samples := maxi(int(stats["speed_samples"]), 1)
	last_result = stats.duplicate()
	last_result["reason"] = reason
	last_result["time_remaining"] = time_remaining
	last_result["average_speed"] = float(stats["speed_accum"]) / samples
	last_result["run_seed"] = run_seed
	Events.run_ended.emit(last_result)


## Clean slate for a scene reload.
func reset() -> void:
	active = false
	time_remaining = 0.0
	TimeDirector.reset()


func _on_enemy_killed(_enemy: Node3D, info: Dictionary) -> void:
	if not active:
		return
	stats["kills"] = int(stats["kills"]) + 1
	if bool(info.get("headshot", false)):
		stats["headshot_kills"] = int(stats["headshot_kills"]) + 1
	var reward: float = info.get("time_reward", rules.default_kill_reward)
	grant_time(reward, &"kill")


func _on_player_damaged(amount: float, _source: Node) -> void:
	if active:
		stats["damage_taken"] = float(stats["damage_taken"]) + amount


func _on_door_breached(_door: Node3D, _speed: float) -> void:
	if active:
		stats["doors_breached"] = int(stats["doors_breached"]) + 1


func _on_borrow_started() -> void:
	if active:
		stats["borrow_uses"] = int(stats["borrow_uses"]) + 1


func _on_borrow_ended(seconds_used: float) -> void:
	if active:
		stats["borrow_seconds"] = float(stats["borrow_seconds"]) + seconds_used


func _on_weapon_fired(_weapon_id: StringName) -> void:
	if active:
		stats["shots_fired"] = int(stats["shots_fired"]) + 1


func _on_player_died(cause: StringName) -> void:
	end_run(cause)
