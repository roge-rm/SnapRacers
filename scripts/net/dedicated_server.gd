class_name DedicatedServer
extends Node

## SnapRacers running as a dedicated server, a game that's always there for
## people to join with nobody of its own racing in it.
##
## Phones join over ENet and web pages over a WebSocket (a secure one, when
## it's given a certificate), both in the same game (see MergedPeer). It keeps
## a lobby going, starts a race a few seconds after everyone in it is ready,
## moves a cup on by itself after the standings and goes back to the lobby at
## the end. It tells the local network it's there, like a phone hosting.
##
## It's run from its web admin page (see server/web-admin), which talks to it
## over a control channel on this machine only, with one line of tab separated
## words in and one line of JSON back. The settings live in a JSON file, so
## they survive a restart.
##
## It starts with --server on the command line, or from a build exported as a
## dedicated server.

const CONTROL_PORT := 27289
const WS_PORT := 27282
const LOG_LINES := 500

var config := {}
var config_path := ""
var _control: TCPServer
var _clients: Array[StreamPeerTCP] = []
var _log: Array = []
var _log_count := 0
var _finder: GameFinder
## When to do the next thing by itself, whether that's starting, moving the cup
## on or going back to the lobby.
var _start_at := -1.0
var _next_at := -1.0
var _next := Callable()
var _clock := 0.0
var _state := "lobby"
var _secure := false
## The settings that only take hold when it starts again.
const NEEDS_RESTART := ["port", "ws_port", "tls_cert", "tls_key"]


static func wanted() -> bool:
	return OS.has_feature("dedicated_server") or OS.get_cmdline_user_args().has("--server")


func _ready() -> void:
	name = "Server"
	config_path = OS.get_environment("SNAPRACERS_CONFIG")
	if config_path == "":
		config_path = "user://server.json"
	_load_config()
	var net := Game.net
	var merged := MergedPeer.new()
	var why := []
	var enet := Connections.host_enet(int(config.port), why)
	if enet == null:
		say(why[0])
		get_tree().quit(1)
		return
	merged.add(enet)
	var ws := WebSocketMultiplayerPeer.new()
	var tls: TLSOptions = null
	if str(config.tls_cert) != "" and str(config.tls_key) != "":
		var key := CryptoKey.new()
		var cert := X509Certificate.new()
		if key.load(config.tls_key) == OK and cert.load(config.tls_cert) == OK:
			tls = TLSOptions.server(key, cert)
			_secure = true
			say("Web players connect over a secure WebSocket")
		else:
			say("I couldn't read the certificate or its key, so web players connect without one")
	if ws.create_server(int(config.ws_port), "*", tls) == OK:
		merged.add(ws)
	else:
		say("I couldn't open the WebSocket port %d, so web players can't join" % int(config.ws_port))
	net.host(merged, true)
	net.settings = _settings_from_config()
	net.changed.connect(_on_changed)
	net.race_over.connect(_on_race_over)
	net.multiplayer.peer_connected.connect(func(id: int) -> void: say("Someone's connecting (%d)" % id))
	net.multiplayer.peer_disconnected.connect(func(id: int) -> void: say("Player %d left" % id))
	_finder = GameFinder.new()
	add_child(_finder)
	_control = TCPServer.new()
	if _control.listen(CONTROL_PORT, "127.0.0.1") != OK:
		say("I couldn't open the control port %d, so the web admin can't reach me" % CONTROL_PORT)
	say("%s is up, on port %d (and %d for web players)" % [config.name, int(config.port), int(config.ws_port)])
	_advertise()


func _load_config() -> void:
	config = {
		"name": "SnapRacers server", "port": NetSession.PORT, "ws_port": WS_PORT,
		"tls_cert": "", "tls_key": "",
		"mode": NetSession.SINGLE, "course": "peach_pit", "cup": "baseplate", "laps": 3,
		"ai": true, "difficulty": Difficulty.DEFAULT, "start_after": 10, "standings_for": 15,
	}
	var data = JSON.parse_string(FileAccess.get_file_as_string(config_path)) if FileAccess.file_exists(config_path) else null
	if data is Dictionary:
		config.merge(data, true)
	# Docker says which ports and certificate to use, every time. The name's
	# only where it starts, so a new one from the admin page sticks.
	var keys := ["port", "ws_port", "tls_cert", "tls_key"]
	if not data is Dictionary:
		keys.append("name")
	for key in keys:
		var env := OS.get_environment("SNAPRACERS_" + key.to_upper())
		if env != "":
			config[key] = int(env) if key.ends_with("port") else env


