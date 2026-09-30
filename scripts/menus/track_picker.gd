class_name TrackPicker
extends Control

## Pick a course for a time trial, a practice session or a race against the
## AI, on your own or for two. They're listed cup by cup, then the courses
## you've built in the track editor, and each one says how long a lap is and
## what's waiting for you on it. In time trials it shows your record too.

var mode := Game.MODE_RACE
## A race just for you, from the Single player menu.
var alone := false


func _init(for_mode := Game.MODE_RACE, for_one := false) -> void:
	mode = for_mode
	alone = for_one


func _ready() -> void:
	var titles := {
		Game.MODE_TIME_TRIAL: "Time trial",
		Game.MODE_PRACTICE: "Practice",
		Game.MODE_RACE: "Single race" if alone else "Pick a course",
	}
	var column := MenuStyle.page(self, titles.get(mode, "Pick a course"), go_back, 760.0)
	for cup in GrandPrix.cups():
		column.add_child(MenuStyle.heading(cup.name))
		for id in cup.tracks:
			column.add_child(_course_button(Tracks.path_of(id)))
	# The courses you've built, as long as they're finished.
	var yours := CourseDesign.saved().filter(func(p): return CourseDesign.load_file(p) != null and CourseDesign.load_file(p).problems().is_empty())
	if not yours.is_empty():
		column.add_child(MenuStyle.heading("Your courses"))
		for path in yours:
			column.add_child(_course_button(path))
	MenuStyle.back_at_bottom(column, go_back)


func _course_button(path: String) -> Button:
	var id := Tracks.id_of(path)
	var track := TrackPath.load_file(path)
	var line := describe(track)
	if mode == Game.MODE_TIME_TRIAL and Records.best_time(id) > 0.0:
		line += "\nRecord %s, best lap %s" % [RaceHud.clock(Records.best_time(id)), RaceHud.clock(Records.best_lap(id))]
	var button := MenuStyle.button(track.name, Game.show_kart_picker.bind(_starter(mode, path, alone), Game.show_tracks.bind(mode, alone), mode == Game.MODE_RACE), line)
	button.custom_minimum_size.y = 84.0
	button.set_meta("track", path)
	return button


## A line saying what's on a track, like "1866 m, 3 laps, a bridge and a jump".
static func describe(track: TrackPath) -> String:
	var things := []
	var has := func(what: Callable) -> bool:
		return track.pieces.any(what)
	if has.call(func(p): return p.type == "loop"):
		things.append("a loop")
	if has.call(func(p): return p.type == "curve" and p.sticky):
		things.append("a wall ride")
	var highest := 0.0
	for point in track.points:
		highest = maxf(highest, point.y)
	if highest > 4.0 and not has.call(func(p): return p.type == "loop"):
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


## What starts the race once a kart's picked. It's made here, away from the
## course list, which is gone by then.
static func _starter(for_mode: String, path: String, for_one: bool) -> Callable:
	return func() -> void:
		Game.racing_alone = for_one
		Game.start_course(for_mode, path)


func go_back() -> void:
	if mode == Game.MODE_RACE and not alone:
		Game.show_multiplayer()
	else:
		Game.show_single_player()
