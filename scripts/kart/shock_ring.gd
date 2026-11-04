class_name ShockRing
extends Node3D

## The burst a shockwave sends out: a flash in the middle, a wall that
## grows outward, and rings across the ground.

const TIME := 0.7
const COLOUR := Color(0.7, 0.95, 1.0, 1.0)

var reach := 12.0
var _age := 0.0
var _flash: MeshInstance3D
var _wall: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _light: OmniLight3D


func _init() -> void:
	top_level = true
	_flash = _mesh(_disc(0.12), 1.2)
	_flash.position.y = 0.06
	add_child(_flash)
	_wall = _mesh(_pipe(1.8), 0.9)
	_wall.position.y = 0.9
	add_child(_wall)
	for i in 3:
		var ring := _mesh(MeshKit.arc_tube(1.0, 0.14 + i * 0.04, 0.0, TAU, 40, 6), 1.0)
		add_child(ring)
		_rings.append(ring)
	_light = OmniLight3D.new()
	_light.light_color = Color("#b8f4ff")
	_light.light_energy = 6.0
	_light.omni_range = 14.0
	_light.shadow_enabled = false
	add_child(_light)


func _disc(height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	return mesh


func _pipe(height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = height
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 32
	mesh.rings = 1
	return mesh


func _mesh(mesh: Mesh, bright: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var look := StandardMaterial3D.new()
	look.albedo_color = COLOUR
	look.emission_enabled = true
	look.emission = Color("#d4fbff") * bright
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = look
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / TIME, 0.0, 1.0)
	if t >= 1.0:
		queue_free()
		return
	var fade := 1.0 - t
	# Expand quickly enough to pass ahead of a moving first person camera.
	var expansion := 1.0 - pow(1.0 - t, 4.0)
	_flash.scale = Vector3(lerpf(0.6, reach * 0.35, t), 1.0, lerpf(0.6, reach * 0.35, t))
	_tint(_flash, fade * fade * 1.2)
	var wall_r := lerpf(0.5, reach, expansion)
	_wall.scale = Vector3(wall_r, 1.0 + 0.35 * t, wall_r)
	_tint(_wall, fade * 0.7)
	for i in _rings.size():
		var delay := i * 0.12
		var u := clampf((_age - delay) / (TIME - delay * 0.5), 0.0, 1.0)
		var r := lerpf(0.6, reach, 1.0 - pow(1.0 - u, 4.0))
		_rings[i].visible = _age >= delay
		_rings[i].basis = Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(r, r, 1.0))
		_rings[i].position.y = 0.12 + i * 0.18
		_tint(_rings[i], (1.0 - u) * 0.9)
	if _light != null:
		_light.light_energy = 6.0 * fade * fade


func _tint(node: MeshInstance3D, alpha: float) -> void:
	var look: StandardMaterial3D = node.material_override
	var a := clampf(alpha, 0.0, 1.0)
	look.albedo_color.a = a
	look.emission = Color("#d4fbff") * a
