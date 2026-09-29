class_name V4Simulation
extends RefCounted

const STEP_SECONDS := 0.05
var floors := 4
var time := 0.0
var cars: Array[V4Elevator] = []
var passengers: Array[V4Passenger] = []
var hall := V4HallRequests.new()
var dispatcher := V4Dispatcher.new()
var misses := 0
var failed := false
var patience := 25.0
signal passenger_missed(passenger: V4Passenger)

func configure(floor_count: int, car_count: int) -> void:
	floors = floor_count
	cars.clear()
	passengers.clear()
	hall = V4HallRequests.new()
	time = 0.0
	misses = 0
	failed = false
	for index in car_count:
		cars.append(V4Elevator.new(index + 1, floors))

func spawn(origin: int, destination: int) -> V4Passenger:
	if origin == destination or mini(origin, destination) < 1 or maxi(origin, destination) > floors:
		return null
	var p := V4Passenger.new(passengers.size() + 1, origin, destination, time)
	p.patience = patience
	passengers.append(p)
	hall.register(p)
	return p

func step() -> void:
	if failed:
		return
	time += STEP_SECONDS
	for p in passengers:
		if p.waiting() and time - p.request_time >= p.patience - 0.000001:
			p.state = V4Passenger.State.MISSED
			p.owner = 0
			hall.remove(p)
			misses += 1
			passenger_missed.emit(p)
			if misses >= 5:
				failed = true
				return
	for car in cars:
		car.tick_strategy(STEP_SECONDS, hall)
	dispatcher.assign(self)
	for car in cars:
		car.step(STEP_SECONDS, hall, time)

func set_strategy(car_id: int, draft: V4Strategy, preparation: bool) -> bool:
	for car in cars:
		if car.id == car_id:
			return car.request_strategy(draft.validated(floors), preparation)
	return false

func is_drained() -> bool:
	for p in passengers:
		if p.state != V4Passenger.State.COMPLETED and p.state != V4Passenger.State.MISSED:
			return false
	return true
