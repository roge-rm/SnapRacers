extends Node

## Looks after what carries from one screen to the next (your kart and your
## settings) and swaps between the screens.
##
## The game opens on a splash screen, which gets the shaders ready, and then
## the main menu. The phone's back button (or Esc) asks the current screen to
## go back, and a screen that doesn't say otherwise goes back to the menu.

## The stock karts, which the AI drives and anyone can pick.
const STOCK := "res://data/karts/stock"
const STARTER := STOCK + "/starter.json"
## The kart you were last working on, kept between launches.
const CURRENT_KART := "user://current_kart.json"
## The driver you last built, kept between launches too.
const CURRENT_DRIVER := "user://current_driver.json"
const ROSTER := "res://data/characters/roster"
const SETTINGS := "user://settings.cfg"
const TRACKS := "res://data/tracks"

var design: KartDesign
var character: CharacterDesign
## The theme for in-game panels (the garage and the race HUD).
var theme: Theme
var settings := ConfigFile.new()
## The track the next race is on. Race again keeps it.
var track_path := TRACKS + "/peach_pit.json"

## What kind of race the next one is.
const MODE_RACE := "race" # against the AI, one or two players (see split())
const MODE_GRAND_PRIX := "grand_prix"
const MODE_TIME_TRIAL := "time_trial"
const MODE_PRACTICE := "practice"
var mode := MODE_RACE
## The cup being raced, while there's a Grand Prix on.
var grand_prix: GrandPrix

## How the screen is shared in a race. SOLO is one player. SIDE_BY_SIDE is two
## players in landscape with half the screen each. FACE_TO_FACE is two players
## in portrait with the phone flat between them and the far player's half
## upside down.
const SOLO := ""
const SIDE_BY_SIDE := "side"
const FACE_TO_FACE := "face"
## What `kart_choice()` says when you're driving the kart from the garage.
const OWN_KART := "own"

var _host: Node
var _screen: Node
## Whether the race going on was started from the track editor, which is
## where leaving it goes back to.
var came_from_editor := false
## Whether a race against the AI is just you (a single race), rather than
## the two of you from the Multiplayer menu.
var racing_alone := false
## Whether the perflog switch has started its race (see show_menu()).
var _perf_started := false
## Racing with people on other devices (see NetSession).
var net: NetSession
## Which controller is whose (see Controllers).
var controllers: Controllers
## The Android network plugin, when there is one (see NetPlugin).
var plugin: NetPlugin
## Whether two people on this phone join an online game together.
var online_two := false
## The cup whose courses were picked from last, to come back to.
var cup_shown := ""
var _part_pictures: PartThumbnails
var _trophy_pictures: TrophyThumbnails
var _loading: CanvasLayer
var _loading_since := 0
var _portrait := false


func _ready() -> void:
	# Esc and Back still work while a race is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings.load(SETTINGS)
	if FileAccess.file_exists(CURRENT_KART):
		design = KartDesign.load_file(CURRENT_KART)
	if design == null or design.parts.is_empty():
		design = KartDesign.load_file(STARTER)
	character = CharacterDesign.load_file(CURRENT_DRIVER if FileAccess.file_exists(CURRENT_DRIVER) else ROSTER + "/racer.json")
	theme = Theme.new()
	theme.default_font_size = 22
	MenuStyle.add_switches(theme)
	Sounds.setup(volume(Sounds.MUSIC_BUS), volume(Sounds.EFFECTS_BUS))
	plugin = NetPlugin.new()
	add_child(plugin)
	# A on a controller presses buttons, like Enter. (B goes back, through
	# PadFocus.)
	var accept := InputEventJoypadButton.new()
	accept.device = -1
	accept.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept", accept):
		InputMap.action_add_event("ui_accept", accept)
	var focus := PadFocus.new()
	focus.screen = func() -> Node: return _screen
	focus.back = _go_back
	add_child(focus)
	controllers = Controllers.new()
	controllers.settings = settings
	controllers.changed.connect(save_settings)
	add_child(controllers)
	net = NetSession.new()
	add_child(net)
	# Wherever we are when an online game ends under us (the host left, say),
	# it's back to the online screen, which says why.
	net.ended.connect(func(_reason: String) -> void:
		grand_prix = null
		if not _screen is OnlineMenu:
			show_online())


