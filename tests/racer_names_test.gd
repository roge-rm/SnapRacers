extends Node

## Matching names keep separate points, starting places and podium karts.

const RECORDS := "user://test_racer_names_records.cfg"

class SetupSession extends NetSession:
	func _begin_round() -> void:
		setup = _setup()

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	Records.use_file(RECORDS)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	var settings := Game.settings.encode_to_text()
	var design := Game.design
	Game.design = Game.stock_kart("kart_kid").duplicate_design()
	Game.design.name = "The player's kart"
	Game.settings.set_value("race", "kart", Game.OWN_KART)
	Game.settings.set_value("race", "player_two", "crusher")
	_helpers()
	await _offline(false)
	await _offline(true)
	_online()
	Game.design = design
	Game.settings.clear()
	Game.settings.parse(settings)
	Records.use_file(Records.FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	print("All racer name checks passed." if failures == 0 else "%d racer name checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _helpers() -> void:
	var names := RaceNames.new()
	var entries := [
		{"identity": "ai", "name": "Brickley"},
		{"identity": "one", "name": "Brickley", "human": 0},
		{"identity": "two", "name": "Brickley 2", "human": 1},
	]
	names.assign(entries)
	check(entries.map(func(e): return e.name) == ["Brickley 3", "Brickley", "Brickley 2"], "human names have priority and generated suffixes leave requested names free")
	var next := [{"identity": "ai", "name": "Brickley"}, {"identity": "new", "name": "Brickley", "human": 0}]
	names.assign(next)
	check(next[0].name == "Brickley 3" and next[1].name == "Brickley 4", "departed racers keep their labels reserved throughout the cup")


func _race_after(before: Node) -> Race:
	for i in 300:
		await frames(1)
		if Game._screen is Race and Game._screen != before:
			return Game._screen as Race
	return null


func _offline(two: bool) -> void:
	Game.settings.set_value("race", "split", Game.SIDE_BY_SIDE if two else Game.SOLO)
	Game.settings.set_value("player", "name", "Brickley")
	Game.settings.set_value("player", "name_two", "Rusty")
	var before := Game._screen
	Game.start_grand_prix("baseplate", two)
	var race := await _race_after(before)
	check(race != null, "the cup starts with matching player and AI names%s" % (" for two" if two else ""))
	if race == null:
		return
	var gp := Game.grand_prix
	var labels := race.racers.map(func(r): return r.name)
	check(labels.all(func(n): return labels.count(n) == 1), "every entrant has a separate race label")
	check(race.player.name == "Brickley" and (not two or race.humans[1].name == "Rusty"), "players retain their chosen names")
	var matching: Race.Racer = race.racers.filter(func(r): return r.cpu and r.kart.driver.name == "Brickley")[0]
	check(matching.name != race.player.name, "the matching AI gets a separate label")
	var ai_label := matching.name
	var ai_kart := matching.kart.design.name
	var people := race.humans.map(func(r): return r.name)
	var order: Array = [race.player.name, matching.name] + labels.filter(func(n): return n != race.player.name and n != matching.name)
	Game.finish_grand_prix_race(order)
	await frames(3)
	check(gp.points.size() == Race.KARTS and gp.points.Brickley == 15 and gp.points[ai_label] == 12, "matching names score independent first and second place points")
	check(gp.best_place() == 1 and gp.people == people, "the player's cup placing refers only to their own row")
	var cells := Game._screen.find_children("*", "Label", true, false)
	check(cells.any(func(c): return c.text == "Brickley" and c.theme_type_variation == "LeadAccentLabel") if not two else cells.any(func(c): return c.text == "Brickley" and c.has_theme_color_override("font_color")), "the player has their own highlighted standings row")
	var grid := gp.grid_order()
	before = Game._screen
	Game.next_grand_prix_race()
	race = await _race_after(before)
	check(race != null and race.racers.map(func(r): return r.name) == grid, "the next grid has separate starting places for both names")
	if race == null:
		return
	check(race.racers.any(func(r): return r.cpu and r.name == ai_label), "the AI label remains the same across cup rounds")
	gp.round = gp.track_ids().size() - 1
	Game.finish_grand_prix_race(order)
	await frames(3)
	var podium := race.podium
	check(podium != null and podium.order[0][0] == "Brickley" and podium.order[0][1].name == "The player's kart", "the winning player keeps their own kart on the podium")
	check(podium != null and podium.order[1][0] == ai_label and podium.order[1][1].name == ai_kart, "the matching AI also keeps its own podium kart")
	Game.grand_prix = null
	Game.show_menu()
	await frames(2)


func _online() -> void:
	var session := SetupSession.new()
	session.role = NetSession.Role.HOST
	var player := {"name": "Brickley", "kart": Game.stock_kart("kart_kid").to_dict(), "driver": Game.character.to_dict()}
	session.members = {2: {"ready": true, "players": [player]}, 3: {"ready": true, "players": [player]}}
	session.settings = NetSession.default_settings()
	session.settings.mode = NetSession.CUP
	var course: Dictionary = session.settings.course
	session.settings.cup = {"name": "Name test", "courses": [course, course]}
	session.start()
	var first: Array = session.setup.entries
	var labels := first.map(func(e): return e.name)
	check(labels.size() == 8 and labels.all(func(n): return labels.count(n) == 1), "online humans and AI with the same requested name all get separate labels")
	var original: String = first.filter(func(e): return e.get("human", false) and e.owner == 2)[0].name
	var survivor: String = first.filter(func(e): return e.get("human", false) and e.owner == 3)[0].name
	var gp := GrandPrix.new("baseplate")
	gp.add_results(labels)
	session.cup_points = gp.points.duplicate()
	session.cup_round = 1
	session.members.erase(2)
	var second := session._setup()
	check(second.entries.any(func(e): return e.get("human", false) and e.owner == 3 and e.name == survivor), "a surviving duplicate-name player keeps their cup identity after another leaves")
	check(second.points.has(original) and not second.entries.any(func(e): return e.name == original), "the departed player's points stay separate and their label is not reassigned")
	session.members[4] = {"ready": true, "players": [player]}
	var joined := session._setup()
	check(joined.entries.any(func(e): return e.get("human", false) and e.owner == 4 and e.name != original and e.name != survivor), "a new same-name player cannot inherit a departed player's points")
	session.members.erase(4)
	session.start()
	check(session.setup.entries.any(func(e): return e.get("human", false) and e.owner == 3 and e.name == "Brickley"), "a new cup releases old race labels")
	session.free()
