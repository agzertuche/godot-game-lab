# Elevator Rush V4 — Strategy Roguelite Design

## Purpose and agreed scope

Test whether it is enjoyable to build an autonomous elevator system through upgrades, observe traffic problems, adjust strategy during waves, and try again after failure.

The desired rhythm is act → observe → identify a bottleneck → adjust → observe the result. The player manages rules, never individual trips. Presentation stays abstract: a vertical building, generic passengers and cars, floor numbers increasing upward, readable destinations, direction, capacity, queues, and patience. No lore, art pipeline, music, economy, shops, rarity, rerolls, unlock trees, or persistent progression.

Create a separate Godot 4 Compatibility project at `prototypes/elevator-rush/v4`. Preserve V1, V2, and V3. Reuse proven simulation concepts and regression scenarios after inspecting and executing them; previous static reviews do not establish runtime correctness.

## Lessons carried forward

- V1: visible passengers, destinations, capacity, and patience make transport understandable. Do not restore manual route programming.
- V2: coverage, staging, direction preferences, and per-elevator feedback create useful decisions. Avoid a crowded always-visible configuration table and a grade that rewards utilization irrespective of passenger outcomes.
- V3: keep simulation separate from presentation, seeded demand, between-wave upgrade choices, and failure pressure. Restore meaningful opportunities to act on forecasts. Each upgrade must change observable behavior, not just an internal score.

## Run flow

New Run → forecast and preparation → autonomous wave with live adjustments → wave report and next forecast → choose one of three upgrades → choose target when applicable → preparation → next wave.

Three elevators start with capacity four and full coverage of a four-floor building. Five introductory waves introduce demand patterns and a fifth floor. Thereafter waves escalate until the fifth missed passenger ends the run; there is no final victory wave. The building remains capped at five floors for this prototype.

Preparation has no time limit. Show the next forecast before upgrade selection. Choosing an upgrade never automatically starts the next wave. No demand appears while preparing or choosing upgrades.

Initial tuning proposal: each wave spawns traffic over 30 seconds in bursts with short lulls. Introductory demand is 12, 16, 20, 24, then 28 passengers; floor counts are 4, 4, 4, 5, 5. Patterns introduce lobby-up, heavier lobby-up, mixed traffic, upper-floor return, then mixed bursts. From wave six, increase demand by four passengers per wave and select among those patterns deterministically from the run seed. These numbers are tuning defaults, not claims of balance.

A wave ends when all scheduled passengers have spawned and every passenger has completed or missed. Continue service after spawning ends. Waiting patience bounds the drain period even with an invalid coverage configuration. Report waves cleared, total delivered, total misses, and waiting-time feedback. Run failure takes precedence over wave completion on the same simulation tick.

## Passenger failure pressure

The HUD always displays `Misses: N / 5`. Misses persist across waves. The fifth miss immediately ends the run and freezes the simulation until a new run or retry.

Patience counts down while WAITING or ASSIGNED, including time waiting for doors and a boarding slot. It stops when BOARDING begins; onboard passengers do not abandon trips. Start with 25 seconds of patience as a tuning default. A passenger whose patience reaches zero before boarding becomes MISSED, leaves the queue, and is removed from request ownership and reservations. Empty hall requests are removed.

Resolve expiration before starting a new boarding transfer at the same simulation timestamp. Resolve simultaneous expirations in stable passenger-ID order and stop when the fifth miss is recorded.

## Live elevator strategy

Each elevator exposes served floor range, staging floor, and direction preference: Normal, Favor Up, or Favor Down. Soft preferences influence dispatch while permitting opposite-direction service. Do not add hard direction-only modes in this version.

The player selects a car and edits its strategy in one readable panel. Apply creates a visible pending strategy. The car stops accepting additional assignments, completes committed pickups and deliveries, activates the new configuration, then begins an eight-second cooldown. Preserve commitments to specific passengers so new arrivals joining an existing hall call cannot indefinitely postpone the change. Expired commitments are removed normally.

While a change is pending, further Apply actions replace its draft; they do not add jobs or restart commitment collection. During cooldown the player can inspect and edit a draft, but Apply is disabled with a countdown. Show current and pending values separately. Coverage changes never strand onboard riders.

Preparation changes apply immediately and have no cooldown. Validate floor ranges and staging against unlocked floors. Warn if a configuration leaves forecast trips without coverage, but allow experimentation; misses remain the consequence. New floors extend existing full-building coverage automatically, while intentionally restricted ranges remain restricted.

Express Service toggles use the same pending-change and cooldown rules. No move, pick-up, open-door, or visit-floor commands exist.

## Upgrade pool

Offer three distinct eligible cards after each cleared wave. Most cards target one chosen elevator; whole-system cards apply once confirmed. Show exact before-and-after effects and eligible targets. Selecting a card or target is reversible until confirmation; confirmation consumes the wave's single choice. If fewer than three eligible upgrade types remain, show only those available. If none remain, skip the offer and return to preparation with a clear explanation.

Initial tuning proposals:

| Upgrade | Target | Effect and cap |
| --- | --- | --- |
| Faster Motor | One car | Add 25 percentage points of base travel speed; cap at twice base speed |
| Larger Cabin | One car | Add two seats; capacity 4 → 6 → 8 |
| Faster Doors | One car | Reduce combined door opening/closing duration by 20% of its base duration per choice; floor at 40% of base |
| Quick Boarding | One car | Reduce each passenger's boarding/exiting duration by 20% of base per choice; floor at 40% of base |
| Express Service | One car | Acquire once; while carrying riders, defer additional hall pickups until empty; can be toggled off |
| Patient Passengers | Whole system | Add five seconds of patience; cap at 40 seconds |
| Aging Protection | Whole system | Acquire once; overdue unassigned requests get first access to free service capacity before ordinary dispatch |