## Starts as a dedicated server in `host`, with no screens of its own.
func start_server(host: Node) -> void:
	_host = host
	Sounds.hushed = true
	host.add_child(DedicatedServer.new())


## Starts the game in `host`. Tests skip the splash, and race on a clear day
## unless they pick otherwise, so they come out the same every time.
func start(host: Node, splash := true) -> void:
	_host = host
	part_pictures()
	if not splash:
		settings.set_value("race", "weather", "clear")
		settings.set_value("race", "time", "day")
		settings.set_value("display", "graphics", Graphics.DEFAULT)
	set_graphics(graphics())
	if splash:
		_swap(SplashScreen.new())
	else:
		show_menu()


## The pictures of the parts for the garage, taken once for the whole game.
func part_pictures() -> PartThumbnails:
	if _part_pictures == null:
		_part_pictures = PartThumbnails.new()
		add_child(_part_pictures)
	return _part_pictures


## The pictures of the cups' trophies, the same way.
func trophy_pictures() -> TrophyThumbnails:
	if _trophy_pictures == null:
		_trophy_pictures = TrophyThumbnails.new()
		add_child(_trophy_pictures)
	return _trophy_pictures


func show_menu() -> void:
	# A debug switch for timing races on a device. If there's a file called
	# perflog in the app's data folder, the game goes straight into a race on
	# the course and in the weather and time it names, like
	# "peach_pit rain night", the AI drives, and the race logs its frame rate
	# (see Race).
	if OS.is_debug_build() and FileAccess.file_exists("user://perflog") and not _perf_started:
		_perf_started = true
		var words := FileAccess.get_file_as_string("user://perflog").strip_edges().split(" ")
		settings.set_value("race", "split", SOLO)
		settings.set_value("race", "weather", words[1] if words.size() > 1 else Conditions.RANDOM)
		settings.set_value("race", "time", words[2] if words.size() > 2 else Conditions.RANDOM)
		racing_alone = true
		start_race(TRACKS + "/" + (words[0] if words.size() > 0 and words[0] != "" else "peach_pit") + ".json")
		return
	_swap(MainMenu.new())


## The garage, the driver screen and the track editor.
func show_editors() -> void:
	_swap(EditorsMenu.new())


func show_garage() -> void:
	_swap(Garage.new())


func show_drive() -> void:
	_swap(TestDrive.new())


func show_single_player() -> void:
	_swap(SinglePlayerMenu.new())


func show_multiplayer() -> void:
	_swap(MultiplayerMenu.new())


func show_cups() -> void:
	_swap(CupGrid.new(MODE_GRAND_PRIX))


## The cups you've made.
func show_your_cups() -> void:
	_swap(CupGrid.new(MODE_GRAND_PRIX, false, true))


## Hosting or joining a game over the network.
func show_online() -> void:
	_swap(OnlineMenu.new())


## The lobby of the online game we're in.
func show_lobby() -> void:
	_swap(Lobby.new())


## The points between the races of a cup raced online.
func show_net_standings() -> void:
	_swap(GrandPrixStandings.new(grand_prix))


## A race with nobody to show it to, for the dedicated server.
func show_server_race(path: String) -> void:
	track_path = path
	_swap(Race.new(SOLO))


## Make a cup of your own, or change the one in this file.
func show_cup_builder(path := "") -> void:
	_swap(CupBuilder.new(path))


## The cups, to pick a course from for time trials, practice or a race against
## the AI, on your own or (from the Multiplayer menu) for two. Coming back
## from a race goes back to the cup it was in.
func show_tracks(for_mode := MODE_RACE, alone := false, back_to_cup := false) -> void:
	if back_to_cup and cup_shown != "":
		show_course_grid(for_mode, alone, cup_shown)
	else:
		_swap(CupGrid.new(for_mode, alone))


## A cup's courses, or the ones you've built (CourseGrid.YOURS).
func show_course_grid(for_mode: String, alone: bool, cup: String) -> void:
	_swap(CourseGrid.new(for_mode, alone, cup))


