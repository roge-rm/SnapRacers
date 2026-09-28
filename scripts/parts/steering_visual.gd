class_name SteeringVisual
extends Node3D

## What the driver steers with: a wheel on a column, or handlebars. It turns
## with the kart's steering, and says where the driver's hands go on it so
## they can follow it round.
##
## It sits in its part's box, with the wheel tilted up toward the driver
## behind it (+Z).

## How far the wheel turns at full lock. Any further and the driver's hands
## would have to reach right over the top of it.
const TURN := PI / 3.0
## Hands slide round the rim a little as it turns, so they follow this much
## of its turn. A minifig's arms only swing forward and back, so their hands
## can't go far round a wheel.
const HANDS_FOLLOW := 0.5

var style := "wheel"
## Big, like a minifig's steering wheel, so hands at quarter to three are
## right where a minifig's arms reach.
var radius := 0.16
var _wheel: Node3D
var _base := Basis.IDENTITY
## The wheel's place when it's straight, which grips are worked out from.
var _rest := Transform3D.IDENTITY


func _init(def: Dictionary, extent: Vector3) -> void:
	style = str(def.get("style", "wheel"))
	var colour: Color = def.get("color", Color("#1b1b1b"))
	var bottom := -extent.y * 0.5
	# The wheel reaches back over the seat's edge toward the driver, to where a
	# minifig's hands land when its arms swing forward from sitting in the
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
		# Handlebars no wider than a minifig can hold.
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


## Turns the wheel for this much steering, -1 full left to 1 full right.
func steer(amount: float) -> void:
	_wheel.basis = _base * Basis(Vector3.UP, -amount * TURN)


## Where the hands go for this much steering, in this node's space:
## [left point, right point, left along the rim, right along the rim]. Hands
## sit at quarter to three on a wheel, and on the grips of handlebars, and
## move round with it (sliding a little on a wheel's rim).
func grips(amount: float) -> Array:
	var spin := -amount * TURN * (HANDS_FOLLOW if style == "wheel" else 1.0)
	var out := []
	for angle in [PI, 0.0]:
		var a: float = angle + spin
		# From the wheel's straight position: the turn is already in `a`.
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
