# Elevator Rush V3

Player: Starts an autonomous run and chooses one system upgrade between traffic stages.
Objective: Improve an elevator build until escalating traffic overwhelms it.
Main obstacle: Passenger backlog, waits, and finite elevator throughput.
Win condition: Complete the small MVP stage sequence.
Lose condition: A backlog or wait-pressure threshold fails the run.

## Scope

V3 is a neutral, abstract roguelite prototype. It exists to validate whether randomized upgrades make an autonomous elevator system worth replaying. It uses primitive shapes and readable numbers only; no theme, lore, characters, environments, art pipeline, or audio.

## Tasks

- [x] Create a separate Godot Compatibility project and neutral run-flow shell.
- [ ] Port the small request-driven autonomous elevator simulation.
- [ ] Add five deterministic escalating traffic stages.
- [ ] Add a simple backlog/wait-pressure failure rule.
- [ ] Add a twelve-item randomized upgrade pool.
- [ ] Apply upgrades only between stages.
- [x] Present the building, queues, car capacity, and destinations.
- [ ] Run deterministic checks and manually tune several builds.
- [ ] Record lessons and stop after the MVP loop is evaluated.

## Explicitly deferred

Theme and non-abstract art, economy, shops, rarity, rerolls, upgrade levels, unlock trees, meta-progression, lore, audio, and any direct elevator controls are out of scope.

## Controls and run loop

- Press **START RUN** to begin the fixed-seed Stage 1 demand schedule.
- Watch the building view: waiting circles show passenger destinations, cabin circles show riders and destinations, and the arrow above each cabin shows service direction.
- The HUD exposes backlog, oldest wait, the active failure thresholds, pressure, and the current upgrade build.
- Clear a non-final stage to choose one of three randomized, high-contrast upgrades. The selected upgrade immediately starts the next stage.
- **Traffic Preview** pauses briefly after it is chosen to reveal the next stage before it begins.
- A failed run or completed five-stage run shows a summary. **START NEW RUN** resets to the same seeded sequence for a fair retry.

There are no manual elevator movement controls: the simulation owns dispatch, routes, doors, pickup, and drop-off.

## Lessons

Complete this section after the MVP is tested.
