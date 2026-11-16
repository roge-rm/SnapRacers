class_name ColourPalette
extends VBoxContainer

## Colour swatches for the garage and the driver screen: the colours used last
## along the top (once there are some), the main colours under them, and a
## More colours button that opens a bigger grid, which closes after a pick.
## Every pick goes into Recent (see Paints).

signal picked(colour: Color)

var swatch_size := 42.0

var _current: Variant = null
var _main: Array[Color] = []
var _recent_row: HBoxContainer
var _recent: Array[Button] = []
var _grid: GridContainer
var _more_button: Button
var _more: PopupPanel
var _more_grid: GridContainer


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
	_recent_row = HBoxContainer.new()
	_recent_row.add_theme_constant_override("separation", 6)
	add_child(_recent_row)
	var label := Label.new()
	label.text = "RECENT"
	label.add_theme_font_size_override("font_size", UiKit.SMALL)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_recent_row.add_child(label)
	for i in Paints.RECENT_MOST:
		var swatch := _swatch(Color.WHITE)
		_recent_row.add_child(swatch)
		_recent.append(swatch)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	_more_button = BuilderStyle.pill("More colours", Color(0, 0, 0, 0.45), UiKit.WHITE, open_more, 36.0)
	add_child(_more_button)
	_build_more()


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
	return _more.visible


func close_more() -> void:
	_more.hide()


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


func _swatch(colour: Color) -> Button:
	var swatch := Button.new()
	swatch.custom_minimum_size = Vector2(swatch_size, swatch_size)
	swatch.focus_mode = FOCUS_ALL
	swatch.set_meta("colour", colour)
	swatch.pressed.connect(func() -> void: _pick(swatch.get_meta("colour")))
	return swatch


func _pick(colour: Color) -> void:
	_more.hide()
	_current = colour
	remember(colour)
	_refresh()
	picked.emit(colour)


func _refresh() -> void:
	var recent := recent_colours()
	_recent_row.visible = not recent.is_empty()
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
