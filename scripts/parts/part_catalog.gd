class_name PartCatalog
extends RefCounted

## Every part the game knows about, read once from data/parts.json.

const PATH := "res://data/parts.json"

static var _parts: Dictionary = {}


static func get_part(id: String) -> Dictionary:
	_load()
	return _parts.get(id, {})


static func ids() -> Array:
	_load()
	return _parts.keys()


static func _load() -> void:
	if not _parts.is_empty():
		return
	var text := FileAccess.get_file_as_string(PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("parts"):
		push_error("I couldn't read the part catalogue at %s" % PATH)
		return
	for id in data.parts:
		var part: Dictionary = data.parts[id]
		part["id"] = id
		var s: Array = part.get("size", [1, 1, 1])
		part["size"] = Vector3i(int(s[0]), int(s[1]), int(s[2]))
		part["color"] = Color(part.get("color", "#ffffff"))
		_parts[id] = part
