extends Node

## Reverse and mirrored as race settings: they persist, a cup copies them,
## apply_layout follows those flags, and cup medals follow the header's layout.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/layout_settings_test.tscn

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var saved_reversed := Game.reversed()
	var saved_mirrored := Game.mirrored()
	var saved_kart: Variant = Game.settings.get_value("race", "kart", Game.OWN_KART)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	check(not Game.reversed() and not Game.mirrored(), "a test start leaves reverse and mirrored off")

	Game.set_reversed(true)
	Game.set_mirrored(false)
	check(Game.reversed() and not Game.mirrored(), "reversed persists through set_setting")
	Game.set_mirrored(true)
	Game.set_reversed(false)
	check(not Game.reversed() and Game.mirrored(), "mirrored persists through set_setting")

	Game.set_reversed(true)
	Game.set_mirrored(true)
	Game.settings.set_value("race", "kart", Game.DEFAULT_STOCK)
	Game.start_grand_prix("baseplate")
	check(Game.grand_prix != null and Game.grand_prix.reversed and Game.grand_prix.mirrored, "start_grand_prix copies both flags")

	var peach := TrackPath.load_file(Tracks.path_of("peach_pit"))
	peach.apply_layout(Game.grand_prix.mirrored, Game.grand_prix.reversed)
	check(peach.mirrored and peach.reversed, "peach_pit apply_layout from those flags")

	Game.set_reversed(false)
	Game.set_mirrored(true)
	peach = TrackPath.load_file(Tracks.path_of("peach_pit"))
	peach.apply_layout(Game.mirrored(), Game.reversed())
	check(peach.mirrored and not peach.reversed, "peach_pit apply_layout from Game flags one at a time")

	Game.settings.set_value("race", "kart", saved_kart)
	Game.set_reversed(saved_reversed)
	Game.set_mirrored(saved_mirrored)
	_pips()
	await _picker_row()
	_cup_header()
	print("%d layout settings checks passed." % checks if failures == 0 else "%d of %d layout settings checks failed." % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _pips() -> void:
	print("-- Cup layout filter")
	const RECORDS := "user://layout_settings_records.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	Records.use_file(RECORDS)
	check(Records.layout_key(false, false) == "" and Records.layout_key(true, false) == "reverse" and Records.layout_key(false, true) == "mirrored" and Records.layout_key(true, true) == "reverse mirrored", "layout_key names reverse, mirrored and both")
	Records.add_cup_place("baseplate", 1)
	Records.add_cup_place("baseplate", 2, Difficulty.DEFAULT, false, "reverse")
	Records.add_cup_place("baseplate", 1, "hard", false, "reverse")
	Records.add_cup_place("baseplate", 3, "easy", false, "reverse mirrored")
	Records.add_cup_place("baseplate", 1, "hard", true, "mirrored")
	var ordinary := CupGrid.medals_for("baseplate")
	var reverse := CupGrid.medals_for("baseplate", false, "reverse")
	var both := CupGrid.medals_for("baseplate", false, "reverse mirrored")
	check(ordinary[1].is_equal_approx(UiKit.MEDALS[1]) and ordinary[0].a == 0.0, "ordinary Normal is gold, Easy empty")
	check(reverse[1].is_equal_approx(UiKit.MEDALS[2]) and reverse[2].is_equal_approx(UiKit.MEDALS[1]), "reverse Normal is silver, Hard gold")
	check(both[0].is_equal_approx(UiKit.MEDALS[3]) and both[1].a == 0.0, "reverse mirrored Easy is bronze, Normal empty")
	check(CupGrid.best_place("baseplate") == 1 and CupGrid.best_place("baseplate", false, "reverse") == 1, "the trophy follows the picked layout")
	check(CupGrid.medals_for("baseplate", true, "mirrored")[2].is_equal_approx(UiKit.MEDALS[1]) and CupGrid.medals_for("baseplate", true)[2].a == 0.0, "cups for two keep their own mirrored medals")
	check(is_equal_approx(MenuCard.PILL.y, 20.0) and is_equal_approx(MenuCard.PILL.x, 46.0), "pills are only as wide as the three letters")
	Records.use_file(Records.FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))


