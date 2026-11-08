class_name CreationsMenu
extends Control

## The saved courses, cups, karts and drivers you can change or share.

const KINDS := [Sharing.COURSE, Sharing.CUP, Sharing.KART, Sharing.DRIVER]
const TITLES := ["Courses", "Cups", "Karts", "Drivers"]

var kind := Sharing.COURSE
var selected := ""
var _entries: Array[Dictionary] = []
var _rows: Array[Button] = []
var _tabs: Array[Button] = []
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _status: Label
var _actions: Array[Button] = []
var _delete_action: Button
var _import: Button
var _rename_dialog: ConfirmationDialog
var _rename_name: LineEdit
var _rename_problem: Label
var _name_action := "Rename"
var _delete_dialog: ConfirmationDialog


func _init(which := Sharing.COURSE, path := "") -> void:
	kind = which if which in KINDS else Sharing.COURSE
	selected = path


func _ready() -> void:
	var column := MenuStyle.page(self, "Creations", go_back, 640.0)
	# Keep the tabs and actions visible while the saved items scroll.
	var page_scroll := column.get_parent().get_parent()
	column.reparent(page_scroll.get_parent())
	page_scroll.get_parent().remove_child(page_scroll)
	page_scroll.queue_free()
	column.custom_minimum_size.x = 0.0
	column.size_flags_vertical = SIZE_EXPAND_FILL
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for i in KINDS.size():
		var button := MenuStyle.button(TITLES[i], _tab.bind(KINDS[i]))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		tabs.add_child(button)
		_tabs.append(button)
	_import = MenuStyle.button("Import", _open_import)
	tabs.add_child(_import)
	_list_scroll = ScrollContainer.new()
	_list_scroll.follow_focus = true
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(_list)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	for item in [["Edit", _edit], ["Rename", _open_rename], ["Duplicate", _open_duplicate], ["Share", _share], ["Delete", _open_delete]]:
		var button := MenuStyle.button(item[0], item[1])
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, UiKit.pad(UiKit.pill(state), 12, 10, UiKit.LEAN))
		actions.add_child(button)
		_actions.append(button)
		if item[0] == "Delete":
			_delete_action = button
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.theme_type_variation = "DangerLabel"
	column.add_child(_status)
	_make_dialogs()
	var restore := selected != ""
	refresh()
	if restore:
		_restore_focus.call_deferred(true)


func focus_key() -> String:
	return "creations/" + kind


func next_tab(by: int) -> void:
	_tab(KINDS[posmod(KINDS.find(kind) + by, KINDS.size())])
	if PadFocus.using_pad:
		_tabs[KINDS.find(kind)].grab_focus()


func _tab(which: String) -> void:
	kind = which
	selected = ""
	_status.text = ""
	refresh()


func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_entries = CreationLibrary.entries(kind)
	if not _entries.any(func(entry: Dictionary) -> bool: return entry.path == selected):
		selected = "" if _entries.is_empty() else str(_entries[0].path)
	for i in _tabs.size():
		MenuStyle.mark_tab(_tabs[i], KINDS[i] == kind)
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = "No saved %s yet." % TITLES[KINDS.find(kind)].to_lower()
		_list.add_child(empty)
	for entry in _entries:
		var button := MenuStyle.button(entry.name, _select.bind(entry.path))
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.set_meta("creation", entry.path)
		_rows.append(button)
		if kind == Sharing.COURSE:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_list.add_child(row)
			button.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_child(button)
			var play := IconButton.new("play", "Test drive %s" % entry.name)
			play.disabled = not entry.readable
			play.set_meta("test_course", entry.path)
			row.add_child(play)
			ScrollButton.let_scroll(play, _test_drive.bind(entry.path))
		else:
			_list.add_child(button)
	_update_selection()


func _selected_entry() -> Dictionary:
	for entry in _entries:
		if entry.path == selected:
			return entry
	return {}


func _select(path: String) -> void:
	selected = path
	_status.text = ""
	_update_selection()


func _update_selection() -> void:
	var entry := _selected_entry()
	for action in _actions:
		action.disabled = entry.is_empty() or (action != _delete_action and not entry.get("readable", false))
	for button in _rows:
		MenuStyle.mark(button, button.get_meta("creation", "") == selected)
	if not entry.is_empty() and not entry.readable:
		_status.text = entry.problem


func _restore_focus(force := false) -> void:
	if not PadFocus.using_pad and not force:
		return
	# Refresh needs a layout pass before the scroll range includes new rows.
	await get_tree().process_frame
	for button in _rows:
		if button.get_meta("creation", "") == selected:
			button.grab_focus()
			_list_scroll.ensure_control_visible(button)
			return
	_import.grab_focus()


