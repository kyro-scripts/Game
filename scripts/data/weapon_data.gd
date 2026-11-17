class_name WeaponData
extends Resource
## Data definition for a weapon. The weapon roster is an OPEN design question;
## this structure exists so new weapons are data + an optional script override,
## not a rewrite.

@export var id: StringName = &""
@export var display_name: String = ""
@export var tags: Array[StringName] = []

@export_group("Damage")
@export_range(0.0, 500.0, 0.5) var damage: float = 34.0
## Number of rays per shot (shotgun-style weapons use > 1).
@export_range(1, 32) var pellets: int = 1
@export_range(0.0, 30.0, 0.1, "suffix:°") var spread_degrees: float = 0.0
@export_range(1.0, 500.0, 1.0, "suffix:m") var max_range: float = 200.0
@export_range(1.0, 5.0, 0.05) var headshot_multiplier: float = 2.0
## Knockback impulse applied to staggered enemies.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var knockback: float = 4.0

@export_group("Handling")
## Seconds between shots (scaled by the PLAYER time channel).
@export_range(0.02, 3.0, 0.01, "suffix:s") var fire_interval: float = 0.26
## Hold-to-fire if true, otherwise each click fires (with a short buffer).
@export var automatic: bool = false
## 0 = infinite (implementation default for the placeholder sidearm).
@export_range(0, 200) var magazine_size: int = 0
@export_range(0.0, 5.0, 0.05, "suffix:s") var reload_time: float = 0.9

@export_group("Feel")
@export_range(0.0, 15.0, 0.1, "suffix:°") var recoil_pitch_degrees: float = 2.2
@export_range(0.0, 1.0, 0.01) var camera_trauma: float = 0.16
@export var tracer_color: Color = Color(0.85, 0.06, 0.05)
