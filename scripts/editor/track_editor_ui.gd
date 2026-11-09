class_name TrackEditorUI
extends Control

## The track editor's panels, laid out like the garage's. The course fills the
## screen and every panel floats over it.
##
## Across the top are the tool buttons for leaving, undo, redo, fitting the
## course in view and the file menu. Down the left is the drawer of pieces with
## a rail of tabs, and the landmarks tab has the big things to put around the
## course. In the top right is one line about the course, which opens into its
## card with its name, laps and theme, anything stopping it being raced and
## Close it up. Test drive and race are along the bottom.
##
## Tap a piece of road and its actions come up in the bottom right, and a
## landmark in hand has its own.

signal piece_chosen(spec: Dictionary)
signal landmark_chosen(prop: String)
signal undo_pressed
signal redo_pressed
signal fit_pressed
signal menu_pressed
signal new_pressed
signal save_pressed
signal load_chosen(path: String)
signal share_pressed
signal name_changed(text: String)
signal laps_changed(laps: int)
signal map_rotation_changed(degrees: float)
signal theme_chosen(theme: String)
signal hills_chosen(hills: float)
signal weather_chosen(weather: String)
signal time_chosen(time: String)
signal close_up_pressed
signal join_ends_pressed
signal join_accepted
signal join_cancelled
signal dimension_changed(key: String, metres: float)
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

