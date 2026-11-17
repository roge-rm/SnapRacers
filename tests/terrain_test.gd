extends Node

## Builds the ground of tests/data/ground_course.json, a loop on a hand-made
## ground map (tools/track-design/ground_map.py course), and checks the
## ground meets the road's edges in the cutting and on the embankment, is
## the raw map under the bridge, eases down to a level rim at the grid's
## edge with the far floor under it, the lakes and river sit in the ground, a
## big landmark on a slope doesn't hang over it and the TV cameras are above
## the ground, the ground stays under the road all the way round and the road's
## ground is no steeper than about 12% along the road or any way under it.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . tests/terrain_test.tscn

const COURSE := "res://tests/data/ground_course.json"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COURSE))
	var track := TrackPath.from_dict(data)
	check(track.closes and track.ground != null and track.has_relief(), "the test course closes and has a map")
	var builder := TrackBuilder.new(track)
	builder.scenery = "landmarks"
	builder.sky = false
	add_child(builder)
	var terrain := builder.terrain
	check(terrain != null, "a course with a map gets the rolling ground")
	if terrain == null:
		_finish()
		return
	_edges(track, terrain)
	_bridge(track, terrain)
	_rim(track, terrain, builder)
	_pools(track, terrain)
	_landmark(builder)
	_tv(track, terrain)
	_slope(track)
	_any_way(track)
	_under_road(track, terrain)
	builder.free()
	_finish()


