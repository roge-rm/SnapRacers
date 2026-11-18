extends Node

## Checks courses with the game's own code and prints a line for each: whether
## it closes, clashes, its length, how close two stretches come middle to
## middle, CourseDesign.problems(), paint squares, landmarks, the start, and
## whether it still closes mirrored, reversed and both. Landmarks too close to
## the road or in water and paint the editor wouldn't allow by the road count
## as fails too. Then a line with every
## course that failed a check.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tools/track-design/course_check.tscn [-- id or file.json ...]
## With no ids it checks every course in the cups, in cup order.

## The checks a stock course should pass (see PLAN-tracks.md and track_test).
const SHORTEST := 1400.0
const LONGEST := 2100.0
const MOST_PAINT := 400
const GRID_BEHIND := 2.0 * TrackPiece.TILE
const STRAIGHTS := ["straight", "half_straight", "quarter_straight", "adjustable_straight"]


func _ready() -> void:
	var targets: Array = Array(OS.get_cmdline_user_args())
	if targets.is_empty():
		targets = Tracks.all()
	var failed := []
	for target: String in targets:
		var path: String = target if target.ends_with(".json") else Tracks.path_of(target)
		var id := path.get_file().get_basename()
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			print("%s: FAIL can't read %s" % [id, path])
			failed.append(id)
			continue
		var bad := _check(id, data)
		if not bad.is_empty():
			failed.append("%s (%s)" % [id, ", ".join(bad)])
	print("CHECKED %d courses, %d failed%s" % [targets.size(), failed.size(), (": " + "; ".join(failed)) if failed else ""])
	get_tree().quit(1 if failed else 0)


## The pieces (as "number:type") the editor's drawer and piece panel can't make.
func _not_makeable(data: Dictionary) -> Array:
	var out := []
	var pieces: Array = data.get("pieces", [])
	for k in pieces.size():
		if not TrackCatalogue.makeable(pieces[k]):
			out.append("%d:%s" % [k + 1, JSON.stringify(pieces[k])])
	return out


## Prints the line for one course and gives back what failed.
func _check(id: String, data: Dictionary) -> Array:
	var bad := []
	var track := TrackPath.from_dict(data)
	var clashes := track.clashes()
	var close := _closest_stretches(track)
	var problems := CourseDesign.from_dict(data).problems()
	var squares := track.paint.squares.size()
	var heading := TrackPath.heading_of(track.start.basis)
	var first: TrackPiece = track.pieces[track.piece_of[0]] if not track.pieces.is_empty() else null
	var on_straight := first != null and first.type in STRAIGHTS and not first.crossing
	var behind := _straight_behind(track)
	var bad_marks := _landmarks_in_the_way(track)
	var bad_paint := _paint_too_close(track)
	var unmakeable := _not_makeable(data)
	var layouts := []
	for layout in [[true, false, "mirrored"], [false, true, "reversed"], [true, true, "both"]]:
		var turned := TrackPath.from_dict(data)
		turned.apply_layout(layout[0], layout[1])
		layouts.append("%s %s" % [layout[2], "ok" if turned.closes else "OPEN"])
		if not turned.closes:
			bad.append(layout[2] + " open")
	if not track.closes:
		bad.append("open")
	if not clashes.is_empty():
		bad.append("clashes")
	if track.length < SHORTEST or track.length > LONGEST:
		bad.append("length")
	if close <= TrackPiece.TILE - 1.0:
		bad.append("close stretches")
	if not problems.is_empty():
		bad.append("problems")
	if squares > MOST_PAINT:
		bad.append("paint")
	if not on_straight or heading < 0 or heading % 6 != 0:
		bad.append("start")
	if behind < GRID_BEHIND - 0.01:
		bad.append("grid")
	if not unmakeable.is_empty():
		bad.append("editor can't make %s" % " ".join(unmakeable))
	if not bad_marks.is_empty():
		bad.append("landmarks %s" % " ".join(bad_marks))
	if bad_paint > 0:
		bad.append("%d squares by the road" % bad_paint)
	var ground := "no ground map"
	if track.ground != null:
		ground = "ground %d x %d" % [track.ground.cols, track.ground.rows]
	print("%s: %s, %d clashes, %.0f m, closest %.0f m, problems %s, paint %d, %s, landmarks %d, start %s at %s degrees with %.0f m behind, %s%s" % [
		id, "closes" if track.closes else "OPEN", clashes.size(), track.length, close,
		"none" if problems.is_empty() else "[%s]" % " ".join(problems),
		squares, ground, track.landmarks.size(), "on a straight" if on_straight else "NOT on a straight",
		heading * 15 if heading >= 0 else -1, behind, ", ".join(layouts),
		"" if bad.is_empty() else ", FAIL " + ", ".join(bad)])
	return bad


