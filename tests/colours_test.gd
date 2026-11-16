extends Node

## Kart and driver colours: the old palette colours load as the same colour,
## a colour from anywhere survives saving, loading and share codes, a bad one
## falls back, Recent keeps the last 6 newest first, and the garage and driver
## screen palettes show Recent and open More colours.
##
## Saves settings, so run it with XDG_DATA_HOME inside build/:
##   XDG_DATA_HOME=build/colours-profile tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/colours_test.tscn

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/")):
		push_error("Set XDG_DATA_HOME to a folder inside build/.")
		get_tree().quit(1)
		return
	var saved_recent: Variant = Game.settings.get_value("paint", "recent", [])
	_old_colours()
	_new_colours()
	_bad_colours()
	_recent()
	await _palettes()
	Game.set_setting("paint", "recent", saved_recent)
	print("%d colour checks, %d failed." % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _kart(colour: Variant) -> Dictionary:
	var entry := {"id": "brick_2x2", "pos": [0, 0, 0], "turn": 0}
	if colour != null:
		entry["color"] = colour
	return {"name": "Colour test", "about": "", "parts": [entry]}


func _old_colours() -> void:
	print("-- Old colours")
	var kart_ok := true
	for hex in GarageUI.PAINTS:
		var design := KartDesign.from_dict(_kart(hex))
		var back: Dictionary = design.to_dict().parts[0]
		kart_ok = kart_ok and design.parts[0].color == Color(hex) and back.color == hex
	check(kart_ok, "every old garage paint loads and saves as the same colour")
	var driver_ok := true
	for hex in CharacterDesign.palette():
		var code := Paints.code(hex)
		var design := CharacterDesign.from_dict({"head": {"style": "smile", "color": code}, "torso": {"style": "racing_suit", "color": code}})
		driver_ok = driver_ok and design.color_of("torso") == Color(code) and design.to_dict().torso.color == code
	# The skin and hair colours the editor used to show first are still read.
	for hex in ["#8fd3f4", "#4fb35f", "#f2cd37", "#c4281c", "#6c3fb5"]:
		var design := CharacterDesign.from_dict({"head": {"style": "smile", "color": hex}, "hair": {"style": "spiky", "color": hex}})
		driver_ok = driver_ok and design.color_of("head") == Color(hex) and design.color_of("hair") == Color(hex)
	check(driver_ok, "old driver colours, bright skin and hair too, load the same")
	var stock := CharacterDesign.load_file("%s/%s.json" % [Game.ROSTER, Game.stock_driver_keys()[0]])
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [Game.ROSTER, Game.stock_driver_keys()[0]]))
	check(Paints.code(stock.color_of("torso")) == str(raw.torso.color).to_lower(), "a stock driver keeps its torso colour")


func _new_colours() -> void:
	print("-- Any colour")
	var odd := "#12ab9e"
	var kart := KartDesign.from_dict(_kart(odd))
	var file: Dictionary = JSON.parse_string(JSON.stringify(kart.to_dict()))
	check(KartDesign.from_dict(file).parts[0].color == Color(odd), "a kart colour off every palette survives saving and loading")
	var code := Sharing.code_for(Sharing.envelope_for(Sharing.KART, kart.to_dict()))
	var found := Sharing.read(code)
	check(found.get("kind") == Sharing.KART and found.data.parts[0].get("color") == odd, "and a share code")
	var more := Paints.more()
	check(more.size() >= 36 and more.size() <= 45 and more.size() % Paints.MORE_COLUMNS == 0, "More colours has %d colours in full rows" % more.size())
	var driver := CharacterDesign.from_dict({"head": {"style": "smile", "color": Paints.MORE[7]}, "torso": {"style": "racing_suit", "color": odd}})
	var driver_back := CharacterDesign.from_dict(JSON.parse_string(JSON.stringify(driver.to_dict())))
	check(driver_back.color_of("torso") == Color(odd) and driver_back.color_of("head") == Color(Paints.MORE[7]), "a driver's colours survive saving and loading")
	var driver_found := Sharing.read(Sharing.code_for(Sharing.envelope_for(Sharing.DRIVER, driver.to_dict())))
	check(driver_found.get("kind") == Sharing.DRIVER and driver_found.data.torso.color == odd, "and a share code")
	check(CharacterDesign.well_formed(driver.to_dict()), "and is fine to send online")


