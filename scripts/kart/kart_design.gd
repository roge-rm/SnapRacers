class_name KartDesign
extends RefCounted

## A kart as the player built it, with its parts, where they sit and which way
## they're turned. It's what gets saved and sent to other players, so it stays
## plain data.
##
## It also knows the building rules. Parts join where their connectors meet
## (see Connectors), the way real bricks do, with the studs on top of one
## pressing into the bottom of the part above. Wheels, fairings and side pods
## clip onto the side of a part instead.

## How big a kart can be, in studs across, plates high and studs long.
const BUILD_SIZE := Vector3i(20, 30, 24)
## How far above the bottom of the wheels everything else has to be, in
## plates, so it doesn't scrape when the springs squash.
const CLEARANCE := 2
const SAVE_DIR := "user://karts"
## How much of a wheel's height its two crossed boxes cover, for bumping
## into other parts.
const ROUND_SHARE := 0.7

var name := "Kart"
## A line about what kind of kart it is, for the stock karts.
var about := ""
## Each entry is { "id": String, "place": Transform3D }, plus "color" (a
## Color) when the part has been painted something other than its own colour.
## The place takes the part's own space to the kart's, in the fine unit (see
## Grid). Each entry also has "at" (Vector3i) and "rot" (int), where it sits
## on the stud grid and how many quarter turns it's turned, for parts that sit
## on the grid flat side down. Make entries with grid_entry() or
## placed_entry() so these agree.
var parts: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> KartDesign:
	var design := KartDesign.new()
	design.name = str(data.get("name", "Kart"))
	design.about = str(data.get("about", ""))
	for entry in data.get("parts", []):
		# Parts the game no longer has, like the gadgets that are power-ups
		# now, are left off.
		if PartCatalog.get_part(str(entry.get("id", ""))).is_empty():
			continue
		var id := str(entry.get("id", ""))
		var color: Variant = Color(str(entry.color)) if entry.has("color") else null
		if entry.has("pos"):
			var pos: Array = entry.pos
			var basis: Basis = Grid.turns()[clampi(int(entry.get("turn", 0)), 0, 23)]
			design.parts.append(placed_entry(id, Transform3D(basis, Vector3(float(pos[0]), float(pos[1]), float(pos[2]))), color))
		else:
			# A kart saved before parts could be turned every way, by where
			# it sat on the stud grid.
			var at: Array = entry.get("at", [0, 0, 0])
			design.parts.append(grid_entry(id, Vector3i(int(at[0]), int(at[1]), int(at[2])), int(entry.get("rot", 0)), color))
	return design


## An entry for a part sitting on the stud grid flat side down, with the
## front left bottom corner of its box at `at` after it's turned `rot`
## quarter turns.
static func grid_entry(id: String, at: Vector3i, rot: int, color: Variant = null) -> Dictionary:
	return placed_entry(id, grid_place(id, at, rot), color)


## An entry for a part put anywhere.
static func placed_entry(id: String, place: Transform3D, color: Variant = null) -> Dictionary:
	var cell := fine_box(id, place).position / Grid.UNIT_FINE
	var turn := Grid.turn_index(place.basis)
	var entry := {
		"id": id,
		"place": place,
		"at": Vector3i(roundi(cell.x), roundi(cell.y), roundi(cell.z)),
		"rot": turn if turn >= 0 and turn < 4 else -1,
	}
	entry["_grid"] = [entry.at, entry.rot]
	if color != null:
		entry["color"] = color
	return entry


## Where a part sitting on the grid goes, as its place.
static func grid_place(id: String, at: Vector3i, rot: int) -> Transform3D:
	return box_place(id, Grid.yaw(rot), at)


