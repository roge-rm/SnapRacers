class_name BrickTrap
extends StaticBody3D

## A trap dropped on the road behind a kart, lying flat on whatever's under
## it, that clears away after a while:
## - "marbles": round 1x1 bricks scattered all over, which roll under the
##   wheels, so whoever drives across them loses nearly all their grip and
##   slides;
## - "spikes": a cluster of little grey cones, which hold karts back hard
##   without making them slide, and knock a part off one that hits them fast
##   (see Kart).
##
## Wheels feel it through the ground's "grip" and "drag", and a ghost drives
## over it as if it isn't there ("trap").

const LIFETIME := 15.0
## For each kind: how far across it reaches, the grip and drag on it, and how
## many pieces are scattered over it.
const KINDS := {
	"marbles": { "radius": 2.0, "grip": 0.12, "drag": 0.6, "pieces": 22 },
	"spikes": { "radius": 2.3, "grip": 0.85, "drag": 35.0, "pieces": 14 },
}
const MARBLE_COLOURS := [Color("#c4281c"), Color("#0d69ab"), Color("#f2cd37"), Color("#4b974b"), Color("#f2f3f2"), Color("#da8540")]
const SPIKE := Color("#635f61")

var kind := "marbles"
var _age := 0.0


## A trap on the ground just behind this kart.
static func drop_behind(from: Kart, what := "marbles") -> BrickTrap:
	var trap := BrickTrap.new(what)
	var behind := from.global_position + from.global_basis.z * 2.6
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


func _init(what := "marbles") -> void:
	kind = what if KINDS.has(what) else "marbles"
	var of: Dictionary = KINDS[kind]
	var radius: float = of.radius
	collision_layer = Kart.LAYER_WORLD
	set_meta("grip", of.grip)
	set_meta("drag", of.drag)
	set_meta("trap", kind)
	# Thin enough that nothing catches on its edge.
	var shape := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = radius
	disc.height = 0.04
	shape.shape = disc
	add_child(shape)
	add_child(_pieces(of.pieces, radius))


## The bricks scattered over it, baked into one mesh.
func _pieces(count: int, radius: float) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + get_instance_id()
	var parts: Array[Node3D] = []
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius * 0.9
		var at := Vector3(cos(a) * r, 0.0, sin(a) * r)
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
			# A round 1x1 brick, some on their sides.
			piece.mesh = MeshKit.rounded_cylinder(0.12, 0.2, 0.025, 14)
			var tipped := rng.randf() < 0.5
			piece.position = at + Vector3.UP * (0.12 if tipped else 0.1)
			piece.rotation = Vector3(PI * 0.5 if tipped else 0.0, rng.randf() * TAU, 0.0)
			piece.material_override = PartVisuals.material(MARBLE_COLOURS[rng.randi() % MARBLE_COLOURS.size()])
		parts.append(piece)
	var baked := KartMesh.bake(parts)
	for part in parts:
		part.free()
	return baked


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
