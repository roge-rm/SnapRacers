class_name KartDesign
extends RefCounted

## A kart as the player built it: which parts, where they sit on the grid and
## which way they're turned. This is what gets saved, and what gets sent to
## other players in a network game, so it stays plain data.
##
## It also knows the building rules. Parts join the way real bricks do: studs
## on top of one part press into the bottom of the part above, as long as
## they overlap. Wheels are the exception. They have no studs and clip onto
## the side of a part by their axle instead.

## How big a kart can be, in studs across, plates high and studs long.
const BUILD_SIZE := Vector3i(20, 30, 24)
const SAVE_DIR := "user://karts"

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
			"rot": posmod(int(entry.get("rot", 0)), 4),
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


func duplicate_design() -> KartDesign:
	return KartDesign.from_dict(to_dict())


## Saves into the player's own karts folder, named after the kart. Returns the
## path it was saved to, or an empty string if it couldn't be written.
func save() -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := "%s/%s.json" % [SAVE_DIR, file_name_for(name)]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("I couldn't save the kart to %s" % path)
		return ""
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return path


static func file_name_for(kart_name: String) -> String:
	var clean := ""
	for c in kart_name.strip_edges().to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			clean += c
		elif not clean.ends_with("_"):
			clean += "_"
	clean = clean.trim_prefix("_").trim_suffix("_")
	return clean if clean != "" else "kart"


## Every kart the player has saved, as paths.
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


# Building rules.

func box_of(index: int) -> AABB:
	return part_box(parts[index].id, parts[index].at, parts[index].rot)


static func part_box(id: String, at: Vector3i, rot: int) -> AABB:
	var def := PartCatalog.get_part(id)
	var size := Grid.rotated_size(def.get("size", Vector3i.ONE), rot)
	return AABB(Vector3(at), Vector3(size))


static func is_wheel(id: String) -> bool:
	return PartCatalog.get_part(id).get("kind", "") == "wheel"


## Would a part here fit inside the build area without going through anything?
func fits(id: String, at: Vector3i, rot: int, ignore := -1) -> bool:
	var box := part_box(id, at, rot)
	if box.position.x < 0 or box.position.y < 0 or box.position.z < 0:
		return false
	if box.end.x > BUILD_SIZE.x or box.end.y > BUILD_SIZE.y or box.end.z > BUILD_SIZE.z:
		return false
	for i in parts.size():
		if i != ignore and _overlap_volume(box, box_of(i)) > 0.0:
			return false
	return true


## Do these two parts hold onto each other?
static func joined(id_a: String, box_a: AABB, id_b: String, box_b: AABB) -> bool:
	var wheel_a := is_wheel(id_a)
	var wheel_b := is_wheel(id_b)
	if wheel_a and wheel_b:
		return false
	if not wheel_a and not wheel_b:
		# Studs: one sits right on top of the other and they overlap from above.
		var stacked := is_equal_approx(box_a.end.y, box_b.position.y) or is_equal_approx(box_b.end.y, box_a.position.y)
		return stacked and _overlap_area(box_a, box_b, Vector3.AXIS_Y) > 0.0
	# Axle: the wheel's flat side is against the side of the part.
	var side_by_side := is_equal_approx(box_a.end.x, box_b.position.x) or is_equal_approx(box_b.end.x, box_a.position.x)
	return side_by_side and _overlap_area(box_a, box_b, Vector3.AXIS_X) > 0.0


## Would a part here be held on by anything? The first part always is.
func attaches(id: String, at: Vector3i, rot: int, ignore := -1) -> bool:
	var box := part_box(id, at, rot)
	var others := 0
	for i in parts.size():
		if i == ignore:
			continue
		others += 1
		if joined(id, box, parts[i].id, box_of(i)):
			return true
	return others == 0


## Which parts each part is joined to, as lists of indices.
func links() -> Array:
	var out := []
	for i in parts.size():
		out.append([])
	for i in parts.size():
		for j in range(i + 1, parts.size()):
			if joined(parts[i].id, box_of(i), parts[j].id, box_of(j)):
				out[i].append(j)
				out[j].append(i)
	return out


## Splits the kart into the groups of parts that hold together. A finished
## kart is one group. Crashes will use this to work out what falls off with a
## part that breaks away.
func groups() -> Array:
	var link := links()
	var seen := {}
	var out := []
	for start in parts.size():
		if seen.has(start):
			continue
		var group := []
		var todo := [start]
		seen[start] = true
		while not todo.is_empty():
			var i: int = todo.pop_back()
			group.append(i)
			for j in link[i]:
				if not seen.has(j):
					seen[j] = true
					todo.append(j)
		out.append(group)
	return out


## Everything stopping this kart from being driven, in words for the player.
## An empty list means it's good to go.
func problems() -> Array[String]:
	var out: Array[String] = []
	var seats := 0
	var engines := 0
	var wheels := 0
	var lowest_wheel := 1 << 20
	var lowest_other := 1 << 20
	for i in parts.size():
		var def := PartCatalog.get_part(parts[i].id)
		match def.get("kind", ""):
			"seat":
				seats += 1
			"engine":
				engines += 1
			"wheel":
				wheels += 1
				lowest_wheel = mini(lowest_wheel, parts[i].at.y)
				continue
		lowest_other = mini(lowest_other, parts[i].at.y)
	if parts.is_empty():
		out.append("Pick a part on the left to start building.")
		return out
	if seats == 0:
		out.append("It needs a seat for the driver.")
	if engines == 0:
		out.append("It needs an engine.")
	if wheels < 3:
		out.append("It needs at least three wheels.")
	if groups().size() > 1:
		out.append("Some parts aren't attached to the rest.")
	for i in parts.size():
		for j in range(i + 1, parts.size()):
			if _overlap_volume(box_of(i), box_of(j)) > 0.0:
				out.append("Two parts are inside each other.")
				return out
	if wheels > 0 and lowest_other < lowest_wheel:
		out.append("Something hangs down below the wheels and would scrape along the ground.")
	return out


static func _overlap_volume(a: AABB, b: AABB) -> float:
	var i := a.intersection(b)
	return i.size.x * i.size.y * i.size.z if i.has_volume() else 0.0


## How much two boxes overlap when you look along one axis.
static func _overlap_area(a: AABB, b: AABB, axis: int) -> float:
	var total := 1.0
	for k in 3:
		if k == axis:
			continue
		var d := minf(a.end[k], b.end[k]) - maxf(a.position[k], b.position[k])
		if d <= 0.0:
			return 0.0
		total *= d
	return total
