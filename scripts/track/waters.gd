class_name Waters
extends RefCounted

## Lakes and rivers of water or lava, put where the ground decides.
##
## A lake fills the hollow round its seed `at` up to `level`: all the ground
## under the level joined to the seed, so its shore is the ground's contour
## there and its surface is flat. Nothing is dug for it. A river is a drawn
## line of points, each with a width. It carves a channel with sloping banks,
## and its surface runs downhill from its first point to its last, never up,
## a little under the banks. A river that runs into a lake ends at its level.
## Neither reaches road on the ground: they keep half its width, the kerb and
## PaintedAreas.ROAD_ROOM away, and may go under raised road.
##
## Course file: "water": [{"kind": "lake", "type": "water", "at": [x, z],
## "level": y}, {"kind": "river", "type": "lava", "points": [[x, z, w], ...]}].
## Old painted water or lava on a course with no ground map becomes one lake
## of each type that keeps the squares as "cells", runs of [z, x0, count]
## (see PaintedAreas), and is built like painted ground.
##
## settle() works it all out on a grid of Terrain.CELL points, the terrain's
## own when there is one. Lookups read that grid, a few points per call.

const TYPES := ["water", "lava"]
const KINDS := ["lake", "river"]
## The most lakes and rivers on one course, and points on one river.
const MOST_BODIES := 24
const MOST_POINTS := 160
const MIN_WIDTH := 6.0
const MAX_WIDTH := 30.0
## Levels and heights keep within this many metres of the start.
const HIGHEST := 200.0
## The furthest a lake's seed or a river's point can be, in metres.
const FURTHEST := PaintedAreas.MOST_SPAN * PaintedAreas.CELL
const CELL := 4.0
## How far round the road the grid reaches without a terrain, as Terrain's
## does (Scenery.REACH + 45).
const REACH := 125.0
## A river's surface sits this far under its lower bank.
const UNDER := 0.5
## How far apart a river's surface heights are worked out along it.
const STEP := 3.0
## How far out past a river's edge its banks are measured.
const BANK_OUT := 2.0
## How steeply the banks rise past the water's edge, metres up per metre out.
const BANK_SLOPE := 0.6
## Where a river drops more than this per metre it has white rapids.
const RAPIDS := 0.035
## The most grid points one lake can cover, 640,000 square metres.
const MOST_LAKE := 40000
## Water this shallow you can drive through.
## How steep the bank round an old painted pool is dug, rise over run, and
## how far out from the pool it can go, in metres.
const BANK_DUG := 0.35
const DIG_BANK := 48.0
const SHALLOW := 0.3

## Each lake or river as read from the course file, with "at" a Vector2 and
## "points" a PackedVector3Array of (x, z, width).
var bodies: Array = []

## Worked out by settle().
var settled := false
var origin := Vector2.ZERO
var cols := 0
var rows := 0
## The ground before and after the rivers carve it.
var base := PackedFloat32Array()
var heights := PackedFloat32Array()
## Points near road on the ground, 1, where no water goes.
var blocked := PackedByteArray()
## Which body each point is wet by, its index plus one, and the surface there.
var wet := PackedInt32Array()
var tops := PackedFloat32Array()
## Each lake's level once it's kept clear of the road, NAN for a river.
var levels := PackedFloat32Array()
## Each river's line, every STEP metres: "at" (x, z), "top", "width", "steep"
## (metres down per metre) and "dry" (1 where the road's in the way).
var lines: Array = []
## The type of the body the last level_at() found, "" for none.
var kind := ""


func is_empty() -> bool:
	return bodies.is_empty()


## Whether any lake or river goes by the ground (not old squares).
func has_real() -> bool:
	for body: Dictionary in bodies:
		if not body.has("cells"):
			return true
	return false


func duplicate_waters() -> Waters:
	return from_dict(to_dict())


static func make_lake(type: String, at: Vector2, level: float) -> Dictionary:
	return {"kind": "lake", "type": type, "at": at, "level": level}


static func make_river(type: String, points: PackedVector3Array) -> Dictionary:
	return {"kind": "river", "type": type, "points": points}


# The course file.

func to_dict() -> Array:
	var out := []
	for body: Dictionary in bodies:
		var entry := {"kind": body.kind, "type": body.type}
		if body.kind == "lake":
			entry.at = [snappedf(body.at.x, 0.01), snappedf(body.at.y, 0.01)]
			entry.level = snappedf(body.level, 0.01)
			if body.has("cells"):
				entry.cells = _runs(body.cells)
		else:
			var points := []
			for p: Vector3 in body.points:
				points.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
			entry.points = points
		out.append(entry)
	return out


