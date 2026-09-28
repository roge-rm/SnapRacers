extends Node

## Looks after what carries from one screen to the next (your kart and your
## settings) and swaps between the screens.
##
## The game opens on a splash screen, which gets the shaders ready, and then
## the main menu. The phone's back button (or Esc) asks the current screen to
## go back, and a screen that doesn't say otherwise goes back to the menu.

const STARTER := "res://data/karts/starter.json"
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
var track_path := TRACKS + "/brickyard.json"

var _host: Node
var _screen: Node
var _loading: CanvasLayer
var _loading_since := 0


func _ready() -> void:
	settings.load(SETTINGS)
	if FileAccess.file_exists(CURRENT_KART):
		design = KartDesign.load_file(CURRENT_KART)
	if design == null or design.parts.is_empty():
		design = KartDesign.load_file(STARTER)
	character = CharacterDesign.load_file(CURRENT_DRIVER if FileAccess.file_exists(CURRENT_DRIVER) else ROSTER + "/racer.json")
	theme = Theme.new()
	theme.default_font_size = 22


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


func show_tracks() -> void:
	_swap(TrackPicker.new())


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
	# A kart that can't race (say one saved before steering wheels were
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


func show_fps() -> bool:
	return settings.get_value("display", "show_fps", false)


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
	_host.add_child(next)


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
