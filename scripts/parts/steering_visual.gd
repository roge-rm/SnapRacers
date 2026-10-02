class_name SteeringVisual
extends Node3D

## What the driver steers with, a wheel on a column, handlebars, a yoke (a
## wheel with its top cut off, so it tucks in under a windscreen) or a
## motorbike's bars, which are modelled and turn on their stem. It turns
## with the kart's steering and says where the driver's hands go on it, so they
## can follow it around.
##
## It sits in its part's box, with the wheel tilted up toward the driver behind
## it (+Z).

## How far the wheel turns at full lock. Any further and the driver's hands
## would have to reach right over the top of it.
const TURN := PI / 3.0
## Hands slide around the rim a little as it turns, so they follow this much
## of its turn. A brick figure's arms only swing forward and back, so their hands
## can't go far around a wheel.
const HANDS_FOLLOW := 0.5
## How far a motorbike's bars turn at full lock, the same as the wheels.
const BIKE_TURN := Kart.MAX_STEER

var style := "wheel"
## Big, like a brick figure's steering wheel, so hands at quarter to three are
## right where a brick figure's arms reach.
var radius := 0.16
var _wheel: Node3D
var _base := Basis.IDENTITY
## The wheel's place when it's straight, which grips are worked out from.
var _rest := Transform3D.IDENTITY


func _init(def: Dictionary, extent: Vector3) -> void:
	style = str(def.get("style", "wheel"))
	if def.has("mesh"):
		_bike_bars(def, extent)
		return
	var colour: Color = def.get("color", Color("#1b1b1b"))
	var bottom := -extent.y * 0.5
	# The wheel reaches back over the seat's edge toward the driver, to where a
	# brick figure's hands land when its arms swing forward from sitting in the
	# seat behind.
	var hub := Vector3(0.0, extent.y * 0.5 + 0.015, extent.z * 0.5 + 0.013)
	var foot := Vector3(0.0, bottom + 0.03, -extent.z * 0.3)
	_add(MeshKit.rounded_box(Vector3(0.14, 0.04, 0.16), 0.015), Color("#3c3f44"), Transform3D(Basis.IDENTITY, Vector3(0.0, bottom + 0.02, 0.0)))
	# The column from its foot up to the hub.
	var column := hub - foot
	var up := column.normalized()
	var side := Vector3.RIGHT
	var fwd := side.cross(up).normalized()
	var col := CylinderMesh.new()
	col.top_radius = 0.022
	col.bottom_radius = 0.028
	col.height = column.length()
	col.radial_segments = 12
	_add(col, Color("#9aa0a6"), Transform3D(Basis(side, up, fwd), (foot + hub) * 0.5), 0.6)

	# The wheel faces the driver, tipped back like a real one.
	var facing := Vector3(0.0, 0.75, 1.0).normalized()
	_base = Basis(Vector3.RIGHT, facing, Vector3.RIGHT.cross(facing))
	_wheel = Node3D.new()
	_rest = Transform3D(_base, hub)
	_wheel.transform = _rest
	add_child(_wheel)
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.035
	hub_mesh.bottom_radius = 0.04
	hub_mesh.height = 0.035
	hub_mesh.radial_segments = 16
	_add(hub_mesh, colour, Transform3D.IDENTITY, 0.0, _wheel)
	if style == "bars":
		# Handlebars no wider than a brick figure can hold.
		radius = 0.19
		var bar := CylinderMesh.new()
		bar.top_radius = 0.016
		bar.bottom_radius = 0.016
		bar.height = radius * 2.0
		bar.radial_segments = 10
		_add(bar, Color("#9aa0a6"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), 0.6, _wheel)
		for s in [-1.0, 1.0]:
			var grip := CylinderMesh.new()
			grip.top_radius = 0.024
			grip.bottom_radius = 0.024
			grip.height = 0.09
			grip.radial_segments = 12
			_add(grip, colour, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(radius * s, 0.0, 0.0)), 0.0, _wheel)
	elif style == "yoke":
		# The bottom half of a rim, with a short grip rising from each end.
		radius = 0.15
		_add(MeshKit.arc_tube(radius, 0.018, PI, TAU, 14, 8), colour, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), 0.0, _wheel)
		for s in [-1.0, 1.0]:
			var grip := CylinderMesh.new()
			grip.top_radius = 0.02
			grip.bottom_radius = 0.02
			grip.height = 0.08
			grip.radial_segments = 10
			_add(grip, colour, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(radius * s, 0.0, -0.03)), 0.0, _wheel)
		var bar := MeshKit.rounded_box(Vector3(radius * 1.6, 0.014, 0.03), 0.006)
		_add(bar, Color("#9aa0a6"), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.03)), 0.6, _wheel)
	else:
		var rim := TorusMesh.new()
		rim.inner_radius = radius - 0.016
		rim.outer_radius = radius + 0.016
		rim.rings = 32
		_add(rim, colour, Transform3D.IDENTITY, 0.0, _wheel)
		for a in [0.0, PI, PI * 1.5]:
			var spoke := Vector3(cos(a), 0.0, -sin(a))
			var mesh := MeshKit.rounded_box(Vector3(radius, 0.014, 0.022), 0.006)
			_add(mesh, Color("#9aa0a6"), Transform3D(Basis(Vector3.UP, a), spoke * radius * 0.5), 0.6, _wheel)


