extends SceneTree

## Run with XDG_DATA_HOME set inside build/creations, never the real profile.

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))


func put(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data if data is String else JSON.stringify(data))
	file.close()


func _initialize() -> void:
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/creations/")):
		push_error("Set XDG_DATA_HOME to an isolated folder inside build/creations.")
		quit(1)
		return
	for kind in Sharing.KINDS:
		check(CreationLibrary.entries(kind).is_empty(), "an empty %s library lists no stock creations" % kind)
	var course := CourseDesign.starter().to_dict()
	course.name = "Zulu"
	course["future_field"] = {"keep": [1, "two", {"three": true}]}
	var original := Sharing.path_for(Sharing.COURSE, course.name)
	put(original, course)
	var empty := CourseDesign.new().to_dict()
	empty.name = "alpha"
	var empty_path := Sharing.path_for(Sharing.COURSE, empty.name)
	put(empty_path, empty)
	var other := empty.duplicate(true)
	other.name = "ALPHA"
	put("user://courses/alias.json", other)
	put("user://courses/broken.json", "{broken")
	put("user://courses/not_a_creation.json", {"answer": 42})
	put("user://courses/notes.txt", "ignore me")
	put("user://courses/nested/hidden.json", course)
	var entries := CreationLibrary.entries(Sharing.COURSE)
	check(entries.size() == 5, "all top-level JSON files are listed, including drafts and corrupt files")
	check(entries[0].path == "user://courses/alias.json" and entries[1].path == empty_path and entries.back().name == "Zulu", "names sort without case, with paths breaking ties")
	check(entries[0].readable and entries[1].readable, "empty courses remain readable and editable")
	check(not entries[2].readable and entries[2].problem != "" and not entries[3].readable, "corrupt files explain why they cannot be opened")
	check(same(CreationLibrary.read(Sharing.COURSE, original).data.future_field, course.future_field), "reading preserves extra saved fields")
	check(CreationLibrary.envelope(Sharing.COURSE, empty_path).has("why"), "sharing keeps its existing empty-course validation")
	check(CreationLibrary.read(Sharing.COURSE, empty_path).has("data"), "a sharing failure leaves the draft editable")
	var cup := {"name": "Snapshot cup", "made_by": "Tester", "races": [{"from": original, "course": course.duplicate(true)}], "extra": 17}
	var cup_path := Sharing.path_for(Sharing.CUP, cup.name)
	put(cup_path, cup)
	var cup_before := FileAccess.get_file_as_string(cup_path)
	check(CreationLibrary.read(Sharing.CUP, cup_path).has("data"), "a cup with one unfinished course remains readable")
	check(CreationLibrary.envelope(Sharing.CUP, cup_path).has("why"), "an unfinished cup keeps the sharing error")
	var empty_cup := {"name": "Empty cup", "races": []}
	put("user://cups/empty.json", empty_cup)
	check(CreationLibrary.read(Sharing.CUP, "user://cups/empty.json").has("data"), "an empty cup remains editable")
	var malicious_cup := cup.duplicate(true)
	malicious_cup.races[0].course.pieces = "bad"
	put("user://cups/bad.json", malicious_cup)
	check(CreationLibrary.read(Sharing.CUP, "user://cups/bad.json").has("why"), "invalid cup snapshots cannot reach an editor")
	_rename_checks(original, course, empty_path)
	check(FileAccess.get_file_as_string(cup_path) == cup_before, "renaming a standalone course leaves cup snapshots untouched")
	_design_checks()
	_duplicate_checks()
	_large_saved_checks()
	_path_checks()
	_review_regressions()
	_delete_checks(cup_path, cup_before)
	print("All %d creation library checks passed." % checks if failures == 0 else "%d of %d creation library checks failed." % [failures, checks])
	quit(1 if failures > 0 else 0)