## Shared drawer data, including its row order and mirrored pieces.
const CATEGORIES := TrackCatalogue.CATEGORIES
const CLOSE_FAILED := "Couldn't close this layout with the available pieces. Adjust the final bends or straights and try again."
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
	["Ferris wheel", "ferris_wheel"], ["Pagoda", "pagoda"], ["Old banking", "old_banking"],
	["Oast house", "oast_house"], ["Standing stones", "standing_stones"], ["Control tower", "control_tower"],
	["Crowd on a bank", "spectator_bank"], ["Viewing deck", "viewing_deck"], ["Kart office", "kart_office"],
	["Parked karts", "kart_row"], ["Carousel", "carousel"], ["Drop tower", "drop_tower"], ["Red roof", "red_roof"],
	["Chalet", "chalet"], ["Alpine church", "alpine_church"], ["Cable car", "cable_car"], ["Ski jump", "ski_jump"],
	["Snowy peak", "snowy_peak"], ["Mesa", "mesa"], ["Butte", "butte"], ["Saloon", "saloon"], ["Water tower", "water_tower"],
	["Saguaro", "saguaro"], ["Mine carts", "mine_carts"], ["Windpump", "windpump"],
	["Stepped pyramid", "stepped_pyramid"], ["Stone head", "stone_head"], ["Waterfall", "waterfall"],
	["Rope bridge", "rope_bridge"], ["Treetop walkway", "canopy_walk"], ["Rock tower", "karst"],
	["Jungle hut", "jungle_hut"], ["Parrots", "parrots"],
	["Neon tower", "neon_tower"], ["Lantern gate", "lantern_gate"], ["Tunnel mouth", "tunnel_mouth"],
	["Spire tower", "spire_tower"], ["Clock tower", "clock_tower"], ["Overpass", "overpass"], ["Temple spire", "chedi"],
	["Office block", "city_block"], ["Terraced houses", "townhouses"], ["Double decker bus", "double_decker"],
	["Tuk tuk", "tuk_tuk"], ["Traffic light", "traffic_light"], ["Neon sign", "neon_sign"], ["Phone box", "phone_box"],
	["Hot air balloon", "hot_air_balloon"], ["Airship", "airship"], ["Airship dock", "sky_dock"], ["Waterfall island", "falls_isle"],
	["Rainbow", "rainbow"], ["Weather vane", "weather_vane"], ["Windmill island", "windmill_isle"], ["Sky lighthouse", "sky_lighthouse"],
	["Floating island", "sky_isle"], ["Cloud", "cloud_puff"],
]
const LANDMARK_GROUPS := [
	["Countryside", ["barn", "silo", "big_windmill", "church", "villa", "cottage", "cabin", "trullo", "stilt_hut", "oast_house", "red_roof"]],
	["Castles", ["castle", "tower", "castle_wall", "lighthouse", "ruins", "pagoda", "standing_stones"]],
	["Industry", ["rocket", "radar", "factory", "crane", "tanks", "chimney", "headframe", "excavator", "wind_turbine", "slag_heap"]],
	["Nature", ["volcano", "mountain", "lake", "pond", "lava_pool"]],
	["Trackside & parks", ["station", "ferris_wheel", "old_banking", "control_tower", "spectator_bank", "viewing_deck", "kart_office", "kart_row", "carousel", "drop_tower"]],
	["Alpine", ["chalet", "alpine_church", "cable_car", "ski_jump", "snowy_peak"]],
	["Desert", ["dune", "mesa", "butte", "saloon", "water_tower", "saguaro", "mine_carts", "windpump"]],
	["Jungle", ["stepped_pyramid", "stone_head", "waterfall", "rope_bridge", "canopy_walk", "karst", "jungle_hut", "parrots"]],
	["City", ["skyscraper", "neon_tower", "lantern_gate", "tunnel_mouth", "spire_tower", "clock_tower", "overpass", "chedi", "city_block", "townhouses", "double_decker", "tuk_tuk", "traffic_light", "neon_sign", "phone_box"]],
	["Sky", ["hot_air_balloon", "airship", "sky_dock", "falls_isle", "rainbow", "weather_vane", "windmill_isle", "sky_lighthouse", "sky_isle", "cloud_puff"]],
]
const SURFACES := [["Road", "asphalt"], ["Concrete", "concrete"], ["Dirt", "dirt"], ["Gravel", "gravel"], ["Grass", "grass"], ["Mud", "mud"], ["Sand", "sand"], ["Ice", "ice"]]
## "Auto" has walls only where you'd fall off, and grass runoff everywhere
## else (see TrackPiece.edges).
const EDGES := [["Auto", "auto"], ["Walls", "walls"], ["Left open", "left_open"], ["Right open", "right_open"], ["Open", "open"]]
## How much the ground rises and falls around the course, in metres (see
## TrackPath.hills).
const HILLS := [["Flat", "0"], ["Rolling", "8"], ["Hilly", "16"]]
## What each theme is called on its button.
const THEME_NAMES := {
	"orchard": "Orchard", "trulli": "Olive groves", "lake": "Lakeside", "mine": "Coal mine",
	"delta": "River delta", "pit": "Open pit", "industry": "Factories", "amber": "Old town",
	"timber": "Mountains", "frost": "Snow", "desert": "Desert city", "railway": "Railway",
	"windmill": "Windmills", "space": "Space centre", "volcano": "Volcano", "castle": "Castle",
	"sakura": "Cherry blossom", "ardennes": "Forest hills", "royal_park": "Royal park", "golden_hills": "Golden hills",
	"kent_downs": "Kent downs", "brittany": "Brittany", "varmland": "Swedish pines", "trondelag": "Norway",
	"hall_red": "Red hall", "hall_green": "Green hall", "hall_blue": "Blue hall", "hall_neon": "Neon hall",
	"park_wonder": "Theme park", "park_lake": "Lakeside park", "park_carolina": "Pine park", "park_desert": "Desert park",
	"alps_meadow": "Alpine meadow", "alps_snow": "Ski resort", "alps_lake": "Alpine lake", "alps_pass": "Mountain pass",
	"canyon_cactus": "Cactus desert", "canyon_ranch": "Desert ranch", "canyon_mesa": "Canyon rim", "canyon_mine": "Gold mine",
	"jungle_canopy": "Rainforest", "jungle_falls": "Jungle waterfall", "jungle_temple": "Jungle temple", "jungle_swamp": "Jungle swamp",
	"city_tokyo": "Neon city", "city_dubai": "City of towers", "city_london": "Old city", "city_bangkok": "Busy city",
	"sky": "Sky", "sky_falls": "Sky waterfalls", "sky_isles": "Sky islands", "sky_port": "Airship port", "sky_balloons": "Balloon festival",
}
const DANGER := BuilderStyle.DANGER
## How far the race buttons sit up from the bottom of the screen.
const BOTTOM_GAP := -14.0
const DATA := BuilderStyle.DATA

var _toolbar: PanelContainer
var _undo: IconButton
var _redo: IconButton
var _file_menu: PopupMenu

var _drawer: PanelContainer
var _drawer_row: HBoxContainer
var _rail_box: RailBox
var _rail: Array[IconButton] = []
var _heading: Label
var _tiles: GridContainer
var _drawer_clearance: Control
var _category := 0
var _landmark_filter: OptionButton
var _landmark_group := 0
var _tile_memory: Dictionary = {}
var _pictures: LandmarkThumbnails

