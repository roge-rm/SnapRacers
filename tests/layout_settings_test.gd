extends Node

## Reverse and mirrored as race settings: they persist, a cup copies them,
## and apply_layout follows those flags.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/layout_settings_test.tscn

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var saved_reversed := Game.reversed()
	var saved_mirrored := Game.mirrored()
	var saved_kart: Variant = Game.settings.get_value("race", "kart", Game.OWN_KART)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	check(not Game.reversed() and not Game.mirrored(), "a test start leaves reverse and mirrored off")

	Game.set_reversed(true)
	Game.set_mirrored(false)
	check(Game.reversed() and not Game.mirrored(), "reversed persists through set_setting")
	Game.set_mirrored(true)
	Game.set_reversed(false)
	check(not Game.reversed() and Game.mirrored(), "mirrored persists through set_setting")

	Game.set_reversed(true)
	Game.set_mirrored(true)
	Game.settings.set_value("race", "kart", Game.DEFAULT_STOCK)
	Game.start_grand_prix("baseplate")
	check(Game.grand_prix != null and Game.grand_prix.reversed and Game.grand_prix.mirrored, "start_grand_prix copies both flags")

	var peach := TrackPath.load_file(Tracks.path_of("peach_pit"))
	peach.apply_layout(Game.grand_prix.mirrored, Game.grand_prix.reversed)
	check(peach.mirrored and peach.reversed, "peach_pit apply_layout from those flags")

	Game.set_reversed(false)
	Game.set_mirrored(true)
	peach = TrackPath.load_file(Tracks.path_of("peach_pit"))
	peach.apply_layout(Game.mirrored(), Game.reversed())
	check(peach.mirrored and not peach.reversed, "peach_pit apply_layout from Game flags one at a time")

	Game.settings.set_value("race", "kart", saved_kart)
	Game.set_reversed(saved_reversed)
	Game.set_mirrored(saved_mirrored)
	print("%d layout settings checks passed." % checks if failures == 0 else "%d of %d layout settings checks failed." % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
