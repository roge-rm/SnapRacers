extends Node

## Two copies of the game racing each other over the network: one hosts and
## the other joins, the way two phones on the same Wi-Fi would. It runs as two
## processes, started by tools/run-net-test.sh:
##
##   ... res://tests/net_test.tscn -- host
##   ... res://tests/net_test.tscn -- join
##
## Each lets the AI drive its own kart, and checks what it sees: the other
## player's kart moving, the AI karts, the lobby, the race starting for both
## at once, and everyone back in the lobby at the end with the same order.

const PORT := 27290

var failures := 0
var host: Node
var role := "host"
var order: Array = []


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + ("[%s] " % role) + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func screen() -> Node:
	return host.get_child(host.get_child_count() - 1)


## Waits up to `seconds` for this to be true.
func until(test: Callable, seconds: float) -> bool:
	var give_up := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call():
		if Time.get_ticks_msec() > give_up:
			return false
		await get_tree().process_frame
	return true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else "host"
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("player", "name", "Host" if role == "host" else "Joiner")
	Game.settings.set_value("race", "kart", "starter")
	var net := Game.net
	net.race_begun.connect(func() -> void: order.clear())

	if role == "host":
		var peer := Connections.host_enet(PORT)
		check(peer != null, "a game can be hosted")
		net.host(peer)
		var course = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
		net.set_settings({"course": course, "laps": 1, "ai": true, "difficulty": "expert", "weather": "rain", "time": "dusk"})
		Game.show_lobby()
		check(await until(func(): return net.members.size() == 2, 30.0), "the other player joins")
		check(await until(func(): return net.can_start(), 30.0), "and says they're ready")
		net.start()
	else:
		net.join(Connections.join_enet("127.0.0.1", PORT))
		Game.show_lobby()
		check(await until(func(): return net.members.size() == 2, 30.0), "the lobby shows both of us")
		check(net.settings.course.name == "Peach Pit" and int(net.settings.laps) == 1, "with the host's course and laps")
		net.set_ready(true)

	check(await until(func(): return screen() is Race, 30.0), "the race starts")
	var race: Race = screen()
	check(race.racers.size() == 8, "with both of us and six AI karts (%d)" % race.racers.size())
	# Whoever's hosting picks the weather, and everyone races in it with the
	# same puddles.
	var puddles := race.builder.puddles
	check(race.conditions.weather == "rain" and race.conditions.time == "dusk" and puddles != null, "in the host's rain at dusk, puddles and all (seed %d, %d puddles, the first at %s)" % [race.conditions.seed, puddles.spots.size() if puddles != null else 0, puddles.spots[0][0].snapped(Vector3.ONE * 0.1) if puddles != null and not puddles.spots.is_empty() else "none"])
	var remote := race.racers.filter(func(r): return r.kart.remote)
	check(remote.size() == (1 if role == "host" else 7), "and the karts driven elsewhere are remote here (%d)" % remote.size())
	# The AI drives our kart for us.
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	driver.others.assign(race.racers.map(func(r): return r.kart))
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	check(await until(func(): return race.started, 30.0), "the countdown runs out and it's go")
	var other: Race.Racer = race.racers.filter(func(r): return r.player == false and r.name == ("Joiner" if role == "host" else "Host"))[0]
	var at := other.kart.global_position
	await get_tree().create_timer(5.0).timeout
	check(other.kart.global_position.distance_to(at) > 20.0, "the other player's kart is seen moving (%.0f m)" % other.kart.global_position.distance_to(at))
	# Keep the finishing order while the race is still here to ask.
	var back := await until(func():
		if is_instance_valid(race) and screen() == race:
			order = race.standings().map(func(r): return r.name)
		return screen() is Lobby, 180.0)
	check(back, "when everyone's home, it's back to the lobby")
	check(order.size() == 8, "and the race had a finishing order")
	print("[%s] order: %s" % [role, ", ".join(order)])

	# A cup of two short races, with the standings in between.
	if role == "host":
		var courses := []
		for id in ["peach_pit", "lemon_lake"]:
			var course = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(id)))
			course.laps = 1
			courses.append(course)
		net.set_settings({"mode": NetSession.CUP, "cup": {"name": "Test Cup", "courses": courses}})
		check(await until(func(): return net.can_start(), 30.0), "back in the lobby, they're ready for a cup")
		net.start()
	else:
		check(await until(func(): return net.settings.mode == NetSession.CUP, 30.0), "the host picks a cup")
		net.set_ready(true)
	for round in 2:
		check(await until(func(): return screen() is Race, 30.0), "race %d of the cup starts" % (round + 1))
		var leg: Race = screen()
		var ai := AIDriver.new()
		ai.kart = leg.player.kart
		ai.track = leg.track
		ai.others.assign(leg.racers.map(func(r): return r.kart))
		leg.add_child(ai)
		leg.player.ai = ai
		leg.player.kart.controls = ai.controls
		check(await until(func(): return screen() is GrandPrixStandings, 180.0), "then the standings")
		print("[%s] points after race %d: %s" % [role, round + 1, Game.grand_prix.standings()])
		if role == "host":
			await get_tree().create_timer(1.0).timeout
			if round == 0:
				net.next_round()
			else:
				net.back_to_lobby()
	check(await until(func(): return screen() is Lobby, 30.0), "after the last race, it's back to the lobby")
	await frames(10)
	net.leave()
	print("All net checks passed." if failures == 0 else "%d net checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