func _rename_checks(original: String, course: Dictionary, occupied: String) -> void:
	var before := FileAccess.get_file_as_string(original)
	for name in ["", "   ", "x".repeat(Sharing.MOST_NAME + 1), "two\nlines", "two\tcolumns"]:
		check(CreationLibrary.rename(Sharing.COURSE, original, name).has("why") and FileAccess.get_file_as_string(original) == before, "invalid name leaves the source unchanged: %s" % name.left(16).replace("\n", "\\n").replace("\t", "\\t"))
	for name in ["alpha", "ALPHA", "alpha!"]:
		check(CreationLibrary.rename(Sharing.COURSE, original, name).has("why") and FileAccess.get_file_as_string(original) == before, "a colliding name leaves both files unchanged: " + name)
	check(FileAccess.file_exists(occupied), "a failed rename keeps the existing target")
	put("user://courses/legacy_target.json", {"name": "Name / collision", "pieces": []})
	check(CreationLibrary.rename(Sharing.COURSE, original, "Name ? collision").has("why"), "sanitised names collide even when the existing filename differs")
	var renamed := CreationLibrary.rename(Sharing.COURSE, original, "  New course  ")
	check(not renamed.has("why") and renamed.path == Sharing.path_for(Sharing.COURSE, "New course") and not FileAccess.file_exists(original), "rename writes the new file before removing the old one")
	if renamed.has("why"):
		return
	var expected := course.duplicate(true)
	expected.name = "New course"
	check(same(JSON.parse_string(FileAccess.get_file_as_string(renamed.path)), expected), "only the name changes, including all extra data")
	var same_path := CreationLibrary.rename(Sharing.COURSE, renamed.path, "NEW COURSE")
	check(not same_path.has("why") and same_path.path == renamed.path and JSON.parse_string(FileAccess.get_file_as_string(renamed.path)).name == "NEW COURSE", "a display-name change at the same path saves safely")
	DirAccess.make_dir_recursive_absolute("user://courses/blocked.json")
	before = FileAccess.get_file_as_string(renamed.path)
	check(CreationLibrary.rename(Sharing.COURSE, renamed.path, "blocked").has("why") and FileAccess.get_file_as_string(renamed.path) == before, "a directory at the destination cannot destroy the source")
	check(CreationLibrary.rename(Sharing.COURSE, "user://courses/broken.json", "Fixed").has("why"), "corrupt JSON cannot be renamed through model defaults")
	var folder := ProjectSettings.globalize_path("user://courses")
	var permissions := FileAccess.get_unix_permissions(folder)
	var error := FileAccess.set_unix_permissions(folder, permissions & ~FileAccess.UNIX_WRITE_OWNER)
	check(error == OK, "the read-only folder fixture was set")
	if error == OK:
		var failed_rename := CreationLibrary.rename(Sharing.COURSE, renamed.path, "Cannot write")
		var failed_delete := CreationLibrary.delete(Sharing.COURSE, renamed.path)
		FileAccess.set_unix_permissions(folder, permissions)
		check(failed_rename.has("why") and FileAccess.get_file_as_string(renamed.path) == before, "a write failure leaves the original saved data intact")
		check(failed_delete.has("why") and FileAccess.file_exists(renamed.path), "an operating-system deletion failure returns an error")
	var leftovers := Array(DirAccess.get_directories_at("user://courses")).filter(func(name): return name.begins_with(".rename_"))
	check(leftovers.is_empty(), "renames leave no temporary directories")