## Pick a kart, then `go` starts the race. Back goes to `back`. With `ai`,
## it's a race against the AI and you pick how good they are too. With `two`,
## it's two on this phone: player 1 picks, then player 2 does, and back from
## player 2 goes to player 1 again.
func show_kart_picker(go: Callable, back: Callable, ai := false, two := false) -> void:
	if not two:
		_swap(KartPicker.new(go, back, ai))
		return
	var again := show_kart_picker.bind(go, back, ai, true)
	var second := func() -> void: _swap(KartPicker.new(go, again, false, 2))
	_swap(KartPicker.new(second, back, ai, 1))


## Starts a Grand Prix, of one of the game's cups by its id, or of a cup of
## your own (as CupDesign.to_cup() makes it).
func start_grand_prix(which: Variant) -> void:
	mode = MODE_GRAND_PRIX
	came_from_editor = false
	grand_prix = GrandPrix.new(which)
	# Everyone keeps the same kart for the whole cup.
	grand_prix.karts = draw_karts(ai_driver_keys())
	grand_prix.ranks = draw_ranks(ai_driver_keys())
	grand_prix.player_kart = kart_choice()
	grand_prix.difficulty = difficulty()
	grand_prix.weather = weather()
	grand_prix.time = time_of_day()
	show_race(grand_prix.track_path())


## Called when you move on from a Grand Prix race's results. `order` is
## everyone's names, winner first.
func finish_grand_prix_race(order: Array) -> void:
	grand_prix.add_results(order)
	_swap(GrandPrixStandings.new(grand_prix))


func next_grand_prix_race() -> void:
	show_race(grand_prix.track_path())


## Starts a time trial, practice or a race against the AI on this course.
## From the track editor, leaving the race goes back there.
func start_course(for_mode: String, path: String, from_editor := false) -> void:
	came_from_editor = from_editor
	if from_editor:
		racing_alone = true
	match for_mode:
		MODE_TIME_TRIAL:
			start_time_trial(path)
		MODE_PRACTICE:
			start_practice(path)
		_:
			start_race(path)


func start_time_trial(path: String) -> void:
	mode = MODE_TIME_TRIAL
	show_race(path)


func start_practice(path: String) -> void:
	mode = MODE_PRACTICE
	show_race(path)


func start_race(path: String) -> void:
	mode = MODE_RACE
	show_race(path)


## The track editor, with the course you were last working on.
func show_track_editor() -> void:
	came_from_editor = false
	_swap(TrackEditor.new())


func show_driver() -> void:
	_swap(DriverBuilder.new())


func show_settings() -> void:
	_swap(SettingsScreen.new())


func show_about() -> void:
	_swap(AboutScreen.new())


