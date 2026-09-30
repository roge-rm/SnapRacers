extends Node

## Times every stock kart around a few courses with the AI driving, to check
## they're close enough to each other that any of them can win. Each kart does
## two laps on its own, from a standing start. Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/balance.tscn
## Name karts or courses after -- to only do those, like -- rocket peach_pit.

const COURSES := ["peach_pit", "foundry_flats", "launchpad_loop", "dune_drift"]
const LAPS := 2
const GIVE_UP := 400.0

var host: Node
var _last: Race


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	var only: Array = OS.get_cmdline_user_args()
	# Any of the game's courses can be named, not just the usual four.
	var named: Array = only.filter(func(o): return o in Tracks.all())
	var courses: Array = named if not named.is_empty() else COURSES
	var karts: Array = Game.stock_keys().filter(func(k): return only.is_empty() or only.has(k) or not only.any(func(o): return Game.stock_keys().has(o)))
	var times := {}
	for course in courses:
		for key in karts:
			var result: Array = await _time(key, course)
			times[key] = times.get(key, []) + [result]
			print("%-14s %-16s %s" % [key, course, "%.1f s, laps %s, %d resets" % [result[0], result[1], result[2]] if result[0] < INF else "didn't finish"])
	# How each kart compares with the middle of the field, course by course.
	print("\n%-14s %s   overall" % ["kart", "   ".join(courses.map(func(c): return "%-14s" % c))])
	var middles := []
	for i in courses.size():
		var all: Array = karts.map(func(k): return times[k][i][0])
		all.sort()
		middles.append(all[all.size() / 2])
	for key in karts:
		var line := "%-14s" % key
		var total := 0.0
		for i in courses.size():
			var ratio: float = times[key][i][0] / middles[i]
			total += ratio
			line += "   %+5.1f%%        " % ((ratio - 1.0) * 100.0)
		line += "   %+5.1f%%" % ((total / courses.size() - 1.0) * 100.0)
		print(line)
	get_tree().quit()


## Two laps of a course in one stock kart, as [time, lap times, resets].
func _time(key: String, course: String) -> Array:
	Game.settings.set_value("race", "kart", key)
	Game.mode = Game.MODE_TIME_TRIAL
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race and child != _last and not child.is_queued_for_deletion():
				race = child
	_last = race
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	driver.others.assign([race.player.kart])
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	var resets := [0]
	var racer := race.player
	# How it was doing a moment before, for working out why it was reset.
	var before: Array[String] = []
	race.player.kart.was_reset.connect(func() -> void:
		resets[0] += 1
		if OS.has_environment("RACE_DEBUG") and before.size() > 40:
			print("    %s reset. A second before: %s\n      half a second before: %s" % [key, before[-60] if before.size() >= 60 else before[0], before[-30]]))
	while race.player.progress.lap_times.size() < LAPS and race.time < GIVE_UP:
		await get_tree().physics_frame
		if OS.has_environment("TRACE_FROM") and Engine.get_physics_frames() % (60 if OS.has_environment("TRACE_ALL") else 10) == 0:
			var from := float(OS.get_environment("TRACE_FROM"))
			if racer.offset > from and (racer.offset < from + 40.0 or OS.has_environment("TRACE_ALL")) and racer.progress.lap_times.is_empty():
				var k := racer.kart
				var side := (k.global_position - race.track.point_at(racer.offset)).dot(race.track.right_at(racer.offset))
				print("    %.1f m: %.1f m/s, %+.1f m across, steer %+.2f of %.0f°, throttle %.1f brake %.1f, bend %.3f, boost %.1f" % [racer.offset, k.linear_velocity.length(), side, k.controls.steer, rad_to_deg(k.full_lock), k.controls.throttle, k.controls.brake, race.track.bend_at(racer.offset), k.boost_left])
		if OS.has_environment("RACE_DEBUG"):
			var kart := racer.kart
			var piece: int = race.track.piece_of[race.track._index_before(racer.offset)]
			var middle := race.track.point_at(racer.offset)
			before.append("at %.0f m on a %s, %.1f m/s, up %.2f, %.1f m above the road, %.1f m from its middle, %d wheels down, lost %d parts" % [racer.offset, race.track.pieces[piece].type, kart.linear_velocity.length(), kart.global_basis.y.y, kart.global_position.y - middle.y, (kart.global_position - middle).length(), kart.wheels.filter(func(w): return w.grounded).size(), kart.lost.size()] + ", throttle %.1f brake %.1f steer %.1f, touching %s" % [kart.controls.throttle, kart.controls.brake, kart.controls.steer, kart.get_colliding_bodies().map(func(b): return "%s %s" % [b.name, b.get_class()])])
			if before.size() > 120:
				before.pop_front()
	if OS.has_environment("RACE_DEBUG") and race.player.progress.lap_times.size() < LAPS:
		print("    %s gave up at %.0f m, going %.1f m/s, %.1f m across the road, stuck %.1f s, backing %.1f s" % [key, racer.offset, racer.kart.linear_velocity.length(), (racer.kart.global_position - race.track.point_at(racer.offset)).dot(race.track.right_at(racer.offset)), driver._stuck, driver._backing])
	var laps: Array = race.player.progress.lap_times.slice(0, LAPS)
	var total := INF
	if laps.size() >= LAPS:
		total = laps.reduce(func(a, b): return a + b, 0.0)
	return [total, laps.map(func(t): return snappedf(t, 0.1)), resets[0]]
