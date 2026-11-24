class_name CharacterRig
extends Node3D

## A driver's model, built from a CharacterDesign, and the thing that poses it.
## It's a brick figure, with a round head with its face printed on, a flat fronted
## torso that's narrower at the shoulders, hips, two leg blocks with feet
## sticking out the front and short arms with C shaped hands. Every piece is
## modelled in tools/characters and listed in data/characters/pieces_made.json.
##
## It's a little cuter than a toy figure, with a bigger head, more rounded
## blocks, shiny plastic and a face with big shiny eyes and rosy cheeks.
##
## The bare figure (hips, legs, torso, neck, arms, hands and the stud on the
## head) is modelled in tools/characters, which writes its numbers to
## data/characters/figure.json; the constants here have to match them. Once
## built, each bone's pieces are baked into one mesh (see CharacterMesh).
##
## It moves the way a brick figure does. The legs only hinge at the hips, so sitting
## they stick straight out in front. The arms are rigid with a fixed bend at
## the elbow and only swing at the shoulder, and the hands twist at the wrist.
## To hold a steering wheel each arm swings to the angle that brings its hand
## closest to the rim.
##
## A lively one (in a race or on the driver screen) blinks, pulls faces, looks
## at karts beside it and cheers when it wins, and standing it fidgets, looks
## around and waves now and then. Pictures stay still. On a podium they can
## also jump up onto a step, clap, sulk, or hold something up in one hand.
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
## How much bigger the head is than a toy figure's, which is most of what makes
## them look cute. Everything on the head is made at toy figure size and grows
## with it.
const HEAD_SCALE := 1.2
## The middle of the head, which grows up from where it sits on the neck.
const HEAD_Y := NECK_Y + 0.015 + HEAD_HEIGHT * 0.5 * HEAD_SCALE
const LEG_X := 0.095
const LEG_LENGTH := 0.3
const FEET_BELOW := LEG_LENGTH

# The arm goes down from the shoulder to the elbow, a little out to follow
# the torso's side, then the forearm bends forward and a little inward, and
# the hand is past the wrist. The wrist is where a straight upper arm with
# the forearm bent by ELBOW_BEND and FOREARM_IN puts it.
const SHOULDER_Y := HIPS_TOP + TORSO_HEIGHT - 0.045
const SHOULDER_OUT := 0.038
const UPPER_ARM := 0.14
const FOREARM := 0.12
const ELBOW_BEND := deg_to_rad(35.0)
const FOREARM_IN := 0.25
const ELBOW_OUT := 0.03
const HAND_SIZE := 0.045
## Where the hands rest, standing and sitting, left then right.
const STANDING_REST: Array[Vector3] = [Vector3(-0.2, 0.2, -0.3), Vector3(0.2, 0.2, -0.3)]
const SEATED_REST: Array[Vector3] = [Vector3(-0.15, 0.19, -0.2), Vector3(0.15, 0.19, -0.2)]
## Astride, how far the legs swing down from straight out in front, and how
## far the upper body leans forward.
const ASTRIDE_LEGS := deg_to_rad(25.0)
const ASTRIDE_LEAN := deg_to_rad(30.0)
## How far the arms can swing out to the sides, astride.
const MOST_SPREAD := deg_to_rad(60.0)
## The bones, each baked into one mesh.
const BONES := ["hips", "legs", "upper", "head", "arm_l", "arm_r", "hand_l", "hand_r"]
## Leaning back further than this (in radians) wears the reclined back piece.
const RECLINED := 0.7
## Holding something up: the left arm goes up and out to the side in a cheer,
## clear of the head, pumping up and down.
const HOLD_SWING := deg_to_rad(155.0)
const HOLD_SPREAD := 0.45
const HOLD_PUMP := 0.14
## The right arm holds it up beside the head: swung up until the forearm
## points a little above level, so the hand's hole stands nearly upright,
## and turned out at the shoulder to keep what's held clear of the head.
## It bobs it up and down by CARRY_PUMP.
const CARRY_SWING := deg_to_rad(68.0)
const CARRY_TURN := deg_to_rad(-62.0)
const CARRY_SPREAD := 0.3
const CARRY_PUMP := 0.08
## How long the arms take to go up.
const RAISE := 0.35
## Clapping: the arms out in front, turning in at the shoulders from open to
## where the hands meet, this many times a second.
const CLAP_SWING := deg_to_rad(80.0)
const CLAP_OPEN := deg_to_rad(12.0)
const CLAP_SHUT := deg_to_rad(27.0)
const CLAP_RATE := 2.6
## Sulking, how far forward the shoulders slump, in radians.
const SULK_SLUMP := 0.22

