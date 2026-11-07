class_name ClosureCursor
extends RefCounted

## x and z are four integer coefficients in 4*(1, sqrt(2), sqrt(3), sqrt(6))
## metres, followed by the connector heading and relative height in levels.
const QUARTER := [[4, 0, 0, 0], [0, 1, 0, 1], [0, 0, 2, 0], [0, 2, 0, 0], [2, 0, 0, 0], [0, -1, 0, 1], [0, 0, 0, 0]]


static func cosine(heading: int) -> PackedInt64Array:
	var h := posmod(heading, 24)
	var sign := 1
	if h > 12:
		h = 24 - h
	if h > 6:
		h = 12 - h
		sign = -1
	var out := PackedInt64Array(QUARTER[h])
	for i in 4:
		out[i] *= sign
	return out


static func sine(heading: int) -> PackedInt64Array:
	return cosine(6 - heading)


static func value(coefficients: PackedInt64Array, offset := 0) -> float:
	return coefficients[offset] + coefficients[offset + 1] * sqrt(2.0) + coefficients[offset + 2] * sqrt(3.0) + coefficients[offset + 3] * sqrt(6.0)


static func start(heading: int) -> PackedInt64Array:
	return PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, heading, 0])


## Empty means the piece's endpoint cannot use integer drawer levels/radii.
static func advance(cursor: PackedInt64Array, piece: TrackPiece) -> PackedInt64Array:
	var levels := piece.rise / TrackPiece.LEVEL
	if not is_finite(levels) or absf(levels - roundf(levels)) > 0.000001:
		return PackedInt64Array()
	var out := cursor.duplicate()
	var h := int(cursor[8])
	var j := posmod(h + piece.heading_delta(), 24)
	var c := cosine(h)
	var s := sine(h)
	if piece.type in ["curve", "arc"]:
		var radius := piece.radius / 16.0
		if absf(radius - roundf(radius)) > 0.000001:
			return PackedInt64Array()
		var cj := cosine(j)
		var sj := sine(j)
		var k := roundi(radius) * piece.turn
		for i in 4:
			out[i] += k * (c[i] - cj[i])
			out[i + 4] += k * (sj[i] - s[i])
	else:
		var across := piece.across
		if piece.type == "loop":
			across = piece.side
		var along_halves := 1 if piece.type == "half_straight" else 2 * piece.tiles
		for i in 4:
			out[i] += 2 * across * c[i] - along_halves * s[i]
			out[i + 4] -= 2 * across * s[i] + along_halves * c[i]
	out[8] = j
	out[9] += roundi(levels)
	return out


static func pose(cursor: PackedInt64Array) -> Transform3D:
	return Transform3D(TrackPath.heading_basis(cursor[8]), Vector3(4.0 * value(cursor), cursor[9] * TrackPiece.LEVEL, 4.0 * value(cursor, 4)))


static func key(cursor: PackedInt64Array) -> String:
	return ",".join(Array(cursor).map(func(n): return str(n)))


static func at_start(cursor: PackedInt64Array, heading: int) -> bool:
	if cursor[8] != heading or cursor[9] != 0:
		return false
	for i in 8:
		if cursor[i] != 0:
			return false
	return true
