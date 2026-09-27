class_name KartDesign
extends RefCounted

## A kart as the player built it: which parts, where they sit on the grid and
## which way they're turned. This is what gets saved, and what gets sent to
## other players in a network game, so it stays plain data.

var name := "Kart"
## Each entry is { "id": String, "at": Vector3i, "rot": int }.
var parts: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> KartDesign:
	var design := KartDesign.new()
	design.name = str(data.get("name", "Kart"))
	for entry in data.get("parts", []):
		var at: Array = entry.get("at", [0, 0, 0])
		design.parts.append({
			"id": str(entry.get("id", "")),
			"at": Vector3i(int(at[0]), int(at[1]), int(at[2])),
			"rot": int(entry.get("rot", 0)),
		})
	return design


static func load_file(path: String) -> KartDesign:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("I couldn't read the kart at %s" % path)
		return KartDesign.new()
	return from_dict(data)


func to_dict() -> Dictionary:
	var out := []
	for p in parts:
		out.append({ "id": p.id, "at": [p.at.x, p.at.y, p.at.z], "rot": p.rot })
	return { "name": name, "parts": out }
