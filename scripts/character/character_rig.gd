class_name CharacterRig
extends Node3D

## A driver's model, built from a CharacterDesign, and the thing that poses
## it. It's a minifig. It has a round head with its face printed on, a flat
## fronted torso that's narrower at the shoulders, hips, two leg blocks with
## feet sticking out the front, and short arms with C shaped hands.
##
## It moves the way a minifig does, too. The legs only hinge at the hips, so
## when it sits down they stick straight out in front. The arms are rigid,
## with the minifig's fixed bend at the elbow, and they only swing at the
## shoulder. The hands twist at the wrist. To hold a steering wheel, each arm
## swings to whichever angle brings its hand closest to the rim. When the
## wheel sits where a minifig can reach it, that's right on the rim.
##
## The origin is where the driver sits, in the middle of the bottom of the
## hips. They face -Z. When they're standing, the feet are FEET_BELOW under the
## origin.

const HIPS_TOP := 0.08
const TORSO_HEIGHT := 0.34
const TORSO_Y := HIPS_TOP + TORSO_HEIGHT * 0.5
const TORSO_BOTTOM_WIDTH := 0.4
const TORSO_TAPER := 0.78
const TORSO_DEPTH := 0.2
const NECK_Y := HIPS_TOP + TORSO_HEIGHT + 0.015
const HEAD_RADIUS := 0.12
const HEAD_HEIGHT := 0.2
const HEAD_Y := NECK_Y + 0.015 + HEAD_HEIGHT * 0.5
const LEG_X := 0.095
const LEG_LENGTH := 0.3
const FEET_BELOW := LEG_LENGTH

# The arm goes straight down from the shoulder to the elbow, then the forearm
# bends forward and a little inward, and the hand is past the wrist.
const SHOULDER_Y := HIPS_TOP + TORSO_HEIGHT - 0.045
const UPPER_ARM := 0.14
const FOREARM := 0.12
const ELBOW_BEND := deg_to_rad(35.0)
const FOREARM_IN := 0.25
const HAND_SIZE := 0.045

var design: CharacterDesign
var seated := true

var _head: Node3D
var _arm: Array[Node3D] = []
var _hand: Array[Node3D] = []
## Where each hand's grip sits, in its arm's own unswung space.
var _grip_local: Array[Vector3] = []
var _materials := {}

static var _faces := {}


func _init(character: CharacterDesign, sitting := true) -> void:
	design = character
	seated = sitting


func _ready() -> void:
	_build_hips_and_legs()
	_build_torso()
	_build_head()
	_build_arms()
	rest_hands()


# Posing.

## Puts the hands as near these points (in the rig's own space) as swinging
## the arms allows, gripping along these directions.
func grip(left: Vector3, right: Vector3, left_along := Vector3.BACK, right_along := Vector3.BACK) -> void:
	_swing_arm(0, left, left_along)
	_swing_arm(1, right, right_along)


## Rests the hands on the thighs when sitting, or down by the sides when
## standing.
func rest_hands() -> void:
	if seated:
		grip(Vector3(-0.15, 0.16, -0.2), Vector3(0.15, 0.16, -0.2), Vector3.FORWARD, Vector3.FORWARD)
	else:
		grip(Vector3(-0.2, -0.2, 0.0), Vector3(0.2, -0.2, 0.0), Vector3.FORWARD, Vector3.FORWARD)


## Turns the head a little toward where the kart's going, -1 left to 1 right.
func look(amount: float) -> void:
	if _head != null:
		_head.rotation.y = -clampf(amount, -1.0, 1.0) * 0.35


## Where each hand is holding right now, in the rig's space. Tests use it.
func hand_position(side: int) -> Vector3:
	return _arm[side].transform * _grip_local[side]


func shoulder(side: int) -> Vector3:
	var sign := -1.0 if side == 0 else 1.0
	return Vector3(_shoulder_x() * sign, SHOULDER_Y, 0.0)


func _shoulder_x() -> float:
	var half_top := TORSO_BOTTOM_WIDTH * TORSO_TAPER * 0.5
	var half_bottom := TORSO_BOTTOM_WIDTH * 0.5
	var at := lerpf(half_bottom, half_top, (SHOULDER_Y - HIPS_TOP) / TORSO_HEIGHT)
	return at + 0.038


