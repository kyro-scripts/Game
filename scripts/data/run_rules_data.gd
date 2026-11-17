class_name RunRulesData
extends Resource
## Rules for a single run. Every value here is an IMPLEMENTATION DEFAULT
## (see docs/DESIGN_NOTES.md) and is expected to change with playtesting or be
## swapped wholesale by future rule-set unlocks.

@export var id: StringName = &"standard"
@export var display_name: String = "Standard Masque"

@export_group("Run Timer")
## Seconds on the clock when the run begins.
@export_range(10.0, 600.0, 1.0, "suffix:s") var starting_time: float = 90.0
## The clock can never be topped up above this.
@export_range(10.0, 900.0, 1.0, "suffix:s") var max_time: float = 180.0
## Used when an enemy's data does not specify its own reward.
@export_range(0.0, 10.0, 0.1, "suffix:s") var default_kill_reward: float = 2.0
## Below this the stopwatch and screen start warning the player.
@export_range(0.0, 60.0, 0.5, "suffix:s") var low_time_warning: float = 15.0

@export_group("Player")
@export_range(1.0, 500.0, 1.0) var player_max_health: float = 100.0
