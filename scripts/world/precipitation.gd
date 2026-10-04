class_name Precipitation
extends MultiMeshInstance3D

## Rain, snow or dust falling around whoever's watching. It's one batch of
## little flat shapes in a box the shader moves along on the graphics card and
## wraps around whichever camera is drawing, so it's always falling all
## around you, in both halves of a split screen, with nothing for the
## processor to do each frame.

## The box it falls in around the camera, in metres.
const BOX := Vector3(30.0, 18.0, 30.0)

## Each kind: how many, how big each one is (across, up), which way and how
## fast it falls, how much it wanders, its colour and see-through-ness, and
## whether it's a streak along the way it falls (rain) or faces you (snow).
const KINDS := {
	"rain": {"count": 1100, "size": Vector2(0.018, 0.6), "fall": Vector3(1.5, -16.0, 0.8), "sway": 0.0, "colour": Color(0.8, 0.84, 0.9, 0.5), "streak": 1.0},
	"storm": {"count": 1300, "size": Vector2(0.018, 0.7), "fall": Vector3(4.0, -19.0, 2.0), "sway": 0.0, "colour": Color(0.75, 0.8, 0.88, 0.4), "streak": 1.0},
	"snow": {"count": 900, "size": Vector2(0.09, 0.09), "fall": Vector3(0.6, -1.6, 0.3), "sway": 0.5, "colour": Color(1.0, 1.0, 1.0, 0.9), "streak": 0.0},
	"dust": {"count": 400, "size": Vector2(0.9, 0.5), "fall": Vector3(7.0, -0.3, 2.5), "sway": 1.2, "colour": Color(0.78, 0.62, 0.42, 0.12), "streak": 0.0},
}

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix, skip_vertex_transform, fog_disabled;
uniform vec3 box;
uniform vec3 fall;
uniform float sway;
uniform vec4 colour;
uniform float streak;
varying vec2 shape;
varying float near;

void vertex() {
	// Where this one is in the box, moved along by time and wrapped around
	// the camera so the box always surrounds it.
	vec3 p = INSTANCE_CUSTOM.xyz * box + fall * TIME;
	p += vec3(sin(TIME * 1.3 + INSTANCE_CUSTOM.y * 40.0), 0.0, cos(TIME * 1.1 + INSTANCE_CUSTOM.x * 40.0)) * sway;
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	p = mod(p - eye + box * 0.5, box) - box * 0.5 + eye;
	vec3 up = streak > 0.5 ? normalize(-fall) : INV_VIEW_MATRIX[1].xyz;
	vec3 right = streak > 0.5 ? normalize(cross(up, INV_VIEW_MATRIX[2].xyz)) : INV_VIEW_MATRIX[0].xyz;
	vec3 world = p + right * VERTEX.x + up * VERTEX.y;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	shape = UV * 2.0 - 1.0;
	// Right in front of the camera one would fill the screen, so they fade
	// out close up.
	near = smoothstep(1.5, 4.0, length(p - eye));
}

void fragment() {
	ALBEDO = colour.rgb;
	// A streak fades at its ends; a flake or a wisp is soft and round.
	float soft = streak > 0.5 ? 1.0 - abs(shape.y) : 1.0 - smoothstep(0.4, 1.0, length(shape));
	ALPHA = colour.a * soft * near;
}
"""

static var _shader: Shader


## The right kind for this weather, or null if nothing's falling.
static func for_weather(weather: String) -> Precipitation:
	if not KINDS.has(weather):
		return null
	var falling := Precipitation.new()
	falling._make(KINDS[weather])
	return falling


func _make(kind: Dictionary) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var quad := QuadMesh.new()
	quad.size = kind.size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	var count := roundi(kind.count * Graphics.value("falling"))
	multi.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		multi.set_instance_transform(i, Transform3D.IDENTITY)
		multi.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), 0.0))
	multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("box", BOX)
	material.set_shader_parameter("fall", kind.fall)
	material.set_shader_parameter("sway", kind.sway)
	material.set_shader_parameter("colour", kind.colour)
	material.set_shader_parameter("streak", kind.streak)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader puts them around the camera, wherever it is, so it must
	# never be left out for being off screen.
	custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
