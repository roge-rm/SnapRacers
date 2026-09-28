class_name TrackEditorUI
extends Control

## The track editor's panels, laid out like the garage's. The course fills
## the screen and every panel floats over it.
##
## Across the top are the tool buttons: leave, undo, redo, fit the course in
## view, and the file menu. Down the left is the drawer of pieces, with a
## rail of tabs. Tap a piece and it clicks onto the end of the road (or after
## the piece you've picked out). The landmarks tab has the big things to put
## around the course instead. In the top right is one line about the course,
## which opens into its card: its name, laps and theme, anything stopping it
## being raced, and Close it up. Test drive and race are along the bottom.
##
## Tap a piece of road and its actions come up in the bottom right: take it
## out, add more after it, and change its surface or walls. A landmark in
## hand has its own: turn it, put it down, or take it away.

signal piece_chosen(spec: Dictionary)
signal landmark_chosen(prop: String)
signal undo_pressed
signal redo_pressed
signal fit_pressed
signal menu_pressed
signal new_pressed
signal save_pressed
signal load_chosen(path: String)
signal name_changed(text: String)
signal laps_changed(laps: int)
signal theme_chosen(theme: String)
signal close_up_pressed
signal delete_pressed
signal add_after_pressed
signal surface_chosen(surface: String)
signal edges_chosen(edges: String)
signal deselect_pressed
signal turn_landmark_pressed
signal drop_landmark_pressed
signal remove_landmark_pressed
signal drive_pressed
signal race_pressed

## The pieces, tab by tab, as [what it says on the tile, spec].
const CATEGORIES := [
	["Straights", "straights", [
		["1 tile", {"type": "straight", "length": 1}], ["2 tiles", {"type": "straight", "length": 2}],
		["3 tiles", {"type": "straight", "length": 3}], ["4 tiles", {"type": "straight", "length": 4}],
	]],
	["Bends", "bends", [
		["Tight left", {"type": "curve", "turn": "left", "size": 1}], ["Tight right", {"type": "curve", "turn": "right", "size": 1}],
		["Left", {"type": "curve", "turn": "left", "size": 2}], ["Right", {"type": "curve", "turn": "right", "size": 2}],
		["Wide left", {"type": "curve", "turn": "left", "size": 3}], ["Wide right", {"type": "curve", "turn": "right", "size": 3}],
	]],
	["Slants", "slants", [
		["S bend left", {"type": "slant", "turn": "left", "length": 2, "across": 1}], ["S bend right", {"type": "slant", "turn": "right", "length": 2, "across": 1}],
		["Slant left", {"type": "slant", "turn": "left", "length": 3, "across": 1}], ["Slant right", {"type": "slant", "turn": "right", "length": 3, "across": 1}],
		["Long slant left", {"type": "slant", "turn": "left", "length": 4, "across": 2}], ["Long slant right", {"type": "slant", "turn": "right", "length": 4, "across": 2}],
	]],
	["Hills", "hills", [
		["Hump", {"type": "crest", "length": 3, "height": 1.5}], ["Big hump", {"type": "crest", "length": 3, "height": 3.0}],
		["Ramp up", {"type": "ramp", "length": 2, "rise": 1}], ["Ramp down", {"type": "ramp", "length": 2, "rise": -1}],
		["Climb left", {"type": "curve", "turn": "left", "size": 2, "rise": 1}], ["Climb right", {"type": "curve", "turn": "right", "size": 2, "rise": 1}],
		["Drop left", {"type": "curve", "turn": "left", "size": 2, "rise": -1}], ["Drop right", {"type": "curve", "turn": "right", "size": 2, "rise": -1}],
	]],
	["Stunts", "stunts", [
		["Jump", {"type": "jump"}], ["Loop", {"type": "loop", "side": "right"}],
		["Wall ride left", {"type": "curve", "turn": "left", "size": 3, "bank": 80}], ["Wall ride right", {"type": "curve", "turn": "right", "size": 3, "bank": 80}],
		["Banked left", {"type": "curve", "turn": "left", "size": 3, "bank": 22}], ["Banked right", {"type": "curve", "turn": "right", "size": 3, "bank": 22}],
		["Shortcut left", {"type": "curve", "turn": "left", "size": 2, "cut": true}], ["Shortcut right", {"type": "curve", "turn": "right", "size": 2, "cut": true}],
	]],
]
## The landmarks you can put down, as [name, prop].
const LANDMARKS := [
	["Barn", "barn"], ["Silo", "silo"], ["Windmill", "big_windmill"], ["Church", "church"],
	["Castle", "castle"], ["Tower", "tower"], ["Castle wall", "castle_wall"], ["Lighthouse", "lighthouse"],
	["Rocket", "rocket"], ["Radar", "radar"], ["Factory", "factory"], ["Crane", "crane"],
	["Tanks", "tanks"], ["Chimney", "chimney"], ["Pithead", "headframe"], ["Digger", "excavator"],
	["Wind turbine", "wind_turbine"], ["Skyscraper", "skyscraper"], ["Station", "station"], ["Villa", "villa"],
	["Cottage", "cottage"], ["Cabin", "cabin"], ["Trullo", "trullo"], ["Hut on stilts", "stilt_hut"],
	["Ruins", "ruins"], ["Volcano", "volcano"], ["Mountain", "mountain"], ["Lake", "lake"],
	["Pond", "pond"], ["Lava pool", "lava_pool"], ["Slag heap", "slag_heap"], ["Dune", "dune"],
]
const SURFACES := [["Road", "asphalt"], ["Dirt", "dirt"], ["Grass", "grass"], ["Sand", "sand"], ["Ice", "ice"]]
const EDGES := [["Walls", "walls"], ["Left open", "left_open"], ["Right open", "right_open"], ["Open", "open"]]
## What each theme is called on its button.
const THEME_NAMES := {
	"orchard": "Orchard", "trulli": "Olive groves", "lake": "Lakeside", "mine": "Coal mine",
	"delta": "River delta", "pit": "Open pit", "industry": "Factories", "amber": "Old town",
	"timber": "Mountains", "frost": "Snow", "desert": "Desert city", "railway": "Railway",
	"windmill": "Windmills", "space": "Space centre", "volcano": "Volcano", "castle": "Castle",
}
const DANGER := BuilderStyle.DANGER
const DATA := BuilderStyle.DATA

