extends Node

## Runs every race in a Grand Prix and checks its layout through the standings.
const MOST_TIME := 600.0

var host: Node


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	var args := OS.get_cmdline_user_args()
	var reversed := args.has("reversed=on")
	var mirrored := args.has("mirrored=on")
	Game.set_reversed(reversed)
	Game.set_mirrored(mirrored)
	Game.start_grand_prix("baseplate")
	var places: Array = []
	var all_finished := true
	var race: Race = await _wait_for_race()
	for round in 4:
		var expected_track: String = Game.grand_prix.track_ids()[round]
		if race.track_id != expected_track:
			push_error("Race %d loaded %s instead of %s" % [round + 1, race.track_id, expected_track])
			get_tree().quit(1)
			return
		var layout_ok := race.track.reversed == reversed and race.track.mirrored == mirrored
		if not layout_ok:
			push_error("Race %d loaded the wrong layout" % (round + 1))
			get_tree().quit(1)
			return
		var driver := AIDriver.new()
		driver.kart = race.player.kart
		driver.track = race.track
		race.add_child(driver)
		race.player.ai = driver
		race.player.kart.controls = driver.controls
		while not race.started:
			await get_tree().process_frame
		print("SOAK %s race=%d reversed=%s mirrored=%s" % [race.track_id, round + 1, reversed, mirrored])
		var elapsed := 0.0
		while elapsed < MOST_TIME and not race.racers.all(func(r: Race.Racer) -> bool: return r.progress.finished):
			await get_tree().physics_frame
			elapsed = race.time
		var order := race.standings().map(func(r: Race.Racer) -> String: return r.name)
		var finished := 0
		for racer in race.racers:
			if racer.progress.finished:
				finished += 1
		all_finished = all_finished and race.racers.size() == 8 and finished == 8
		print("RESULT %s reversed=%s mirrored=%s: %d of %d finished, %.0f s" % [race.track_id, reversed, mirrored, finished, race.racers.size(), race.time])
		places.append(order.find(Game.player_name()) + 1)
		Game.finish_grand_prix_race(order)
		if round < 3:
			Game.next_grand_prix_race()
			race = await _wait_for_race(race)
			var next_ok := race.track.reversed == Game.grand_prix.reversed and race.track.mirrored == Game.grand_prix.mirrored
			if not next_ok:
				push_error("Race %d lost the cup layout after standings" % (round + 2))
				get_tree().quit(1)
				return
			if race.track.reversed != reversed or race.track.mirrored != mirrored:
				push_error("Race %d layout flags changed" % (round + 2))
				get_tree().quit(1)
				return
	var gp := Game.grand_prix
	var standings := gp.standings()
	print("CUP baseplate places=%s reversed=%s mirrored=%s layout_still_on=%s standings=%s" % [places, gp.reversed, gp.mirrored, gp.reversed == reversed and gp.mirrored == mirrored, standings])
	all_finished = all_finished and places.size() == 4 and gp.finished()
	get_tree().quit(0 if all_finished and gp.reversed == reversed and gp.mirrored == mirrored else 1)


func _wait_for_race(previous: Race = null) -> Race:
	while true:
		for child in host.get_children():
			if child is Race and child != previous:
				return child
		await get_tree().process_frame
	return null