var design: CharacterDesign
var seated := true
## How far back they lean from the hips, in radians, for a laid back seat.
## Set it before the rig goes into the scene.
var recline := 0.0
var astride := false
## Astride, whether the feet go forward on a chopper's pegs.
var feet_forward := false
## Off leaves every piece its own mesh, for tests that look at the pieces.
var bake := true

var _head: Node3D
## Everything above the hips, which leans back with `recline`.
var _upper: Node3D
## The neck post, on its own node on the upper body so the driver's own first
## person camera can leave it out with the head.
var _neck: Node3D
## The legs, which swing down astride. Otherwise it's the rig itself.
var _legs: Node3D
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
## Standing about on their own, looking around, waving and hopping now and
## then. Off leaves them to whoever's posing them.
var idle := true
var _clap_left := 0.0
var _sulk_left := 0.0
var _slump := 0.0
## How far each arm's turned in at the shoulder, for clapping.
var _turn_in: Array[float] = [0.0, 0.0]
## Arms up holding something, and how far up they've got, 0 to 1, from the
## swing they started at.
var _raised := false
var _raise := 1.0
var _raise_from := [0.0, 0.0]
var _turn_from := [0.0, 0.0]
## What's held in the right hand, its size, and the point on it that's in
## the hand, in its own space.
var _held: Node3D
var _held_scale := Vector3.ONE
var _held_grip := Vector3.ZERO
## A leap from one spot to another (see leap()), with how long it has left
## and takes.
var _leap_left := 0.0
var _leap_time := 0.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO


func _init(character: CharacterDesign, sitting := true) -> void:
	design = character
	seated = sitting


func _ready() -> void:
	# The upper body pivots at the top of the hips. Its children are placed in
	# the rig's own space, as if it weren't leaning.
	_upper = Node3D.new()
	_upper.transform = _upper_at(recline, astride)
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
	# Standing, the arms swing forward so the hands are out in front, clear
	# of the torso.
	var rest := SEATED_REST if seated else STANDING_REST
	grip(rest[0], rest[1], Vector3.FORWARD, Vector3.FORWARD)
	if _upper != null:
		for side in 2:
			_rest_swing[side] = _swing_of(side)


## Where the eyes are, in world space, for a first person camera.
func eye_point() -> Vector3:
	if _head == null:
		return global_position + global_basis.y * HEAD_Y
	return _head.global_position + _head.global_basis.y * 0.02 - _head.global_basis.z * 0.06


## Where the eyes are in the rig's own space with the head straight, worked
## out without building the rig, for a kart deciding what's in the driver's way.
static func rest_eye(lean_back: float, on_bike: bool) -> Vector3:
	return _upper_at(lean_back, on_bike) * (Vector3(0.0, HEAD_Y, 0.0) + Vector3(0.0, 0.02, -0.06) * HEAD_SCALE)


## The upper body's place, pivoting at the top of the hips.
static func _upper_at(lean_back: float, on_bike: bool) -> Transform3D:
	var pivot := Vector3(0.0, HIPS_TOP, 0.0)
	var lean := Basis(Vector3.RIGHT, lean_back - (ASTRIDE_LEAN if on_bike else 0.0))
	return Transform3D(lean, pivot - lean * pivot)


func _apply_head_layer() -> void:
	if _head == null:
		return
	for part in [_head, _neck]:
		for node in part.find_children("*", "VisualInstance3D", true, false):
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
	if not lively or not FacePrint.changes(design.face(), mood):
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


