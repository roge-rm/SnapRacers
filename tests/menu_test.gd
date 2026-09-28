extends Node

## Starts the game the way it really starts, splash and all, and walks
## through the menus.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/menu_test.tscn

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func screen() -> Node:
	for i in range(host.get_child_count() - 1, -1, -1):
		var child := host.get_child(i)
		if not child.is_queued_for_deletion():
			return child
	return null


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	host = Node.new()
	add_child(host)
	var saved_name = Game.settings.get_value("player", "name", "")
	var saved_split = Game.settings.get_value("race", "split", Game.SOLO)
	var saved_second = Game.settings.get_value("race", "player_two", "brickley")
	Game.start(host)
	check(screen() is SplashScreen, "the game opens on the splash")
	await frames(3)
	check(screen().find_children("*", "Race", true, false).size() == 1, "the splash is warming up a race behind itself")
	var waited := 0
	while not (screen() is MainMenu) and waited < 600:
		await frames(1)
		waited += 1
	check(screen() is MainMenu, "then it moves on to the menu (%d frames)" % waited)

	var buttons := screen().find_children("*", "Button", true, false)
	var labels := buttons.map(func(b): return b.text.get_slice("\n", 0))
	check(labels == ["Single player", "Multiplayer", "Garage", "Driver", "Settings", "About", "Quit"], "the menu has its buttons %s" % [labels])

	Game.show_settings()
	await frames(2)
	check(screen() is SettingsScreen, "settings opens")
	var back := screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Back")
	check(back.size() == 2, "settings has a Back button at the top and the bottom")
	Game.set_setting("player", "name", "Tester")
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "back from settings goes to the menu")

	Game.show_garage()
	await frames(2)
	var garage: Garage = screen()
	garage.start_placing("brick_2x2")
	Game._go_back()
	await frames(1)
	check(screen() is Garage and garage._holding == "", "back in the garage puts the part down first")
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "and then goes to the menu")

	await _driver()

	Game.show_single_player()
	await frames(2)
	check(screen() is SinglePlayerMenu, "single player opens")
	var picks := screen().find_children("*", "Button", true, false).filter(func(b): return b.text != "Back")
	var labels2 := picks.map(func(b): return b.text.get_slice("\n", 0))
	check(labels2 == ["Grand Prix", "Time trial", "Practice"], "with a Grand Prix, time trials and practice %s" % [labels2])
	picks[2].pressed.emit()
	await frames(2)
	check(screen() is TrackPicker, "practice opens the course list")
	var tracks := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("track"))
	check(tracks.size() == 16, "with all 16 courses on it (%d)" % tracks.size())
	print("    " + " / ".join(tracks.map(func(b): return b.text.get_slice("\n", 0))))
	tracks[13].pressed.emit()
	await frames(2)
	check(screen() is KartPicker, "picking one asks which kart to race in")
	var cards := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("kart"))
	check(cards.size() == 17, "your own and all 16 stock karts (%d)" % cards.size())
	var was_choice := Game.kart_choice()
	cards.filter(func(b): return b.get_meta("kart") == "rocket")[0].pressed.emit()
	check(Game.kart_choice() == "rocket", "tapping one picks it")
	screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Race")[0].pressed.emit()
	await frames(4)
	check(screen() is Race, "Race starts a practice session")
	var race: Race = screen()
	check(race.player.kart.design.name == "Rocket", "in the kart you picked (%s)" % race.player.kart.design.name)
	Game.set_kart_choice(was_choice)
	check(race.mode == Game.MODE_PRACTICE and race.racers.size() == 1, "on your own (%d karts)" % race.racers.size())
	check(race.track.name == "Launchpad Loop", "on that course (%s)" % race.track.name)
	check(race.player.name == "Tester", "and uses the name from settings (%s)" % race.player.name)
	await frames(12)
	check(Game._loading == null, "the loading screen goes once the race is drawing")
	Game._go_back()
	await frames(2)
	check(screen() is TrackPicker, "back from practice goes to the course list")
	Game._go_back()
	await frames(2)
	check(screen() is SinglePlayerMenu, "and then back to single player")
	screen().find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Grand Prix"))[0].pressed.emit()
	await frames(2)
	check(screen() is CupPicker, "Grand Prix opens the cups")
	var cups := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("cup"))
	check(cups.size() == 4, "and there are four (%s)" % [cups.map(func(b): return b.text.get_slice("\n", 0))])
	var was_level := Game.difficulty()
	cups[0].pressed.emit()
	await frames(2)
	var levels := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("level"))
	check(screen() is KartPicker and levels.size() == 4, "a cup asks for a kart and how good the AI should be")
	levels.filter(func(b): return b.get_meta("level") == "hard")[0].pressed.emit()
	check(Game.difficulty() == "hard", "tapping a level picks it")
	Game.set_difficulty(was_level)
	Game._go_back()
	await frames(2)
	Game._go_back()
	await frames(2)
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "back twice goes to the menu")

	Game.show_multiplayer()
	await frames(2)
	check(screen() is MultiplayerMenu, "multiplayer opens")
	var layouts := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("mode"))
	check(layouts.size() == 2, "with side by side and face to face")
	var second: Button = screen()._second
	layouts[1].pressed.emit()
	check(Game.split() == Game.FACE_TO_FACE, "picking face to face remembers it")
	var was := Game.player_two_kart()
	second.pressed.emit()
	check(Game.player_two_kart() != was, "tapping player 2's kart moves them on to another (%s)" % Game.player_two_kart())
	screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Pick a course")[0].pressed.emit()
	await frames(2)
	check(screen() is TrackPicker and screen().mode == Game.MODE_RACE, "pick a course opens the course list for a race")
	Game._go_back()
	await frames(2)
	check(screen() is MultiplayerMenu, "and back goes to multiplayer")
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "and back again to the menu")

	Game.set_setting("player", "name", saved_name)
	Game.set_setting("race", "split", saved_split)
	Game.set_setting("race", "player_two", saved_second)
	print("All menu checks passed." if failures == 0 else "%d menu checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The driver screen: picking styles and colours, undo and redo, and leaving.
func _driver() -> void:
	var kept := Game.character.duplicate_design()
	Game.show_driver()
	await frames(2)
	var builder: DriverBuilder = screen()
	check(builder is DriverBuilder, "the driver screen opens")
	var ui := builder.ui
	var tiles := ui.find_children("*", "Button", true, false).filter(func(b): return b is DriverUI.DriverTile)
	check(tiles.size() == CharacterDesign.styles("head").size(), "the drawer starts on the heads, one tile each (%d)" % tiles.size())
	ui.show_slot("headgear")
	await frames(1)
	var hat := "top_hat" if builder.design.style_of("headgear") != "top_hat" else "cap"
	var before := builder.design.style_of("headgear")
	ui.style_chosen.emit("headgear", hat)
	check(builder.design.style_of("headgear") == hat and Game.character.style_of("headgear") == hat, "tapping a tile puts it on, and it's kept")
	var blue := Color(CharacterDesign.palette()[3])
	ui.colour_chosen.emit("headgear", blue)
	check(builder.design.color_of("headgear").is_equal_approx(blue), "tapping a colour paints it")
	ui.undo_pressed.emit()
	ui.undo_pressed.emit()
	check(builder.design.style_of("headgear") == before, "undo takes both back")
	ui.redo_pressed.emit()
	check(builder.design.style_of("headgear") == hat, "and redo puts the hat back")
	ui.name_changed.emit("Tester")
	ui.random_pressed.emit()
	check(builder.design.name == "Tester", "a random driver keeps their name")
	ui.pose_toggled.emit(true)
	await frames(2)
	check(builder._wheel != null, "sitting shows them at a steering wheel")
	ui.done_pressed.emit()
	await frames(2)
	check(screen() is MainMenu, "Done goes back to the menu")
	Game.keep_character(kept)
