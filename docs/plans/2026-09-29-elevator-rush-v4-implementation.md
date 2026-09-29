# Elevator Rush V4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an abstract autonomous elevator roguelite with useful live adjustments, targeted upgrades, endless waves, and failure on the fifth miss.

**Architecture:** Build a standalone V4 project with a fixed-step simulation and a thin Godot presentation layer. Passenger-level reservations let multiple elevators service one logical hall call. Strategy changes drain finite commitments; run progression and upgrade effects use explicit interfaces outside routing code.

**Tech Stack:** Godot 4 stable, typed GDScript, Compatibility renderer, native Control containers and primitive drawing, SceneTree headless tests.

**Spec:** `docs/plans/2026-09-28-elevator-rush-v4-design.md` (approved).

## Global Constraints

- Work in `prototypes/elevator-rush/v4`; V1–V3 remain unchanged. Direct work on main follows the user's repository preference.
- Three elevators, capacity four, initially four floors; five-floor building cap. Portrait baseline 600×960.
- One simulation clock; visuals never choose routes or determine completion. No manual elevator movement commands.
- Seven upgrade types only. No economy, rerolls, rarity, themed art/audio, or persistent progression.
- Five misses across the run cause immediate failure. Five introductory waves lead into endless escalation.
- Validate inside Godot before declaring simulation or UI functional. Static diff checks alone are insufficient.
- Preserve `.gd.uid` files, exclude `.godot` caches, and stage only task-owned files. Use names prefixed `V4` for global classes.

## Review Focus

1. A crowded single-direction lobby call must mobilize several cars without double-booking a passenger (Task 2).
2. Continuous arrivals and repeated Apply clicks must not postpone a pending strategy forever (Task 3).
3. Simultaneous expiry/boarding/wave completion must end consistently on exactly the fifth miss (Task 2).
4. Repeated upgrade-button clicks, exhausted offers, or restarting during selection must not grant extra upgrades (Tasks 5–6).
5. Different render frame rates must not change seeded simulation results; long text and large queues must remain readable (Tasks 4 and 6).

## Files and boundaries

All paths below are relative to `prototypes/elevator-rush/v4/` unless stated otherwise. Keep this compact layout; do not create a reusable framework.

| Files | Responsibility |
| --- | --- |
| `project.godot`, `main.tscn`, `main.gd` | Startup and UI-to-run coordination |
| `passenger.gd`, `hall_requests.gd` | Passenger lifecycle, hall grouping, disjoint reservations |
| `elevator.gd`, `dispatcher.gd`, `simulation.gd` | Car service, assignment decisions, ordered simulation ticks |
| `strategy.gd` | Validated floor coverage, staging, direction preference, express setting |
| `waves.gd`, `run.gd` | Seeded demand/forecasts and run phase transitions |
| `upgrades.gd` | Seven definitions, eligible offers, target validation, capped build tuning |
| `building_view.gd`, `strategy_panel.tscn`, `strategy_panel.gd` | Read-only building and selected-car editing |
| `upgrade_panel.tscn`, `upgrade_panel.gd`, `report.gd` | Upgrade selection and factual metrics/report presentation |
| `tests/test_runner.gd`, `tests/test_*.gd` | Headless assertion runner and focused test suites |
| `README.md` | Five-line concept, at most ten tasks, controls, validation evidence and lessons |

## Verification protocol

Resolve `GODOT_BIN` to an actual executable before running commands below. Check PATH, `/Applications`, `~/Applications`, `~/Downloads`, and the executable path of an already-running Godot process. Do not install or download an engine silently. If discovery fails, report that exact prerequisite and obtain its location before claiming red/green tests or moving into full UI development.

```bash
"$GODOT_BIN" --version
"$GODOT_BIN" --headless --path prototypes/elevator-rush/v4 --editor --quit
"$GODOT_BIN" --headless --path prototypes/elevator-rush/v4 --script res://tests/test_runner.gd
"$GODOT_BIN" --headless --path prototypes/elevator-rush/v4 --quit-after 120
git diff --check
```

Runner reports assertion count and exits once, nonzero on failures. Read logs for parser/runtime errors even if the engine exits zero. Each task adds its tests first, observes the intended failure, implements, then reruns the suite. Import the project before running tests when global class registration is needed. Commit only after relevant checks pass; record validation blocks honestly.

### Task 1: Executable single-car transport foundation

