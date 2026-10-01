class_name RaceMenu
extends Control

## The menu you open in a race, from the button at the top, Start on a
## controller, Esc or Back. It covers that player's view, so in split screen
## each player has their own. In a single player race it pauses everything
## until you go back to it. In split screen and online the race carries on.
##
## It has the settings that make sense halfway round: the sound, your
## touch steering, your camera and map, and the frame rate.

signal resume_pressed
signal restart_pressed
signal quit_pressed

var race: Race
var racer: Race.Racer
## Which person this is, 0 for player 1.
var person := 0
## Whether the race is paused while this is open.
var pauses := true
## Whether there's a Restart, which there isn't in a Grand Prix or online.
var can_restart := true

var _camera_button: Button
var _map_button: Button
var _resume: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Game.theme
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BuilderStyle.scrim(16, 0.9))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(440.0, 0.0)
	scroll.add_child(column)

	var title := Label.new()
	title.text = "Paused" if pauses else "Menu"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_resume = BuilderStyle.main_pill("Resume", func() -> void: resume_pressed.emit())
	column.add_child(_resume)
	if can_restart:
		column.add_child(BuilderStyle.dark_pill("Restart", func() -> void: restart_pressed.emit()))

	for bus in [[Sounds.MUSIC_BUS, "Music"], [Sounds.EFFECTS_BUS, "Effects"]]:
		var name: String = bus[0]
		column.add_child(_row(bus[1], MenuStyle.slider(Game.volume(name), func(value: float) -> void:
			Game.set_volume(name, value)
			if name == Sounds.EFFECTS_BUS:
				Sounds.play("fx/click"))))

	if racer.hud != null and racer.hud.touch != null and DisplayServer.is_touchscreen_available():
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", 8)
		var buttons := {}
		for how in TouchControls.STEERING:
			var button := MenuStyle.button(TouchControls.STEERING[how], func() -> void:
				Game.set_steering(person, how)
				racer.hud.touch.steering = how
				for other in buttons:
					MenuStyle.mark(buttons[other], other == how))
			button.custom_minimum_size = Vector2(130.0, 48.0)
			buttons[how] = button
			choices.add_child(button)
		for how in buttons:
			MenuStyle.mark(buttons[how], how == Game.steering(person))
		column.add_child(_row("Steering", choices))

	if racer.camera != null:
		_camera_button = MenuStyle.button(RaceCamera.NAMES[racer.camera.view], func() -> void:
			racer.camera.next_view()
			_camera_button.text = RaceCamera.NAMES[racer.camera.view])
		_camera_button.custom_minimum_size = Vector2(220.0, 48.0)
		column.add_child(_row("Camera", _camera_button))
	if racer.hud != null and racer.hud.map != null:
		_map_button = MenuStyle.button(CourseMap.NAMES[racer.hud.map.mode], _next_map)
		_map_button.custom_minimum_size = Vector2(220.0, 48.0)
		column.add_child(_row("Map", _map_button))

	var fps := CheckButton.new()
	fps.focus_mode = Control.FOCUS_NONE
	fps.button_pressed = Game.show_fps()
	fps.toggled.connect(func(on: bool) -> void: Game.set_setting("display", "show_fps", on))
	column.add_child(_row("Frame rate", fps))

	column.add_child(BuilderStyle.dark_pill("Quit the race", func() -> void: quit_pressed.emit()))
	# No taller than the view it's in, scrolling if it has to.
	var room := get_viewport_rect().size.y - 40.0
	scroll.custom_minimum_size = Vector2(440.0, minf(column.get_combined_minimum_size().y, room))
	panel.reset_size()
	panel.position = (get_viewport_rect().size - panel.size) * 0.5


## A setting's name on the left and what changes it on the right.
func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if control is HSlider:
		control.custom_minimum_size.x = 240.0
	row.add_child(control)
	return row


func _next_map() -> void:
	var map: CourseMap = racer.hud.map
	var mode: String = CourseMap.MODES[(CourseMap.MODES.find(map.mode) + 1) % CourseMap.MODES.size()]
	map.mode = mode
	Game.set_map_view(person, mode)
	_map_button.text = CourseMap.NAMES[mode]


## Start or B on the controller closes it again, and so does Esc (through
## Race.go_back).
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_START, JOY_BUTTON_B]:
		if racer.input == null or racer.input.owns_joypad(event.device):
			get_viewport().set_input_as_handled()
			resume_pressed.emit()