var _chip: Button
var _card: PanelContainer
var _name_label: Label
var _about_label: Label
var _problems_label: Label
var _laps_label: Label
var _map_rotation_label: Label
var _map_preview: CourseOutlineView
var _hills: Dictionary = {}
var _weathers: Dictionary = {}
var _times: Dictionary = {}
var _close_up: Button
var _join_ends: Button
var _join_actions: PanelContainer
var _join_accept: Button
var _join_restore_card := false
var _themes: Dictionary = {}

var _actions: PanelContainer
var _action_title: Label
var _action_dimensions: Label
var _dimension_rows: VBoxContainer
var _length: SpinBox
var _sideways: SpinBox
var _sideways_row: HBoxContainer
var _surfaces: Dictionary = {}
var _edges: Dictionary = {}
var _landmark_actions: PanelContainer

var _bottom: VBoxContainer
var _safe: SafeArea
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
var _close_failure: AcceptDialog
var _course_name := ""
## Whether the course is up in the sky, so the landmarks under the road are
## offered too.
var _in_sky := false


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
	for panel in [_toolbar, _chip, _card, _actions, _join_actions, _landmark_actions, _bottom]:
		safe.watch(panel)
	safe.watch(_drawer, true)
	safe.flow(_rail_box)
	safe.flow(_drawer_row, 1)
	_safe = safe
	_bottom.resized.connect(_lift_actions)
	_lift_actions()


## The piece and landmark panels sit over the race buttons, which they'd
## cover otherwise. Built on where the buttons were put, before SafeArea
## moves anything.
func _lift_actions() -> void:
	for panel in [_actions, _join_actions, _landmark_actions]:
		panel.offset_bottom = BOTTOM_GAP - _bottom.size.y - 8.0
		_safe.moved(panel)


## The race buttons keep clear of the card and the drawer, and the card ends
## above the piece or landmark panel when one's up.
func _keep_clear() -> void:
	BuilderStyle.slide_clear(_bottom, [_drawer], [_card, _actions, _join_actions, _landmark_actions])
	# Leave room to scroll every part above the race buttons on narrow screens.
	var drawer_rect := _drawer.get_global_rect()
	var buttons_rect := _bottom.get_global_rect()
	var clearance := 0.0
	if drawer_rect.intersects(buttons_rect):
		clearance = maxf(0.0, drawer_rect.end.y - buttons_rect.position.y + 8.0)
	_drawer_clearance.custom_minimum_size.y = clearance
	var bottom := 1.0
	if size.y > 0.0:
		for panel: Control in [_actions, _join_actions, _landmark_actions]:
			if panel.visible:
				bottom = minf(bottom, panel.get_global_rect().position.y / size.y)
	if not is_equal_approx(_card.anchor_bottom, bottom):
		_card.set_anchor(SIDE_BOTTOM, bottom, true, false)


## Whether this screen position is on one of the panels instead of the course.
func is_over_ui(pos: Vector2) -> bool:
	if _load_popup.visible or _new_dialog.visible or _name_dialog.visible or _file_menu.visible or _close_failure.visible:
		return true
	for panel in [_toolbar, _drawer, _chip, _card, _actions, _join_actions, _landmark_actions, _bottom]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(pos):
			return true
	return false


# What the editor tells the panels.

