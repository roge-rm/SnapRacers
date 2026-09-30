class_name PieceIcon
extends Control

## A picture of a piece of track for the track editor's drawer, drawn from its
## own shape as the road seen from above on its tiles, coming in at the bottom.
## Anything that climbs or drops has a little side view under it too, and the
## loop and the jump are marked so you can tell them apart.

const ROAD := Color("#8a8d86")
const EDGE := Color("#f2f2f2")
const KERB := Color("#d8261c")
const GRID := Color(1, 1, 1, 0.08)
const PROFILE := Color("#7fd8ff")

var spec: Dictionary


func _init(piece_spec: Dictionary) -> void:
	spec = piece_spec
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var piece := TrackPiece.from_spec(spec)
	var steps := 48
	var points := PackedVector2Array()
	var heights := PackedFloat32Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in steps + 1:
		var p := piece.point(float(k) / steps)
		var flat := Vector2(p.x, p.z)
		points.append(flat)
		heights.append(p.y)
		lo = lo.min(flat)
		hi = hi.max(flat)
	# The tiles it sits on, so a big bend looks big next to a small one.
	var half := TrackPiece.TILE * 0.5
	lo = Vector2(floorf((lo.x + half) / TrackPiece.TILE) * TrackPiece.TILE - half, floorf(lo.y / TrackPiece.TILE) * TrackPiece.TILE)
	hi = Vector2(ceilf((hi.x + half) / TrackPiece.TILE) * TrackPiece.TILE - half, ceilf(hi.y / TrackPiece.TILE) * TrackPiece.TILE)
	hi = hi.max(lo + Vector2(TrackPiece.TILE, TrackPiece.TILE))
	var climbs := _climbs(heights)
	var room := Rect2(Vector2(6, 6), size - Vector2(12, 12 + (18 if climbs else 0)))
	var span := hi - lo
	var scale := minf(room.size.x / span.x, room.size.y / span.y)
	var offset := room.position + (room.size - span * scale) * 0.5
	var to_icon := func(p: Vector2) -> Vector2:
		return offset + (p - lo) * scale
	for x in range(int(round(span.x / TrackPiece.TILE)) + 1):
		var a: Vector2 = to_icon.call(Vector2(lo.x + x * TrackPiece.TILE, lo.y))
		draw_line(a, a + Vector2(0, span.y * scale), GRID, 1.0)
	for y in range(int(round(span.y / TrackPiece.TILE)) + 1):
		var a: Vector2 = to_icon.call(Vector2(lo.x, lo.y + y * TrackPiece.TILE))
		draw_line(a, a + Vector2(span.x * scale, 0), GRID, 1.0)

	var line := PackedVector2Array()
	for p in points:
		line.append(to_icon.call(p))
	var road := maxf(10.0 * scale, 4.0)
	if spec.get("cut", false):
		# The dirt patch inside a cut bend, from the middle of the bend out
		# most of the way to the road.
		var middle := Vector2(piece.turn * piece.radius, 0.0)
		var patch := PackedVector2Array([to_icon.call(middle)])
		for k in 9:
			var a := PI * 0.5 * k / 8.0
			patch.append(to_icon.call(middle + Vector2(-piece.turn * cos(a), -sin(a)) * piece.radius * 0.7))
		draw_colored_polygon(patch, Color("#8a6a45"))
	if piece.type == "jump":
		# The gap between the kicker and the landing.
		var gap_from := int(steps * TrackPiece.KICKER_END / (piece.tiles * TrackPiece.TILE))
		var gap_to := int(steps * TrackPiece.LANDING_START / (piece.tiles * TrackPiece.TILE))
		draw_polyline(line.slice(0, gap_from + 1), EDGE, road + 3.0, true)
		draw_polyline(line.slice(gap_to), EDGE, road + 3.0, true)
		draw_polyline(line.slice(0, gap_from + 1), ROAD, road, true)
		draw_polyline(line.slice(gap_to), ROAD, road, true)
	else:
		var edge := KERB if absf(piece.bank) > 0.0 else EDGE
		draw_polyline(line, edge, road + (6.0 if piece.sticky else 3.0), true)
		draw_polyline(line, _surface(), road, true)
	# Which way it runs.
	var tip := line[line.size() - 1]
	var way := (tip - line[line.size() - 3]).normalized()
	var side := Vector2(-way.y, way.x)
	draw_colored_polygon(PackedVector2Array([tip + way * 4.0, tip - way * 4.0 + side * 4.0, tip - way * 4.0 - side * 4.0]), Color.WHITE)
	if piece.type == "loop":
		var middle: Vector2 = line[steps / 2]
		draw_arc(middle, road * 1.6, 0.0, TAU, 24, Color.WHITE, 2.5, true)

	if climbs:
		_draw_profile(heights, Rect2(Vector2(10, size.y - 20), Vector2(size.x - 20, 14)))


func _surface() -> Color:
	return TrackBuilder.COLOURS.get(spec.get("surface", "asphalt"), ROAD).lightened(0.15)


func _climbs(heights: PackedFloat32Array) -> bool:
	for h in heights:
		if absf(h) > 0.3:
			return true
	return false


## The piece from the side, so you can see it climb, drop or hump.
func _draw_profile(heights: PackedFloat32Array, box: Rect2) -> void:
	var top := 0.0
	var bottom := 0.0
	for h in heights:
		top = maxf(top, h)
		bottom = minf(bottom, h)
	var tall := maxf(top - bottom, 1.0)
	var line := PackedVector2Array()
	for k in heights.size():
		var x := box.position.x + box.size.x * k / (heights.size() - 1)
		var y := box.end.y - (heights[k] - bottom) / tall * box.size.y
		line.append(Vector2(x, y))
	draw_line(Vector2(box.position.x, box.end.y + 1), Vector2(box.end.x, box.end.y + 1), Color(1, 1, 1, 0.2), 1.0)
	draw_polyline(line, PROFILE, 2.5, true)
