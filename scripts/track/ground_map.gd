class_name GroundMap
extends RefCounted

## A course's own ground: heights in metres above the start on a grid of
## points `cell` metres apart (the same squares as PaintedAreas), read
## bilinear between them and held at the edge outside. It takes the place of
## TrackPath.hills.
##
## A course file keeps it as "ground": { "cell": 8.0, "origin": [x, z],
## "size": [cols, rows], "step": 0.05, "data": "<base64>" }. Each height is
## rounded to `step` and stored as the difference from the plane through its
## left, upper and upper left neighbours (left only on the first row, upper
## only on the first column), as zigzag varints, deflated (zlib format) and
## base64. tools/track-design/ground_map.py writes the same.

const CELL := 8.0
const STEP := 0.05
## 256 x 256 points, 2 km square.
const MOST_POINTS := 65536
## The highest and lowest a point can be, in metres from the start.
const HIGHEST := 200.0
## The steepest the road takes from the map alone, as a slope. Steeper climbs
## come from ramp pieces on top.
const ROAD_STEEPEST := 0.12
## The binomial blur for the road copy, 1 4 6 4 1 over five points (16 m
## each side on 8 m cells).
const ROAD_BLUR := [1.0 / 16.0, 4.0 / 16.0, 6.0 / 16.0, 4.0 / 16.0, 1.0 / 16.0]

var cell := CELL
## Where the first point is, as x, z.
var origin := Vector2.ZERO
var cols := 0
var rows := 0
## Row by row, cols across, in metres.
var heights := PackedFloat32Array()
## The smoothed copy the road follows (see road()).
var _road: GroundMap
## The heights encode() last wrote out, and its text.
var _encoded_heights := PackedFloat32Array()
var _encoded := ""

## The last few maps decoded, by their text, and road copies made, so
## building a course again and again (the editor does on every change) only
## does the work when the ground has changed. Locked, as the editor's closer
## builds courses on another thread.
const KEPT := 4
static var _decoded: Dictionary = {}
static var _roads: Array = []
static var _lock := Mutex.new()


static func blank(origin_: Vector2, cols_: int, rows_: int, cell_ := CELL) -> GroundMap:
	var map := GroundMap.new()
	map.origin = origin_
	map.cols = cols_
	map.rows = rows_
	map.cell = cell_
	map.heights.resize(cols_ * rows_)
	return map


func duplicate_map() -> GroundMap:
	var copy := GroundMap.blank(origin, cols, rows, cell)
	copy.heights = heights.duplicate()
	return copy


## Drops the road copy, after the heights have been changed.
func changed() -> void:
	_road = null


func height_at(x: float, z: float) -> float:
	if cols < 1 or rows < 1:
		return 0.0
	var fx := clampf((x - origin.x) / cell, 0.0, cols - 1.0)
	var fz := clampf((z - origin.y) / cell, 0.0, rows - 1.0)
	var ix := mini(int(fx), maxi(cols - 2, 0))
	var iz := mini(int(fz), maxi(rows - 2, 0))
	var ax := fx - ix
	var az := fz - iz
	var ix1 := mini(ix + 1, cols - 1)
	var iz1 := mini(iz + 1, rows - 1)
	var h00 := heights[iz * cols + ix]
	var h10 := heights[iz * cols + ix1]
	var h01 := heights[iz1 * cols + ix]
	var h11 := heights[iz1 * cols + ix1]
	return lerpf(lerpf(h00, h10, ax), lerpf(h01, h11, ax), az)


func height_of(x: int, z: int) -> float:
	return heights[clampi(z, 0, rows - 1) * cols + clampi(x, 0, cols - 1)]


## The ground the road follows: the map blurred over 16 m, made no steeper
## than ROAD_STEEPEST any way, then blurred again. Made once and kept until
## changed().
func road() -> GroundMap:
	if _road != null:
		return _road
	var made := PackedFloat32Array()
	_lock.lock()
	for entry: Array in _roads:
		if entry[0] == cell and entry[1] == cols and entry[2] == rows and entry[3] == heights:
			made = entry[4]
			break
	_lock.unlock()
	if made.is_empty() and not heights.is_empty():
		var key := heights.duplicate()
		made = road_heights().heights
		_lock.lock()
		_roads.push_front([cell, cols, rows, key, made])
		if _roads.size() > KEPT:
			_roads.resize(KEPT)
		_lock.unlock()
	_road = GroundMap.blank(origin, cols, rows, cell)
	if not made.is_empty():
		_road.heights = made.duplicate()
	return _road


