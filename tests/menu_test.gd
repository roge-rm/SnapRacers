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
	check(labels == ["Race", "Garage", "Driver", "Multiplayer", "Settings", "About"], "the menu has its buttons %s" % [labels])
	check(buttons[3].disabled, "multiplayer isn't open yet")

	Game.show_settings()
	await frames(2)
	check(screen() is SettingsScreen, "settings opens")
	var back := screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Back")
	check(back.size() == 1, "settings has a Back button")
	Game.set_setting("player", "name", "Tester")
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "back from settings goes to the menu")

	Game.show_garage()
	await frames(2)
	var garage: Garage = screen()
	garage._start_holding("brick_2x2")
	Game._go_back()
	await frames(1)
	check(screen() is Garage and garage._holding == "", "back in the garage puts the part down first")
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "and then goes to the menu")

	Game.show_tracks()
	await frames(2)
	check(screen() is TrackPicker, "race opens the track list")
	var tracks := screen().find_children("*", "Button", true, false).filter(func(b): return b.text != "Back")
	var names := tracks.map(func(b): return b.text.get_slice("\n", 0))
	check(names == ["Brickyard", "Loopworks"], "with every track on it %s" % [names])
	print("    " + " / ".join(tracks.map(func(b): return b.text.replace("\n", ": "))))
	tracks[1].pressed.emit()
	await frames(4)
	check(screen() is Race, "picking one starts a race")
	check(screen().track.name == "Loopworks", "on that track (%s)" % screen().track.name)
	var race: Race = screen()
	check(race.player.name == "Tester", "and uses the name from settings (%s)" % race.player.name)
	await frames(12)
	check(Game._loading == null, "the loading screen goes once the race is drawing")
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "back from a race goes to the menu")

	Game.set_setting("player", "name", saved_name)
	print("All menu checks passed." if failures == 0 else "%d menu checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
