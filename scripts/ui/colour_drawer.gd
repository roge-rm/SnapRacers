class_name ColourDrawer
extends PanelContainer

## The colours down the right side of the garage and the driver screen, the
## left drawer mirrored: a heading with a button that puts it away, then the
## palette (see ColourPalette), scrolling if it's too tall. Put away, a handle
## at the right edge brings it back. Add `handle` beside it.
##
## `set_open()` is what the player chose and stays put, and `set_shown()` is
## whether there's anything to colour.

## Its top sits under the stats chip and its bottom over the row of big
## buttons along the bottom.
const TOP := 56.0
const BOTTOM := 86.0

var palette: ColourPalette
var handle: Button
## The heading, for a screen to add its own buttons to.
var heading: HBoxContainer
var is_open := true
var _shown := true
var _title: Label
var _shut: IconButton


func _init(title: String, swatch_size := 42.0) -> void:
	add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 8))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	heading = HBoxContainer.new()
	column.add_child(heading)
	_shut = IconButton.new("open", "Put the colours away")
	_shut.custom_minimum_size = Vector2(40, 40)
	_shut.pressed.connect(set_open.bind(false))
	heading.add_child(_shut)
	_title = Label.new()
	_title.text = title.to_upper()
	_title.theme_type_variation = "ShelfLabel"
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	palette = ColourPalette.new(swatch_size)
	scroll.add_child(palette)

	handle = BuilderStyle.drawer_handle(set_open.bind(true))
	handle.text = "‹"


## Lays it out down the right side of `parent`, and its handle at the edge.
func place(parent: Control) -> void:
	parent.add_child(self)
	set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	grow_horizontal = GROW_DIRECTION_BEGIN
	offset_right = -8.0
	offset_top = TOP
	offset_bottom = -BOTTOM
	parent.add_child(handle)
	handle.set_anchors_and_offsets_preset(PRESET_CENTER_RIGHT)
	handle.grow_horizontal = GROW_DIRECTION_BEGIN
	handle.offset_top = -40.0
	handle.offset_bottom = 40.0
	_show()


func set_title(title: String) -> void:
	_title.text = title.to_upper()


## Puts it away or brings it back. A controller's focus goes with it.
func set_open(open: bool) -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_focus := focused != null and (focused == handle or is_ancestor_of(focused))
	is_open = open
	_show()
	if had_focus and _shown:
		(_shut if open else handle).grab_focus()


## Whether there's anything to colour. With nothing it's hidden, handle and all.
func set_shown(shown: bool) -> void:
	_shown = shown
	_show()
	if not shown:
		palette.close_more()


func _show() -> void:
	visible = _shown and is_open
	if handle != null:
		handle.visible = _shown and not is_open
