extends SceneTree

## Checks the seaside themes the track editor offers, and the island theme on
## every course that comes with the game: the shore goes all the way round
## the road and any landmarks with the beach clear of the road, the sea
## covers none of the land, and it all stays small enough for a phone.
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
		var shore := Scenery.island_shore(track)
		var inland := Scenery.largest(Geometry2D.offset_polygon(shore, -Scenery.BEACH))
		var box := Rect2(shore[0], Vector2.ZERO)
		for p in shore:
			box = box.expand(p)
		var far_box := box.grow(Scenery.SEA_OUT)
		var outline := PackedVector2Array([far_box.position, Vector2(far_box.end.x, far_box.position.y), far_box.end, Vector2(far_box.position.x, far_box.end.y)])
		var centre := Vector2(track.points[0].x, track.points[0].z)
		var sea := Scenery._ring_triangles(outline, shore, centre)
		var beach := Scenery._ring_triangles(shore, inland, centre)
		slowest = maxi(slowest, Time.get_ticks_msec() - started)
		most_shore = maxi(most_shore, shore.size())
		most_sea = maxi(most_sea, (sea.size() + beach.size()) / 3)
		# The road's edges stay inland of the beach.
		var dry := true
		for k in range(0, track.points.size(), 4):
			for side in [-1.0, 1.0]:
				var edge: Vector3 = track.points[k] + track.rights[k] * side * (track.width * 0.5 + TrackPath.KERB)
				dry = dry and Scenery.inside(inland, Vector2(edge.x, edge.z))
		check(dry, "%s: the road stays inland of the beach" % id)
		check(Scenery.inside(inland, Vector2(far.x, far.z)), "%s: a landmark 110 m out stands on the island" % id)
		# The sea and the land between them cover the whole square once.
		var area := 0.0
		for tris in [sea, beach]:
			for i in range(0, tris.size(), 3):
				area += absf((tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i])) * 0.5
		var whole := far_box.get_area() - absf(Scenery._area(inland))
		check(absf(area - whole) < whole * 0.001, "%s: the sea and beach have no gaps or overlaps (%.0f of %.0f m²)" % [id, area, whole])
		var wet := false
		for k in range(0, track.points.size(), 8):
			var p := Vector2(track.points[k].x, track.points[k].z)
			for i in range(0, sea.size(), 3):
				if Geometry2D.point_is_inside_triangle(p, sea[i], sea[i + 1], sea[i + 2]):
					wet = true
		check(not wet, "%s: no sea over the road" % id)
	check(most_shore < 1500, "the shore has at most %d corners" % most_shore)
	check(most_sea < 4000, "the sea and beach have at most %d triangles" % most_sea)
	check(slowest < 1000, "working the island out takes at most %d ms" % slowest)
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
	print("%d failed" % failures if failures > 0 else "All island checks passed.")
	quit(1 if failures > 0 else 0)
