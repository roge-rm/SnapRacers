class_name TrackBuilder
extends Node3D

## Builds the track you drive on from a TrackPath.
##
## Each piece becomes one static body with its road and the deck under it.
## It's all swept along the line down the middle, so hills and banking come
## for free. Like a real kart track, the road has white lines down its edges
## and runs out onto the grass, with bumpy kerbs on the corners (see Kerbs).
## Only where you'd fall off (raised road, loops, wall rides and banked bends)
## is there a shoulder and a low brick wall. Raised road gets pillars down to
## the ground, cut bends get a dirt patch inside, and there's a gantry over
## the start line.
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
## How wide the white lines down the road's edges are.
const LINE := 0.35
const LINE_COLOUR := Color("#f2f2f2")
## Road higher than this above the ground gets walls, so you can't drive off
## the edge of it.
const RAISED := 0.5
## Kerbs: how tight a corner has to be to get them (one over its radius), how
## high their ridged top is, how long each red or white block is, and how
## short a run of kerb is worth putting down.
const KERB_BEND := 1.0 / 150.0
const KERB_HEIGHT := 0.1
const KERB_BLOCK := 1.2
const KERB_SHORTEST := 6
## Kerbs get less grip than the road, besides the bumping (see Kart).
const KERB_GRIP := 0.9

const COLOURS := {
	"asphalt": Color("#6c6e68"), # dark bluish grey, like the bricks
	"dirt": Color("#8a6a45"),
	"grass": Color("#3d7a32"),
	"sand": Color("#d9c38c"),
	"ice": Color("#cfe8f2"),
}
const DECK_COLOUR := Color("#7a7f87")

const PILLAR_COLOUR := Color("#a3a2a4")
## Which surface each edge of the outline is, for the shader.
const KIND := {"road": 0.0, "kerb": 1.0, "deck": 2.0, "wall": 3.0, "walltop": 4.0, "line": 5.0}

var track: TrackPath
## How much scenery to put around it: "all", "landmarks" (only the ones put
## down by hand, which the track editor uses to stay quick) or "none".
var scenery := "all"
## Whether it brings its own sky and sun. The track editor has its own.
var sky := true
var _material: ShaderMaterial
## The rolling ground, on a course with hills.
var terrain: Terrain
## The course's theme (see Scenery.THEMES), which sets the colours.
var _theme: Dictionary

# Each shader is made once and kept for as long as the game runs. The phone
# compiles a shader the first time it's drawn, and a new Shader object counts
# as new even with the same code, so building them fresh for every race made
# every race stall on its first frame.
static var _road_shader: Shader
static var _grass_shader: Shader
static var _shared_material: ShaderMaterial


