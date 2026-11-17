class_name CourseOutline
extends RefCounted

## The shape of a course seen from above, for the course map in a race and the
## cards on the cup and course screens. Working one out means building the
## whole course, which is slow on a phone, so each one is kept while the game
## runs and saved too, under what's in the course's file. Then it only gets
## worked out again when the course changes.
##
## An outline is { name, summary, line, heights, start, across, loops, splits,
## paint, box }: the course's name and a line about it (see describe()), the middle
## of the road as (x, z) points that come back round to the first, how high
## the road is at each, where the start line is and which way is across it
## there, where any loops and corkscrews are, each split's branches (see
## _splits_of()), the painted ground as runs (see PaintedAreas.to_dict()), and
## the box around it all.

const SAVED := "user://pictures/outlines"
## Every how many of the course's samples (a metre apart) go in the line.
const EVERY := 4
## Goes up when outlines are worked out differently, so the saved ones go.
const LOOK := 5
## The island's colour, drawn between a split's branches.
const ISLAND := Color("#4b9f4a")

static var _kept := {}
static var _tidied := false


## The outline of the course in this file.
static func of(path: String) -> Dictionary:
	var key := _key(path)
	if _kept.has(key):
		return _kept[key]
	var text := ""
	var saved := ""
	# A released game's own courses only change with its version, so they're
	# saved under that and their path, which saves reading and hashing them.
	# Debug builds go by what's in the file, so edited courses show.
	if path.begins_with("res://") and OS.has_feature("template") and not OS.is_debug_build():
		saved = "%s/%d-%s-%s.json" % [SAVED, LOOK, ProjectSettings.get_setting("application/config/version", ""), path.md5_text()]
	else:
		text = FileAccess.get_file_as_string(path)
		saved = "%s/%d-%s.json" % [SAVED, LOOK, text.md5_text()]
	var outline := _read(saved)
	if outline.is_empty():
		if text == "":
			text = FileAccess.get_file_as_string(path)
		var data = JSON.parse_string(text)
		var track := TrackPath.from_dict(data) if typeof(data) == TYPE_DICTIONARY else TrackPath.new()
		outline = of_track(track)
		_write(saved, outline)
	_kept[key] = outline
	return outline


## Whether the outline of this course is ready without working anything out.
static func is_ready(path: String) -> bool:
	return _kept.has(_key(path))


## The outline of a course that's already built.
static func of_track(track: TrackPath) -> Dictionary:
	var line := PackedVector2Array()
	var heights := PackedFloat32Array()
	var loops: Array[Vector2] = []
	var last_piece := -1
	for k in range(0, track.points.size(), EVERY):
		var point := track.points[k]
		line.append(Vector2(point.x, point.z))
		heights.append(point.y)
	for k in track.points.size():
		var piece := track.piece_of[k] if k < track.piece_of.size() else -1
		if piece != last_piece and piece >= 0 and piece < track.pieces.size() and TrackPiece.turns_over(track.pieces[piece].type):
			loops.append(Vector2(track.points[k].x, track.points[k].z))
		last_piece = piece
	if line.is_empty():
		line.append(Vector2.ZERO)
		heights.append(0.0)
	line.append(line[0])
	heights.append(heights[0])
	var rotation := deg_to_rad(track.map_rotation)
	var box := Rect2(line[0].rotated(rotation), Vector2.ZERO)
	for p in line:
		box = box.expand(p.rotated(rotation))
	var across := Vector2(track.start.basis.x.x, track.start.basis.x.z)
	return {
		"name": track.name, "summary": describe(track), "map_rotation": track.map_rotation,
		"line": line, "heights": heights, "loops": loops, "splits": _splits_of(track), "box": box,
		"paint": track.paint.to_dict().runs,
		"start": line[0], "across": across.normalized() if across.length() > 0.01 else Vector2.RIGHT,
	}


## Each split as { middle, across, left, right }: points down its middle line
## as (x, z), which way is right there, and how far right of the middle each
## branch's middle is, in metres.
static func _splits_of(track: TrackPath) -> Array:
	var out := []
	if not track.has_splits:
		return out
	var count := track.points.size()
	# From a sample off any split, so one across the start isn't cut in two.
	var first := 0 if not track.closes else -1
	for k in count:
		if first < 0 and not track.split_sample(k):
			first = k
	if first < 0:
		return out
	var split := {}
	for n in count + (1 if track.closes else 0):
		var k := (first + n) % count
		var on := track.split_sample(k)
		if not on and split.is_empty():
			continue
		if split.is_empty():
			split = {"middle": PackedVector2Array(), "across": PackedVector2Array(), "left": PackedFloat32Array(), "right": PackedFloat32Array()}
		# Every EVERY samples, and the one just past the end, where the
		# branches have met up again.
		if not on or split.middle.is_empty() or n % EVERY == 0:
			split.middle.append(Vector2(track.points[k].x, track.points[k].z))
			split.across.append(Vector2(track.rights[k].x, track.rights[k].z).normalized())
			split.left.append(track.branch_lefts[k].x)
			split.right.append(track.branch_rights[k].x)
		if not on:
			out.append(split)
			split = {}
	if not split.is_empty():
		out.append(split)
	return out


