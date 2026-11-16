extends Node

## Where a saved window goes, and the Display choice's saved values.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/window_mode_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var one := [Rect2i(0, 0, 1920, 1040)]
	var two := [Rect2i(0, 0, 1920, 1040), Rect2i(1920, 0, 1280, 1024)]
	check(WindowMode.fit_rect(Rect2i(100, 100, 800, 600), one) == Rect2i(100, 100, 800, 600), "a window on a screen stays")
	check(WindowMode.fit_rect(Rect2i(2000, 100, 800, 600), two) == Rect2i(2000, 100, 800, 600), "and on the second screen")
	check(WindowMode.fit_rect(Rect2i(2000, 100, 800, 600), one) == Rect2i(560, 220, 800, 600), "a window whose screen has gone is centred on the first")
	check(WindowMode.fit_rect(Rect2i(1800, 900, 800, 600), one) == Rect2i(1120, 440, 800, 600), "one hanging off the edge is pulled back in")
	check(WindowMode.fit_rect(Rect2i(0, 0, 5000, 4000), one) == Rect2i(0, 0, 1920, 1040), "one bigger than the screen shrinks to it")
	check(WindowMode.fit_rect(Rect2i(10, 10, 20, 20), one).size == WindowMode.MIN_SIZE, "and one too small grows to the least")
	check(WindowMode.fit_rect(Rect2i(0, 0, 800, 600), []) == Rect2i(0, 0, 800, 600), "with no screens it's left alone")

	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var saved: Variant = Game.settings.get_value("display", "window_mode", "")
	check(Game.window_mode != null, "Game has the window mode")
	Game.set_setting("display", "window_mode", "window")
	check(WindowMode.mode() == WindowMode.WINDOW, "window is read back")
	Game.set_setting("display", "window_mode", "nonsense")
	check(WindowMode.MODES.has(WindowMode.mode()), "a bad value falls back to a real mode")
	Game.set_setting("display", "window_rect", Rect2i(5, 6, 700, 500))
	check(WindowMode.saved_rect() == Rect2i(5, 6, 700, 500), "the window's place is read back")
	Game.set_setting("display", "window_rect", Rect2i())
	check(WindowMode.saved_rect().size == Vector2i.ZERO, "no saved place is an empty rect")
	Game.set_setting("display", "window_mode", saved)
	print("%d failed" % failures if failures else "all passed")
	get_tree().quit(1 if failures else 0)
