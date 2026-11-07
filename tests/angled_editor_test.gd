extends Node

## Bend parts, controller focus, placement and worker results.

var failures := 0
var chosen: Dictionary = {}
var editor: TrackEditor


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	await _controls()
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_track_editor()
	await frames(3)
	editor = host.get_child(host.get_child_count() - 1)
	await _controller()
	_placement()
	_save_start()
	await _failed_worker()
	_stale_worker()
	host.queue_free()
	await frames(3)
	print("All angled editor checks passed." if failures == 0 else "%d angled editor checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _category(name: String) -> int:
	for i in TrackCatalogue.CATEGORIES.size():
		if TrackCatalogue.CATEGORIES[i][0] == name:
			return i
	return -1


func _controls() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 450)
	add_child(viewport)
	var ui := TrackEditorUI.new()
	viewport.add_child(ui)
	ui.piece_chosen.connect(func(spec: Dictionary) -> void: chosen = spec)
	await frames(3)
	var reached: Array = []
	var pairs := true
	var icons := true
	ui._show_category(_category("Bends"))
	check(ui._tiles.get_child_count() == 32, "Bends offers all 32 plain parts at once")
	var labels := true
	for angle_index in 4:
		for size_index in 4:
			for side_index in 2:
				var angle: int = TrackCatalogue.BEND_ANGLES[angle_index]
				var turn := "left" if side_index == 0 else "right"
				var expected := TrackCatalogue.bend(angle, size_index + 1, turn)
				chosen = {}
				var tile := ui._tiles.get_child(angle_index * 8 + size_index * 2 + side_index)
				tile.pressed.emit()
				pairs = pairs and chosen == expected and not reached.has(chosen)
				var pictures := tile.find_children("*", "PieceIcon", false, false)
				icons = icons and pictures.size() == 1 and pictures[0].spec == expected
				var label: Label = tile.get_child(0)
				labels = labels and label.text == "%d° %s %s" % [angle, ["tight", "normal", "wide", "extra wide"][size_index], turn]
				reached.append(chosen)
	check(pairs, "32 unique plain parts run by angle, then tight to extra wide, each in a left/right row")
	check(icons, "each bend preview uses its own angle, size and turn")
	check(labels, "every plain bend is labelled with its angle, radius and direction")
	for category in TrackEditorUI.CATEGORIES.size():
		if category == _category("Bends"):
			continue
		ui._show_category(category)
		for tile in ui._tiles.get_children():
			chosen = {}
			tile.pressed.emit()
			if not reached.has(chosen):
				reached.append(chosen)
	var catalogue := TrackCatalogue.specs()
	check(reached.size() == 97 and catalogue.all(func(spec): return reached.has(spec)), "all 97 standard presets are reachable across the drawer")
	var screen := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var fit := true
	var clear := true
	for family in ["Straights", "Bends", "Offsets", "Hills", "Banked", "Specials"]:
		ui._show_category(_category(family))
		await frames(3)
		for tile in ui._tiles.get_children():
			var label: Label = tile.get_child(0)
			var caption_fits := Rect2(Vector2.ZERO, tile.size).encloses(label.get_rect()) and label.get_line_count() * label.get_line_height() <= label.size.y
			if not caption_fits:
				print("Caption overflow: ", label.text.replace("\n", " / "), " · ", label.get_line_count(), " lines × ", label.get_line_height(), " in ", label.size)
			fit = fit and caption_fits
		var scroll: ScrollContainer = ui._tiles.get_parent()
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await frames(3)
		var last: Control = ui._tiles.get_child(ui._tiles.get_child_count() - 1)
		clear = clear and scroll.get_global_rect().encloses(last.get_global_rect()) and last.get_global_rect().end.y < ui._bottom.get_global_rect().position.y
	check(fit, "all 97 captions fit their 104 px tiles at 800 by 450")
	check(clear, "the final row in every road tab scrolls fully above the race buttons on narrow screens")
	check(screen.encloses(ui._drawer.get_global_rect()) and ui._drawer.find_children("*", "OptionButton", true, false).all(func(choice): return not choice.visible), "the parts drawer fits an 800 by 450 view without road dropdowns")
	check(ui._rail.size() == 7 and ui._rail.all(func(tab): return screen.encloses(tab.get_global_rect())), "all seven rail tabs fit the narrow landscape screen")
	check(ui._tiles.size.x <= ui._tiles.get_parent().size.x and ui._tiles.get_parent().size.y >= BuilderStyle.TILE.y, "narrow landscape keeps both part columns and at least one visible row")
	ui.show_selection(7, {"type": "arc", "angle": 45, "turn": "left", "size": 2, "rise": 1, "surface": "dirt", "edges": "open"})
	check(ui._action_title.text == "8 · 45° up 3 m · Normal left" and ui._action_dimensions.text == "45° · radius 48 m · up 3 m", "selection shows the actual part name, index and compact dimensions after changing its surface and walls")
	var selections_fit := true
	for spec in catalogue:
		ui.show_selection(96, spec)
		await frames(3)
		selections_fit = selections_fit and screen.encloses(ui._actions.get_global_rect())
		for readout in [ui._action_title, ui._action_dimensions]:
			var width: float = readout.get_theme_font("font").get_string_size(readout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, readout.get_theme_font_size("font_size")).x
			if width > readout.size.x:
				print("Selection overflow: ", readout.text, " · ", width, " in ", readout.size.x)
			selections_fit = selections_fit and width <= readout.size.x
	check(selections_fit, "all selected part names and dimensions fit their action panel at 800 by 450")
	viewport.queue_free()
	await frames()


