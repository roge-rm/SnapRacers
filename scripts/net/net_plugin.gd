class_name NetPlugin
extends Node

## The game's end of the Android plugin (android-plugin), which finds games
## with NSD, joins and hosts over Wi-Fi Direct, carries a game over Bluetooth,
## and shares courses and cups with other apps (see ShareSheet). Everywhere
## else (a PC, the web, the server) there's no plugin, and it all just says it
## isn't there.
##
## The plugin puts everything that happens in a queue, and this empties it
## every frame (and whenever the Bluetooth peer polls), turning each thing
## into a signal, or handing it to the Bluetooth peer.

## A game found, with how ("nsd", "direct" or "bluetooth") and what's known
## about it ("name", and "address" and "port", or "device").
signal found(how: String, game: Dictionary)
## A game found with NSD has gone.
signal lost(how: String, game_name: String)
## Looking over Wi-Fi Direct or Bluetooth has finished, or couldn't start.
signal looking_done(how: String, why: String)
signal direct_hosting(ok: bool, why: String)
## Joined a Wi-Fi Direct group, with the host's address to race to, or why not.
signal direct_joined(address: String, why: String)
## A file's been picked to open, with what's in it, or "" and why not.
signal picked(text: String, why: String)

var android: Object
## The Bluetooth game going on, if there is one.
var bluetooth: BluetoothPeer


func _ready() -> void:
	name = "NetPlugin"
	if Engine.has_singleton("SnapRacersNet"):
		android = Engine.get_singleton("SnapRacersNet")


func has() -> bool:
	return android != null


func _process(_delta: float) -> void:
	pump()


## Deals with everything the plugin's said since last time.
func pump() -> void:
	if android == null:
		return
	while true:
		var event: Dictionary = android.poll()
		if event.is_empty():
			return
		match str(event.kind):
			"found":
				found.emit(str(event.how), event)
			"lost":
				lost.emit(str(event.how), str(event.name))
			"looking_done":
				looking_done.emit(str(event.how), str(event.get("why", "")))
			"direct_hosting":
				direct_hosting.emit(bool(event.ok), str(event.why))
			"direct_joined":
				direct_joined.emit(str(event.address), str(event.why))
			"picked":
				picked.emit(str(event.get("text", "")), str(event.get("why", "")))
			"bt_connected", "bt_packet", "bt_left", "bt_failed":
				if bluetooth != null:
					bluetooth.got(event)


## Asks for these Android permissions, one at a time, and says whether they
## were all given.
func allowed(permissions: PackedStringArray) -> bool:
	for permission in permissions:
		if permission in OS.get_granted_permissions():
			continue
		if OS.request_permission(permission):
			continue
		while true:
			var answer: Array = await get_tree().on_request_permissions_result
			if answer[0] == permission:
				if not answer[1]:
					return false
				break
	return true


## Why Wi-Fi Direct can't be used, for the player, or "". It asks for its
## permission first, if it needs to.
func direct_ready() -> String:
	if android == null:
		return "Wi-Fi Direct only works on Android phones."
	await allowed(android.direct_permissions())
	return android.direct_why_not()


## The same for Bluetooth, which also offers to turn it on.
func bluetooth_ready() -> String:
	if android == null:
		return "Bluetooth only works on Android phones."
	await allowed(android.bt_permissions())
	if android.bt_is_off():
		android.bt_ask_to_turn_on()
		# Android's question is on screen now. Waiting for the answer.
		var give_up := Time.get_ticks_msec() + 30000
		while android.bt_is_off() and Time.get_ticks_msec() < give_up:
			await get_tree().create_timer(0.5).timeout
	return android.bt_why_not()
