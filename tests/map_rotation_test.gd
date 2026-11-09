extends Node

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var course := CourseDesign.new()
	course.name = "Map rotation test"
	for side in 4:
		course.pieces.append({"type": "straight", "length": 4 if side % 2 == 0 else 2})
		course.pieces.append({"type": "curve", "turn": "right", "size": 2})
	course.landmarks = [{"prop": "windmill", "at": [20, 30], "facing": 1}]
	var original := course.track()
	var outline := CourseOutline.of_track(original)
	check(not course.to_dict().has("map_rotation") and original.map_rotation == 0.0, "legacy maps default to north up without an extra saved field")
	course.map_rotation = 90.0
	var track := course.track()
	var rotated := CourseOutline.of_track(track)
	check(track.points == original.points and track.start == original.start and track.landmarks == original.landmarks, "map rotation leaves road, start and landmark geometry unchanged")
	check(rotated.box.size.is_equal_approx(Vector2(outline.box.size.y, outline.box.size.x)), "a quarter turn swaps the fitted map bounds")
	var transform := CourseOutline.fit(rotated, Rect2(0, 0, 240, 160), 12)
	var contained := true
	for point in rotated.line:
		contained = contained and Rect2(11.9, 11.9, 216.2, 136.2).has_point(transform * point)
	check(contained and transform.x.normalized().is_equal_approx(Vector2.DOWN), "rotated map fits its card and turns clockwise")
	for encoded in [Sharing.code_for(course.to_dict()), Sharing.file_for(course.to_dict())]:
		var read := Sharing.read(encoded)
		check(not read.has("why") and CourseDesign.from_dict(read.get("data", {})).map_rotation == 90.0, "map orientation survives code or file sharing")
	var cup := CupDesign.new()
	cup.name = "Rotated map cup"
	cup.races = [{"from": "", "course": course.to_dict()}]
	var shared_cup := Sharing.read(Sharing.code_for(cup.to_dict()))
	check(not shared_cup.has("why") and shared_cup.data.races[0].course.map_rotation == 90.0, "courses embedded in shared cups retain their map orientation")
	var invalid := course.to_dict()
	var rejected := true
	for value in ["90", true, -15, 360, INF, NAN]:
		invalid.map_rotation = value
		rejected = rejected and Sharing.validate_course(invalid).has("why") and Sharing.validate_saved(Sharing.COURSE, invalid).has("why")
	check(rejected, "raw and saved imports reject nonnumeric, nonfinite and out-of-range map rotations")
	check(course.with_start_on_longest_straight().map_rotation == 90.0, "moving the starting grid preserves the chosen map rotation")
	var path := "user://courses/map_rotation_test.json"
	course.save(path)
	var first_key := CourseOutline._key(path)
	var saved := CourseOutline.of(path)
	course.map_rotation = 45.0
	course.save(path)
	check(first_key != CourseOutline._key(path) and CourseOutline.of(path).map_rotation == 45.0, "saving a new map angle invalidates the outline even within the same second")
	var cache := "user://map_rotation_outline.json"
	CourseOutline._write(cache, saved)
	var cached := CourseOutline._read(cache)
	check(cached.map_rotation == 90.0 and cached.box.size.distance_to(saved.box.size) < 0.2, "disk outline cache retains rotation and rotated bounds")
	var map := CourseMap.new()
	map.track = track
	add_child(map)
	var fitted := CourseOutline.fit(rotated, Rect2(Vector2.ZERO, Vector2.ONE * map.across), 14)
	check(map._whole().is_equal_approx(fitted), "whole race map uses the thumbnail rotation transform for road and kart markers")
	var kart := Kart.new()
	add_child(kart)
	map.you = kart
	var close := map._close_up()
	track.map_rotation = 0.0
	check(close.is_equal_approx(map._close_up()), "kart-following close up keeps its heading-up orientation")
	map.queue_free()
	kart.queue_free()
	var editor := TrackEditor.new(path)
	add_child(editor)
	await get_tree().process_frame
	var before := editor.course.to_dict()
	editor.ui.map_rotation_changed.emit(15.0)
	var preview := editor.ui._map_preview
	check(editor.course.map_rotation == 60.0 and preview._outline.map_rotation == 60.0 and editor.ui._map_rotation_label.text == "Map rotation 60°", "editor rotation controls update the saved angle and live preview")
	var current: Variant = JSON.parse_string(FileAccess.get_file_as_string(TrackEditor.CURRENT))
	check(current.course.map_rotation == 60.0, "map rotation updates the editor draft")
	editor.undo()
	check(editor.course.to_dict() == before, "undo restores the previous map orientation and all course data")
	editor.redo()
	check(editor.course.map_rotation == 60.0, "redo restores map rotation")
	editor.rotate_map(-75)
	check(editor.course.map_rotation == 345.0, "rotating left wraps around zero degrees")
	editor.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(cache)
	print("%d map rotation checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
