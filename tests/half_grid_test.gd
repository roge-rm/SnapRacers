extends Node

## Physical grid room and start connectors for full and half straights.

var failures := 0
var checks := 0
var greatest_length_difference := 0.0
var greatest_connector_difference := 0.0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/creations/")):
		push_error("Set XDG_DATA_HOME to an isolated folder inside build/creations.")
		get_tree().quit(1)
		return
	call_deferred("_run")


func _halves(count: int) -> Array:
	var out := []
	for i in count:
		out.append({"type": "half_straight"})
	return out


func _loop(run: Array) -> CourseDesign:
	var course := CourseDesign.new()
	course.name = "Half grid test"
	course.landmarks = [{"prop": "windmill", "at": [30.0, -20.0], "facing": 1}]
	for i in 4:
		course.pieces.append_array(run.duplicate(true))
		course.pieces.append({"type": "curve", "size": 2, "turn": "right"})
	return course


func _grid_problem(course: CourseDesign) -> bool:
	return course.problems().any(func(problem): return problem.contains("starting grid"))


func _room(course: CourseDesign) -> bool:
	var units := course._units()
	var ahead := 0.0
	var behind := 0.0
	for unit in units:
		var length := course._grid_length(unit)
		if length == 0.0:
			break
		ahead += length
	for i in units.size():
		var length := course._grid_length(units[-i - 1])
		if length == 0.0:
			break
		behind += length
	return behind >= CourseDesign.GRID_TILES and ahead >= 1.0


func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.000000001
	if a is Dictionary and b is Dictionary:
		return a.size() == b.size() and a.keys().all(func(key): return b.has(key) and _same(a[key], b[key]))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


func _world_road(before: TrackPath, after: TrackPath) -> bool:
	var difference := absf(before.length - after.length)
	greatest_length_difference = maxf(greatest_length_difference, difference)
	if not before.closes or not after.closes or difference > 0.001:
		print("Road length difference: %.9f m, closed: %s / %s" % [difference, before.closes, after.closes])
		return false
	for i in before.pieces.size():
		var piece := before.pieces[i]
		for t in [0.0, 0.3, 0.7, 1.0]:
			var point := before.piece_starts[i] * piece.point(t)
			var nearest := INF
			for j in after.pieces.size():
				var other := after.pieces[j]
				if other.type in ["straight", "half_straight"]:
					var local := after.piece_starts[j].affine_inverse() * point
					nearest = minf(nearest, local.distance_to(Vector3(0, 0, clampf(local.z, -other.path_length(), 0.0))))
				elif other.to_spec() == piece.to_spec():
					nearest = minf(nearest, point.distance_to(after.piece_starts[j] * other.point(t)))
			if nearest > 0.0005:
				print("World road difference: %.9f m at piece %d, t %.2f" % [nearest, i, t])
				return false
	return true


func _half_connectors(before: TrackPath, after: TrackPath) -> bool:
	var old_count := 0
	var new_count := 0
	for piece in after.pieces:
		if piece.type == "half_straight":
			new_count += 1
	for i in before.pieces.size():
		if before.pieces[i].type != "half_straight":
			continue
		old_count += 1
		var nearest := INF
		for j in after.pieces.size():
			if after.pieces[j].to_spec() == before.pieces[i].to_spec() and after.piece_starts[j].basis.is_equal_approx(before.piece_starts[i].basis):
				nearest = minf(nearest, after.piece_starts[j].origin.distance_to(before.piece_starts[i].origin))
		greatest_connector_difference = maxf(greatest_connector_difference, nearest)
		if nearest >= 0.0001:
			print("Half connector difference: %.9f m at piece %d" % [nearest, i])
			return false
	return old_count == new_count


