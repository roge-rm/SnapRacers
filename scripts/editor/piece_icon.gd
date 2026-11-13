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
const HILL_HEIGHT := 6.0
const ISLAND := Color("#4b9f4a")
## A jump split's kicker and landing.
const KICKER := Color("#f2cd37")
## The road's width the icons are drawn for, in metres.
const ROAD_WIDTH := 13.0

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
	# A split's branches reach out past its middle line.
	var branches := _branches(piece, steps)
	for side in branches:
		for p in side:
			lo = lo.min(p)
			hi = hi.max(p)
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
	if piece.type == "curve" and piece.cut:
		# The dirt patch inside a cut bend, from the middle of the bend out
		# most of the way to the road.
		var middle := Vector2(piece.turn * piece.radius, 0.0)
		var patch := PackedVector2Array([to_icon.call(middle)])
		for k in 9:
			var a := PI * 0.5 * k / 8.0
			patch.append(to_icon.call(middle + Vector2(-piece.turn * cos(a), -sin(a)) * piece.radius * 0.7))
		draw_colored_polygon(patch, Color("#8a6a45"))
	if piece.is_split():
		_draw_split(piece, steps, to_icon, road / ROAD_WIDTH * 1.3)
	elif piece.type == "jump":
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
	if piece.crossing:
		# The railway across the middle, with its sleepers.
		var middle: Vector2 = line[steps / 2]
		var run := (line[steps / 2 + 1] - line[steps / 2 - 1]).normalized()
		var rail := Vector2(-run.y, run.x)
		var reach := size.x * 0.5
		var k := -reach
		while k <= reach:
			draw_line(middle + rail * k - run * 5.0, middle + rail * k + run * 5.0, Color("#8a6a45"), 2.0)
			k += 6.0
		for g in [-2.5, 2.5]:
			draw_line(middle - rail * reach + run * g, middle + rail * reach + run * g, Color("#c8ccd2"), 1.5)
	# Which way it runs.
	var tip := line[line.size() - 1]
	var forward := piece.exit().basis * Vector3.FORWARD
	var way := Vector2(forward.x, forward.z).normalized()
	var side := Vector2(-way.y, way.x)
	draw_colored_polygon(PackedVector2Array([tip + way * 4.0, tip - way * 4.0 + side * 4.0, tip - way * 4.0 - side * 4.0]), Color.WHITE)
	if TrackPiece.turns_over(piece.type):
		var middle: Vector2 = line[steps / 2]
		draw_arc(middle, road * 1.6, 0.0, TAU, 24, Color.WHITE, 2.5, true)

	if climbs:
		_draw_profile(heights, Rect2(Vector2(10, size.y - 20), Vector2(size.x - 20, 14)))