func _edit() -> void:
	var found := CreationLibrary.read(kind, selected)
	if found.has("why"):
		_status.text = found.why
		return
	Game.edit_creation(kind, selected)


func _test_drive(path: String) -> void:
	_select(path)
	var found := CreationLibrary.read(Sharing.COURSE, path)
	if found.has("why"):
		_status.text = found.why
		return
	var course := CourseDesign.from_dict(found.data)
	var problems := course.problems()
	if not problems.is_empty():
		_status.text = problems[0]
		return
	Game.start_course(Game.MODE_PRACTICE, path, false, Game.show_creations.bind(Sharing.COURSE, path))


func _share() -> void:
	var found := CreationLibrary.envelope(kind, selected)
	if found.has("why"):
		_status.text = found.why
		return
	var window := ShareWindow.open(found.envelope, self)
	window.popup_hide.connect(func() -> void: _restore_focus.call_deferred())


func _open_import() -> void:
	var window := AddWindow.open(self, "Import a creation")
	window.added.connect(func(which: String, path: String) -> void:
		kind = which
		selected = path
		_status.text = ""
		refresh())
	window.done.connect(func(_added: bool) -> void: _restore_focus.call_deferred())


func _make_dialogs() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename"
	_rename_dialog.ok_button_text = "Rename"
	_rename_dialog.dialog_hide_on_ok = false
	_rename_dialog.theme = MenuStyle.theme()
	PadFocus.close_on_b(_rename_dialog)
	add_child(_rename_dialog)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 440.0
	_rename_dialog.add_child(column)
	_rename_name = LineEdit.new()
	_rename_name.max_length = 32
	PadKeyboard.attach(_rename_name)
	column.add_child(_rename_name)
	_rename_name.text_submitted.connect(func(_text: String) -> void: _rename())
	_rename_problem = Label.new()
	_rename_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rename_problem.theme_type_variation = "DangerLabel"
	column.add_child(_rename_problem)
	_rename_dialog.confirmed.connect(_rename)
	_rename_dialog.visibility_changed.connect(func() -> void:
		if not _rename_dialog.visible:
			_restore_focus.call_deferred(_name_action == "Duplicate"))
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete"
	_delete_dialog.ok_button_text = "Delete"
	_delete_dialog.theme = MenuStyle.theme()
	PadFocus.close_on_b(_delete_dialog)
	_delete_dialog.dialog_hide_on_ok = false
	_delete_dialog.confirmed.connect(_delete)
	_delete_dialog.visibility_changed.connect(func() -> void:
		if not _delete_dialog.visible:
			_restore_focus.call_deferred())
	add_child(_delete_dialog)


func _open_rename() -> void:
	var entry := _selected_entry()
	if entry.is_empty():
		return
	var warning := "Renaming changes the records shown for this %s." % ("course" if kind == Sharing.COURSE else "cup") if kind in [Sharing.COURSE, Sharing.CUP] else ""
	_open_name("Rename", entry.name, warning)


func _open_duplicate() -> void:
	var proposed := CreationLibrary.copy_name(kind, selected)
	if proposed.has("why"):
		_status.text = proposed.why
		return
	_open_name("Duplicate", proposed.name)


func _open_name(action: String, name: String, warning := "") -> void:
	_name_action = action
	_rename_dialog.title = action
	_rename_dialog.ok_button_text = action
	_rename_name.text = name
	_rename_problem.text = warning
	_rename_dialog.reset_size()
	_rename_dialog.popup_centered()
	_rename_name.grab_focus()
	_rename_name.select_all()


func _rename() -> void:
	var result := CreationLibrary.duplicate_creation(kind, selected, _rename_name.text) if _name_action == "Duplicate" else CreationLibrary.rename(kind, selected, _rename_name.text)
	if result.has("why"):
		_rename_problem.text = result.why
		return
	selected = result.path
	_status.text = ""
	refresh()
	_rename_dialog.hide()


func _open_delete() -> void:
	var entry := _selected_entry()
	if entry.is_empty():
		return
	_delete_dialog.dialog_text = 'Delete "%s"?' % entry.name
	_delete_dialog.popup_centered()
	PadFocus.focus_first(_delete_dialog)


func _delete() -> void:
	var result := CreationLibrary.delete(kind, selected)
	if result.has("why"):
		_delete_dialog.hide()
		_status.text = result.why
		return
	_status.text = ""
	refresh()
	_delete_dialog.hide()


func go_back() -> void:
	Game.show_menu()
