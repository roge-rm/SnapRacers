class_name BrickShapes
extends RefCounted

## Meshes for the parts that aren't plain boxes, like slopes, curves, nose
## cones, wedge plates, mudguards, fairings, windscreens and wings, in the
## shapes real bricks come in.
##
## Every shape is made facing forward (its sloped or rounded end toward -Z),
## centred on its own origin and filling its box `extent`, and the part is
## turned afterwards. Most of them are a side view pushed out across the width.
## Each one is made once for each size and then shared.

## How tall the little upright lip at the bottom of a slope is.
const LIP := 0.035

static var _cache: Dictionary = {}


## The mesh for a shape, or null for a plain box.
static func mesh(shape: String, extent: Vector3) -> Mesh:
	var key := "%s %s" % [shape, extent]
	if _cache.has(key):
		return _cache[key]
	var made: Mesh = null
	var h := extent * 0.5
	match shape:
		"slope", "slope_long":
			# A flat row one stud deep at the back, with its studs, then the
			# slope down to a small lip at the front.
			made = extrude(PackedVector2Array([
				Vector2(-h.z, -h.y), Vector2(h.z, -h.y), Vector2(h.z, h.y),
				Vector2(h.z - Grid.STUD, h.y), Vector2(-h.z, -h.y + LIP)]), extent.x)
		"slope_inverted":
			made = extrude(PackedVector2Array([
				Vector2(-h.z, h.y - LIP), Vector2(-h.z, h.y), Vector2(h.z, h.y),
				Vector2(h.z, -h.y), Vector2(h.z - Grid.STUD, -h.y)]), extent.x)
		"curve":
			var points := PackedVector2Array([Vector2(h.z, -h.y), Vector2(h.z, h.y)])
			var steps := 12
			for i in range(steps, -1, -1):
				var t := float(i) / steps
				points.append(Vector2(lerpf(-h.z, h.z, t), -h.y + LIP + (extent.y - LIP) * sin(t * PI * 0.5)))
			points.append(Vector2(-h.z, -h.y))
			made = extrude(points, extent.x, true)
		"arch":
			# A thin band over the top, like a mudguard.
			var points := PackedVector2Array()
			var steps := 14
			var thick := 0.05
			for i in steps + 1:
				var a := PI * float(i) / steps
				points.append(Vector2(-cos(a) * h.z, -h.y + sin(a) * extent.y))
			for i in range(steps, -1, -1):
				var a := PI * float(i) / steps
				points.append(Vector2(-cos(a) * (h.z - thick), -h.y + sin(a) * (extent.y - thick)))
			made = extrude(points, extent.x, true)
		"fairing":
			# Seen from the side, round at the front and tapering to the back.
			var points := PackedVector2Array()
			var steps := 16
			var front := minf(h.y, h.z)
			for i in steps + 1:
				var a := PI * 0.5 + PI * float(i) / steps
				points.append(Vector2(-h.z + front + cos(a) * front, sin(-a) * h.y))
			points.append(Vector2(h.z, h.y * 0.6))
			points.append(Vector2(h.z, -h.y * 0.6))
			made = extrude(points, extent.x, true)
		"screen":
			# A thin pane leaning back from the front edge.
			var t := 0.035
			made = extrude(PackedVector2Array([
				Vector2(-h.z, -h.y), Vector2(-h.z + t * 2.0, -h.y),
				Vector2(h.z, h.y), Vector2(h.z - t * 2.0, h.y)]), extent.x)
		"wedge_left", "wedge_right":
			made = _wedge(extent, shape == "wedge_right")
		"nose":
			made = _nose(extent)
		"wing_front":
			made = _wing(extent, 0.0)
		"wing_tall":
			made = _wing(extent, extent.y - 0.08)
		"round":
			var round := CylinderMesh.new()
			round.top_radius = minf(h.x, h.z)
			round.bottom_radius = round.top_radius
			round.height = extent.y
			round.radial_segments = 20
			made = round
	if made != null:
		# Whichever way around the faces above were written, make them all
		# face out.
		var tool := SurfaceTool.new()
		tool.create_from(made, 0)
		tool.index()
		made = tool.commit()
		MeshKit.fix_winding(made)
	_cache[key] = made
	return made


