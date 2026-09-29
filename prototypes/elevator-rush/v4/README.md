# Elevator Rush V4

Player: Configure autonomous elevator rules and select targeted upgrades.
Objective: Serve increasingly difficult traffic for as many waves as possible.
Main obstacle: Capacity, travel and service time, coverage, and waiting patience.
Win condition: Clear another wave; progression is endless.
Lose condition: The fifth missed passenger ends the run.

## Scope

Abstract Godot 4 Compatibility prototype. Three cars, four to five floors, live strategy changes, seven capped upgrades, seeded replay. No direct movement commands, economy, theme, music, or persistent progression. V1–V3 remain separate.

## Tasks

- [ ] Tested transport and shared-call dispatch
- [ ] Passenger patience and five-miss failure
- [ ] Live strategy changes
- [ ] Seeded endless waves and reports
- [ ] Targeted upgrades
- [ ] Readable UI and rendered validation
- [ ] Whole-run tests and human playtesting

## Lessons

## Current implementation

V4 is an abstract strategy roguelite prototype. Three autonomous elevators serve seeded passenger waves. The player configures floor coverage, staging, and soft direction preferences, then observes the system and can submit live rule changes while the wave runs. Five misses ends the run.

The current build includes deterministic wave forecasts, five introductory wave patterns followed by endless escalation, wave reports, replay/reset, and a seven-card upgrade pool (speed, capacity, doors, boarding, express, patience, aging protection). The building view animates elevator cars between floors and draws waiting/riding passengers as destination-numbered circles. Upgrade cards are real selectable controls with a highlighted selection and a separate confirmation button; choosing a card does not silently apply it.

## Controls

In preparation, edit each elevator's staging floor, maximum served floor, and direction preference, then press `APPLY` and `START RUSH`. During a wave, pressing `APPLY` submits a pending strategy; committed passengers finish before activation and an eight-second cooldown prevents thrashing. After a report, choose one upgrade and start the next wave. `RETRY SAME RUN` restores the same seed and clears the build.

## Validation evidence

Godot 4.7.1 Compatibility headless validation currently reports `639 checks, 0 failures`. A separate scene smoke test instantiates `main.tscn` and reports `V4 UI smoke: main scene instantiated`. Manual Godot click/layout and balance playtests are still required.