## Draws the splits of an outline over its road, already drawn with `to_view`:
## the two branches `width` thick with `edge` round them and the island
## between them. On a small map the branches are spread out to at least a
## few lines apart, so the island shows.
static func draw_splits(item: CanvasItem, outline: Dictionary, to_view: Transform2D, width: float, edge_width: float, road: Color, edge: Color) -> void:
	var scale := to_view.basis_xform(Vector2.RIGHT).length()
	var least := width * 1.3
	for split: Dictionary in outline.get("splits", []):
		var widest := 0.001
		for n in split.middle.size():
			widest = maxf(widest, maxf(-split.left[n], split.right[n]))
		var sides := [PackedVector2Array(), PackedVector2Array()]
		for n in split.middle.size():
			var at: Vector2 = to_view * (split.middle[n] as Vector2)
			var right: Vector2 = to_view.basis_xform(split.across[n]).normalized()
			for side in 2:
				var metres: float = split.left[n] if side == 0 else split.right[n]
				var pixels := signf(metres) * maxf(absf(metres) * scale, least * absf(metres) / widest)
				sides[side].append(at + right * pixels)
		if sides[0].size() < 2:
			continue
		var island: PackedVector2Array = sides[0].duplicate()
		var back: PackedVector2Array = sides[1].duplicate()
		back.reverse()
		island.append_array(back)
		for side in sides:
			item.draw_polyline(side, edge, edge_width, true)
		# The road's own line runs down the middle, so the island covers it.
		item.draw_colored_polygon(island, ISLAND)
		for side in sides:
			item.draw_polyline(side, road, width, true)


## Fills the painted squares of an outline in their colours, drawn with
## `to_view`.
static func draw_paint(item: CanvasItem, outline: Dictionary, to_view: Transform2D) -> void:
	var cell := PaintedAreas.CELL
	for run in outline.get("paint", []):
		var type := str(run[3])
		if not PaintedAreas.TYPES.has(type):
			continue
		var low := Vector2(float(run[1]), float(run[0])) * cell
		var wide := Vector2(float(run[2]) * cell, cell)
		var corners := PackedVector2Array([to_view * low, to_view * (low + Vector2(wide.x, 0.0)), to_view * (low + wide), to_view * (low + Vector2(0.0, wide.y))])
		item.draw_colored_polygon(corners, PaintedAreas.TYPES[type].colour)


## The game's own courses never change while it runs, but yours can.
static func _key(path: String) -> String:
	if path.begins_with("user://"):
		return "%s %s" % [path, FileAccess.get_file_as_string(path).md5_text()]
	return path


static func _read(saved: String) -> Dictionary:
	if not FileAccess.file_exists(saved):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(saved))
	if typeof(data) != TYPE_DICTIONARY or not data.has("line") or not data.has("summary"):
		return {}
	var line := PackedVector2Array()
	for i in range(0, data.line.size() - 1, 2):
		line.append(Vector2(data.line[i], data.line[i + 1]))
	var loops: Array[Vector2] = []
	for i in range(0, data.loops.size() - 1, 2):
		loops.append(Vector2(data.loops[i], data.loops[i + 1]))
	if line.size() < 2:
		return {}
	var splits := []
	for split in data.get("splits", []):
		if not split is Dictionary:
			continue
		var middle := PackedVector2Array()
		var across := PackedVector2Array()
		for i in range(0, split.get("middle", []).size() - 1, 2):
			middle.append(Vector2(split.middle[i], split.middle[i + 1]))
			across.append(Vector2(split.across[i], split.across[i + 1]))
		splits.append({"middle": middle, "across": across, "left": PackedFloat32Array(split.get("left", [])), "right": PackedFloat32Array(split.get("right", []))})
	var rotation := deg_to_rad(float(data.get("map_rotation", 0.0)))
	var box := Rect2(line[0].rotated(rotation), Vector2.ZERO)
	for p in line:
		box = box.expand(p.rotated(rotation))
	return {
		"name": str(data.get("name", "")), "summary": str(data.summary), "map_rotation": float(data.get("map_rotation", 0.0)),
		"line": line, "heights": PackedFloat32Array(data.heights), "loops": loops, "splits": splits, "box": box,
		"paint": data.get("paint", []),
		"start": line[0], "across": Vector2(data.across[0], data.across[1]),
	}


