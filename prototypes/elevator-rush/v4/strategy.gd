class_name V4Strategy
extends RefCounted

var min_floor := 1
var max_floor := 4
var staging := 1
var preference := 0
var express := false

func validated(floors: int) -> V4Strategy:
	var copy := V4Strategy.new()
	copy.min_floor = clampi(mini(min_floor, max_floor), 1, floors)
	copy.max_floor = clampi(maxi(min_floor, max_floor), 1, floors)
	copy.staging = clampi(staging, 1, floors)
	copy.preference = clampi(preference, -1, 1)
	copy.express = express
	return copy

func covers(p: V4Passenger) -> bool:
	return p.origin >= min_floor and p.origin <= max_floor and p.destination >= min_floor and p.destination <= max_floor

func summary() -> String:
	var mode := "Normal" if preference == 0 else "Favor up" if preference == 1 else "Favor down"
	return "F%d–%d · idle F%d · %s%s" % [min_floor, max_floor, staging, mode, " · Express" if express else ""]
