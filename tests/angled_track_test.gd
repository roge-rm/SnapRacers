extends SceneTree

## Circular bends, connector headings and moving the start on angled road.
## Run with --headless --path . -s tests/angled_track_test.gd.

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_arcs()
	_headings()
	_connections()
	_starts()
	print("All angled track checks passed." if failures == 0 else "%d angled track checks failed." % failures)
	quit(1 if failures > 0 else 0)


func _arcs() -> void:
	for angle in [30, 45, 60, 90]:
		for turn in ["left", "right"]:
			for size in [1, 2, 3, 4]:
				var spec := {"type": "arc", "angle": angle, "turn": turn, "size": size}
				var piece := TrackPiece.from_spec(spec)
				var sign := -1 if turn == "left" else 1
				var radius: float = (size - 0.5) * TrackPiece.TILE
				var radians := deg_to_rad(angle)
				var expected := Vector3(sign * radius * (1.0 - cos(radians)), 0.0, -radius * sin(radians))
				var length := 0.0
				var previous := Vector3.ZERO
				for k in range(1, 1001):
					var at := piece.point(k / 1000.0)
					length += previous.distance_to(at)
					previous = at
				var entry := (piece.point(0.001) - piece.point(0.0)).normalized()
				var tangent := (piece.point(1.0) - piece.point(0.999)).normalized()
				var forward := Vector3(sign * sin(radians), 0.0, -cos(radians))
				var correct := piece.point(0.0) == Vector3.ZERO and piece.exit().origin.distance_to(expected) < 0.00002
				correct = correct and entry.dot(Vector3.FORWARD) > 0.99999 and tangent.dot(forward) > 0.99999 and (-piece.exit().basis.z).dot(forward) > 0.99999
				correct = correct and absf(piece.path_length() - radius * radians) < 0.000001 and absf(length - piece.path_length()) < 0.001
				correct = correct and piece.to_spec() == spec and piece.heading_delta() == -sign * (angle / 15)
				check(correct, "%d degree %s size %d has its circular endpoint, tangent, length and spec" % [angle, turn, size])
				if angle == 90:
					var old := TrackPiece.from_spec({"type": "curve", "turn": turn, "size": size, "rise": 2, "bank": 60})
					spec.merge({"rise": 2, "bank": 60})
					var arc := TrackPiece.from_spec(spec)
					var same := old.path_length() == arc.path_length() and old.heading_delta() == arc.heading_delta()
					for k in 101:
						var t := k / 100.0
						same = same and old.point(t).distance_to(arc.point(t)) < 0.00002 and old.bank_at(t) == arc.bank_at(t) and old.up(t) == arc.up(t)
					check(same and arc.sticky, "90 degree %s size %d matches legacy rise and bank profiles" % [turn, size])
	var rising := TrackPiece.from_spec({"type": "arc", "angle": 30, "size": 2, "rise": 2, "bank": 60})
	check(rising.sticky and rising.point(1.0).y == 6.0 and is_equal_approx(rising.bank_at(0.5), deg_to_rad(60.0)), "a shallow arc supports rise, bank and wall rides")
	var course := CourseDesign.new()
	course.pieces = [rising.to_spec(), {"type": "straight"}]
	check(course._units()[1][1] == 2, "arc rise counts towards the level of later straights")


func _headings() -> void:
	var right := TrackPiece.from_spec({"type": "arc", "angle": 45, "turn": "right", "size": 2})
	var left := TrackPiece.from_spec({"type": "arc", "angle": 30, "turn": "left", "size": 2})
	var pose := TrackPath.advance_pose(TrackPath.advance_pose(Transform3D.IDENTITY, right), left)
	check(TrackPath.heading_of(pose.basis) == 23, "45 right then 30 left exits 15 degrees clockwise")
	check(TrackPath.heading_of(Basis(Vector3.UP, deg_to_rad(14.0))) == -1, "an off-grid heading is rejected instead of quantised")
	check(TrackPath.heading_of(Basis.IDENTITY.scaled(Vector3(2, 1, 1))) == -1, "connector bases must stay rigid")
	for heading in 24:
		var basis := TrackPath.heading_basis(heading)
		var start := Transform3D(basis, Vector3(7.25, 3.0, -9.5))
		var straight := TrackPiece.from_spec({"type": "straight", "length": 1})
		var next := TrackPath.advance_pose(start, straight)
		var correct := TrackPath.heading_of(next.basis) == heading and absf(start.origin.distance_to(next.origin) - 32.0) < 0.00001
		for piece_spec in [{"type": "ramp"}, {"type": "slant"}, {"type": "loop"}, {"type": "corkscrew"}, {"type": "crossing"}]:
			var piece := TrackPiece.from_spec(piece_spec)
			var end := TrackPath.advance_pose(start, piece)
			correct = correct and TrackPath.heading_of(end.basis) == heading and end.origin.distance_to(start * piece.exit().origin) < 0.00001
		check(correct, "heading %d rigidly carries straights, ramps, slants, stunts and crossings" % heading)
	for angle in [30, 45]:
		var specs := []
		var end := Transform3D.IDENTITY
		for k in int(360 / angle):
			var spec := {"type": "arc", "angle": angle, "turn": "right", "size": 2}
			specs.append(spec)
			end = TrackPath.advance_pose(end, TrackPiece.from_spec(spec))
		var track := TrackPath.from_dict({"grid": 32, "pieces": specs})
		check(track.closes and end.origin.length() < 0.0001 and TrackPath.heading_of(end.basis) == 0, "%d %d degree arcs close without changing their endpoints" % [specs.size(), angle])


