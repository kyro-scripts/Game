# Design notes: locked specs, implementation defaults, architecture

This file separates **what the design has decided** from **what the code had
to pick in order to run**. Don't promote an implementation default to design
without deciding to.

## Locked (do not redesign without the designer asking)

* First person, extremely fast, aggressive horror roguelite shooter. You
  escape a castle, after *The Masque of the Red Death*.
* Dark, sparse, uncanny. The palette is almost entirely **black, white and
  red**, and nothing is cluttered for its own sake.
* Horror comes from uncanniness, space, sound, faces, repetition, impossible
  behaviour and anticipation. Gore is not the main device.
* **Every face or mask is trying to look human and failing.**
* The player holds a firearm in one hand and a visible **analog stopwatch**
  in the other.
* The stopwatch's first power is **Borrow Time**.
* Sliding. Bunny-hop movement that preserves momentum. Doors are
  **breached**, not opened.
* Procedural gothic corridors and rooms, built from modular chunks with
  sockets, not free-form geometry.
* Kills sustain the run timer.
* At the end of each floor you pick one of several rewards, presented as
  **old uncanny playing cards**.
* Each run remixes layout, events, weapon availability and stopwatch
  upgrades.
* A rank at the end of the run. Light, *horizontal* unlocks.
* **The Castle Learns You**: a bounded adaptive director.
* **The Guest in Red** is a recurring stalker and existential threat. Visual
  target: a flowing, rough-painted red hooded robe, a **white analog clock
  for a face**, and a jagged black brushstroke silhouette.
* ULTRAKILL and Post Void are *references only*. Nothing is copied from them.

## Implementation defaults currently in code (all tunable)

| Default | Value | Where |
|---|---|---|
| Ground top speed | 11 m/s | `MovementTuning.ground_max_speed` |
| Ground accel / friction | 80 m/s² / 9 | `MovementTuning` |
| Jump velocity / gravity | 7.2 m/s / 22 m/s² (about a 1.2 m apex) | `MovementTuning` |
| Bhop landing grace / jump buffer / coyote | 0.12 s / 0.15 s / 0.10 s | `MovementTuning` |
| Hop chain bonus / cap | +0.6 m/s per clean hop / 22 m/s | `MovementTuning` |
| Air strafe cap / air steer | 2.2 m/s / 1.8 rad/s | `MovementTuning` |
| Slide entry speed / boost / cooldown | 6 m/s / +4.5 m/s / 0.8 s | `MovementTuning` |
| Slide friction / min speed / max | 3 m/s² / 4 m/s / 34 m/s | `MovementTuning` |
| Capsule stand / crouch | 1.8 m / 0.9 m | `MovementTuning` |
| Breach threshold / momentum kept | 7 m/s / 92% | `MovementTuning` |
| "Sprint" | no separate key: you always run at base speed | design choice pending |
| Run timer start / cap | 90 s / 180 s | `RunRulesData` |
| Kill reward | walker 3 s, turret 2 s (design range 1.5–4 s) | `EnemyData.time_reward` |
| Player health | 100 HP, no regen | `RunRulesData.player_max_health` |
| Borrow Time world / player / audio scale | 0.35 / 0.92 / 0.55 | `BorrowTimeData` |
| Borrow max duration / recharge | 2.5 s / 8 s from empty (after 0.8 s) | `BorrowTimeData` |
| Borrow minimum charge / kill refund | 20% / +12% | `BorrowTimeData` |
| Time Debt drain / duration | 1.65× for 1–4 s, scaled by use; stacks to a 6 s cap | `BorrowTimeData` |
| Borrow input | hold (toggle available in F1) | `GameState` |
| Placeholder sidearm | 34 dmg, 0.26 s, ×2 headshot, infinite ammo | `WeaponData` |
| Physics tick | 120 Hz, Jolt | `project.godot` |
| Speed / FPS readout | on by default (prototype) | `GameState` |

## Open questions (left open on purpose)

The weapon roster; story interpretation; floor count; the number of
stopwatch powers; the unlock tree; how faces are produced as final art; the
soundtrack; the ending; whether the Red Death can be defeated; whether escape
is possible. Each one is backed by data definitions (`WeaponData`,
`StopwatchModuleData`, `RunRulesData`, `EnemyData`) so it can change later.

## Architecture

### Time

`TimeDirector` (autoload) is the only source of time scaling.

* Channels: `WORLD`, `ENEMY`, `PROJECTILE`, `ANIMATION`, `PLAYER`, `AUDIO`,
  `RUN_TIMER`. ENEMY, PROJECTILE and ANIMATION are multiplied by WORLD.
* Effects push named modifiers (`{Channel: multiplier}`), and every active
  modifier is multiplied together. Borrow Time pushes `borrow_time`, debt
  pushes `time_debt` and the end of a run pushes `run_over`. Future
  stopwatch modules add their own without knowing about these.
* Consumers multiply their real delta by their channel. `CharacterBody3D`s
  scale their velocity around `move_and_slide()`, because the engine
  integrates with its own physics delta.
* `TimeDirector.world_time` is a shared world-scaled clock. Faces blink on
  it, and the pendulum clock reads it.

### Events

`Events` (autoload) is a signal bus. It carries `enemy_killed`,
`player_damaged`, `door_breached`, `borrow_time_started/ended`,
`time_debt_started/ended`, `time_granted`, `clock_chimed`, `room_entered`,
`room_cleared`, `floor_completed`, `run_started` and `run_ended`. Payloads
are dictionaries, so later scoring and adaptive telemetry can read extra keys
without changing any signatures.

### Ownership

* `RunManager` owns the timer, stats and run lifecycle.
* `Player` owns locomotion and health.
* `StopwatchController` owns the equipped stopwatch module, which today is
  Borrow Time.
* `WeaponBase` owns firing.
* `EnemyBase` owns enemy life and death. Archetypes override
  `_tick_behaviour()`.
* `AudioDirector` owns buses and placeholder sounds. Replace a sound with
  `register_stream(name, stream)`.
* `Palette` owns every placeholder material, so re-grading the whole game
  is a one-file change.

### Placeholder → real art seams

* Weapon model: add children to `Player/Head/Camera/ViewmodelRoot/Weapon/Model`.
  The code-built placeholder only appears when `Model` is empty.
* Stopwatch: `.../Stopwatch/Model`, same rule.
* Enemy body: `Visual`. Face: `Visual/Head/Face`, which must keep
  `set_expression()` and `flash()`.
* Doors and the clock regenerate their visuals in code. Swap the scripts
  when the real art arrives.

## Roadmap

| Phase | Status |
|---|---|
| A: movement sandbox | **done**, awaiting a human feel pass |
| B: combat + time | **done** |
| C: procedural floor (sockets, seeds, validator, 100-seed stress test) | next, after feel sign-off |
| D: encounters (Rusher, Watcher, Bellkeeper on `EnemyBase`) | — |
| E: reward cards | — |
| F: uncanny systems (Frozen Dancer, Painted Crowd, Applause, Guest sightings) | — |
| G: rank + meta | — |
| H: The Castle Learns You | — |

## Known limitations of this slice

* There are no stairs or step-up yet. Level geometry uses ramps.
* Enemies steer straight at you. `NavigationAgent3D` arrives in Phase C/D
  with baked navigation per room.
* Faces, gun, stopwatch and audio are all placeholders. Their seams are
  listed above.
* Settings aren't saved yet (Phase G).
