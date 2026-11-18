extends Node
## Global gameplay signal bus (autoload "Events").
##
## Systems announce what happened here instead of reaching into each other's
## nodes. Listeners (RunManager, AudioDirector, HUD, later the AdaptiveDirector
## and scoring) subscribe without the emitter knowing they exist.
##
## Payload dictionaries are intentionally loose so later phases (style scoring,
## "The Castle Learns You" telemetry) can read extra keys without signature churn.

@warning_ignore_start("unused_signal")

# --- Combat -----------------------------------------------------------------
## info keys: id, tags, time_reward, position, headshot, killer_speed, distance
signal enemy_killed(enemy: Node3D, info: Dictionary)
signal enemy_damaged(enemy: Node3D, amount: float, info: Dictionary)
signal player_damaged(amount: float, source: Node)
signal player_died(cause: StringName)
signal weapon_fired(weapon_id: StringName)

# --- Movement / world -------------------------------------------------------
signal door_breached(door: Node3D, impact_speed: float)

# --- Stopwatch / time -------------------------------------------------------
signal borrow_time_started()
signal borrow_time_ended(seconds_used: float)
signal time_debt_started(duration: float, drain_multiplier: float)
signal time_debt_ended()
## Emitted whenever seconds are added to the run timer.
signal time_granted(seconds: float, reason: StringName)
signal clock_chimed()

# --- Atmosphere ---------------------------------------------------------------
## An unexplained event happened (shift, light_dies, sound, guest, ...).
signal atmosphere_event(kind: StringName)
## The Red Death was seen (or let itself be seen).
signal guest_sighted(at: Vector3)

# --- Structure (used from Phase C onward) -----------------------------------
signal room_entered(room: Node)
signal room_cleared(room: Node)
signal floor_completed(floor_index: int)

# --- Run lifecycle ----------------------------------------------------------
signal run_started(run_seed: int)
## result keys: reason, time_survived, kills, damage_taken, doors_breached, ...
signal run_ended(result: Dictionary)

@warning_ignore_restore("unused_signal")
