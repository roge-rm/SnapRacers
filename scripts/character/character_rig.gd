class_name CharacterRig
extends Node3D

## A driver's model, built from a CharacterDesign, and the thing that poses it.
## It's a minifig, with a round head with its face printed on, a flat fronted
## torso that's narrower at the shoulders, hips, two leg blocks with feet
## sticking out the front and short arms with C shaped hands. What each piece
## looks like is in scripts/character/looks, one file for each kind.
##
## It's a little cuter than a real minifig, with a bigger head, more rounded
## blocks, shiny plastic and a face with big shiny eyes and rosy cheeks.
##
## It moves the way a minifig does. The legs only hinge at the hips, so sitting
## they stick straight out in front. The arms are rigid with a fixed bend at
## the elbow and only swing at the shoulder, and the hands twist at the wrist.
## To hold a steering wheel each arm swings to the angle that brings its hand
## closest to the rim.
##
## A lively one (in a race or on the driver screen) blinks, pulls faces, looks
## at karts beside it and cheers when it wins, and standing it fidgets, looks
## around and waves now and then. Pictures stay still.
##
## Astride a motorbike's saddle, the legs swing down toward the footpegs
## instead of out in front, the upper body leans forward and the arms swing
## out to the sides as well, to reach wide bars.
##
## The origin is where the driver sits, in the middle of the bottom of the
## hips, and they face -Z. Standing, the feet are FEET_BELOW under the origin.

const HIPS_TOP := 0.08
const TORSO_HEIGHT := 0.34
const TORSO_Y := HIPS_TOP + TORSO_HEIGHT * 0.5
const TORSO_BOTTOM_WIDTH := 0.4
const TORSO_TAPER := 0.78
const TORSO_DEPTH := 0.2
const NECK_Y := HIPS_TOP + TORSO_HEIGHT + 0.015
const HEAD_RADIUS := 0.12
const HEAD_HEIGHT := 0.2
## How much bigger the head is than a minifig's, which is most of what makes
## them look cute. Everything on the head is made at minifig size and grows
## with it.
const HEAD_SCALE := 1.2
## The middle of the head, which grows up from where it sits on the neck.
const HEAD_Y := NECK_Y + 0.015 + HEAD_HEIGHT * 0.5 * HEAD_SCALE
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
## Astride, how far the legs swing down from straight out in front, and how
## far the upper body leans forward.
const ASTRIDE_LEGS := deg_to_rad(25.0)
const ASTRIDE_LEAN := deg_to_rad(30.0)
## How far the arms can swing out to the sides, astride.
const MOST_SPREAD := deg_to_rad(60.0)
## Where domes over the head (hair, helmets and hoods) start, which is where
## the flat top of the head starts to round over, above the eyebrows.
const DOME_BASE := HEAD_HEIGHT * 0.5 - 0.035

var design: CharacterDesign
var seated := true
## How far back they lean from the hips, in radians, for a laid back seat.
## Set it before the rig goes into the scene.
var recline := 0.0
var astride := false

var _head: Node3D
## Everything above the hips, which leans back with `recline`.
var _upper: Node3D
## A grip asked for before the rig was built, to do once it is.
var _early_grip := []
## The render layer (counting from 1) the head and headgear are drawn on, so
## one camera can leave them out. 0 leaves them on the usual layer.
var head_layer := 0:
	set(value):
		head_layer = value
		_apply_head_layer()
var _arm: Array[Node3D] = []
var _hand: Array[Node3D] = []
## How far each arm swings out to the side.
var _spread: Array[float] = [0.0, 0.0]
## Where each hand's grip sits, in its arm's own unswung space.
var _grip_local: Array[Vector3] = []

static var _materials := {}
## Face materials by face, skin, facial hair and mood.
static var _faces := {}
## Faces in a mood being painted on another thread, by the same key, and the
## pictures of them once they're done.
static var _painting := {}
static var _painted := {}
## Faces waiting to be painted one a frame, where there are no threads.
static var _one_at_a_time: Array[Callable] = []
## How many lively rigs are about. When the last one goes, anything still
## being painted is waited for, since Godot crashes on quitting with a task
## that's never been waited for.
static var _lively_count := 0

