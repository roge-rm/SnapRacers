extends Node

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


func _ready() -> void:
	var course := CourseDesign.new()
	for turn in ["right", "left"]:
		for i in 3:
			course.pieces.append(TrackCatalogue.bend(90, 2, turn))
		course.pieces.append({"type": "straight", "length": 3})
	var track := course.track()
	check(track.closes and track.length > CourseDesign.SHORTEST, "figure eight closes with a full length lap")
	check(not track.clashes().is_empty(), "automatic closing still sees the crossing as occupied")
	check(track.clashes(5.0, true).is_empty(), "flat crossing is allowed for an editor course")
	check(course.problems().is_empty(), "figure eight is ready to test drive and race")
	var builder := TrackBuilder.new(track)
	var clear := true
	for index in [3, 7]:
		var first := track.piece_of.find(index)
		clear = clear and builder._walls(track.pieces[index], first, first + 1) == [false, false]
	builder.free()
	check(clear, "the crossing straights have no walls")
	var crossing := Vector3(0, 0, 48)
	var one := track.distances[track.piece_of.find(3)] + 48.0
	var two := track.distances[track.piece_of.find(7)] + 48.0
	check(track.point_at(one).distance_to(crossing) < 0.001 and track.point_at(two).distance_to(crossing) < 0.001, "both branches pass through the same point")
	var followed := true
	for at in [one, two]:
		var hint: float = at - 10.0
		for step in range(-10, 11):
			var wanted: float = at + step
			hint = track.offset_near(track.point_at(wanted), hint, 5.0, 40.0)
			followed = followed and absf(hint - wanted) < 0.05
	check(followed, "race progress keeps its branch through both crossing passes")
	var moved := course.with_start_on_longest_straight()
	check(moved.problems().is_empty(), "moving the starting grid preserves a valid figure eight")
	var saved := moved.save("user://courses/figure_eight_test.json")
	var loaded := CourseDesign.load_file(saved)
	check(loaded != null and loaded.problems().is_empty(), "a saved figure eight loads ready to race")
	DirAccess.remove_absolute(saved)
	var walls := course.duplicate_design()
	walls.pieces[3]["edges"] = "walls"
	check(walls.problems().has("The road runs into itself."), "walls across another road remain invalid")
	var raised := course.duplicate_design()
	raised.start.origin.y = 3.0
	check(raised.problems().has("The road runs into itself."), "overlapping raised roads retain clearance checks")
	var banked := course.duplicate_design()
	banked.pieces[3] = {"type": "ramp", "length": 3, "rise": 1}
	check(not banked.track().clashes(5.0, true).is_empty(), "a low ramp crossing keeps its clearance checks")
	_check_curved_contact()
	print("%d figure eight checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _check_curved_contact() -> void:
	var touching := CourseDesign.new()
	for turn in ["right", "left"]:
		for i in 4:
			touching.pieces.append(TrackCatalogue.bend(90, 2, turn))
	var path := touching.track()
	var probe := KerbProbe.new(path)
	probe._prepare()
	probe._add_kerbs()
	var trimmed := 0
	var retained := 0
	var clear := true
	for side in [-1, 1]:
		for k in path.points.size():
			if probe._kerb_crosses_road(k, side):
				trimmed += 1
			else:
				retained += 1
	for run in probe.runs:
		for k in run[0]:
			clear = clear and not probe._kerb_crosses_road(k, run[1])
	check(trimmed > 0 and retained > trimmed and not probe.runs.is_empty(), "touching curves trim crossing curbs and keep the rest")
	check(clear, "generated curb runs stay off the other road")
	probe.free()
	touching.start.origin.y = 6.0
	var raised := KerbProbe.new(touching.track())
	check(not raised._kerb_crosses_road(0, 1), "curb trimming does not treat elevated road as a flat crossover")
	raised.free()
