extends SceneTree

## Checks a course's ground map: it goes to text and back, reads what
## tools/track-design/ground_map.py writes, mirrored layouts read it mirrored,
## the road's copy keeps to ROAD_STEEPEST, an old course's grows with it, and
## a course with hills and no map builds exactly as before.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/ground_map_test.gd

## Terrain and road heights of Timberline (hills 20, no map), to the mm,
## before ground maps came in.
const TIMBERLINE_HASH := 477631302

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_round_trip()
	_fixture()
	_road_copy()
	_course()
	_mirrored()
	_growth()
	_timberline()
	print("All ground map checks passed." if failures == 0 else "%d ground map checks failed." % failures)
	quit(1 if failures > 0 else 0)


## Smooth rolling ground the size of a 1.8 km course, about 94 x 82 points.
static func rolling(cols := 94, rows := 82) -> GroundMap:
	var map := GroundMap.blank(Vector2(-376.0, -328.0), cols, rows)
	for z in rows:
		for x in cols:
			var h := 9.0 * sin(x * 0.09 + 0.4) * cos(z * 0.07) + 5.0 * sin((x + z) * 0.045) + 0.04 * x * GroundMap.CELL
			map.heights[z * cols + x] = h
	return map


func _round_trip() -> void:
	var map := rolling()
	var text := map.encode()
	var back := GroundMap.decode(text, map.cols, map.rows)
	var worst := 0.0
	for i in map.heights.size():
		worst = maxf(worst, absf(back.heights[i] - map.heights[i]))
	check(back != null and worst <= GroundMap.STEP * 0.5 + 0.0001, "a map goes to text and back to within half a step (%.3f m)" % worst)
	check(text.length() < 12000, "94 x 82 points of rolling ground is %.1f KB of text" % (text.length() / 1024.0))
	var dict := map.to_dict()
	var again := GroundMap.from_dict(JSON.parse_string(JSON.stringify(dict)))
	check(again != null and again.encode() == text and again.origin == map.origin and again.cols == 94 and again.rows == 82, "and its course file entry reads back the same")
	check(GroundMap.decode(text, map.cols + 1, map.rows) == null and GroundMap.decode(text, map.cols, map.rows - 1) == null, "the wrong size doesn't read")
	check(GroundMap.decode("bm9wZQ==", 3, 3) == null and GroundMap.decode("", 3, 3) == null, "nor does data that isn't a map")


func _fixture() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/ground_fixture.json"))
	var map := GroundMap.from_dict(data.ground)
	var same: bool = map != null and map.heights.size() == data.heights.size()
	if same:
		for i in map.heights.size():
			same = same and absf(map.heights[i] - float(data.heights[i])) < 0.0001
	check(same, "the map ground_map.py wrote reads the same here")
	check(map != null and map.encode() != "" and GroundMap.decode(map.encode(), map.cols, map.rows).heights == map.heights, "and writes back the same heights")
	check(map != null and is_equal_approx(map.height_at(-32.0 + 4.0, -24.0), (map.heights[0] + map.heights[1]) * 0.5) and is_equal_approx(map.height_at(-1000.0, -1000.0), map.heights[0]), "it's bilinear between points and held at the edge")


func _road_copy() -> void:
	# Rough ground: a 30 m spike and a 20 m pit on a steep slope.
	var map := rolling(40, 40)
	for z in map.rows:
		for x in map.cols:
			map.heights[z * map.cols + x] += 0.3 * x * GroundMap.CELL
	map.heights[10 * map.cols + 10] += 30.0
	map.heights[25 * map.cols + 30] -= 20.0
	var road := map.road()
	var straight := GroundMap.ROAD_STEEPEST * map.cell + 0.0001
	var diagonal := GroundMap.ROAD_STEEPEST * map.cell * sqrt(2.0) + 0.0001
	var steepest := 0.0
	var holds := true
	for z in map.rows:
		for x in map.cols:
			var h := road.height_of(x, z)
			holds = holds and absf(road.height_of(x + 1, z) - h) <= straight and absf(road.height_of(x, z + 1) - h) <= straight
			holds = holds and absf(road.height_of(x + 1, z + 1) - h) <= diagonal and absf(road.height_of(x - 1, z + 1) - h) <= diagonal
			steepest = maxf(steepest, absf(road.height_of(x + 1, z) - h) / map.cell)
	check(holds, "the road's copy is no steeper than %d%% between points (steepest %.1f%%)" % [roundi(GroundMap.ROAD_STEEPEST * 100.0), steepest * 100.0])
	check(map.road() == road, "and it's made once")
	map.changed()
	check(map.road() != road, "and again after a change")


