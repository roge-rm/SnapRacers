class_name EditorsMenu
extends Control

## Where you make things of your own, like a kart in the garage, a driver to
## sit in it and courses to race on. Back from any of them comes here.


func _ready() -> void:
	var column := MenuStyle.screen(self)
	column.add_child(MenuStyle.title("SnapRacers", "Editors"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 24.0)
	column.add_child(gap)
	for item in [
		["Garage", Game.show_garage, "Build your kart out of bricks and parts"],
		["Driver", Game.show_driver, "Choose who's driving, and how they look"],
		["Track editor", Game.show_track_editor, "Lay out a course of your own and race on it"],
	]:
		var button := MenuStyle.button(item[0], item[1], item[2])
		button.custom_minimum_size.y = 84.0
		column.add_child(button)
	MenuStyle.back_at_bottom(column, Game.show_menu)


func go_back() -> void:
	Game.show_menu()