## Claps, arms out in front and the hands meeting, looking happy.
func clap(seconds := 3.0) -> void:
	if not lively:
		return
	_clap_left = seconds
	_sulk_left = 0.0
	feel("happy", seconds)


## Slumps forward with a cross face, shaking the head now and then.
func sulk(seconds := 3.0) -> void:
	if not lively:
		return
	_sulk_left = seconds
	if _clap_left > 0.0:
		_clap_left = 0.0
		_turn_in = [0.0, 0.0]
		rest_hands()
	feel("cross", seconds)


## Jumps from where they are to `to` (in the parent's space) over `seconds`,
## arms swinging up on the way.
func leap(to: Vector3, seconds := 0.6) -> void:
	_leap_from = position
	_leap_to = to
	_leap_time = seconds
	_leap_left = seconds
	_hop_left = 0.0
	if not lively or seconds <= 0.0:
		position = to
		_hop_from = to
		_leap_left = 0.0


## The left arm up and out to the side in a cheer, and the right one up
## beside the head, ready to hold something there. `now` puts them there
## straight away.
func raise_arms(now := false) -> void:
	_raised = true
	_clap_left = 0.0
	if _cheer_left > 0.0:
		position = _hop_from
	_cheer_left = 0.0
	_wave_left = 0.0
	_raise = 1.0 if now or not lively else 0.0
	if _upper != null:
		# From where they are now, turned in for a clap or not.
		for side in 2:
			_raise_from[side] = _swing_of(side)
			_turn_from[side] = _turn_in[side]
	if _raise >= 1.0 and _upper != null:
		_pose_raised(0.0)


## Holds `prop` up in the right hand, by the point `grip` on it (in its own
## space), with its up through the hand's hole and its front the same way as
## theirs. It goes on the upper body, keeping its size, and stays there until
## let_go().
func hold(prop: Node3D, grip: Vector3, now := false) -> void:
	if not _raised:
		raise_arms(now)
	elif now:
		_raise = 1.0
	_held = prop
	_held_grip = grip
	_held_scale = prop.scale
	if prop.get_parent() == null:
		_upper.add_child(prop)
	elif prop.get_parent() != _upper:
		prop.reparent(_upper, false)
	_hop_from = position
	if now:
		_pose_raised(0.0)
	_place_held()
	if lively:
		feel("laugh", INF)


## What's held, or null.
func held() -> Node3D:
	return _held


## Puts down whatever's held, with the arms back down, and hands it back to
## the caller, out of the scene, to keep or free.
func let_go() -> Node3D:
	var was := _held
	if was != null and was.get_parent() == _upper:
		_upper.remove_child(was)
	_held = null
	_raised = false
	_spread = [0.0, 0.0]
	_turn_in = [0.0, 0.0]
	rest_hands()
	return was


