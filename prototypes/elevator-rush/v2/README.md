# Elevator Rush V2

Player: A dispatcher configuring autonomous elevator coverage.
Objective: Clear three fixed passenger waves by earning a run grade of 8.0 or higher.
Main obstacle: Passenger flow changes from upward lobby traffic to mixed traffic and then a heavy downward exit rush.
Win condition: Clear all three 60-second levels.
Lose condition: None; low-performing strategies are evaluated rather than failed.

## Scope

V2 is a separate Godot 4 prototype. It tests a tower-defense-like loop: configure three elevators, run a fixed passenger wave, inspect results, change strategy, and replay the same demand. A grade of 8.0 unlocks the next level.

- 10 floors and 3 autonomous elevators.
- Each elevator has capacity for 4 passengers, shown as high-contrast in-cabin rider circles labelled with their destination floors.
- Three 60-second fixed-seed waves: Morning Rush (50 passengers), Midday Exchange (54), and Evening Exit (58).
- Each elevator gets a contiguous allowed floor range, one staging floor, and a behavior: `Normal`, `Up Bias`, `Down Bias`, `Up Only`, or `Down Only`.
- Dispatch is deliberately simple: an elevator claims up to its capacity from the oldest valid waiting floor, then delivers riders in ascending floors while going up and descending floors while going down. Biases favor their direction but rescue opposite-direction passengers after 20 seconds; `Only` modes never serve the opposite direction. With room available, elevators collect compatible passengers en route and at delivery stops. Other elevators only target a floor when unclaimed passengers remain.
- During a wave, the player may change coverage, staging, and behavior. Each change is pending until its elevator completes committed work and becomes idle, then applies after an 8-second per-elevator cooldown.
- No manual movement or passenger commands.

## Controls

1. Set each elevator's `MIN`, `MAX`, `STAGING`, and behavior rule.
2. Select the displayed **START LEVEL** button. The strategy panel remains available during the simulation.
3. During a wave, change an elevator's settings and select **APPLY**. The current and pending strategies are shown in the HUD and at the elevator.
4. Review global and per-elevator metrics, including the final strategy and number of live changes.
5. Earn `8.0+` to unlock the next level; otherwise select **ADJUST STRATEGY & REPLAY** to retry the same demand. Clearing Level 3 shows a congratulations result.
6. During a wave, use **RESTART LEVEL** to immediately rerun the same demand with the current strategy.

## Run Grade

Results also show a weighted `0–10` grade to compare the same wave across strategies: delivery completion (4 points), average wait (2), longest wait (1.25), utilization (1), passenger-load balance (0.75), and stop efficiency (1). Completion and waiting time are intentionally the priorities.

## Manual Test Checklist

- [ ] Change coverage and staging for all three elevators before starting.
- [ ] Confirm elevators move autonomously while each strategy row remains editable outside its own cooldown.
- [ ] Confirm Morning Rush is lobby-to-upper-floor traffic, while the later waves use mixed and then upper-to-lobby traffic.
- [ ] Confirm a passenger waiting at a delivery stop boards when the elevator continues in that passenger's direction and has capacity.
- [ ] Confirm an elevator stops for the nearest compatible passenger ahead while travelling with available capacity.
- [ ] Confirm `Up Bias` / `Down Bias` favor their direction, while `Up Only` / `Down Only` never board the opposite direction.
- [ ] Confirm live strategy edits show pending state, wait for committed passengers, and apply at idle after the per-elevator cooldown.
- [ ] Confirm results show global delivery/wait metrics and three per-elevator rows.
- [ ] Confirm replay preserves the same passenger demand while allowing strategy changes.
- [ ] Confirm an 8.0+ grade unlocks the next level, and clearing Level 3 shows the completion result.
