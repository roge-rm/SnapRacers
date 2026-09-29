class_name CupDesign
extends RefCounted

## A Grand Prix cup of your own: a name and 2 to 8 races, raced in order,
## on the game's courses and ones you've built.
##
## It's saved as one file in user://cups with every course in it, so it can
## be sent to other players as it is. The game's own courses are raced from
## the game. Yours are raced from the copy in the cup, so changing a course
## later doesn't change a cup you've already made with it.

const FOLDER := "user://cups"
## Where the courses in a cup are put to be raced.
const PLAYING := "user://cups/playing"
const FEWEST := 2
const MOST := 8

var name := "My cup"
var made_by := ""
## The races in order, each { "from": where the course came from, "course":
## the course itself }.
var races: Array = []


static func from_dict(data: Dictionary) -> CupDesign:
	var c := CupDesign.new()
	c.name = str(data.get("name", "My cup"))
	c.made_by = str(data.get("made_by", ""))
	for race in data.get("races", []):
		if race is Dictionary and race.get("course") is Dictionary:
			c.races.append({"from": str(race.get("from", "")), "course": race.course.duplicate(true)})
	return c


func to_dict() -> Dictionary:
	return {"name": name, "made_by": made_by, "races": races.duplicate(true)}


static func load_file(path: String) -> CupDesign:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(data) if data is Dictionary else null


## Where a cup with this name is kept.
static func path_for(cup_name: String) -> String:
	return CourseDesign.path_for(cup_name).replace(CourseDesign.FOLDER, FOLDER)


func save(path := "") -> String:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var to := path if path != "" else path_for(name)
	var file := FileAccess.open(to, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return to


## Every cup you've saved, by path, in name order.
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


## Adds a race on the course in this file, if there's room.
func add(path: String) -> bool:
	if races.size() >= MOST:
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	races.append({"from": path, "course": data})
	return true


## What's wrong with it, or "" if it's ready to race.
func problem() -> String:
	if races.size() < FEWEST:
		return "A cup needs at least %d races." % FEWEST
	for race in races:
		# The game's own courses are raced as they are, so only yours get checked.
		if str(race.from).begins_with(Tracks.FOLDER):
			continue
		if not CourseDesign.from_dict(race.course).problems().is_empty():
			return "%s isn't finished." % str(race.course.get("name", "A course"))
	return ""


func course_names() -> Array:
	return races.map(func(r): return str(r.course.get("name", "Course")))


## The cup the way a Grand Prix wants it: { "id", "name", "paths" }. The
## game's courses are raced from the game, and yours are written out from
## the cup to be raced.
func to_cup(id: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(PLAYING)
	var paths := []
	for i in races.size():
		var from: String = races[i].from
		if from.begins_with(Tracks.FOLDER):
			paths.append(from)
			continue
		var to := "%s/%s_%d.json" % [PLAYING, id, i + 1]
		var file := FileAccess.open(to, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(races[i].course))
		paths.append(to)
	return {"id": id, "name": name, "paths": paths}


## A cup's id, for its trophies: "mine_" and its file name.
static func id_of(path: String) -> String:
	return "mine_" + path.get_file().get_basename()
