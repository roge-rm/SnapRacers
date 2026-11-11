extends Node

## Retakes the main menu and the README's builder and kart-picker screens at
## 1280 x 720.
## Run with a separate XDG_DATA_HOME so editor autosaves stay in that profile:
##   xvfb-run -a -s '-screen 0 1280x720x24' tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --fixed-fps 60 --disable-render-loop res://tools/shots/menu_shots.tscn
## With `-- screens FOLDER WIDTH HEIGHT` it shoots every menu and popup
## instead, into FOLDER as <screen>-<width>x<height>.png. Set
## SNAPRACERS_CUTOUT for a pretend camera hole. It needs a real screen:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/menu_shots.tscn -- screens /srv/downloads/temp/debug/snapracers/ui-looks/m3 1280 720
const OUT := "res://build/shots/readme"
var host: Node
var _folder := ""
var _size := Vector2i(1280, 720)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 4 and args[0] == "screens":
		_folder = args[1]
		_size = Vector2i(int(args[2]), int(args[3]))
		await _screens(args.slice(4))
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(OUT)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	RaceWindow.forced_id = "windsurf_way"
	Game.design = Game.stock_kart("quarter_mile").duplicate_design()
	Game.character = Game.roster_driver("racer").duplicate_design()
	Game.settings.set_value("race", "kart", "quarter_mile")

	Game.show_menu()
	await screen_of(MainMenu)
	await ready_pictures()
	await shot("menu")

	Game.show_garage()
	var garage: Garage = await screen_of(Garage)
	garage.ui._show_category(2)
	await ready_pictures()
	await shot("garage")

	Game.show_kart_picker(Game.show_menu, Game.show_menu, true)
	var picker: KartPicker = await screen_of(KartPicker)
	await ready_pictures()
	var card: Control = picker._cards["night_shift"]
	for node in picker.find_children("*", "ScrollContainer", true, false):
		if node.is_ancestor_of(card):
			node.scroll_vertical = roundi(card.position.y)
	await get_tree().process_frame
	await shot("karts")

	Game.character = Game.roster_driver("brickley").duplicate_design()
	Game.show_driver()
	var driver: DriverBuilder = await screen_of(DriverBuilder)
	await ready_pictures()
	driver._last_touch = 0.0
	driver._turntable.rotation.y = PI + 0.25
	await shot("driver")

	Game.show_track_editor()
	var editor: TrackEditor = await screen_of(TrackEditor)
	editor.load_course(Tracks.path_of("pithead_park"))
	# Wait for the editor's full course build after loading.
	for i in 60:
		await get_tree().process_frame
	await ready_pictures()
	await shot("editor")
	host.queue_free()
	for i in 3:
		await get_tree().process_frame
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
	get_tree().quit()


func screen_of(kind: Variant) -> Node:
	for i in 120:
		await get_tree().process_frame
		for child in host.get_children():
			if is_instance_of(child, kind) and not child.is_queued_for_deletion():
				return child
	push_error("Screenshot screen did not open")
	get_tree().quit(1)
	return null


func ready_pictures() -> void:
	# Thumbnails need real render frames before their images reach the UI.
	for i in 180:
		await get_tree().process_frame
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
		var busy := false
		for node in get_tree().root.find_children("*", "", true, false):
			if node is PartThumbnails or node is KartThumbnails or node is DriverThumbnails:
				busy = busy or node.is_processing()
		if i >= 4 and not busy:
			return
	push_error("Screenshot thumbnails did not finish")
	get_tree().quit(1)


func shot(which: String) -> void:
	# One frame lays out the UI after the last thumbnail or scroll change.
	for i in 2:
		await get_tree().process_frame
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	# On a big screen the window can come out bigger than asked; the UI
	# scales with it, so a smaller copy looks the same as 1280 x 720.
	if picture.get_size() != Vector2i(1280, 720):
		if picture.get_width() * 9 != picture.get_height() * 16:
			push_error("Unexpected screenshot dimensions: %s" % picture.get_size())
			get_tree().quit(1)
			return
		picture.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	picture.save_png("%s/%s.png" % [OUT, which])
	print("saved ", which)


# ----------------------------------------------------------- every screen

## The picker for player two with the longest name a garage kart can have.
func _long_name_picker() -> void:
	Game.design.name = "Wwwwwwwwwwwwwwww"
	Game.show_kart_picker(Game.show_menu, Game.show_menu, true, true)


