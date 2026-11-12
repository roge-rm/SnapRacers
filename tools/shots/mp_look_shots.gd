extends Node

## Takes the two player menu, the online screens, the lobby (hosting, with a
## pretend second player and as a pretend joiner, a cup, no AI, and narrow
## with a camera hole) and a few comparison screens into FOLDER, one picture
## per screenful. With "lobby" after FOLDER it only takes the lobby, and
## with "mp" only the two player and online menus.
## Run it with its own XDG_DATA_HOME, on a real screen:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/mp_look_shots.tscn -- FOLDER [lobby]

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
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await frames(10)
	if args.has("mp"):
		await _two_and_online()
		get_tree().quit()
		return
	if not args.has("lobby"):
		await _screens("main_menu", Game.show_menu)
		await _screens("single_player_menu", Game.show_single_player)
		await _screens("cup_grid", Game.show_cups)
		await _screens("course_grid", Game.show_course_grid.bind(Game.MODE_RACE, true, "gearbox"))
		await _screens("kart_picker", Game.show_kart_picker.bind(Game.show_menu, Game.show_menu, true))
		await _screens("two_player_menu", Game.show_multiplayer)
		await _screens("online_menu", Game.show_online)
	Game.online_two = false
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(27297, NetSession.MOST_KARTS) == OK:
		Game.net.host(peer)
		Game.show_lobby()
		await _screens("lobby_host_alone", Callable())
		# A pretend second player on this phone.
		var me: Dictionary = Game.net.members[1]
		var two: Dictionary = me.players[0].duplicate(true)
		two.name = "Player 2"
		two.driver = CharacterDesign.for_key("stock:nova").to_dict()
		me.players.append(two)
		Game.net.changed.emit()
		await _screens("lobby_host_two_local", Callable())
		# A pretend joiner, as a second person.
		var other: Dictionary = me.duplicate(true)
		other.name = "Joiner"
		other.players = [two.duplicate(true)]
		other.players[0].name = "Joiner"
		other.ready = true
		Game.net.members[2] = other
		Game.net.changed.emit()
		await _screens("lobby_host_with_joiner", Callable())
		Game.net.set_settings({"mirrored": true, "weather": "rain"})
		Game.net.set_settings({"mode": NetSession.CUP, "cup": Lobby._game_cup(GrandPrix.cups()[1])})
		await _screens("lobby_host_cup", Callable())
		Game.net.set_settings({"mode": NetSession.SINGLE, "ai": false})
		await _screens("lobby_host_no_ai", Callable())
		Game.net.set_settings({"ai": true, "weather": Conditions.RANDOM, "time": Conditions.RANDOM})
		# A narrower screen with a camera hole on the left folds the options.
		get_window().size = Vector2i(1100, 720)
		SafeArea.pretend.assign([Rect2(0, 330, 60, 60)])
		await frames(10)
		await _screens("lobby_narrow_hole", Callable())
		(Game._screen as Lobby)._open_options()
		await _screens("lobby_narrow_options", Callable())
		(Game._screen as Lobby)._options_window.hide()
		SafeArea.pretend.assign([])
		get_window().size = Vector2i(1280, 720)
		await frames(10)
		# The joiner's own view.
		Game.net.role = NetSession.Role.CLIENT
		Game.net.members.erase(1)
		Game.net.members[1] = other
		Game.net.members[2] = me
		Game.net.changed.emit()
		await _screens("lobby_joiner", Callable())
		Game.net.role = NetSession.Role.HOST
		Game.net.leave()
	get_tree().quit()


## The two player menu each way, online with and without games found, and
## both narrow with a camera hole.
func _two_and_online() -> void:
	var was := Game.split()
	Game.set_setting("race", "split", Game.SIDE_BY_SIDE)
	await _screens("two_player_side", Game.show_multiplayer)
	Game.set_setting("race", "split", Game.FACE_TO_FACE)
	await _screens("two_player_face", Game.show_multiplayer)
	RaceWindow.forced_id = "peach_pit"
	Game.online_two = false
	await _screens("online_none", Game.show_online)
	Game.online_two = true
	Game.show_online()
	await frames(3)
	var menu := Game._screen as OnlineMenu
	menu._finder.found["10.0.0.7"] = {"name": "Dan's phone", "players": 2, "port": NetSession.PORT, "heard": menu._finder._clock + 600.0}
	menu._finder.found["10.0.0.9"] = {"name": "Tab", "players": 1, "port": NetSession.PORT, "heard": menu._finder._clock + 600.0}
	menu._show_found()
	await _screens("online_two_games", Callable())
	get_window().size = Vector2i(1100, 720)
	SafeArea.pretend.assign([Rect2(0, 330, 60, 60)])
	await frames(10)
	await _screens("online_narrow_hole", Callable())
	await _screens("two_player_narrow_hole", Game.show_multiplayer)
	SafeArea.pretend.assign([])
	get_window().size = Vector2i(1280, 720)
	Game.online_two = false
	Game.set_setting("race", "split", was)


## Opens a screen (unless the call is empty, when the current one stays) and
## takes it, then scrolls it down a screenful at a time.
func _screens(which: String, open: Callable) -> void:
	if open.is_valid():
		open.call()
	await frames(5)
	await _shoot(which)
	var scrolls := Game._screen.find_children("*", "ScrollContainer", true, false)
	for scroll: ScrollContainer in scrolls:
		if not scroll.is_visible_in_tree() or scroll.size.x < 600:
			continue
		var bar := scroll.get_v_scroll_bar()
		var n := 2
		while scroll.scroll_vertical + scroll.size.y < bar.max_value - 1.0 and n < 12:
			scroll.scroll_vertical = mini(scroll.scroll_vertical + int(scroll.size.y) - 40, int(bar.max_value - scroll.size.y))
			await frames(5)
			await _shoot("%s_scroll%d" % [which, n])
			n += 1
		scroll.scroll_vertical = 0
		break


func _shoot(which: String) -> void:
	for i in 600:
		await get_tree().process_frame
		var busy := false
		for kind in ["DriverPortraits", "KartThumbnails"]:
			for node in get_tree().root.find_children("*", kind, true, false):
				busy = busy or node.is_processing()
		if i >= 10 and not busy:
			break
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_folder, which])
	print("saved ", which)
