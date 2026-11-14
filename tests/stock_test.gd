extends Node

## Checks the stock karts, bikes, trikes and quads. There are 22 karts and
## trucks, seven bikes, five trikes and six quads, every one can be driven and says what it's like, no
## two drive the same, and each one gets around a lap of Peach Pit with the AI
## driving it. tools/stock-karts/balance.tscn goes
## further and times them all on four courses.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/stock_test.tscn

# A lap of Peach Pit takes them all 75 to 90 s at kart scale, so this leaves
# room for a slow one without waiting on one that's stuck.
const GIVE_UP := 110.0

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	var keys := Game.stock_keys()
	var by_wheels := {}
	for key in keys:
		var stats := KartStats.compute(Game.stock_kart(key))
		var wheels := stats.wheels.size()
		var kind := "bike" if wheels == 2 else "trike" if wheels == 3 else "quad" if stats.is_quad() else "kart"
		by_wheels[kind] = by_wheels.get(kind, 0) + 1
	check(by_wheels.get("kart", 0) == 22 and by_wheels.get("bike", 0) == 7 and by_wheels.get("trike", 0) == 5 and by_wheels.get("quad", 0) == 6, "there are 22 karts and trucks, seven bikes, five trikes and six quads %s" % by_wheels)
	# Every old stock id leads to one that's still there, and a saved old
	# pick is swapped for its new id.
	var lost := Game.OLD_STOCK.keys().filter(func(k): return not keys.has(Game.OLD_STOCK[k]))
	check(lost.is_empty() and Game.OLD_STOCK.keys().all(func(k): return not keys.has(k)), "every old stock id leads to a new one %s" % [lost])
	var was_kart = Game.settings.get_value("race", "kart", Game.OWN_KART)
	var was_two = Game.settings.get_value("race", "player_two", Game.PLAYER_TWO_STOCK)
	Game.settings.set_value("race", "kart", "starter")
	Game.settings.set_value("race", "player_two", "superbike")
	Game._move_old_stock()
	check(Game.settings.get_value("race", "kart") == "kart_kid" and Game.settings.get_value("race", "player_two") == "streak", "old picks in the settings move to the new ids")
	Game.settings.set_value("race", "kart", was_kart)
	Game.settings.set_value("race", "player_two", was_two)
	Game.save_settings()
	var looks := []
	var names := {}
	for key in keys:
		var design := Game.stock_kart(key)
		var stats := KartStats.compute(design)
		names[design.name] = true
		check(design.problems().is_empty() and design.about != "", "%s can be driven and says what it's like %s" % [design.name, design.problems()])
		looks.append([key, Vector4(stats.top_speed() * 3.6, stats.pull() * 10.0, stats.cornering() * 10.0, stats.mass / 10.0), Vector3(stats.drag_area * 10.0, stats.control * 10.0, stats.offroad * 10.0)])
	check(names.size() == keys.size(), "and they all have their own names")
	# Every pair differs by a fair bit in something.
	var same := []
	for i in looks.size():
		for j in range(i + 1, looks.size()):
			var a: Array = looks[i]
			var b: Array = looks[j]
			var gap: Vector4 = (a[1] - b[1]).abs()
			var gap2: Vector3 = (a[2] - b[2]).abs()
			if maxf(maxf(gap.x, gap.y), maxf(gap.z, gap.w)) < 2.0 and maxf(gap2.x, maxf(gap2.y, gap2.z)) < 1.0:
				same.append("%s and %s" % [a[0], b[0]])
	check(same.is_empty(), "no two of them drive the same %s" % [same])

	Game.settings.set_value("race", "split", Game.SOLO)
	var was: String = Game.settings.get_value("race", "kart", Game.OWN_KART)
	var last: Race = null
	for key in keys:
		Game.settings.set_value("race", "kart", key)
		Game.mode = Game.MODE_TIME_TRIAL
		Game.show_race(Game.TRACKS + "/peach_pit.json")
		var race: Race = null
		while race == null:
			await get_tree().process_frame
			for child in host.get_children():
				if child is Race and child != last and not child.is_queued_for_deletion():
					race = child
		last = race
		var driver := AIDriver.new()
		driver.kart = race.player.kart
		driver.track = race.track
		driver.others.assign([race.player.kart])
		race.add_child(driver)
		race.player.ai = driver
		race.player.kart.controls = driver.controls
		var resets := [0]
		race.player.kart.was_reset.connect(func() -> void: resets[0] += 1)
		while race.player.progress.lap_times.is_empty() and race.time < GIVE_UP:
			await get_tree().physics_frame
		var lap: float = race.player.progress.lap_times[0] if not race.player.progress.lap_times.is_empty() else INF
		check(lap < GIVE_UP and resets[0] <= 1, "the %s gets around a lap (%.1f s, %d resets)" % [race.player.kart.design.name, lap, resets[0]])
	Game.settings.set_value("race", "kart", was)
	print("All stock kart checks passed." if failures == 0 else "%d stock kart checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
