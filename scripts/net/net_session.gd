class_name NetSession
extends Node

## Racing with other people over a network: hosting or joining a game, the
## lobby, and everything the race needs to send between devices.
##
## One device hosts (a phone, or the dedicated server) and everyone else joins
## it. The host decides what's raced and who's in it, and runs the AI karts
## and the race's rules. Every device drives its own karts itself, so steering
## feels instant however far away the host is, and tells everyone else where
## they are about twenty times a second (see NetRace).
##
## Nothing here cares how the devices are connected. It takes a
## MultiplayerPeer from the Wi-Fi, Wi-Fi Direct, Bluetooth or server code and
## works over whichever one it is.
##
## It lives at the top of the scene tree under Game, as "Net", so its RPCs
## land in the same place on every device.

signal changed
## The game's over for us, and why (the host left, we couldn't get in...).
signal ended(reason: String)
## A race is about to start, with Game set up for it.
signal race_begun
## The host's ended the race, in this finishing order.
signal race_over(order: Array)

## Racing uses its own number, so it can't be confused with an older game.
const VERSION := 2
const PORT := 27280
const MOST_KARTS := 8
## What a host can put on.
const SINGLE := "race"
const CUP := "cup"

enum Role { NONE, HOST, CLIENT, SERVER }
const WIFI := "wifi"
const DIRECT := "direct"
const BLUETOOTH := "bluetooth"

var role := Role.NONE
## Everyone in the game, by peer id: { "name", "players": [ { "name",
## "driver", "kart" } ], "ready" }. A server has no players of its own.
var members := {}
## What's being raced: { "mode", "course" (a course), "cup" ({ "name",
## "courses" }), "laps", "ai", "difficulty" }.
var settings := {}
## The race going on, as the host set it up (see _setup()).
var setup := {}
## The race's own part of this, while there's a race.
var race: NetRace
## Why the last try to join didn't work.
var last_problem := ""
## How the game's connected: WIFI (which is also a hotspot, a server, or the
## internet), DIRECT (Wi-Fi Direct) or BLUETOOTH.
var over := WIFI
var _loaded := {}


func _ready() -> void:
	name = "Net"
	# Courses from online races before this one.
	if DirAccess.dir_exists_absolute("user://net"):
		for file in DirAccess.get_files_at("user://net"):
			DirAccess.remove_absolute("user://net".path_join(file))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_host_gone)


func is_online() -> bool:
	return role != Role.NONE


func is_host() -> bool:
	return role == Role.HOST or role == Role.SERVER


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


# Starting and stopping.

## Hosts a game over this peer, already listening. A dedicated server hosts
## without racing itself.
func host(peer: MultiplayerPeer, dedicated := false, how := WIFI) -> void:
	leave()
	over = how
	multiplayer.multiplayer_peer = peer
	role = Role.SERVER if dedicated else Role.HOST
	members.clear()
	if not dedicated:
		members[1] = _me()
		members[1].ready = true
	if settings.is_empty():
		settings = default_settings()
	changed.emit()


## Joins a game over this peer, already connecting.
func join(peer: MultiplayerPeer, how := WIFI) -> void:
	leave()
	over = how
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	last_problem = ""
	changed.emit()


## Leaves the game, or stops hosting it.
func leave() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	# A Wi-Fi Direct group outlives the game, so it's ended here.
	if over == DIRECT and role != Role.NONE and Game.plugin.has():
		if role == Role.HOST:
			Game.plugin.android.direct_stop_hosting()
		else:
			Game.plugin.android.direct_leave()
	over = WIFI
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE
	members.clear()
	setup = {}
	_loaded.clear()


static func default_settings() -> Dictionary:
	return {
		"mode": SINGLE,
		"course": JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit"))),
		"cup": {},
		"laps": 3,
		"ai": true,
		"difficulty": Difficulty.DEFAULT,
	}


## Who I am and what I'm racing, to send when joining.
func _me() -> Dictionary:
	var players := [{
		"name": Game.online_name(),
		"driver": Game.character.to_dict(),
		"kart": Game.chosen_design().to_dict(),
	}]
	# Two on one phone take two places.
	if Game.split() != Game.SOLO and Game.online_two:
		players.append({
			"name": "%s 2" % Game.online_name(),
			"driver": Game.roster_driver(Game.ai_driver_keys()[0]).to_dict(),
			"kart": Game.stock_kart(Game.player_two_kart()).to_dict(),
		})
	return {"name": Game.online_name(), "players": players, "ready": false}


func player_count() -> int:
	var count := 0
	for peer in members:
		count += members[peer].players.size()
	return count


