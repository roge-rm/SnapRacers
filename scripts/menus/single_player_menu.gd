class_name SinglePlayerMenu
extends Control

## Racing on your own. A Grand Prix is four races against the AI for points
## and a trophy, a time trial is you against the clock, and practice is as
## many laps as you like with nobody else around.


func _ready() -> void:
	var column := MenuStyle.screen(self)
	column.add_child(MenuStyle.title("SnapRacers", "Single player"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 24.0)
	column.add_child(gap)
	for item in [
		["Grand Prix", Game.show_cups, "Four cups of four races each, for points and trophies"],
		["Time trial", Game.show_tracks.bind(Game.MODE_TIME_TRIAL), "Race the clock on any of the 16 courses"],
		["Practice", Game.show_tracks.bind(Game.MODE_PRACTICE), "Drive any course on your own, for as long as you like"],
	]:
		var button := MenuStyle.button(item[0], item[1], item[2])
		button.custom_minimum_size.y = 84.0
		column.add_child(button)
	MenuStyle.back_at_bottom(column, Game.show_menu)


func go_back() -> void:
	Game.show_menu()
