extends RefCounted

func run(t) -> void:
	var sim := V4Simulation.new()
	sim.configure(4, 3)
	t.check(V4Upgrades.apply("motor", 1, sim) and is_equal_approx(sim.cars[0].speed, 1.25), "Motor changes travel speed")
	t.check(V4Upgrades.apply("cabin", 1, sim) and sim.cars[0].capacity == 6, "Cabin increases capacity")
	var before := sim.cars[0].transfer_seconds
	t.check(V4Upgrades.apply("boarding", 1, sim) and sim.cars[0].transfer_seconds < before, "Boarding upgrade changes transfer time")
	t.check(V4Upgrades.apply("patience", 0, sim) and sim.patience == 30.0, "Patient passengers changes expiry")
	var offers := V4Upgrades.offer(12, 1, sim.cars)
	t.check(offers.size() <= 3 and offers.size() == offers.duplicate().size(), "Upgrade offer is unique and capped")
	sim.cars[0].speed = 2.0; sim.cars[1].speed = 2.0; sim.cars[2].speed = 2.0
	t.check(not V4Upgrades.offer(12, 1, sim.cars).has("motor"), "Capped motor is not offered")