# The host.

func _on_peer_connected(_peer: int) -> void:
	pass


func _on_peer_disconnected(peer: int) -> void:
	if not is_host():
		return
	members.erase(peer)
	_loaded.erase(peer)
	_share()
	if race != null:
		_gone.rpc(peer)
		race.forget(peer)
		_maybe_go()


## Someone asks to join, with who they are and what they're racing.
@rpc("any_peer", "reliable")
func _hello(info: Dictionary) -> void:
	if not is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	var problem := _check(info)
	if problem != "":
		_refused.rpc_id(peer, problem)
		# Give the message a moment to get there before hanging up.
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer != null:
				multiplayer.multiplayer_peer.disconnect_peer(peer))
		return
	info.ready = false
	members[peer] = info
	_share()


## What stops this player joining, or "".
func _check(info: Dictionary) -> String:
	if int(info.get("version", 0)) != VERSION:
		return "That game is on a different version of SnapRacers."
	if not setup.is_empty():
		return "That game is already racing. Try again when they're back in the lobby."
	var players: Array = info.get("players", [])
	if players.is_empty():
		return "Nobody to race."
	if player_count() + players.size() > MOST_KARTS:
		return "That game is full."
	for p in players:
		var kart := KartDesign.from_dict(p.get("kart", {}))
		if not kart.problems().is_empty():
			return "Your kart can't race yet: %s" % kart.problems()[0]
	return ""


## The lobby as it is now, to everyone.
func _share() -> void:
	if is_host():
		_lobby.rpc(members, settings)
		changed.emit()


func set_settings(changes: Dictionary) -> void:
	if not is_host():
		return
	settings.merge(changes, true)
	_share()


## Whether everyone's ready and there's someone to race.
func can_start() -> bool:
	if not is_host() or player_count() == 0:
		return false
	for peer in members:
		if not members[peer].ready:
			return false
	return true


## Starts the race (or the cup) for everyone.
func start() -> void:
	if not can_start():
		return
	if settings.mode == CUP:
		cup_points = {}
		cup_round = 0
	_begin_round()


## Where a cup's got to, which only the host keeps.
var cup_points := {}
var cup_round := 0


func _begin_round() -> void:
	setup = _setup()
	_loaded.clear()
	_begin.rpc(setup)


## Everything every device needs to set the race up the same way.
func _setup() -> Dictionary:
	var entries := []
	var ids := members.keys()
	ids.sort()
	for peer in ids:
		var players: Array = members[peer].players
		for i in players.size():
			entries.append({"owner": peer, "local": i, "human": true, "name": players[i].name, "driver": players[i].driver, "kart": players[i].kart})
	if settings.ai:
		var drivers := Game.ai_driver_keys()
		var karts := Game.draw_karts(drivers)
		var ranks := Game.draw_ranks(drivers)
		var fill := mini(drivers.size(), MOST_KARTS - entries.size())
		for i in fill:
			var who := Game.roster_driver(drivers[i])
			entries.push_front({"owner": 1, "ai": true, "name": who.name, "driver": who.to_dict(), "kart": Game.stock_kart(karts.get(drivers[i], "starter")).to_dict(), "rank": ranks.get(drivers[i], i), "line": (i % 3 - 1) * 1.5})
	# In a cup, after the first race the grid goes by the points so far,
	# leader at the back.
	if settings.mode == CUP and cup_round > 0:
		entries.sort_custom(func(a, b) -> bool: return cup_points.get(a.name, 0) < cup_points.get(b.name, 0))
	var course: Dictionary = settings.course
	if settings.mode == CUP:
		course = settings.cup.courses[cup_round]
	return {
		"mode": settings.mode, "course": course, "laps": int(settings.laps) if settings.mode == SINGLE else int(course.get("laps", 3)),
		"difficulty": settings.difficulty, "entries": entries, "round": cup_round,
		"rounds": settings.cup.get("courses", []).size() if settings.mode == CUP else 1,
		"cup_name": settings.cup.get("name", ""), "points": cup_points,
	}


## A device has its race loaded. Once everyone has, the countdown starts.
@rpc("any_peer", "call_local", "reliable")
func _race_loaded() -> void:
	if not is_host():
		return
	_loaded[multiplayer.get_remote_sender_id()] = true
	_maybe_go()


func _maybe_go() -> void:
	if setup.is_empty() or race == null:
		return
	for peer in members:
		if not _loaded.has(peer):
			return
	_go.rpc()


