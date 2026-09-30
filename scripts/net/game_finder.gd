class_name GameFinder
extends Node

## Finds games on the same network, and lets a host be found.
##
## A host says it's there every second with a little broadcast on the local
## network, and anyone looking listens for them. This works on phones,
## computers and the dedicated server alike. On Android, NSD finds games too
## through the SnapRacers plugin, and both lists are merged into one. A web
## page can't do either, so it's given an address instead.
##
## A game played on your own advertises nothing.

signal found_changed

const PORT := 27281
const EVERY := 1.0
## A game that hasn't been heard from for this long has gone.
const FORGET_AFTER := 4.0

## What a host says about itself, while it's advertising.
var advert := {}
## Games found, by address: { "name", "players", "most", "port", "version",
## "heard" (when) }.
var found := {}

var _sender: PacketPeerUDP
var _listener: PacketPeerUDP
var _send_in := 0.0
var _clock := 0.0


## Starts telling the network about this game.
func advertise(info: Dictionary) -> void:
	advert = info
	if _sender == null:
		_sender = PacketPeerUDP.new()
		_sender.set_broadcast_enabled(true)
		_sender.set_dest_address("255.255.255.255", PORT)
	if Game.plugin.has():
		Game.plugin.android.nsd_advertise(str(info.get("name", "SnapRacers")), int(info.get("port", NetSession.PORT)))


func stop_advertising() -> void:
	advert = {}
	if _sender != null:
		_sender.close()
		_sender = null
	if Game.plugin.has():
		Game.plugin.android.nsd_stop_advertising()


## Starts looking for games.
func look() -> void:
	if OS.has_feature("web"):
		return
	if _listener == null:
		_listener = PacketPeerUDP.new()
		if _listener.bind(PORT) != OK:
			_listener = null
	if Game.plugin.has():
		if not Game.plugin.found.is_connected(_on_nsd_found):
			Game.plugin.found.connect(_on_nsd_found)
			Game.plugin.lost.connect(_on_nsd_lost)
		# Some phones drop broadcasts to save power unless asked not to.
		Game.plugin.android.hear_broadcasts(true)
		Game.plugin.android.nsd_look()


func stop_looking() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	if Game.plugin.has() and Game.plugin.found.is_connected(_on_nsd_found):
		Game.plugin.found.disconnect(_on_nsd_found)
		Game.plugin.lost.disconnect(_on_nsd_lost)
		Game.plugin.android.hear_broadcasts(false)
		Game.plugin.android.nsd_stop_looking()
	found.clear()


func _exit_tree() -> void:
	stop_advertising()
	stop_looking()


func _process(delta: float) -> void:
	_clock += delta
	if _sender != null and not advert.is_empty():
		_send_in -= delta
		if _send_in <= 0.0:
			_send_in = EVERY
			var message := advert.duplicate()
			message.game = "snapracers"
			_sender.put_packet(JSON.stringify(message).to_utf8_buffer())
	var any_change := false
	if _listener != null:
		while _listener.get_available_packet_count() > 0:
			var packet := _listener.get_packet()
			var address := _listener.get_packet_ip()
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data is Dictionary and data.get("game", "") == "snapracers":
				data.heard = _clock
				if not found.has(address):
					any_change = true
				found[address] = data
	for address in found.keys():
		if _clock - float(found[address].heard) > FORGET_AFTER:
			found.erase(address)
			any_change = true
	if any_change:
		found_changed.emit()


## A game NSD found (see the Android plugin). The ones it finds over Wi-Fi
## Direct and Bluetooth are the online screen's to show.
func _on_nsd_found(how: String, game: Dictionary) -> void:
	if how != "nsd":
		return
	var address := str(game.address)
	# NSD finds this phone's own game too.
	if address in Connections.my_addresses():
		return
	var was := found.has(address)
	# NSD says when a game's gone (see _on_nsd_lost), but in case it doesn't,
	# it's forgotten after a minute anyway.
	found[address] = {"name": str(game.name), "nsd": str(game.name), "port": int(game.port), "heard": _clock + 60.0, "version": NetSession.VERSION}
	if not was:
		found_changed.emit()


func _on_nsd_lost(how: String, game_name: String) -> void:
	if how != "nsd":
		return
	for address in found.keys():
		if found[address].get("nsd", "") == game_name:
			found.erase(address)
			found_changed.emit()
