class_name TrackPicker
extends Control

## Pick which track to race on. Each one says how long a lap is and what's
## waiting for you on it.


func _ready() -> void:
	var column := MenuStyle.page(self, "Pick a track", Game.show_menu, 560.0)
	var files := Array(DirAccess.get_files_at(Game.TRACKS)).filter(func(f): return f.ends_with(".json"))
	files.sort()
	for file in files:
		var path: String = Game.TRACKS + "/" + file
		var track := TrackPath.load_file(path)
		var button := MenuStyle.button(track.name, func() -> void: Game.show_race(path), describe(track))
		button.custom_minimum_size.y = 84.0
		column.add_child(button)


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
	Game.show_menu()
