class_name GarageUI
extends Control

## The garage's panels. The kart fills the screen and every panel floats over
## it on its own dark, see-through backing.
##
## Across the top is a row of round tool buttons for leaving, undo, redo,
## mirror, paint, the camera views and the file menu. Down the left is the
## parts drawer, with a rail of tabs and a picture of each part. The drawer
## slides away while you've got a part in hand or picked out, and a little
## handle at the edge brings it back. In the top right is one line of how the
## kart will drive, which opens into the whole card.
##
## A part in hand shows in a chip under the toolbar, with the arrows, up and
## down, turn, flip, way on, slide and place in the bottom right. Tap a part on the kart and its
## actions pop up beside it. Race and test drive are along the bottom.

signal part_chosen(id: String)
## A part dragged out of the drawer. `finger` is the touch index, or -1 for
## the mouse.
signal part_dragged(id: String, finger: int)
signal nudged(direction: Vector2i)
signal raise_pressed
signal lower_pressed
signal turn_pressed
signal flip_pressed
signal way_pressed
signal slide_pressed
signal place_pressed
signal cancel_pressed
signal move_pressed
signal copy_pressed
signal delete_pressed
signal deselect_pressed
signal undo_pressed
signal redo_pressed
signal mirror_toggled(on: bool)
signal paint_toggled(on: bool)
signal colour_chosen(colour: Color)
signal view_pressed(view: String)
signal new_pressed
signal save_pressed
signal load_chosen(path: String)
signal drive_pressed
signal race_pressed
signal menu_pressed
signal name_changed(text: String)
## A tab of the drawer was opened, with the parts on it.
signal tab_shown(ids: Array)

## The drawer's tabs: name, kinds of part, groups of part and picture. A
## part goes in the tab for its group, or for its kind if it hasn't got one.
## Wings all go together.
const CATEGORIES := [
	["Plates", ["plate"], ["plates", "tiles"], "plates"],
	["Bricks", ["brick"], ["bricks", "brackets"], "bricks"],
	["Curves", ["body", "fairing", "gadget"], ["curves", "slopes", "arches"], "slopes"],
	["Rods and joints", [], ["bars", "technic", "hinges"], "rods"],
	["Wheels", ["wheel"], ["wheels"], "wheels"],
	["Engines", ["engine"], [], "engines"],
	["Cockpit", ["seat", "steering", "screen"], ["details"], "extras"],
	["Bikes", [], ["bike"], "bikes"],
	["Wings", ["wing"], [], "wings"],
]
## The colours you can paint parts, the classic brick ones.
const PAINTS := [
	"#c4281c", "#da8540", "#f2cd37", "#a4bd46", "#4b9f4a", "#237841", "#36aebf", "#0d69ab",
	"#143044", "#7b2e2f", "#694030", "#d7c599", "#f2f3f2", "#a3a2a4", "#635f61", "#1b2a34",
]
## What the stats card says about where most of the kart's drag comes from.
const DRAG_TIPS := {
	"driver": "Most of the drag is the driver. A windscreen in front of them, or a seat that lays them back, would help.",
	"wheels": "Most of the drag is the wheels. Fairings in front of them would help.",
	"flat": "Most of the drag is flat fronts. Slopes, curves or a nose cone would help.",
	"smooth": "The air gets past this kart smoothly.",
}
const DANGER := BuilderStyle.DANGER
const DATA := BuilderStyle.DATA

enum Mode { IDLE, PLACING, SELECTED, PAINTING }

var _toolbar: HBoxContainer
var _undo: IconButton
var _redo: IconButton
var _mirror: IconButton
var _paint: IconButton
var _views_menu: PopupMenu
var _file_menu: PopupMenu

var _drawer: PanelContainer
## The drawer's row (the rail, then the tiles) and the rail itself, which
## make way for a camera hole partway down the side (see SafeArea).
var _drawer_row: HBoxContainer
var _rail_box: VBoxContainer
var _drawer_handle: Button
var _drawer_open := true
## The drawer was pulled back out while a part is in hand, so it stays out.
var _peek := false
var _rail: Array[IconButton] = []
var _heading: Label
var _tiles: GridContainer
var _category := 0