## Reads a "water" entry, for a course whose tiles were `grow` times smaller
## than now. Entries that aren't well formed are dropped.
static func from_dict(data: Variant, grow := 1.0) -> Waters:
	var waters := Waters.new()
	if not data is Array or not is_finite(grow) or grow <= 0.0:
		return waters
	for entry in data:
		if waters.bodies.size() >= MOST_BODIES:
			break
		if not entry is Dictionary or not entry.get("kind") in KINDS or not entry.get("type") in TYPES:
			continue
		if entry.kind == "lake":
			var at: Variant = _pair(entry.get("at"))
			if at == null or not _number(entry.get("level")) or absf(float(entry.level)) > HIGHEST:
				continue
			var body := make_lake(entry.type, at * grow, float(entry.level))
			if entry.has("cells"):
				var cells := _cells(entry.cells, grow)
				if cells.is_empty():
					continue
				body.cells = cells
			waters.bodies.append(body)
		else:
			if not entry.get("points") is Array or entry.points.size() < 2 or entry.points.size() > MOST_POINTS:
				continue
			var points := PackedVector3Array()
			for p in entry.points:
				if not p is Array or p.size() != 3 or not _number(p[0]) or not _number(p[1]) or not _number(p[2]):
					points.clear()
					break
				var w := clampf(float(p[2]) * grow, MIN_WIDTH, MAX_WIDTH)
				var spot := Vector2(float(p[0]), float(p[1])) * grow
				if absf(spot.x) > FURTHEST or absf(spot.y) > FURTHEST:
					points.clear()
					break
				points.append(Vector3(spot.x, spot.y, w))
			if points.size() >= 2:
				waters.bodies.append(make_river(entry.type, points))
	return waters


## Whether a "water" entry is well formed and inside the limits, for shared
## courses (see Sharing).
static func valid(data: Variant) -> bool:
	if not data is Array or data.size() > MOST_BODIES:
		return false
	var squares := 0
	for entry in data:
		if not entry is Dictionary or not entry.get("kind") in KINDS or not entry.get("type") in TYPES:
			return false
		if entry.kind == "lake":
			if _pair(entry.get("at")) == null or not _number(entry.get("level")) or absf(float(entry.level)) > HIGHEST:
				return false
			if entry.has("cells"):
				if not entry.cells is Array:
					return false
				for run in entry.cells:
					if not run is Array or run.size() != 3 or not _number(run[0]) or not _number(run[1]) or not _number(run[2]):
						return false
					if absf(float(run[0])) > PaintedAreas.MOST_SPAN or absf(float(run[1])) > PaintedAreas.MOST_SPAN or float(run[2]) < 1.0 or float(run[2]) > PaintedAreas.MOST_SPAN:
						return false
					squares += int(run[2])
					if squares > PaintedAreas.MOST_SQUARES:
						return false
		else:
			if not entry.get("points") is Array or entry.points.size() < 2 or entry.points.size() > MOST_POINTS:
				return false
			for p in entry.points:
				if not p is Array or p.size() != 3 or not _number(p[0]) or not _number(p[1]) or not _number(p[2]):
					return false
				if absf(float(p[0])) > FURTHEST or absf(float(p[1])) > FURTHEST or float(p[2]) < MIN_WIDTH - 0.01 or float(p[2]) > MAX_WIDTH + 0.01:
					return false
	return true


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _pair(value: Variant) -> Variant:
	if not value is Array or value.size() != 2 or not _number(value[0]) or not _number(value[1]):
		return null
	var at := Vector2(float(value[0]), float(value[1]))
	if absf(at.x) > FURTHEST or absf(at.y) > FURTHEST:
		return null
	return at


static func _runs(cells: Dictionary) -> Array:
	var paint := PaintedAreas.new()
	for square: Vector2i in cells:
		paint.squares[square] = "water"
	var runs := []
	for run: Array in paint.to_dict().runs:
		runs.append([run[0], run[1], run[2]])
	return runs


static func _cells(runs: Variant, grow: float) -> Dictionary:
	if not runs is Array:
		return {}
	var paint_runs := []
	for run in runs:
		if run is Array and run.size() == 3:
			paint_runs.append([run[0], run[1], run[2], "water"])
	var paint := PaintedAreas.from_dict({"cell": PaintedAreas.CELL, "runs": paint_runs}, grow)
	var out := {}
	for square: Vector2i in paint.squares:
		out[square] = true
	return out


## Old lakes' squares as painted ground of their type, built and looked up
## like painted ground.
func old_squares() -> PaintedAreas:
	var paint := PaintedAreas.new()
	for body: Dictionary in bodies:
		if body.has("cells"):
			for square: Vector2i in body.cells:
				paint.squares[square] = body.type
	return paint


