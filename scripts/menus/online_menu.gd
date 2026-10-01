class_name OnlineMenu
extends Control

## Racing people on other devices, by hosting a game or joining one. Games on
## the same network turn up here by themselves, and any game can be joined by
## typing its address, which also reaches servers on the internet. On an
## Android phone a game can also be hosted and found over Wi-Fi Direct or
## Bluetooth.

var _found: VBoxContainer
var _address: LineEdit
var _problem: Label
var _finder: GameFinder
var _two: CheckButton
## Games found over Wi-Fi Direct and Bluetooth, and what's going on with them.
var _nearby: VBoxContainer
var _nearby_found := {}
var _looking: Label
## The port of the Wi-Fi Direct game being joined.
var _direct_port := NetSession.PORT


func _ready() -> void:
	var column := MenuStyle.page(self, "Online", go_back, 760.0)
	_problem = Label.new()
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.add_theme_color_override("font_color", BuilderStyle.DANGER)
	_problem.add_theme_font_size_override("font_size", 20)
	_problem.text = Game.net.last_problem
	_problem.visible = _problem.text != ""
	column.add_child(_problem)

	var two_row := HBoxContainer.new()
	column.add_child(two_row)
	var heading := MenuStyle.heading("Two of us on this phone", "On a split screen")
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	two_row.add_child(heading)
	_two = CheckButton.new()
	_two.focus_mode = FOCUS_ALL
	_two.button_pressed = Game.online_two
	_two.toggled.connect(func(on: bool) -> void:
		Game.online_two = on
		if on and Game.split() == Game.SOLO:
			Game.set_setting("race", "split", Game.SIDE_BY_SIDE))
	two_row.add_child(_two)

	if not OS.has_feature("web"):
		column.add_child(MenuStyle.heading("Host a game", "For phones on this Wi-Fi or this phone's hotspot"))
		var host := MenuStyle.button("Host a game", _host)
		host.custom_minimum_size.y = 72.0
		column.add_child(host)
		if Game.plugin.has():
			column.add_child(_pair(
				MenuStyle.button("Host over Wi-Fi Direct", _host_direct, "No Wi-Fi needed"),
				MenuStyle.button("Host over Bluetooth", _host_bluetooth, "For a few players")))

	column.add_child(MenuStyle.heading("Join a game", "Games on this network show up here" if not OS.has_feature("web") else "Type a SnapRacers server's address"))
	_found = VBoxContainer.new()
	_found.add_theme_constant_override("separation", 8)
	column.add_child(_found)
	if Game.plugin.has():
		column.add_child(_pair(
			MenuStyle.button("Find Wi-Fi Direct games", _look.bind(NetSession.DIRECT)),
			MenuStyle.button("Find Bluetooth games", _look.bind(NetSession.BLUETOOTH))))
		_looking = Label.new()
		_looking.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_looking.add_theme_color_override("font_color", BuilderStyle.DATA)
		_looking.add_theme_font_size_override("font_size", 20)
		_looking.visible = false
		column.add_child(_looking)
		_nearby = VBoxContainer.new()
		_nearby.add_theme_constant_override("separation", 8)
		column.add_child(_nearby)
		Game.plugin.found.connect(_on_nearby_found)
		Game.plugin.looking_done.connect(_on_looking_done)
		Game.plugin.direct_joined.connect(_on_direct_joined)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_address = LineEdit.new()
	_address.placeholder_text = "Or type an address"
	_address.text = Game.settings.get_value("online", "address", "")
	_address.size_flags_horizontal = SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(_text: String) -> void: _join_typed())
	row.add_child(_address)
	var join := MenuStyle.button("Join", _join_typed)
	join.custom_minimum_size.x = 140.0
	row.add_child(join)

	column.add_child(MenuStyle.heading("How do I connect?", HELP_WEB if OS.has_feature("web") else HELP_PHONE if Game.plugin.has() else HELP))
	MenuStyle.back_at_bottom(column, go_back)

	_finder = GameFinder.new()
	add_child(_finder)
	_finder.found_changed.connect(_show_found)
	_finder.look()
	_show_found()


const HELP := "On the same Wi-Fi, one of you hosts and the others see it here. With no Wi-Fi, turn on one phone's hotspot, connect the others to it and host on that phone. Anywhere else, join a SnapRacers server by typing its address. A game on the internet needs port 27280 open."
const HELP_PHONE := "On the same Wi-Fi, one phone hosts and the others see it here. With no Wi-Fi around, one phone hosts over Wi-Fi Direct and the others tap Find Wi-Fi Direct games (the host might have to accept each one), or one phone turns on its hotspot and hosts. Bluetooth works for two or three phones with no Wi-Fi at all. One hosts over Bluetooth, and the others tap Find Bluetooth games and pick the host's phone by its Bluetooth name. Pairing the phones first makes it quicker. Anywhere else, join a SnapRacers server by typing its address."
const HELP_WEB := "In a browser you can join a SnapRacers server by typing its address, but you can't host or find games. The server needs a certificate for web players, which its admin can set up."


func _show_found() -> void:
	for child in _found.get_children():
		child.queue_free()
	if _finder.found.is_empty():
		var none := Label.new()
		none.text = "No games found yet" if not OS.has_feature("web") else ""
		none.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		_found.add_child(none)
		return
	for address in _found_sorted():
		var game: Dictionary = _finder.found[address]
		var line := str(address)
		if game.has("players"):
			line += "  ·  %d of %d" % [int(game.players), int(game.get("most", NetSession.MOST_KARTS))]
		var button := MenuStyle.button(str(game.get("name", "A game")), _join.bind(address, int(game.get("port", NetSession.PORT))), line)
		button.custom_minimum_size.y = 76.0
		_found.add_child(button)


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


func _show_nearby() -> void:
	for child in _nearby.get_children():
		child.queue_free()
	for key in _nearby_found:
		var game: Dictionary = _nearby_found[key]
		var button: Button
		if game.how == NetSession.DIRECT:
			button = MenuStyle.button(str(game.name), _join_direct.bind(str(game.device), int(game.port)), "Wi-Fi Direct")
		else:
			button = MenuStyle.button(str(game.name), _join_bluetooth.bind(str(game.device)), "Bluetooth, paired" if game.get("paired", false) else "Bluetooth")
		button.custom_minimum_size.y = 76.0
		_nearby.add_child(button)


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