var _stats_chip: Button
var _stats_card: PanelContainer
var _stats_name: Label
var _stats_label: Label
var _problems_label: Label
var _tip_label: Label
var _problem_count := 0

var _held_chip: PanelContainer
var _held_picture: TextureRect
## The parts on the drawer's tab that's open.
var shown: Array = []
var _held_name: Label
var _placing: PanelContainer
var _place: Button
var _turn_buttons: Array[Button] = []
var _flip: Button
var _way: Button
var _slide: Button
var _actions: PanelContainer
var _action_title: Label
var _anchor := Vector2.ZERO
var _painting: PanelContainer
var _swatches: Array[Button] = []
var _paint_colour := Color(PAINTS[0])

var _bottom: VBoxContainer
var _status: Label
var _status_panel: PanelContainer
var _drive: Button
var _race: Button
var _toast_left := 0.0
var _hint := ""

var _load_popup: PopupPanel
var _load_list: VBoxContainer
var _new_dialog: ConfirmationDialog
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _kart_name := ""
var _mode := Mode.IDLE
var _mirror_on := false


func _ready() -> void:
	theme = MenuStyle.theme()
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_toolbar()
	_build_drawer()
	_build_stats()
	_build_held_chip()
	_build_placing()
	_build_actions()
	_build_painting()
	_build_bottom()
	_build_dialogs()
	_show_category(0)
	set_mode(Mode.IDLE, "")
	# Nothing hides under a camera hole.
	var safe := SafeArea.new()
	add_child(safe)
	for panel in [_toolbar, _drawer_handle, _stats_chip, _stats_card, _held_chip, _placing, _actions, _painting, _bottom]:
		safe.watch(panel)
	safe.watch(_drawer, true)
	safe.flow(_rail_box)
	safe.flow(_drawer_row, 1)


## Whether this screen position is on one of the panels instead of the kart.
func is_over_ui(pos: Vector2) -> bool:
	if _load_popup.visible or _new_dialog.visible or _name_dialog.visible or _views_menu.visible or _file_menu.visible:
		return true
	for panel in [_toolbar, _drawer, _drawer_handle, _stats_chip, _stats_card, _held_chip, _placing, _actions, _painting, _bottom]:
		if panel.visible and panel.get_global_rect().has_point(pos):
			return true
	return false


func is_over_bank(pos: Vector2) -> bool:
	return _drawer_open and _drawer.get_global_rect().has_point(pos)


func set_kart_name(text: String) -> void:
	_kart_name = text
	_stats_name.text = text


## Shows the controls for what you're doing, with `what` being the part you're
## placing or have picked out. `moves` says which of "turn", "flip", "way" and
## "slide" it can do.
func set_mode(mode: Mode, what: String, moves := {}) -> void:
	if mode != _mode:
		_peek = false
	_mode = mode
	for button in _turn_buttons:
		button.disabled = not moves.get("turn", true)
	_flip.disabled = not moves.get("flip", false)
	_way.disabled = not moves.get("way", false)
	_slide.disabled = not moves.get("slide", false)
	_held_chip.visible = mode == Mode.PLACING
	_placing.visible = mode == Mode.PLACING
	_actions.visible = mode == Mode.SELECTED
	_painting.visible = mode == Mode.PAINTING
	_paint.on = mode == Mode.PAINTING
	match mode:
		Mode.PLACING:
			_held_name.text = what
			_hint = "Drag it or tap a dot where it goes."
		Mode.SELECTED:
			_action_title.text = what
			_hint = ""
		Mode.PAINTING:
			_hint = "Tap parts to paint them."
		_:
			_hint = "Drag a part from the left onto the kart, or tap one on the kart."
	_show_drawer(mode == Mode.IDLE or mode == Mode.PAINTING or _peek)
	_show_status()


