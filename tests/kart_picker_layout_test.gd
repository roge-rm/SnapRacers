extends Node

## The kart picker: its two sections, cards the size of the driver cards with
## their words inside the slant, the stats panel, everything fitting with and
## without a camera hole, the New kart round trip, racing a saved kart and
## falling back when it's gone.
##
##   XDG_DATA_HOME=SCRATCH tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/kart_picker_layout_test.tscn

var failures := 0
var checks := 0
var host: Node


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func screen() -> Node:
	return Game._screen


func wait_for(kind: Variant) -> Node:
	var before := screen()
	for i in 300:
		await frames(1)
		if is_instance_of(screen(), kind) and screen() != before:
			return screen()
	return null


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await frames(5)
	var was_kart := Game.kart_choice()
	var was_two := Game.player_two_kart()
	for path in KartDesign.saved_paths():
		DirAccess.remove_absolute(path)
	await _sections()
	await _layout()
	var saved := await _new_kart()
	await _saved_kart_races(saved)
	await _deleted_falls_back(saved)
	Game.set_kart_choice(was_kart)
	Game.set_setting("race", "player_two", was_two)
	SafeArea.pretend.assign([])
	print("%d kart picker checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)


func _sections() -> void:
	print("-- Sections")
	Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true))
	await frames(4)
	var picker := screen() as KartPicker
	var headings := picker.find_children("*", "Label", true, false).filter(func(l): return l.text.to_upper() in ["YOUR KARTS", "STOCK KARTS"]).map(func(l): return l.text.to_upper())
	check(headings == ["YOUR KARTS", "STOCK KARTS"], "your karts then stock karts (%s)" % [headings])
	var yours: Array = picker.yours.get_children()
	check(yours.size() == 2 and yours[0].get_meta("kart", "") == Game.OWN_KART and yours[1] == picker.new_card, "with no saved karts it's the garage kart and New kart")
	var name: Label = yours[0].find_child("Name", true, false)
	check(name.text == Game.design.name, "the garage kart goes by its own name (%s)" % name.text)
	check(picker.stock.get_child_count() == Game.stock_keys().size(), "every stock kart in its own section")
	check(picker.yours.columns == DriverGrid.COLUMNS and picker.stock.columns == DriverGrid.COLUMNS, "as many to a row as the driver cards")
	var weight: Label = picker._cards[Game.DEFAULT_STOCK].find_child("Weight", true, false)
	check(weight != null and weight.text.ends_with(" kg"), "each card says its weight (%s)" % (weight.text if weight else ""))
	picker._cards["scrambler"].tapped.emit()
	var picked: Dictionary = picker.amounts_for(Game.stock_kart("scrambler"))
	check(Game.kart_choice() == "scrambler" and is_equal_approx(picker._bars["speed"].amount, picked.speed), "picking a kart shows its bars")
	var other: String = Game.stock_keys().filter(func(k): return k != "scrambler" and not is_equal_approx(picker.amounts_for(Game.stock_kart(k)).speed, picked.speed))[0]
	picker._cards[other].grab_focus()
	await frames(1)
	check(is_equal_approx(picker._bars["speed"].amount, picker.amounts_for(Game.stock_kart(other)).speed), "moving onto a card shows its bars")
	picker._race.grab_focus()
	await frames(1)
	check(is_equal_approx(picker._bars["speed"].amount, picked.speed), "and moving off goes back to the picked kart's")
	# A saved copy of the garage kart is only shown once, as the garage card.
	var copy_path := Game.design.duplicate_design().save()
	Game.set_kart_choice(KartDesign.key_for(copy_path))
	Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true))
	await frames(4)
	picker = screen() as KartPicker
	check(picker.yours.get_child_count() == 2 and picker.chosen() == Game.OWN_KART, "a saved copy of the garage kart isn't shown twice (%d cards, %s)" % [picker.yours.get_child_count(), picker.chosen()])
	DirAccess.remove_absolute(copy_path)


func _layout() -> void:
	print("-- Layout")
	var stock := Game.stock_keys()
	for entry in [["Red Rocket", 0], ["A kart with a very long name indeed", 4]]:
		var kart := Game.stock_kart(stock[entry[1]])
		kart.name = entry[0]
		kart.save()
	for holes in [[], [Rect2(0, 320, 70, 80)]]:
		SafeArea.pretend.assign(holes)
		for setup in [[true, 0], [true, 1], [false, 2]]:
			Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, setup[0], setup[1]))
			await frames(4)
			var picker := screen() as KartPicker
			var what := "player %d, %d holes" % [setup[1], holes.size()]
			var wide := get_viewport().get_visible_rect().size.x
			var back: Control = picker.find_children("*", "Button", true, false).filter(func(b): return b.text == "Back")[0]
			check(back.get_global_rect().end.x <= wide + 0.5 and picker._race.get_global_rect().end.x <= wide + 0.5, "Back and %s fit, %s" % [picker._race.text, what])
			var panel: Control = picker._stats_grid.get_parent()
			var inside := panel.get_global_rect().grow(1.0)
			var fits := true
			for bar in picker._bars.values():
				fits = fits and inside.encloses(bar.get_global_rect()) and bar.size.x >= 30.0
			check(fits and panel.get_global_rect().end.x <= picker._race.get_global_rect().position.x, "the stats bars fit in their panel, %s" % what)
			check(picker._cards[Game.OWN_KART].size == DriverGrid.CARD, "cards are the driver cards' size, %s" % what)
			if setup[1] == 0 and holes.is_empty():
				check(picker.yours.get_child_count() == 4, "saved karts sit between the garage kart and New kart")
				await _words_fit(picker)


