class_name Controllers
extends Node

## Which controller belongs to which player. A controller that's plugged in
## goes to the first player without one, preferring a player whose
## controller was this kind last time, so it comes back to the same player.
## The settings let you swap them round.
##
## With one player on their own, any controller drives (see
## LocalPlayerInput), so this matters for split screen and the menus.

signal changed
## A player's controller has come unplugged.
signal unplugged(person: int)

const PLAYERS := 2

## Device id to player, 0 for player 1.
var owners := {}
var settings: ConfigFile


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_connection)
	for device in Input.get_connected_joypads():
		_give(device)


## The controller player `person` has, or -1.
func device_of(person: int) -> int:
	for device in owners:
		if owners[device] == person:
			return device
	return -1


## Whose a controller is, or -1.
func owner_of(device: int) -> int:
	return owners.get(device, -1)


## Gives a controller to a player. The one they had goes to whoever had this
## one, so it's a swap.
func give(device: int, person: int) -> void:
	var had := device_of(person)
	var was: int = owners.get(device, -1)
	owners[device] = person
	if had != -1 and had != device:
		if was == -1:
			owners.erase(had)
		else:
			owners[had] = was
	_remember()
	changed.emit()


## What kind of controller it is, the same for every one of that kind.
static func _guid(device: int) -> String:
	return Input.get_joy_guid(device) if Input.get_connected_joypads().has(device) else ""


## What a controller is called, like "Xbox Wireless Controller".
static func name_of(device: int) -> String:
	var name := Input.get_joy_name(device) if Input.get_connected_joypads().has(device) else ""
	return name if name != "" else "Controller %d" % (device + 1)


func _on_connection(device: int, connected: bool) -> void:
	if connected:
		_give(device)
	else:
		var person: int = owners.get(device, -1)
		owners.erase(device)
		if person != -1:
			unplugged.emit(person)
	changed.emit()


func _give(device: int) -> void:
	if owners.has(device):
		return
	var guid := _guid(device)
	var free := []
	for person in PLAYERS:
		if device_of(person) == -1:
			free.append(person)
	if free.is_empty():
		return
	var person: int = free[0]
	for wants in free:
		if settings != null and settings.get_value("controllers", "player_%d" % (wants + 1), "") == guid:
			person = wants
			break
	owners[device] = person
	_remember()


func _remember() -> void:
	if settings == null:
		return
	for person in PLAYERS:
		var device := device_of(person)
		if device != -1:
			settings.set_value("controllers", "player_%d" % (person + 1), _guid(device))
