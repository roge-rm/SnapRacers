class_name CharacterDesign
extends RefCounted

## A driver as the player built them: a name, and a style and colour for each
## of their five pieces. Like a kart design it's plain data, so it saves as a
## small file and travels to other players in a network game.
##
## How heavy the pieces add up to decides the driver's class, and the weight
## goes into the kart like any other part, so a heavy driver makes a heavier,
## steadier kart and a light one a quicker, twitchier one.

const PIECES_PATH := "res://data/characters/pieces.json"
const SLOTS := ["head", "headgear", "torso", "arms", "legs"]
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
	var out: Array[Color] = []
	for hex in catalog().get("skin" if for_skin else "palette", []):
		out.append(Color(hex))
	return out


static func from_dict(data: Dictionary) -> CharacterDesign:
	var design := CharacterDesign.new()
	design.name = str(data.get("name", "Driver"))
	for slot in SLOTS:
		var entry: Dictionary = data.get(slot, {})
		var style := str(entry.get("style", styles(slot)[0] if not styles(slot).is_empty() else ""))
		if piece(slot, style).is_empty() and not styles(slot).is_empty():
			style = styles(slot)[0]
		design.pieces[slot] = { "style": style, "color": Color(str(entry.get("color", "#f2cd37"))) }
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


## Whether this piece has a flag set in the catalog, like bare arms or boots.
func has(slot: String, flag: String) -> bool:
	return bool(piece(slot, style_of(slot)).get(flag, false))


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
	var skins := palette(true)
	var colours := palette()
	for slot in SLOTS:
		var options := styles(slot)
		var colour: Color = skins[rng.randi() % skins.size()] if slot == "head" else colours[rng.randi() % colours.size()]
		design.pieces[slot] = { "style": options[rng.randi() % options.size()], "color": colour }
	return design