func _controller() -> void:
	var ui := editor.ui
	var pad: TrackEditorPad = editor.find_children("*", "TrackEditorPad", false, false)[0]
	ui._show_category(_category("Bends"))
	await frames()
	ui._tiles.get_child(0).grab_focus()
	var navigation := true
	for row in 15:
		await _dpad(JOY_BUTTON_DPAD_DOWN)
		navigation = navigation and get_viewport().gui_get_focus_owner() == ui._tiles.get_child((row + 1) * 2)
	await _dpad(JOY_BUTTON_DPAD_RIGHT)
	check(navigation and get_viewport().gui_get_focus_owner() == ui._tiles.get_child(31), "d-pad moves through all 16 bend rows and across to the last part")
	var scroll: ScrollContainer = ui._tiles.get_parent()
	var last: Control = ui._tiles.get_child(ui._tiles.get_child_count() - 1)
	check(scroll.scroll_vertical > 0 and scroll.get_global_rect().encloses(last.get_global_rect()), "following controller focus scrolls the last bend fully into view")
	check(not pad._button(JOY_BUTTON_DPAD_UP) and not pad._button(JOY_BUTTON_DPAD_DOWN), "the editor pad leaves focused part navigation to the grid")
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames()
	pad._button(JOY_BUTTON_LEFT_SHOULDER)
	await frames(3)
	check(get_viewport().gui_get_focus_owner() == ui._tiles.get_child(31) and scroll.scroll_vertical > 0, "LB/RB restore the last bend part and its scroll position")
	ui._show_category(_category("Hills"))
	await frames(3)
	ui._tiles.get_child(0).grab_focus()
	var hill_navigation := true
	for row in 13:
		await _dpad(JOY_BUTTON_DPAD_DOWN)
		hill_navigation = hill_navigation and get_viewport().gui_get_focus_owner() == ui._tiles.get_child((row + 1) * 2)
	await _dpad(JOY_BUTTON_DPAD_RIGHT)
	var hill_scroll: ScrollContainer = ui._tiles.get_parent()
	check(hill_navigation and get_viewport().gui_get_focus_owner() == ui._tiles.get_child(27) and hill_scroll.get_global_rect().encloses(ui._tiles.get_child(27).get_global_rect()), "d-pad reaches the last hump through all 14 hill rows and keeps it visible")
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(3)
	check(ui._category == _category("Banked"), "the shoulder button reaches the separate Banked family")
	pad._button(JOY_BUTTON_LEFT_SHOULDER)
	await frames(3)
	check(get_viewport().gui_get_focus_owner() == ui._tiles.get_child(27) and hill_scroll.scroll_vertical > 0, "returning from Banked restores the last hill and its scroll position")
	ui._show_category(TrackEditorUI.CATEGORIES.size())
	ui._landmark_filter.grab_focus()
	ui._landmark_filter.show_popup()
	check(not pad._button(JOY_BUTTON_DPAD_DOWN) and not pad._button(JOY_BUTTON_B), "landmark dropdown navigation and popup dismissal stay with the control")
	ui._landmark_filter.get_popup().hide()


