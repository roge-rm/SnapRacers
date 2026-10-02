class_name PowerupLook
extends RefCounted

## What a power-up box looks like, built from bricks and baked into one mesh
## (see KartMesh), with its foot on the road:
## - "crate": a studded brick crate with a "?" picked out in little plates on
##   every side, on a round turntable, turning slowly;
## - "stud": a giant gold stud standing up like a coin and spinning, half
##   see-through, which is the one the game uses;
## - "bag": a parts bag with bricks showing through, bobbing just off the road.

const LOOKS := ["crate", "stud", "bag"]
## How fast each turns, in radians a second, and how far it bobs up and down.
const SPIN := { "crate": 0.9, "stud": 2.2, "bag": 0.7 }
const BOB := { "crate": 0.0, "stud": 0.12, "bag": 0.1 }
## The "?", from the top row down, as which of three plates across are there.
const QUESTION := ["###", "..#", ".##", "...", ".#."]

static var _meshes := {}


static func mesh(look: String) -> Mesh:
	if not _meshes.has(look):
		var parts: Array[Node3D] = []
		match look:
			"stud":
				_stud(parts)
			"bag":
				_bag(parts)
			_:
				_crate(parts)
		var baked := KartMesh.bake(parts)
		for part in parts:
			part.free()
		_meshes[look] = baked.mesh
		baked.free()
	return _meshes[look]


static func _piece(parts: Array[Node3D], shape: Mesh, at: Vector3, colour: Color, basis := Basis.IDENTITY, finish := "plastic") -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = shape
	piece.transform = Transform3D(basis, at)
	if finish == "see-through":
		# Its own see-through amount, kept in the colour.
		var clear := StandardMaterial3D.new()
		clear.albedo_color = colour
		clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		piece.material_override = clear
	else:
		piece.material_override = PartVisuals.finished(colour, finish)
	parts.append(piece)


static func _crate(parts: Array[Node3D]) -> void:
	var size := Vector3(0.84, 0.66, 0.84)
	var bottom := 0.12
	# The turntable it sits on.
	_piece(parts, MeshKit.rounded_cylinder(0.62, 0.1, 0.03), Vector3(0.0, 0.05, 0.0), Props.LIGHT_GREY)
	var colour := Color("#0d69ab")
	_piece(parts, MeshKit.rounded_box(size, 0.04), Vector3(0.0, bottom + size.y * 0.5, 0.0), colour)
	var studs := PartVisuals.make_studs(size, colour)
	studs.position = Vector3(0.0, bottom + size.y * 0.5, 0.0)
	parts.append(studs)
	# The "?" on each side, in little white plates.
	var dot := 0.1
	var plate := MeshKit.rounded_box(Vector3(dot * 0.92, dot * 0.92, 0.04), 0.012)
	for side in 4:
		var turn := Basis(Vector3.UP, side * PI * 0.5)
		for row in QUESTION.size():
			for column in 3:
				if QUESTION[row][column] != "#":
					continue
				var local := Vector3((column - 1) * dot, bottom + size.y * 0.5 + (2 - row) * dot, size.z * 0.5 + 0.015)
				_piece(parts, plate, turn * local, Color.WHITE, turn)


static func _stud(parts: Array[Node3D]) -> void:
	var middle := Vector3(0.0, 0.95, 0.0)
	var flat := Basis(Vector3.RIGHT, PI * 0.5)
	var gold := Color("#d98a00", 0.5)
	_piece(parts, MeshKit.rounded_cylinder(0.5, 0.2, 0.05, 32), middle, gold, flat, "see-through")
	# A stud on each face, so it's a stud whichever way it's turned.
	for side in [-1.0, 1.0]:
		_piece(parts, MeshKit.rounded_cylinder(0.3, 0.08, 0.025, 24), middle + Vector3(0.0, 0.0, side * 0.13), Color(gold.lightened(0.15), 0.5), flat, "see-through")


static func _bag(parts: Array[Node3D]) -> void:
	var middle := Vector3(0.0, 0.9, 0.0)
	# The bricks inside, a little jumbled, then the bag over them.
	_piece(parts, MeshKit.rounded_box(Vector3(0.42, 0.24, 0.2), 0.02), middle + Vector3(-0.08, -0.18, 0.0), Color("#c4281c"), Basis(Vector3.BACK, 0.3))
	_piece(parts, MeshKit.rounded_box(Vector3(0.2, 0.2, 0.2), 0.02), middle + Vector3(0.14, 0.05, 0.0), Color("#f2cd37"), Basis(Vector3.BACK, -0.4))
	_piece(parts, MeshKit.rounded_box(Vector3(0.36, 0.08, 0.2), 0.015), middle + Vector3(-0.1, 0.16, 0.0), Color("#4b974b"), Basis(Vector3.BACK, 0.15))
	_piece(parts, MeshKit.rounded_box(Vector3(0.8, 0.95, 0.3), 0.12), middle, Color(0.9, 0.95, 1.0, 0.35), Basis.IDENTITY, "glass")
	# The sealed strip along the top.
	_piece(parts, MeshKit.rounded_box(Vector3(0.82, 0.08, 0.06), 0.02), middle + Vector3(0.0, 0.47, 0.0), Color.WHITE)
