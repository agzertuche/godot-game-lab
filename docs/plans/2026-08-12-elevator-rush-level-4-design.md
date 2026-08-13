# Elevator Rush V2 — Level 4 Design

## Goal

Add a final adaptive challenge that tests real-time strategy adjustment without adding new elevator mechanics or passenger types.

## Agreed design

- Add **Level 4: Adaptive Chaos** after Evening Exit.
- The level lasts 60 seconds and contains 60 passengers with a randomized mix of lobby-to-upper, upper-to-lobby, and cross-floor requests.
- Generate the random schedule once when Level 4 unlocks. Do not show its exact traffic composition in the forecast.
- Keep that generated schedule for `RESTART LEVEL` and ordinary result retries, so strategy comparison remains fair.
- Keep the pass threshold at `8.0+`.
- On a passing Level 4 result, show two choices:
  - **REPLAY SAME CHALLENGE** uses the stored Level 4 schedule.
  - **NEW CHALLENGE** generates a fresh Level 4 schedule, then returns to Level 4 preparation.
- Do not add passenger types, upgrades, progression beyond Level 4, or manual elevator movement.

## Validation

- Unlock Level 4 from a passing Level 3 result.
- Confirm first Level 4 generation is unpredictable but stays fixed across restart/retry.
- Confirm a new challenge changes the generated demand while retaining Level 4 configuration flow.
- Confirm Level 4 still uses the existing live-strategy controls and 8.0 pass threshold.