## The same moved through `flip` (x, z -> x, z), for a mirrored layout.
func flip_all(flip: Callable) -> void:
	for body: Dictionary in bodies:
		if body.has("cells"):
			continue
		if body.kind == "lake":
			body.at = flip.call(body.at.x, body.at.y)
		else:
			var points := PackedVector3Array()
			for p: Vector3 in body.points:
				var to: Vector2 = flip.call(p.x, p.y)
				points.append(Vector3(to.x, to.y, p.z))
			body.points = points
	settled = false


# Old painted water and lava.

## A course file's lakes and rivers, with any painted water and lava taken
## out of `paint` and made into lakes (see from_paint()).
static func read_course(data: Dictionary, paint: PaintedAreas, map: GroundMap) -> Waters:
	var waters := from_dict(data.get("water"), TrackPath.growth(data))
	if paint.has_deep():
		var ground := func(x: float, z: float) -> float: return map.height_at(x, z) if map != null else 0.0
		var old := from_paint(paint, map, ground)
		for body: Dictionary in old.bodies:
			if waters.bodies.size() < MOST_BODIES:
				waters.bodies.append(body)
	return waters


## Takes the water and lava squares out of `paint` and makes a lake of each
## pool at its PaintedAreas.surface_levels() level, seeded at its lowest
## square. With a ground map the pool's hollow is dug into the map, so the
## lake fills it. With none the lake keeps its squares (see old_squares()).
static func from_paint(paint: PaintedAreas, map: GroundMap, ground: Callable) -> Waters:
	var waters := Waters.new()
	for type: String in TYPES:
		var pool := PaintedAreas.new()
		for square: Vector2i in paint.squares:
			if paint.squares[square] == type:
				pool.squares[square] = type
		if pool.is_empty():
			continue
		for square: Vector2i in pool.squares:
			paint.squares.erase(square)
		# With no map one lake of each type keeps all its squares.
		if map == null:
			var cells := {}
			for square: Vector2i in pool.squares:
				cells[square] = true
			var first: Vector2i = pool.squares.keys()[0]
			var lake := make_lake(type, PaintedAreas.middle_of(first), 0.0)
			lake.cells = cells
			waters.bodies.append(lake)
			continue
		var levels := pool.surface_levels(ground)
		# Each pool on its own: squares that touch, corners too.
		var seen := {}
		for first: Vector2i in pool.squares:
			if seen.has(first):
				continue
			var group: Array[Vector2i] = [first]
			seen[first] = true
			var n := 0
			while n < group.size():
				var square := group[n]
				n += 1
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var next := square + Vector2i(dx, dz)
						if pool.squares.has(next) and not seen.has(next):
							seen[next] = true
							group.append(next)
			var level: float = levels[first]
			if waters.bodies.size() >= MOST_BODIES:
				break
			var own := PaintedAreas.new()
			for square in group:
				own.squares[square] = type
			_dig(map, own, level)
			var seed := group[0]
			var lowest := INF
			for square in group:
				var middle := PaintedAreas.middle_of(square)
				var h := map.height_at(middle.x, middle.y)
				if h < lowest:
					lowest = h
					seed = square
			waters.bodies.append(make_lake(type, PaintedAreas.middle_of(seed), level))
	if map != null:
		map.changed()
	return waters


## Lowers the map under a painted pool: to its level where the field's at
## PaintedAreas.DEEP, deeper towards the middle.
static func _dig(map: GroundMap, pool: PaintedAreas, level: float) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for square: Vector2i in pool.squares:
		lo = lo.min(Vector2(square) * PaintedAreas.CELL)
		hi = hi.max(Vector2(square + Vector2i.ONE) * PaintedAreas.CELL)
	lo -= Vector2.ONE * PaintedAreas.BLUR
	hi += Vector2.ONE * PaintedAreas.BLUR
	for z in range(maxi(0, ceili((lo.y - map.origin.y) / map.cell)), mini(map.rows - 1, floori((hi.y - map.origin.y) / map.cell)) + 1):
		var at_z := map.origin.y + z * map.cell
		for x in range(maxi(0, ceili((lo.x - map.origin.x) / map.cell)), mini(map.cols - 1, floori((hi.x - map.origin.x) / map.cell)) + 1):
			var at_x := map.origin.x + x * map.cell
			var field := pool.deep_field_at(at_x, at_z)
			if field <= PaintedAreas.EDGE:
				continue
			var i := z * map.cols + x
			map.heights[i] = minf(map.heights[i], level + (PaintedAreas.DEEP - field) * 3.0)
	# Then the banks round it are eased down to no steeper than BANK_DUG, so
	# a pool cut into a slope gets a sloped bank, not a wall.
	var x0 := maxi(0, floori((lo.x - DIG_BANK - map.origin.x) / map.cell))
	var x1 := mini(map.cols - 1, ceili((hi.x + DIG_BANK - map.origin.x) / map.cell))
	var z0 := maxi(0, floori((lo.y - DIG_BANK - map.origin.y) / map.cell))
	var z1 := mini(map.rows - 1, ceili((hi.y + DIG_BANK - map.origin.y) / map.cell))
	var rise := map.cell * BANK_DUG
	for n in ceili(DIG_BANK / map.cell):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var i := z * map.cols + x
				var low := map.heights[i]
				if x > 0:
					low = minf(low, map.heights[i - 1] + rise)
				if x < map.cols - 1:
					low = minf(low, map.heights[i + 1] + rise)
				if z > 0:
					low = minf(low, map.heights[i - map.cols] + rise)
				if z < map.rows - 1:
					low = minf(low, map.heights[i + map.cols] + rise)
				map.heights[i] = low