## Blinking, moods, looking around and (standing) fidgeting. Pictures of
## drivers leave it off. Set it before the rig goes into the scene.
var lively := false
var _face: MeshInstance3D
var _mood := ""
var _mood_left := 0.0
var _blink_in := 0.0
var _blink_left := 0.0
var _rng := RandomNumberGenerator.new()
## Where the head turns, with the steering, toward a kart alongside, or
## (standing) at whatever's caught their eye.
var _steer_look := 0.0
var _glance := 0.0
var _glancing := false
var _idle_look := 0.0
var _idle_look_in := 0.0
## The arms' swing at rest, and what they're doing now.
var _rest_swing := [0.0, 0.0]
var _rest_along := [Vector3.FORWARD, Vector3.FORWARD]
var _cheer_left := 0.0
var _wave_left := 0.0
var _wave_in := 0.0
var _hop_left := 0.0
var _hop_in := 0.0
var _hop_from := Vector3.ZERO
var _time := 0.0


func _init(character: CharacterDesign, sitting := true) -> void:
	design = character
	seated = sitting


func _ready() -> void:
	# The upper body pivots at the top of the hips. Its children are placed in
	# the rig's own space, as if it weren't leaning.
	_upper = Node3D.new()
	var pivot := Vector3(0.0, HIPS_TOP, 0.0)
	var lean := Basis(Vector3.RIGHT, recline - (ASTRIDE_LEAN if astride else 0.0))
	_upper.transform = Transform3D(lean, pivot - lean * pivot)
	add_child(_upper)
	_build()
	_apply_head_layer()
	_rng.randomize()
	_blink_in = _rng.randf_range(1.0, 4.0)
	_wave_in = _rng.randf_range(4.0, 8.0)
	_hop_in = _rng.randf_range(6.0, 12.0)
	_time = _rng.randf() * 10.0
	set_process(lively)
	if lively:
		_lively_count += 1
		_paint_moods()
	if _early_grip.is_empty():
		rest_hands()
	else:
		grip.callv(_early_grip)


# Posing.

## Puts the hands as near these points (in the rig's own space) as swinging
## the arms allows, gripping along these directions.
func grip(left: Vector3, right: Vector3, left_along := Vector3.BACK, right_along := Vector3.BACK) -> void:
	if _upper == null:
		_early_grip = [left, right, left_along, right_along]
		return
	# The arms hang off the leaning upper body, so work in its space.
	var to_upper := _upper.transform.affine_inverse()
	_swing_arm(0, to_upper * left, to_upper.basis * left_along)
	_swing_arm(1, to_upper * right, to_upper.basis * right_along)


## Rests the hands on the thighs when sitting, or down by the sides when
## standing.
func rest_hands() -> void:
	# Standing, the arms swing a little forward so the hands hang just in
	# front of the hips instead of going into them.
	if seated:
		grip(Vector3(-0.15, 0.19, -0.2), Vector3(0.15, 0.19, -0.2), Vector3.FORWARD, Vector3.FORWARD)
	else:
		grip(Vector3(-0.2, -0.1, -0.3), Vector3(0.2, -0.1, -0.3), Vector3.FORWARD, Vector3.FORWARD)
	if _upper != null:
		for side in 2:
			_rest_swing[side] = _swing_of(side)


## Where the eyes are, in world space, for a first person camera.
func eye_point() -> Vector3:
	if _head == null:
		return global_position + global_basis.y * HEAD_Y
	return _head.global_position + _head.global_basis.y * 0.02 - _head.global_basis.z * 0.06


func _apply_head_layer() -> void:
	if _head == null:
		return
	for node in _head.find_children("*", "VisualInstance3D", true, false):
		node.layers = 1 << (head_layer - 1) if head_layer > 0 else 1


## Turns the head a little toward where the kart's going, -1 left to 1 right.
func look(amount: float) -> void:
	_steer_look = -clampf(amount, -1.0, 1.0) * 0.35
	if _head != null and not lively:
		_head.rotation.y = _steer_look


