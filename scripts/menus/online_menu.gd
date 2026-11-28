class_name OnlineMenu
extends Control

## Racing people on other devices, by hosting a game or joining one. Games on
## the same network turn up here by themselves, and any game can be joined by
## typing its address, which also reaches servers on the internet. On an
## Android phone a game can also be hosted and found over Wi-Fi Direct or
## Bluetooth.

var _games: Container
var _games_scroll: ScrollContainer
var _address: LineEdit
var _problem: Label
var _finder: GameFinder
var _two: Button
## Games found over Wi-Fi Direct and Bluetooth, and what's going on with them.
var _nearby_found := {}
var _looking: Label
## Hosting and finding games over Wi-Fi Direct and Bluetooth, on Android.
var _without_window: PopupPanel
var _without_list: VBoxContainer
## The port of the Wi-Fi Direct game being joined.
var _direct_port := NetSession.PORT

static var _switches := {}


func _ready() -> void:
	var parts := MenuStyle.menu_parts(self, "Online")
	var steps: Container = parts.steps
	var top: HBoxContainer = parts.top

	if Game.plugin.has():
		var without := MenuStyle.button("Without Wi-Fi", _open_without)
		without.theme_type_variation = "SmallButton"
		MenuStyle.snug(without, false, 52.0)
		without.custom_minimum_size.y = 52.0
		without.size_flags_vertical = SIZE_SHRINK_CENTER
		top.add_child(without)
		_build_without()
	_two = MenuStyle.button("Two of us on this phone", _toggle_two)
	_two.theme_type_variation = "SmallButton"
	MenuStyle.snug(_two, false, 52.0)
	_two.custom_minimum_size.y = 52.0
	_two.size_flags_vertical = SIZE_SHRINK_CENTER
	_two.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_two.add_theme_constant_override("h_separation", 10)
	for colour in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		_two.add_theme_color_override(colour, UiKit.WHITE)
	top.add_child(_two)
	top.add_child(MenuStyle.link("Back", go_back, "back"))
	_show_two()

	_problem = Label.new()
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.theme_type_variation = "DangerLabel"
	_problem.custom_minimum_size.x = 440.0
	_problem.text = Game.net.last_problem
	_problem.visible = _problem.text != ""
	steps.add_child(_problem)

	if not OS.has_feature("web"):
		steps.add_child(MenuStyle.big_button("Host a game", "plus", _host, "Others on your Wi-Fi join you"))

	# Found games, two to a screenful, scrolling if there are more.
	_games_scroll = ScrollContainer.new()
	_games_scroll.follow_focus = true
	_games_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	steps.add_child(_games_scroll)
	_games = MenuStyle.Steps.new()
	_games.size_flags_horizontal = SIZE_EXPAND_FILL
	_games_scroll.add_child(_games)
	_looking = Label.new()
	_looking.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_looking.theme_type_variation = "DataLabel"
	_looking.custom_minimum_size.x = 440.0
	_looking.visible = false
	steps.add_child(_looking)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.custom_minimum_size.x = 470.0
	steps.add_child(row)
	_address = LineEdit.new()
	PadKeyboard.attach(_address)
	_address.placeholder_text = "Or type an address"
	_address.text = Game.settings.get_value("online", "address", "")
	_address.size_flags_horizontal = SIZE_EXPAND_FILL
	_address.custom_minimum_size.y = 56.0
	_address.text_submitted.connect(func(_text: String) -> void: _join_typed())
	row.add_child(_address)
	var join := MenuStyle.button("Join", _join_typed)
	join.custom_minimum_size.x = 130.0
	row.add_child(join)

	if Game.plugin.has():
		Game.plugin.found.connect(_on_nearby_found)
		Game.plugin.looking_done.connect(_on_looking_done)
		Game.plugin.direct_joined.connect(_on_direct_joined)

	_finder = GameFinder.new()
	add_child(_finder)
	_finder.found_changed.connect(_show_found)
	_finder.look()
	_show_found()


func _toggle_two() -> void:
	Game.online_two = not Game.online_two
	if Game.online_two and Game.split() == Game.SOLO:
		Game.set_setting("race", "split", Game.SIDE_BY_SIDE)
	_show_two()


## The two of us pill, with a switch showing on or off.
func _show_two() -> void:
	_two.icon = _switch(Game.online_two)


