extends Node

## Times a lap of Peach Pit and Foundry Flats in the default stock kart
## (Kart Kid), with the AI driving as a middling driver of the seven. Checks
## each level is quicker than the one before, and about as far behind Expert
## as it's meant to be (see GAPS). Clear daytime and fixed race/driver seeds
## keep weather and random mistakes from changing the comparison each run.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/difficulty_test.tscn

const GIVE_UP := 240.0
const SEED := 12345
const COURSES := ["peach_pit", "foundry_flats"]
## How far behind Expert each level laps, in percent, and how far off that
## still counts. Easy makes the most mistakes, so it gets a little more margin.
const GAPS := {"easy": [25.0, 5.5], "normal": [10.0, 5.0], "hard": [4.0, 2.0]}

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.character = Kart.default_driver()
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "kart", Game.DEFAULT_STOCK)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	var last: Race = null
	for course in COURSES:
		var times := {}
		for level in Difficulty.LEVELS:
			seed(SEED)
			Game.mode = Game.MODE_TIME_TRIAL
			Game.show_race(Game.TRACKS + "/%s.json" % course)
			var race: Race = null
			while race == null:
				await get_tree().process_frame
				for child in host.get_children():
					if child is Race and child != last and not child.is_queued_for_deletion():
						race = child
			last = race
			var driver := AIDriver.new()
			driver.kart = race.player.kart
			driver.track = race.track
			driver.others.assign([race.player.kart])
			Difficulty.apply(driver, level, 3, 7)
			race.add_child(driver)
			driver._rng.seed = SEED # _ready randomizes it when added to the race.
			var resets := [0]
			race.player.kart.was_reset.connect(func() -> void:
				resets[0] += 1
				print("    %s, %s reset at %.0f m" % [course, level, race.player.offset]))
			race.player.ai = driver
			race.player.kart.controls = driver.controls
			while race.player.progress.lap_times.is_empty() and race.time < GIVE_UP:
				await get_tree().physics_frame
			times[level] = race.player.progress.lap_times[0] if not race.player.progress.lap_times.is_empty() else INF
			check(is_finite(times[level]), "%s, %s finishes a lap" % [course, Difficulty.name_of(level)])
			print("  %s, %s: %.1f s, %d resets" % [course, Difficulty.name_of(level), times[level], resets[0]])
			if course == "foundry_flats":
				check(resets[0] == 0, "%s finishes Foundry Flats without resetting" % Difficulty.name_of(level))
		check(times.easy > times.normal and times.normal > times.hard and times.hard > times.expert, "on %s each level laps quicker than the one before" % course)
		for level in GAPS:
			var gap: float = (times[level] / times.expert - 1.0) * 100.0
			var want: Array = GAPS[level]
			check(absf(gap - want[0]) <= want[1], "and %s is %.1f%% behind Expert (it should be about %.1f%%)" % [Difficulty.name_of(level), gap, want[0]])
	print("All difficulty checks passed." if failures == 0 else "%d difficulty checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
