extends Node

## 15 and 75 degree bends: a closed loop built from them, its kerbs and
## racing line, Close it up finishing it, and share code checks.

var checks := 0
var failures := 0


class KerbProbe extends TrackBuilder:
	var runs: Array = []

	func _add_kerb(run: Array, side: int) -> void:
		runs.append([run, side])


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + label)
	if not ok:
		failures += 1


## Half a lap turning right through 15, 75, 75 and 15 degrees, so two of them
## close by symmetry, with the straights between running at 15 degree headings.
static func loop_course() -> CourseDesign:
	var course := CourseDesign.new()
	for half in 2:
		course.pieces.append_array([
			{"type": "straight", "length": 3},
			TrackCatalogue.bend(15, 2, "right"),
			{"type": "straight", "length": 1},
			TrackCatalogue.bend(75, 3, "right"),
			{"type": "straight", "length": 1},
			TrackCatalogue.bend(75, 3, "right"),
			{"type": "straight", "length": 1},
			TrackCatalogue.bend(15, 2, "right"),
		])
	return course


func _ready() -> void:
	_catalogue()
	_loop()
	_closing()
	_sharing()
	print("%d checks, %d failed" % [checks, failures])
	print("passed" if failures == 0 else "failed")
	get_tree().quit(1 if failures > 0 else 0)


func _catalogue() -> void:
	var bends := []
	for angle in [15, 75]:
		for size in TrackCatalogue.BEND_SIZES:
			for turn in ["left", "right"]:
				bends.append(TrackCatalogue.bend(angle, size, turn))
	var offered := TrackCatalogue.specs()
	var choices := TrackCatalogue.closer_choices()
	check(bends.all(func(spec): return spec in offered and spec in choices), "all 16 bends are in the drawer and Close it up can pick them")
	var headings := true
	var exits := true
	for spec in bends:
		var piece := TrackPiece.from_spec(spec)
		var turn := -1 if spec.turn == "left" else 1
		headings = headings and piece.heading_delta() == -turn * spec.angle / 15
		var radians := deg_to_rad(spec.angle)
		var want := Vector3(turn * piece.radius * (1.0 - cos(radians)), 0.0, -piece.radius * sin(radians))
		exits = exits and piece.exit().origin.distance_to(want) < 0.0001 and TrackPath.heading_of(piece.exit().basis) == posmod(-turn * spec.angle / 15, 24)
		for heading in 24:
			var cursor := ClosureCursor.advance(ClosureCursor.start(heading), piece)
			var pose := Transform3D(TrackPath.heading_basis(heading), Vector3.ZERO) * piece.exit()
			exits = exits and not cursor.is_empty() and ClosureCursor.pose(cursor).origin.distance_to(pose.origin) < 0.001 and cursor[8] == TrackPath.heading_of(pose.basis)
	check(headings, "15 degree bends turn one step, 75 degree bends five")
	check(exits, "exits and the exact closing cursor agree at all 24 headings")
	check(TrackCatalogue.piece_name(TrackCatalogue.bend(75, 4, "left")) == "75° extra wide left" and TrackCatalogue.dimensions(TrackCatalogue.bend(15, 1, "right")) == "15° · radius 16 m", "names and dimensions")


func _loop() -> void:
	var course := loop_course()
	var track := course.track()
	check(track.closes and track.length > CourseDesign.SHORTEST, "a loop of 15 and 75 degree bends closes (%.0f m)" % track.length)
	check(track.clashes().is_empty() and course.problems().is_empty(), "it has no clashes and is ready to race")
	var line := track.racing_line()
	var half := track.width * 0.5
	var on_road := true
	var bent := false
	for k in track.points.size():
		var o := line.offsets[k]
		on_road = on_road and is_finite(o) and absf(o) <= half - RacingLine.MARGIN + 0.05
		bent = bent or absf(o) > 1.0
	check(on_road and bent, "it gets a racing line that stays on the road and uses its width")
	var probe := KerbProbe.new(track)
	probe._prepare()
	probe._add_kerbs()
	var kerbed := {}
	for run in probe.runs:
		for k in run[0]:
			var piece := track.pieces[track.piece_of[k]]
			if piece.type == "arc":
				kerbed[piece.angle] = true
	probe.free()
	check(kerbed.has(15) and kerbed.has(75), "both bends get kerbs")


func _closing() -> void:
	# Ending on each of the four bends, then with that bend left off.
	var course := loop_course()
	for end in [1, 3, 5, 7]:
		var turned := course.duplicate_design()
		turned.pieces = course.pieces.slice(end + 1) + course.pieces.slice(0, end + 1)
		var wanted: Dictionary = turned.pieces.pop_back()
		var found := turned.close_up(3, 10000)
		var done := turned.duplicate_design()
		done.pieces.append_array(found)
		var track := done.track()
		check(found.has(wanted) and track.closes and track.clashes().is_empty(), "Close it up puts back the %d° bend %s" % [wanted.angle, JSON.stringify(found)])


func _sharing() -> void:
	var course := loop_course()
	course.name = "Fine angles"
	var code := Sharing.code_for(Sharing.envelope_for(Sharing.COURSE, course.to_dict()))
	var read := Sharing.read(code)
	var same := not read.has("why") and JSON.stringify(JSON.parse_string(JSON.stringify(read.data.pieces))) == JSON.stringify(JSON.parse_string(JSON.stringify(course.to_dict().pieces)))
	check(same, "a course with them goes through a share code unchanged %s" % read.get("why", ""))
	for bad in [5, 20, 70, 105]:
		var spec := {"type": "arc", "angle": bad, "turn": "left", "size": 2}
		check(not Sharing._piece(spec), "a %d degree arc is still turned down" % bad)
