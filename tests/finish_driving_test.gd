extends Node

## Crosses the finish with a human at the controls, then leaves the AI to
## drive while the results are up, including one player finishing first.

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	var saved := Game.settings.encode_to_text()
	Game.settings.set_value("race", "kart", "kart_kid")
	Game.settings.set_value("race", "player_two", "kart_kid")
	for split in [Game.SOLO, Game.SIDE_BY_SIDE]:
		Game.settings.set_value("race", "split", split)
		await _finish(split)
	Game.settings.clear()
	Game.settings.parse(saved)
	print("All finish driving checks passed." if failures == 0 else "%d finish driving checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _finish(split: String) -> void:
	print("-- Finish driving %s" % split)
	var previous := Game._screen
	Game.start_race(Tracks.path_of("peach_pit"))
	for i in 300:
		await get_tree().process_frame
		if Game._screen is Race and Game._screen != previous:
			break
	var race := Game._screen as Race
	check(race != null, "the race starts")
	if race == null:
		return
	await frames(5)
	race.started = true
	race.time = 120.0
	race.train_clock.now = race.time
	for racer in race.racers:
		racer.kart.locked = false
	var human: Race.Racer = race.humans[-1]
	check(human.ai == null and human.kart.controls == human.input.controls, "the player approaches the line without an AI driver")
	human.input.set_physics_process(false)
	human.input.controls.throttle = 1.0
	var before_line := race.track.length - 2.0
	human.offset = before_line
	human.progress = RaceProgress.new(race.track.length, race.laps, before_line)
	human.progress.laps = race.laps - 1
	human.progress._quarters_seen = {1: true, 2: true, 3: true}
	human.progress._lap_started = 80.0
	human.kart.global_transform = race.track.place_at(before_line)
	human.kart.linear_velocity = race.track.forward_at(before_line) * 15.0
	human.kart.angular_velocity = Vector3.ZERO
	for i in 120:
		await frames(1)
		if human.progress.finished:
			break
	check(human.progress.finished and human.ai != null and human.kart.controls == human.ai.controls, "crossing the finish hands the kart to the AI")
	if not human.progress.finished or human.ai == null:
		return
	check(is_equal_approx(human.ai.offset, human.offset) and is_equal_approx(human.ai.clock, race.train_clock.now), "the AI starts at the kart's current road position and crossing clock")
	var finished_at := human.progress.finish_time
	var finished_distance := human.progress.distance()
	var previous_offset := human.offset
	human.input.controls.throttle = 0.0
	human.input.controls.brake = 1.0
	var travelled := 0.0
	for i in 60 * 12:
		await frames(1)
		travelled += wrapf(human.offset - previous_offset, -race.track.length * 0.5, race.track.length * 0.5)
		previous_offset = human.offset
	print("        drove %.1f m after finishing, speed %.1f m/s" % [travelled, human.kart.forward_speed])
	check(travelled > 80.0 and human.kart.forward_speed > 3.0, "the AI keeps driving after the player releases GO or holds the brake")
	check(human.hud._results.visible and human.kart.controls == human.ai.controls, "the AI still owns the controls while the results stay open")
	check(human.progress.finish_time == finished_at and human.progress.distance() == finished_distance, "driving on keeps the recorded finish unchanged")
	var driver := human.ai
	human.kart.controls = human.input.controls
	driver.offset = -1.0
	driver.clock = -1.0
	race._player_finished(human)
	check(human.ai == driver and human.kart.controls == driver.controls and is_equal_approx(driver.offset, human.offset) and is_equal_approx(driver.clock, race.train_clock.now), "an existing AI driver also gets the kart's controls and current position")
	if split != Game.SOLO:
		var other: Race.Racer = race.humans[0]
		check(not other.progress.finished and other.ai == null and other.kart.controls == other.input.controls, "the other player keeps manual control until they finish")
