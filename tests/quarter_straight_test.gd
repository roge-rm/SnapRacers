extends Node

var failures := 0
var checks := 0
const QUARTER := {"type": "quarter_straight"}


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var part := TrackPiece.from_spec(QUARTER)
	check(part.type == "quarter_straight" and part.run_length() == 8.0 and part.path_length() == 8.0 and part.exit().origin == Vector3(0, 0, -8), "quarter straight is eight metres with an unchanged exit heading")
	check(part.to_spec() == QUARTER and TrackCatalogue.dimensions(QUARTER) == "8 m long", "quarter straight round-trips and reports its actual length")
	check(TrackCatalogue.specs().count(QUARTER) == 1 and TrackCatalogue.closer_choices().back() == QUARTER, "drawer and closing catalogue offer the quarter straight once")
	var exact := true
	var cursor_error := 0.0
	for h in 24:
		var initial := ClosureCursor.start(h)
		var four := initial
		for i in 4:
			four = ClosureCursor.advance(four, part)
		exact = exact and four == ClosureCursor.advance(initial, TrackPiece.from_spec({"type": "straight"}))
		for spec in TrackCatalogue.specs():
			var piece := TrackPiece.from_spec(spec)
			var pose := TrackPath.advance_pose(Transform3D(TrackPath.heading_basis(h), Vector3.ZERO), piece)
			var cursor := ClosureCursor.advance(initial, piece)
			cursor_error = maxf(cursor_error, ClosureCursor.pose(cursor).origin.distance_to(pose.origin))
	check(exact and cursor_error < 0.0001, "quarter-length exact lattice matches every drawer endpoint at all 24 headings (%.6f m)" % cursor_error)
	var mesh := TrackBuilder.piece_mesh(QUARTER, TrackPath.WIDTH, "orchard")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nearest := INF
	for vertex in vertices:
		nearest = minf(nearest, vertex.distance_to(Vector3(TrackPath.WIDTH * 0.5, TrackBuilder.LIFT, -8)))
	check(nearest < 0.0001, "quarter preview road reaches its full connector")
	var course := CourseDesign.new()
	course.name = "Quarter grid"
	for side in 4:
		for i in 16:
			course.pieces.append(QUARTER.duplicate())
		course.pieces.append({"type": "curve", "turn": "right", "size": 2})
	check(course.problems().is_empty() and course._longest_straight() == 4.0, "quarter-only straights provide a valid closed course and four-tile grid run")
	var moved := course.with_start_on_longest_straight()
	check(moved.problems().is_empty() and moved.pieces.count(QUARTER) == 64 and moved.track().closes, "moving the grid preserves quarter connectors and closure")
	var serialized: Variant = JSON.parse_string(JSON.stringify(moved.to_dict()))
	check(CourseDesign.from_dict(serialized).problems().is_empty(), "quarter course survives JSON save and load")
	for encoded in [Sharing.code_for(moved.to_dict()), Sharing.file_for(moved.to_dict())]:
		var result := Sharing.read(encoded)
		check(not result.has("why") and CourseDesign.from_dict(result.get("data", {})).track().closes, "quarter course imports from its sharing code or file")
	var invalid := moved.to_dict()
	invalid.pieces[0] = {"type": "quarter_straight", "length": 2}
	check(Sharing.validate_course(invalid).has("why") and Sharing.validate_saved(Sharing.COURSE, invalid).has("why"), "fixed quarter length rejects malformed raw and saved imports")
	var partial := moved.duplicate_design()
	partial.pieces.pop_back()
	check(partial.close_up(1, 1000) == [QUARTER], "automatic closing can fill an exact eight-metre gap")
	var net := NetSession.new()
	add_child(net)
	check(NetSession.VERSION == 17 and net._check({"version": 16}).contains("different version") and net._check({"version": 17, "players": []}) == "Nobody to race.", "current online handshake is accepted and older peers are rejected before misreading quarter straights")
	net.queue_free()
	print("%d quarter-straight checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