func set_held_picture(picture: Texture2D) -> void:
	_held_picture.texture = picture


func set_can_place(ok: bool) -> void:
	_place.disabled = not ok


func set_history(can_undo: bool, can_redo: bool) -> void:
	_undo.disabled = not can_undo
	_redo.disabled = not can_redo


func set_mirror(on: bool) -> void:
	_mirror_on = on
	_mirror.on = on


func paint_colour() -> Color:
	return _paint_colour


## Where the picked out part is on the screen, so its actions sit beside it.
func set_selection_anchor(pos: Vector2) -> void:
	_anchor = pos
	if _actions.visible:
		_place_actions()


func show_stats(stats: KartStats, problems: Array[String]) -> void:
	var lines := [
		"Top speed  %d km/h" % roundi(stats.top_speed() * 3.6),
		"Pull  %.2f g" % stats.pull(),
		"Cornering  %.2f g" % stats.cornering(),
		"Control  %d%%" % roundi(stats.control * 100.0),
		"Off-road grip  %+d%%" % roundi(stats.offroad * 100.0),
		"Weight  %d kg" % roundi(stats.mass),
		"Power  %.1f kW" % (stats.power / 1000.0),
	]
	if stats.thrust > 0.0:
		lines.append("Thrust  %d N" % roundi(stats.thrust))
	lines.append("Drag  %.2f m²" % stats.drag_area)
	lines.append("Wheels  %d" % stats.wheels.size())
	if stats.lift_area > 0.0:
		lines.append("Wing  %.2f m²" % stats.lift_area)
	_stats_label.text = "\n".join(lines)
	_tip_label.text = DRAG_TIPS.get(stats.most_drag(), "") if not stats.parts.is_empty() else ""
	_tip_label.visible = _tip_label.text != ""
	_problems_label.text = "\n\n".join(problems)
	_problems_label.visible = not problems.is_empty()
	_problem_count = problems.size()
	_stats_chip.text = "%s%d km/h  ·  %.2f g  ·  %d kg" % ["!  " if problems.size() > 0 else "", roundi(stats.top_speed() * 3.6), stats.pull(), roundi(stats.mass)]
	_stats_chip.add_theme_color_override("font_color", DANGER if problems.size() > 0 else DATA)
	_drive.disabled = not problems.is_empty()
	_race.disabled = not problems.is_empty()
	_show_status()


func toast(text: String) -> void:
	_status.text = text
	_status_panel.visible = true
	_toast_left = 2.0


## The line over the race button. It shows a message for a moment after
## something happens, otherwise what's wrong with the kart, or a hint.
func _show_status() -> void:
	if _toast_left > 0.0:
		return
	if _problem_count > 0 and _mode == Mode.IDLE:
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
	var close := IconButton.new("close", "Leave the garage")
	close.pressed.connect(func() -> void: menu_pressed.emit())
	_undo = IconButton.new("undo", "Undo")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_redo = IconButton.new("redo", "Redo")
	_redo.pressed.connect(func() -> void: redo_pressed.emit())
	_mirror = IconButton.new("mirror", "Mirror parts onto both sides")
	_mirror.pressed.connect(func() -> void: mirror_toggled.emit(not _mirror_on))
	_paint = IconButton.new("paint", "Paint")
	_paint.pressed.connect(func() -> void: paint_toggled.emit(_mode != Mode.PAINTING))
	var camera := IconButton.new("camera", "Camera views")
	var more := IconButton.new("more", "Save, load or start again")
	for button in [close, _undo, _redo, _mirror, _paint, camera, more]:
		_toolbar.add_child(button)

	_views_menu = _menu(["Front", "Side", "Top", "Angle", "Fit the kart"])
	_views_menu.id_pressed.connect(func(id: int) -> void: view_pressed.emit(["front", "side", "top", "angle", "fit"][id]))
	camera.pressed.connect(_pop_under.bind(_views_menu, camera))
	_file_menu = _menu(["Save", "Load", "Rename", "New kart"])
	_file_menu.id_pressed.connect(_on_file_menu)
	more.pressed.connect(_pop_under.bind(_file_menu, more))


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