## Looks toward something in the rig's own space, like a kart pulling up
## alongside, or back where the kart's going when it's Vector3.ZERO.
func glance(toward: Vector3) -> void:
	_glancing = toward.length() > 0.01
	if _glancing:
		_glance = clampf(atan2(-toward.x, -toward.z), -1.3, 1.3)


func _exit_tree() -> void:
	if not lively:
		return
	_lively_count -= 1
	if _lively_count <= 0:
		_lively_count = 0
		for key in _painting:
			if _painting[key] != -1:
				WorkerThreadPool.wait_for_task_completion(_painting[key])
		_painting.clear()
		_one_at_a_time.clear()
		_painted.clear()


## Pulls a face for a while, one of FacePrint.MOODS.
func feel(mood: String, seconds := 1.5) -> void:
	if not lively or not FacePrint.changes(design.style_of("head"), mood):
		return
	_mood = mood
	_mood_left = seconds
	_blink_left = 0.0


## Arms up, waving and bouncing in the seat, with a big laugh.
func cheer(seconds := 4.0) -> void:
	if not lively:
		return
	_cheer_left = seconds
	_hop_from = position
	feel("laugh", seconds)


## A happy little hop.
func hop() -> void:
	if lively and _hop_left <= 0.0 and _cheer_left <= 0.0:
		_hop_left = 0.5
		_hop_from = position
		feel("happy", 0.8)


## The lights that go with the toy plastic, for somewhere a driver's shown
## close up. There's a cool light from the other side from the sun and a warm
## one from behind that picks out their edges.
static func add_toy_lights(parent: Node) -> void:
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill.light_color = Color("#cfe0ff")
	fill.light_energy = 0.25
	parent.add_child(fill)
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-25.0, 10.0, 0.0)
	back.light_color = Color("#fff1dc")
	back.light_energy = 0.3
	parent.add_child(back)


## Whether the arms are busy (cheering or waving), so whoever's posing them
## on a steering wheel should leave them be.
func busy_hands() -> bool:
	return _cheer_left > 0.0 or _wave_left > 0.0


func _process(delta: float) -> void:
	_time += delta
	if not _one_at_a_time.is_empty():
		_one_at_a_time.pop_front().call()
	# Blinking every few seconds, unless they're pulling a face.
	_mood_left -= delta
	# A blink that starts now shows for at least a frame, however slow the
	# frames are.
	_blink_left -= delta
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_in = _rng.randf_range(2.0, 5.0)
		_blink_left = 0.13
	var mood := ""
	if _mood_left > 0.0:
		mood = _mood
	elif _blink_left > 0.0 and FacePrint.changes(design.style_of("head"), "blink"):
		mood = "blink"
	_face.material_override = _face_material(mood)

	# Standing about, they look around, wave now and then and give a little
	# hop.
	if not seated and _cheer_left <= 0.0:
		_idle_look_in -= delta
		if _idle_look_in <= 0.0:
			_idle_look_in = _rng.randf_range(1.5, 4.0)
			_idle_look = 0.0 if _rng.randf() < 0.4 else _rng.randf_range(-0.8, 0.8)
		_wave_in -= delta
		if _wave_in <= 0.0 and _hop_left <= 0.0:
			_wave_in = _rng.randf_range(7.0, 12.0)
			_wave_left = 1.6
			feel("happy", 1.6)
		_hop_in -= delta
		if _hop_in <= 0.0 and _wave_left <= 0.0:
			_hop_in = _rng.randf_range(8.0, 14.0)
			hop()

	var turn := _steer_look + _idle_look * (0.0 if seated else 1.0)
	if _glancing and seated:
		turn = _glance
	if _wave_left > 0.0:
		turn = 0.0
	_head.rotation.y = lerpf(_head.rotation.y, turn, 1.0 - exp(-delta * 8.0))

	# The arms, when nobody else is posing them. Minifig arms are too short to
	# reach over the head, so cheering is pumping both fists out in front, and
	# waving is one hand up in front of the shoulder, twisting at the wrist.
	if _cheer_left > 0.0:
		_cheer_left -= delta
		for side in 2:
			_set_swing(side, PI * 0.6 + sin(_time * 9.0 + side * PI) * 0.12, Vector3.UP)
		position = _hop_from + Vector3.UP * absf(sin(_time * 7.0)) * 0.06
		if _cheer_left <= 0.0:
			position = _hop_from
			rest_hands()
	elif _wave_left > 0.0:
		_wave_left -= delta
		_set_swing(0, _rest_swing[0], _rest_along[0])
		_set_swing(1, PI * 0.62 + sin(_time * 5.0) * 0.06, Vector3.UP + Vector3.RIGHT * sin(_time * 11.0) * 1.2)
		if _wave_left <= 0.0:
			rest_hands()
	elif not seated:
		# A gentle sway of the arms while they stand there.
		for side in 2:
			_set_swing(side, _rest_swing[side] + sin(_time * 1.6 + side * PI) * 0.06, _rest_along[side])

	if _hop_left > 0.0:
		_hop_left -= delta
		position = _hop_from + Vector3.UP * sin(clampf(1.0 - _hop_left / 0.5, 0.0, 1.0) * PI) * 0.05
		if _hop_left <= 0.0:
			position = _hop_from


