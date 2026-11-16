extends SceneTree

## The trophy a cup of your own awards: saved in its file and share code only
## when picked, carried to a Grand Prix, and left as it was for an old cup.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/cup_trophy_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var cup := CupDesign.new()
	cup.name = "Trophy test cup"
	cup.made_by = "Tester"
	cup.add(Tracks.path_of("lemon_lake"))
	cup.add(Tracks.path_of("peach_pit"))

	print("-- An old cup")
	var old := cup.to_dict()
	check(not old.has("trophy"), "no pick, no key in the file")
	var old_code := Sharing.code_for(old)
	var old_back := Sharing.read(old_code)
	check(not old_back.data.has("trophy"), "and none in the share code")
	var reloaded := CupDesign.from_dict(old_back.data)
	check(reloaded.trophy == "" and reloaded.trophy_spec() == TrophyModel.spec_for(cup.name) and reloaded.trophy_colour() == TrophyModel.colour_for(cup.name), "it keeps the trophy picked from its name")
	var plain := cup.to_cup("mine_x")
	check(not plain.has("trophy") and not plain.has("colour"), "and its Grand Prix has none to override it")

	print("-- A picked trophy")
	cup.trophy = "gearbox"
	var game_cup := GrandPrix.cup_by_id("gearbox")
	check(cup.to_dict().trophy == "gearbox", "the pick is in the file")
	check(CupDesign.from_dict(JSON.parse_string(JSON.stringify(cup.to_dict()))).trophy == "gearbox", "and reads back")
	var back := Sharing.read(Sharing.code_for(cup.to_dict()))
	check(back.get("kind") == Sharing.CUP and back.data.get("trophy") == "gearbox", "and in the share code")
	check(Sharing.read(Sharing.file_for(cup.to_dict())).data.get("trophy") == "gearbox", "and in the shared file")
	var picked := CupDesign.from_dict(back.data)
	check(picked.trophy_spec() == game_cup.trophy and picked.trophy_colour() == Color(game_cup.colour), "it shows that game cup's trophy and colour")
	var gp := cup.to_cup("mine_x")
	check(gp.trophy == game_cup.trophy and gp.colour == game_cup.colour, "a Grand Prix of it awards the same")
	var online := Sharing.cup_from_online({"name": "X", "courses": [], "trophy": "gearbox"})
	check(online.get("trophy") == "gearbox", "a cup sent online keeps the pick")
	check(not Sharing.cup_from_online({"name": "X", "courses": []}).has("trophy"), "and one with none stays without")
	check(CupDesign.award("gearbox").trophy == game_cup.trophy, "the online setup resolves a pick the same way")

	print("-- An unknown trophy")
	cup.trophy = "nonsense"
	check(cup.to_cup("mine_x").has("trophy") == false, "a Grand Prix ignores it")
	check(cup.trophy_spec() == TrophyModel.spec_for(cup.name), "and it shows the trophy from the name")
	check(CupDesign.award("").is_empty() and CupDesign.award("nonsense").is_empty(), "no award for an empty or unknown pick")

	print("All cup trophy checks passed." if failures == 0 else "%d cup trophy checks failed." % failures)
	quit(1 if failures > 0 else 0)
