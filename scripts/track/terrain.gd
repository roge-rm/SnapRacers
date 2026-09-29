class_name Terrain
extends StaticBody3D

## The ground a hilly course sits on: grass that rolls with the hills (see
## TrackPath.ground_height()) and meets the road level, so the road never
## floats above it or sinks into it.
##
## Right beside the road the ground is as high as the road, level across,
## like a real track's verges. Out over the runoff it eases back to the
## hills. Under road up in the air (a bridge, a loop, a jump's gap) it's just
## the hills.
##
## It's a grid of heights CELL metres apart, drawn as one mesh on the studded
## baseplate, and karts drive on it like the flat grass. A flat course uses
## the plain flat grass instead, which is quicker to make.

const CELL := 4.0
## How far out from the road's edge the ground takes to go from the road's
## height to the hills'.
const BLEND := 30.0
## How far below the road the ground sits under it, out of sight.
const SINK := 0.03

var track: TrackPath
## The corner of the grid, and how many points across and down it has.
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var heights := PackedFloat32Array()


func _init(path: TrackPath, reach: float) -> void:
	track = path
	collision_layer = Kart.LAYER_WORLD
	var grass: Array = track.grip_and_drag("grass")
	set_meta("grip", grass[0])
	set_meta("drag", grass[1])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.points:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	origin = lo - Vector2.ONE * reach
	cols = int((hi.x - lo.x + reach * 2.0) / CELL) + 2
	rows = int((hi.y - lo.y + reach * 2.0) / CELL) + 2
	_work_out_heights()


## How high the ground is here, between the grid's points.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / CELL, 0.0, cols - 1.001)
	var fz := clampf((z - origin.y) / CELL, 0.0, rows - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var ax := fx - ix
	var az := fz - iz
	var h00 := heights[iz * cols + ix]
	var h10 := heights[iz * cols + ix + 1]
	var h01 := heights[(iz + 1) * cols + ix]
	var h11 := heights[(iz + 1) * cols + ix + 1]
	return lerpf(lerpf(h00, h10, ax), lerpf(h01, h11, ax), az)


func _point(x: int, z: int) -> Vector2:
	return origin + Vector2(x, z) * CELL


## Whether the road at this sample lies on the ground, rather than up in the
## air or leaning on a bank. The flat run in and out of a loop does, even
## though the whole loop is sticky.
func _on_ground(k: int) -> bool:
	return track.solids[k] and track.ups[k].y > 0.985 \
		and track.points[k].y - track.grounds[k] < TrackBuilder.RAISED


func _work_out_heights() -> void:
	# The nearest bit of road on the ground to every point, spread out across
	# the grid in two sweeps from the points right beside the road (the usual
	# trick for a distance map).
	var count := cols * rows
	var nearest := PackedInt32Array()
	nearest.resize(count)
	nearest.fill(-1)
	var gap := PackedFloat32Array()
	gap.resize(count)
	gap.fill(INF)
	for k in track.points.size():
		if not _on_ground(k):
			continue
		var p := Vector2(track.points[k].x, track.points[k].z)
		var cx := int(roundf((p.x - origin.x) / CELL))
		var cz := int(roundf((p.y - origin.y) / CELL))
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var x := cx + dx
				var z := cz + dz
				if x < 0 or z < 0 or x >= cols or z >= rows:
					continue
				var d := _point(x, z).distance_to(p)
				if d < gap[z * cols + x]:
					gap[z * cols + x] = d
					nearest[z * cols + x] = k
	for back in [false, true]:
		var step := 1 if back else -1
		var zs := range(rows - 1, -1, -1) if back else range(rows)
		var xs := range(cols - 1, -1, -1) if back else range(cols)
		for z in zs:
			for x in xs:
				var i: int = z * cols + x
				var here := _point(x, z)
				for n in [Vector2i(x + step, z), Vector2i(x, z + step), Vector2i(x + step, z + step), Vector2i(x - step, z + step)]:
					if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
						continue
					var k := nearest[n.y * cols + n.x]
					if k < 0:
						continue
					var d := here.distance_to(Vector2(track.points[k].x, track.points[k].z))
					if d < gap[i]:
						gap[i] = d
						nearest[i] = k
	var edge := track.width * 0.5 + TrackPath.KERB
	heights.resize(count)
	for z in rows:
		for x in cols:
			var i := z * cols + x
			var at := _point(x, z)
			var hill := track.ground_height(at.x, at.y)
			var k := nearest[i]
			if k < 0:
				heights[i] = hill
				continue
			var road := track.points[k].y - SINK
			heights[i] = lerpf(road, hill, smoothstep(edge, edge + BLEND, gap[i]))


func _ready() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(cols * rows)
	normals.resize(cols * rows)
	for z in rows:
		for x in cols:
			var i := z * cols + x
			var at := _point(x, z)
			vertices[i] = Vector3(at.x, heights[i], at.y)
			var left := heights[z * cols + maxi(x - 1, 0)]
			var right := heights[z * cols + mini(x + 1, cols - 1)]
			var near := heights[maxi(z - 1, 0) * cols + x]
			var far := heights[mini(z + 1, rows - 1) * cols + x]
			normals[i] = Vector3(left - right, CELL * 2.0, near - far).normalized()
	var indices := PackedInt32Array()
	for z in rows - 1:
		for x in cols - 1:
			var a := z * cols + x
			var b := a + 1
			var c := a + cols
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var look := MeshInstance3D.new()
	look.mesh = mesh
	look.material_override = TrackBuilder.baseplate(Color(Scenery.theme_named(track.theme).get("ground", "#4b9f4a")))
	add_child(look)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	add_child(shape)
