class_name MeshKit
extends RefCounted

## Shapes for character models that primitives don't cover: boxes with
## rounded edges (optionally narrower at the top, for a torso), tubes bent
## round an arc (a mouth, a visor band), and C-shaped hands. They're all made
## once for each set of numbers and shared.

static var _cache: Dictionary = {}


## A box with rounded edges and corners, `radius` round. `taper` narrows the
## top face to that fraction of the bottom's width, like a minifig torso.
static func rounded_box(size: Vector3, radius: float, taper := 1.0, steps := 5) -> ArrayMesh:
	var key := "box %s %s %s %s" % [size, radius, taper, steps]
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3.ONE * r
	# Build it as a subdivided cube pushed out onto the rounded box, face by
	# face, so every face has plenty of vertices for smooth corners.
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	var n := steps * 2
	for face in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var grid := []
		for i in n + 1:
			var row := []
			for j in n + 1:
				var p: Vector3 = normal + u * (float(i) / n * 2.0 - 1.0) + v * (float(j) / n * 2.0 - 1.0)
				# Spread the vertices so they bunch at the rounded edges.
				p = Vector3(_ease(p.x), _ease(p.y), _ease(p.z))
				var point := p * half
				var core := point.clamp(-inner, inner)
				var out := point - core
				var dir := out.normalized() if out.length() > 0.0001 else normal
				var surface := core + dir * r
				var shrink := lerpf(1.0, taper, (surface.y + half.y) / size.y)
				surface.x *= shrink
				row.append([surface, dir])
			grid.append(row)
		for i in n:
			for j in n:
				var a: Array = grid[i][j]
				var b: Array = grid[i + 1][j]
				var c: Array = grid[i + 1][j + 1]
				var d: Array = grid[i][j + 1]
				for vertex in [a, b, c, a, c, d]:
					tool.set_normal(vertex[1])
					tool.add_vertex(vertex[0])
	tool.index()
	var mesh := tool.commit()
	_fix_winding(mesh)
	_cache[key] = mesh
	return mesh


static func _ease(x: float) -> float:
	return signf(x) * (1.0 - pow(1.0 - absf(x), 1.6))


