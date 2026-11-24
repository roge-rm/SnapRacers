class_name DriverUI
extends Control

## The driver screen's panels, laid out like the garage's. The driver stands in
## the middle and every panel floats over the scene on its own dark,
## see-through backing.
##
## Across the top are round tool buttons for leaving, undo, redo, a random
## driver and a menu to save, load, rename or start again. Down the left is the drawer, with a rail of tabs for the nine pieces
## and a picture of your driver wearing each style. The colours are in a
## drawer down the right, under their name and weight in the top right (which
## opens into a card), and sitting them in a kart and Done are along the
## bottom.

signal style_chosen(slot: String, style: String)
## One part of the face picked on its own: "eyes", "brows" or "mouth" and a
## shape's name, or "extras" and the whole list of them.
signal face_part_chosen(part: String, value: Variant)
signal colour_chosen(slot: String, colour: Color)
signal undo_pressed
signal redo_pressed
signal random_pressed
signal pose_toggled(driving: bool)
signal done_pressed
signal name_changed(text: String)
signal share_pressed
signal import_pressed
signal save_pressed
signal new_pressed
signal load_chosen(path: String)

const SLOTS := [["head", "Face"], ["hair", "Hair"], ["facial_hair", "Facial hair"], ["headgear", "Headgear"], ["neck", "Neck"], ["torso", "Torso"], ["back", "Back"], ["arms", "Arms"], ["legs", "Legs"]]
const SWATCH := 42.0
## The face tab's groups: the named faces, then each part on its own.
const FACE_GROUPS := [["faces", "Faces"], ["eyes", "Eyes"], ["brows", "Brows"], ["mouth", "Mouth"], ["extras", "Extras"]]
const FACE_PICTURE := Vector2i(160, 120)

var slot := "head"
var design: CharacterDesign
## Which of FACE_GROUPS the face tab shows.
var face_group := "faces"

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
var _face_row: HFlowContainer
var _face_pills := {}
## Flat face pictures for the face part tiles, by face and skin.
static var _face_pictures := {}
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
var _colours: ColourDrawer
var _swatches: ColourPalette
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
	for panel in [_toolbar, _chip, _card, _colours, _colours.handle, _bottom]:
		safe.watch(panel)
	safe.watch(_drawer, true)
	safe.flow(_rail_box)
	safe.flow(_drawer_row, 1)


## Whether this screen position is on one of the panels instead of the scene.
func is_over_ui(pos: Vector2) -> bool:
	if _load_popup.visible or _new_dialog.visible or _name_dialog.visible or _file_menu.visible or _swatches.more_open():
		return true
	for panel in [_toolbar, _drawer, _chip, _card, _colours, _colours.handle, _bottom]:
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
	_face_row.visible = slot == "head"
	for group in _face_pills:
		MenuStyle.mark(_face_pills[group], group == face_group)
	if slot == "head" and face_group != "faces":
		_show_face_parts()
		_show_swatches()
		return
	for style in CharacterDesign.styles(slot):
		var info := CharacterDesign.piece(slot, style)
		var weight := str(snappedf(float(info.get("mass", 0.0)), 0.1)).trim_suffix(".0")
		var picked: bool = design.style_of(slot) == style and not (slot == "head" and design.has_own_face())
		var tile := DriverTile.new(style, "%s\n%s kg" % [info.get("name", style), weight], picked)
		tile.set_meta("key", DriverThumbnails.key_of(design, slot, style))
		tile.icon = _pictures.picture(design, slot, style)
		tile.tapped.connect(func() -> void: style_chosen.emit(slot, style))
		# Greyed when it leaves long hair's length off.
		if not _keeps_length(slot, style):
			tile.modulate = Color(1, 1, 1, 0.45)
		_tiles.add_child(tile)
	_show_swatches()


## Whether wearing this style keeps the length of the driver's long hair,
## or of this long hair, which some neck pieces, back pieces and headgear
## don't fit with.
func _keeps_length(which: String, style: String) -> bool:
	if not which in ["hair", "neck", "back", "headgear"]:
		return true
	var apart := CharacterRig.length_apart(style if which == "hair" else design.style_of("hair"))
	for other in ["neck", "back", "headgear"]:
		if apart.has("%s %s" % [other, style if other == which else design.style_of(other)]):
			return false
	return true


