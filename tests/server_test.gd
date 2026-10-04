extends Node

## A player joining the dedicated server, the way a phone does (over ENet) or
## a web page does (over a WebSocket). tools/run-server-test.sh starts the
## server and one of each:
##
##   ... res://tests/server_test.tscn -- enet
##   ... res://tests/server_test.tscn -- ws
##
## The ENet one also works the server's control channel the way its web
## admin does: reading its status and changing its settings.

var failures := 0
var host: Node
var how := "enet"
var order: Array = []


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + ("[%s] " % how) + what)
	if not ok:
		failures += 1


func screen() -> Node:
	return host.get_child(host.get_child_count() - 1)


func until(test: Callable, seconds: float) -> bool:
	var give_up := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call():
		if Time.get_ticks_msec() > give_up:
			return false
		await get_tree().process_frame
	return true


## One command to the server's control channel, as the web admin sends it.
func control(words: Array) -> Dictionary:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", DedicatedServer.CONTROL_PORT) != OK:
		return {}
	var give_up := Time.get_ticks_msec() + 5000
	while tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < give_up:
		tcp.poll()
		await get_tree().process_frame
	tcp.put_data(("\t".join(words) + "\n").to_utf8_buffer())
	var text := ""
	while not text.contains("\n") and Time.get_ticks_msec() < give_up:
		tcp.poll()
		if tcp.get_available_bytes() > 0:
			text += tcp.get_utf8_string(tcp.get_available_bytes())
		await get_tree().process_frame
	var reply = JSON.parse_string(text.split("\n")[0])
	return reply if reply is Dictionary else {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	how = args[0] if not args.is_empty() else "enet"
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("player", "name", "Phone" if how == "enet" else "Browser")
	Game.settings.set_value("race", "kart", "starter")
	var net := Game.net

	if how == "enet":
		var status := await control(["status"])
		check(status.get("ok", false) and status.get("state") == "lobby", "the server answers its control channel, in the lobby (%s)" % status.get("state"))
		for setting in [["mode", "race"], ["course", "peach_pit"], ["laps", "1"], ["start_after", "3"], ["standings_for", "2"], ["weather", "snow"]]:
			check((await control(["set", setting[0], setting[1]])).get("ok", false), "and takes a setting (%s)" % setting[0])
		check(not (await control(["set", "weather", "hail"])).get("ok", false), "but not a weather it doesn't have")
		var courses := await control(["courses"])
		check(courses.get("courses", []).size() >= 16, "and lists the courses it can put on (%d)" % courses.get("courses", []).size())
		net.join(Connections.join_enet("127.0.0.1", NetSession.PORT))
	else:
		# Give the phone a moment to set the server up first.
		await get_tree().create_timer(2.0).timeout
		net.join(Connections.join_websocket("ws://127.0.0.1:%d" % DedicatedServer.WS_PORT))
	Game.show_lobby()
	check(await until(func(): return not net.members.is_empty(), 20.0), "it joins the server's lobby")
	check(await until(func(): return net.members.size() == 2, 20.0), "and sees the other player there too")
	check(int(net.settings.laps) == 1, "with the laps the admin set")
	if how == "enet":
		var status := await control(["status"])
		check(status.get("players", []).size() == 2, "the server's status lists both players (%d)" % status.get("players", []).size())
	net.set_ready(true)
	check(await until(func(): return screen() is Race, 30.0), "once everyone's ready, the server starts the race")
	var race: Race = screen()
	check(race.racers.size() == 8, "the server fills the grid with its AI (%d karts)" % race.racers.size())
	check(race.conditions.weather == "snow", "in the snow the admin set (%s)" % race.conditions.describe())
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	driver.others.assign(race.racers.map(func(r): return r.kart))
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	var back := await until(func():
		if is_instance_valid(race) and screen() == race:
			order = race.standings().map(func(r): return r.name)
		return screen() is Lobby, 200.0)
	check(back, "when everyone's home, the server takes everyone back to the lobby")
	print("[%s] order: %s" % [how, ", ".join(order)])
	await get_tree().create_timer(1.0).timeout
	if how == "enet":
		var after := await control(["status"])
		check(after.get("state") == "lobby", "and its status says it's back in the lobby (%s)" % after.get("state"))
		await control(["restart"])
	net.leave()
	print("All server checks passed." if failures == 0 else "%d server checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
