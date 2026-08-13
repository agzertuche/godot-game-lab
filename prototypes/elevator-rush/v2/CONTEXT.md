# Elevator Rush V2

This prototype is a strategy simulation about configuring autonomous elevators for fixed passenger waves. It exists to test whether analysing results and changing rules is engaging without manual elevator driving.

## Language

**Strategy**:
The configuration of an elevator's floor coverage, staging floor, and behavior rule. All settings may be adjusted during a wave as a pending strategy.
_Avoid_: Manual command, route

**Wave**:
A fixed, replayable set of passenger demand released over one timed level.
_Avoid_: Day, random run

**Dispatch**:
The autonomous decision process that assigns passengers and selects an elevator's next stop.
_Avoid_: Player control, driving

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
The weighted 0–10 result used to evaluate a strategy and unlock the next wave.
_Avoid_: Score, rating

**Change Summary**:
A compact per-elevator results line listing the final behavior rule and number of live strategy changes made during the wave. It is not a full replay or event timeline.
_Avoid_: Replay log, audit trail
