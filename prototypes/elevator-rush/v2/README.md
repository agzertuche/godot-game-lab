# Elevator Rush V2

Player: A dispatcher configuring autonomous elevator coverage.
Objective: Clear four passenger waves by earning a run grade of 8.0 or higher.
Main obstacle: Passenger flow shifts from predictable rush patterns to an unknown mixed final challenge.
Win condition: Clear all four 60-second levels.
Lose condition: None; low-performing strategies are evaluated rather than failed.

## Scope

V2 is a separate Godot 4 prototype. It tests a tower-defense-like loop: configure three elevators, run a passenger wave, inspect results, change strategy, and replay the same demand. A grade of 8.0 unlocks the next level.

- 10 floors and 3 autonomous elevators.
- Each elevator has capacity for 4 passengers, shown as high-contrast in-cabin rider circles labelled with their destination floors.
- Four 60-second waves: three fixed-seed levels—Morning Rush (50 passengers), Midday Exchange (54), and Evening Exit (58)—followed by Adaptive Chaos (60 passengers).
- Adaptive Chaos generates a mixed passenger schedule when it is unlocked. Its schedule remains fixed for level restarts, failed-run retries, and **REPLAY SAME CHALLENGE**, so strategy comparisons stay fair. **NEW CHALLENGE** generates a new Adaptive Chaos schedule.
- Each elevator gets a contiguous allowed floor range, one staging floor, and a behavior: `Normal`, `Up Bias`, `Down Bias`, `Up Only`, or `Down Only`.
- Dispatch is deliberately simple: a shared dispatcher assigns grouped hall requests to eligible elevators. Each elevator then serves compatible requests in its current direction, while rider destinations become deduplicated destination requests. This request-driven foundation keeps hall demand, routing, and presentation separate.
- During a wave, the player may change coverage, staging, and behavior. Each change is pending until its elevator completes committed work and becomes idle, then applies after an 8-second per-elevator cooldown.
- No manual movement or passenger commands.

## Controls

1. Set each elevator's `MIN`, `MAX`, `STAGING`, and behavior rule.
2. Select the displayed **START LEVEL** button. The strategy panel remains available during the simulation.
3. During a wave, change an elevator's settings and select **APPLY**. The current and pending strategies are shown in the HUD and at the elevator.
4. Review global and per-elevator metrics, including the final strategy and number of live changes.
5. Earn `8.0+` to unlock the next level; otherwise select **ADJUST STRATEGY & REPLAY** to retry the same demand. Clearing Level 4 shows a congratulations result with **REPLAY SAME CHALLENGE** and **NEW CHALLENGE**.
6. During a wave, use **RESTART LEVEL** to immediately rerun the same demand with the current strategy.

## Run Grade

Results also show a weighted `0–10` grade to compare the same wave across strategies: delivery completion (4 points), average wait (2), longest wait (1.25), utilization (1), passenger-load balance (0.75), and stop efficiency (1). Completion and waiting time are intentionally the priorities.

## Request-Driven Simulation Glossary

- **Hall Request**: shared demand for one floor and travel direction. Multiple passengers waiting at Floor 5 for `UP` use one request; Floor 5 `DOWN` is a separate request.
- **Destination Request**: an in-car stop created when a passenger boards. Several passengers requesting the same floor create one physical stop.
- **Service Direction**: the elevator's current collection direction: `UP`, `DOWN`, or `IDLE`. It remains meaningful while the car is stopped.
- **Movement State**: whether the car is `IDLE`, `MOVING`, or `STOPPED`; it is separate from service direction.
- **Door State**: the independent door lifecycle: `CLOSED`, `OPENING`, `OPEN`, or `CLOSING`.

## Manual Test Checklist

- [ ] Change coverage and staging for all three elevators before starting.
- [ ] Confirm elevators move autonomously while each strategy row remains editable outside its own cooldown.
- [ ] Confirm Morning Rush is lobby-to-upper-floor traffic, Midday Exchange is mixed, and Evening Exit is upper-to-lobby traffic.
- [ ] Confirm a passenger waiting at a delivery stop boards when the elevator continues in that passenger's direction and has capacity.
- [ ] Confirm an elevator stops for the nearest compatible passenger ahead while travelling with available capacity.
- [ ] Confirm `Up Bias` / `Down Bias` favor their direction, while `Up Only` / `Down Only` never board the opposite direction.
- [ ] Confirm live strategy edits show pending state, wait for committed passengers, and apply at idle after the per-elevator cooldown.
- [ ] Confirm results show global delivery/wait metrics and three per-elevator rows.
- [ ] Confirm each fixed-seed level replays the same passenger demand while allowing strategy changes.
- [ ] Pass Level 3 with an `8.0+` grade and confirm Level 4 — Adaptive Chaos unlocks.
- [ ] Start Adaptive Chaos, use **RESTART LEVEL**, and confirm the passenger timing and trips repeat.
- [ ] Pass Adaptive Chaos, choose **REPLAY SAME CHALLENGE**, and confirm its generated demand repeats.
- [ ] Pass Adaptive Chaos, choose **NEW CHALLENGE**, and confirm a different mixed demand pattern is generated.
- [ ] Confirm an `8.0+` grade is a pass on every level and clearing Level 4 shows the completion result.
