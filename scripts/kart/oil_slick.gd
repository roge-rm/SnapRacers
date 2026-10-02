class_name OilSlick
extends StaticBody3D

## The puddle an oil can leaves on the road behind a kart. It lies flat on
## whatever's under it, and wheels on it lose almost all their grip, so
## whoever drives over it slides. It soaks away after a while. Glue is a
## patch the same way, but sticky: it holds karts back hard without making
## them slide.

const LIFETIME := 15.0
## For each kind: how big, the grip and drag on it, and its colour.
const KINDS := {
	"oil": { "radius": 2.0, "grip": 0.12, "drag": 0.6, "colour": Color("#15131a"), "shine": true },
	"glue": { "radius": 2.5, "grip": 0.85, "drag": 35.0, "colour": Color("#f5d020"), "shine": false },
}

var kind := "oil"
var _age := 0.0


## A slick on the ground just behind this kart.
static func drop_behind(from: Kart, what := "oil") -> OilSlick:
	var slick := OilSlick.new(what)
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


func _init(what := "oil") -> void:
	kind = what if KINDS.has(what) else "oil"
	var look_of: Dictionary = KINDS[kind]
	var radius: float = look_of.radius
	collision_layer = Kart.LAYER_WORLD
	set_meta("grip", look_of.grip)
	set_meta("drag", look_of.drag)
	# A ghost goes over glue as well as oil.
	set_meta("oil", true)
	# Thin enough that nothing catches on its edge.
	var shape := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = radius
	disc.height = 0.04
	shape.shape = disc
	add_child(shape)
	var look := MeshInstance3D.new()
	var puddle := CylinderMesh.new()
	puddle.top_radius = radius
	puddle.bottom_radius = radius
	puddle.height = 0.04
	puddle.radial_segments = 24
	look.mesh = puddle
	var shine := StandardMaterial3D.new()
	shine.albedo_color = look_of.colour
	shine.metallic = 0.6 if look_of.shine else 0.0
	shine.roughness = 0.1 if look_of.shine else 0.8
	look.material_override = shine
	add_child(look)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
