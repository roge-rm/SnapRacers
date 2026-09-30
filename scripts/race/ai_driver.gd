class_name AIDriver
extends Node

## Drives a kart around a track.
##
## It aims at a point on the track a little way ahead (further the faster it's
## going) and steers toward it. For speed it looks down the road for bends,
## works out how fast its own kart can take each one from how well it grips,
## and brakes in time to be at that speed when it gets there. If it runs into
## something it backs off it, and if it's still stuck or upside down after a
## couple of seconds it resets, the same as a player would.

## How close to its kart's limit it dares to corner. 1 is right at the limit.
@export var skill := 0.92
## How far right of the middle of the road it likes to drive, in metres.
@export var line := 0.0
## How hard it pushes its engine, as a fraction (see Difficulty).
var pace := 1.0
## The chance of misjudging a bend, going in too fast or too slow (see
## Difficulty).
var mistakes := 0.0
## The chance, each time it comes to a loop, that it loses its nerve on the
## way up, backs off, and falls off it (see Difficulty).
var loop_nerves := 0.0
## How often it uses a gadget when the moment's right, from 0 to 1.
var gadget_sense := 1.0
## How much extra push it gets a long way behind the people racing, and how
## much it lifts off a long way ahead of them.
var catch_up := 0.0
var ease_off := 0.0
## How far behind the leading person in the race it is, in metres. It's
## negative when it's ahead. The race keeps this up to date.
var behind := 0.0

const BRAKING := 8.0 # m/s² it counts on when planning to slow down
const LOOK_NEAR := 7.0
const LOOK_FAR := 26.0
const STUCK_AFTER := 2.5
## Stuck the right way up for this long, it backs off for BACK_FOR before it
## tries again. Only if that doesn't work does it reset.
const BACK_AFTER := 0.8
const BACK_FOR := 1.0
## How far on around the track it has to get before it counts as unstuck.
const FREE_AFTER := 6.0
## How far ahead it looks for a loop, so it has its foot down for the whole
## run in to it.
const LOOP_AHEAD := 40.0
## Before that, how far ahead of a loop it starts cornering like an expert
## (LOOP_SKILL), so it doesn't come to the loop short of speed.
const LOOP_RUN_IN := 90.0
const LOOP_SKILL := 0.95
const SEE_AHEAD := 12.0 # how far ahead it watches for karts in its way
const KART_ROOM := 2.8 # how far to the side a kart has to be to be out of the way

var kart: Kart
var track: TrackPath
## The other karts, so it can get around them.
var others: Array[Kart] = []
## Where the kart is along the track. The race keeps this up to date.
var offset := 0.0
var controls := KartControls.new()

var _stuck := 0.0
var _think := 0.0
var _rng := RandomNumberGenerator.new()
## Whether there's a bend coming up, and how it's misjudging it: 1 is right,
## more is too fast and less is too slow.
var _bend_coming := false
var _misjudge := 1.0
## Whether it's on a loop, and whether it's lost its nerve on this one.
var _on_loop := false
var _lost_nerve := false
## Time left backing away from something it's stuck against.
var _backing := 0.0
## Whether it's backed off already this time it got stuck.
var _backed := false
## Where it was on the track when it got stuck.
var _stuck_at := 0.0

