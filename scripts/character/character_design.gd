class_name CharacterDesign
extends RefCounted

## A driver as the player built them, with a name and a style and colour for
## each piece (face, hair, facial hair, headgear, neck, torso, back, arms and
## legs). Like a kart design it's plain data, so it saves as a small file and
## goes to other players in a network game.
##
## The weight of their pieces goes into the kart like any other part, so a
## heavy driver makes a heavier, steadier kart and a light one a quicker,
## twitchier one.

const PIECES_PATH := "res://data/characters/pieces.json"
## "head" is the face and the skin colour.
const SLOTS := ["head", "hair", "facial_hair", "headgear", "neck", "torso", "back", "arms", "legs"]
## What a driver saved without a slot gets for it.
const DEFAULTS := {
	"hair": ["none", "#6b4430"],
	"facial_hair": ["none", "#6b4430"],
	"neck": ["none", "#c4281c"],
	"back": ["none", "#3c3f44"],
}
## Headgear styles that are hair now, for drivers saved with them as headgear.
const HAIR_THAT_WAS_HEADGEAR := { "spiky_hair": "spiky", "ponytail": "ponytail" }
const LIGHT_BELOW := 36.0
const HEAVY_FROM := 44.0
const SAVE_DIR := "user://drivers"

static var _pieces: Dictionary = {}

var name := "Driver"
## slot -> { "style": String, "color": Color }
var pieces := {}


static func catalog() -> Dictionary:
	if _pieces.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(PIECES_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			_pieces = data
	return _pieces


static func styles(slot: String) -> Array:
	return catalog().get(slot, {}).keys()


static func piece(slot: String, style: String) -> Dictionary:
	return catalog().get(slot, {}).get(style, {})


static func palette(for_skin := false) -> Array[Color]:
	return _colours("skin" if for_skin else "palette")


## The colours a slot can be: skin tones for the face, hair colours for hair
## and facial hair, and the usual palette for everything else.
static func colours_for(slot: String) -> Array[Color]:
	match slot:
		"head":
			return _colours("skin")
		"hair", "facial_hair":
			return _colours("hair_colours")
	return _colours("palette")


static func _colours(list: String) -> Array[Color]:
	var out: Array[Color] = []
	for hex in catalog().get(list, []):
		out.append(Color(hex))
	return out


static func from_dict(data: Dictionary) -> CharacterDesign:
	var design := CharacterDesign.new()
	design.name = str(data.get("name", "Driver"))
	for slot in SLOTS:
		var fallback: Array = DEFAULTS.get(slot, [styles(slot)[0] if not styles(slot).is_empty() else "", "#f2cd37"])
		var entry: Dictionary = data.get(slot, {})
		var style := str(entry.get("style", fallback[0]))
		if piece(slot, style).is_empty() and not styles(slot).is_empty():
			style = fallback[0] if not piece(slot, fallback[0]).is_empty() else styles(slot)[0]
		design.pieces[slot] = { "style": style, "color": Color(str(entry.get("color", fallback[1]))) }
	# Spiky hair and the ponytail move from headgear to hair.
	var old_gear := str(data.get("headgear", {}).get("style", ""))
	if HAIR_THAT_WAS_HEADGEAR.has(old_gear) and not data.has("hair"):
		design.pieces["hair"] = { "style": HAIR_THAT_WAS_HEADGEAR[old_gear], "color": Color(str(data.headgear.get("color", "#6b4430"))) }
		design.pieces["headgear"] = { "style": "none", "color": design.color_of("headgear") }
	return design


static func load_file(path: String) -> CharacterDesign:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("I couldn't read the driver at %s" % path)
		return from_dict({})
	return from_dict(data)


func to_dict() -> Dictionary:
	var out := { "name": name }
	for slot in SLOTS:
		out[slot] = { "style": style_of(slot), "color": "#" + color_of(slot).to_html(false) }
	return out


func duplicate_design() -> CharacterDesign:
	return CharacterDesign.from_dict(to_dict())


func style_of(slot: String) -> String:
	return pieces.get(slot, {}).get("style", "")


func color_of(slot: String) -> Color:
	return pieces.get(slot, {}).get("color", Color.WHITE)


func set_piece(slot: String, style := "", color := Color(0, 0, 0, 0)) -> void:
	var entry: Dictionary = pieces.get(slot, {}).duplicate()
	if style != "":
		entry["style"] = style
	if color.a > 0.0:
		entry["color"] = color
	pieces[slot] = entry


## Whether this piece has a flag set in the catalogue, like bare arms or boots.
func has(slot: String, flag: String) -> bool:
	return bool(piece(slot, style_of(slot)).get(flag, false))


## A setting of this piece in the catalogue, like how long the sleeves are.
func setting(slot: String, key: String, fallback: Variant = "") -> Variant:
	return piece(slot, style_of(slot)).get(key, fallback)


## Skin shows on the head, and on bare arms and legs.
func skin() -> Color:
	return color_of("head")


func mass() -> float:
	var total := 0.0
	for slot in SLOTS:
		total += float(piece(slot, style_of(slot)).get("mass", 0.0))
	return total


func weight_class() -> String:
	var m := mass()
	if m < LIGHT_BELOW:
		return "Light"
	if m >= HEAVY_FROM:
		return "Heavy"
	return "Medium"


func save() -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := "%s/%s.json" % [SAVE_DIR, KartDesign.file_name_for(name)]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return path


## A new driver made of random pieces and colours.
static func random(rng: RandomNumberGenerator) -> CharacterDesign:
	var design := CharacterDesign.new()
	design.name = "Driver"
	for slot in SLOTS:
		var options := styles(slot)
		var colours := colours_for(slot)
		var style: String = options[rng.randi() % options.size()]
		# Plenty of drivers have nothing on their neck or back, or no beard.
		if slot in ["facial_hair", "neck", "back"] and rng.randf() < 0.5:
			style = "none"
		design.pieces[slot] = { "style": style, "color": colours[rng.randi() % colours.size()] }
	return design