**Files:** Create `project.godot`, `main.tscn`, `main.gd`, `README.md`, `passenger.gd`, `hall_requests.gd`, `elevator.gd`, `strategy.gd`, `simulation.gd`, `tests/test_runner.gd`, `tests/test_service.gd`.

**Interfaces:** `V4Passenger` stores stable ID, origin/destination, direction, request time, patience seconds, owner car ID, and WAITING/ASSIGNED/BOARDING/RIDING/EXITING/COMPLETED/MISSED state. `V4Strategy` stores min/max floor, staging, Normal/Favor Up/Favor Down, and express enabled. `V4Simulation.configure(floors: int, car_count: int)`, `spawn(origin: int, destination: int) -> V4Passenger`, `step() -> void`; time advances by `STEP_SECONDS = 0.05`. `V4HallRequests.reserve(passenger_id: int, car_id: int) -> bool`, `release(passenger_id: int) -> void`; `V4Elevator.step(delta: float, hall: V4HallRequests, now: float) -> void` handles reserved jobs.

- [ ] Locate and run Godot, create isolated Compatibility project and a minimal startup scene; document the concept before simulation implementation.
- [ ] Write `test_reserved_passenger_completes_1_to_4`: spawn passenger, reserve for car, advance real ticks; assert COMPLETED, correct destination, empty cabin and request, and exactly one boarding/exiting event. Write `test_four_transfers_cost_more_than_one` with measured elapsed service time.
- [ ] Run tests and observe missing behavior; implement model and ordered service: arrive → open → sequential exits → sequential boardings → close → route. Initial tunables: 1 floor/second, 0.4s open + 0.4s close, 0.35s per boarding/exiting transfer. Seat occupancy includes BOARDING passengers.
- [ ] Add ascending/descending stops, opposite-direction deferral, terminal-floor reversal, duplicate destinations, capacity safety, invalid equal-origin/destination rejection, and parking without a service stop. Signal arrival, doors opened, boarded, exited, request completion, and direction change once per transition.
- [ ] Run the full verification protocol, inspect V1–V3 path diff for no changes, and commit `feat: add v4 tested elevator service` with only these files and their UIDs.

### Task 2: Shared-call dispatch, expiration, and five-miss failure

**Files:** Create `dispatcher.gd`, `tests/test_dispatch.gd`, `tests/test_patience.gd`; modify `hall_requests.gd`, `elevator.gd`, `simulation.gd`, `tests/test_runner.gd`.

**Interfaces:** `V4Dispatcher.assign(sim: V4Simulation) -> void`, `calculate_assignment_cost(car: V4Elevator, passenger: V4Passenger, now: float) -> float`. Hall lookup groups by origin/direction but ownership lives on each passenger. Simulation exposes `cars`, `passengers`, `misses`, `failed`, `is_drained() -> bool`, and passenger/run transition signals. Add `aging_protection: bool` to dispatcher, initially false; Task 5 enables it.

- [ ] Write `test_twelve_lobby_passengers_use_three_cars`: one hall group with 12 waiters, three capacity-four cars; assert three disjoint four-person reservations, no duplicate ownership, and all eventually served. Add mixed-destination coverage and leftover-demand cases.
- [ ] Implement deterministic assignment: rank eligible unassigned passengers by best available-car pickup estimate; break ties by request time then passenger ID, and car ties by ID. Recompute free seats after each assignment. Cost combines logical travel distance/speed, relevant stops, turnaround, load, and a small soft direction-preference penalty. Requests beyond coverage stay pending.
- [ ] Write `test_expiry_releases_reservation`, `test_boarding_freezes_patience`, `test_fifth_miss_wins_over_wave_completion`, and `test_simultaneous_expiry_stops_at_five`. Assert waiting at exactly 25s expires before a boarding transfer can start at that timestamp; no sixth expiry processes after failure.
- [ ] Implement stable tick order: increment clock, admit due spawns, expire waiting/assigned IDs, abort on fifth miss, apply ready strategy transitions, dispatch, advance cars/transfers, collect metrics, then evaluate drain. A request survives while it contains waiting/assigned passengers; reservation release never discards other cars' work.
- [ ] Verify the real multi-car simulation and all prior tests, then commit `feat: add v4 dispatch and patience failure`.

### Task 3: Safe live strategy updates

**Files:** Modify `strategy.gd`, `elevator.gd`, `dispatcher.gd`, `simulation.gd`; create `tests/test_strategy.gd`; update runner.

