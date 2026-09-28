class_name Tracks
extends RefCounted

## The courses that come with the game, by id (the file name without .json),
## in the order the cups run them.

const FOLDER := "res://data/tracks"


static func path_of(id: String) -> String:
	return "%s/%s.json" % [FOLDER, id]


static func id_of(path: String) -> String:
	return path.get_file().get_basename()


## Every course id, cup by cup, easiest first.
static func all() -> Array:
	var out := []
	for cup in GrandPrix.cups():
		out.append_array(cup.tracks)
	return out
