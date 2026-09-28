class_name StudField
extends Node3D

## The loose studs along a track, which karts pick up to spend on gadgets.
##
## They're laid out on their own from the track's shape. Every so often
## there's a row of three right across the road, so wherever you drive you get
## at least one, and a line through the middle or along the curb gets two. The
## rows shift from side to side, so the line that pays best keeps changing.
##
## Studs are personal. Every kart collects each one for itself, so the karts
## ahead can't take them all before you get there. (When they could, whoever
## was last had the fewest gadgets, which is the wrong way around.) What you
## see is your own set. A stud you've picked up disappears for you and comes
## back a few seconds later. A magnet picks them up from much further away.
##
## In split screen each player's set is drawn on its own render layer (see
## layer_of()), and each player's camera leaves out the other one's.

const EVERY := 40.0 # metres between rows
const ACROSS := [-3.0, 0.0, 3.0] # where the three studs in a row sit
const SHIFT := [0.0, -1.5, 1.5] # how the whole row moves across, row by row
const HEIGHT := 0.7
const REACH := 1.8
const MAGNET_REACH := 3.5 # two of the three in a row, not the whole road
const BACK_AFTER := 6.0
## The render layer of the first viewer's studs. The next viewer's is the one
## after it.
const FIRST_LAYER := 11

const SPIN_SHADER := """
shader_type spatial;
uniform vec4 colour : source_color = vec4(0.95, 0.8, 0.2, 1.0);

void vertex() {
	float a = TIME * 3.0 + float(INSTANCE_ID) * 0.7;
	mat3 spin = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
	VERTEX = spin * VERTEX + vec3(0.0, sin(TIME * 2.0 + float(INSTANCE_ID)) * 0.08, 0.0);
	NORMAL = spin * NORMAL;
}

void fragment() {
	ALBEDO = colour.rgb;
	METALLIC = 0.6;
	ROUGHNESS = 0.3;
	EMISSION = colour.rgb * 0.25;
}
"""

static var _shader: Shader

var track: TrackPath
var spots: Array[Transform3D] = []
## Whose studs are shown, which is the karts the cameras follow. The rest
## collect theirs unseen. Set this before it's added to the scene.
var viewers: Array[Kart] = []
## For each kart (by instance id), when each stud comes back for it.
var _back_at := {}
var _time := 0.0
## One for each viewer.
var _multis: Array[MultiMesh] = []


func _init(path: TrackPath) -> void:
	track = path


func _ready() -> void:
	var row := 0
	var d := 30.0
	while d < track.length - 20.0:
		var shift: float = SHIFT[row % SHIFT.size()]
		if track.solid_at(d):
			for across in ACROSS:
				var frame := track.frame_at(d)
				frame.origin += frame.basis.y * HEIGHT + frame.basis.x * (across + shift)
				spots.append(frame)
		row += 1
		d += EVERY

	var stud := CylinderMesh.new()
	stud.top_radius = 0.32
	stud.bottom_radius = 0.32
	stud.height = 0.2
	stud.radial_segments = 14
	# It stands on its edge like a coin, so you can see it spinning.
	var turned := ArrayMesh.new()
	var arrays := stud.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var edge := Basis(Vector3.RIGHT, PI * 0.5)
	for i in verts.size():
		verts[i] = edge * verts[i]
		normals[i] = edge * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	turned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if _shader == null:
		_shader = TrackBuilder.shader_for(SPIN_SHADER)
	var material := ShaderMaterial.new()
	material.shader = _shader
	for v in viewers.size():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = turned
		multi.instance_count = spots.size()
		for i in spots.size():
			multi.set_instance_transform(i, spots[i])
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		draw.material_override = material
		if viewers.size() > 1:
			draw.layers = 1 << (layer_of(v) - 1)
		add_child(draw)
		_multis.append(multi)


## The render layer (counting from 1) that this viewer's studs are drawn on.
static func layer_of(viewer_index: int) -> int:
	return FIRST_LAYER + viewer_index


## Hands this kart any studs it's driving through, and says how many.
func collect(kart: Kart) -> int:
	var back := _times_for(kart)
	var reach := MAGNET_REACH if kart.has_gadget("magnet") else REACH
	var middle := kart.global_position + kart.global_basis.y * 0.5
	var got := 0
	for i in spots.size():
		if back[i] > _time:
			continue
		if spots[i].origin.distance_squared_to(middle) < reach * reach:
			back[i] = _time + BACK_AFTER
			var v := viewers.find(kart)
			if v >= 0:
				_multis[v].set_instance_transform(i, spots[i].scaled_local(Vector3.ONE * 0.001))
			got += 1
	return got


func _times_for(kart: Kart) -> PackedFloat32Array:
	var id := kart.get_instance_id()
	if not _back_at.has(id):
		var times := PackedFloat32Array()
		times.resize(spots.size())
		_back_at[id] = times
	return _back_at[id]


func _physics_process(delta: float) -> void:
	_time += delta
	for v in viewers.size():
		var back := _times_for(viewers[v])
		for i in spots.size():
			if back[i] > 0.0 and back[i] <= _time:
				back[i] = 0.0
				_multis[v].set_instance_transform(i, spots[i])
