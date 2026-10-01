class_name ControlsPage
extends VBoxContainer

## The controllers and buttons part of Settings > Controls. It shows whose
## each controller is, and lets you give a controller to a player by pressing
## a button on it. Then for each player, every action with its key and its two
## controller buttons. Tap one and press the key or button you want for it,
## and an action that had it already gets the old one, so nothing's lost.

## Only whose controller is whose, for the split screen setup.
var owners_only := false

## The binding being changed, as [what, action, slot], what being "key",
## "pad" or "owner". Empty when nothing is.
var _waiting := []
var _person := 0
var _owners: VBoxContainer
var _grid: GridContainer
var _who: Array[Button] = []
var _prompt: Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	if not owners_only:
		add_child(MenuStyle.heading("Controllers", "With two players, each has their own"))
	_owners = VBoxContainer.new()
	_owners.add_theme_constant_override("separation", 8)
	add_child(_owners)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", MenuStyle.ACCENT)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.visible = false
	add_child(_prompt)
	if owners_only:
		if Game.controllers != null:
			Game.controllers.changed.connect(_show)
		_show()
		return

	add_child(MenuStyle.heading("Buttons", "Tap one, then press the key or button for it"))
	var players := HBoxContainer.new()
	players.add_theme_constant_override("separation", 10)
	add_child(players)
	for person in Controllers.PLAYERS:
		var button := MenuStyle.button("Player %d" % (person + 1), func() -> void:
			_person = person
			_show())
		button.custom_minimum_size = Vector2(160.0, 48.0)
		players.add_child(button)
		_who.append(button)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	var reset := MenuStyle.button("Put back how they were", func() -> void:
		InputBindings.reset(Game.settings, _person)
		Game.save_settings()
		_show())
	reset.custom_minimum_size = Vector2(0.0, 48.0)
	add_child(reset)
	if Game.controllers != null:
		Game.controllers.changed.connect(_show)
	_show()


func _show() -> void:
	if not is_inside_tree():
		return
	for child in _owners.get_children():
		child.queue_free()
	for person in Controllers.PLAYERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_owners.add_child(row)
		var label := Label.new()
		var device := Game.controllers.device_of(person) if Game.controllers != null else -1
		label.text = "Player %d   %s" % [person + 1, Controllers.name_of(device) if device != -1 else "No controller"]
		label.add_theme_font_size_override("font_size", 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var pick := MenuStyle.button("Change", _wait.bind(["owner", "", person]))
		pick.custom_minimum_size = Vector2(140.0, 44.0)
		row.add_child(pick)
	if owners_only:
		return
	for i in _who.size():
		MenuStyle.mark(_who[i], i == _person)

	for child in _grid.get_children():
		child.queue_free()
	for heading in ["", "Key", "Controller", "Or"]:
		var label := Label.new()
		label.text = heading
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		_grid.add_child(label)
	var settings := Game.settings
	for action in InputBindings.ACTIONS:
		var name := Label.new()
		name.text = InputBindings.NAMES[action]
		name.add_theme_font_size_override("font_size", 20)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(name)
		if action == "menu":
			# The menu's always Esc on a keyboard, which is Back everywhere.
			var esc := Label.new()
			esc.text = "Esc"
			esc.add_theme_font_size_override("font_size", 20)
			_grid.add_child(esc)
		else:
			_grid.add_child(_cell(InputBindings.key_name(InputBindings.key(settings, _person, action)), ["key", action, 0]))
		var pads := InputBindings.pad(settings, _person, action)
		for slot in InputBindings.PAD_SLOTS:
			_grid.add_child(_cell(InputBindings.pad_name(pads[slot]) if slot < pads.size() else "None", ["pad", action, slot]))


func _cell(text: String, what: Array) -> Button:
	var button := MenuStyle.button(text, _wait.bind(what))
	button.custom_minimum_size = Vector2(150.0, 44.0)
	button.add_theme_font_size_override("font_size", 18)
	if what == _waiting:
		MenuStyle.mark(button, true)
		button.text = "..."
	return button


## Waits for the next key or button for this binding.
func _wait(what: Array) -> void:
	_waiting = what
	match what[0]:
		"key":
			_prompt.text = "Press a key for %s, or Esc to leave it" % InputBindings.NAMES[what[1]]
		"pad":
			_prompt.text = "Press a button or push a stick for %s, or Esc to leave it. Back clears it." % InputBindings.NAMES[what[1]]
		"owner":
			_prompt.text = "Press a button on the controller for Player %d" % (what[2] + 1)
	_prompt.visible = true
	_show()


func _stop() -> void:
	_waiting = []
	_prompt.visible = false
	_show()


func _input(event: InputEvent) -> void:
	if _waiting.is_empty():
		return
	var settings := Game.settings
	var person := _person
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_stop()
			return
		if _waiting[0] == "key":
			_swap_key(person, _waiting[1], event.physical_keycode)
			Game.save_settings()
			_stop()
		return
	if _waiting[0] == "owner":
		if event is InputEventJoypadButton and event.pressed:
			get_viewport().set_input_as_handled()
			Game.controllers.give(event.device, _waiting[2])
			_stop()
		return
	if _waiting[0] != "pad":
		return
	var input := InputBindings.from_event(event)
	if input.is_empty():
		return
	get_viewport().set_input_as_handled()
	if input == [InputBindings.BUTTON, JOY_BUTTON_BACK, 1] and _waiting[1] != "view":
		InputBindings.set_pad(settings, person, _waiting[1], _waiting[2], [])
	else:
		_swap_pad(person, _waiting[1], _waiting[2], input)
	Game.save_settings()
	_stop()


## Gives an action a key. Another action with that key gets this one's old
## key instead.
func _swap_key(person: int, action: String, code: Key) -> void:
	var settings := Game.settings
	var old := InputBindings.key(settings, person, action)
	for other in InputBindings.ACTIONS:
		if other != action and InputBindings.key(settings, person, other) == code:
			InputBindings.set_key(settings, person, other, old)
	InputBindings.set_key(settings, person, action, code)


## The same for a button or stick on a controller.
func _swap_pad(person: int, action: String, slot: int, input: Array) -> void:
	var settings := Game.settings
	var mine := InputBindings.pad(settings, person, action)
	var old: Array = mine[slot] if slot < mine.size() else []
	for other in InputBindings.ACTIONS:
		if other == action:
			continue
		var theirs := InputBindings.pad(settings, person, other)
		for i in theirs.size():
			if theirs[i] == input:
				InputBindings.set_pad(settings, person, other, i, old)
	InputBindings.set_pad(settings, person, action, slot, input)
