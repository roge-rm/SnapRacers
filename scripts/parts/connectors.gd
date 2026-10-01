class_name Connectors
extends RefCounted

## Where parts join each other. Every part has connectors, each a spot on the
## part with a type and the way it faces out. Two parts join where one's
## connector sits on the other's, facing it, and the two types go together:
## a stud into a socket, or a clip onto the side of a part.
##
## Spots are in the fine unit (see Grid), in the part's own space, before
## it's turned and moved.

## Which type goes with which.
const PAIRS := {
	"stud": "socket", "socket": "stud",
	"clip": "side", "side": "clip",
}
## How close two spots have to be to count as the same, in the fine unit.
const NEAR := 0.5

static var _cache := {}


## The part's connectors, each { "type", "at", "axis" }. Plates, bricks and
## bodywork have studs across the top, sockets across the bottom and spots
## down each side a wheel or fairing can clip onto. Wheels and fairings clip
## on by either side.
static func of(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	var def := PartCatalog.get_part(id)
	var out := []
	if def.is_empty():
		return out
	var size: Vector3i = def.size
	var fine := Grid.fine_size(size)
	var clips: bool = def.get("kind", "") in ["wheel", "fairing"]
	for j in size.y:
		for k in size.z:
			var y := (j + 0.5) * Grid.PLATE_FINE
			var z := (k + 0.5) * Grid.STUD_FINE
			out.append({ "type": "clip" if clips else "side", "at": Vector3(0.0, y, z), "axis": Vector3.LEFT })
			out.append({ "type": "clip" if clips else "side", "at": Vector3(fine.x, y, z), "axis": Vector3.RIGHT })
	if not clips:
		for i in size.x:
			for k in size.z:
				var x := (i + 0.5) * Grid.STUD_FINE
				var z := (k + 0.5) * Grid.STUD_FINE
				out.append({ "type": "stud", "at": Vector3(x, fine.y, z), "axis": Vector3.UP })
				out.append({ "type": "socket", "at": Vector3(x, 0.0, z), "axis": Vector3.DOWN })
	_cache[id] = out
	return out


## The part's connectors where it's been put, `place` taking its own space to
## the kart's.
static func placed(id: String, place: Transform3D) -> Array:
	var out := []
	for c in of(id):
		out.append({ "type": c.type, "at": place * c.at, "axis": (place.basis * c.axis).normalized() })
	return out


## Whether these two placed connectors join.
static func meet(a: Dictionary, b: Dictionary) -> bool:
	return PAIRS.get(a.type, "") == b.type and a.at.distance_to(b.at) < NEAR and a.axis.dot(b.axis) < -0.99


## A key for looking spots up quickly, the same for spots that meet.
static func key_of(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x), roundi(at.y), roundi(at.z))
