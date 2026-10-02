class_name PartCatalog
extends RefCounted

## Every part the game knows about. The first parts are in data/parts.json,
## and the ones modelled by tools/parts are in data/parts_made.json, with
## their meshes, connectors and solid boxes.

const PATH := "res://data/parts.json"
const MADE_PATH := "res://data/parts_made.json"

static var _parts: Dictionary = {}


static func get_part(id: String) -> Dictionary:
	_load()
	return _parts.get(id, {})


static func ids() -> Array:
	_load()
	return _parts.keys()


## The parts the garage offers: all of them but the old ones a modelled part
## has replaced (see "replaced_by" in parts.json), which only stay so karts
## built with them still load.
static func in_garage() -> Array:
	return ids().filter(func(id: String) -> bool: return not _parts[id].has("replaced_by"))


## The box a part fills before it's turned, in the fine unit (see Grid).
static func fine_size(id: String) -> Vector3:
	var def := get_part(id)
	if def.has("fine_size"):
		return def.fine_size
	return Grid.fine_size(def.get("size", Vector3i.ONE))


static func _load() -> void:
	if not _parts.is_empty():
		return
	for path in [PATH, MADE_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY or not data.has("parts"):
			push_error("I couldn't read the part catalogue at %s" % path)
			continue
		for id in data.parts:
			_parts[id] = _read(id, data.parts[id])


static func _read(id: String, part: Dictionary) -> Dictionary:
	part["id"] = id
	var s: Array = part.get("size", [1, 1, 1])
	part["size"] = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	part["color"] = Color(part.get("color", "#ffffff"))
	if part.has("fine_size"):
		part["fine_size"] = _vector(part.fine_size)
	if part.has("connectors"):
		var connectors := []
		for c in part.connectors:
			connectors.append({ "type": str(c.type), "at": _vector(c.at), "axis": _vector(c.axis).normalized(), "length": float(c.get("length", 0.0)) })
		part["connectors"] = connectors
	if part.has("solids"):
		var solids: Array[AABB] = []
		for b in part.solids:
			solids.append(AABB(_vector(b.slice(0, 3)), _vector(b.slice(3, 6)) - _vector(b.slice(0, 3))))
		part["solids"] = solids
	if part.has("seat_box"):
		var b: Array = part.seat_box
		part["seat_box"] = AABB(_vector(b.slice(0, 3)), _vector(b.slice(3, 6)) - _vector(b.slice(0, 3)))
	if part.has("trim"):
		part.trim["color"] = Color(part.trim.color)
	return part


static func _vector(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
