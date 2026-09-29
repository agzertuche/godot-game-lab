class_name V4Simulation
extends RefCounted

const STEP_SECONDS := 0.05
var floors := 4
var time := 0.0
var cars: Array[V4Elevator] = []
var passengers: Array[V4Passenger] = []
var hall := V4HallRequests.new()

func configure(floor_count: int, car_count: int) -> void:
	floors = floor_count
	cars.clear()
	passengers.clear()
	hall = V4HallRequests.new()
	time = 0.0
	for index in car_count:
		cars.append(V4Elevator.new(index + 1, floors))

func spawn(origin: int, destination: int) -> V4Passenger:
	if origin == destination or mini(origin, destination) < 1 or maxi(origin, destination) > floors:
		return null
	var p := V4Passenger.new(passengers.size() + 1, origin, destination, time)
	passengers.append(p)
	hall.register(p)
	return p

func step() -> void:
	time += STEP_SECONDS
	for car in cars:
		car.step(STEP_SECONDS, hall, time)

func is_drained() -> bool:
	for p in passengers:
		if p.state != V4Passenger.State.COMPLETED and p.state != V4Passenger.State.MISSED:
			return false
	return true
