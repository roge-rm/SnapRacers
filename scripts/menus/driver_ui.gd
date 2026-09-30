class_name DriverUI
extends Control

## The driver screen's panels, laid out like the garage's. The driver stands in
## the middle and every panel floats over the scene on its own dark,
## see-through backing.
##
## Across the top are round tool buttons for leaving, undo, redo and a random
## driver. Down the left is the drawer, with a rail of tabs for the nine pieces
## and a picture of your driver wearing each style. The colours are in the
## bottom right, their name and weight in the top right (which opens into a
## card to rename them), and sitting them in a kart and Done are along the
## bottom.

signal style_chosen(slot: String, style: String)
signal colour_chosen(slot: String, colour: Color)
signal undo_pressed
signal redo_pressed
signal random_pressed
signal pose_toggled(driving: bool)
signal done_pressed
signal name_changed(text: String)

const SLOTS := [["head", "Face"], ["hair", "Hair"], ["facial_hair", "Facial hair"], ["headgear", "Headgear"], ["neck", "Neck"], ["torso", "Torso"], ["back", "Back"], ["arms", "Arms"], ["legs", "Legs"]]
const SWATCH := 42.0

var slot := "head"
var design: CharacterDesign

var _toolbar: HBoxContainer
var _undo: IconButton
var _redo: IconButton
var _drawer: PanelContainer
## The drawer's row (the rail, then the tiles) and the rail itself, which
## make way for a camera hole partway down the side (see SafeArea).
var _drawer_row: HBoxContainer
var _rail_box: VBoxContainer
var _rail: Array[IconButton] = []
var _heading: Label
var _tiles: GridContainer
var _chip: Button
var _card: PanelContainer
var _name_edit: LineEdit
var _weight: Label
var _colours: PanelContainer
var _swatches: GridContainer
var _bottom: VBoxContainer
var _pose: Button
var _driving := false
var _pictures: DriverThumbnails


func _ready() -> void:
	theme = MenuStyle.theme()
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_pictures = DriverThumbnails.new()
	_pictures.ready_for.connect(_show_picture)
	add_child(_pictures)
	_build_toolbar()
	_build_drawer()
	_build_card()
	_build_colours()
	_build_bottom()
	# Nothing hides under a camera hole.
	var safe := SafeArea.new()
	add_child(safe)
	for panel in [_toolbar, _chip, _card, _colours, _bottom]:
		safe.watch(panel)
	safe.watch(_drawer, true)
	safe.flow(_rail_box)
	safe.flow(_drawer_row, 1)


## Whether this screen position is on one of the panels instead of the scene.
func is_over_ui(pos: Vector2) -> bool:
	for panel in [_toolbar, _drawer, _chip, _card, _colours, _bottom]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(pos):
			return true
	return false


## Shows this driver: their tiles, colours, name and weight.
func show_design(who: CharacterDesign) -> void:
	design = who
	if _name_edit.text.strip_edges() != design.name:
		_name_edit.text = design.name
	_chip.text = "%s  ·  %s  ·  %.0f kg" % [design.name, design.weight_class(), design.mass()]
	_weight.text = "%s, %.0f kg" % [design.weight_class(), design.mass()]
	show_slot(slot)


func set_history(can_undo: bool, can_redo: bool) -> void:
	_undo.disabled = not can_undo
	_redo.disabled = not can_redo


func show_slot(which: String) -> void:
	slot = which
	for i in SLOTS.size():
		_rail[i].on = SLOTS[i][0] == slot
		if _rail[i].on:
			_heading.text = SLOTS[i][1].to_upper()
	_pictures.drop_waiting()
	for child in _tiles.get_children():
		child.queue_free()
	for style in CharacterDesign.styles(slot):
		var info := CharacterDesign.piece(slot, style)
		var weight := str(snappedf(float(info.get("mass", 0.0)), 0.1)).trim_suffix(".0")
		var tile := DriverTile.new(style, "%s\n%s kg" % [info.get("name", style), weight], design.style_of(slot) == style)
		tile.set_meta("key", DriverThumbnails.key_of(design, slot, style))
		tile.icon = _pictures.picture(design, slot, style)
		tile.tapped.connect(func() -> void: style_chosen.emit(slot, style))
		_tiles.add_child(tile)
	_show_swatches()


func _show_picture(key: String, picture: Texture2D) -> void:
	for tile in _tiles.get_children():
		if tile.get_meta("key", "") == key:
			tile.icon = picture


func _show_swatches() -> void:
	for child in _swatches.get_children():
		child.queue_free()
	var colours := CharacterDesign.colours_for(slot)
	# Nothing has no colour to pick.
	_colours.visible = design.style_of(slot) != "none"
	_swatches.columns = mini(colours.size(), 10)
	for colour in colours:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
		swatch.focus_mode = FOCUS_NONE
		BuilderStyle.show_swatch(swatch, colour, colour.is_equal_approx(design.color_of(slot)))
		swatch.pressed.connect(func() -> void: colour_chosen.emit(slot, colour))
		_swatches.add_child(swatch)


# Building the panels.

func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 10)
	add_child(_toolbar)
	_toolbar.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_toolbar.grow_horizontal = GROW_DIRECTION_BOTH
	_toolbar.offset_top = 8.0
	var close := IconButton.new("close", "Leave the driver screen")
	close.pressed.connect(func() -> void: done_pressed.emit())
	_undo = IconButton.new("undo", "Undo")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_redo = IconButton.new("redo", "Redo")
	_redo.pressed.connect(func() -> void: redo_pressed.emit())
	var dice := IconButton.new("dice", "A random driver")
	dice.pressed.connect(func() -> void: random_pressed.emit())
	for button in [close, _undo, _redo, dice]:
		_toolbar.add_child(button)


