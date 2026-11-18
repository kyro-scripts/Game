# Masque Prototype *(working title)*

A first-person, very fast, sparse horror roguelite shooter set inside a castle,
built on Poe's public-domain *The Masque of the Red Death*. You flee through
rooms of black, white and red, carrying a gun in one hand and an analog
stopwatch in the other.

**Engine:** Godot **4.7.x**, GDScript, desktop, keyboard + mouse.
**Status:** **Phases A + B done:** movement sandbox, combat, run timer,
Borrow Time and Time Debt, plus a minimalist surreal-horror visual
overhaul: the dream-castle sandbox, almost-human enemies, the Red Death,
the held stopwatch and atmosphere. Procedural floors (Phase C) haven't started yet,
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

An impossible, minimal dream-castle, built from code. The run seed varies its
inconsistencies. Teleport between spaces from F1 → Teleport.

| Space | What it is | Movement test |
|---|---|---|
| **Vestibule** | A crooked, low room. The door you came in by is too small to have fitted through, and a tall slit leads on. | — |
| **The Narrowing** | A twisting corridor that tightens as its ceiling sinks. Dim chalk lines mark the floor edges. One dark stretch is lit only by light leaking under a door. | **jump** the beam |
| **The Long Hall** | Massive (32 × 92 m), empty and black, with isolated pools of white light from far overhead. Eleven identical doors along one wall leak light; one is lifted off the floor and one is missing. There's a door nine metres up the other wall, a single high **red** window framed by jagged black forms, and a white chair that moves when you aren't looking. | **slide** under the black monolith; the **dais** is for sliding downhill; the far wall's **long low slot** is for a sustained slide |
| **Low chamber** | A 2.9 m ceiling after the hall's thirty, and a pillar far too thin for its load. | — |
| **The Repeating Corridor** | Four identical bays, each with one bulb and a side door. One bay's bulb is on the wrong side, one bay is dark, one side door is on the other wall, and one door has a face fixed to it. | **4 breachable doors** |
| **Clock chamber** | An irregular room with a checkerboard floor that slowly swells out of true. Pillars are the wrong sizes, one leans, and one hangs from nothing. The pendulum clock is framed by jagged black forms. | combat (dummies respawn) |

The dummies are **test dummies**, not canon enemies. The Rusher, Watcher and
Bellkeeper come in Phase D, built on the same `EnemyBase`.

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

### Look: minimalist surreal horror
**Black dominates. White defines the shapes you need: faces, hands, edges,
doors and light. Red is rare and means danger, the supernatural or the Red
Death.** Everything is procedural; nothing is imported.

* **Materials** (`shaders/`):
  * `painted_surface`: rough, imperfect brushwork, with drifting stroke
    direction, dry-brush ridges, drips, rare cracks and wet sheen. It has no
    bricks.
  * `lacquer_floor`: near-mirror black, so isolated lights double in it. It
    has an optional warped checkerboard.
  * `skin`: painted, waxy and faintly self-lit.
  * `cloth`: rough painted streaks and a pale edge, so dark figures read
    against black.
* **Lighting:** ambient light is almost nothing. You get islands of white:
  bare bulbs on long cords, tight overhead pools with volumetric shafts, light
  leaking under doors, and dim chalk lines along floor edges and openings so
  geometry reads at speed. The watch's luminous dial lights the space just
  around you.
* **Enemies:** almost-human, something imitating a person.
  * Eyes are slightly too far apart and too low, the eyebrows too high, the
    nose too short. The mouth is too wide and too close to the nose, with
    corners turned up too sharply and a sliver of too many teeth.
  * Real eyeballs stare at you. One is set a few degrees off, and now and then
    both snap to stare at nothing.
  * Every face blinks together, rarely.
  * Bodies are stiff, like stop-motion, while the heads glide. Heads sometimes
    snap to a wrong tilt. Necks are too long and arms hang to the knees.
  * The irises burn **red** only when one means to hurt you.
* **The Guest in Red** (the Red Death), after the reference: a rough-painted
  red hood, a white clock where the face should be with hands running
  backwards, and jagged black forms in a red haze. It is a sighting, not a
  fight. It's gone if you approach or hold your gaze.
* **Atmosphere** (`AtmosphereDirector`). Silence is the default, with only a
  faint pressure tone and clocks somewhere in the dark, out of step with your
  watch. Every 18–42 s one unexplained thing happens:
  * a Red Death sighting;
  * a light dying for a moment;
  * a whisper, distant slam, drone, wrong note or breathing;
  * a door's light turning red;
  * every clock stopping at once.

  None of these are jumpscares. You can trigger each from F1 → Atmosphere.
* **The stopwatch is held.** A gloved hand's jointed fingers curl round the
  case and the thumb sits on the crown. The thumb visibly presses the crown,
  which depresses. A white cuff and a sleeve lead back toward the camera.
  Spring-driven motion answers everything you do: it lifts toward your eyes
  to read during Borrow Time, dips at a sprint, leans into strafes and slides,
  lags jumps, jolts on landings and shots, rattles in debt and trembles on low
  time.
* **Performance:** volumetric fog plus about 9 shadowed spot lights. If needed,
  untick `window_shafts` on the sandbox's `Blockout` node.

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
scripts/world      BreachableDoor, PendulumClock, SandboxBlockout, CastleProps, FlickerLight, spawners
scripts/util       Palette, CastleMaterials, MeshKit (lathe / sweep / arches / vault / mask / curtain)
scripts/ui         HUD, PostProcess, DebugOverlay, DebugMenu, RunEndScreen
scenes/        main, player, enemies, door, sandbox
tests/         headless gameplay tests (98 checks)
tools/         validate_project.gd, run_tests.sh, capture_screenshots.tscn
docs/          DESIGN_NOTES.md: locked specs vs implementation defaults, architecture
```

## Tests

```bash
tools/run_tests.sh /path/to/godot   # import, validate all files, run tests, smoke-run main
```

For visual checks, `res://tools/capture_screenshots.tscn` boots the real game
and saves PNGs of key moments to `user://screenshots/` (or `$SHOT_DIR`):
* every space in the sequence;
* the jump, the slide under the monolith and a door bursting;
* the red window and a Red Death sighting;
* a face close-up and a face macro;
* a red-eyed attack windup, firing and a kill;
* Borrow Time with the watch raised, Time Debt and low time;
* the debug menu and the run-end screen.

Short-lived effects are photographed in engine slow motion.
It needs a real renderer, so run it without `--headless`.

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
