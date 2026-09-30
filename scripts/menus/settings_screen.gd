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
		tab.flat = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 24)
		tab.pressed.connect(_show_tab.bind(i))
		slot.add_child(tab)
		var line := ColorRect.new()
		line.custom_minimum_size = Vector2(0.0, 3.0)
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


func _show_tab(index: int) -> void:
	for i in TABS.size():
		var on := i == index
		_pages[i].visible = on
		_underlines[i].color = MenuStyle.ACCENT if on else Color(1.0, 1.0, 1.0, 0.12)
		var colour := MenuStyle.ACCENT if on else Color(1.0, 1.0, 1.0, 0.8)
		_tab_buttons[i].add_theme_color_override("font_color", colour)
		_tab_buttons[i].add_theme_color_override("font_hover_color", colour)


func _player_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.add_child(MenuStyle.heading("Name", "Shown in the results and to other players online"))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "You"
	name_edit.max_length = 20
	name_edit.text = Game.settings.get_value("player", "name", "")
	name_edit.text_changed.connect(func(text: String) -> void: Game.set_setting("player", "name", text.strip_edges()))
	page.add_child(name_edit)
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
		who.add_theme_font_size_override("font_size", 22)
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
	var row := HBoxContainer.new()
	page.add_child(row)
	var heading := MenuStyle.heading("Show frame rate")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.button_pressed = Game.show_fps()
	toggle.toggled.connect(func(on: bool) -> void: Game.set_setting("display", "show_fps", on))
	row.add_child(toggle)
	return page


func go_back() -> void:
	Game.show_menu()