## Where each hand is holding right now, in the rig's space. Tests use it.
func hand_position(side: int) -> Vector3:
	return _upper.transform * (_arm[side].transform * _grip_local[side])


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
	if astride:
		# Out to the side first, as far as it takes to get the hand over the
		# target.
		var out := (absf(target.x) - absf(pivot.x)) / reach.length()
		_spread[side] = clampf(asin(clampf(out, 0.0, 1.0)), 0.0, MOST_SPREAD)
		want = _spread_basis(side).inverse() * want
	# Swinging about X only moves the hand around in the Y-Z plane.
	var angle := atan2(want.z, want.y) - atan2(reach.z, reach.y)
	_set_swing(side, angle, along)


func _spread_basis(side: int) -> Basis:
	return Basis(Vector3.BACK, _spread[side] * (1.0 if side == 1 else -1.0))


## How far the arm is swung now.
func _swing_of(side: int) -> float:
	var y := _spread_basis(side).inverse() * _arm[side].transform.basis.y
	return atan2(y.z, y.y)


## Swings the arm about its shoulder to `angle`, and twists the hand to hold
## along `along`.
func _set_swing(side: int, angle: float, along: Vector3) -> void:
	var pivot := shoulder(side)
	var swing := _spread_basis(side) * Basis(Vector3.RIGHT, angle)
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

func _build() -> void:
	var before := get_child_count()
	LegLooks.build(self)
	if astride:
		# The legs, but not the hips, swing down about the hip.
		var hip := Vector3(0.0, HIPS_TOP * 0.5, 0.0)
		var down := Basis(Vector3.RIGHT, -ASTRIDE_LEGS)
		var legs := Node3D.new()
		legs.transform = Transform3D(down, hip - down * hip)
		var made := get_children().slice(before + 1)
		add_child(legs)
		for node in made:
			node.reparent(legs, false)
	TorsoLooks.build(self)
	# The neck post the head sits on.
	add(_upper, MeshKit.rounded_cylinder(0.05, 0.03, 0.006, 20), design.skin(), Vector3(0.0, NECK_Y, 0.0))
	NeckLooks.build(self)
	BackLooks.build(self)
	_build_head()
	_build_arms()


## The head, which turns to look where the kart's going.
func head() -> Node3D:
	return _head


## Everything above the hips, which leans back in a laid back seat.
func upper() -> Node3D:
	return _upper


func _build_head() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0.0, HEAD_Y, 0.0)
	_head.scale = Vector3.ONE * HEAD_SCALE
	_upper.add_child(_head)
	_face = MeshInstance3D.new()
	_face.mesh = MeshKit.rounded_cylinder(HEAD_RADIUS, HEAD_HEIGHT, 0.035, 40)
	_face.material_override = _face_material()
	_head.add_child(_face)
	var covered := HeadgearLooks.covers_top(design.style_of("headgear"))
	# The stud on top shows when there's nothing over it.
	if design.style_of("hair") == "none" and not covered:
		add(_head, MeshKit.rounded_cylinder(0.06, 0.045, 0.01, 24), design.skin(), Vector3(0.0, HEAD_HEIGHT * 0.5 + 0.018, 0.0))
	HairLooks.build(self, covered)
	HairLooks.build_beard(self)
	HeadgearLooks.build(self)