var _toolbar: HBoxContainer
var _undo: IconButton
var _redo: IconButton
var _file_menu: PopupMenu

var _drawer: PanelContainer
var _drawer_row: HBoxContainer
var _rail_box: VBoxContainer
var _rail: Array[IconButton] = []
var _heading: Label
var _tiles: GridContainer
var _category := 0
var _pictures: LandmarkThumbnails

var _chip: Button
var _card: PanelContainer
var _name_label: Label
var _about_label: Label
var _problems_label: Label
var _laps_label: Label
var _close_up: Button
var _themes: Dictionary = {}

var _actions: PanelContainer
var _action_title: Label
var _surfaces: Dictionary = {}
var _edges: Dictionary = {}
var _landmark_actions: PanelContainer

var _bottom: VBoxContainer
var _status: Label
var _status_panel: PanelContainer
var _race: Button
var _toast_left := 0.0
var _hint := ""
var _problem_count := 0

var _load_popup: PopupPanel
var _load_list: VBoxContainer
var _new_dialog: ConfirmationDialog
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _course_name := ""


func _ready() -> void:
	theme = MenuStyle.theme()
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_pictures = LandmarkThumbnails.new()
	_pictures.ready_for.connect(_show_picture)
	add_child(_pictures)
	_build_toolbar()
	_build_drawer()
	_build_card()
	_build_actions()
	_build_bottom()
	_build_dialogs()
	_show_category(0)
	show_selection(-1, {})
	var safe := SafeArea.new()
	add_child(safe)
	for panel in [_toolbar, _chip, _card, _actions, _landmark_actions, _bottom]:
		safe.watch(panel)
	safe.watch(_drawer, true)
	safe.flow(_rail_box)
	safe.flow(_drawer_row, 1)


## Whether this screen position is on one of the panels instead of the course.
func is_over_ui(pos: Vector2) -> bool:
	if _load_popup.visible or _new_dialog.visible or _name_dialog.visible or _file_menu.visible:
		return true
	for panel in [_toolbar, _drawer, _chip, _card, _actions, _landmark_actions, _bottom]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(pos):
			return true
	return false


# What the editor tells the panels.

## The course's name, length and laps on the chip, and its card.
func show_course(course: CourseDesign, length: float, problems: Array[String], can_close: bool) -> void:
	_course_name = course.name
	_chip.text = "%s · %d m · %d lap%s" % [course.name, roundi(length), course.laps, "" if course.laps == 1 else "s"]
	_name_label.text = course.name
	_about_label.text = "%d pieces, %d m a lap" % [course.pieces.size(), roundi(length)]
	_laps_label.text = "%d lap%s" % [course.laps, "" if course.laps == 1 else "s"]
	for id in _themes:
		BuilderStyle.show_swatch(_themes[id], Color(Scenery.theme_named(id).ground).darkened(0.35), id == course.theme)
	_problems_label.text = "\n".join(problems.map(func(p): return "• " + p))
	_problems_label.visible = not problems.is_empty()
	_close_up.visible = can_close
	_problem_count = problems.size()
	_chip.add_theme_color_override("font_color", DANGER if _problem_count > 0 else DATA)
	_race.disabled = _problem_count > 0
	_show_status()


