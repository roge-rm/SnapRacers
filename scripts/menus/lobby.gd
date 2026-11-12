class_name Lobby
extends Control

## An online game before and between races. Every place in the race has a
## card: the racers with their driver and kart, then AI drivers or open
## places. Tapping your own card changes your driver. The host picks one race
## or a cup, which course or cup (the game's or their own, sent to everyone),
## how many laps, the weather and time, and whether AI drivers fill the empty
## places. Everyone says they're ready and the host starts it.

## The header's pills, shorter than other buttons so they fit beside the title.
const PILL_HIGH := 48.0
const PILL_FONT := 20

## My players' cards, the second for a second player on this phone.
var driver_cards: Array[LobbyCard] = []
## Every place in the race, racers first in the order they joined.
var _places: Array[LobbyCard] = []
var _margin: MarginContainer
var _title: PanelContainer
var _leave: Button
## The pills in the header, between the title and Leave.
var _header: HBoxContainer
var _options: Button
var _weather: Button
var _time: Button
var _reverse: Button
var _mirror: Button
var _ai: Button
var _difficulty: Button
## Whether weather, time, reverse, mirrored and AI are in the Options window
## for want of room in the header.
var folded := false
var _options_window: PopupPanel
var _options_list: VBoxContainer
var _status: Label
var _right: VBoxContainer
var _window_button: Button
var _window: RaceWindow
var _modes: Array[Button] = []
var _fewer: Button
var _more: Button
var _laps: Label
var _keep: HBoxContainer
var _start: Button
var _finder: GameFinder
var _picker: PopupPanel
var _picker_list: VBoxContainer
var _portraits: DriverPortraits
## The trophy picture the window's waiting for, for a cup.
var _trophy_key := ""
## How hosting over Wi-Fi Direct is going.
var _direct_status := "Starting Wi-Fi Direct..."

static var _switches := {}


func _ready() -> void:
	theme = MenuStyle.theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := MenuStyle.backdrop()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_left", 40)
	_margin.add_theme_constant_override("margin_right", 40)
	_margin.add_theme_constant_override("margin_top", 24)
	_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var safe := SafeArea.new()
	add_child(safe)
	safe.pad(_margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_margin.add_child(outer)
	_portraits = DriverPortraits.new()
	_portraits.ready_for.connect(_on_portrait)
	add_child(_portraits)

	_build_header(outer)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.pad(UiKit.slant(UiKit.PANEL, UiKit.LEAN, UiKit.EDGE, 1, false), 12, 2, UiKit.LEAN, 34.0))
	chip.size_flags_horizontal = SIZE_SHRINK_BEGIN
	outer.add_child(chip)
	_status = Label.new()
	_status.add_theme_color_override("font_color", UiKit.BLUE)
	_status.add_theme_font_size_override("font_size", 20)
	chip.add_child(_status)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	outer.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 2.0
	body.add_child(grid)
	for i in NetSession.MOST_KARTS:
		var card := LobbyCard.new()
		card.size_flags_vertical = SIZE_EXPAND_FILL
		card.tapped.connect(_tapped.bind(i))
		grid.add_child(card)
		_places.append(card)
	_build_race(body)

	_build_options()
	_picker = PopupPanel.new()
	_picker.theme = MenuStyle.theme()
	add_child(_picker)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(520, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker.add_child(scroll)
	_picker_list = VBoxContainer.new()
	_picker_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_picker_list)

	# A host lets the network know the game's here, when it can be joined
	# that way (a Bluetooth game can't).
	if Game.net.role == NetSession.Role.HOST and Game.net.over != NetSession.BLUETOOTH:
		_finder = GameFinder.new()
		add_child(_finder)
	if Game.net.over == NetSession.DIRECT and Game.plugin.has():
		Game.plugin.direct_hosting.connect(func(ok: bool, why: String) -> void:
			_direct_status = "Others can find this game with Find Wi-Fi Direct games" if ok else why
			_show())
	Game.trophy_pictures().ready_for.connect(_on_trophy)
	Game.net.changed.connect(_show)
	# The margins grow to clear a camera hole, which changes the room.
	outer.resized.connect(_fit_header)
	_margin.resized.connect(_fit_header)
	_margin.theme_changed.connect(_fit_header)
	_show()