const THINK_EVERY := 0.3 # seconds between looking at its gadgets


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if kart == null or track == null:
		return
	controls.reset = false
	controls.gadget = [false, false]
	var speed := kart.linear_velocity.length()
	_use_gadgets(delta, speed)

	# Steering.
	var look := clampf(5.0 + speed * 0.55, LOOK_NEAR, LOOK_FAR)
	var target := track.point_at(offset + look) + track.right_at(offset + look) * (line + _dodge())
	var up := kart.global_basis.y
	var to_target := target - kart.global_position
	to_target -= up * to_target.dot(up)
	var facing := -kart.global_basis.z
	var angle := facing.signed_angle_to(to_target, up)
	controls.steer = clampf(-angle / kart.full_lock * 1.2, -1.0, 1.0)

	# For speed, find the slowest it needs to be for anything coming up, with
	# room to brake. A driver who can't steer quickly (see KartStats.control)
	# takes every bend a little slower.
	_judge_bends()
	# With a loop coming up it takes the bends before it as well as it can, so
	# it gets there with all the speed it needs, whatever its level.
	var daring := maxf(skill, LOOP_SKILL) if _loop_within(LOOP_RUN_IN) else skill
	var grip := kart.stats.cornering() * KartStats.gravity() * daring * minf(1.0, 0.6 + 0.4 * kart.stats.control) * _misjudge
	var allowed := INF
	# Far enough ahead to stop for any bend from the speed it's doing, and a
	# little more.
	var ahead := 4.0
	var reach := maxf(64.0, speed * speed / (2.0 * BRAKING) + 24.0)
	while ahead <= reach:
		var bend := track.bend_at(offset + ahead)
		if bend > 0.002:
			var corner := sqrt(grip / bend)
			allowed = minf(allowed, sqrt(corner * corner + 2.0 * BRAKING * ahead))
		ahead += 4.0
	# The bend it's in counts too, or it floors it on the way out of a hairpin
	# while it's still turning and runs wide.
	var here := maxf(track.bend_at(offset), track.bend_at(offset + 2.0))
	if here > 0.002:
		allowed = minf(allowed, sqrt(grip / here))

	if _backing > 0.0:
		# Backing off whatever it ran into, steering the other way.
		_backing -= delta
		controls.throttle = 0.0
		controls.brake = 1.0
		controls.steer = -controls.steer
	# Easing off going into a loop or up it is how you fall off the top, so it
	# keeps its foot down until it's back on the flat and brakes for the next
	# bend after that.
	elif _looping():
		controls.throttle = 1.0
		controls.brake = 0.0
		# Once the road really starts to climb is where it loses its nerve if
		# it's going to. It lifts off and dabs the brake and doesn't make the
		# top.
		if _lost_nerve and up.y < 0.7:
			controls.throttle = 0.0
			controls.brake = 0.5
	# In a tight bend it holds its speed down firmly. Out on the road it lets
	# it run a little over before braking.
	elif speed > allowed + (0.4 if here > 0.05 else 1.5):
		controls.throttle = 0.0
		controls.brake = 1.0
	elif speed > allowed:
		controls.throttle = 0.0 if here > 0.05 else 0.2
		controls.brake = 0.0
	else:
		controls.throttle = 1.0
		controls.brake = 0.0

	_stuck_check(delta, speed, up)
	kart.push = pace * Difficulty.push_for(behind, catch_up, ease_off, track.length)
	# A loop needs everything the kart's got, whatever the level.
	if _on_loop and not _lost_nerve:
		kart.push = maxf(kart.push, 1.0)


## Whether it's on the way around a loop, or about to start up one.
func _looping() -> bool:
	var looping := _loop_within(LOOP_AHEAD)
	if looping and not _on_loop:
		_lost_nerve = _rng.randf() < loop_nerves
	_on_loop = looping
	return looping


## Whether a loop climbs up within this far ahead, or it's already on one.
func _loop_within(distance: float) -> bool:
	var ahead := 0.0
	while ahead <= distance:
		if track.piece_type_at(offset + ahead) == "loop" and track.up_at(offset + ahead).y < 0.9:
			return true
		ahead += 4.0
	return false


## As each bend comes up, it might get it wrong (see `mistakes`). Going in
## too fast it runs wide, and too slow it just loses time.
func _judge_bends() -> void:
	var coming := track.bend_at(offset + 20.0) > 0.05
	if coming and not _bend_coming:
		_misjudge = 1.0
		if _rng.randf() < mistakes:
			_misjudge = 1.18 if _rng.randf() < 0.5 else 0.8
	elif not coming and track.bend_at(offset) < 0.02:
		_misjudge = 1.0
	_bend_coming = coming