func set_undo_state(can_undo: bool, can_redo: bool) -> void:
	_undo.disabled = not can_undo
	_redo.disabled = not can_redo


## The piece picked out, or -1 for none.
func show_selection(index: int, spec: Dictionary) -> void:
	_actions.visible = index != -1
	if index == -1:
		return
	_action_title.text = "Piece %d" % (index + 1)
	var surface: String = spec.get("surface", "asphalt")
	for id in _surfaces:
		MenuStyle.mark(_surfaces[id], id == surface)
	var edges: String = spec.get("edges", "walls")
	for id in _edges:
		MenuStyle.mark(_edges[id], id == edges)


## Whether a landmark's in hand, being put down.
func show_landmark_in_hand(on: bool) -> void:
	_landmark_actions.visible = on
	if on:
		_actions.visible = false


func set_hint(text: String) -> void:
	_hint = text
	_show_status()


## A message for a few seconds, like "Saved".
func toast(text: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_status_panel.visible = true
	_toast_left = 2.5


func _show_status() -> void:
	if _toast_left > 0.0:
		return
	if _problem_count > 0 and _hint == "":
		_status.text = "%d thing%s to fix before it can race (see the card)" % [_problem_count, "" if _problem_count == 1 else "s"]
		_status.add_theme_color_override("font_color", DANGER)
	else:
		_status.text = _hint
		_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_status_panel.visible = _status.text != ""


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_show_status()


# Building the panels.

func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 10)
	add_child(_toolbar)
	_toolbar.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_toolbar.grow_horizontal = GROW_DIRECTION_BOTH
	_toolbar.offset_top = 8.0
	var close := IconButton.new("close", "Leave the track editor")
	close.pressed.connect(func() -> void: menu_pressed.emit())
	_undo = IconButton.new("undo", "Undo")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_redo = IconButton.new("redo", "Redo")
	_redo.pressed.connect(func() -> void: redo_pressed.emit())
	var fit := IconButton.new("fit", "Fit the course in view")
	fit.pressed.connect(func() -> void: fit_pressed.emit())
	var more := IconButton.new("more", "Save, load or start again")
	for button in [close, _undo, _redo, fit, more]:
		_toolbar.add_child(button)
	_file_menu = BuilderStyle.menu(["Save", "Load", "Rename", "New course"])
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
	var tabs: Array = CATEGORIES.map(func(c): return [c[0], c[1]]) + [["Landmarks", "landmarks"]]
	for i in tabs.size():
		var tab := IconButton.new(tabs[i][1], tabs[i][0])
		tab.pressed.connect(_show_category.bind(i))
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


func _show_category(index: int) -> void:
	_category = index
	for i in _rail.size():
		_rail[i].on = i == index
	for child in _tiles.get_children():
		child.queue_free()
	if index < CATEGORIES.size():
		_heading.text = CATEGORIES[index][0].to_upper()
		for entry in CATEGORIES[index][2]:
			var spec: Dictionary = entry[1]
			var tile := _tile("")
			var label := Label.new()
			label.text = entry[0]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 14)
			label.mouse_filter = MOUSE_FILTER_IGNORE
			tile.add_child(label)
			label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
			label.offset_top = -24.0
			var picture := PieceIcon.new(spec)
			tile.add_child(picture)
			picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			picture.offset_bottom = -26.0
			tile.pressed.connect(func() -> void: piece_chosen.emit(spec.duplicate()))
			_tiles.add_child(tile)
	else:
		_heading.text = "LANDMARKS"
		_pictures.take(LANDMARKS.map(func(l): return l[1]))
		for entry in LANDMARKS:
			var prop: String = entry[1]
			var tile := _tile(entry[0])
			tile.set_meta("prop", prop)
			tile.icon = LandmarkThumbnails.picture(prop)
			tile.pressed.connect(func() -> void: landmark_chosen.emit(prop))
			_tiles.add_child(tile)


func _tile(label: String) -> Button:
	var tile := Button.new()
	tile.text = label
	tile.focus_mode = FOCUS_NONE
	tile.custom_minimum_size = BuilderStyle.TILE
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.expand_icon = true
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed"]:
		tile.add_theme_stylebox_override(state, BuilderStyle.tile_box(state))
	return tile