func _fixture(run: Array, label: String, rotate := 0, angled := false) -> void:
	var course := _loop(run)
	if rotate > 0:
		course.pieces = course.pieces.slice(rotate) + course.pieces.slice(0, rotate)
	if angled:
		course.start = TrackPath.start_from([sqrt(2.0), 0, -sqrt(3.0), 0.5])
	var before := course.track()
	var moved := course.with_start_on_longest_straight()
	var after := moved.track()
	check(course.problems().is_empty() and moved.problems().is_empty() and _room(moved), label + " has a legal grid with 64 m behind and 32 m ahead")
	check(_world_road(before, after) and _half_connectors(before, after) and moved.landmarks == course.landmarks, label + " preserves road, half connectors and landmarks")
	var original_connector := false
	var units := course._units()
	for i in units.size():
		if course._pose_before(i, units).is_equal_approx(moved.start):
			original_connector = true
	check(original_connector, label + " moves the line onto an existing connector")
	var saved := CourseDesign.load_file(moved.save())
	check(saved != null and _same(saved.pieces, moved.pieces) and _world_road(after, saved.track()) and _half_connectors(before, saved.track()), label + " saves and reloads every half spec and world connector")
	DirAccess.remove_absolute(CourseDesign.path_for(moved.name))


func _run() -> void:
	var halves := _loop(_halves(10))
	check(halves.track().closes and halves.track().length >= CourseDesign.SHORTEST and halves._longest_straight() == 5.0, "ten half straights per side supply 160 m, or five grid tiles")
	_fixture(_halves(10), "all half straights")
	_fixture(_halves(9), "an odd number of half straights")
	_fixture([{"type": "half_straight"}, {"type": "straight", "length": 3}], "a half at the start of the run")
	_fixture([{"type": "straight", "length": 3}, {"type": "half_straight"}], "a half at the end of the run")
	_fixture([{"type": "half_straight"}, {"type": "straight", "length": 2}, {"type": "half_straight"}, {"type": "half_straight"}], "mixed full and half straights")
	_fixture(_halves(7), "a run across the saved start", 3)
	_fixture(_halves(7), "an angled run across the saved start", 3, true)
	_fixture(_halves(6), "the exact 96 m minimum")

	for count in [1, 2, 3, 4, 5]:
		var short := _loop(_halves(count))
		check(short._longest_straight() == count * 0.5 and _grid_problem(short), "%d half straights cannot supply 96 m of grid road" % count)
	var awkward := _loop([{"type": "half_straight"}, {"type": "straight", "length": 2}, {"type": "half_straight"}])
	check(awkward._longest_straight() == 3.0 and _grid_problem(awkward), "96 m without a connector at 64 m cannot fit the grid")
	var tied := awkward.duplicate_design()
	tied.pieces = tied.pieces.slice(0, 4) + _halves(6) + [{"type": "curve"}]
	var tied_units := tied._units()
	check(tied._best_run(tied_units)[1] == 3.0 and tied._grid_split(tied_units, tied._best_run(tied_units)) >= 0, "equal-length runs favour the one with a legal connector")

	var elevated := _loop([{"type": "ramp", "length": 1, "rise": 1}] + _halves(10) + [{"type": "ramp", "length": 1, "rise": -1}])
	check(elevated._longest_straight() == 0.0 and _grid_problem(elevated), "elevated half straights cannot host the grid")
	for decoration in [{"surface": "asphalt"}, {"surface": "concrete"}, {"edges": "auto"}, {"edges": "walls"}]:
		var part := {"type": "half_straight"}
		part.merge(decoration)
		var decorated := _loop([{"type": "straight", "length": 2}, part, {"type": "half_straight"}])
		check(decorated._longest_straight() == 2.0 and _grid_problem(decorated), "half straights with %s keep breaking the grid run" % str(decoration))

	var legacy := true
	for length in range(1, 11):
		var course := _loop([{"type": "straight", "length": length}])
		var moved := course.with_start_on_longest_straight()
		var ahead := maxi(1, mini(4, length - CourseDesign.GRID_TILES - 1))
		legacy = legacy and moved.start.origin.is_equal_approx(Vector3(0, 0, -(length - ahead) * TrackPiece.TILE))
		legacy = legacy and _world_road(course.track(), moved.track()) and moved.landmarks == course.landmarks
	check(legacy, "all full-tile runs retain their original start placement and world road")
	print("Greatest sampled lap-length difference: %.9f m; half connector difference: %.9f m." % [greatest_length_difference, greatest_connector_difference])
	print("All %d half grid checks passed." % checks if failures == 0 else "%d of %d half grid checks failed." % [failures, checks])
	get_tree().quit(1 if failures else 0)
