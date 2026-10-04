class_name Puddles
extends Node3D

## Puddles on the road in the rain. Driving through one there's even less
## grip than on the wet road, and the water drags. They're the same for the
## same seed, so everyone online has the same ones.
##
## They're not bodies a wheel can touch: a kart asks how far into a puddle a
## point is (see factor_at()), so the road under them stays the road, sticky
## and all.

## How many, and how big across, in metres.
const COUNT := [10, 25]
const SIZE := [2.4, 6.0]
## They keep this far in from the road's edges.
const EDGE := 1.5
## Never where the road climbs, rolls or leaves the ground.
const NOT_ON := ["ramp", "jump", "loop", "corkscrew", "wallride", "bank"]
## For looking them up quickly, a grid of squares this big.
const CELL := 4.0
const WATER := Color("#1c242c")

## Each puddle as [middle, radius].
var spots: Array = []
var _cells := {}


func _init(track: TrackPath = null, chance_seed := 0, amount := 0.0) -> void:
	if track == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([chance_seed, track.name])
	var count := roundi(lerpf(COUNT[0], COUNT[1], amount))
	var tries := 0
	while spots.size() < count and tries < count * 20:
		tries += 1
		var offset := rng.randf() * track.length
		var type := track.piece_type_at(offset)
		if NOT_ON.has(type) or track.up_at(offset).y < 0.97 or track.pieces[track.piece_of[track._index_before(offset)]].sticky:
			continue
		var radius := rng.randf_range(SIZE[0], SIZE[1]) * 0.5
		var across := rng.randf_range(-1.0, 1.0) * maxf(track.width * 0.5 - EDGE - radius, 0.0)
		var middle := track.point_at(offset) + track.right_at(offset) * across
		if spots.any(func(s: Array) -> bool: return s[0].distance_to(middle) < s[1] + radius + 2.0):
			continue
		add(middle, radius)
	_draw(track)


## Puts a puddle here, this big. Tests make their own this way.
func add(middle: Vector3, radius: float) -> void:
	spots.append([middle, radius])
	var low := _cell(middle - Vector3(radius, 0.0, radius))
	var high := _cell(middle + Vector3(radius, 0.0, radius))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var key := Vector2i(x, z)
			if not _cells.has(key):
				_cells[key] = []
			_cells[key].append(spots.size() - 1)


## How far into a puddle this point is: 0 outside, 1 in the middle, and in
## between near its edge.
func factor_at(point: Vector3) -> float:
	var most := 0.0
	for i in _cells.get(_cell(point), []):
		var middle: Vector3 = spots[i][0]
		var radius: float = spots[i][1]
		var d := Vector2(point.x - middle.x, point.z - middle.z).length()
		if absf(point.y - middle.y) < 2.0:
			most = maxf(most, 1.0 - smoothstep(radius * 0.7, radius, d))
	return most


static func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


## Flat water lying on the road, drawn all at once.
func _draw(track: TrackPath) -> void:
	if spots.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = SceneryKit.mesh_for("cylinder")
	multi.instance_count = spots.size()
	for i in spots.size():
		var middle: Vector3 = spots[i][0]
		var radius: float = spots[i][1]
		var up := track.up_at(track.offset_of(middle))
		var flat := Basis.looking_at(up.cross(Vector3.RIGHT).normalized() if absf(up.x) < 0.9 else Vector3.FORWARD, up)
		flat = flat * Basis.from_scale(Vector3(radius * 2.0, 0.02, radius * 2.0))
		multi.set_instance_transform(i, Transform3D(flat, middle + up * 0.02))
		multi.set_instance_color(i, WATER)
		multi.set_instance_custom_data(i, Color(float(SceneryKit.WATER), 0.0, 0.0, 0.0))
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.material_override = SceneryKit.material()
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