func road_heights() -> GroundMap:
	var out := duplicate_map()
	if cols < 1 or rows < 1:
		return out
	_blur(out.heights)
	# Slope limit: a lower pass cuts peaks and a raise pass fills valleys, each
	# two sweeps over the neighbours, and the two are averaged. Raising is
	# lowering the ground turned upside down.
	var lowered := _lowered(out.heights)
	var flipped := PackedFloat32Array()
	flipped.resize(out.heights.size())
	for i in out.heights.size():
		flipped[i] = -out.heights[i]
	var raised := _lowered(flipped)
	for i in out.heights.size():
		out.heights[i] = (lowered[i] - raised[i]) * 0.5
	# Blurred again to round off the creases the limit leaves, which would
	# be sudden changes of grade along the road. A blur can't make it steeper.
	_blur(out.heights)
	return out


## Blurs `h` in place with ROAD_BLUR, along rows then down columns, held at
## the edges.
func _blur(h: PackedFloat32Array) -> void:
	var across := PackedFloat32Array()
	across.resize(h.size())
	var w0: float = ROAD_BLUR[0]
	var w1: float = ROAD_BLUR[1]
	var w2: float = ROAD_BLUR[2]
	for z in rows:
		var row := z * cols
		for x in cols:
			across[row + x] = h[row + maxi(x - 2, 0)] * w0 + h[row + maxi(x - 1, 0)] * w1 + h[row + x] * w2 \
				+ h[row + mini(x + 1, cols - 1)] * w1 + h[row + mini(x + 2, cols - 1)] * w0
	for z in rows:
		var a := maxi(z - 2, 0) * cols
		var b := maxi(z - 1, 0) * cols
		var c := z * cols
		var d := mini(z + 1, rows - 1) * cols
		var e := mini(z + 2, rows - 1) * cols
		for x in cols:
			h[c + x] = across[a + x] * w0 + across[b + x] * w1 + across[c + x] * w2 + across[d + x] * w1 + across[e + x] * w0


## A copy of `from` with each point brought down to within ROAD_STEEPEST of
## its neighbours, in a sweep forwards and one back.
func _lowered(from: PackedFloat32Array) -> PackedFloat32Array:
	var h := from.duplicate()
	var straight := ROAD_STEEPEST * cell
	var diagonal := straight * sqrt(2.0)
	var twice := 2.0 * straight * straight
	var last_x := cols - 1
	var last_z := rows - 1
	for sweep in 2:
		var back := sweep == 1
		var step := 1 if back else -1
		for zn in rows:
			var z: int = last_z - zn if back else zn
			var zs: int = z + step
			var z_in := zs >= 0 and zs < rows
			var row := z * cols
			var other := zs * cols
			for xn in cols:
				var x: int = last_x - xn if back else xn
				var xs: int = x + step
				var xd: int = x - step
				var i: int = row + x
				var best := h[i]
				if xs >= 0 and xs < cols:
					best = minf(best, h[i + step] + straight)
					if z_in:
						best = minf(best, h[other + xs] + diagonal)
				if z_in:
					best = minf(best, h[other + x] + straight)
					if xd >= 0 and xd < cols:
						best = minf(best, h[other + xd] + diagonal)
				# The neighbours across and along can each be within reach and
				# still make the slope between them too steep for a diagonal road,
				# so the slope through both together is held to it too.
				var a := h[i - 1] if x > 0 else h[i]
				if x < last_x:
					a = minf(a, h[i + 1])
				var b := h[i - cols] if z > 0 else h[i]
				if z < last_z:
					b = minf(b, h[i + cols])
				var apart := absf(a - b)
				if apart < straight:
					best = minf(best, (a + b) * 0.5 + sqrt(twice - apart * apart) * 0.5)
				h[i] = best
	return h


# Files.

func to_dict() -> Dictionary:
	return {"cell": cell, "origin": [origin.x, origin.y], "size": [cols, rows], "step": STEP, "data": encode()}


