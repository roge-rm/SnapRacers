class_name TrackPicker
extends Control

## Pick who's playing and which track to race on. Each track says how long a
## lap is and what's waiting for you on it.
##
## Two people can play on one phone, sharing the screen side by side
## (landscape, half each) or face to face (portrait, with the phone flat
## between them). Player 2 drives one of the AI karts, and you pick which one
## here.

const MODES := [
	[Game.SOLO, "1 player", "Just you"],
	[Game.SIDE_BY_SIDE, "2 players", "Side by side"],
	[Game.FACE_TO_FACE, "2 players", "Face to face"],
]

var _mode_buttons: Array[Button] = []
var _second: Button


func _ready() -> void:
	var column := MenuStyle.page(self, "Pick a track", Game.show_menu, 760.0)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 14)
	column.add_child(modes)
	for mode in MODES:
		var button := MenuStyle.button(mode[1], _set_mode.bind(mode[0]), mode[2])
		button.custom_minimum_size.y = 84.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("mode", mode[0])
		modes.add_child(button)
		_mode_buttons.append(button)
	_second = MenuStyle.button("", _next_kart)
	column.add_child(_second)
	_show_mode()

	var files := Array(DirAccess.get_files_at(Game.TRACKS)).filter(func(f): return f.ends_with(".json"))
	files.sort()
	for file in files:
		var path: String = Game.TRACKS + "/" + file
		var track := TrackPath.load_file(path)
		var button := MenuStyle.button(track.name, func() -> void: Game.show_race(path), describe(track))
		button.custom_minimum_size.y = 84.0
		button.set_meta("track", path)
		column.add_child(button)


func _set_mode(mode: String) -> void:
	Game.set_setting("race", "split", mode)
	_show_mode()


## Lights up the chosen way to play, and shows player 2's kart if there is a
## player 2.
func _show_mode() -> void:
	for button in _mode_buttons:
		var on: bool = button.get_meta("mode") == Game.split()
		var colour := MenuStyle.ACCENT if on else Color.WHITE
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, colour)
		# There's an outline around the chosen one too, because the colour alone
		# is easy to miss.
		for state in ["normal", "hover", "pressed"]:
			button.remove_theme_stylebox_override(state)
			if on:
				var box := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
				if box != null:
					box.border_color = MenuStyle.ACCENT
					box.set_border_width_all(3)
					button.add_theme_stylebox_override(state, box)
	_second.visible = Game.players() > 1
	var design := KartDesign.load_file("%s/%s.json" % [Game.AI_KARTS, Game.player_two_kart()])
	_second.text = "Player 2 drives %s's kart   ›" % design.name


## Player 2 moves on to the next AI kart.
func _next_kart() -> void:
	var keys := Game.ai_kart_keys()
	var next := keys[(keys.find(Game.player_two_kart()) + 1) % keys.size()]
	Game.set_setting("race", "player_two", next)
	_show_mode()


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
