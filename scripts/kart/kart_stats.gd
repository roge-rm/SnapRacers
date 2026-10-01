class_name KartStats
extends RefCounted

## Everything about how a kart drives that can be worked out from its design.
## The kart uses it to set up its physics and the garage shows it.
##
## Drag comes from the kart's shape. Seen from the front, each square a stud
## across and a plate high with something in it catches wind, depending on what
## the wind hits first and leaves last there. A flat face catches all of it and
## a slope or nose cone lets it slide past. The driver catches wind unless
## something is in front of them, and an open wheel churns up extra air.
##
## Ergonomics is how easily the driver steers, from how they sit, what they
## steer with and how far they reach.

const AIR_DENSITY := 1.2
const BODY_DRAG := 0.5
const TIRE_DRAG := 0.9
const TIRE_FRICTION := 1.25 # grip of a plain tire, as a multiple of its load
const DRIVER_MASS := 45.0
## How much of a square's drag is down to what the wind hits first. The rest
## is down to what it leaves last.
const FRONT_SHARE := 0.6
## How smooth the air finds the driver, and a wheel's round tire.
const DRIVER_AERO := 0.9
const WHEEL_AERO := 0.8
## Each stud further from the seat the steering is costs the driver this much
## control.
const REACH_COST := 0.12
## Past this many studs from the seat, the driver can't reach it at all.
const MOST_REACH := 2


class PartInfo:
	var index := 0 # position in the design's part list
	var def: Dictionary
	var at := Vector3i.ZERO # the corner of the box it fills on the grid
	var rot := 0 # quarter turns, or -1 if it's tipped over
	var size := Vector3i.ONE # grid size after turning
	var basis := Basis.IDENTITY # which way it's turned
	var centre := Vector3.ZERO # metres, in kart space
	var extent := Vector3.ONE # metres, after turning
	var low := Vector3.ZERO # the exact corner of its box, in grid units
	var high := Vector3.ONE # and the far corner


var parts: Array[PartInfo] = []
var wheels: Array[PartInfo] = []
var mass := 0.0
var center_of_mass := Vector3.ZERO
## Every engine's power, and every jet's thrust, times this. The parts keep
## their own numbers against each other, and these set how quick karts are
## overall. Top speed goes with the cube root of power, and with the square
## root of thrust.
const POWER_SCALE := 2.4
const THRUST_SCALE := 1.4

var power := 0.0
var max_force := 0.0
## Push that doesn't go through the wheels, from jet engines, in newtons.
var thrust := 0.0
var drag_area := 0.0
var lift_area := 0.0
var rolling := 0.0 # average rolling resistance of the tires
## How well the tires grip. It's the front wheels' or the back wheels',
## whichever grip less, since that end slides first.
var grip := 0.0
## How much grip the tires keep on grass and dirt, on average (see parts.json).
var offroad := 0.0
## How quickly the driver can steer, as a fraction of the best there is.
var control := 1.0
var has_seat := false
var seat: PartInfo
var seat_top := Vector3.ZERO
## How far back the driver leans, in radians.
var recline := 0.0
## Whether the driver sits astride a saddle, like on a motorbike.
var astride := false
## What the drag comes from, in m² of drag area: "driver", "wheels", "flat"
## (flat fronts and backs) and "smooth" (everything else).
var drag_parts := {}
## What the driver steers with, if it's still on.
var steering: PartInfo
## Where the kart's origin sits on the design grid. It's under the middle of
## its footprint, at the bottom.
var origin_cell := Vector3.ZERO


## How smooth a part is to the air at its front and back, as it's turned.
## Turned halfway around, its back is at the front. Turned any other way, the
## wind hits its side.
static func aero_of(def: Dictionary, rot: int) -> Vector2:
	return aero_turned(def, Grid.yaw(rot))


static func aero_turned(def: Dictionary, basis: Basis) -> Vector2:
	var aero: Dictionary = def.get("aero", {})
	var front: float = aero.get("front", 1.0)
	var back: float = aero.get("back", 1.0)
	var side: float = aero.get("side", 1.0)
	var facing := basis * Vector3.FORWARD
	if facing.dot(Vector3.FORWARD) > 0.9:
		return Vector2(front, back)
	if facing.dot(Vector3.BACK) > 0.9:
		return Vector2(back, front)
	return Vector2(side, side)


