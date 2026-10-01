class_name KartMesh
extends RefCounted

## Bakes a kart's parts into one mesh, so a kart is a draw call or three
## however many parts it has. Phones are slow at drawing lots of little
## things, and a kart can have a hundred parts. Each part keeps its colour in
## the mesh's vertex colours, and there's one surface each for plastic, glass
## and metal.
##
## The parts that move by themselves, the wheels and the steering, stay as
## they are.

static var _materials := {}


## One mesh of all these part looks, which have to be in the same space (the
## kart's) and aren't in the tree yet.
static func bake(looks: Array[Node3D]) -> MeshInstance3D:
	# For each kind of surface: vertices, normals, colours and indices.
	var surfaces := {}
	for look in looks:
		_gather(look, look.transform, surfaces)
	var mesh := ArrayMesh.new()
	for kind in ["plastic", "glass", "metal"]:
		if not surfaces.has(kind):
			continue
		var s: Array = surfaces[kind]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s[0]
		arrays[Mesh.ARRAY_NORMAL] = s[1]
		arrays[Mesh.ARRAY_COLOR] = s[2]
		arrays[Mesh.ARRAY_INDEX] = s[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(kind))
	var out := MeshInstance3D.new()
	out.mesh = mesh
	return out


## The material for one kind of surface, coloured by the mesh.
static func material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# The colours are the parts' own, which are sRGB like any colour picked.
	m.vertex_color_is_srgb = true
	m.roughness = 0.55
	m.metallic_specular = 0.35
	match kind:
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"metal":
			m.metallic = 0.7
			m.roughness = 0.3
	_materials[kind] = m
	return m


static func _gather(node: Node, where: Transform3D, surfaces: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var mat: Material = node.material_override if node.material_override != null else node.mesh.surface_get_material(i)
			_add(node.mesh.surface_get_arrays(i), where, mat, surfaces)
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		var multi: MultiMesh = node.multimesh
		for k in multi.instance_count:
			for i in multi.mesh.get_surface_count():
				_add(multi.mesh.surface_get_arrays(i), where * multi.get_instance_transform(k), node.material_override, surfaces)
	for child in node.get_children():
		if child is Node3D:
			_gather(child, where * child.transform, surfaces)


static func _add(arrays: Array, where: Transform3D, mat: Material, surfaces: Dictionary) -> void:
	var colour := Color.WHITE
	var kind := "plastic"
	if mat is StandardMaterial3D:
		colour = mat.albedo_color
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			kind = "glass"
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
