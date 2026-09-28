class_name TrackBuilder
extends Node3D

## Builds the track you drive on from a TrackPath.
##
## Each piece becomes one static body with its road, its curbs and the deck
## under them, plus a low brick wall down any side that has one. It's all
## swept along the line down the middle, so hills and banking come for free.
## Raised road gets pillars down to the ground, cut bends get a dirt patch
## inside, and there's a gantry over the start line.
##
## It's all made to look like it's built from bricks (see BrickShaders). The
## road is smooth tiles, the curbs and wall tops have studs, the walls and the
## road's edges are courses of bricks, the ground is a baseplate, and brick
## trees stand around the outside.

const DECK := 0.6 # how thick the road is
const WALL_HEIGHT := 1.0
const WALL_THICKNESS := 0.5
const LIFT := 0.02 # keeps road at ground level just above the grass
const PILLAR_EVERY := 16.0
const PILLAR_SIZE := 1.5 # six studs square

const COLOURS := {
	"asphalt": Color("#6c6e68"), # dark bluish grey, like the bricks
	"dirt": Color("#8a6a45"),
	"grass": Color("#3d7a32"),
	"sand": Color("#d9c38c"),
	"ice": Color("#cfe8f2"),
}
const KERB_RED := Color("#d8261c")
const KERB_WHITE := Color("#f2f2f2")
const DECK_COLOUR := Color("#7a7f87")

const WALL_COLOUR := Color("#c4281c")
const GROUND_COLOUR := Color("#4b9f4a") # bright green
const PILLAR_COLOUR := Color("#a3a2a4")
const TRUNK_COLOUR := Color("#694030")
const LEAF_COLOURS := [Color("#237841"), Color("#2c8a3f"), Color("#3f9c46")]
const TREES := 60
const TREE_CLEAR := 12.0 # from the edge of the road
## Which surface each edge of the outline is, for the shader.
const KIND := {"road": 0.0, "kerb": 1.0, "deck": 2.0, "wall": 3.0, "walltop": 4.0}

var track: TrackPath
var _material: ShaderMaterial

# Each shader is made once and kept for as long as the game runs. The phone
# compiles a shader the first time it's drawn, and a new Shader object counts
# as new even with the same code, so building them fresh for every race made
# every race stall on its first frame.
static var _road_shader: Shader
static var _grass_shader: Shader
static var _block_shader: Shader