static func _switch(on: bool) -> Texture2D:
	if not _switches.has(on):
		var image := UiKit.switch_picture(on, 1.0).get_image()
		image.resize(46, 22, Image.INTERPOLATE_LANCZOS)
		_switches[on] = ImageTexture.create_from_image(image)
	return _switches[on]


## The window with hosting and finding over Wi-Fi Direct and Bluetooth. It
## only closes with Close or B.
func _build_without() -> void:
	_without_window = PopupPanel.new()
	_without_window.theme = MenuStyle.theme()
	_without_window.popup_window = false
	_without_window.exclusive = true
	PadFocus.close_on_b(_without_window)
	add_child(_without_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_without_window.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	column.add_child(head)
	var heading := MenuStyle.heading("Without Wi-Fi")
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(heading)
	var close := MenuStyle.link("Close", _without_window.hide, "close")
	close.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(close)
	_without_list = VBoxContainer.new()
	_without_list.add_theme_constant_override("separation", 10)
	_without_list.custom_minimum_size.x = 520.0
	column.add_child(_without_list)
	_without_list.add_child(_pair(
		MenuStyle.button("Host over Wi-Fi Direct", _from_without.bind(_host_direct), "No Wi-Fi needed"),
		MenuStyle.button("Host over Bluetooth", _from_without.bind(_host_bluetooth), "For a few players")))
	_without_list.add_child(_pair(
		MenuStyle.button("Find Wi-Fi Direct games", _from_without.bind(_look.bind(NetSession.DIRECT))),
		MenuStyle.button("Find Bluetooth games", _from_without.bind(_look.bind(NetSession.BLUETOOTH)))))


func _open_without() -> void:
	_without_window.popup_centered()
	PadFocus.focus_first.call_deferred(_without_list)


## Whether the Without Wi-Fi window is open.
func without_open() -> bool:
	return _without_window != null and _without_window.visible


func _from_without(action: Callable) -> void:
	_without_window.hide()
	action.call()


## Every game found, on this network and nearby, as a card each.
func _show_found() -> void:
	for child in _games.get_children():
		_games.remove_child(child)
		child.queue_free()
	for address in _found_sorted():
		var game: Dictionary = _finder.found[address]
		var line := str(address)
		if game.has("players"):
			line += ", %d of %d" % [int(game.players), int(game.get("most", NetSession.MOST_KARTS))]
		var card := MenuStyle.big_button(str(game.get("name", "A game")), "race", _join.bind(address, int(game.get("port", NetSession.PORT))), line)
		card.set_meta("address", address)
		_games.add_child(card)
	for key in _nearby_found:
		var game: Dictionary = _nearby_found[key]
		var card: BigButton
		if game.how == NetSession.DIRECT:
			card = MenuStyle.big_button(str(game.name), "race", _join_direct.bind(str(game.device), int(game.port)), "Wi-Fi Direct")
		else:
			card = MenuStyle.big_button(str(game.name), "race", _join_bluetooth.bind(str(game.device)), "Bluetooth, paired" if game.get("paired", false) else "Bluetooth")
		_games.add_child(card)
	var count := _games.get_child_count()
	if count == 0 and not OS.has_feature("web"):
		var none := Label.new()
		none.text = "No games found yet"
		none.theme_type_variation = "NoteLabel"
		_games.add_child(none)
	_games_scroll.visible = _games.get_child_count() > 0
	# Room for two games, and the rest scroll.
	var high := 0.0
	var shown := 0
	for child: Control in _games.get_children():
		if shown == 2:
			break
		high += child.get_combined_minimum_size().y + (UiKit.GAP_M if shown > 0 else 0.0)
		shown += 1
	_games_scroll.custom_minimum_size.y = high


func _show_nearby() -> void:
	_show_found()


func _found_sorted() -> Array:
	var keys := _finder.found.keys()
	keys.sort()
	return keys


func _exit_tree() -> void:
	if Game.plugin.has():
		Game.plugin.android.direct_stop_looking()
		Game.plugin.android.bt_stop_looking()


func _pair(left: Button, right: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for button in [left, right]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 72.0
		row.add_child(button)
	return row


func _host() -> void:
	var why := []
	var peer := Connections.host_enet(NetSession.PORT, why)
	if peer == null:
		_show_problem(why[0])
		return
	Game.net.host(peer)
	Game.show_lobby()


func _host_direct() -> void:
	var why: String = await Game.plugin.direct_ready()
	if not is_inside_tree():
		return
	if why != "":
		_show_problem(why)
		return
	var problem := []
	var peer := Connections.host_enet(NetSession.PORT, problem)
	if peer == null:
		_show_problem(problem[0])
		return
	Game.net.host(peer, false, NetSession.DIRECT)
	Game.plugin.android.direct_host(Game.game_name(), NetSession.PORT)
	Game.show_lobby()


func _host_bluetooth() -> void:
	var why: String = await Game.plugin.bluetooth_ready()
	if not is_inside_tree():
		return
	if why != "":
		_show_problem(why)
		return
	# Phones that have never paired with this one can only find it while
	# it's findable, so Android's asked straight away.
	if not Game.plugin.android.bt_is_findable():
		Game.plugin.android.bt_ask_to_be_findable()
	var peer := BluetoothPeer.host(Game.plugin)
	if peer == null:
		_show_problem("I couldn't start a Bluetooth game.")
		return
	Game.net.host(peer, false, NetSession.BLUETOOTH)
	Game.show_lobby()


## Looks for games nearby over Wi-Fi Direct or Bluetooth.
func _look(how: String) -> void:
	var why := ""
	if how == NetSession.DIRECT:
		why = await Game.plugin.direct_ready()
	else:
		why = await Game.plugin.bluetooth_ready()
	if not is_inside_tree():
		return
	if why != "":
		_show_problem(why)
		return
	_problem.visible = false
	for key in _nearby_found.keys():
		if _nearby_found[key].how == how:
			_nearby_found.erase(key)
	_show_nearby()
	if how == NetSession.DIRECT:
		_say("Looking for Wi-Fi Direct games...")
		Game.plugin.android.direct_look(30)
	else:
		_say("Looking for phones over Bluetooth...")
		Game.plugin.android.bt_look(15)


func _say(text: String) -> void:
	_looking.text = text
	_looking.visible = text != ""


func _on_nearby_found(how: String, game: Dictionary) -> void:
	if how == "nsd":
		return
	game.how = how
	_nearby_found["%s %s" % [how, game.device]] = game
	_show_nearby()


func _on_looking_done(_how: String, why: String) -> void:
	if why != "":
		_show_problem(why)
	_say("" if not _nearby_found.is_empty() else "Nothing found. Is the other phone hosting, and close by?")


func _join_direct(device: String, port: int) -> void:
	_direct_port = port
	_problem.visible = false
	_say("Joining over Wi-Fi Direct. If the host's phone asks, accept on it.")
	Game.plugin.android.direct_join(device)


## Once it's joined the host's Wi-Fi Direct group (or not), it's ENet like
## Wi-Fi.
func _on_direct_joined(address: String, why: String) -> void:
	_say("")
	if address == "":
		_show_problem(why)
		return
	var problem := []
	var peer := Connections.join_enet(address, _direct_port, problem)
	if peer == null:
		_show_problem(problem[0])
		return
	Game.net.join(peer, NetSession.DIRECT)
	Game.show_lobby()


func _join_bluetooth(device: String) -> void:
	var why: String = await Game.plugin.bluetooth_ready()
	if not is_inside_tree():
		return
	if why != "":
		_show_problem(why)
		return
	var peer := BluetoothPeer.join(Game.plugin, device)
	if peer == null:
		_show_problem("I couldn't start joining over Bluetooth.")
		return
	Game.net.join(peer, NetSession.BLUETOOTH)
	Game.show_lobby()


func _join_typed() -> void:
	var text := _address.text.strip_edges()
	if text == "":
		return
	Game.set_setting("online", "address", text)
	if OS.has_feature("web") or text.begins_with("ws://") or text.begins_with("wss://"):
		var url := Connections.websocket_url(text)
		var why := []
		var peer := Connections.join_websocket(url, why)
		if peer == null:
			_show_problem(why[0])
			return
		Game.net.join(peer)
		Game.show_lobby()
		return
	var parts := Connections.parse_address(text)
	_join(parts[0], parts[1])


func _join(address: String, port: int) -> void:
	var why := []
	var peer := Connections.join_enet(address, port, why)
	if peer == null:
		_show_problem(why[0])
		return
	Game.net.join(peer)
	Game.show_lobby()


func _show_problem(text: String) -> void:
	_problem.text = text
	_problem.visible = true
	Sounds.play("fx/nope")


func go_back() -> void:
	Game.show_multiplayer()
