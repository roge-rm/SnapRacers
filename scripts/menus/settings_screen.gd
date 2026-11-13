class_name SettingsScreen
extends Control

## Settings, in tabs. Everything saves as soon as you change it.

const TABS := ["Player", "Controls", "Sound", "Display"]

var _tab_buttons: Array[Button] = []
var _underlines: Array[ColorRect] = []
var _pages: Array[Control] = []


func _ready() -> void:
	var column := MenuStyle.page(self, "Settings", Game.show_menu)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	column.add_child(tabs)
	for i in TABS.size():
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_constant_override("separation", 0)
		tabs.add_child(slot)
		var tab := Button.new()
		tab.text = TABS[i]
		tab.theme_type_variation = "TabButton"
		tab.focus_mode = Control.FOCUS_ALL
		tab.pressed.connect(_show_tab.bind(i))
		slot.add_child(tab)
		var line := ColorRect.new()
		line.custom_minimum_size = Vector2(0.0, 4.0)
		slot.add_child(line)
		_tab_buttons.append(tab)
		_underlines.append(line)

	_pages.append(_player_page())
	_pages.append(_controls_page())
	_pages.append(_sound_page())
	_pages.append(_display_page())
	for page in _pages:
		column.add_child(page)
	MenuStyle.back_at_bottom(column, Game.show_menu)
	_show_tab(0)


## LB and RB on a controller go to the tab before or after.
func next_tab(by: int) -> void:
	var now := _pages.find(_pages.filter(func(p): return p.visible)[0])
	_show_tab(posmod(now + by, TABS.size()))
	PadFocus.focus_first(_pages[posmod(now + by, TABS.size())])


func _show_tab(index: int) -> void:
	for i in TABS.size():
		var on := i == index
		_pages[i].visible = on
		_underlines[i].color = UiKit.ACCENT if on else UiKit.EDGE
		MenuStyle.mark_tab(_tab_buttons[i], on)


func _player_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.add_child(MenuStyle.heading("Name"))
	var name_edit := LineEdit.new()
	PadKeyboard.attach(name_edit)
	name_edit.placeholder_text = "You"
	name_edit.max_length = 20
	name_edit.text = Game.settings.get_value("player", "name", "")
	name_edit.text_changed.connect(func(text: String) -> void: Game.set_setting("player", "name", text.strip_edges()))
	page.add_child(name_edit)
	var row := HBoxContainer.new()
	page.add_child(row)
	var heading := MenuStyle.heading("Driver picker before karts")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.button_pressed = Game.driver_picker_step()
	toggle.toggled.connect(func(on: bool) -> void: Game.set_setting("race", "driver_picker", on))
	row.add_child(toggle)
	var own_row := HBoxContainer.new()
	page.add_child(own_row)
	var own_heading := MenuStyle.heading("AI can use your drivers")
	own_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own_row.add_child(own_heading)
	var own_toggle := CheckButton.new()
	own_toggle.focus_mode = Control.FOCUS_ALL
	own_toggle.button_pressed = Game.ai_own_drivers()
	own_toggle.toggled.connect(func(on: bool) -> void: Game.set_setting("race", "ai_own_drivers", on))
	own_row.add_child(own_toggle)
	return page


func _controls_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.add_child(MenuStyle.heading("Touch steering"))
	for person in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		page.add_child(row)
		var who := Label.new()
		who.text = "Player %d" % (person + 1)
		who.custom_minimum_size = Vector2(120.0, 0.0)
		row.add_child(who)
		var choices := {}
		for how in TouchControls.STEERING:
			var button := MenuStyle.button(TouchControls.STEERING[how], func() -> void:
				Game.set_steering(person, how)
				for other in choices:
					MenuStyle.mark(choices[other], other == how))
			button.custom_minimum_size = Vector2(160.0, 48.0)
			choices[how] = button
			row.add_child(button)
		for how in choices:
			MenuStyle.mark(choices[how], how == Game.steering(person))
	page.add_child(MenuStyle.heading("Touch controls"))
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 10)
	page.add_child(size_row)
	var size_label := Label.new()
	size_label.text = "Size"
	size_label.custom_minimum_size = Vector2(120.0, 0.0)
	size_row.add_child(size_label)
	var sizes := {}
	for pick in TouchControls.SIZES:
		var button := MenuStyle.button(TouchControls.SIZES[pick], func() -> void:
			Game.set_touch_size(pick)
			for other in sizes:
				MenuStyle.mark(sizes[other], other == pick))
		button.custom_minimum_size = Vector2(160.0, 48.0)
		sizes[pick] = button
		size_row.add_child(button)
	for pick in sizes:
		MenuStyle.mark(sizes[pick], pick == Game.touch_size())
	var height_row := HBoxContainer.new()
	height_row.add_theme_constant_override("separation", 10)
	page.add_child(height_row)
	var height_label := Label.new()
	height_label.text = "Height"
	height_label.custom_minimum_size = Vector2(120.0, 0.0)
	height_row.add_child(height_label)
	height_row.add_child(MenuStyle.slider(Game.touch_height(), Game.set_touch_height, TouchControls.HEIGHT_LOWEST, TouchControls.HEIGHT_HIGHEST, 0.05))
	page.add_child(ControlsPage.new())
	return page


func _sound_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	for bus in [[Sounds.MUSIC_BUS, "Music", ""], [Sounds.EFFECTS_BUS, "Effects", ""]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		page.add_child(row)
		var heading := MenuStyle.heading(bus[1], bus[2])
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(heading)
		var name: String = bus[0]
		row.add_child(MenuStyle.slider(Game.volume(name), func(value: float) -> void:
			Game.set_volume(name, value)
			# A click at the new level, so you can hear how loud it is.
			if name == Sounds.EFFECTS_BUS:
				Sounds.play("fx/click")))
	return page


func _display_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.add_child(MenuStyle.heading("Graphics"))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 10)
	page.add_child(levels)
	var buttons := {}
	for level in Graphics.LEVELS:
		var button := MenuStyle.button(Graphics.NAMES[level], func() -> void:
			Game.set_graphics(level)
			for other in buttons:
				MenuStyle.mark(buttons[other], other == level))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuStyle.mark(button, level == Game.graphics())
		buttons[level] = button
		levels.add_child(button)
	var row := HBoxContainer.new()
	page.add_child(row)
	var heading := MenuStyle.heading("Show frame rate")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.button_pressed = Game.show_fps()
	toggle.toggled.connect(func(on: bool) -> void: Game.set_setting("display", "show_fps", on))
	row.add_child(toggle)
	return page


func go_back() -> void:
	Game.show_menu()
