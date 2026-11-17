extends SceneTree

## Checks the seaside themes the track editor offers, and the island theme on
## every course that comes with the game: the shore goes all the way round
## the road and any landmarks, the runoff is all sand with the sea just past
## it, the sea covers none of the land, and it all stays small enough for a
## phone. A home-made course that curls round on itself gets its sea right
## too.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/island_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var known := true
	for id in TrackEditorUI.THEME_NAMES:
		known = known and Scenery.THEMES.has(id)
	check(known, "every theme the editor offers is a theme we know")
	for id in ["gran_canaria", "sardinia", "malta", "phillip_island", "island"]:
		check(TrackEditorUI.THEME_NAMES.has(id), "the editor offers %s as %s" % [id, TrackEditorUI.THEME_NAMES.get(id, "nothing")])
	var most_shore := 0
	var most_sea := 0
	var slowest := 0
	for id in Tracks.all():
		var data = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(id)))
		data.theme = "island"
		# A hand-placed landmark well out from the road, which the island
		# has to reach.
		var track := TrackPath.from_dict(data)
		var far := track.points[0] + track.rights[0] * 110.0
		data.landmarks = data.get("landmarks", []) + [{"prop": "lighthouse", "at": [far.x, far.z], "facing": 0}]
		track = TrackPath.from_dict(data)
		var started := Time.get_ticks_msec()
		var made := _island(track, id)
		slowest = maxi(slowest, Time.get_ticks_msec() - started)
		var shore: PackedVector2Array = made[0]
		most_shore = maxi(most_shore, shore.size())
		most_sea = maxi(most_sea, made[1])
		check(Scenery.inside(made[2], Vector2(far.x, far.z)), "%s: a landmark 110 m out stands on the island" % id)
		# The runoff past the kerbs is all land, and the sea comes in close
		# past it, nearer than a kart can wander before it's put back.
		var runoff_dry := true
		var near := 0
		var samples := 0
		# Where the road runs, by 8 m square, so a side with another stretch
		# of road close by (where the island fills in between) is left out.
		var road := {}
		for j in range(0, track.points.size(), 2):
			var cell := Vector2i(floori(track.points[j].x / 8.0), floori(track.points[j].z / 8.0))
			if not road.has(cell):
				road[cell] = []
			road[cell].append(track.distances[j])
		for k in range(0, track.points.size(), 4):
			var lanes := track.lanes_of(k)
			for side in [-1.0, 1.0]:
				var edge := lanes[0].x if side < 0.0 else lanes[lanes.size() - 1].y
				var runoff: Vector3 = track.points[k] + track.rights[k] * (edge + side * (TrackPath.KERB + Race.RUNOFF))
				runoff_dry = runoff_dry and Scenery.inside(shore, Vector2(runoff.x, runoff.z))
				var wet: Vector3 = track.points[k] + track.rights[k] * (edge + side * 21.0)
				if _other_road_near(road, wet, track.distances[k], track.length):
					continue
				samples += 1
				if not Scenery.inside(shore, Vector2(wet.x, wet.z)):
					near += 1
		check(runoff_dry, "%s: the runoff is all on the island" % id)
		check(near > samples * 0.125, "%s: the sea's within 21 m of the road along much of it (%d of %d open sides)" % [id, near, samples])
	check(most_shore < 1500, "the shore has at most %d corners" % most_shore)
	check(most_sea < 4000, "the sea and beach have at most %d triangles" % most_sea)
	check(slowest < 1000, "working the island out takes at most %d ms" % slowest)
	_curled()
	_lagoon()
	# A hilly island eases down to just under the sea at the shore.
	var data = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(Tracks.all()[0])))
	data.theme = "island"
	data.hills = 16.0
	var hilly := TrackPath.from_dict(data)
	var terrain := Terrain.new(hilly, Scenery.REACH + 45.0)
	var shore := Scenery.island_shore(hilly)
	var level := Scenery.island_level(hilly, shore)
	var under := true
	for i in range(0, shore.size(), 3):
		var p := shore[i]
		under = under and terrain.height_at(p.x, p.y) < level + 0.05
	check(under, "a hilly island's ground is under the sea at the shore (%.1f m)" % level)
	terrain.free()
	# So does one on a ground map, with the sea as low as the map at the shore.
	var mapped_data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/ground_course.json"))
	mapped_data.theme = "island"
	var mapped := TrackPath.from_dict(mapped_data)
	terrain = Terrain.new(mapped, Scenery.REACH + 45.0)
	shore = Scenery.island_shore(mapped)
	level = Scenery.island_level(mapped, shore)
	under = true
	var lowest := INF
	for i in range(0, shore.size(), 3):
		var p := shore[i]
		under = under and terrain.height_at(p.x, p.y) < level + 0.05
		lowest = minf(lowest, mapped.ground_height(p.x, p.y))
	check(under and level <= lowest + 0.001, "an island on a ground map is under the sea at the shore (%.1f m)" % level)
	terrain.free()
	print("%d failed" % failures if failures > 0 else "All island checks passed.")
	quit(1 if failures > 0 else 0)