func _connections() -> void:
	var worst_point := 0.0
	var worst_frame := 0.0
	var meshes := true
	var placements := true
	for degrees in [15, 30, 45, 60]:
		for angle in [30, 45, 60, 90]:
			var spec := {"type": "arc", "angle": angle, "turn": "right", "size": 2, "bank": 22, "rise": 1}
			var track := TrackPath.from_dict({"grid": 32, "start": [10, 0, 20, degrees / 90.0], "pieces": [{"type": "straight"}, spec, {"type": "straight"}]})
			var course := CourseDesign.from_dict({"grid": 32, "start": [10, 0, 20, degrees / 90.0], "pieces": [{"type": "straight"}, spec, {"type": "straight"}]})
			course.pieces[1].erase("rise")
			placements = placements and course._pose_before(2, course._units()).is_equal_approx(course.track().piece_starts[2])
			var local := TrackPath.from_dict({"grid": 32, "pieces": [spec]})
			var pose := track.piece_starts[1]
			var first := track.piece_of.find(1)
			for k in local.points.size():
				worst_point = maxf(worst_point, (pose * local.points[k]).distance_to(track.points[first + k]))
				worst_frame = maxf(worst_frame, (pose.basis * local.rights[k]).distance_to(track.rights[first + k]))
			var piece := TrackPiece.from_spec(spec)
			var end := TrackPath.advance_pose(pose, piece)
			var seam := track.piece_of.find(2)
			meshes = meshes and end.origin.distance_to(track.points[seam]) < 0.00001 and track.forwards[seam].dot(-end.basis.z) > 0.99999
			var builder := TrackBuilder.new(track)
			builder._prepare()
			var mesh := builder._piece_mesh(1)
			var preview := TrackBuilder.piece_mesh(spec, track.width, track.theme)
			meshes = meshes and mesh != null and preview != null
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			# Full road includes the final short strip into the next piece.
			var right_edge := builder._at(seam, Vector2(track.width * 0.5, 0.0))
			meshes = meshes and _nearest(vertices, right_edge) < 0.0001
			builder.free()
	check(worst_point < 0.0001 and worst_frame < 0.0002, "local previews and full samples agree at angled headings (%.6f m, %.6f frame)" % [worst_point, worst_frame])
	check(placements, "track starts and course placement agree at every angled seam")
	check(meshes, "full meshes reach each real connector with no missing strip or displaced seam")


func _nearest(points: PackedVector3Array, to: Vector3) -> float:
	var best := INF
	for p in points:
		best = minf(best, p.distance_to(to))
	return best


func _starts() -> void:
	for heading in 24:
		var course := CourseDesign.new()
		course.start = Transform3D(TrackPath.heading_basis(heading), Vector3(sqrt(2.0) * 10, 0, sqrt(3.0) * -20))
		course.pieces = [{"type": "arc", "angle": 45, "turn": "left", "size": 2}]
		var data := course.to_dict()
		var back := CourseDesign.from_dict(JSON.parse_string(JSON.stringify(data)))
		var correct := back.start.origin == course.start.origin and TrackPath.heading_of(back.start.basis) == heading
		correct = correct and typeof(data.start[3]) == (TYPE_INT if heading % 6 == 0 else TYPE_FLOAT)
		check(correct, "start %d survives JSON with precise position and fractional quarter turns" % heading)
	for degrees in [15, 30, 45, 60]:
		var course := CourseDesign.new()
		course.start = TrackPath.start_from([sqrt(2.0), 0, -sqrt(3.0), degrees / 90.0])
		course.landmarks = [{"prop": "windmill", "at": [30.0, -20.0], "facing": 1}]
		for side in 4:
			course.pieces.append_array([{"type": "arc", "angle": 45, "turn": "right", "size": 2}, {"type": "arc", "angle": 45, "turn": "right", "size": 2}, {"type": "straight", "length": 4}])
		var before := course.track()
		var moved := course.with_start_on_longest_straight()
		var after := CourseDesign.from_dict(JSON.parse_string(JSON.stringify(moved.to_dict()))).track()
		var worst := 0.0
		for i in before.pieces.size():
			var piece := before.pieces[i]
			for t in [0.0, 0.3, 0.7]:
				var point := before.piece_starts[i] * piece.point(t)
				var nearest := INF
				for j in after.pieces.size():
					var local := after.piece_starts[j].affine_inverse() * point
					if after.pieces[j].type == "straight":
						var along := clampf(-local.z, 0.0, after.pieces[j].tiles * TrackPiece.TILE)
						nearest = minf(nearest, local.distance_to(Vector3(0, 0, -along)))
					else:
						for u in [0.0, 0.3, 0.7]:
							nearest = minf(nearest, point.distance_to(after.piece_starts[j] * after.pieces[j].point(u)))
				worst = maxf(worst, nearest)
		check(before.closes and after.closes and worst < 0.0003 and absf(before.length - after.length) < 0.01, "%d degree reroot keeps the same world road (%.6f m)" % [degrees, worst])
		check(moved.landmarks == course.landmarks and moved.start.origin != course.start.origin, "%d degree reroot moves the line and keeps world landmarks" % degrees)
