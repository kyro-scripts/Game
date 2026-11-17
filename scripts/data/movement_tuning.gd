class_name MovementTuning
extends Resource
## Every player-locomotion number lives here so movement feel can be tuned
## without touching code (and live, from the F1 debug menu).
##
## ALL VALUES ARE IMPLEMENTATION DEFAULTS, not locked design.
##
## Movement model in one paragraph:
##  * Ground: velocity moves toward (input * max speed) at `ground_accel`.
##    Over-speed (e.g. after a hop chain) bleeds at `overspeed_decel`, but NOT
##    during the short `landing_grace_time` window after touching down.
##  * Jumping inside that window (buffer/coyote make it forgiving) therefore
##    keeps all momentum and adds `hop_chain_bonus` -> skilful bunny hops.
##  * Air: Quake-family "add speed along wish dir up to a small cap" plus a
##    gentle steer that rotates velocity toward the look direction.
##  * Slide: entered at speed, gets a one-off boost (with cooldown), low
##    friction, slopes accelerate it, capsule lowers, jumping out keeps speed.

@export_group("Ground")
## Top running speed reached from input alone.
@export_range(1.0, 40.0, 0.1, "suffix:m/s") var ground_max_speed: float = 11.0
## How quickly input reaches top speed.
@export_range(1.0, 400.0, 1.0, "suffix:m/s²") var ground_accel: float = 80.0
## Quake-style friction coefficient when there is no input.
@export_range(0.0, 40.0, 0.1) var ground_friction: float = 9.0
## Friction treats speeds below this as this (lets you stop crisply).
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var stop_speed: float = 3.0
## How fast speed above `ground_max_speed` bleeds once grounded (after grace).
@export_range(0.0, 200.0, 1.0, "suffix:m/s²") var overspeed_decel: float = 16.0
## How quickly over-speed momentum can be redirected on the ground.
@export_range(0.0, 30.0, 0.1, "suffix:rad/s") var overspeed_turn_rate: float = 5.0

@export_group("Air")
@export_range(1.0, 100.0, 0.5, "suffix:m/s²") var gravity: float = 22.0
## Extra gravity while falling, for snappier arcs.
@export_range(1.0, 3.0, 0.01) var fall_gravity_multiplier: float = 1.15
@export_range(5.0, 100.0, 1.0, "suffix:m/s") var terminal_velocity: float = 45.0
## Acceleration available along the wish direction in the air.
@export_range(0.0, 400.0, 1.0, "suffix:m/s²") var air_accel: float = 70.0
## Air acceleration only adds speed while velocity along the wish direction
## is below this. Small values = classic strafe-turning; large = arcade.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var air_wish_speed_cap: float = 2.2
## Rotates horizontal velocity toward the wish direction without losing speed.
@export_range(0.0, 20.0, 0.1, "suffix:rad/s") var air_steer_rate: float = 1.8
## Horizontal air speed softly clamps toward this.
@export_range(5.0, 100.0, 0.5, "suffix:m/s") var air_max_speed: float = 32.0

@export_group("Jump & Hop")
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var jump_velocity: float = 7.2
## Grace period to jump after walking off a ledge.
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time: float = 0.1
## A jump pressed this long before landing still fires on landing.
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time: float = 0.15
## After landing, ground friction / over-speed bleed is suspended this long.
## Jumping inside the window is a "clean hop".
@export_range(0.0, 0.5, 0.01, "suffix:s") var landing_grace_time: float = 0.12
## Speed added along travel direction for each clean hop.
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var hop_chain_bonus: float = 0.6
## Hop bonus never pushes speed past this.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var hop_bonus_cap: float = 22.0
## Holding jump re-jumps automatically on landing (accessibility option).
@export var auto_bhop: bool = false

@export_group("Slide")
## Need at least this much horizontal speed to start a slide.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var slide_min_entry_speed: float = 6.0
## One-off speed added when a slide starts (subject to cooldown and cap).
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var slide_entry_boost: float = 4.5
@export_range(0.0, 5.0, 0.05, "suffix:s") var slide_boost_cooldown: float = 0.8
## Entry boost never pushes speed above this.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var slide_boost_cap: float = 22.0
## Deceleration while sliding on flat ground.
@export_range(0.0, 50.0, 0.1, "suffix:m/s²") var slide_friction: float = 3.0
## How strongly slopes speed up / slow down a slide (1 = full gravity).
@export_range(0.0, 3.0, 0.05) var slide_gravity_factor: float = 1.0
## Slide ends (becomes a crouch) below this speed.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var slide_min_speed: float = 4.0
@export_range(0.0, 10.0, 0.05, "suffix:rad/s") var slide_steer_rate: float = 1.1
## Extra speed when jumping out of a slide.
@export_range(0.0, 10.0, 0.05, "suffix:m/s") var slide_jump_bonus: float = 0.5
## Hard ceiling on slide speed (downhill runaway protection).
@export_range(5.0, 100.0, 0.5, "suffix:m/s") var slide_max_speed: float = 34.0

@export_group("Capsule & Crouch")
@export_range(0.5, 3.0, 0.01, "suffix:m") var stand_height: float = 1.8
@export_range(0.3, 2.0, 0.01, "suffix:m") var crouch_height: float = 0.9
@export_range(0.1, 1.0, 0.01, "suffix:m") var capsule_radius: float = 0.4
@export_range(0.2, 3.0, 0.01, "suffix:m") var stand_eye_height: float = 1.62
@export_range(0.1, 2.0, 0.01, "suffix:m") var crouch_eye_height: float = 0.72
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var crouch_speed: float = 5.0
@export_range(1.0, 60.0, 0.5) var eye_height_sharpness: float = 16.0

@export_group("Door Breach")
## Speed into a door needed to burst through it.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var breach_min_speed: float = 7.0
## Fraction of pre-impact velocity kept after bursting through.
@export_range(0.0, 1.2, 0.01) var breach_momentum_retain: float = 0.92

@export_group("Camera Feel")
## Extra FOV degrees at `fov_speed_full` horizontal speed.
@export_range(0.0, 40.0, 0.5, "suffix:°") var fov_speed_bonus: float = 14.0
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var fov_speed_start: float = 11.0
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var fov_speed_full: float = 26.0
@export_range(0.0, 10.0, 0.1, "suffix:°") var strafe_roll_degrees: float = 1.4
@export_range(0.0, 15.0, 0.1, "suffix:°") var slide_roll_degrees: float = 3.5