func _show_picture(prop: String, picture: Texture2D) -> void:
	for tile in _tiles.get_children():
		if tile.get_meta("prop", "") == prop:
			tile.icon = picture


func _build_card() -> void:
	_chip = Button.new()
	_chip.focus_mode = FOCUS_NONE
	_chip.add_theme_font_size_override("font_size", 19)
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
	_card.add_theme_stylebox_override("panel", BuilderStyle.scrim())
	_card.visible = false
	add_child(_card)
	_card.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_card.grow_horizontal = GROW_DIRECTION_BEGIN
	_card.offset_right = -8.0
	_card.offset_top = 8.0
	_card.custom_minimum_size = Vector2(330, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_label.clip_text = true
	top.add_child(_name_label)
	var rename := BuilderStyle.word("Rename", MenuStyle.ACCENT, _open_rename)
	top.add_child(rename)
	var close := IconButton.new("close", "Close")
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(func() -> void:
		_card.visible = false
		_chip.visible = true)
	top.add_child(close)
	_about_label = Label.new()
	_about_label.add_theme_font_size_override("font_size", 18)
	_about_label.add_theme_color_override("font_color", DATA)
	box.add_child(_about_label)

	var laps := HBoxContainer.new()
	laps.add_theme_constant_override("separation", 8)
	box.add_child(laps)
	var fewer := IconButton.new("shut", "Fewer laps")
	fewer.custom_minimum_size = Vector2(40, 40)
	fewer.pressed.connect(func() -> void: laps_changed.emit(-1))
	laps.add_child(fewer)
	_laps_label = Label.new()
	_laps_label.custom_minimum_size = Vector2(80, 0)
	_laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_laps_label.add_theme_font_size_override("font_size", 20)
	laps.add_child(_laps_label)
	var more := IconButton.new("open", "More laps")
	more.custom_minimum_size = Vector2(40, 40)
	more.pressed.connect(func() -> void: laps_changed.emit(1))
	laps.add_child(more)

	var theme_heading := Label.new()
	theme_heading.text = "Theme"
	theme_heading.add_theme_font_size_override("font_size", 16)
	theme_heading.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(theme_heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for id in THEME_NAMES:
		var ground := Color(Scenery.theme_named(id).ground).darkened(0.35)
		var ink := Color("#1b1b1b") if ground.get_luminance() > 0.5 else Color.WHITE
		var swatch := BuilderStyle.pill(THEME_NAMES[id], ground, ink, func() -> void: theme_chosen.emit(id), 36.0)
		swatch.add_theme_font_size_override("font_size", 15)
		swatch.custom_minimum_size.x = 150.0
		grid.add_child(swatch)
		_themes[id] = swatch

	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.custom_minimum_size = Vector2(310, 0)
	_problems_label.add_theme_color_override("font_color", DANGER)
	_problems_label.add_theme_font_size_override("font_size", 17)
	box.add_child(_problems_label)
	_close_up = BuilderStyle.main_pill("Close it up", func() -> void: close_up_pressed.emit())
	box.add_child(_close_up)


func _build_actions() -> void:
	_actions = PanelContainer.new()
	_actions.add_theme_stylebox_override("panel", BuilderStyle.scrim())
	add_child(_actions)
	_actions.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_actions.grow_horizontal = GROW_DIRECTION_BEGIN
	_actions.grow_vertical = GROW_DIRECTION_BEGIN
	_actions.offset_right = -8.0
	_actions.offset_bottom = -8.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_actions.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_action_title = Label.new()
	_action_title.add_theme_font_size_override("font_size", 20)
	_action_title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_action_title)
	var done := IconButton.new("close", "Done with this piece")
	done.custom_minimum_size = Vector2(40, 40)
	done.pressed.connect(func() -> void: deselect_pressed.emit())
	top.add_child(done)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(BuilderStyle.word("Add after", MenuStyle.ACCENT, func() -> void: add_after_pressed.emit()))
	row.add_child(BuilderStyle.word("Take out", DANGER, func() -> void: delete_pressed.emit()))
	box.add_child(_choices(SURFACES, _surfaces, func(id: String) -> void: surface_chosen.emit(id)))
	box.add_child(_choices(EDGES, _edges, func(id: String) -> void: edges_chosen.emit(id)))

	_landmark_actions = PanelContainer.new()
	_landmark_actions.add_theme_stylebox_override("panel", BuilderStyle.scrim())
	_landmark_actions.visible = false
	add_child(_landmark_actions)
	_landmark_actions.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_landmark_actions.grow_horizontal = GROW_DIRECTION_BEGIN
	_landmark_actions.grow_vertical = GROW_DIRECTION_BEGIN
	_landmark_actions.offset_right = -8.0
	_landmark_actions.offset_bottom = -8.0
	var lm := VBoxContainer.new()
	lm.add_theme_constant_override("separation", 8)
	_landmark_actions.add_child(lm)
	var hint := Label.new()
	hint.text = "Drag it where you want it"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	lm.add_child(hint)
	var lm_row := HBoxContainer.new()
	lm_row.add_theme_constant_override("separation", 10)
	lm.add_child(lm_row)
	lm_row.add_child(BuilderStyle.dark_pill("Turn", func() -> void: turn_landmark_pressed.emit()))
	lm_row.add_child(BuilderStyle.word("Take away", DANGER, func() -> void: remove_landmark_pressed.emit()))
	var put := BuilderStyle.main_pill("Put it down", func() -> void: drop_landmark_pressed.emit())
	lm.add_child(put)


## A row of small pills to pick one of, like the surfaces.
func _choices(items: Array, keep: Dictionary, picked: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for item in items:
		var id: String = item[1]
		var button := MenuStyle.button(item[0], picked.bind(id))
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 15)
		keep[id] = button
		row.add_child(button)
	return row


func _build_bottom() -> void:
	_bottom = VBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 8)
	add_child(_bottom)
	_bottom.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_bottom.grow_horizontal = GROW_DIRECTION_BOTH
	_bottom.grow_vertical = GROW_DIRECTION_BEGIN
	_bottom.offset_bottom = -14.0
	_status_panel = PanelContainer.new()
	_status_panel.add_theme_stylebox_override("panel", BuilderStyle.scrim(8))
	_status_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	_bottom.add_child(_status_panel)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_panel.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_bottom.add_child(row)
	row.add_child(BuilderStyle.dark_pill("Test drive", func() -> void: drive_pressed.emit()))
	_race = BuilderStyle.main_pill("Race", func() -> void: race_pressed.emit())
	_race.custom_minimum_size.x = 220.0
	row.add_child(_race)


