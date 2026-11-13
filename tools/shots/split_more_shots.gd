extends Node

## Pictures of the rest of the split pieces, each in a little square course:
## from above, and from a kart's height coming up to it and down its odd
## branch. It needs a screen.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/split_more_shots.tscn [-- name]
## They're saved in /srv/downloads/temp/debug/snapracers/split-pieces/game.

const OUT := "/srv/downloads/temp/debug/snapracers/split-pieces/game"
const PIECES := {
	"split96": {"type": "split", "length": 3},
	"wide": {"type": "split", "length": 4, "island": 38.0},
	"bend_wide_left": {"type": "split_bend", "turn": "left", "size": 3},
	"bend_extra_right": {"type": "split_bend", "turn": "right", "size": 4},
	"rough_left": {"type": "rough_split", "side": "left"},
	"rough_right": {"type": "rough_split", "side": "right"},
	"jump_left": {"type": "jump_split", "side": "left"},
	"jump_right": {"type": "jump_split", "side": "right"},
}

var _camera: Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var only := OS.get_cmdline_user_args()
	_camera = Camera3D.new()
	_camera.far = 1500.0
	add_child(_camera)
	_camera.current = true
	for key: String in PIECES:
		if not only.is_empty() and not only.has(key):
			continue
		await _piece(key, PIECES[key])
	get_tree().quit()


## A square course of right hand bends with the piece on its first side, or
## as its first corner for a bend.
static func course(spec: Dictionary) -> TrackPath:
	var size := int(spec.get("size", 3))
	var corner := {"type": "curve", "turn": "right", "size": size}
	var pieces := []
	if spec.type == "split_bend":
		corner.turn = spec.turn
		pieces = [{"type": "straight", "length": 4}, spec]
	else:
		var tiles := TrackPiece.from_spec(spec).tiles
		pieces = [{"type": "straight", "length": 1}, spec, {"type": "straight", "length": 5 - tiles}, corner]
	for i in 3:
		pieces.append({"type": "straight", "length": 4 if spec.type == "split_bend" else 6})
		pieces.append(corner)
	return TrackPath.from_dict({"name": "Split shots", "theme": "orchard", "pieces": pieces})


func _piece(key: String, spec: Dictionary) -> void:
	var track := course(spec)
	if not track.closes:
		push_error("%s: the course doesn't close" % key)
	var builder := TrackBuilder.new(track, Conditions.resolve(track.theme, "clear", "day", 7))
	add_child(builder)
	var index := track.pieces.find_custom(func(p: TrackPiece) -> bool: return p.is_split())
	var from := 0
	while track.piece_of[from] != index:
		from += 1
	var start := track.distances[from]
	var run := track.pieces[index].path_length()
	var middle := start + run * 0.5
	# A kart parked on each branch, for scale.
	var design := KartDesign.load_file("res://data/karts/stock/kart_kid.json")
	var karts: Array[Kart] = []
	for side in 2:
		var kart := Kart.new()
		kart.build(design)
		var at := start + run * 0.3
		var spot := track.place_at(at, 0.3)
		spot.origin += spot.basis.x * track.branch_centre_at(at, side)
		kart.transform = spot
		kart.locked = true
		add_child(kart)
		karts.append(kart)
	for i in 20:
		await get_tree().process_frame
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = run * 0.75 + 20.0
	var above := track.point_at(middle)
	_camera.global_transform = Transform3D(Basis.IDENTITY, above + Vector3.UP * 300.0).looking_at(above, Vector3.RIGHT)
	await _shot(key, "above")
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 70.0
	_look(track, start - 14.0, 0.0, start + 30.0, 0.0, 1.6)
	await _shot(key, "coming")
	var odd := track.pieces[index].odd_branch()
	if odd < 0:
		odd = 1 if track.pieces[index].turn > 0 else 0
	var lane := func(d: float) -> float: return track.branch_centre_at(d, odd)
	_look(track, start + run * 0.25, lane.call(start + run * 0.25), start + run * 0.6, lane.call(start + run * 0.6), 1.4)
	await _shot(key, "branch")
	# A jump from the side, out past its branch.
	if spec.type == "jump_split":
		var outward := -1.0 if odd == 0 else 1.0
		_look(track, start + run * 0.45, lane.call(start + run * 0.45) + outward * 26.0, start + run * 0.5, lane.call(start + run * 0.5), 3.0)
		await _shot(key, "side")
	for kart in karts:
		kart.queue_free()
	builder.queue_free()
	await get_tree().process_frame


func _look(track: TrackPath, from: float, from_across: float, to: float, to_across: float, height: float) -> void:
	var eye := track.point_at(from) + track.right_at(from) * from_across + Vector3.UP * height
	var at := track.point_at(to) + track.right_at(to) * to_across + Vector3.UP * 0.5
	_camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(at, Vector3.UP)


func _shot(key: String, what: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [OUT, key, what])
	print("saved ", key, " ", what)
