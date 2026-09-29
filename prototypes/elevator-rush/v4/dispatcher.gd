class_name V4Dispatcher
extends RefCounted

signal assigned(passenger: V4Passenger, car: V4Elevator)
var aging_protection := false

func calculate_assignment_cost(car: V4Elevator, p: V4Passenger, _now: float) -> float:
	var distance := absf(p.origin - car.floor_position) / car.speed
	var turnaround := 0.0
	if car.direction != 0 and (p.direction != car.direction or (p.origin - car.floor_position) * car.direction < 0):
		turnaround = 5.0
	var preference := 2.0 if car.active_strategy.preference != 0 and car.active_strategy.preference != p.direction else 0.0
	return distance + turnaround + preference + car.destinations().size() * 0.8 + car.riders.size() * 0.3

func assign(sim: V4Simulation) -> void:
	var candidates: Array[V4Passenger] = []
	for p in sim.passengers:
		if p.waiting() and p.owner == 0:
			candidates.append(p)
	# Recompute costs after each seat reservation. Stable tie-breaking is explicit.
	while not candidates.is_empty():
		var chosen: V4Passenger
		var chosen_car: V4Elevator
		var best := INF
		for p in candidates:
			for car in sim.cars:
				if not car.accepts(p, sim.hall):
					continue
				var score := calculate_assignment_cost(car, p, sim.time) + sim.hall.assigned(car.id).size() * 0.3
				if chosen == null or score < best - 0.000001:
					chosen = p
					chosen_car = car
					best = score
		if chosen == null:
			break
		sim.hall.reserve(chosen.id, chosen_car.id)
		assigned.emit(chosen, chosen_car)
		candidates.erase(chosen)
