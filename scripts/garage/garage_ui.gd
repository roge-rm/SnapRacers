class_name GarageUI
extends Control

## The garage's panels. The part bank is down the left, the kart's name and
## the file buttons are along the top, how it'll drive is on the right, and
## the buttons for the part you're holding or have picked out are along the
## bottom. Everything in between is the 3D view, which the garage handles.

signal part_chosen(id: String)
signal turn_pressed
signal remove_pressed
signal pick_up_pressed
signal undo_pressed
signal done_pressed
signal new_pressed
signal save_pressed
signal load_chosen(path: String)
signal drive_pressed
signal name_changed(text: String)

const SIDE_WIDTH := 330.0
const CATEGORIES := [
	["Plates", ["plate"]],
	["Bricks", ["brick"]],
	["Wheels", ["wheel"]],
	["Engines", ["engine"]],
	["Extras", ["seat", "wing"]],
]
const WARNING := Color("#ffb347")

var _left: PanelContainer
var _right: PanelContainer
var _top: HBoxContainer
var _bottom: HBoxContainer
var _part_list: VBoxContainer
var _part_group := ButtonGroup.new()
var _category_group := ButtonGroup.new()
var _name_edit: LineEdit
var _stats_label: Label
var _problems_label: Label
var _drive: Button
var _turn: Button
var _remove: Button
var _pick_up: Button
var _done: Button
var _undo: Button
var _hint: Label
var _toast: Label
var _toast_left := 0.0
var _load_popup: PopupPanel
var _load_list: VBoxContainer


func _ready() -> void:
	theme = Game.theme
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_left()
	_build_right()
	_build_top()
	_build_bottom()
	_build_load_popup()

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_hint.offset_left = SIDE_WIDTH + 12.0
	_hint.offset_right = -SIDE_WIDTH + 28.0
	_hint.offset_top = 76.0

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(PRESET_CENTER)

	_show_category(0)


## Is this screen position on one of the panels rather than the 3D view?
func is_over_ui(pos: Vector2) -> bool:
	if _load_popup.visible:
		return true
	for panel in [_left, _right, _top, _bottom]:
		if panel.visible and panel.get_global_rect().has_point(pos):
			return true
	return false


func set_kart_name(text: String) -> void:
	if _name_edit.text != text:
		_name_edit.text = text


## What the buttons along the bottom should offer right now.
func set_mode(holding: String, selected_name: String, can_turn: bool, can_undo: bool) -> void:
	_turn.visible = holding != "" or selected_name != ""
	_turn.disabled = not can_turn
	_done.visible = holding != ""
	_remove.visible = holding == "" and selected_name != ""
	_pick_up.visible = holding == "" and selected_name != ""
	_undo.disabled = not can_undo
	if holding != "":
		var part := PartCatalog.get_part(holding)
		_hint.text = "Holding %s. Touch where it should go." % part.get("name", holding)
	elif selected_name != "":
		_hint.text = selected_name
	else:
		_hint.text = "Pick a part on the left, or touch one on the kart."
	if holding == "":
		var pressed := _part_group.get_pressed_button()
		if pressed != null:
			pressed.set_pressed_no_signal(false)


func show_stats(stats: KartStats, problems: Array[String]) -> void:
	var lines := [
		"Weight  %d kg" % roundi(stats.mass),
		"Power  %.1f kW" % (stats.power / 1000.0),
		"Top speed  %d km/h" % roundi(stats.top_speed() * 3.6),
		"Pull  %.2f g" % stats.pull(),
		"Cornering  %.2f g" % stats.cornering(),
		"Drag  %.2f m²" % stats.drag_area,
		"Wheels  %d" % stats.wheels.size(),
	]
	if stats.lift_area > 0.0:
		lines.append("Wing  %.2f m²" % stats.lift_area)
	_stats_label.text = "\n".join(lines)
	_problems_label.text = "\n\n".join(problems)
	_problems_label.visible = not problems.is_empty()
	_drive.disabled = not problems.is_empty()


func toast(text: String) -> void:
	_toast.text = text
	_toast_left = 2.0
	_toast.modulate.a = 1.0


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)


func _build_left() -> void:
	_left = PanelContainer.new()
	add_child(_left)
	_left.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
	_left.offset_right = SIDE_WIDTH
	var box := VBoxContainer.new()
	_left.add_child(box)

	var tabs := HFlowContainer.new()
	box.add_child(tabs)
	for i in CATEGORIES.size():
		var tab := Button.new()
		tab.text = CATEGORIES[i][0]
		tab.toggle_mode = true
		tab.button_group = _category_group
		tab.focus_mode = FOCUS_NONE
		tab.custom_minimum_size = Vector2(0, 48)
		tab.pressed.connect(_show_category.bind(i))
		tabs.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	box.add_child(scroll)
	_part_list = VBoxContainer.new()
	_part_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_part_list)


