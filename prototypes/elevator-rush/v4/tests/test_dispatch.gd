extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://dispatcher.gd"):
		t.check(false, "Autonomous dispatch must serve one shared call with several cars")
		return
	var sim := V4Simulation.new()
	sim.configure(4, 3)
	for index in 12:
		sim.spawn(1, 4)
	sim.dispatcher.assign(sim)
	t.check(sim.hall.groups.size() == 1, "One shared floor/direction call")
	for car in sim.cars:
		t.check(sim.hall.assigned(car.id).size() == 4, "Three disjoint capacity-four allocations")
	for tick in 500:
		sim.step()
	t.check(sim.is_drained() and sim.misses == 0, "All twelve riders arrive")
	sim = V4Simulation.new()
	sim.configure(4, 0)
	for index in 6:
		sim.spawn(1, 4)
	for tick in 500:
		sim.step()
	t.check(sim.failed and sim.misses == 5, "Fifth simultaneous expiry freezes the run")
	t.check(sim.passengers[5].waiting(), "Sixth expiry not processed after failure")
	var frozen_time := sim.time
	sim.step()
	t.check(sim.time == frozen_time, "Failed simulation freezes")
	sim = V4Simulation.new()
	sim.configure(4, 1)
	var p := sim.spawn(1, 4)
	p.patience = 0.45
	for tick in 9:
		sim.step()
	t.check(p.state == V4Passenger.State.MISSED and p.owner == 0, "Exact door/expiry boundary favors expiration")
	t.check(sim.hall.groups.is_empty(), "Expiry cleans request and reservation")
	sim = V4Simulation.new()
	sim.configure(4, 1)
	p = sim.spawn(1, 4)
	p.patience = 1.0
	for tick in 200:
		sim.step()
	t.check(p.state == V4Passenger.State.COMPLETED, "Patience stops at boarding")
