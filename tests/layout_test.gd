extends SceneTree

## Checks mirrored and reversed paths without loading race scenes.

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _oval() -> TrackPath:
	return TrackPath.from_dict({
		"name": "Layout oval",
		"grid": TrackPiece.TILE,
		"landmarks": [{"prop": "tree", "at": [12.0, 0.0], "facing": 1}],
		"pieces": [
			{"type": "straight", "length": 2},
			{"type": "curve", "turn": "left", "size": 2},
			{"type": "curve", "turn": "left", "size": 2},
			{"type": "straight", "length": 2},
			{"type": "curve", "turn": "left", "size": 2},
			{"type": "curve", "turn": "left", "size": 2},
		],
	})


func _initialize() -> void:
	var oval := _oval()
	var old_origin := oval.start.origin
	var old_forward := -oval.start.basis.z
	var old_length := oval.length
	oval.apply_layout(false, true)
	check(oval.start.origin.is_equal_approx(old_origin) and (-oval.start.basis.z).dot(old_forward) < -0.999 \
		and oval.closes and absf(oval.length - old_length) < 1.0, "a reversed oval starts at the line facing back and closes")

	var banked := TrackPiece.from_spec({"type": "curve", "turn": "right", "size": 2, "bank": 22})
	check(banked.bank_at(0.5) > 0.0, "a right bank leans the inside down")
	banked.mirror()
	check(banked.turn < 0 and banked.bank > 0.0 and banked.bank_at(0.5) < 0.0, "a mirrored bank still leans inward")

	oval = _oval()
	old_forward = -oval.start.basis.z
	oval.apply_layout(true, false)
	var mark: Dictionary = oval.landmarks[0]
	check(oval.pieces[1].turn > 0 and (-oval.start.basis.z).dot(old_forward) > 0.999 \
		and is_equal_approx(float(mark.at[0]), -12.0) and int(mark.facing) == 3, "a mirrored oval swaps its turns and landmark side")

	var ordinary := TrackPath.load_file(Tracks.path_of("peach_pit"))
	var ordinary_clashes := ordinary.clashes().size()
	var peach := TrackPath.load_file(Tracks.path_of("peach_pit"))
	old_length = peach.length
	peach.apply_layout(true, false)
	check(peach.closes and peach.clashes().size() <= ordinary_clashes and absf(peach.length - old_length) < 1.0, "mirrored Peach Pit closes without new clashes")

	peach = TrackPath.load_file(Tracks.path_of("peach_pit"))
	old_origin = peach.start.origin
	peach.apply_layout(false, true)
	var grid_delta := peach.grid_slot(0).origin - old_origin
	check(peach.closes and peach.point_at(0.0).distance_to(old_origin) < 0.1 \
		and grid_delta.dot(-peach.start.basis.z) < 0.0, "reversed Peach Pit keeps offset zero and its grid behind the line")

	var foundry := TrackPath.load_file(Tracks.path_of("foundry_flats"))
	foundry.apply_layout(false, true)
	var jump := foundry.pieces.filter(func(piece: TrackPiece): return piece.type == "jump")[0] as TrackPiece
	var first_gap := -1
	for i in 97:
		if not jump.solid(i / 96.0):
			first_gap = i
			break
	var before := jump.point((first_gap - 1) / 96.0).y
	var approach := jump.point((first_gap - 8) / 96.0).y
	var after_gap := first_gap
	while after_gap <= 96 and not jump.solid(after_gap / 96.0):
		after_gap += 1
	check(first_gap > 8 and before > approach and before > 0.5 and after_gap <= 96 \
		and jump.solid(after_gap / 96.0), "a reversed jump has a kicker, gap and landing in drive order")

	var launchpad := TrackPath.load_file(Tracks.path_of("launchpad_loop"))
	launchpad.apply_layout(false, true)
	check(launchpad.closes and launchpad.has_turns_over(), "reversed Launchpad Loop closes and still turns over")

	var cactus := TrackPath.load_file(Tracks.path_of("cactus_canyon"))
	cactus.apply_layout(false, true)
	check(cactus.pieces.any(func(piece: TrackPiece): return piece.crossing), "reversed Cactus Canyon keeps its crossing")

	peach = TrackPath.load_file(Tracks.path_of("peach_pit"))
	peach.apply_layout(true, true)
	check(peach.closes, "mirrored and reversed Peach Pit closes")

	peach = TrackPath.load_file(Tracks.path_of("peach_pit"))
	old_length = peach.length
	old_forward = peach.forward_at(0.0)
	peach.apply_layout(false, false)
	check(is_equal_approx(peach.length, old_length) and peach.forward_at(0.0).is_equal_approx(old_forward), "the ordinary layout stays unchanged")

	peach = TrackPath.load_file(Tracks.path_of("peach_pit"))
	peach.apply_layout(true, true)
	old_origin = peach.points[20]
	old_forward = peach.forward_at(0.0)
	peach.apply_layout(true, true)
	check(peach.points[20].is_equal_approx(old_origin) and peach.forward_at(0.0).is_equal_approx(old_forward), "applying a layout twice is a no-op")

	print("%d layout checks passed." % checks if failures == 0 else "%d of %d layout checks failed." % [failures, checks])
	quit(1 if failures > 0 else 0)
