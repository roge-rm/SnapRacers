extends Node

## Run with XDG_DATA_HOME in build/creations.

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


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


func _ready() -> void:
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/creations/")):
		push_error("Set XDG_DATA_HOME to an isolated folder inside build/creations.")
		get_tree().quit(1)
		return
	call_deferred("_run")


func _additions() -> Array:
	var out := [{"type": "half_straight"}]
	for rise in [1, -1]:
		out.append({"type": "ramp", "length": 1, "rise": rise})
	for size in [2, 3]:
		for turn in ["left", "right"]:
			for rise in [1, -1]:
				out.append({"type": "arc", "angle": 45, "size": size, "turn": turn, "rise": rise})
			out.append({"type": "arc", "angle": 45, "size": size, "turn": turn, "bank": 22})
	return out


func _run() -> void:
	var specs := _additions()
	var offered := TrackCatalogue.specs()
	var unique := []
	for spec in offered:
		if spec not in unique:
			unique.append(spec)
	check(specs.size() == 15 and offered.size() == 98 and unique.size() == 98 and specs.all(func(spec): return spec in offered), "the catalogue adds all 15 standard parts once")
	_geometry(specs)
	_half_cursor()
	_meshes(specs)
	_grid()
	_portability(specs)
	print("All %d track parts upgrade checks passed." % checks if failures == 0 else "%d of %d track parts upgrade checks failed." % [failures, checks])
	get_tree().quit(1 if failures else 0)


func _geometry(specs: Array) -> void:
	for spec in specs:
		var piece := TrackPiece.from_spec(spec)
		var back := TrackPiece.from_spec(piece.to_spec())
		var rise: float = spec.get("rise", 0) * TrackPiece.LEVEL
		var correct: bool = _same(piece.to_spec(), spec) and piece.point(0.0) == Vector3.ZERO and piece.point(1.0).y == rise
		correct = correct and piece.point(1.0).distance_to(piece.exit().origin) < 0.00001
		var entry := (piece.point(0.0001) - piece.point(0.0)).normalized()
		var exit_forward := (piece.point(1.0) - piece.point(0.9999)).normalized()
		correct = correct and entry.dot(Vector3.FORWARD) > 0.99999 and exit_forward.dot(-piece.exit().basis.z) > 0.99999
		correct = correct and absf(piece.bank_at(0.0)) < 0.000001 and absf(piece.bank_at(1.0)) < 0.000001 and not piece.sticky
		for k in 101:
			var t := k / 100.0
			correct = correct and piece.point(t).is_finite() and piece.point(t) == back.point(t)
		if spec.type == "half_straight":
			correct = correct and piece.path_length() == 16.0 and piece.exit().origin == Vector3(0, 0, -16)
		elif spec.type == "ramp":
			correct = correct and piece.point(0.5) == Vector3(0, rise * 0.5, -16) and piece.exit().origin.z == -32
		elif spec.has("bank"):
			correct = correct and is_equal_approx(absf(piece.bank_at(0.5)), deg_to_rad(22.0))
		check(correct, "flat connectors, finite profile and unchanged spec for " + str(spec))


func _half_cursor() -> void:
	var half := TrackPiece.from_spec({"type": "half_straight"})
	var whole := TrackPiece.from_spec({"type": "straight", "length": 1})
	var exact := true
	for h in 24:
		var cursor := ClosureCursor.advance(ClosureCursor.start(h), half)
		var pose := TrackPath.advance_pose(Transform3D(TrackPath.heading_basis(h), Vector3.ZERO), half)
		exact = exact and ClosureCursor.pose(cursor).origin.distance_to(pose.origin) < 0.00001
		exact = exact and ClosureCursor.advance(cursor, half) == ClosureCursor.advance(ClosureCursor.start(h), whole)
	check(exact, "two half straights equal one full tile in exact coefficients at every heading")
	var allowed := TrackCatalogue.closer_choices()
	check({"type": "half_straight"} in allowed and {"type": "ramp", "length": 1, "rise": -1} in allowed, "the standard closing catalogue includes both compact connector choices")


