class_name HeadlightPool
extends MeshInstance3D

## The light a kart's headlights throw on the road ahead, as a fan of soft
## light lying just above it. A real light would mean drawing the road and
## everything near it again for every kart, too slow for a phone, so it's one
## see-through shape that adds its light to whatever's under it.

## How long and wide the fan is, in metres, and how bright.
const LENGTH := 10.0
const WIDTH := 4.0
const BRIGHTNESS := 0.5

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float bright = 0.35;
void fragment() {
	// UV.y runs from the kart (1) out to the far end (0). The fan widens as
	// it goes, and fades out at its far end and its sides.
	float out_ = 1.0 - UV.y;
	float across = abs(UV.x - 0.5) * 2.0;
	float fan = 1.0 - smoothstep(0.25 + 0.75 * out_, 0.35 + 0.8 * out_, across);
	float fade = smoothstep(0.0, 0.12, out_) * (1.0 - smoothstep(0.55, 1.0, out_));
	ALBEDO = vec3(1.0, 0.92, 0.75) * bright * fan * fade;
}
"""

static var _shader: Shader


## A fan in front of a kart whose front is `front` and whose wheels touch the
## ground at `ground` (both along and up, in the kart's own space).
func _init(front: float, ground: float) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var quad := PlaneMesh.new()
	quad.size = Vector2(WIDTH, LENGTH)
	mesh = quad
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("bright", BRIGHTNESS)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A little up, since the kart sits lower than its wheels at rest.
	position = Vector3(0.0, ground + 0.2, front - LENGTH * 0.5)
