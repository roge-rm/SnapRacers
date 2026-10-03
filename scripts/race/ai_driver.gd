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
## Whether it slides round the tightest bends instead of braking for them
## (see Kart.sliding). Only Expert drivers do.
var slides := false
## How tight a bend has to be to slide round it (its curvature, one over its
## radius), and how long it kicks the brake to start the slide, tuned with
## tools/stock-karts/slide_bench.gd. It plans to take a bend it'll slide this
## much faster than it could grip round it. With the turbo at the end of a
## slide it comes out about even with braking: a little quicker on some
## courses, a little slower on Hairpin Hall, where it runs wide.
static var slide_bend := 0.06
static var slide_time := 0.25
static var slide_plan := 1.15
var _slide_left := 0.0
var _slid_this_bend := false
## Which way the bend it's sliding round goes, 1 right and -1 left, or 0.
var _slide_way := 0.0
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
## With a wheel knocked off it can't steer or drive properly, so after this
## long it resets to get it back on, the way a person would, unless it has
## a repair to use.
const WHEEL_GONE_FOR := 1.0
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
## How far to the side another kart has to be to be out of the way, past
## touching. Bikes are narrower, so they get by with less.
const KART_GAP := 0.8
## Pointing further than this from where it's going, it slows down enough
## to turn onto it, though never below TURN_ROUND_SPEED.
const TURN_ROUND_ANGLE := 0.5
const TURN_ROUND_SPEED := 4.0
## How far ahead it watches for a brick wall across the road. A wall can't
## move out of the way, so it starts going round one sooner than a kart.
const SEE_WALL := 45.0
## How much further than touching it keeps from the end of a wall.
const WALL_GAP := 1.2

var kart: Kart
var track: TrackPath
## The other karts, so it can get around them.
var others: Array[Kart] = []
## Where the kart is along the track. The race keeps this up to date.
var offset := 0.0
var controls := KartControls.new()

var _stuck := 0.0
var _think := 0.0
## How long it's held what's on each gadget button, in seconds.
var _held_for: Array[float] = [0.0, 0.0]
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
## How long it's been going with a wheel knocked off.
var _wheel_gone := 0.0
## Where each brick wall is along the track, worked out once since a wall
## doesn't move.
var _wall_offsets := {}

const THINK_EVERY := 0.3 # seconds between looking at its gadgets
## After holding a power-up this long it uses it at the next moment that
## isn't a bad one, so it has room for the next box.
const HOLD_AT_MOST := 12.0


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
	# It doesn't aim past where a corkscrew starts to roll, or it aims up
	# and off to the side of the road it's on and runs into the wall.
	if track.piece_type_at(offset) != "corkscrew":
		var to_roll := 4.0
		while to_roll < look:
			if track.piece_type_at(offset + to_roll) == "corkscrew" and track.up_at(offset + to_roll).y < 0.97:
				look = maxf(to_roll - 2.0, LOOK_NEAR)
				break
			to_roll += 2.0
	var target := track.point_at(offset + look) + track.right_at(offset + look) * (line + _dodge())
	var up := kart.global_basis.y
	var to_target := target - kart.global_position
	to_target -= up * to_target.dot(up)
	var facing := -kart.global_basis.z
	var angle := facing.signed_angle_to(to_target, up)
	# On a corkscrew the point ahead is round the roll from here, and the
	# road takes you round it without steering, so it only edges back toward
	# its line.
	if track.piece_type_at(offset) == "corkscrew":
		var off_line := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset)) - line
		angle = atan(off_line / 20.0)
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
		# A corkscrew swings to the side as it rolls, but it's no bend to
		# slow down for, any more than a loop is.
		var bend := 0.0 if TrackPiece.turns_over(track.piece_type_at(offset + ahead)) else track.bend_at(offset + ahead)
		if bend > 0.002:
			var corner := sqrt(grip * (slide_plan if slides and bend > slide_bend else 1.0) / bend)
			allowed = minf(allowed, sqrt(corner * corner + 2.0 * BRAKING * ahead))
		ahead += 4.0
	# The bend it's in counts too, or it floors it on the way out of a hairpin
	# while it's still turning and runs wide.
	var here := 0.0 if TrackPiece.turns_over(track.piece_type_at(offset)) else maxf(track.bend_at(offset), track.bend_at(offset + 2.0))
	if here > 0.002 and not kart.sliding:
		allowed = minf(allowed, sqrt(grip / here))
	# Pointing well away from where it's going, like after a spin or out on
	# the grass, it slows to what it can turn onto it at, or it goes round
	# in a big circle and away from the road.
	if absf(angle) > TURN_ROUND_ANGLE and not kart.sliding:
		var across := 1.0 if absf(angle) > PI * 0.5 else sin(absf(angle))
		allowed = minf(allowed, maxf(sqrt(grip * to_target.length() / (2.0 * across)), TURN_ROUND_SPEED))

	# The bend coming up next, for sliding into.
	var tight := maxf(here, track.bend_at(offset + speed * 0.3))
	if tight < slide_bend * 0.5 and not kart.sliding:
		_slid_this_bend = false
		_slide_way = 0.0
	if slides and not _slid_this_bend and tight > slide_bend and speed > Kart.SLIDE_SPEED + 3.0 and not _loop_within(LOOP_AHEAD):
		# Into the tightest bends a top driver kicks the tail out and slides
		# round on the gas.
		_slid_this_bend = true
		_slide_left = slide_time
		var ahead_of := track.point_at(offset + 15.0) - track.point_at(offset)
		_slide_way = 1.0 if ahead_of.dot(track.right_at(offset)) > 0.0 else -1.0

	if _slide_left > 0.0:
		# The kick: gas and brake together, steering round.
		_slide_left -= delta
		controls.throttle = 1.0
		controls.brake = 1.0
		controls.steer = _slide_way
	elif kart.sliding and _slide_way != 0.0 and here > slide_bend * 0.4 and _slide_on_line():
		# Holding the slide on the gas, steering harder the tighter the bend
		# and if it's running wide.
		controls.throttle = 1.0
		controls.brake = 0.0
		# Enough to go round the bend at this speed, and more if it's running
		# wide (see Kart._hold_slide).
		var wide := -(kart.global_position - track.point_at(offset)).dot(track.right_at(offset)) * _slide_way
		var slide_grip := kart.stats.cornering() * KartStats.gravity() * Kart.slide_corner
		controls.steer = _slide_way * clampf(speed * speed * maxf(here, track.bend_at(offset + 6.0)) / slide_grip + maxf(wide - 1.5, 0.0) * 0.15 + minf(wide + 1.5, 0.0) * 0.15, 0.25, 1.0)
	elif kart.sliding and _slide_way != 0.0:
		# Out of the hairpin it straightens up, which ends the slide, and
		# drives on.
		controls.throttle = 1.0
		controls.brake = 0.0
		controls.steer = 0.0
	elif _backing > 0.0:
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