func _menu(items: Array) -> PopupMenu:
	var list := BuilderStyle.menu(items)
	add_child(list)
	return list


func _pop_under(menu: PopupMenu, button: Control) -> void:
	var rect := button.get_global_rect()
	menu.popup(Rect2i(Vector2i(rect.position + Vector2(0, rect.size.y + 6)), Vector2i(220, 0)))


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
	# The rail of tabs down the edge.
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 4)
	row.add_child(rail)
	_rail_box = rail
	_drawer_row = row
	for i in CATEGORIES.size():
		var tab := IconButton.new(CATEGORIES[i][3], CATEGORIES[i][0])
		tab.pressed.connect(_show_category.bind(i))
		rail.add_child(tab)
		_rail.append(tab)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 18)
	_heading.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_heading.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(_heading)
	var shut := IconButton.new("shut", "Put the parts away")
	shut.custom_minimum_size = Vector2(40, 40)
	shut.pressed.connect(func() -> void:
		_peek = false
		_show_drawer(false))
	heading.add_child(shut)
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

	# The handle that's left at the edge when the drawer is away.
	_drawer_handle = BuilderStyle.drawer_handle(func() -> void:
		_peek = true
		_show_drawer(true))
	add_child(_drawer_handle)
	_drawer_handle.set_anchors_and_offsets_preset(PRESET_CENTER_LEFT)
	_drawer_handle.offset_top = -40.0
	_drawer_handle.offset_bottom = 40.0


func _show_drawer(open: bool) -> void:
	_drawer_open = open
	_drawer.visible = open
	_drawer_handle.visible = not open


func _show_category(index: int) -> void:
	_category = index
	for i in _rail.size():
		_rail[i].on = i == index
	_heading.text = CATEGORIES[index][0].to_upper()
	for child in _tiles.get_children():
		child.queue_free()
	shown.clear()
	var ids := PartCatalog.in_garage()
	ids.sort_custom(func(a, b): return PartCatalog.get_part(a).mass < PartCatalog.get_part(b).mass)
	for id in ids:
		var part := PartCatalog.get_part(id)
		if category_of(part) != index:
			continue
		var tile := PartTile.new(id, part.name)
		tile.chosen.connect(func() -> void: part_chosen.emit(id))
		tile.dragged.connect(func(finger: int) -> void: part_dragged.emit(id, finger))
		_tiles.add_child(tile)
		shown.append(id)
	tab_shown.emit(shown)


## Which of the drawer's tabs a part goes in.
static func category_of(def: Dictionary) -> int:
	var kind: String = def.get("kind", "")
	var group: String = def.get("group", "")
	for i in CATEGORIES.size():
		if kind == "wing" and CATEGORIES[i][1].has(kind):
			return i
	if group != "":
		for i in CATEGORIES.size():
			if CATEGORIES[i][2].has(group):
				return i
	for i in CATEGORIES.size():
		if CATEGORIES[i][1].has(kind):
			return i
	return 0


## Puts a part's picture on its tile once it's been taken.
func show_picture(id: String, picture: Texture2D) -> void:
	for tile in _tiles.get_children():
		if tile is PartTile and tile.id == id:
			tile.icon = picture