func _nearest(vertices: PackedVector3Array, point: Vector3) -> float:
	var nearest := INF
	for vertex in vertices:
		nearest = minf(nearest, vertex.distance_to(point))
	return nearest


func _meshes(specs: Array) -> void:
	var good := true
	var worst := 0.0
	for h in [0, 1, 3, 5]:
		for spec in specs:
			var track := TrackPath.from_dict({"grid": 32, "start": [7, 0, -11, h / 6.0], "pieces": [{"type": "straight"}, spec, {"type": "straight"}]})
			var local := TrackPath.from_dict({"grid": 32, "pieces": [spec]})
			var first := track.piece_of.find(1)
			var seam := track.piece_of.find(2)
			for k in local.points.size():
				worst = maxf(worst, (track.piece_starts[1] * local.points[k]).distance_to(track.points[first + k]))
			var end := TrackPath.advance_pose(track.piece_starts[1], track.pieces[1])
			good = good and track.points[seam].distance_to(end.origin) < 0.00001 and track.forwards[seam].dot(-end.basis.z) > 0.99999
			var builder := TrackBuilder.new(track)
			builder._prepare()
			var mesh := builder._piece_mesh(1)
			var preview := TrackBuilder.piece_mesh(spec, track.width, track.theme)
			good = good and mesh != null and preview != null
			if mesh != null:
				var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				good = good and _nearest(vertices, builder._at(seam, Vector2(track.width * 0.5, 0))) < 0.0001
				good = good and _nearest(vertices, builder._at(seam, Vector2(-track.width * 0.5, 0))) < 0.0001
			builder.free()
	check(good and worst < 0.0001, "all new road meshes join both real connector edges and match local previews (%.6f m)" % worst)


func _grid() -> void:
	var short := CourseDesign.new()
	short.pieces = [{"type": "curve"}, {"type": "straight", "length": 2}, {"type": "half_straight"}]
	check(short._units().size() == 4 and short._units()[-1][0] == {"type": "half_straight"} and short._longest_straight() == 2.5, "a half straight supplies 16 metres and preserves its spec without counting as a full tile")
	var course := _ready_course("right")
	var before := course.track()
	var moved := course.with_start_on_longest_straight()
	var after := moved.track()
	var preserved := before.closes and after.closes and absf(before.length - after.length) < 0.001
	var half_count := 0
	for i in before.pieces.size():
		if before.pieces[i].type != "half_straight":
			continue
		half_count += 1
		var found := false
		for j in after.pieces.size():
			if after.pieces[j].type == "half_straight" and after.piece_starts[j].origin.distance_to(before.piece_starts[i].origin) < 0.0001:
				found = after.piece_starts[j].basis.is_equal_approx(before.piece_starts[i].basis)
		preserved = preserved and found
	check(preserved and half_count == 8 and moved.pieces.count({"type": "half_straight"}) == 8, "moving the start preserves all half straights at their world connectors")
	var saved := CourseDesign.load_file(moved.save())
	check(saved != null and _same(saved.pieces, moved.pieces) and saved.track().closes, "saved rerooted courses keep every half straight and still close")


func _ready_course(turn: String) -> CourseDesign:
	var course := CourseDesign.new()
	course.name = "Compact parts " + turn
	for i in 8:
		course.pieces.append_array([{"type": "straight", "length": 3}, {"type": "half_straight"}, {"type": "ramp", "length": 1, "rise": 1}, {"type": "ramp", "length": 1, "rise": -1}])
		var arc := {"type": "arc", "angle": 45, "turn": turn, "size": 2 + i % 2}
		if i < 2:
			arc.rise = 1
		elif i < 4:
			arc.bank = 22
		elif i < 6:
			arc.rise = -1
		course.pieces.append(arc)
	return course