## How far to move over to get around a kart close ahead, in metres to the
## right. It goes whichever way is further from the kart and still on the
## road.
func _dodge() -> float:
	var facing := -kart.global_basis.z
	var right := kart.global_basis.x
	var half_road := track.width * 0.5 - 1.5
	var here := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset))
	for other in others:
		# A kart can go mid-race, like when someone online leaves.
		if other == kart or not is_instance_valid(other):
			continue
		var gap := other.global_position - kart.global_position
		var ahead := gap.dot(facing)
		var side := gap.dot(right)
		if ahead > 0.0 and ahead < SEE_AHEAD and absf(side) < KART_ROOM:
			var go_right := side < 0.0
			if here + KART_ROOM > half_road:
				go_right = false
			elif here - KART_ROOM < -half_road:
				go_right = true
			return (KART_ROOM if go_right else -KART_ROOM) * (1.0 - ahead / SEE_AHEAD * 0.5)
	return 0.0


## Every so often it looks at each gadget it can afford and uses it if the
## moment's right. That's a turbo on a straight with no jump coming, the cannon
## at a kart dead ahead, bricks for a kart right behind, a repair once it's
## lost a couple of parts, a shield when someone's close and a spring to hop
## free when it's stuck.
func _use_gadgets(delta: float, speed: float) -> void:
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK_EVERY
	# The ones that depend on the moment come first, so it doesn't spend every
	# stud on the turbo.
	var buttons := kart.buttons()
	var order := range(buttons.size())
	order.sort_custom(func(a, b): return buttons[a][1].get("gadget", "") != "turbo" and buttons[b][1].get("gadget", "") == "turbo")
	for slot in order:
		var kind: String = buttons[slot][1].get("gadget", "")
		if _worth_using(kind, speed):
			# A less canny driver lets the moment pass more often.
			if _rng.randf() > gadget_sense:
				_think = THINK_EVERY * 4.0
			elif kart.can_use(slot):
				controls.gadget[slot] = true
			return


func _worth_using(kind: String, speed: float) -> bool:
	match kind:
		"turbo":
			if speed < 8.0:
				return false
			# Not in a bend, with one coming or before a jump it would fly off.
			# The faster it's going, the further ahead it has to be clear, or
			# it carries the kart wide out of a hairpin.
			var ahead := -4.0
			while ahead <= maxf(40.0, speed * Kart.TURBO_TIME * 1.5 + 15.0):
				if track.bend_at(offset + ahead) > 0.008 or track.piece_type_at(offset + ahead) == "jump":
					return false
				ahead += 4.0
			return true
		"cannon":
			return _nearest(3.0, 28.0, 2.2) != null
		"dropper", "oil":
			return _nearest(-14.0, -2.0, 4.0) != null
		"shield":
			return _nearest(-5.0, 5.0, 4.0) != null
		"repair":
			return kart.lost.size() >= 2
		"spring":
			# A hop gets it free when something's holding it up.
			return speed < 2.0 and not kart.locked
	return false


## The closest other kart between these distances ahead (negative is behind)
## and within this far to either side, or null.
func _nearest(from: float, to: float, side_room: float) -> Kart:
	var facing := -kart.global_basis.z
	var right := kart.global_basis.x
	for other in others:
		# A kart can go mid-race, like when someone online leaves.
		if other == kart or not is_instance_valid(other):
			continue
		var gap := other.global_position - kart.global_position
		var ahead := gap.dot(facing)
		if ahead > from and ahead < to and absf(gap.dot(right)) < side_room:
			return other
	return null


func _stuck_check(delta: float, speed: float, up: Vector3) -> void:
	# It's stuck against something, or on its back. Upside down only counts
	# when it isn't meant to be, so not at the top of a loop. It's free again
	# once it's a little further around the track.
	var upside_down := up.y < 0.3 and not kart.sticking
	if not kart.locked and (speed < 1.5 or upside_down):
		if _stuck == 0.0:
			_stuck_at = offset
		_stuck += delta
	elif _stuck > 0.0 and offset - _stuck_at > FREE_AFTER:
		_stuck = 0.0
		_backed = false
	# The right way up, against a wall or a barrier, it backs off it once,
	# the way a person would.
	if not upside_down and _stuck > BACK_AFTER and not _backed:
		_backed = true
		_backing = BACK_FOR
	if _stuck > STUCK_AFTER:
		_stuck = 0.0
		_backed = false
		_backing = 0.0
		controls.reset = true