func _build_stats() -> void:
	_stats_chip = Button.new()
	_stats_chip.focus_mode = FOCUS_ALL
	_stats_chip.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed"]:
		_stats_chip.add_theme_stylebox_override(state, BuilderStyle.scrim(8))
	_stats_chip.pressed.connect(func() -> void:
		_stats_chip.visible = false
		_stats_card.visible = true)
	add_child(_stats_chip)
	_stats_chip.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_stats_chip.grow_horizontal = GROW_DIRECTION_BEGIN
	_stats_chip.offset_right = -8.0
	_stats_chip.offset_top = 8.0

	_stats_card = PanelContainer.new()
	_stats_card.add_theme_stylebox_override("panel", BuilderStyle.scrim())
	_stats_card.visible = false
	add_child(_stats_card)
	_stats_card.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_stats_card.grow_horizontal = GROW_DIRECTION_BEGIN
	_stats_card.offset_right = -8.0
	_stats_card.offset_top = 8.0
	_stats_card.custom_minimum_size = Vector2(250, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_stats_card.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_stats_name = Label.new()
	_stats_name.add_theme_font_size_override("font_size", 22)
	_stats_name.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_stats_name)
	var close := IconButton.new("close", "Close")
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(func() -> void:
		_stats_card.visible = false
		_stats_chip.visible = true)
	top.add_child(close)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", DATA)
	box.add_child(_stats_label)
	_tip_label = Label.new()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(230, 0)
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(_tip_label)
	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.custom_minimum_size = Vector2(230, 0)
	_problems_label.add_theme_color_override("font_color", DANGER)
	_problems_label.add_theme_font_size_override("font_size", 17)
	box.add_child(_problems_label)


func _build_held_chip() -> void:
	_held_chip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MenuStyle.ACCENT, 0.25)
	style.set_corner_radius_all(24)
	style.content_margin_left = 8
	style.content_margin_right = 4
	_held_chip.add_theme_stylebox_override("panel", style)
	add_child(_held_chip)
	_held_chip.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_held_chip.grow_horizontal = GROW_DIRECTION_BOTH
	_held_chip.offset_top = 66.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_held_chip.add_child(row)
	_held_picture = TextureRect.new()
	_held_picture.custom_minimum_size = Vector2(40, 40)
	_held_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_held_picture)
	_held_name = Label.new()
	_held_name.add_theme_font_size_override("font_size", 20)
	row.add_child(_held_name)
	var drop := IconButton.new("close", "Put it down")
	drop.custom_minimum_size = Vector2(40, 40)
	drop.pressed.connect(func() -> void: cancel_pressed.emit())
	row.add_child(drop)


## The controls for putting a part in hand exactly where you want it.
func _build_placing() -> void:
	_placing = PanelContainer.new()
	var panel := BuilderStyle.scrim(16)
	panel.set_content_margin_all(14)
	_placing.add_theme_stylebox_override("panel", panel)
	add_child(_placing)
	_placing.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_placing.grow_horizontal = GROW_DIRECTION_BEGIN
	_placing.grow_vertical = GROW_DIRECTION_BEGIN
	_placing.offset_right = -8.0
	_placing.offset_bottom = -8.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_placing.add_child(row)
	var pad := NudgePad.new()
	pad.nudged.connect(func(d: Vector2i) -> void: nudged.emit(d))
	row.add_child(pad)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)
	var updown := HBoxContainer.new()
	updown.add_theme_constant_override("separation", 8)
	column.add_child(updown)
	for pair in [["Up", raise_pressed], ["Down", lower_pressed]]:
		var button := RepeatButton.new()
		BuilderStyle.chip(button, pair[0])
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		var sig: Signal = pair[1]
		button.fired.connect(func() -> void: sig.emit())
		updown.add_child(button)
	var moves := GridContainer.new()
	moves.columns = 2
	moves.add_theme_constant_override("h_separation", 8)
	moves.add_theme_constant_override("v_separation", 8)
	column.add_child(moves)
	var turn := Button.new()
	BuilderStyle.chip(turn, "Turn")
	turn.pressed.connect(func() -> void: turn_pressed.emit())
	_turn_buttons.append(turn)
	_flip = Button.new()
	BuilderStyle.chip(_flip, "Flip")
	_flip.pressed.connect(func() -> void: flip_pressed.emit())
	_way = Button.new()
	BuilderStyle.chip(_way, "Way on")
	_way.pressed.connect(func() -> void: way_pressed.emit())
	_slide = RepeatButton.new()
	BuilderStyle.chip(_slide, "Slide")
	_slide.fired.connect(func() -> void: slide_pressed.emit())
	for button in [turn, _flip, _way, _slide]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		moves.add_child(button)
	_place = BuilderStyle.pill("Place", MenuStyle.ACCENT, BuilderStyle.ON_ACCENT, func() -> void: place_pressed.emit(), 52.0)
	# Placing a part makes its own snap, so no click on top.
	_place.set_meta("quiet", true)
	column.add_child(_place)


