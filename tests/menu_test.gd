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
	check(labels == ["Single player", "Multiplayer", "Editors", "Settings", "About", "Quit"], "the menu has its buttons %s" % [labels])
	# The garage, the driver screen and the track editor are all under Editors.
	buttons.filter(func(b): return b.text.begins_with("Editors"))[0].pressed.emit()
	await frames(2)
	check(screen() is EditorsMenu, "Editors opens its own menu")
	labels = screen().find_children("*", "Button", true, false).map(func(b): return b.text.get_slice("\n", 0))
	check(labels == ["Garage", "Driver", "Track editor", "Back"], "with the editors in it %s" % [labels])
	Game._go_back()
	await frames(2)
	check(screen() is MainMenu, "and back goes to the menu")

	Game.show_settings()
	await frames(2)
	check(screen() is SettingsScreen, "settings opens")
	var back := screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Back" and not b is ScrollButton)
	check(back.size() == 2, "settings has a Back button at the top and the bottom")
	# Steering with buttons instead of the stick, picked in Settings.
	var saved_steering := Game.steering(0)
	var buttons_pill := screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Buttons")
	check(buttons_pill.size() == 2, "settings has a steering choice for each player")
	buttons_pill[0].pressed.emit()
	check(Game.steering(0) == "buttons", "picking Buttons for player 1 keeps it")
	await _controls_page()
	var touch := TouchControls.new()
	touch.steering = Game.steering(0)
	add_child(touch)
	touch.size = Vector2(2340, 1080)
	var spots := touch._buttons()
	check(spots.has("left") and spots.has("right"), "then there are left and right buttons")
	touch._input(_touch(0, spots.left[0], true))
	check(touch.steer == -1.0, "holding left steers all the way left")
	touch._input(_drag(0, spots.right[0]))
	check(touch.steer == 1.0, "sliding across to right steers all the way right")
	touch._input(_touch(0, spots.right[0], false))
	check(touch.steer == 0.0, "and letting go straightens up")
	# GO and brake halfway up the right side, with the brake right under GO,
	# and a slide from GO onto a gadget uses it without letting go of GO.
	touch.gadget_names = ["Turbo", ""]
	spots = touch._buttons()
	check(spots.gas[0].y < touch.size.y * 0.7 and spots.gas[0].y > touch.size.y * 0.5, "GO sits two fifths of the way up (%d of %d)" % [spots.gas[0].y, touch.size.y])
	check(is_equal_approx(spots.brake[0].x, spots.gas[0].x) and spots.brake[0].y > spots.gas[0].y, "with the brake right under it")
	check(spots.gadget0[0].y < spots.gas[0].y and spots.gadget0[0].x < spots.gas[0].x, "and the gadget up and to its left")
	touch._input(_touch(1, spots.gas[0], true))
	touch._input(_drag(1, spots.gadget0[0]))
	check(touch.take_gadget_tap(0), "sliding from GO onto the gadget uses it")
	check(touch.throttle == 1.0, "while GO stays held")
	touch._input(_drag(1, spots.gadget0[0] + Vector2(3, 3)))
	check(not touch.take_gadget_tap(0), "and only once while the thumb stays on it")
	touch._input(_touch(1, spots.gadget0[0], false))
	check(touch.throttle == 0.0, "letting go lets go of GO")
	# On a whole phone screen, half of one side by side, and half of one face
	# to face (which is portrait), nothing overlaps or runs off the edge.
	touch.gadget_names = ["Turbo", "Magnet"]
	for how in ["buttons", "stick"]:
		touch.steering = how
		for layout in [[Vector2(2340, 1080), TouchControls.HEIGHT], [Vector2(1170, 1080), TouchControls.HEIGHT_SPLIT], [Vector2(1080, 1170), TouchControls.HEIGHT_SPLIT]]:
			touch.size = layout[0]
			touch.height = layout[1]
			var all := touch._buttons()
			if touch.steering == "stick":
				all.stick = touch._stick()
			var clashes := []
			for a in all:
				var c: Vector2 = all[a][0]
				var r: float = all[a][1]
				if c.x - r < 0.0 or c.y - r < 0.0 or c.x + r > touch.size.x or c.y + r > touch.size.y:
					clashes.append("%s off the edge" % a)
				for b in all:
					if str(a) < str(b) and c.distance_to(all[b][0]) < r + all[b][1]:
						clashes.append("%s on %s" % [a, b])
			check(clashes.is_empty(), "the controls fit on a %dx%d screen, steering with %s %s" % [touch.size.x, touch.size.y, how, clashes])
	touch.size = Vector2(2340, 1080)
	touch.height = TouchControls.HEIGHT
	touch.gadget_names = ["", ""]
	touch.steering = "stick"
	check(not touch._buttons().has("left"), "with the stick there are no steering buttons")
	touch.queue_free()
	Game.set_steering(0, saved_steering)
	await _camera_holes()

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
	check(screen() is EditorsMenu, "and then goes to the editors")

	await _driver()

	Game.show_single_player()
	await frames(2)
	check(screen() is SinglePlayerMenu, "single player opens")
	var picks := screen().find_children("*", "Button", true, false).filter(func(b): return b.text != "Back")
	var labels2 := picks.map(func(b): return b.text.get_slice("\n", 0))
	check(labels2 == ["Grand Prix", "Single race", "Time trial", "Practice"], "with a Grand Prix, a single race, time trials and practice %s" % [labels2])
	picks[3].pressed.emit()
	await frames(2)
	check(screen() is CupGrid and screen().mode == Game.MODE_PRACTICE, "practice opens the cups")
	var cup_cards := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("cup"))
	check(cup_cards.size() == GrandPrix.cups().size(), "with every cup on it (%d)" % cup_cards.size())
	cup_cards.filter(func(b): return b.get_meta("cup") == "keystone")[0].pressed.emit()
	await frames(2)
	check(screen() is CourseGrid and screen().cup == "keystone", "a cup opens its courses")
	var tracks := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("track"))
	check(tracks.size() == 4, "all four of them (%d)" % tracks.size())
	tracks.filter(func(b): return b.get_meta("track") == Tracks.path_of("launchpad_loop"))[0].pressed.emit()
	await frames(2)
	check(screen() is KartPicker, "picking one asks which kart to race in")
	var cards := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("kart"))
	check(cards.size() == Game.stock_keys().size() + 1, "your own and all the stock karts (%d)" % cards.size())
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
	check(screen() is Race and race.menu_open(race.player) and get_tree().paused, "back in a race opens the menu and pauses")
	race._menus[race.player].quit_pressed.emit()
	await frames(2)
	check(screen() is CourseGrid and screen().cup == "keystone" and not get_tree().paused, "and quitting from it goes back to that cup's courses")
	Game._go_back()
	await frames(2)
	check(screen() is CupGrid, "and then back to the cups")
	Game._go_back()
	await frames(2)
	check(screen() is SinglePlayerMenu, "and then back to single player")
	screen().find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Grand Prix"))[0].pressed.emit()
	await frames(2)
	check(screen() is CupGrid and screen().mode == Game.MODE_GRAND_PRIX, "Grand Prix opens the cups")
	var cups := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("cup"))
	check(cups.size() == GrandPrix.cups().size(), "and they're all there (%s)" % [cups.map(func(b): return b.text.get_slice("\n", 0))])
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
	layouts[1].pressed.emit()
	check(Game.split() == Game.FACE_TO_FACE, "picking face to face remembers it")
	screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Pick a course")[0].pressed.emit()
	await frames(2)
	check(screen() is CupGrid and screen().mode == Game.MODE_RACE and not screen().alone, "pick a course opens the cups for a race")
	# Each player picks a kart in turn, player 1 first.
	screen().find_children("*", "Button", true, false).filter(func(b): return b.get_meta("cup", "") == "baseplate")[0].pressed.emit()
	await frames(2)
	screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("track"))[0].pressed.emit()
	await frames(2)
	var picker := screen() as KartPicker
	check(picker != null and picker.player == 1, "picking a course asks player 1 for a kart first")
	var tagged := picker.find_children("*", "Label", true, false).any(func(l): return l.text == "PLAYER 1")
	check(tagged, "with a tag saying it's player 1")
	check(picker._name != null and picker._name.text == Game.player_one_name(), "and player 1's name, filled in (%s)" % (picker._name.text if picker._name != null else "none"))
	var was_one := Game.kart_choice()
	picker.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("kart", "") == "rocket")[0].pressed.emit()
	picker.find_children("*", "Button", true, false).filter(func(b): return b.text == "Next")[0].pressed.emit()
	await frames(2)
	picker = screen() as KartPicker
	check(picker != null and picker.player == 2, "then player 2")
	check(picker.find_children("*", "Label", true, false).any(func(l): return l.text == "PLAYER 2"), "with a tag saying it's player 2")
	picker.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("kart", "") == "dirt_bike")[0].pressed.emit()
	check(Game.player_two_kart() == "dirt_bike" and Game.kart_choice() == "rocket", "and each keeps their own kart (%s and %s)" % [Game.kart_choice(), Game.player_two_kart()])
	var was_two_name = Game.settings.get_value("player", "name_two", "")
	picker._name.text = "Gina"
	picker._name.text_changed.emit("Gina")
	check(Game.player_two_name() == "Gina", "player 2 can give their name")
	Game._go_back()
	await frames(2)
	check(screen() is KartPicker and screen().player == 1, "back from player 2 goes to player 1")
	Game.set_kart_choice(was_one)
	Game.set_setting("player", "name_two", was_two_name)
	Game.show_multiplayer()
	await frames(2)
	screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Pick a course")[0].pressed.emit()
	await frames(2)
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


