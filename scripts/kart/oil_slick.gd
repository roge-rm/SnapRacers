class_name OilSlick
extends StaticBody3D

## The puddle an oil can leaves on the road behind a kart. It lies flat on
## whatever's under it, and wheels on it lose almost all their grip, so
## whoever drives over it slides. It soaks away after a while.

const LIFETIME := 15.0
const RADIUS := 2.0
const GRIP := 0.12
const DRAG := 0.6

var _age := 0.0


## A slick on the ground just behind this kart.
static func drop_behind(from: Kart) -> OilSlick:
	var slick := OilSlick.new()
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
	slick.transform = Transform3D(Basis.looking_at(forward, normal), ground + normal * 0.03)
	return slick


func _init() -> void:
	collision_layer = Kart.LAYER_WORLD
	set_meta("grip", GRIP)
	set_meta("drag", DRAG)
	# Thin enough that nothing catches on its edge.
	var shape := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = RADIUS
	disc.height = 0.04
	shape.shape = disc
	add_child(shape)
	var look := MeshInstance3D.new()
	var puddle := CylinderMesh.new()
	puddle.top_radius = RADIUS
	puddle.bottom_radius = RADIUS
	puddle.height = 0.04
	puddle.radial_segments = 24
	look.mesh = puddle
	var shine := StandardMaterial3D.new()
	shine.albedo_color = Color("#15131a")
	shine.metallic = 0.6
	shine.roughness = 0.1
	look.material_override = shine
	add_child(look)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