## The head's material, with the face and any facial hair printed on, in a mood
## or its own look. Each is painted once and kept.
##
## Painting a face takes long enough to hitch a race on a phone, so the moods
## are painted on other threads (see _paint_moods), and until one's ready the
## face stays as it is.
func _face_material(mood := "") -> StandardMaterial3D:
	var key := _face_key(mood)
	if _faces.has(key):
		return _faces[key]
	if mood != "":
		if not _painted.has(key) or not _painting.has(key):
			return _face_material()
		if _painting[key] != -1:
			WorkerThreadPool.wait_for_task_completion(_painting[key])
		_painting.erase(key)
		_faces[key] = _new_face_material(_painted[key])
		_painted.erase(key)
		return _faces[key]
	_faces[key] = _new_face_material(_paint(""))
	return _faces[key]


func _face_key(mood: String) -> String:
	return "%s %s %s %s %s" % [design.style_of("head"), design.skin().to_html(), design.style_of("facial_hair"), design.color_of("facial_hair").to_html(), mood]


func _paint(mood: String) -> Image:
	return FacePrint.paint_image(design.style_of("head"), design.skin(), HEAD_RADIUS, HEAD_HEIGHT, design.style_of("facial_hair"), design.color_of("facial_hair"), mood)


static func _new_face_material(image: Image) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.45
	material.metallic_specular = 0.4
	_make_toy(material)
	return material


## Starts painting this face in each mood it looks different in, on other
## threads. Only the picture's painted there. It's made into a material back
## on the main thread the first time it's wanted.
func _paint_moods() -> void:
	# The cache only grows while people try on faces, so now and then it's
	# emptied. Rigs that are showing a face keep their own hold on it.
	if _faces.size() > 80:
		_faces.clear()
	var style := design.style_of("head")
	for mood in FacePrint.MOODS:
		var key := _face_key(mood)
		if _faces.has(key) or _painting.has(key) or not FacePrint.changes(style, mood):
			continue
		var paint := _painter(key, style, design.skin(), design.style_of("facial_hair"), design.color_of("facial_hair"), mood)
		# With no threads (a web page), a task would run straight away and
		# hold everything up, so the faces are painted one a frame instead.
		if not OS.has_feature("threads") and OS.has_feature("web"):
			_painting[key] = -1
			_one_at_a_time.append(paint)
		else:
			_painting[key] = WorkerThreadPool.add_task(paint, false, "face " + mood)


## What paints one face in a mood on another thread. It's made here, away
## from any rig, so it doesn't matter if the rig's gone by the time it runs.
static func _painter(key: String, style: String, skin: Color, beard: String, beard_colour: Color, mood: String) -> Callable:
	var store := _painted
	return func() -> void:
		var image := FacePrint.paint_image(style, skin, HEAD_RADIUS, HEAD_HEIGHT, beard, beard_colour, mood)
		(func() -> void: store[key] = image).call_deferred()


func _build_arms() -> void:
	for side in 2:
		var arm := Node3D.new()
		_upper.add_child(arm)
		var hand := Node3D.new()
		_upper.add_child(hand)
		var dir := _forearm_dir(side)
		var elbow := Vector3(0.0, -UPPER_ARM, 0.0)
		var wrist := elbow + dir * FOREARM
		ArmLooks.build(self, arm, hand, side, elbow, wrist, dir)
		_arm.append(arm)
		_hand.append(hand)
		_grip_local.append(wrist + dir * HAND_SIZE)


# Helpers the looks are made with.