## Works out the island round a course and checks the road's inland of the
## beach, the sea and beach cover the square round it once and there's no
## sea over the road. Returns [shore, triangles, inland].
func _island(track: TrackPath, id: String) -> Array:
	var shore := Scenery.island_shore(track)
	var inland := Scenery.largest(Geometry2D.offset_polygon(shore, -Scenery.ISLAND_BEACH))
	var box := Rect2(shore[0], Vector2.ZERO)
	for p in shore:
		box = box.expand(p)
	var far_box := box.grow(Scenery.SEA_OUT)
	var outline := PackedVector2Array([far_box.position, Vector2(far_box.end.x, far_box.position.y), far_box.end, Vector2(far_box.position.x, far_box.end.y)])
	var centre := Vector2(track.points[0].x, track.points[0].z)
	var sea := Scenery._ring_triangles(outline, shore, centre)
	var beach := Scenery._ring_triangles(shore, inland, centre)
	# The road's edges stay inland of the beach.
	var dry := true
	for k in range(0, track.points.size(), 4):
		var lanes := track.lanes_of(k)
		for edge in [lanes[0].x - TrackPath.KERB, lanes[lanes.size() - 1].y + TrackPath.KERB]:
			var at: Vector3 = track.points[k] + track.rights[k] * edge
			dry = dry and Scenery.inside(inland, Vector2(at.x, at.z))
	check(dry, "%s: the road stays inland of the beach" % id)
	_covers(id, far_box, inland, sea, beach)
	var wet := false
	for k in range(0, track.points.size(), 8):
		var p := Vector2(track.points[k].x, track.points[k].z)
		for i in range(0, sea.size(), 3):
			# Slivers with no area say every point's inside them.
			if absf((sea[i + 1] - sea[i]).cross(sea[i + 2] - sea[i])) > 0.01 and Geometry2D.point_is_inside_triangle(p, sea[i], sea[i + 1], sea[i + 2]):
				wet = true
	check(not wet, "%s: no sea over the road" % id)
	return [shore, (sea.size() + beach.size()) / 3, inland]


## The sea and the land between them cover the whole square once.
func _covers(id: String, far_box: Rect2, inland: PackedVector2Array, sea: PackedVector2Array, beach: PackedVector2Array) -> void:
	var area := 0.0
	for tris in [sea, beach]:
		for i in range(0, tris.size(), 3):
			area += absf((tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i])) * 0.5
	var whole := far_box.get_area() - absf(Scenery._area(inland))
	check(absf(area - whole) < whole * 0.001, "%s: the sea and beach have no gaps or overlaps (%.0f of %.0f m²)" % [id, area, whole])


## A home-made course that spirals in on itself, and a hook of land round a
## bay with the cuts made from a spot outside it, which leaves bits of land
## clear of the first cuts.
func _curled() -> void:
	var spiral := TrackPath.from_dict({"name": "Curled", "theme": "island", "width": 13.0, "grid": 32, "pieces": [
		{"type": "straight", "length": 8}, {"type": "curve", "turn": "right", "size": 2},
		{"type": "straight", "length": 7}, {"type": "curve", "turn": "right", "size": 2},
		{"type": "straight", "length": 7}, {"type": "curve", "turn": "right", "size": 2},
		{"type": "straight", "length": 5}, {"type": "curve", "turn": "right", "size": 2},
		{"type": "straight", "length": 4}, {"type": "curve", "turn": "right", "size": 1},
		{"type": "straight", "length": 2},
	]})
	_island(spiral, "a course that curls round on itself")
	# A C of land round a bay, open to the east, and the cuts from a spot in
	# the bay, so the C's back and ends sit in the quarters on their own.
	var hook := PackedVector2Array()
	for i in 25:
		var a := deg_to_rad(40.0 + i * 280.0 / 24.0)
		hook.append(Vector2(cos(a), sin(a)) * 200.0)
	for i in 25:
		var a := deg_to_rad(320.0 - i * 280.0 / 24.0)
		hook.append(Vector2(cos(a), sin(a)) * 120.0)
	var far_box := Rect2(-1000.0, -1000.0, 2000.0, 2000.0)
	var outline := PackedVector2Array([far_box.position, Vector2(far_box.end.x, far_box.position.y), far_box.end, Vector2(far_box.position.x, far_box.end.y)])
	for centre in [Vector2.ZERO, Vector2(600.0, 500.0)]:
		var sea := Scenery._ring_triangles(outline, hook, centre)
		var area := 0.0
		var over := false
		for i in range(0, sea.size(), 3):
			var size := absf((sea[i + 1] - sea[i]).cross(sea[i + 2] - sea[i])) * 0.5
			area += size
			if size < 0.01:
				continue
			for spot in [Vector2(-160.0, 0.0), Vector2(0.0, 160.0), Vector2(0.0, -160.0), Vector2(110.0, 120.0)]:
				over = over or Geometry2D.point_is_inside_triangle(spot, sea[i], sea[i + 1], sea[i + 2])
		var whole := far_box.get_area() - absf(Scenery._area(hook))
		check(absf(area - whole) < whole * 0.001 and not over, "a hook of land cut from %s gets sea all round it and none over it (%.0f of %.0f m²)" % [centre, area, whole])