## The course's name, length and laps on the chip, and its card.
func show_course(course: CourseDesign, length: float, problems: Array[String], can_close: bool, outline_track: TrackPath = null) -> void:
	_course_name = course.name
	var in_sky: bool = Scenery.theme_named(course.theme).get("void", false)
	if in_sky != _in_sky:
		_in_sky = in_sky
		if _category >= CATEGORIES.size():
			_show_category(_category)
	_chip.text = "%s · %d m · %d lap%s" % [course.name, roundi(length), course.laps, "" if course.laps == 1 else "s"]
	_name_label.text = course.name
	_about_label.text = "%d pieces, %d m a lap" % [course.pieces.size(), roundi(length)]
	_laps_label.text = "%d lap%s" % [course.laps, "" if course.laps == 1 else "s"]
	_map_rotation_label.text = "Map rotation %d°" % roundi(course.map_rotation)
	_map_preview.show_track(outline_track if outline_track != null else course.track())
	for id in _themes:
		BuilderStyle.show_swatch(_themes[id], Color(Scenery.theme_named(id).ground).darkened(0.35), id == course.theme, UiKit.LEAN)
	for id in _hills:
		MenuStyle.mark(_hills[id], is_equal_approx(float(id), course.hills))
	for id in _weathers:
		MenuStyle.mark(_weathers[id], id == course.weather)
	for id in _times:
		MenuStyle.mark(_times[id], id == course.time)
	_problems_label.text = "\n".join(problems.map(func(p): return "• " + p))
	_problems_label.visible = not problems.is_empty()
	_close_up.visible = can_close
	_join_ends.visible = can_close
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
	_action_title.text = "%d · %s" % [index + 1, TrackCatalogue.piece_name(spec)]
	_action_dimensions.text = TrackCatalogue.dimensions(spec)
	_action_dimensions.tooltip_text = _action_dimensions.text
	var adjustable := TrackPiece.adjustable_spec(spec)
	_dimension_rows.visible = not adjustable.is_empty()
	if not adjustable.is_empty():
		_length.set_block_signals(true)
		_length.min_value = 2.0 if adjustable.type == "adjustable_offset" else 0.25
		_length.set_value_no_signal(float(adjustable.metres))
		_length.set_block_signals(false)
		_sideways_row.visible = adjustable.type == "adjustable_offset"
		_sideways.set_value_no_signal(float(adjustable.get("shift", 0.0)))
	var surface: String = spec.get("surface", "asphalt")
	for id in _surfaces:
		MenuStyle.mark(_surfaces[id], id == surface)
	var edges: String = spec.get("edges", "auto")
	for id in _edges:
		MenuStyle.mark(_edges[id], id == edges)


func show_join_preview(on: bool, restore_controls := false) -> void:
	_join_actions.visible = on
	if on:
		_join_restore_card = _card.visible
		_card.hide()
		_actions.hide()
		_join_accept.grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and _join_actions.is_ancestor_of(focused):
			focused.release_focus()
		if restore_controls:
			_card.visible = _join_restore_card
			(_join_ends if _card.visible else _chip).grab_focus()


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
	_status.add_theme_color_override("font_color", UiKit.WHITE)
	_status_panel.visible = true
	_toast_left = 2.5


func show_close_failure() -> void:
	_close_failure.popup_centered(Vector2i(440, 0))


func _show_status() -> void:
	if _toast_left > 0.0:
		return
	if _problem_count > 0 and _hint == "":
		_status.text = "%d thing%s to fix before it can race (see the card)" % [_problem_count, "" if _problem_count == 1 else "s"]
		_status.add_theme_color_override("font_color", DANGER)
	else:
		_status.text = _hint
		_status.add_theme_color_override("font_color", UiKit.SOFT)
	_status_panel.visible = _status.text != ""


func _process(delta: float) -> void:
	_keep_clear()
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_show_status()


# Building the panels.

func _build_toolbar() -> void:
	var close := IconButton.new("close", "Leave the track editor")
	close.pressed.connect(func() -> void: menu_pressed.emit())
	_undo = IconButton.new("undo", "Undo")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_redo = IconButton.new("redo", "Redo")
	_redo.pressed.connect(func() -> void: redo_pressed.emit())
	var fit := IconButton.new("fit", "Fit the course in view")
	fit.pressed.connect(func() -> void: fit_pressed.emit())
	var more := IconButton.new("more", "Save, load, share or start again")
	_toolbar = BuilderStyle.toolbar([[close], [_undo, _redo], [fit], [more]])
	add_child(_toolbar)
	_toolbar.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_toolbar.grow_horizontal = GROW_DIRECTION_BOTH
	_toolbar.offset_top = 8.0
	_file_menu = BuilderStyle.menu(["Save", "Load", "Rename", "Share", "New course"])
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
			share_pressed.emit()
		4:
			_new_dialog.popup_centered()


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
	var tabs: Array = CATEGORIES.map(func(c): return [c[0], c[1]]) + [["Landmarks", "landmarks"]]
	for i in tabs.size():
		var tab := BuilderStyle.rail_tab(tabs[i][1], tabs[i][0])
		tab.pressed.connect(_show_category.bind(i))
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
	_landmark_filter = OptionButton.new()
	_landmark_filter.focus_mode = FOCUS_ALL
	_landmark_filter.fit_to_longest_item = false
	_landmark_filter.clip_text = true
	_landmark_filter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_landmark_filter.add_item("All landmarks")
	for group in LANDMARK_GROUPS:
		_landmark_filter.add_item(group[0])
	_landmark_filter.custom_minimum_size.y = 44.0
	_landmark_filter.item_selected.connect(_choose_landmark_group)
	PadFocus.close_on_b(_landmark_filter.get_popup())
	column.add_child(_landmark_filter)
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
	_drawer_clearance = Control.new()
	_drawer_clearance.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(_drawer_clearance)