func _design_checks() -> void:
	var driver := CharacterDesign.from_dict({}).to_dict()
	driver.name = "Imported racer"
	var kart := {"name": "Imported kart", "parts": [], "about": "Unfinished"}
	for fixture in [{"kind": Sharing.DRIVER, "data": driver}, {"kind": Sharing.KART, "data": kart}]:
		var added := Sharing.add(Sharing.read(JSON.stringify(fixture.data)))
		check(not added.has("why"), "imported %s saves into the existing library" % fixture.kind)
		if added.has("why"):
			continue
		var entries := CreationLibrary.entries(fixture.kind)
		check(entries.size() == 1 and entries[0].path == added.path and entries[0].readable, "imported %s appears in the creation library" % fixture.kind)
		var shared := CreationLibrary.envelope(fixture.kind, added.path)
		check(not shared.has("why") and shared.envelope.kind == fixture.kind and Sharing.read(JSON.stringify(shared.envelope)).kind == fixture.kind, "a %s can be shared through a validated envelope" % fixture.kind)
		var renamed := CreationLibrary.rename(fixture.kind, added.path, "Renamed " + fixture.kind)
		check(not renamed.has("why") and CreationLibrary.read(fixture.kind, renamed.get("path", "")).name == "Renamed " + fixture.kind, "a %s can be renamed" % fixture.kind)
		check(not CreationLibrary.delete(fixture.kind, renamed.get("path", "")).has("why"), "a %s can be deleted" % fixture.kind)
	var ready = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
	ready.name = "Imported course"
	var imported := Sharing.add(Sharing.read(JSON.stringify(ready)))
	check(not imported.has("why") and CreationLibrary.read(Sharing.COURSE, imported.path).name == ready.name, "an imported course appears beside locally saved courses")
	check(not CreationLibrary.envelope(Sharing.COURSE, imported.path).has("why"), "a valid course still shares")
	var cup := {"name": "Ready cup", "races": [{"from": "", "course": ready}, {"from": "", "course": ready}]}
	put("user://cups/ready.json", cup)
	var shared := CreationLibrary.envelope(Sharing.CUP, "user://cups/ready.json")
	check(not shared.has("why") and shared.envelope.kind == Sharing.CUP, "a valid cup still shares")


func _duplicate_checks() -> void:
	var course := CourseDesign.starter().to_dict()
	course.merge({"name": "Copied course", "weather": "rain", "time": "night", "fixed_time": true, "laps": 7}, true)
	var cup := {"name": "Copied cup", "races": [{"from": "user://courses/legacy.json", "course": course.duplicate(true), "extra_race": "keep"}]}
	var kart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/legacy/starter.json"))
	kart.name = "Copied kart"
	kart.parts[0]["suspension"] = KartDesign.SUSPENSION[0]
	var driver := CharacterDesign.from_dict({}).to_dict()
	driver.name = "Copied driver"
	driver.head.color = "#123456"
	for fixture in [{"kind": Sharing.COURSE, "data": course}, {"kind": Sharing.CUP, "data": cup}, {"kind": Sharing.KART, "data": kart}, {"kind": Sharing.DRIVER, "data": driver}]:
		fixture.data["extra"] = {"keep": [1, {"nested": true}]}
		fixture.data["made_by"] = "Original author"
		var path := Sharing.path_for(fixture.kind, fixture.data.name)
		put(path, fixture.data)
		var before := FileAccess.get_file_as_string(path)
		var proposed := CreationLibrary.copy_name(fixture.kind, path)
		check(proposed.get("name", "") == fixture.data.name + " copy", "a %s copy suggests its source name" % fixture.kind)
		var copied := CreationLibrary.duplicate_creation(fixture.kind, path, proposed.get("name", ""))
		check(not copied.has("why") and copied.get("path", path) != path and FileAccess.get_file_as_string(path) == before, "duplicating a %s creates a new file and preserves every source byte" % fixture.kind)
		if copied.has("why"):
			continue
		var expected: Dictionary = fixture.data.duplicate(true)
		expected.name = proposed.name
		check(same(CreationLibrary.read(fixture.kind, copied.path).data, expected), "a %s copy changes only its top-level name, preserving settings and metadata" % fixture.kind)
		check(CreationLibrary.copy_name(fixture.kind, path).name == fixture.data.name + " copy 2", "repeated %s copies get a numbered suggestion" % fixture.kind)
		var copy_before := FileAccess.get_file_as_string(copied.path)
		for name in ["", "   ", "x".repeat(33), "two\nlines", "two\tcolumns", fixture.data.name, str(proposed.name).to_upper(), str(proposed.name) + "!"]:
			check(CreationLibrary.duplicate_creation(fixture.kind, path, name).has("why") and FileAccess.get_file_as_string(path) == before and FileAccess.get_file_as_string(copied.path) == copy_before, "invalid or occupied %s copy name leaves both files intact: %s" % [fixture.kind, name.left(18)])
		expected.extra.keep[1].nested = false
		check(not CreationLibrary.save(fixture.kind, copied.path, expected, true).has("why") and FileAccess.get_file_as_string(path) == before, "editing a %s copy preserves the original" % fixture.kind)
		CreationLibrary.delete(fixture.kind, path)
		check(CreationLibrary.read(fixture.kind, copied.path).has("data"), "a %s copy remains readable after its original is deleted" % fixture.kind)
		CreationLibrary.delete(fixture.kind, copied.path)
	for name in ["q".repeat(80), "賽車".repeat(20), "Name / punctuation", "Line\nwith\ttabs"]:
		var path := "user://karts/copy_source.json"
		put(path, {"name": name, "parts": []})
		var proposed := CreationLibrary.copy_name(Sharing.KART, path)
		var copied := CreationLibrary.duplicate_creation(Sharing.KART, path, proposed.get("name", ""))
		check(not copied.has("why") and str(proposed.name).length() <= 32, "long, Unicode and legacy names get usable bounded suggestions: " + name.left(12))
		if not copied.has("why"):
			var again := CreationLibrary.copy_name(Sharing.KART, path)
			check(again.name.ends_with(" copy 2") and str(again.name).length() <= 32 and Sharing.path_for(Sharing.KART, again.name) != copied.path, "numbering keeps the suffix within the name limit")
			CreationLibrary.delete(Sharing.KART, copied.path)
		CreationLibrary.delete(Sharing.KART, path)
	put("user://courses/legacy_copy.json", {"name": "alpha copy", "pieces": []})
	put("user://courses/legacy_punctuation.json", {"name": "alpha copy 2!", "pieces": []})
	check(CreationLibrary.copy_name(Sharing.COURSE, "user://courses/alpha.json").name == "alpha copy 3", "suggestions skip legacy display names and sanitised filename collisions")
	CreationLibrary.delete(Sharing.COURSE, "user://courses/legacy_copy.json")
	CreationLibrary.delete(Sharing.COURSE, "user://courses/legacy_punctuation.json")
	for path in ["user://courses/broken.json", "user://courses/not_a_creation.json", "user://cups/bad.json"]:
		check(CreationLibrary.copy_name(Sharing.COURSE if path.contains("courses") else Sharing.CUP, path).has("why") and CreationLibrary.duplicate_creation(Sharing.COURSE if path.contains("courses") else Sharing.CUP, path, "Cannot copy").has("why"), "unreadable creations cannot be duplicated: " + path.get_file())


