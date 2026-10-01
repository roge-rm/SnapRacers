extends Node

## The single player modes. It runs a whole Grand Prix with the races cut
## short (each one "finishes" straight away in a set order), and checks the
## points, the grid order and the trophy at the end. Then a time trial and its
## records, practice, which never finishes, and the difficulty levels.
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
	# Normal difficulty, whatever was last picked, without saving over it.
	Game.settings.set_value("race", "difficulty", Difficulty.DEFAULT)
	await _grand_prix()
	await _difficulty()
	await _time_trial()
	await _practice()
	await _your_cup()
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
	var karts := {}
	var skill_order := {}
	# Finish every race with you coming second, behind Brickley.
	for round in 4:
		var race: Race = await wait_for(Race)
		check(race != null and race.mode == Game.MODE_GRAND_PRIX, "race %d of the cup starts" % (round + 1))
		check(race.track_id == Game.grand_prix.track_ids()[round], "on the cup's course %d (%s)" % [round + 1, race.track.name])
		check(race.racers.size() == Race.KARTS, "against the AI (%d karts)" % race.racers.size())
		# The AI are the drivers from the roster, each in a stock kart they keep
		# for the whole cup.
		var now := {}
		for r in race.racers:
			now[r.name] = r.kart.design.name
		var skills := {}
		for r in race.racers:
			if not r.player:
				skills[r.name] = snappedf(r.ai.skill, 0.0001)
		if round == 0:
			skill_order = skills
		else:
			check(skills == skill_order, "and the same pecking order")
		if round == 0:
			karts = now
			var ai: Array = race.racers.filter(func(r): return not r.player)
			check(ai.all(func(r): return Game.ai_driver_keys().has(r.name.to_lower())), "the AI are the roster's drivers %s" % [ai.map(func(r): return r.name)])
			var kinds := {}
			for r in ai:
				kinds[r.kart.design.name] = true
			check(kinds.size() == ai.size(), "each in a different stock kart %s" % [now.values()])
		else:
			check(now == karts, "everyone's in the same kart as the first race")
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


var check_ranks := []


func _difficulty() -> void:
	print("-- Difficulty")
	var ai := AIDriver.new()
	var ranges := []
	for level in Difficulty.LEVELS:
		Difficulty.apply(ai, level, 0, 7)
		var quickest := ai.skill
		Difficulty.apply(ai, level, 6, 7)
		ranges.append([quickest, ai.skill, ai.mistakes])
	ai.free()
	var climbs := true
	for i in range(1, ranges.size()):
		climbs = climbs and ranges[i][0] > ranges[i - 1][0] and ranges[i][1] > ranges[i - 1][1] and ranges[i][2] <= ranges[i - 1][2]
	check(climbs and ranges.all(func(r): return r[0] > r[1]), "each level's drivers are quicker and slip less than the last's, and the field is spread out %s" % [ranges])
	check(Difficulty.push_for(300.0, 0.04, 0.1) > 1.0 and is_equal_approx(Difficulty.push_for(10.0, 0.04, 0.1), 1.0), "far behind, the AI gets a little extra push, but not when it's close")
	check(Difficulty.push_for(-200.0, 0.0, 0.3) < 0.8, "and on Easy it lifts off when it's well ahead of you")
	check(is_equal_approx(Difficulty.push_for(300.0, 0.0, 0.0), 1.0) and is_equal_approx(Difficulty.push_for(-300.0, 0.0, 0.0), 1.0), "while Expert never helps anyone")
	# A different driver's the quickest from race to race.
	var quickest := {}
	for i in 30:
		var ranks := Game.draw_ranks(Game.ai_driver_keys())
		check_ranks = ranks.values()
		for driver in ranks:
			if ranks[driver] == 0:
				quickest[driver] = true
	check_ranks.sort()
	check(check_ranks == range(7) and quickest.size() > 2, "the pecking order is shuffled every time (%d different drivers were quickest in 30 draws)" % quickest.size())
	Records.add_cup_place("axle", 2, "hard")
	check(Records.best_cup_place("axle", "hard") == 2 and Records.best_cup_place("axle") == 0, "a cup's trophies are kept for each level")

	Game.settings.set_value("race", "difficulty", "expert")
	Game.start_race(Tracks.path_of("peach_pit"))
	var race: Race = await wait_for(Race)
	var skills: Array = race.racers.filter(func(r): return not r.player).map(func(r): return r.ai.skill)
	check(race.difficulty == "expert" and skills.all(func(k): return k >= 0.94), "a race uses the level you picked %s" % [skills])
	Game.settings.set_value("race", "difficulty", Difficulty.DEFAULT)