## Works out the stats for a design. Parts whose index is in `skip` are left
## out, which is how a damaged kart is worked out. Pass the origin of the
## undamaged kart as `fixed_origin` so the parts that are left don't shift.
static func compute(design: KartDesign, skip := {}, fixed_origin: Variant = null, driver_mass := DRIVER_MASS) -> KartStats:
	var stats := KartStats.new()
	var lo := Vector3.ONE * INF
	var hi := -lo
	for i in design.parts.size():
		if skip.has(i):
			continue
		var p: Dictionary = design.parts[i]
		var def := PartCatalog.get_part(p.id)
		if def.is_empty():
			continue
		if p.has("color"):
			def = def.duplicate()
			def["color"] = p.color
		var info := PartInfo.new()
		info.index = i
		info.def = def
		var box := KartDesign.fine_box(p.id, KartDesign.place_of(p))
		info.low = box.position / Grid.UNIT_FINE
		info.high = box.end / Grid.UNIT_FINE
		info.at = Vector3i(roundi(info.low.x), roundi(info.low.y), roundi(info.low.z))
		info.size = Vector3i(roundi(info.high.x), roundi(info.high.y), roundi(info.high.z)) - info.at
		info.rot = p.get("rot", 0)
		info.basis = KartDesign.place_of(p).basis
		stats.parts.append(info)
		lo = lo.min(info.low)
		hi = hi.max(info.high)
	if stats.parts.is_empty():
		return stats
	stats.origin_cell = Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	if fixed_origin != null:
		stats.origin_cell = fixed_origin

	var weighted := Vector3.ZERO
	var offroad_total := 0.0
	var seat_control := 1.0
	for info in stats.parts:
		info.extent = Grid.to_metres(info.high - info.low)
		info.centre = Grid.to_metres((info.low + info.high) * 0.5 - stats.origin_cell)
		var part_mass: float = info.def.get("mass", 1.0)
		stats.mass += part_mass
		weighted += info.centre * part_mass
		match info.def.kind:
			"wheel":
				stats.wheels.append(info)
				stats.rolling += info.def.get("rolling", 0.015)
				stats.grip += info.def.get("grip", 1.0)
				offroad_total += info.def.get("offroad", 0.0)
			"engine":
				stats.power += info.def.get("power", 0.0) * POWER_SCALE
				stats.max_force += info.def.get("max_force", 0.0)
				stats.thrust += info.def.get("thrust", 0.0) * THRUST_SCALE
			"wing":
				stats.lift_area += info.def.get("lift_area", 0.0)
			"seat":
				if not stats.has_seat:
					stats.has_seat = true
					stats.seat = info
					stats.recline = deg_to_rad(info.def.get("recline", 0.0))
					stats.astride = info.def.get("astride", false)
					seat_control = info.def.get("control", 1.0)
					# The driver sits in the middle of the seat with their legs
					# out in front. Any further back on a long seat and their
					# weight takes too much off the front wheels.
					stats.seat_top = info.centre + Vector3(0.0, info.extent.y * 0.5, 0.0)
					stats.mass += driver_mass
					weighted += (stats.seat_top + Vector3.UP * 0.3 * cos(stats.recline)) * driver_mass
			"steering":
				if stats.steering == null:
					stats.steering = info

	stats.center_of_mass = weighted / maxf(stats.mass, 0.001)
	stats._work_out_drag()
	if not stats.wheels.is_empty():
		stats.rolling /= stats.wheels.size()
		stats.offroad = offroad_total / stats.wheels.size()
		stats.grip = stats._axle_grip()
	if stats.steering != null:
		var reach := maxi(design.steering_gap(), 0)
		stats.control = seat_control * float(stats.steering.def.get("control", 1.0)) * maxf(1.0 - REACH_COST * reach, 0.2)
	return stats