## Where a part turned by `basis` goes to have the front left bottom corner
## of its box at `at` on the stud grid.
static func box_place(id: String, basis: Basis, at: Vector3i) -> Transform3D:
	var size := PartCatalog.fine_size(id)
	var low := (Transform3D(basis, Vector3.ZERO) * AABB(Vector3.ZERO, size)).position
	return Transform3D(basis, Vector3(at) * Grid.UNIT_FINE - low)


## How many studs, plates and studs a part turned by `basis` takes up on the
## grid, rounded up.
static func grid_size(id: String, basis: Basis) -> Vector3i:
	var size := (Transform3D(basis, Vector3.ZERO) * AABB(Vector3.ZERO, PartCatalog.fine_size(id))).size / Grid.UNIT_FINE
	return Vector3i(maxi(1, ceili(size.x - 0.01)), maxi(1, ceili(size.y - 0.01)), maxi(1, ceili(size.z - 0.01)))


## Where an entry's part has been put. An entry made the old way, with only
## "at" and "rot", or whose "at" or "rot" has been changed since, gets its
## place worked out again from those.
static func place_of(entry: Dictionary) -> Transform3D:
	var rot := int(entry.get("rot", 0))
	var grid := [entry.get("at", Vector3i.ZERO), rot]
	if not entry.has("place") or (entry.has("at") and rot >= 0 and entry.get("_grid", []) != grid):
		entry["place"] = grid_place(entry.id, grid[0], rot)
		entry["_grid"] = grid
	return entry.place


## The solid boxes of a part where it's been put, in the fine unit. Most parts
## are solid all through their box, but a part with bits sticking out, like a
## wheel holder's pins, says which boxes are solid, so a wheel can go over its
## pin.
static func solid_boxes(id: String, place: Transform3D) -> Array[AABB]:
	var out: Array[AABB] = []
	var def := PartCatalog.get_part(id)
	if def.has("solids"):
		for b in def.solids:
			out.append(place * b)
	elif def.get("kind", "") == "wheel":
		# A wheel is round, so it's two boxes across each other instead of
		# its whole box, and it leaves the corners free.
		var size := PartCatalog.fine_size(id)
		var inset := size.z * (1.0 - ROUND_SHARE) * 0.5
		out.append(place * AABB(Vector3(0.0, 0.0, inset), Vector3(size.x, size.y, size.z - inset * 2.0)))
		out.append(place * AABB(Vector3(0.0, inset, 0.0), Vector3(size.x, size.y - inset * 2.0, size.z)))
	else:
		out.append(fine_box(id, place))
	return out


## Whether two parts where they've been put go through each other.
static func clash(id_a: String, place_a: Transform3D, id_b: String, place_b: Transform3D) -> bool:
	if not fine_box(id_a, place_a).intersects(fine_box(id_b, place_b)):
		return false
	for a in solid_boxes(id_a, place_a):
		for b in solid_boxes(id_b, place_b):
			if _overlap_volume(a, b) > 0.0:
				return true
	return false


## The box a part fills where it's been put, in the fine unit.
static func fine_box(id: String, place: Transform3D) -> AABB:
	return place * AABB(Vector3.ZERO, PartCatalog.fine_size(id))


static func load_file(path: String) -> KartDesign:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("I couldn't read the kart at %s" % path)
		return KartDesign.new()
	return from_dict(data)


func to_dict() -> Dictionary:
	var out := []
	for p in parts:
		var place := place_of(p)
		var pos := [snappedf(place.origin.x, 0.01), snappedf(place.origin.y, 0.01), snappedf(place.origin.z, 0.01)]
		var entry := { "id": p.id, "pos": pos, "turn": maxi(Grid.turn_index(place.basis), 0) }
		if p.has("color"):
			entry["color"] = "#" + p.color.to_html(false)
		out.append(entry)
	var data := { "name": name, "parts": out }
	if about != "":
		data["about"] = about
	return data


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

## The box a part fills, on the stud grid (studs across, plates up, studs
## along).
func box_of(index: int) -> AABB:
	return _grid_box(fine_box(parts[index].id, place_of(parts[index])))