**Interfaces:** `V4Simulation.set_strategy(car_id: int, draft: V4Strategy, preparation: bool) -> bool`; elevator exposes `active_strategy`, nullable `pending_strategy`, immutable-on-first-apply committed passenger IDs, and `cooldown_remaining`. `V4Strategy.validated(floor_count: int) -> V4Strategy` returns a copy with range/staging constrained to unlocked floors.

- [ ] Write `test_pending_change_finishes_finite_commitments`: apply during pickup, continuously spawn matching passengers, then assert old commitments complete, later arrivals aren't acquired, pending settings activate, and cooldown begins at 8s.
- [ ] Write `test_reapply_replaces_draft_not_commitments`, `test_expired_commitment_does_not_block_activation`, `test_cooldown_rejects_apply`, and `test_prep_applies_immediately`. Assert onboard destinations remain served after coverage shrinks.
- [ ] Implement finite commitment draining and preference cost; unassigned cars can still serve opposite-direction requests under Favor Up/Down. Express activation is validated against ownership, and loaded express cars finish cabin destinations before taking additional pickups; already committed pickups remain recorded until fulfilled.
- [ ] Verify tests and commit `feat: add v4 live strategy changes`.

### Task 4: Seeded forecasts, wave progression, and run reports

**Files:** Create `waves.gd`, `run.gd`, `report.gd`, `tests/test_run.gd`; modify `simulation.gd` and runner.

**Interfaces:** `V4Waves.definition(root_seed: int, wave: int) -> Dictionary` yields floors, passenger count, pattern, duration, schedule. `V4Run.new_run(seed_value: int)`, `start_wave() -> bool`, `advance(real_delta: float) -> void`, `retry_same_run() -> void`; phases PREPARATION/RUNNING/REPORT/UPGRADE/FAILED. `continue_report() -> void` enters upgrade selection (Task 5 supplies offers). Expose current/next forecast, root seed, waves cleared, cumulative misses/delivered, current simulation, and wave report. `V4Report.snapshot() -> Dictionary` returns total and per-car metrics.

- [ ] Write `test_intro_then_endless`: floor counts `[4,4,4,5,5,5]`, passenger counts `[12,16,20,24,28,32]`; wave six must exist and cannot produce a victory state. Verify the named introductory patterns and valid distinct trip endpoints.
- [ ] Build deterministic schedules in three bursts over 30s with lulls. Separate demand and offer seed derivation; never use frame-dependent RNG. From wave six select among established patterns and add four passengers per wave.
- [ ] Write `test_same_seed_replays_demand`, `test_frame_chunking_preserves_outcome` (0.05s vs 0.2s render deltas), `test_no_spawns_outside_running`, and `test_misses_persist_then_retry_resets`. The accumulator must retain elapsed time, not discard ticks; stop consuming simulation steps upon phase change.
- [ ] Preserve car strategies/build between waves, clear transient jobs/cooldowns, and stage idle cars at configured floors. Extend ranges that previously served the full building when floor five opens; keep restricted zones unchanged. Add a regression test for both cases.
- [ ] Record pickup waits at BOARDING, per-car transported count and full/idle seconds, misses by origin, and cumulative deliveries. Report a factual worst-miss floor with stable tie-breaking. Completion requires all scheduled demand resolved; no-demand/zero-delivery reports must avoid division by zero. Test this explicitly.
- [ ] Verify tests and commit `feat: add v4 seeded endless waves`.

### Task 5: Seven upgrades and transactional selection

**Files:** Create `upgrades.gd`, `tests/test_upgrades.gd`; modify `run.gd`, `dispatcher.gd`, `elevator.gd`, runner.

**Interfaces:** `V4Upgrades.offer(seed_value: int, wave: int, cars: Array) -> Array[String]`, `eligible_targets(id: String, cars: Array) -> Array[int]`, `preview(id: String, target_id: int) -> Dictionary`, `apply(id: String, target_id: int) -> bool`. The run exposes `current_offer` and `confirm_upgrade(id: String, target_id: int) -> bool`, guarding phase and exactly one choice. Use target ID zero for whole-system effects. Store tuning relative to immutable base values and behavior ownership separately from enabled state.

