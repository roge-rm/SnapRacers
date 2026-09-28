class_name SinglePlayerMenu
extends Control

## Racing on your own. A Grand Prix is four races against the AI for points
## and a trophy, a time trial is you against the clock, and practice is as
## many laps as you like with nobody else around.


func _ready() -> void:
	var column := MenuStyle.page(self, "Single player", Game.show_menu, 620.0)
	for item in [
		["Grand Prix", Game.show_cups, "Four cups of four races each, for points and trophies"],
		["Time trial", Game.show_tracks.bind(Game.MODE_TIME_TRIAL), "Race the clock on any of the 16 courses"],
		["Practice", Game.show_tracks.bind(Game.MODE_PRACTICE), "Drive any course on your own, for as long as you like"],
	]:
		var button := MenuStyle.button(item[0], item[1], item[2])
		button.custom_minimum_size.y = 84.0
		column.add_child(button)


func go_back() -> void:
	Game.show_menu()
