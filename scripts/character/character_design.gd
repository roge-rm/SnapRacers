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
## "head" is the face and the skin colour. Its style is a named face from
## FacePrint.FACES. A face built from separate parts keeps them in "face" as
## well (see face()), and the style is the named face it started from.
const SLOTS := ["head", "hair", "facial_hair", "headgear", "neck", "torso", "back", "arms", "legs"]
## What a driver saved without a slot gets for it.
const DEFAULTS := {
	"hair": ["none", "#6b4430"],
	"facial_hair": ["none", "#6b4430"],
	"neck": ["none", "#c4281c"],
	"back": ["none", "#3c3f44"],
}
## The face's parts, in the order FacePrint has them.
const FACE_PARTS := ["eyes", "brows", "mouth", "extras"]
## Headgear styles that are hair now, for drivers saved with them as headgear.
const HAIR_THAT_WAS_HEADGEAR := { "spiky_hair": "spiky", "ponytail": "ponytail" }
const LIGHT_BELOW := 36.0
const HEAVY_FROM := 44.0
const SAVE_DIR := "user://drivers"
## How a pick of driver for a race is written (see for_key()).
const OWN_KEY := "own"
const SAVED_KEY := "saved:"
const STOCK_KEY := "stock:"

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


## The colours a slot shows first: natural skin tones for the face, natural
## shades for hair and facial hair, and the usual palette for everything else.
## Any other colour comes from More colours.
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
		design.pieces[slot] = { "style": style, "color": Paints.read(entry.get("color", fallback[1]), Color(fallback[1])) }
		if slot == "head" and entry.get("face") is Dictionary:
			design.pieces.head["face"] = _read_face(entry.face, style)
			design._settle_face()
	# Spiky hair and the ponytail move from headgear to hair.
	var old_gear := str(data.get("headgear", {}).get("style", ""))
	if HAIR_THAT_WAS_HEADGEAR.has(old_gear) and not data.has("hair"):
		design.pieces["hair"] = { "style": HAIR_THAT_WAS_HEADGEAR[old_gear], "color": Paints.read(data.headgear.get("color", "#6b4430"), Color("#6b4430")) }
		design.pieces["headgear"] = { "style": "none", "color": design.color_of("headgear") }
	return design


## Whether `data` has the shape from_dict reads: each piece a dictionary
## with a text style and a colour code. For drivers sent over the network.
static func well_formed(data: Dictionary) -> bool:
	if data.has("name") and not data.name is String:
		return false
	for slot in SLOTS:
		if not data.has(slot):
			continue
		var entry = data[slot]
		if not entry is Dictionary:
			return false
		if entry.has("style") and not (entry.style is String and entry.style.length() <= 64):
			return false
		if entry.has("color") and not (entry.color is String and entry.color.length() <= 32):
			return false
		if slot == "head" and entry.has("face") and not face_well_formed(entry.face):
			return false
	return true


## Whether a face's parts have the shape from_dict reads: text for the eyes,
## brows and mouth and a short list of text for the extras. Names it doesn't
## know are fine, as they're swapped for the named face's own.
static func face_well_formed(face: Variant) -> bool:
	if not face is Dictionary or face.size() > 8:
		return false
	for part in ["eyes", "brows", "mouth"]:
		if face.has(part) and not (face[part] is String and face[part].length() <= 40):
			return false
	if face.has("extras"):
		if not face.extras is Array or face.extras.size() > 16:
			return false
		for extra in face.extras:
			if not (extra is String and extra.length() <= 40):
				return false
	return true


## The parts saved for a face, with any it doesn't know (from a later
## version, say) swapped for the named face's own.
static func _read_face(data: Dictionary, style: String) -> Array:
	var named := FacePrint.parts_of(style)
	var out := named.duplicate(true)
	for i in 3:
		var value = data.get(FACE_PARTS[i])
		if value is String and value in FacePrint.PARTS[FACE_PARTS[i]]:
			out[i] = value
	if data.get("extras") is Array:
		var extras := []
		for extra in data.extras:
			if extra is String and (extra in FacePrint.EXTRAS or extra == "blush") and not extras.has(extra):
				extras.append(extra)
		out[3] = extras
	return out


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
	var own = pieces.get("head", {}).get("face")
	if own is Array:
		out.head["face"] = { "eyes": own[0], "brows": own[1], "mouth": own[2], "extras": own[3].duplicate() }
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
		# Picking a named face takes all of it.
		entry.erase("face")
	if color.a > 0.0:
		entry["color"] = color
	pieces[slot] = entry