## The host ends the race and says the order everyone finished in. In a cup
## the points go on, and everyone sees the standings. Otherwise everyone goes
## back to the lobby.
func end_race(order: Array) -> void:
	if not is_host():
		return
	_race_over.rpc(order)


func next_round() -> void:
	if not is_host():
		return
	cup_round += 1
	if cup_round >= setup.get("rounds", 1):
		back_to_lobby()
		return
	_begin_round()


func back_to_lobby() -> void:
	if not is_host():
		return
	setup = {}
	for peer in members:
		members[peer].ready = peer == 1 and role == Role.HOST
	_to_lobby.rpc(members, settings)


# Everyone.

func set_ready(ready: bool) -> void:
	if role == Role.CLIENT:
		_set_ready.rpc_id(1, ready)
	elif role == Role.HOST:
		members[1].ready = ready
		_share()


@rpc("any_peer", "reliable")
func _set_ready(ready: bool) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if is_host() and members.has(peer):
		members[peer].ready = ready
		_share()


func _on_connected() -> void:
	var info := _me()
	info.version = VERSION
	_hello.rpc_id(1, info)


func _on_failed() -> void:
	_end("I couldn't reach that game.")


func _on_host_gone() -> void:
	_end("The host left the game.")


func _end(reason: String) -> void:
	last_problem = reason
	leave()
	ended.emit(reason)


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	_end(reason)


@rpc("authority", "reliable")
func _lobby(everyone: Dictionary, what: Dictionary) -> void:
	members = everyone
	settings = what
	changed.emit()


## Sets the race up here, from the host's setup, and shows it.
@rpc("authority", "call_local", "reliable")
func _begin(race_setup: Dictionary) -> void:
	setup = race_setup
	DirAccess.make_dir_recursive_absolute("user://net")
	# Named for this copy of the game, since two copies on one computer (the
	# network tests) share the same folder.
	var path := "user://net/course_%d.json" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(race_setup.course))
	file = null
	if race_setup.mode == CUP:
		Game.mode = Game.MODE_GRAND_PRIX
		if Game.grand_prix == null or int(race_setup.round) == 0:
			Game.grand_prix = GrandPrix.new({"id": "net", "name": race_setup.cup_name, "paths": []})
		var gp := Game.grand_prix
		gp.round = int(race_setup.round)
		gp.difficulty = race_setup.difficulty
		gp.cup.paths = []
		for i in int(race_setup.rounds):
			gp.cup.paths.append(path)
		gp.points = race_setup.points.duplicate()
	else:
		Game.mode = Game.MODE_RACE
		Game.grand_prix = null
	race_begun.emit()
	if role == Role.SERVER:
		Game.show_server_race(path)
	else:
		Game.show_race(path)


@rpc("authority", "call_local", "reliable")
func _go() -> void:
	if race != null:
		race.go()


@rpc("authority", "call_local", "reliable")
func _gone(peer: int) -> void:
	if race != null:
		race.forget(peer)


@rpc("authority", "call_local", "reliable")
func _race_over(order: Array) -> void:
	race = null
	if setup.get("mode", SINGLE) == CUP and Game.grand_prix != null:
		Game.grand_prix.add_results(order)
		if is_host():
			cup_points = Game.grand_prix.points.duplicate()
		race_over.emit(order)
		# A server has nobody to show the standings to.
		if role != Role.SERVER:
			Game.show_net_standings()
	else:
		race_over.emit(order)
		if role != Role.SERVER:
			Game.show_lobby()


@rpc("authority", "call_local", "reliable")
func _to_lobby(everyone: Dictionary, what: Dictionary) -> void:
	members = everyone
	settings = what
	setup = {}
	race = null
	Game.grand_prix = null
	if role != Role.SERVER:
		Game.show_lobby()


## The race tells us it's loaded and ready to count down.
func race_ready(net_race: NetRace) -> void:
	race = net_race
	if is_host():
		_loaded[1] = true
		_maybe_go()
	else:
		_race_loaded.rpc_id(1)


# While racing. The race's own NetRace does the work, and these just carry it.

@rpc("any_peer", "unreliable_ordered")
func kart_state(slot: int, state: PackedFloat32Array) -> void:
	if race != null:
		race.got_state(multiplayer.get_remote_sender_id(), slot, state)


@rpc("any_peer", "reliable")
func kart_event(slot: int, kind: String, data: Variant) -> void:
	if race != null:
		race.got_event(multiplayer.get_remote_sender_id(), slot, kind, data)


## A kart's finished, by the host's clock, so everyone agrees on the order.
@rpc("authority", "reliable")
func finished(slot: int, time: float) -> void:
	if race != null:
		race.got_finish(slot, time)
