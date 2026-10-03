class_name BuildMath
extends RefCounted

## The garage's math, kept apart from anything on screen so it can be tested
## on its own. It works out where a ray from the camera lands on the kart or
## the floor, and where a new part goes for that spot. Everything here is in
## grid units (studs across, plates up, studs along).

## How far nearest_cell looks for somewhere better, in studs either way and
## plates up.
const SLIDE_STEPS := 2
const STACK_STEPS := 12

static var _offsets: Array[Vector3i] = []


class Hit:
	var t := INF
	var point := Vector3.ZERO
	var normal := Vector3i.ZERO # the face it went in through
	var part := -1 # which part was hit, or -1 for the floor

	func is_hit() -> bool:
		return t < INF


## Where a ray first goes into a box, as [distance, face normal], or an empty
## array if it misses. A ray that starts inside the box doesn't count.
static func ray_box(origin: Vector3, dir: Vector3, box: AABB) -> Array:
	var t_in := -INF
	var t_out := INF
	var axis := -1
	var face := 0
	for k in 3:
		if absf(dir[k]) < 1e-9:
			if origin[k] < box.position[k] or origin[k] > box.end[k]:
				return []
			continue
		var t1 := (box.position[k] - origin[k]) / dir[k]
		var t2 := (box.end[k] - origin[k]) / dir[k]
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		if t1 > t_in:
			t_in = t1
			axis = k
			face = -1 if dir[k] > 0.0 else 1
		t_out = minf(t_out, t2)
	if axis == -1 or t_out < t_in or t_in < 0.0:
		return []
	var normal := Vector3i.ZERO
	normal[axis] = face
	return [t_in, normal]


## The first thing a ray from the camera hits, which is either a part or the
## floor of the build area.
static func cast(design: KartDesign, origin: Vector3, dir: Vector3) -> Hit:
	var hit := Hit.new()
	for i in design.parts.size():
		var result := ray_box(origin, dir, design.box_of(i))
		if not result.is_empty() and result[0] < hit.t:
			hit.t = result[0]
			hit.normal = result[1]
			hit.part = i
	if dir.y < 0.0 and origin.y > 0.0:
		var t := -origin.y / dir.y
		var p := origin + dir * t
		var size := KartDesign.BUILD_SIZE
		if t < hit.t and p.x >= 0.0 and p.z >= 0.0 and p.x <= size.x and p.z <= size.z:
			hit.t = t
			hit.normal = Vector3i(0, 1, 0)
			hit.part = -1
	if hit.is_hit():
		hit.point = origin + dir * hit.t
	return hit


## Where a part of this size goes when it's put down on this spot. On top of
## something it sits on it, under something it hangs from it, and against a
## side it butts up against it. It's centred on the spot each time.
static func placement(hit: Hit, size: Vector3i) -> Vector3i:
	var p := hit.point
	var at := Vector3i(
		floori(p.x - size.x * 0.5 + 0.5),
		floori(p.y - size.y * 0.5 + 0.5),
		floori(p.z - size.z * 0.5 + 0.5))
	var n := hit.normal
	if n.y > 0:
		at.y = roundi(p.y)
	elif n.y < 0:
		at.y = roundi(p.y) - size.y
	elif n.x > 0:
		at.x = roundi(p.x)
	elif n.x < 0:
		at.x = roundi(p.x) - size.x
	elif n.z > 0:
		at.z = roundi(p.z)
	elif n.z < 0:
		at.z = roundi(p.z) - size.z
	var room := KartDesign.BUILD_SIZE - size
	return Vector3i(clampi(at.x, 0, room.x), clampi(at.y, 0, room.y), clampi(at.z, 0, room.z))


## The nearest spot to `at` where the part fits and is held on, or `at` itself
## if there's nowhere close. Fingers are big and studs are small, so being off
## by a stud or two shouldn't stop a part from going down. It tries sliding a
## little first, then stacking higher.
static func nearest_spot(design: KartDesign, id: String, at: Vector3i, rot: int) -> Vector3i:
	return nearest_cell(design, id, at, Grid.yaw(rot))


## The same for a part turned by `basis`, any way up. `known` remembers
## which cells work, so a finger dragging it along only has to try the new
## ones. Pass the same one only while the kart, the part and how it's turned
## stay the same.
static func nearest_cell(design: KartDesign, id: String, at: Vector3i, basis: Basis, known := {}) -> Vector3i:
	var near: KartDesign = null
	for offset in _nearest_first():
		var spot := at + offset
		if not known.has(spot):
			if near == null:
				# Only the parts somewhere near can be in the way or hold it on.
				var first := KartDesign.box_place(id, basis, at)
				var area := _spread(KartDesign.fine_box(id, first)).merge(_spread(first * Connectors.bounds(id)).grow(Connectors.NEAR + 0.01))
				near = design.only_near(area.grow(0.1))
				# With nothing near, nothing holds it on anywhere here.
				if near.parts.is_empty() and not design.parts.is_empty():
					return at
			var place := KartDesign.box_place(id, basis, spot)
			known[spot] = near.fits_place(id, place) and near.attaches_place(id, place)
		if known[spot]:
			return spot
	return at


## A box grown to cover everywhere nearest_cell might move it to.
static func _spread(box: AABB) -> AABB:
	var low := Vector3(-SLIDE_STEPS, 0, -SLIDE_STEPS) * Grid.UNIT_FINE
	var high := Vector3(SLIDE_STEPS, STACK_STEPS, SLIDE_STEPS) * Grid.UNIT_FINE
	return AABB(box.position + low, box.size + high - low)


## The steps nearest_cell tries, cheapest first: sliding costs one a stud
## and stacking one and a half a plate. Ties go lowest first, then by x and
## then by z.
static func _nearest_first() -> Array[Vector3i]:
	if not _offsets.is_empty():
		return _offsets
	var costed := []
	for dy in range(0, STACK_STEPS + 1):
		for dx in range(-SLIDE_STEPS, SLIDE_STEPS + 1):
			for dz in range(-SLIDE_STEPS, SLIDE_STEPS + 1):
				costed.append([dy * 1.5 + absi(dx) + absi(dz), costed.size(), Vector3i(dx, dy, dz)])
	costed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for c in costed:
		_offsets.append(c[2])
	return _offsets
