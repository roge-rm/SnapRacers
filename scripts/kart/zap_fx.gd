class_name ZapFx
extends Node3D

## Lightning on a struck kart: a bolt from the sky, then sparks and a glow
## that stay on for as long as the kart is slowed.
## Many karts can be struck at once, so the pieces share their meshes and
## materials (each fades with an instance uniform), the glow is a flat
## billboard, sparks and glow are only drawn near a camera, and only a few
## strikes near a race camera get a light, for the first moment.

const COLOUR := Color(1.0, 0.92, 0.35, 1.0)
## The sky bolt is only on for this long at the start. Sparks and the glow
## last the whole slowdown.
const BOLT_TIME := 0.55
const SPARK_EVERY := 0.07
## Sparks, glow and the disc aren't drawn past this from a camera (metres).
const NEAR_RANGE := 45.0
## In Compatibility each omni light draws everything in its range again, so
## at most this many strikes light up at once, and only for LIGHT_TIME. A
## kart a camera follows is always lit.
const MAX_LIGHTS := 2
const LIGHT_TIME := 1.0
## A strike gets a light only this close to a race camera (metres), unless
## that camera follows the struck kart.
const LIGHT_REACH := 40.0

var _age := 0.0
var _spark_wait := 0.0
var _bolt: MeshInstance3D
var _column: MeshInstance3D
var _glow: MeshInstance3D
var _disc: MeshInstance3D
var _sparks: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _rng := RandomNumberGenerator.new()

static var _lights_on := 0
static var _bolt_mesh: ArrayMesh
static var _spark_mesh: ArrayMesh
static var _pole_mesh: CylinderMesh
static var _glow_mesh: QuadMesh
static var _pad_mesh: CylinderMesh
static var _look: ShaderMaterial
static var _glow_look: ShaderMaterial


func _init() -> void:
	top_level = true
	_rng.randomize()
	_make_meshes()
	_bolt = _mesh(_bolt_mesh)
	add_child(_bolt)
	_column = _mesh(_pole_mesh)
	_column.position.y = 8.0
	add_child(_column)
	_glow = _mesh(_glow_mesh, _glow_look)
	_glow.position.y = 0.7
	# It turns to face the camera and comes towards it, outside the flat quad's box.
	_glow.extra_cull_margin = 3.0
	_near_only(_glow)
	add_child(_glow)
	_disc = _mesh(_pad_mesh)
	_disc.position.y = 0.05
	_near_only(_disc)
	add_child(_disc)
	for i in 5:
		var spark := _mesh(_spark_mesh)
		_near_only(spark)
		add_child(spark)
		_sparks.append(spark)
	_place_sparks()


func _exit_tree() -> void:
	_drop_light()


func _ready() -> void:
	_follow()
	_take_light()


## Starts the strike over, if lightning hits a kart that's already zapped.
func restart() -> void:
	_age = 0.0
	_spark_wait = 0.0
	_place_sparks()
	_take_light()


func _process(delta: float) -> void:
	if not _follow():
		return
	_age += delta
	var life := Kart.ZAP_TIME
	if _age >= life:
		queue_free()
		return
	var fade := 1.0 if _age < life - 0.4 else (life - _age) / 0.4
	var strike := clampf(1.0 - _age / BOLT_TIME, 0.0, 1.0)
	_bolt.visible = strike > 0.0
	_column.visible = strike > 0.0
	if strike > 0.0:
		_tint(_bolt, strike * 1.4)
		_tint(_column, strike)
		_column.scale = Vector3(1.0 + strike * 0.8, 1.0, 1.0 + strike * 0.8)
	var pulse := 0.55 + 0.45 * sin(_age * 18.0)
	_tint(_glow, fade * (0.22 + 0.2 * pulse))
	_glow.scale = Vector3.ONE * (1.0 + 0.12 * pulse + strike * 0.5)
	_disc.scale = Vector3(lerpf(1.6, 3.2, 1.0 - strike), 1.0, lerpf(1.6, 3.2, 1.0 - strike))
	_tint(_disc, fade * (0.25 + strike * 0.7))
	_spark_wait -= delta
	if _spark_wait <= 0.0:
		_spark_wait = SPARK_EVERY
		_place_sparks()
	for spark in _sparks:
		_tint(spark, fade * (0.7 + 0.3 * pulse))
	if _light != null:
		if _age >= LIGHT_TIME:
			_drop_light()
		else:
			var dim := clampf((LIGHT_TIME - _age) / 0.3, 0.0, 1.0)
			_light.light_energy = dim * (2.2 + 6.0 * strike + 1.4 * pulse)


## Lights this strike if a race camera follows the kart, or there's a light
## free and one is near. With no race camera (tests, the garage) it's lit.
func _take_light() -> void:
	if _light != null:
		return
	var near := _near_a_camera()
	if near == 0 or (near == 1 and _lights_on >= MAX_LIGHTS):
		return
	_light = OmniLight3D.new()
	_light.light_color = Color("#fff1a8")
	_light.light_energy = 8.0
	_light.omni_range = 12.0
	_light.shadow_enabled = false
	_light.position.y = 1.4
	add_child(_light)
	_lights_on += 1


