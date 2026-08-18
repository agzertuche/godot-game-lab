# Elevator Rush Abstract Roguelite MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a neutral, abstract Elevator Rush V3 prototype that tests whether randomized upgrades and escalating autonomous traffic create a compelling run-based progression loop.

**Architecture:** Create `prototypes/elevator-rush/v3` as a separate Godot project so V2 remains a preserved strategy-wave reference. Carry over only the request-driven simulation concepts—passengers, hall requests, dispatcher, controller, and presentation adapter—then add a small RunManager, data-driven stage definitions, and a compact upgrade-choice layer. The player never drives an elevator; choices only change system rules between stages.

**Tech Stack:** Godot 4.7, GDScript, Compatibility renderer, primitive Control/Node2D visuals, lightweight headless SceneTree test runner.

**Assumption:** V3 starts with three elevators and allows its building to unlock floors from three to five over a single run. It deliberately does not inherit V2's live per-elevator configuration UI, fixed four-level campaign, grade gate, or theme.

---

### Task 1: Create the isolated V3 project and document the MVP loop

**Files:**
- Create: `prototypes/elevator-rush/v3/project.godot`
- Create: `prototypes/elevator-rush/v3/scenes/Main.tscn`
- Create: `prototypes/elevator-rush/v3/scripts/main.gd`
- Create: `prototypes/elevator-rush/v3/README.md`
- Create: `prototypes/elevator-rush/v3/CONTEXT.md`

**Step 1: Write the five-line README concept**

Document:

```text
Player: chooses one system upgrade between autonomous traffic stages.
Objective: improve an elevator build until escalating traffic overwhelms it.
Main obstacle: passenger backlog, waits, and finite elevator throughput.
Win condition: complete the small MVP stage sequence.
Lose condition: backlog/wait-pressure threshold fails the run.
```

List no more than ten MVP tasks and explicitly defer theme, economy, rerolls, rarities, meta-progression, and non-abstract art.

**Step 2: Configure the project**

Use a 600×960 portrait viewport and Compatibility renderer. Make `Main.tscn` the startup scene.

**Step 3: Add neutral shell UI**

Create three initially hidden panels: Stage HUD, UpgradeChoicePanel, and RunResultPanel. Use generic labels such as `STAGE 1`, `SYSTEM UPGRADE`, and `RUN OVER`; no lore/themed terminology.

**Step 4: Validate project parsing**

Run when Godot is available:

```bash
godot --headless --path prototypes/elevator-rush/v3 --editor --quit
```

Expected: exit 0.

**Step 5: Commit**

```bash
git add prototypes/elevator-rush/v3
git commit -m "feat: create elevator rush roguelite shell"
```

### Task 2: Port the small autonomous simulation foundation without V2 campaign UI

**Files:**
- Create: `prototypes/elevator-rush/v3/scripts/simulation/simulation_types.gd`
- Create: `prototypes/elevator-rush/v3/scripts/simulation/passenger.gd`
- Create: `prototypes/elevator-rush/v3/scripts/simulation/hall_request.gd`
- Create: `prototypes/elevator-rush/v3/scripts/simulation/hall_request_manager.gd`
- Create: `prototypes/elevator-rush/v3/scripts/simulation/elevator_controller.gd`
- Create: `prototypes/elevator-rush/v3/scripts/simulation/elevator_dispatcher.gd`
- Create: `prototypes/elevator-rush/v3/tests/elevator_run_test.gd`

**Step 1: Write the failing foundation test**

Create a `SceneTree` runner that expresses the essential pipeline:

```gdscript
func test_passenger_request_becomes_delivery() -> void:
    # Passenger 1 -> 3 creates one UP hall request.
    # Dispatcher assigns it, controller boards it, then destination 3 completes it.
    pass
```

**Step 2: Run red**

```bash
godot --headless --path prototypes/elevator-rush/v3 -s res://tests/elevator_run_test.gd
```

Expected: non-zero exit because models do not exist.

**Step 3: Port only proven model responsibilities**

Retain:

- Passenger state and request direction.
- Consolidated floor/direction hall requests.
- Isolated deterministic dispatcher scoring seam.
- Directional collective routing, destination-stop deduplication, capacity, door dwell, dropoff-before-pickup, and leftover demand re-offer.

Do not port V2's levels, results grade, preparation controls, behavior modes, or live strategy editor.

**Step 4: Run green**

Run the same command. Expected: exit 0.

**Step 5: Commit**

