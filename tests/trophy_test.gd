extends SceneTree

## The cups' brick trophies (TrophyModel) and the course layouts on the cup
## screen (CourseOutline).
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/trophy_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _init() -> void:
	print("-- Trophies")
	var tops := {}
	for cup in GrandPrix.cups():
		check(cup.has("colour") and cup.has("trophy"), "the %s has a colour and a trophy" % cup.name)
		var spec: Dictionary = cup.get("trophy", {})
		check(TrophyModel.TOPS.has(spec.get("top", "")), "  and its top is one there is (%s)" % spec.get("top", ""))
		tops[spec.get("top", "")] = true
		for finish in TrophyModel.FINISHES:
			var pieces := TrophyModel.pieces(spec, Color(cup.get("colour", "#ffffff")), finish)
			var all := AABB(pieces[0].box.position, pieces[0].box.size)
			for piece in pieces:
				all = all.merge(piece.box)
			var fits := all.position.y > -0.01 and all.size.x < 1.3 and all.size.z < 1.3 and all.size.y < 2.2
			var loose := _loose(pieces)
			if finish == "grey" or not fits or loose > 0:
				check(fits and loose == 0, "  in %s it's a sensible size (%.2f by %.2f by %.2f m) with nothing loose (%d)" % [finish, all.size.x, all.size.y, all.size.z, loose])
	check(tops.size() == GrandPrix.cups().size(), "every cup's trophy is different")
	var mine := TrophyModel.spec_for("My Cup")
	check(mine == TrophyModel.spec_for("My Cup") and TrophyModel.colour_for("My Cup") == TrophyModel.colour_for("My Cup"), "your own cup gets a trophy from its name, the same every time")
	check(TrophyModel.finish_for(1) == "gold" and TrophyModel.finish_for(3) == "bronze" and TrophyModel.finish_for(4) == "grey" and TrophyModel.finish_for(0) == "grey", "top three are gold, silver and bronze, and the rest grey")

	print("-- Course layouts")
	for id in ["peach_pit", "launchpad_loop", "spark_deck", "serpent_summit"]:
		var path := Tracks.path_of(id)
		var track := TrackPath.load_file(path)
		var outline := CourseOutline.of_track(track)
		var line: PackedVector2Array = outline.line
		var box := Rect2(Vector2(track.points[0].x, track.points[0].z), Vector2.ZERO)
		for p in track.points:
			box = box.expand(Vector2(p.x, p.z))
		var outline_box: Rect2 = outline.box
		check(line.size() > 20 and line[0] == line[line.size() - 1], "%s's layout comes back round to the start (%d points)" % [track.name, line.size()])
		check(outline_box.grow(CourseOutline.EVERY * 2.0).encloses(box) and box.grow(1.0).encloses(outline_box), "  and fills the same space as the course")
		check(outline.name == track.name and outline.summary.begins_with("%d m" % roundi(track.length)), "  with its name and a line about it (%s)" % outline.summary)
		var loops := track.pieces.filter(func(p): return TrackPiece.turns_over(p.type)).size()
		check(outline.loops.size() == loops, "  and a mark for each loop or corkscrew (%d)" % outline.loops.size())
		var saved := CourseOutline.of(path)
		check(saved.line.size() == line.size() and saved.summary == outline.summary, "  which comes back the same once it's saved")

	print("All trophy checks passed." if failures == 0 else "%d trophy checks failed." % failures)
	quit(1 if failures > 0 else 0)


## How many pieces of a trophy aren't held on, through the others, to the
## plinth on the ground.
static func _loose(pieces: Array) -> int:
	var held := {}
	var reached: Array[int] = []
	for i in pieces.size():
		if pieces[i].box.position.y < 0.01:
			held[i] = true
			reached.append(i)
	while not reached.is_empty():
		var i: int = reached.pop_back()
		for k in pieces.size():
			if not held.has(k) and (pieces[i].box as AABB).grow(0.005).intersects(pieces[k].box):
				held[k] = true
				reached.append(k)
	return pieces.size() - held.size()
