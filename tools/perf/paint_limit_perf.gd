extends Node

## Times building Peach Pit with painted ground of a few sizes, flat and on
## hills, against the same course without it, to pick PaintedAreas.MOST_SQUARES.
## "blob" fills squares out from the middle of the course where they're
## allowed, "scatter" puts every other square in mixed types, the most edges
## a share code can ask for. Headless is fine:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tools/perf/paint_limit_perf.tscn

const SIZES := [500, 1000, 2000]


func _ready() -> void:
	for hills in [0.0, 10.0]:
		var data = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
		data.hills = hills
		var none := mini(_time(data), _time(data))
		print("hills %d: without paint %d ms, %d bytes sent" % [int(hills), none, var_to_bytes(data).size()])
		var track := TrackPath.from_dict(data)
		var middle := Vector2.ZERO
		for p in track.points:
			middle += Vector2(p.x, p.z)
		middle /= track.points.size()
		var centre := PaintedAreas.square_at(middle.x, middle.y)
		var ring := _spiral(centre, SIZES.max() * 4)
		for size: int in SIZES:
			for pattern in ["blob", "scatter"]:
				var areas := PaintedAreas.new()
				var types := PaintedAreas.TYPES.keys()
				for sq: Vector2i in ring:
					if areas.count() >= size:
						break
					if pattern == "blob":
						areas.set_square(sq, "water")
					elif (sq.x + sq.y) % 2 == 0:
						areas.set_square(sq, types[absi(sq.x * 3 + sq.y) % types.size()])
				data.paint = areas.to_dict()
				var took := mini(_time(data), _time(data))
				print("  %5d squares %-7s %5d ms (%d more), %d bytes sent" % [areas.count(), pattern, took, took - none, var_to_bytes(data).size()])
	get_tree().quit()


## Squares out from `centre` ring by ring.
func _spiral(centre: Vector2i, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [centre]
	var r := 1
	while out.size() < count:
		for x in range(-r, r + 1):
			out.append(centre + Vector2i(x, -r))
			out.append(centre + Vector2i(x, r))
		for z in range(-r + 1, r):
			out.append(centre + Vector2i(-r, z))
			out.append(centre + Vector2i(r, z))
		r += 1
	return out


func _time(data: Dictionary) -> int:
	var builder := TrackBuilder.new(TrackPath.from_dict(data))
	builder.sky = false
	var t0 := Time.get_ticks_msec()
	add_child(builder)
	var took := Time.get_ticks_msec() - t0
	builder.free()
	return took