## Flips any triangle whose winding points it inward, so the rounded box
## shows from outside whichever way the face loops above happened to run.
static func _fix_winding(mesh: ArrayMesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		var facing := (b - a).cross(c - a)
		var outward := normals[indices[t]] + normals[indices[t + 1]] + normals[indices[t + 2]]
		# Godot treats clockwise as the front, which here means the cross
		# product points inward.
		if facing.dot(outward) > 0.0:
			var swap := indices[t + 1]
			indices[t + 1] = indices[t + 2]
			indices[t + 2] = swap
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## A round tube bent along an arc in the XY plane, from `from` to `to`
## radians (0 is +X, going round toward +Y).
static func arc_tube(radius: float, thickness: float, from: float, to: float, steps := 16, sides := 8) -> ArrayMesh:
	var key := "arc %s %s %s %s" % [radius, thickness, from, to]
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for i in steps + 1:
		var angle := lerpf(from, to, float(i) / steps)
		var centre := Vector3(cos(angle), sin(angle), 0.0) * radius
		var out := Vector3(cos(angle), sin(angle), 0.0)
		var ring := []
		for k in sides:
			var around := float(k) / sides * TAU
			var normal := out * cos(around) + Vector3.BACK * sin(around)
			ring.append([centre + normal * thickness, normal])
		rings.append(ring)
	for i in steps:
		for k in sides:
			var a: Array = rings[i][k]
			var b: Array = rings[i + 1][k]
			var c: Array = rings[i + 1][(k + 1) % sides]
			var d: Array = rings[i][(k + 1) % sides]
			for vertex in [a, c, b, a, d, c]:
				tool.set_normal(vertex[1])
				tool.add_vertex(vertex[0])
	# Round caps on the ends.
	for end in [0, steps]:
		var ring: Array = rings[end]
		var angle := lerpf(from, to, float(end) / steps)
		var centre := Vector3(cos(angle), sin(angle), 0.0) * radius
		var along := Vector3(-sin(angle), cos(angle), 0.0) * (1.0 if end == steps else -1.0)
		for k in sides:
			var a: Array = ring[k]
			var b: Array = ring[(k + 1) % sides]
			var tip := centre + along * thickness * 0.6
			for vertex in ([[tip, along], a, b] if end == steps else [[tip, along], b, a]):
				tool.set_normal(vertex[1])
				tool.add_vertex(vertex[0])
	var mesh := tool.commit()
	_cache[key] = mesh
	return mesh


## A shape turned on a lathe: `profile` is (distance out, height) points from
## bottom to top, spun round the Y axis. Only the part of the turn from `from`
## to `to` (radians, 0 at -Z, going round toward +X) is made, which is how an
## open-face helmet leaves room for the face. Normals come from the profile,
## so the result is smooth. Texture coordinates run round it with the front
## (-Z) in the middle of the texture, and from top to bottom, which is how a
## face gets printed on a head.
static func lathe(profile: PackedVector2Array, sides := 32, from := 0.0, to := TAU) -> ArrayMesh:
	var key := "lathe %s %s %s %s" % [profile, sides, from, to]
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	# Profile normals, from the neighbouring points.
	var normals := PackedVector2Array()
	for i in n:
		var before := profile[maxi(i - 1, 0)]
		var after := profile[mini(i + 1, n - 1)]
		var along := (after - before).normalized()
		normals.append(Vector2(along.y, -along.x))
	var low := profile[0].y
	var high := profile[0].y
	for p in profile:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var closed := is_equal_approx(to - from, TAU)
	var steps := sides if closed else maxi(2, int(sides * (to - from) / TAU))
	for k in steps:
		var a0 := from + (to - from) * k / steps
		var a1 := from + (to - from) * (k + 1) / steps
		for i in n - 1:
			var quad := []
			for corner in [[i, a0], [i + 1, a0], [i + 1, a1], [i, a1]]:
				var p := profile[corner[0]]
				var nn := normals[corner[0]]
				var ang: float = corner[1]
				var dir := Vector3(sin(ang), 0.0, -cos(ang))
				var uv := Vector2((ang + PI) / TAU, 1.0 - (p.y - low) / maxf(high - low, 0.0001))
				quad.append([dir * p.x + Vector3.UP * p.y, (dir * nn.x + Vector3.UP * nn.y).normalized(), uv])
			for vertex in [quad[0], quad[2], quad[1], quad[0], quad[3], quad[2]]:
				tool.set_normal(vertex[1])
				tool.set_uv(vertex[2])
				tool.add_vertex(vertex[0])
	tool.index()
	var mesh := tool.commit()
	_fix_winding(mesh)
	_cache[key] = mesh
	return mesh


## A cylinder with its top and bottom edges rounded over, like a minifig
## head or a stud. Its middle is at the origin.
static func rounded_cylinder(radius: float, height: float, round := 0.02, sides := 32) -> ArrayMesh:
	var profile := PackedVector2Array()
	var h := height * 0.5
	profile.append(Vector2(0.0, -h))
	for i in 7:
		var a := PI * 0.5 * (1.0 - i / 6.0)
		profile.append(Vector2(radius - round + cos(a) * round, -h + round - sin(a) * round))
	for i in 7:
		var a := PI * 0.5 * i / 6.0
		profile.append(Vector2(radius - round + cos(a) * round, h - round + sin(a) * round))
	profile.append(Vector2(0.0, h))
	return lathe(profile, sides)


## A minifig hand: a thick C shape, open toward -Y, sized to grip a rim.
static func hand(size := 0.05) -> ArrayMesh:
	return arc_tube(size, size * 0.45, deg_to_rad(-40.0), deg_to_rad(220.0), 14, 8)
