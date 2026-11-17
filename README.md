# Masque Prototype *(working title)*

A first-person, very fast, sparse horror roguelite shooter set inside a castle,
built on Poe's public-domain *The Masque of the Red Death*. You flee through
rooms of black, white and red, carrying a gun in one hand and an analog
stopwatch in the other.

**Engine:** Godot **4.7.x**, GDScript, desktop, keyboard + mouse.
**Status:** **Phases A + B done:** movement sandbox, combat, run timer,
Borrow Time and Time Debt. Procedural floors (Phase C) haven't started yet,
on purpose: movement feel gets signed off first (see *Next step* below).

---

## Running it

1. Open the folder in Godot 4.7 (Project Manager → Import → `project.godot`).
2. Press **F5** (Run Project). The game loads straight into the graybox sandbox.

| Input | Action |
|---|---|
| Mouse | Look |
| W A S D | Move (you always run; base speed is about 11 m/s) |
| Space | Jump. Press it just as you land to bunny-hop. |
| Ctrl / Shift / C | Slide when moving fast; crouch when slow. Hold it in the air to slide on landing. |
| Left mouse | Fire |
| Right mouse / E | **Borrow Time** (hold) |
| F1 | Debug menu (pauses the game; live tuning sliders) |
| F3 | Speed / state readout |
| F5 | Restart run |
| Esc | Pause and release the mouse |

### The sandbox (`scenes/sandbox/movement_sandbox.tscn`)

You spawn at the start of the **speed hall**. Teleport between areas from F1 → Teleport.

* **Speed hall** (0 → −100 m). Pillars every 8 m make speed readable, and
  floor markers show every 10 m. It has a hurdle (**jump**), a low gate
  (**slide** under it), a ramp up to a platform with a long ramp down
  (**slide downhill** to gain speed), and a low tunnel (a sustained slide).
  A static target dummy stands at 10 m. A lantern-turret dummy sits on the
  platform.
* **Door gallery** (−100 → −160 m). A tight corridor with **4 breachable
  doors**. Hit one above about 7 m/s and it bursts. A slow touch makes it
  creak open, which takes long enough to feel like a penalty.
* **Arena** (−160 → −200 m). Has 3 walker dummies, 2 lantern turrets and a
  pendulum wall clock that runs on *world* time, so Borrow Time shows up
  everywhere. Dummies respawn 4 s after they die.

The dummies are **test dummies**, not canon enemies. The Rusher, Watcher and
Bellkeeper come in Phase D, built on the same `EnemyBase`.

---

## What's implemented

### Movement (Phase A)
* A custom `CharacterBody3D` controller (`scripts/player/player.gd`) with
  ground, air and slide states.
* **Bunny-hopping.** Landing opens a 0.12 s *grace window* with no ground
  friction. A jump inside it (the 0.15 s jump buffer makes this forgiving)
  keeps all your momentum and adds a **hop bonus**. Late jumps bleed speed
  back to run speed. Tested: 8 clean hops take you from 11.0 to 15.8 m/s.
* **Air control.** Quake-style strafe acceleration plus a gentle steer that
  never costs you speed.
* **Slide.** One boost when you enter (with a cooldown), low friction,
  slopes speed it up, lower capsule, and you can't stand up under a low
  ceiling. Slide-jumps keep their speed, and landing with slide held goes
  straight into a slide.
* **Door breach.** If you hit a door faster than `breach_min_speed`, it
  splinters along your path and you keep about 92% of your speed.
* **Camera feel.** FOV widens with speed, the view rolls into strafes and
  slides, dips when you land, and shakes on impacts and shots. The trauma
  shake and recoil are tuned separately.
* Every number is in `data/movement/default_movement.tres`
  (`MovementTuning`). You can tune it live in **F1 → Live tuning** and use
  **Save tuning** to write it back.

### Combat, time and the run (Phase B)
* **Hitscan placeholder sidearm.** Rays hit enemy *hurtboxes*, and head hits
  get a multiplier. Firing gives a muzzle flash, a red tracer, recoil, a kick
  and hit/kill markers on the crosshair.
* **`EnemyBase`** handles health, stagger, death, line of sight and head
  tracking. Two test archetypes use it: a **walker** (chases, telegraphs,
  lunges) and a **lantern turret** (slow projectiles).