func _bad_colours() -> void:
	print("-- Bad colours")
	for bad in ["purple-ish", 42, null, ["#ffffff"], "", "#12345"]:
		var kart := KartDesign.from_dict(_kart(bad))
		check(kart.parts.size() == 1 and not kart.parts[0].has("color"), "a kart colour of %s leaves the part its own colour" % [bad])
	var driver := CharacterDesign.from_dict({"head": {"style": "smile", "color": "nope"}, "torso": {"style": "racing_suit", "color": 7}})
	check(driver.color_of("head") == Color("#f2cd37") and driver.color_of("torso") == Color("#f2cd37"), "a bad driver colour falls back to stock yellow")
	check(Sharing.read(Sharing.code_for(Sharing.envelope_for(Sharing.KART, _kart("nope")))).has("why"), "a share code with a bad colour is turned away")
	check(not CharacterDesign.well_formed({"torso": {"style": "racing_suit", "color": "nope"}}), "and so is a driver online")
	check(Paints.read("#ff000080") != null and Paints.read("#ff000080").a < 1.0, "a colour with see-through still reads")


func _recent() -> void:
	print("-- Recent")
	var list: Array = []
	for hex in ["#111111", "#222222", "#333333"]:
		list = Paints.with_recent(list, Color(hex))
	check(list == ["#333333", "#222222", "#111111"], "newest first")
	list = Paints.with_recent(list, Color("#111111"))
	check(list == ["#111111", "#333333", "#222222"], "a colour used again moves to the front, not in twice")
	for hex in ["#444444", "#555555", "#666666", "#777777"]:
		list = Paints.with_recent(list, Color(hex))
	check(list.size() == 6 and list[0] == "#777777" and list[5] == "#333333", "at most 6, the oldest drops off")
	check(Paints.with_recent(["junk", 5, "#abcdef", "#ABCDEF"], Color("#010101")) == ["#010101", "#abcdef"], "junk in the settings is left out")
	Game.set_setting("paint", "recent", "not a list")
	check(ColourPalette.recent_colours().is_empty(), "settings that aren't a list mean no Recent")
	Game.set_setting("paint", "recent", [])
	ColourPalette.remember(Color("#c4281c"))
	ColourPalette.remember(Color("#0d69ab"))
	ColourPalette.remember(Color("#c4281c"))
	var recent := ColourPalette.recent_colours()
	check(recent.size() == 2 and recent[0] == Color("#c4281c") and recent[1] == Color("#0d69ab"), "Recent is saved in the settings")


func _palettes() -> void:
	print("-- Palettes")
	Game.set_setting("paint", "recent", [])
	var palette := ColourPalette.new()
	add_child(palette)
	var main: Array[Color] = [Color("#c4281c"), Color("#0d69ab")]
	palette.show_colours(main, 8, main[0])
	await get_tree().process_frame
	check(not palette._recent_row.visible, "Recent is hidden while it's empty")
	var got: Array = []
	palette.picked.connect(func(colour: Color) -> void: got.append(colour))
	palette.open_more()
	check(palette.more_open(), "More colours opens")
	var pick: Button = palette._more_grid.get_child(13)
	pick.pressed.emit()
	await get_tree().process_frame
	check(got == [Color(Paints.MORE[13])], "picking in More colours picks that colour")
	check(not palette.more_open(), "and closes the grid")
	check(palette._recent_row.visible and palette._recent[0].visible and palette._recent[0].get_meta("colour") == Color(Paints.MORE[13]) and not palette._recent[1].visible, "and puts it in Recent")
	palette._grid.get_child(1).pressed.emit()
	check(got.back() == main[1] and palette._recent[0].get_meta("colour") == main[1] and palette._recent[1].get_meta("colour") == Color(Paints.MORE[13]), "a main colour goes first in Recent")
	palette._recent[1].pressed.emit()
	check(got.back() == Color(Paints.MORE[13]), "a Recent colour can be picked again")
	palette.open_more()
	palette.close_more()
	check(not palette.more_open(), "More colours closes without a pick")
	palette.queue_free()
	var skin := CharacterDesign.colours_for("head")
	var hair := CharacterDesign.colours_for("hair")
	check(skin.size() >= 10 and skin.size() <= 14 and not skin.has(Color("#8fd3f4")) and not skin.has(Color("#4fb35f")), "the driver screen shows %d skin tones, the bright ones under More" % skin.size())
	check(hair.size() >= 10 and not hair.has(Color("#d86cb0")) and not hair.has(Color("#0d69ab")), "and %d natural hair shades" % hair.size())
	var bright_ok := true
	for hex in ["#8fd3f4", "#4fb35f", "#c4281c", "#e36a1a", "#0d69ab", "#d86cb0", "#6c3fb5", "#f2cd37"]:
		bright_ok = bright_ok and hex in Paints.MORE
	check(bright_ok, "the bright skin and hair colours that left are in More colours")
	Game.set_setting("paint", "recent", [])
