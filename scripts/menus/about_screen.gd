class_name AboutScreen
extends Control

## What the game is and who made what.


func _ready() -> void:
	var column := MenuStyle.page(self, "About", Game.show_menu)
	column.add_child(MenuStyle.title("SnapRacers", "Version %s" % ProjectSettings.get_setting("application/config/version", "")))
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	text.text = "\n".join([
		"SnapRacers is a kart racing game where you build your kart out of bricks and then race it.",
		"",
		"Every part you add changes how it drives. Wider tires grip more and drag more, a bigger engine is faster and heavier, and slopes, nose cones and fairings let the air slide past. Crashes knock parts off, and a reset puts them back on for a moment's slowdown.",
		"",
		"If you'd rather not build, there are sixteen stock karts to pick from, and the AI drivers race in them too.",
		"",
		"Race the AI on your own, with a friend on the same phone, or with people on other phones. Build your own courses and cups in the editors.",
		"",
		"Every course is based on a real circuit somewhere in the world, traced from OpenStreetMap map data, which is © OpenStreetMap contributors and available under the Open Database Licence.",
		"",
		"Made with the Godot Engine (godotengine.org), which is free and open source under the MIT licence.",
		"",
		"Enjoy!",
		"Dan",
	])
	column.add_child(text)
	MenuStyle.back_at_bottom(column, Game.show_menu)


func go_back() -> void:
	Game.show_menu()
