extends Node

## Uses an empty isolated profile inside build/creations.

var failures := 0
var checks := 0
var host: Node


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func screen() -> Node:
	return host.get_child(host.get_child_count() - 1)


func put(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data if data is String else JSON.stringify(data))
	file.close()


func _ready() -> void:
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/creations/")):
		push_error("Set XDG_DATA_HOME to an isolated folder inside build/creations.")
		get_tree().quit(1)
		return
	PadFocus.using_pad = true
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await frames()
	var button: Button = screen().find_children("*", "Button", true, false).filter(func(b): return b.text == "Creations")[0]
	button.pressed.emit()
	await frames()
	check(screen() is CreationsMenu, "Creations opens from the main menu")
	var menu: CreationsMenu = screen()
	get_window().size = Vector2i(960, 540)
	await frames()
	check(menu._tabs.all(func(b): return b.get_global_rect().end.x <= menu.size.x) and menu._actions.all(func(b): return b.get_global_rect().end.x <= menu.size.x), "tabs and actions fit narrow landscape")
	check(menu.kind == Sharing.COURSE and menu._entries.is_empty(), "the empty library starts on Courses without stock")
	check(menu._actions.all(func(b): return b.disabled), "empty tabs disable item actions")
	menu.next_tab(-1)
	check(menu.kind == Sharing.DRIVER and get_viewport().gui_get_focus_owner() == menu._tabs[3], "shoulders wrap between tabs with focus")
	var course := CourseDesign.new()
	course.name = "Zulu"
	var course_path := Sharing.path_for(Sharing.COURSE, course.name)
	put(course_path, course.to_dict())
	var alpha := course.to_dict()
	alpha.name = "alpha"
	var alpha_path := Sharing.path_for(Sharing.COURSE, alpha.name)
	put(alpha_path, alpha)
	put("user://courses/broken.json", "{broken")
	menu._tab(Sharing.COURSE)
	check(menu._entries.map(func(e): return e.name) == ["alpha", "broken", "Zulu"], "the manager alphabetises drafts and corrupt files")
	menu._select("user://courses/broken.json")
	check(menu._actions.size() == 5 and menu._actions.all(func(b): return b.disabled == (b.text != "Delete")), "corrupt files offer Delete only")
	check(menu._status.text != "", "corrupt files show their read error")
	menu._open_delete()
	check(menu._delete_dialog.dialog_text.contains("broken"), "delete confirmation names the saved item")
	menu._delete_dialog.hide()
	check(FileAccess.file_exists("user://courses/broken.json"), "cancelling deletion leaves the file")
	menu._open_delete()
	menu._delete()
	await frames()
	check(not FileAccess.file_exists("user://courses/broken.json") and menu._entries.size() == 2, "confirmed deletion refreshes the list")
	check(get_viewport().gui_get_focus_owner() != null, "focus survives removing the selected item")
	menu._select(course_path)
	menu._share()
	check(menu._status.text != "" and menu.find_children("*", "ShareWindow", true, false).is_empty(), "sharing an unfinished course shows its validation error")
	menu._open_rename()
	check(menu._rename_name.max_length == 32 and menu._rename_problem.text.contains("records"), "course rename limits names and explains records")
	menu._rename_name.text = "alpha"
	menu._rename()
	check(menu._rename_dialog.visible and menu._rename_problem.text.contains("already"), "duplicate names keep the rename dialog open with an error")
	menu._rename_name.text = "Bravo"
	menu._rename()
	await frames()
	course_path = Sharing.path_for(Sharing.COURSE, "Bravo")
	check(menu.selected == course_path and menu._entries[1].name == "Bravo", "rename preserves selection and refreshes order")
	check(get_viewport().gui_get_focus_owner().get_meta("creation", "") == course_path, "rename restores focus to the renamed item")
	var source_bytes := FileAccess.get_file_as_string(course_path)
	menu._open_duplicate()
	check(menu._rename_dialog.title == "Duplicate" and menu._rename_dialog.ok_button_text == "Duplicate" and menu._rename_name.text == "Bravo copy" and menu._rename_problem.text == "", "Duplicate opens with an editable free name and its own confirmation")
	menu._rename_dialog.hide()
	await frames()
	check(menu.selected == course_path and menu._entries.size() == 2 and FileAccess.get_file_as_string(course_path) == source_bytes, "cancelling Duplicate preserves the library and selection")
	menu._open_duplicate()
	menu._rename_name.text = "alpha"
	menu._rename()
	check(menu._rename_dialog.visible and menu._rename_problem.text.contains("already") and menu.selected == course_path, "an occupied copy name keeps confirmation open with an error")
	menu._rename_name.text = " "
	menu._rename()
	check(menu._rename_dialog.visible and menu._rename_problem.text.contains("name"), "a blank copy name stays in the dialog with an error")
	menu._rename_name.text = "My copy"
	menu._rename_dialog.confirmed.emit()
	await frames()
	var copied_path := Sharing.path_for(Sharing.COURSE, "My copy")
	check(menu.selected == copied_path and menu._entries.size() == 3 and FileAccess.get_file_as_string(course_path) == source_bytes, "confirming Duplicate saves the chosen name and selects the new copy")
	check(get_viewport().gui_get_focus_owner().get_meta("creation", "") == copied_path, "Duplicate focuses the new copy")
	menu._open_rename()
	check(menu._rename_dialog.title == "Rename" and menu._rename_dialog.ok_button_text == "Rename" and menu._rename_problem.text.contains("records"), "Rename restores its title, button and records warning after Duplicate")
	menu._rename_dialog.hide()
	menu._select(course_path)
	var kept_course := {"path": "unrelated", "course": CourseDesign.starter().to_dict()}
	put(TrackEditor.CURRENT, kept_course)
	var kept_course_text := FileAccess.get_file_as_string(TrackEditor.CURRENT)
	menu._edit()
	await frames()
	var editor: TrackEditor = screen()
	check(editor.course.pieces.is_empty() and editor.path == course_path, "Edit loads the selected empty course without replacing it with a starter")
	check(FileAccess.get_file_as_string(TrackEditor.CURRENT) == kept_course_text, "opening a saved course preserves the unrelated editor draft")
	var alpha_bytes := FileAccess.get_file_as_string(alpha_path)
	editor.course.name = "alpha"
	editor.save()
	check(editor.path == course_path and CreationLibrary.read(Sharing.COURSE, course_path).name == "alpha" and FileAccess.get_file_as_string(alpha_path) == alpha_bytes, "saving a renamed course updates its selected identity and preserves the other course")
	editor.load_course(Tracks.path_of("peach_pit"))
	editor.course.pieces.clear()
	editor.course.name = "alpha"
	check(editor.save() == "" and FileAccess.get_file_as_string(alpha_path) == alpha_bytes, "saving a stock course copy cannot overwrite an existing course")
	editor.undo()
	check(editor.path == course_path, "undoing a course load restores its saved identity")
	editor.ui.new_pressed.emit()
	editor.course.pieces.clear()
	editor.course.name = "Undo saved course"
	editor.add_piece({"type": "straight", "length": 1})
	var new_course_path := editor.save()
	editor.undo()
	check(editor.path == new_course_path and editor.save() == new_course_path, "content undo after a first course save keeps its new file")
	editor.undo()
	check(editor.path == course_path, "undoing New still restores the earlier course file")
	editor.redo()
	check(editor.path == new_course_path and editor.save() == new_course_path, "redoing New restores the newly saved course identity")
	editor.undo()
	editor.go_back()
	await frames()
	menu = screen()
	check(menu.kind == Sharing.COURSE and menu.selected == course_path, "leaving the course editor returns to the same tab and selection")
	for i in 20:
		var extra := course.to_dict()
		extra.name = "Extra %02d" % i
		put(Sharing.path_for(Sharing.COURSE, extra.name), extra)
	menu.refresh()
	await frames()
	check(menu._list_scroll.get_v_scroll_bar().max_value > menu._list_scroll.size.y and menu._actions.all(func(b): return b.get_global_rect().end.y <= menu.size.y), "a long library scrolls while its actions stay on screen")
	var back: Button = menu.find_children("*", "Button", true, false).filter(func(b): return b.text == "Back")[0]
	check(menu._list_scroll.size.y >= menu._list.get_child(0).size.y and back.get_global_rect().position.y >= 0.0 and back.get_global_rect().end.y <= menu.size.y and menu._tabs.all(func(b): return b.get_global_rect().position.y >= 0.0 and b.get_global_rect().end.y <= menu.size.y), "narrow landscape keeps Back, tabs and a complete item row visible")
	menu._select(copied_path)
	menu._open_duplicate()
	check(menu._rename_name.text == "My copy copy", "a copy can also be duplicated")
	PadFocus.using_pad = false
	menu._rename_name.text = "Zzz copied draft"
	menu._rename_name.text_submitted.emit(menu._rename_name.text)
	await frames()
	var focused: Control = get_viewport().gui_get_focus_owner()
	check(focused != null and focused.get_meta("creation", "") == menu.selected and menu.selected == Sharing.path_for(Sharing.COURSE, "Zzz copied draft"), "keyboard confirmation focuses the new copy without a controller")
	check(menu._list_scroll.scroll_vertical > 0 and focused.get_global_rect().position.y >= menu._list_scroll.get_global_rect().position.y and focused.get_global_rect().end.y <= menu._list_scroll.get_global_rect().end.y, "Duplicate scrolls the new selected item fully into view")
	PadFocus.using_pad = true
	if DisplayServer.get_name() != "headless" and OS.has_environment("SNAPRACERS_CREATIONS_CAPTURE"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SNAPRACERS_CREATIONS_CAPTURE"))
	menu._open_import()
	await frames()
	var add: AddWindow = menu.find_children("*", "AddWindow", true, false)[0]
	var driver := CharacterDesign.load_file(Game.ROSTER + "/racer.json")
	driver.name = "Imported driver"
	add._add(Sharing.file_for(Sharing.envelope_for(Sharing.DRIVER, driver.to_dict())))
	check(menu.kind == Sharing.DRIVER and menu._entries.size() == 1, "global import switches to the imported driver's tab")
	var driver_path := menu.selected
	add.hide()
	await frames()
	check(get_viewport().gui_get_focus_owner().get_meta("creation", "") == driver_path, "closing import focuses the imported item")
	menu._share()
	await frames()
	var share: ShareWindow = menu.find_children("*", "ShareWindow", true, false)[0]
	check(Sharing.kind_of(share.data) == Sharing.DRIVER and Sharing.data_of(share.data).name == driver.name, "Share uses the saved driver's envelope")
	share.hide()
	await frames()
	var old_driver := Game.character.to_dict()
	Game.keep_character(Game.character)
	var old_driver_file := FileAccess.get_file_as_string(Game.CURRENT_DRIVER)
	menu._edit()
	await frames()
	var builder: DriverBuilder = screen()
	check(builder.design.name == driver.name, "Edit loads the selected saved driver")
	check(Game.character.to_dict() == old_driver and FileAccess.get_file_as_string(Game.CURRENT_DRIVER) == old_driver_file, "opening a driver leaves the unrelated current driver alone")
	var other_driver := driver.to_dict()
	other_driver.name = "Other driver"
	var other_driver_path := Sharing.path_for(Sharing.DRIVER, other_driver.name)
	put(other_driver_path, other_driver)
	var driver_bytes := FileAccess.get_file_as_string(other_driver_path)
	builder.design.name = other_driver.name
	builder._save()
	check(builder.saved_path == driver_path and CreationLibrary.read(Sharing.DRIVER, driver_path).name == other_driver.name and FileAccess.get_file_as_string(other_driver_path) == driver_bytes, "saving a renamed driver updates its selected identity and preserves the other driver")
	builder._new_driver()
	builder.design.name = other_driver.name
	builder._save()
	check(builder.saved_path == "" and FileAccess.get_file_as_string(other_driver_path) == driver_bytes, "a new driver cannot overwrite an existing driver's file")
	builder.undo()
	check(builder.saved_path == driver_path, "undoing New restores the driver's saved identity")
	builder._load(other_driver_path)
	check(builder.saved_path == other_driver_path, "loading a saved driver selects its file identity")
	builder.undo()
	check(builder.saved_path == driver_path, "undoing Load restores the previous driver's identity")
	builder._new_driver()
	builder.design.name = "Undo saved driver"
	builder.randomise()
	builder._save()
	var new_driver_path := builder.saved_path
	builder.undo()
	builder._save()
	check(new_driver_path != "" and builder.saved_path == new_driver_path, "content undo after a first driver save keeps its new file")
	builder.undo()
	check(builder.saved_path == driver_path, "undoing New after saving restores the earlier driver file")
	builder.go_back()
	await frames()
	check(screen() is CreationsMenu and screen().kind == Sharing.DRIVER, "Done returns from the driver to its tab")
	var kart := KartDesign.new()
	kart.name = "Empty kart"
	var kart_path := Sharing.path_for(Sharing.KART, kart.name)
	put(kart_path, kart.to_dict())
	Game.show_creations(Sharing.KART, kart_path)
	await frames()
	var old_kart := Game.design.to_dict()
	screen()._edit()
	await frames()
	var garage: Garage = screen()
	check(garage.design.name == kart.name and garage.design.parts.is_empty(), "Edit loads an unfinished saved kart")
	check(Game.design.to_dict() == old_kart, "opening a kart leaves the unrelated current kart alone")
	var other_kart := kart.to_dict()
	other_kart.name = "Other kart"
	var other_kart_path := Sharing.path_for(Sharing.KART, other_kart.name)
	put(other_kart_path, other_kart)
	var kart_bytes := FileAccess.get_file_as_string(other_kart_path)
	garage.design.name = other_kart.name
	garage._save()
	check(garage.saved_path == kart_path and CreationLibrary.read(Sharing.KART, kart_path).name == other_kart.name and FileAccess.get_file_as_string(other_kart_path) == kart_bytes, "saving a renamed kart updates its selected identity and preserves the other kart")
	garage._new_kart()
	garage.design.name = other_kart.name
	garage._save()
	check(garage.saved_path == "" and FileAccess.get_file_as_string(other_kart_path) == kart_bytes, "a new kart cannot overwrite an existing kart's file")
	garage.undo()
	check(garage.saved_path == kart_path, "undoing New restores the kart's saved identity")
	garage._load(other_kart_path)
	check(garage.saved_path == other_kart_path, "loading a saved kart selects its file identity")
	garage.undo()
	check(garage.saved_path == kart_path, "undoing Load restores the previous kart's identity")
	garage._new_kart()
	garage.design.name = "Undo saved kart"
	garage._remember()
	garage.design.about = "Edited"
	garage._save()
	var new_kart_path := garage.saved_path
	garage.undo()
	garage._save()
	check(new_kart_path != "" and garage.saved_path == new_kart_path, "content undo after a first kart save keeps its new file")
	garage.undo()
	check(garage.saved_path == kart_path, "undoing New after saving restores the earlier kart file")
	Game.keep_design(garage.design)
	Game.show_garage()
	await frames()
	garage = screen()
	garage._to_menu()
	await frames()
	check(screen() is CreationsMenu and screen().kind == Sharing.KART, "garage return context survives re-entry after a test drive")
	Game.show_creations(Sharing.COURSE, course_path)
	await frames()
	screen()._edit()
	await frames()
	Game.came_from_editor = true
	Game.show_track_editor()
	await frames()
	screen().go_back()
	await frames()
	check(screen() is CreationsMenu and screen().kind == Sharing.COURSE, "course return context survives re-entry after a race")
	var cup := CupDesign.new()
	cup.name = "Draft cup"
	var cup_path := cup.save()
	Game.show_creations(Sharing.CUP, cup_path)
	await frames()
	screen()._edit()
	await frames()
	var cup_builder: CupBuilder = screen()
	check(cup_builder.path == cup_path and cup_builder.cup.races.is_empty(), "Edit opens an unfinished saved cup")
	cup_builder.go_back()
	await frames()
	check(screen() is CreationsMenu and screen().kind == Sharing.CUP, "Back returns from the cup builder to its tab")
	screen()._edit()
	await frames()
	cup_builder = screen()
	cup_builder.cup.add(Tracks.path_of("peach_pit"))
	cup_builder.cup.add(Tracks.path_of("lemon_lake"))
	var other_cup := cup_builder.cup.to_dict()
	other_cup.name = "Other cup"
	var other_cup_path := Sharing.path_for(Sharing.CUP, other_cup.name)
	put(other_cup_path, other_cup)
	var cup_bytes := FileAccess.get_file_as_string(other_cup_path)
	cup_builder.cup.name = other_cup.name
	cup_builder.save()
	await frames()
	check(CreationLibrary.read(Sharing.CUP, cup_path).name == other_cup.name and FileAccess.get_file_as_string(other_cup_path) == cup_bytes, "saving a renamed cup preserves its selected identity and the other cup")
	check(screen() is CreationsMenu and screen().kind == Sharing.CUP and FileAccess.file_exists(cup_path), "saving a finished cup returns to the manager with the same saved identity")
	screen()._edit()
	await frames()
	cup_builder = screen()
	cup_builder._delete_dialog.confirmed.emit()
	await frames()
	check(screen() is CreationsMenu and screen().kind == Sharing.CUP and not FileAccess.file_exists(cup_path), "cup builder deletion returns to the manager and refreshes it")
	Game.show_editors()
	Game.show_driver()
	await frames()
	screen().go_back()
	await frames()
	check(screen() is EditorsMenu, "ordinary editors keep their default return route")
	print("All %d creations menu checks passed." % checks if failures == 0 else "%d creations menu checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