func _screens(only: Array) -> void:
	get_window().mode = Window.MODE_WINDOWED
	await frames(5)
	get_window().size = _size
	await frames(10)
	DirAccess.make_dir_recursive_absolute(_folder)
	host = Node.new()
	add_child(host)
	var want := func(which: String) -> bool: return only.is_empty() or only.has(which)
	# Made-up medals for the cups, kept apart from the real records.
	Records.use_file("user://shots_records.cfg")
	var places := [1, 2, 3, 1, 0, 2, 0, 3, 0, 1, 0, 0, 2, 0]
	var n := 0
	for cup in GrandPrix.cups():
		for level in Difficulty.LEVELS.slice(0, 1 + n % 4):
			if places[n % places.size()] > 0:
				Records.add_cup_place(cup.id, places[n % places.size()], level, false)
		n += 1
	Game.start(host)
	RaceWindow.forced_id = "windsurf_way"
	await frames(4)
	if want.call("splash"):
		await save("splash")
	while not host.get_children().any(func(c): return c is MainMenu):
		await frames(5)
	await ready_pictures()
	if want.call("menu"):
		await save("menu")
		var first: Control = host.get_child(-1).find_children("*", "BigButton", true, false)[0]
		first.grab_focus()
		await save("menu_focus")
	var screens := [
		["single_player", Game.show_single_player],
		["multiplayer", Game.show_multiplayer],
		["online", Game.show_online],
		["settings", Game.show_settings],
		["about", Game.show_about],
		["editors", Game.show_editors],
		["cups", Game.show_cups],
		["cups_two", Game.show_cups.bind(true)],
		["single_race", Game.show_tracks.bind(Game.MODE_RACE, true)],
		["your_cups", Game.show_your_cups],
		["courses", Game.show_course_grid.bind(Game.MODE_TIME_TRIAL, true, "gearbox")],
		["your_courses", Game.show_course_grid.bind(Game.MODE_RACE, true, CourseGrid.YOURS)],
		["cup_builder", Game.show_cup_builder.bind("")],
		["kart_picker", Game.show_kart_picker.bind(Game.show_menu, Game.show_menu, true)],
		["kart_picker_long", _long_name_picker],
	]
	for pair in screens:
		if not want.call(pair[0]):
			continue
		pair[1].call()
		await ready_pictures()
		await frames(40)
		await save(pair[0])
	if want.call("settings"):
		Game.show_settings()
		await frames(10)
		var page: SettingsScreen = host.get_child(-1)
		for i in page._tab_buttons.size():
			page._tab_buttons[i].pressed.emit()
			await frames(10)
			await save("settings_%d" % i)
	if want.call("standings"):
		var gp := GrandPrix.new("baseplate")
		gp.people = [Game.player_name()]
		var names := [Game.player_name(), "Brickley", "Rusty", "Pip", "Sparks", "Nova", "Bolt", "Dot"]
		gp.add_results(names)
		gp.add_results(names.slice(1) + names.slice(0, 1))
		Game.grand_prix = gp
		Game._swap(GrandPrixStandings.new(gp))
		await frames(20)
		await save("standings")
		Game.grand_prix = null
	if want.call("lobby"):
		var why := []
		var peer := Connections.host_enet(47991, why)
		if peer != null:
			Game.net.host(peer)
			Game.show_lobby()
			await frames(30)
			await save("lobby")
			Game.net.leave()
	if want.call("popups"):
		Game.show_your_cups()
		await frames(20)
		var add := AddWindow.open(host.get_child(-1), "Add a cup")
		await frames(20)
		await save("add_window")
		add.hide()
		ShareWindow.open(GrandPrix.cup_by_id("gearbox"), host.get_child(-1))
		await frames(20)
		await save("share_window")
		Game.show_settings()
		await frames(10)
		var field: LineEdit = host.get_child(-1).find_children("*", "LineEdit", true, false)[0]
		PadKeyboard.open(field)
		await frames(20)
		await save("pad_keyboard")
		Game.show_cup_builder("")
		await frames(10)
		var builder: CupBuilder = host.get_child(-1)
		builder._delete_dialog.popup_centered()
		await frames(20)
		await save("dialog")
		builder._delete_dialog.hide()
		Game.show_loading(true)
		await frames(20)
		await save("loading")
		Game.show_loading(false)
	if want.call("garage"):
		await _garage_shots()
	if want.call("driver"):
		await _driver_shots()
	if want.call("track_editor"):
		await _track_editor_shots()
	# Frames mid-way through the menus' motion, slowed down, only when asked.
	if only.has("motion"):
		await _motion("single_player", Game.show_single_player)
		await _motion("cups", Game.show_cups)
		await _motion("kart_picker", Game.show_kart_picker.bind(Game.show_menu, Game.show_menu, true))
		await _motion("add_window", func() -> void: AddWindow.open(host.get_child(-1), "Add a cup"))
		await _motion("focus_pop", func() -> void:
			PadFocus.using_pad = true
			host.get_child(-1).find_children("*", "BigButton", true, false)[1].grab_focus())
		PadFocus.using_pad = false
	host.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shots_records.cfg"))
	Records.use_file(Records.FILE)
	get_tree().quit()


