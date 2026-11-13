class_name DriverTraits
extends RefCounted

## How an AI driver likes to race, each from -1 to 1 with 0 the level's own
## way (see Difficulty.personalise()). Stock drivers have theirs in their
## roster file under "traits", anyone else gets a mix from their name, so the
## same driver always races the same way and every device works out the same.
## - aggression: closer to other karts, quicker to go for a gap and, where
##   the level allows rubbing, more willing to lean on them.
## - patience: how much a pass has to be worth before it pulls out to try it,
##   and how long it sticks with the side it picked.
## - consistency: fewer misjudged bends and less wander off its line.
## - late_braking: how late it brakes for bends, with more misjudged ones.

const NAMES := ["aggression", "patience", "consistency", "late_braking"]
const ROSTER := "res://data/characters/roster"
## The most a mix from a name goes either way, so made up drivers are
## never as extreme as the stock ones can be.
const FROM_NAME := 0.7

var aggression := 0.0
var patience := 0.0
var consistency := 0.0
var late_braking := 0.0


static func from_dict(data: Dictionary) -> DriverTraits:
	var traits := DriverTraits.new()
	for trait_name in NAMES:
		traits.set(trait_name, clampf(float(data.get(trait_name, 0.0)), -1.0, 1.0))
	return traits


func to_dict() -> Dictionary:
	var out := {}
	for trait_name in NAMES:
		out[trait_name] = get(trait_name)
	return out


## A driver's traits from a stable hash of their name.
static func from_name(driver_name: String) -> DriverTraits:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("traits/" + driver_name)
	var traits := DriverTraits.new()
	for trait_name in NAMES:
		traits.set(trait_name, snappedf(rng.randf_range(-FROM_NAME, FROM_NAME), 0.01))
	return traits


## A stock driver's traits from their roster file, by file name, or null
## when there's no such file or it has none.
static func for_roster(key: String) -> DriverTraits:
	var path := "%s/%s.json" % [ROSTER, key]
	if key == "" or not FileAccess.file_exists(path):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("traits")) != TYPE_DICTIONARY:
		return null
	return from_dict(data.traits)


## The traits for a driver: the roster file's for a stock driver, by its
## key or else by the name on it, otherwise a mix from their name.
static func for_driver(key: String, driver_name: String) -> DriverTraits:
	var traits := for_roster(key)
	if traits == null:
		traits = for_roster(_roster_key_of(driver_name))
	return traits if traits != null else from_name(driver_name)


## Which roster file has this name on it, or "".
static func _roster_key_of(driver_name: String) -> String:
	for file in DirAccess.get_files_at(ROSTER):
		if not file.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(ROSTER + "/" + file))
		if typeof(data) == TYPE_DICTIONARY and str(data.get("name", "")) == driver_name:
			return file.get_basename()
	return ""