## The middles of a split's branches from above, left then right, and
## their outer edges, as [left middles, right middles, left edges, right edges].
func _branches(piece: TrackPiece, steps: int) -> Array:
	if not piece.is_split():
		return []
	var out := [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	for k in steps + 1:
		var t := float(k) / steps
		var p := piece.point(t)
		var ahead := piece.point(minf(t + 0.01, 1.0)) - piece.point(maxf(t - 0.01, 0.0))
		var right := Vector2(-ahead.z, ahead.x).normalized()
		var two := piece.branches(t, ROAD_WIDTH)
		var flat := Vector2(p.x, p.z)
		out[0].append(flat + right * two[0].x)
		out[1].append(flat + right * two[1].x)
		out[2].append(flat + right * (two[0].x - two[0].y * 0.5))
		out[3].append(flat + right * (two[1].x + two[1].y * 0.5))
	return out


## Both branches of a split with the grass island between them. `per_metre`
## is how many pixels a metre of road's width takes.
func _draw_split(piece: TrackPiece, steps: int, to_icon: Callable, per_metre: float) -> void:
	var sides := _branches(piece, steps)
	var island := PackedVector2Array()
	var back := PackedVector2Array()
	for k in steps + 1:
		var t := float(k) / steps
		var two := piece.branches(t, ROAD_WIDTH)
		var gap := maxf(two[1].x - two[0].x, 0.001)
		var from := two[0].y * 0.5 / gap
		var to := 1.0 - two[1].y * 0.5 / gap
		if from >= to:
			continue
		island.append(to_icon.call(sides[0][k].lerp(sides[1][k], from)))
		back.append(to_icon.call(sides[0][k].lerp(sides[1][k], to)))
	back.reverse()
	if island.size() + back.size() >= 3:
		draw_colored_polygon(island + back, ISLAND)
	var lines := []
	for side in 2:
		var line := PackedVector2Array()
		for p in sides[side]:
			line.append(to_icon.call(p))
		lines.append(line)
	var middle := piece.branches(0.5, ROAD_WIDTH)
	# Both edges first, so neither branch's edge shows across the other.
	for side in 2:
		var wide := maxf(middle[side].y * per_metre, 3.0)
		for run in _branch_runs(piece, side, steps, lines[side]):
			draw_polyline(run[0], EDGE, wide + 3.0, true)
	for side in 2:
		var wide := maxf(middle[side].y * per_metre, 3.0)
		var colour := _surface() if piece.branch_surface(side) == piece.surface else TrackBuilder.COLOURS["dirt"].lightened(0.15)
		for run in _branch_runs(piece, side, steps, lines[side]):
			draw_polyline(run[0], KICKER if run[1] else colour, wide, true)


## One branch's line cut into runs with road under them, as [points, up on a
## jump], so a jump split's kicker and landing stand out and its gap is left
## out.
func _branch_runs(piece: TrackPiece, side: int, steps: int, line: PackedVector2Array) -> Array:
	var runs := []
	var run := PackedVector2Array()
	var lifted := false
	for k in steps + 1:
		var t := float(k) / steps
		if not piece.branch_solid(t, side):
			if run.size() >= 2:
				runs.append([run, lifted])
			run = PackedVector2Array()
			continue
		var up := piece.branch_lift(t, side) > 0.05
		if up != lifted and run.size() >= 1:
			run.append(line[k])
			if run.size() >= 2:
				runs.append([run, lifted])
			run = PackedVector2Array()
		lifted = up
		run.append(line[k])
	if run.size() >= 2:
		runs.append([run, lifted])
	return runs


func _surface() -> Color:
	return TrackBuilder.COLOURS.get(spec.get("surface", "asphalt"), ROAD).lightened(0.15)


func _climbs(heights: PackedFloat32Array) -> bool:
	for h in heights:
		if absf(h) > 0.3:
			return true
	return false


## The piece from the side, so you can see it climb, drop or hump.
func _draw_profile(heights: PackedFloat32Array, box: Rect2) -> void:
	var bottom := 0.0
	for h in heights:
		bottom = minf(bottom, h)
	var tall := profile_height(heights)
	var line := PackedVector2Array()
	for k in heights.size():
		var x := box.position.x + box.size.x * k / (heights.size() - 1)
		var y := box.end.y - (heights[k] - bottom) / tall * box.size.y
		line.append(Vector2(x, y))
	draw_line(Vector2(box.position.x, box.end.y + 1), Vector2(box.end.x, box.end.y + 1), Color(1, 1, 1, 0.2), 1.0)
	draw_polyline(line, PROFILE, 2.5, true)


## Ordinary hills share a 6 m scale. Stunt captions give their full height.
func profile_height(heights: PackedFloat32Array) -> float:
	if not TrackPiece.turns_over(str(spec.get("type", "straight"))):
		return HILL_HEIGHT
	var low := 0.0
	var high := 0.0
	for h in heights:
		low = minf(low, h)
		high = maxf(high, h)
	return maxf(HILL_HEIGHT, ceilf((high - low) / HILL_HEIGHT) * HILL_HEIGHT)