## Whether a slide's still following the road: not turned in past it, or
## cut right across the inside.
func _slide_on_line() -> bool:
	var road := track.point_at(offset + 6.0) - track.point_at(offset)
	var flat := kart.linear_velocity - kart.global_basis.y * kart.linear_velocity.dot(kart.global_basis.y)
	if road.length() < 0.1 or flat.length() < 1.0:
		return false
	# Going round to the right, the way it's going turned in past the road is
	# negative.
	var turned_in := -road.signed_angle_to(flat, kart.global_basis.y) * _slide_way
	var inside := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset)) * _slide_way
	return turned_in < deg_to_rad(25.0) and inside < 4.0


## Whether it's on the way around a loop, or about to start up one.
func _looping() -> bool:
	var looping := _loop_within(LOOP_AHEAD)
	if looping and not _on_loop:
		_lost_nerve = _rng.randf() < loop_nerves
	_on_loop = looping
	return looping


## Whether a loop or a corkscrew climbs up within this far ahead, or it's
## already on one.
func _loop_within(distance: float) -> bool:
	var ahead := 0.0
	while ahead <= distance:
		if TrackPiece.turns_over(track.piece_type_at(offset + ahead)) and track.up_at(offset + ahead).y < 0.9:
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
	var wall := _dodge_wall(facing)
	if not is_nan(wall):
		return wall
	for other in others:
		# A kart can go mid-race, like when someone online leaves.
		if other == kart or not is_instance_valid(other):
			continue
		var gap := other.global_position - kart.global_position
		var ahead := gap.dot(facing)
		var side := gap.dot(right)
		var room := (kart.width() + other.width()) * 0.5 + KART_GAP
		if ahead > 0.0 and ahead < SEE_AHEAD and absf(side) < room:
			var go_right := side < 0.0
			if here + room > half_road:
				go_right = false
			elif here - room < -half_road:
				go_right = true
			return (room if go_right else -room) * (1.0 - ahead / SEE_AHEAD * 0.5)
	return 0.0


## How far to move over to get past the end of a brick wall ahead, or NAN
## when there's none in the way. It goes round whichever end has more road
## beyond it.
func _dodge_wall(facing: Vector3) -> float:
	for wall in kart.get_tree().get_nodes_in_group("brick_walls"):
		var ahead: float = (wall.global_position - kart.global_position).dot(facing)
		# It keeps going round until its back end is past it.
		if ahead < -2.0 or ahead > SEE_WALL or not wall.standing():
			continue
		var key: int = wall.get_instance_id()
		if not _wall_offsets.has(key):
			_wall_offsets[key] = track.offset_of(wall.global_position, offset + ahead, 40.0)
		var at: float = _wall_offsets[key]
		var across: float = (wall.global_position - track.point_at(at)).dot(track.right_at(at))
		var room := BrickWall.HALF + kart.width() * 0.5 + WALL_GAP
		if absf(line - across) >= room:
			continue
		var edge := track.width * 0.5 - kart.width() * 0.5 - 0.3
		var want := across + room if across < 0.0 else across - room
		return clampf(want, -edge, edge) - line
	return NAN


