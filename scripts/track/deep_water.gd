class_name DeepWater
extends RefCounted

## Where the water is too deep to drive: the sea beside a seaside course or
## all round an island, lakes and ponds, and painted water, lava and slime
## (see PaintedAreas). A kart that drives in sinks and is put back on the
## road (see Kart.sink()). Puddles and shallows on the road aren't in here.
## Scenery fills it in as it builds.
##
## Every check is a lookup from above, (x, z), so it's cheap enough to do
## for every kart every step.

## Grid cells for an island's land, in metres.
const CELL := 4.0
## How far above the water's surface a kart can be and still be in it, in
## metres, so one flying over on a jump isn't.
const ABOVE := 1.5

## The sea along one side, from above, and how high its surface is. Empty
## when there's none.
var sea := Rect2()
var sea_level := 0.0
## Around an island, which grid cells are land, 1 for land and 0 for sea,
## as rows of `_cols` from `_origin`. Everything off the grid is sea.
var island := false
var island_level := 0.0
var _land := PackedByteArray()
var _origin := Vector2.ZERO
var _cols := 0
var _rows := 0
## Each lake or pond tile as [rect from above, height of its surface], and
## a box round them all for a quick miss.
var _pools: Array = []
var _pool_box := Rect2()
## How high the ground is at (x, z). On a hillside a lake's tiles run into
## the slope, and only count where the water's above the ground.
var ground: Callable = func(_x: float, _z: float) -> float: return 0.0
## Ground painted in the track editor (see PaintedAreas), whose water, lava
## and slime count where their field reaches DEEP, and how high each pool's
## surface is, as square -> height.
var paint: PaintedAreas
var paint_tops := {}
## Lakes and rivers that go by the ground (see Waters), settled.
var waters: Waters
## What the last deep water level_at() found was: "water" for the sea, a lake
## or painted water, or the painted type ("lava", "slime"), "" for none. See
## PaintedAreas.effect_of() for whether it sinks or burns.
var kind := ""


func is_empty() -> bool:
	return sea.size == Vector2.ZERO and not island and _pools.is_empty() and (paint == null or not paint.has_deep()) and (waters == null or not waters.has_real())


## Sea all round the land inside `shore`, from above, with its surface at
## `level`.
func set_island(shore: PackedVector2Array, level: float) -> void:
	if shore.is_empty():
		return
	var box := Rect2(shore[0], Vector2.ZERO)
	for p in shore:
		box = box.expand(p)
	box = box.grow(CELL * 2.0)
	_origin = box.position
	_cols = int(box.size.x / CELL) + 1
	_rows = int(box.size.y / CELL) + 1
	_land = Scenery.inside_grid(shore, _origin + Vector2.ONE * CELL * 0.5, _cols, _rows, CELL)
	island = true
	island_level = level


## A flat tile of a lake or pond, `size` across (x, z) and centred on
## `centre`, its surface `top` metres up.
func add_pool(centre: Vector3, size: Vector2, top: float) -> void:
	var rect := Rect2(Vector2(centre.x, centre.z) - size * 0.5, size)
	_pools.append([rect, top])
	_pool_box = rect if _pools.size() == 1 else _pool_box.merge(rect)


## How high the surface of the deep water at `at` is, or NAN if it's not in
## deep water (or is well above it).
func level_at(at: Vector3) -> float:
	var flat := Vector2(at.x, at.z)
	kind = "water"
	if island:
		var x := floori((flat.x - _origin.x) / CELL)
		var y := floori((flat.y - _origin.y) / CELL)
		var land := x >= 0 and y >= 0 and x < _cols and y < _rows and _land[y * _cols + x] == 1
		if not land and at.y < island_level + ABOVE:
			return island_level
	if sea.size != Vector2.ZERO and sea.has_point(flat) and at.y < sea_level + ABOVE:
		return sea_level
	if not _pools.is_empty() and _pool_box.has_point(flat):
		for pool: Array in _pools:
			var top: float = pool[1]
			if (pool[0] as Rect2).has_point(flat) and at.y < top + ABOVE and ground.call(flat.x, flat.y) < top:
				return top
	if waters != null and waters.settled:
		var surface := waters.level_at(at.x, at.z)
		if not is_nan(surface) and at.y < surface + ABOVE:
			kind = waters.kind
			return surface
	if paint != null and not paint.is_empty():
		var type := paint.kind_at(at.x, at.z)
		if type != "" and PaintedAreas.effect_of(type) != "" and paint.level_at(at.x, at.z) >= PaintedAreas.DEEP:
			var top := paint_top(at.x, at.z)
			if at.y < top + ABOVE:
				kind = type
				return top
	kind = ""
	return NAN


## What kind of deep water is at `at`, as level_at() leaves in `kind`.
func kind_at(at: Vector3) -> String:
	level_at(at)
	return kind


## How high the surface of a painted pool is at (x, z).
func paint_top(x: float, z: float) -> float:
	return PaintedAreas.level_near(paint_tops, x, z, Scenery.PAINT_LIFT)
