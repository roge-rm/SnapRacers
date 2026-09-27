class_name KartStats
extends RefCounted

## Everything about how a kart will drive that can be worked out from its
## design alone. The kart uses it to set up its physics, and the garage uses
## it to show what a change will do before you take it out.

const AIR_DENSITY := 1.2
const BODY_DRAG := 0.5
const TIRE_DRAG := 0.9
const TIRE_FRICTION := 1.25 # grip of a plain tire, as a multiple of its load
const DRIVER_MASS := 45.0


class PartInfo:
	var index := 0 # position in the design's part list
	var def: Dictionary
	var at := Vector3i.ZERO # grid position, as designed
	var size := Vector3i.ONE # grid size after turning
	var centre := Vector3.ZERO # metres, in kart space
	var extent := Vector3.ONE # metres


var parts: Array[PartInfo] = []
var wheels: Array[PartInfo] = []
var mass := 0.0
var center_of_mass := Vector3.ZERO
var power := 0.0
var max_force := 0.0
var drag_area := 0.0
var lift_area := 0.0
var rolling := 0.0 # average rolling resistance of the tires
var grip := 0.0 # average grip of the tires
var has_seat := false
var seat_top := Vector3.ZERO
## Where the kart's origin sits on the design grid: under the middle of its
## footprint, at the bottom.
var origin_cell := Vector3.ZERO


## Works out the stats for a design. Parts whose index is in `skip` are left
## out, which is how a damaged kart is worked out. Pass the origin of the
## undamaged kart as `fixed_origin` so the parts that are left don't shift.
static func compute(design: KartDesign, skip := {}, fixed_origin: Variant = null) -> KartStats:
	var stats := KartStats.new()
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for i in design.parts.size():
		if skip.has(i):
			continue
		var p: Dictionary = design.parts[i]
		var def := PartCatalog.get_part(p.id)
		if def.is_empty():
			continue
		var info := PartInfo.new()
		info.index = i
		info.def = def
		info.at = p.at
		info.size = Grid.rotated_size(def.size, p.rot)
		stats.parts.append(info)
		lo = lo.min(info.at)
		hi = hi.max(info.at + info.size)
	if stats.parts.is_empty():
		return stats
	stats.origin_cell = Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	if fixed_origin != null:
		stats.origin_cell = fixed_origin

	var weighted := Vector3.ZERO
	var frontal_cells := {}
	var wheel_drag := 0.0
	for info in stats.parts:
		info.extent = Grid.to_metres(Vector3(info.size))
		info.centre = Grid.to_metres(Vector3(info.at) + Vector3(info.size) * 0.5 - stats.origin_cell)
		var part_mass: float = info.def.get("mass", 1.0)
		stats.mass += part_mass
		weighted += info.centre * part_mass
		match info.def.kind:
			"wheel":
				stats.wheels.append(info)
				var radius: float = info.def.get("radius", 0.3)
				var width: float = info.def.get("width", 0.25)
				wheel_drag += width * radius * 2.0 * TIRE_DRAG
				stats.rolling += info.def.get("rolling", 0.015)
				stats.grip += info.def.get("grip", 1.0)
				continue
			"engine":
				stats.power += info.def.get("power", 0.0)
				stats.max_force += info.def.get("max_force", 0.0)
			"wing":
				stats.lift_area += info.def.get("lift_area", 0.0)
			"seat":
				if not stats.has_seat:
					stats.has_seat = true
					stats.seat_top = info.centre + Vector3.UP * info.extent.y * 0.5
					stats.mass += DRIVER_MASS
					weighted += (stats.seat_top + Vector3.UP * 0.3) * DRIVER_MASS
		for x in info.size.x:
			for y in info.size.y:
				frontal_cells[Vector2i(info.at.x + x, info.at.y + y)] = true

	stats.center_of_mass = weighted / maxf(stats.mass, 0.001)
	stats.drag_area = frontal_cells.size() * Grid.STUD * Grid.PLATE * BODY_DRAG + wheel_drag
	if not stats.wheels.is_empty():
		stats.rolling /= stats.wheels.size()
		stats.grip /= stats.wheels.size()
	return stats


static func gravity() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


## The speed where the engine's push is used up by air and tire drag, in m/s.
## It's an estimate: it ignores hills, wings and cornering.
func top_speed() -> float:
	var resist_roll := rolling * mass * gravity()
	var net := func(v: float) -> float:
		return minf(max_force, power / v) - 0.5 * AIR_DENSITY * drag_area * v * v - resist_roll
	if power <= 0.0 or net.call(0.1) <= 0.0:
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
	return maxf(max_force - rolling * mass * gravity(), 0.0) / mass / gravity()


## Roughly how hard it can corner before it slides, in g.
func cornering() -> float:
	return grip * TIRE_FRICTION