func _dpad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()


func _placement() -> void:
	editor.course = CourseDesign.new()
	editor._refresh()
	editor.ui._show_category(_category("Bends"))
	editor.ui._tiles.get_child(11).pressed.emit()
	editor.ui._tiles.get_child(2).pressed.emit()
	var end := editor._insert_pose()
	check(TrackPath.heading_of(end.basis) == 23, "45 right then 30 left leaves a 15-degree clockwise insertion heading")
	editor.ui._show_category(0)
	editor.ui._tiles.get_child(1).pressed.emit()
	var pose: Transform3D = editor.track.piece_starts[2]
	var exit := editor._insert_pose()
	var travel := exit.origin - pose.origin
	check(pose.is_equal_approx(end) and travel.distance_to(Vector3(32 * sin(PI / 12), 0, -32 * cos(PI / 12))) < 0.0001 and absf(travel.length() - 32.0) < 0.0001, "the ordinary one-tile straight follows that heading for 32 metres")
	editor.insert_after = 0
	check(editor._insert_pose().is_equal_approx(TrackPath.advance_pose(editor.course.start, TrackPiece.from_spec(editor.course.pieces[0]))), "insert-after placement uses the shared geometry pose")
	editor.insert_after = -1


func _save_start() -> void:
	var course := CourseDesign.new()
	course.name = "Angled editor test"
	course.made_by = "Editor checks"
	course.start = Transform3D(TrackPath.heading_basis(1), Vector3(sqrt(2.0), 0, -sqrt(3.0)))
	for side in 4:
		course.pieces.append_array([TrackCatalogue.bend(45, 2, "right"), TrackCatalogue.bend(45, 2, "right"), {"type": "straight", "length": 4}])
	course.landmarks = [{"prop": "barn", "at": [400, 400], "facing": 0}]
	var expected := CourseDesign.from_dict(JSON.parse_string(JSON.stringify(course.with_start_on_longest_straight().to_dict())))
	editor.course = course
	editor.path = ""
	editor._refresh()
	var path := editor.save()
	var saved := CourseDesign.load_file(path)
	check(path != "" and saved != null and saved.to_dict() == expected.to_dict() and saved.track().closes and TrackPath.heading_of(saved.start.basis) % 6 != 0, "saving relocates the start with the geometry API and preserves fractional headings and landmarks")
	if path != "":
		DirAccess.remove_absolute(path)


func _failed_worker() -> void:
	editor.course = CourseDesign.new()
	var spec := TrackCatalogue.bend(45, 2, "right")
	spec["rise"] = 0.5
	editor.course.pieces = [spec]
	editor._refresh()
	var before := editor.course.to_dict().duplicate(true)
	var undo_count := editor._undo.size()
	editor.close_up()
	var deadline := Time.get_ticks_msec() + 5000
	while editor._closing != -1 and Time.get_ticks_msec() < deadline:
		await frames(1)
	check(editor._closing == -1 and editor.ui._close_failure.visible and editor.ui._close_failure.dialog_text == "Couldn't close this layout with the available pieces. Adjust the final bends or straights and try again.", "an unsuccessful worker completion shows the requested clear alert")
	check(editor.course.to_dict() == before and editor._undo.size() == undo_count, "failed completion leaves the layout and undo history unchanged")
	editor.ui._close_failure.hide()


func _stale_worker() -> void:
	editor._closer_source = editor.course.to_dict().duplicate(true)
	editor._closer_result = [{"type": "straight", "length": 1}]
	editor._closing = WorkerThreadPool.add_task(func() -> void: pass)
	editor.add_piece({"type": "straight", "length": 2})
	var changed := editor.course.to_dict().duplicate(true)
	editor._finish_closing()
	check(editor.course.to_dict() == changed and editor._closing == -1, "a worker result for an earlier layout never appends pieces to the changed course")
