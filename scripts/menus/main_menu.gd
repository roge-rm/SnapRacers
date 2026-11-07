class_name MainMenu
extends Control

## The first thing you see after the splash.


func _ready() -> void:
	var column := MenuStyle.menu_screen(self)
	column.add_child(MenuStyle.big_button("Single player", "race", Game.show_single_player))
	column.add_child(MenuStyle.big_button("Multiplayer", "two", Game.show_multiplayer))
	column.add_child(MenuStyle.big_button("Editors", "wrench", Game.show_editors))
	column.add_child(MenuStyle.big_button("Creations", "cards", Game.show_creations))
	column.add_child(MenuStyle.big_button("Settings", "gear", Game.show_settings))
	column.add_child(MenuStyle.big_button("About", "info", Game.show_about))
	# A web page can't close itself, so there it has no Quit.
	if not OS.has_feature("web"):
		MenuStyle.back_at_bottom(column, go_back, "Quit")


## Back from the menu leaves the game, the way apps usually do.
func go_back() -> void:
	if not OS.has_feature("web"):
		get_tree().quit()
