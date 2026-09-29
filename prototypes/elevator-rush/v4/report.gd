class_name V4Report
extends RefCounted

static func snapshot(sim: V4Simulation, wave: int) -> Dictionary:
	var delivered := 0
	var missed := 0
	var total_wait := 0.0
	var longest := 0.0
	for passenger in sim.passengers:
		if passenger.state == V4Passenger.State.COMPLETED:
			delivered += 1
			total_wait += passenger.pickup_wait
			longest = maxf(longest, passenger.pickup_wait)
		elif passenger.state == V4Passenger.State.MISSED:
			missed += 1
	var cars: Array[Dictionary] = []
	for car in sim.cars:
		cars.append({"id": car.id, "transported": car.transported, "stops": car.stops, "full": car.full_seconds, "idle": car.idle_seconds, "capacity": car.capacity})
	return {"wave": wave, "total": sim.passengers.size(), "delivered": delivered, "missed": missed, "average_wait": total_wait / float(delivered) if delivered > 0 else 0.0, "longest_wait": longest, "cars": cars}
