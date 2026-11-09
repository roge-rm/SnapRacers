extends Node

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var low := _bridge(1, 22, "right", 0)
	check(_centre_clashes(low).is_empty(), "centre-only check misses the concrete 3 m banked bridge")
	if baseline:
		check(low.clashes().is_empty(), "unmodified clashes confirms the concrete bridge miss")
	else:
		for turn in ["left", "right"]:
			for heading in [0, 3, 6, 13]:
				for bank in [22, 80]:
					var lower := _bridge(1, bank, turn, heading)
					var upper := _bridge(2, bank, turn, heading)
					check(not lower.clashes().is_empty(), "%s bank %d at heading %d rejects 3 m clearance" % [turn, bank, heading])
					check(upper.clashes().is_empty(), "%s bank %d at heading %d allows 6 m clearance" % [turn, bank, heading])
		check(_isolated_crossing(5.0).clashes().is_empty(), "flat roads keep the exact 5 m clearance threshold")
		check(not _isolated_crossing(4.999).clashes().is_empty(), "flat roads below 5 m still clash")
		var adjacent := CourseDesign.new()
		adjacent.pieces = [{"type": "straight", "length": 1}, {"type": "straight", "length": 1}]
		check(adjacent.track().clashes().is_empty(), "adjacent pieces remain exempt")
		var crossed := CourseDesign.starter()
		crossed.pieces.append_array([
			TrackCatalogue.bend(90, 1, "right"), TrackCatalogue.bend(90, 1, "right"),
			TrackCatalogue.bend(90, 1, "right"), {"type": "straight", "length": 2},
		])
		check(not crossed.track().clashes().is_empty(), "same-height self crossing remains a clash")
	var changed := []
	var count := 0
	for id in Tracks.all():
		var track := TrackPath.load_file(Tracks.path_of(id))
		var previous := _centre_clashes(track)
		var current := track.clashes()
		if previous != current:
			changed.append([id, previous.size(), current.size()])
		count += 1
	check(count == 56 and changed.is_empty(), "all 56 stock courses retain the same clash results %s" % [changed])
	print("All %d banked clearance checks passed." % checks if failures == 0 else "%d banked clearance checks failed." % failures)
	get_tree().quit(1 if failures else 0)


func _bridge(levels: int, bank: int, turn: String, heading: int) -> TrackPath:
	var course := CourseDesign.new()
	course.start = Transform3D(TrackPath.heading_basis(heading), Vector3(123.25, 0, -91.5))
	course.pieces = [
		{"type": "ramp", "length": 2, "rise": levels},
		{"type": "curve", "turn": turn, "size": 3, "bank": bank},
		{"type": "ramp", "length": 2, "rise": -levels},
		{"type": "straight", "length": 3}, TrackCatalogue.bend(90, 1, turn),
		{"type": "straight", "length": 3}, TrackCatalogue.bend(90, 1, turn),
		{"type": "straight", "length": 2}, TrackCatalogue.bend(45, 4, turn),
		{"type": "straight", "length": 2}, {"type": "straight", "length": 3},
	]
	return course.track()


func _isolated_crossing(height: float) -> TrackPath:
	var track := TrackPath.new()
	track.pieces.append(TrackPiece.from_spec({"type": "straight"}))
	for i in 100:
		track.points.append(Vector3(i * 1000.0, 0, 0))
		track.distances.append(float(i))
		track.rights.append(Vector3.RIGHT)
		track.piece_of.append(0)
	track.points[0] = Vector3(0, height, 0)
	track.points[40] = Vector3.ZERO
	track.length = 100.0
	return track


func _centre_clashes(track: TrackPath) -> Array:
	var out := []
	var reach := track.width + 2.0 * TrackPath.KERB + 1.0
	var skip := int(ceil(reach * 2.0 / TrackPath.SAMPLE))
	var count := track.points.size()
	for i in range(0, count, 4):
		for j in range(i + skip, count, 4):
			if count - (j - i) < skip:
				continue
			var a := track.points[i]
			var b := track.points[j]
			if Vector2(a.x - b.x, a.z - b.z).length() < reach and absf(a.y - b.y) < 5.0:
				out.append([track.distances[i], track.distances[j]])
	return out