func _build_dialogs() -> void:
	_load_popup = PopupPanel.new()
	_load_popup.theme = MenuStyle.theme()
	_load_popup.add_theme_stylebox_override("panel", BuilderStyle.scrim(12, 0.9))
	add_child(_load_popup)
	var box := VBoxContainer.new()
	_load_popup.add_child(box)
	var title := Label.new()
	title.text = "Load a course"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_load_list = VBoxContainer.new()
	_load_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_load_list)

	_new_dialog = ConfirmationDialog.new()
	_new_dialog.theme = MenuStyle.theme()
	_new_dialog.title = "Start a new course?"
	_new_dialog.dialog_text = "This clears the course. Undo brings it back."
	_new_dialog.ok_button_text = "New"
	_new_dialog.cancel_button_text = "Keep building"
	_new_dialog.confirmed.connect(func() -> void: new_pressed.emit())
	add_child(_new_dialog)

	_name_dialog = ConfirmationDialog.new()
	_name_dialog.theme = MenuStyle.theme()
	_name_dialog.title = "Name your course"
	_name_dialog.ok_button_text = "Rename"
	_name_edit = LineEdit.new()
	_name_edit.max_length = 32
	_name_edit.custom_minimum_size = Vector2(360, 0)
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(func() -> void:
		var text := _name_edit.text.strip_edges()
		if text != "":
			name_changed.emit(text))
	add_child(_name_dialog)


func _open_rename() -> void:
	_name_edit.text = _course_name
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


## Your courses, then the ones that come with the game. Loading one of those
## gives you a copy of it to change.
func _open_load() -> void:
	for child in _load_list.get_children():
		child.queue_free()
	var saved := CourseDesign.saved()
	if not saved.is_empty():
		_load_list.add_child(MenuStyle.heading("Your courses"))
		for path in saved:
			var course := CourseDesign.load_file(path)
			if course != null:
				_load_list.add_child(_load_button(course.name, path))
	_load_list.add_child(MenuStyle.heading("The game's courses", "Load one to build on it. It becomes a course of your own."))
	for id in Tracks.all():
		var track := TrackPath.load_file(Tracks.path_of(id))
		_load_list.add_child(_load_button(track.name, Tracks.path_of(id)))
	_load_popup.popup_centered()


func _load_button(text: String, path: String) -> Button:
	return MenuStyle.button(text, func() -> void:
		_load_popup.hide()
		load_chosen.emit(path))
