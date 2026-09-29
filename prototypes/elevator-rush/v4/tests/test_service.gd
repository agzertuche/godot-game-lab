extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://simulation.gd"):
		t.check(false, "Transport simulation must exist and deliver reserved passengers")
		return
	var model = load("res://simulation.gd")
	var sim = model.new()
	sim.configure(4, 1)
	t.check(sim.spawn(1, 1) == null, "Reject equal trip endpoints")
	var p = sim.spawn(1, 4)
	sim.hall.reserve(p.id, 1)
	var events: Array[String] = []
	sim.cars[0].passenger_boarded.connect(func(_p): events.append("board"))
	sim.cars[0].passenger_exited.connect(func(_p): events.append("exit"))
	for tick in 400:
		sim.step()
	t.check(p.state == p.State.COMPLETED, "Reserved 1→4 passenger completes")
	t.check(events == ["board", "exit"], "Exactly one board and exit event")
	t.check(sim.cars[0].riders.is_empty() and sim.hall.groups.is_empty(), "Delivery clears cabin and hall request")
	t.check(trip_time(model, 4) > trip_time(model, 1) + 1.5, "Four passenger transfers cost more than one")
	# Real cabin destinations must be served in ascending order, with one stop per floor.
	sim = model.new()
	sim.configure(4, 1)
	var destinations: Array[int] = []
	sim.cars[0].passenger_exited.connect(func(rider): destinations.append(rider.destination))
	for floor in [4, 2, 3, 3]:
		p = sim.spawn(1, floor)
		sim.hall.reserve(p.id, 1)
	for tick in 600:
		sim.step()
		t.check(sim.cars[0].riders.size() <= 4, "Capacity never exceeded")
	t.check(destinations == [2, 3, 3, 4], "Collective ascending order, duplicate destinations")
	t.check(sim.cars[0].stops == 4, "One pickup and three distinct delivery stops")
	var car = sim.cars[0]
	car.active_strategy.staging = 1
	var stops_before: int = car.stops
	for tick in 150:
		sim.step()
	t.check(car.floor_position == 1.0 and car.stops == stops_before, "Idle parking is not a service stop")

func trip_time(model, count: int) -> float:
	var sim = model.new()
	sim.configure(4, 1)
	for index in count:
		var p = sim.spawn(1, 4)
		sim.hall.reserve(p.id, 1)
	for tick in 800:
		sim.step()
		if sim.is_drained():
			return sim.time
	return INF