static func _write(saved: String, outline: Dictionary) -> void:
	var flat := func(points: Array) -> Array:
		var out := []
		for p in points:
			out.append(snappedf(p.x, 0.1))
			out.append(snappedf(p.y, 0.1))
		return out
	var heights := []
	for h in outline.heights:
		heights.append(snappedf(h, 0.1))
	var splits := []
	for split in outline.get("splits", []):
		var across := []
		for p in split.across:
			across.append(snappedf(p.x, 0.001))
			across.append(snappedf(p.y, 0.001))
		splits.append({"middle": flat.call(Array(split.middle)), "across": across,
			"left": Array(split.left).map(func(n): return snappedf(n, 0.1)), "right": Array(split.right).map(func(n): return snappedf(n, 0.1))})
	DirAccess.make_dir_recursive_absolute(SAVED)
	_tidy()
	var file := FileAccess.open(saved, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"name": outline.name, "summary": outline.summary, "map_rotation": outline.get("map_rotation", 0.0),
		"line": flat.call(Array(outline.line)), "heights": heights, "loops": flat.call(outline.loops), "splits": splits,
		"across": [outline.across.x, outline.across.y], "paint": outline.get("paint", []),
	}))


## Deletes outlines saved by other versions of the game, once a run. Names
## are LOOK-md5 or LOOK-version-md5.
static func _tidy() -> void:
	if _tidied:
		return
	_tidied = true
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	for name in DirAccess.get_files_at(SAVED):
		var parts := name.get_basename().split("-")
		if parts[0] != str(LOOK) or (parts.size() == 3 and parts[1] != version):
			DirAccess.remove_absolute("%s/%s" % [SAVED, name])


## A line saying what's on a track, like "1866 m, 3 laps, a bridge and a jump".
static func describe(track: TrackPath) -> String:
	var things := []
	var has := func(what: Callable) -> bool:
		return track.pieces.any(what)
	var loops := track.pieces.filter(func(p): return p.type == "loop").size()
	if loops > 0:
		things.append("a loop" if loops == 1 else "two loops" if loops == 2 else "%d loops" % loops)
	if has.call(func(p): return p.type == "corkscrew"):
		things.append("a corkscrew")
	if has.call(func(p): return p.type in ["curve", "arc"] and p.sticky):
		things.append("a wall ride")
	if crosses_over(track):
		things.append("a bridge")
	if has.call(func(p): return p.type == "jump"):
		things.append("a jump")
	if has.call(func(p): return p.cut):
		things.append("a shortcut")
	if has.call(func(p): return p.crossing):
		things.append("a level crossing")
	if has.call(func(p): return p.is_split()):
		things.append("a split")
	var text := "%d m, %d laps" % [roundi(track.length), track.laps]
	if not things.is_empty():
		var last: String = things.pop_back()
		text += ", " + (", ".join(things) + " and " if not things.is_empty() else "") + last
	return text


## Whether the road goes over itself anywhere, on a bridge. Loops and
## corkscrews go over themselves too, but they aren't bridges, and road that's
## only high up because of the hills isn't either.
static func crosses_over(track: TrackPath) -> bool:
	var cell := track.width
	var spots := {}
	for k in range(0, track.points.size(), 3):
		var piece := track.piece_of[k] if k < track.piece_of.size() else -1
		if piece >= 0 and piece < track.pieces.size() and TrackPiece.turns_over(track.pieces[piece].type):
			continue
		var p := track.points[k]
		var key := Vector2i(floori(p.x / cell), floori(p.z / cell))
		for x in range(key.x - 1, key.x + 2):
			for z in range(key.y - 1, key.y + 2):
				for other in spots.get(Vector2i(x, z), []):
					var q := track.points[other]
					var apart := absf(track.distances[k] - track.distances[other])
					apart = minf(apart, track.length - apart)
					if apart > 60.0 and Vector2(p.x - q.x, p.z - q.z).length() < track.width * 0.5 and absf(p.y - q.y) > 3.0:
						return true
		spots.get_or_add(key, []).append(k)
	return false


## Fits an outline into a rect, keeping its shape and chosen map orientation.
static func fit(outline: Dictionary, rect: Rect2, margin: float) -> Transform2D:
	var box: Rect2 = outline.box
	var room := rect.size - Vector2.ONE * margin * 2.0
	var scale := minf(room.x / maxf(box.size.x, 1.0), room.y / maxf(box.size.y, 1.0))
	var offset := rect.position + Vector2.ONE * margin + (room - box.size * scale) * 0.5
	return Transform2D(0.0, Vector2(scale, scale), 0.0, offset - box.position * scale) * Transform2D(deg_to_rad(float(outline.get("map_rotation", 0.0))), Vector2.ZERO)
