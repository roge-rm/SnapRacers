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
		"Every part you add changes how it drives. Wider tires grip more but drag more, a bigger engine is faster but heavier, and slopes, nose cones and fairings let the air slide past. How your driver sits matters too. Lying down keeps them out of the wind, but it's harder to steer. Anything you bolt on can get knocked off in a crash. If that happens, reset and you'll be back on the track in one piece, just a little slower for a moment.",
		"",
		"If you'd rather not build, there are sixteen stock karts to pick from, and the AI drivers race in them too.",
		"",
		"Race against the AI on your own, or with a friend on the same phone.",
		"",
		"All 16 courses are based on real kart circuits around the world. Their layouts were traced from OpenStreetMap map data, which is © OpenStreetMap contributors and available under the Open Database Licence.",
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
