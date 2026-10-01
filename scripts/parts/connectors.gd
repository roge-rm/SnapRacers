class_name Connectors
extends RefCounted

## Where parts join each other. Every part has connectors, each a spot on the
## part with a type and the way it faces out. Two parts join where one's
## connector sits on the other's and the two types go together:
##
## - A stud goes into a socket, facing each other.
## - A clip or a wheel hub goes onto the side spot of one of the first parts.
## - A clip goes on a bar, a pin into a hole, an axle into an axle hole or a
##   wheel hub, and one half of a hinge onto the other, lined up along the
##   same line. Bars, pins, axles, holes, hubs and hinges are lines with a
##   length, and they join anywhere they overlap.
## - A ball goes in a cup, any way round.
##
## Spots are in the fine unit (see Grid), in the part's own space, before
## it's turned and moved. The parts modelled by tools/parts say where their
## connectors are, and the first parts have theirs worked out from their box.

## Which types go with which, and how they have to line up: "facing" for
## pointing at each other, "along" for lying on the same line either way, and
## "any" for any way round.
const PAIRS := {
	"stud": { "socket": "facing" },
	"socket": { "stud": "facing" },
	"clip": { "side": "facing", "bar": "along" },
	"side": { "clip": "facing", "hub": "facing" },
	"bar": { "clip": "along" },
	"pin": { "hole": "along", "hub": "along" },
	"hole": { "pin": "along", "axle": "along" },
	"axle": { "hole": "along", "axle_hole": "along", "hub": "along" },
	"axle_hole": { "axle": "along" },
	"hub": { "pin": "along", "axle": "along", "side": "facing" },
	"hinge_a": { "hinge_b": "along" },
	"hinge_b": { "hinge_a": "along" },
	"ball": { "cup": "any" },
	"cup": { "ball": "any" },
}
## How close two spots have to be to count as the same, in the fine unit.
const NEAR := 0.5
## How far apart the spots along a line are, in the fine unit.
const LINE_STEP := 1.0

static var _cache := {}


## The part's connectors, each { "type", "at", "axis", "length" }.
static func of(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	var def := PartCatalog.get_part(id)
	var out := []
	if def.is_empty():
		return out
	if def.has("connectors"):
		out = def.connectors
	else:
		out = _worked_out(def)
	_cache[id] = out
	return out


## Plates, bricks and bodywork from the first parts have studs across the
## top, sockets across the bottom and spots down each side a wheel or
## fairing can clip onto. Their wheels and fairings clip on by either side,
## and their wheels have a hub through the middle as well.
static func _worked_out(def: Dictionary) -> Array:
	var out := []
	var size: Vector3i = def.size
	var fine := Grid.fine_size(size)
	var clips: bool = def.get("kind", "") in ["wheel", "fairing"]
	for j in size.y:
		for k in size.z:
			var y := (j + 0.5) * Grid.PLATE_FINE
			var z := (k + 0.5) * Grid.STUD_FINE
			out.append({ "type": "clip" if clips else "side", "at": Vector3(0.0, y, z), "axis": Vector3.LEFT, "length": 0.0 })
			out.append({ "type": "clip" if clips else "side", "at": Vector3(fine.x, y, z), "axis": Vector3.RIGHT, "length": 0.0 })
	if def.get("kind", "") == "wheel":
		# And a hub through the middle, so it goes on a pin or an axle too.
		out.append({ "type": "hub", "at": Vector3(0.0, fine.y * 0.5, fine.z * 0.5), "axis": Vector3.RIGHT, "length": fine.x })
	if not clips:
		for i in size.x:
			for k in size.z:
				var x := (i + 0.5) * Grid.STUD_FINE
				var z := (k + 0.5) * Grid.STUD_FINE
				out.append({ "type": "stud", "at": Vector3(x, fine.y, z), "axis": Vector3.UP, "length": 0.0 })
				out.append({ "type": "socket", "at": Vector3(x, 0.0, z), "axis": Vector3.DOWN, "length": 0.0 })
	return out


## The part's connectors where it's been put, `place` taking its own space to
## the kart's. A line comes out as a spot every LINE_STEP along it. Each spot
## says which of the part's connectors it's on ("index"), how far along it is
## ("along") and which step along ("step").
static func placed(id: String, place: Transform3D) -> Array:
	var out := []
	var list := of(id)
	for i in list.size():
		var c: Dictionary = list[i]
		var axis: Vector3 = (place.basis * c.axis).normalized()
		var start: Vector3 = place * c.at
		var length: float = c.get("length", 0.0)
		if length <= 0.0:
			out.append({ "type": c.type, "at": start, "axis": axis, "index": i, "along": 0.0, "step": 0 })
			continue
		var steps := maxi(1, roundi(length / LINE_STEP))
		for k in steps + 1:
			var along := length * k / steps
			out.append({ "type": c.type, "at": start + axis * along, "axis": axis, "index": i, "along": along, "step": k })
	return out


## Whether these two placed connectors join.
static func meet(a: Dictionary, b: Dictionary) -> bool:
	var how: String = PAIRS.get(a.type, {}).get(b.type, "")
	if how == "" or a.at.distance_to(b.at) >= NEAR:
		return false
	match how:
		"facing":
			return a.axis.dot(b.axis) < -0.99
		"along":
			return absf(a.axis.dot(b.axis)) > 0.99
	return true


## A key for looking spots up quickly, the same for spots that meet.
static func key_of(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x), roundi(at.y), roundi(at.z))
