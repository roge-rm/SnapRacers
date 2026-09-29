class_name Lobby
extends Control

## An online game before (and between) races. Everyone in it is listed with
## their kart. The host picks what's raced: one race or a cup, which course
## or cup (the game's or their own, sent to everyone), how many laps, and
## whether AI drivers fill the empty places. Everyone says they're ready, and
## the host starts it.

var _status: Label
var _people: VBoxContainer
var _settings: VBoxContainer
var _ready_button: Button
var _start: Button
var _finder: GameFinder
var _picker: PopupPanel
var _picker_list: VBoxContainer
## How hosting over Wi-Fi Direct is going.
var _direct_status := "Starting Wi-Fi Direct..."


func _ready() -> void:
	var column := MenuStyle.page(self, "Lobby", go_back, 760.0)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", BuilderStyle.DATA)
	column.add_child(_status)
	column.add_child(MenuStyle.heading("Who's racing"))
	_people = VBoxContainer.new()
	_people.add_theme_constant_override("separation", 6)
	column.add_child(_people)
	column.add_child(MenuStyle.heading("The race"))
	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 10)
	column.add_child(_settings)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	_ready_button = MenuStyle.button("I'm ready", func() -> void:
		var me: Dictionary = Game.net.members.get(Game.net.my_id(), {})
		Game.net.set_ready(not me.get("ready", false)))
	_ready_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_ready_button.custom_minimum_size.y = 72.0
	row.add_child(_ready_button)
	_start = MenuStyle.button("Start", Game.net.start)
	_start.size_flags_horizontal = SIZE_EXPAND_FILL
	_start.custom_minimum_size.y = 72.0
	row.add_child(_start)
	MenuStyle.back_at_bottom(column, go_back, "Leave")

	_picker = PopupPanel.new()
	_picker.theme = MenuStyle.theme()
	_picker.add_theme_stylebox_override("panel", BuilderStyle.scrim(12, 0.9))
	add_child(_picker)
	var scroll := ScrollContainer.new()
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
	Game.net.changed.connect(_show)
	_show()


func _exit_tree() -> void:
	if Game.net.changed.is_connected(_show):
		Game.net.changed.disconnect(_show)


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
		_status.text = "Others can join at %s" % (addresses[0] if not addresses.is_empty() else "this phone's address")
	else:
		_status.text = "Waiting for the host to start"
	if _finder != null:
		_finder.advertise({"name": Game.game_name(), "players": net.player_count(), "most": NetSession.MOST_KARTS, "port": NetSession.PORT, "version": NetSession.VERSION})

	for child in _people.get_children():
		child.queue_free()
	var ids := net.members.keys()
	ids.sort()
	for peer in ids:
		var member: Dictionary = net.members[peer]
		for player in member.players:
			var line := Label.new()
			var kart := str(player.get("kart", {}).get("name", "a kart"))
			line.text = "%s   %s, in the %s" % ["✓" if member.ready else "·", player.name, kart]
			line.add_theme_font_size_override("font_size", 22)
			if peer == net.my_id():
				line.add_theme_color_override("font_color", Color("#f2cd37"))
			_people.add_child(line)
	if net.settings.get("ai", true) and net.player_count() < NetSession.MOST_KARTS:
		var fill := Label.new()
		fill.text = "     and %d AI driver%s" % [NetSession.MOST_KARTS - net.player_count(), "" if NetSession.MOST_KARTS - net.player_count() == 1 else "s"]
		fill.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		_people.add_child(fill)

	_show_settings(host)
	var me: Dictionary = net.members.get(net.my_id(), {})
	_ready_button.visible = net.role == NetSession.Role.CLIENT
	_ready_button.text = "Not ready after all" if me.get("ready", false) else "I'm ready"
	_start.visible = host
	_start.disabled = not net.can_start()


func _show_settings(host: bool) -> void:
	for child in _settings.get_children():
		child.queue_free()
	var s: Dictionary = Game.net.settings
	if s.is_empty():
		return
	var cup: bool = s.mode == NetSession.CUP
	if host:
		var modes := HBoxContainer.new()
		modes.add_theme_constant_override("separation", 10)
		_settings.add_child(modes)
		for pair in [[NetSession.SINGLE, "One race"], [NetSession.CUP, "A cup"]]:
			var button := MenuStyle.button(pair[1], _set_mode.bind(pair[0]))
			button.size_flags_horizontal = SIZE_EXPAND_FILL
			MenuStyle.mark(button, s.mode == pair[0])
			modes.add_child(button)
	var what := "%s, %d races" % [s.cup.get("name", "No cup picked"), s.cup.get("courses", []).size()] if cup else "%s, %d laps" % [s.course.get("name", "A course"), int(s.laps)]
	if host:
		_settings.add_child(MenuStyle.button(what + "   ›", _pick))
		if not cup:
			var laps := HBoxContainer.new()
			laps.add_theme_constant_override("separation", 10)
			_settings.add_child(laps)
			laps.add_child(MenuStyle.button("Fewer laps", func() -> void: Game.net.set_settings({"laps": maxi(int(s.laps) - 1, 1)})))
			laps.add_child(MenuStyle.button("More laps", func() -> void: Game.net.set_settings({"laps": mini(int(s.laps) + 1, 9)})))
		var ai_row := HBoxContainer.new()
		_settings.add_child(ai_row)
		var heading := MenuStyle.heading("AI drivers in the empty places")
		heading.size_flags_horizontal = SIZE_EXPAND_FILL
		ai_row.add_child(heading)
		var toggle := CheckButton.new()
		toggle.focus_mode = FOCUS_NONE
		toggle.button_pressed = s.ai
		toggle.toggled.connect(func(on: bool) -> void: Game.net.set_settings({"ai": on}))
		ai_row.add_child(toggle)
		if s.ai:
			var levels := HBoxContainer.new()
			levels.add_theme_constant_override("separation", 8)
			_settings.add_child(levels)
			for level in Difficulty.LEVELS:
				var button := MenuStyle.button(Difficulty.name_of(level), func() -> void: Game.net.set_settings({"difficulty": level}))
				button.size_flags_horizontal = SIZE_EXPAND_FILL
				MenuStyle.mark(button, s.difficulty == level)
				levels.add_child(button)
	else:
		var label := Label.new()
		label.text = "%s\n%s" % [what, ("AI drivers in the empty places, %s" % Difficulty.name_of(s.difficulty).to_lower()) if s.ai else "No AI drivers"]
		label.add_theme_font_size_override("font_size", 22)
		_settings.add_child(label)


func _set_mode(mode: String) -> void:
	var changes := {"mode": mode}
	if mode == NetSession.CUP and Game.net.settings.cup.is_empty():
		changes.cup = _game_cup(GrandPrix.cups()[0])
	Game.net.set_settings(changes)


## The list of courses (for one race) or cups to pick from.
func _pick() -> void:
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
					_picker_list.add_child(_choice(mine.name, {"cup": {"name": mine.name, "courses": mine.races.map(func(r): return r.course)}}))
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