## The landmarks the editor wouldn't let you drop: too close to the road, or
## in or by water or lava (see TrackEditor._clear_of_road()).
func _landmarks_in_the_way(track: TrackPath) -> Array:
	var out := []
	for i in track.landmarks.size():
		var mark: Dictionary = track.landmarks[i]
		var at := Vector2(float(mark.at[0]), float(mark.at[1]))
		var own: float = Props.ROOM.get(mark.prop, 3.0)
		var room: float = own + track.width * 0.5 + TrackPath.KERB + TrackBuilder.WALL_THICKNESS + TrackEditor.LANDMARK_GAP
		var clear := true
		for p in track.points:
			if Vector2(p.x, p.z).distance_to(at) < room:
				clear = false
				break
		if clear and track.waters.has_real():
			track.waters.ensure(track)
			clear = not track.waters.covered(Vector3(at.x, 0.0, at.y), own)
		var paint := Scenery.paint_of(track)
		if clear and paint.has_deep():
			for k in 9:
				var spot := at + (Vector2.ZERO if k == 0 else Vector2.from_angle(k * TAU / 8.0) * own)
				var kind := paint.kind_at(spot.x, spot.y)
				if kind != "" and PaintedAreas.effect_of(kind) != "":
					clear = false
					break
		if not clear:
			out.append("%d:%s" % [i, mark.prop])
	return out


## How many painted squares sit where the editor wouldn't paint them.
func _paint_too_close(track: TrackPath) -> int:
	var count := 0
	var paint := Scenery.paint_of(track)
	for square: Vector2i in paint.squares:
		if not PaintedAreas.allowed(square, paint.squares[square], track):
			count += 1
	return count


## How far the straights run back from the start line, at ground level,
## wrapping round from the last piece. The grid needs two tiles of it.
func _straight_behind(track: TrackPath) -> float:
	var total := 0.0
	for k in range(track.pieces.size() - 1, -1, -1):
		var piece: TrackPiece = track.pieces[k]
		if piece.type not in STRAIGHTS or piece.crossing:
			break
		total += piece.run_length()
	return total


## How close two stretches of road at ground level come, middle to middle,
## leaving out the two sides of a loop or a corkscrew and anything on a
## bridge above or below. The same as track_test's.
func _closest_stretches(track: TrackPath) -> float:
	var nearest := INF
	var count := track.points.size()
	for i in range(0, count, 4):
		if track.points[i].y > 0.5 or TrackPiece.turns_over(track.pieces[track.piece_of[i]].type):
			continue
		for j in range(i + 4, count, 4):
			var along := track.distances[j] - track.distances[i]
			if minf(along, track.length - along) < TrackPiece.TILE * 3.0:
				continue
			if track.points[j].y > 0.5 or TrackPiece.turns_over(track.pieces[track.piece_of[j]].type):
				continue
			var a := track.points[i]
			var b := track.points[j]
			nearest = minf(nearest, Vector2(a.x - b.x, a.z - b.z).length())
	return nearest