```bash
git add prototypes/elevator-rush/v3/scripts/simulation prototypes/elevator-rush/v3/tests/elevator_run_test.gd
git commit -m "feat: add autonomous elevator simulation"
```

### Task 3: Define data-driven stages and a single run state machine

**Files:**
- Create: `prototypes/elevator-rush/v3/scripts/run/stage_definition.gd`
- Create: `prototypes/elevator-rush/v3/scripts/run/run_manager.gd`
- Modify: `prototypes/elevator-rush/v3/scripts/main.gd`
- Modify: `prototypes/elevator-rush/v3/tests/elevator_run_test.gd`

**Step 1: Write failing stage progression tests**

Assert the run starts at Stage 1 with three floors, advances only after active traffic drains within its threshold, and ends in failure when backlog pressure exceeds its threshold.

**Step 2: Add fixed MVP stages**

Use a typed `StageDefinition` with `floor_count`, `passenger_count`, `spawn_duration`, `traffic_pattern`, and `failure_threshold`. Start with exactly five stages:

| Stage | Floors | Pattern | Purpose |
| --- | ---: | --- | --- |
| 1 | 3 | light lobby-up | teach baseline |
| 2 | 4 | denser lobby-up | raise throughput need |
| 3 | 4 | rush mixed direction | test direction handling |
| 4 | 5 | upper-floor return | add coverage pressure |
| 5 | 5 | fixed constraint pattern | final MVP stress |

Use fixed seeds for reproducible stage demand during balancing.

**Step 3: Implement RunManager phases**

```gdscript
enum RunPhase { STAGE_INTRO, RUNNING, UPGRADE_CHOICE, FAILED, WON }
```

RunManager owns stage spawn timing, no-new-spawns/draining transition, escalating backlog pressure, advance/failure transitions, and signals. It must not own dispatch routing.

**Step 4: Define the minimal failure rule**

Fail when either active waiting passenger count or the oldest waiting time crosses the current stage's named threshold. Expose both values to HUD/debug output. Do not add satisfaction, money, or multiple failure meters.

**Step 5: Run test and commit**

```bash
godot --headless --path prototypes/elevator-rush/v3 -s res://tests/elevator_run_test.gd
git add prototypes/elevator-rush/v3/scripts/run prototypes/elevator-rush/v3/scripts/main.gd prototypes/elevator-rush/v3/tests/elevator_run_test.gd
git commit -m "feat: add escalating elevator run stages"
```

### Task 4: Add a compact, data-driven upgrade pool and application boundary

**Files:**
- Create: `prototypes/elevator-rush/v3/scripts/upgrades/upgrade_definition.gd`
- Create: `prototypes/elevator-rush/v3/scripts/upgrades/upgrade_manager.gd`
- Modify: `prototypes/elevator-rush/v3/scripts/simulation/elevator_controller.gd`
- Modify: `prototypes/elevator-rush/v3/scripts/simulation/elevator_dispatcher.gd`
- Modify: `prototypes/elevator-rush/v3/scripts/main.gd`
- Modify: `prototypes/elevator-rush/v3/tests/elevator_run_test.gd`

**Step 1: Write failing deterministic-choice tests**

Given a seeded random generator and an empty run build, assert exactly three unique choices appear, applying one updates the correct system stat/rule, and the same seed produces the same offer sequence.

**Step 2: Implement exactly 12 definitions**

Use a typed definition with `id`, `title`, `description`, and one explicit effect type/value. Initial pool:

```text
Motor Tune          + elevator speed
Cabin Expansion     + capacity
Door Actuators      - door dwell
Patient Crowd       + passenger patience
Lobby Parking       idle cars stage at floor 1
Directional Bias    dispatcher favors matching service direction
Express Service     riders cause incompatible hall calls to be skipped
Priority Routing    old requests receive stronger dispatcher age weight
Traffic Preview     show the next stage definition
Quick Boarding      faster transfer time
Dispatch Relay      lower intermediate-stop penalty
Wide Service        elevator zones extend to all unlocked floors
```

Keep effects additive/simple. No rarity, upgrade levels, rerolls, shops, or unlock tree.

**Step 3: Apply effects through explicit tunable fields**

UpgradeManager owns the run's chosen definitions and applies them only between stages. It changes controller/dispatcher/passenger tuning values through named setters; it must not mutate UI or choose routes directly.

**Step 4: Define simple synergy visibility**

Do not add a synergy system. The HUD's `BUILD` line lists chosen upgrades so combinations such as speed + quick boarding or directional bias + priority routing can be recognized in play.

**Step 5: Run test and commit**

