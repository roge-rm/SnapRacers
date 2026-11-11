class_name Records
extends RefCounted

## Your best times and trophies, kept on the phone between launches.
##
## Time trials keep the best race time and the best single lap on each course,
## in clear daytime outdoors or any conditions indoors. Existing records stay.
## Grand Prix cups keep the best place you've finished them in, at each
## difficulty, with cups for two kept apart. Reverse, mirrored and both have
## their own keys.

const FILE := "user://records.cfg"

static var _file: ConfigFile
static var _path := FILE


static func _load() -> ConfigFile:
	if _file == null:
		_file = ConfigFile.new()
		_file.load(_path)
	return _file


static func _save() -> void:
	_load().save(_path)


## Reverse, mirrored, or both, for a record key. Ordinary is empty.
static func layout_key(reversed: bool, mirrored: bool) -> String:
	if reversed and mirrored:
		return "reverse mirrored"
	if reversed:
		return "reverse"
	if mirrored:
		return "mirrored"
	return ""


## The best race time on this course, in seconds, or 0 if there isn't one.
static func best_time(track_id: String, layout := "") -> float:
	return _load().get_value("time", _time_key(track_id, layout), 0.0)


static func best_lap(track_id: String, layout := "") -> float:
	return _load().get_value("lap", _time_key(track_id, layout), 0.0)


## Keeps these if they're records. Returns [new best time, new best lap].
static func add_time(track_id: String, time: float, lap: float, conditions: Conditions = null, layout := "") -> Array:
	if conditions != null and not conditions.records_allowed():
		return [false, false]
	var better_time := time > 0.0 and (best_time(track_id, layout) <= 0.0 or time < best_time(track_id, layout))
	var better_lap := lap > 0.0 and (best_lap(track_id, layout) <= 0.0 or lap < best_lap(track_id, layout))
	var key := _time_key(track_id, layout)
	if better_time:
		_load().set_value("time", key, time)
	if better_lap:
		_load().set_value("lap", key, lap)
	if better_time or better_lap:
		_save()
	return [better_time, better_lap]


## The best place you've finished this cup in (1 is a win) at this
## difficulty, or 0 if you haven't finished it yet. Cups for two on one phone
## keep their own places, the better of the two players. `layout` is reverse,
## mirrored, or both; empty is ordinary.
static func best_cup_place(cup_id: String, level := Difficulty.DEFAULT, two := false, layout := "") -> int:
	return _load().get_value(_cup_section(two), _cup_key(cup_id, level, layout), 0)


static func add_cup_place(cup_id: String, place: int, level := Difficulty.DEFAULT, two := false, layout := "") -> bool:
	var best := best_cup_place(cup_id, level, two, layout)
	if best == 0 or place < best:
		_load().set_value(_cup_section(two), _cup_key(cup_id, level, layout), place)
		_save()
		return true
	return false


static func _cup_section(two: bool) -> String:
	return "cup_two" if two else "cup"


## Ordinary Normal keeps the plain cup id, where cups finished before there
## were difficulty levels are kept. A layout sits between the cup and the
## level, and Normal still drops its name.
static func _cup_key(cup_id: String, level: String, layout := "") -> String:
	var base := cup_id if layout == "" else "%s %s" % [cup_id, layout]
	return base if level == Difficulty.DEFAULT else "%s %s" % [base, level]


static func _time_key(track_id: String, layout := "") -> String:
	return track_id if layout == "" else "%s %s" % [track_id, layout]


## Keeps records in another file instead, so tests don't touch the real ones.
static func use_file(path: String) -> void:
	_path = path
	_file = null
