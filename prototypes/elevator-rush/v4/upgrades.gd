class_name V4Upgrades
extends RefCounted

const IDS := ["motor", "cabin", "doors", "boarding", "express", "patience", "aging"]

static func descriptions() -> Dictionary:
	return {"motor": "Faster Motor · +25% speed for one car", "cabin": "Larger Cabin · +2 seats for one car", "doors": "Faster Doors · 20% quicker doors", "boarding": "Quick Boarding · 20% quicker transfers", "express": "Express Service · skip new hall calls while loaded", "patience": "Patient Passengers · +5 seconds system-wide", "aging": "Aging Protection · prioritize old requests"}

static func offer(seed_value: int, wave: int, cars: Array, patience: float = 25.0, aging: bool = false) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ (wave * 1231)
	var eligible: Array[String] = []
	for id in IDS:
		if id == "motor" and cars.all(func(car): return car.speed >= 2.0):
			continue
		if id == "cabin" and cars.all(func(car): return car.capacity >= 8):
			continue
		if id == "doors" and cars.all(func(car): return car.door_seconds <= 0.160001):
			continue
		if id == "boarding" and cars.all(func(car): return car.transfer_seconds <= 0.140001):
			continue
		if id == "express" and cars.all(func(car): return car.express_owned):
			continue
		if id == "patience" and patience >= 40.0:
			continue
		if id == "aging" and aging:
			continue
		eligible.append(id)
	eligible.shuffle()
	var result: Array[String] = []
	for id in eligible:
		if result.size() >= 3:
			break
		result.append(id)
	return result

static func apply(id: String, target_id: int, sim: V4Simulation) -> bool:
	if id == "patience":
		sim.patience = minf(40.0, sim.patience + 5.0)
		return true
	if id == "aging":
		sim.dispatcher.aging_protection = true
		return true
	for car in sim.cars:
		if car.id != target_id:
			continue
		match id:
			"motor": car.speed = minf(2.0, car.speed + 0.25)
			"cabin": car.capacity = mini(8, car.capacity + 2)
			"doors": car.door_seconds = maxf(0.16, car.door_seconds * 0.8)
			"boarding": car.transfer_seconds = maxf(0.14, car.transfer_seconds * 0.8)
			"express": car.express_owned = true; car.active_strategy.express = true
			_: return false
		return true
	return false
