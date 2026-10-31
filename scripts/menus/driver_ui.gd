class_name DriverUI
extends Control

## The driver screen's panels, laid out like the garage's. The driver stands in
## the middle and every panel floats over the scene on its own dark,
## see-through backing.
##
## Across the top are round tool buttons for leaving, undo, redo, a random
## driver and a menu to save, load, rename or start again. Down the left is the drawer, with a rail of tabs for the nine pieces
## and a picture of your driver wearing each style. The colours are in the
## bottom right, their name and weight in the top right (which opens into a
## card), and sitting them in a kart and Done are along the
## bottom.

signal style_chosen(slot: String, style: String)
signal colour_chosen(slot: String, colour: Color)
signal undo_pressed
signal redo_pressed
signal random_pressed
signal pose_toggled(driving: bool)
signal done_pressed
signal name_changed(text: String)
signal save_pressed
signal new_pressed
signal load_chosen(path: String)

const SLOTS := [["head", "Face"], ["hair", "Hair"], ["facial_hair", "Facial hair"], ["headgear", "Headgear"], ["neck", "Neck"], ["torso", "Torso"], ["back", "Back"], ["arms", "Arms"], ["legs", "Legs"]]
const SWATCH := 42.0

var slot := "head"
var design: CharacterDesign

var _toolbar: PanelContainer
var _undo: IconButton
var _redo: IconButton
var _drawer: PanelContainer
## The drawer's row (the rail, then the tiles) and the rail itself, which
## make way for a camera hole partway down the side (see SafeArea).
var _drawer_row: HBoxContainer
var _rail_box: RailBox
var _rail: Array[IconButton] = []
var _heading: Label
var _tiles: GridContainer
var _chip: Button
var _card: PanelContainer
var _file_menu: PopupMenu
var _load_popup: PopupPanel
var _load_list: VBoxContainer
var _new_dialog: ConfirmationDialog
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _status: Label
var _status_panel: PanelContainer
var _toast_left := 0.0
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
	_build_dialogs()
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
	if _load_popup.visible or _new_dialog.visible or _name_dialog.visible or _file_menu.visible:
		return true
	for panel in [_toolbar, _drawer, _chip, _card, _colours, _bottom]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(pos):
			return true
	return false


## Shows this driver: their tiles, colours, name and weight.
func show_design(who: CharacterDesign) -> void:
	design = who
	_chip.text = "%s  ·  %s  ·  %.0f kg" % [design.name, design.weight_class(), design.mass()]
	_weight.text = "%s, %.0f kg" % [design.weight_class(), design.mass()]
	show_slot(slot)


## A line of news over the Done button for a moment.
func toast(text: String) -> void:
	_status.text = text
	_status_panel.visible = true
	_toast_left = 2.0


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_status_panel.visible = false


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
		swatch.focus_mode = FOCUS_ALL
		BuilderStyle.show_swatch(swatch, colour, colour.is_equal_approx(design.color_of(slot)))
		swatch.pressed.connect(func() -> void: colour_chosen.emit(slot, colour))
		_swatches.add_child(swatch)


# Building the panels.

func _build_toolbar() -> void:
	var close := IconButton.new("close", "Leave the driver screen")
	close.pressed.connect(func() -> void: done_pressed.emit())
	_undo = IconButton.new("undo", "Undo")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_redo = IconButton.new("redo", "Redo")
	_redo.pressed.connect(func() -> void: redo_pressed.emit())
	var dice := IconButton.new("dice", "A random driver")
	dice.pressed.connect(func() -> void: random_pressed.emit())
	var more := IconButton.new("more", "Save, load or start again")
	_toolbar = BuilderStyle.toolbar([[close], [_undo, _redo], [dice], [more]])
	add_child(_toolbar)
	_toolbar.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_toolbar.grow_horizontal = GROW_DIRECTION_BOTH
	_toolbar.offset_top = 8.0

	_file_menu = BuilderStyle.menu(["Save", "Load", "Rename", "New driver"])
	add_child(_file_menu)
	_file_menu.id_pressed.connect(_on_file_menu)
	more.pressed.connect(func() -> void:
		var rect := more.get_global_rect()
		_file_menu.popup(Rect2i(Vector2i(rect.position + Vector2(0, rect.size.y + 6)), Vector2i(220, 0))))


func _on_file_menu(id: int) -> void:
	match id:
		0:
			save_pressed.emit()
		1:
			_open_load()
		2:
			_open_rename()
		3:
			_new_dialog.popup_centered()


