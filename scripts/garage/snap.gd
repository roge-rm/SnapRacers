class_name Snap
extends RefCounted

## Where a part can go onto a kart by its connectors, for the garage. It's
## kept apart from anything on screen so it can be tested on its own.
##
## A spot is one of the kart's connectors with nothing joined to it yet:
## { "type", "at", "axis", "part", "index", "along", "step" }, in the fine
## unit in the kart's space (see Connectors.placed). Bars, axles and the other
## lines have a spot every SPOT_EVERY steps along them.
##
## A way on is one way a part can go onto a spot: { "place", "own", "cost" },
## with "own" the part's own connector spot that meets it, in the part's own
## space. Ways on that have been checked also say whether the part "fits"
## there without going through anything.

## Every this many steps along a line is a spot, a quarter of a stud apart.
## Slide moves a part this far along a line too.
const SPOT_EVERY := 5
const SLIDE := 5.0
## What turning a part from how it's turned now costs, against how far its
## middle is from where it's wanted, in the fine unit. Turning it is a lot
## worse.
const TURN_COST := 1000.0


## Every spot on the kart that something could join.
static func open_spots(design: KartDesign) -> Array:
	var all := []
	var by_key := {}
	for i in design.parts.size():
		for c in Connectors.placed(design.parts[i].id, KartDesign.place_of(design.parts[i])):
			c["part"] = i
			var key := Connectors.key_of(c.at)
			if not by_key.has(key):
				by_key[key] = []
			by_key[key].append(c)
			all.append(c)
	var out := []
	for c in all:
		if c.step % SPOT_EVERY != 0:
			continue
		var taken := false
		for other in by_key[Connectors.key_of(c.at)]:
			if other.part != c.part and Connectors.meet(c, other):
				taken = true
				break
		if not taken:
			out.append(c)
	return out


## The spots on the kart this part could go onto by one of its connectors.
static func spots_for(design: KartDesign, id: String) -> Array:
	var types := {}
	for c in Connectors.of(id):
		for t in Connectors.PAIRS.get(c.type, {}):
			types[t] = true
	return open_spots(design).filter(func(s: Dictionary) -> bool: return types.has(s.type))


## How the part's connector and the spot have to line up to join: "facing",
## "along", "any", or "" if they don't go together.
static func how(own: Dictionary, spot: Dictionary) -> String:
	return Connectors.PAIRS.get(own.type, {}).get(spot.type, "")


## Every way the part can go onto the spot, best first: turned as near as it
## can be to `keep`, then with its middle as near as it can be to `near`, seen
## along the spot's axis. So a part goes on the way it's already turned,
## centred over the spot you picked.
static func ways(id: String, spot: Dictionary, keep: Basis, near: Vector3) -> Array:
	var out := []
	var middle := PartCatalog.fine_size(id) * 0.5
	var turns := Grid.turns()
	if KartDesign.is_wheel(id):
		# Wheels keep their axles across the kart.
		turns = turns.filter(func(turn: Basis) -> bool: return absf(turn.x.x) >= 0.99)
	for own in Connectors.placed(id, Transform3D.IDENTITY):
		if own.step % SPOT_EVERY != 0:
			continue
		var join := how(own, spot)
		if join == "":
			continue
		for turn in turns:
			var axis: Vector3 = turn * own.axis
			if join == "facing" and axis.dot(spot.axis) > -0.99:
				continue
			if join == "along" and absf(axis.dot(spot.axis)) < 0.99:
				continue
			var place := Transform3D(turn, spot.at - turn * own.at)
			var off: Vector3 = place * middle - near
			off -= spot.axis * off.dot(spot.axis)
			out.append({ "place": place, "own": own, "cost": off.length() + TURN_COST * apart(turn, keep) })
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cost < b.cost)
	return out


## How far apart two turns are, 0 for the same up to 4 for opposite.
static func apart(a: Basis, b: Basis) -> float:
	return 3.0 - (a.x.dot(b.x) + a.y.dot(b.y) + a.z.dot(b.z))


## The first of these ways on where the part fits, or the first of them
## anyway if it doesn't fit anywhere. Empty if there are none.
static func best(design: KartDesign, id: String, choices: Array) -> Dictionary:
	# Only the parts near one of the ways on can be in the way.
	var area := AABB()
	for i in choices.size():
		var box := KartDesign.fine_box(id, choices[i].place)
		area = box if i == 0 else area.merge(box)
	var near := design.only_near(area.grow(0.1))
	for way in choices:
		if near.fits_place(id, way.place):
			way["fits"] = true
			return way
	if choices.is_empty():
		return {}
	var first: Dictionary = choices[0]
	first["fits"] = false
	return first