func _path_checks() -> void:
	var outside := "user://outside.json"
	put(outside, {"name": "Outside", "pieces": []})
	for path in [outside, "user://courses/../outside.json", "user://courses/nested/hidden.json", "user://courses/notes.txt", Tracks.path_of("peach_pit"), "user://cups/empty.json", ProjectSettings.globalize_path("user://courses/alpha.json")]:
		check(CreationLibrary.read(Sharing.COURSE, path).has("why") and CreationLibrary.rename(Sharing.COURSE, path, "Escape").has("why") and CreationLibrary.duplicate_creation(Sharing.COURSE, path, "Escape").has("why") and CreationLibrary.copy_name(Sharing.COURSE, path).has("why") and CreationLibrary.delete(Sharing.COURSE, path).has("why") and CreationLibrary.envelope(Sharing.COURSE, path).has("why"), "every operation rejects a path outside the exact library: " + path.get_file())
	check(CreationLibrary.entries("unknown").is_empty() and CreationLibrary.read("unknown", outside).has("why") and CreationLibrary.delete("unknown", outside).has("why"), "unknown kinds are rejected")
	check(CreationLibrary.read(Sharing.COURSE, "user://courses/missing.json").has("why") and CreationLibrary.delete(Sharing.COURSE, "user://courses/missing.json").has("why"), "missing files return errors")
	var directory := DirAccess.open("user://courses")
	var linked := directory.create_link(ProjectSettings.globalize_path(outside), ProjectSettings.globalize_path("user://courses/link.json"))
	check(linked == OK, "the symlink fixture was created")
	if linked == OK:
		check(CreationLibrary.read(Sharing.COURSE, "user://courses/link.json").has("why") and CreationLibrary.delete(Sharing.COURSE, "user://courses/link.json").has("why") and CreationLibrary.rename(Sharing.COURSE, "user://courses/link.json", "Linked").has("why") and CreationLibrary.duplicate_creation(Sharing.COURSE, "user://courses/link.json", "Linked").has("why"), "symlinked files cannot read, rename, duplicate or delete outside the library")
		check(CreationLibrary.rename(Sharing.COURSE, "user://courses/alpha.json", "link").has("why") and FileAccess.file_exists(outside), "a symlink at the target cannot be overwritten")
		check(CreationLibrary.duplicate_creation(Sharing.COURSE, "user://courses/alpha.json", "link").has("why") and FileAccess.get_file_as_string(outside).contains("Outside"), "duplicate cannot overwrite a linked destination")
		directory.remove("link.json")
	DirAccess.make_dir_recursive_absolute("user://elsewhere")
	put("user://elsewhere/secret.json", {"name": "Secret", "parts": []})
	var root := DirAccess.open("user://")
	root.remove("karts")
	linked = root.create_link(ProjectSettings.globalize_path("user://elsewhere"), ProjectSettings.globalize_path("user://karts"))
	check(linked == OK, "the linked library fixture was created")
	if linked == OK:
		check(CreationLibrary.entries(Sharing.KART).is_empty() and CreationLibrary.read(Sharing.KART, "user://karts/secret.json").has("why") and CreationLibrary.duplicate_creation(Sharing.KART, "user://karts/secret.json", "Secret copy").has("why") and CreationLibrary.delete(Sharing.KART, "user://karts/secret.json").has("why"), "symlinked library folders cannot expose outside files")
		root.remove("karts")
	check(FileAccess.file_exists(outside), "rejected operations leave outside files intact")