- [ ] Write cap tests: motor increments 0.25 to 2.0 multiplier; cabin 4→6→8; doors/transfers each reduce 0.2 of base to minimum 0.4; patience 25→30→35→40; Express per car and Aging Protection global acquire once.
- [ ] Implement the seven definitions with exact numerical previews. Offer unique upgrade types with at least one eligible target. Exclude capped/ineligible choices. A build is retained and reapplied once when constructing the next wave, never compounded by reading UI or restarting a scene.
- [ ] Write `test_duplicate_confirmation_grants_once`, `test_invalid_target_keeps_offer`, `test_express_off_does_not_restore_eligibility`, `test_two_or_zero_types_left`, `test_retry_resets_build`, and same-seed/same-choice offer equivalence. An empty pool goes to PREPARATION with an explicit exhausted-pool message.
- [ ] Implement Aging Protection: before throughput ranking, allocate available capacity to overdue unassigned requests at 60% of patience, ordered oldest-first. Add a contention fixture where a distant overdue request loses to a near new request normally but wins with the upgrade; car coverage/capacity still hold.
- [ ] Compare enabled/disabled Express under identical demand, and measure motor, door, and transfer improvements in real ticks. Confirm Larger Cabin changes maximum riders and Patient Passengers changes expiration, not an unrelated grade.
- [ ] Verify suite and commit `feat: add v4 targeted capped upgrades`.

### Task 6: Readable building, live editor, upgrade targeting, and results

**Files:** Create `building_view.gd`, `strategy_panel.tscn`, `strategy_panel.gd`, `upgrade_panel.tscn`, `upgrade_panel.gd`, `tests/test_ui.gd`; modify `main.tscn`, `main.gd`, `README.md`, runner.

**Interfaces:** `building_view.simulation: V4Simulation` is read-only; strategy panel emits `strategy_submitted(car_id: int, draft: V4Strategy)`; upgrade panel emits `upgrade_confirmed(id: String, target_id: int)`. Main delegates through run/simulation APIs and owns the render accumulator call only. New Run chooses a random root seed once; Retry Same Run reuses the current seed.

- [ ] Add a scene smoke test that instantiates Main, starts/prepares a run, edits a strategy, exercises pending/cooldown display, presents a controlled upgrade offer, changes target, confirms twice, and retries. Assert phase transitions and exactly one applied upgrade via the public model.
- [ ] Build container-driven layout: header/misses, readable building, three large car selectors, one selected-car editor, phase-specific action area. Use 44px minimum hit targets, labeled controls, dark/light contrast, destination circles and overflow counts. Show current/pending values and editable draft distinctly; don't overwrite a draft every simulation frame.
- [ ] Add forecast and uncovered-trip warning in preparation. Report precedes upgrade choice and includes next forecast. Upgrade selection displays target eligibility and exact before/after values; allow changing selections until explicit confirmation. End confirmation in preparation with a separate Start Wave action.
- [ ] Show per-car build, occupancy, direction, next stop and countdown; global `Misses: N / 5`. Failure freezes play and exposes New Run and Retry Same Run. No per-trip controls.
- [ ] Render at 600×960 and click actual controls in preparation/running/upgrade/failure states. Capture screenshots for queue overflow, capacity eight, longest build/status labels, cooldown and reduced offers. Use screenshots to correct clipping and overlapping controls; headless scene tests do not replace this check.
- [ ] Run engine import, entire test suite, smoke startup and diff checks; update README controls/evidence and commit `feat: add v4 strategy roguelite interface`.

### Task 7: Whole-run validation and restrained tuning

**Files:** Modify `tests/test_run.gd`, `README.md`; adjust only named constants in `waves.gd`, `upgrades.gd`, and `elevator.gd` if measured evidence calls for it.

- [ ] Add bounded headless full-run scenarios using fixed seed and documented choices. Verify baseline wave one is serviceable, progression passes wave five under at least one viable fixture/build, a deliberately uncovered configuration fails on five misses, and retry reproduces results. Bound test duration and fail on stalled progression rather than hanging.
- [ ] Run full engine validation, including a fresh import, all tests and main startup. Review the complete V4 diff against the approved spec; verify previous prototype files unchanged. Fix actual failures before concluding.
- [ ] Manually play at least three builds and record seed, choices, wave reached, misses, bottleneck observations and whether live adjustments visibly helped. Do not claim fun or balance from automated throughput tests. If human evaluation is unavailable, list it as outstanding.
- [ ] Tune only measured problems using named constants; rerun relevant regression tests after tuning. Record actual results and limitations in README, mark implementation tasks separately from manual evaluation, and commit `test: validate elevator rush v4 runs`.

## Handoff

This plan is ready for review; it does not authorize additions beyond the spec. Execute tasks in order because reservation ownership, live changes, and upgrade effects share simulation interfaces. Prefer native implementation with one final independent review to reduce repeated handoffs across these boundaries. No implementation or claim of completed runtime validation is part of this planning commit.
