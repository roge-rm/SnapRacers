class_name PartVisuals
extends RefCounted

## Makes the meshes for parts. The kart on the track and the garage both use
## these, so a part always looks the same wherever you see it. They're simple
## shapes for now, standing in until the real brick models exist.

const STUD_RADIUS := 0.075
const STUD_HEIGHT := 0.05

static var _materials: Dictionary = {}
static var _stud_mesh: CylinderMesh


## A part centred on its own origin. Wheels come out with their axle along X.
static func make(def: Dictionary, extent: Vector3) -> Node3D:
	if def.get("kind", "") == "wheel":
		return make_wheel(def)
	if def.get("kind", "") == "steering":
		return SteeringVisual.new(def, extent)
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = extent - Vector3.ONE * 0.004 # a hairline gap so parts read as separate bricks
	mesh.mesh = box
	mesh.material_override = material(def.color)
	root.add_child(mesh)
	if def.kind in ["plate", "brick"]:
		root.add_child(make_studs(extent, def.color))
	return root


static func make_studs(extent: Vector3, color: Color) -> MultiMeshInstance3D:
	var across := roundi(extent.x / Grid.STUD)
	var along := roundi(extent.z / Grid.STUD)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _stud()
	multi.instance_count = across * along
	var corner := Vector3(-extent.x * 0.5 + Grid.STUD * 0.5, extent.y * 0.5 + STUD_HEIGHT * 0.5, -extent.z * 0.5 + Grid.STUD * 0.5)
	var i := 0
	for x in across:
		for z in along:
			multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, corner + Vector3(x * Grid.STUD, 0.0, z * Grid.STUD)))
			i += 1
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material(color)
	return node


static func make_wheel(def: Dictionary) -> Node3D:
	var radius: float = def.get("radius", 0.3)
	var width: float = def.get("width", 0.25)
	var pivot := Node3D.new()
	var tire := MeshInstance3D.new()
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = radius
	tire_mesh.bottom_radius = radius
	tire_mesh.height = width
	tire_mesh.radial_segments = 20
	tire.mesh = tire_mesh
	tire.material_override = material(def.color)
	tire.rotation.z = PI * 0.5
	pivot.add_child(tire)

	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.55
	hub_mesh.bottom_radius = radius * 0.55
	hub_mesh.height = width + 0.02
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.material_override = material(Color("#e0e0e0"))
	hub.rotation.z = PI * 0.5
	pivot.add_child(hub)

	# A bar across the hub so you can see the wheel turning.
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(width + 0.03, radius * 1.1, 0.06)
	bar.mesh = bar_mesh
	bar.material_override = material(Color("#8a8a8a"))
	pivot.add_child(bar)
	return pivot


## The driver, sitting with their bottom at the origin and facing forward.
static func make_driver() -> Node3D:
	var driver := Node3D.new()
	var pieces := [
		# [size, position, colour]
		[Vector3(0.36, 0.14, 0.42), Vector3(0.0, 0.07, -0.12), "#0d69ab"], # legs, sitting
		[Vector3(0.38, 0.34, 0.2), Vector3(0.0, 0.31, 0.02), "#c4281c"], # torso
		[Vector3(0.1, 0.28, 0.12), Vector3(-0.24, 0.3, -0.06), "#c4281c"], # arms
		[Vector3(0.1, 0.28, 0.12), Vector3(0.24, 0.3, -0.06), "#c4281c"],
	]
	for piece in pieces:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = piece[0]
		mesh.mesh = box
		mesh.position = piece[1]
		mesh.material_override = material(Color(piece[2]))
		driver.add_child(mesh)
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.12
	head_mesh.bottom_radius = 0.12
	head_mesh.height = 0.22
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.6, 0.02)
	head.material_override = material(Color("#f2cd37"))
	driver.add_child(head)
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.15
	helmet_mesh.height = 0.2
	helmet_mesh.is_hemisphere = true
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 0.66, 0.02)
	helmet.material_override = material(Color("#ffffff"))
	driver.add_child(helmet)
	return driver


## Makes a part see-through, and red when it can't go where it is. I swap the
## materials instead of drawing a tint on top, because overlays didn't show up
## on the phone.
static func set_ghost(node: Node, fits: bool) -> void:
	_tint(node, func(base: StandardMaterial3D) -> StandardMaterial3D:
		return _variant(base.albedo_color if fits else Color("#ff2a1a"), 0.55))


## Lightens a part to show it's the one picked out.
static func set_highlight(node: Node, on: bool) -> void:
	if not on:
		_tint(node, Callable())
		return
	_tint(node, func(base: StandardMaterial3D) -> StandardMaterial3D:
		return _variant(base.albedo_color.lightened(0.45), 1.0))


## Runs every mesh in a part through `change`, starting from the material it
## was made with each time. An empty Callable puts the originals back.
static func _tint(node: Node, change: Callable) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D and child.material_override is StandardMaterial3D:
			if not child.has_meta("base_material"):
				child.set_meta("base_material", child.material_override)
			var base: StandardMaterial3D = child.get_meta("base_material")
			child.material_override = base if change.is_null() else change.call(base)
		_tint(child, change)


static var _variants: Dictionary = {}

static func _variant(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), alpha]
	if not _variants.has(key):
		var m := material(color).duplicate() as StandardMaterial3D
		m.albedo_color = Color(color, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_variants[key] = m
	return _variants[key]


static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		# Plastic has a soft sheen, not a mirror shine. Flat tops facing the sky
		# looked pale blue when this was glossier.
		m.roughness = 0.55
		m.metallic_specular = 0.35
		_materials[key] = m
	return _materials[key]


static func _stud() -> CylinderMesh:
	if _stud_mesh == null:
		_stud_mesh = CylinderMesh.new()
		_stud_mesh.top_radius = STUD_RADIUS
		_stud_mesh.bottom_radius = STUD_RADIUS
		_stud_mesh.height = STUD_HEIGHT
		_stud_mesh.radial_segments = 10
		_stud_mesh.rings = 1
	return _stud_mesh