## Whether road more than 100 m further round the lap passes within about
## 40 m of `at`, from the squares in `road` (see above).
func _other_road_near(road: Dictionary, at: Vector3, along: float, length: float) -> bool:
	var middle := Vector2i(floori(at.x / 8.0), floori(at.z / 8.0))
	for dz in range(-5, 6):
		for dx in range(-5, 6):
			for d in road.get(middle + Vector2i(dx, dz), []):
				if absf(wrapf(float(d) - along, -length * 0.5, length * 0.5)) > 100.0:
					return true
	return false


## Painted water inside the loop of road on an island makes a lagoon: it's
## deep water, nothing stands in it, and squares painted out past the shore
## are left out.
func _lagoon() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
	data.theme = "island"
	data.hills = 0.0
	# Its own landmarks stand inside the loop, so they go.
	data.erase("landmarks")
	var track := TrackPath.from_dict(data)
	var loop := PackedVector2Array()
	var middle := Vector2.ZERO
	for p in track.points:
		loop.append(Vector2(p.x, p.z))
		middle += Vector2(p.x, p.z) / track.points.size()
	var areas := PaintedAreas.new()
	var inside := 0
	# A band across the loop, to stay under PaintedAreas.MOST_SQUARES.
	for z in range(-15, 15):
		for x in range(-60, 60):
			var square := Vector2i(x, z)
			if Scenery.inside(loop, PaintedAreas.middle_of(square)) and PaintedAreas.allowed(square, "water", track):
				areas.set_square(square, "water")
				inside += 1
	# And a row of squares far out to sea.
	var far := track.points[0] + track.rights[0] * 300.0
	for n in 4:
		areas.set_square(PaintedAreas.square_at(far.x + n * 8.0, far.z), "water")
	data.paint = areas.to_dict()
	track = TrackPath.from_dict(data)
	var kept := Scenery.paint_of(track)
	check(inside > 20 and kept.count() == inside, "an island keeps the %d squares inside its shore and drops the 4 out at sea (kept %d)" % [inside, kept.count()])
	# Built straight away, off the tree, since a -s script's tree only gets
	# going after this.
	var scenery := Scenery.new(track, track.theme)
	scenery._ready()
	var deep := 0
	var standing := 0
	var dry_wet := 0
	for square: Vector2i in kept.squares:
		var at := PaintedAreas.middle_of(square)
		if not kept.inside(at.x, at.y):
			continue
		if is_finite(scenery.water.level_at(Vector3(at.x, 0.3, at.y))) and scenery.water.kind == "water":
			deep += 1
		if scenery._inside_hall(Vector3(at.x, 0.0, at.y), 1.0):
			dry_wet += 1
	for spot in scenery._placed:
		if kept.covered(spot[0]):
			standing += 1
	var middles := kept.squares.keys().filter(func(s: Vector2i) -> bool: var m := PaintedAreas.middle_of(s); return kept.inside(m.x, m.y))
	check(deep == middles.size(), "the lagoon is deep water all over (%d of %d)" % [deep, middles.size()])
	check(dry_wet == 0, "and none of it counts as dry land")
	check(standing == 0, "nothing's put down in it (%d)" % standing)
	var drawn: Array[String] = []
	for child in scenery.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("Paint"):
			drawn.append(child.name)
	check(drawn == ["Paint water", "Paint water edge"], "the lagoon is drawn as one mesh and its sandy edge another (%s)" % str(drawn))
	scenery.free()
