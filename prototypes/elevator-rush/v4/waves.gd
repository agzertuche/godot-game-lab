class_name V4Waves
extends RefCounted

static func definition(root_seed: int, wave: int) -> Dictionary:
	var index := maxi(1, wave)
	var floor_count := 4 if index <= 3 else 5
	var count := 8 + index * 4
	var pattern := "lobby_up" if index == 1 else "heavy_lobby_up" if index == 2 else "mixed" if index == 3 else "upper_return" if index == 4 else "mixed_bursts"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root_seed) ^ (index * 7919)
	var schedule: Array[Dictionary] = []
	for passenger_index in count:
		var origin := 1
		var destination := rng.randi_range(2, floor_count)
		if pattern == "mixed" or pattern == "mixed_bursts":
			origin = rng.randi_range(1, floor_count)
			destination = rng.randi_range(1, floor_count)
			while destination == origin:
				destination = rng.randi_range(1, floor_count)
		elif pattern == "upper_return" and passenger_index % 3 == 0:
			origin = rng.randi_range(2, floor_count)
			destination = 1
		var burst := 0.0 if passenger_index < count / 3 else 10.0 if passenger_index < count * 2 / 3 else 20.0
		schedule.append({"at": burst + float(passenger_index % 4) * 0.45, "origin": origin, "destination": destination})
	return {"wave": index, "floors": floor_count, "passengers": count, "pattern": pattern, "duration": 30.0, "schedule": schedule}
