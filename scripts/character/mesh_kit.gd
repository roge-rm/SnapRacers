class_name MeshKit
extends RefCounted

## Shapes for character models that Godot's primitives don't cover, like boxes
## with rounded edges (which can be narrower at the top, for a torso), tubes
## bent around an arc, one piece arms and C shaped hands. Each one is made once
## for each set of numbers and then shared.

static var _cache: Dictionary = {}


## A box with rounded edges and corners, rounded to `radius`. `taper` narrows the
## top face to that fraction of the bottom's width, like a brick figure torso.
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
	fix_winding(mesh)
	_cache[key] = mesh
	return mesh


static func _ease(x: float) -> float:
	return signf(x) * (1.0 - pow(1.0 - absf(x), 1.6))


## Flips any triangle whose winding points it inward, so the rounded box
## shows from outside whichever way the face loops above happened to run.
static func fix_winding(mesh: ArrayMesh) -> void:
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


## A brick figure arm as one piece, from a rounded shoulder at `top` straight down
## to the elbow at `elbow`, around a smooth bend and along `dir` to a flat end
## at `end`, all in the arm's own space. It's a tube with a rounded square
## cross section, and only the stretch from `from` to `to` metres along it is
## made, so an arm printed in two colours is two meshes that meet exactly.
## arm_length is how long the whole arm is and arm_elbow how far along the
## middle of the bend is.
static func arm(top: Vector3, elbow: Vector3, end: Vector3, from := 0.0, to := INF) -> ArrayMesh:
	var key := "arm %s %s %s %s %s" % [top, elbow, end, from, to]
	if _cache.has(key):
		return _cache[key]
	var path := _arm_path(top, elbow, end)
	var points: PackedVector3Array = path[0]
	var along: PackedFloat32Array = path[1]
	var length: float = along[along.size() - 1]
	to = minf(to, length)
	# The frame around the tube, carried along the path without twisting.
	var tangents: Array[Vector3] = []
	for i in points.size():
		var ahead := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		tangents.append(ahead.normalized())
	var sideways: Array[Vector3] = [Vector3.RIGHT]
	for i in range(1, points.size()):
		var turn := Quaternion(tangents[i - 1], tangents[i]) if tangents[i - 1].dot(tangents[i]) < 0.99999 else Quaternion.IDENTITY
		sideways.append((turn * sideways[i - 1]).normalized())
	# The rings to make, from `from` to `to`.
	var picks: Array[float] = [from]
	for i in points.size():
		if along[i] > from + 0.0005 and along[i] < to - 0.0005:
			picks.append(along[i])
	picks.append(to)
	var section := _arm_section()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for at in picks:
		var i := along.bsearch(at)
		i = clampi(i, 1, points.size() - 1)
		var t := clampf((at - along[i - 1]) / maxf(along[i] - along[i - 1], 0.00001), 0.0, 1.0)
		var centre := points[i - 1].lerp(points[i], t)
		var forward := tangents[i - 1].slerp(tangents[i], t).normalized()
		var u := sideways[i - 1].slerp(sideways[i], t)
		u = (u - forward * u.dot(forward)).normalized()
		var v := forward.cross(u)
		# The shoulder end is rounded over like a dome, and the wrist end a
		# little, before its flat end.
		var scale := 1.0
		var tilt := 0.0
		if at < ARM_DOME:
			tilt = 1.0 - at / ARM_DOME
			scale = sqrt(maxf(1.0 - tilt * tilt, 0.0))
			tilt = -tilt
		var ring := []
		for corner in section:
			var flat: Vector2 = corner[0]
			var out: Vector2 = corner[1]
			var normal := (u * out.x + v * out.y) * scale + forward * tilt
			ring.append([centre + (u * flat.x + v * flat.y) * scale, normal.normalized()])
		rings.append(ring)
	var sides := section.size()
	for i in rings.size() - 1:
		for k in sides:
			var a: Array = rings[i][k]
			var b: Array = rings[i + 1][k]
			var c: Array = rings[i + 1][(k + 1) % sides]
			var d: Array = rings[i][(k + 1) % sides]
			for vertex in [a, b, c, a, c, d]:
				tool.set_normal(vertex[1])
				tool.add_vertex(vertex[0])
	# The flat end at the wrist.
	if to >= length - 0.0005:
		var last: Array = rings[rings.size() - 1]
		var middle := Vector3.ZERO
		for vertex in last:
			middle += vertex[0]
		middle /= sides
		var out_end := tangents[tangents.size() - 1]
		for k in sides:
			for vertex in [[middle, out_end], [last[k][0], out_end], [last[(k + 1) % sides][0], out_end]]:
				tool.set_normal(vertex[1])
				tool.add_vertex(vertex[0])
	tool.index()
	var mesh := tool.commit()
	fix_winding(mesh)
	_cache[key] = mesh
	return mesh


## How far along the arm the rounded shoulder goes.
const ARM_DOME := 0.04
## How far before and after the elbow the bend starts and ends.
const ARM_BEND := 0.04


static func arm_length(top: Vector3, elbow: Vector3, end: Vector3) -> float:
	var along: PackedFloat32Array = _arm_path(top, elbow, end)[1]
	return along[along.size() - 1]


