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
var _loading: CanvasLayer
var _loading_since := 0
var _portrait := false


func _ready() -> void:
	settings.load(SETTINGS)
	if FileAccess.file_exists(CURRENT_KART):
		design = KartDesign.load_file(CURRENT_KART)
	if design == null or design.parts.is_empty():
		design = KartDesign.load_file(STARTER)
	character = CharacterDesign.load_file(CURRENT_DRIVER if FileAccess.file_exists(CURRENT_DRIVER) else ROSTER + "/racer.json")
	theme = Theme.new()
	theme.default_font_size = 22
	Sounds.setup(volume(Sounds.MUSIC_BUS), volume(Sounds.EFFECTS_BUS))


## Starts the game in `host`. Tests skip the splash.
func start(host: Node, splash := true) -> void:
	_host = host
	if splash:
		_swap(SplashScreen.new())
	else:
		show_menu()


func show_menu() -> void:
	_swap(MainMenu.new())


func show_garage() -> void:
	_swap(Garage.new())


func show_drive() -> void:
	_swap(TestDrive.new())


func show_single_player() -> void:
	_swap(SinglePlayerMenu.new())


func show_multiplayer() -> void:
	_swap(MultiplayerMenu.new())


func show_cups() -> void:
	_swap(CupPicker.new())


## The course list for time trials, practice or a race against the AI,
## on your own or (from the Multiplayer menu) for two.
func show_tracks(for_mode := MODE_RACE, alone := false) -> void:
	_swap(TrackPicker.new(for_mode, alone))


## Pick a kart, then `go` starts the race. Back goes to `back`. With `ai`,
## it's a race against the AI and you pick how good they are too.
func show_kart_picker(go: Callable, back: Callable, ai := false) -> void:
	_swap(KartPicker.new(go, back, ai))


func start_grand_prix(cup_id: String) -> void:
	mode = MODE_GRAND_PRIX
	grand_prix = GrandPrix.new(cup_id)
	# Everyone keeps the same kart for the whole cup.
	grand_prix.karts = draw_karts(ai_driver_keys())
	grand_prix.ranks = draw_ranks(ai_driver_keys())
	grand_prix.player_kart = kart_choice()
	grand_prix.difficulty = difficulty()
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
	# A kart that can't race (like one saved before steering wheels were
	# needed) goes to the garage instead, which lists what's missing.
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


## Which stock kart player 2 drives, by its file name.
func player_two_kart() -> String:
	var key: String = settings.get_value("race", "player_two", "sparky")
	return key if stock_keys().has(key) else "sparky"


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
