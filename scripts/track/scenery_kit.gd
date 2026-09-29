class_name SceneryKit
extends RefCounted

## Collects the bricks for everything built around a track (buildings, trees,
## tire stacks, grandstands) and draws them all at once. Every box, cylinder
## and cone goes into one batch per shape, with its colour and the kind of
## surface it has (see BrickShaders.BLOCK), so a track full of scenery is
## still only a handful of draws for the phone.
##
## Boxes can be solid too, so karts bump into them. Only things near the road
## need to be, since a kart that wanders far off is put back anyway.

enum { BRICK, WINDOWS, SMOOTH, GLOW, WATER }

static var _shader: Shader
static var _material: ShaderMaterial
static var _meshes := {}

## [transform, colour, surface] for each shape.
var boxes: Array = []
var cylinders: Array = []
var cones: Array = []
## [transform, size] for the boxes karts can hit.
var solids: Array = []
## The same for soft things like tire stacks, which karts bounce off instead
## of stopping dead against.
var soft: Array = []
static var _bouncy: PhysicsMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_shader = TrackBuilder.shader_for(BrickShaders.BLOCK)
		_material = ShaderMaterial.new()
		_material.shader = _shader
	return _material


static func _mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		match kind:
			"box":
				_meshes[kind] = BoxMesh.new()
			"cylinder":
				var c := CylinderMesh.new()
				c.top_radius = 0.5
				c.bottom_radius = 0.5
				c.height = 1.0
				c.radial_segments = 16
				c.rings = 1
				_meshes[kind] = c
			"cone":
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = 0.5
				c.height = 1.0
				c.radial_segments = 16
				c.rings = 1
				_meshes[kind] = c
	return _meshes[kind]


## A box standing on `bottom` (the middle of its base), lined up with the grid.
func box(bottom: Vector3, size: Vector3, colour: Color, surface := BRICK, solid := true) -> void:
	var where := Transform3D(Basis.IDENTITY, bottom + Vector3.UP * size.y * 0.5)
	boxes.append([where.scaled_local(size), colour, surface])
	if solid:
		solids.append([where, size])


## Something soft karts can hit, `size` big, centred on `where`.
func soft_box(where: Transform3D, size: Vector3) -> void:
	soft.append([where, size])


## A box turned or tipped by `basis`, for roofs, blades and the like. It's
## never solid.
func turned_box(centre: Vector3, size: Vector3, basis: Basis, colour: Color, surface := SMOOTH) -> void:
	boxes.append([Transform3D(basis, centre).scaled_local(size), colour, surface])


func cylinder(bottom: Vector3, radius: float, height: float, colour: Color, surface := BRICK, solid := false) -> void:
	var where := Transform3D(Basis.IDENTITY, bottom + Vector3.UP * height * 0.5)
	cylinders.append([where.scaled_local(Vector3(radius * 2.0, height, radius * 2.0)), colour, surface])
	if solid:
		solids.append([where, Vector3(radius * 1.6, height, radius * 1.6)])


## A cylinder lying along `basis`'s Y, like a wheel or a pipe, centred on
## `centre`.
func turned_cylinder(centre: Vector3, radius: float, length: float, basis: Basis, colour: Color, surface := SMOOTH) -> void:
	cylinders.append([Transform3D(basis, centre).scaled_local(Vector3(radius * 2.0, length, radius * 2.0)), colour, surface])


func cone(bottom: Vector3, radius: float, height: float, colour: Color, surface := BRICK) -> void:
	var where := Transform3D(Basis.IDENTITY, bottom + Vector3.UP * height * 0.5)
	cones.append([where.scaled_local(Vector3(radius * 2.0, height, radius * 2.0)), colour, surface])


## Adds everything collected so far to `parent`, and the solid parts as one
## static body.
func build(parent: Node3D) -> void:
	for kind in ["box", "cylinder", "cone"]:
		var list: Array = boxes if kind == "box" else (cylinders if kind == "cylinder" else cones)
		if list.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = _mesh(kind)
		multi.instance_count = list.size()
		for i in list.size():
			multi.set_instance_transform(i, list[i][0])
			multi.set_instance_color(i, list[i][1])
			multi.set_instance_custom_data(i, Color(float(list[i][2]), 0.0, 0.0, 0.0))
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		draw.material_override = material()
		parent.add_child(draw)
	if not soft.is_empty():
		if _bouncy == null:
			_bouncy = PhysicsMaterial.new()
			_bouncy.bounce = 0.5
			_bouncy.friction = 0.2
		var cushion := StaticBody3D.new()
		# On the hazard layer, which karts hit but their wheels don't ride on,
		# or a kart would climb right up over the stacks.
		cushion.collision_layer = Kart.LAYER_HAZARD
		cushion.physics_material_override = _bouncy
		cushion.set_meta("soft", true)
		parent.add_child(cushion)
		for thing in soft:
			var shape := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = thing[1]
			shape.shape = b
			shape.transform = thing[0]
			cushion.add_child(shape)
	if solids.is_empty():
		return
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	parent.add_child(body)
	for solid in solids:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = solid[1]
		shape.shape = b
		shape.transform = solid[0]
		body.add_child(shape)
