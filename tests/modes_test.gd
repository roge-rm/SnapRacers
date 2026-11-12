extends Node

## The single player modes. It runs a whole Grand Prix with the races cut
## short (each one "finishes" straight away in a set order), and checks the
## points, the grid order and the trophy at the end. Then a time trial and its
## records, practice, which never finishes, and the difficulty levels. A Grand
## Prix for two in split screen too.
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


## The standings showing, on a screen of their own or over the podium.
func _standings() -> GrandPrixStandings:
	var now := screen()
	if now is Race:
		return (now as Race).cup_standings
	return now as GrandPrixStandings


## After a cup's last race the podium goes up on the course first, and Back
## skips it to the standings over it.
func _past_podium(race: Race) -> void:
	if not Game.grand_prix.finished():
		return
	check(race.podium != null and screen() == race, "after the last race the podium goes up")
	race.podium._time = Podium.IGNORE_INPUT
	Game._go_back()
	check(screen() == race and race.cup_standings != null, "then the standings come up over it")


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	Records.use_file(RECORDS)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	# Normal difficulty, whatever was last picked, without saving over it.
	Game.settings.set_value("race", "difficulty", Difficulty.DEFAULT)
	await _kart_validation()
	await _grand_prix()
	await _grand_prix_for_two()
	await _difficulty()
	await _time_trial()
	await _practice()
	await _your_cup()
	Records.use_file(Records.FILE)
	print("All mode checks passed." if failures == 0 else "%d mode checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _kart_validation() -> void:
	print("-- Selected kart validation")
	var saved_design := Game.design
	var saved_settings := Game.settings.encode_to_text()
	var settings_existed := FileAccess.file_exists(Game.SETTINGS)
	var settings_file := FileAccess.get_file_as_bytes(Game.SETTINGS) if settings_existed else PackedByteArray()
	Game.design = KartDesign.new()
	var draft := Game.design
	Game.settings.set_value("race", "kart", Game.OWN_KART)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.racing_alone = false
	var path := Tracks.path_of("peach_pit")
	Game.show_kart_picker(Game.start_race.bind(path), Game.show_menu)
	await frames(2)
	var picker := screen() as KartPicker
	check(picker != null and picker._cards[Game.OWN_KART].disabled, "an unfinished garage kart cannot be picked")
	var key: String = Game.stock_keys().filter(func(k): return k != Game.DEFAULT_STOCK)[0]
	if picker != null:
		picker._cards[key].tapped.emit()
		picker._race.pressed.emit()
	var race := await wait_for(Race) as Race
	check(race != null and race.player.kart.design.name == Game.stock_kart(key).name, "picking another kart starts the race while the garage draft is unfinished")
	check(Game.design == draft and Game.design.parts.is_empty(), "racing a stock kart leaves the garage draft alone")

	Game.start_grand_prix("baseplate")
	race = await wait_for(Race) as Race
	check(race != null and race.player.kart.design.name == Game.stock_kart(key).name, "a cup also starts with the chosen stock kart and an unfinished draft")
	Game.settings.set_value("race", "kart", Game.OWN_KART)
	Game.next_grand_prix_race()
	race = await wait_for(Race) as Race
	check(race != null and race.player.kart.design.name == Game.stock_kart(key).name, "carrying on a cup checks its original kart choice")
	Game.grand_prix = null
	Game.settings.set_value("race", "kart", key)
	Game.settings.set_value("race", "player_two", Game.DEFAULT_STOCK)
	Game.settings.set_value("race", "split", Game.SIDE_BY_SIDE)
	Game.start_race(path)
	race = await wait_for(Race) as Race
	check(race != null and race.humans.size() == 2 and race.humans[0].kart.design.name == Game.stock_kart(key).name and race.humans[1].kart.design.name == Game.stock_kart(Game.DEFAULT_STOCK).name, "two selected stock karts race with an unfinished garage draft")

	Game.settings.set_value("race", "kart", Game.OWN_KART)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.start_race(path)
	await frames(2)
	check(screen() is Garage and Game.design == draft and not Game.design.problems().is_empty(), "racing the unfinished garage kart still returns to the garage")
	Game.design = saved_design
	Game.settings.clear()
	Game.settings.parse(saved_settings)
	if settings_existed:
		var file := FileAccess.open(Game.SETTINGS, FileAccess.WRITE)
		file.store_buffer(settings_file)
	else:
		DirAccess.remove_absolute(Game.SETTINGS)
	Game.show_menu()
	await frames(2)


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
	var cup_field := []
	# Finish every race with you coming second, behind whoever starts at the front.
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
		var ai_names: Array = race.racers.filter(func(r): return not r.player).map(func(r): return r.name)
		ai_names.sort()
		if round == 0:
			cup_field = ai_names
		else:
			check(ai_names == cup_field, "the same AI drivers as the first race %s" % [ai_names])
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
		order = [order[0], me] + order.slice(2)
		Game.finish_grand_prix_race(order)
		await _past_podium(race)
		await frames(2)
		var standings := _standings()
		check(standings != null, "after race %d the standings come up" % (round + 1))
		if round == 0:
			var next_button: Button = standings.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Next race"))[0]
			var block: Control = next_button.get_parent()
			check(block.get_global_rect().get_center().distance_to(standings.size * 0.5) < 2.0, "the heading, results and next race button share a centred block")
		if round < 3:
			var next := standings.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Next race"))
			check(next.size() == 1, "with a button for the next race")
			next[0].pressed.emit()
	check(Game.grand_prix.finished(), "after four races the cup is over")
	var place: int = Game.grand_prix.standings().map(func(s): return s[0]).find(me) + 1
	check(place >= 1 and place <= 3, "and you're on the podium (%s)" % RaceHud.ordinal(place))
	check(Records.best_cup_place("baseplate") == place, "which is kept as your best in the cup")
	var labels := _standings().find_children("*", "Label", true, false).map(func(l): return l.text)
	check(labels.any(func(t): return t.contains("trophy")), "and the last screen gives you a trophy")


## A Grand Prix for two from the Multiplayer menu: both people race every round
## against the AI in split screen, both score, and the trophy goes by the
## better of them.
func _grand_prix_for_two() -> void:
	print("-- Grand Prix for two")
	var was := {}
	for key in ["split", "kart", "player_two", "driver", "player_two_driver"]:
		was[key] = Game.settings.get_value("race", key) if Game.settings.has_section_key("race", key) else null
	var stock := Game.stock_keys()
	Game.settings.set_value("race", "split", Game.SIDE_BY_SIDE)
	Game.settings.set_value("race", "kart", stock[0])
	Game.settings.set_value("race", "player_two", stock[1])
	Game.settings.set_value("race", "driver", "stock:brickley")
	Game.settings.set_value("race", "player_two_driver", "stock:nova")
	Game.show_multiplayer()
	await frames(2)
	var cup_button := screen().find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Grand Prix"))
	check(cup_button.size() == 1, "the Multiplayer menu has a Grand Prix")
	cup_button[0].pressed.emit()
	await frames(2)
	check(screen() is CupGrid and screen().mode == Game.MODE_GRAND_PRIX and Game.cups_for_two, "which opens the cups for two")
	screen().find_children("*", "Button", true, false).filter(func(b): return b.get_meta("cup", "") == "gearbox")[0].pressed.emit()
	await frames(2)
	check(screen() is DriverPicker and screen().player == 1, "and picking a cup asks player 1 who drives first")
	Game._go_back()
	await frames(2)
	check(screen() is CupGrid and Game.cups_for_two, "back from the picker goes to the cups for two")

	# The two people never share a name, or their points would be kept as one.
	var names_were := [Game.settings.get_value("player", "name", ""), Game.settings.get_value("player", "name_two", "")]
	for pair in [["", ""], ["", "Player 1"], ["Player 2", ""], ["Sam", "Sam"], ["Player 2", "Player 2"], ["Sam", "Gina"]]:
		Game.settings.set_value("player", "name", pair[0])
		Game.settings.set_value("player", "name_two", pair[1])
		check(Game.player_one_name() != Game.player_two_name(), "names %s give %s and %s" % [pair, Game.player_one_name(), Game.player_two_name()])
	check(Game.player_two_name() == "Gina", "and player 2's own name is kept when it's different")
	Game.settings.set_value("player", "name", names_were[0])
	Game.settings.set_value("player", "name_two", names_were[1])

	var single_gearbox := Records.best_cup_place("gearbox")
	Game.start_grand_prix("gearbox", true)
	var one := Game.player_one_name()
	var two := Game.player_two_name()
	check(Game.grand_prix.people == [one, two], "both people are in the cup (%s and %s)" % [one, two])
	var mine := [Game.stock_kart(stock[0]).name, Game.stock_kart(stock[1]).name]
	var rounds := Game.grand_prix.track_ids().size()
	for round in rounds:
		var race: Race = await wait_for(Race)
		check(race != null and race.split == Game.SIDE_BY_SIDE, "race %d is in split screen" % (round + 1))
		check(race.humans.size() == 2 and race.humans.map(func(h): return h.name) == [one, two], "with both people racing")
		check(race.racers.size() == Race.KARTS, "and the same number of karts as on your own (%d)" % race.racers.size())
		var ai: Array = race.racers.filter(func(r): return not r.player)
		check(ai.all(func(r): return not mine.has(r.kart.design.name)), "no AI driver's in either player's kart")
		check(race.humans.map(func(h): return h.kart.driver.name) == ["Brickley", "Nova"], "each player races as who they picked")
		check(ai.all(func(r): return not ["Brickley", "Nova"].has(r.kart.driver.name)), "and no AI driver is either of them")
		if round == 0:
			# Picking again mid-cup changes nothing until the next cup.
			Game.settings.set_value("race", "driver", "stock:wren")
		if round == 1:
			# Player 2 won the first race, so starts last; player 1 came third.
			check(race.racers.find(race.humans[1]) == Race.KARTS - 1, "the grid goes by points for player 2")
			check(race.racers.find(race.humans[0]) == Race.KARTS - 3, "and for player 1")
		if round == 0:
			# Player 1 home first can't move on while player 2's still racing.
			race.humans[0].progress.finished = true
			race.humans[0].progress.finish_time = race.time
			race._player_finished(race.humans[0])
			await frames(2)
			var hud: RaceHud = race.humans[0].hud
			check(hud._next.disabled and hud._waiting.visible and hud._waiting.text == "%s is still racing" % two, "Standings waits for player 2 (%s)" % hud._waiting.text)
			hud.next_pressed.emit()
			await frames(2)
			check(screen() == race, "and the race doesn't end before player 2 is home")
			# Everyone but player 2 home lets it move on.
			var cpus: Array = race.racers.filter(func(r): return not r.player)
			for r in cpus:
				r.progress.finished = true
			await frames(2)
			check(not hud._next.disabled and not hud._waiting.visible, "once all but one are home, Standings can be pressed without player 2")
			for i in cpus.size():
				cpus[i].progress.finished = i < cpus.size() - 1
			await frames(2)
			check(hud._next.disabled, "and not with two still racing")
			for r in cpus:
				r.progress.finished = false
			race.humans[1].progress.finished = true
			race._player_finished(race.humans[1])
			await frames(2)
			check(not hud._next.disabled and not hud._waiting.visible, "once they are, Standings can be pressed")
		# Player 2 wins every race and player 1 comes third.
		var others: Array = race.racers.map(func(r): return r.name).filter(func(n): return n != one and n != two)
		var order: Array = [two, others[0], one] + others.slice(1)
		Game.finish_grand_prix_race(order)
		await _past_podium(race)
		await frames(2)
		var standings := _standings()
		check(standings != null, "after race %d the standings come up" % (round + 1))
		if round == 0:
			var next_button: Button = standings.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Next race"))[0]
			var block: Control = next_button.get_parent()
			check(block.get_global_rect().get_center().distance_to(standings.size * 0.5) < 2.0, "the heading, results and next race button share a centred block")
		var coloured := standings.find_children("*", "Label", true, false).filter(func(l): return l.text in [one, two] and l.has_theme_color_override("font_color"))
		check(coloured.size() == 2 and coloured.all(func(l): return KartPicker.PLAYER_COLOURS.has(l.get_theme_color("font_color"))), "with both people in their colours")
		if round < rounds - 1:
			standings.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Next race"))[0].pressed.emit()
	check(Game.grand_prix.finished(), "the cup's over")
	check(Game.grand_prix.points[two] == 15 * rounds and Game.grand_prix.points[one] == 10 * rounds, "both people scored (%s)" % [Game.grand_prix.points])
	check(Records.best_cup_place("gearbox", Difficulty.DEFAULT, true) == 1, "the trophy for two goes by the better place (%d)" % Records.best_cup_place("gearbox", Difficulty.DEFAULT, true))
	check(Records.best_cup_place("gearbox") == single_gearbox, "and single player's trophy isn't touched")
	check(CupGrid.best_place("gearbox", true) == 1 and CupGrid.best_place("gearbox") == single_gearbox, "the cups for two show their own trophy")
	Game._go_back()
	await frames(2)
	check(screen() is CupGrid and Game.cups_for_two, "leaving goes back to the cups for two")
	Game._go_back()
	await frames(2)
	check(screen() is MultiplayerMenu, "and back from there to the Multiplayer menu")

	# Quitting mid-cup goes back the same way.
	Game.start_grand_prix("gearbox", true)
	var race: Race = await wait_for(Race)
	race.leave()
	await frames(2)
	check(screen() is CupGrid and Game.cups_for_two and Game.grand_prix == null, "quitting a cup for two goes back to its cups")
	Game.show_cups()
	await frames(2)
	check(not Game.cups_for_two, "and Single player's Grand Prix stays for one")
	for key in was:
		if was[key] == null:
			Game.settings.erase_section_key("race", key)
		else:
			Game.settings.set_value("race", key, was[key])


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
		var ranks := Game.draw_ranks(Game.ai_field(1))
		check_ranks = ranks.values()
		for driver in ranks:
			if ranks[driver] == 0:
				quickest[driver] = true
	check_ranks.sort()
	check(check_ranks == range(7) and quickest.size() > 2, "the pecking order is shuffled every time (%d different drivers were quickest in 30 draws)" % quickest.size())
	# Each race draws its AI drivers from the roster, never one a player took.
	var picked := Game.driver_choice()
	var picked_two := Game.driver_choice(true)
	var was_mode := Game.mode
	Game.mode = Game.MODE_RACE
	Game.set_driver_choice(CharacterDesign.STOCK_KEY + "fizz")
	Game.set_driver_choice(CharacterDesign.STOCK_KEY + "maple", true)
	var fields := {}
	var clean := true
	var sizes := true
	for i in 30:
		var one := Game.ai_field(1)
		var two := Game.ai_field(2)
		clean = clean and not one.has("fizz") and not two.has("fizz") and not two.has("maple")
		sizes = sizes and one.size() == Race.KARTS - 1 and two.size() == Race.KARTS - 2
		var sorted := one.duplicate()
		sorted.sort()
		fields[str(sorted)] = true
	check(sizes, "the AI fill the grid, 7 with one player and 6 with two")
	check(clean, "and no AI driver is a stock driver a player picked")
	check(fields.size() > 1, "different races draw different AI drivers (%d fields in 30 draws)" % fields.size())
	Game.set_driver_choice(picked)
	Game.set_driver_choice(picked_two, true)
	Game.mode = was_mode
	Records.add_cup_place("axle", 2, "hard")
	check(Records.best_cup_place("axle", "hard") == 2 and Records.best_cup_place("axle") == 0, "a cup's trophies are kept for each level")
	Records.add_cup_place("axle", 1, "easy", false, "reverse")
	check(Records.best_cup_place("axle") == 0 and Records.best_cup_place("axle", "easy") == 0, "a reverse cup place does not fill ordinary")
	check(Records.best_cup_place("axle", "easy", false, "reverse") == 1, "and is kept as reverse Easy")
	Records.add_cup_place("axle", 2, "expert", false, "reverse mirrored")
	check(Records.best_cup_place("axle", "expert", false, "reverse") == 0 and Records.best_cup_place("axle", "expert", false, "mirrored") == 0, "reverse and mirrored stay empty when only both is finished")
	check(Records.best_cup_place("axle", "expert", false, "reverse mirrored") == 2, "and reverse mirrored is its own place")
	var saved := ConfigFile.new()
	saved.load(ProjectSettings.globalize_path(RECORDS))
	check(saved.get_value("cup", "axle reverse easy", 0) == 1 and saved.get_value("cup", "axle reverse mirrored expert", 0) == 2, "layout keys sit between the cup and the level")
	check(saved.get_value("cup", "axle hard", 0) == 2 and saved.get_value("cup", "axle", 0) == 0, "ordinary keys stay as they were")

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
	await frames(2)
	check(not race.player.hud._slots.visible, "and no power-up boxes on the screen")
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

	for weather in Conditions.WEATHERS:
		for time in Conditions.TIMES:
			var conditions := Conditions.resolve("temperate", weather, time, 1)
			if conditions.records_allowed():
				continue
			check(Records.add_time("peach_pit", 90.0, 20.0, conditions) == [false, false], "%s at %s cannot replace clear daytime records" % [weather, time])
	check(is_equal_approx(Records.best_time("peach_pit"), 120.75) and is_equal_approx(Records.best_lap("peach_pit"), 38.0), "ineligible runs leave saved records untouched")
	race.conditions = Conditions.resolve("temperate", "rain", "night", 1)
	p.finish_time = 90.0
	race._player_finished(race.player)
	cells = race.player.hud._results_list.get_children().map(func(c): return c.text)
	check(race.new_records == [false, false] and cells.has("Clear daytime only") and not cells.has("Course record"), "wet trial results explain why the time does not count")
	var indoor := Conditions.from_dict({"indoor": true, "weather": "snow", "time": "night"})
	check(Records.add_time("indoor_test", 90.0, 20.0, indoor) == [true, true], "indoor courses always allow records")
	Records.use_file(RECORDS)
	check(is_equal_approx(Records.best_time("peach_pit"), 120.75), "eligible records survive a reload")
	check(Records.add_time("peach_pit", 90.0, 20.0, null, "reverse") == [true, true], "a reverse time is a record of its own")
	check(is_equal_approx(Records.best_time("peach_pit"), 120.75) and is_equal_approx(Records.best_lap("peach_pit"), 38.0), "and does not replace ordinary peach_pit")
	check(is_equal_approx(Records.best_time("peach_pit", "reverse"), 90.0) and is_equal_approx(Records.best_lap("peach_pit", "reverse"), 20.0), "the reverse time and lap are kept")


func _practice() -> void:
	print("-- Practice")
	Game.start_practice(Tracks.path_of("launchpad_loop"))
	var race: Race = await wait_for(Race)
	check(race.mode == Game.MODE_PRACTICE and race.racers.size() == 1, "practice is just you too")
	check(race.laps > 1000, "and it goes on for as many laps as you like")
	check(race.boxes != null, "with power-ups, so you can try them out")
	await frames(20)
	check(race.player.hud._place.text == "Practice", "the HUD says it's practice")
	check(race.player.hud._slots.visible, "with the power-up boxes at the bottom")
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
	await frames(3)
	check(_cup_actions_fit(listed[0]), "Change and Share fit inside the custom cup's slanted card")
	var narrow := SubViewport.new()
	narrow.size = Vector2i(800, 450)
	add_child(narrow)
	var narrow_picker := CupGrid.new(Game.MODE_GRAND_PRIX, false, true)
	narrow.add_child(narrow_picker)
	await frames(4)
	var narrow_cards := narrow_picker.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("cup", "") == CupDesign.id_of(path))
	check(narrow_cards.size() == 1 and _cup_actions_fit(narrow_cards[0]), "custom cup actions stay readable and inside the card at 800 by 450")
	narrow.queue_free()
	await frames(2)
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


func _cup_actions_fit(card: MenuCard) -> bool:
	var actions := card.find_children("*", "Button", true, false).filter(func(button): return button.text in ["Change", "Share"])
	if actions.size() != 2 or actions[0].get_global_rect().intersects(actions[1].get_global_rect()):
		return false
	var face := card.get_theme_stylebox("normal") as SlantBox
	var tilt := face.tilt_for(card.size.y)
	var into := card.get_global_transform().affine_inverse()
	for action in actions:
		if action.size.y < 40.0 or action.size.x < action.get_combined_minimum_size().x:
			return false
		for corner in [Vector2.ZERO, Vector2(action.size.x, 0), action.size, Vector2(0, action.size.y)]:
			var point: Vector2 = into * (action.get_global_transform() * corner)
			var right := card.size.x - point.y * tilt - face.edge_width
			if point.y < 0.0 or point.y > card.size.y or point.x < face.left_at(card.size, point.y) or point.x > right:
				return false
	return true