func _exit_tree() -> void:
	if Game.net.changed.is_connected(_show):
		Game.net.changed.disconnect(_show)
	if Game.trophy_pictures().ready_for.is_connected(_on_trophy):
		Game.trophy_pictures().ready_for.disconnect(_on_trophy)


## The title, the race's options as pills and Leave.
func _build_header(outer: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP_M)
	outer.add_child(top)
	_title = MenuStyle.ribbon("Lobby")
	top.add_child(_title)
	MenuStyle.fit_ribbon(_title, "Lobby", 1000.0)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 6)
	_header.size_flags_horizontal = SIZE_EXPAND_FILL
	_header.size_flags_vertical = SIZE_SHRINK_CENTER
	_header.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(_header)
	_leave = MenuStyle.link("Leave", go_back, "back")
	_leave.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(_leave)

	_options = _pill(_open_options)
	_options.text = "Options"
	_weather = _pill(func() -> void:
		Game.net.set_settings({"weather": Conditions.next_pick(_setting("weather", Conditions.RANDOM), Conditions.WEATHERS)}))
	_time = _pill(func() -> void:
		Game.net.set_settings({"time": Conditions.next_pick(_setting("time", Conditions.RANDOM), Conditions.TIMES)}))
	_reverse = _pill(func() -> void: Game.net.set_settings({"reversed": not bool(_setting("reversed", false))}))
	_reverse.text = "Reverse"
	_mirror = _pill(func() -> void: Game.net.set_settings({"mirrored": not bool(_setting("mirrored", false))}))
	_mirror.text = "Mirrored"
	_ai = _pill(func() -> void: Game.net.set_settings({"ai": not bool(_setting("ai", true))}))
	_ai.text = "AI"
	_ai.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ai.add_theme_constant_override("h_separation", 8)
	for colour in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		_ai.add_theme_color_override(colour, UiKit.WHITE)
	_ai.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.5))
	_difficulty = _pill(func() -> void:
		var at := Difficulty.LEVELS.find(_setting("difficulty", Difficulty.DEFAULT))
		Game.net.set_settings({"difficulty": Difficulty.LEVELS[(at + 1) % Difficulty.LEVELS.size()]}))
	for b in [_options, _weather, _time, _reverse, _mirror, _ai, _difficulty]:
		_header.add_child(b)


## A pill for the header.
func _pill(action: Callable) -> Button:
	var b := MenuStyle.button("", action)
	b.custom_minimum_size.y = PILL_HIGH
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", PILL_FONT)
	MenuStyle.snug(b, false, PILL_HIGH)
	return b


## The course or cup in its window, one race or a cup, the laps and Start.
func _build_race(body: HBoxContainer) -> void:
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", UiKit.GAP_M)
	_right.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(_right)
	_window_button = ScrollButton.new()
	_window_button.focus_mode = FOCUS_ALL
	for state in UiKit.STATES:
		_window_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_window_button.custom_minimum_size.y = 160.0
	_window_button.tapped.connect(_pick)
	_right.add_child(_window_button)
	_window = RaceWindow.new()
	_window.pick_at_random = false
	_window_button.add_child(_window)
	_window.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for what in [_window_button.focus_entered, _window_button.focus_exited, _window_button.mouse_entered, _window_button.mouse_exited]:
		what.connect(_light_window)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", UiKit.GAP_M)
	_right.add_child(modes)
	for pair in [[NetSession.SINGLE, "One race"], [NetSession.CUP, "A cup"]]:
		var b := MenuStyle.button(pair[1], _set_mode.bind(pair[0]))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.set_meta("mode", pair[0])
		modes.add_child(b)
		_modes.append(b)

	var laps := HBoxContainer.new()
	laps.add_theme_constant_override("separation", UiKit.GAP_M)
	_right.add_child(laps)
	_fewer = MenuStyle.button("−", func() -> void: Game.net.set_settings({"laps": maxi(int(_setting("laps", 3)) - 1, 1)}))
	_fewer.custom_minimum_size.x = 90
	laps.add_child(_fewer)
	_laps = Label.new()
	_laps.theme_type_variation = "LeadLabel"
	_laps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_laps.size_flags_horizontal = SIZE_EXPAND_FILL
	_laps.size_flags_vertical = SIZE_SHRINK_CENTER
	_laps.custom_minimum_size.y = UiKit.BUTTON_HEIGHT
	_laps.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	laps.add_child(_laps)
	_more = MenuStyle.button("+", func() -> void: Game.net.set_settings({"laps": mini(int(_setting("laps", 3)) + 1, 9)}))
	_more.custom_minimum_size.x = 90
	laps.add_child(_more)

	_keep = HBoxContainer.new()
	_keep.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.add_child(_keep)

	var gap := Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	_right.add_child(gap)
	# The window keeps the still's shape, as tall as there's room for.
	_right.resized.connect(_fit_window)
	_start = MenuStyle.button("Start", _start_or_ready)
	_start.theme_type_variation = "MainButton"
	_start.custom_minimum_size = Vector2(240, 60)
	_right.add_child(_start)