## The shiny toy plastic the driver's made of, in a colour.
static func mat(colour: Color, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s %s" % [colour.to_html(), metallic]
	if not _materials.has(key):
		var m := PartVisuals.material(Color(colour, 1.0)).duplicate() as StandardMaterial3D
		if metallic > 0.0:
			m.metallic = metallic
			m.roughness = 0.3
		if colour.a < 1.0:
			m.albedo_color = colour
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_make_toy(m)
		_materials[key] = m
	return _materials[key]


## Toy plastic, with a clear shiny coat and a soft glow around the edges.
static func _make_toy(m: StandardMaterial3D) -> void:
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	m.clearcoat_enabled = true
	m.clearcoat = 0.35
	m.clearcoat_roughness = 0.3


## Adds a mesh to `parent` in a colour. A see-through colour makes a
## see-through piece.
func add(parent: Node3D, mesh: Mesh, colour: Color, at := Vector3.ZERO, turn := Basis.IDENTITY, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(colour, metallic)
	node.transform = Transform3D(turn, at)
	parent.add_child(node)
	return node


## A flat piece of printing on a surface, made as a thin rounded tile.
func print_on(parent: Node3D, size: Vector2, colour: Color, at: Vector3, turn := Basis.IDENTITY) -> MeshInstance3D:
	return add(parent, MeshKit.rounded_box(Vector3(size.x, size.y, 0.006), 0.003), colour, at, turn)


## A box with rounded edges. Rounding a thin box pulls its corners out into
## spikes, so thin ones (like bands and straps) are left square.
func box(size: Vector3, round := 0.01) -> Mesh:
	var thinnest := minf(size.x, minf(size.y, size.z))
	if thinnest < 0.02:
		var plain := BoxMesh.new()
		plain.size = size
		return plain
	return MeshKit.rounded_box(size, minf(round, thinnest * 0.3))


func sphere(radius: float, height := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 if height < 0.0 else height
	s.radial_segments = 20
	s.rings = 10
	return s


func cylinder(top: float, bottom: float, height: float, sides := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


func ring(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 10
	return t


## A basis that points +Y along `direction`.
static func pointing(direction: Vector3) -> Basis:
	var y := direction.normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	x = (x - y * x.dot(y)).normalized()
	return Basis(x, y, x.cross(y))


## A shell around the head, `extra` out from it, with a dome over the top
## (unless `dome` is false) and a band that comes down to `bottom` from `from`
## to `to` (radians, 0 at the front, going around toward the right), up to
## `band_top`. Helmets, hoods and hair are made of these.
func shell(colour: Color, extra: float, from: float, to: float, bottom: float, dome := true, band_top := DOME_BASE, metallic := 0.0) -> void:
	var r := HEAD_RADIUS + extra
	var material := mat(colour, metallic).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var meshes := []
	if dome:
		var outline := PackedVector2Array()
		for i in 9:
			var a := PI * 0.5 * i / 8.0
			outline.append(Vector2(r * cos(a), DOME_BASE + dome_height(extra) * sin(a)))
		meshes.append(MeshKit.lathe(outline, 40))
	if bottom < band_top:
		meshes.append(MeshKit.lathe(PackedVector2Array([Vector2(r - 0.004, bottom), Vector2(r, bottom + minf(0.03, band_top - bottom)), Vector2(r, band_top)]), 40, from, to))
	for mesh in meshes:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		_head.add_child(node)


## How far out from the middle of the head a dome made by shell() is at this
## height, for putting things on the front of it.
static func shell_radius(extra: float, height: float) -> float:
	var up := clampf((height - DOME_BASE) / dome_height(extra), 0.0, 1.0)
	return (HEAD_RADIUS + extra) * cos(asin(up))


## How tall a dome made by shell() is, from DOME_BASE to its top.
static func dome_height(extra: float) -> float:
	return 0.08 + extra * 0.5


## Goggles on the front of whatever's `out` from the middle of the head at
## this height (the head, a band or a helmet), sitting on it, not in it.
func goggles(height: float, out: float = HEAD_RADIUS) -> void:
	for s in [-1.0, 1.0]:
		add(_head, ring(0.022, 0.033), Color("#3c3f44"), Vector3(0.036 * s, height, -out - 0.008), Basis(Vector3.RIGHT, PI * 0.5), 0.5)
		add(_head, cylinder(0.023, 0.023, 0.008, 16), Color(Color("#8fd3f4"), 0.75), Vector3(0.036 * s, height, -out - 0.01), Basis(Vector3.RIGHT, PI * 0.5), 0.4)