static func part_box(id: String, at: Vector3i, rot: int) -> AABB:
	return _grid_box(fine_box(id, grid_place(id, at, rot)))


static func _grid_box(fine: AABB) -> AABB:
	return AABB(fine.position / Grid.UNIT_FINE, fine.size / Grid.UNIT_FINE)


static func is_wheel(id: String) -> bool:
	return PartCatalog.get_part(id).get("kind", "") == "wheel"


## Whether a part clips onto the side of another part instead of joining by
## studs. Wheels do, and so do fairings.
static func clips_on_side(id: String) -> bool:
	return PartCatalog.get_part(id).get("kind", "") in ["wheel", "fairing"]


## Whether a part on the grid here would fit inside the build area without
## going through anything.
func fits(id: String, at: Vector3i, rot: int, ignore := -1) -> bool:
	return fits_place(id, grid_place(id, at, rot), ignore)


func fits_place(id: String, place: Transform3D, ignore := -1) -> bool:
	var box := fine_box(id, place)
	var area := AABB(Vector3.ZERO, Vector3(BUILD_SIZE) * Grid.UNIT_FINE)
	if not area.grow(0.01).encloses(box):
		return false
	for i in parts.size():
		if i != ignore and clash(id, place, parts[i].id, place_of(parts[i])):
			return false
	return true


## Whether these two parts, where they've been put, hold onto each other.
## Each needs an "id" and a "place".
static func joined(a: Dictionary, b: Dictionary) -> bool:
	var spots := {}
	for c in Connectors.placed(a.id, place_of(a)):
		var key := Connectors.key_of(c.at)
		if not spots.has(key):
			spots[key] = []
		spots[key].append(c)
	for c in Connectors.placed(b.id, place_of(b)):
		for other in spots.get(Connectors.key_of(c.at), []):
			if Connectors.meet(c, other):
				return true
	return false


## Whether a part on the grid here would be held on by anything. The first
## part always is.
func attaches(id: String, at: Vector3i, rot: int, ignore := -1) -> bool:
	return attaches_place(id, grid_place(id, at, rot), ignore)


func attaches_place(id: String, place: Transform3D, ignore := -1) -> bool:
	var entry := { "id": id, "place": place }
	var others := 0
	for i in parts.size():
		if i == ignore:
			continue
		others += 1
		if joined(entry, parts[i]):
			return true
	return others == 0


## Which parts each part is joined to, as lists of indices.
func links() -> Array:
	var out := []
	var spots := {}
	for i in parts.size():
		out.append([])
		for c in Connectors.placed(parts[i].id, place_of(parts[i])):
			c["part"] = i
			var key := Connectors.key_of(c.at)
			if not spots.has(key):
				spots[key] = []
			spots[key].append(c)
	for key in spots:
		var here: Array = spots[key]
		for a in here.size():
			for b in range(a + 1, here.size()):
				var i: int = here[a].part
				var j: int = here[b].part
				if i != j and not out[i].has(j) and Connectors.meet(here[a], here[b]):
					out[i].append(j)
					out[j].append(i)
	return out


## Splits the kart into the groups of parts that hold together. A finished
## kart is one group. Crashes use this to work out what falls off along with
## a part that breaks away.
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


## Which parts would fall off once the parts in `lost` are gone, because
## nothing joins them to `anchor` (the seat) any more. The lost parts
## themselves aren't in the list.
func detached_after(lost: Dictionary, anchor: int) -> Array[int]:
	var link := links()
	var reached := { anchor: true }
	var todo := [anchor]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		for j in link[i]:
			if not reached.has(j) and not lost.has(j):
				reached[j] = true
				todo.append(j)
	var out: Array[int] = []
	for i in parts.size():
		if not reached.has(i) and not lost.has(i):
			out.append(i)
	return out