func _picker_row() -> void:
	print("-- Kart picker")
	var picker := KartPicker.new(func() -> void: pass, func() -> void: pass, true)
	add_child(picker)
	await get_tree().process_frame
	var layout := 0
	for node in picker.find_children("*", "Button", true, false):
		if node.text == "Reverse" or node.text == "Mirrored":
			layout += 1
	check(layout == 0, "reverse and mirrored have left the kart picker")
	var header: HBoxContainer = picker._difficulty_row.get_parent()
	var back := header.get_child(header.get_child_count() - 1) as Button
	check(picker._difficulty_row.get_index() == 1 and back != null and back.text == "Back", "AI difficulty sits between Pick a kart and Back")
	var names: Array = picker._difficulty_row.get_children().map(func(b): return b.text)
	check(names == ["Easy", "Normal", "Hard", "Expert"], "Easy, Normal, Hard and Expert share that row")
	check(picker.find_children("*", "Label", true, false).filter(func(l): return l.text == "AI drivers").is_empty(), "the AI drivers label has left")
	var was_level := Game.difficulty()
	Game.set_difficulty("easy")
	picker._show_level("easy")
	check(picker._levels["easy"].get_theme_color("font_color") == MenuStyle.ACCENT and picker._levels["hard"].get_theme_color("font_color") == Color.WHITE, "easy lights up when it's on")
	picker._levels["hard"].pressed.emit()
	check(Game.difficulty() == "hard" and picker._levels["hard"].get_theme_color("font_color") == MenuStyle.ACCENT, "tapping hard picks it")
	Game.set_difficulty(was_level)
	picker.free()
	var trial := KartPicker.new(func() -> void: pass, func() -> void: pass, false)
	add_child(trial)
	await get_tree().process_frame
	check(trial._difficulty_row == null and trial.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("level")).is_empty(), "a time trial has no difficulty in the header")
	trial.free()


func _cup_header() -> void:
	print("-- Cup header")
	var cups := CupGrid.new()
	add_child(cups)
	var outer: VBoxContainer = cups._column.get_parent().get_parent().get_parent()
	var top: HBoxContainer = outer.get_child(0)
	check(cups._conditions_row.get_parent() == top, "weather, time, reverse and mirrored sit in the header")
	var back := top.get_child(top.get_child_count() - 1) as Button
	check(cups._conditions_row.get_index() == 1 and back != null and back.text == "Back", "between the title and Back")
	check(cups._conditions_row.get_child_count() == 4, "the four picks share that row")
	check(cups._conditions_row.get_child(0) == cups._weather and cups._conditions_row.get_child(1) == cups._time and cups._conditions_row.get_child(2) == cups._reversed and cups._conditions_row.get_child(3) == cups._mirrored, "weather and time sit before reverse and mirrored")
	Game.set_weather("rain")
	Game.set_time_of_day("day")
	Game.set_reversed(false)
	Game.set_mirrored(false)
	cups._show_conditions()
	check(cups._weather.text == "Rain" and cups._time.text == "Day", "weather and time say the pick")
	check(cups._reversed.text == "Reverse" and cups._mirrored.text == "Mirrored", "reverse and mirrored are just the words")
	check(cups._reversed.get_theme_color("font_color") == Color.WHITE, "reverse is dark when it's off")
	Game.set_reversed(true)
	cups._show_conditions()
	check(cups._reversed.get_theme_color("font_color") == MenuStyle.ACCENT, "reverse lights up when it's on")
	Game.set_reversed(false)
	cups._show_conditions()
	check(cups._reversed.get_theme_color("font_color") == Color.WHITE, "and goes dark when it's off again")
