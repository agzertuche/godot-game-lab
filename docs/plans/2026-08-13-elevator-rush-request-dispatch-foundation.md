# Elevator Rush Request-Dispatch Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Elevator Rush V2's passenger-list-driven claims with a deterministic, autonomous collective-selective request and dispatch simulation foundation.

**Architecture:** Preserve `Main.tscn` and primitive visuals as presentation. Add simulation classes where `HallRequestManager` consolidates passenger demand, `ElevatorDispatcher` alone assigns unassigned hall requests, and `ElevatorController` owns only assigned requests, destinations, passenger transfers, doors, and collective routing. Controllers emit simulation events; Node2D visuals observe those events/state.

**Tech Stack:** Godot 4.7, typed GDScript, Compatibility renderer, a lightweight headless `SceneTree` test runner.

**Reference:** Peters describes conventional collective operation as serving same-direction landing calls and car calls in one direction before reversing, while dispatcher ETA may account for stops and load. [Peters, *Elevator Dispatching*](https://download.peters-research.com/library/Elevator_Dispatching.pdf)

---

### Task 1: Define simulation vocabulary and a headless test entry point

**Files:**
- Create: `prototypes/elevator-rush/v2/scripts/simulation/simulation_types.gd`
- Create: `prototypes/elevator-rush/v2/tests/collective_control_test.gd`
- Modify: `prototypes/elevator-rush/v2/CONTEXT.md`
- Modify: `prototypes/elevator-rush/v2/README.md`

**Step 1: Write a failing test runner**

Create the test entry script as `SceneTree`; begin with a failing assertion named `TODO: up service ignores down hall calls`.

**Step 2: Verify red**

Run:

```bash
godot --headless --path prototypes/elevator-rush/v2 -s res://tests/collective_control_test.gd
```

Expected: non-zero exit. If Godot is unavailable, record it and retain the runner for later.

**Step 3: Add shared domain enums**

Implement typed, logic-free common types:

```gdscript
class_name SimulationTypes
extends RefCounted

enum Direction { DOWN = -1, IDLE = 0, UP = 1 }
enum PassengerState { WAITING, ASSIGNED, BOARDING, RIDING, EXITING, COMPLETED }
enum MovementState { IDLE, MOVING, STOPPED }
enum DoorState { CLOSED, OPENING, OPEN, CLOSING }
```

**Step 4: Turn green**

Replace the placeholder with an assertion that `SimulationTypes.Direction.UP == 1`, then run the same test command. Expected: exit 0.

**Step 5: Record vocabulary**

Add concise glossary definitions for Hall Request, Destination Request, Service Direction, Movement State, and Door State. README should name request-driven collective control as the simulation model.

**Step 6: Commit**

```bash
git add prototypes/elevator-rush/v2/scripts/simulation/simulation_types.gd prototypes/elevator-rush/v2/tests/collective_control_test.gd prototypes/elevator-rush/v2/CONTEXT.md prototypes/elevator-rush/v2/README.md
git commit -m "feat: add elevator simulation vocabulary"
```

### Task 2: Add independent passenger demand and consolidated Hall Requests

**Files:**
- Create: `prototypes/elevator-rush/v2/scripts/simulation/hall_request.gd`
- Create: `prototypes/elevator-rush/v2/scripts/simulation/hall_request_manager.gd`
- Modify: `prototypes/elevator-rush/v2/scripts/passenger.gd`
- Modify: `prototypes/elevator-rush/v2/tests/collective_control_test.gd`

**Step 1: Write failing consolidation tests**

At the public `HallRequestManager.register_waiting_passenger(passenger, now)` seam, assert two Floor 5 UP passengers share one request, a Floor 5 DOWN passenger creates another, and impossible Floor 1 DOWN/Floor 10 UP calls are rejected.

**Step 2: Verify red**

Run the headless runner. Expected: missing models/manager failure.

**Step 3: Implement HallRequest**

Create a typed `RefCounted` containing `floor`, `direction`, `created_at`, `waiting_passengers`, and `assigned_elevator_id`. Provide `waiting_time(now)`, add/remove waiting passengers, and `is_active()`.

**Step 4: Extend Passenger**

Use `SimulationTypes.PassengerState`; add `requested_direction`, `request_time`, and `assigned_elevator_id`. Derive direction in `configure`; retain drawing only. Passenger must not call elevator/controller methods.

**Step 5: Implement HallRequestManager**

Use a floor/direction dictionary key, own active request lifecycle, and emit `hall_request_created` / `hall_request_completed`. Expose `get_unassigned_requests()`, `get_active_requests()`, and `remove_passenger_from_request()`. A request ends only when no waiting passenger remains.

**Step 6: Verify green and commit**

Run the headless runner; expected exit 0. Then:

```bash
git add prototypes/elevator-rush/v2/scripts/simulation/hall_request.gd prototypes/elevator-rush/v2/scripts/simulation/hall_request_manager.gd prototypes/elevator-rush/v2/scripts/passenger.gd prototypes/elevator-rush/v2/tests/collective_control_test.gd
git commit -m "feat: add passenger hall requests"
```

### Task 3: Create a collective-selective ElevatorController

**Files:**
- Create: `prototypes/elevator-rush/v2/scripts/simulation/elevator_controller.gd`
- Modify: `prototypes/elevator-rush/v2/scripts/elevator.gd`
- Modify: `prototypes/elevator-rush/v2/tests/collective_control_test.gd`

**Step 1: Write failing controller tests**

At Floor 2, UP direction, assigned requests `3/UP`, `4/DOWN`, `6/UP`, and destination 7: assert stops are `3 → 6 → 7`, followed only then by reversal for `4/DOWN`. Add mirror DOWN test.

**Step 2: Implement controller state and pure routing seam**

Controller owns `current_floor`, `movement_state`, `service_direction`, `passengers`, `capacity`, `assigned_hall_requests`, destination-stop Dictionary, and `door_state`. Implement:

```gdscript
func is_request_compatible(request: HallRequest) -> bool
func next_stop() -> int
func recalculate_service_direction() -> int
func add_hall_request(request: HallRequest) -> void
func add_destination_request(floor: int) -> void
```

UP serves only UP requests/destinations above in ascending order while work remains; DOWN mirrors it. IDLE travels to assigned origin then adopts its request direction. Destination Dictionary makes duplicated destination floors one stop.

**Step 3: Convert RushElevator to presentation adapter**

Retain Node2D motion and circle drawing. Remove global request claiming/routing policy; it reads one controller's next stop and invokes controller stop processing after physical arrival.

**Step 4: Verify green and commit**

Run headless tests; expected exit 0. Then:

```bash
git add prototypes/elevator-rush/v2/scripts/simulation/elevator_controller.gd prototypes/elevator-rush/v2/scripts/elevator.gd prototypes/elevator-rush/v2/tests/collective_control_test.gd
git commit -m "feat: add collective elevator controller"
```

### Task 4: Add an isolated cost-based ElevatorDispatcher

**Files:**
- Create: `prototypes/elevator-rush/v2/scripts/simulation/elevator_dispatcher.gd`
- Modify: `prototypes/elevator-rush/v2/tests/collective_control_test.gd`

**Step 1: Write failing dispatcher tests**

Given two known controller states and one Hall Request, assert a lower ETA/compatible direction car wins. Assert a 20-second-aged request receives a lower score than a new equivalent request.

**Step 2: Implement dispatcher boundary**

`ElevatorDispatcher` has no visual dependency and exposes:

```gdscript
func calculate_assignment_cost(controller: ElevatorController, request: HallRequest, now: float) -> float
func assign_unassigned_requests(controllers: Array[ElevatorController], requests: Array[HallRequest], now: float) -> void
```

Keep ETA, intermediate-stop, direction-mismatch, load, and waiting-age weights as named constants in this file. Assignment sets request ownership and calls only `controller.add_hall_request(request)`. Emit `hall_request_assigned`.

**Step 3: Verify green and commit**

Run headless tests; expected exit 0. Then:

```bash
git add prototypes/elevator-rush/v2/scripts/simulation/elevator_dispatcher.gd prototypes/elevator-rush/v2/tests/collective_control_test.gd
git commit -m "feat: add hall request dispatcher"
```

### Task 5: Implement ordered stops, capacity, and request lifecycle

**Files:**
- Modify: `prototypes/elevator-rush/v2/scripts/simulation/elevator_controller.gd`
- Modify: `prototypes/elevator-rush/v2/scripts/simulation/hall_request_manager.gd`
- Modify: `prototypes/elevator-rush/v2/tests/collective_control_test.gd`

**Step 1: Write failing transfer tests**

Assert stop processing exits riders before boarding, boards only capacity and compatible direction, leaves excess riders on an active Hall Request, and adds a single destination stop for duplicate destinations.

**Step 2: Implement the explicit stop contract**

Add:

```gdscript
func process_stop(request_manager: HallRequestManager, now: float) -> Dictionary
```

Required order: arrive → doors open → exits → free capacity → compatible boardings → destination requests → doors close → route recalculation. Return a small event dictionary for presentation, but complete the simulation state independent of animation.

Emit meaningful transitions: `elevator_arrived`, `doors_opened`, `passenger_boarded`, `passenger_exited`, and `elevator_direction_changed`.

**Step 3: Make excess demand reassignable**

If capacity leaves compatible passengers waiting, Hall Request remains active. Clear its allocation when it still requires service so dispatcher can assign it later; committed riders retain their controller assignment.

**Step 4: Verify green and commit**

Run headless tests; expected exit 0. Then:

```bash
git add prototypes/elevator-rush/v2/scripts/simulation/elevator_controller.gd prototypes/elevator-rush/v2/scripts/simulation/hall_request_manager.gd prototypes/elevator-rush/v2/tests/collective_control_test.gd
git commit -m "feat: process collective elevator stops"
```

### Task 6: Wire managers into Main and keep presentation observational

**Files:**
- Modify: `prototypes/elevator-rush/v2/scripts/main.gd`
- Modify: `prototypes/elevator-rush/v2/scripts/elevator.gd`
- Modify: `prototypes/elevator-rush/v2/scripts/passenger.gd`
- Modify: `prototypes/elevator-rush/v2/scenes/Main.tscn`

**Step 1: Replace the old simulation authority**

Remove `update_simulation(delta, waiting_passengers)` and direct passenger-list claims as dispatch authority. Main owns one HallRequestManager and one ElevatorDispatcher, advancing each tick in this order:

```text
spawn passenger → register Hall Request → dispatcher assigns → controllers advance → adapters render/move → completed passenger metrics
```

Keep schedules, grade, level flow, zones, staging, and live strategy controls; adapt their data to controllers rather than adding new gameplay.

**Step 2: Connect simulation to visual state**

Keep shafts, floor layout, waiting circles, cabin circles, and existing controls. Presentation reads Passenger/Controller state and controller signals; no tween or button determines route policy.

**Step 3: Add compact debug visibility**

Add a small HUD/debug label: each elevator's floor, service direction, rider capacity, assigned hall requests, destination stops, and next stop. Present passenger/request state in inspectable text; do not build a polished debugger.

**Step 4: Verify and commit**

Run headless logic tests and, when available:

```bash
godot --headless --path prototypes/elevator-rush/v2 --editor --quit
godot --headless --path prototypes/elevator-rush/v2 --quit-after 2
git diff --check
```

Then commit:

```bash
git add prototypes/elevator-rush/v2/scripts/main.gd prototypes/elevator-rush/v2/scripts/elevator.gd prototypes/elevator-rush/v2/scripts/passenger.gd prototypes/elevator-rush/v2/scenes/Main.tscn
git commit -m "refactor: drive elevators from hall requests"
```

### Task 7: Add the deterministic scenario and complete validation docs

**Files:**
- Modify: `prototypes/elevator-rush/v2/tests/collective_control_test.gd`
- Modify: `prototypes/elevator-rush/v2/README.md`
- Modify: `prototypes/elevator-rush/v2/CONTEXT.md`

**Step 1: Add scenario**

Create controllers at Floors 1 and 8, then passengers: `2→7`, `4→9`, `6→1`, `8→3`, `3→10`. Advance fixed-time steps to a bounded limit.

**Step 2: Assert complete behavior**

Assert duplicate floor/direction consolidation, directional skipping, destination delivery, capacity safety, active unserved requests, deterministic dispatcher selection, and all passengers `COMPLETED` before the limit.

**Step 3: Run full runner**

```bash
godot --headless --path prototypes/elevator-rush/v2 -s res://tests/collective_control_test.gd
```

Expected: exit 0.

**Step 4: Do manual editor validation**

Confirm UP skips DOWN at intermediate floor, exits precede boarding, full cars leave active demand, idle cars adopt assigned call direction at pickup, HUD matches state, and existing live strategy changes still wait for committed work.

**Step 5: Update docs and commit**

Document model/limitations and deferred upgrades/economy/maintenance/prediction/destination dispatch. Then:

```bash
git add prototypes/elevator-rush/v2/tests/collective_control_test.gd prototypes/elevator-rush/v2/README.md prototypes/elevator-rush/v2/CONTEXT.md
git commit -m "test: cover collective elevator dispatch"
```

### Task 8: Final review

**Files:**
- Review: `prototypes/elevator-rush/v2/scripts/simulation/`
- Review: `prototypes/elevator-rush/v2/scripts/main.gd`
- Review: `prototypes/elevator-rush/v2/tests/collective_control_test.gd`

**Step 1: Run checks**

```bash
git diff --check
godot --headless --path prototypes/elevator-rush/v2 -s res://tests/collective_control_test.gd
godot --headless --path prototypes/elevator-rush/v2 --editor --quit
godot --headless --path prototypes/elevator-rush/v2 --quit-after 2
```

**Step 2: Review**

Use `@code-review` against the implementation base. Confirm Dispatcher is the only global assignment authority, controller route decisions have no UI/animation dependency, and V1 is unchanged. Commit only review fixes if needed.