## The small window with the options that don't fit in the header. It only
## closes with Close or B.
func _build_options() -> void:
	_options_window = PopupPanel.new()
	_options_window.theme = MenuStyle.theme()
	_options_window.popup_window = false
	_options_window.exclusive = true
	PadFocus.close_on_b(_options_window)
	add_child(_options_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_options_window.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	column.add_child(top)
	var heading := MenuStyle.heading("Options")
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(heading)
	var close := MenuStyle.link("Close", _options_window.hide, "close")
	close.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(close)
	_options_list = VBoxContainer.new()
	_options_list.add_theme_constant_override("separation", 10)
	_options_list.custom_minimum_size.x = 320.0
	column.add_child(_options_list)


func _open_options() -> void:
	_options_window.popup_centered()
	PadFocus.focus_first.call_deferred(_options_list)


## Whether the Options window is open.
func options_open() -> bool:
	return _options_window.visible


func _setting(key: String, otherwise: Variant) -> Variant:
	return Game.net.settings.get(key, otherwise)


func _show() -> void:
	var net := Game.net
	var host := net.is_host()
	if net.role == NetSession.Role.CLIENT and net.members.is_empty():
		_status.text = "Joining..."
	elif host and net.over == NetSession.DIRECT:
		_status.text = _direct_status
	elif host and net.over == NetSession.BLUETOOTH:
		_status.text = "Others can join with Find Bluetooth games, and pick %s" % Game.plugin.android.bt_name()
	elif host:
		var addresses := Connections.my_addresses()
		_status.text = "Join at %s" % (addresses[0] if not addresses.is_empty() else "this phone's address")
	else:
		_status.text = "Joined %s" % (str(net.members[1].name) if net.members.has(1) else "the game")
	if _finder != null:
		_finder.advertise({"name": Game.game_name(), "players": net.player_count(), "most": NetSession.MOST_KARTS, "port": NetSession.PORT, "version": NetSession.VERSION})
	_show_places()
	_show_settings(host)
	_show_start(host)
	_fit_header()


## Everyone racing, then AI drivers or open places.
func _show_places() -> void:
	var net := Game.net
	var ai := bool(net.settings.get("ai", true))
	var level := str(net.settings.get("difficulty", Difficulty.DEFAULT))
	var locked := not net.setup.is_empty()
	# The player whose card is picked out keeps it when the cards move round.
	var focused := get_viewport().gui_get_focus_owner()
	var held: int = focused.get_meta("player") if focused is LobbyCard and focused.has_meta("player") else -1
	driver_cards.clear()
	var at := 0
	var ids := net.members.keys()
	ids.sort()
	for peer in ids:
		var member: Dictionary = net.members[peer]
		var mine: bool = peer == net.my_id()
		for i in member.players.size():
			if at >= _places.size():
				break
			var player: Dictionary = member.players[i]
			var card := _places[at]
			var design := CharacterDesign.from_dict(player.get("driver", {}))
			var kart := str(player.get("kart", {}).get("name", "A kart"))
			# The host's always ready, so only the others say so.
			card.show_racer(str(player.name), design, kart, i + 1 if mine else 0, not mine and peer != 1 and bool(member.ready))
			if card.wants_portrait():
				_portraits.take(design)
			_let_tap(card, mine)
			card.disabled = mine and locked
			if mine:
				card.set_meta("player", i)
				driver_cards.append(card)
			at += 1
	for i in range(at, _places.size()):
		var card := _places[i]
		if ai:
			card.show_ai(level)
		else:
			card.show_open()
		_let_tap(card, false)
		card.disabled = false
	if held != -1 and not driver_cards.is_empty():
		var card: LobbyCard = driver_cards[mini(held, driver_cards.size() - 1)]
		if not card.has_focus():
			card.grab_focus()


func _let_tap(card: LobbyCard, on: bool) -> void:
	card.focus_mode = FOCUS_ALL if on else FOCUS_NONE
	card.mouse_filter = MOUSE_FILTER_STOP if on else MOUSE_FILTER_IGNORE
	if not on:
		card.remove_meta("player")
		if card.has_focus():
			card.release_focus()


func _tapped(place: int) -> void:
	var card := _places[place]
	if card.has_meta("player") and not card.disabled:
		open_drivers(card.get_meta("player"))


func _on_portrait(look: String, picture: Texture2D) -> void:
	for card in _places:
		card.show_portrait(look, picture)


## Opens the driver cards for my player `index` (1 is a second player on
## this phone). There's no New driver card, since the driver screen would
## leave the lobby.
func open_drivers(index: int) -> DriverWindow:
	var two := driver_cards.size() > 1
	var second := index == 1
	var taken := Game.driver_choice() if second else ""
	var window := DriverWindow.open(self, Game.driver_choice(second), taken, (index + 1) if two else 0, false)
	window.picked.connect(pick_driver.bind(index))
	return window


## Races my player `index` as the driver with this pick key, and tells the
## host. It can't be changed once a race is set up.
func pick_driver(key: String, index := 0) -> void:
	if not Game.net.setup.is_empty():
		return
	Game.set_driver_choice(key, index == 1)
	var design := CharacterDesign.for_key(key)
	if index < driver_cards.size():
		driver_cards[index].show_driver(design)
		if driver_cards[index].wants_portrait():
			_portraits.take(design)
	Game.net.set_driver(index, design.to_dict())


func _show_settings(host: bool) -> void:
	var s: Dictionary = Game.net.settings
	_right.visible = not s.is_empty()
	_header.visible = not s.is_empty()
	if s.is_empty():
		return
	var cup: bool = s.mode == NetSession.CUP
	var ai := bool(s.get("ai", true))
	var weather: String = s.get("weather", Conditions.RANDOM)
	var time: String = s.get("time", Conditions.RANDOM)
	_weather.text = "Any weather" if weather == Conditions.RANDOM else Conditions.WEATHER_NAMES.get(weather, "Any weather")
	_time.text = "Any time" if time == Conditions.RANDOM else Conditions.TIME_NAMES.get(time, "Any time")
	MenuStyle.snug(_reverse, bool(s.get("reversed", false)), PILL_HIGH)
	MenuStyle.snug(_mirror, bool(s.get("mirrored", false)), PILL_HIGH)
	_ai.icon = _switch(ai)
	_difficulty.text = Difficulty.name_of(str(s.get("difficulty", Difficulty.DEFAULT)))
	_difficulty.visible = ai
	for b in [_weather, _time, _reverse, _mirror, _ai, _difficulty]:
		b.disabled = not host

	if cup:
		_show_cup(s.get("cup", {}))
	else:
		_show_course(s.get("course", {}))
	_window_button.disabled = not host
	_window_button.focus_mode = FOCUS_ALL if host else FOCUS_NONE
	_light_window()
	for b in _modes:
		MenuStyle.snug(b, s.mode == b.get_meta("mode"), UiKit.BUTTON_HEIGHT)
		b.disabled = not host
	_fewer.visible = not cup
	_more.visible = not cup
	_fewer.disabled = not host
	_more.disabled = not host
	if cup:
		var races: int = s.get("cup", {}).get("courses", []).size()
		_laps.text = "%d race%s" % [races, "" if races == 1 else "s"]
	else:
		_laps.text = "%d lap%s" % [int(s.laps), "" if int(s.laps) == 1 else "s"]
	for child in _keep.get_children():
		child.queue_free()
	_keep.visible = false
	if not host:
		_offer_to_keep(s, cup)


## The course's still in the window, or just its name for one of yours.
func _show_course(course: Dictionary) -> void:
	var id := _course_id(str(course.get("name", "")))
	if id != "" and ResourceLoader.exists(RaceWindow.still_path(id)):
		_window.show_course(id)
	else:
		_window.show_picture(null, str(course.get("name", "A course")))
	_trophy_key = ""


## The cup's trophy in the window, in gold.
func _show_cup(cup: Dictionary) -> void:
	var title := str(cup.get("name", "No cup picked"))
	var spec := TrophyModel.spec_for(title)
	var colour := TrophyModel.colour_for(title)
	for game_cup in GrandPrix.cups():
		if game_cup.name == title:
			spec = game_cup.get("trophy", {})
			colour = Color(game_cup.get("colour", "#a3a2a4"))
	var finish := TrophyModel.finish_for(1)
	_trophy_key = TrophyThumbnails.key_of(spec, colour, finish)
	_window.show_picture(TrophyThumbnails.picture(_trophy_key), title, true)
	if TrophyThumbnails.picture(_trophy_key) == null:
		Game.trophy_pictures().take(spec, colour, finish)


func _on_trophy(key: String, picture: Texture2D) -> void:
	if key == _trophy_key:
		_window.show_picture(picture, _window.course_name, true)


static var _course_ids := {}


## The id of the game's course with this name, or "" for one of yours.
static func _course_id(course_name: String) -> String:
	if _course_ids.is_empty():
		for id in Tracks.all():
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(id)))
			if data is Dictionary:
				_course_ids[str(data.get("name", ""))] = str(id)
	return _course_ids.get(course_name, "")


