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
const SHORTEST := 300.0
## Tiles of straight road the grid needs behind the start line.
const GRID_TILES := 2

var name := "My course"
var theme := "orchard"
var laps := 3
var width := 10.0
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
	c.width = float(data.get("width", 10.0))
	c.made_by = str(data.get("made_by", ""))
	for spec in data.get("pieces", []):
		if spec is Dictionary:
			c.pieces.append(spec.duplicate())
	for mark in data.get("landmarks", []):
		if mark is Dictionary and Props.ROOM.has(str(mark.get("prop", ""))):
			c.landmarks.append(mark.duplicate())
	c.start = TrackPath.start_from(data.get("start", []))
	return c


func to_dict() -> Dictionary:
	var turns := roundi(start.basis.get_euler().y / (PI * 0.5))
	return {
		"name": name, "made_by": made_by, "theme": theme, "laps": laps, "width": width,
		"start": [snappedf(start.origin.x, 0.01), snappedf(start.origin.y, 0.01), snappedf(start.origin.z, 0.01), posmod(turns, 4)],
		"pieces": pieces.duplicate(true), "landmarks": landmarks.duplicate(true),
	}


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
	if not path.clashes().is_empty():
		out.append("The road runs into itself.")
	if _below_ground(path):
		out.append("The road goes below the ground.")
	if path.closes and _longest_straight() < GRID_TILES + 1:
		out.append("There's no straight long enough for the starting grid. It needs %d tiles in a row at ground level." % (GRID_TILES + 1))
	return out


func _below_ground(path: TrackPath) -> bool:
	for p in path.points:
		if p.y < -0.1:
			return true
	return false


# Where the start line goes.

## The pieces broken up so every tile of plain straight road is its own
## entry, each with the level it's at. Anything else is left whole.
func _units() -> Array:
	var units := []
	var level := 0
	for spec in pieces:
		if spec.get("type") == "straight" and not spec.has("surface") and not spec.has("edges"):
			for k in int(spec.get("length", 1)):
				units.append(["S", level])
		else:
			units.append([spec, level])
			if spec.get("type") in ["ramp", "curve", "slant"]:
				level += int(spec.get("rise", 0))
	return units


## The most tiles of plain straight road in a row at ground level, going
## around past the start if it has to.
func _longest_straight() -> int:
	return _best_run(_units())[1]


func _best_run(units: Array) -> Array:
	var n := units.size()
	var best := 0
	var best_len := 0
	for i in n:
		if units[i][0] is not String or units[i][1] != 0 or (units[i - 1][0] is String and units[i - 1][1] == 0):
			continue
		var j := i
		while units[j % n][0] is String and units[j % n][1] == 0 and j - i < n:
			j += 1
		if j - i > best_len:
			best = i
			best_len = j - i
	return [best, best_len]


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
	var ahead := maxi(1, mini(4, found[1] - GRID_TILES - 1))
	var split: int = (found[0] + found[1] - ahead) % n
	var turned := units.slice(split) + units.slice(0, split)
	copy.pieces.clear()
	var run := 0
	for unit in turned + [[null, 0]]:
		if unit[0] is String:
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
	copy.start = start * _pose_before(split, units)
	return copy


## Where the road is at the start of this unit, flat on the ground.
func _pose_before(index: int, units: Array) -> Transform3D:
	var pose := Transform3D.IDENTITY
	for i in index:
		var piece: TrackPiece
		if units[i][0] is String:
			piece = TrackPiece.from_spec({"type": "straight", "length": 1})
		else:
			piece = TrackPiece.from_spec(units[i][0])
		pose = pose * piece.exit()
	pose.origin.y = 0.0
	return pose


# Closing it up.

## Pieces that would bring the end of the road back around to the start,
## facing the right way at the right height, without running into the road
## that's already there, or [] if nothing short enough will. Fewest pieces
## first, then the shortest road.
func close_up(most := 7, budget := 40000) -> Array:
	return CourseCloser.new(self).find(most, budget)
