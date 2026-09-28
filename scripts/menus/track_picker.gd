class_name TrackPicker
extends Control

## Pick a course for a time trial, a practice session or a two player race.
## They're listed cup by cup, and each one says how long a lap is and what's
## waiting for you on it. In time trials it shows your record too.

var mode := Game.MODE_RACE


func _init(for_mode := Game.MODE_RACE) -> void:
	mode = for_mode


func _ready() -> void:
	var titles := {
		Game.MODE_TIME_TRIAL: "Time trial",
		Game.MODE_PRACTICE: "Practice",
		Game.MODE_RACE: "Pick a course",
	}
	var column := MenuStyle.page(self, titles.get(mode, "Pick a course"), go_back, 760.0)
	for cup in GrandPrix.cups():
		column.add_child(MenuStyle.heading(cup.name))
		for id in cup.tracks:
			var path := Tracks.path_of(id)
			var track := TrackPath.load_file(path)
			var line := describe(track)
			if mode == Game.MODE_TIME_TRIAL and Records.best_time(id) > 0.0:
				line += "\nRecord %s, best lap %s" % [RaceHud.clock(Records.best_time(id)), RaceHud.clock(Records.best_lap(id))]
			var button := MenuStyle.button(track.name, _start.bind(path), line)
			button.custom_minimum_size.y = 84.0
			button.set_meta("track", path)
			column.add_child(button)
	MenuStyle.back_at_bottom(column, go_back)


func _start(path: String) -> void:
	match mode:
		Game.MODE_TIME_TRIAL:
			Game.start_time_trial(path)
		Game.MODE_PRACTICE:
			Game.start_practice(path)
		_:
			Game.start_race(path)


## A line saying what's on a track, like "675 m, 3 laps, a bridge and a jump".
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


func go_back() -> void:
	if mode == Game.MODE_RACE:
		Game.show_multiplayer()
	else:
		Game.show_single_player()
