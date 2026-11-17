class_name GroundBrush
extends RefCounted

## Sculpting a course's ground map in the track editor's Ground tab: making
## a map from the hills, growing it with the course and the brush's tools.
##
## Every tool works on the map's points under the brush, fully in the middle
## and softly out to past its edge, by how long it's held: Raise and Lower
## move RATE metres a second at the middle, the rest ease a point towards
## their height at EASE a second. Smooth goes towards the average of a point
## and its neighbours, Flatten towards the height where the stroke started
## and Level to road towards the road's ground nearest each point.

const TOOLS := ["raise", "lower", "smooth", "flatten", "level"]
## The tools for lakes and rivers (see TrackEditor.water_begin()).
const WATER_TOOLS := ["lake", "river", "valley"]
const NAMES := {"raise": "Raise", "lower": "Lower", "smooth": "Smooth", "flatten": "Flatten", "level": "Level to road", "lake": "Lake", "river": "River", "valley": "Follow the valley"}
## How wide a river is, in metres, by the brush's size.
const RIVER_WIDTHS := {1: 8.0, 3: 12.0, 5: 18.0}
## How wide each brush is, in metres, by its size in squares.
const WIDTHS := {1: 8.0, 3: 24.0, 5: 40.0}
## Metres a second at the middle for Raise and Lower.
const RATE := 2.0
## How fast the other tools close in on their height, a second.
const EASE := 4.0
## Sculpting keeps within this many metres of the start.
const MOST := 60.0
## The map reaches this far past the road's box each way, like the stock
## courses' maps (dem.py).
const MARGIN := 128.0
## Road samples are looked up in squares this big for Level to road.
const BUCKET := 32.0


## A new map covering the course, with the hills it has now baked in, so
## nothing moves when it takes their place. Null if the road has no points.
static func bake(track: TrackPath) -> GroundMap:
	var area := cover(track)
	if area.is_empty():
		return null
	var map := GroundMap.blank(area[0], area[1], area[2])
	for z in map.rows:
		for x in map.cols:
			var at: Vector2 = map.origin + Vector2(x, z) * map.cell
			map.heights[z * map.cols + x] = clampf(track.ground_height(at.x, at.y), -MOST, MOST)
	return map


## Where a map for this course goes: [origin, cols, rows], on the 8 m squares,
## the road's box and MARGIN each side, no more than GroundMap.MOST_POINTS
## round the middle. Empty if the road has no points.
static func cover(track: TrackPath, cell := GroundMap.CELL) -> Array:
	if track.points.is_empty():
		return []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.points:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	lo = ((lo - Vector2.ONE * MARGIN) / cell).floor() * cell
	hi = ((hi + Vector2.ONE * MARGIN) / cell).ceil() * cell
	var cols := int(roundf((hi.x - lo.x) / cell)) + 1
	var rows := int(roundf((hi.y - lo.y) / cell)) + 1
	var side := int(sqrt(float(GroundMap.MOST_POINTS)))
	if cols * rows > GroundMap.MOST_POINTS:
		var middle := ((lo + hi) * 0.5 / cell).round() * cell
		cols = mini(cols, side)
		rows = mini(rows, GroundMap.MOST_POINTS / cols)
		lo = middle - Vector2(cols - 1, rows - 1) * 0.5 * cell
		lo = (lo / cell).round() * cell
	return [lo, cols, rows]


## The map made bigger to cover the course, its new points the height at the
## old edge (what the map gave there anyway), or null if it covers it already
## or can't grow any more.
static func grown(map: GroundMap, track: TrackPath) -> GroundMap:
	var area := cover(track, map.cell)
	if area.is_empty():
		return null
	var cell := map.cell
	# Kept on the map's own points, which may not be on the 8 m squares.
	var lo: Vector2 = map.origin + ((area[0] - map.origin) / cell).floor() * cell
	var far: Vector2 = area[0] + Vector2(area[1] - 1, area[2] - 1) * cell
	var hi: Vector2 = map.origin + ((far - map.origin) / cell).ceil() * cell
	var old_hi := map.origin + Vector2(map.cols - 1, map.rows - 1) * cell
	lo = lo.min(map.origin)
	hi = hi.max(old_hi)
	var cols := int(roundf((hi.x - lo.x) / cell)) + 1
	var rows := int(roundf((hi.y - lo.y) / cell)) + 1
	if cols == map.cols and rows == map.rows:
		return null
	if cols * rows > GroundMap.MOST_POINTS:
		return null
	var out := GroundMap.blank(lo, cols, rows, cell)
	var dx := int(roundf((map.origin.x - lo.x) / cell))
	var dz := int(roundf((map.origin.y - lo.y) / cell))
	for z in rows:
		for x in cols:
			out.heights[z * cols + x] = map.height_of(x - dx, z - dz)
	return out


## The points the brush reaches, with how strongly, as [index, weight] pairs.
static func reach(map: GroundMap, at: Vector2, size: int) -> Array:
	var radius: float = WIDTHS.get(size, 8.0) * 0.5
	var inner := radius * 0.5
	var outer := radius + map.cell * 0.75
	var out := []
	var x0 := maxi(0, floori((at.x - outer - map.origin.x) / map.cell))
	var x1 := mini(map.cols - 1, ceili((at.x + outer - map.origin.x) / map.cell))
	var z0 := maxi(0, floori((at.y - outer - map.origin.y) / map.cell))
	var z1 := mini(map.rows - 1, ceili((at.y + outer - map.origin.y) / map.cell))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var d := (map.origin + Vector2(x, z) * map.cell).distance_to(at)
			var weight := 1.0 - smoothstep(inner, outer, d)
			if weight > 0.001:
				out.append([z * map.cols + x, weight])
	return out