## Nothing on a menu page or the driving controls sits under a camera hole,
## wherever it is, and the driving controls don't end up on top of each other
## getting out of its way.
func _camera_holes() -> void:
	var window := SafeArea.screen_size(get_viewport())
	var across := window.y * 0.1
	var spots := {
		"top left": Vector2(0.0, 0.0), "bottom left": Vector2(0.0, window.y - across),
		"top right": Vector2(window.x - across, 0.0), "bottom right": Vector2(window.x - across, window.y - across),
		"partway down the left": Vector2(0.0, window.y * 0.45), "partway down the right": Vector2(window.x - across, window.y * 0.45),
	}
	var page: Control = screen()
	var safe: SafeArea = page.find_children("SafeArea", "SafeArea", false, false)[0]
	var title: Label = page.find_children("*", "Label", true, false).filter(func(l): return l.text == "Settings")[0]
	var back: Button = page.find_children("*", "Button", true, false).filter(func(b): return b.text == "Back")[0]
	var touch := TouchControls.new()
	add_child(touch)
	touch.gadget_names = ["Turbo", "Shield"]
	await frames(2)
	for spot in spots:
		SafeArea.pretend = [Rect2(spots[spot], Vector2(across, across))]
		safe.refit()
		await frames(4)
		var hole: Rect2 = SafeArea.holes_in(get_viewport())[0]
		check(not title.get_global_rect().intersects(hole) and not back.get_global_rect().intersects(hole), "with a camera hole %s, a menu page's title and Back are clear of it" % spot)
		touch._holes = SafeArea.holes_in(get_viewport())
		for how in TouchControls.STEERING:
			touch.steering = how
			var circles := touch._buttons()
			if how == "stick":
				circles["stick"] = touch._stick()
			var trouble := []
			for n in circles:
				var c: Vector2 = circles[n][0]
				var r: float = circles[n][1]
				if c.distance_to(c.clamp(hole.position, hole.end)) < r - 0.5:
					trouble.append("%s under it" % n)
				if c.x - r < -0.5 or c.y - r < -0.5 or c.x + r > touch.size.x + 0.5 or c.y + r > touch.size.y + 0.5:
					trouble.append("%s off the screen" % n)
				for m in circles:
					if m > n and c.distance_to(circles[m][0]) < r + circles[m][1] - 0.5:
						trouble.append("%s on %s" % [n, m])
			check(trouble.is_empty(), "and steering with the %s, the driving controls are clear of it too %s" % [how, trouble])
	SafeArea.pretend = []
	safe.refit()
	touch.queue_free()
	await frames(4)