func _show_category(index: int) -> void:
	var tabs: Array = _category_group.get_buttons()
	tabs[index].set_pressed_no_signal(true)
	for child in _part_list.get_children():
		child.queue_free()
	var kinds: Array = CATEGORIES[index][1]
	var ids := PartCatalog.ids()
	ids.sort()
	for id in ids:
		var part := PartCatalog.get_part(id)
		if not kinds.has(part.kind):
			continue
		var button := Button.new()
		button.text = "%s\n%s" % [part.name, _part_summary(part)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = _part_group
		button.focus_mode = FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 72)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(func() -> void: part_chosen.emit(id))
		_part_list.add_child(button)


func _part_summary(part: Dictionary) -> String:
	var size: Vector3i = part.size
	var bits := ["%s kg" % _num(part.mass)]
	match part.kind:
		"wheel":
			bits.append("grip %s" % _num(part.grip))
			bits.append("%d cm wide" % roundi(part.width * 100.0))
		"engine":
			bits.append("%s kW" % _num(part.power / 1000.0))
		"wing":
			bits.append("downforce")
		_:
			bits.append("%d x %d" % [size.x, size.z])
	return ", ".join(bits)


static func _num(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


func _build_right() -> void:
	_right = PanelContainer.new()
	add_child(_right)
	_right.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	_right.offset_left = -SIDE_WIDTH + 40.0
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_right.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_stats_label = Label.new()
	box.add_child(_stats_label)

	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.add_theme_color_override("font_color", WARNING)
	_problems_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_problems_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(spacer)

	_drive = Button.new()
	_drive.text = "Drive"
	_drive.custom_minimum_size = Vector2(0, 80)
	_drive.add_theme_font_size_override("font_size", 30)
	_drive.focus_mode = FOCUS_NONE
	_drive.pressed.connect(func() -> void: drive_pressed.emit())
	box.add_child(_drive)


func _build_top() -> void:
	_top = HBoxContainer.new()
	add_child(_top)
	_top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_top.offset_left = SIDE_WIDTH + 12.0
	_top.offset_right = -SIDE_WIDTH + 28.0
	_top.offset_top = 8.0
	_top.offset_bottom = 64.0

	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "Kart name"
	_name_edit.max_length = 32
	_name_edit.text_changed.connect(func(text: String) -> void: name_changed.emit(text))
	_top.add_child(_name_edit)
	_top.add_child(_small_button("New", func() -> void: new_pressed.emit()))
	_top.add_child(_small_button("Load", _open_load))
	_top.add_child(_small_button("Save", func() -> void: save_pressed.emit()))


func _build_bottom() -> void:
	_bottom = HBoxContainer.new()
	add_child(_bottom)
	_bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_bottom.offset_left = SIDE_WIDTH + 12.0
	_bottom.offset_right = -SIDE_WIDTH + 28.0
	_bottom.offset_top = -72.0
	_bottom.offset_bottom = -8.0
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_turn = _small_button("Turn", func() -> void: turn_pressed.emit())
	_pick_up = _small_button("Move", func() -> void: pick_up_pressed.emit())
	_remove = _small_button("Remove", func() -> void: remove_pressed.emit())
	_done = _small_button("Done", func() -> void: done_pressed.emit())
	_undo = _small_button("Undo", func() -> void: undo_pressed.emit())
	for button in [_turn, _pick_up, _remove, _done, _undo]:
		_bottom.add_child(button)


func _small_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 56)
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(action)
	return button


func _build_load_popup() -> void:
	_load_popup = PopupPanel.new()
	_load_popup.theme = Game.theme
	add_child(_load_popup)
	var box := VBoxContainer.new()
	_load_popup.add_child(box)
	var title := Label.new()
	title.text = "Load a kart"
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	box.add_child(scroll)
	_load_list = VBoxContainer.new()
	_load_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_load_list)


func _open_load() -> void:
	for child in _load_list.get_children():
		child.queue_free()
	var choices: Array = [["Starter (comes with the game)", Game.STARTER]]
	for path in KartDesign.saved_paths():
		var design := KartDesign.load_file(path)
		choices.append([design.name, path])
	for choice in choices:
		var button := _small_button(choice[0], func() -> void:
			_load_popup.hide()
			load_chosen.emit(choice[1]))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_load_list.add_child(button)
	_load_popup.popup_centered()
