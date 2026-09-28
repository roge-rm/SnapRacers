class_name Tracks
extends RefCounted

## The courses that come with the game, by id (the file name without .json),
## in the order the cups run them.

const FOLDER := "res://data/tracks"


static func path_of(id: String) -> String:
	return "%s/%s.json" % [FOLDER, id]


## A course's id, for its records. Your own courses (in user://courses) get
## "mine_" in front, so one named like a course that comes with the game
## still keeps its own records.
static func id_of(path: String) -> String:
	var id := path.get_file().get_basename()
	return "mine_" + id if path.begins_with(CourseDesign.FOLDER) else id


## Every course id, cup by cup, easiest first.
static func all() -> Array:
	var out := []
	for cup in GrandPrix.cups():
		out.append_array(cup.tracks)
	return out