func save(which: String) -> void:
	# Long enough for the menus' motion to finish (see UiMotion).
	await get_tree().create_timer(0.4).timeout
	for i in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var name := "%s-%dx%d" % [which, picture.get_width(), picture.get_height()]
	if OS.get_environment("SNAPRACERS_CUTOUT") != "":
		name += "-cutout"
		# The pretend hole, drawn in so it shows.
		for hole in SafeArea.pretend:
			picture.fill_rect(Rect2i(hole), Color.BLACK)
	picture.save_png("%s/%s.png" % [_folder, name])
	print("saved ", name)


## Shoots every frame while `action` plays out from the main menu, with
## time slowed to a quarter so the motion spreads over more frames.
func _motion(which: String, action: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(_folder + "/motion")
	Game.show_menu()
	await frames(40)
	Engine.time_scale = 0.25
	action.call()
	for i in 14:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/motion/%s-%02d.png" % [_folder, which, i])
	Engine.time_scale = 1.0
	for window in host.get_child(-1).find_children("*", "Window", true, false):
		window.hide()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ----------------------------------------------------------- the editors

## The garage idle, with its stats card open, holding a part, with a part
## picked out, painting, and with a controller's focus on a rail tab.
func _garage_shots() -> void:
	Game.show_garage()
	var garage: Garage = await screen_of(Garage)
	garage.ui._show_category(2)
	await ready_pictures()
	await save("garage")
	PadFocus.using_pad = true
	garage.ui._rail[3].grab_focus()
	await save("garage_focus")
	garage.ui._tiles.get_child(1).grab_focus()
	await save("garage_tile_focus")
	PadFocus.using_pad = false
	get_viewport().gui_release_focus()
	garage.ui._stats_chip.pressed.emit()
	await save("garage_card")
	garage.ui._stats_card.visible = false
	garage.ui._stats_chip.visible = true
	garage.start_placing("p_curve_2x2")
	await ready_pictures()
	await save("garage_holding")
	garage.cancel()
	garage.select(0)
	await frames(5)
	await save("garage_selected")
	garage.select(-1)
	garage.set_painting(true)
	await save("garage_paint")
	garage.set_painting(false)


## The driver screen, and with its card open.
func _driver_shots() -> void:
	Game.character = Game.roster_driver("brickley").duplicate_design()
	Game.show_driver()
	var driver: DriverBuilder = await screen_of(DriverBuilder)
	await ready_pictures()
	driver._last_touch = 0.0
	driver._turntable.rotation.y = PI + 0.25
	await save("driver")
	driver.ui._chip.pressed.emit()
	await save("driver_card")
	driver.ui._card.visible = false
	driver.ui._chip.visible = true
	# A name of its own, so nobody's saved driver is touched.
	driver.design.name = "Shot driver"
	var shot_path := driver.design.save()
	driver.ui._file_menu.popup(Rect2i(Vector2i(640, 70), Vector2i(220, 0)))
	await save("driver_menu")
	driver.ui._file_menu.hide()
	driver.ui._open_load()
	await save("driver_load")
	driver.ui._load_popup.hide()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(shot_path))


## The track editor, with its card open, a piece picked out (with and
## without the card) and a landmark in hand.
func _track_editor_shots() -> void:
	Game.show_track_editor()
	var editor: TrackEditor = await screen_of(TrackEditor)
	editor.load_course(Tracks.path_of("pithead_park"))
	for i in 60:
		await get_tree().process_frame
	await ready_pictures()
	await save("track_editor")
	editor.ui._chip.pressed.emit()
	await save("track_editor_card")
	editor.ui._card.visible = false
	editor.ui._chip.visible = true
	editor._select(3)
	await frames(5)
	await save("track_editor_piece")
	editor.ui._chip.pressed.emit()
	await frames(5)
	await save("track_editor_card_piece")
	editor.ui._card.visible = false
	editor.ui._chip.visible = true
	editor._select(-1)
	editor.ui._show_category(editor.ui._rail.size() - 1)
	await ready_pictures()
	await frames(30)
	await save("track_editor_landmarks")