func _fit_window() -> void:
	_window_button.custom_minimum_size.y = clampf(floorf(_right.size.x / RaceWindow.SHAPE) + 16.0, 160.0, 300.0)


func _light_window() -> void:
	_window.lit = not _window_button.disabled and (_window_button.has_focus() or _window_button.is_hovered())


## The AI switch's picture, on or off.
static func _switch(on: bool) -> Texture2D:
	if not _switches.has(on):
		var image := UiKit.switch_picture(on, 1.0).get_image()
		image.resize(46, 22, Image.INTERPOLATE_LANCZOS)
		_switches[on] = ImageTexture.create_from_image(image)
	return _switches[on]


## Start for the host. A joiner says they're ready with it, then it waits
## for the host, and tapping it again takes it back.
func _show_start(host: bool) -> void:
	var me: Dictionary = Game.net.members.get(Game.net.my_id(), {})
	var waiting := not host and bool(me.get("ready", false))
	_start.size_flags_horizontal = SIZE_SHRINK_END if host else SIZE_FILL
	if host:
		_start.text = "Start"
		_start.disabled = not Game.net.can_start()
	else:
		_start.text = "Waiting for the host" if waiting else "I'm ready"
		_start.disabled = Game.net.members.is_empty()
	for state in ["normal", "hover", "pressed"]:
		if waiting:
			_start.add_theme_stylebox_override(state, _start.get_theme_stylebox("disabled", "MainButton"))
		else:
			_start.remove_theme_stylebox_override(state)
	for colour in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		if waiting:
			_start.add_theme_color_override(colour, _start.get_theme_color("font_disabled_color", "MainButton"))
		else:
			_start.remove_theme_color_override(colour)


