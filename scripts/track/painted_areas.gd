class_name PaintedAreas
extends RefCounted

## Ground painted in the track editor: lakes, lava, mud and the like. It's a
## grid of 8 m squares from the world origin with a type in each, and the
## squares are blurred into a smooth 0 to 1 field per type, so an area has
## soft round edges. Lookups read the squares straight, a few per call, so
## they're fine for every wheel every physics step.
##
## A course file keeps it as "paint": { "cell": 8.0, "runs": [[z, x0, count,
## type], ...] }, a row of squares of one type per run.

const CELL := 8.0
## How wide the blur is, in metres. A single square reaches 1 at its middle,
## 0.5 on its edge and under 0.25 beyond 2 m out.
const BLUR := 6.0
## The field level of the deep part and of where the edge band starts.
const DEEP := 0.5
const EDGE := 0.25
## Types that sink or burn a kart keep this far past the kerb from road on the
## ground, in metres.
const ROAD_ROOM := 2.0
## Road this far above the ground is raised: a bridge or a jump.
const RAISED := 2.0
## The most squares one course can have.
const MOST_SQUARES := 200000
## The furthest a square or a run can reach, in squares.
const MOST_SPAN := 4096

## Each type: name on its tile, colour, edge colour (sand round water, crust
## round lava), the SceneryKit surface by name (water, glow, plain, smooth), effect ("sink", "burn" or ""), and the
## TrackPath.OFFROAD key whose grip and drag it uses when it only slows ("" for
## the ones that sink or burn).
const TYPES := {
	"water": {"name": "Water", "colour": Color("#2f7fb5"), "edge": Color("#d8c88f"), "surface": "water", "effect": "sink", "offroad": ""},
	"lava": {"name": "Lava", "colour": Color("#e8561a"), "edge": Color("#2a2220"), "surface": "glow", "effect": "burn", "offroad": ""},
	"slime": {"name": "Slime", "colour": Color("#7fd23a"), "edge": Color("#3d6b22"), "surface": "glow", "effect": "burn", "offroad": ""},
	"mud": {"name": "Mud", "colour": Color("#6b4a2e"), "edge": Color("#8a6a45"), "surface": "plain", "effect": "", "offroad": "mud"},
	"gravel": {"name": "Gravel", "colour": Color("#9a9690"), "edge": Color("#b3afa8"), "surface": "plain", "effect": "", "offroad": "gravel"},
	"sand": {"name": "Sand", "colour": Color("#dcc686"), "edge": Color("#e6d6a0"), "surface": "plain", "effect": "", "offroad": "sand"},
	"ice": {"name": "Ice", "colour": Color("#bfe6f2"), "edge": Color("#e4f6fb"), "surface": "smooth", "effect": "", "offroad": "ice"},
}

## The type in each square, by Vector2i(x, z).
var squares := {}


func is_empty() -> bool:
	return squares.is_empty()


func count() -> int:
	return squares.size()


func duplicate_areas() -> PaintedAreas:
	var copy := PaintedAreas.new()
	copy.squares = squares.duplicate()
	return copy


## Whether it sinks a kart, burns it or neither: "sink", "burn" or "".
static func effect_of(type: String) -> String:
	return TYPES[type].effect if TYPES.has(type) else ""


## Which square the point is in.
static func square_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


## Where the middle of a square is, as x, z.
static func middle_of(square: Vector2i) -> Vector2:
	return Vector2((square.x + 0.5) * CELL, (square.y + 0.5) * CELL)


# Painting.

## Puts a type in a square, or clears it with "". Returns whether it changed.
func set_square(square: Vector2i, type: String) -> bool:
	if type == "":
		return squares.erase(square)
	if not TYPES.has(type) or squares.get(square, "") == type:
		return false
	squares[square] = type
	return true


func square_type(square: Vector2i) -> String:
	return squares.get(square, "")


## Paints a brush of 1 square or 3 by 3 around the point, or erases with "".
## With a track, squares it doesn't allow are left alone (see allowed()).
## Returns how many squares changed.
func paint_at(x: float, z: float, type: String, brush := 1, track: TrackPath = null) -> int:
	var middle := square_at(x, z)
	var reach := 1 if brush >= 3 else 0
	var changed := 0
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var square := middle + Vector2i(dx, dz)
			if type != "" and track != null and not allowed(square, type, track):
				continue
			if set_square(square, type):
				changed += 1
	return changed


func erase_at(x: float, z: float, brush := 1) -> int:
	return paint_at(x, z, "", brush)


