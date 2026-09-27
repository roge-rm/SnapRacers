extends SceneTree

## Checks the tracks that come with the game: every one should close into a
## loop, with no two bits of road running into each other, and the lap
## counting should hold up to driving backwards over the line.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/track_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	for file in DirAccess.get_files_at("res://data/tracks"):
		if not file.ends_with(".json"):
			continue
		var track := TrackPath.load_file("res://data/tracks/" + file)
		print("%s: %d pieces, %.0f m a lap" % [track.name, track.pieces.size(), track.length])
		check(track.closes, "%s comes back round to the start" % track.name)
		var clashes := track.clashes()
		check(clashes.is_empty(), "%s has no road running into other road %s" % [track.name, clashes.slice(0, 3)])
		var highest := 0.0
		for p in track.points:
			highest = maxf(highest, p.y)
		check(highest > 5.0, "%s climbs (highest point %.1f m)" % [track.name, highest])
		var stuck := track.stickies.count(true)
		print("    %d m of it sticky" % stuck)

		# Round trip through the file format.
		var again := TrackPath.from_dict(track.to_dict())
		check(is_equal_approx(again.length, track.length), "%s saves and loads the same" % track.name)

		# Positions map back to the right place along the track, even where
		# the road crosses over itself.
		var worst := 0.0
		var d := 0.0
		while d < track.length:
			var found := track.offset_of(track.point_at(d) + track.up_at(d) * 0.5, d)
			var off := absf(found - d)
			worst = maxf(worst, minf(off, track.length - off))
			d += 7.0
		check(worst < 1.0, "%s finds where a kart is along it (worst %.2f m out)" % [track.name, worst])

	var brickyard := TrackPath.load_file("res://data/tracks/brickyard.json")
	var over := 0
	for i in range(0, brickyard.points.size(), 4):
		for j in range(i + 30, brickyard.points.size(), 4):
			var a := brickyard.points[i]
			var b := brickyard.points[j]
			if Vector2(a.x - b.x, a.z - b.z).length() < 4.0 and absf(a.y - b.y) > 5.0:
				over += 1
	check(over > 0, "the Brickyard bridge really does cross over the road below")

	# The loop piece ends on the grid, one tile across and three along.
	var loop := TrackPiece.from_spec({ "type": "loop", "side": "right" })
	var out := loop.exit().origin
	check(out.distance_to(Vector3(16.0, 0.0, -48.0)) < 0.01, "a loop ends on the grid (%s)" % out)
	check(absf(loop.point(0.999).y) < 0.05, "and back down at road level (%.3f m)" % loop.point(0.999).y)
	var top := 0.0
	for i in 101:
		top = maxf(top, loop.point(i / 100.0).y)
	check(top > 15.0 and top < 30.0, "a loop is a sensible height (%.1f m)" % top)
	check(TrackPiece.from_spec({ "type": "curve", "bank": 80 }).sticky, "a bend banked 80 degrees is a wall ride you stick to")
	check(not TrackPiece.from_spec({ "type": "curve", "bank": 22 }).sticky, "a gently banked bend isn't")

	# Lap counting.
	var length := 100.0
	var progress := RaceProgress.new(length, 2, 92.0)
	var t := 0.0
	var at := 92.0
	for step in 300:
		t += 0.1
		at = fposmod(at + 1.0, length)
		progress.update(at, t)
	check(progress.finished, "two laps and a bit finishes a two-lap race")
	check(progress.lap_times.size() == 2, "with two lap times (%s)" % [progress.lap_times])

	progress = RaceProgress.new(length, 3, 92.0)
	at = 92.0
	for step in 12:
		at = fposmod(at + 1.0, length)
		progress.update(at, 0.0)
	check(progress.laps == 0, "crossing the line from the grid starts lap one")
	for step in 8:
		at = fposmod(at - 1.0, length)
		progress.update(at, 0.0)
	check(progress.laps == -1, "backing over the line takes it away again")
	for step in 8:
		at = fposmod(at + 1.0, length)
		progress.update(at, 0.0)
	check(progress.laps == 0, "and driving forward over it gives it back, but no more")
	for step in 5:
		at = fposmod(at - 1.0, length)
		progress.update(at, 0.0)
	for step in 5:
		at = fposmod(at + 1.0, length)
		progress.update(at, 0.0)
	check(progress.laps == 0, "rocking back and forth over the line gains nothing")

	print("All track checks passed." if failures == 0 else "%d track checks failed." % failures)
	quit(1 if failures > 0 else 0)
