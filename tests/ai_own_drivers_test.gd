extends Node

## The "AI can use your drivers" setting: off the AI field is stock drivers
## only, on it can draw your saved drivers, never one a player picked, and a
## Grand Prix keeps them all cup, with a deleted one swapped for a stock one.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/ai_own_drivers_test.tscn

var failures := 0
var host: Node
var made: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_for_race(before: Node) -> Race:
	for i in 300:
		await frames(1)
		if Game._screen is Race and Game._screen != before:
			return Game._screen
	return null


func _stock(key: String) -> bool:
	return Game.ai_driver_keys().has(key) or key == "racer"


func _ready() -> void:
	var saved_settings := Game.settings.encode_to_text()
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await frames(5)
	Game.mode = Game.MODE_RACE
	Game.set_driver_choice(CharacterDesign.STOCK_KEY + "fizz")
	Game.set_driver_choice(CharacterDesign.STOCK_KEY + "maple", true)
	check(not Game.ai_own_drivers(), "off by default")

	# Three saved drivers, each looking like nobody else.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for name in ["Zed Test", "Yara Test", "Xan Test"]:
		var who := CharacterDesign.random(rng)
		who.name = name
		made.append(who.save())
	var saved_keys := CharacterDesign.saved_drivers().map(func(e): return e.key)
	check(saved_keys.size() == 3, "three saved drivers %s" % [saved_keys])

	var stock_only := true
	var sizes := true
	for i in 100:
		var one := Game.ai_field(1)
		var two := Game.ai_field(2)
		stock_only = stock_only and (one + two).all(_stock)
		sizes = sizes and one.size() == Race.KARTS - 1 and two.size() == Race.KARTS - 2
	check(stock_only, "off: only stock drivers")
	check(sizes, "off: fields are the right size")

	Game.set_setting("race", "ai_own_drivers", true)
	var pool := Game.ai_candidates()
	check(saved_keys.all(func(k): return pool.has(k)) and pool.has(CharacterDesign.OWN_KEY), "on: the pool has the saved drivers and your own")
	Game.set_driver_choice(saved_keys[0])
	Game.set_driver_choice(saved_keys[1], true)
	var seen := {}
	var clean := true
	sizes = true
	var unique := true
	for i in 300:
		var one := Game.ai_field(1)
		var two := Game.ai_field(2)
		for key in one + two:
			seen[key] = true
		clean = clean and not one.has(saved_keys[0]) and not two.has(saved_keys[0]) and not two.has(saved_keys[1])
		sizes = sizes and one.size() == Race.KARTS - 1 and two.size() == Race.KARTS - 2
		var names := {}
		for key in two:
			names[Game.roster_driver(key).name] = true
		unique = unique and names.size() == two.size()
	check(seen.has(saved_keys[1]) and seen.has(saved_keys[2]), "on: saved drivers get drawn")
	check(clean, "on: never a driver a player picked")
	check(sizes, "on: fields are the right size")
	check(unique, "on: nobody twice")

	# A Grand Prix keeps a saved driver all cup, under their own name.
	Game.set_driver_choice(CharacterDesign.STOCK_KEY + "fizz")
	Game.start_grand_prix("baseplate")
	var race := await wait_for_race(null)
	check(race != null, "the cup starts")
	var target := CharacterDesign.SAVED_KEY + "xan_test"
	var field := Game.grand_prix.drivers
	if not field.has(target):
		var out := field[0]
		field[0] = target
		Game.grand_prix.karts[target] = Game.grand_prix.karts[out]
		Game.grand_prix.ranks[target] = Game.grand_prix.ranks[out]
	var before := Game.grand_prix.drivers.duplicate()
	Game.next_grand_prix_race()
	race = await wait_for_race(race)
	var ai_names: Array = race.racers.filter(func(r): return not r.player).map(func(r): return r.name)
	check(Game.grand_prix.drivers == before and ai_names.has("Xan Test"), "the cup keeps the saved driver %s" % [ai_names])
	var kart: String = Game.grand_prix.karts[target]
	var rank: int = Game.grand_prix.ranks[target]

	# Delete them, and a stock driver takes their place, kart and rank.
	DirAccess.remove_absolute(made[2])
	Game.next_grand_prix_race()
	race = await wait_for_race(race)
	var now := Game.grand_prix.drivers
	var at := before.find(target)
	ai_names = race.racers.filter(func(r): return not r.player).map(func(r): return r.name)
	check(now.size() == before.size() and not now.has(target) and _stock(now[at]), "a deleted driver gives way to a stock one %s" % [now])
	check(Game.grand_prix.karts.get(now[at]) == kart and Game.grand_prix.ranks.get(now[at]) == rank, "in their kart and rank")
	var distinct := {}
	for key in now:
		distinct[key] = true
	check(distinct.size() == now.size() and not now.has("fizz") and not ai_names.has("Xan Test"), "nobody twice and not the player's driver %s" % [ai_names])

	# AI karts: stock only when off, your saved karts that can race when on.
	check(not Game.ai_own_karts(), "karts: off by default")
	var good := Game.stock_kart(Game.stock_keys()[0]).duplicate_design()
	good.name = "Zz Good Test"
	made.append(good.save())
	var bad := good.duplicate_design()
	bad.name = "Zz Bad Test"
	bad.parts.clear()
	check(not bad.problems().is_empty(), "karts: the bad kart can't race")
	made.append(bad.save())
	var good_key := KartDesign.SAVED_KEY + "zz_good_test"
	var bad_key := KartDesign.SAVED_KEY + "zz_bad_test"
	var ai_drivers := Game.ai_field(1)
	var off_ok := true
	for i in 50:
		off_ok = off_ok and Game.draw_karts(ai_drivers).values().all(func(k): return Game.stock_keys().has(k))
	check(off_ok, "karts off: only stock karts")
	Game.set_setting("race", "ai_own_karts", true)
	var dealt := {}
	var never_bad := true
	var never_left_out := true
	for i in 200:
		for dealt_kart in Game.draw_karts(ai_drivers, [good_key]).values():
			dealt[dealt_kart] = true
			never_bad = never_bad and dealt_kart != bad_key
			never_left_out = never_left_out and dealt_kart != good_key
	check(dealt.has(Game.OWN_KART) == Game.design.problems().is_empty(), "karts on: the garage kart is dealt when it can race")
	check(not dealt.has(good_key) and never_left_out, "karts on: a left out kart isn't dealt")
	var dealt_good := false
	for i in 200:
		dealt_good = dealt_good or Game.draw_karts(ai_drivers).values().has(good_key)
	check(dealt_good, "karts on: a saved kart gets dealt")
	check(never_bad, "karts on: a kart that can't race is never dealt")
	# A Grand Prix swaps a deleted saved kart for a stock one.
	Game.grand_prix = GrandPrix.new("baseplate")
	Game.grand_prix.drivers = ["fizz"]
	Game.grand_prix.karts = {"fizz": good_key}
	DirAccess.remove_absolute(made[made.size() - 2])
	Game.refresh_grand_prix_field()
	check(Game.stock_keys().has(Game.grand_prix.karts["fizz"]), "karts: a deleted saved kart becomes a stock one")
	Game.grand_prix = null
	Game.set_setting("race", "ai_own_karts", false)

	for path in made:
		DirAccess.remove_absolute(path)
	Game.settings.clear()
	Game.settings.parse(saved_settings)
	Game.save_settings()
	print("ai own drivers test: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
