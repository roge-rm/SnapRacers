extends SceneTree

## Painted ground: it goes to a course file as runs and back, merges
## neighbours, drops types it doesn't know, has soft edges, keeps water and
## lava off road on the ground but not under raised road, lets mud and the like
## up to the kerb, and moves out with an old course's tiles.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/painted_area_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var areas := PaintedAreas.new()
	for x in range(2, 6):
		areas.set_square(Vector2i(x, 3), "water")
	areas.set_square(Vector2i(6, 3), "lava")
	areas.set_square(Vector2i(-2, -1), "mud")
	areas.set_square(Vector2i(8, 3), "water")
	var dict := areas.to_dict()
	check(dict.runs == [[-1, -2, 1, "mud"], [3, 2, 4, "water"], [3, 6, 1, "lava"], [3, 8, 1, "water"]], "neighbours of one type merge into runs, a different type or a gap starts another (%s)" % str(dict.runs))
	var back := PaintedAreas.from_dict(JSON.parse_string(JSON.stringify(dict)))
	check(back.squares == areas.squares and back.count() == 7, "it comes back the same through JSON")
	check(PaintedAreas.from_dict(back.to_dict()).to_dict() == dict, "and again")

	var odd := PaintedAreas.from_dict({"cell": 8.0, "runs": [[0, 0, 2, "water"], [1, 0, 3, "quicksand"], "junk", [2, 0], [3, 0, 0, "water"], [4, 0, 1, 7]]})
	check(odd.count() == 2 and odd.square_type(Vector2i(1, 0)) == "water", "unknown types and bad runs are dropped, the rest kept")
	check(PaintedAreas.from_dict(null).is_empty() and PaintedAreas.from_dict({"runs": 5}).is_empty(), "nothing to read gives nothing painted")

	var lake := PaintedAreas.new()
	lake.set_square(Vector2i(0, 0), "water")
	var middle := PaintedAreas.middle_of(Vector2i(0, 0))
	check(lake.kind_at(middle.x, middle.y) == "water" and lake.inside(middle.x, middle.y), "the middle of a square is deep water")
	check(lake.kind_at(middle.x + 6.0, middle.y) == "" and lake.level_at(middle.x + 6.0, middle.y) == 0.0, "6 m from its middle is dry")
	var edge := lake.level_at(8.0, middle.y)
	check(is_equal_approx(edge, 0.5) and lake.kind_at(9.0, middle.y) == "water" and not lake.inside(9.0, middle.y), "the edge is the 0.5 line and just outside it is the shallow band (%.2f)" % edge)
	check(lake.covered(Vector3(middle.x + 6.0, 0, middle.y), 3.0) and not lake.covered(Vector3(middle.x + 6.0, 0, middle.y), 0.1), "covered looks round a spot by its room")
	check(lake.field_at(middle.x, middle.y, "lava") == 0.0, "the field of another type is 0")

	var brushed := PaintedAreas.new()
	check(brushed.paint_at(20.0, 20.0, "sand", 3) == 9 and brushed.count() == 9, "a brush of 3 paints 9 squares")
	check(brushed.paint_at(20.0, 20.0, "sand", 3) == 0, "painting the same again changes nothing")
	check(brushed.erase_at(20.0, 20.0, 1) == 1 and brushed.count() == 8, "the eraser takes one square")

	var track := TrackPath.from_dict({"theme": "orchard", "start": [0, 0, 0, 0], "pieces": [{"type": "straight", "length": 6}]})
	var z := track.points[track.points.size() / 2].z
	var half := track.outer_half(track.points.size() / 2)
	var near := Vector2i(0, floori(z / PaintedAreas.CELL))
	var side := (track.points[track.points.size() / 2].x)
	var reach := half + TrackPath.KERB
	# A square whose near edge is 'gap' metres off the road's edge line.
	var at := func(gap: float) -> Vector2i:
		return Vector2i(floori((side + reach + gap) / PaintedAreas.CELL) + (1 if (side + reach + gap) < 0.0 else 0), near.y)
	var touching := Vector2i(floori(side / PaintedAreas.CELL), near.y)
	check(not PaintedAreas.allowed(touching, "water", track) and not PaintedAreas.allowed(touching, "mud", track), "no type goes on the road itself")
	var far_x := side + reach + PaintedAreas.ROAD_ROOM + 1.0
	var water_square := Vector2i(floori(far_x / PaintedAreas.CELL) + 1, near.y)
	check(PaintedAreas.allowed(water_square, "water", track), "water is fine well clear of the road")
	var found_water := false
	var found_mud := false
	for k in range(-4, 8):
		var sq := Vector2i(k, near.y)
		var gap := minf(absf(sq.x * PaintedAreas.CELL - side), absf((sq.x + 1) * PaintedAreas.CELL - side))
		var inside := side >= sq.x * PaintedAreas.CELL and side <= (sq.x + 1) * PaintedAreas.CELL
		if inside:
			continue
		if gap >= reach and gap < reach + PaintedAreas.ROAD_ROOM:
			found_mud = found_mud or (PaintedAreas.allowed(sq, "mud", track) and not PaintedAreas.allowed(sq, "water", track))
			found_water = true
	check(found_water and found_mud, "between the kerb and 2 m past it, mud is allowed and water is not")
	var refused := PaintedAreas.new()
	check(refused.paint_at(side, z, "water", 3, track) == 0 and refused.is_empty(), "a brush over the road paints nothing")

	var bridge := TrackPath.from_dict({"theme": "orchard", "start": [0, 0, 0, 0], "pieces": [{"type": "straight", "length": 2}, {"type": "ramp", "length": 4, "rise": 3}, {"type": "straight", "length": 4}, {"type": "ramp", "length": 4, "rise": -3}, {"type": "straight", "length": 2}]})
	var top := 0
	for i in bridge.points.size():
		if bridge.points[i].y - bridge.grounds[i] > bridge.points[top].y - bridge.grounds[top]:
			top = i
	var high := bridge.points[top]
	var raised: float = high.y - bridge.grounds[top]
	check(raised > PaintedAreas.RAISED, "the test road rises %.1f m" % raised)
	var under := PaintedAreas.square_at(high.x, high.z)
	check(PaintedAreas.allowed(under, "water", bridge), "water can go under raised road")
	check(not PaintedAreas.allowed(PaintedAreas.square_at(bridge.points[0].x, bridge.points[0].z), "water", bridge), "but not on the same road where it's on the ground")

	var old_data := {"grid": TrackPiece.OLD_TILE, "start": [0, 0, 0, 0], "pieces": [{"type": "straight", "length": 3}],
		"paint": {"cell": 8.0, "runs": [[1, 2, 2, "lava"]]}}
	var grow := TrackPath.growth(old_data)
	var old_track := TrackPath.from_dict(old_data)
	var design := CourseDesign.from_dict(old_data)
	check(grow == 2.0 and old_track.paint.count() == 8 and design.paint.count() == 8, "an old course's squares are %d times as many, grown out to fit" % int(grow))
	var lo := Vector2(2 * 8.0 * grow, 1 * 8.0 * grow)
	var hi := Vector2(4 * 8.0 * grow, 2 * 8.0 * grow)
	var fits := true
	for sq: Vector2i in old_track.paint.squares:
		var m := PaintedAreas.middle_of(sq)
		fits = fits and m.x > lo.x and m.x < hi.x and m.y > lo.y and m.y < hi.y
	check(fits and old_track.paint.kind_at(lo.x + 4.0, lo.y + 4.0) == "lava" and old_track.paint.kind_at(hi.x + 6.0, hi.y + 6.0) == "", "and cover the same ground")
	check(design.to_dict().paint == old_track.paint.to_dict() and design.to_dict().grid == TrackPiece.TILE, "a design saves them at the new size")

	var plain := CourseDesign.from_dict({"start": [0, 0, 0, 0], "pieces": [{"type": "straight", "length": 3}]})
	check(not plain.to_dict().has("paint"), "a course with none saves no paint")
	var painted := CourseDesign.from_dict({"grid": TrackPiece.TILE, "start": [0, 0, 0, 0], "pieces": [{"type": "straight", "length": 3}], "paint": dict})
	check(painted.to_dict().paint == dict and painted.duplicate_design().paint.squares == areas.squares, "a design keeps its paint through to_dict and duplicate")
	check(TrackPath.from_dict(painted.to_dict()).paint.squares == areas.squares, "a track reads it too")

	var shared := Sharing.read(Sharing.code_for(painted.to_dict()))
	check(shared.get("kind") == Sharing.COURSE and shared.data.get("paint") == dict, "paint survives a share code")
	var bad := painted.to_dict()
	bad.paint = {"cell": 8.0, "runs": [[0, 0, 1, 5]]}
	check(Sharing.read(Sharing.code_for(bad)).has("why"), "a code with a run that isn't well formed is turned away")
	bad.paint = {"cell": 8.0, "runs": []}
	for k in Sharing.MOST_PAINT_RUNS + 1:
		bad.paint.runs.append([k % 100, 0, 1, "water"])
	check(Sharing.read(Sharing.code_for(bad)).has("why"), "and so is one with too many runs")

	print("All painted area checks passed." if failures == 0 else "%d painted area checks failed." % failures)
	quit(1 if failures > 0 else 0)
