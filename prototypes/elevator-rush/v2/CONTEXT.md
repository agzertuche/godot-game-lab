# Elevator Rush V2

This prototype is a strategy simulation about configuring autonomous elevators for fixed passenger waves. It exists to test whether analysing results and changing rules is engaging without manual elevator driving.

## Language

**Strategy**:
The configuration of an elevator's floor coverage, staging floor, and behavior rule. All settings may be adjusted during a wave as a pending strategy.
_Avoid_: Manual command, route

**Wave**:
A timed set of passenger demand released over one level. Levels 1–3 use fixed seeds; Adaptive Chaos is generated once per challenge and then remains replayable.
_Avoid_: Day

**Adaptive Challenge**:
Level 4, `ADAPTIVE CHAOS`: an intentionally unpredictable, mixed-traffic wave. It generates its passenger schedule once upon unlock or when the player selects **NEW CHALLENGE**, then preserves that schedule for restart, retry, and **REPLAY SAME CHALLENGE**.
_Avoid_: Fully random retry, daily challenge

**Dispatch**:
The autonomous decision process that assigns hall requests and selects an elevator's next stop.
_Avoid_: Player control, driving

**Hall Request**:
Shared demand created by all waiting passengers at the same origin floor who want the same direction. Opposite directions remain separate requests.
_Avoid_: Individual elevator command, passenger route

**Destination Request**:
An in-car stop created when a passenger boards. Multiple riders for the same destination share one physical stop.
_Avoid_: Hall request, manual floor selection

**Service Direction**:
The current collection direction of an elevator: `UP`, `DOWN`, or `IDLE`. It is independent from whether the car is currently moving.
_Avoid_: Animation state, velocity

**Movement State**:
Whether an elevator is `IDLE`, `MOVING`, or `STOPPED` in the simulation.
_Avoid_: Service direction

**Door State**:
The simulation lifecycle of an elevator's doors: `CLOSED`, `OPENING`, `OPEN`, or `CLOSING`.
_Avoid_: Visual-only animation state

**Behavior Rule**:
One pre-wave policy that biases an elevator's automatic dispatch inside its allowed coverage.
_Avoid_: Direct command, active ability

**Direction Priority**:
A behavior rule of `Up`, `Down`, or `Normal` that makes an elevator favor compatible passengers travelling in that direction for both request claims and en-route pickups. It is a soft preference: when preferred work is absent, normal valid dispatch resumes.
_Avoid_: Direction lock, one-way elevator

**Direction Commitment**:
A hard `Up Only` or `Down Only` behavior rule. The elevator may reposition when idle, but never claims or boards opposite-direction passengers.
_Avoid_: Strong priority, hard priority

**Pending Strategy**:
A live strategy change that has been selected but will not apply until its elevator next becomes idle. Each change starts that elevator's 8-second, per-elevator strategy-change cooldown; once the cooldown ends, the latest edit replaces any earlier pending strategy. It is shown in both the elevator label and its HUD strategy card.
_Avoid_: Immediate reroute, command queue

**Committed Passenger**:
A passenger already riding in, or claimed by, an elevator. A later strategy change never removes this assignment; the elevator completes the passenger's trip before applying a pending strategy.
_Avoid_: Reassignable passenger, stranded rider

**Grade**:
The weighted 0–10 result used to evaluate a strategy and unlock the next wave. A grade of 8.0 or higher passes a level.
_Avoid_: Score, rating

**Change Summary**:
A compact per-elevator results line listing the final behavior rule and number of live strategy changes made during the wave. It is not a full replay or event timeline.
_Avoid_: Replay log, audit trail

**Request-Driven Simulation**:
The autonomous demand-to-delivery chain: passenger -> shared hall request -> dispatcher assignment -> elevator controller pickup -> destination request -> dropoff. The player configures rules, but does not issue movement commands.
_Avoid_: Manual routing, click-to-move

**Hall Request Manager**:
The simulation service that groups waiting passengers by origin floor and requested direction, maintains each call while demand remains, and releases partial demand after a full elevator boards only some riders.
_Avoid_: Per-passenger elevator target

**Elevator Dispatcher**:
The only global request assignment authority. Its current deterministic scorer weighs pickup distance, intermediate stops, directional fit, car load, and request age; the scorer is intentionally isolated for replacement.
_Avoid_: Elevator-owned global dispatch, optimal dispatch claim

**Elevator Controller**:
Simulation-only owner of an individual car's logical movement, service direction, door lifecycle, capacity, assigned hall requests, and deduplicated destination requests. Presentation observes it but cannot choose its route.
_Avoid_: Visual elevator node, animation-driven logic

**Collective Selective Service**:
While serving `UP`, a controller takes destination stops and UP hall requests in ascending order, leaving DOWN calls for its return; `DOWN` is the mirror behavior. It reverses only when no valid work remains ahead.
_Avoid_: Nearest-call-only routing, arbitrary reversal

**Deterministic Simulation Check**:
A headless, fixed-timestep test scenario that executes hall registration, dispatch, travel, doors, transfer ordering, and completion without `Main` or visual nodes. It is a repeatable behavior specification, not a recorded gameplay run.
_Avoid_: Manual-only verification, UI test
