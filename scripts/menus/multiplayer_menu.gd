class_name MultiplayerMenu
extends Control

## Racing with other people: two people on one phone, sharing the screen
## side by side (landscape, half each) or face to face (portrait, with the
## phone flat between them), against six AI karts in one race or a Grand
## Prix, or online against people on other devices. Each player picks their
## kart once the course or cup is picked (see KartPicker). A chip per player
## shows their controller; tap it and press a button on the controller to
## give it to them.

const LAYOUTS := [
	[Game.SIDE_BY_SIDE, "Side by side"],
	[Game.FACE_TO_FACE, "Face to face"],
]

var _layout_buttons: Array[Button] = []
var _window: RaceWindow
var _chips: Array[Button] = []
var _chip_words: Array[Label] = []
## The player waiting for a button on their controller, or -1.
var _waiting := -1


func _ready() -> void:
	# Two players always share the screen one way or the other.
	if Game.split() == Game.SOLO:
		Game.set_setting("race", "split", Game.SIDE_BY_SIDE)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", UiKit.GAP_M)
	_window = RaceWindow.new()
	_window.pick_at_random = false
	_window.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(_window)
	var layouts := HBoxContainer.new()
	layouts.add_theme_constant_override("separation", UiKit.GAP_M)
	right.add_child(layouts)
	for layout in LAYOUTS:
		var button := MenuStyle.button(layout[1], _set_layout.bind(layout[0]))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.set_meta("mode", layout[0])
		layouts.add_child(button)
		_layout_buttons.append(button)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", UiKit.GAP_M)
	right.add_child(chips)
	for person in Controllers.PLAYERS:
		chips.add_child(_chip(person))

	var parts := MenuStyle.menu_parts(self, "Two players", right)
	var steps: Container = parts.steps
	steps.add_child(MenuStyle.big_button("Grand Prix", "trophy", Game.show_cups.bind(true), "Cups of four races, for two"))
	steps.add_child(MenuStyle.big_button("Single race", "race", Game.show_tracks.bind(Game.MODE_RACE), "Any course, for two"))
	steps.add_child(MenuStyle.big_button("Online", "two", Game.show_online, "Host or join a game"))
	parts.top.add_child(MenuStyle.link("Back", go_back, "back"))
	if Game.controllers != null:
		Game.controllers.changed.connect(_show_chips)
	_show()
	_show_chips()


## A player's colour tag with their controller beside it.
func _chip(person: int) -> Button:
	var b := Button.new()
	b.theme_type_variation = "CardButton"
	b.focus_mode = FOCUS_ALL
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 52)
	b.set_meta("player", person)
	b.pressed.connect(_wait.bind(person))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_child(MenuStyle.tag("P%d" % (person + 1), UiKit.PLAYERS[person]))
	var label := Label.new()
	label.theme_type_variation = "LeadLabel"
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 20)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	_chips.append(b)
	_chip_words.append(label)
	return b


func _set_layout(layout: String) -> void:
	Game.set_setting("race", "split", layout)
	_show()


## Lights up the chosen layout and draws it.
func _show() -> void:
	for button in _layout_buttons:
		MenuStyle.mark(button, button.get_meta("mode") == Game.split())
	_window.split = Game.split()


## Each player's controller, or what to do while one's being given.
func _show_chips() -> void:
	if not is_inside_tree():
		return
	for person in _chips.size():
		var device := Game.controllers.device_of(person) if Game.controllers != null else -1
		var words := Controllers.name_of(device) if device != -1 else "No controller"
		if person == _waiting:
			words = "Press a button on it"
		_chip_words[person].text = words
		_chip_words[person].tooltip_text = words
		MenuStyle.mark(_chips[person], person == _waiting)


## Waits for a button on the controller for this player. Tapping it again or
## Esc stops waiting.
func _wait(person: int) -> void:
	_waiting = -1 if _waiting == person or Game.controllers == null else person
	_show_chips()


func _input(event: InputEvent) -> void:
	if _waiting == -1:
		return
	# While it waits, keys and controllers don't move round the menu.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_waiting = -1
		_show_chips()
	elif event is InputEventJoypadButton and event.pressed:
		var person := _waiting
		_waiting = -1
		Game.controllers.give(event.device, person)
		_show_chips()


func go_back() -> void:
	Game.show_menu()
