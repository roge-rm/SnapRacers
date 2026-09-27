class_name MainMenu
extends Control

## The first thing you see after the splash.


func _ready() -> void:
	var column := MenuStyle.screen(self)
	column.add_child(MenuStyle.title())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 24.0)
	column.add_child(gap)
	column.add_child(MenuStyle.button("Race", Game.show_tracks))
	column.add_child(MenuStyle.button("Garage", Game.show_garage))
	var multiplayer_button := MenuStyle.button("Multiplayer", Callable(), "Coming later")
	multiplayer_button.custom_minimum_size.y = 76.0
	multiplayer_button.disabled = true
	column.add_child(multiplayer_button)
	column.add_child(MenuStyle.button("Settings", Game.show_settings))
	column.add_child(MenuStyle.button("About", Game.show_about))


## Back from the menu leaves the game, the way apps usually do.
func go_back() -> void:
	get_tree().quit()
