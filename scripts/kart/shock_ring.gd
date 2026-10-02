class_name ShockRing
extends MeshInstance3D

## The ring a shockwave sends out across the ground, growing and fading.

const TIME := 0.45

var reach := 8.0
var _age := 0.0
var _look: StandardMaterial3D


func _init() -> void:
	mesh = MeshKit.arc_tube(1.0, 0.06, 0.0, TAU, 40, 6)
	_look = StandardMaterial3D.new()
	_look.albedo_color = Color(1.0, 0.95, 0.7, 0.8)
	_look.emission_enabled = true
	_look.emission = Color("#fff1b0")
	_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _look
	top_level = true


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / TIME, 0.0, 1.0)
	if t >= 1.0:
		queue_free()
		return
	var r := lerpf(0.8, reach, t)
	# The arc tube goes round in its own XY plane, so it's laid flat.
	basis = Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(r, r, 1.0))
	_look.albedo_color.a = 0.8 * (1.0 - t)
