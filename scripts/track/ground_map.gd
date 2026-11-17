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


## The ground the road follows: the map blurred over 16 m, then no steeper
## than ROAD_STEEPEST between neighbouring points. Made once and kept until
## changed().
func road() -> GroundMap:
	if _road == null:
		_road = road_heights()
	return _road


func road_heights() -> GroundMap:
	var out := duplicate_map()
	if cols < 1 or rows < 1:
		return out
	# Blur along rows, then down columns.
	var across := PackedFloat32Array()
	across.resize(heights.size())
	for z in rows:
		for x in cols:
			var sum := 0.0
			for k in 5:
				sum += height_of(x + k - 2, z) * ROAD_BLUR[k]
			across[z * cols + x] = sum
	for z in rows:
		for x in cols:
			var sum := 0.0
			for k in 5:
				sum += across[clampi(z + k - 2, 0, rows - 1) * cols + x] * ROAD_BLUR[k]
			out.heights[z * cols + x] = sum
	# Slope limit: a lower pass cuts peaks and a raise pass fills valleys, each
	# two sweeps over the 8 neighbours, and the two are averaged.
	var lowered := _limited(out.heights, false)
	var raised := _limited(out.heights, true)
	for i in out.heights.size():
		out.heights[i] = (lowered[i] + raised[i]) * 0.5
	return out


func _limited(from: PackedFloat32Array, raise: bool) -> PackedFloat32Array:
	var h := from.duplicate()
	var straight := ROAD_STEEPEST * cell
	var diagonal := straight * sqrt(2.0)
	for back in [false, true]:
		var step := 1 if back else -1
		var zs := range(rows - 1, -1, -1) if back else range(rows)
		var xs := range(cols - 1, -1, -1) if back else range(cols)
		for z in zs:
			for x in xs:
				var i: int = z * cols + x
				var best := h[i]
				for n in [Vector3i(x + step, z, 0), Vector3i(x, z + step, 0), Vector3i(x + step, z + step, 1), Vector3i(x - step, z + step, 1)]:
					if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
						continue
					var reach := diagonal if n.z == 1 else straight
					var other := h[n.y * cols + n.x]
					best = maxf(best, other - reach) if raise else minf(best, other + reach)
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
	return Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))


## The map from encode()'s text, or null if it isn't cols x rows points
## within HIGHEST.
static func decode(text: String, cols_: int, rows_: int) -> GroundMap:
	if cols_ < 1 or rows_ < 1 or cols_ * rows_ > MOST_POINTS or text.length() > MOST_POINTS * 8:
		return null
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
	var map := GroundMap.blank(Vector2.ZERO, cols_, rows_)
	for i in count:
		map.heights[i] = q[i] * STEP
	return map


static func _predict(q: PackedInt32Array, x: int, z: int, cols_: int) -> int:
	if z == 0:
		return q[x - 1] if x > 0 else 0
	if x == 0:
		return q[(z - 1) * cols_]
	return q[z * cols_ + x - 1] + q[(z - 1) * cols_ + x] - q[(z - 1) * cols_ + x - 1]


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