## Adds up the drag of every square of the kart seen from the front (see the
## top of this file).
func _work_out_drag() -> void:
	# For each square: [front z, front aero, what's at the front, back z,
	# back aero].
	var squares := {}
	var add := func(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, aero: Vector2, what: String) -> void:
		for x in range(x0, x1):
			for y in range(y0, y1):
				var key := Vector2i(x, y)
				if not squares.has(key):
					squares[key] = [z0, aero.x, what, z1, aero.y]
					continue
				var square: Array = squares[key]
				if z0 < square[0]:
					square[0] = z0
					square[1] = aero.x
					square[2] = what
				if z1 > square[3]:
					square[3] = z1
					square[4] = aero.y
	for info in parts:
		# A steering wheel or handlebars are mostly holes, so the wind goes
		# straight through.
		if info.def.kind == "steering":
			continue
		if info.def.kind == "wheel":
			add.call(info.at.x, info.at.x + info.size.x, info.at.y, info.at.y + info.size.y, info.at.z, info.at.z + info.size.z, Vector2(WHEEL_AERO, WHEEL_AERO), "wheel %d" % info.index)
			continue
		var aero := aero_turned(info.def, info.basis)
		add.call(info.at.x, info.at.x + info.size.x, info.at.y, info.at.y + info.size.y, info.at.z, info.at.z + info.size.z, aero, "flat" if aero.x >= 0.9 else "smooth")
	if seat != null:
		# The driver, as tall as they sit up, across the width of the seat.
		var top := seat.at.y + seat.size.y
		var height: int = seat.def.get("driver_height", 7)
		add.call(seat.at.x, seat.at.x + seat.size.x, top, top + height, seat.at.z, seat.at.z + seat.size.z, Vector2(DRIVER_AERO, 1.0), "driver")

	var cell := Grid.STUD * Grid.PLATE
	drag_parts = { "driver": 0.0, "wheels": 0.0, "flat": 0.0, "smooth": 0.0 }
	var open_squares := {}
	for key in squares:
		var square: Array = squares[key]
		var what: String = square[2]
		var amount: float = cell * BODY_DRAG * (FRONT_SHARE * square[1] + (1.0 - FRONT_SHARE) * square[4])
		if what.begins_with("wheel"):
			open_squares[what] = open_squares.get(what, 0) + 1
			what = "wheels"
		drag_parts[what] += amount
	# A wheel churns up the air as it spins, for as much of it as is out in
	# the open.
	for info in wheels:
		var radius: float = info.def.get("radius", 0.3)
		var width: float = info.def.get("width", 0.25)
		var open := float(open_squares.get("wheel %d" % info.index, 0)) / maxf(info.size.x * info.size.y, 1.0)
		drag_parts["wheels"] += width * radius * 2.0 * TIRE_DRAG * open
	drag_area = 0.0
	for what in drag_parts:
		drag_area += drag_parts[what]


## The average grip of the wheels in front of the centre of mass, or behind
## it, whichever is less. A kart with only one end (or wheels all in a line)
## goes by the average of all of them.
func _axle_grip() -> float:
	var front := []
	var back := []
	for info in wheels:
		var g: float = info.def.get("grip", 1.0)
		if info.centre.z < center_of_mass.z:
			front.append(g)
		else:
			back.append(g)
	var mean := func(values: Array) -> float:
		return values.reduce(func(a, b): return a + b, 0.0) / maxf(values.size(), 1)
	if front.is_empty() or back.is_empty():
		return mean.call(front + back)
	return minf(mean.call(front), mean.call(back))


## What most of the drag comes from ("driver", "wheels", "flat" or "smooth").
func most_drag() -> String:
	var most := "smooth"
	for what in drag_parts:
		if drag_parts[what] > drag_parts.get(most, 0.0):
			most = what
	return most


static func gravity() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


## The speed where the engine's push is used up by air and tire drag, in m/s.
## It's an estimate that ignores hills, wings and cornering.
func top_speed() -> float:
	var resist_roll := rolling * mass * gravity()
	var net := func(v: float) -> float:
		return minf(max_force, power / v) + thrust - 0.5 * AIR_DENSITY * drag_area * v * v - resist_roll
	if (power <= 0.0 and thrust <= 0.0) or net.call(0.1) <= 0.0:
		return 0.0
	var lo := 0.1
	var hi := 150.0
	for i in 40:
		var mid := (lo + hi) * 0.5
		if net.call(mid) > 0.0:
			lo = mid
		else:
			hi = mid
	return lo


## How hard it pulls away from a standstill, in g.
func pull() -> float:
	if mass <= 0.0:
		return 0.0
	return maxf(max_force + thrust - rolling * mass * gravity(), 0.0) / mass / gravity()


## Roughly how hard it can corner before it slides, in g.
func cornering() -> float:
	return grip * TIRE_FRICTION