func _touch(finger: int, at: Vector2, down: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = down
	return event


func _drag(finger: int, at: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	return event


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
	# Pressed the way a tap presses it, so the tile's own wiring is checked
	# too.
	var hat_tile: Button = ui.find_children("*", "Button", true, false).filter(func(b): return b is DriverUI.DriverTile and b.style == hat and not b.is_queued_for_deletion())[0]
	check(hat_tile.mouse_filter == Control.MOUSE_FILTER_PASS, "a tile lets a drag through to scroll the list")
	hat_tile.pressed.emit()
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
	check(screen() is EditorsMenu, "Done goes back to the editors")
	Game.keep_character(kept)


## Settings > Controls has whose controller is whose and every player's
## keys and buttons, which can be changed.
func _controls_page() -> void:
	var pages := screen().find_children("*", "ControlsPage", true, false)
	check(pages.size() == 1, "settings has the controllers and buttons")
	if pages.is_empty():
		return
	var page: ControlsPage = pages[0]
	var settings := Game.settings
	var had: Variant = settings.get_value("bindings", "player_2", null)
	page._person = 1
	page._wait(["key", "reset", 0])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	page._input(key)
	check(InputBindings.key(settings, 1, "reset") == KEY_G and page._waiting.is_empty(), "tapping player 2's reset and pressing G changes it")
	page._wait(["pad", "gadget_1", 0])
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	page._input(shoulder)
	check(InputBindings.pad(settings, 1, "gadget_1")[0] == [InputBindings.BUTTON, JOY_BUTTON_LEFT_SHOULDER, 1], "and power-up 1 can go on LB")
	check(InputBindings.pad(settings, 1, "look_back")[0] == [InputBindings.BUTTON, JOY_BUTTON_X, 1], "which gives look back the X it had, so nothing's lost")
	page._wait(["owner", "", 1])
	var press := InputEventJoypadButton.new()
	press.device = 30
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	page._input(press)
	check(Game.controllers.device_of(1) == 30, "pressing a button on a controller gives it to player 2")
	Game.controllers._on_connection(30, false)
	var reset := screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Put back how they were")
	check(reset.size() == 1, "and there's a way to put them back")
	if not reset.is_empty():
		reset[0].pressed.emit()
	check(InputBindings.key(settings, 1, "reset") == KEY_ENTER, "which puts player 2 back how they were")
	if had == null:
		InputBindings.reset(settings, 1)
	else:
		settings.set_value("bindings", "player_2", had)
	Game.save_settings()