* **Uncanny placeholder faces** (`FaceRig`). The eyes are slightly off, the
  smile is too symmetrical and too wide, every face blinks on one shared
  clock, expressions snap with no transition, and heads track you at a
  constant angular speed. Masks drop face-up when an enemy dies. There's no
  gore.
* **Run timer.** You start with 90 s (cap 180 s). Kills add `time_reward`
  (3 s walker, 2 s turret). The run ends when the clock hits zero or you die.
* **Borrow Time.** Hold it and the world runs at 0.35× while you stay at
  0.92×. The **run timer keeps draining in real time**. A full charge lasts
  2.5 s and recharges, and kills refund 12%. When you let go you take
  **Time Debt**: the timer drains at 1.65× for 1–4 s, depending on how long
  you borrowed.
* **`TimeDirector`.** Separate channels for WORLD, ENEMY, PROJECTILE,
  ANIMATION, PLAYER, AUDIO and RUN_TIMER, set by stackable named modifiers.
  `Engine.time_scale` is never used for gameplay.
* **The stopwatch is the interface.** The red hand unwinds toward twelve,
  the subdial shows minutes and 12 bezel pips show charge. During Borrow Time
  the face inverts and the thumb presses the crown. In debt the hand sweeps
  nervously. When time is low it ticks louder and jolts.
* **Audio.** Every placeholder sound is synthesised in code
  (`AudioDirector`). During Borrow Time the World bus is low-passed and world
  sounds pitch down; the gun and stopwatch stay crisp.
* **Palette grade** (`shaders/palette_post.gdshader`). Anything not strongly
  red collapses to monochrome. Borrow Time adds a tight vignette and a radial
  smear. Debt, damage and low time push red in from the edges.
* **Run-end screen** shows raw stats. Ranking comes in Phase G.

---

## Project layout

```
autoload/      Events (signal bus), GameState, TimeDirector, AudioDirector, RunManager
data/          .tres tuning: movement, borrow time, weapons, enemies, run rules
scripts/data/  Resource classes for that data
scripts/player Player controller, camera feel, StopwatchController (Borrow Time)
scripts/viewmodel  Hands rendering (separate camera, fixed FOV), stopwatch, sway
scripts/weapons    WeaponBase (hitscan)
scripts/enemies    EnemyBase, FaceRig, Hurtbox, test dummies, Projectile
scripts/world      BreachableDoor, PendulumClock, SandboxBlockout, spawners, debris
scripts/ui         HUD, PostProcess, DebugOverlay, DebugMenu, RunEndScreen
scenes/        main, player, enemies, door, sandbox
tests/         headless gameplay tests (94 checks)
tools/         validate_project.gd, run_tests.sh
docs/          DESIGN_NOTES.md: locked specs vs implementation defaults, architecture
```

## Tests

```bash
tools/run_tests.sh /path/to/godot   # import, validate all files, run tests, smoke-run main
```

The tests drive the game the way a player would, through input actions,
jumps and trigger pulls, and then check physical outcomes. Some examples:
top speed reached within 0.25 s, the hop chain builds speed and late hops
don't, slide boost and friction, staying crouched under a ceiling, momentum
through a breach, a slow push not counting as a breach, body shots and
headshots needed for a kill, the time reward on a kill, world/enemy/projectile
slowdown, the timer staying real-time during Borrow Time, debt length and
drain rate, charge gating and refill, and the run ending on time-out or death.

---

## Next step: needs a human playtest

Phase A's exit criterion is that the movement **feels** right. That can't be
verified headlessly. Before Phase C (procedural floors) starts, please play
the sandbox and report:

1. Is the run speed of 11 m/s fast enough? Is the hop bonus of +0.6 per hop
   too generous or too stingy?
2. Is the bhop timing window (0.12 s grace + 0.15 s buffer) too forgiving?
3. Is the slide boost and its friction right? Does the downhill slide feel good?
4. Is the breach threshold of 7 m/s right?
5. Borrow Time: is 0.35× world for 2.5 s, plus 1.65× debt, the right trade?
6. Mouse sensitivity and base FOV (both adjustable in F1).

Every one of these is a slider in **F1 → Live tuning**.
