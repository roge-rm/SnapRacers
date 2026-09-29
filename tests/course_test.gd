extends SceneTree

## Checks courses built in the track editor: what stops one being raced,
## finishing one off with Close it up, moving the start line, and saving.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/course_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	# A new course isn't ready: it's just a straight.
	var fresh := CourseDesign.starter()
	check(fresh.problems().has("The road doesn't come back around to the start yet."), "a new course needs finishing %s" % [fresh.problems()])

	# Close it up finishes off a half built course.
	var half := CourseDesign.starter()
	half.pieces.append_array([
		{"type": "straight", "length": 2}, {"type": "curve", "turn": "right", "size": 2},
		{"type": "straight", "length": 3}, {"type": "curve", "turn": "right", "size": 1},
		{"type": "slant", "turn": "left", "length": 2, "across": 1},
	])
	var started := Time.get_ticks_msec()
	var extra := half.close_up()
	var took := Time.get_ticks_msec() - started
	check(not extra.is_empty(), "Close it up finds a way back to the start (%d pieces, %d ms)" % [extra.size(), took])
	half.pieces.append_array(extra)
	var track := half.track()
	check(track.closes and track.clashes().is_empty(), "and then the road closes without running into itself")
	check(half.problems().is_empty(), "and it's ready to race %s" % [half.problems()])

	# Up on a bridge, it comes back down to the ground.
	var up := CourseDesign.starter()
	up.pieces.append_array([{"type": "ramp", "length": 2, "rise": 1}, {"type": "curve", "turn": "left", "size": 2}])
	var down := up.close_up()
	up.pieces.append_array(down)
	check(not down.is_empty() and up.track().closes, "from up a ramp too (%d pieces)" % down.size())

	# The road running into itself.
	var crossed := CourseDesign.starter()
	crossed.pieces.append_array([
		{"type": "curve", "turn": "right", "size": 1}, {"type": "curve", "turn": "right", "size": 1},
		{"type": "curve", "turn": "right", "size": 1}, {"type": "straight", "length": 2},
	])
	check(crossed.problems().has("The road runs into itself."), "running into itself is spotted")

	# Moving the start line onto the longest straight keeps the lap the same,
	# and the landmarks stay in the same place beside the road.
	var built := CourseDesign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit"))))
	built.landmarks = [{"prop": "windmill", "at": [30.0, -20.0], "facing": 1}]
	var before := built.track()
	var mark_before := _gap_to_road(before, built.landmarks[0].at)
	var turned := built.with_start_on_longest_straight()
	var after := turned.track()
	check(after.closes and absf(after.length - before.length) < 1.0, "moving the start line keeps the lap the same (%.0f m, %.0f m)" % [before.length, after.length])
	check(absf(_gap_to_road(after, turned.landmarks[0].at) - mark_before) < 0.5, "and a landmark stays where it was beside the road")
	check(turned._longest_straight() >= CourseDesign.GRID_TILES + 1, "and there's room for the grid")

	# Saving and loading.
	half.name = "Course Test Loop"
	half.landmarks = [{"prop": "barn", "at": [40.0, 10.0], "facing": 2}]
	var path := half.save()
	var back := CourseDesign.load_file(path)
	var flat := func(c: CourseDesign) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(c.to_dict())))
	var same: bool = back != null and flat.call(back) == flat.call(half)
	check(same, "a course saves and loads the same (%s)" % path)
	check(CourseDesign.saved().has(path), "and it's listed with the saved courses")
	var raced := TrackPath.load_file(path)
	check(raced.closes and raced.landmarks.size() == 1, "and it loads as a track to race, landmarks and all")
	DirAccess.remove_absolute(path)

	# A course saved before the tiles were kart sized: the same pieces, with
	# its start, landmarks and road all grown to match.
	var old_file := half.to_dict()
	old_file.erase("grid")
	old_file.width = 10.0
	old_file.start = [16.0, 0.0, -32.0, 1]
	old_file.landmarks = [{"prop": "barn", "at": [40.0, 10.0], "facing": 2}]
	var grown := CourseDesign.from_dict(old_file)
	check(grown.width == TrackPath.WIDTH, "an old course gets today's road width (%.0f m)" % grown.width)
	check(grown.start.origin.is_equal_approx(Vector3(32.0, 0.0, -64.0)), "and its start moves out with its bigger tiles (%s)" % grown.start.origin)
	check(grown.landmarks[0].at == [80.0, 20.0], "and so do its landmarks (%s)" % [grown.landmarks[0].at])
	var old_track := TrackPath.from_dict(old_file)
	check(old_track.closes and old_track.start.origin.is_equal_approx(grown.start.origin), "and it races the same way (%s)" % old_track.start.origin)
	check(grown.to_dict().get("grid", 0) == TrackPiece.TILE, "and it saves as a kart sized course")

	print("All course checks passed." if failures == 0 else "%d course checks failed." % failures)
	quit(1 if failures > 0 else 0)


func _gap_to_road(track: TrackPath, at: Array) -> float:
	var p := Vector3(at[0], 0.0, at[1])
	var best := INF
	for q in track.points:
		best = minf(best, Vector2(q.x - p.x, q.z - p.z).length())
	return best