func _time_trial() -> void:
	print("-- Time trial")
	Game.start_time_trial(Tracks.path_of("peach_pit"))
	var race: Race = await wait_for(Race)
	check(race.mode == Game.MODE_TIME_TRIAL and race.racers.size() == 1, "a time trial is just you (%d karts)" % race.racers.size())
	check(race.boxes == null, "with no power-ups to pick up")
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
	check(race.boxes != null, "with power-ups, so you can try them out")
	await frames(20)
	check(race.player.hud._place.text == "Practice", "the HUD says it's practice")
	race.leave()
	await frames(2)
	var picker := screen()
	check((picker is CupGrid or picker is CourseGrid) and picker.mode == Game.MODE_PRACTICE, "leaving goes back to the practice courses")


## A cup of your own: made on the Make a cup page from one of the game's
## courses and one you've built, then raced like any other cup.
func _your_cup() -> void:
	var built := CourseDesign.starter()
	built.name = "Modes Test Course"
	built.pieces.append_array([{"type": "straight", "length": 2}, {"type": "curve", "turn": "right", "size": 2}, {"type": "straight", "length": 3}])
	built.pieces.append_array(built.close_up())
	var course_path := built.with_start_on_longest_straight().save()

	Game.show_cup_builder()
	await frames(2)
	var builder: CupBuilder = screen()
	check(builder != null and builder._save.disabled, "Make a cup starts empty, and can't be saved yet")
	builder._name.text = "Modes Test Cup"
	builder._name.text_changed.emit("Modes Test Cup")
	var courses := builder.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("track"))
	courses.filter(func(b): return b.get_meta("track") == Tracks.path_of("peach_pit"))[0].pressed.emit()
	courses.filter(func(b): return b.get_meta("track") == course_path)[0].pressed.emit()
	check(builder.cup.races.size() == 2 and not builder._save.disabled, "adding two races makes it ready to save")
	builder.save()
	await frames(2)
	var picker: CupGrid = screen()
	var path := CupDesign.path_for("Modes Test Cup")
	check(FileAccess.file_exists(path), "it saves as a cup of your own")
	var listed := picker.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("cup", "") == CupDesign.id_of(path))
	check(picker.yours and listed.size() == 1, "and it's with your cups")
	Game.show_cups()
	await frames(2)
	var yours := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("yours"))
	check(yours.size() == 1, "which the Grand Prix has a card for")

	# Racing it.
	var cup := CupDesign.load_file(path)
	Game.start_grand_prix(cup.to_cup(CupDesign.id_of(path)))
	var race: Race = await wait_for(Race)
	check(race != null and race.track.name == "Peach Pit", "it starts on its first course")
	check(Game.grand_prix.track_ids().size() == 2, "and it's two races long")
	Game.grand_prix.add_results(race.standings().map(func(r): return r.name))
	check(not Game.grand_prix.finished() and TrackPath.load_file(Game.grand_prix.track_path()).name == "Modes Test Course", "the second race is on the course you built")
	Game.grand_prix.add_results(race.standings().map(func(r): return r.name))
	check(Game.grand_prix.finished(), "and after that the cup's done")
	Game.grand_prix = null
	Game.show_cups()
	await frames(2)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(course_path)
