class_name RaceMenu
extends Control

## The menu you open in a race, from the button at the top, Start on a
## controller, Esc or Back. Off the network it pauses everything until you
## go back to it, and in split screen it's one menu over the whole screen
## for both players, with the settings of whoever opened it. Online each
## player has their own over their view and the race carries on. Start and B
## close it (see Race._menu_keys).
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
## Whether it picks out Resume when it opens with a controller.
var focus_on_open := true
## Whether there's a Restart, which there isn't in a Grand Prix or online.
var can_restart := true

var _camera_button: Button
var _map_button: Button
var _resume: Button

const COLUMN := 440.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Game.theme
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(UiKit.INK, 0.7)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.popup())
	add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiKit.GAP_XL)
	scroll.add_child(body)
	# The title and the buttons, then the settings. On a wide view they sit side
	# by side, otherwise in one column with Quit last.
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", UiKit.GAP_M)
	main.custom_minimum_size = Vector2(COLUMN, 0.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiKit.GAP_M)
	column.custom_minimum_size = Vector2(COLUMN, 0.0)

	var title := Label.new()
	title.text = "Paused" if pauses else "Menu"
	title.theme_type_variation = "HeadingLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)
	var restart: Button = null
	_resume = BuilderStyle.main_pill("Resume", func() -> void: resume_pressed.emit())
	main.add_child(_resume)
	if can_restart:
		restart = BuilderStyle.dark_pill("Restart", func() -> void: restart_pressed.emit())
		main.add_child(restart)

	for bus in [[Sounds.MUSIC_BUS, "Music"], [Sounds.EFFECTS_BUS, "Effects"]]:
		var name: String = bus[0]
		column.add_child(_row(bus[1], MenuStyle.slider(Game.volume(name), func(value: float) -> void:
			Game.set_volume(name, value)
			if name == Sounds.EFFECTS_BUS:
				Sounds.play("fx/click"))))

	if racer.hud != null and racer.hud.touch != null and DisplayServer.is_touchscreen_available():
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", UiKit.GAP_S)
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
		var sizes := HBoxContainer.new()
		sizes.add_theme_constant_override("separation", UiKit.GAP_S)
		var size_buttons := {}
		for pick in TouchControls.SIZES:
			var button := MenuStyle.button(TouchControls.SIZES[pick], func() -> void:
				Game.set_touch_size(pick)
				for touch in _touches():
					touch.control_size = pick
				for other in size_buttons:
					MenuStyle.mark(size_buttons[other], other == pick))
			button.custom_minimum_size = Vector2(110.0, 48.0)
			size_buttons[pick] = button
			sizes.add_child(button)
		for pick in size_buttons:
			MenuStyle.mark(size_buttons[pick], pick == Game.touch_size())
		column.add_child(_row("Controls size", sizes))
		var raise := func(value: float) -> void:
			Game.set_touch_height(value)
			var touches := _touches()
			for touch in touches:
				touch.height = TouchControls.height_for(value, touches.size() > 1)
		column.add_child(_row("Controls height", MenuStyle.slider(Game.touch_height(), raise, TouchControls.HEIGHT_LOWEST, TouchControls.HEIGHT_HIGHEST, 0.05)))

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
	fps.focus_mode = Control.FOCUS_ALL
	fps.button_pressed = Game.show_fps()
	fps.toggled.connect(func(on: bool) -> void: Game.set_setting("display", "show_fps", on))
	column.add_child(_row("Frame rate", fps))

	var quit := BuilderStyle.dark_pill("Quit the race", func() -> void: quit_pressed.emit())
	main.add_child(quit)

	# Two columns when the view is wide enough for them, else one.
	var view := get_viewport_rect().size
	var gap := float(UiKit.GAP_XL)
	var margins := 34.0 + 24.0 + 40.0
	var two := view.x > view.y and view.x >= 2.0 * COLUMN + gap + margins
	if two:
		body.add_child(main)
		body.add_child(column)
		_link_columns(main, column)
	else:
		main.remove_child(quit)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", UiKit.GAP_M)
		if restart != null:
			main.remove_child(restart)
			restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buttons.add_child(restart)
		quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(quit)
		var column_count := column.get_child_count()
		var all := VBoxContainer.new()
		all.add_theme_constant_override("separation", UiKit.GAP_M)
		all.custom_minimum_size = Vector2(COLUMN, 0.0)
		for child in main.get_children():
			main.remove_child(child)
			all.add_child(child)
		all.add_child(buttons)
		for child in column.get_children():
			column.remove_child(child)
			all.add_child(child)
		var first := _focusable(all.get_child(all.get_child_count() - column_count))
		if not first.is_empty():
			for button in _focusable(buttons):
				button.focus_neighbor_bottom = button.get_path_to(first[0])
			first[0].focus_neighbor_top = first[0].get_path_to(quit)
		main.free()
		column.free()
		body.add_child(all)
	# No taller than the view it's in, scrolling if it has to.
	var room := view.y - 40.0
	scroll.custom_minimum_size = Vector2(body.get_combined_minimum_size().x, minf(body.get_combined_minimum_size().y, room))
	panel.reset_size()
	panel.position = (view - panel.size) * 0.5
	if PadFocus.using_pad and focus_on_open:
		_resume.grab_focus.call_deferred()


## Lets left and right cross between the two columns. A slider keeps left and
## right for itself, so the way back from there is up from the first setting.
func _link_columns(left: Control, right: Control) -> void:
	var mine := _focusable(left)
	var theirs := _focusable(right)
	if mine.is_empty() or theirs.is_empty():
		return
	for control in mine:
		control.focus_neighbor_right = control.get_path_to(theirs[0])
	for control in theirs:
		if not control is Slider and control.get_parent() is HBoxContainer:
			var row := control.get_parent()
			if _focusable(row)[0] == control:
				control.focus_neighbor_left = control.get_path_to(mine[0])
	theirs[0].focus_neighbor_top = theirs[0].get_path_to(mine[-1])
	mine[-1].focus_neighbor_bottom = mine[-1].get_path_to(theirs[0])


func _focusable(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for child in root.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			out.append(child)
		out.append_array(_focusable(child))
	return out


## Every player's touch controls in this race, which share their size and
## height.
func _touches() -> Array[TouchControls]:
	var out: Array[TouchControls] = []
	if race != null:
		for human in race.humans:
			if human.hud != null and human.hud.touch != null:
				out.append(human.hud.touch)
	if out.is_empty() and racer.hud != null and racer.hud.touch != null:
		out.append(racer.hud.touch)
	return out


## A setting's name on the left and what changes it on the right.
func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if control is HSlider:
		control.custom_minimum_size.x = 240.0
	row.add_child(control)
	return row


func _next_map() -> void:
	var map: CourseMap = racer.hud.map
	var mode := map.next_mode()
	map.mode = mode
	# The map two players share is kept as player 1's.
	Game.set_map_view(0 if map.shared() else person, mode)
	_map_button.text = CourseMap.NAMES[mode]