static func arm_elbow(top: Vector3, elbow: Vector3, _end: Vector3) -> float:
	return top.distance_to(elbow) - ARM_BEND * 0.3


## The points down the middle of an arm, and how far along each one is.
static func _arm_path(top: Vector3, elbow: Vector3, end: Vector3) -> Array:
	var down := (elbow - top).normalized()
	var out := (end - elbow).normalized()
	var bend_from := elbow - down * ARM_BEND
	var bend_to := elbow + out * ARM_BEND
	var points := PackedVector3Array()
	var dome_steps := 6
	for i in dome_steps:
		points.append(top.lerp(top + down * ARM_DOME, float(i) / dome_steps))
	for i in 4:
		points.append((top + down * ARM_DOME).lerp(bend_from, float(i) / 4.0))
	for i in 11:
		var t := float(i) / 10.0
		# A curve from the start of the bend to its end, pulled toward the
		# elbow, so the arm bends smoothly.
		points.append(bend_from.lerp(elbow, t).lerp(elbow.lerp(bend_to, t), t))
	for i in range(1, 5):
		points.append(bend_to.lerp(end, float(i) / 4.0))
	var along := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		along.append(along[i - 1] + points[i].distance_to(points[i - 1]))
	return [points, along]


## Around a rounded square, as [point, outward direction] pairs.
static func _arm_section() -> Array:
	var half := Vector2(0.042, 0.044)
	var r := 0.034
	var out := []
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for q in 4:
		var c: Vector2 = corners[q]
		var middle := (half - Vector2(r, r)) * c
		for k in 5:
			var angle := (q + k / 4.0) * PI * 0.5
			var dir := Vector2(cos(angle), sin(angle))
			out.append([middle + dir * r, dir])
	return out


## A round tube bent along an arc in the XY plane, from `from` to `to`
## radians (0 is +X, going around toward +Y).
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


## A shape turned on a lathe. `profile` is (distance out, height) points from
## bottom to top, spun around the Y axis. Only the part of the turn from
## `from` to `to` (radians, 0 at -Z, going around toward +X) is made, which is
## how an open face helmet leaves room for the face. Normals come from the
## profile, so the result is smooth. Texture coordinates run around it with
## the front (-Z) in the middle of the texture, and from top to bottom, which
## is how a face gets printed on a head.
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
	fix_winding(mesh)
	_cache[key] = mesh
	return mesh


## A cylinder with its top and bottom edges rounded over, like a brick figure
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


## A brick figure hand, a thick C shape with flat faces front and back, softly
## rounded edges and a gap to grip through. The hole runs along Z, and the ring
## goes around from `from` to `to` in the XY plane like arc_tube(), so the gap
## is centred on -Y.
static func hand(size := 0.05, from := deg_to_rad(-50.0), to := deg_to_rad(230.0)) -> ArrayMesh:
	var key := "hand %s %s %s" % [size, from, to]
	if _cache.has(key):
		return _cache[key]
	var outer := size
	var inner := size * 0.45
	var half := size * 0.48
	var bevel := size * 0.14
	# The cross section, as (distance from the middle, z) with its normal,
	# going around a rectangle with rounded corners.
	var section: Array = []
	var corners := [
		[Vector2(outer - bevel, half - bevel), 0.0],
		[Vector2(inner + bevel, half - bevel), PI * 0.5],
		[Vector2(inner + bevel, -half + bevel), PI],
		[Vector2(outer - bevel, -half + bevel), PI * 1.5],
	]
	for corner in corners:
		for i in 4:
			var a: float = corner[1] + PI * 0.5 * i / 3.0
			var n := Vector2(cos(a), sin(a))
			section.append([corner[0] + n * bevel, n])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 18
	var ring := func(angle: float, point: Vector2) -> Vector3:
		return Vector3(cos(angle) * point.x, sin(angle) * point.x, point.y)
	for i in steps:
		var a0 := lerpf(from, to, float(i) / steps)
		var a1 := lerpf(from, to, float(i + 1) / steps)
		for k in section.size():
			var p: Array = section[k]
			var q: Array = section[(k + 1) % section.size()]
			var corners3 := [ring.call(a0, p[0]), ring.call(a1, p[0]), ring.call(a1, q[0]), ring.call(a0, q[0])]
			var normals := [ring.call(a0, p[1]).normalized(), ring.call(a1, p[1]).normalized(), ring.call(a1, q[1]).normalized(), ring.call(a0, q[1]).normalized()]
			for v in [0, 1, 2, 0, 2, 3]:
				tool.set_normal(normals[v])
				tool.add_vertex(corners3[v])
	# Flat ends where the gap is.
	var outline := PackedVector2Array(section.map(func(p): return p[0]))
	var triangles := Geometry2D.triangulate_polygon(outline)
	for end in [[from, -1.0], [to, 1.0]]:
		var angle: float = end[0]
		var along: Vector3 = Vector3(-sin(angle), cos(angle), 0.0) * float(end[1])
		for t in range(0, triangles.size(), 3):
			for v in 3:
				tool.set_normal(along)
				tool.add_vertex(ring.call(angle, outline[triangles[t + v]]))
	tool.index()
	var mesh := tool.commit()
	fix_winding(mesh)
	_cache[key] = mesh
	return mesh