```bash
godot --headless --path prototypes/elevator-rush/v3 -s res://tests/elevator_run_test.gd
git add prototypes/elevator-rush/v3/scripts/upgrades prototypes/elevator-rush/v3/scripts/simulation prototypes/elevator-rush/v3/scripts/main.gd prototypes/elevator-rush/v3/tests/elevator_run_test.gd
git commit -m "feat: add randomized elevator upgrades"
```

### Task 5: Connect upgrade choices and abstract simulation presentation

**Files:**
- Modify: `prototypes/elevator-rush/v3/scenes/Main.tscn`
- Modify: `prototypes/elevator-rush/v3/scripts/main.gd`
- Create: `prototypes/elevator-rush/v3/scripts/presentation/elevator_view.gd`
- Create: `prototypes/elevator-rush/v3/scripts/presentation/passenger_view.gd`

**Step 1: Wire RunManager signals**

Connect stage-start, upgrade-offered, run-failed, and run-won events. The UI reflects RunManager state; buttons only select one of three offered upgrades or start/restart a run.

**Step 2: Create readable placeholder visuals**

Draw a neutral vertical building with floor numbers increasing upward, generic circles/rectangles for passengers/cars, waiting queue count, capacity, passenger destination labels, and direction arrows. Keep animation limited to logical position interpolation and door state.

**Step 3: Implement UpgradeChoicePanel**

Show three large, equally prominent buttons with title and one-line mechanical description. Disable/hide the rest of the UI until one is selected. `Traffic Preview` may additionally reveal the following stage line after selection.

**Step 4: Implement the Stage HUD**

Show `STAGE`, active passenger backlog, oldest wait, current stage goal/threshold, and `BUILD`. Use high-contrast values and no themed wording.

**Step 5: Run the project and commit**

```bash
godot --headless --path prototypes/elevator-rush/v3 --quit-after 2
git add prototypes/elevator-rush/v3/scenes/Main.tscn prototypes/elevator-rush/v3/scripts/main.gd prototypes/elevator-rush/v3/scripts/presentation
git commit -m "feat: add elevator roguelite run UI"
```

### Task 6: Tune the MVP run and record validation findings

**Files:**
- Modify: `prototypes/elevator-rush/v3/scripts/run/stage_definition.gd`
- Modify: `prototypes/elevator-rush/v3/scripts/upgrades/upgrade_manager.gd`
- Modify: `prototypes/elevator-rush/v3/README.md`
- Modify: `prototypes/elevator-rush/v3/CONTEXT.md`
- Modify: `prototypes/elevator-rush/v3/tests/elevator_run_test.gd`

**Step 1: Add deterministic balance checks**

Assert baseline Stage 1 is completable, an intentionally weak build fails by a later stage, and a representative upgrade build can reach farther. Do not assert an exact optimal build or a universal win rate.

**Step 2: Run manual validation**

At 600×960, complete several runs with different seeded upgrade offers. Record:

- Whether the three choices are understandable without a tooltip.
- Whether choices combine into understandable builds.
- Whether harder stages create observable backlog/failure pressure.
- Whether a loss motivates another run.
- Whether any choice is an obvious mandatory pick.

**Step 3: Tune only named stage/upgrade constants**

Adjust spawn rate, thresholds, and effect values. Do not add new upgrade systems to solve balance issues.

**Step 4: Final validation and commit**

```bash
git diff --check
godot --headless --path prototypes/elevator-rush/v3 -s res://tests/elevator_run_test.gd
godot --headless --path prototypes/elevator-rush/v3 --editor --quit
godot --headless --path prototypes/elevator-rush/v3 --quit-after 2
git add prototypes/elevator-rush/v3
git commit -m "test: tune elevator roguelite mvp"
```

Document actual findings and retain intentional limitations: no economy, themed content, rerolls, rarity, meta-progression, dynamic prediction, or additional passenger types.

### Task 7: Final scope review

**Files:**
- Review: `prototypes/elevator-rush/v3/`
- Review: `prototypes/elevator-rush/v2/`

**Step 1: Verify boundaries**

Confirm V1 and V2 are unchanged by V3 implementation, no non-abstract art/audio/narrative was introduced, and the only player commands are Start/Restart and one upgrade choice between stages.

**Step 2: Review against the MVP question**

Confirm the run supports the intended evidence: randomized choices alter the autonomous system, traffic grows harder, failure is understandable, and the player receives enough feedback to compare builds.

**Step 3: Run repository check**

```bash
git diff --check
git status --short
```
