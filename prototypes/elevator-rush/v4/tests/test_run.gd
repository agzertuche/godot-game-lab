extends RefCounted

func run(t) -> void:
	var first := V4Waves.definition(77, 1)
	t.check(first.floors == 4 and first.passengers == 12 and first.pattern == "lobby_up", "First wave forecast")
	var fifth := V4Waves.definition(77, 5)
	var sixth := V4Waves.definition(77, 6)
	t.check(fifth.floors == 5 and sixth.passengers == 32, "Introductory progression reaches five floors")
	var a := V4Waves.definition(123, 3)
	var b := V4Waves.definition(123, 3)
	t.check(a.schedule == b.schedule, "Seeded demand repeats exactly")
	var run := V4Run.new(99)
	t.check(run.phase == V4Run.Phase.PREPARATION and run.start_wave(), "Run enters automatic wave")
	for _i in 2000:
		run.advance(0.05)
		if run.phase != V4Run.Phase.RUNNING:
			break
	t.check(run.phase == V4Run.Phase.REPORT or run.phase == V4Run.Phase.FAILED, "Wave reaches report or failure")