## A picked out part's actions, which float beside it.
func _build_actions() -> void:
	_actions = PanelContainer.new()
	_actions.add_theme_stylebox_override("panel", BuilderStyle.scrim(8, 0.82))
	add_child(_actions)
	var row := HBoxContainer.new()
	_actions.add_child(row)
	_action_title = Label.new()
	_action_title.add_theme_font_size_override("font_size", 16)
	_action_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_action_title.custom_minimum_size = Vector2(150, 0)
	_action_title.clip_text = true
	row.add_child(_action_title)
	row.add_child(BuilderStyle.word("Move", MenuStyle.ACCENT, func() -> void: move_pressed.emit()))
	var turn := BuilderStyle.word("Turn", MenuStyle.ACCENT, func() -> void: turn_pressed.emit())
	_turn_buttons.append(turn)
	row.add_child(turn)
	row.add_child(BuilderStyle.word("Copy", MenuStyle.ACCENT, func() -> void: copy_pressed.emit()))
	row.add_child(BuilderStyle.word("Delete", DANGER, func() -> void: delete_pressed.emit()))
	var close := IconButton.new("close", "Done")
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(func() -> void: deselect_pressed.emit())
	row.add_child(close)


## Under the part where there's room, otherwise over it, and always on screen.
func _place_actions() -> void:
	_actions.reset_size()
	var bar := _actions.size
	var screen := size
	var bottom_limit := screen.y - 150.0
	var y := _anchor.y + 44.0
	if y + bar.y > bottom_limit:
		y = _anchor.y - 44.0 - bar.y
	y = clampf(y, 64.0, maxf(bottom_limit - bar.y, 64.0))
	var x := clampf(_anchor.x - bar.x * 0.5, 8.0, maxf(screen.x - bar.x - 8.0, 8.0))
	_actions.position = Vector2(x, y)


func _build_painting() -> void:
	_painting = PanelContainer.new()
	_painting.add_theme_stylebox_override("panel", BuilderStyle.scrim(16))
	add_child(_painting)
	_painting.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_painting.grow_horizontal = GROW_DIRECTION_BEGIN
	_painting.grow_vertical = GROW_DIRECTION_BEGIN
	_painting.offset_right = -8.0
	_painting.offset_bottom = -8.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_painting.add_child(row)
	var swatches := GridContainer.new()
	swatches.columns = 8
	swatches.add_theme_constant_override("h_separation", 6)
	swatches.add_theme_constant_override("v_separation", 6)
	row.add_child(swatches)
	for hex in PAINTS:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(42, 42)
		swatch.focus_mode = FOCUS_ALL
		var colour := Color(hex)
		swatch.set_meta("colour", colour)
		swatch.pressed.connect(func() -> void:
			_paint_colour = colour
			_show_swatches()
			colour_chosen.emit(colour))
		swatches.add_child(swatch)
		_swatches.append(swatch)
	var done := IconButton.new("close", "Stop painting")
	done.pressed.connect(func() -> void: paint_toggled.emit(false))
	row.add_child(done)
	_show_swatches()


## The paint colour before or after, for a controller's LB and RB.
func next_colour(by: int) -> void:
	var at := PAINTS.find("#" + _paint_colour.to_html(false))
	_paint_colour = Color(PAINTS[posmod(at + by, PAINTS.size())])
	_show_swatches()
	colour_chosen.emit(_paint_colour)