## Whether a type can go in a square. Types that sink or burn keep half the
## road's width, its kerb and ROAD_ROOM away from road on the ground, and may
## go under raised road. The ones that only slow keep off the road and kerb.
static func allowed(square: Vector2i, type: String, track: TrackPath) -> bool:
	if not TYPES.has(type):
		return false
	var room := ROAD_ROOM if TYPES[type].effect != "" else 0.0
	var low := Vector2(square.x * CELL, square.y * CELL)
	var high := low + Vector2(CELL, CELL)
	for i in track.points.size():
		var p := track.points[i]
		var reach := track.outer_half(i) + TrackPath.KERB + room
		if p.x < low.x - reach or p.x > high.x + reach or p.z < low.y - reach or p.z > high.y + reach:
			continue
		if p.y - track.grounds[i] > RAISED:
			continue
		var gap := Vector2(p.x - clampf(p.x, low.x, high.x), p.z - clampf(p.z, low.y, high.y))
		if gap.length() < reach:
			return false
	return true


# The course file.

## The runs of squares, merging neighbours of one type along a row.
func to_dict() -> Dictionary:
	var keys := squares.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var runs := []
	var run: Array = []
	for square: Vector2i in keys:
		var type: String = squares[square]
		if not run.is_empty() and run[0] == square.y and run[1] + run[2] == square.x and run[3] == type:
			run[2] += 1
		else:
			run = [square.y, square.x, 1, type]
			runs.append(run)
	return {"cell": CELL, "runs": runs}


## Reads a "paint" entry, for a course whose tiles were `grow` times smaller
## than now (1 for a current one). Runs that aren't well formed and types it
## doesn't know are dropped.
static func from_dict(data: Variant, grow := 1.0) -> PaintedAreas:
	var areas := PaintedAreas.new()
	if not data is Dictionary or not data.get("runs") is Array:
		return areas
	var cell := CELL
	if data.get("cell") is float or data.get("cell") is int:
		cell = float(data.cell)
	if not is_finite(cell) or cell <= 0.0 or not is_finite(grow) or grow <= 0.0:
		return areas
	var read := {}
	for run in data.runs:
		if not run is Array or run.size() < 4 or not run[3] is String or not TYPES.has(run[3]):
			continue
		if not (run[0] is float or run[0] is int) or not (run[1] is float or run[1] is int) or not (run[2] is float or run[2] is int):
			continue
		var z := float(run[0])
		var x0 := float(run[1])
		var span := float(run[2])
		if not is_finite(z) or not is_finite(x0) or not is_finite(span) or absf(z) > MOST_SPAN or absf(x0) > MOST_SPAN or span < 1.0 or span > MOST_SPAN:
			continue
		for k in int(span):
			if read.size() >= MOST_SQUARES:
				break
			read[Vector2i(int(x0) + k, int(z))] = run[3]
	if is_equal_approx(cell * grow, CELL):
		areas.squares = read
		return areas
	# Squares of another size are redrawn on this grid: each square here takes
	# the type of the old one its middle is in.
	var size := cell * grow
	for square: Vector2i in read:
		var low := Vector2(square.x, square.y) * size
		var first := Vector2i(ceili(low.x / CELL - 0.5), ceili(low.y / CELL - 0.5))
		var last := Vector2i(ceili((low.x + size) / CELL - 0.5) - 1, ceili((low.y + size) / CELL - 0.5) - 1)
		last = Vector2i(maxi(last.x, first.x), maxi(last.y, first.y)) if size < CELL else last
		for z in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				if areas.squares.size() >= MOST_SQUARES:
					return areas
				areas.squares[Vector2i(x, z)] = read[square]
	return areas


## A "paint" entry for a course made when tiles were `grow` times smaller,
## moved out to fit like its landmarks are.
static func grown_dict(data: Variant, grow: float) -> Dictionary:
	return from_dict(data, grow).to_dict()


# Lookup.

## The field of one type at a point, from 0 to 1.
func field_at(x: float, z: float, type: String) -> float:
	if squares.is_empty():
		return 0.0
	_look(x, z, type)
	return _level


## Which type is at the point, or "" where the field is under EDGE.
func kind_at(x: float, z: float) -> String:
	if squares.is_empty():
		return ""
	_look(x, z, "")
	return _kind


## How strong the field is at the point for the type there, 0 where none.
func level_at(x: float, z: float) -> float:
	if squares.is_empty():
		return 0.0
	_look(x, z, "")
	return _level


## Whether the point is in the deep part of an area.
func inside(x: float, z: float) -> bool:
	return level_at(x, z) >= DEEP


## Whether any painted area is at the point or within `room` metres of it.
func covered(at: Vector3, room := 0.0) -> bool:
	if squares.is_empty():
		return false
	if kind_at(at.x, at.z) != "":
		return true
	if room <= 0.0:
		return false
	for k in 8:
		var angle := k * TAU / 8.0
		if kind_at(at.x + cos(angle) * room, at.z + sin(angle) * room) != "":
			return true
	return false


