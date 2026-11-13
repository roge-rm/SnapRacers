extends Node

## Pictures of the split straight in a little test course: from above, and
## from a kart's height coming up to it and down each branch. It needs a
## screen. Add "hills" after -- for the course on hills.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/split_shots.tscn [-- hills]
## They're saved in /srv/downloads/temp/debug/snapracers/split-pieces/game.

const OUT := "/srv/downloads/temp/debug/snapracers/split-pieces/game"
const PIECES := [
	{"type": "straight", "length": 1},
	{"type": "split", "length": 2},
	{"type": "curve", "turn": "right", "size": 2},
	{"type": "curve", "turn": "right", "size": 2},
	{"type": "straight", "length": 3},
	{"type": "curve", "turn": "right", "size": 2},
	{"type": "curve", "turn": "right", "size": 2},
]

var _camera: Camera3D
var _name := "flat"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var hills := OS.get_cmdline_user_args().has("hills")
	_name = "hills" if hills else "flat"
	var track := TrackPath.from_dict({"name": "Split shots", "theme": "orchard", "hills": 8.0 if hills else 0.0, "pieces": PIECES})
	var builder := TrackBuilder.new(track, Conditions.resolve(track.theme, "clear", "day", 7))
	add_child(builder)
	# A kart parked on each branch, for scale.
	var design := KartDesign.load_file("res://data/karts/stock/kart_kid.json")
	for across in [-11.0, 11.0]:
		var kart := Kart.new()
		kart.build(design)
		var spot := track.place_at(TrackPiece.TILE * 2.0 + 6.0, 0.3)
		spot.origin += spot.basis.x * across
		kart.transform = spot
		kart.locked = true
		add_child(kart)
	_camera = Camera3D.new()
	_camera.far = 1500.0
	add_child(_camera)
	_camera.current = true
	for i in 30:
		await get_tree().process_frame
	var middle := TrackPiece.TILE * 2.0
	# From above, the split and then the whole course.
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 60.0
	var above := track.point_at(middle)
	_camera.global_transform = Transform3D(Basis.IDENTITY, above + Vector3.UP * 300.0).looking_at(above, Vector3.RIGHT)
	await _shot("above")
	var bounds := AABB(track.points[0], Vector3.ZERO)
	for p in track.points:
		bounds = bounds.expand(p)
	_camera.size = maxf(bounds.size.x, bounds.size.z) * 9.0 / 16.0 + 80.0
	var centre := bounds.get_center()
	_camera.global_transform = Transform3D(Basis.IDENTITY, centre + Vector3.UP * 600.0).looking_at(centre, Vector3.RIGHT)
	await _shot("course")
	# From a kart's height: coming up to it, then partway down each branch.
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 70.0
	_look(track, TrackPiece.TILE - 14.0, 0.0, TrackPiece.TILE + 30.0, 0.0, 1.6)
	await _shot("coming")
	_look(track, TrackPiece.TILE + 12.0, -9.0, TrackPiece.TILE + 50.0, -9.0, 1.4)
	await _shot("left_branch")
	_look(track, TrackPiece.TILE + 12.0, 9.0, TrackPiece.TILE + 50.0, 9.0, 1.4)
	await _shot("right_branch")
	# Looking back at the far nose where they join up.
	_look(track, TrackPiece.TILE * 3.0 + 18.0, 4.0, TrackPiece.TILE * 2.0 + 10.0, 0.0, 3.0)
	await _shot("join")
	get_tree().quit()


func _look(track: TrackPath, from: float, from_across: float, to: float, to_across: float, height: float) -> void:
	var eye := track.point_at(from) + track.right_at(from) * from_across + Vector3.UP * height
	var at := track.point_at(to) + track.right_at(to) * to_across + Vector3.UP * 0.5
	_camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(at, Vector3.UP)


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/split_%s_%s.png" % [OUT, _name, what])
	print("saved ", what)
