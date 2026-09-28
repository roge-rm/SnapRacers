extends Node

## Times a lap of Peach Pit in the Starter with the AI driving at each
## difficulty, as a middling driver of the seven, and checks each level is
## quicker than the one before.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/difficulty_test.tscn

const GIVE_UP := 90.0

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
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "kart", "starter")
	var times := {}
	var last: Race = null
	for level in Difficulty.LEVELS:
		Game.mode = Game.MODE_TIME_TRIAL
		Game.show_race(Game.TRACKS + "/peach_pit.json")
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
		race.player.ai = driver
		race.player.kart.controls = driver.controls
		while race.player.progress.lap_times.is_empty() and race.time < GIVE_UP:
			await get_tree().physics_frame
		times[level] = race.player.progress.lap_times[0] if not race.player.progress.lap_times.is_empty() else INF
		print("  %s: %.1f s" % [Difficulty.name_of(level), times[level]])
	check(times.easy > times.normal and times.normal > times.hard and times.hard > times.expert, "each level laps quicker than the one before")
	check(times.easy > times.expert * 1.06, "and Easy is well behind Expert (%.1f%%)" % ((times.easy / times.expert - 1.0) * 100.0))
	print("All difficulty checks passed." if failures == 0 else "%d difficulty checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