func _build_drawer() -> void:
	_drawer = PanelContainer.new()
	_drawer.add_theme_stylebox_override("panel", BuilderStyle.scrim())
	add_child(_drawer)
	_drawer.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
	_drawer.offset_left = 8.0
	_drawer.offset_top = 8.0
	_drawer.offset_bottom = -8.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_drawer.add_child(row)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 4)
	row.add_child(rail)
	_rail_box = rail
	_drawer_row = row
	for pair in SLOTS:
		var tab := IconButton.new(pair[0], pair[1])
		tab.pressed.connect(func() -> void: show_slot(pair[0]))
		rail.add_child(tab)
		_rail.append(tab)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 18)
	_heading.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_heading.custom_minimum_size.y = 40.0
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_tiles = GridContainer.new()
	_tiles.columns = 2
	_tiles.add_theme_constant_override("h_separation", 4)
	_tiles.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_tiles)


## Their name and weight on one line in the top right, which opens into a card.
func _build_card() -> void:
	_chip = Button.new()
	_chip.focus_mode = FOCUS_NONE
	_chip.add_theme_font_size_override("font_size", 19)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		_chip.add_theme_color_override(state, BuilderStyle.DATA)
	for state in ["normal", "hover", "pressed"]:
		_chip.add_theme_stylebox_override(state, BuilderStyle.scrim(8))
	_chip.pressed.connect(func() -> void:
		_chip.visible = false
		_card.visible = true)
	add_child(_chip)
	_chip.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_chip.grow_horizontal = GROW_DIRECTION_BEGIN
	_chip.offset_right = -8.0
	_chip.offset_top = 8.0

	_card = PanelContainer.new()
	var style := BuilderStyle.scrim()
	style.set_content_margin_all(14)
	_card.add_theme_stylebox_override("panel", style)
	_card.visible = false
	add_child(_card)
	_card.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_card.grow_horizontal = GROW_DIRECTION_BEGIN
	_card.offset_right = -8.0
	_card.offset_top = 8.0
	_card.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := Label.new()
	title.text = "NAME"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(title)
	var close := IconButton.new("close", "Close")
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(func() -> void:
		_name_edit.release_focus()
		_card.visible = false
		_chip.visible = true)
	top.add_child(close)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 20
	_name_edit.text_changed.connect(func(text: String) -> void: name_changed.emit(text))
	box.add_child(_name_edit)
	_weight = Label.new()
	_weight.add_theme_font_size_override("font_size", 22)
	_weight.add_theme_color_override("font_color", BuilderStyle.DATA)
	box.add_child(_weight)
	var about := Label.new()
	about.text = "A heavier driver makes a steadier kart and a lighter one a quicker one."
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(270, 0)
	about.add_theme_font_size_override("font_size", 17)
	about.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(about)


func _build_colours() -> void:
	_colours = PanelContainer.new()
	var style := BuilderStyle.scrim(16)
	style.set_content_margin_all(10)
	_colours.add_theme_stylebox_override("panel", style)
	add_child(_colours)
	_colours.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_colours.grow_horizontal = GROW_DIRECTION_BEGIN
	_colours.grow_vertical = GROW_DIRECTION_BEGIN
	_colours.offset_right = -8.0
	_colours.offset_bottom = -8.0
	_swatches = GridContainer.new()
	_swatches.add_theme_constant_override("h_separation", 6)
	_swatches.add_theme_constant_override("v_separation", 6)
	_colours.add_child(_swatches)


## A hint, then sitting them in a kart and a big Done button, along the bottom.
func _build_bottom() -> void:
	_bottom = VBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_END
	_bottom.add_theme_constant_override("separation", 8)
	add_child(_bottom)
	_bottom.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_bottom.grow_horizontal = GROW_DIRECTION_BOTH
	_bottom.grow_vertical = GROW_DIRECTION_BEGIN
	_bottom.offset_bottom = -14.0
	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", BuilderStyle.scrim(8))
	hint_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	_bottom.add_child(hint_panel)
	var hint := Label.new()
	hint.text = "Drag them to spin them around."
	hint.add_theme_font_size_override("font_size", 18)
	hint_panel.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_bottom.add_child(row)
	_pose = BuilderStyle.dark_pill("Sit in a kart", func() -> void:
		_driving = not _driving
		_pose.text = "STAND UP" if _driving else "SIT IN A KART"
		pose_toggled.emit(_driving))
	row.add_child(_pose)
	var done := BuilderStyle.main_pill("Done", func() -> void: done_pressed.emit())
	done.custom_minimum_size.x = 180.0
	row.add_child(done)


## A style of piece in the drawer: a picture of your driver wearing it, its
## name and weight. The one they're wearing is lit up.
class DriverTile:
	extends ScrollButton

	var style := ""

	func _init(which: String, label: String, picked: bool) -> void:
		# ScrollButton's own set up (the tap, and letting drags scroll the
		# list) only happens if it's asked for.
		super()
		style = which
		text = label
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		expand_icon = true
		focus_mode = FOCUS_NONE
		custom_minimum_size = BuilderStyle.TILE + Vector2(0, 16)
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_theme_font_size_override("font_size", 14)
		if picked:
			for state in ["font_color", "font_hover_color", "font_pressed_color"]:
				add_theme_color_override(state, MenuStyle.ACCENT)
		for state in ["normal", "hover", "pressed"]:
			add_theme_stylebox_override(state, BuilderStyle.tile_box(state, picked))