func _build_dialogs() -> void:
	_load_popup = PopupPanel.new()
	_load_popup.theme = MenuStyle.theme()
	add_child(_load_popup)
	var box := VBoxContainer.new()
	_load_popup.add_child(box)
	var title := Label.new()
	title.text = "Load a driver"
	title.theme_type_variation = "LeadLabel"
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(460, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_load_list = VBoxContainer.new()
	_load_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_load_list)

	_new_dialog = ConfirmationDialog.new()
	PadFocus.close_on_b(_new_dialog)
	_new_dialog.theme = MenuStyle.theme()
	_new_dialog.title = "Start a new driver?"
	_new_dialog.dialog_text = "This goes back to the starting driver. Undo brings yours back."
	_new_dialog.ok_button_text = "New"
	_new_dialog.cancel_button_text = "Keep building"
	_new_dialog.confirmed.connect(func() -> void: new_pressed.emit())
	add_child(_new_dialog)

	_name_dialog = ConfirmationDialog.new()
	PadFocus.close_on_b(_name_dialog)
	_name_dialog.theme = MenuStyle.theme()
	_name_dialog.title = "Name your driver"
	_name_dialog.ok_button_text = "Rename"
	_name_edit = LineEdit.new()
	PadKeyboard.attach(_name_edit)
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(360, 0)
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(func() -> void:
		var text := _name_edit.text.strip_edges()
		if text != "":
			name_changed.emit(text))
	add_child(_name_dialog)


func _open_rename() -> void:
	_name_edit.text = design.name
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


## The drivers you've saved, then the stock drivers. Loading a stock driver
## gives you a copy of them to change.
func _open_load() -> void:
	for child in _load_list.get_children():
		child.queue_free()
	var saved := CharacterDesign.saved_paths()
	if not saved.is_empty():
		_load_list.add_child(MenuStyle.heading("Your drivers"))
		for path in saved:
			_load_list.add_child(_load_button(CharacterDesign.load_file(path).name, path))
	_load_list.add_child(MenuStyle.heading("Stock drivers"))
	for key in Game.stock_driver_keys():
		var path := "%s/%s.json" % [Game.ROSTER, key]
		_load_list.add_child(_load_button(CharacterDesign.load_file(path).name, path))
	_load_popup.popup_centered()


func _load_button(text: String, path: String) -> Button:
	return MenuStyle.button(text, func() -> void:
		_load_popup.hide()
		load_chosen.emit(path))


func _build_drawer() -> void:
	_drawer = PanelContainer.new()
	add_child(_drawer)
	_drawer.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
	_drawer.offset_left = 8.0
	_drawer.offset_top = 8.0
	_drawer.offset_bottom = -8.0
	var row := HBoxContainer.new()
	_drawer.add_child(row)
	# The rail of tabs down the edge.
	var rail := BuilderStyle.dress_drawer(_drawer, row)
	_rail_box = rail
	_drawer_row = row
	for pair in SLOTS:
		var tab := BuilderStyle.rail_tab(pair[0], pair[1])
		tab.pressed.connect(func() -> void: show_slot(pair[0]))
		rail.add_child(tab)
		_rail.append(tab)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	_heading = Label.new()
	_heading.theme_type_variation = "ShelfLabel"
	_heading.custom_minimum_size.y = 40.0
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_heading)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
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
	_chip = BuilderStyle.stats_chip()
	_chip.pressed.connect(func() -> void:
		_chip.visible = false
		_card.visible = true)
	add_child(_chip)
	_chip.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_chip.grow_horizontal = GROW_DIRECTION_BEGIN
	_chip.offset_right = -8.0
	_chip.offset_top = 8.0

	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", BuilderStyle.scrim(14, 14))
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
	title.text = "WEIGHT"
	title.theme_type_variation = "ShelfLabel"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(title)
	var close := IconButton.new("close", "Close")
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(func() -> void:
		_card.visible = false
		_chip.visible = true)
	top.add_child(close)
	_weight = Label.new()
	_weight.theme_type_variation = "DataLabel"
	box.add_child(_weight)
	var about := Label.new()
	about.text = "A heavier driver makes a steadier kart and a lighter one a quicker one."
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(270, 0)
	about.theme_type_variation = "NoteLabel"
	box.add_child(about)


func _build_colours() -> void:
	_colours = PanelContainer.new()
	_colours.add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 10))
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


## Sitting them in a kart and a big Done button, along the bottom.
func _build_bottom() -> void:
	_bottom = VBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_END
	_bottom.add_theme_constant_override("separation", 8)
	add_child(_bottom)
	_bottom.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_bottom.grow_horizontal = GROW_DIRECTION_BOTH
	_bottom.grow_vertical = GROW_DIRECTION_BEGIN
	_bottom.offset_bottom = -14.0
	_status_panel = PanelContainer.new()
	_status_panel.add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 4))
	_status_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	_status_panel.visible = false
	_bottom.add_child(_status_panel)
	_status = Label.new()
	_status.theme_type_variation = "StatusLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_panel.add_child(_status)
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
		focus_mode = FOCUS_ALL
		custom_minimum_size = BuilderStyle.TILE + Vector2(0, 16)
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BuilderStyle.dress_tile(self, picked)