## Where a prop held by `grip` (in its own space) and sized by `size` sits in
## the world with the arms all the way up, for bringing it to the hand.
func hold_transform(size: Vector3, grip: Vector3) -> Transform3D:
	var hand := _hand_at(1, CARRY_SWING, Vector3.UP, -CARRY_SPREAD, CARRY_TURN)
	var basis := _upright(hand.basis.z, size)
	return _upper.global_transform * Transform3D(basis, hand.origin - basis * grip)


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
	return _cheer_left > 0.0 or _wave_left > 0.0 or _clap_left > 0.0 or _raised


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
	elif _blink_left > 0.0 and FacePrint.changes(design.face(), "blink"):
		mood = "blink"
	_face.material_override = _face_material(mood)

	# Standing about, they look around, wave now and then and give a little
	# hop.
	if not seated and idle and _cheer_left <= 0.0 and not _raised and _clap_left <= 0.0 and _sulk_left <= 0.0:
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

	var turn := _steer_look + _idle_look * (0.0 if seated or not idle else 1.0)
	if _glancing and seated:
		turn = _glance
	if _wave_left > 0.0:
		turn = 0.0
	if _sulk_left > 0.0:
		# A slow shake of the head now and then.
		turn = sin(_time * 2.2) * 0.35 * maxf(sin(_time * 0.7), 0.0)
	elif _held != null:
		# Looking over at what they're holding up.
		turn = -0.3
	_head.rotation.y = lerpf(_head.rotation.y, turn, 1.0 - exp(-delta * 8.0))

	# Sulking, the shoulders slump forward from the hips.
	_sulk_left -= delta
	var slump := SULK_SLUMP if _sulk_left > 0.0 else 0.0
	if not is_equal_approx(_slump, slump):
		_slump = move_toward(_slump, slump, delta * 0.6)
		_upper.transform = _upper_at(recline - _slump, astride)

	# The arms, when nobody else is posing them. Brick figure arms are too short to
	# reach over the head, so cheering is pumping both fists out in front, and
	# waving is one hand up in front of the shoulder, twisting at the wrist.
	if _raised:
		_raise = minf(_raise + delta / RAISE, 1.0)
		_pose_raised(_time)
		if _held != null and _leap_left <= 0.0:
			position = _hop_from + Vector3.UP * absf(sin(_time * 4.0)) * 0.035
	elif _leap_left > 0.0:
		# Arms swing up as they jump, and back down as they land.
		var up := sin(clampf(1.0 - _leap_left / _leap_time, 0.0, 1.0) * PI)
		for side in 2:
			_set_swing(side, lerpf(_rest_swing[side], PI * 0.55, up), _rest_along[side])
	elif _clap_left > 0.0:
		_clap_left -= delta
		var shut := 0.5 + 0.5 * sin(_time * TAU * CLAP_RATE)
		for side in 2:
			_turn_in[side] = lerpf(CLAP_OPEN, CLAP_SHUT, shut)
			_set_swing(side, CLAP_SWING + sin(_time * 1.3 + side) * 0.05, Vector3.UP)
		if _clap_left <= 0.0:
			_turn_in = [0.0, 0.0]
			rest_hands()
	elif _cheer_left > 0.0:
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
	elif not seated and _sulk_left <= 0.0:
		# A gentle sway of the arms while they stand there.
		for side in 2:
			_set_swing(side, _rest_swing[side] + sin(_time * 1.6 + side * PI) * 0.06, _rest_along[side])

	if _leap_left > 0.0:
		_leap_left -= delta
		var t := clampf(1.0 - _leap_left / _leap_time, 0.0, 1.0)
		# Up first and across after, so the feet clear the edge of what
		# they're jumping onto.
		position = _leap_from.lerp(_leap_to, t * t)
		position.y = lerpf(_leap_from.y, _leap_to.y, sin(t * PI * 0.5)) + sin(t * PI) * 0.25
		if _leap_left <= 0.0:
			position = _leap_to
			_hop_from = position
			if not _raised:
				rest_hands()
	elif _hop_left > 0.0:
		_hop_left -= delta
		position = _hop_from + Vector3.UP * sin(clampf(1.0 - _hop_left / 0.5, 0.0, 1.0) * PI) * 0.05
		if _hop_left <= 0.0:
			position = _hop_from


## The arms up in the hold pose, the left one cheering and the right one
## holding up what's held beside the head, both pumping up and down.
func _pose_raised(time: float) -> void:
	var smooth := _raise * _raise * (3.0 - 2.0 * _raise)
	var beat := 0.5 - 0.5 * cos(time * 4.0) if _held != null and lively else 0.0
	_spread[0] = -HOLD_SPREAD * smooth
	_turn_in[0] = lerpf(_turn_from[0], 0.0, smooth)
	_set_swing(0, lerpf(_raise_from[0], HOLD_SWING - beat * HOLD_PUMP, smooth), Vector3.FORWARD)
	_spread[1] = -CARRY_SPREAD * smooth
	_turn_in[1] = lerpf(_turn_from[1], CARRY_TURN, smooth)
	_set_swing(1, lerpf(_raise_from[1], CARRY_SWING + beat * CARRY_PUMP, smooth), Vector3.UP)
	_place_held()


