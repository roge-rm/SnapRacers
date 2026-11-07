extends Node

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var wide := CourseDesign.new()
	for i in 4:
		wide.pieces.append(TrackCatalogue.bend(90, 4, "right"))
	_check_missing(wide, "extra wide cardinal bend", true)
	var offset := CourseDesign.new()
	for i in 2:
		offset.pieces.append_array([
			TrackCatalogue.bend(90, 2, "right"), {"type": "straight", "length": 2},
			TrackCatalogue.bend(90, 2, "right"), {"type": "slant", "turn": "right", "length": 4, "across": 2},
		])
	_check_missing(offset, "large cardinal offset", true)
	for ramp in [{"length": 3, "rise": 2}, {"length": 1, "rise": 1}]:
		var raised := CourseDesign.new()
		raised.pieces = [
			TrackCatalogue.bend(90, 2, "right"), TrackCatalogue.bend(90, 2, "right"),
			{"type": "ramp", "length": ramp.length, "rise": ramp.rise},
			TrackCatalogue.bend(90, 2, "right"), TrackCatalogue.bend(90, 2, "right"),
			{"type": "ramp", "length": ramp.length, "rise": -ramp.rise},
		]
		_check_missing(raised, "%d m long, %d m descending ramp" % [ramp.length * 32, ramp.rise * 3], true)
	var half := CourseDesign.new()
	for i in 2:
		half.pieces.append_array([TrackCatalogue.bend(90, 2, "right"), TrackCatalogue.bend(90, 2, "right"), {"type": "half_straight"}])
	_check_missing(half, "half straight cardinal return", false)
	var angled := wide.duplicate_design()
	angled.start = Transform3D(TrackPath.heading_basis(3), Vector3(123.25, 7, -28.5))
	_check_missing(angled, "same extra wide bend at 45 degrees", false)
	var old := CourseDesign.starter()
	old.pieces.append_array([
		{"type": "straight", "length": 2}, TrackCatalogue.bend(90, 2, "right"),
		{"type": "straight", "length": 3}, TrackCatalogue.bend(90, 1, "right"),
		{"type": "slant", "turn": "left", "length": 2, "across": 1},
	])
	var legacy := CourseCloser.new(old)._find_legacy(7, 10000)
	check(not legacy.is_empty() and legacy == old.close_up(), "successful legacy route keeps the same parts and order")
	for limits in [[0, 100], [-1, 100], [7, 0], [7, -1]]:
		var closer := CourseCloser.new(old)
		check(closer.find(limits[0], limits[1]).is_empty() and closer.expanded_count == 0, "non-positive limits %s do no search work" % [limits])
	for budget in [1, 2, 7, 37, 100]:
		var partial := wide.duplicate_design()
		partial.pieces.pop_back()
		var closer := CourseCloser.new(partial)
		closer.find(1, budget)
		check(closer.expanded_count > 0 and closer.expanded_count <= budget, "legacy plus fallback respects total budget %d (%d used)" % [budget, closer.expanded_count])
	var blocked := wide.duplicate_design()
	blocked.pieces.append_array(wide.pieces.duplicate(true))
	blocked.pieces.pop_back()
	check(blocked.close_up(1, 1000).is_empty(), "full clash check rejects overlapping exact returns")
	print("All %d closing upgrade checks passed." % checks if failures == 0 else "%d closing upgrade checks failed." % failures)
	get_tree().quit(1 if failures else 0)


func _check_missing(full: CourseDesign, label: String, legacy_fails: bool) -> void:
	check(full.track().closes and full.track().clashes().is_empty(), label + " fixture closes cleanly")
	var partial := full.duplicate_design()
	var expected: Dictionary = partial.pieces.pop_back()
	var before := JSON.stringify(partial.to_dict())
	if legacy_fails:
		check(CourseCloser.new(partial)._find_legacy(1, 1000).is_empty(), label + " is unavailable to the legacy search")
	var result := partial.close_up(1, 1000)
	check(result == [expected], label + " uses its available standard part")
	check(not result.is_empty() and result.all(func(spec): return spec in TrackCatalogue.closer_choices()), label + " returns catalogue choices")
	check(JSON.stringify(partial.to_dict()) == before, label + " leaves the course unchanged")
	partial.pieces.append_array(result)
	var heading := TrackPath.heading_of(partial.start.basis)
	var cursor := ClosureCursor.start(heading)
	for spec in partial.pieces:
		cursor = ClosureCursor.advance(cursor, TrackPiece.from_spec(spec))
	check(ClosureCursor.at_start(cursor, heading) and partial.track().closes and partial.track().clashes().is_empty(), label + " passes exact pose and full clash checks")
