# Elevator Rush V3 Context

## Design question

Is it fun to improve an autonomous elevator system with randomized upgrades while traffic becomes progressively harder?

## Loop

```text
Start run -> autonomous traffic stage -> evaluate system -> choose 1 of 3 upgrades -> harder stage -> fail or complete run
```

The player changes system rules between stages. They never direct a car, open doors, choose a pickup, or select a destination.

## MVP boundaries

- Start with three elevators and unlock only Floors 3–5 across a five-stage run.
- Keep passenger, request, dispatch, route, capacity, and door simulation deterministic.
- Keep the presentation neutral: vertical floors, generic passenger circles, generic elevator rectangles, direction/state colors, and high-contrast values.
- Build a small set of numeric and behavioral upgrades only after the autonomous baseline works.
- Preserve V1 and V2 as separate prototypes.