## Swings the arm about its shoulder, and only that way, to the angle that
## brings the hand closest to the target, then twists the hand to hold along
## the given direction.
func _swing_arm(side: int, target: Vector3, along: Vector3) -> void:
	var pivot := shoulder(side)
	var reach := _grip_local[side]
	var want := target - pivot
	# Swinging about X only moves the hand around in the Y-Z plane.
	var angle := atan2(want.z, want.y) - atan2(reach.z, reach.y)
	var swing := Basis(Vector3.RIGHT, angle)
	_arm[side].transform = Transform3D(swing, pivot)
	# The hand's hole runs along what it's holding, with the wrist behind.
	var wrist_dir := swing * _forearm_dir(side)
	var y := -wrist_dir
	var z := along - y * along.dot(y)
	if z.length() < 0.01:
		z = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	z = z.normalized()
	var x := y.cross(z).normalized()
	var hand_at := pivot + swing * _grip_local[side]
	_hand[side].transform = Transform3D(Basis(x, y, z), hand_at)


func _forearm_dir(side: int) -> Vector3:
	var sign := -1.0 if side == 0 else 1.0
	return Vector3(-sign * FOREARM_IN, -cos(ELBOW_BEND), -sin(ELBOW_BEND)).normalized()


# Building.

func _mat(colour: Color, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s %s" % [colour.to_html(), metallic]
	if not _materials.has(key):
		var m := PartVisuals.material(colour)
		if metallic > 0.0:
			m = m.duplicate() as StandardMaterial3D
			m.metallic = metallic
			m.roughness = 0.3
		_materials[key] = m
	return _materials[key]


func _add(parent: Node3D, mesh: Mesh, colour: Color, at := Vector3.ZERO, turn := Basis.IDENTITY, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(colour, metallic)
	node.transform = Transform3D(turn, at)
	parent.add_child(node)
	return node


## A flat piece of printing on a surface, made as a thin rounded tile.
func _print(parent: Node3D, size: Vector2, colour: Color, at: Vector3, turn := Basis.IDENTITY) -> void:
	_add(parent, MeshKit.rounded_box(Vector3(size.x, size.y, 0.006), 0.003), colour, at, turn)


func _sphere(radius: float, height := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 if height < 0.0 else height
	s.radial_segments = 20
	s.rings = 10
	return s


func _cylinder(top: float, bottom: float, height: float, sides := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


func _build_hips_and_legs() -> void:
	var colour := design.color_of("legs")
	var skin := design.skin()
	var thin := design.has("legs", "thin")
	var bare := design.has("legs", "bare")
	var boots := design.has("legs", "boots")
	var width := 0.13 if thin else 0.17
	var boot := Color("#2a2a2a")
	_add(self, MeshKit.rounded_box(Vector3(0.38, HIPS_TOP, TORSO_DEPTH), 0.015), colour, Vector3(0.0, HIPS_TOP * 0.5, 0.0))
	for sign in [-1.0, 1.0]:
		var x: float = LEG_X * sign
		var foot_size := Vector3(width + (0.02 if boots else 0.0), 0.075 if boots else 0.065, 0.11 if boots else 0.1)
		var foot_colour := boot if boots else colour
		# The leg in two lengths, so shorts and boots can colour them apart.
		var top_share := 0.4 if bare else (0.65 if boots else 1.0)
		var bottom_colour := skin if bare else (boot if boots else colour)
		var length := LEG_LENGTH * top_share
		var rest := LEG_LENGTH - length
		if seated:
			# Straight out in front with the feet up, like a minifig sitting down.
			_add(self, MeshKit.rounded_box(Vector3(width, 0.13, length + 0.01), 0.02), colour, Vector3(x, 0.065, -length * 0.5))
			if rest > 0.0:
				_add(self, MeshKit.rounded_box(Vector3(width * 0.97, 0.125, rest), 0.02), bottom_colour, Vector3(x, 0.065, -length - rest * 0.5))
			_add(self, MeshKit.rounded_box(Vector3(foot_size.x, foot_size.z, foot_size.y), 0.02), foot_colour, Vector3(x, 0.13 + foot_size.z * 0.5 - 0.03, -LEG_LENGTH + foot_size.y * 0.5))
		else:
			# A hairline gap under the hips, like a real minifig's, so the two
			# don't flicker where they meet.
			_add(self, MeshKit.rounded_box(Vector3(width, length - 0.004, 0.13), 0.02), colour, Vector3(x, -length * 0.5 - 0.002, 0.0))
			if rest > 0.0:
				_add(self, MeshKit.rounded_box(Vector3(width * 0.97, rest, 0.125), 0.02), bottom_colour, Vector3(x, -length - rest * 0.5, 0.0))
			_add(self, MeshKit.rounded_box(foot_size, 0.02), foot_colour, Vector3(x, -LEG_LENGTH + foot_size.y * 0.5, -0.065 - foot_size.z * 0.5 + 0.03))


func _build_torso() -> void:
	var colour := design.color_of("torso")
	var style := design.style_of("torso")
	var armour := style == "armour"
	_add(self, MeshKit.rounded_box(Vector3(TORSO_BOTTOM_WIDTH, TORSO_HEIGHT, TORSO_DEPTH), 0.015, TORSO_TAPER), colour, Vector3(0.0, TORSO_Y, 0.0), Basis.IDENTITY, 0.35 if armour else 0.0)
	var front := -TORSO_DEPTH * 0.5 - 0.002
	var light := colour.lightened(0.45)
	var dark := colour.darkened(0.4)
	match style:
		"racing_suit":
			_print(self, Vector2(0.06, TORSO_HEIGHT * 0.9), Color.WHITE, Vector3(-0.06, TORSO_Y, front))
			_add(self, _cylinder(0.04, 0.04, 0.006), Color.WHITE, Vector3(0.075, TORSO_Y + 0.07, front), Basis(Vector3.RIGHT, PI * 0.5))
		"jacket":
			_print(self, Vector2(0.012, TORSO_HEIGHT * 0.88), dark, Vector3(0.0, TORSO_Y - 0.01, front))
			for s in [-1.0, 1.0]:
				_print(self, Vector2(0.08, 0.035), dark, Vector3(0.045 * s, NECK_Y - 0.035, front), Basis(Vector3.BACK, 0.55 * s))
		"overalls":
			_print(self, Vector2(0.2, 0.15), light, Vector3(0.0, TORSO_Y - 0.07, front))
			for s in [-1.0, 1.0]:
				_print(self, Vector2(0.03, 0.2), light, Vector3(0.08 * s, TORSO_Y + 0.07, front))
				_add(self, _cylinder(0.012, 0.012, 0.006, 12), Color("#f2cd37"), Vector3(0.08 * s, TORSO_Y, front - 0.004), Basis(Vector3.RIGHT, PI * 0.5))
		"hoodie":
			_add(self, MeshKit.rounded_box(Vector3(0.24, 0.08, 0.06), 0.03), colour, Vector3(0.0, NECK_Y - 0.01, 0.09))
			_print(self, Vector2(0.2, 0.07), dark, Vector3(0.0, TORSO_Y - 0.1, front))
			for s in [-1.0, 1.0]:
				_print(self, Vector2(0.008, 0.09), Color.WHITE, Vector3(0.03 * s, NECK_Y - 0.06, front))
		"armour":
			_add(self, MeshKit.rounded_box(Vector3(0.3, 0.18, 0.02), 0.015, 0.85), light, Vector3(0.0, TORSO_Y + 0.04, front), Basis.IDENTITY, 0.6)
		"tee":
			_print(self, Vector2(0.1, 0.02), dark, Vector3(0.0, NECK_Y - 0.02, front))
	# The neck post the head sits on.
	_add(self, MeshKit.rounded_cylinder(0.05, 0.03, 0.006, 20), design.skin(), Vector3(0.0, NECK_Y, 0.0))


func _build_head() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0.0, HEAD_Y, 0.0)
	add_child(_head)
	var head := MeshInstance3D.new()
	head.mesh = MeshKit.rounded_cylinder(HEAD_RADIUS, HEAD_HEIGHT, 0.035, 40)
	head.material_override = _face_material()
	_head.add_child(head)
	var gear := design.style_of("headgear")
	if gear in ["none", "ponytail", "headband"]:
		_add(_head, MeshKit.rounded_cylinder(0.06, 0.045, 0.01, 24), design.skin(), Vector3(0.0, HEAD_HEIGHT * 0.5 + 0.018, 0.0))
	_build_headgear()


## The head's material, with its face printed on. Each face is painted once
## for each skin colour and kept.
func _face_material() -> StandardMaterial3D:
	var key := "%s %s" % [design.style_of("head"), design.skin().to_html()]
	if not _faces.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = FacePrint.paint(design.style_of("head"), design.skin(), HEAD_RADIUS, HEAD_HEIGHT)
		material.roughness = 0.45
		material.metallic_specular = 0.4
		_faces[key] = material
	return _faces[key]


func _build_headgear() -> void:
	var colour := design.color_of("headgear")
	var top := HEAD_HEIGHT * 0.5
	var r := HEAD_RADIUS
	match design.style_of("headgear"):
		"racing_helmet":
			_open_helmet_shell(colour, true)
			# A strap under the chin, and a clear visor pushed up on the brow.
			_add(_head, MeshKit.arc_tube(r + 0.004, 0.006, deg_to_rad(205.0), deg_to_rad(335.0)), Color("#1b1b1b"), Vector3(0.0, 0.0, -0.04))
			var visor := _add(_head, MeshKit.rounded_box(Vector3(0.22, 0.035, 0.03), 0.012), Color("#8fd3f4"), Vector3(0.0, 0.085, -r - 0.012), Basis(Vector3.RIGHT, -0.3), 0.3)
			visor.transparency = 0.35
			_add(_head, MeshKit.rounded_box(Vector3(0.035, 0.015, 0.2), 0.007), Color.WHITE, Vector3(0.0, top + 0.05, 0.02))
		"open_helmet":
			_open_helmet_shell(colour, false)
			_goggles(0.075)
		"cap":
			_add(_head, _sphere(r + 0.008, 0.1), colour, Vector3(0.0, top - 0.005, 0.0))
			_add(_head, MeshKit.rounded_box(Vector3(0.17, 0.012, 0.1), 0.005), colour, Vector3(0.0, top - 0.012, -r - 0.03))
			_add(_head, _sphere(0.012), colour.darkened(0.3), Vector3(0.0, top + 0.045, 0.0))
		"beanie":
			_add(_head, _sphere(r + 0.01, 0.16), colour, Vector3(0.0, top - 0.015, 0.0))
			var rim := TorusMesh.new()
			rim.inner_radius = r - 0.004
			rim.outer_radius = r + 0.026
			_add(_head, rim, colour.darkened(0.2), Vector3(0.0, top - 0.045, 0.0))
			_add(_head, _sphere(0.035), Color.WHITE, Vector3(0.0, top + 0.08, 0.0))
		"hard_hat":
			_add(_head, _sphere(r + 0.018, 0.14), colour, Vector3(0.0, top, 0.0))
			_add(_head, MeshKit.rounded_cylinder(r + 0.05, 0.014, 0.006, 32), colour, Vector3(0.0, top - 0.025, -0.01))
			_add(_head, MeshKit.rounded_box(Vector3(0.028, 0.028, 0.22), 0.012), colour.lightened(0.2), Vector3(0.0, top + 0.06, 0.0))
		"spiky_hair":
			_add(_head, _sphere(r + 0.006, 0.08), colour, Vector3(0.0, top - 0.005, 0.01))
			for i in 7:
				var a := -1.2 + i * 0.4
				var spike := _add(_head, _cylinder(0.0, 0.034, 0.11, 8), colour, Vector3(sin(a) * 0.07, top + 0.04, cos(a) * 0.05 + 0.02))
				spike.basis = Basis(Vector3(cos(a), 0.0, -sin(a)), -0.5) * Basis(Vector3.RIGHT, 0.3)
		"ponytail":
			_add(_head, _sphere(r + 0.008, 0.1), colour, Vector3(0.0, top - 0.005, 0.012))
			_add(_head, MeshKit.rounded_box(Vector3(0.22, 0.13, 0.05), 0.025), colour, Vector3(0.0, 0.0, r - 0.012))
			var tail := _add(_head, _cylinder(0.02, 0.04, 0.16, 12), colour, Vector3(0.0, -0.02, r + 0.07))
			tail.basis = Basis(Vector3.RIGHT, -0.5)
		"headband":
			var band := TorusMesh.new()
			band.inner_radius = r - 0.002
			band.outer_radius = r + 0.012
			_add(_head, band, colour, Vector3(0.0, 0.06, 0.0))
			_goggles(0.07)
		"top_hat":
			_add(_head, MeshKit.rounded_cylinder(r + 0.05, 0.014, 0.006, 32), colour, Vector3(0.0, top + 0.005, 0.0))
			_add(_head, MeshKit.rounded_cylinder(0.095, 0.18, 0.01, 28), colour, Vector3(0.0, top + 0.095, 0.0))
			_add(_head, _cylinder(0.097, 0.097, 0.03, 28), Color("#c4281c"), Vector3(0.0, top + 0.03, 0.0))


## A minifig helmet. It's a dome over the top that comes down around the back
## and sides, but it's open at the front so the face shows.
func _open_helmet_shell(colour: Color, deep: bool) -> void:
	var r := HEAD_RADIUS + 0.022
	var top := HEAD_HEIGHT * 0.5
	var dome := PackedVector2Array()
	for i in 9:
		var a := PI * 0.5 * i / 8.0
		dome.append(Vector2(r * cos(a), 0.045 + top * sin(a)))
	var material := _mat(colour).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shell := MeshInstance3D.new()
	shell.mesh = MeshKit.lathe(dome, 40)
	shell.material_override = material
	_head.add_child(shell)
	if deep:
		var sides := PackedVector2Array([Vector2(r - 0.004, -0.075), Vector2(r, -0.03), Vector2(r, 0.05)])
		var guard := MeshInstance3D.new()
		# It goes from just past one cheek around the back to the other, leaving
		# the face clear.
		guard.mesh = MeshKit.lathe(sides, 40, deg_to_rad(62.0), deg_to_rad(298.0))
		guard.material_override = material
		_head.add_child(guard)


func _goggles(height: float) -> void:
	for s in [-1.0, 1.0]:
		var rim := TorusMesh.new()
		rim.inner_radius = 0.022
		rim.outer_radius = 0.033
		_add(_head, rim, Color("#3c3f44"), Vector3(0.036 * s, height, -HEAD_RADIUS - 0.01), Basis(Vector3.RIGHT, PI * 0.5), 0.5)
		var lens := _add(_head, _cylinder(0.023, 0.023, 0.008, 16), Color("#8fd3f4"), Vector3(0.036 * s, height, -HEAD_RADIUS - 0.012), Basis(Vector3.RIGHT, PI * 0.5), 0.4)
		lens.transparency = 0.25


func _build_arms() -> void:
	var colour := design.color_of("arms")
	var skin := design.skin()
	var metal := design.has("arms", "metal")
	var bare := design.has("arms", "bare")
	var gloves := design.has("arms", "gloves")
	var shine := 0.5 if metal else 0.0
	var hand_colour := Color("#3c3f44") if gloves else (colour.lightened(0.15) if metal else skin)
	for side in 2:
		var arm := Node3D.new()
		add_child(arm)
		# The upper arm hangs straight down from the shoulder. Its top tucks
		# into the side of the torso, so there's no joint showing.
		_add(arm, MeshKit.rounded_box(Vector3(0.085, UPPER_ARM + 0.04, 0.09), 0.038), colour, Vector3(0.0, -UPPER_ARM * 0.5 + 0.02, 0.0), Basis.IDENTITY, shine)
		# The forearm carries on from inside the elbow at the fixed bend.
		var dir := _forearm_dir(side)
		var elbow := Vector3(0.0, -UPPER_ARM, 0.0)
		var wrist := elbow + dir * FOREARM
		var fore_colour := skin if bare else colour
		var y := -dir
		var x := (Vector3.RIGHT - y * Vector3.RIGHT.dot(y)).normalized()
		var z := x.cross(y)
		var fore_basis := Basis(x, y, z)
		_add(arm, MeshKit.rounded_box(Vector3(0.08, FOREARM + 0.05, 0.085), 0.036), fore_colour, (elbow + wrist) * 0.5 - dir * 0.015, fore_basis, shine)
		if bare:
			# A short sleeve over the top of the arm, skin below it.
			_add(arm, MeshKit.rounded_box(Vector3(0.092, 0.07, 0.096), 0.035), colour, Vector3(0.0, -0.02, 0.0))
			_add(arm, MeshKit.rounded_box(Vector3(0.082, UPPER_ARM * 0.6, 0.086), 0.036), skin, Vector3(0.0, -UPPER_ARM * 0.7, 0.0))
		# The wrist, and the hand on it, which twists to grip.
		_add(arm, _cylinder(0.022, 0.022, 0.03, 12), hand_colour, wrist + dir * 0.008, fore_basis, shine)
		var hand := Node3D.new()
		add_child(hand)
		_add(hand, MeshKit.hand(HAND_SIZE), hand_colour, Vector3.ZERO, Basis.IDENTITY, shine)
		_arm.append(arm)
		_hand.append(hand)
		_grip_local.append(wrist + dir * HAND_SIZE)
