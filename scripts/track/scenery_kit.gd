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
##
## Everything added between begin() and done() is one prop, which breaks
## together when a kart hits it (see WorldDamage).
##
## Parts added between begin_mover() and end_mover() move, like a windmill's
## sails or a ferris wheel, and are drawn on their own (see WorldDamage). And
## fan() adds a minifig to watch the race (see Crowd).

enum { BRICK, WINDOWS, SMOOTH, GLOW, WATER, PLAIN }

static var _shader: Shader
static var _material: ShaderMaterial
static var _meshes := {}

## [transform, colour, surface, prop] for each shape, the prop being its
## place in `groups` or -1 for things that never break.
var boxes: Array = []
var cylinders: Array = []
var cones: Array = []
## [transform, size, prop] for the boxes karts can hit.
var solids: Array = []
## The same for soft things like tire stacks, which karts bounce off instead
## of stopping dead against.
var soft: Array = []
## The props that can break, each { name, small, tires }. A small one comes
## down whole, a big one only where it's hit, and tire stacks lose their top
## tires.
var groups: Array = []
var _group := -1
## The moving parts: each { pivot, motion, group, boxes, cylinders, cones },
## with the parts' transforms from the pivot. A motion is one of
## { "spin": axis, "speed": radians a second },
## { "swing": axis, "angle": radians, "rate": radians a second } or
## { "bob": distance, "rate": radians a second }, about the pivot's own axes.
var movers: Array = []
var _mover := {}
## The minifigs watching, each [feet, shirt, legs, hair or a cap, crowd],
## the crowd being which bunch of them they're in, so they cheer together.
var fans: Array = []
var _crowd := 0


static func material() -> ShaderMaterial:
	if _material == null:
		_shader = TrackBuilder.shader_for(BrickShaders.BLOCK)
		_material = ShaderMaterial.new()
		_material.shader = _shader
	return _material


## Starts a prop that can break. Everything added until done() is part of it.
func begin(prop: String, small: bool, tires := false) -> void:
	groups.append({ "name": prop, "small": small, "tires": tires })
	_group = groups.size() - 1


func done() -> void:
	_group = -1


## Starts a moving part, turning or bobbing about `pivot`. Everything added
## until end_mover() moves with it, and none of it is solid.
func begin_mover(pivot: Transform3D, motion: Dictionary) -> void:
	_mover = { "pivot": pivot, "motion": motion, "group": _group, "boxes": [], "cylinders": [], "cones": [] }


func end_mover() -> void:
	if not _mover.is_empty():
		movers.append(_mover)
	_mover = {}


## A minifig standing on `feet`, facing its -Z (towards the road), in these
## colours. Fans added together until the next new_crowd() cheer together.
func fan(feet: Transform3D, shirt: Color, legs: Color, hair: Color) -> void:
	fans.append([feet, shirt, legs, hair, _crowd])


func new_crowd() -> void:
	_crowd += 1


## Where a shape goes: into the moving part being built, if there is one.
func _add(kind: String, where: Transform3D, colour: Color, surface: int) -> bool:
	if _mover.is_empty():
		return false
	# Brick patterns are worked out from where they are in the world, so on
	# a moving part they'd slide about. Those are plain plastic instead.
	var plain := PLAIN if surface != GLOW else GLOW
	_mover[kind].append([_mover.pivot.affine_inverse() * where, colour, plain])
	return true


static func mesh_for(kind: String) -> Mesh:
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
	if _add("boxes", where.scaled_local(size), colour, surface):
		return
	boxes.append([where.scaled_local(size), colour, surface, _group])
	if solid:
		solids.append([where, size, _group])


## Something soft karts can hit, `size` big, centred on `where`.
func soft_box(where: Transform3D, size: Vector3) -> void:
	soft.append([where, size, _group])


## A box turned or tipped by `basis`, for roofs, blades and the like. It's
## never solid.
func turned_box(centre: Vector3, size: Vector3, basis: Basis, colour: Color, surface := SMOOTH) -> void:
	if _add("boxes", Transform3D(basis, centre).scaled_local(size), colour, surface):
		return
	boxes.append([Transform3D(basis, centre).scaled_local(size), colour, surface, _group])


func cylinder(bottom: Vector3, radius: float, height: float, colour: Color, surface := BRICK, solid := false) -> void:
	var where := Transform3D(Basis.IDENTITY, bottom + Vector3.UP * height * 0.5)
	if _add("cylinders", where.scaled_local(Vector3(radius * 2.0, height, radius * 2.0)), colour, surface):
		return
	cylinders.append([where.scaled_local(Vector3(radius * 2.0, height, radius * 2.0)), colour, surface, _group])
	if solid:
		solids.append([where, Vector3(radius * 1.6, height, radius * 1.6), _group])


## A cylinder lying along `basis`'s Y, like a wheel or a pipe, centred on
## `centre`.
func turned_cylinder(centre: Vector3, radius: float, length: float, basis: Basis, colour: Color, surface := SMOOTH) -> void:
	if _add("cylinders", Transform3D(basis, centre).scaled_local(Vector3(radius * 2.0, length, radius * 2.0)), colour, surface):
		return
	cylinders.append([Transform3D(basis, centre).scaled_local(Vector3(radius * 2.0, length, radius * 2.0)), colour, surface, _group])


func cone(bottom: Vector3, radius: float, height: float, colour: Color, surface := BRICK) -> void:
	var where := Transform3D(Basis.IDENTITY, bottom + Vector3.UP * height * 0.5)
	if _add("cones", where.scaled_local(Vector3(radius * 2.0, height, radius * 2.0)), colour, surface):
		return
	cones.append([where.scaled_local(Vector3(radius * 2.0, height, radius * 2.0)), colour, surface, _group])


## Adds everything collected so far to `parent`, with the solid parts, all
## ready to break (see WorldDamage).
func build(parent: Node3D) -> WorldDamage:
	var damage := WorldDamage.new(self)
	parent.add_child(damage)
	return damage
