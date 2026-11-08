class_name CourseDesign
extends RefCounted

## A course you've built in the track editor, or are building. It's the same
## as a course that comes with the game (pieces clicked together one after
## another, see TrackPiece), plus the landmarks you've put down around it.
##
## Each one is saved as a file of its own in user://courses, with everything
## needed to race on it, so it can be sent to other players as it is.
##
## It knows what stops it being raced (problems()), how to finish the road
## off back to the start (close_up()), and where the start line should go
## (with_start_on_longest_straight()).

const FOLDER := "user://courses"
## The shortest lap worth racing, in metres.
const SHORTEST := 600.0
## Tiles of straight road the grid needs behind the start line.
const GRID_TILES := 2

var name := "My course"
var theme := "orchard"
var laps := 3
var width := TrackPath.WIDTH
## How much the ground rises and falls around it (see TrackPath.hills).
var hills := 0.0
## The weather and time of day it's raced in, unless the player picks (see
## Conditions).
var weather := Conditions.RANDOM
var time := Conditions.RANDOM
## Whether `time` is the only time of day it's raced at.
var fixed_time := false
## Who made it, from Settings.
var made_by := ""
## The pieces in order, as their specs (see TrackPiece.from_spec()).
var pieces: Array = []
## Landmarks you've put down: { "prop": "windmill", "at": [x, z], "facing": 0 }.
var landmarks: Array = []
## Where the start line is. Moving it to another straight keeps the road
## where it was, so this is wherever that straight is.
var start := Transform3D.IDENTITY


static func from_dict(data: Dictionary) -> CourseDesign:
	var c := CourseDesign.new()
	c.name = str(data.get("name", "My course"))
	c.theme = str(data.get("theme", "orchard"))
	c.laps = clampi(int(data.get("laps", 3)), 1, 9)
	c.width = float(data.get("width", TrackPath.WIDTH))
	c.hills = float(data.get("hills", 0.0))
	c.weather = str(data.get("weather", Conditions.RANDOM))
	c.time = str(data.get("time", Conditions.RANDOM))
	c.fixed_time = bool(data.get("fixed_time", false))
	c.made_by = str(data.get("made_by", ""))
	for spec in data.get("pieces", []):
		if spec is Dictionary:
			c.pieces.append(spec.duplicate())
	for mark in data.get("landmarks", []):
		if mark is Dictionary and Props.ROOM.has(str(mark.get("prop", ""))):
			c.landmarks.append(mark.duplicate())
	c.start = TrackPath.start_from(data.get("start", []))
	# One made before the tiles were kart sized comes out twice as big (see
	# TrackPath.from_dict()).
	var grow := TrackPath.growth(data)
	if grow != 1.0:
		c.width = TrackPath.WIDTH
		c.start.origin *= Vector3(grow, 1.0, grow)
		c.landmarks = TrackPath.grown_landmarks(c.landmarks, grow)
	return c


func to_dict() -> Dictionary:
	var heading := TrackPath.heading_of(start.basis)
	if heading < 0:
		push_error("Course starts must face a multiple of 15 degrees")
		return {}
	var turns: Variant = heading / 6 if heading % 6 == 0 else heading / 6.0
	var precise := heading % 6 != 0 or pieces.any(func(spec): return spec.get("type") == "arc")
	var position := [start.origin.x, start.origin.y, start.origin.z] if precise else [snappedf(start.origin.x, 0.01), snappedf(start.origin.y, 0.01), snappedf(start.origin.z, 0.01)]
	var out := {
		"name": name, "made_by": made_by, "theme": theme, "laps": laps, "width": width, "grid": TrackPiece.TILE,
		"start": position + [turns],
		"pieces": pieces.duplicate(true), "landmarks": landmarks.duplicate(true), "hills": hills,
	}
	if weather != Conditions.RANDOM:
		out.weather = weather
	if time != Conditions.RANDOM:
		out.time = time
	if fixed_time:
		out.fixed_time = true
	return out


func duplicate_design() -> CourseDesign:
	return from_dict(to_dict())


## A new course: a straight long enough for the grid, and the rest is yours.
static func starter() -> CourseDesign:
	var c := CourseDesign.new()
	c.pieces = [{"type": "straight", "length": 3}]
	return c


# Files.

static func load_file(path: String) -> CourseDesign:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return from_dict(data)


## Where a course with this name is kept.
static func path_for(course_name: String) -> String:
	var safe := ""
	for c in course_name.to_lower():
		safe += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	safe = safe.strip_edges().trim_prefix("_").trim_suffix("_")
	return "%s/%s.json" % [FOLDER, safe if safe != "" else "course"]