## Reads a "ground" entry, for a course whose tiles were `grow` times smaller.
## Anything wrong gives null, no map.
static func from_dict(data: Variant, grow := 1.0) -> GroundMap:
	if not data is Dictionary or not data.get("data") is String:
		return null
	var cell_ = data.get("cell", CELL)
	var step_ = data.get("step", STEP)
	var at = data.get("origin")
	var size = data.get("size")
	if not _number(cell_) or not _number(step_) or not is_equal_approx(float(step_), STEP):
		return null
	if not at is Array or at.size() != 2 or not _number(at[0]) or not _number(at[1]):
		return null
	if not size is Array or size.size() != 2 or not _number(size[0]) or not _number(size[1]):
		return null
	if not is_finite(grow) or grow <= 0.0 or float(cell_) <= 0.0:
		return null
	var cols_ := int(size[0])
	var rows_ := int(size[1])
	if float(cols_) != float(size[0]) or float(rows_) != float(size[1]) or cols_ < 1 or rows_ < 1 or cols_ * rows_ > MOST_POINTS:
		return null
	var map := decode(data.data, cols_, rows_)
	if map == null:
		return null
	map.cell = float(cell_) * grow
	map.origin = Vector2(float(at[0]), float(at[1])) * grow
	return map


func encode() -> String:
	if _encoded != "" and heights == _encoded_heights:
		return _encoded
	var bytes := PackedByteArray()
	var q := PackedInt32Array()
	q.resize(heights.size())
	for i in heights.size():
		q[i] = roundi(clampf(heights[i], -HIGHEST, HIGHEST) / STEP)
	for z in rows:
		for x in cols:
			var d := q[z * cols + x] - _predict(q, x, z, cols)
			var u := d * 2 if d >= 0 else -d * 2 - 1
			while u >= 0x80:
				bytes.append((u & 0x7f) | 0x80)
				u >>= 7
			bytes.append(u)
	_encoded = Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))
	_encoded_heights = heights.duplicate()
	return _encoded


## The map from encode()'s text, or null if it isn't cols x rows points
## within HIGHEST.
static func decode(text: String, cols_: int, rows_: int) -> GroundMap:
	if cols_ < 1 or rows_ < 1 or cols_ * rows_ > MOST_POINTS or text.length() > MOST_POINTS * 8:
		return null
	_lock.lock()
	var known: Array = _decoded.get(text, [])
	_lock.unlock()
	if not known.is_empty() and known[0] == cols_ and known[1] == rows_:
		return _decoded_map(text, known[2], cols_, rows_)
	var packed := Marshalls.base64_to_raw(text)
	if packed.is_empty():
		return null
	var most := cols_ * rows_ * 3
	var bytes := packed.decompress_dynamic(most, FileAccess.COMPRESSION_DEFLATE)
	if bytes.is_empty() or bytes.size() > most:
		return null
	var count := cols_ * rows_
	var q := PackedInt32Array()
	q.resize(count)
	var at := 0
	var limit := roundi(HIGHEST / STEP)
	for i in count:
		var u := 0
		var shift := 0
		while true:
			if at >= bytes.size() or shift >= 21:
				return null
			var b := bytes[at]
			at += 1
			u |= (b & 0x7f) << shift
			shift += 7
			if b < 0x80:
				break
		var d := (u >> 1) if u & 1 == 0 else -((u + 1) >> 1)
		var v := d + _predict(q, i % cols_, i / cols_, cols_)
		if absi(v) > limit:
			return null
		q[i] = v
	if at != bytes.size():
		return null
	var heights_ := PackedFloat32Array()
	heights_.resize(count)
	for i in count:
		heights_[i] = q[i] * STEP
	_lock.lock()
	if _decoded.size() >= KEPT:
		_decoded.clear()
	_decoded[text] = [cols_, rows_, heights_]
	_lock.unlock()
	return _decoded_map(text, heights_, cols_, rows_)


static func _decoded_map(text: String, heights_: PackedFloat32Array, cols_: int, rows_: int) -> GroundMap:
	var map := GroundMap.blank(Vector2.ZERO, cols_, rows_)
	map.heights = heights_.duplicate()
	map._encoded = text
	map._encoded_heights = heights_.duplicate()
	return map


static func _predict(q: PackedInt32Array, x: int, z: int, cols_: int) -> int:
	if z == 0:
		return q[x - 1] if x > 0 else 0
	if x == 0:
		return q[(z - 1) * cols_]
	return q[z * cols_ + x - 1] + q[(z - 1) * cols_ + x] - q[(z - 1) * cols_ + x - 1]


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