func _drop_light() -> void:
	if _light == null:
		return
	_light.queue_free()
	_light = null
	_lights_on -= 1


## 2 if a race camera follows the kart (or there are none), 1 if one is
## near, or 0.
func _near_a_camera() -> int:
	var kart := get_parent() as Node3D
	if kart == null or not is_inside_tree():
		return 0
	var cams := get_tree().get_nodes_in_group("race_cameras")
	if cams.is_empty():
		return 2
	var near := 0
	for cam in cams:
		if cam.target == kart:
			return 2
		if kart.global_position.distance_squared_to(cam.global_position) <= LIGHT_REACH * LIGHT_REACH:
			near = 1
	return near


func _place_sparks() -> void:
	for spark in _sparks:
		var around := _rng.randf() * TAU
		var reach := _rng.randf_range(0.35, 1.15)
		spark.position = Vector3(cos(around) * reach, _rng.randf_range(0.25, 1.9), sin(around) * reach)
		spark.basis = Basis.from_euler(Vector3(
			_rng.randf_range(-0.8, 0.8),
			_rng.randf_range(0.0, TAU),
			_rng.randf_range(-0.8, 0.8)))
		var size := _rng.randf_range(1.4, 2.6)
		spark.scale = Vector3(size, size, size)


func _follow() -> bool:
	var kart := get_parent() as Node3D
	if kart == null or not is_instance_valid(kart):
		queue_free()
		return false
	# The sparks, glow and disc tilt with the kart, on a corkscrew say. The
	# bolt and its column come straight down from the sky.
	global_transform = Transform3D(kart.global_basis.orthonormalized(), kart.global_position)
	_bolt.global_transform = Transform3D(Basis.IDENTITY, global_position)
	_column.global_transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 8.0)
	return true


static func _make_meshes() -> void:
	if _bolt_mesh != null:
		return
	_bolt_mesh = _ribbon(PackedVector3Array([
		Vector3(0.15, 16.0, 0.0),
		Vector3(1.35, 13.4, 0.25),
		Vector3(-1.05, 10.8, -0.35),
		Vector3(0.95, 8.1, 0.4),
		Vector3(-0.75, 5.4, -0.2),
		Vector3(0.55, 2.9, 0.18),
		Vector3(-0.12, 1.2, 0.0),
		Vector3(0.0, 0.35, 0.0),
	]), 0.22)
	_spark_mesh = _ribbon(_jagged(1.0, 0.45, 5), 0.08)
	_pole_mesh = CylinderMesh.new()
	_pole_mesh.top_radius = 0.06
	_pole_mesh.bottom_radius = 0.2
	_pole_mesh.height = 16.0
	_pole_mesh.radial_segments = 8
	_pole_mesh.rings = 1
	_pole_mesh.cap_top = false
	_pole_mesh.cap_bottom = false
	_glow_mesh = QuadMesh.new()
	_glow_mesh.size = Vector2(4.4, 4.4)
	_pad_mesh = CylinderMesh.new()
	_pad_mesh.top_radius = 1.0
	_pad_mesh.bottom_radius = 1.0
	_pad_mesh.height = 0.1
	_pad_mesh.radial_segments = 20
	_pad_mesh.rings = 1
	var plain := Shader.new()
	plain.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 colour : source_color;
instance uniform float fade = 1.0;
void fragment() {
	ALBEDO = colour.rgb;
	ALPHA = clamp(fade, 0.0, 1.0);
}
"""
	_look = ShaderMaterial.new()
	_look.shader = plain
	_look.set_shader_parameter("colour", COLOUR)
	var glow := Shader.new()
	glow.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 colour : source_color;
instance uniform float fade = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	// Brought towards the camera so the kart doesn't hide it.
	MODELVIEW_MATRIX[3].z += 1.6;
}
void fragment() {
	float edge = clamp(1.0 - length(UV * 2.0 - 1.0), 0.0, 1.0);
	ALBEDO = colour.rgb;
	ALPHA = clamp(fade * edge * edge * 3.2, 0.0, 1.0);
}
"""
	_glow_look = ShaderMaterial.new()
	_glow_look.shader = glow
	_glow_look.set_shader_parameter("colour", COLOUR)


static func _jagged(height: float, jag: float, points: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in points:
		var t := float(i) / float(points - 1)
		var side := 0.0 if i == 0 or i == points - 1 else (1.0 if i % 2 == 0 else -1.0) * jag
		pts.append(Vector3(side, t * height, side * 0.35))
	return pts


static func _ribbon(points: PackedVector3Array, width: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var along := b - a
		var side := along.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = along.cross(Vector3.FORWARD)
		side = side.normalized() * (width * 0.5)
		var a0 := a - side
		var a1 := a + side
		var b0 := b - side
		var b1 := b + side
		for vertex in [a0, a1, b1, a0, b1, b0]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)
	tool.index()
	return tool.commit()


func _mesh(mesh: Mesh, look: ShaderMaterial = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = look if look != null else _look
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _near_only(node: MeshInstance3D) -> void:
	node.visibility_range_end = NEAR_RANGE
	node.visibility_range_end_margin = 5.0


func _tint(node: MeshInstance3D, alpha: float) -> void:
	node.set_instance_shader_parameter("fade", clampf(alpha, 0.0, 1.0))
