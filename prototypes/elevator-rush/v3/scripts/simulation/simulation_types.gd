class_name ElevatorSimulationTypes
extends RefCounted

## Domain vocabulary shared by the headless elevator simulation.
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
	OPEN,
}
