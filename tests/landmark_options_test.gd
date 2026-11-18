extends Node

## Landmark turning in 15 degree steps, sizes, landmarks over the road, picking
## one up by pad, and a course's about text and fixed time, saved and loaded.

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var course := CourseDesign.new()
	course.name = "Landmark options"
	course.pieces = [{"type": "straight", "length": 3}, {"type": "straight", "length": 3}]
	course.about = "A short test."
	course.inspired_by = "Somewhere"
	course.fixed_time = true
	course.time = "dusk"
	var path := "user://courses/landmark_options_test.json"
	course.save(path)
	var editor := TrackEditor.new(path)
	add_child(editor)
	await get_tree().process_frame
	check(editor.course.about == "A short test." and editor.course.inspired_by == "Somewhere", "about and inspired by load")
	var saved := editor.course.to_dict()
	check(saved.about == "A short test." and saved.inspired_by == "Somewhere" and saved.fixed_time, "and save")
	check(CourseDesign.from_dict({"name": "Old", "pieces": []}).about == "", "old courses without them load")

	# On the road: only the spanning props are allowed.
	var on_road: Vector3 = editor.track.points[editor.track.points.size() / 2]
	for prop in ["house", "overpass", "cable_car", "rope_bridge", "canopy_walk", "bridge"]:
		var mark := {"prop": prop, "at": [on_road.x, on_road.z], "facing": 0, "angle": 0}
		check(not editor._clear_of_road(mark), "%s on the road: refused, its solid parts are in the way" % prop)
	var wide := {"prop": "canopy_walk", "at": [on_road.x, on_road.z], "facing": 0, "angle": 0, "scale": 2.0}
	check(editor._clear_of_road(wide), "a canopy walk at double size spans the road on its trunks")
	wide.angle = 90
	wide.facing = 1
	check(not editor._clear_of_road(wide), "but not turned along the road")

	# Turning and size in hand.
	editor.pick_up_landmark("house")
	for k in 3:
		editor.turn_landmark(1)
	check(editor._holding.angle == 45, "three turns make 45 degrees")
	editor.turn_landmark(1)
	check(editor._holding.angle == 60 and editor._holding.facing == 1, "60 degrees is nearest to a quarter turn")
	editor.turn_landmark(-1)
	editor.turn_landmark(-1)
	editor.turn_landmark(-1)
	editor.turn_landmark(-1)
	check(editor._holding.angle == 0, "turning back to 0")
	editor.turn_landmark(-1)
	check(editor._holding.angle == 345, "and on round")
	editor.size_landmark()
	check(editor._holding.scale == 1.5, "Size goes to the next size (%s)" % editor._holding.scale)
	var spot := Vector3(400.0, 0.0, 400.0)
	editor._holding.at = [spot.x, spot.z]
	editor.drop_landmark()
	check(editor.course.landmarks.size() == 1 and editor.course.landmarks[0].angle == 345 and editor.course.landmarks[0].scale == 1.5, "it's kept with its angle and size")
	var round_trip := CourseDesign.from_dict(editor.course.to_dict())
	check(round_trip.landmarks[0].angle == 345 and round_trip.landmarks[0].scale == 1.5, "and survives saving and loading")
	var shared := Sharing.validate_course(editor.course.to_dict())
	check(not shared.has("why") and shared.data.landmarks[0].angle == 345, "and sharing accepts it (%s)" % shared.get("why", ""))
	var bad := editor.course.to_dict()
	bad.landmarks[0].angle = 20
	check(Sharing.validate_course(bad).has("why"), "but not an angle off the 15 degree steps")
	check(is_equal_approx(Props.room_of(round_trip.landmarks[0]), Props.ROOM.house * 1.5), "its room grows with its size")
	check(Props.angle_of({"facing": 3}) == 270, "an old landmark's quarter turns count as degrees")

	# Built, turned and bigger.
	var kit_plain := SceneryKit.new()
	var kit_big := SceneryKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Props.add_mark(kit_plain, {"prop": "windmill", "at": [0, 0], "facing": 0}, Vector3.ZERO, rng)
	rng.seed = 5
	Props.add_mark(kit_big, {"prop": "windmill", "at": [0, 0], "facing": 0, "angle": 45, "scale": 2.0}, Vector3.ZERO, rng)
	check(kit_plain.boxes.size() == kit_big.boxes.size() and kit_big.bounds().size.y > kit_plain.bounds().size.y * 1.9, "a double size landmark is twice as tall")

	# The pad picks one up.
	editor._select(-1)
	check(editor.pick_next_landmark() and editor._holding.index == 0 and editor._holding.angle == 345 and editor._holding.scale == 1.5, "the pad picks up a placed landmark with its angle and size")
	editor._drop_holding()
	check(editor._holding.is_empty(), "and puts it back")

	print("All landmark option checks passed." if failures == 0 else "%d landmark option checks failed." % failures)
	DirAccess.remove_absolute(path)
	get_tree().quit(1 if failures > 0 else 0)