func _start_or_ready() -> void:
	if Game.net.is_host():
		Game.net.start()
	else:
		var me: Dictionary = Game.net.members.get(Game.net.my_id(), {})
		Game.net.set_ready(not me.get("ready", false))


## Puts weather, time, reverse, mirrored and AI in the header if they fit
## beside the title and Leave, or in the Options window if not.
func _fit_header() -> void:
	if _margin == null:
		return
	var across := _margin.get_viewport_rect().size.x - _margin.get_theme_constant("margin_left") - _margin.get_theme_constant("margin_right")
	var between := _header.get_theme_constant("separation")
	var room := across - _title.get_combined_minimum_size().x - _leave.get_combined_minimum_size().x - UiKit.GAP_M * 2
	var need := 0.0
	var pills := [_weather, _time, _reverse, _mirror, _ai]
	if _difficulty.visible:
		pills.append(_difficulty)
	for b: Button in pills:
		need += b.get_combined_minimum_size().x + between
	var fold := need - between > room
	if fold == folded and _options.get_parent() != null and (_options.visible == fold):
		return
	folded = fold
	var had_focus := get_viewport().gui_get_focus_owner()
	for b in [_weather, _time, _reverse, _mirror, _ai]:
		b.get_parent().remove_child(b)
		if fold:
			b.size_flags_horizontal = SIZE_FILL
			_options_list.add_child(b)
		else:
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			_header.add_child(b)
	_header.move_child(_difficulty, -1)
	_options.visible = fold
	_difficulty.size_flags_horizontal = SIZE_SHRINK_END if fold else SIZE_EXPAND_FILL
	if not fold and _options_window.visible:
		_options_window.hide()
	if had_focus is Control and is_instance_valid(had_focus) and had_focus.is_visible_in_tree():
		had_focus.grab_focus()