## Every so often it looks at the power-ups it's holding and uses one if the
## moment's right. That's a turbo on a straight with no jump coming, the
## cannon at a kart dead ahead, a homing brick or lightning when anyone's
## ahead, bricks or marbles for a kart right behind, a repair once it's lost a
## couple of parts, a shield when someone's close, a ghost to get through a
## kart in the way or free when it's stuck, a tow rope onto a kart ahead on a
## clear bit of road, a brick wall or spikes for a kart close behind, and a
## shockwave in a crowd.
func _use_gadgets(delta: float, speed: float) -> void:
	_think -= delta
	if _think > 0.0:
		return
	for slot in Powerups.HOLD:
		_held_for[slot] = _held_for[slot] + THINK_EVERY - _think if kart.held[slot] != "" else 0.0
	_think = THINK_EVERY
	for slot in Powerups.HOLD:
		var kind := kart.held[slot]
		var waited := _held_for[slot] > HOLD_AT_MOST and not kind.ends_with("turbo")
		# A turbo it's held twice as long goes on anything but a bend or a jump.
		if kind.ends_with("turbo") and _held_for[slot] > HOLD_AT_MOST * 2.0:
			waited = speed > 8.0 and track.bend_at(offset + 10.0) < 0.008 and track.piece_type_at(offset + 30.0) != "jump"
		if kind != "" and (waited or _worth_using(kind, speed)):
			# A less canny driver lets the moment pass more often.
			if _rng.randf() > gadget_sense:
				_think = THINK_EVERY * 4.0
			elif kart.can_use(slot):
				controls.gadget[slot] = true
			return


func _worth_using(kind: String, speed: float) -> bool:
	match kind:
		"turbo", "big_turbo", "triple_turbo":
			if speed < 8.0:
				return false
			# Not in a bend, with one coming or before a jump it would fly off.
			# The faster it's going and the longer the turbo, the further ahead
			# it has to be clear, or it carries the kart wide out of a hairpin.
			var time := Kart.BIG_TURBO_TIME if kind == "big_turbo" else Kart.TURBO_TIME
			var ahead := -4.0
			while ahead <= maxf(40.0, speed * time * 1.5 + 15.0):
				if track.bend_at(offset + ahead) > 0.008 or track.piece_type_at(offset + ahead) == "jump":
					return false
				ahead += 4.0
			return true
		"cannon":
			return _nearest(3.0, 28.0, 2.2) != null
		"homing":
			return _nearest(3.0, 120.0, 40.0) != null
		"lightning":
			return _nearest(3.0, 400.0, 400.0) != null
		"dropper", "marbles":
			return _nearest(-14.0, -2.0, 4.0) != null
		"shield":
			return _nearest(-5.0, 5.0, 4.0) != null
		"repair":
			return kart.lost.size() >= 2 or _lost_a_wheel()
		"ghost":
			return _nearest(2.0, 12.0, 2.5) != null or (speed < 2.0 and not kart.locked)
		"tow":
			if _nearest(10.0, TowRope.REACH, 30.0) == null:
				return false
			# Not into a tight bend, which it would be pulled wide of.
			var ahead := 0.0
			while ahead <= 40.0:
				if track.bend_at(offset + ahead) > 0.02:
					return false
				ahead += 4.0
			return true
		"wall":
			return _nearest(-20.0, -3.0, 6.0) != null
		"spikes":
			return _nearest(-14.0, -2.0, 4.0) != null
		"shockwave":
			return _count_near(6.0) >= 2 or _nearest(-3.0, 3.0, 3.0) != null
	return false


## How many other karts are within this far.
func _count_near(reach: float) -> int:
	return others.filter(func(k): return is_instance_valid(k) and k != kart and k.global_position.distance_to(kart.global_position) < reach).size()


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
	_wheel_gone = _wheel_gone + delta if _lost_a_wheel() and not kart.locked and not kart.held.has("repair") else 0.0
	if _stuck > STUCK_AFTER or _wheel_gone > WHEEL_GONE_FOR:
		_stuck = 0.0
		_wheel_gone = 0.0
		_backed = false
		_backing = 0.0
		controls.reset = true


## Whether any of its wheels have been knocked off.
func _lost_a_wheel() -> bool:
	for i in kart.lost:
		if KartDesign.is_wheel(kart.design.parts[i].id):
			return true
	return false
