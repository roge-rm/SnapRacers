extends Node

## Builds Peach Pit with a big painted lake, everything inside the loop of
## road, flat and on hills, and prints how many vertices and triangles the
## painted ground has and how long the course takes to build with and without
## it. It saves both courses in build/creations, big_lake_0.json and
## big_lake_10.json, and the same without the lake (_none), for race_perf.
## It needs a screen, since a headless run keeps no mesh data:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/perf/paint_perf.tscn

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/creations"))
	for hills in [0.0, 10.0]:
		var data = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
		data.hills = hills
		var track := TrackPath.from_dict(data)
		var loop := PackedVector2Array()
		for p in track.points:
			loop.append(Vector2(p.x, p.z))
		var areas := PaintedAreas.new()
		for z in range(-60, 60):
			for x in range(-60, 60):
				var sq := Vector2i(x, z)
				if Scenery.inside(loop, PaintedAreas.middle_of(sq)) and PaintedAreas.allowed(sq, "water", track):
					areas.set_square(sq, "water")
		data.paint = areas.to_dict()
		var f := FileAccess.open("res://build/creations/big_lake_%d.json" % int(hills), FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		track = TrackPath.from_dict(data)
		var builder := TrackBuilder.new(track)
		builder.sky = false
		var t0 := Time.get_ticks_msec()
		add_child(builder)
		var t1 := Time.get_ticks_msec()
		var meshes := 0
		var verts := 0
		var tris := 0
		for node in builder.find_children("*", "MultiMeshInstance3D", true, false):
			var mm := (node as MultiMeshInstance3D).multimesh
			if node.name.begins_with("Paint"):
				meshes += 1
				var arrays := mm.mesh.surface_get_arrays(0)
				verts += arrays[Mesh.ARRAY_VERTEX].size()
				tris += arrays[Mesh.ARRAY_INDEX].size() / 3
		print("hills %d: %d squares, %d painted meshes, %d vertices, %d triangles, built in %d ms" % [hills, areas.count(), meshes, verts, tris, t1 - t0])
		# Without paint, to compare.
		data.erase("paint")
		var none := FileAccess.open("res://build/creations/big_lake_%d_none.json" % int(hills), FileAccess.WRITE)
		none.store_string(JSON.stringify(data))
		none.close()
		var plain := TrackBuilder.new(TrackPath.from_dict(data))
		plain.sky = false
		var t2 := Time.get_ticks_msec()
		add_child(plain)
		print("  without paint built in %d ms" % (Time.get_ticks_msec() - t2))
		builder.free()
		plain.free()
	get_tree().quit()