## The field of every type at the point, as type -> 0 to 1, only the types
## that reach it.
func weights_at(x: float, z: float) -> Dictionary:
	var out := {}
	if squares.is_empty():
		return out
	var half := BLUR * 0.5
	for cz in range(floori((z - half) / CELL), floori((z + half) / CELL) + 1):
		var oz := minf(z + half, (cz + 1) * CELL) - maxf(z - half, cz * CELL)
		for cx in range(floori((x - half) / CELL), floori((x + half) / CELL) + 1):
			var type: String = squares.get(Vector2i(cx, cz), "")
			if type != "":
				var ox := minf(x + half, (cx + 1) * CELL) - maxf(x - half, cx * CELL)
				out[type] = out.get(type, 0.0) + ox * oz / (BLUR * BLUR)
	return out


## The field of all the types that sink or burn together, from 0 to 1.
func deep_field_at(x: float, z: float) -> float:
	var sum := 0.0
	var weights := weights_at(x, z)
	for type: String in weights:
		if TYPES[type].effect != "":
			sum += weights[type]
	return sum


## Whether any square sinks or burns.
func has_deep() -> bool:
	for type: String in squares.values():
		if TYPES[type].effect != "":
			return true
	return false


## How high each pool of water or lava sits, as square -> height for every
## square that sinks or burns. Squares that touch, corners too, are one pool,
## and its level is the lowest ground just round its edge, from `ground`
## (x, z -> height), so it never spills over. Flat ground gives 0.
func surface_levels(ground: Callable) -> Dictionary:
	var deep := {}
	for square: Vector2i in squares:
		if TYPES[squares[square]].effect != "":
			deep[square] = true
	var levels := {}
	var out := CELL * 0.5 + 1.5
	for first: Vector2i in deep:
		if levels.has(first):
			continue
		# Flood the pool from its first square, then find its lowest edge.
		var pool: Array[Vector2i] = [first]
		levels[first] = 0.0
		var n := 0
		var low := INF
		while n < pool.size():
			var square := pool[n]
			n += 1
			var middle := middle_of(square)
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var next := square + Vector2i(dx, dz)
					if next == square:
						continue
					if deep.has(next):
						if not levels.has(next):
							levels[next] = 0.0
							pool.append(next)
					elif dx == 0 or dz == 0:
						var side := Vector2(dx, dz)
						var along := Vector2(-dz, dx)
						for k in [-3.0, 0.0, 3.0]:
							var at: Vector2 = middle + side * out + along * k
							low = minf(low, ground.call(at.x, at.y))
					else:
						var at := middle + Vector2(dx, dz) * (CELL * 0.5 + 1.0)
						low = minf(low, ground.call(at.x, at.y))
		if low == INF:
			low = 0.0
		for square in pool:
			levels[square] = low
	return levels


## The level from surface_levels() for the pool at a point: its square's, or
## the nearest neighbouring square's that has one. `none` if there's none.
static func level_near(levels: Dictionary, x: float, z: float, none := 0.0) -> float:
	var square := square_at(x, z)
	if levels.has(square):
		return levels[square]
	var best := INF
	var level := none
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var next := square + Vector2i(dx, dz)
			if levels.has(next):
				var gap := middle_of(next).distance_squared_to(Vector2(x, z))
				if gap < best:
					best = gap
					level = levels[next]
	return level


var _kind := ""
var _level := 0.0


## Sets _kind and _level: the one type asked for, or with "" whichever is
## strongest if it reaches EDGE. Each square counts by how much of the blur's
## box over the point it covers, so it's at most four squares.
func _look(x: float, z: float, only: String) -> void:
	var half := BLUR * 0.5
	var x0 := floori((x - half) / CELL)
	var x1 := floori((x + half) / CELL)
	var z0 := floori((z - half) / CELL)
	var z1 := floori((z + half) / CELL)
	var names := []
	var weights := []
	for cz in range(z0, z1 + 1):
		var oz := minf(z + half, (cz + 1) * CELL) - maxf(z - half, cz * CELL)
		for cx in range(x0, x1 + 1):
			var type: String = squares.get(Vector2i(cx, cz), "")
			if type == "" or (only != "" and type != only):
				continue
			var ox := minf(x + half, (cx + 1) * CELL) - maxf(x - half, cx * CELL)
			var at := names.find(type)
			if at < 0:
				names.append(type)
				weights.append(ox * oz / (BLUR * BLUR))
			else:
				weights[at] += ox * oz / (BLUR * BLUR)
	_kind = ""
	_level = 0.0
	for k in names.size():
		if weights[k] > _level:
			_level = weights[k]
			_kind = names[k]
	if only != "":
		_kind = only if _level > 0.0 else ""
	elif _level < EDGE:
		_kind = ""
		_level = 0.0
