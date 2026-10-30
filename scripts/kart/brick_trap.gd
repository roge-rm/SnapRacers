class_name BrickTrap
extends StaticBody3D

## A trap dropped on the road behind a kart, lying flat on whatever's under
## it, that clears away after a while:
## - "marbles": round 1x1 bricks scattered all over, which roll under the
##   wheels, so whoever drives across them loses nearly all their grip and
##   slides;
## - "spikes": a cluster of little grey cones, which hold karts back hard
##   without making them slide, and pop a tire of one that hits them fast
##   (see Kart).
##
## Wheels feel it through the ground's "grip" and "drag", and a ghost drives
## over it as if it isn't there ("trap").

const LIFETIME := 15.0
## Clear space between the kart's tail and the nearest edge of the patch.
const DROP_GAP := 0.5
## For each kind: how far it reaches either side of its middle across the
## road and along it, the grip and drag on it, and how many pieces are
## scattered over it. Marbles are a wide oval across the road.
const KINDS := {
	"marbles": { "across": 3.4, "along": 2.6, "grip": 0.12, "drag": 0.6, "pieces": 48 },
	"spikes": { "across": 2.3, "along": 2.3, "grip": 0.85, "drag": 35.0, "pieces": 14 },
}
## Sides of the oval the patch's shape is made of.
const SIDES := 24
const MARBLE_COLOURS := BrickPile.COLOURS
## The little pieces marbles are made of: round and square 1x1 bricks, round
## plates, balls and 1x2 plates.
const MARBLE_SHAPES := ["round", "square", "round_plate", "ball", "plate_1x2"]
const SPIKE := Color("#635f61")

var kind := "marbles"
var _age := 0.0


## A trap on the ground just behind this kart.
static func drop_behind(from: Kart, what := "marbles") -> BrickTrap:
	# From the kart's grid slot and how many things it's dropped, so every
	# device scatters the same pieces.
	var trap := BrickTrap.new(what, hash([from.grid_slot, from.drops]))
	from.drops += 1
	# The entire patch must clear the kart, including long builds and rear wheels.
	var distance: float = from.rear_bumper_point().z + KINDS[trap.kind].along + DROP_GAP
	var behind := from.global_position + from.global_basis.z * distance
	# Down onto whatever's under that spot, lying flat on it.
	var space := from.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(behind + Vector3.UP * 2.0, behind + Vector3.DOWN * 4.0, Kart.LAYER_WORLD)
	var hit := space.intersect_ray(query)
	var ground: Vector3 = hit.position if not hit.is_empty() else behind
	var normal: Vector3 = hit.normal if not hit.is_empty() else Vector3.UP
	var forward := (-from.global_basis.z).slide(normal).normalized()
	if forward.length() < 0.1:
		forward = Vector3.FORWARD
	trap.transform = Transform3D(Basis.looking_at(forward, normal), ground + normal * 0.01)
	return trap


func _init(what := "marbles", look_seed := 0) -> void:
	kind = what if KINDS.has(what) else "marbles"
	var of: Dictionary = KINDS[kind]
	var across: float = of.across
	var along: float = of.along
	collision_layer = Kart.LAYER_WORLD
	set_meta("grip", of.grip)
	set_meta("drag", of.drag)
	set_meta("trap", kind)
	# A flat oval, thin enough that nothing catches on its edge.
	var shape := CollisionShape3D.new()
	var oval := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for i in SIDES:
		var a := TAU * i / SIDES
		for y in [-0.02, 0.02]:
			points.append(Vector3(cos(a) * across, y, sin(a) * along))
	oval.points = points
	shape.shape = oval
	add_child(shape)
	add_child(_pieces(of.pieces, across, along, look_seed))


## The bricks scattered over it, baked into one mesh.
func _pieces(count: int, across: float, along: float, look_seed: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([kind, look_seed])
	var parts: Array[Node3D] = []
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.9
		var at := Vector3(cos(a) * r * across, 0.0, sin(a) * r * along)
		var piece := MeshInstance3D.new()
		if kind == "spikes":
			# A little grey cone on a round plate.
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.13
			cone.height = 0.3
			cone.radial_segments = 10
			piece.mesh = cone
			piece.position = at + Vector3.UP * 0.19
			piece.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
			piece.material_override = PartVisuals.material(SPIKE)
			var plate := MeshInstance3D.new()
			plate.mesh = MeshKit.rounded_cylinder(0.14, 0.06, 0.015, 12)
			plate.position = at + Vector3.UP * 0.03
			plate.material_override = PartVisuals.material(SPIKE.darkened(0.2))
			parts.append(plate)
		else:
			# A little piece of a random shape, some on their sides.
			var tipped := rng.randf() < 0.5
			var high := 0.2
			match MARBLE_SHAPES[rng.randi_range(0, MARBLE_SHAPES.size() - 1)]:
				"round":
					piece.mesh = MeshKit.rounded_cylinder(0.12, 0.2, 0.025, 14)
				"square":
					piece.mesh = MeshKit.rounded_box(Vector3(0.24, 0.2, 0.24), 0.025)
				"round_plate":
					piece.mesh = MeshKit.rounded_cylinder(0.12, 0.08, 0.02, 14)
					high = 0.08
					tipped = false
				"ball":
					var ball := SphereMesh.new()
					ball.radius = 0.12
					ball.height = 0.24
					ball.radial_segments = 12
					ball.rings = 6
					piece.mesh = ball
					high = 0.24
					tipped = false
				_:
					piece.mesh = MeshKit.rounded_box(Vector3(0.24, 0.08, 0.48), 0.02)
					high = 0.08
					tipped = false
			piece.position = at + Vector3.UP * (0.12 if tipped else high * 0.5)
			piece.rotation = Vector3(PI * 0.5 if tipped else 0.0, rng.randf() * TAU, 0.0)
			piece.material_override = PartVisuals.material(MARBLE_COLOURS[rng.randi_range(0, MARBLE_COLOURS.size() - 1)])
		parts.append(piece)
	var baked := KartMesh.bake(parts)
	for part in parts:
		part.free()
	return baked


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
