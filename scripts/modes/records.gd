class_name Records
extends RefCounted

## Your best times and trophies, kept on the phone between launches.
##
## Time trials keep the best race time and the best single lap on each course.
## Grand Prix cups keep the best place you've finished them in, at each
## difficulty.

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


## The best race time on this course, in seconds, or 0 if there isn't one.
static func best_time(track_id: String) -> float:
	return _load().get_value("time", track_id, 0.0)


static func best_lap(track_id: String) -> float:
	return _load().get_value("lap", track_id, 0.0)


## Keeps these if they're records. Returns [new best time, new best lap].
static func add_time(track_id: String, time: float, lap: float) -> Array:
	var better_time := time > 0.0 and (best_time(track_id) <= 0.0 or time < best_time(track_id))
	var better_lap := lap > 0.0 and (best_lap(track_id) <= 0.0 or lap < best_lap(track_id))
	if better_time:
		_load().set_value("time", track_id, time)
	if better_lap:
		_load().set_value("lap", track_id, lap)
	if better_time or better_lap:
		_save()
	return [better_time, better_lap]


## The best place you've finished this cup in (1 is a win) at this
## difficulty, or 0 if you haven't finished it yet.
static func best_cup_place(cup_id: String, level := Difficulty.DEFAULT) -> int:
	return _load().get_value("cup", _cup_key(cup_id, level), 0)


static func add_cup_place(cup_id: String, place: int, level := Difficulty.DEFAULT) -> bool:
	var best := best_cup_place(cup_id, level)
	if best == 0 or place < best:
		_load().set_value("cup", _cup_key(cup_id, level), place)
		_save()
		return true
	return false


## Normal keeps using the plain cup id, which is where cups finished before
## there were difficulty levels are kept.
static func _cup_key(cup_id: String, level: String) -> String:
	return cup_id if level == Difficulty.DEFAULT else "%s %s" % [cup_id, level]


## Keeps records in another file instead, so tests don't touch the real ones.
static func use_file(path: String) -> void:
	_path = path
	_file = null