## The race can take a moment to appear (longer the first time, while shaders
## compile), so "Loading" goes up first and the race takes it down once it's
## on screen.
func show_race(path := "") -> void:
	if path != "":
		track_path = path
	# A kart that can't race goes to the garage instead, which lists what's
	# missing.
	if not design.problems().is_empty():
		show_garage()
		return
	show_loading(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_swap(Race.new())


## Keeps this as the kart you're working on, here and on disk.
func keep_design(new_design: KartDesign) -> void:
	design = new_design.duplicate_design()
	var file := FileAccess.open(CURRENT_KART, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(design.to_dict(), "\t"))


## Keeps this as your driver, here and on disk.
func keep_character(who: CharacterDesign) -> void:
	character = who.duplicate_design()
	var file := FileAccess.open(CURRENT_DRIVER, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(character.to_dict(), "\t"))


## The driver for one of the AI karts, by the kart's file name.
func roster_driver(key: String) -> CharacterDesign:
	var path := "%s/%s.json" % [ROSTER, key]
	return CharacterDesign.load_file(path) if FileAccess.file_exists(path) else Kart.default_driver()


func player_name() -> String:
	var name: String = settings.get_value("player", "name", "")
	return name if name.strip_edges() != "" else "You"


## Player 1's name with two on one phone, where "You" wouldn't say which.
func player_one_name() -> String:
	var name: String = str(settings.get_value("player", "name", "")).strip_edges()
	return name if name != "" else "Player 1"


## The name other people see online. "You" would only confuse them, so
## without a name set, it's the phone's.
func online_name() -> String:
	var name: String = settings.get_value("player", "name", "")
	if name.strip_edges() != "":
		return name
	var model := OS.get_model_name()
	return model if model != "" and model != "GenericDevice" else "A racer"


## What a game this phone hosts is called, in other people's lists.
func game_name() -> String:
	return "%s's game" % online_name()


## How the screen is shared in the next race (SOLO, SIDE_BY_SIDE or
## FACE_TO_FACE).
func split() -> String:
	var mode: String = settings.get_value("race", "split", SOLO)
	return mode if mode in [SOLO, SIDE_BY_SIDE, FACE_TO_FACE] else SOLO


func players() -> int:
	return 1 if split() == SOLO else 2


## How the screen is shared in the race about to start. Only races against the
## AI can be for two. Everything else is for one player.
func race_split() -> String:
	return split() if mode == MODE_RACE and not racing_alone else SOLO


## Which kart player 2 drives: a stock kart by its file name, or the one in
## the garage (OWN_KART).
func player_two_kart() -> String:
	var key: String = settings.get_value("race", "player_two", "sparky")
	if key == OWN_KART and design.problems().is_empty():
		return key
	return key if stock_keys().has(key) else "sparky"


func player_two_design() -> KartDesign:
	var key := player_two_kart()
	return design if key == OWN_KART else stock_kart(key)


## Player 2's name, for two on one phone. It's "Player 2" until they give
## one, or if it's the same as player 1's.
func player_two_name() -> String:
	var name := str(settings.get_value("player", "name_two", "")).strip_edges()
	return name if name != "" and name != player_name() else "Player 2"


## The stock karts' file names, without .json, in order.
func stock_keys() -> Array[String]:
	var keys: Array[String] = []
	for file in DirAccess.get_files_at(STOCK):
		if file.ends_with(".json"):
			keys.append(file.get_basename())
	keys.sort()
	return keys


func stock_kart(key: String) -> KartDesign:
	return KartDesign.load_file("%s/%s.json" % [STOCK, key])


## The AI drivers, by their file names in the roster. The Racer is yours.
func ai_driver_keys() -> Array[String]:
	var keys: Array[String] = []
	for file in DirAccess.get_files_at(ROSTER):
		if file.ends_with(".json") and file != "racer.json":
			keys.append(file.get_basename())
	keys.sort()
	return keys


## Deals a random stock kart to each of these drivers, as { driver: kart }.
## Nobody gets the same kart as anyone else while there are enough to go
## around, and nobody gets one in `leave_out` (like player 2's).
func draw_karts(drivers: Array, leave_out: Array = []) -> Dictionary:
	var deck: Array[String] = []
	var out := {}
	for driver in drivers:
		if deck.is_empty():
			deck = stock_keys().filter(func(k): return not leave_out.has(k))
			deck.shuffle()
		out[driver] = deck.pop_back()
	return out


## Shuffles the AI drivers' pecking order, as { driver: rank }, with 0 the
## quickest (see Difficulty). It's drawn fresh for every race, or once for a
## Grand Prix, so it isn't always the same driver making life hard.
func draw_ranks(drivers: Array) -> Dictionary:
	var order := drivers.duplicate()
	order.shuffle()
	var out := {}
	for i in order.size():
		out[order[i]] = i
	return out


## Which kart you race in: OWN_KART for the one from the garage, or a stock
## kart's key.
func kart_choice() -> String:
	var key: String = settings.get_value("race", "kart", OWN_KART)
	return key if key == OWN_KART or stock_keys().has(key) else OWN_KART


func set_kart_choice(key: String) -> void:
	set_setting("race", "kart", key)


## How good the AI drivers are in races and Grand Prix cups (see Difficulty).
func difficulty() -> String:
	var level: String = settings.get_value("race", "difficulty", Difficulty.DEFAULT)
	return level if Difficulty.LEVELS.has(level) else Difficulty.DEFAULT


func set_difficulty(level: String) -> void:
	set_setting("race", "difficulty", level)


## The weather and time of day picked for races, or Conditions.RANDOM to
## leave them to chance (see Conditions).
func weather() -> String:
	var pick: String = settings.get_value("race", "weather", Conditions.RANDOM)
	return pick if Conditions.WEATHERS.has(pick) else Conditions.RANDOM


func set_weather(pick: String) -> void:
	set_setting("race", "weather", pick)


func time_of_day() -> String:
	var pick: String = settings.get_value("race", "time", Conditions.RANDOM)
	return pick if Conditions.TIMES.has(pick) else Conditions.RANDOM


func set_time_of_day(pick: String) -> void:
	set_setting("race", "time", pick)


## How much the game draws, "low", "medium" or "high" (see Graphics).
func graphics() -> String:
	var level: String = settings.get_value("display", "graphics", Graphics.DEFAULT)
	return level if Graphics.LEVELS.has(level) else Graphics.DEFAULT


func set_graphics(level: String) -> void:
	set_setting("display", "graphics", level)
	Graphics.level = level
	if is_inside_tree():
		Graphics.apply_to(get_tree().root)


## How each person steers on a touch screen, "stick" or "buttons" (see
## TouchControls.STEERING), 0 for player 1.
func steering(person: int) -> String:
	return settings.get_value("controls", "player_%d" % (person + 1), "stick")


func set_steering(person: int, how: String) -> void:
	set_setting("controls", "player_%d" % (person + 1), how)


## The camera view each person last used (see RaceCamera), 0 for player 1.
func camera_view(person: int) -> String:
	return settings.get_value("camera", "player_%d" % (person + 1), "chase")


func set_camera_view(person: int, view: String) -> void:
	set_setting("camera", "player_%d" % (person + 1), view)


## How each person's map in the corner of a race shows (see CourseMap.MODES),
## 0 for player 1.
func map_view(person: int) -> String:
	return settings.get_value("map", "player_%d" % (person + 1), "outline")


func set_map_view(person: int, mode: String) -> void:
	set_setting("map", "player_%d" % (person + 1), mode)


## The kart you race in, from your choice. In a Grand Prix it's the one you
## started the cup with.
func chosen_design() -> KartDesign:
	var key := kart_choice()
	if mode == MODE_GRAND_PRIX and grand_prix != null and grand_prix.player_kart != "":
		key = grand_prix.player_kart
	return design if key == OWN_KART else stock_kart(key)


func show_fps() -> bool:
	return settings.get_value("display", "show_fps", false)


## The volume of the Music or Effects bus, 0 to 1.
func volume(bus: String) -> float:
	return settings.get_value("sound", bus.to_lower(), 0.8 if bus == Sounds.MUSIC_BUS else 1.0)


func set_volume(bus: String, value: float) -> void:
	set_setting("sound", bus.to_lower(), value)
	Sounds.set_volume(bus, value)


func set_setting(section: String, key: String, value: Variant) -> void:
	settings.set_value(section, key, value)
	settings.save(SETTINGS)


## Saves the settings after something's changed them, like new bindings.
func save_settings() -> void:
	settings.save(SETTINGS)


func show_loading(on: bool) -> void:
	if on and _loading == null:
		_loading_since = Time.get_ticks_msec()
		_loading = CanvasLayer.new()
		_loading.layer = 100
		var root := Control.new()
		root.theme = MenuStyle.theme()
		_loading.add_child(root)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var back := MenuStyle.backdrop()
		root.add_child(back)
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var label := Label.new()
		label.text = "Loading"
		label.add_theme_font_size_override("font_size", 40)
		root.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		add_child(_loading)
	elif not on and _loading != null:
		print("Loading took %d ms" % (Time.get_ticks_msec() - _loading_since))
		_loading.queue_free()
		_loading = null


func _swap(next: Node) -> void:
	# Nothing's paused on a new screen.
	get_tree().paused = false
	if _screen != null:
		_screen.queue_free()
	_screen = next
	# Each cup has its own race tune, and everywhere else plays the menu's.
	# The splash is quiet.
	if next is Race:
		Sounds.music(Sounds.race_tune(Tracks.id_of(track_path)))
	elif not next is SplashScreen:
		Sounds.music("menu")
	_set_portrait(next is Race and race_split() == FACE_TO_FACE)
	_host.add_child(next)
	# With a controller in hand, the new screen's first button is picked out.
	if not next is Race:
		PadFocus.focus_first.call_deferred(next)


## Face to face races are played in portrait. Everything else is landscape.
func _set_portrait(on: bool) -> void:
	if on == _portrait:
		return
	_portrait = on
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT if on else DisplayServer.SCREEN_SENSOR_LANDSCAPE)


func _go_back() -> void:
	if _screen != null and _screen.has_method("go_back"):
		_screen.go_back()
	else:
		show_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_go_back()