## How many studs the driver has to reach forward from the front of their
## seat to the steering, or -1 if the steering isn't in front of the seat
## where they could get at it (or there's no seat or steering).
func steering_gap() -> int:
	var seat := seat_index()
	if seat == -1:
		return -1
	var seat_box := seat_box_of(seat)
	var best := -1
	for i in parts.size():
		if PartCatalog.get_part(parts[i].id).get("kind", "") != "steering":
			continue
		var box := box_of(i)
		# It has to be in front of the seat and overlap it from side to side.
		var gap := roundi(seat_box.position.z - box.end.z)
		var across := minf(box.end.x, seat_box.end.x) - maxf(box.position.x, seat_box.position.x)
		if gap >= 0 and across > 0.0 and (best == -1 or gap < best):
			best = gap
	return best


## Where the driver sits on the seat part at this index, on the stud grid.
## That's the whole part, except on a motorbike frame, which says where its
## seat is.
func seat_box_of(index: int) -> AABB:
	var def := PartCatalog.get_part(parts[index].id)
	if not def.has("seat_box"):
		return box_of(index)
	return _grid_box(place_of(parts[index]) * (def.seat_box as AABB))


func seat_index() -> int:
	for i in parts.size():
		if PartCatalog.get_part(parts[i].id).get("kind", "") == "seat":
			return i
	return -1


## Everything stopping this kart from being driven, in words for the player.
## An empty list means it's good to go.
func problems() -> Array[String]:
	var out: Array[String] = []
	var seats := 0
	var engines := 0
	var wheels := 0
	var steering := 0
	var lowest_wheel := INF
	var lowest_other := INF
	for i in parts.size():
		var def := PartCatalog.get_part(parts[i].id)
		var bottom := box_of(i).position.y
		match def.get("kind", ""):
			"seat":
				seats += 1
				# A motorbike frame is the seat and the engine.
				if def.get("power", 0.0) > 0.0:
					engines += 1
			"engine":
				engines += 1
			"steering":
				steering += 1
			"wheel":
				wheels += 1
				lowest_wheel = minf(lowest_wheel, bottom)
				continue
		lowest_other = minf(lowest_other, bottom)
	if parts.is_empty():
		out.append("Pick a part on the left to start building.")
		return out
	if seats == 0:
		out.append("It needs a seat for the driver.")
	if engines == 0:
		out.append("It needs an engine.")
	if steering == 0:
		out.append("It needs a steering wheel or handlebars in front of the seat.")
	elif seats > 0:
		var gap := steering_gap()
		if gap == -1 or gap > KartStats.MOST_REACH:
			out.append("The steering has to be right in front of the seat.")
	if wheels < 2:
		out.append("It needs at least two wheels.")
	elif wheels == 2 and not _wheels_in_line():
		out.append("Two wheels have to be one behind the other.")
	if groups().size() > 1:
		out.append("Some parts aren't attached to the rest.")
	for i in parts.size():
		for j in range(i + 1, parts.size()):
			if clash(parts[i].id, place_of(parts[i]), parts[j].id, place_of(parts[j])):
				out.append("Two parts are inside each other.")
				return out
	if wheels > 0 and lowest_other < lowest_wheel + CLEARANCE - 0.01:
		out.append("Something hangs too low. Everything but the wheels needs two plates of room underneath.")
	return out


## Whether the wheels are one behind the other, like a bike's.
func _wheels_in_line() -> bool:
	var xs: Array[float] = []
	for i in parts.size():
		if is_wheel(parts[i].id):
			xs.append(box_of(i).get_center().x)
	return xs.max() - xs.min() < 1.0


## How much two boxes overlap, leaving out a sliver at their faces, so parts
## that only touch don't count.
static func _overlap_volume(a: AABB, b: AABB) -> float:
	var i := a.grow(-0.05).intersection(b.grow(-0.05))
	return i.size.x * i.size.y * i.size.z if i.has_volume() else 0.0