## What's held, with its grip in the middle of the right hand's hole and its
## up along the hole.
func _place_held() -> void:
	if _held == null or _upper == null:
		return
	var hand := _hand[1].transform
	var basis := _upright(hand.basis.z, _held_scale)
	_held.transform = Transform3D(basis, hand.origin - basis * _held_grip)


## A turn with its up along `up` and its front as near theirs as that
## allows, sized by `size`.
static func _upright(up: Vector3, size: Vector3) -> Basis:
	var y := up.normalized()
	var z := (Vector3.BACK - y * y.z).normalized()
	return Basis(y.cross(z), y, z) * Basis.from_scale(size)


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
	return at + SHOULDER_OUT


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
	var y := (_inward_basis(side, _turn_in[side]) * _spread_basis(side)).inverse() * _arm[side].transform.basis.y
	return atan2(y.z, y.y)


## Swings the arm about its shoulder to `angle`, and twists the hand to hold
## along `along`.
func _set_swing(side: int, angle: float, along: Vector3) -> void:
	_arm[side].transform = Transform3D(_swing_basis(side, angle, _spread[side], _turn_in[side]), shoulder(side))
	_hand[side].transform = _hand_at(side, angle, along, _spread[side], _turn_in[side])


## The hand for a swing, a spread and a turn in, with its hole running along
## what it's holding and the wrist behind.
func _hand_at(side: int, angle: float, along: Vector3, spread: float, turn: float) -> Transform3D:
	var swing := _swing_basis(side, angle, spread, turn)
	var y := -(swing * _forearm_dir(side))
	var z := along - y * along.dot(y)
	if z.length() < 0.01:
		z = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Transform3D(Basis(x, y, z), shoulder(side) + swing * _grip_local[side])


## The arm's turn for a swing, with its spread out to the side and its turn
## in at the shoulder.
func _swing_basis(side: int, angle: float, spread: float, turn: float) -> Basis:
	var out := Basis(Vector3.BACK, spread * (1.0 if side == 1 else -1.0))
	return _inward_basis(side, turn) * out * Basis(Vector3.RIGHT, angle)


func _inward_basis(side: int, turn: float) -> Basis:
	return Basis(Vector3.UP, turn * (1.0 if side == 1 else -1.0))


## Where the hand's grip is, in the upper body's space, for a swing and a
## spread, with no turn in.
func _grip_at(side: int, angle: float, spread: float) -> Vector3:
	var out := Basis(Vector3.BACK, spread * (1.0 if side == 1 else -1.0))
	return shoulder(side) + out * Basis(Vector3.RIGHT, angle) * _grip_local[side]


func _forearm_dir(side: int) -> Vector3:
	return (wrist(side) - elbow(side)).normalized()


## The elbow, in the arm's own space (its origin is the shoulder).
static func elbow(side: int) -> Vector3:
	return Vector3(ELBOW_OUT * (-1.0 if side == 0 else 1.0), -UPPER_ARM, 0.0)


## The wrist, in the arm's own space.
static func wrist(side: int) -> Vector3:
	var sign := -1.0 if side == 0 else 1.0
	var bent := Vector3(-sign * FOREARM_IN, -cos(ELBOW_BEND), -sin(ELBOW_BEND)).normalized()
	return Vector3(0.0, -UPPER_ARM, 0.0) + bent * FOREARM


## Where the arm's middle runs, in the arm's own space: the top of the
## shoulder, the elbow, where the forearm turns in and the end of the
## forearm, the way tools/characters models it.
static func arm_path(side: int) -> PackedVector3Array:
	var sign := -1.0 if side == 0 else 1.0
	var e := elbow(side)
	var w := wrist(side)
	var mid := e + (w - e) * 0.6
	mid.x = e.x
	return PackedVector3Array([Vector3(0.017 * sign, -0.004, 0.0), e, mid, w - (w - e).normalized() * 0.013])