## A course with a map: the road follows the road copy, the ground reads the
## raw map, the hills are ignored and dropped.
func _course() -> void:
	var data := _oval()
	data.hills = 20.0
	data.ground = rolling().to_dict()
	var track := TrackPath.from_dict(data)
	var map := GroundMap.from_dict(data.ground)
	var follows := true
	for k in range(0, track.points.size(), 7):
		var p := track.points[k]
		follows = follows and absf(track.grounds[k] - map.road().height_at(p.x, p.z)) < 0.001
		follows = follows and absf(track.ground_height(p.x, p.z) - map.height_at(p.x, p.z)) < 0.001
	check(track.has_relief() and follows, "the road follows the map's road copy and the ground is the map")
	var steepest := 0.0
	for k in range(1, track.points.size()):
		var run := Vector2(track.points[k].x, track.points[k].z).distance_to(Vector2(track.points[k - 1].x, track.points[k - 1].z))
		if run > 0.5:
			steepest = maxf(steepest, absf(track.grounds[k] - track.grounds[k - 1]) / run)
	check(steepest <= GroundMap.ROAD_STEEPEST * sqrt(2.0), "the road climbs at most about %d%% (%.1f%%)" % [roundi(GroundMap.ROAD_STEEPEST * 100.0), steepest * 100.0])
	var saved := track.to_dict()
	check(saved.has("ground") and not saved.has("hills"), "the track saves its map and drops the hills")
	var design := CourseDesign.from_dict(data)
	var design_data := design.to_dict()
	check(design.ground != null and design_data.get("ground", {}).get("data") == data.ground.data and not design_data.has("hills"), "and so does the course")
	check(design.duplicate_design().track().points == track.points, "a copy of the course builds the same road")
	var plain := _oval()
	check(not TrackPath.from_dict(plain).has_relief() and CourseDesign.from_dict(plain).to_dict().has("hills"), "a flat course has no relief and keeps saving its hills")


func _mirrored() -> void:
	var data := _oval()
	data.ground = rolling().to_dict()
	var plain := TrackPath.from_dict(data)
	var flipped := TrackPath.from_dict(data)
	flipped.apply_layout(true, false)
	var same := true
	for spot in [Vector2(30.0, -50.0), Vector2(-120.0, 80.0), Vector2(200.0, 10.0)]:
		# The start faces down -z at the origin, so a mirror flips x.
		same = same and is_equal_approx(flipped.ground_height(-spot.x, spot.y), plain.ground_height(spot.x, spot.y))
		same = same and is_equal_approx(flipped.road_ground(-spot.x, spot.y), plain.road_ground(spot.x, spot.y))
	check(same, "a mirrored layout reads the map mirrored around the start")
	var lap := true
	for k in range(0, flipped.points.size(), 11):
		var p := flipped.points[k]
		lap = lap and absf(flipped.grounds[k] - plain.road_ground(-p.x, p.z)) < 0.001
	check(lap, "and its road follows the mirrored map")


func _growth() -> void:
	var data := _oval()
	data.grid = TrackPiece.OLD_TILE
	data.ground = rolling(20, 20).to_dict()
	var map := GroundMap.from_dict(data.ground)
	var grow := TrackPath.growth(data)
	var track := TrackPath.from_dict(data)
	var design := CourseDesign.from_dict(data)
	var spot := map.origin + Vector2(37.0, 51.0)
	check(track.ground != null and is_equal_approx(track.ground.cell, GroundMap.CELL * grow) and track.ground.origin == map.origin * grow, "an old course's map grows with its tiles (cell %d m)" % track.ground.cell)
	check(is_equal_approx(track.ground_height(spot.x * grow, spot.y * grow), map.height_at(spot.x, spot.y)) and is_equal_approx(design.ground.height_at(spot.x * grow, spot.y * grow), map.height_at(spot.x, spot.y)), "and the heights move out with it")


## Heights of a hills course with no map haven't changed.
func _timberline() -> void:
	var track := TrackPath.load_file("res://data/tracks/timberline.json")
	var terrain := Terrain.new(track, Scenery.REACH + 45.0)
	var ints := PackedInt32Array()
	for h in terrain.heights:
		ints.append(roundi(h * 1000.0))
	for p in track.points:
		ints.append(roundi(p.y * 1000.0))
	var got := hash(ints)
	check(track.ground == null and got == TIMBERLINE_HASH, "Timberline's hills build the same as before (%d)" % got)
	terrain.free()


## A small closed course on flat ground, starting at the origin facing -z.
static func _oval() -> Dictionary:
	return {
		"name": "Ground test", "theme": "orchard", "grid": TrackPiece.TILE,
		"pieces": [
			{"type": "straight", "length": 3}, {"type": "curve", "turn": "right", "size": 2},
			{"type": "straight", "length": 2}, {"type": "curve", "turn": "right", "size": 2},
			{"type": "straight", "length": 3}, {"type": "curve", "turn": "right", "size": 2},
			{"type": "straight", "length": 2}, {"type": "curve", "turn": "right", "size": 2},
		],
	}
