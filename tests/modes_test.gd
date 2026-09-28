extends Node

## The single player modes. It runs a whole Grand Prix with the races cut
## short (each one "finishes" straight away in a set order), and checks the
## points, the grid order and the trophy at the end. Then a time trial and its
## records, and practice, which never finishes.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/modes_test.tscn

const RECORDS := "user://test_records.cfg"

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func screen() -> Node:
	for i in range(host.get_child_count() - 1, -1, -1):
		var child := host.get_child(i)
		if not child.is_queued_for_deletion():
			return child
	return null


## Waits for a new screen of this kind (not the one showing now).
func wait_for(kind: Variant) -> Node:
	var before := screen()
	for i in 300:
		await frames(1)
		if is_instance_of(screen(), kind) and screen() != before:
			return screen()
	return null


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	Records.use_file(RECORDS)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await _grand_prix()
	await _time_trial()
	await _practice()
	Records.use_file(Records.FILE)
	print("All mode checks passed." if failures == 0 else "%d mode checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _grand_prix() -> void:
	print("-- Grand Prix")
	var gp := GrandPrix.new("baseplate")
	check(gp.track_ids().size() == 4, "a cup has four races")
	gp.add_results(["A", "B", "C"])
	gp.add_results(["C", "A", "B"])
	check(gp.points == {"A": 27, "B": 22, "C": 25}, "points add up race by race %s" % [gp.points])
	check(gp.standings().map(func(s): return s[0]) == ["A", "C", "B"], "and the standings go by points")
	check(gp.grid_order() == ["B", "C", "A"], "and the leader starts at the back of the next race")

	Game.start_grand_prix("baseplate")
	var me := Game.player_name()
	# Finish every race with you coming second, behind Brickley.
	for round in 4:
		var race: Race = await wait_for(Race)
		check(race != null and race.mode == Game.MODE_GRAND_PRIX, "race %d of the cup starts" % (round + 1))
		check(race.track_id == Game.grand_prix.track_ids()[round], "on the cup's course %d (%s)" % [round + 1, race.track.name])
		check(race.racers.size() == Race.KARTS, "against the AI (%d karts)" % race.racers.size())
		if round == 1:
			# You were second, so you start near the back but not last.
			var slot := race.racers.find(race.player)
			check(slot == Race.KARTS - 2, "after a race the grid goes by points, leader at the back (you're in slot %d)" % slot)
		var order: Array = [race.racers[0].name, me]
		for r in race.racers:
			if not order.has(r.name):
				order.append(r.name)
		if round == 0:
			order = ["Brickley", me] + order.filter(func(n): return n != "Brickley" and n != me)
		else:
			order = [order[0], me] + order.slice(2)
		Game.finish_grand_prix_race(order)
		await frames(2)
		var standings := screen() as GrandPrixStandings
		check(standings != null, "after race %d the standings come up" % (round + 1))
		if round < 3:
			var next := standings.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Next race"))
			check(next.size() == 1, "with a button for the next race")
			next[0].pressed.emit()
	check(Game.grand_prix.finished(), "after four races the cup is over")
	var place: int = Game.grand_prix.standings().map(func(s): return s[0]).find(me) + 1
	check(place >= 1 and place <= 3, "and you're on the podium (%s)" % RaceHud.ordinal(place))
	check(Records.best_cup_place("baseplate") == place, "which is kept as your best in the cup")
	var labels := screen().find_children("*", "Label", true, false).map(func(l): return l.text)
	check(labels.any(func(t): return t.contains("trophy")), "and the last screen gives you a trophy")


func _time_trial() -> void:
	print("-- Time trial")
	Game.start_time_trial(Tracks.path_of("peach_pit"))
	var race: Race = await wait_for(Race)
	check(race.mode == Game.MODE_TIME_TRIAL and race.racers.size() == 1, "a time trial is just you (%d karts)" % race.racers.size())
	check(race.studs == null, "with no studs to pick up")
	# Pretend you've done three laps.
	var p := race.player.progress
	p.lap_times.assign([41.5, 39.25, 40.0])
	p.finished = true
	p.finish_time = 120.75
	race._player_finished(race.player)
	check(race.new_records == [true, true], "the first go is a record for time and lap")
	check(is_equal_approx(Records.best_time("peach_pit"), 120.75) and is_equal_approx(Records.best_lap("peach_pit"), 39.25), "and both are kept")
	check(Records.add_time("peach_pit", 125.0, 38.0) == [false, true], "a slower time with a faster lap only beats the lap record")
	var cells := race.player.hud._results_list.get_children().map(func(c): return c.text)
	check(cells.has("Best lap") and cells.has("Course record"), "the results show your laps and the record %s" % [cells.slice(0, 6)])
	var again := race.player.hud._results.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(again == ["Try again", "Other course", "Menu"], "with the right choices %s" % [again])


func _practice() -> void:
	print("-- Practice")
	Game.start_practice(Tracks.path_of("launchpad_loop"))
	var race: Race = await wait_for(Race)
	check(race.mode == Game.MODE_PRACTICE and race.racers.size() == 1, "practice is just you too")
	check(race.laps > 1000, "and it goes on for as many laps as you like")
	check(race.studs != null, "with studs, so you can try your gadgets")
	await frames(20)
	check(race.player.hud._place.text == "Practice", "the HUD says it's practice")
	race.leave()
	await frames(2)
	var picker := screen() as TrackPicker
	check(picker != null and picker.mode == Game.MODE_PRACTICE, "leaving goes back to the practice course list")
