class_name SimulationTypes
extends RefCounted

## Shared simulation vocabulary. These enums describe domain state only; they
## deliberately do not contain presentation or routing behavior.

enum Direction {
	DOWN = -1,
	IDLE = 0,
	UP = 1,
}

enum PassengerState {
	WAITING,
	ASSIGNED,
	BOARDING,
	RIDING,
	EXITING,
	COMPLETED,
}

enum MovementState {
	IDLE,
	MOVING,
	STOPPED,
}

enum DoorState {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
}