Numeric upgrades can recur until their eligible targets reach their caps. Cards display actual values, not rarity or level labels. Express eligibility ends once every car owns it; toggling it off does not make it purchasable again. Adaptive Staging and Traffic Preview are excluded; forecasts are a baseline feature.

Normal dispatch must have a measurable throughput-oriented request-ordering policy. Aging Protection changes that ordering for requests waiting at least 60% of their patience, oldest first. Do not implement it merely by subtracting the same age term from every car's cost for one request: that cannot change the selected car. It does not interrupt onboard service or override coverage. A before/after contention test must prove that acquiring it changes which request gets the next available capacity.

Capacity + Quick Boarding should support high-volume local service. Speed + Express should support long trips. These are hypotheses to test, not a separate synergy subsystem. Show each car's acquired upgrades so the player can recognize its role.

## Simulation responsibilities

Use one fixed-step simulation clock independent of rendering. The run coordinator advances demand, patience, dispatch, travel, doors, and passenger transfers in a stable documented order. Presentation observes state and events and submits strategy or upgrade choices through explicit methods.

- Passenger/request state owns trips, patience, state, hall-call membership, and reservation ownership.
- Hall requests consolidate floor and direction. Capacity reservations may assign different waiting passenger subsets to multiple cars without duplicating passengers or logical calls; one large lobby queue must be serviceable by several cars.
- Dispatcher chooses assignments and owns request priority and isolated car-cost calculation. Honor capacity reservations, coverage, soft directional preferences, pending strategy changes, and Express restrictions.
- Elevator controller owns collective directional service, travel, doors, committed jobs, destinations, and transfers. Deduplicate destination stops, drop off before boarding, and preserve direction while valid work remains ahead.
- Run coordinator owns waves, forecasts, miss allowance, seeds, reports, and phase transitions.
- Upgrade definitions/build state own eligibility and tuning effects. Rebuilding a stage applies the retained build exactly once.

Door opening/closing time and per-passenger transfer time must be separate. Boarding four passengers should cost more transfer time than boarding one. Parking alone does not open doors or count as a service stop. Use typed local scripts and small scenes; no shared framework or global autoload is required.

## Readability and feedback

Keep the building readable while editing one selected car. Use large elevator selectors, labeled controls with at least 44px touch targets, high-contrast values, and distinct disabled/pending states. Destination numbers remain inside passenger circles, with overflow counts when queues or cabins exceed available display space.

During waves show misses, patience urgency, occupancy, direction, next stop, and pending strategy activation. Between waves show delivered/missed counts, average and longest pickup wait, per-car transported counts, and time spent full or idle. Derive short factual observations such as `Most misses occurred on Floor 5`; avoid claiming a cause the recorded data cannot establish.

Use a 600×960 portrait baseline and layout containers. Do not shrink the building or text until the information becomes illegible to fit every setting simultaneously. Rendered screenshots and actual click tests are required to validate the layout.

## Seeds and replay

New Run generates a new root seed. Retry Same Run restores that seed and resets the build, misses, and progression. Use separate deterministic random streams for demand and upgrade offers; presentation and input timing must not consume them. Repeating the same choices on the same seed reproduces offers and traffic. Different choices can alter future eligible offers; demand remains identical for the same wave and root seed.

## Validation and delivery gates

Before building the full UI, locate an executable Godot installation and run simulation scenarios. If unavailable, explicitly report runtime validation as blocked rather than declaring the foundation tested. A clean diff is not a parser or gameplay check.

Required regression coverage:

- Collective UP/DOWN stops, reversal, dropoff-before-pickup, deduplicated destinations, and no capacity overflow.
- Shared hall calls served by multiple cars with disjoint passenger reservations and persistent leftover demand.
- Expiration cleans assignments; boarding stops patience; the fifth miss ends a run, including simultaneous expiry and wave-end boundaries.
- Live changes preserve committed service, stop new commitments, activate despite continued arrivals, and enforce cooldown.
- Separate door and per-passenger transfer timing; each upgrade changes observable behavior and respects its cap.
- Aging Protection changes request allocation under contention; Express defers hall pickups without losing committed riders.
- Exactly one upgrade per cleared wave; fewer-than-three and exhausted offers; correct effects after stage resets.
- New-run seeds, same-seed repeatability, five introductory waves, and continued escalation after wave five.

Manual evaluation must establish whether players can spot a bottleneck, make an adjustment, and recognize its consequence; whether upgrades produce distinct car roles; and whether a loss invites another attempt. Tune traffic, timers, caps, and failure pressure before adding systems.

## Implementation sequence

1. Isolated V4 project and executable simulation checks.
2. Autonomous transport, patience/misses, and a complete single-wave loop.
3. Live strategy editing with commitment boundaries and cooldown.
4. Forecasts, introductory waves, endless escalation, and seeded retry.
5. Seven upgrades, target selection, repeat eligibility, and caps.
6. Readable presentation, reports, whole-run validation, and playtest tuning.

This document captures the agreed gameplay direction. Numeric defaults and the precise UI layout are implementation proposals to verify during testing. Detailed implementation planning follows review of this written spec.