## The way on by the next of the part's own connectors after the one it's on
## now, kept turned the same if it can be. Empty if there's no other.
static func next_way(design: KartDesign, id: String, spot: Dictionary, way: Dictionary) -> Dictionary:
	var count := Connectors.of(id).size()
	var now: int = way.own.index
	var choices := ways(id, spot, way.place.basis, spot.at).filter(func(w: Dictionary) -> bool: return w.own.index != now)
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var after_a := posmod(a.own.index - now - 1, count)
		var after_b := posmod(b.own.index - now - 1, count)
		return after_a < after_b if after_a != after_b else a.cost < b.cost)
	return best(design, id, choices)


## The part turned a quarter turn about the joint, staying on the same spot.
## Empty if it can't be.
static func turned(design: KartDesign, id: String, spot: Dictionary, way: Dictionary) -> Dictionary:
	var basis := exact(Basis(spot.axis, -PI * 0.5) * way.place.basis)
	return _turned_to(design, id, spot, way, basis)


## The part turned over, staying on the same spot. Empty if it only goes on
## one way up there.
static func flipped(design: KartDesign, id: String, spot: Dictionary, way: Dictionary) -> Dictionary:
	var over := Vector3.RIGHT if absf(spot.axis.x) < 0.5 else Vector3.UP
	var basis := exact(Basis(over, PI) * way.place.basis)
	return _turned_to(design, id, spot, way, basis)


static func _turned_to(design: KartDesign, id: String, spot: Dictionary, way: Dictionary, basis: Basis) -> Dictionary:
	var middle: Vector3 = way.place * (PartCatalog.fine_size(id) * 0.5)
	var choices := ways(id, spot, basis, middle).filter(func(w: Dictionary) -> bool: return apart(w.place.basis, basis) < 0.01)
	return best(design, id, choices)


## Whether the part slides along this joint, like a clip on a bar or a wheel
## on an axle.
static func slides(spot: Dictionary, way: Dictionary) -> bool:
	return how(way.own, spot) == "along"


## The part slid along the joint a quarter of a stud, or back to the start
## once it gets to the end. It comes with the spot it's on now.
static func slid(design: KartDesign, id: String, spot: Dictionary, way: Dictionary) -> Dictionary:
	var other: Dictionary = design.parts[spot.part]
	var step: Vector3 = spot.axis * SLIDE
	var place: Transform3D = way.place
	var moved := 1.0
	if KartDesign.joined({ "id": id, "place": Transform3D(place.basis, place.origin + step) }, other):
		place.origin += step
	else:
		# Past the end, so back to the other end.
		moved = 0.0
		for i in 400:
			var back := Transform3D(place.basis, place.origin - step)
			if not KartDesign.joined({ "id": id, "place": back }, other):
				break
			place = back
			moved -= 1.0
	var on := spot.duplicate()
	on.at = spot.at + step * moved
	return { "place": place, "own": way.own, "cost": 0.0, "fits": design.fits_place(id, place), "spot": on }


## The nearest of the 24 turns to this one.
static func exact(basis: Basis) -> Basis:
	var all := Grid.turns()
	var best_turn: Basis = all[0]
	var best_apart := INF
	for turn in all:
		var a := apart(turn, basis)
		if a < best_apart:
			best_apart = a
			best_turn = turn
	return best_turn


## Where a part would go as the mirror image of one at `place`, across the
## middle of the kart from side to side. Parts can't really be mirrored, so
## its twin is turned to look like it: the same, end for end. A wheel's twin
## is turned round, so its outside faces out on both sides.
static func mirror_place(id: String, place: Transform3D) -> Transform3D:
	var width := KartDesign.BUILD_SIZE.x * Grid.STUD_FINE
	var size := PartCatalog.fine_size(id)
	var across := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3(width, 0.0, 0.0))
	var own := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3(size.x, 0.0, 0.0))
	if KartDesign.is_wheel(id):
		own = Transform3D(Basis.from_scale(Vector3(1.0, 1.0, -1.0)), Vector3(0.0, 0.0, size.z))
	var twin := across * place * own
	return Transform3D(exact(twin.basis), twin.origin)