func _save_config() -> void:
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(config, "\t"))


## The courses and cups it can put on, the game's own and any in the courses/
## and cups/ folders beside the config file.
func courses() -> Dictionary:
	var out := {}
	for id in Tracks.all():
		out[id] = Tracks.path_of(id)
	var folder := config_path.get_base_dir().path_join("courses")
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".json"):
				out["mine_" + file.get_basename()] = folder.path_join(file)
	return out


func cups() -> Dictionary:
	var out := {}
	for cup in GrandPrix.cups():
		out[cup.id] = Lobby._game_cup(cup)
	var folder := config_path.get_base_dir().path_join("cups")
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			var mine := CupDesign.load_file(folder.path_join(file)) if file.ends_with(".json") else null
			if mine != null and mine.problem() == "":
				out["mine_" + file.get_basename()] = {"name": mine.name, "courses": mine.races.map(func(r): return r.course)}
	return out


func _settings_from_config() -> Dictionary:
	var course_path: String = courses().get(config.course, Tracks.path_of("peach_pit"))
	return {
		"mode": config.mode,
		"course": JSON.parse_string(FileAccess.get_file_as_string(course_path)),
		"cup": cups().get(config.cup, cups().values()[0]),
		"laps": int(config.laps),
		"ai": bool(config.ai),
		"difficulty": config.difficulty,
	}


func say(line: String) -> void:
	_log_count += 1
	_log.append([_log_count, Time.get_datetime_string_from_system(), line])
	if _log.size() > LOG_LINES:
		_log.pop_front()
	print(line)


func _advertise() -> void:
	_finder.advertise({"name": config.name, "players": Game.net.player_count(), "most": NetSession.MOST_KARTS, "port": int(config.port), "version": NetSession.VERSION})


# Running the lobby by itself.

func _on_changed() -> void:
	_advertise()
	if not Game.net.setup.is_empty():
		return
	_state = "lobby"
	if Game.net.can_start():
		if _start_at < 0.0:
			_start_at = _clock + float(config.start_after)
			say("Everyone's ready. Starting in %d seconds" % int(config.start_after))
	else:
		_start_at = -1.0


func _on_race_over(_order: Array) -> void:
	say("The race is over. They finished %s." % ", ".join(_order))
	var net := Game.net
	if net.setup.get("mode", NetSession.SINGLE) != NetSession.CUP:
		# After one race everyone's straight back in the lobby.
		_state = "lobby"
		net.back_to_lobby.call_deferred()
		return
	_state = "standings"
	if int(net.setup.round) + 1 < int(net.setup.rounds):
		_later(float(config.standings_for), net.next_round)
	else:
		_later(float(config.standings_for), net.back_to_lobby)


func _later(seconds: float, what: Callable) -> void:
	_next_at = _clock + seconds
	_next = what


func _process(delta: float) -> void:
	_clock += delta
	if _start_at >= 0.0 and _clock >= _start_at:
		_start_at = -1.0
		if Game.net.can_start() and Game.net.setup.is_empty():
			_state = "racing"
			say("Racing on %s" % str(Game.net.settings.course.get("name", "a course")) if Game.net.settings.mode == NetSession.SINGLE else "Racing the %s" % str(Game.net.settings.cup.get("name", "cup")))
			Game.net.start()
	if _next_at >= 0.0 and _clock >= _next_at:
		_next_at = -1.0
		if _next.is_valid():
			var what := _next
			_next = Callable()
			if not Game.net.setup.is_empty() or what == Game.net.back_to_lobby:
				_state = "racing" if what == Game.net.next_round else "lobby"
				what.call()
	_serve_control()


# The control channel.

func _serve_control() -> void:
	if _control == null or not _control.is_listening():
		return
	while _control.is_connection_available():
		_clients.append(_control.take_connection())
	for client: StreamPeerTCP in _clients.duplicate():
		client.poll()
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(client)
			continue
		var waiting := client.get_available_bytes()
		if waiting <= 0:
			continue
		var text := client.get_utf8_string(waiting)
		var line := text.split("\n")[0]
		var reply := command(line.split("\t"))
		client.put_data((JSON.stringify(reply) + "\n").to_utf8_buffer())
		client.disconnect_from_host()
		_clients.erase(client)