## Where the figure's numbers in data/characters/figure.json don't match the
## rig's, which means the meshes were made for another rig.
static func figure_mismatches() -> Array[String]:
	var mine := {
		"HIPS_TOP": HIPS_TOP, "TORSO_HEIGHT": TORSO_HEIGHT, "TORSO_BOTTOM_WIDTH": TORSO_BOTTOM_WIDTH,
		"TORSO_TAPER": TORSO_TAPER, "TORSO_DEPTH": TORSO_DEPTH, "NECK_Y": NECK_Y, "HEAD_RADIUS": HEAD_RADIUS,
		"HEAD_HEIGHT": HEAD_HEIGHT, "HEAD_SCALE": HEAD_SCALE, "LEG_X": LEG_X, "LEG_LENGTH": LEG_LENGTH,
		"SHOULDER_Y": SHOULDER_Y, "SHOULDER_OUT": SHOULDER_OUT, "UPPER_ARM": UPPER_ARM, "FOREARM": FOREARM,
		"ELBOW_BEND": rad_to_deg(ELBOW_BEND), "FOREARM_IN": FOREARM_IN, "ELBOW_OUT": ELBOW_OUT,
		"HAND_SIZE": HAND_SIZE, "ASTRIDE_LEGS": rad_to_deg(ASTRIDE_LEGS), "ASTRIDE_LEAN": rad_to_deg(ASTRIDE_LEAN),
		"MOST_SPREAD": rad_to_deg(MOST_SPREAD),
	}
	var theirs := CharacterMesh.figure()
	var out: Array[String] = []
	for name in mine:
		if not theirs.has(name) or absf(float(theirs[name]) - mine[name]) > 0.0001:
			out.append("%s: %s here, %s in figure.json" % [name, mine[name], theirs.get(name, "nothing")])
	for name in ["STANDING_REST", "SEATED_REST"]:
		var rest: Array[Vector3] = STANDING_REST if name == "STANDING_REST" else SEATED_REST
		var listed: Array = theirs.get(name, [])
		for side in 2:
			if listed.size() != 2 or Vector3(listed[side][0], listed[side][1], listed[side][2]).distance_to(rest[side]) > 0.0001:
				out.append("%s doesn't match figure.json" % name)
				break
	return out


# Building.

func _build() -> void:
	_legs = self
	if astride:
		# The legs, but not the hips, swing down about the hip.
		var hip := Vector3(0.0, HIPS_TOP * 0.5, 0.0)
		var down := Basis(Vector3.RIGHT, -ASTRIDE_LEGS)
		_legs = Node3D.new()
		_legs.transform = Transform3D(down, hip - down * hip)
		add_child(_legs)
	_neck = Node3D.new()
	_neck.name = "Neck"
	_upper.add_child(_neck)
	_build_head()
	_build_arms()
	var bones := _bones()
	# The back piece has its own shape lying back, so the recline is in the key too.
	var key := "%s %s %s %s %s" % [JSON.stringify(design.to_dict()), seated, astride, feet_forward, back_variant()]
	var baked := CharacterMesh.kept(key) if bake else {}
	if baked.is_empty():
		var pose := leg_pose()
		_wear("legs")
		_wear("legs", pose + "_l")
		_wear("legs", pose + "_r")
		_wear("torso")
		# The neck post the head sits on.
		_add_figure("neck", _neck, {"skin": design.skin()})
		_wear("neck")
		_wear("back", back_variant())
		_dress_head()
		_wear("arms")
		_wear("arms", "arm_r")
		_wear("arms", "hand_l")
		_wear("arms", "hand_r")
		if not bake:
			return
		var skip: Array = bones.values()
		for bone in bones:
			baked[bone] = CharacterMesh.bake(bones[bone], skip)
		CharacterMesh.keep(key, baked)
	for bone in bones:
		if baked.get(bone) != null:
			var node := MeshInstance3D.new()
			node.name = "Baked"
			node.mesh = baked[bone]
			bones[bone].add_child(node)


## The nodes each bone's pieces go on. Without astride the legs are on the
## rig with the hips.
func _bones() -> Dictionary:
	var out := { "hips": self, "upper": _upper, "neck": _neck, "head": _head, "arm_l": _arm[0], "arm_r": _arm[1], "hand_l": _hand[0], "hand_r": _hand[1] }
	if _legs != self:
		out["legs"] = _legs
	return out


