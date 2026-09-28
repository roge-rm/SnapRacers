extends Node

## Runs a whole race with the AI driving every kart, yours included, and
## checks that everyone gets around without getting stuck.
##
## It runs as a scene because the race uses the Game autoload. --fixed-fps
## lets it run as fast as it can instead of in real time, with the physics
## still stepping 1/60 s at a time. (Speeding up Engine.time_scale makes the
## steps longer instead, and the suspension can't cope with that.) Pass a
## track's file name after -- to race there instead of Peach Pit.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/race_test.tscn -- launchpad_loop

const GIVE_UP := 260.0 # seconds of race time

var race: Race
var failures := 0
var resets := {}
var first_lap := {}
var used := {}


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var which := "peach_pit"
	if not OS.get_cmdline_user_args().is_empty():
		which = OS.get_cmdline_user_args()[0]
	# One player, whatever was last picked, without saving over it.
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.show_race(Game.TRACKS + "/" + which + ".json")
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	# Let the AI drive your kart too.
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	driver.others.assign(race.racers.map(func(r): return r.kart))
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	for racer in race.racers:
		resets[racer.name] = 0
		racer.kart.gadget_used.connect(func(kind: String) -> void: used[kind] = used.get(kind, 0) + 1)
		racer.kart.was_reset.connect(func() -> void:
			resets[racer.name] += 1
			if OS.has_environment("RACE_DEBUG"):
				print("RESET %s (%s) at %.0f m (piece %d %s) speed %.1f" % [racer.name, racer.kart.design.name, racer.offset, race.track.piece_of[race.track._index_before(racer.offset)], race.track.pieces[race.track.piece_of[race.track._index_before(racer.offset)]].type, racer.kart.linear_velocity.length()]))
	print("%s, %.0f m a lap, %d karts" % [race.track.name, race.track.length, race.racers.size()])


func _physics_process(_delta: float) -> void:
	if race == null:
		return
	for racer in race.racers:
		if racer.progress.lap_times.size() >= 1 and not first_lap.has(racer.name):
			first_lap[racer.name] = racer.progress.lap_times[0]
	var everyone := race.racers.all(func(r): return r.progress.finished)
	if everyone or race.time > GIVE_UP:
		for racer in race.standings():
			print("  %s in the %s: %s, laps %s, %d resets" % [racer.name, racer.kart.design.name, RaceHud.clock(racer.progress.finish_time) if racer.progress.finished else "didn't finish", racer.progress.lap_times.map(func(t): return snappedf(t, 0.1)), resets[racer.name]])
		for racer in race.racers:
			check(racer.progress.finished, "%s finishes" % racer.name)
			# With cannon bricks, dropped piles and a pack going around a loop, a
			# reset now and then is part of racing. A kart that keeps needing them
			# isn't.
			check(resets[racer.name] <= 6, "%s doesn't keep needing resets (%d)" % [racer.name, resets[racer.name]])
		var fewest: int = race.racers.map(func(r): return r.kart.studs_picked).min()
		check(fewest >= 15, "every kart gets a fair share of studs (fewest %d)" % fewest)
		var all_resets: int = resets.values().reduce(func(a, b): return a + b, 0)
		# The courses are narrow kart tracks with tight hairpins, so eight karts
		# bump into each other now and then, most of all on the first lap.
		check(all_resets <= 20, "not many resets across the whole field (%d)" % all_resets)
		print("  gadgets used: %s" % [used])
		print("  studs picked up: %s" % [race.racers.map(func(r): return "%s %d" % [r.name, r.kart.studs_picked])])
		check(used.size() >= 2, "the AI uses more than one kind of gadget (%d kinds)" % used.size())
		var fastest := INF
		for racer in race.racers:
			if racer.progress.finished:
				fastest = minf(fastest, racer.progress.finish_time)
		var average := race.track.length * race.laps / fastest
		check(average > 13.5, "the winner goes around at a good clip (%.1f s, %.1f m/s)" % [fastest, average])
		print("All race checks passed." if failures == 0 else "%d race checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)
		race = null