func _show_category(index: int) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var restore_focus := focused != null and _tiles.is_ancestor_of(focused)
	_category = index
	for i in _rail.size():
		_rail[i].on = i == index
	for child in _tiles.get_children():
		_tiles.remove_child(child)
		child.queue_free()
	_landmark_filter.visible = index >= CATEGORIES.size()
	if index < CATEGORIES.size():
		_heading.text = CATEGORIES[index][0].to_upper()
		for row in CATEGORIES[index][2]:
			for entry in row:
				_add_piece_tile(entry)
	else:
		_heading.text = "LANDMARKS"
		_landmark_filter.select(_landmark_group)
		var offered := LANDMARKS.filter(func(l):
			return (_in_sky or not l[1] in Props.BELOW_ROAD) and (
				_landmark_group == 0 or l[1] in LANDMARK_GROUPS[_landmark_group - 1][1]))
		_pictures.take(offered.map(func(l): return l[1]))
		for entry in offered:
			var prop: String = entry[1]
			var tile := _tile(entry[0])
			tile.set_meta("prop", prop)
			tile.icon = LandmarkThumbnails.picture(prop)
			tile.tapped.connect(func() -> void: landmark_chosen.emit(prop))
			_add_palette_tile(tile, prop)
	if restore_focus:
		_restore_palette_focus.call_deferred()


func _choose_landmark_group(index: int) -> void:
	_landmark_group = index
	_show_category(_category)


func palette_has_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and (_tiles.is_ancestor_of(focused) or focused == _landmark_filter)


func palette_popup_open() -> bool:
	return _landmark_filter.get_popup().visible


func _add_piece_tile(entry: Array) -> void:
	var spec: Dictionary = entry[1]
	var tile := _tile("")
	var label := Label.new()
	label.text = entry[0]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = "TileLabel"
	label.mouse_filter = MOUSE_FILTER_IGNORE
	tile.add_child(label)
	label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	label.offset_top = -44.0
	label.offset_left = 3.0
	label.offset_right = -3.0
	var picture := PieceIcon.new(spec)
	tile.add_child(picture)
	picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	picture.offset_bottom = -46.0
	tile.set_meta("spec", spec)
	tile.tooltip_text = "%s\n%s" % [TrackCatalogue.piece_name(spec), TrackCatalogue.dimensions(spec)]
	if spec.type == "slant":
		tile.tooltip_text += "\nEnds face forward."
	tile.tapped.connect(func() -> void: piece_chosen.emit(spec.duplicate()))
	_add_palette_tile(tile, entry[0])


func _palette_key() -> String:
	return "%d:%d" % [_category, _landmark_group if _category >= CATEGORIES.size() else 0]


func _add_palette_tile(tile: ScrollButton, id: String) -> void:
	var key := _palette_key()
	var remember := func() -> void: _tile_memory[key] = id
	tile.set_meta("palette_id", id)
	tile.focus_entered.connect(remember)
	tile.tapped.connect(remember)
	_tiles.add_child(tile)


## Returns to the last tile used in this tab or landmark group.
func focus_palette() -> bool:
	var remembered: String = _tile_memory.get(_palette_key(), "")
	var first: BaseButton
	for tile in _tiles.get_children():
		if tile is BaseButton and not tile.is_queued_for_deletion():
			if first == null:
				first = tile
			if tile.get_meta("palette_id", "") == remembered:
				tile.grab_focus()
				_scroll_to_focused_tile.call_deferred(tile)
				return true
	if first != null:
		first.grab_focus()
		return true
	if _landmark_filter.visible:
		_landmark_filter.grab_focus()
		return true
	return false