func _show_swatches() -> void:
	for swatch in _swatches:
		var colour: Color = swatch.get_meta("colour")
		BuilderStyle.show_swatch(swatch, colour, colour.is_equal_approx(_paint_colour))


## A line of news, then test drive and a big race button, along the bottom.
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
	_drive = BuilderStyle.dark_pill("Test drive", func() -> void: drive_pressed.emit())
	row.add_child(_drive)
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
	title.text = "Load a kart"
	title.add_theme_font_size_override("font_size", 26)
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
	_new_dialog.theme = MenuStyle.theme()
	_new_dialog.title = "Start a new kart?"
	_new_dialog.dialog_text = "This clears the garage. Undo brings it back."
	_new_dialog.ok_button_text = "New"
	_new_dialog.cancel_button_text = "Keep building"
	_new_dialog.confirmed.connect(func() -> void: new_pressed.emit())
	add_child(_new_dialog)

	_name_dialog = ConfirmationDialog.new()
	_name_dialog.theme = MenuStyle.theme()
	_name_dialog.title = "Name your kart"
	_name_dialog.ok_button_text = "Rename"
	_name_edit = LineEdit.new()
	_name_edit.max_length = 32
	_name_edit.custom_minimum_size = Vector2(360, 0)
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(func() -> void:
		var text := _name_edit.text.strip_edges()
		if text != "":
			name_changed.emit(text)
			set_kart_name(text))
	add_child(_name_dialog)


func _open_rename() -> void:
	_name_edit.text = _kart_name
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


## The karts you've saved, then the stock karts. Loading a stock kart gives
## you a copy of it to change.
func _open_load() -> void:
	for child in _load_list.get_children():
		child.queue_free()
	var saved := KartDesign.saved_paths()
	if not saved.is_empty():
		_load_list.add_child(MenuStyle.heading("Your karts"))
		for path in saved:
			_load_list.add_child(_load_button(KartDesign.load_file(path).name, path))
	_load_list.add_child(MenuStyle.heading("Stock karts"))
	for key in Game.stock_keys():
		var design := Game.stock_kart(key)
		_load_list.add_child(_load_button(design.name, "%s/%s.json" % [Game.STOCK, key]))
	_load_popup.popup_centered()


func _load_button(text: String, path: String) -> Button:
	return MenuStyle.button(text, func() -> void:
		_load_popup.hide()
		load_chosen.emit(path))


## A part in the drawer: its picture and name. Tap it to get it on the kart,
## or drag it sideways out onto the kart. Dragging up or down scrolls instead.
class PartTile:
	extends Button

	signal chosen
	signal dragged(finger: int)

	const DRAG_START := 22.0

	var id := ""
	var _press := Vector2.ZERO
	var _pressing := false
	var _dragged := false

	func _init(part_id: String, label: String) -> void:
		id = part_id
		text = label
		icon = PartThumbnails.picture(part_id)
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		expand_icon = true
		focus_mode = FOCUS_ALL
		custom_minimum_size = BuilderStyle.TILE
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_theme_font_size_override("font_size", 14)
		for state in ["normal", "hover", "pressed"]:
			add_theme_stylebox_override(state, BuilderStyle.tile_box(state))
		pressed.connect(func() -> void:
			if not _dragged:
				chosen.emit())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_pressing = event.pressed
			if event.pressed:
				_press = event.position
				_dragged = false
		elif event is InputEventScreenDrag and _pressing and not _dragged:
			var moved: Vector2 = event.position - _press
			if moved.length() > DRAG_START and absf(moved.x) > absf(moved.y):
				_dragged = true
				dragged.emit(event.index)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
			_pressing = event.pressed
			if event.pressed:
				_press = event.position
				_dragged = false
		elif event is InputEventMouseMotion and _pressing and not _dragged and not DisplayServer.is_touchscreen_available():
			var moved: Vector2 = event.position - _press
			if moved.length() > DRAG_START and absf(moved.x) > absf(moved.y):
				_dragged = true
				dragged.emit(-1)
