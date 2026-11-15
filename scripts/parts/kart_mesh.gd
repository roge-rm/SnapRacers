class_name KartMesh
extends RefCounted

## Bakes a kart's parts into one mesh, so a kart is a draw call or three
## however many parts it has. Phones are slow at drawing lots of little
## things, and a kart can have a hundred parts. Each part keeps its colour in
## the mesh's vertex colours, and there's one surface each for plastic, glass
## and metal, and one for the lenses of lights, which can shine (see LAMP).
##
## The parts that move by themselves, the wheels and the steering, stay as
## they are.

static var _materials := {}
static var _lamp_shader: Shader

## The lenses of a kart's lights. `on` makes them shine, white or amber ones
## brightly and red tail lights more softly, and `brake` makes the red ones
## shine brightly, day or night.
const LAMP := """
shader_type spatial;
render_mode cull_disabled;
uniform float on = 0.0;
uniform float brake = 0.0;
void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float red = step(0.5, COLOR.r) * (1.0 - step(0.35, COLOR.g));
	ALBEDO = col * 0.7;
	ROUGHNESS = 0.2;
	EMISSION = col * (on * mix(3.0, 1.2, red) + brake * red * 4.0);
}
"""


## One mesh of all these part looks, which have to be in the same space (the
## kart's) and aren't in the tree yet. `spans` gets, for each look in order,
## where its vertices went as [surface, first, past the last] lists, for
## hide_span().
static func bake(looks: Array[Node3D], spans: Array = []) -> MeshInstance3D:
	# For each kind of surface: vertices, normals, colours and indices.
	var surfaces := {}
	var found := []
	for look in looks:
		var before := {}
		for kind in surfaces:
			before[kind] = surfaces[kind][0].size()
		_gather(look, look.transform, surfaces)
		var span := {}
		for kind in surfaces:
			var first: int = before.get(kind, 0)
			if surfaces[kind][0].size() > first:
				span[kind] = Vector2i(first, surfaces[kind][0].size())
		found.append(span)
	var mesh := ArrayMesh.new()
	var surface_of := {}
	for kind in ["plastic", "glass", "metal", "lamp"]:
		if not surfaces.has(kind):
			continue
		surface_of[kind] = mesh.get_surface_count()
		var s: Array = surfaces[kind]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s[0]
		arrays[Mesh.ARRAY_NORMAL] = s[1]
		arrays[Mesh.ARRAY_COLOR] = s[2]
		arrays[Mesh.ARRAY_INDEX] = s[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(kind))
	spans.clear()
	for span in found:
		var where := []
		for kind in span:
			where.append([surface_of[kind], span[kind].x, span[kind].y])
		spans.append(where)
	var out := MeshInstance3D.new()
	out.mesh = mesh
	return out


## Stops drawing vertices `first` up to `last` of a baked surface, like a part
## knocked off a kart, by moving them all to one point so their triangles
## have no size. It's much quicker than baking the mesh again.
static func hide_span(mesh: ArrayMesh, surface: int, first: int, last: int) -> void:
	var stride := RenderingServer.mesh_surface_get_format_vertex_stride(mesh.surface_get_format(surface), mesh.surface_get_array_len(surface))
	var gone := PackedByteArray()
	gone.resize((last - first) * stride)
	gone.fill(0)
	mesh.surface_update_vertex_region(surface, first * stride, gone)


## The material for one kind of surface, coloured by the mesh. Each kart
## makes its own copy of the lamp one, so its lights go on by themselves.
static func material(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	if kind == "lamp":
		if _lamp_shader == null:
			_lamp_shader = Shader.new()
			_lamp_shader.code = LAMP
		var lamp := ShaderMaterial.new()
		lamp.shader = _lamp_shader
		_materials[kind] = lamp
		return lamp
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# The colours are the parts' own, which are sRGB like any colour picked.
	m.vertex_color_is_srgb = true
	m.roughness = 0.55
	m.metallic_specular = 0.35
	# The cab is the same mesh as the body, so sun shadows on it land on
	# the dash and the wheel. Those stay off.
	m.disable_receive_shadows = true
	match kind:
		"glass":
			# One side only, so a windshield doesn't fill the screen twice
			# and looking out from a cab the glass isn't there.
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_BACK
			m.roughness = 0.12
			m.metallic_specular = 0.6
		"metal":
			m.metallic = 0.7
			m.roughness = 0.3
	_materials[kind] = m
	return m


## A light part's look says so (see PartVisuals.make_turned()), and its
## glass goes in with the lamps.
static func _gather(node: Node, where: Transform3D, surfaces: Dictionary, light := false) -> void:
	light = light or node.has_meta("light")
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var mat: Material = node.material_override if node.material_override != null else node.mesh.surface_get_material(i)
			_add(node.mesh.surface_get_arrays(i), where, mat, surfaces, light)
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		var multi: MultiMesh = node.multimesh
		for k in multi.instance_count:
			for i in multi.mesh.get_surface_count():
				_add(multi.mesh.surface_get_arrays(i), where * multi.get_instance_transform(k), node.material_override, surfaces, light)
	for child in node.get_children():
		if child is Node3D:
			_gather(child, where * child.transform, surfaces, light)


static func _add(arrays: Array, where: Transform3D, mat: Material, surfaces: Dictionary, light := false) -> void:
	var colour := Color.WHITE
	var kind := "plastic"
	if mat is StandardMaterial3D:
		colour = mat.albedo_color
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			kind = "lamp" if light else "glass"
			if kind == "glass":
				colour = PartVisuals.glass_colour(colour)
		elif mat.metallic > 0.3:
			kind = "metal"
	if not surfaces.has(kind):
		surfaces[kind] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array()]
	var s: Array = surfaces[kind]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var start: int = s[0].size()
	var turn := where.basis.inverse().transposed()
	for v in verts.size():
		s[0].append(where * verts[v])
		s[1].append((turn * normals[v]).normalized() if v < normals.size() else Vector3.UP)
		s[2].append(colour)
	if indices.is_empty():
		for v in verts.size():
			s[3].append(start + v)
	else:
		for index in indices:
			s[3].append(start + index)