## The legs, which swing down astride. Their pieces go on here.
func legs() -> Node3D:
	return _legs


## Adds a piece of the bare figure made in tools/characters to `parent`, with
## a colour for each of its regions. Regions not given aren't added.
func _add_figure(piece: String, parent: Node3D, colours: Dictionary, sitting := false, metallic := 0.0) -> void:
	var regions := CharacterMesh.figure_regions(piece, sitting)
	for region in colours:
		if regions.has(region):
			add(parent, regions[region], colours[region], Vector3.ZERO, Basis.IDENTITY, metallic)


## Adds the style worn in `slot` (see add_style), unless it's "none".
func _wear(slot: String, variant := "", place := Transform3D.IDENTITY) -> void:
	if design.style_of(slot) != "none" and not add_style(slot, variant, place):
		push_warning("No %s made for %s" % [slot, design.style_of(slot)])


## Adds the style worn in `slot` as made in tools/characters, if it's made
## there, on the node for its bone, or its `variant` (like hair's "cut" for
## under a hat, or an arm style's "arm_r" and hands) when it has one, on the
## variant's own bone if it has one, placed by `place` in the bone's space.
## The skin region is in the driver's skin. Returns whether it was.
func add_style(slot: String, variant := "", place := Transform3D.IDENTITY) -> bool:
	var entry := CharacterMesh.style(slot, design.style_of(slot))
	if entry.is_empty():
		return false
	if variant != "" and not entry.has(variant):
		return false
	var shape: Dictionary = entry.get(variant) if variant != "" else entry
	var bones := _bones()
	bones["legs"] = _legs
	var parent: Node3D = bones.get(shape.get("bone", entry.get("bone", "upper")), _upper)
	for region in shape.regions:
		var look := [design.skin(), 0.0] if region == "skin" else CharacterMesh.region_colour(entry, region, design.color_of(slot))
		var node := add(parent, CharacterMesh.mesh(shape.regions[region]), look[0], place.origin, place.basis, look[1])
		if slot in ["hair", "facial_hair"] and look[1] == 0.0:
			node.material_override = hair_mat(look[0])
	return true


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
	# The head itself stays out of the bake, since its face is painted.
	_face = MeshInstance3D.new()
	_face.mesh = MeshKit.rounded_cylinder(HEAD_RADIUS, HEAD_HEIGHT, 0.035, 40)
	_face.material_override = _face_material()
	_face.set_meta("unbaked", true)
	_head.add_child(_face)


## What's on the head: the stud, hair, facial hair and headgear.
## Under a hat that covers the top of the head, hair has a cut version that
## only comes up to the hat's rim. Printed facial hair is on the face (see
## FacePrint), so only the raised kind is added.
func _dress_head() -> void:
	var headgear := design.style_of("headgear")
	var hair := design.style_of("hair")
	var under := hair_under(headgear)
	# The stud on top shows when there's nothing over it.
	if hair == "none" and under == "full":
		_add_figure("stud", _head, {"skin": design.skin()})
	if under != "hidden":
		_wear("hair", "cut" if under == "cut" else "")
	# Long hair's length down the back shows under any headgear, unless
	# something it doesn't fit with is worn.
	var length := length_variant()
	if length != "" and not length_left_off(design):
		_wear("hair", length)
	if not CharacterMesh.style("facial_hair", design.style_of("facial_hair")).is_empty():
		_wear("facial_hair")
	if headgear == "none":
		return
	# Bands worn on the hair are made for each hairdo. Other headgear worn on
	# the hair, like a party hat, is placed to fit it.
	if CharacterMesh.style("headgear", headgear).has("on_" + hair):
		_wear("headgear", "on_" + hair)
	else:
		_wear("headgear", "", headgear_fit(headgear, hair))


## What hair shows under this headgear: "cut", "hidden" or "full". Hats have
## the cut hair under them, helmets and hoods hide it, and what's worn on the
## hair has the full hair.
static func hair_under(headgear: String) -> String:
	return str(CharacterMesh.style("headgear", headgear).get("hair", "full"))


