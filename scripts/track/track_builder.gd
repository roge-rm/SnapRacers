class_name TrackBuilder
extends Node3D

## Builds the track you drive on from a TrackPath.
##
## Each piece becomes one static body: its road, kerbs and the deck under
## them, plus a low brick wall down any side that has one. It's all swept
## along the line down the middle, so hills and banking come for free. Raised
## road gets pillars down to the ground, cut bends get a dirt patch inside,
## and there's a gantry over the start line.

const DECK := 0.6 # how thick the road is
const WALL_HEIGHT := 1.0
const WALL_THICKNESS := 0.5
const LIFT := 0.02 # keeps ground-level road just above the grass
const PILLAR_EVERY := 16.0
const PILLAR_SIZE := 1.4

const COLOURS := {
	"asphalt": Color("#51545b"),
	"dirt": Color("#8a6a45"),
	"grass": Color("#3d7a32"),
	"sand": Color("#d9c38c"),
	"ice": Color("#cfe8f2"),
}
const KERB_RED := Color("#d8261c")
const KERB_WHITE := Color("#f2f2f2")
const DECK_COLOUR := Color("#7a7f87")

const GRASS_SHADER := """
shader_type spatial;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world.xz / 4.0);
	float check = mod(cell.x + cell.y, 2.0);
	vec3 grass = mix(vec3(0.24, 0.52, 0.2), vec3(0.21, 0.47, 0.18), check);
	// The colours are picked as sRGB, but ALBEDO wants linear.
	ALBEDO = pow(grass, vec3(2.2));
	ROUGHNESS = 0.9;
}
"""

const ROAD_SHADER := """
shader_type spatial;

void fragment() {
	// Vertex colours are picked as sRGB, but ALBEDO wants linear.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
}
"""

var track: TrackPath
var _material: ShaderMaterial

# Each shader is made once and kept for as long as the game runs. The phone
# compiles a shader the first time it's drawn, and a new Shader object counts
# as new even with the same code, so building them fresh for every race made
# every race stall on its first frame.
static var _road_shader: Shader
static var _grass_shader: Shader


static func shader_for(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func _init(path: TrackPath) -> void:
	track = path


func _ready() -> void:
	# A plain standard material lit the flat road with so much sky on the
	# phone that the asphalt came out pale blue, so the road has a shader of
	# its own like the grass.
	if _road_shader == null:
		_road_shader = shader_for(ROAD_SHADER)
		_grass_shader = shader_for(GRASS_SHADER)
	_material = ShaderMaterial.new()
	_material.shader = _road_shader
	SkyAndSun.add_to(self, 80.0)
	_add_grass()
	for i in track.pieces.size():
		_add_piece(i)
	_add_pillars()
	_add_gantry()


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
	var material := ShaderMaterial.new()
	material.shader = _grass_shader
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)


## The outline of the road across, as edges to sweep along the track. Each
## edge is [from, to, colour name], in (right, up) metres, and faces out to
## the left of the way it runs.
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
		edges.append([Vector2(kerb, WALL_HEIGHT), Vector2(wall, WALL_HEIGHT), "wall"])
		edges.append([Vector2(wall, WALL_HEIGHT), Vector2(wall, -DECK), "wall"])
	else:
		edges.append([Vector2(kerb, 0.0), Vector2(kerb, -DECK), "deck"])
	if piece.wall_left:
		edges.append([Vector2(-kerb, WALL_HEIGHT), Vector2(-kerb, 0.0), "wall"])
		edges.append([Vector2(-wall, WALL_HEIGHT), Vector2(-kerb, WALL_HEIGHT), "wall"])
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
	# Run on into the next piece's first sample so there's no seam.
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
				"wall":
					colour = Color("#c4281c") if stripe else KERB_WHITE
				_:
					colour = DECK_COLOUR
			_sweep(tool, a, b, edge[0], edge[1], colour)
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
func _sweep(tool: SurfaceTool, a: int, b: int, from: Vector2, to: Vector2, colour: Color) -> void:
	var out := Vector2(-(to.y - from.y), to.x - from.x).normalized()
	var normal_a := track.rights[a] * out.x + track.ups[a] * out.y
	var normal_b := track.rights[b] * out.x + track.ups[b] * out.y
	var af := _at(a, from)
	var at := _at(a, to)
	var bf := _at(b, from)
	var bt := _at(b, to)
	tool.set_color(colour)
	for v in [[af, normal_a], [bt, normal_b], [at, normal_a], [af, normal_a], [bf, normal_b], [bt, normal_b]]:
		tool.set_normal(v[1])
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
	var order := [0, 1, 2, 0, 2, 3] if facing > 0.0 else [0, 2, 1, 0, 3, 2]
	for i in order:
		tool.add_vertex(points[i])


## The dirt patch inside a cut bend: a quarter circle from the corner of the
## bend out to the inside kerb.
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
	look.material_override = _material
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
		if track.distances[k] < next or not track.solids[k]:
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
		var where := Transform3D(Basis.looking_at(Vector3(track.forwards[k].x, 0.0, track.forwards[k].z).normalized(), Vector3.UP), Vector3(p.x, bottom * 0.5, p.z))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(PILLAR_SIZE, bottom, PILLAR_SIZE)
		shape.shape = box
		shape.transform = where
		body.add_child(shape)
		spots.append(where.scaled_local(Vector3(PILLAR_SIZE, bottom, PILLAR_SIZE)))
	if spots.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BoxMesh.new()
	multi.instance_count = spots.size()
	for i in spots.size():
		multi.set_instance_transform(i, spots[i])
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.material_override = PartVisuals.material(Color("#a3a2a4"))
	add_child(draw)


## An arch of bricks over the start line.
func _add_gantry() -> void:
	var frame := track.frame_at(0.0)
	var reach := track.width * 0.5 + TrackPath.KERB + WALL_THICKNESS + 1.0
	var height := 5.0
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	body.transform = frame
	add_child(body)
	var blocks := [
		[Vector3(-reach, height * 0.5, 0.0), Vector3(1.0, height, 1.0), Color("#c4281c")],
		[Vector3(reach, height * 0.5, 0.0), Vector3(1.0, height, 1.0), Color("#c4281c")],
		[Vector3(0.0, height + 0.5, 0.0), Vector3(reach * 2.0 + 1.0, 1.0, 1.0), Color("#f2cd37")],
	]
	for block in blocks:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = block[1]
		shape.shape = box
		shape.position = block[0]
		body.add_child(shape)
		var look := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = block[1]
		look.mesh = box_mesh
		look.position = block[0]
		look.material_override = PartVisuals.material(block[2])
		body.add_child(look)
	var line := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(track.width, 1.2)
	line.mesh = quad
	line.position = Vector3(0.0, LIFT + 0.01, 0.0)
	line.material_override = PartVisuals.material(Color("#f2f2f2"))
	body.add_child(line)