static func shader_for(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func _init(path: TrackPath) -> void:
	track = path


func _prepare() -> void:
	# A plain standard material lit the flat road with so much sky on the
	# phone that the asphalt came out pale blue, so the road has its own
	# shader like the grass.
	if _road_shader == null:
		_road_shader = shader_for(BrickShaders.TRACK)
		_grass_shader = shader_for(BrickShaders.BASEPLATE)
	_material = road_material()
	_theme = Scenery.theme_named(track.theme)


## The road's material. Every piece of road shares it.
static func road_material() -> ShaderMaterial:
	if _shared_material == null:
		if _road_shader == null:
			_road_shader = shader_for(BrickShaders.TRACK)
			_grass_shader = shader_for(BrickShaders.BASEPLATE)
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = _road_shader
	return _shared_material


## One piece of road on its own, in its own space, as it would be built into
## a course of this width and theme. The track editor keeps these, so it can
## lay a course out again instantly after every change.
static func piece_mesh(spec: Dictionary, width: float, theme_id: String) -> ArrayMesh:
	var one := TrackPath.from_dict({"theme": theme_id, "width": width, "pieces": [spec]})
	var builder := TrackBuilder.new(one)
	builder._prepare()
	var mesh := builder._piece_mesh(0)
	builder.free()
	return mesh


func _ready() -> void:
	_prepare()
	if sky:
		SkyAndSun.add_to(self, 80.0, Color.TRANSPARENT, _theme.get("sky", []))
	_add_grass()
	for i in track.pieces.size():
		_add_piece(i)
	_add_kerbs()
	_add_pillars()
	_add_gantry()
	# A debug switch for checking the frame rate on a device. If there's a
	# file called noscenery in the app's data folder, the scenery is left out.
	if OS.is_debug_build() and FileAccess.file_exists("user://noscenery"):
		return
	if scenery == "none":
		return
	var dressing := Scenery.new(track, track.theme)
	dressing.ground = ground_at
	dressing.only_landmarks = scenery == "landmarks"
	# Keep the dirt inside cut bends clear, since you drive across it.
	for i in track.pieces.size():
		var piece := track.pieces[i]
		if piece.cut:
			dressing.keep_clear.append([track.piece_starts[i] * Vector3(piece.turn * piece.radius, 0.0, 0.0), piece.radius])
	add_child(dressing)


## How high the ground is here: the hills on a hilly course, and 0 on a flat
## one.
func ground_at(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain != null else 0.0


func _add_grass() -> void:
	if track.hills > 0.0:
		terrain = Terrain.new(track, Scenery.REACH + 45.0)
		add_child(terrain)
		return
	var bounds := AABB(track.points[0], Vector3.ZERO)
	for p in track.points:
		bounds = bounds.expand(p)
	# Wide enough for the scenery and the big landmarks around the outside.
	bounds = bounds.grow(Scenery.REACH + 45.0)
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
	mesh.material_override = _baseplate(Color(_theme.get("ground", "#4b9f4a")))
	body.add_child(mesh)
	add_child(body)


func _baseplate(colour: Color) -> ShaderMaterial:
	return baseplate(colour)


## The studded green baseplate the courses sit on, in a colour.
static func baseplate(colour: Color) -> ShaderMaterial:
	road_material()
	var material := ShaderMaterial.new()
	material.shader = _grass_shader
	material.set_shader_parameter("colour", colour)
	return material


## The outline of the road across, as edges to sweep along the track. Each
## edge is [from, to, surface], in (right, up) metres, and faces out to the
## left of the way it runs. A side with a wall has a shoulder of road out to
## it. A side without one stops at the road's edge, which sits level with the
## grass, so there's nothing to catch on running off it.
func _profile(left_wall: bool, right_wall: bool) -> Array:
	var half := track.width * 0.5
	var right := half + TrackPath.KERB if right_wall else half
	var left := half + TrackPath.KERB if left_wall else half
	var edges := [
		[Vector2(-half, 0.0), Vector2(-half + LINE, 0.0), "line"],
		[Vector2(-half + LINE, 0.0), Vector2(half - LINE, 0.0), "road"],
		[Vector2(half - LINE, 0.0), Vector2(half, 0.0), "line"],
		[Vector2(right, -DECK), Vector2(-left, -DECK), "deck"],
	]
	if right_wall:
		var wall := right + WALL_THICKNESS
		edges.append([Vector2(half, 0.0), Vector2(right, 0.0), "road"])
		edges.append([Vector2(right, 0.0), Vector2(right, WALL_HEIGHT), "wall"])
		edges.append([Vector2(right, WALL_HEIGHT), Vector2(wall, WALL_HEIGHT), "walltop"])
		edges.append([Vector2(wall, WALL_HEIGHT), Vector2(wall, -DECK), "wall"])
	else:
		edges.append([Vector2(right, 0.0), Vector2(right, -DECK), "deck"])
	if left_wall:
		var wall := left + WALL_THICKNESS
		edges.append([Vector2(-left, 0.0), Vector2(-half, 0.0), "road"])
		edges.append([Vector2(-left, WALL_HEIGHT), Vector2(-left, 0.0), "wall"])
		edges.append([Vector2(-wall, WALL_HEIGHT), Vector2(-left, WALL_HEIGHT), "walltop"])
		edges.append([Vector2(-wall, -DECK), Vector2(-wall, WALL_HEIGHT), "wall"])
	else:
		edges.append([Vector2(-left, -DECK), Vector2(-left, 0.0), "deck"])
	return edges


## Whether the road at this sample is somewhere you could fall off: up in the
## air, on a loop or wall ride, or leaning on a banked bend.
func _raised(k: int) -> bool:
	return track.points[k].y - track.grounds[k] > RAISED or track.stickies[k] or track.ups[k].y < 0.985


## Which sides of a piece have walls between these two samples.
func _walls(piece: TrackPiece, a: int, b: int) -> Array:
	var wanted := piece.forced_walls() or _raised(a) or _raised(b)
	return [piece.wall_left and wanted, piece.wall_right and wanted]


func _add_piece(index: int) -> void:
	var piece := track.pieces[index]
	var mesh := _piece_mesh(index)
	if mesh == null:
		return
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	var feel: Array = track.grip_and_drag(piece.surface)
	body.set_meta("grip", feel[0])
	body.set_meta("drag", feel[1])
	body.set_meta("sticky", piece.sticky)
	# Which piece it is, so the track editor can tell which one was tapped.
	body.set_meta("piece", index)
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


## The road, curbs, deck and walls of one piece, swept along the line down
## its middle.
func _piece_mesh(index: int) -> ArrayMesh:
	var piece := track.pieces[index]
	var samples: Array[int] = []
	for k in track.points.size():
		if track.piece_of[k] == index:
			samples.append(k)
	if samples.is_empty():
		return null
	# Run on into the next piece's first sample so there's no seam. The last
	# piece of a track that doesn't come back around to the start has nothing
	# to run on into (joining it to the start drew road right across the map).
	var last_piece := index == track.pieces.size() - 1
	if not last_piece or track.closes:
		samples.append((samples[-1] + 1) % track.points.size())

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surface_colour: Color = COLOURS.get(piece.surface, COLOURS["asphalt"])
	var had := [false, false]
	for n in samples.size() - 1:
		var a := samples[n]
		var b := samples[n + 1]
		if not track.solids[a] or not track.solids[b]:
			had = [false, false]
			continue
		var walls := _walls(piece, a, b)
		# Close off the end of a wall where it starts or stops.
		for side in 2:
			if walls[side] != had[side]:
				_wall_end(tool, a, side == 1, -1.0 if walls[side] else 1.0)
		had = walls
		for edge in _profile(walls[0], walls[1]):
			var colour: Color
			match edge[2]:
				"road":
					colour = surface_colour
				"line":
					colour = LINE_COLOUR
				"wall", "walltop":
					colour = Color(_theme.wall)
				_:
					colour = DECK_COLOUR
			_sweep(tool, a, b, edge[0], edge[1], colour, KIND[edge[2]])
		# Close off the road where it stops for the jump's gap.
		var before := samples[n - 1] if n > 0 else (a - 1 + track.points.size()) % track.points.size()
		if not track.solids[before]:
			_cap(tool, a, -1.0)
		if n + 2 < samples.size() and not track.solids[samples[n + 2]]:
			_cap(tool, b, 1.0)
	return tool.commit()


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


## The end of a wall where it starts or stops, facing along the track (1)
## or back (-1).
func _wall_end(tool: SurfaceTool, k: int, right: bool, facing: float) -> void:
	var inner := track.width * 0.5 + TrackPath.KERB
	var outer := inner + WALL_THICKNESS
	var s := 1.0 if right else -1.0
	var corners := [Vector2(s * inner, -DECK), Vector2(s * outer, -DECK), Vector2(s * outer, WALL_HEIGHT), Vector2(s * inner, WALL_HEIGHT)]
	var points := corners.map(func(c): return _at(k, c))
	var normal: Vector3 = track.forwards[k] * facing
	tool.set_color(Color(_theme.wall))
	tool.set_normal(normal)
	tool.set_uv2(Vector2(KIND["wall"], 0.0))
	var clockwise := (facing > 0.0) == right
	var order := [0, 1, 2, 0, 2, 3] if clockwise else [0, 2, 1, 0, 3, 2]
	for i in order:
		tool.set_uv(Vector2(corners[i].x, corners[i].y))
		tool.add_vertex(points[i])


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
	# In rings, so on a hilly course it can follow the ground.
	var rings := 6
	var lift := LIFT * 0.6
	var spot := func(ring: int, step: int) -> Vector3:
		var a := float(step) / steps * PI * 0.5
		var r := reach * float(ring) / rings
		var v: Vector3 = start * Vector3(piece.turn * (piece.radius - r * cos(a)), 0.0, -r * sin(a))
		v.y = ground_at(v.x, v.z) + lift if terrain != null else v.y + lift
		return v
	for ring in rings:
		for i in steps:
			var quad := [spot.call(ring, i), spot.call(ring + 1, i), spot.call(ring + 1, i + 1), spot.call(ring, i + 1)]
			var tris := [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]
			if piece.turn < 0:
				tris = [quad[0], quad[2], quad[1], quad[0], quad[3], quad[2]]
			for v in tris:
				tool.add_vertex(v)
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


## The red and white kerbs on the corners, like a real kart track has: one on
## the inside of each corner around its middle, and one on the outside where
## it comes out. They're low with ridged tops, so you can drive over them, but
## at speed the ridges bounce the wheels into the air (see Kart), which is why
## you'd rather keep off them.
##
## The corners are found from the line down the middle rather than from the
## pieces, so a slant's kinks get them and so does any course built in the
## editor. Road with walls gets none, and nor does the inside of a cut bend.
func _add_kerbs() -> void:
	var count := track.points.size()
	if count < 8:
		return
	# Which way the road's turning at each sample: 1 right, -1 left, 0 not
	# enough to count.
	var turning := PackedInt32Array()
	turning.resize(count)
	for k in count:
		var before := track.forwards[(k - 3 + count) % count]
		var after := track.forwards[(k + 3) % count]
		var up := track.ups[k]
		var angle := before.signed_angle_to(after, up)
		var rate := absf(angle) / (6.0 * TrackPath.SAMPLE)
		turning[k] = 0 if rate < KERB_BEND else (1 if angle < 0.0 else -1)
	# Each run of the same turning is a corner. It's walked from a sample that
	# isn't turning, so no corner is split across the start.
	var first := -1
	for k in count:
		if turning[k] == 0:
			first = k
			break
	if first < 0:
		return
	var inside: Array = []
	var outside: Array = []
	var k := 0
	while k < count:
		var i := (first + k) % count
		if turning[i] == 0:
			k += 1
			continue
		var run: Array[int] = []
		while k < count and turning[(first + k) % count] == turning[i]:
			run.append((first + k) % count)
			k += 1
		var n := run.size()
		# The inside around the middle half, and the outside from two thirds of
		# the way round to a little past the end.
		inside.append([run.slice(n / 4, n - n / 4), turning[i]])
		var out_run := run.slice(n * 2 / 3)
		for extra in mini(n / 4, 8):
			out_run.append((run[n - 1] + extra + 1) % count)
		outside.append([out_run, -turning[i]])
	for kerb in inside + outside:
		_kerb_run(kerb[0], kerb[1])


## One run of kerb down one side (1 right, -1 left), where the road allows.
func _kerb_run(samples: Array, side: int) -> void:
	var usable: Array[int] = []
	for k in samples:
		var piece := track.pieces[track.piece_of[k]]
		var blocked: bool = not track.solids[k] or _raised(k) or piece.forced_walls() \
			or (piece.cut and side == piece.turn)
		if not blocked:
			usable.append(k)
	# Split where it's blocked, and drop bits too short to bother with.
	var pieces_of_run: Array = [[]]
	for n in usable.size():
		if n > 0 and usable[n] != (usable[n - 1] + 1) % track.points.size():
			pieces_of_run.append([])
		pieces_of_run[-1].append(usable[n])
	for run in pieces_of_run:
		if run.size() >= KERB_SHORTEST:
			_add_kerb(run, side)


func _add_kerb(run: Array, side: int) -> void:
	var half := track.width * 0.5
	var inner := half * side
	var outer := (half + TrackPath.KERB) * side
	var ramp := (half + 0.3) * side
	var top := (half + TrackPath.KERB - 0.2) * side
	# Across the kerb: up a little ramp from the road, the ridged top, and down
	# to the grass. Listed so each edge faces up and out.
	var across := [
		[Vector2(inner, 0.0), Vector2(ramp, KERB_HEIGHT)],
		[Vector2(ramp, KERB_HEIGHT), Vector2(top, KERB_HEIGHT)],
		[Vector2(top, KERB_HEIGHT), Vector2(outer, 0.0)],
	]
	if side < 0:
		across = across.map(func(e): return [e[1], e[0]])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in run.size() - 1:
		var a: int = run[n]
		var b: int = run[n + 1]
		var red := int(track.distances[a] / KERB_BLOCK) % 2 == 0
		var colour := Color(_theme.curbs[0] if red else _theme.curbs[1])
		for edge in across:
			_sweep(tool, a, b, edge[0], edge[1], colour, KIND["kerb"])
	var mesh := tool.commit()
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	body.set_meta("grip", KERB_GRIP)
	body.set_meta("drag", 1.0)
	body.set_meta("kerb", true)
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
		# Nothing goes under loops and wall rides, because the road isn't lying
		# flat there.
		if track.distances[k] < next or not track.solids[k] or track.ups[k].y < 0.9:
			continue
		var p := track.points[k]
		var ground := ground_at(p.x, p.z)
		var bottom := p.y - DECK - ground
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
		var where := Transform3D(Basis.IDENTITY, Vector3(snappedf(p.x, 0.25), ground + bottom * 0.5, snappedf(p.z, 0.25)))
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
	var kit := SceneryKit.new()
	for i in spots.size():
		kit.boxes.append([spots[i], colours[i], SceneryKit.BRICK])
	kit.build(self)


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
		[Vector3(-reach, height * 0.5, 0.0), Vector3(1.0, height, 1.0), Color(_theme.wall)],
		[Vector3(reach, height * 0.5, 0.0), Vector3(1.0, height, 1.0), Color(_theme.wall)],
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
