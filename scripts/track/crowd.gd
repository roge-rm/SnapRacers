class_name Crowd
extends Node3D

## The brick figures watching the race, from a SceneryKit's fans. They're
## cheap brick shapes, drawn in nearby bunches so a far-off grandstand is
## skipped, and they don't cast shadows.
##
## They move in the shader: a little bob and a look around while they wait,
## and when a kart comes by, the bunch nearest it jumps up and down and waves
## its arms. How excited each fan is goes to the shader in its instance's
## custom data, worked out a few times a second.

const PIECES := ["legs", "body", "head", "hair", "face", "left_arm", "right_arm"]
const SKIN := Color("#f2cd37")
const FACE := Color("#1b1b1b")
## How near a kart has to come for a bunch of fans to cheer, and how quickly
## they get excited and calm down again.
const CHEER_REACH := 40.0
const WARM_UP := 3.0
const COOL_DOWN := 0.6
const LOOK_EVERY := 0.25
## A little of the excitement stays all race, so they never stand quite still.
const AT_REST := 0.12
## Fans in one cell are drawn together. Each fan fades in like far-off
## scenery (see Graphics.far()), and a cell is skipped once it's CELL_REACH
## past that, from its middle, which is enough for a fan in its corner.
const CELL := 32.0
const CELL_REACH := 30.0

const SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float part = 0.0;