func _portability(specs: Array) -> void:
	var right := _ready_course("right")
	var left := _ready_course("left")
	check(right.problems().is_empty() and left.problems().is_empty(), "both mirrored cup fixtures are closed, clear and have a full starting grid")
	var cup := {"name": "Compact parts cup", "races": [{"from": "", "course": right.to_dict()}, {"from": "", "course": left.to_dict()}]}
	var contents: Array = right.pieces + left.pieces
	check(specs.all(func(spec): return spec in contents), "ready cup snapshots exercise every new standard part")
	for source in [Sharing.file_for(cup), Sharing.code_for(cup)]:
		var found := Sharing.read(source)
		var good: bool = found.get("kind") == Sharing.CUP
		if good:
			var back := CupDesign.from_dict(found.data)
			var saved := CupDesign.load_file(back.save())
			good = saved != null and _same(saved.races, back.races) and saved.problem() == ""
			var race_paths: Array = back.to_cup("compact_test").paths
			for i in race_paths.size():
				var race := CourseDesign.load_file(race_paths[i])
				good = good and race != null and _same(race.pieces, cup.races[i].course.pieces) and race.track().closes
		check(good, "all new parts survive portable cups, saved snapshots and race materialisation")
	for spec in specs:
		var data := right.to_dict()
		data.pieces = [spec]
		var found := Sharing.validate_course(data)
		check(not found.has("why") and found.data.pieces == data.pieces, "raw course gate accepts the standard spec " + str(spec))
	for setting in [{"length": 0.5}, {"length": 1}, {"length": 2}, {"length": -1}, {"length": INF}, {"length": "16"}, {"rise": 1}, {"size": 2}, {"across": 1}, {"angle": 45}, {"unknown": true}, {"type": "half_unknown"}]:
		var invalid := right.to_dict()
		var piece := {"type": "half_straight"}
		piece.merge(setting, true)
		invalid.pieces[1] = piece
		var bad_cup := cup.duplicate(true)
		bad_cup.races[0].course = invalid
		check(Sharing.validate_course(invalid).has("why") and Sharing.validate_saved(Sharing.COURSE, invalid).has("why") and Sharing.validate_saved(Sharing.CUP, bad_cup).has("why") and Sharing.read(Sharing.code_for(bad_cup)).has("why"), "raw and nested imports reject nonstandard half straight " + str(setting))
	var decorated := right.to_dict()
	decorated.pieces = [{"type": "half_straight", "surface": "concrete", "edges": "walls"}]
	check(not Sharing.validate_course(decorated).has("why") and TrackPiece.from_spec(decorated.pieces[0]).to_spec() == decorated.pieces[0], "half straights retain ordinary surface and wall settings")
	_hosts(right.to_dict(), cup)


func _put(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _hosts(ready: Dictionary, cup: Dictionary) -> void:
	var invalid := ready.duplicate(true)
	invalid.pieces[1].length = 1
	var net := NetSession.new()
	get_tree().root.add_child(net)
	check(NetSession.VERSION == 16 and net._check({"version": 15}).contains("different version") and net._check({"version": 16}) == "Nobody to race.", "protocol 16 prevents old peers from misreading quarter straights")
	net._begin({"course": invalid})
	check(net.setup.is_empty() and net.last_problem == "The host's course can't be built.", "online raw validation rejects a malformed fixed-length piece before construction")
	net.free()
	var folder := "user://compact-host-fixtures"
	_put(folder + "/courses/good.json", ready)
	_put(folder + "/courses/bad.json", invalid)
	_put(folder + "/cups/good.json", cup)
	var bad_cup := cup.duplicate(true)
	bad_cup.races[0].course = invalid
	_put(folder + "/cups/bad.json", bad_cup)
	var server := DedicatedServer.new()
	server.config_path = folder + "/config.json"
	var courses := server.courses()
	var cups := server.cups()
	check(courses.has("mine_good") and not courses.has("mine_bad") and cups.has("mine_good") and not cups.has("mine_bad"), "dedicated discovery accepts new parts and rejects malformed fixed pieces in courses and cups")
	server.free()