func _scroll_to_focused_tile(tile: Control) -> void:
	# Rebuilt tabs need a layout pass before their final rows can scroll into view.
	await get_tree().process_frame
	if is_instance_valid(tile) and get_viewport().gui_get_focus_owner() == tile:
		var scroll: ScrollContainer = _tiles.get_parent()
		scroll.ensure_control_visible(tile)


func _restore_palette_focus() -> void:
	if get_viewport().gui_get_focus_owner() == null:
		focus_palette()


func _tile(label: String) -> ScrollButton:
	var tile := ScrollButton.new()
	tile.text = label
	tile.focus_mode = FOCUS_ALL
	tile.custom_minimum_size = BuilderStyle.TILE
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.expand_icon = true
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BuilderStyle.dress_tile(tile)
	return tile


func _show_picture(prop: String, picture: Texture2D) -> void:
	for tile in _tiles.get_children():
		if tile.get_meta("prop", "") == prop:
			tile.icon = picture


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
	_card.add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 8))
	_card.visible = false
	add_child(_card)
	# As tall as the screen, scrolling, since the themes alone are taller
	# than a phone.
	_card.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	_card.grow_horizontal = GROW_DIRECTION_BEGIN
	_card.offset_right = -8.0
	_card.offset_top = 8.0
	_card.offset_bottom = -8.0
	_card.custom_minimum_size = Vector2(330, 0)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_name_label = Label.new()
	_name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_label.clip_text = true
	top.add_child(_name_label)
	var rename := BuilderStyle.word("Rename", UiKit.ACCENT, _open_rename, true)
	top.add_child(rename)
	var close := IconButton.new("close", "Close")
	close.custom_minimum_size = Vector2(40, 40)
	ScrollButton.let_scroll(close, func() -> void:
		_card.visible = false
		_chip.visible = true)
	top.add_child(close)
	_about_label = Label.new()
	_about_label.theme_type_variation = "StatsLabel"
	box.add_child(_about_label)

	var laps := HBoxContainer.new()
	laps.add_theme_constant_override("separation", 8)
	box.add_child(laps)
	var fewer := IconButton.new("shut", "Fewer laps")
	fewer.custom_minimum_size = Vector2(40, 40)
	ScrollButton.let_scroll(fewer, func() -> void: laps_changed.emit(-1))
	laps.add_child(fewer)
	_laps_label = Label.new()
	_laps_label.custom_minimum_size = Vector2(80, 0)
	_laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_laps_label.theme_type_variation = "CardTitleLabel"
	laps.add_child(_laps_label)
	var more := IconButton.new("open", "More laps")
	more.custom_minimum_size = Vector2(40, 40)
	ScrollButton.let_scroll(more, func() -> void: laps_changed.emit(1))
	laps.add_child(more)


	_map_preview = CourseOutlineView.new()
	_map_preview.custom_minimum_size = Vector2(180, 110)
	box.add_child(_map_preview)
	var rotation := HBoxContainer.new()
	rotation.add_theme_constant_override("separation", 8)
	box.add_child(rotation)
	var left := IconButton.new("undo", "Rotate map left")
	left.custom_minimum_size = Vector2(40, 40)
	ScrollButton.let_scroll(left, func() -> void: map_rotation_changed.emit(-15.0))
	rotation.add_child(left)
	_map_rotation_label = Label.new()
	_map_rotation_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_map_rotation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotation.add_child(_map_rotation_label)
	var right := IconButton.new("redo", "Rotate map right")
	right.custom_minimum_size = Vector2(40, 40)
	ScrollButton.let_scroll(right, func() -> void: map_rotation_changed.emit(15.0))
	rotation.add_child(right)

	var theme_heading := Label.new()
	theme_heading.text = "Theme"
	theme_heading.theme_type_variation = "SmallLabel"
	box.add_child(theme_heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for id in THEME_NAMES:
		var ground := Color(Scenery.theme_named(id).ground).darkened(0.35)
		var ink := UiKit.INK if ground.get_luminance() > 0.5 else UiKit.WHITE
		var swatch := BuilderStyle.pill(THEME_NAMES[id], ground, ink, func() -> void: theme_chosen.emit(id), 36.0, true)
		swatch.custom_minimum_size.x = 150.0
		grid.add_child(swatch)
		_themes[id] = swatch

	var hills_heading := Label.new()
	hills_heading.text = "Hills"
	hills_heading.theme_type_variation = "SmallLabel"
	box.add_child(hills_heading)
	box.add_child(_choices(HILLS, _hills, func(id: String) -> void: hills_chosen.emit(float(id))))

	# The weather and time it's raced in, unless whoever races it picks.
	for which in [["Weather", Conditions.WEATHERS, Conditions.WEATHER_NAMES, _weathers, weather_chosen], ["Time of day", Conditions.TIMES, Conditions.TIME_NAMES, _times, time_chosen]]:
		var heading := Label.new()
		heading.text = which[0]
		heading.theme_type_variation = "SmallLabel"
		box.add_child(heading)
		var items := [[which[2][Conditions.RANDOM], Conditions.RANDOM]]
		for id in which[1]:
			items.append([which[2][id].split(" ")[0], id])
		var picked: Signal = which[4]
		box.add_child(_choices(items, which[3], func(id: String) -> void: picked.emit(id), 4))

	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.custom_minimum_size = Vector2(310, 0)
	_problems_label.theme_type_variation = "ProblemLabel"
	box.add_child(_problems_label)
	_close_up = BuilderStyle.main_pill("Close it up", func() -> void: close_up_pressed.emit(), true)
	box.add_child(_close_up)
	_join_ends = BuilderStyle.dark_pill("Join ends", func() -> void: join_ends_pressed.emit())
	box.add_child(_join_ends)


func _build_actions() -> void:
	_actions = PanelContainer.new()
	_actions.add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 8))
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
	_action_title.theme_type_variation = "CardTitleLabel"
	_action_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_action_title.clip_text = true
	top.add_child(_action_title)
	var done := IconButton.new("close", "Done with this piece")
	done.custom_minimum_size = Vector2(40, 40)
	done.pressed.connect(func() -> void: deselect_pressed.emit())
	top.add_child(done)
	_action_dimensions = Label.new()
	_action_dimensions.theme_type_variation = "SmallLabel"
	_action_dimensions.clip_text = true
	box.add_child(_action_dimensions)
	_dimension_rows = VBoxContainer.new()
	_dimension_rows.add_theme_constant_override("separation", 4)
	box.add_child(_dimension_rows)
	_length = _dimension_control(_dimension_rows, "Length", "metres", 0.25, 512.0)
	_sideways = _dimension_control(_dimension_rows, "Sideways", "shift", -256.0, 256.0)
	_sideways_row = _sideways.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(BuilderStyle.word("Add after", UiKit.ACCENT, func() -> void: add_after_pressed.emit()))
	row.add_child(BuilderStyle.word("Take out", DANGER, func() -> void: delete_pressed.emit()))
	box.add_child(_choices(SURFACES, _surfaces, func(id: String) -> void: surface_chosen.emit(id)))
	box.add_child(_choices(EDGES, _edges, func(id: String) -> void: edges_chosen.emit(id)))
	_join_actions = PanelContainer.new()
	_join_actions.add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 8))
	_join_actions.hide()
	add_child(_join_actions)
	_join_actions.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_join_actions.grow_horizontal = GROW_DIRECTION_BEGIN
	_join_actions.grow_vertical = GROW_DIRECTION_BEGIN
	_join_actions.offset_right = -8.0
	_join_actions.offset_bottom = -8.0
	var join_box := VBoxContainer.new()
	join_box.add_theme_constant_override("separation", 6)
	_join_actions.add_child(join_box)
	var join_title := Label.new()
	join_title.text = "Join ends"
	join_title.theme_type_variation = "CardTitleLabel"
	join_box.add_child(join_title)
	_join_accept = BuilderStyle.main_pill("Use join", func() -> void: join_accepted.emit())
	join_box.add_child(_join_accept)
	join_box.add_child(BuilderStyle.dark_pill("Cancel", func() -> void: join_cancelled.emit()))

	_landmark_actions = PanelContainer.new()
	_landmark_actions.add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 8))
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
	hint.theme_type_variation = "SmallLabel"
	lm.add_child(hint)
	var lm_row := HBoxContainer.new()
	lm_row.add_theme_constant_override("separation", 10)
	lm.add_child(lm_row)
	lm_row.add_child(BuilderStyle.dark_pill("Turn", func() -> void: turn_landmark_pressed.emit()))
	lm_row.add_child(BuilderStyle.word("Take away", DANGER, func() -> void: remove_landmark_pressed.emit()))
	var put := BuilderStyle.main_pill("Put it down", func() -> void: drop_landmark_pressed.emit())
	lm.add_child(put)


