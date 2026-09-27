class_name TestTrack
extends Node3D

## A plain oval on a big green baseplate, with a jump on the back straight and
## a pile of loose bricks in the middle to crash into. It's for trying out
## handling until the real tracks and the track builder exist.

const HALF_STRAIGHT := 40.0
const RADIUS := 30.0
const ROAD_WIDTH := 12.0
const LOT := 130.0

var spawn := Transform3D(Basis.IDENTITY, Vector3(RADIUS, 0.05, 20.0))

const GROUND_SHADER := """
shader_type spatial;
uniform float half_straight;
uniform float radius;
uniform float road_width;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world.xz / 4.0);
	float check = mod(cell.x + cell.y, 2.0);
	vec3 grass = mix(vec3(0.24, 0.52, 0.2), vec3(0.21, 0.47, 0.18), check);
	float along = world.z - clamp(world.z, -half_straight, half_straight);
	float d = abs(length(vec2(world.x, along)) - radius);
	float half_road = road_width * 0.5;
	vec3 colour = grass;
	if (d < half_road + 0.8) {
		float stripe = mod(floor((world.z + world.x) / 2.0), 2.0);
		colour = mix(vec3(0.85, 0.1, 0.08), vec3(0.95), stripe);
	}
	if (d < half_road) {
		colour = vec3(0.32, 0.33, 0.36);
		if (abs(world.z - 20.0) < 0.6 && world.x > 0.0) {
			colour = vec3(0.95);
		}
	}
	// The colours above are picked as sRGB, but ALBEDO wants linear.
	ALBEDO = pow(colour, vec3(2.2));
	ROUGHNESS = 0.9;
}
"""


func _ready() -> void:
	_add_environment()
	_add_ground()
	_add_walls()
	_add_ramp(Vector3(-RADIUS, 0.0, 0.0), 0.0)
	_add_brick_pile(Vector3(0.0, 0.0, 0.0))


func _add_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#3d7fd6")
	sky_material.sky_horizon_color = Color("#b9d6f2")
	sky_material.ground_horizon_color = Color("#b9d6f2")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _add_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LOT * 2.0, 2.0, LOT * 2.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(LOT * 2.0, LOT * 2.0)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	mesh.mesh = plane
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	material.shader = shader
	material.set_shader_parameter("half_straight", HALF_STRAIGHT)
	material.set_shader_parameter("radius", RADIUS)
	material.set_shader_parameter("road_width", ROAD_WIDTH)
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)


func _add_walls() -> void:
	for i in 4:
		var angle := i * PI * 0.5
		var along := Vector3(cos(angle), 0.0, sin(angle))
		var wall_at := Vector3(-along.z, 0.0, along.x) * LOT
		_add_box(wall_at + Vector3.UP * 0.6, Vector3(LOT * 2.0, 1.2, 1.0), Basis(Vector3.UP, -angle), Color("#c4281c"))


func _add_ramp(at: Vector3, yaw: float) -> void:
	var length := 7.0
	var rise := 1.2
	var tilt := atan2(rise, length)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	_add_box(at + Vector3.UP * (rise * 0.5 - 0.35), Vector3(8.0, 0.6, sqrt(length * length + rise * rise)), basis, Color("#f2cd37"))


func _add_box(at: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	body.transform = Transform3D(basis, at)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)


func _add_brick_pile(at: Vector3) -> void:
	var colors := [Color("#c4281c"), Color("#0d69ab"), Color("#f2cd37"), Color("#ffffff"), Color("#237841")]
	var size := Vector3(4.0, 3.0, 2.0) * Grid.UNIT * 2.0
	for layer in 4:
		for i in 6:
			var body := RigidBody3D.new()
			body.collision_layer = Kart.LAYER_WORLD
			body.collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS
			body.mass = 3.0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			body.add_child(shape)
			var mesh := MeshInstance3D.new()
			var box_mesh := BoxMesh.new()
			box_mesh.size = size
			mesh.mesh = box_mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = colors[(layer + i) % colors.size()]
			material.roughness = 0.35
			mesh.material_override = material
			body.add_child(mesh)
			var shift := size.x * 0.5 if layer % 2 == 1 else 0.0
			body.position = at + Vector3(i * size.x + shift - size.x * 3.0, size.y * (layer + 0.5), 0.0)
			add_child(body)