func _finish() -> void:
	print("All terrain checks passed." if failures == 0 else "%d terrain checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The road sample nearest a spot on the ground.
static func _nearest(track: TrackPath, x: float, z: float) -> int:
	var best := 0
	for k in track.points.size():
		var p := track.points[k]
		if Vector2(p.x - x, p.z - z).length() < Vector2(track.points[best].x - x, track.points[best].z - z).length():
			best = k
	return best


## Along the road on the ground the ground at the kerbs' outer edge is just
## under the road, however far the map is above or below it there.
func _edges(track: TrackPath, terrain: Terrain) -> void:
	var edge := track.width * 0.5 + TrackPath.KERB
	var worst := 0.0
	var cut := 0.0
	var fill := 0.0
	for k in range(0, track.points.size(), 3):
		if not terrain._on_ground(k):
			continue
		var p := track.points[k]
		for side in [-1.0, 1.0]:
			var at: Vector3 = p + track.rights[k] * side * edge
			worst = maxf(worst, absf(terrain.surface_at(at.x, at.z) - (at.y - Terrain.MAP_SINK)))
			var away: Vector3 = p + track.rights[k] * side * (edge + 15.0)
			var raw := track.ground_height(away.x, away.z) - p.y
			cut = maxf(cut, raw)
			fill = maxf(fill, -raw)
	check(worst < 0.15, "the ground meets the kerbs' edge along the road (%.2f m off at most)" % worst)
	check(cut > 2.0, "the road runs through a cutting, the map 15 m out up to %.1f m above it" % cut)
	check(fill > 2.0, "and along an embankment, the map up to %.1f m below it" % fill)
	# In the cutting the ground climbs back up to the map away from the road.
	var k := _nearest(track, 288.0, -80.0)
	var p := track.points[k]
	var out := p + track.rights[k] * (edge + Terrain.BLEND + 4.0) * signf(track.rights[k].x)
	check(absf(terrain.height_at(out.x, out.z) - track.ground_height(out.x, out.z)) < 0.15 and track.ground_height(out.x, out.z) > p.y + 2.0, "past the blend the cutting's bank is the map (%.1f m above the road)" % (terrain.height_at(out.x, out.z) - p.y))


## Under the bridge over the valley the ground is the raw map, well below it.
## The river runs under its middle, so this is past the river's bank.
func _bridge(track: TrackPath, terrain: Terrain) -> void:
	var k := _nearest(track, 0.0, -184.0)
	var p := track.points[k]
	var under := terrain.height_at(p.x, p.z)
	check(not terrain._on_ground(k) and absf(under - track.ground_height(p.x, p.z)) < 0.05, "under the bridge the ground is the map")
	check(p.y - under > 2.0, "and the bridge stands %.1f m over the valley side" % (p.y - under))


## The grid's edge is level at the rim, the lowest map point along it, and the
## far floor is just under it.
func _rim(track: TrackPath, terrain: Terrain, builder: TrackBuilder) -> void:
	var level := true
	var lowest := INF
	for x in terrain.cols:
		for z in [0, terrain.rows - 1]:
			level = level and absf(terrain.heights[z * terrain.cols + x] - terrain.rim) < 0.01
			var at := terrain._point(x, z)
			lowest = minf(lowest, track.ground_height(at.x, at.y))
	for z in terrain.rows:
		for x in [0, terrain.cols - 1]:
			level = level and absf(terrain.heights[z * terrain.cols + x] - terrain.rim) < 0.01
	check(level and terrain.rim <= lowest + 0.001, "the edge of the ground is level at the map's lowest edge point (%.1f m)" % terrain.rim)
	# Inside EDGE the ground is the map, out to where the road's blend reaches.
	var inside := Vector2i(int((Terrain.EDGE + 4.0) / Terrain.CELL), terrain.rows / 2)
	var at := terrain._point(inside.x, inside.y)
	check(absf(terrain.heights[inside.y * terrain.cols + inside.x] - track.ground_height(at.x, at.y)) < 0.01, "and past EDGE in from it, it's the map")
	var high := -INF
	for z in terrain.rows:
		high = maxf(high, terrain.heights[z * terrain.cols + terrain.cols - 1 - int(Terrain.EDGE / Terrain.CELL)])
	print("        the high side comes down %.1f m over the outer %d m" % [high - terrain.rim, roundi(Terrain.EDGE)])
	var dressing := Scenery.new(track, "alpine")
	dressing.ground = builder.ground_at
	dressing.terrain = terrain
	check(is_equal_approx(dressing._far_level(Vector2.ZERO, Vector2.ONE * 500.0), terrain.rim - 1.0), "the far floor sits a metre under the rim")
	dressing.free()


## The lakes and the river sit in the ground: under every wet point the
## ground is under the surface (see water_test for the rest).
func _pools(track: TrackPath, terrain: Terrain) -> void:
	var waters := track.waters
	var under := true
	var count := 0
	for i in waters.wet.size():
		if waters.wet[i] > 0:
			count += 1
			var at := waters.origin + Vector2(i % waters.cols, i / waters.cols) * Waters.CELL
			under = under and terrain.height_at(at.x, at.y) < waters.tops[i]
	check(count > 0 and under and waters.heights == terrain.heights, "the lakes and the river sit in the ground (%d points)" % count)


## The barn on the hill's slope sits at the lowest ground under its corners.
func _landmark(builder: TrackBuilder) -> void:
	var dressing: Scenery
	for child in builder.get_children():
		if child is Scenery:
			dressing = child
	var found := false
	for placed: Array in dressing._placed if dressing != null else []:
		var at: Vector3 = placed[0]
		if Vector2(at.x, at.z).distance_to(Vector2(360.0, -20.0)) > 1.0:
			continue
		found = true
		var corner: float = Props.ROOM.barn * 0.7
		var middle := builder.ground_at(at.x, at.z)
		var low := middle
		for dx in [-corner, corner]:
			for dz in [-corner, corner]:
				low = minf(low, builder.ground_at(at.x + dx, at.z + dz))
		check(is_equal_approx(at.y, low) and middle - low > 0.3, "the barn on the slope sits at its lowest corner, %.1f m under its middle" % (middle - low))
	check(found, "the barn is placed")


## The TV cameras are at least TV_HEIGHT over the map, so none is in a bank.
func _tv(track: TrackPath, terrain: Terrain) -> void:
	var camera := RaceCamera.new()
	camera.track = track
	camera._place_tv_cameras()
	var clear := true
	for spot in camera._tv_spots:
		clear = clear and spot.y >= terrain.height_at(spot.x, spot.z) + RaceCamera.TV_HEIGHT - 0.01
	check(clear, "the TV cameras are all above the ground")
	camera.free()


## How steep the road's ground gets along the road, between the map's points.
func _slope(track: TrackPath) -> void:
	var steepest := 0.0
	for k in range(1, track.points.size()):
		var run := Vector2(track.points[k].x - track.points[k - 1].x, track.points[k].z - track.points[k - 1].z).length()
		if run > 0.5:
			steepest = maxf(steepest, absf(track.grounds[k] - track.grounds[k - 1]) / run)
	check(steepest <= GroundMap.ROAD_STEEPEST + 0.005, "the road's ground climbs at most %d%% along the road (%.1f%%)" % [roundi(GroundMap.ROAD_STEEPEST * 100.0), steepest * 100.0])



## How steep the road's ground is under the road in its steepest direction,
## so a diagonal road over the same spot stays near the limit too. Reads
## between map points can go a little over it.
func _any_way(track: TrackPath) -> void:
	var road := track.ground.road()
	var steepest := 0.0
	for p in track.points:
		var across := (road.height_at(p.x + 0.25, p.z) - road.height_at(p.x - 0.25, p.z)) / 0.5
		var along := (road.height_at(p.x, p.z + 0.25) - road.height_at(p.x, p.z - 0.25)) / 0.5
		steepest = maxf(steepest, Vector2(across, along).length())
	check(steepest <= 0.13, "under the road the road's ground is at most 13%% steep any way (%.1f%%)" % (steepest * 100.0))


## The ground stays under the road's surface all the way round, across the
## whole road and its kerbs.
func _under_road(track: TrackPath, terrain: Terrain) -> void:
	var edge := track.width * 0.5 + TrackPath.KERB
	var worst := -INF
	var at := 0.0
	for k in track.points.size():
		if not track.solids[k]:
			continue
		var p := track.points[k]
		for step in 11:
			var spot: Vector3 = p + track.rights[k] * edge * (step / 5.0 - 1.0)
			var poke := terrain.surface_at(spot.x, spot.z) - spot.y
			if poke > worst:
				worst = poke
				at = track.distances[k]
	check(worst <= 0.0, "the ground stays under the road all the way round (%.2f m at most, at %.0f m)" % [worst, at])
