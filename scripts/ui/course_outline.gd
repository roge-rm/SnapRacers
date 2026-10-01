class_name CourseOutline
extends RefCounted

## The shape of a course seen from above, for the course map in a race and the
## cards on the cup and course screens. Working one out means building the
## whole course, which is slow on a phone, so each one is kept while the game
## runs and saved too, under what's in the course's file. Then it only gets
## worked out again when the course changes.
##
## An outline is { name, summary, line, heights, start, across, loops, box }:
## the course's name and a line about it (see describe()), the middle of the
## road as (x, z) points that come back round to the first, how high the road
## is at each, where the start line is and which way is across it there, where
## any loops and corkscrews are, and the box around it all.

const SAVED := "user://pictures/outlines"
## Every how many of the course's samples (a metre apart) go in the line.
const EVERY := 4
## Goes up when outlines are worked out differently, so the saved ones go.
const LOOK := 1

static var _kept := {}


## The outline of the course in this file.
static func of(path: String) -> Dictionary:
	var key := _key(path)
	if _kept.has(key):
		return _kept[key]
	var text := FileAccess.get_file_as_string(path)
	var saved := "%s/%d-%s.json" % [SAVED, LOOK, text.md5_text()]
	var outline := _read(saved)
	if outline.is_empty():
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
	var box := Rect2(line[0], Vector2.ZERO)
	for p in line:
		box = box.expand(p)
	var across := Vector2(track.start.basis.x.x, track.start.basis.x.z)
	return {
		"name": track.name, "summary": describe(track),
		"line": line, "heights": heights, "loops": loops, "box": box,
		"start": line[0], "across": across.normalized() if across.length() > 0.01 else Vector2.RIGHT,
	}


## The game's own courses never change while it runs, but yours can.
static func _key(path: String) -> String:
	if path.begins_with("user://"):
		return "%s %d" % [path, FileAccess.get_modified_time(path)]
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
	var box := Rect2(line[0], Vector2.ZERO)
	for p in line:
		box = box.expand(p)
	return {
		"name": str(data.get("name", "")), "summary": str(data.summary),
		"line": line, "heights": PackedFloat32Array(data.heights), "loops": loops, "box": box,
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
	DirAccess.make_dir_recursive_absolute(SAVED)
	var file := FileAccess.open(saved, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"name": outline.name, "summary": outline.summary,
		"line": flat.call(Array(outline.line)), "heights": heights, "loops": flat.call(outline.loops),
		"across": [outline.across.x, outline.across.y],
	}))


## A line saying what's on a track, like "1866 m, 3 laps, a bridge and a jump".
static func describe(track: TrackPath) -> String:
	var things := []
	var has := func(what: Callable) -> bool:
		return track.pieces.any(what)
	if has.call(func(p): return p.type == "loop"):
		things.append("a loop")
	if has.call(func(p): return p.type == "corkscrew"):
		things.append("a corkscrew")
	if has.call(func(p): return p.type == "curve" and p.sticky):
		things.append("a wall ride")
	var highest := 0.0
	for point in track.points:
		highest = maxf(highest, point.y)
	if highest > 4.0 and not has.call(func(p): return TrackPiece.turns_over(p.type)):
		things.append("a bridge")
	if has.call(func(p): return p.type == "jump"):
		things.append("a jump")
	if has.call(func(p): return p.cut):
		things.append("a shortcut")
	var text := "%d m, %d laps" % [roundi(track.length), track.laps]
	if not things.is_empty():
		var last: String = things.pop_back()
		text += ", " + (", ".join(things) + " and " if not things.is_empty() else "") + last
	return text


## Fits an outline into a rect, keeping its shape, with north up.
static func fit(outline: Dictionary, rect: Rect2, margin: float) -> Transform2D:
	var box: Rect2 = outline.box
	var room := rect.size - Vector2.ONE * margin * 2.0
	var scale := minf(room.x / maxf(box.size.x, 1.0), room.y / maxf(box.size.y, 1.0))
	var offset := rect.position + Vector2.ONE * margin + (room - box.size * scale) * 0.5
	return Transform2D(0.0, Vector2(scale, scale), 0.0, offset - box.position * scale)