varying vec3 tint;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float cheer = INSTANCE_CUSTOM.y;
	float t = TIME + phase * 7.0;
	// A jump that gets bigger the more excited they are, and a sway.
	float hop = abs(sin(t * 6.5)) * 0.12 * cheer * cheer;
	float sway = sin(t * 1.3) * 0.05;
	vec3 v = VERTEX;
	if (part > 4.5) {
		// The arms swing up about the shoulder, out to the side.
		float side = part > 5.5 ? -1.0 : 1.0;
		float lift = 0.15 + cheer * (2.3 + 0.5 * sin(t * 9.0));
		float c = cos(lift * side);
		float s = sin(lift * side);
		v = vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
		v += vec3(side * 0.24, 0.78, 0.0);
	} else if (part > 1.5) {
		// The head, and the hair and face on it, look about a little.
		float look = sin(t * 0.7) * 0.4 * (1.0 - cheer);
		float c = cos(look);
		float s = sin(look);
		v = vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
	}
	v.x += sway * v.y * 0.3;
	v.y += hop;
	VERTEX = v;
	tint = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	ALBEDO = tint;
}
"""

static var _shader: Shader
static var _meshes := {}

## Each cell's MultiMeshes, piece name to MultiMesh.
var _cell_multis: Array = []
var _home: PackedInt32Array = PackedInt32Array()
var _local: PackedInt32Array = PackedInt32Array()
## Each bunch of fans: where its middle is, which fans are in it, and how
## excited it is.
var _bunches := {}
var _phases := PackedFloat32Array()
var _look_in := 0.0
var _looks := 0
var _karts: Array = []


func _init(fans: Array) -> void:
	name = "Crowd"
	if _shader == null:
		_shader = TrackBuilder.shader_for(BrickShaders.fading(SHADER))
	var rng := RandomNumberGenerator.new()
	rng.seed = fans.size()
	_phases.resize(fans.size())
	_home.resize(fans.size())
	_local.resize(fans.size())
	var grouped := {}
	for i in fans.size():
		var fan: Array = fans[i]
		var feet: Transform3D = fan[0]
		_phases[i] = rng.randf()
		var bunch: int = fan[4]
		if not _bunches.has(bunch):
			_bunches[bunch] = { "middle": Vector3.ZERO, "fans": [], "cheer": AT_REST }
		_bunches[bunch].fans.append(i)
		_bunches[bunch].middle += feet.origin
		var key := Vector2i(floori(feet.origin.x / CELL), floori(feet.origin.z / CELL))
		if not grouped.has(key):
			grouped[key] = []
		grouped[key].append(i)
	for bunch in _bunches.values():
		bunch.middle /= bunch.fans.size()
	for key in grouped:
		_add_cell(fans, grouped[key], Vector3((key.x + 0.5) * CELL, 0.0, (key.y + 0.5) * CELL))


func _add_cell(fans: Array, indices: Array, origin: Vector3) -> void:
	var cell := _cell_multis.size()
	var pack := {}
	var draws := {}
	for p in PIECES.size():
		var piece: String = PIECES[p]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = mesh_of(piece)
		multi.instance_count = indices.size()
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("part", float(p))
		material.set_shader_parameter("fade_range", Vector2(Graphics.far() - WorldDamage.FADE_BAND, Graphics.far()))
		draw.material_override = material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		draw.position = origin
		draw.visibility_range_end = Graphics.far() + CELL_REACH
		draw.visibility_range_end_margin = 2.0
		add_child(draw)
		pack[piece] = multi
		draws[piece] = draw
	_cell_multis.append(pack)
	for k in indices.size():
		var i: int = indices[k]
		var fan: Array = fans[i]
		var feet: Transform3D = fan[0]
		_home[i] = cell
		_local[i] = k
		var colours := { "legs": fan[2], "body": fan[1], "head": SKIN, "hair": fan[3], "face": FACE, "left_arm": fan[1], "right_arm": fan[1] }
		var where := Transform3D(feet.basis, feet.origin - origin)
		var rest := Color(_phases[i], AT_REST, 0.0, 0.0)
		for piece in PIECES:
			var multi: MultiMesh = pack[piece]
			multi.set_instance_transform(k, where)
			multi.set_instance_color(k, colours[piece])
			multi.set_instance_custom_data(k, rest)
	var bounds := AABB(Vector3(-CELL * 0.5 - 2.0, -1.0, -CELL * 0.5 - 2.0), Vector3(CELL + 4.0, 12.0, CELL + 4.0))
	for piece in PIECES:
		pack[piece].custom_aabb = bounds
		draws[piece].custom_aabb = bounds


## The mesh for one piece of a fan, standing on the origin and facing -Z. An
## arm hangs from the origin, its shoulder, and the shader puts it in place.
static func mesh_of(piece: String) -> Mesh:
	if _meshes.has(piece):
		return _meshes[piece]
	var made: Mesh
	match piece:
		"legs":
			made = _join([[_box(Vector3(0.17, 0.4, 0.2)), Vector3(-0.1, 0.2, 0.0)],
				[_box(Vector3(0.17, 0.4, 0.2)), Vector3(0.1, 0.2, 0.0)],
				[_box(Vector3(0.4, 0.1, 0.2)), Vector3(0.0, 0.42, 0.0)]])
		"body":
			made = _join([[_box(Vector3(0.42, 0.36, 0.2)), Vector3(0.0, 0.65, 0.0)]])
		"head":
			made = _join([[_cyl(0.12, 0.22), Vector3(0.0, 0.96, 0.0)],
				[_cyl(0.06, 0.06), Vector3(0.0, 1.08, 0.0)]])
		"hair":
			made = _join([[_box(Vector3(0.27, 0.12, 0.26)), Vector3(0.0, 1.07, 0.02)]])
		"face":
			made = _join([[_box(Vector3(0.05, 0.04, 0.02)), Vector3(-0.045, 0.995, -0.115)],
				[_box(Vector3(0.05, 0.04, 0.02)), Vector3(0.045, 0.995, -0.115)],
				[_box(Vector3(0.08, 0.02, 0.02)), Vector3(0.0, 0.955, -0.118)]])
		_:
			made = _join([[_box(Vector3(0.1, 0.3, 0.12)), Vector3(0.0, -0.13, 0.0)],
				[_cyl(0.05, 0.08), Vector3(0.0, -0.31, 0.0)]])
	_meshes[piece] = made
	return made


static func _box(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cyl(radius: float, height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


## Several meshes, each moved by its offset or transform, as one.
static func _join(pieces: Array) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		var where: Transform3D = piece[1] if piece[1] is Transform3D else Transform3D(Basis.IDENTITY, piece[1])
		tool.append_from(piece[0], 0, where)
	return tool.commit()


func _process(delta: float) -> void:
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = LOOK_EVERY
	_looks += 1
	# Every couple of seconds, in case someone's joined.
	if _karts.is_empty() or _looks % 8 == 0:
		_karts = get_tree().get_nodes_in_group("karts")
	for bunch in _bunches.values():
		var near := false
		for kart in _karts:
			if is_instance_valid(kart) and kart.global_position.distance_to(bunch.middle) < CHEER_REACH:
				near = true
				break
		var was: float = bunch.cheer
		bunch.cheer = move_toward(bunch.cheer, 1.0 if near else AT_REST, LOOK_EVERY * (WARM_UP if near else COOL_DOWN))
		if absf(bunch.cheer - was) < 0.001:
			continue
		for i in bunch.fans:
			# Not all of them get quite as excited.
			var each: float = bunch.cheer * (0.7 + 0.3 * _phases[i])
			var data := Color(_phases[i], each, 0.0, 0.0)
			var pack: Dictionary = _cell_multis[_home[i]]
			var li := _local[i]
			for piece in PIECES:
				pack[piece].set_instance_custom_data(li, data)
