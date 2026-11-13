extends SceneTree

## Checks the racing line on every course that comes with the game, in all
## four layouts: it stays inside the road with room for a kart, it's a number
## everywhere, it doesn't jump from one sample to the next or across the start
## line, and it bends less than the middle of the road.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/racing_line_test.gd

const LAYOUTS := [[false, false], [false, true], [true, false], [true, true]]
## The most it may move across between samples about a metre apart, and the
## most that can change from one sample to the next, so it has no kinks.
const MOST_STEP := 0.8
const MOST_KINK := 0.15
const SLACK := 0.001
const TRACKS := "res://data/tracks"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var files := Array(DirAccess.get_files_at(TRACKS)).filter(func(f): return f.ends_with(".json"))
	files.sort()
	check(files.size() > 40, "found the courses (%d)" % files.size())
	var slowest := 0
	var slowest_name := ""
	var longest := 0.0
	var longest_usec := 0
	var longest_name := ""
	var bent_less := 0
	var gain := 0.0
	var runs := 0
	var widest := 0.0
	for file in files:
		for layout in LAYOUTS:
			var track := TrackPath.load_file(TRACKS + "/" + file)
			track.apply_layout(layout[0], layout[1])
			var line := track.racing_line()
			var what := "%s%s%s" % [file.get_basename(), " mirrored" if layout[0] else "", " reversed" if layout[1] else ""]
			var count := track.points.size()
			var half := track.width * 0.5
			var problems := []
			var biggest_step := 0.0
			var biggest_kink := 0.0
			for k in count:
				var o := line.offsets[k]
				if not is_finite(o) or not is_finite(line.bends[k]):
					problems.append("not a number at %d" % k)
					break
				if o > line.highs[k] + SLACK or o < line.lows[k] - SLACK or absf(o) > half - RacingLine.MARGIN + SLACK:
					problems.append("off the road at %.0f m (%.2f)" % [track.distances[k], o])
					break
				var next := (k + 1) % count
				biggest_step = maxf(biggest_step, absf(line.offsets[next] - o))
				biggest_kink = maxf(biggest_kink, absf(line.offsets[next] - 2.0 * o + line.offsets[(k - 1 + count) % count]))
				widest = maxf(widest, absf(o))
			if biggest_step > MOST_STEP:
				problems.append("jumps %.2f m between samples" % biggest_step)
			if biggest_kink > MOST_KINK:
				problems.append("kinks by %.2f m" % biggest_kink)
			var across := absf(track.line_offset_at(track.length - 0.01) - track.line_offset_at(0.01))
			if across > MOST_STEP:
				problems.append("jumps %.2f m at the start line" % across)
			# Somewhere it has to keep to the middle, it does.
			for k in count:
				var piece := track.pieces[track.piece_of[k]]
				if (piece.type == "jump" or TrackPiece.turns_over(piece.type)) and absf(line.offsets[k]) > SLACK:
					problems.append("off the middle on a %s at %.0f m" % [piece.type, track.distances[k]])
					break
			check(problems.is_empty(), "%s %s" % [what, ", ".join(problems)])
			# Driven at the fastest each bend allows, the line should be quicker
			# around than the middle.
			var middle := _lap_time(track, PackedFloat32Array(), track._bends)
			var ours := _lap_time(track, line.offsets, line.bends)
			runs += 1
			if ours < middle:
				bent_less += 1
			else:
				print("  %s is slower than the middle (%.2f s against %.2f s)" % [what, ours, middle])
			gain += 1.0 - ours / middle
			if line.build_usec > slowest:
				slowest = line.build_usec
				slowest_name = what
			if track.length > longest:
				longest = track.length
				longest_usec = line.build_usec
				longest_name = what
	check(bent_less == runs, "the line is quicker than the middle (%d of %d, %.1f%% on average)" % [bent_less, runs, 100.0 * gain / maxi(runs, 1)])
	check(widest > 3.0, "it uses the width of the road (%.1f m at most)" % widest)
	print("  longest course %s (%.0f m) took %.1f ms, slowest %s took %.1f ms" % [longest_name, longest, longest_usec / 1000.0, slowest_name, slowest / 1000.0])
	print("All racing line checks passed." if failures == 0 else "%d racing line checks failed." % failures)
	quit(1 if failures > 0 else 0)


## About how long a lap takes along a line `offsets` right of the middle,
## going as fast as its bends allow, with simple braking and speeding up.
func _lap_time(track: TrackPath, offsets: PackedFloat32Array, bends: PackedFloat32Array) -> float:
	const TOP := 28.0
	const SIDEWAYS := 14.0
	const SPEED_UP := 5.0
	const BRAKE := 12.0
	var count := track.points.size()
	var gaps := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	gaps.resize(count)
	speeds.resize(count)
	for k in count:
		var next := (k + 1) % count
		var a := track.points[k] + track.rights[k] * (offsets[k] if not offsets.is_empty() else 0.0)
		var b := track.points[next] + track.rights[next] * (offsets[next] if not offsets.is_empty() else 0.0)
		gaps[k] = a.distance_to(b)
		var bend: float = 0.0 if TrackPiece.turns_over(track.pieces[track.piece_of[k]].type) else bends[k]
		speeds[k] = minf(TOP, sqrt(SIDEWAYS / maxf(bend, 0.0001)))
	for n in count * 2:
		var k := n % count
		var back := (k - 1 + count) % count
		speeds[k] = minf(speeds[k], sqrt(speeds[back] * speeds[back] + 2.0 * SPEED_UP * gaps[back]))
	for n in count * 2:
		var k := count - 1 - n % count
		var ahead := (k + 1) % count
		speeds[k] = minf(speeds[k], sqrt(speeds[ahead] * speeds[ahead] + 2.0 * BRAKE * gaps[k]))
	var time := 0.0
	for k in count:
		time += gaps[k] / maxf((speeds[k] + speeds[(k + 1) % count]) * 0.5, 0.1)
	return time