## Whether the face is built from parts that aren't a named face.
func has_own_face() -> bool:
	return pieces.get("head", {}).get("face") is Array


## The face's parts, [eyes, brows, mouth, extras]: its own if they've been
## picked separately, or else the named face's.
func face() -> Array:
	var own = pieces.get("head", {}).get("face")
	return own.duplicate(true) if own is Array else FacePrint.parts_of(style_of("head")).duplicate(true)


## Changes one part of the face: "eyes", "brows" or "mouth" to a shape's
## name, or "extras" to a list of them. If that makes a named face, it
## becomes that face.
func set_face_part(part: String, value: Variant) -> void:
	var i := FACE_PARTS.find(part)
	if i < 0:
		return
	var parts := face()
	parts[i] = value.duplicate() if value is Array else value
	var entry: Dictionary = pieces.get("head", {}).duplicate()
	entry["face"] = parts
	pieces["head"] = entry
	_settle_face()


## Drops the face's own parts when they're the same as a named face's, its
## own first.
func _settle_face() -> void:
	var own = pieces.get("head", {}).get("face")
	if not own is Array:
		return
	var names: Array = [style_of("head")] + FacePrint.FACES.keys()
	for named in names:
		if not piece("head", named).is_empty() and FacePrint.parts_of(named) == own:
			pieces.head["style"] = named
			pieces.head.erase("face")
			return


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


## Saves into the player's own drivers folder, named after the driver. Returns
## the path it was saved to, or an empty string if it couldn't be written.
## Saves to the file named after the driver, or to `path` if one is given.
func save(path := "") -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if path == "":
		path = "%s/%s.json" % [SAVE_DIR, file_name_for(name)]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("I couldn't save the driver to %s" % path)
		return ""
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return path


static func file_name_for(driver_name: String) -> String:
	var clean := KartDesign.file_name_for(driver_name)
	return "driver" if clean == "kart" and driver_name.strip_edges().to_lower() != "kart" else clean


## Every driver the player has saved, as paths.
static func saved_paths() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".json"):
			out.append("%s/%s" % [SAVE_DIR, file])
	out.sort()
	return out


## Every driver the player has saved, in file order, as { key, name, path }.
## The key is "saved:" and the file's name without .json.
static func saved_drivers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path in saved_paths():
		out.append({ "key": SAVED_KEY + path.get_file().get_basename(), "name": load_file(path).name, "path": path })
	return out


## The pick keys for every driver you can race as: your own (the one on the
## driver screen), then the saved ones, then the stock ones.
static func pick_keys() -> Array[String]:
	var keys: Array[String] = [OWN_KEY]
	for entry in saved_drivers():
		keys.append(entry.key)
	for key in _game().stock_driver_keys():
		keys.append(STOCK_KEY + key)
	return keys


## The driver for a pick key: "own" is the one on the driver screen,
## "saved:<file>" one in the drivers folder and "stock:<file>" one from the
## roster. A saved or stock driver that's gone gives your own instead. It's
## always a copy, so changing it changes nothing else.
static func for_key(key: String) -> CharacterDesign:
	var game := _game()
	if key.begins_with(SAVED_KEY):
		var path := "%s/%s.json" % [SAVE_DIR, key.trim_prefix(SAVED_KEY)]
		if FileAccess.file_exists(path):
			return load_file(path)
	elif key.begins_with(STOCK_KEY):
		var path := "%s/%s.json" % [game.ROSTER, key.trim_prefix(STOCK_KEY)]
		if FileAccess.file_exists(path):
			return load_file(path)
	return (game.character as CharacterDesign).duplicate_design()


## The Game autoload, looked up when it's needed so this script still
## compiles in the -s tests, which have no autoloads.
static func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Game")


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