static func shader_for(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func _init(path: TrackPath) -> void:
	track = path


func _ready() -> void:
	# A plain standard material lit the flat road with so much sky on the
	# phone that the asphalt came out pale blue, so the road has its own
	# shader like the grass.
	if _road_shader == null:
		_road_shader = shader_for(BrickShaders.TRACK)
		_grass_shader = shader_for(BrickShaders.BASEPLATE)
		_block_shader = shader_for(BrickShaders.BLOCK)
	_material = ShaderMaterial.new()
	_material.shader = _road_shader
	SkyAndSun.add_to(self, 80.0)
	_add_grass()
	for i in track.pieces.size():
		_add_piece(i)
	_add_pillars()
	_add_gantry()
	_add_trees()


func _add_grass() -> void:
	var bounds := AABB(track.points[0], Vector3.ZERO)
	for p in track.points:
		bounds = bounds.expand(p)
	bounds = bounds.grow(80.0)
	var centre := bounds.get_center()
	var grass: Array = track.grip_and_drag("grass")

	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	body.set_meta("grip", grass[0])
	body.set_meta("drag", grass[1])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(bounds.size.x, 2.0, bounds.size.z)
	shape.shape = box
	shape.position = Vector3(centre.x, -1.0, centre.z)
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(bounds.size.x, bounds.size.z)
	mesh.mesh = plane
	mesh.position = Vector3(centre.x, 0.0, centre.z)
	mesh.material_override = _baseplate(GROUND_COLOUR)
	body.add_child(mesh)
	add_child(body)


func _baseplate(colour: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _grass_shader
	material.set_shader_parameter("colour", colour)
	return material


## The outline of the road across, as edges to sweep along the track. Each
## edge is [from, to, surface], in (right, up) metres, and faces out to the
## left of the way it runs.
func _profile(piece: TrackPiece) -> Array:
	var half := track.width * 0.5
	var kerb := half + TrackPath.KERB
	var wall := kerb + WALL_THICKNESS
	var edges := [
		[Vector2(-kerb, 0.0), Vector2(-half, 0.0), "kerb"],
		[Vector2(-half, 0.0), Vector2(half, 0.0), "road"],
		[Vector2(half, 0.0), Vector2(kerb, 0.0), "kerb"],
		[Vector2(kerb, -DECK), Vector2(-kerb, -DECK), "deck"],
	]
	if piece.wall_right:
		edges.append([Vector2(kerb, 0.0), Vector2(kerb, WALL_HEIGHT), "wall"])
		edges.append([Vector2(kerb, WALL_HEIGHT), Vector2(wall, WALL_HEIGHT), "walltop"])
		edges.append([Vector2(wall, WALL_HEIGHT), Vector2(wall, -DECK), "wall"])
	else:
		edges.append([Vector2(kerb, 0.0), Vector2(kerb, -DECK), "deck"])
	if piece.wall_left:
		edges.append([Vector2(-kerb, WALL_HEIGHT), Vector2(-kerb, 0.0), "wall"])
		edges.append([Vector2(-wall, WALL_HEIGHT), Vector2(-kerb, WALL_HEIGHT), "walltop"])
		edges.append([Vector2(-wall, -DECK), Vector2(-wall, WALL_HEIGHT), "wall"])
	else:
		edges.append([Vector2(-kerb, -DECK), Vector2(-kerb, 0.0), "deck"])
	return edges


func _add_piece(index: int) -> void:
	var piece := track.pieces[index]
	var samples: Array[int] = []
	for k in track.points.size():
		if track.piece_of[k] == index:
			samples.append(k)
	if samples.is_empty():
		return
	# Run on into the next piece's first sample so there's no seam. The last
	# piece of a track that doesn't come back around to the start has nothing
	# to run on into (joining it to the start drew road right across the map).
	var last_piece := index == track.pieces.size() - 1
	if not last_piece or track.closes:
		samples.append((samples[-1] + 1) % track.points.size())

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := _profile(piece)
	var surface_colour: Color = COLOURS.get(piece.surface, COLOURS["asphalt"])
	for n in samples.size() - 1:
		var a := samples[n]
		var b := samples[n + 1]
		if not track.solids[a] or not track.solids[b]:
			continue
		var stripe := int(track.distances[a] / 4.0) % 2 == 0
		for edge in profile:
			var colour: Color
			match edge[2]:
				"road":
					colour = surface_colour
				"kerb":
					colour = KERB_RED if stripe else KERB_WHITE
				"wall", "walltop":
					colour = WALL_COLOUR
				_:
					colour = DECK_COLOUR
			_sweep(tool, a, b, edge[0], edge[1], colour, KIND[edge[2]])
		# Close off the road where it stops for the jump's gap.
		var before := samples[n - 1] if n > 0 else (a - 1 + track.points.size()) % track.points.size()
		if not track.solids[before]:
			_cap(tool, a, -1.0)
		if n + 2 < samples.size() and not track.solids[samples[n + 2]]:
			_cap(tool, b, 1.0)

	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	var feel: Array = track.grip_and_drag(piece.surface)
	body.set_meta("grip", feel[0])
	body.set_meta("drag", feel[1])
	body.set_meta("sticky", piece.sticky)
	var mesh := tool.commit()
	var look := MeshInstance3D.new()
	look.mesh = mesh
	look.material_override = _material
	body.add_child(look)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)

	if piece.cut:
		_add_cut(index, piece)


func _at(k: int, across: Vector2) -> Vector3:
	return track.points[k] + track.rights[k] * across.x + track.ups[k] * (across.y + LIFT)


## One edge of the outline, from sample a to sample b.
func _sweep(tool: SurfaceTool, a: int, b: int, from: Vector2, to: Vector2, colour: Color, kind: float) -> void:
	var out := Vector2(-(to.y - from.y), to.x - from.x).normalized()
	var normal_a := track.rights[a] * out.x + track.ups[a] * out.y
	var normal_b := track.rights[b] * out.x + track.ups[b] * out.y
	var af := _at(a, from)
	var at := _at(a, to)
	var bf := _at(b, from)
	var bt := _at(b, to)
	# The shader needs how far along the track this is, and how far across (on
	# flat edges) or up (on upright ones), in metres. The far end of the last
	# stretch is the full length of the lap, not back to 0.
	var along_a := track.distances[a]
	var along_b := track.distances[b] if b > a else track.length
	var upright := absf(to.y - from.y) > absf(to.x - from.x)
	var uv_from := from.y if upright else from.x
	var uv_to := to.y if upright else to.x
	tool.set_color(colour)
	tool.set_uv2(Vector2(kind, 0.0))
	var corners := [
		[af, normal_a, Vector2(along_a, uv_from)],
		[bt, normal_b, Vector2(along_b, uv_to)],
		[at, normal_a, Vector2(along_a, uv_to)],
		[af, normal_a, Vector2(along_a, uv_from)],
		[bf, normal_b, Vector2(along_b, uv_from)],
		[bt, normal_b, Vector2(along_b, uv_to)],
	]
	for v in corners:
		tool.set_normal(v[1])
		tool.set_uv(v[2])
		tool.add_vertex(v[0])


## A flat end on the road where it stops, facing along the track (1) or back
## (-1).
func _cap(tool: SurfaceTool, k: int, facing: float) -> void:
	var kerb := track.width * 0.5 + TrackPath.KERB
	var corners := [Vector2(-kerb, 0.0), Vector2(kerb, 0.0), Vector2(kerb, -DECK), Vector2(-kerb, -DECK)]
	var points := corners.map(func(c): return _at(k, c))
	var normal: Vector3 = track.forwards[k] * facing
	tool.set_color(DECK_COLOUR)
	tool.set_normal(normal)
	tool.set_uv2(Vector2(KIND["deck"], 0.0))
	var order := [0, 1, 2, 0, 2, 3] if facing > 0.0 else [0, 2, 1, 0, 3, 2]
	for i in order:
		tool.set_uv(corners[i])
		tool.add_vertex(points[i])


## The dirt patch inside a cut bend. It's a quarter circle from the corner of
## the bend out to the inside curb.
func _add_cut(index: int, piece: TrackPiece) -> void:
	var start := track.piece_starts[index]
	var reach := piece.radius - track.width * 0.5 - TrackPath.KERB
	var centre := start * Vector3(piece.turn * piece.radius, 0.0, 0.0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_color(COLOURS["dirt"])
	tool.set_normal(Vector3.UP)
	var steps := 16
	var lift := Vector3.UP * LIFT * 0.6
	for i in steps:
		var a0 := float(i) / steps * PI * 0.5
		var a1 := float(i + 1) / steps * PI * 0.5
		var p0 := start * Vector3(piece.turn * (piece.radius - reach * cos(a0)), 0.0, -reach * sin(a0))
		var p1 := start * Vector3(piece.turn * (piece.radius - reach * cos(a1)), 0.0, -reach * sin(a1))
		var tri := [centre, p0, p1] if piece.turn > 0 else [centre, p1, p0]
		for v in tri:
			tool.add_vertex(v + lift)
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	var feel: Array = track.grip_and_drag("dirt")
	body.set_meta("grip", feel[0])
	body.set_meta("drag", feel[1])
	var mesh := tool.commit()
	var look := MeshInstance3D.new()
	look.mesh = mesh
	look.material_override = _baseplate(COLOURS["dirt"])
	body.add_child(look)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


## Pillars under raised road, one every so often, but never standing on
## another bit of road.
func _add_pillars() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	add_child(body)
	var spots: Array[Transform3D] = []
	var clear := track.width * 0.5 + TrackPath.KERB + 2.0
	var next := 0.0
	for k in track.points.size():
		# Nothing goes under loops and wall rides, because the road isn't lying
		# flat there.
		if track.distances[k] < next or not track.solids[k] or track.ups[k].y < 0.9:
			continue
		var p := track.points[k]
		var bottom := p.y - DECK
		if bottom < 1.0:
			continue
		var blocked := false
		for j in range(0, track.points.size(), 2):
			var q := track.points[j]
			if q.y < p.y - 3.0 and Vector2(q.x - p.x, q.z - p.z).length() < clear:
				blocked = true
				break
		if blocked:
			continue
		next = track.distances[k] + PILLAR_EVERY
		# Lined up with the stud grid, like everything else built on the
		# baseplate.
		var where := Transform3D(Basis.IDENTITY, Vector3(snappedf(p.x, 0.25), bottom * 0.5, snappedf(p.z, 0.25)))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(PILLAR_SIZE, bottom, PILLAR_SIZE)
		shape.shape = box
		shape.transform = where
		body.add_child(shape)
		spots.append(where.scaled_local(Vector3(PILLAR_SIZE, bottom, PILLAR_SIZE)))
	if spots.is_empty():
		return
	var colours: Array[Color] = []
	colours.resize(spots.size())
	colours.fill(PILLAR_COLOUR)
	_add_blocks(spots, colours)


## Draws boxes that look built from bricks, all in one go. Each transform
## scales a 1 m cube to size.
func _add_blocks(spots: Array[Transform3D], colours: Array[Color]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = BoxMesh.new()
	multi.instance_count = spots.size()
	for i in spots.size():
		multi.set_instance_transform(i, spots[i])
		multi.set_instance_color(i, colours[i])
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = _block_shader
	draw.material_override = material
	add_child(draw)


## An arch of bricks over the start line.
func _add_gantry() -> void:
	var frame := track.frame_at(0.0)
	var reach := track.width * 0.5 + TrackPath.KERB + WALL_THICKNESS + 1.0
	var height := 5.1 # 17 bricks
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	add_child(body)
	# Lined up with the stud grid, like the pillars.
	var flat := Vector3(frame.basis.z.x, 0.0, frame.basis.z.z).normalized()
	var turn := Basis(Vector3.UP, snappedf(atan2(flat.x, flat.z), PI * 0.5))
	var base := Vector3(snappedf(frame.origin.x, 0.25), frame.origin.y, snappedf(frame.origin.z, 0.25))
	var blocks := [
		[Vector3(-reach, height * 0.5, 0.0), Vector3(1.0, height, 1.0), WALL_COLOUR],
		[Vector3(reach, height * 0.5, 0.0), Vector3(1.0, height, 1.0), WALL_COLOUR],
		[Vector3(0.0, height + 0.45, 0.0), Vector3(reach * 2.0 + 1.0, 0.9, 1.0), Color("#f2cd37")],
	]
	var spots: Array[Transform3D] = []
	var colours: Array[Color] = []
	for block in blocks:
		var size: Vector3 = block[1]
		var where := Transform3D(turn, base + turn * (block[0] as Vector3))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.transform = where
		body.add_child(shape)
		spots.append(where.scaled_local(size))
		colours.append(block[2])
	_add_blocks(spots, colours)
	var line := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(track.width, 1.0)
	line.mesh = quad
	line.transform = frame.translated_local(Vector3(0.0, LIFT + 0.01, 0.0))
	line.material_override = PartVisuals.material(Color("#f2f2f2"))
	add_child(line)


## Brick trees dotted around the outside of the track, well clear of the road
## and of any short cut across a bend. The same track always gets the same
## trees.
func _add_trees() -> void:
	var bounds := AABB(track.points[0], Vector3.ZERO)
	for p in track.points:
		bounds = bounds.expand(p)
	bounds = bounds.grow(55.0)
	var clear := track.width * 0.5 + TrackPath.KERB + TREE_CLEAR
	var cuts: Array[Vector3] = []
	var cut_reach: Array[float] = []
	for i in track.pieces.size():
		var piece := track.pieces[i]
		if piece.cut:
			cuts.append(track.piece_starts[i] * Vector3(piece.turn * piece.radius, 0.0, 0.0))
			cut_reach.append(piece.radius + 4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = track.points.size() * 7919 + int(track.length)
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	add_child(body)
	var spots: Array[Transform3D] = []
	var colours: Array[Color] = []
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < TREES and tries < TREES * 20:
		tries += 1
		var at := Vector2(
			snappedf(rng.randf_range(bounds.position.x, bounds.end.x), 0.5),
			snappedf(rng.randf_range(bounds.position.z, bounds.end.z), 0.5))
		if _near_track(at, clear) or placed.any(func(q: Vector2) -> bool: return q.distance_to(at) < 6.0):
			continue
		var in_cut := false
		for c in cuts.size():
			if Vector2(cuts[c].x, cuts[c].z).distance_to(at) < cut_reach[c]:
				in_cut = true
				break
		if in_cut:
			continue
		placed.append(at)
		var size := rng.randi_range(0, 2)
		var trunk := 0.9 + 0.3 * size
		var layers := [[0.5, trunk, TRUNK_COLOUR]]
		var widths := [3.0, 2.0, 1.0] if size < 2 else [4.0, 3.0, 2.0, 1.0]
		for w in widths.size():
			layers.append([widths[w], 0.9, LEAF_COLOURS[(w + size) % LEAF_COLOURS.size()]])
		var y := 0.0
		for layer in layers:
			var extent := Vector3(layer[0], layer[1], layer[0])
			var where := Transform3D(Basis.IDENTITY, Vector3(at.x, y + extent.y * 0.5, at.y))
			spots.append(where.scaled_local(extent))
			colours.append(layer[2])
			y += extent.y
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, trunk + 0.9, 1.0)
		shape.shape = box
		shape.position = Vector3(at.x, box.size.y * 0.5, at.y)
		body.add_child(shape)
	if not spots.is_empty():
		_add_blocks(spots, colours)


func _near_track(at: Vector2, reach: float) -> bool:
	for k in range(0, track.points.size(), 2):
		var q := track.points[k]
		if Vector2(q.x, q.z).distance_squared_to(at) < reach * reach:
			return true
	return false
