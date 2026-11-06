extends Node

## Shared designs through the editors' menus and import windows.

var failures := 0
var host: Node
var before := {}
var tag := str(Time.get_ticks_usec())


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func window_under(parent: Node, type: String) -> Node:
	for window in parent.find_children("*", type, true, false):
		if not window.is_queued_for_deletion():
			return window
	return null


func _ready() -> void:
	for kind in Sharing.KINDS:
		for path in Sharing.saved_paths(kind):
			before[path] = true
	var kept_driver := Game.character.duplicate_design()
	var kept_kart := Game.design.duplicate_design()
	var was_pad := PadFocus.using_pad
	PadFocus.using_pad = true
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await _driver()
	await _kart()
	await _cup()
	Game.keep_character(kept_driver)
	Game.keep_design(kept_kart)
	PadFocus.using_pad = was_pad
	for kind in Sharing.KINDS:
		for path in Sharing.saved_paths(kind):
			if not before.has(path):
				DirAccess.remove_absolute(path)
	print("All sharing UI checks passed." if failures == 0 else "%d sharing UI checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _driver() -> void:
	Game.show_driver()
	await frames()
	var builder: DriverBuilder = host.get_child(host.get_child_count() - 1)
	var ui := builder.ui
	ui.name_changed.emit("Unfinished driver " + tag)
	var old := builder.design.to_dict()
	var steps := builder._undo.size()
	ui._file_menu.id_pressed.emit(4)
	await frames()
	var share: ShareWindow = window_under(ui, "ShareWindow")
	check(share != null and Sharing.kind_of(share.data) == Sharing.DRIVER, "the driver's file menu shares the current driver")
	check(share.find_children("*", "Label", true, false).any(func(l): return l.text == "Share " + old.name), "the share window names the driver inside its envelope")
	check(Sharing.read(Sharing.file_for(share.data)).get("data") == old and Sharing.read(Sharing.code_for(share.data)).get("data") == old, "the driver's file and code round trip with the current colours")
	share.hide()
	await frames()
	ui._open_load()
	await frames()
	var add: Button = ui._load_list.get_child(0)
	check(add.text == "Add a driver..." and ui._load_popup.gui_get_focus_owner() == add, "Load offers Add a driver first with controller focus")
	add.pressed.emit()
	await frames()
	var imported: AddWindow = window_under(ui, "AddWindow")
	var kart := KartDesign.load_file("res://tests/data/old_starter.json")
	kart.name = "Wrong kind " + tag
	imported._add(Sharing.file_for(Sharing.envelope_for(Sharing.KART, kart.to_dict())))
	check(not imported._any_added and imported._said.text.contains("Add a driver") and not FileAccess.file_exists(Sharing.path_for(Sharing.KART, kart.name)), "a kart is rejected before saving in the driver import")
	check(builder.design.to_dict() == old and builder._undo.size() == steps, "wrong-kind import leaves the driver and history alone")
	imported.hide()
	await frames()
	check(builder.design.to_dict() == old and builder._undo.size() == steps, "closing import leaves the current driver alone")
	ui.import_pressed.emit()
	await frames()
	imported = window_under(ui, "AddWindow")
	var driver := CharacterDesign.load_file("%s/racer.json" % Game.ROSTER)
	driver.name = "Imported driver " + tag
	driver.set_piece("headgear", "top_hat", Color("#145dcc"))
	var data := driver.to_dict()
	imported._add(Sharing.code_for(Sharing.envelope_for(Sharing.DRIVER, data)))
	check(imported._any_added and builder.design.to_dict() == data and Game.character.to_dict() == data, "a driver code is saved and loaded as the current driver")
	check(FileAccess.file_exists(Sharing.path_for(Sharing.DRIVER, driver.name)) and builder._undo.size() == steps + 1, "driver import writes its library entry and adds one undo step")
	imported.hide()
	await frames()
	ui.undo_pressed.emit()
	check(builder.design.to_dict() == old, "undo restores the unsaved driver and name")
	ui.redo_pressed.emit()
	check(builder.design.to_dict() == data, "redo restores the imported driver")


func _kart() -> void:
	Game.show_garage()
	await frames(3)
	var garage: Garage = host.get_child(host.get_child_count() - 1)
	var ui := garage.ui
	garage.design.name = "Unfinished kart " + tag
	var old := garage.design.to_dict()
	var steps := garage._undo.size()
	ui._file_menu.id_pressed.emit(4)
	await frames()
	var share: ShareWindow = window_under(ui, "ShareWindow")
	check(share != null and Sharing.kind_of(share.data) == Sharing.KART, "the garage's file menu shares the current kart")
	check(Sharing.read(Sharing.file_for(share.data)).get("data") == old and Sharing.read(Sharing.code_for(share.data)).get("data") == old, "the kart file and code round trip")
	share.hide()
	await frames()
	ui._open_load()
	await frames()
	var add: Button = ui._load_list.get_child(0)
	check(add.text == "Add a kart..." and ui._load_popup.gui_get_focus_owner() == add, "Load offers Add a kart first with controller focus")
	add.pressed.emit()
	await frames()
	var imported: AddWindow = window_under(ui, "AddWindow")
	var driver := CharacterDesign.load_file("%s/racer.json" % Game.ROSTER)
	driver.name = "Wrong driver " + tag
	imported._add(Sharing.file_for(Sharing.envelope_for(Sharing.DRIVER, driver.to_dict())))
	check(not imported._any_added and imported._said.text.contains("Add a kart") and not FileAccess.file_exists(Sharing.path_for(Sharing.DRIVER, driver.name)), "a driver is rejected before saving in the kart import")
	imported.hide()
	await frames()
	check(garage.design.to_dict() == old and garage._undo.size() == steps, "wrong-kind import and closing leave the kart and history alone")
	ui.part_chosen.emit("brick_2x2")
	check(garage._mode == GarageUI.Mode.PLACING, "a part is in hand before import")
	ui.import_pressed.emit()
	await frames()
	imported = window_under(ui, "AddWindow")
	var kart := KartDesign.new()
	kart.name = "Imported draft " + tag
	kart.parts.append(KartDesign.grid_entry("brick_2x2", Vector3i(8, 3, 10), 0, Color("#cd2345")))
	var data := kart.to_dict()
	imported._add(Sharing.file_for(Sharing.envelope_for(Sharing.KART, data)))
	check(imported._any_added and garage.design.to_dict() == data and Game.design.to_dict() == data, "an unfinished kart file loads and becomes the current garage kart")
	check(FileAccess.file_exists(Sharing.path_for(Sharing.KART, kart.name)) and garage._undo.size() == steps + 1, "kart import writes its library entry and adds one undo step")
	check(garage._selected == -1 and garage._mode == GarageUI.Mode.IDLE, "kart import clears selection and stops placement")
	imported.hide()
	await frames()
	ui.undo_pressed.emit()
	check(garage.design.to_dict() == old, "undo restores the unsaved kart and name")
	ui.redo_pressed.emit()
	check(garage.design.to_dict() == data, "redo restores the imported draft")
	garage._new_kart()
	check(ui._file_menu.is_item_disabled(4), "an empty garage disables Share")


func _cup() -> void:
	Game.show_cup_builder()
	await frames()
	var builder: CupBuilder = host.get_child(host.get_child_count() - 1)
	check(builder._share.disabled and builder._save.disabled, "an empty cup disables Save and Share")
	var course := CourseDesign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit"))))
	course.name = "Shared custom course " + tag
	var path := course.save()
	builder._name.text = "Shared cup " + tag
	builder._name.text_changed.emit(builder._name.text)
	builder.cup.add(Tracks.path_of("lemon_lake"))
	builder.cup.add(path)
	builder._show()
	check(not builder._share.disabled, "a named cup with two finished races enables Share")
	builder._share.pressed.emit()
	await frames()
	var share: ShareWindow = window_under(builder, "ShareWindow")
	var found := Sharing.read(Sharing.file_for(share.data))
	check(found.get("kind") == Sharing.CUP and found.data.races.size() == 2 and found.data.races[0].course.name == "Lemon Lake" and found.data.races[1].course.name == course.name, "Cup Builder shares every course snapshot in race order")
	check(found.data.races[1].from == "", "the exported custom course has no local file path")
	DirAccess.remove_absolute(path)
	check(Sharing.read(Sharing.code_for(share.data)).get("kind") == Sharing.CUP, "the whole cup code remains usable after its source course is removed")
	var code := Sharing.code_for(share.data)
	var cup_name := builder.cup.name
	share.hide()
	await frames()
	builder._name.text_changed.emit("")
	check(builder._share.disabled and builder._save.disabled, "a cup without a name disables Save and Share")
	Game.show_your_cups()
	await frames()
	var grid: CupGrid = host.get_child(host.get_child_count() - 1)
	var add: MenuCard = grid.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("add"))[0]
	add.tapped.emit()
	await frames()
	var imported: AddWindow = window_under(grid, "AddWindow")
	imported._add(code)
	var cup_path := CupDesign.path_for(cup_name)
	var saved := CupDesign.load_file(cup_path)
	check(imported._any_added and saved != null and saved.races.size() == 2 and saved.races[1].course.name == course.name, "Add a cup imports the complete snapshot after its source course is removed")
	imported.hide()
	await frames()
