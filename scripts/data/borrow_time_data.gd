class_name BorrowTimeData
extends StopwatchModuleData
## Tuning for the BORROW TIME stopwatch module (locked concept; all numbers
## below are implementation defaults).
##
## Hold to slow the world. The run timer keeps draining in real time while you
## borrow, and on release the clock charges TIME DEBT: it drains faster for a
## few seconds. Present control is paid for with future safety.

@export_group("Slowdown")
## Multiplier applied to the WORLD channel while fully engaged.
@export_range(0.05, 1.0, 0.01) var world_scale: float = 0.35
## Multiplier applied to the PLAYER channel. Close to 1 = player stays sharp.
@export_range(0.1, 1.0, 0.01) var player_scale: float = 0.92
## Pitch/tempo multiplier for world-sourced sounds.
@export_range(0.1, 1.0, 0.01) var audio_scale: float = 0.55
## Seconds to ease in / out of the slowdown (real time).
@export_range(0.0, 1.0, 0.01, "suffix:s") var ramp_in_time: float = 0.08
@export_range(0.0, 1.0, 0.01, "suffix:s") var ramp_out_time: float = 0.18

@export_group("Charge")
## Real seconds a full charge lasts while held.
@export_range(0.1, 10.0, 0.05, "suffix:s") var max_duration: float = 2.5
## Minimum charge (0..1) needed to start borrowing.
@export_range(0.0, 1.0, 0.01) var min_charge_to_activate: float = 0.2
## Delay after release before charge refills.
@export_range(0.0, 5.0, 0.05, "suffix:s") var recharge_delay: float = 0.8
## Real seconds to refill from empty to full.
@export_range(0.5, 60.0, 0.5, "suffix:s") var recharge_time: float = 8.0
## Charge (0..1) restored instantly per kill.
@export_range(0.0, 1.0, 0.01) var charge_per_kill: float = 0.12
## Lockout after a release so the power cannot be flickered.
@export_range(0.0, 2.0, 0.05, "suffix:s") var reactivation_cooldown: float = 0.35

@export_group("Time Debt")
## Run-timer drain multiplier while in debt.
@export_range(1.0, 5.0, 0.05) var debt_drain_multiplier: float = 1.65
## Debt duration for a full-length borrow.
@export_range(0.0, 15.0, 0.1, "suffix:s") var debt_max_duration: float = 4.0
## Debt duration floor for a very short borrow.
@export_range(0.0, 15.0, 0.1, "suffix:s") var debt_min_duration: float = 1.0
## If true, debt length scales with how long you actually borrowed.
@export var debt_scales_with_use: bool = true
## Debt from repeated borrows stacks, but never beyond this.
@export_range(0.0, 30.0, 0.1, "suffix:s") var debt_stack_cap: float = 6.0
