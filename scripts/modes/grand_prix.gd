class_name GrandPrix
extends RefCounted

## A Grand Prix, which is four races in a row on the courses of one cup.
##
## Everyone scores points for where they finish each race, and whoever has the
## most after the fourth race wins the cup. From the second race on, the grid
## starts in reverse order of the points so far, so the leader starts at the
## back and has to fight their way through again.

const CUPS := "res://data/grand_prix.json"
## Points for first place, second place and so on down to eighth.
const POINTS := [15, 12, 10, 8, 6, 4, 2, 1]

var cup: Dictionary
## Which race of the four is next, counting from 0.
var round := 0
## Points so far, by racer name.
var points := {}
## Each race's finishing order so far, as lists of names.
var results: Array = []
## The stock kart each AI driver races the whole cup in, as { driver: kart }.
var karts := {}
## The kart you started the cup in (see Game.kart_choice()).
var player_kart := ""
## The AI drivers' pecking order for the whole cup, as { driver: rank }.
var ranks := {}
## How good the AI drivers are, for the whole cup (see Difficulty).
var difficulty := Difficulty.DEFAULT

static var _cups: Array = []


## Every cup, as { "id", "name", "tracks": [track ids] }, easiest first.
static func cups() -> Array:
	if _cups.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(CUPS))
		if typeof(data) == TYPE_DICTIONARY:
			_cups = data.get("cups", [])
	return _cups


static func cup_by_id(id: String) -> Dictionary:
	for c in cups():
		if c.id == id:
			return c
	return {}


func _init(cup_id := "") -> void:
	cup = cup_by_id(cup_id)


func track_ids() -> Array:
	return cup.get("tracks", [])


func track_path() -> String:
	return Tracks.path_of(track_ids()[mini(round, track_ids().size() - 1)])


func finished() -> bool:
	return round >= track_ids().size()


## Adds a race's finishing order (names, winner first) and moves on to the
## next race.
func add_results(order: Array) -> void:
	results.append(order.duplicate())
	for i in order.size():
		points[order[i]] = points.get(order[i], 0) + (POINTS[i] if i < POINTS.size() else 0)
	round += 1


## Everyone and their points, most points first. Ties go to whoever did
## better in the last race.
func standings() -> Array:
	var names := points.keys()
	var last: Array = results[-1] if not results.is_empty() else []
	names.sort_custom(func(a, b) -> bool:
		if points[a] != points[b]:
			return points[a] > points[b]
		return last.find(a) < last.find(b))
	return names.map(func(n): return [n, points[n]])


## Where each racer starts the next race, front of the grid first. The first
## race keeps the usual order, with the player at the back.
func grid_order() -> Array:
	var order := standings().map(func(s): return s[0])
	order.reverse()
	return order