func _large_saved_checks() -> void:
	var course := CourseDesign.starter().to_dict()
	course.name = "Long course"
	for i in Sharing.MOST_PIECES:
		course.pieces.append({"type": "straight", "length": 1})
	var marks := CourseDesign.starter().to_dict()
	marks.name = "Many landmarks"
	for i in Sharing.MOST_LANDMARKS + 1:
		marks.landmarks.append({"prop": Props.ROOM.keys()[0], "at": [i, i], "facing": 0})
	var kart := {"name": "Many parts", "parts": []}
	var stock = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/legacy/starter.json"))
	for i in Sharing.MOST_PARTS + 1:
		kart.parts.append(stock.parts[0].duplicate(true))
	var about := {"name": "Long description", "parts": [], "about": "a".repeat(Sharing.MOST_ABOUT + 1)}
	var huge := CourseDesign.starter().to_dict()
	huge.name = "Large save"
	huge["extra"] = "x".repeat(Sharing.MOST_BYTES + 1)
	var named := CourseDesign.starter().to_dict()
	named.name = "n".repeat(Sharing.MOST_NAME + 1)
	for fixture in [{"kind": Sharing.COURSE, "data": course}, {"kind": Sharing.COURSE, "data": marks}, {"kind": Sharing.KART, "data": kart}, {"kind": Sharing.KART, "data": about}, {"kind": Sharing.COURSE, "data": huge}, {"kind": Sharing.COURSE, "data": named}]:
		var path := Sharing.path_for(fixture.kind, fixture.data.name)
		put(path, fixture.data)
		check(CreationLibrary.read(fixture.kind, path).has("data"), "sharing limits do not block local opening: " + fixture.data.name.left(24))
		check(CreationLibrary.entries(fixture.kind).any(func(entry): return entry.path == path and entry.readable), "an oversized local save remains listed as editable")
		check(CreationLibrary.envelope(fixture.kind, path).has("why"), "sharing retains its size limits")
		var copied := CreationLibrary.duplicate_creation(fixture.kind, path, CreationLibrary.copy_name(fixture.kind, path).name)
		check(not copied.has("why"), "an oversized local save can be duplicated")
		if not copied.has("why"):
			CreationLibrary.delete(fixture.kind, copied.path)
		var renamed := CreationLibrary.rename(fixture.kind, path, "Renamed " + fixture.data.name.left(30))
		check(not renamed.has("why"), "an oversized local save can be renamed")
		check(not CreationLibrary.delete(fixture.kind, renamed.get("path", "")).has("why"), "an oversized local save can be deleted")