## Every card's words stay inside its slanted edges.
func _words_fit(picker: KartPicker) -> void:
	var fits := true
	var worst := ""
	for card: Button in picker._cards.values() + [picker.new_card]:
		var shape := card.get_theme_stylebox("normal") as SlantBox
		var tilt := shape.tilt_for(card.size.y)
		for label: Label in card.find_children("*", "Label", true, false):
			if label.text == "+":
				continue
			var rect: Rect2 = label.get_global_rect()
			var local: Vector2 = rect.position - card.get_global_position()
			var bottom: float = local.y + rect.size.y
			var right: float = card.size.x - bottom * tilt - shape.edge_width
			var text_width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			var end: float = local.x + minf(rect.size.x, text_width)
			if end > right or bottom > card.size.y - 4.0 or local.x < 0.0:
				fits = false
				worst += " %s (end %d of %d, bottom %d of %d, left %d)" % [label.text, end, right, bottom, card.size.y, local.x]
	check(fits, "names and weights stay inside the slanted cards %s" % worst)


## New kart opens the garage with an empty kart, and leaving it with parts
## saves it, picks it and comes back here.
func _new_kart() -> String:
	print("-- New kart")
	for path in KartDesign.saved_paths():
		DirAccess.remove_absolute(path)
	Game.show_race_setup(func(): pass, Game.show_menu, true, false, true)
	await frames(3)
	var picker := screen() as KartPicker
	picker.new_card.tapped.emit()
	await frames(3)
	var garage := screen() as Garage
	check(garage != null and garage.design.parts.is_empty() and garage.design.name == "New kart", "New kart opens the garage with an empty kart")
	if garage == null:
		return ""
	var built := Game.stock_kart("scrambler")
	built.name = "Mud Hopper"
	garage.design = built
	garage.go_back()
	await frames(3)
	picker = screen() as KartPicker
	var saved := KartDesign.saved_paths()
	check(saved.size() == 1 and saved[0].ends_with("mud_hopper.json"), "leaving saves it with your karts (%s)" % [saved])
	var key := KartDesign.key_for(saved[0]) if not saved.is_empty() else ""
	check(picker != null and picker._cards.has(key) and picker.yours.get_child(1) == picker._cards[key], "back on the kart picker with it after the garage kart")
	check(Game.kart_choice() == key and picker != null and picker.chosen() == key, "and it's picked (%s)" % Game.kart_choice())
	# Leaving an empty new kart saves nothing.
	picker.new_card.tapped.emit()
	await frames(3)
	(screen() as Garage).go_back()
	await frames(3)
	check(screen() is KartPicker and KartDesign.saved_paths().size() == 1 and Game.kart_choice() == key, "an empty new kart isn't saved")
	return key


func _saved_kart_races(key: String) -> void:
	print("-- Racing a saved kart")
	Game.set_kart_choice(key)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.racing_alone = false
	Game.start_race(Tracks.path_of("peach_pit"))
	var race := await wait_for(Race) as Race
	check(race != null and race.player.kart.design.name == "Mud Hopper", "a picked saved kart is the one raced (%s)" % (race.player.kart.design.name if race else "no race"))
	Game.set_setting("race", "player_two", key)
	check(Game.player_two_kart() == key and Game.player_two_design().name == "Mud Hopper", "player 2 can pick a saved kart too")
	Game.show_menu()
	await frames(3)


func _deleted_falls_back(key: String) -> void:
	print("-- Deleted saved kart")
	DirAccess.remove_absolute(KartDesign.path_for_key(key))
	Game.set_kart_choice(key)
	var fallback := Game.OWN_KART if Game.design.problems().is_empty() else Game.DEFAULT_STOCK
	check(Game.kart_choice() == fallback and Game.chosen_design().name == Game.kart_design(fallback).name, "your pick falls back once it's deleted (%s)" % Game.kart_choice())
	check(Game.kart_design(key).name == Game.stock_kart(Game.DEFAULT_STOCK).name, "a cup started in it races the default stock kart")
	Game.set_setting("race", "player_two", key)
	check(Game.player_two_kart() == Game.PLAYER_TWO_STOCK, "player 2's pick falls back too")
	Game._swap(KartPicker.new(Game.show_menu, Game.show_menu))
	await frames(3)
	check(not (screen() as KartPicker)._cards.has(key) and (screen() as KartPicker).chosen() == fallback, "the picker marks the fallback")
