extends Node

## Runs a whole race with the AI driving every kart, yours included, and
## checks everyone gets round without getting stuck.
##
## It runs as a scene because the race uses the Game autoload. --fixed-fps
## lets it run flat out instead of in real time, with the physics still
## stepping 1/60 s at a time (speeding up Engine.time_scale makes the steps
## longer instead, and the suspension can't cope with that):
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/race_test.tscn

const GIVE_UP := 260.0 # seconds of race time

var race: Race
var failures := 0
var resets := {}
var first_lap := {}


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_race()
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
		racer.kart.was_reset.connect(func() -> void: resets[racer.name] += 1)
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
			print("  %s: %s, laps %s, %d resets" % [racer.name, RaceHud.clock(racer.progress.finish_time) if racer.progress.finished else "didn't finish", racer.progress.lap_times.map(func(t): return snappedf(t, 0.1)), resets[racer.name]])
		for racer in race.racers:
			check(racer.progress.finished, "%s finishes" % racer.name)
			check(resets[racer.name] <= 3, "%s rarely needs a reset (%d)" % [racer.name, resets[racer.name]])
		var fastest := INF
		for racer in race.racers:
			if racer.progress.finished:
				fastest = minf(fastest, racer.progress.finish_time)
		check(fastest < 150.0, "the winner takes under two and a half minutes (%.1f s)" % fastest)
		print("All race checks passed." if failures == 0 else "%d race checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)
		race = null