## A row of small pills to pick one of, like the surfaces.
func _dimension_control(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = "SmallLabel"
	label.custom_minimum_size.x = 80
	row.add_child(label)
	var less := BuilderStyle.dark_pill("−", func() -> void: pass)
	less.custom_minimum_size.x = 40
	less.tooltip_text = "Reduce %s by 0.25 m" % title.to_lower()
	row.add_child(less)
	var number := SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.step = 0.001
	number.suffix = " m"
	number.custom_minimum_size.x = 116
	number.size_flags_horizontal = SIZE_EXPAND_FILL
	number.update_on_text_changed = false
	number.value_changed.connect(func(value: float) -> void: dimension_changed.emit(key, value))
	row.add_child(number)
	less.pressed.connect(func() -> void: number.value = maxf(number.min_value, number.value - 0.25))
	var more := BuilderStyle.dark_pill("+", func() -> void: number.value = minf(number.max_value, number.value + 0.25))
	more.custom_minimum_size.x = 40
	more.tooltip_text = "Increase %s by 0.25 m" % title.to_lower()
	row.add_child(more)
	return number


func _choices(items: Array, keep: Dictionary, picked: Callable, columns := 0) -> Container:
	var row: Container = GridContainer.new() if columns > 0 else HBoxContainer.new()
	if columns > 0:
		row.columns = columns
		row.add_theme_constant_override("h_separation", 4)
		row.add_theme_constant_override("v_separation", 4)
	row.add_theme_constant_override("separation", 4)
	for item in items:
		var id: String = item[1]
		var button := MenuStyle.button(item[0], picked.bind(id))
		button.custom_minimum_size = Vector2(0, 40)
		button.theme_type_variation = "ChoiceButton"
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
	_bottom.offset_bottom = BOTTOM_GAP
	_status_panel = PanelContainer.new()
	_status_panel.add_theme_stylebox_override("panel", BuilderStyle.scrim(10, 4))
	_status_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	_bottom.add_child(_status_panel)
	_status = Label.new()
	_status.theme_type_variation = "StatusLabel"
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
	_close_failure = AcceptDialog.new()
	_close_failure.theme = MenuStyle.theme()
	_close_failure.title = "Close it up"
	_close_failure.dialog_text = CLOSE_FAILED
	_close_failure.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_close_failure)
	PadFocus.close_on_b(_close_failure)
	_load_popup = PopupPanel.new()
	_load_popup.theme = MenuStyle.theme()
	add_child(_load_popup)
	var box := VBoxContainer.new()
	_load_popup.add_child(box)
	var title := Label.new()
	title.text = "Load a course"
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
	_new_dialog.title = "Start a new course?"
	_new_dialog.dialog_text = "This clears the course. Undo brings it back."
	_new_dialog.ok_button_text = "New"
	_new_dialog.cancel_button_text = "Keep building"
	_new_dialog.confirmed.connect(func() -> void: new_pressed.emit())
	add_child(_new_dialog)

	_name_dialog = ConfirmationDialog.new()
	PadFocus.close_on_b(_name_dialog)
	_name_dialog.theme = MenuStyle.theme()
	_name_dialog.title = "Name your course"
	_name_dialog.ok_button_text = "Rename"
	_name_edit = LineEdit.new()
	PadKeyboard.attach(_name_edit)
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
	_load_list.add_child(MenuStyle.button("Add a course you've been sent", func() -> void:
		_load_popup.hide()
		AddWindow.open(self, "Add a course").added.connect(func(kind: String, path: String) -> void:
			if kind == Sharing.COURSE:
				load_chosen.emit(path))))
	var saved := CourseDesign.saved()
	if not saved.is_empty():
		_load_list.add_child(MenuStyle.heading("Your courses"))
		for path in saved:
			var course := CourseDesign.load_file(path)
			if course != null:
				_load_list.add_child(_load_button(course.name, path))
	_load_list.add_child(MenuStyle.heading("The game's courses"))
	for id in Tracks.all():
		var track := TrackPath.load_file(Tracks.path_of(id))
		_load_list.add_child(_load_button(track.name, Tracks.path_of(id)))
	_load_popup.popup_centered()


func _load_button(text: String, path: String) -> Button:
	return MenuStyle.button(text, func() -> void:
		_load_popup.hide()
		load_chosen.emit(path))