func _review_regressions() -> void:
	var crossing := CourseDesign.starter().to_dict()
	crossing.name = "Raised crossing draft"
	crossing.pieces = [{"type": "ramp", "rise": 2}, {"type": "crossing"}]
	var path := Sharing.path_for(Sharing.COURSE, crossing.name)
	put(path, crossing)
	check(LevelCrossing.problem(CourseDesign.from_dict(crossing).track()) != "", "the crossing fixture is unfinished")
	check(CreationLibrary.read(Sharing.COURSE, path).has("data"), "an unfinished crossing course stays editable")
	check(CreationLibrary.envelope(Sharing.COURSE, path).has("why"), "sharing still rejects an unfinished crossing")
	var cup := {"name": "Crossing cup draft", "races": [{"from": path, "course": crossing}]}
	put("user://cups/crossing_draft.json", cup)
	check(CreationLibrary.read(Sharing.CUP, "user://cups/crossing_draft.json").has("data"), "a cup with an unfinished crossing stays editable")
	var kart := {"name": "Selected identity", "parts": []}
	path = "user://karts/selected_identity.json"
	check(not CreationLibrary.save(Sharing.KART, path, kart).has("why"), "a new saved identity can be created")
	var before := FileAccess.get_file_as_string(path)
	var changed := kart.duplicate(true)
	changed.name = "Another display name"
	check(CreationLibrary.save(Sharing.KART, path, changed).has("why") and FileAccess.get_file_as_string(path) == before, "saving a new identity cannot overwrite an existing file")
	check(not CreationLibrary.save(Sharing.KART, path, changed, true).has("why") and CreationLibrary.read(Sharing.KART, path).name == changed.name, "an explicit selected identity keeps its file when its display name changes")
	before = FileAccess.get_file_as_string(path)
	check(CreationLibrary.save(Sharing.COURSE, path, crossing, true).has("why") and FileAccess.get_file_as_string(path) == before, "saving cannot cross a library boundary")
	check(CreationLibrary.save(Sharing.KART, path, crossing, true).has("why") and FileAccess.get_file_as_string(path) == before, "saving rejects data of the wrong kind")
	DirAccess.make_dir_recursive_absolute("user://karts/save_blocked.json")
	check(CreationLibrary.save(Sharing.KART, "user://karts/save_blocked.json", kart).has("why"), "a directory cannot be replaced by a save")


func _delete_checks(cup_path: String, cup_before: String) -> void:
	var draft := KartDesign.new()
	draft.name = "Live draft"
	put("user://current_kart.json", draft.to_dict())
	put("user://karts/library_copy.json", draft.to_dict())
	var before := FileAccess.get_file_as_string("user://current_kart.json")
	check(not CreationLibrary.delete(Sharing.KART, "user://karts/library_copy.json").has("why") and draft.name == "Live draft" and FileAccess.get_file_as_string("user://current_kart.json") == before, "deleting a saved kart preserves the current in-memory and on-disk draft")
	var source := Sharing.path_for(Sharing.COURSE, "NEW COURSE")
	check(not CreationLibrary.delete(Sharing.COURSE, source).has("why") and not FileAccess.file_exists(source), "a saved course can be deleted")
	check(FileAccess.get_file_as_string(cup_path) == cup_before, "deleting a standalone course leaves cup snapshots untouched")
	check(not CreationLibrary.delete(Sharing.COURSE, "user://courses/broken.json").has("why") and not FileAccess.file_exists("user://courses/broken.json"), "a corrupt saved file can be deleted")
	check(CreationLibrary.delete(Sharing.COURSE, "user://courses/blocked.json").has("why") and DirAccess.dir_exists_absolute("user://courses/blocked.json"), "failed deletion returns an error and leaves the directory intact")
	for fixture in [{"kind": Sharing.DRIVER, "draft": "user://current_driver.json", "data": CharacterDesign.from_dict({}).to_dict()}, {"kind": Sharing.COURSE, "draft": "user://current_course.json", "data": CourseDesign.new().to_dict()}]:
		put(fixture.draft, fixture.data)
		var path := Sharing.path_for(fixture.kind, "Library copy")
		put(path, fixture.data)
		before = FileAccess.get_file_as_string(fixture.draft)
		check(not CreationLibrary.delete(fixture.kind, path).has("why") and FileAccess.get_file_as_string(fixture.draft) == before, "deleting a saved %s preserves its separate current draft" % fixture.kind)
