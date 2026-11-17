class_name ColourPalette
extends VBoxContainer

## Colour swatches for the garage and the driver screen: the colours used last
## along the top (once there are some), the main colours under them, both in
## the same number of columns, and a
## More colours button that opens a bigger grid, which closes after a pick. A
## + at the end of the Recent row opens the custom picker (ColourPicker).
## Every pick goes into Recent (see Paints).

signal picked(colour: Color)

var swatch_size := 42.0

var _current: Variant = null
var _main: Array[Color] = []
var _recent_row: GridContainer
var _recent: Array[Button] = []
var _grid: GridContainer
var _more_button: Button
var _more: PopupPanel
var _more_grid: GridContainer
var _plus: Button
var _custom: PopupPanel
var _picker: ColourPicker


## The colours used last, newest first, from the settings.
static func recent_colours() -> Array[Color]:
	var out: Array[Color] = []
	var saved: Variant = Game.settings.get_value("paint", "recent", [])
	if not saved is Array:
		return out
	for entry in saved:
		var known: Variant = Paints.read(entry)
		if known != null and out.size() < Paints.RECENT_MOST:
			out.append(known)
	return out


## Puts a colour first in Recent and saves the settings.
static func remember(colour: Color) -> void:
	var saved: Variant = Game.settings.get_value("paint", "recent", [])
	Game.set_setting("paint", "recent", Paints.with_recent(saved if saved is Array else [], colour))


func _init(size := 42.0) -> void:
	swatch_size = size
	add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "RECENT"
	label.add_theme_font_size_override("font_size", UiKit.SMALL)
	add_child(label)
	_recent_row = GridContainer.new()
	_recent_row.add_theme_constant_override("h_separation", 6)
	_recent_row.add_theme_constant_override("v_separation", 6)
	add_child(_recent_row)
	for i in Paints.RECENT_MOST:
		var swatch := _swatch(Color.WHITE)
		_recent_row.add_child(swatch)
		_recent.append(swatch)
	_plus = Button.new()
	_plus.text = "+"
	_plus.custom_minimum_size = Vector2(swatch_size, swatch_size)
	_plus.focus_mode = FOCUS_ALL
	_plus.add_theme_font_size_override("font_size", UiKit.BODY)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_plus.add_theme_color_override(state, UiKit.WHITE)
	_plus.pressed.connect(open_picker)
	_recent_row.add_child(_plus)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	_more_button = BuilderStyle.pill("More colours", Color(0, 0, 0, 0.45), UiKit.WHITE, open_more, 36.0)
	add_child(_more_button)
	_build_more()
	_build_picker()


## Shows these as the main colours, `columns` to a row, with `current` picked
## out wherever it shows.
func show_colours(main: Array[Color], columns: int, current: Variant) -> void:
	_current = current
	if main != _main:
		_main = main.duplicate()
		for child in _grid.get_children():
			_grid.remove_child(child)
			child.queue_free()
		for colour in _main:
			_grid.add_child(_swatch(colour))
	_grid.columns = maxi(columns, 1)
	_recent_row.columns = _grid.columns
	_refresh()


## Picks out a different colour without changing the swatches.
func set_current(colour: Variant) -> void:
	_current = colour
	_refresh()


func open_more() -> void:
	_refresh()
	_more.popup_centered()
	if PadFocus.using_pad:
		PadFocus.focus_first(_more_grid)


func more_open() -> bool:
	return _more.visible or _custom.visible


func close_more() -> void:
	_more.hide()
	_custom.hide()


## Opens the custom picker, starting from the colour that's picked now.
func open_picker() -> void:
	_picker.set_colour(_current if _current != null else Color.WHITE)
	_custom.popup_centered()
	_keep_clear(_custom)
	if PadFocus.using_pad:
		_picker.focus_square()


func picker_open() -> bool:
	return _custom.visible


func close_picker() -> void:
	_custom.hide()


## Uses the colour the picker shows, as if it was picked.
func use_picker() -> void:
	_picker.used.emit(_picker.colour())


func _build_more() -> void:
	_more = PopupPanel.new()
	PadFocus.close_on_b(_more)
	_more.theme = MenuStyle.theme()
	add_child(_more)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_more.add_child(box)
	var title := Label.new()
	title.text = "More colours"
	title.theme_type_variation = "LeadLabel"
	box.add_child(title)
	_more_grid = GridContainer.new()
	_more_grid.columns = Paints.MORE_COLUMNS
	_more_grid.add_theme_constant_override("h_separation", 6)
	_more_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_more_grid)
	for colour in Paints.more():
		_more_grid.add_child(_swatch(colour))
	var custom := BuilderStyle.pill("+ Pick a colour", Color(0, 0, 0, 0.45), UiKit.WHITE, func() -> void:
		_more.hide()
		open_picker(), 36.0)
	box.add_child(custom)


func _build_picker() -> void:
	_custom = PopupPanel.new()
	PadFocus.close_on_b(_custom)
	_custom.theme = MenuStyle.theme()
	add_child(_custom)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_custom.add_child(box)
	var title := Label.new()
	title.text = "Pick a colour"
	title.theme_type_variation = "LeadLabel"
	box.add_child(title)
	_picker = ColourPicker.new()
	_picker.used.connect(func(colour: Color) -> void: _pick(colour))
	box.add_child(_picker)


## Moves a popup off the camera holes.
func _keep_clear(popup: Window) -> void:
	for hole in SafeArea.holes_in(get_viewport()):
		var rect := Rect2(popup.position, popup.size)
		if rect.intersects(hole.grow(SafeArea.CLEAR)):
			var right := hole.end.x + SafeArea.CLEAR
			var left := hole.position.x - SafeArea.CLEAR - rect.size.x
			popup.position.x = int(right if rect.get_center().x > hole.get_center().x or left < 0.0 else left)


func _swatch(colour: Color) -> Button:
	var swatch := Button.new()
	swatch.custom_minimum_size = Vector2(swatch_size, swatch_size)
	swatch.focus_mode = FOCUS_ALL
	swatch.set_meta("colour", colour)
	swatch.pressed.connect(func() -> void: _pick(swatch.get_meta("colour")))
	return swatch


func _pick(colour: Color) -> void:
	_more.hide()
	_custom.hide()
	_current = colour
	remember(colour)
	_refresh()
	picked.emit(colour)


func _refresh() -> void:
	var recent := recent_colours()
	BuilderStyle.show_swatch(_plus, Color(0, 0, 0, 0.45), false)
	for i in _recent.size():
		_recent[i].visible = i < recent.size()
		if i < recent.size():
			_recent[i].set_meta("colour", recent[i])
	var all: Array = []
	all.append_array(_recent)
	all.append_array(_grid.get_children())
	all.append_array(_more_grid.get_children())
	for swatch: Button in all:
		if swatch.visible:
			var colour: Color = swatch.get_meta("colour")
			BuilderStyle.show_swatch(swatch, colour, _current != null and colour.is_equal_approx(_current))
