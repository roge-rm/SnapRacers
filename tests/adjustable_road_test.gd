extends Node

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var conversions := true
	for spec in [{"type": "straight", "length": 3}, {"type": "half_straight"}, {"type": "quarter_straight"}, {"type": "slant", "length": 3, "across": 1, "turn": "left", "surface": "dirt", "edges": "open"}]:
		var changed := TrackPiece.adjustable_spec(spec)
		var original := TrackPiece.from_spec(spec)
		var edited := TrackPiece.from_spec(changed)
		conversions = conversions and original.exit().is_equal_approx(edited.exit()) and edited.surface == original.surface and edited.edges == original.edges
	check(conversions and TrackPiece.adjustable_spec({"type": "ramp"}).is_empty(), "ordinary straights and flat offsets convert without moving connectors or losing finish")
	var specs := [{"type": "adjustable_straight", "metres": 11.313708498}, {"type": "adjustable_straight", "metres": 0.25}, {"type": "adjustable_offset", "metres": 96.125, "shift": -11.314}]
	var geometry := true
	for spec in specs:
		var piece := TrackPiece.from_spec(spec)
		geometry = geometry and piece.to_spec() == spec and piece.safe_dimensions(13.0)
		geometry = geometry and piece.exit().origin.distance_to(Vector3(float(spec.get("shift", 0)), 0, -float(spec.metres))) < 0.00001
		geometry = geometry and (piece.point(0.00001) - piece.point(0)).normalized().dot(Vector3.FORWARD) > 0.99999
		geometry = geometry and (piece.point(1) - piece.point(0.99999)).normalized().dot(Vector3.FORWARD) > 0.99999
	check(geometry, "fractional metre geometry round-trips and both offset tangents stay aligned")
	var mesh := TrackBuilder.piece_mesh(specs[0], TrackPath.WIDTH, "orchard")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nearest := INF
	for vertex in vertices:
		nearest = minf(nearest, vertex.distance_to(Vector3(TrackPath.WIDTH * 0.5, TrackBuilder.LIFT, -float(specs[0].metres))))
	check(nearest < 0.0001, "custom preview mesh reaches the unrounded connector edge")
	var all_connectors := true
	for target in [Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.25)), Transform3D(Basis.IDENTITY, Vector3(8, 0, -96)), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(32, 0, -32))]:
		var spec := TrackPiece.connector_spec(target, 13.0)
		if spec.is_empty():
			all_connectors = false
			continue
		var join := TrackPiece.from_spec(spec)
		all_connectors = all_connectors and join.exit().is_equal_approx(target) and join.safe_connector(13.0)
		all_connectors = all_connectors and (join.point(0.00001) - join.point(0)).normalized().dot(Vector3.FORWARD) > 0.99999
		all_connectors = all_connectors and (join.point(1) - join.point(0.99999)).normalized().dot(-target.basis.z) > 0.99999
	check(all_connectors, "join proposal handles tiny straight gaps, sideways gaps and changed headings with exact endpoint tangents")
	check(TrackPiece.connector_spec(Transform3D.IDENTITY, 13.0).is_empty() and TrackPiece.connector_spec(Transform3D(Basis.IDENTITY, Vector3(0, 1, -32)), 13.0).is_empty() and TrackPiece.connector_spec(Transform3D(Basis.IDENTITY, Vector3(0, 0, 32)), 13.0).is_empty(), "joins refuse zero gaps, level mismatches and reversing loops")
	check(not TrackPiece.from_spec({"type": "adjustable_offset", "metres": 2, "shift": 100}).safe_dimensions(13.0), "offset safety rejects shifts too sharp for the road width")
	var course := CourseDesign.new()
	course.name = "Metric grid"
	course.start.origin = Vector3(0.123456, 0, 0.654321)
	for side in 4:
		course.pieces.append({"type": "adjustable_straight", "metres": 160.125})
		course.pieces.append({"type": "curve", "turn": "right", "size": 2})
	check(course.problems().is_empty() and course._longest_straight() == 160.125 / 32.0, "fractional straights provide a valid starting grid without rounding")
	var moved := course.with_start_on_longest_straight()
	var sum := 0.0
	for spec in moved.pieces:
		if spec.type == "adjustable_straight":
			sum += float(spec.metres)
	check(moved.track().closes and moved.problems().is_empty() and absf(sum - 4 * 160.125) < 0.000001 and moved.to_dict().start[0] == moved.start.origin.x, "grid relocation splits long metric straights while preserving length and precise world start")
	var finish := {"type": "adjustable_straight", "metres": 64.125, "surface": "dirt", "edges": "walls"}
	var styled := CourseDesign.new()
	styled.pieces = [finish]
	var retained := styled.with_start_on_longest_straight()
	check(retained.pieces == styled.pieces and finish.metres == 64.125, "grid handling does not rewrite styled custom pieces")
	var path := "user://courses/adjustable_road_test.json"
	course.save(path)
	var loaded := CourseDesign.load_file(path)
	var file_read := Sharing.read(Sharing.file_for(course.to_dict()))
	var code_read := Sharing.read(Sharing.code_for(course.to_dict()))
	check(loaded != null and loaded.track().points == course.track().points and not file_read.has("why") and not code_read.has("why") and CourseDesign.from_dict(code_read.data).track().points == course.track().points, "metric pieces survive saved files and file/code sharing")
	var payload := course.to_dict()
	var malformed := true
	for bad in [{"type": "adjustable_straight", "metres": NAN}, {"type": "adjustable_straight", "metres": "12"}, {"type": "adjustable_straight", "metres": 0.1}, {"type": "adjustable_offset", "metres": 16, "shift": INF}, {"type": "connector", "end": [0, -32], "heading": 0.5, "handles": [10, 10]}, {"type": "connector", "end": [0, -32], "heading": 0, "handles": [-1, 10]}]:
		payload.pieces = [bad]
		malformed = malformed and Sharing.validate_course(payload).has("why") and Sharing.validate_saved(Sharing.COURSE, payload).has("why")
	check(malformed, "raw and saved imports reject malformed and unbounded metric dimensions")
	var candidate := TrackPiece.connector_spec(Transform3D(Basis.IDENTITY, Vector3(8, 0, -96)), 13.0)
	payload.pieces = [candidate, specs[2]]
	check(not Sharing.validate_course(payload).has("why"), "shared connectors and safe adjustable offsets retain their shape")
	var before := course.to_dict()
	check(course.close_up().is_empty() and course.to_dict() == before and ClosureCursor.advance(ClosureCursor.start(0), TrackPiece.from_spec(specs[0])).is_empty(), "fixed-part closer refuses non-lattice pieces without moving or rounding the course")
	var net := NetSession.new()
	check(NetSession.VERSION == 17 and net._check({"version": 16}).contains("different version") and net._check({"version": 17, "players": []}) == "Nobody to race.", "protocol 17 prevents earlier peers from misreading adjustable pieces")
	check(not TrackPiece.from_spec({"type": "connector", "end": [0, -32], "heading": 0, "handles": [512, 512]}).safe_connector(13.0), "analytic control-polygon guard rejects collinear reversal hidden between curvature samples")
	var dense_specs := []
	for i in 400:
		dense_specs.append({"type": "adjustable_straight", "metres": 0.25, "edges": "walls"})
	var dense := TrackPath.from_dict({"grid": 32, "pieces": dense_specs})
	var dense_ok := true
	for distance in [10.375, 50.375, 98.375]:
		var position := dense.point_at(distance)
		dense_ok = dense_ok and absf(dense.offset_of(position, distance, 5.0) - distance) < 0.001
		dense_ok = dense_ok and absf(dense.offset_near(position, distance, 5.0, 40.0) - distance) < 0.001
	check(dense_ok, "hinted lookups search travelled distance through many sub-metre pieces")
	check(dense.clashes().is_empty(), "dense short pieces do not report adjacent walled road as a self-collision")
	var distant := TrackPath.from_dict({"grid": 32, "start": [12000, 0, 12000, 0], "pieces": [{"type": "adjustable_straight", "metres": 0.25}]})
	check(distant.forwards[1].is_equal_approx(Vector3.FORWARD) and distant.rights[1].is_equal_approx(Vector3.RIGHT), "sub-metre tangent frames remain valid far from the world origin")
	net.free()
	DirAccess.remove_absolute(path)
	print("%d adjustable road checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
