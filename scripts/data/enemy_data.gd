class_name EnemyData
extends Resource
## Data definition for an enemy archetype. Behaviour lives in the archetype
## script; numbers live here so balancing never needs code changes.

@export var id: StringName = &""
@export var display_name: String = ""
## Tags drive encounter budgeting and adaptive weighting in later phases.
@export var tags: Array[StringName] = []
## Encounter budget cost (Phase D).
@export_range(0, 20) var threat_cost: int = 1

@export_group("Vitals")
@export_range(1.0, 5000.0, 1.0) var max_health: float = 100.0
## Single-hit damage at or above this staggers the enemy.
@export_range(0.0, 500.0, 1.0) var stagger_threshold: float = 30.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var stagger_time: float = 0.3
## Seconds added to the run timer on death (design range ~1.5–4).
@export_range(0.0, 10.0, 0.1, "suffix:s") var time_reward: float = 2.5

@export_group("Movement")
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var move_speed: float = 6.0
@export_range(0.0, 200.0, 1.0, "suffix:m/s²") var acceleration: float = 30.0
@export_range(0.0, 30.0, 0.1, "suffix:rad/s") var turn_speed: float = 6.0

@export_group("Senses")
@export_range(0.0, 200.0, 1.0, "suffix:m") var detection_range: float = 30.0
## How quickly the head tracks the target (rad/s, constant speed = uncanny).
@export_range(0.0, 30.0, 0.1, "suffix:rad/s") var head_track_speed: float = 3.0

@export_group("Attack")
@export_range(0.0, 200.0, 1.0) var attack_damage: float = 15.0
@export_range(0.0, 50.0, 0.1, "suffix:m") var attack_range: float = 2.2
@export_range(0.0, 5.0, 0.05, "suffix:s") var attack_windup: float = 0.45
@export_range(0.0, 5.0, 0.05, "suffix:s") var attack_recover: float = 0.6
## Ranged archetypes.
@export_range(0.0, 100.0, 0.5, "suffix:m/s") var projectile_speed: float = 9.0
@export_range(0.1, 10.0, 0.05, "suffix:s") var fire_interval: float = 1.8
