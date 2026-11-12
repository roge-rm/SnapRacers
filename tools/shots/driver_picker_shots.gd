extends Node

## Takes the driver picker for one player and for player 2, with a saved
## driver added, into FOLDER as driver_picker.png and driver_picker_two.png,
## then walks the setup for two through Game and takes the kart picker with
## player 1's driver, its driver window (with and without a pretend camera
## hole), the karts after picking there, player 2's driver picker and the
## lobby with its driver card and drivers open.
## Run it with its own XDG_DATA_HOME, on a real screen:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/driver_picker_shots.tscn -- FOLDER

var _folder := "res://build/shots"
var host: Node


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_folder = args[0]
	DirAccess.make_dir_recursive_absolute(_folder)
	get_window().mode = Window.MODE_WINDOWED
	await frames(5)
	get_window().size = Vector2i(1280, 720)
	await frames(10)
	var saved := Game.roster_driver("wren")
	saved.name = "Zippy"
	saved.set_piece("torso", "", Color("#c4281c"))
	saved.save()
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await frames(10)
	Game._swap(DriverPicker.new(func(_k): pass, Game.show_menu, "stock:brickley"))
	await _shoot("driver_picker")
	Game._swap(DriverPicker.new(func(_k): pass, Game.show_menu, "stock:nova", "stock:brickley", 2))
	await _shoot("driver_picker_two")
	# The whole setup for two through Game: P1 driver, kart, P2 driver.
	Game.settings.set_value("race", "driver", "stock:brickley")
	Game.show_race_setup(Game.show_menu, Game.show_menu, true, true)
	await frames(5)
	(Game._screen as DriverPicker).grid.marked_card().pressed.emit()
	await frames(5)
	await _shoot("kart_picker_with_driver", "KartThumbnails")
	# The driver card's window, then a pick from it, which retakes the karts.
	var picker: KartPicker = Game._screen
	var window := picker.open_drivers()
	await _shoot("kart_picker_driver_window")
	window.grid.cards["stock:wren"].pressed.emit()
	await frames(5)
	await _shoot("kart_picker_after_pick", "KartThumbnails")
	# The window with a pretend camera hole partway down the left side.
	SafeArea.pretend = [Rect2(0, 320, 70, 80)]
	window = picker.open_drivers()
	await _shoot("kart_picker_driver_window_hole")
	window.hide()
	SafeArea.pretend = []
	picker.pick_driver("stock:brickley")
	await frames(5)
	Game._go_back()
	await frames(5)
	print("back from the kart picker: ", Game._screen.get_class(), " ", (Game._screen as DriverPicker) != null)
	(Game._screen as DriverPicker).grid.marked_card().pressed.emit()
	await frames(5)
	(Game._screen as KartPicker)._go.call()
	await frames(5)
	await _shoot("driver_picker_two_from_flow")
	# One player against the AI, with the driver card and difficulty.
	Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true))
	await _shoot("kart_picker_one", "KartThumbnails")
	# The lobby, hosting, with your driver card, then its drivers open.
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(27296, NetSession.MOST_KARTS) == OK:
		Game.net.host(peer)
		Game.show_lobby()
		await _shoot("lobby_driver_card")
		(Game._screen as Lobby).open_drivers(0)
		await _shoot("lobby_driver_window")
		Game.net.leave()
	Game.settings.set_value("race", "driver", "")
	DirAccess.remove_absolute("%s/zippy.json" % CharacterDesign.SAVE_DIR)
	get_tree().quit()


func _shoot(which: String, busy_kind := "DriverPortraits") -> void:
	for i in 600:
		await get_tree().process_frame
		var busy := false
		for node in get_tree().root.find_children("*", busy_kind, true, false):
			busy = busy or node.is_processing()
		if i >= 10 and not busy:
			break
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	picture.save_png("%s/%s.png" % [_folder, which])
	print("saved ", which, " ", picture.get_size())