## A button to keep the host's own course or cup, when it isn't one of the
## game's and you haven't got it already.
func _offer_to_keep(s: Dictionary, cup: bool) -> void:
	var data: Dictionary = Sharing.cup_from_online(s.cup) if cup else s.course
	var found := Sharing.read(JSON.stringify(data))
	if found.has("why"):
		return
	if not cup and Sharing.is_the_games(Sharing.COURSE, found.data):
		return
	if cup and GrandPrix.cups().any(func(c): return c.name == found.data.name) and found.data.races.all(func(r): return str(r.from) != ""):
		return
	_keep.visible = true
	var have := Sharing.yours_already(found.kind, found.data)
	if have != "":
		var kept := Label.new()
		kept.text = "It's with your cups" if cup else "It's with your courses"
		kept.theme_type_variation = "AccentLabel"
		_keep.add_child(kept)
		return
	_keep.add_child(MenuStyle.chip("Keep this cup" if cup else "Keep this course", func() -> void:
		Sharing.add(found)
		_show()))


func _set_mode(mode: String) -> void:
	var changes := {"mode": mode}
	if mode == NetSession.CUP and Game.net.settings.cup.is_empty():
		changes.cup = _game_cup(GrandPrix.cups()[0])
	Game.net.set_settings(changes)


## The list of courses (for one race) or cups to pick from.
func _pick() -> void:
	if not Game.net.is_host():
		return
	for child in _picker_list.get_children():
		child.queue_free()
	if Game.net.settings.mode == NetSession.CUP:
		_picker_list.add_child(MenuStyle.heading("The game's cups"))
		for cup in GrandPrix.cups():
			_picker_list.add_child(_choice(cup.name, {"cup": _game_cup(cup)}))
		var yours := CupDesign.saved()
		if not yours.is_empty():
			_picker_list.add_child(MenuStyle.heading("Your cups"))
			for path in yours:
				var mine := CupDesign.load_file(path)
				if mine != null and mine.problem() == "":
					_picker_list.add_child(_choice(mine.name, {"cup": {"name": mine.name, "made_by": mine.made_by, "courses": mine.races.map(func(r): return r.course)}}))
	else:
		for cup in GrandPrix.cups():
			_picker_list.add_child(MenuStyle.heading(cup.name))
			for id in cup.tracks:
				var course = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(id)))
				_picker_list.add_child(_choice(course.name, {"course": course, "laps": int(course.get("laps", 3))}))
		var yours := CourseDesign.saved()
		if not yours.is_empty():
			_picker_list.add_child(MenuStyle.heading("Your courses"))
			for path in yours:
				var mine := CourseDesign.load_file(path)
				if mine != null and mine.problems().is_empty():
					_picker_list.add_child(_choice(mine.name, {"course": mine.to_dict(), "laps": mine.laps}))
	_picker.popup_centered()
	# The old list is only freed at the end of the frame.
	PadFocus.focus_first.call_deferred(_picker_list)


func _choice(label: String, changes: Dictionary) -> Button:
	return MenuStyle.button(label, func() -> void:
		_picker.hide()
		Game.net.set_settings(changes))


## One of the game's cups, with its courses in it, to send to everyone.
static func _game_cup(cup: Dictionary) -> Dictionary:
	return {"name": cup.name, "courses": cup.tracks.map(func(id): return JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(id))))}


func go_back() -> void:
	Game.net.leave()
	Game.show_online()
