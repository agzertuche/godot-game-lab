extends RefCounted

func run(t) -> void:
	var sim := V4Simulation.new()
	sim.configure(4, 1)
	if not sim.has_method("set_strategy"):
		t.check(false, "Live strategy API must drain finite commitments")
		return
	var p := sim.spawn(1, 4)
	sim.step()
	var draft := V4Strategy.new()
	draft.max_floor = 2
	t.check(sim.set_strategy(1, draft, false), "Accept pending strategy")
	var car := sim.cars[0]
	for tick in 230:
		if tick % 20 == 0:
			sim.spawn(1, 4)
		if tick == 10:
			draft.staging = 2
			t.check(sim.set_strategy(1, draft, false), "Replace pending draft")
		sim.step()
		if car.pending_strategy == null:
			break
	t.check(p.state == V4Passenger.State.COMPLETED, "Original rider delivered before coverage changes")
	t.check(car.active_strategy.max_floor == 2 and car.active_strategy.staging == 2, "Latest pending settings activate despite arrivals")
	t.check(car.cooldown_remaining > 7.9, "Eight-second cooldown starts on activation")
	t.check(not sim.set_strategy(1, draft, false), "Reject apply during cooldown")
	t.check(sim.set_strategy(1, draft, true) and car.cooldown_remaining == 0, "Preparation change immediate without cooldown")
	sim = V4Simulation.new()
	sim.configure(4, 1)
	p = sim.spawn(4, 1)
	p.patience = 0.1
	sim.step()
	sim.set_strategy(1, draft, false)
	for tick in 30:
		sim.step()
	t.check(sim.cars[0].pending_strategy == null, "Expired committed pickup does not block activation")
	# Soft down preference must still handle an upward request.
	sim = V4Simulation.new()
	sim.configure(4, 1)
	draft = V4Strategy.new()
	draft.preference = -1
	sim.set_strategy(1, draft, true)
	p = sim.spawn(1, 3)
	for tick in 200:
		sim.step()
	t.check(p.state == V4Passenger.State.COMPLETED, "Direction preference is soft")
