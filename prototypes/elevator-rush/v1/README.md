# Elevator Rush Prototype

Player: A dispatcher programming two elevators in a six-floor building.
Objective: Deliver as many passengers as possible during a five-minute shift.
Main obstacle: Waiting passengers lose patience while each elevator can only follow four queued stops.
Win condition: Complete the five-minute shift with the best score possible.
Lose condition: None; this prototype always ends when the shift finishes.

## Scope

This standalone portrait Godot 4 prototype validates a two-stage route loop: select an empty elevator and send it to one pickup floor. Everyone waiting there boards up to capacity. Then select that elevator, read its onboard destinations, queue up to four delivery floors in order, and start delivery.

It uses primitive visuals only. It deliberately excludes upgrades, money, extra elevators, sound, tutorials, save data, monetization, and polish systems.

## Controls

- Tap or click **SELECT ELEVATOR A/B**.
- With an empty elevator, tap one floor and use **GO TO PICKUP FLOOR**.
- When passengers board, their destinations appear in the **Onboard** line.
- Tap floors `1` through `6` in the delivery order, then use **START DELIVERY**.
- Use **UNDO** and **CLEAR** while programming either step.

## Phases

1. Observe passengers and their destination labels.
2. Send an empty elevator to a floor with waiting passengers.
3. Program the onboard passengers’ destinations after they enter.
4. During rush hour, prioritize expiring passengers.
5. Review the score at **DAY COMPLETE**, then use **PLAY AGAIN**.

## Validation Questions

- Is it clear which elevator is selected and which stops are drafted versus active?
- Can a player understand why a passenger is or is not picked up?
- Does the rush-hour spawn rate create useful pressure without feeling random?
- Are the route controls comfortable in a 540x960 portrait viewport?