# Working it out.

## Works the lakes and rivers out on a grid of CELL points for a track
## without its terrain: the track's ground, as far round as Terrain reaches.
func settle_on(track: TrackPath) -> void:
	# On a course with no map or hills there's no hollow to fill.
	if not track.has_relief() or not has_real():
		settled = true
		cols = 0
		rows = 0
		return
	settle_with(track, track.ground_height)


## The same on the ground `ground` gives, (x, z) -> height.
func settle_with(track: TrackPath, ground_of: Callable) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.points:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	if lo.x == INF:
		return
	var reach := REACH
	var at := lo - Vector2.ONE * reach
	var c := int((hi.x - lo.x + reach * 2.0) / CELL) + 2
	var r := int((hi.y - lo.y + reach * 2.0) / CELL) + 2
	var ground := PackedFloat32Array()
	ground.resize(c * r)
	for z in r:
		for x in c:
			var spot := at + Vector2(x, z) * CELL
			ground[z * c + x] = ground_of.call(spot.x, spot.y)
	settle(at, c, r, ground, blocked_grid(track, at, c, r))


## Settles on the track's ground unless it's been settled already.
func ensure(track: TrackPath) -> void:
	if not settled:
		settle_on(track)


## The points of a grid near road on the ground, where no water goes: within
## half the road's width, its kerb and PaintedAreas.ROAD_ROOM (1). Past the
## edge of a ground map is 2: a lake stops there as at a wall.
static func blocked_grid(track: TrackPath, at: Vector2, c: int, r: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(c * r)
	var map := track.ground
	if map != null:
		var area := Rect2(map.origin, Vector2(map.cols - 1, map.rows - 1) * map.cell)
		for z in r:
			for x in c:
				if not area.has_point(at + Vector2(x, z) * CELL):
					out[z * c + x] = 2
	for k in track.points.size():
		var p := track.points[k]
		if k < track.grounds.size() and p.y - track.grounds[k] > PaintedAreas.RAISED:
			continue
		var reach := track.outer_half(k) + TrackPath.KERB + PaintedAreas.ROAD_ROOM
		var x0 := maxi(0, ceili((p.x - reach - at.x) / CELL))
		var x1 := mini(c - 1, floori((p.x + reach - at.x) / CELL))
		var z0 := maxi(0, ceili((p.z - reach - at.y) / CELL))
		var z1 := mini(r - 1, floori((p.z + reach - at.y) / CELL))
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var spot := at + Vector2(x, z) * CELL
				if spot.distance_squared_to(Vector2(p.x, p.z)) < reach * reach:
					out[z * c + x] = 1
	return out


## Works out every river's surface and channel and every lake's water on a
## grid of the ground's heights, `ground`, and returns the ground with the
## channels carved in.
func settle(at: Vector2, c: int, r: int, ground: PackedFloat32Array, block: PackedByteArray) -> PackedFloat32Array:
	origin = at
	cols = c
	rows = r
	base = ground.duplicate()
	blocked = block
	resettle()
	return heights


## Works it all out again on the same ground, after the bodies change.
func resettle() -> void:
	settled = true
	heights = base.duplicate()
	wet = PackedInt32Array()
	wet.resize(cols * rows)
	tops = PackedFloat32Array()
	tops.resize(cols * rows)
	levels = PackedFloat32Array()
	levels.resize(bodies.size())
	levels.fill(NAN)
	lines = []
	lines.resize(bodies.size())
	if bodies.is_empty() or cols < 2 or rows < 2:
		return
	# Lakes first on the ground as it is, so rivers know where they end.
	for b in bodies.size():
		if bodies[b].kind == "lake" and not bodies[b].has("cells"):
			levels[b] = _flood(b, bodies[b].level)
	for b in bodies.size():
		if bodies[b].kind == "river":
			lines[b] = _line(b)
	for b in bodies.size():
		if lines[b] != null:
			_carve(b)
	# Then again on the carved ground, over the rivers where they meet.
	for b in bodies.size():
		if bodies[b].kind == "lake" and not bodies[b].has("cells"):
			_clear_lake(b)
			levels[b] = _flood(b, bodies[b].level)


func _clear_lake(b: int) -> void:
	for i in wet.size():
		if wet[i] == b + 1:
			wet[i] = 0


## Fills the lake from its seed up to `level`, kept under any road on the
## ground it would reach. Returns the level it settles at.
func _flood(b: int, level: float) -> float:
	var seed := _index(bodies[b].at)
	if seed < 0:
		return level
	for attempt in 4:
		var reached := PackedInt32Array()
		var lowest_road := INF
		if heights[seed] < level and blocked[seed] == 0:
			var seen := {seed: true}
			reached.append(seed)
			var n := 0
			while n < reached.size() and reached.size() < MOST_LAKE:
				var i := reached[n]
				n += 1
				var x := i % cols
				var z := i / cols
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var nz := z + d.y
					if nx < 0 or nz < 0 or nx >= cols or nz >= rows:
						continue
					var j := nz * cols + nx
					if seen.has(j) or heights[j] >= level:
						continue
					seen[j] = true
					if blocked[j] == 2:
						continue
					if blocked[j] == 1:
						lowest_road = minf(lowest_road, heights[j])
						continue
					reached.append(j)
		if lowest_road < level and attempt < 3:
			level = lowest_road - 0.2
			continue
		for i in reached:
			wet[i] = b + 1
			tops[i] = level
		return level
	return level


## A river's line every STEP metres, smooth through its points, with its
## surface going only down.
func _line(b: int) -> Dictionary:
	var points: PackedVector3Array = bodies[b].points
	var at := PackedVector2Array()
	var widths := PackedFloat32Array()
	for k in points.size() - 1:
		var p0: Vector3 = points[maxi(k - 1, 0)]
		var p1: Vector3 = points[k]
		var p2: Vector3 = points[k + 1]
		var p3: Vector3 = points[mini(k + 2, points.size() - 1)]
		var length := Vector2(p1.x, p1.y).distance_to(Vector2(p2.x, p2.y))
		var steps := maxi(1, ceili(length / STEP))
		for s in steps:
			var t := float(s) / steps
			var spot := _spline(Vector2(p0.x, p0.y), Vector2(p1.x, p1.y), Vector2(p2.x, p2.y), Vector2(p3.x, p3.y), t)
			at.append(spot)
			widths.append(lerpf(p1.z, p2.z, t))
	var last: Vector3 = points[points.size() - 1]
	at.append(Vector2(last.x, last.y))
	widths.append(last.z)
	var count := at.size()
	var top := PackedFloat32Array()
	top.resize(count)
	var dry := PackedByteArray()
	dry.resize(count)
	var into_lake := -1
	var high := INF
	for i in count:
		var along := (at[mini(i + 1, count - 1)] - at[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-along.y, along.x) * (widths[i] * 0.5 + BANK_OUT)
		var bank := minf(_ground_at(at[i] + side), _ground_at(at[i] - side))
		high = minf(high, bank - UNDER)
		top[i] = high
		var g := _index(at[i])
		dry[i] = 1 if g < 0 or blocked[g] == 1 else 0
		if g >= 0 and wet[g] > 0 and bodies[wet[g] - 1].kind == "lake" and into_lake < 0 and i > 0:
			into_lake = i
	# Into a lake: it ends at the lake's level, and nothing below it.
	if into_lake >= 0:
		var g := _index(at[into_lake])
		var lake_level := tops[g]
		count = mini(count, into_lake + 2)
		at.resize(count)
		widths.resize(count)
		top.resize(count)
		dry.resize(count)
		for i in count:
			top[i] = maxf(top[i], lake_level)
		top[count - 1] = lake_level
	var steep := PackedFloat32Array()
	steep.resize(count)
	for i in count:
		var a := maxi(i - 2, 0)
		var z := mini(i + 2, count - 1)
		var run := maxf(at[a].distance_to(at[z]), 0.01)
		steep[i] = (top[a] - top[z]) / run
	return {"at": at, "top": top, "width": widths, "steep": steep, "dry": dry}


static func _spline(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Digs the river's channel into `heights` and wets the points under its
## surface, nearest stretch first where two overlap.
func _carve(b: int) -> void:
	var line: Dictionary = lines[b]
	var at: PackedVector2Array = line.at
	var top: PackedFloat32Array = line.top
	var widths: PackedFloat32Array = line.width
	var dry: PackedByteArray = line.dry
	var near := {}
	for i in at.size() - 1:
		if dry[i] == 1 or dry[i + 1] == 1:
			continue
		var a := at[i]
		var e := at[i + 1]
		var half := maxf(widths[i], widths[i + 1]) * 0.5
		var reach := half + 16.0
		var x0 := maxi(0, floori((minf(a.x, e.x) - reach - origin.x) / CELL))
		var x1 := mini(cols - 1, ceili((maxf(a.x, e.x) + reach - origin.x) / CELL))
		var z0 := maxi(0, floori((minf(a.y, e.y) - reach - origin.y) / CELL))
		var z1 := mini(rows - 1, ceili((maxf(a.y, e.y) + reach - origin.y) / CELL))
		var seg := e - a
		var length2 := maxf(seg.length_squared(), 0.0001)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var g := z * cols + x
				# Not at the grid's edge, which stays level, nor beside the
				# road's ground, which meets the kerbs.
				if x == 0 or z == 0 or x == cols - 1 or z == rows - 1 or _by_road(x, z):
					continue
				var spot := origin + Vector2(x, z) * CELL
				var t := clampf((spot - a).dot(seg) / length2, 0.0, 1.0)
				var d := spot.distance_to(a + seg * t)
				var w := lerpf(widths[i], widths[i + 1], t) * 0.5
				var s := lerpf(top[i], top[i + 1], t)
				var depth := clampf(w * 0.25, 0.8, 2.0)
				var target: float
				if d <= w:
					target = s - depth + (depth + 0.3) * pow(d / w, 2.0)
				else:
					target = s + 0.3 + (d - w) * BANK_SLOPE
				heights[g] = minf(heights[g], target)
				if d <= w + 1.0 and heights[g] < s and (wet[g] == 0 or (bodies[wet[g] - 1].kind == "river" and d < near.get(g, INF))):
					wet[g] = b + 1
					tops[g] = s
					near[g] = d


## Whether a grid point or any next to it is blocked.
func _by_road(x: int, z: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var nx := clampi(x + dx, 0, cols - 1)
			var nz := clampi(z + dz, 0, rows - 1)
			if blocked[nz * cols + nx] == 1:
				return true
	return false


## The grid point nearest a spot, or -1 off the grid.
func _index(at: Vector2) -> int:
	var x := roundi((at.x - origin.x) / CELL)
	var z := roundi((at.y - origin.y) / CELL)
	if x < 0 or z < 0 or x >= cols or z >= rows:
		return -1
	return z * cols + x


## The carved ground here, between the grid's points.
func _ground_at(at: Vector2) -> float:
	var fx := clampf((at.x - origin.x) / CELL, 0.0, cols - 1.001)
	var fz := clampf((at.y - origin.y) / CELL, 0.0, rows - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var ax := fx - ix
	var az := fz - iz
	var i := iz * cols + ix
	return lerpf(lerpf(heights[i], heights[i + 1], ax), lerpf(heights[i + cols], heights[i + cols + 1], ax), az)


func ground_at(x: float, z: float) -> float:
	if not settled or cols < 2:
		return 0.0
	return _ground_at(Vector2(x, z))


# Lookup.

## How high the surface of a lake or river is at (x, z), or NAN where there's
## none or it's shallow enough to drive through. Leaves its type in `kind`.
func level_at(x: float, z: float) -> float:
	kind = ""
	var top := surface_at(x, z)
	if is_nan(top) or top - _ground_at(Vector2(x, z)) < SHALLOW:
		kind = ""
		return NAN
	return top


## The surface over (x, z) where any of the grid points round it is wet,
## shallow or not, NAN where none is.
func surface_at(x: float, z: float) -> float:
	kind = ""
	if not settled or cols < 2:
		return NAN
	var fx := (x - origin.x) / CELL
	var fz := (z - origin.y) / CELL
	if fx < 0.0 or fz < 0.0 or fx >= cols - 1 or fz >= rows - 1:
		return NAN
	var ix := int(fx)
	var iz := int(fz)
	var ax := fx - ix
	var az := fz - iz
	var sum := 0.0
	var weight := 0.0
	var best := 0.0
	for c: Vector3i in [Vector3i(0, 0, 0), Vector3i(1, 0, 1), Vector3i(0, 1, 2), Vector3i(1, 1, 3)]:
		var i := (iz + c.y) * cols + ix + c.x
		if wet[i] == 0:
			continue
		var w := (ax if c.x == 1 else 1.0 - ax) * (az if c.y == 1 else 1.0 - az) + 0.001
		sum += tops[i] * w
		weight += w
		if w > best:
			best = w
			kind = bodies[wet[i] - 1].type
	if weight <= 0.0:
		return NAN
	return sum / weight


## Which type is at (x, z), deep enough to sink or burn, or "".
func kind_at(x: float, z: float) -> String:
	level_at(x, z)
	return kind


## Whether any lake or river is at `at` or within `room` metres of it.
func covered(at: Vector3, room := 0.0) -> bool:
	if not settled or not has_real():
		return false
	if not is_nan(surface_at(at.x, at.z)):
		return true
	if room <= 0.0:
		return false
	for k in 8:
		var angle := k * TAU / 8.0
		if not is_nan(surface_at(at.x + cos(angle) * room, at.z + sin(angle) * room)):
			return true
	if room > CELL * 2.0:
		return covered(at, room * 0.5)
	return false


## How many grid points each body wets.
func wet_count(b: int) -> int:
	var n := 0
	for i in wet.size():
		if wet[i] == b + 1:
			n += 1
	return n


## The body whose water is at (x, z), -1 for none.
func body_at(x: float, z: float) -> int:
	if not settled:
		return -1
	var g := _index(Vector2(x, z))
	if g >= 0 and wet[g] > 0:
		return wet[g] - 1
	for b in bodies.size():
		if lines[b] == null:
			continue
		var line: Dictionary = lines[b]
		for i in line.at.size():
			if (line.at[i] as Vector2).distance_to(Vector2(x, z)) < line.width[i] * 0.5 + 2.0:
				return b
	return -1


## Steepest descent down the ground from `from`, as river points `width`
## wide about every 12 m, until it reaches a hollow, the ground's edge or
## MOST_POINTS. `ground` is (x, z) -> height.
static func follow_valley(ground: Callable, from: Vector2, width: float, area: Rect2) -> PackedVector3Array:
	var out := PackedVector3Array([Vector3(from.x, from.y, width)])
	var here := from
	var heading := Vector2.ZERO
	var h: float = ground.call(here.x, here.y)
	var flat := 0
	var walked := 0.0
	while out.size() < MOST_POINTS:
		var best := Vector2.ZERO
		var lowest := INF
		for k in 24:
			var way := Vector2.from_angle(k * TAU / 24.0)
			if heading != Vector2.ZERO and way.dot(heading) < 0.2:
				continue
			var spot := here + way * 6.0
			var g: float = ground.call(spot.x, spot.y)
			if g < lowest:
				lowest = g
				best = way
		if best == Vector2.ZERO or not area.has_point(here + best * 6.0):
			break
		if lowest > h - 0.02:
			flat += 1
			if flat > 6:
				break
		else:
			flat = 0
		heading = best if heading == Vector2.ZERO else (heading * 0.6 + best * 0.4).normalized()
		here += heading * 6.0
		h = minf(h, lowest)
		walked += 6.0
		if walked >= 12.0:
			walked = 0.0
			out.append(Vector3(here.x, here.y, width))
	if out.size() < 2:
		out.append(Vector3(here.x, here.y, width))
	return out


# Drawing.

## The colours a body is drawn in: deep, shallow and foam.
static func colours(type: String) -> Array:
	if type == "lava":
		return [Color("#e8561a"), Color("#3a2620"), Color("#ffb347")]
	return [Color("#2f6f9f"), Color("#7fc4c0"), Color("#eef6f6")]


## A flat mesh at a lake's level over every cell it wets, coloured lighter
## where it's shallow; the ground comes up through it at the shore. Null if
## the lake is dry.
func lake_mesh(b: int) -> ArrayMesh:
	if not settled or b >= levels.size() or is_nan(levels[b]):
		return null
	var level := levels[b]
	var look := colours(bodies[b].type)
	var placed := {}
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var order := PackedInt32Array()
	for z in rows - 1:
		for x in cols - 1:
			var i := z * cols + x
			if wet[i] != b + 1 and wet[i + 1] != b + 1 and wet[i + cols] != b + 1 and wet[i + cols + 1] != b + 1:
				continue
			var corner := PackedInt32Array()
			for c in [i, i + 1, i + cols, i + cols + 1]:
				var index: int = placed.get(c, -1)
				if index < 0:
					index = points.size()
					placed[c] = index
					var spot := origin + Vector2(c % cols, c / cols) * CELL
					points.append(Vector3(spot.x, level, spot.y))
					normals.append(Vector3.UP)
					var depth := level - heights[c]
					var tint: Color = look[1].lerp(look[0], smoothstep(0.1, 1.6, depth))
					tints.append(tint)
				corner.append(index)
			order.append_array([corner[0], corner[1], corner[2], corner[1], corner[3], corner[2]])
	if order.is_empty():
		return null
	return _mesh(points, normals, tints, order, PackedVector2Array(), PackedVector2Array())


## A ribbon along a river at its surface, a little wider than its channel so
## the banks come up through it, with the distance along in UV.x, across in
## UV.y, and how fast it flows and how white in UV2. Null if it's all dry.
func river_mesh(b: int) -> ArrayMesh:
	if not settled or b >= lines.size() or lines[b] == null:
		return null
	var line: Dictionary = lines[b]
	var at: PackedVector2Array = line.at
	var look := colours(bodies[b].type)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var uvs := PackedVector2Array()
	var flows := PackedVector2Array()
	var order := PackedInt32Array()
	var along := 0.0
	var previous := -1
	for i in at.size():
		if i > 0:
			along += at[i].distance_to(at[i - 1])
		if line.dry[i] == 1:
			previous = -1
			continue
		var forward := (at[mini(i + 1, at.size() - 1)] - at[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-forward.y, forward.x)
		var half: float = line.width[i] * 0.5 + 1.5
		var steep: float = line.steep[i]
		var white := smoothstep(RAPIDS * 0.6, RAPIDS * 2.0, steep)
		var speed := 0.6 + clampf(steep * 40.0, 0.0, 3.0)
		var base_index := points.size()
		for s in [-1.0, 1.0]:
			var spot: Vector2 = at[i] + side * half * s
			points.append(Vector3(spot.x, line.top[i], spot.y))
			normals.append(Vector3.UP)
			tints.append(look[0].lerp(look[2], white * 0.55))
			uvs.append(Vector2(along, s * half))
			flows.append(Vector2(speed, white))
		if previous >= 0:
			order.append_array([previous, previous + 1, base_index, previous + 1, base_index + 1, base_index])
		previous = base_index
	if order.is_empty():
		return null
	return _mesh(points, normals, tints, order, uvs, flows)


static func _mesh(points: PackedVector3Array, normals: PackedVector3Array, tints: PackedColorArray, order: PackedInt32Array, uvs: PackedVector2Array, flows: PackedVector2Array) -> ArrayMesh:
	# Facing up whichever way round the triangles came (clockwise from above
	# is the front).
	for t in range(0, order.size(), 3):
		var a := points[order[t]]
		var b := points[order[t + 1]]
		var c := points[order[t + 2]]
		if (b - a).cross(c - a).y > 0.0:
			var keep := order[t + 1]
			order[t + 1] = order[t + 2]
			order[t + 2] = keep
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = flows
	arrays[Mesh.ARRAY_INDEX] = order
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Spots along a lava lake's shore and both banks of a lava river about
## `gap` metres apart, at the surface, for night lights.
func lava_edges(gap: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not settled:
		return out
	var taken := {}
	var per := maxi(1, roundi(gap / CELL))
	for b in bodies.size():
		if bodies[b].type != "lava" or bodies[b].has("cells"):
			continue
		if bodies[b].kind == "lake":
			for z in range(1, rows - 1):
				for x in range(1, cols - 1):
					var i := z * cols + x
					if wet[i] != b + 1:
						continue
					if wet[i + 1] == b + 1 and wet[i - 1] == b + 1 and wet[i + cols] == b + 1 and wet[i - cols] == b + 1:
						continue
					var key := Vector2i(x / per, z / per)
					if taken.has(key):
						continue
					taken[key] = true
					var spot := origin + Vector2(x, z) * CELL
					out.append(Vector3(spot.x, tops[i], spot.y))
		elif lines[b] != null:
			var line: Dictionary = lines[b]
			var walked := gap
			for i in line.at.size():
				if i > 0:
					walked += (line.at[i] as Vector2).distance_to(line.at[i - 1])
				if walked < gap or line.dry[i] == 1:
					continue
				walked = 0.0
				var forward := ((line.at[mini(i + 1, line.at.size() - 1)] as Vector2) - (line.at[maxi(i - 1, 0)] as Vector2)).normalized()
				var side := Vector2(-forward.y, forward.x) * (float(line.width[i]) * 0.5)
				for s in [-1.0, 1.0]:
					var spot: Vector2 = line.at[i] + side * s
					out.append(Vector3(spot.x, line.top[i], spot.y))
	return out
