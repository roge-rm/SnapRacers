extends Node

## Lakes and rivers that go by the ground (see Waters), on
## tests/data/ground_course.json: the lake fills its hollow and no more, flat,
## with a smooth shore; the river never flows uphill, sits under its banks,
## runs under the bridge and has rapids down the drop; a river into a lake
## ends at its level; neither reaches road on the ground; old painted water
## turns into lakes, dug into a map or kept as squares without one; shared
## codes check them; and in a race a kart sinks in the lake and the river and
## burns in the lava lake.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . tests/water_test.tscn

const COURSE := "res://tests/data/ground_course.json"
const RACE_COURSE := "user://water_test.json"

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	host = Node.new()
	add_child(host)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COURSE))
	var track := TrackPath.from_dict(data)
	var builder := TrackBuilder.new(track)
	builder.scenery = "landmarks"
	builder.sky = false
	host.add_child(builder)
	var waters := track.waters
	check(builder.terrain != null and waters.settled and waters.bodies.size() == 3, "the test course has two lakes and a river, settled on its ground")
	_lake(waters, 0, "the lake")
	_lake(waters, 1, "the lava lake")
	_river(track, waters, 2)
	_road_rule(track, waters)
	_deep(builder, waters)
	builder.free()
	_into_lake(data)
	_old_paint(data)
	_sharing(data)
	Game.start(host, false)
	var saved := Game.settings.encode_to_text()
	Game.settings.set_value("race", "kart", "kart_kid")
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	await _race(data)
	Game.settings.clear()
	Game.settings.parse(saved)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RACE_COURSE))
	print("All water checks passed." if failures == 0 else "%d water checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The lake covers only ground under its level joined to the seed, ground
## round it is at or over the level, its surface is flat and its shore is a
## smooth curve round it.
func _lake(waters: Waters, b: int, what: String) -> void:
	var level := waters.levels[b]
	var count := 0
	var under := true
	var flat := true
	var held := true
	var far := 0.0
	var seed: Vector2 = waters.bodies[b].at
	for i in waters.wet.size():
		if waters.wet[i] != b + 1:
			continue
		count += 1
		under = under and waters.heights[i] < level
		flat = flat and is_equal_approx(waters.tops[i], level)
		var x := i % waters.cols
		var z := i / waters.cols
		far = maxf(far, (waters.origin + Vector2(x, z) * Waters.CELL).distance_to(seed))
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if x + d.x < 0 or z + d.y < 0 or x + d.x >= waters.cols or z + d.y >= waters.rows:
				held = false
				continue
			var j := (z + d.y) * waters.cols + x + d.x
			if waters.wet[j] != b + 1:
				held = held and (waters.heights[j] >= level or waters.blocked[j] == 1)
	check(count > 20 and is_equal_approx(level, waters.bodies[b].level), "%s fills %d points at its level %.2f" % [what, count, level])
	check(under and held and far < 70.0, "and stays in its hollow, all under the level and the ground round it over it (%.0f m across at most)" % (far * 2.0))
	var mesh := waters.lake_mesh(b)
	var level_mesh := mesh != null
	if mesh != null:
		for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			level_mesh = level_mesh and is_equal_approx(v.y, level)
	check(flat and level_mesh, "its surface is flat")
	# The shore: where the ground crosses the level between grid points,
	# round the lake by angle. A smooth shore changes radius gently.
	var shore: Array[Vector2] = []
	for i in waters.wet.size():
		if waters.wet[i] != b + 1:
			continue
		var x := i % waters.cols
		var z := i / waters.cols
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var j := (z + d.y) * waters.cols + x + d.x
			if waters.wet[j] == b + 1:
				continue
			var t := (level - waters.heights[i]) / maxf(waters.heights[j] - waters.heights[i], 0.001)
			shore.append(waters.origin + (Vector2(x, z) + Vector2(d) * clampf(t, 0.0, 1.0)) * Waters.CELL)
	var middle := Vector2.ZERO
	for p in shore:
		middle += p
	middle /= maxf(shore.size(), 1.0)
	shore.sort_custom(func(a: Vector2, c: Vector2) -> bool: return (a - middle).angle() < (c - middle).angle())
	var jump := 0.0
	for k in shore.size():
		var a := shore[k].distance_to(middle)
		var c := shore[(k + 1) % shore.size()].distance_to(middle)
		jump = maxf(jump, absf(a - c))
	check(shore.size() > 12 and jump < 3.0, "its shore is smooth: %d points round it, the radius changing at most %.1f m from one to the next" % [shore.size(), jump])


func _river(track: TrackPath, waters: Waters, b: int) -> void:
	var line: Dictionary = waters.lines[b]
	var tops: PackedFloat32Array = line.top
	var downhill := true
	for i in range(1, tops.size()):
		downhill = downhill and tops[i] <= tops[i - 1] + 0.0001
	check(tops.size() > 50 and downhill, "the river never flows uphill, %.1f m down over %d steps" % [tops[0] - tops[tops.size() - 1], tops.size()])
	var under_banks := true
	for i in tops.size():
		var at: Vector2 = line.at[i]
		var forward := ((line.at[mini(i + 1, tops.size() - 1)] as Vector2) - (line.at[maxi(i - 1, 0)] as Vector2)).normalized()
		var side := Vector2(-forward.y, forward.x) * (float(line.width[i]) * 0.5 + Waters.BANK_OUT)
		var bank := minf(_base(waters, at + side), _base(waters, at - side))
		under_banks = under_banks and tops[i] <= bank - Waters.UNDER + 0.001
	check(under_banks, "and its surface is under its banks")
	var steepest := 0.0
	for s: float in line.steep:
		steepest = maxf(steepest, s)
	check(steepest > Waters.RAPIDS, "with rapids where it drops (%.1f%% at the steepest)" % (steepest * 100.0))
	# Under the bridge on the west straight: road well up over it.
	var bridged := false
	for i in tops.size():
		var at: Vector2 = line.at[i]
		var k := track.offset_of(Vector3(at.x, 0.0, at.y))
		var p := track.point_at(k)
		if Vector2(p.x, p.z).distance_to(at) < 8.0 and p.y - tops[i] > 3.0 and line.dry[i] == 0:
			bridged = true
	check(bridged, "it runs on under the bridge")
	check(waters.wet_count(b) > 60, "and wets %d points" % waters.wet_count(b))


func _base(waters: Waters, at: Vector2) -> float:
	var keep := waters.heights
	waters.heights = waters.base
	var h := waters.ground_at(at.x, at.y)
	waters.heights = keep
	return h


## No water on or right beside road on the ground, and a lake raised over
## the road comes back down under it.
func _road_rule(track: TrackPath, waters: Waters) -> void:
	var clear := true
	for i in waters.wet.size():
		clear = clear and not (waters.wet[i] > 0 and waters.blocked[i] == 1)
	var road_dry := true
	for k in range(0, track.points.size(), 2):
		var p := track.points[k]
		if p.y - track.grounds[k] < PaintedAreas.RAISED:
			road_dry = road_dry and is_nan(waters.surface_at(p.x, p.z))
	check(clear and road_dry, "nothing is wet by road on the ground")
	var high := waters.duplicate_waters()
	high.bodies[0].level = 30.0
	high.settle(waters.origin, waters.cols, waters.rows, waters.base, waters.blocked)
	var kept := true
	for i in high.wet.size():
		kept = kept and not (high.wet[i] > 0 and high.blocked[i] == 1)
	check(high.levels[0] < 30.0 and kept, "a lake raised over the road settles under it (%.2f)" % high.levels[0])


## DeepWater answers for the lakes and the river, lava burns, and dry ground
## and the road aren't deep.
func _deep(builder: TrackBuilder, waters: Waters) -> void:
	var water := builder.water
	for b in 2:
		var at: Vector2 = waters.bodies[b].at
		var level := water.level_at(Vector3(at.x, waters.levels[b] - 0.5, at.y))
		check(is_equal_approx(level, waters.levels[b]) and water.kind == ["water", "lava"][b] and PaintedAreas.effect_of(water.kind) == ["sink", "burn"][b], "the middle of %s is deep, %s, which %ss" % [["the lake", "the lava lake"][b], water.kind, PaintedAreas.effect_of(water.kind)])
	var line: Dictionary = waters.lines[2]
	var middle: Vector2 = line.at[line.at.size() / 3]
	var top := water.level_at(Vector3(middle.x, float(line.top[line.at.size() / 3]) - 0.3, middle.y))
	check(is_finite(top) and water.kind == "water", "the middle of the river is deep (%.2f)" % top)
	check(not is_finite(water.level_at(Vector3(middle.x, top + 3.0, middle.y))), "well above it isn't")


## A river drawn down into the lake ends at the lake's level, never below.
func _into_lake(data: Dictionary) -> void:
	var trial: Dictionary = data.duplicate(true)
	var lake: Array = trial.water[0].at
	trial.water.append({"kind": "river", "type": "water", "points": [[lake[0] + 64.0, lake[1] - 6.0, 8.0], [lake[0] + 40.0, lake[1] - 2.0, 8.0], [lake[0] + 20.0, lake[1], 8.0], [lake[0], lake[1], 8.0]]})
	var track := TrackPath.from_dict(trial)
	var waters := track.waters
	waters.settle_on(track)
	var tops: PackedFloat32Array = waters.lines[3].top
	var level := waters.levels[0]
	var above := true
	for t in tops:
		above = above and t >= level - 0.0001
	check(tops.size() > 2 and is_equal_approx(tops[tops.size() - 1], level) and above, "a river into the lake ends at its level %.2f (from %.2f)" % [level, tops[0]])


## Painted water on the map course becomes a lake per pool, each in a hollow
## dug into the map, and on a course with no map the pools keep their squares.
func _old_paint(data: Dictionary) -> void:
	var old: Dictionary = data.duplicate(true)
	old.erase("water")
	var runs := []
	for row in [-21, -20]:
		for span in [[-6, 8], [3, 6], [10, 6]]:
			runs.append([row, span[0], span[1], "water"])
	for row in range(-38, -34):
		runs.append([row, 16, 4, "lava"])
	old.paint = {"cell": 8.0, "runs": runs}
	var track := TrackPath.from_dict(old)
	track.waters.settle_on(track)
	# Pools down a slope run together: the higher one's lake spills into the
	# lower ones. Either way the water's where it was painted.
	var covered := 0
	var squares := 0
	for run: Array in runs:
		for k in int(run[2]):
			var middle := PaintedAreas.middle_of(Vector2i(int(run[1]) + k, int(run[0])))
			squares += 1
			if not is_nan(track.waters.surface_at(middle.x, middle.y)):
				covered += 1
	check(track.paint.is_empty() and track.waters.bodies.size() == 4 and covered >= squares * 0.9, "an old painted map course has a lake per pool (%d), filling %d of its %d squares" % [track.waters.bodies.size(), covered, squares])
	var design := CourseDesign.from_dict(old)
	var saved := design.to_dict()
	check(not saved.has("paint") and saved.get("water", []).size() == 4 and TrackPath.from_dict(saved).waters.bodies.size() == 4, "and saves them as lakes")
	var flat: Dictionary = old.duplicate(true)
	flat.erase("ground")
	var plain := TrackPath.from_dict(flat)
	squares = 0
	for body: Dictionary in plain.waters.bodies:
		squares += body.get("cells", {}).size()
	check(plain.waters.bodies.size() == 2 and squares == 56 and Scenery.paint_of(plain).count() == 56 and not plain.waters.has_real(), "with no map a lake of each type keeps their squares (%d), built like painted ground" % squares)
	var back := TrackPath.from_dict(CourseDesign.from_dict(flat).to_dict())
	check(Scenery.paint_of(back).squares == Scenery.paint_of(plain).squares, "and keep them through saving")


func _sharing(data: Dictionary) -> void:
	var read := Sharing.read(Sharing.code_for(data))
	check(read.get("kind") == Sharing.COURSE and read.data.get("water", []).size() == 3, "a shared course brings its lakes and river")
	var bad := [
		[{"kind": "river", "type": "water", "points": [[0, 0, 8]]}],
		[{"kind": "river", "type": "water", "points": [[0, 0, 8], [10, 0, 99]]}],
		[{"kind": "lake", "type": "mud", "at": [0, 0], "level": 0}],
		[{"kind": "lake", "type": "water", "at": [0, 0], "level": 900}],
	]
	var many := []
	for k in Waters.MOST_BODIES + 1:
		many.append({"kind": "lake", "type": "water", "at": [k, 0], "level": 0})
	bad.append(many)
	var long := []
	for k in Waters.MOST_POINTS + 1:
		long.append([k, 0, 8])
	bad.append([{"kind": "river", "type": "water", "points": long}])
	var turned := 0
	for water in bad:
		var trial: Dictionary = data.duplicate(true)
		trial.water = water
		if Sharing.read(Sharing.code_for(trial)).has("why"):
			turned += 1
	check(turned == bad.size(), "bad lakes and rivers and too many are turned away (%d of %d)" % [turned, bad.size()])


## In a race a kart going into the lake or the river sinks, and into the
## lava lake burns, and is told which.
func _race(data: Dictionary) -> void:
	var file := FileAccess.open(RACE_COURSE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var previous := Game._screen
	Game.start_race(RACE_COURSE)
	for i in 300:
		await get_tree().process_frame
		if Game._screen is Race and Game._screen != previous:
			break
	var race := Game._screen as Race
	check(race != null, "the race starts")
	if race == null:
		return
	await frames(5)
	race.started = true
	race.time = 10.0
	var human: Race.Racer = race.humans[0]
	human.input.set_physics_process(false)
	var splashed := []
	human.kart.splashed.connect(func(kind: String) -> void: splashed.append(kind))
	for racer in race.racers:
		if racer != human:
			racer.kart.locked = true
	var waters := race.track.waters
	var line: Dictionary = waters.lines[2]
	var river: Vector2 = line.at[line.at.size() / 3]
	var spots := [[waters.bodies[0].at, waters.levels[0], "water", "the lake"], [river, float(line.top[line.at.size() / 3]), "water", "the river"], [waters.bodies[1].at, waters.levels[1], "lava", "the lava lake"]]
	for spot: Array in spots:
		var at: Vector2 = spot[0]
		await frames(int(Kart.RESET_SLOWDOWN_TIME * 60.0) + 10)
		var had := splashed.size()
		var kart := human.kart
		kart.global_transform = Transform3D(Basis.IDENTITY, Vector3(at.x, float(spot[1]) + 0.4, at.y))
		kart.linear_velocity = Vector3(0.0, -2.0, 6.0)
		kart.on_road = false
		var sank := false
		for i in 30:
			await frames(1)
			sank = sank or kart.sinking_left > 0.0
		check(sank and splashed.size() == had + 1 and splashed[splashed.size() - 1] == spot[2], "into %s the kart %s (%s)" % [spot[3], "burns" if spot[2] == "lava" else "sinks", splashed.slice(had)])