## Works the brush at `at` for `seconds`. `target` is the Flatten height and
## `road` a RoadLevels for Level to road. Whether anything moved.
static func work(map: GroundMap, tool: String, at: Vector2, size: int, seconds: float, target := 0.0, road: RoadLevels = null) -> bool:
	var points := reach(map, at, size)
	if points.is_empty() or seconds <= 0.0:
		return false
	var before := map.heights.duplicate() if tool == "smooth" else PackedFloat32Array()
	if tool == "level" and road != null:
		road.follow(map, at, WIDTHS.get(size, 8.0) * 0.5 + map.cell, seconds)
	var moved := false
	for point: Array in points:
		var i: int = point[0]
		var weight: float = point[1]
		var h := map.heights[i]
		var goal := h
		match tool:
			"raise":
				goal = h + RATE * seconds * weight
			"lower":
				goal = h - RATE * seconds * weight
			"smooth", "flatten", "level":
				var towards := target
				if tool == "smooth":
					towards = _average(map, before, i)
				elif tool == "level":
					if road == null:
						continue
					var x := i % map.cols
					var z := i / map.cols
					var spot := map.origin + Vector2(x, z) * map.cell
					towards = road.level_at(spot)
				goal = lerpf(h, towards, (1.0 - exp(-EASE * seconds)) * weight)
		goal = clampf(goal, -MOST, MOST)
		if absf(goal - h) > 0.0001:
			map.heights[i] = goal
			moved = true
	if moved:
		map.changed()
	return moved


static func _average(map: GroundMap, h: PackedFloat32Array, i: int) -> float:
	var x := i % map.cols
	var z := i / map.cols
	var sum := 0.0
	var count := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var nz := z + dz
			if nx >= 0 and nx < map.cols and nz >= 0 and nz < map.rows:
				sum += h[nz * map.cols + nx]
				count += 1
	return sum / count


## The road's ground nearest any point, for Level to road. Made once a stroke.
## The road follows the ground beside it a little, so while the brush levels
## the ground the road's ground round the brush is worked out again from the
## map every REFRESH seconds, in a window LOCAL metres past the brush.
class RoadLevels:
	const REFRESH := 0.1
	const LOCAL := 64.0
	var track: TrackPath
	var buckets := {}
	## Nearest road sample to each point asked about.
	var _nearest := {}
	## The road's ground worked out round the brush, and where it's good.
	var _local: GroundMap
	var _local_rect := Rect2()
	var _since := INF

	func _init(path: TrackPath) -> void:
		track = path
		for k in range(0, path.points.size(), 2):
			var p := path.points[k]
			var key := Vector2i(floori(p.x / BUCKET), floori(p.z / BUCKET))
			if not buckets.has(key):
				buckets[key] = PackedInt32Array()
			buckets[key].append(k)

	## Works out the road's ground round `at` again from the map, if it's
	## been REFRESH seconds.
	func follow(map: GroundMap, at: Vector2, radius: float, seconds: float) -> void:
		_since += seconds
		if _since < REFRESH:
			return
		_since = 0.0
		var reach := radius + LOCAL
		var x0 := maxi(0, floori((at.x - reach - map.origin.x) / map.cell))
		var x1 := mini(map.cols - 1, ceili((at.x + reach - map.origin.x) / map.cell))
		var z0 := maxi(0, floori((at.y - reach - map.origin.y) / map.cell))
		var z1 := mini(map.rows - 1, ceili((at.y + reach - map.origin.y) / map.cell))
		if x1 <= x0 or z1 <= z0:
			_local = null
			return
		var window := GroundMap.blank(map.origin + Vector2(x0, z0) * map.cell, x1 - x0 + 1, z1 - z0 + 1, map.cell)
		for z in window.rows:
			for x in window.cols:
				window.heights[z * window.cols + x] = map.heights[(z0 + z) * map.cols + x0 + x]
		_local = window.road_heights()
		# The blur reaches 32 m, so the window's edge is only good that far in.
		_local_rect = Rect2(window.origin, Vector2(window.cols - 1, window.rows - 1) * map.cell).grow(-LOCAL * 0.5)

	## The road's ground at the road sample nearest this point.
	func level_at(at: Vector2) -> float:
		var best := _nearest_to(at)
		if best < 0:
			return 0.0
		var p := track.points[best]
		if _local != null and _local_rect.has_point(Vector2(p.x, p.z)):
			# Road raised by its own piece keeps the ground it was built on.
			var climb := p.y - (track.grounds[best] if best < track.grounds.size() else p.y)
			if climb < TrackBuilder.RAISED:
				return _local.height_at(p.x, p.z)
		return track.grounds[best] if best < track.grounds.size() else p.y

	func _nearest_to(at: Vector2) -> int:
		if _nearest.has(at):
			return _nearest[at]
		var key := Vector2i(floori(at.x / BUCKET), floori(at.y / BUCKET))
		var best := -1
		var best_d := INF
		var ring := 0
		# Rings of buckets out until one has road, then one more to be sure
		# the nearest isn't just over the edge of it.
		var found_ring := -1
		while ring < 64 and (found_ring < 0 or ring <= found_ring + 1):
			for dz in range(-ring, ring + 1):
				for dx in range(-ring, ring + 1):
					if maxi(absi(dx), absi(dz)) != ring:
						continue
					for k: int in buckets.get(key + Vector2i(dx, dz), PackedInt32Array()):
						var p := track.points[k]
						var d := Vector2(p.x, p.z).distance_squared_to(at)
						if d < best_d:
							best_d = d
							best = k
			if best >= 0 and found_ring < 0:
				found_ring = ring
			ring += 1
		_nearest[at] = best
		return best