func save(path := "") -> String:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var to := path if path != "" else path_for(name)
	var file := FileAccess.open(to, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return to


## Every course you've saved, by path, in name order.
static func saved() -> Array[String]:
	var out: Array[String] = []
	# Nothing's been saved yet, so there's no folder.
	if not DirAccess.dir_exists_absolute(FOLDER):
		return out
	for file in DirAccess.get_files_at(FOLDER):
		if file.ends_with(".json"):
			out.append("%s/%s" % [FOLDER, file])
	out.sort()
	return out


# The course as a track.

## The course as a track to drive on, with the start line where it's been put.
func track() -> TrackPath:
	return TrackPath.from_dict(to_dict())


## What stops it being raced, as sentences. None means it's ready.
func problems() -> Array[String]:
	var out: Array[String] = []
	var path := track()
	if not path.closes:
		out.append("The road doesn't come back around to the start yet.")
	elif path.length < SHORTEST:
		out.append("A lap is only %d m. It needs to be at least %d m." % [roundi(path.length), roundi(SHORTEST)])
	if not path.clashes(5.0, true).is_empty():
		out.append("The road runs into itself.")
	if _below_ground(path):
		out.append("The road goes below the ground.")
	var crossing := LevelCrossing.problem(path)
	if crossing != "":
		out.append(crossing)
	var units := _units()
	var found := _best_run(units)
	if path.closes and _grid_split(units, found) < 0:
		out.append("The starting grid needs a ground-level straight connector with %d m behind it and %d m ahead." % [GRID_TILES * TrackPiece.TILE, TrackPiece.TILE])
	return out


func _below_ground(path: TrackPath) -> bool:
	# With hills, the ground under each point is the hill there, not the start.
	for k in path.points.size():
		var ground := path.grounds[k] if k < path.grounds.size() else 0.0
		if path.points[k].y < ground - 0.1:
			return true
	return false


# Where the start line goes.

## Plain full straights split into tiles. Every entry holds its spec and
## level, and half straights keep their original connectors.
func _units() -> Array:
	var units := []
	var level := 0
	for spec in pieces:
		if spec.get("type") == "straight" and not spec.has("surface") and not spec.has("edges"):
			for k in int(spec.get("length", 1)):
				units.append([{"type": "straight", "length": 1}, level])
		else:
			units.append([spec, level])
			if spec.get("type") in ["ramp", "curve", "arc", "slant"]:
				level += int(spec.get("rise", 0))
	return units


## Plain ground-level road length in tiles, including half tiles.
func _grid_length(unit: Array) -> float:
	var spec: Dictionary = unit[0]
	if unit[1] != 0 or spec.has("surface") or spec.has("edges"):
		return 0.0
	if spec.get("type") == "straight":
		return 1.0
	if spec.get("type") == "half_straight":
		return 0.5
	return 0.0


## The most tiles of plain straight road in a row at ground level, going
## around past the start if it has to.
func _longest_straight() -> float:
	return _best_run(_units())[1]


func _best_run(units: Array) -> Array:
	var n := units.size()
	var best := [0, 0.0]
	for i in n:
		if _grid_length(units[i]) == 0.0 or (i > 0 and _grid_length(units[i - 1]) > 0.0):
			continue
		var j := i
		var length := 0.0
		while j - i < n and _grid_length(units[j % n]) > 0.0:
			length += _grid_length(units[j % n])
			j += 1
		if length > best[1] or (length == best[1] and _grid_split(units, best) < 0 and _grid_split(units, [i, length]) >= 0):
			best = [i, length]
	return best


## Pick a connector with room for the grid behind and one tile ahead.
## Short unfinished courses can still move their line to the nearest one.
func _grid_split(units: Array, found: Array, require_room := true) -> int:
	if units.is_empty() or found[1] == 0.0:
		return -1
	var ahead := clampf(found[1] - GRID_TILES - 1.0, 1.0, 4.0)
	var target: float = found[1] - ahead
	var distance := 0.0
	var best := -1
	var gap := INF
	for step in units.size():
		var index: int = (found[0] + step) % units.size()
		var length := _grid_length(units[index])
		if length == 0.0 or distance >= found[1]:
			break
		if not require_room or (distance >= GRID_TILES and found[1] - distance >= 1.0):
			var difference := absf(distance - target)
			if difference < gap:
				best = index
				gap = difference
		distance += length
	return best


## The same course with its start line moved onto its longest straight, with
## the grid behind it and up to four tiles in front, so the pack spreads out
## before the first corner. The lap is the same, it just starts somewhere
## else. The course has to close for it to make sense.
func with_start_on_longest_straight() -> CourseDesign:
	var units := _units()
	var found := _best_run(units)
	var n := units.size()
	var copy := duplicate_design()
	if n == 0 or found[1] == 0:
		return copy
	var split := _grid_split(units, found)
	if split < 0:
		split = _grid_split(units, found, false)
	var turned := units.slice(split) + units.slice(0, split)
	copy.pieces.clear()
	var run := 0
	for unit in turned + [[null, 0]]:
		if unit[0] != null and unit[0].get("type") == "straight" and not unit[0].has("surface") and not unit[0].has("edges"):
			run += 1
			continue
		while run > 0:
			var chunk := mini(3, run)
			copy.pieces.append({"type": "straight", "length": chunk})
			run -= chunk
		if unit[0] != null:
			copy.pieces.append(unit[0])
	# The road stays where it is, so the start line goes where that straight
	# already was.
	copy.start = _pose_before(split, units)
	return copy


## Where the road is at the start of this unit, flat on the ground.
func _pose_before(index: int, units: Array) -> Transform3D:
	var pose := start
	for i in index:
		var piece := TrackPiece.from_spec(units[i][0])
		pose = TrackPath.advance_pose(pose, piece)
	pose.origin.y = start.origin.y
	return pose


# Closing it up.

## Pieces that would bring the end of the road back around to the start,
## facing the right way at the right height, without running into the road
## that's already there, or [] if nothing short enough will. Fewest pieces
## first, then the shortest road.
func close_up(most := 7, budget := 40000) -> Array:
	return CourseCloser.new(self).find(most, budget)
