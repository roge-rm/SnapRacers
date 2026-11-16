extends Node

## The player tag colour: the default, saving the pick, a bad saved value,
## player 2 when it clashes, and the colour in the online info.
##
## Saves settings, so run it with XDG_DATA_HOME inside build/:
##   XDG_DATA_HOME=$PWD/build/tag-profile tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/tag_colour_test.tscn

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/")):
		push_error("Set XDG_DATA_HOME to a folder inside build/.")
		get_tree().quit(1)
		return
	Game.settings.set_value("player", "tag_colour", null)
	check(Game.TAG_COLOURS.size() == 8, "8 colours to pick from")
	check(Game.tag_colour(0) == UiKit.PLAYERS[0] and Game.tag_colour(1) == UiKit.PLAYERS[1], "the default is today's colours")
	Game.set_tag_pick(5)
	var reread := ConfigFile.new()
	reread.load(Game.SETTINGS)
	check(int(reread.get_value("player", "tag_colour", -1)) == 5 and Game.tag_colour(0) == Game.TAG_COLOURS[5], "the pick is saved")
	for bad in ["red", 99, -1, 2.5, null]:
		Game.settings.set_value("player", "tag_colour", bad)
		check(Game.tag_pick() == 0 and Game.tag_colour(0) == UiKit.PLAYERS[0], "a bad saved value (%s) is the default" % str(bad))
	Game.set_tag_pick(1)
	check(Game.tag_colour(0) != Game.tag_colour(1), "player 2 moves on when it matches player 1")
	Game.set_tag_pick(3)
	check(Game.tag_colour(1) == Game.TAG_COLOURS[1], "and keeps its own otherwise")
	var net := NetSession.new()
	var me: Dictionary = net._me()
	check(me.players[0].get("tag", -1) == 3, "the info carries the pick")
	check(Game.tag_from_info(me.players[0], Color.BLACK) == Game.TAG_COLOURS[3], "and reads it back")
	var old: Dictionary = me.players[0].duplicate()
	old.erase("tag")
	check(Game.tag_from_info(old, Color.BLACK) == Color.BLACK, "info without it gets the fallback")
	check(Game.tag_from_info({"tag": "x"}, Color.BLACK) == Color.BLACK and Game.tag_from_info({"tag": 40}, Color.BLACK) == Color.BLACK, "so does a bad one")
	var kart := KartDesign.from_dict(old.get("kart", {}))
	check(NetSession.new()._check({"version": NetSession.VERSION, "players": [old]}) == "" or not kart.problems().is_empty(), "the host accepts info without it")
	net.free()
	print("%d tag colour checks, %d failed." % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
