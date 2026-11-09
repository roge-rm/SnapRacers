extends SceneTree

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var trig_ok := true
	var endpoint_ok := true
	var options := TrackCatalogue.closer_choices()
	for h in 24:
		trig_ok = trig_ok and absf(ClosureCursor.value(ClosureCursor.cosine(h)) - 4.0 * cos(h * TAU / 24)) < 0.00000001
		trig_ok = trig_ok and absf(ClosureCursor.value(ClosureCursor.sine(h)) - 4.0 * sin(h * TAU / 24)) < 0.00000001
		for spec in TrackCatalogue.specs():
			var piece := TrackPiece.from_spec(spec)
			var cursor := ClosureCursor.advance(ClosureCursor.start(h), piece)
			var exact := ClosureCursor.pose(cursor)
			var physical := TrackPath.advance_pose(Transform3D(TrackPath.heading_basis(h), Vector3.ZERO), piece)
			endpoint_ok = endpoint_ok and exact.origin.distance_to(physical.origin) < 0.0001 and exact.basis.is_equal_approx(physical.basis)
	check(trig_ok, "exact coefficient table matches sine and cosine at all 24 headings")
	check(endpoint_ok, "exact cursor matches physical exits for all 98 drawer specs at all 24 headings")
	var presets := 0
	for category in TrackCatalogue.CATEGORIES:
		for row in category[2]:
			presets += row.size()
	check(presets == 98 and TrackCatalogue.specs().size() == 98, "all 98 drawer parts appear once in the canonical catalogue")
	check(options.size() == 55, "55 standard closer choices include half straights and five descending ramps")
	var nearby := ClosureCursor.start(0)
	nearby[0] = 99
	nearby[1] = -70
	check(ClosureCursor.pose(nearby).origin.length() < 0.5 and ClosureCursor.key(nearby) != ClosureCursor.key(ClosureCursor.start(0)), "nearby physical endpoints retain distinct exact keys")
	check(not ClosureCursor.at_start(nearby, 0), "the physical closing tolerance cannot satisfy the exact goal")
	var mixed := _circle()
	check(mixed.track().closes and mixed.track().clashes().is_empty(), "mixed 30, 45 and 60 degree fixture closes cleanly")
	for missing in [1, 2, 3]:
		var partial := mixed.duplicate_design()
		partial.pieces.resize(partial.pieces.size() - missing)
		_check_return(partial, missing, "mixed-angle fixture missing %d pieces" % missing)
	var diagonal := mixed.duplicate_design()
	diagonal.start = Transform3D(TrackPath.heading_basis(5), Vector3(17.12345, 8, -63.56789))
	diagonal.pieces.pop_back()
	_check_return(diagonal, 1, "non-cardinal start with arbitrary translation")
	var elevated := CourseDesign.new()
	elevated.start = Transform3D(TrackPath.heading_basis(1), Vector3.ZERO)
	elevated.pieces = [
		TrackCatalogue.bend(90, 2, "right"), TrackCatalogue.bend(90, 2, "right"),
		{"type": "ramp", "length": 3, "rise": 2},
		TrackCatalogue.bend(30, 2, "right"), TrackCatalogue.bend(60, 2, "right"), TrackCatalogue.bend(90, 2, "right"),
	]
	_check_return(elevated, 1, "elevated end uses the offered 3-tile, 2-level descent")
	var blocked := _circle()
	# A full circle followed by another would overlap the existing lap.
	blocked.pieces.append_array(_circle().pieces)
	blocked.pieces.pop_back()
	var snapshot := JSON.stringify(blocked.to_dict())
	check(blocked.close_up(1, 100).is_empty() and JSON.stringify(blocked.to_dict()) == snapshot, "collision rejects an overlapping exact return without changing the course")
	var tiny := _circle()
	tiny.pieces.resize(2)
	snapshot = JSON.stringify(tiny.to_dict())
	check(tiny.close_up(7, 0).is_empty(), "zero budget returns no pieces")
	var first := tiny.close_up(7, 1)
	check(first.is_empty() and first == tiny.close_up(7, 1), "tiny bounded failure is deterministic")
	check(tiny.close_up(1, 100).is_empty() and JSON.stringify(tiny.to_dict()) == snapshot, "unclosable depth limit leaves the course unchanged")
	var fractional := _circle()
	fractional.pieces.pop_back()
	fractional.pieces[0]["rise"] = 0.5
	snapshot = JSON.stringify(fractional.to_dict())
	check(fractional.close_up().is_empty() and JSON.stringify(fractional.to_dict()) == snapshot, "unsupported fractional levels fail unchanged")
	print("All %d advanced closer checks passed." % checks if failures == 0 else "%d advanced closer checks failed." % failures)
	quit(1 if failures else 0)


func _circle() -> CourseDesign:
	var course := CourseDesign.new()
	for repetition in 2:
		for angle in [30, 60, 45, 45]:
			course.pieces.append(TrackCatalogue.bend(angle, 2, "right"))
	return course


func _check_return(course: CourseDesign, most: int, label: String) -> void:
	var before := JSON.stringify(course.to_dict())
	var started := Time.get_ticks_msec()
	var result := course.close_up(most, 10000)
	var elapsed := Time.get_ticks_msec() - started
	check(not result.is_empty(), "%s finds a return (%d pieces, %d ms)" % [label, result.size(), elapsed])
	check(before == JSON.stringify(course.to_dict()), "%s leaves its input unchanged" % label)
	var allowed := TrackCatalogue.closer_choices()
	var standard := not result.is_empty()
	for spec in result:
		standard = standard and spec in allowed
	check(standard, "%s returns only drawer pieces" % label)
	var done := course.duplicate_design()
	done.pieces.append_array(result)
	check(not result.is_empty() and done.track().closes and done.track().clashes().is_empty(), "%s passes full closure and collision checks" % label)
	var heading := TrackPath.heading_of(course.start.basis)
	var cursor := ClosureCursor.start(heading)
	for spec in done.pieces:
		cursor = ClosureCursor.advance(cursor, TrackPiece.from_spec(spec))
	check(not result.is_empty() and ClosureCursor.at_start(cursor, heading), "%s returns an exact zero endpoint" % label)
	check(result == course.close_up(most, 10000), "%s repeats deterministically" % label)