## Which shape of long hair's length down the back the rig wears, made for
## each pose like the back piece, or "" when the hair has none.
func length_variant() -> String:
	var v := back_variant()
	var key := "length" if v == "" else "length_" + v
	return key if CharacterMesh.style("hair", design.style_of("hair")).has(key) else ""


## The pieces this hairdo's length doesn't fit with, as "slot style".
static func length_apart(hair: String) -> Array:
	return CharacterMesh.style("hair", hair).get("apart", [])


## Whether a driver's long hair has its length left off, for a neck piece,
## back piece or headgear it doesn't fit with.
static func length_left_off(who: CharacterDesign) -> bool:
	var apart := length_apart(who.style_of("hair"))
	for slot in ["neck", "back", "headgear"]:
		if apart.has("%s %s" % [slot, who.style_of(slot)]):
			return true
	return false


## Where headgear worn on the hair goes for this hairdo, in the head's space.
static func headgear_fit(headgear: String, hair: String) -> Transform3D:
	var fits: Dictionary = CharacterMesh.style("headgear", headgear).get("fit", {})
	var f: Array = fits.get(hair, fits.get("none", [1.0, 1.0, 0.0, 0.0]))
	return Transform3D(Basis.from_scale(Vector3(f[0], f[1], f[0])), Vector3(0.0, f[2], f[3]))


## Which shape of the legs the rig wears: "standing", "seated", "astride",
## or "forward" astride with the feet on a chopper's pegs.
func leg_pose() -> String:
	if astride:
		return "forward" if feet_forward else "astride"
	return "seated" if seated else "standing"


## Which shape of the back piece the rig wears: its own standing, or the one
## made for sitting, lying back or riding astride.
func back_variant() -> String:
	if astride:
		return "astride"
	if not seated:
		return ""
	return "reclined" if recline > RECLINED else "seated"


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
	return "%s %s %s %s %s" % [str(design.face()), design.skin().to_html(), design.style_of("facial_hair"), design.color_of("facial_hair").to_html(), mood]


func _paint(mood: String) -> Image:
	return FacePrint.paint_image(design.face(), design.skin(), HEAD_RADIUS, HEAD_HEIGHT, design.style_of("facial_hair"), design.color_of("facial_hair"), mood)


static func _new_face_material(image: Image) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.45
	material.metallic_specular = 0.4
	make_toy(material)
	return material


## Starts painting this face in each mood it looks different in, on other
## threads. Only the picture's painted there. It's made into a material back
## on the main thread the first time it's wanted.
func _paint_moods() -> void:
	# The cache only grows while people try on faces, so now and then it's
	# emptied. Rigs that are showing a face keep their own hold on it.
	if _faces.size() > 80:
		_faces.clear()
	var style := design.face()
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
static func _painter(key: String, style: Array, skin: Color, beard: String, beard_colour: Color, mood: String) -> Callable:
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
		_arm.append(arm)
		_hand.append(hand)
		_grip_local.append(wrist(side) + _forearm_dir(side) * HAND_SIZE)


# Materials.

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
		make_toy(m)
		_materials[key] = m
	return _materials[key]


## Plastic for hair, with less sheen, so the top of a dark hairdo keeps
## its colour under the lights.
static func hair_mat(colour: Color) -> StandardMaterial3D:
	var key := "hair %s" % colour.to_html()
	if not _materials.has(key):
		var m := mat(colour).duplicate() as StandardMaterial3D
		make_matte(m)
		_materials[key] = m
	return _materials[key]


## Less sheen and edge glow, for hair seen across its top.
static func make_matte(m: StandardMaterial3D) -> void:
	m.clearcoat_enabled = false
	m.roughness = 0.7
	m.metallic_specular = 0.2
	m.rim_enabled = false
	m.set_meta("matte", true)


## Toy plastic, with a clear shiny coat and a soft glow around the edges.
static func make_toy(m: StandardMaterial3D) -> void:
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