## A motorbike's bars, from their model, turning about the stem at the
## front. The bar is swept back toward the rider along the top, with a grip
## at each end.
func _bike_bars(def: Dictionary, extent: Vector3) -> void:
	var stem := Vector3(0.0, 0.0, -extent.z * 0.5 + Grid.STUD * 0.5)
	_wheel = Node3D.new()
	_wheel.position = stem
	add_child(_wheel)
	var model := PartVisuals._modelled(def)
	model.position = -stem
	_wheel.add_child(model)
	radius = def.get("grip_reach", 0.35)
	_rest = Transform3D(Basis.IDENTITY, Vector3(0.0, extent.y * 0.5 - 0.04, extent.z * 0.5 - 0.05) - stem)


## Turns the wheel for this much steering, -1 full left to 1 full right.
func steer(amount: float) -> void:
	if style == "bikebars":
		_wheel.basis = Basis(Vector3.UP, -amount * BIKE_TURN)
		return
	_wheel.basis = _base * Basis(Vector3.UP, -amount * TURN)


## Where the hands go for this much steering, in this node's space, as
## [left point, right point, left along the rim, right along the rim]. Hands
## sit at quarter to three on a wheel and on the grips of handlebars, and they
## move around with it (sliding a little on a wheel's rim).
func grips(amount: float) -> Array:
	if style == "bikebars":
		var turn := Transform3D(Basis(Vector3.UP, -amount * BIKE_TURN), _wheel.position)
		return [turn * (_rest.origin + Vector3(-radius, 0.0, 0.0)), turn * (_rest.origin + Vector3(radius, 0.0, 0.0)), turn.basis * Vector3.LEFT, turn.basis * Vector3.RIGHT]
	var spin := -amount * TURN * (HANDS_FOLLOW if style == "wheel" else 1.0)
	var out := []
	for angle in [PI, 0.0]:
		var a: float = angle + spin
		# Start from the wheel's straight position, since the turn is already
		# in `a`.
		var point := _rest * (Vector3(cos(a), 0.0, -sin(a)) * radius)
		var along := (_rest.basis * Vector3(-sin(a), 0.0, -cos(a))).normalized()
		out.append(point)
		out.append(along)
	return [out[0], out[2], out[1], out[3]]


func _add(mesh: Mesh, colour: Color, where: Transform3D, metallic := 0.0, parent: Node3D = null) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := PartVisuals.material(colour)
	if metallic > 0.0:
		material = material.duplicate() as StandardMaterial3D
		material.metallic = metallic
		material.roughness = 0.3
	node.material_override = material
	node.transform = where
	(parent if parent != null else self).add_child(node)