## What's wrong with a setting's new value, or nothing.
func _check_setting(key: String, value: Variant) -> String:
	var number := typeof(value) in [TYPE_INT, TYPE_FLOAT]
	match key:
		"mode":
			if not str(value) in [NetSession.SINGLE, NetSession.CUP]:
				return "The mode is %s or %s" % [NetSession.SINGLE, NetSession.CUP]
		"course":
			if not courses().has(str(value)):
				return "There's no course called %s" % value
		"cup":
			if not cups().has(str(value)):
				return "There's no cup called %s" % value
		"laps":
			if not number or int(value) < 1 or int(value) > 9:
				return "Laps go from 1 to 9"
		"difficulty":
			if not str(value) in Difficulty.LEVELS:
				return "The difficulty is one of %s" % ", ".join(Difficulty.LEVELS)
		"ai":
			if typeof(value) != TYPE_BOOL:
				return "AI drivers are true or false"
		"start_after", "standings_for":
			if not number or float(value) < 0.0 or float(value) > 600.0:
				return "That's a number of seconds, up to 600"
		"port", "ws_port":
			if not number or int(value) < 1024 or int(value) > 65535:
				return "Ports go from 1024 to 65535"
		"name":
			if str(value).strip_edges() == "" or str(value).length() > 40:
				return "The name needs 1 to 40 letters"
	return ""


## Does one command from the web admin, and says how it went.
func command(words: PackedStringArray) -> Dictionary:
	var net := Game.net
	match words[0]:
		"status":
			var players := []
			for peer in net.members:
				for p in net.members[peer].players:
					players.append({"id": peer, "name": p.name, "kart": p.get("kart", {}).get("name", ""), "ready": net.members[peer].ready})
			return {"ok": true, "name": config.name, "state": _state, "players": players, "config": config, "version": NetSession.VERSION,
				"course": str(net.settings.get("course", {}).get("name", "")), "cup": str(net.settings.get("cup", {}).get("name", "")),
				"secure": _secure, "uptime": int(_clock), "most": NetSession.MOST_KARTS,
				"starting_in": maxi(ceili(_start_at - _clock), 0) if _start_at >= 0.0 else -1}
		"ping":
			return {"ok": true}
		"courses":
			var list := []
			for id in courses():
				list.append({"id": id, "name": TrackPath.load_file(courses()[id]).name})
			return {"ok": true, "courses": list}
		"cups":
			var list := []
			var all := cups()
			for id in all:
				list.append({"id": id, "name": all[id].name})
			return {"ok": true, "cups": list}
		"set":
			if words.size() < 3:
				return {"ok": false, "error": "set needs a name and a value"}
			# Numbers and true or false come as JSON, and anything else is text.
			var json := JSON.new()
			var value = json.data if json.parse(words[2]) == OK else words[2]
			if value is float and value == floorf(value) and absf(value) < 1e9:
				value = int(value)
			if not config.has(words[1]):
				return {"ok": false, "error": "There's no setting called %s" % words[1]}
			var wrong := _check_setting(words[1], value)
			if wrong != "":
				return {"ok": false, "error": wrong}
			if typeof(config[words[1]]) == TYPE_STRING:
				value = words[2]
			if config[words[1]] == value:
				return {"ok": true, "restart": false}
			config[words[1]] = value
			_save_config()
			if net.setup.is_empty():
				net.set_settings(_settings_from_config())
			say("%s changed to %s" % [words[1], str(value)])
			return {"ok": true, "restart": words[1] in NEEDS_RESTART}
		"kick":
			var id := int(words[1]) if words.size() > 1 else 0
			if not net.members.has(id):
				return {"ok": false, "error": "Nobody with that id is here"}
			net.multiplayer.multiplayer_peer.disconnect_peer(id)
			say("Kicked %s" % str(net.members[id].name))
			return {"ok": true}
		"start":
			if not net.setup.is_empty() or net.player_count() == 0:
				return {"ok": false, "error": "There's nobody in the lobby to race"}
			for peer in net.members:
				net.members[peer].ready = true
			net.start()
			_state = "racing"
			return {"ok": true}
		"lobby":
			net.back_to_lobby()
			_state = "lobby"
			return {"ok": true}
		"log":
			var after := int(words[1]) if words.size() > 1 else 0
			return {"ok": true, "lines": _log.filter(func(l): return l[0] > after)}
		"restart":
			say("Restarting")
			get_tree().create_timer(0.3).timeout.connect(func() -> void: get_tree().quit(0))
			return {"ok": true}
	return {"ok": false, "error": "I don't know the command %s" % words[0]}