## Shows one face group: each shape on your driver's face, in place of the
## one they have. Extras go on and off, and None takes them all off.
func show_face_group(group: String) -> void:
	face_group = group
	show_slot("head")


func _show_face_parts() -> void:
	var parts := design.face()
	var shapes: Array = [""] + FacePrint.EXTRAS if face_group == "extras" else FacePrint.PARTS[face_group]
	var at := CharacterDesign.FACE_PARTS.find(face_group)
	for shape in shapes:
		var trying := parts.duplicate(true)
		var value: Variant = shape
		var picked := false
		if face_group == "extras":
			if shape == "":
				value = []
				picked = parts[3].all(func(e): return e == "blush")
			else:
				picked = parts[3].has(shape)
				value = parts[3].duplicate()
				if picked:
					value.erase(shape)
				else:
					value.append(shape)
			# Each picture shows its extra on, and None shows none.
			trying[3] = [] if shape == "" else (parts[3] if picked else value)
		else:
			picked = parts[at] == shape
			trying[at] = shape
		var label: String = FacePrint.SHAPE_NAMES.get(shape, shape)
		var tile := DriverTile.new(str(shape), label, picked)
		tile.icon = _face_picture(trying)
		var part: String = face_group
		tile.tapped.connect(func() -> void: face_part_chosen.emit(part, value))
		_tiles.add_child(tile)


## A flat picture of this face on your driver's skin, kept for next time.
func _face_picture(parts: Array) -> Texture2D:
	var key := "%s %s %s %s" % [str(parts), design.skin().to_html(), design.style_of("facial_hair"), design.color_of("facial_hair").to_html()]
	if not _face_pictures.has(key):
		if _face_pictures.size() > 200:
			_face_pictures.clear()
		_face_pictures[key] = ImageTexture.create_from_image(FacePrint.picture(parts, design.skin(), FACE_PICTURE, design.style_of("facial_hair"), design.color_of("facial_hair")))
	return _face_pictures[key]


func _show_picture(key: String, picture: Texture2D) -> void:
	for tile in _tiles.get_children():
		if tile.get_meta("key", "") == key:
			tile.icon = picture


func _show_swatches() -> void:
	var colours := CharacterDesign.colours_for(slot)
	# Nothing has no colour to pick.
	_colours.set_shown(design.style_of(slot) != "none")
	_swatches.show_colours(colours, 4, design.color_of(slot))


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

	_file_menu = BuilderStyle.menu(["Save", "Load", "Rename", "New driver", "Share"])
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
		4:
			share_pressed.emit()


func _build_dialogs() -> void:
	_load_popup = PopupPanel.new()
	PadFocus.close_on_b(_load_popup)
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
	_load_list.add_child(MenuStyle.button("Add a driver...", func() -> void:
		_load_popup.hide()
		import_pressed.emit()))
	var saved := CharacterDesign.saved_drivers()
	if not saved.is_empty():
		_load_list.add_child(MenuStyle.heading("Your drivers"))
		for entry in saved:
			_load_list.add_child(_load_button(entry.name, entry.path))
	_load_list.add_child(MenuStyle.heading("Stock drivers"))
	for key in Game.stock_driver_keys():
		var path := "%s/%s.json" % [Game.ROSTER, key]
		_load_list.add_child(_load_button(CharacterDesign.load_file(path).name, path))
	_load_popup.popup_centered()
	PadFocus.focus_first(_load_popup)


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
	# The face tab picks a named face or each part on its own.
	_face_row = HFlowContainer.new()
	_face_row.add_theme_constant_override("h_separation", 4)
	_face_row.add_theme_constant_override("v_separation", 4)
	_face_row.custom_minimum_size.x = BuilderStyle.TILE.x * 2.0 + 4.0
	column.add_child(_face_row)
	for pair in FACE_GROUPS:
		var pill := MenuStyle.button(pair[1], func() -> void: show_face_group(pair[0]))
		pill.theme_type_variation = "ChoiceButton"
		pill.custom_minimum_size = Vector2(0, 40)
		_face_row.add_child(pill)
		_face_pills[pair[0]] = pill
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
	_colours = ColourDrawer.new("Colours", SWATCH)
	_colours.place(self)
	# The weight card opens over it.
	move_child(_colours, _chip.get_index())
	move_child(_colours.handle, _chip.get_index())
	_swatches = _colours.palette
	_swatches.picked.connect(func(colour: Color) -> void: colour_chosen.emit(slot, colour))


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