## Pushes a side view (points as (z, y), going around either way) out across
## the width, with flat ends. Smooth shading suits curved shapes.
static func extrude(profile: PackedVector2Array, width: float, smooth := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	# Going around anticlockwise, seen from +X, keeps the outside out.
	var area := 0.0
	for i in n:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		profile.reverse()
	var x := width * 0.5
	var edge := func(i: int) -> Vector3:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		var along := b - a
		return Vector3(0.0, -along.x, along.y).normalized()
	for i in n:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		var normal_a: Vector3 = edge.call(i)
		var normal_b: Vector3 = normal_a
		if smooth:
			# Share the normal with the neighbouring edge where the turn is
			# gentle, so curves look round but corners stay sharp.
			var before: Vector3 = edge.call((i - 1 + n) % n)
			var after: Vector3 = edge.call((i + 1) % n)
			if before.dot(normal_a) > 0.7:
				normal_a = (before + normal_a).normalized()
			if after.dot(normal_b) > 0.7:
				normal_b = (after + normal_b).normalized()
		var corners := [Vector3(-x, a.y, a.x), Vector3(x, a.y, a.x), Vector3(x, b.y, b.x), Vector3(-x, b.y, b.x)]
		var normals := [normal_a, normal_a, normal_b, normal_b]
		for k in [0, 2, 1, 0, 3, 2]:
			tool.set_normal(normals[k])
			tool.add_vertex(corners[k])
	# The flat ends.
	var triangles := Geometry2D.triangulate_polygon(profile)
	for side in [-1.0, 1.0]:
		for t in range(0, triangles.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for k in order:
				var p := profile[triangles[t + k]]
				tool.set_normal(Vector3(side, 0.0, 0.0))
				tool.add_vertex(Vector3(x * side, p.y, p.x))
	return tool.commit()


## Which studs a shape has on top, as (x, z) stud cells counted from the
## front left corner, for a part that's `cells` studs across and long. Plain
## boxes have all of them.
static func studs(shape: String, cells: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in cells.x:
		for z in cells.y:
			var keep := true
			match shape:
				"slope", "slope_long":
					keep = z == cells.y - 1
				"curve", "arch", "fairing", "screen", "nose", "wing_front", "wing_tall", "tile":
					keep = false
				"wedge_left", "wedge_right":
					var middle := Vector2(x + 0.5, z + 0.5) * Grid.STUD - Vector2(cells) * Grid.STUD * 0.5
					keep = Geometry2D.is_point_in_polygon(middle, _wedge_outline(Vector2(cells) * Grid.STUD, shape == "wedge_right"))
			if keep:
				out.append(Vector2i(x, z))
	return out


## A wedge plate seen from above, as (x, z) points. The left one has its
## right side straight and its left side cut away toward a point at the front
## right. The right one is its mirror image.
static func _wedge_outline(size: Vector2, right: bool) -> PackedVector2Array:
	var w := size.x * 0.5
	var l := size.y * 0.5
	var points := PackedVector2Array([
		Vector2(-w, l), Vector2(w, l), Vector2(w, -l), Vector2(w - Grid.STUD, -l), Vector2(-w, l - Grid.STUD * 2.0)])
	if right:
		for i in points.size():
			points[i].x = -points[i].x
		points.reverse()
	return points


static func _wedge(extent: Vector3, right: bool) -> ArrayMesh:
	var outline := _wedge_outline(Vector2(extent.x, extent.z), right)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := extent.y * 0.5
	var n := outline.size()
	if Geometry2D.is_polygon_clockwise(outline):
		outline.reverse()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var along := (b - a).normalized()
		var normal := Vector3(along.y, 0.0, -along.x)
		var corners := [Vector3(a.x, -h, a.y), Vector3(b.x, -h, b.y), Vector3(b.x, h, b.y), Vector3(a.x, h, a.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(normal)
			tool.add_vertex(corners[k])
	var triangles := Geometry2D.triangulate_polygon(outline)
	for up in [1.0, -1.0]:
		for t in range(0, triangles.size(), 3):
			var order := [0, 2, 1] if up > 0.0 else [0, 1, 2]
			for k in order:
				var p := outline[triangles[t + k]]
				tool.set_normal(Vector3(0.0, up, 0.0))
				tool.add_vertex(Vector3(p.x, h * up, p.y))
	return tool.commit()


## A nose cone, a rounded tunnel across the back half closing to a rounded
## point at the front, flat underneath.
static func _nose(extent: Vector3) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rx := extent.x * 0.5
	var ry := extent.y
	var rz := extent.z * 0.5
	var base := -extent.y * 0.5
	var around := 16
	var forward := 10
	var point := func(theta: float, phi: float) -> Vector3:
		return Vector3(cos(theta) * cos(phi) * rx, base + sin(theta) * cos(phi) * ry, -sin(phi) * rz)
	var normal := func(theta: float, phi: float) -> Vector3:
		return Vector3(cos(theta) * cos(phi) / rx, sin(theta) * cos(phi) / ry, -sin(phi) / rz).normalized()
	var quad := func(p: Array, nrm: Array) -> void:
		for k in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(nrm[k])
			tool.add_vertex(p[k])
	for i in around:
		var t0 := PI * float(i) / around
		var t1 := PI * float(i + 1) / around
		# The dome at the front.
		for j in forward:
			var f0 := PI * 0.5 * float(j) / forward
			var f1 := PI * 0.5 * float(j + 1) / forward
			quad.call([point.call(t0, f0), point.call(t0, f1), point.call(t1, f1), point.call(t1, f0)],
				[normal.call(t0, f0), normal.call(t0, f1), normal.call(t1, f1), normal.call(t1, f0)])
		# The tunnel across the back.
		var a: Vector3 = point.call(t0, 0.0)
		var b: Vector3 = point.call(t1, 0.0)
		var back := Vector3(0.0, 0.0, rz)
		var na: Vector3 = normal.call(t0, 0.0)
		var nb: Vector3 = normal.call(t1, 0.0)
		quad.call([a + back, a, b, b + back], [na, na, nb, nb])
		# The back end, as a fan from the middle of its bottom edge.
		for k in [Vector3(0.0, base, rz), b + back, a + back]:
			tool.set_normal(Vector3.BACK)
			tool.add_vertex(k)
	# The flat bottom.
	var bottom := PackedVector2Array()
	for j in forward + 1:
		var f := PI * 0.5 * float(j) / forward
		bottom.append(Vector2(cos(f) * rx, -sin(f) * rz))
	for j in range(forward, -1, -1):
		var f := PI * 0.5 * float(j) / forward
		bottom.append(Vector2(-cos(f) * rx, -sin(f) * rz))
	bottom.append(Vector2(-rx, rz))
	bottom.append(Vector2(rx, rz))
	var triangles := Geometry2D.triangulate_polygon(bottom)
	for t in range(0, triangles.size(), 3):
		for k in [0, 1, 2]:
			var p := bottom[triangles[t + k]]
			tool.set_normal(Vector3.DOWN)
			tool.add_vertex(Vector3(p.x, base, p.y))
	return tool.commit()


## A wing, an aerofoil across the full width with an end plate at each side.
## `lift` raises it up on two stilts from the bottom of its box.
static func _wing(extent: Vector3, lift: float) -> ArrayMesh:
	var h := extent * 0.5
	var foil := PackedVector2Array()
	var steps := 10
	var thick := 0.05
	var bottom := -h.y + lift
	for i in steps + 1:
		var t := float(i) / steps
		foil.append(Vector2(lerpf(-h.z, h.z, t), bottom + thick * 0.5 + sin(t * PI) * thick * 0.6 + t * 0.03))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		foil.append(Vector2(lerpf(-h.z, h.z, t), bottom + sin(t * PI) * thick * 0.2 + t * 0.03))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(extrude(foil, extent.x - 0.04, true), 0, Transform3D.IDENTITY)
	for side in [-1.0, 1.0]:
		var plate := Vector3(0.02, minf(extent.y, 0.12), extent.z)
		var middle := clampf(bottom + 0.04, -h.y + plate.y * 0.5, h.y - plate.y * 0.5)
		tool.append_from(_box(plate), 0, Transform3D(Basis.IDENTITY, Vector3(side * (h.x - 0.01), middle, 0.0)))
		if lift > 0.0:
			tool.append_from(_box(Vector3(0.04, lift, 0.06)), 0, Transform3D(Basis.IDENTITY, Vector3(side * h.x * 0.45, -h.y + lift * 0.5, 0.0)))
	return tool.commit()


## A plain box, made the same way as the shapes so they can be put together.
static func _box(size: Vector3) -> ArrayMesh:
	var h := size * 0.5
	return extrude(PackedVector2Array([Vector2(-h.z, -h.y), Vector2(h.z, -h.y), Vector2(h.z, h.y), Vector2(-h.z, h.y)]), size.x)
