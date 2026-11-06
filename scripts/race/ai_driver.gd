class_name AIDriver
extends Node

## Drives a kart around a track.
##
## It aims at a point on the track a little way ahead (further the faster it's
## going) and steers toward it. On a straight it eases the stick, so the
## wheels don't wiggle as the lock shrinks at speed. For speed it looks down
## the road for bends, works out how fast its own kart can take each one from
## how well it grips, and brakes in time to be at that speed when it gets
## there. A kart in its way it goes round, or sits behind until there's a
## gap. If it runs into something, or stops getting anywhere around the
## track, it backs off or pulls away, and if it's still stuck or upside down
## after a couple of seconds it resets, the same as a player would.

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
## How often it notices a useful gadget opportunity.
var gadget_sense := 1.0
var gadget_reaction := 0.25
## Seconds ahead it judges moving targets and threats.
var gadget_planning := 1.5
## How certain a fixed shot must be, from 0 to 1.
var gadget_confidence := 0.75
## Traffic reaction time, prediction horizon and clearance, in seconds and metres.
var traffic_reaction := 0.45
var traffic_planning := 2.0
var traffic_clearance := 0.8
## Zero disables deliberate contact. Otherwise these bound a contested pass.
var traffic_mass_ratio := 0.0
var traffic_contact_closing := 0.0
var traffic_contact_side := 0.0
var traffic_contact_time := 0.0
var traffic_contact_cooldown := 3.0
var traffic := AITrafficPlanner.new()
## Whether it slides round the tightest bends instead of braking for them
## (see Kart.sliding). Only Hard and Expert drivers do.
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
## How much more careful it is in the wet, taken further the slippier it is.
const WET_CARE := 0.8
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
## Getting no more than PROGRESS_STEP metres on around the track in
## PROGRESS_TIME seconds counts as stuck, even if it's moving, like when it's
## scrubbing along another kart or a wall.
const PROGRESS_STEP := 3.0
const PROGRESS_TIME := 2.0
## Further back than this from where it was, in metres, it's been moved, so
## it starts counting again from there.
const MOVED_BACK := 20.0
## After backing off a kart it was stuck against, it drives away from that
## kart's side for this long, in seconds, steering this much.
const PULL_AWAY_FOR := 0.6
const PULL_AWAY_STEER := 0.6
## How many goes it has at getting clear of a kart before it resets.
const KART_TRIES := 2
## How far ahead it looks for a loop, so it has its foot down for the whole
## run in to it.
const LOOP_AHEAD := 40.0
## Before that, how far ahead of a loop it starts cornering like an expert
## (LOOP_SKILL), so it doesn't come to the loop short of speed.
const LOOP_RUN_IN := 90.0
const LOOP_SKILL := 0.95
## A jump needs enough speed out of the bend before its short kicker.
const JUMP_RUN_IN := 40.0
const SEE_AHEAD := 24.0 # how far ahead it watches for karts in its way
## How far to the side another kart has to be to be out of the way, past
## touching. Bikes are narrower, so they get by with less.
const KART_GAP := 0.8
## How quickly it can turn the stick on a straight, in full locks a second.
## In a bend it puts the stick where it wants it.
const STRAIGHT_STEER_RATE := 5.0
## How bent the road can be and still count as a straight for that.
const STRAIGHT_BEND := 0.01
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
var _held_kind: Array[String] = ["", ""]
var _held_uses: Array[int] = [0, 0]
var _held_revision: Array[int] = [-1, -1]
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
## How many times it's tried to get clear this time it got stuck, and
## whether its last go off a kart was forward.
var _tries := 0
var _went_forward := false
## Where it was on the track when it got stuck.
var _stuck_at := 0.0
## Where it was on the track the last time it got PROGRESS_STEP further on,
## and how long ago that was, in seconds.
var _mark := 0.0
var _mark_time := 0.0
## Which side the kart it backed off is on, 1 right, -1 left or 0 for none,
## and how long it has left pulling away from it.
var _away := 0.0
var _recover_from: Kart
var _leaving := 0.0
## How long it's been going with a wheel knocked off.
var _wheel_gone := 0.0
## Where each brick wall is along the track, worked out once since a wall
## doesn't move.
var _wall_offsets := {}
## How far ahead the next loop climbs (INF for none within LOOP_RUN_IN), and
## the physics step that was looked for (see _loop_within()).
var _loop_at := INF
var _loop_looked := -1
var _has_jump := -1
var _jump_run_in := false
## The brick walls in the race, fetched once a step for every driver.
static var _walls: Array = []
static var _walls_frame := -1
## Last steering, so a straight can ease the stick instead of snapping it.
var _steer := 0.0
## The level crossings on the course, and the race clock their trains run
## on (see TrainTimetable), so it can wait for a train or beat it across.
var crossings: Array[LevelCrossing] = []
var clock := 0.0
## For each crossing it's waiting at, the train it's waiting for.
var _train_waits := {}
var _waiting := false
## It starts looking at a crossing this far before it has to stop, past
## what it needs to stop.
const TRAIN_LOOK := 30.0
## It goes over the rails only if it'll be across this long before the train
## gets to the road, or this long after it's gone.
const TRAIN_BEFORE := 1.5
const TRAIN_AFTER := 0.5
## Waiting, it sets off this long before the back of the train is off the
## road, since it takes a moment to get to the rails.
const TRAIN_GO_EARLY := 1.0
## The slowest and quickest it reckons on getting to the rails at.
const TRAIN_SLOWEST := 8.0
const TRAIN_QUICKEST := 30.0
## How far either side of a barrier arm a kart's middle is clear of it, in
## metres, and how long before the arm's solid it wants to be past it, in
## seconds.
const ARM_CLEAR := 2.5
const ARM_BEFORE := 0.3

const THINK_EVERY := 0.3 # seconds between looking at its gadgets
## How far ahead it looks for puddles and snow drifts to go round, or
## SEE_PATCH_TIME seconds ahead at the speed it's going if that's further,
## how often it looks, and the lines across the road it tries, in metres
## from its own, besides hugging either edge. Along each line it looks at
## the water and snow every PATCH_STEP metres.
const SEE_PATCH := 30.0
const SEE_PATCH_TIME := 2.5
const PATCH_EVERY := 0.2
const PATCH_LINES := [0.0, -1.5, 1.5, -3.0, 3.0, -4.5, 4.5, -6.0, 6.0]
const PATCH_STEP := 3.0
## It moves out to a new line at once, but back toward its own line at
## this many metres a second, so it doesn't swerve back.
const PATCH_BACK := 3.0
## What it reckons driving through water costs, in seconds for every metre
## of a wheel's way through water, by depth (1 at the deepest), and what
## moving over to another line and back costs, plus a little for each
## metre over. Already on its way round, the move counts this share.
const WATER_COST := 0.05
const SWERVE_COST := 0.02
const SWERVE_PER_M := 0.075
const SWERVE_HELD := 0.3
## What it reckons driving through snow costs, in seconds: for every metre
## of its way by depth squared (1 at the deepest), and for every time depth
## squared rises from 0 to 1, ploughing into it. Both go by the two sides'
## wheels averaged.
const SNOW_COST := 0.07
const PLOUGH_COST := 1.1
## A kart this far either side of it along the road counts as alongside, and
## three times this ahead as just ahead, in metres.
const PATCH_BESIDE := 4.0
## Going round one it keeps this far in from the road's edge, in metres, so
## it doesn't clip the kerbs and tire stacks.
const PATCH_EDGE := 1.0
var _patch_dodge := 0.0
var _patch_wait := 0.0
var _patch_eased := 0.0
var _patch_staggered := false
var _scan_point := PackedVector3Array()
var _scan_right := PackedVector3Array()
var _scan_frame := -1
var _scan_offset := NAN
var _scan_from := 0.0
## After this long it favours using a safe opportunity over saving the item.
const HOLD_AT_MOST := 12.0
## How often it looks at the bends down the road for braking, in metres, and
## what it saw, kept from step to step.
const BEND_EVERY := 4.0
var _bends := PackedFloat64Array()
## It drives every this many physics steps (see _physics_process()).
const DRIVE_EVERY := 2
var _index := -1
var _steps := 0
var _since_drive := 0.0


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if kart == null or track == null:
		return
	controls.reset = false
	controls.gadget = [false, false]
	var speed := kart.linear_velocity.length()
	_use_gadgets(delta, speed)
	# It steers and works out its speed every other step, holding the
	# controls between, with half the karts on one step and half on the
	# next. With a wheel off the ground, like over a jump and landing, and
	# for getting stuck and resetting, it watches every step.
	if _index < 0 and not others.is_empty():
		_index = maxi(others.find(kart), 0)
	_since_drive += delta
	_steps += 1
	if (_steps + maxi(_index, 0)) % DRIVE_EVERY == 0 or not _all_grounded():
		_drive(_since_drive, speed)
		_since_drive = 0.0
	_stuck_check(delta, speed, kart.global_basis.y)
	kart.push = pace * Difficulty.push_for(behind, catch_up, ease_off, track.length)
	# Loops and jumps need full engine power, whatever the level, so it
	# reaches the top of a loop and clears a jump's landing ramp.
	if (_on_loop and not _lost_nerve) or _jump_run_in:
		kart.push = maxf(kart.push, 1.0)


## Whether every wheel is on the ground.
func _all_grounded() -> bool:
	for wheel in kart.wheels:
		if not wheel.grounded:
			return false
	return true


## Steers and works out how fast to go. `delta` is the time since it last did.
func _drive(delta: float, speed: float) -> void:
	# Steering.
	var look := clampf(5.0 + speed * 0.55, LOOK_NEAR, LOOK_FAR)
	# It doesn't aim past where a corkscrew starts to roll, or it aims up
	# and off to the side of the road it's on and runs into the wall.
	var piece := track.piece_type_at(offset)
	if track.has_corkscrew() and piece != "corkscrew":
		var to_roll := 4.0
		while to_roll < look:
			if track.piece_type_at(offset + to_roll) == "corkscrew" and track.up_at(offset + to_roll).y < 0.97:
				look = maxf(to_roll - 2.0, LOOK_NEAR)
				break
			to_roll += 2.0
	var dodge := _dodge()
	var target := track.point_at(offset + look) + track.right_at(offset + look) * (line + dodge)
	var up := kart.global_basis.y
	var to_target := target - kart.global_position
	to_target -= up * to_target.dot(up)
	var facing := -kart.global_basis.z
	var angle := facing.signed_angle_to(to_target, up)
	# On a corkscrew the point ahead is round the roll from here, and the
	# road takes you round it without steering, so it only edges back toward
	# its line.
	if piece == "corkscrew":
		var off_line := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset)) - line
		angle = atan(off_line / 20.0)
	var straight := piece != "corkscrew" and not TrackPiece.turns_over(piece) and track.bend_at(offset) < STRAIGHT_BEND and track.bend_at(offset + look * 0.4) < STRAIGHT_BEND
	# On a straight the kart's lock shrinks with speed, so aiming with that
	# lock slams the stick for a tiny heading error and the wheels wiggle.
	if straight:
		angle += kart.angular_velocity.dot(up) * 0.12
	var lock := Kart.MAX_STEER if straight else kart.full_lock
	# A kart with no wheels left has no lock (see Kart._pose_driver()).
	controls.steer = clampf(-angle / maxf(lock, 0.001) * 1.2, -1.0, 1.0)
	if straight:
		controls.steer = move_toward(_steer, controls.steer, STRAIGHT_STEER_RATE * delta)

	# For speed, find the slowest it needs to be for anything coming up, with
	# room to brake. A driver who can't steer quickly (see KartStats.control)
	# takes every bend a little slower.
	_judge_bends()
	# It takes the bends before a loop or jump as well as it can, so it
	# gets there with enough speed, whatever its level.
	_jump_run_in = _jump_within(JUMP_RUN_IN)
	var daring := maxf(skill, LOOP_SKILL) if _loop_within(LOOP_RUN_IN) or _jump_run_in else skill
	# On a wet or snowy road it takes everything a little slower, and gives
	# itself a touch more margin besides.
	var weather := kart.weather_grip * lerpf(1.0, WET_CARE, 1.0 - kart.weather_grip)
	var grip := kart.stats.cornering() * KartStats.gravity() * daring * minf(1.0, 0.6 + 0.4 * kart.stats.control) * _misjudge * weather
	var braking := BRAKING * weather
	var allowed := INF
	# Far enough ahead to stop for any bend from the speed it's doing, and a
	# little more. A corkscrew swings to the side as it rolls, but it's no
	# bend to slow down for, any more than a loop is (see
	# TrackPath.corner_bends()).
	var reach := maxf(64.0, speed * speed / (2.0 * braking) + 24.0)
	var count := track.corner_bends(offset, BEND_EVERY, reach, _bends)
	for k in count:
		var bend := _bends[k]
		if bend > 0.002:
			var corner := sqrt(grip * (slide_plan if slides and bend > slide_bend else 1.0) / bend)
			allowed = minf(allowed, sqrt(corner * corner + 2.0 * braking * BEND_EVERY * (k + 1)))
	# The bend it's in counts too, or it floors it on the way out of a hairpin
	# while it's still turning and runs wide.
	var here := 0.0 if TrackPiece.turns_over(piece) else maxf(track.bend_at(offset), track.bend_at(offset + 2.0))
	if here > 0.002 and not kart.sliding:
		allowed = minf(allowed, sqrt(grip / here))
	# Pointing well away from where it's going, like after a spin or out on
	# the grass, it slows to what it can turn onto it at, or it goes round
	# in a big circle and away from the road.
	if absf(angle) > TURN_ROUND_ANGLE and not kart.sliding:
		var across := 1.0 if absf(angle) > PI * 0.5 else sin(absf(angle))
		allowed = minf(allowed, maxf(sqrt(grip * to_target.length() / (2.0 * across)), TURN_ROUND_SPEED))
	# Traffic braking also follows the corridor while a pass moves aside.
	allowed = minf(allowed, traffic.speed_limit)
	if not crossings.is_empty():
		allowed = minf(allowed, _train_limit(speed, braking))

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
	elif kart.sliding and _slide_way != 0.0 and here > slide_bend * 0.4 and _turn_way(offset + maxf(speed * 0.4, 4.0)) == _slide_way and _slide_on_line():
		# Holding the slide on the gas, steering harder the tighter the bend
		# and if it's running wide.
		controls.throttle = 1.0
		controls.brake = 0.0
		# Enough to go round the bend at this speed, and more if it's running
		# wide (see Kart._hold_slide).
		var wide := -(kart.global_position - track.point_at(offset)).dot(track.right_at(offset)) * _slide_way
		var slide_grip := kart.stats.cornering() * KartStats.gravity() * Kart.slide_corner
		controls.steer = _slide_way * clampf(speed * speed * maxf(here, track.bend_at(offset + 6.0)) / slide_grip + maxf(wide - 1.5, 0.0) * 0.15 + minf(wide + 1.5, 0.0) * 0.15, 0.25, 1.0)
	elif kart.sliding and _slide_way != 0.0 and (here <= slide_bend * 0.4 or _turn_way(offset + maxf(speed * 0.4, 4.0)) != _slide_way):
		# Out of the hairpin, or where the road's about to bend back the
		# other way, it straightens up, which ends the slide with a little
		# turbo, and drives on.
		controls.throttle = 1.0
		controls.brake = 0.0
		controls.steer = 0.0
	elif kart.sliding and _slide_way != 0.0:
		# Running wide with the bend still going, it lifts off, which ends
		# the slide, and steers round the rest of it on its tires.
		controls.throttle = 0.0
		controls.brake = 0.0
	elif _backing > 0.0:
		# Backing off whatever it ran into, steering the other way. Off a
		# kart beside it, it steers toward that kart, which in reverse swings
		# its nose away from it, then pulls away to the free side.
		_backing -= delta
		controls.throttle = 0.0
		controls.brake = 1.0
		controls.steer = _away if _away != 0.0 else -controls.steer
		if _backing <= 0.0 and _away != 0.0:
			_leaving = PULL_AWAY_FOR
	elif _leaving > 0.0:
		_leaving -= delta
		controls.throttle = 1.0
		controls.brake = 0.0
		controls.steer = -_away * PULL_AWAY_STEER
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
	# Stopped for a train, it stays stopped.
	elif _waiting and allowed < 2.0:
		controls.throttle = 0.0
		controls.brake = 1.0
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

	# Queue braking has to release before the pedal starts reversing.
	if is_finite(traffic.speed_limit) and not _looping() and _backing <= 0.0 and _leaving <= 0.0 and not kart.sliding:
		var forward_speed := kart.linear_velocity.dot(-kart.global_basis.z)
		if speed > traffic.speed_limit + 0.25:
			controls.throttle = 0.0
			controls.brake = 1.0 if forward_speed > 0.6 else 0.0
		elif traffic.speed_limit < 0.6:
			controls.throttle = 0.0
			controls.brake = 1.0 if forward_speed > 0.6 else 0.0
	_steer = controls.steer


## How fast it can go and still stop before a crossing with a train due,
## or INF. It works out when it would be over the rails: well clear of the
## train either way, it carries on. Otherwise it stops at the line and waits
## until the train's gone.
func _train_limit(speed: float, braking: float) -> float:
	_waiting = false
	var limit := INF
	for crossing in crossings:
		var to_stop := fposmod(crossing.stop_offset() - offset, track.length)
		# Just past the line and still short of the rails counts as at it.
		if to_stop > track.length - LevelCrossing.STOP_BACK + 3.0:
			to_stop -= track.length
		if to_stop > speed * speed / (2.0 * braking) + TRAIN_LOOK:
			continue
		var to_rails := to_stop + LevelCrossing.STOP_BACK
		# The train whose arms are still down, or the next one.
		var window := crossing.timetable.next_window(clock - TrainTimetable.OPEN_AFTER - TrainTimetable.BARRIER_SWING)
		var train := int(window.z)
		var shut := crossing.arms_shut(train)
		if clock > shut.y:
			continue
		if _train_waits.get(crossing.index, -1) != train:
			var first_there := clock + maxf(to_rails - LevelCrossing.TRAIN_HALF - LevelCrossing.KART_ROOM, 0.0) / maxf(speed, TRAIN_QUICKEST)
			var last_off := clock + (to_rails + LevelCrossing.TRAIN_HALF + LevelCrossing.KART_ROOM + 2.0) / maxf(speed, TRAIN_SLOWEST)
			# The barrier arm on the way in has to be up as it goes by.
			var to_arm := to_rails - LevelCrossing.BARRIER_AT
			var past_arm := clock + maxf(to_arm + ARM_CLEAR, 0.0) / maxf(speed, TRAIN_SLOWEST)
			var at_arm := clock + maxf(to_arm - ARM_CLEAR, 0.0) / maxf(speed, TRAIN_QUICKEST)
			var before := last_off < window.x - TRAIN_BEFORE and (to_arm + ARM_CLEAR < 0.0 or past_arm < shut.x - ARM_BEFORE)
			var after := first_there > window.y + TRAIN_AFTER and at_arm > shut.y + ARM_BEFORE
			if before or after:
				continue
			# Past the line, or too close to stop now, it keeps going.
			if to_stop < 0.0 or speed * speed / (2.0 * braking) > to_stop + 4.0:
				continue
			_train_waits[crossing.index] = train
		# It waits at the line, then once the train's nearly gone it can go
		# as far as it could still stop short of the arm, until the arm lifts.
		_waiting = true
		var stop_at := to_stop - 1.0
		if clock > window.y - TRAIN_GO_EARLY:
			stop_at = to_rails - LevelCrossing.BARRIER_AT - ARM_CLEAR
		limit = minf(limit, sqrt(2.0 * braking * maxf(stop_at, 0.0)))
	return limit


## Which way the road's turning here: 1 to the right, -1 to the left.
func _turn_way(at: float) -> float:
	var turn := track.forward_at(at + 3.0) - track.forward_at(at - 3.0)
	return 1.0 if turn.dot(track.right_at(at)) > 0.0 else -1.0


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
## already on one. It looks ahead once a step, as far as it ever needs to.
func _loop_within(distance: float) -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _loop_looked:
		_loop_looked = frame
		_loop_at = INF
		if track.has_turns_over():
			var ahead := 0.0
			while ahead <= LOOP_RUN_IN:
				if TrackPiece.turns_over(track.piece_type_at(offset + ahead)) and track.up_at(offset + ahead).y < 0.9:
					_loop_at = ahead
					break
				ahead += 4.0
	return _loop_at <= distance


## Whether it's on a jump or close enough to build up speed for one.
func _jump_within(distance: float) -> bool:
	if _has_jump < 0:
		_has_jump = 0
		for piece in track.pieces:
			if piece.type == "jump":
				_has_jump = 1
				break
	if _has_jump == 0:
		return false
	var ahead := 0.0
	while ahead <= distance:
		if track.piece_type_at(offset + ahead) == "jump":
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
## right. It picks a side that's still on the road and empty, and holds that
## until it's past, so it doesn't weave back into them.
func _dodge() -> float:
	if kart.ghost_left > 0.0 or TrackPiece.turns_over(track.piece_type_at(offset)):
		_patch_dodge = 0.0
		_patch_eased = 0.0
		traffic.speed_limit = INF
		traffic.queueing = false
		return 0.0
	var wall := _dodge_wall(-kart.global_basis.z)
	var preferred := line + _dodge_patches() if is_nan(wall) else line + wall
	# Finish pulling past the kart it actually backed off. The planner still
	# checks the free side against every other kart and the wall.
	if is_nan(wall) and _tries > 0 and _stuck > 0.0 and is_instance_valid(_recover_from):
		var edge := maxf(track.width * 0.5 - kart.width() * 0.5 - 0.8, 0.0)
		preferred = -_away * edge
	var wall_line := NAN if is_nan(wall) else line + wall
	return traffic.plan(self, preferred, _since_drive, wall_line) - line


## How far to move over to keep out of puddles and drifts ahead. It
## weighs driving through the water and snow on each line it could take
## against moving over, so it goes straight through a small or shallow
## puddle or drift and round a big deep one. It goes back to its own line once that's
## quickest, and never moves onto a line with a kart alongside or just
## ahead. If every line is blocked it holds where it's going.
func _dodge_patches() -> float:
	if kart.puddles == null and kart.drifts == null:
		return 0.0
	# Time since it last drove (see _physics_process()).
	var dt := _since_drive
	if not _patch_staggered:
		# Each kart looks on a different step from the others.
		_patch_staggered = true
		_patch_wait = (maxi(others.find(kart), 0) + 0.5) * dt
	_patch_wait -= dt
	if _patch_wait <= 0.0:
		_patch_wait = PATCH_EVERY
		_patch_dodge = _patch_line()
	if absf(_patch_dodge) < absf(_patch_eased) and _patch_dodge * _patch_eased >= 0.0:
		_patch_eased = move_toward(_patch_eased, _patch_dodge, PATCH_BACK * dt)
	else:
		_patch_eased = _patch_dodge
	return _patch_eased


## The line to move over to for _dodge_patches(), from its own. Lines are
## tried cheapest move first, and a line stops being looked along once it
## can't beat the best so far.
func _patch_line() -> float:
	var own := _line_cost(line)
	if own == 0.0 and _patch_dodge == 0.0:
		return 0.0
	var edge := track.width * 0.5 - kart.width() * 0.5 - PATCH_EDGE
	var tries: Array[float] = [0.0, _patch_dodge]
	for shift: float in PATCH_LINES:
		if shift != 0.0 and shift != _patch_dodge:
			tries.append(shift)
	# And as far over as it can go either way.
	tries.append_array([-edge - line, edge - line])
	var best := INF
	var best_shift := _patch_dodge
	for i in tries.size():
		var shift := tries[i]
		if absf(line + shift) > edge + 0.01 or (i > 0 and shift == 0.0):
			continue
		var swerve := 0.0
		if shift != 0.0:
			swerve = (SWERVE_COST + absf(shift) * SWERVE_PER_M) * (SWERVE_HELD if shift == _patch_dodge else 1.0)
		if swerve >= best:
			continue
		var cost := own if shift == 0.0 else _line_cost(line + shift, best - swerve)
		cost += swerve
		if cost < best and _karts_clear(line + shift):
			best = cost
			best_shift = shift
	return best_shift


## Whether there's no kart alongside or just ahead on this line across the
## road, so moving onto it doesn't swerve into one.
func _karts_clear(across: float) -> bool:
	var along := track.forward_at(offset)
	for other in others:
		if other == kart or not is_instance_valid(other) or other.ghost_left > 0.0:
			continue
		var ahead := (other.global_position - kart.global_position).dot(along)
		if ahead < -PATCH_BESIDE or ahead > PATCH_BESIDE * 3.0:
			continue
		var at := offset + ahead
		var other_across := (other.global_position - track.point_at(at)).dot(track.right_at(at))
		if absf(other_across - across) < (kart.width() + other.width()) * 0.5 + KART_GAP:
			return false
	return true


## What driving on this line across the road for the stretch ahead would
## cost in water and snow, in seconds, going by the depth under each side's
## wheels. INF once the cost reaches `most`, where it stops looking. Snow
## is looked at every half step, as a short drift across the road could fit
## between steps. Ploughing only counts ahead of the front wheels, since
## they've already ploughed what's behind.
func _line_cost(across: float, most := INF) -> float:
	_scan_ahead()
	var wheels := maxf(kart.width() * 0.5 - 0.3, 0.0)
	var front := kart.wheelbase * 0.5
	var wet := 0.0
	var snow := 0.0
	var was_left := 0.0
	var was_right := 0.0
	for i in _scan_point.size():
		var right := _scan_right[i]
		var point := _scan_point[i] + right * across
		if kart.puddles != null:
			wet += kart.puddles.factor_at(point - right * wheels) + kart.puddles.factor_at(point + right * wheels)
		if kart.drifts != null:
			var half := Vector3.UP.cross(right) * PATCH_STEP * 0.5
			for k in 2:
				var at := point + half * k
				# Drag goes by depth squared and ploughing by how much that rises.
				var left := kart.drifts.factor_at(at - right * wheels)
				var right_side := kart.drifts.factor_at(at + right * wheels)
				left *= left
				right_side *= right_side
				snow += (left + right_side) * PATCH_STEP * 0.5 * SNOW_COST
				if _scan_from + (i + k * 0.5) * PATCH_STEP > front:
					snow += (maxf(left - was_left, 0.0) + maxf(right_side - was_right, 0.0)) * PLOUGH_COST
				was_left = left
				was_right = right_side
		if wet * 0.5 * PATCH_STEP * WATER_COST + snow * 0.5 >= most:
			return INF
	return wet * 0.5 * PATCH_STEP * WATER_COST + snow * 0.5


## The middle of the road and its right for _line_cost() to look along,
## once a step. From just behind, so it keeps its back wheels clear too,
## every PATCH_STEP m.
func _scan_ahead() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _scan_frame and offset == _scan_offset:
		return
	_scan_frame = frame
	_scan_offset = offset
	_scan_point.clear()
	_scan_right.clear()
	var see := maxf(SEE_PATCH, kart.linear_velocity.length() * SEE_PATCH_TIME)
	# On whole steps along the track, so the same spots are looked at as it
	# moves and the cost doesn't flicker with where the steps fall.
	var ahead := PATCH_STEP * ceilf(offset / PATCH_STEP) - offset - PATCH_STEP
	_scan_from = ahead
	while ahead <= see:
		var at := offset + ahead
		_scan_point.append(track.point_at(at))
		_scan_right.append(track.right_at(at))
		ahead += PATCH_STEP


## How far to move over to get past the end of a brick wall ahead, or NAN
## when there's none in the way. It goes round whichever end has more road
## beyond it.
func _dodge_wall(facing: Vector3) -> float:
	var frame := Engine.get_physics_frames()
	if frame != _walls_frame:
		_walls_frame = frame
		_walls = kart.get_tree().get_nodes_in_group("brick_walls")
	for wall in _walls:
		if not is_instance_valid(wall):
			continue
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


## Checks both ready buttons and uses the most useful safe opportunity.
func _use_gadgets(delta: float, speed: float) -> void:
	for slot in Powerups.HOLD:
		if kart.held[slot] != _held_kind[slot] or kart.held_uses[slot] != _held_uses[slot] or kart.held_revision[slot] != _held_revision[slot]:
			_held_for[slot] = 0.0
			_held_kind[slot] = kart.held[slot]
			_held_uses[slot] = kart.held_uses[slot]
			_held_revision[slot] = kart.held_revision[slot]
		elif kart.held[slot] != "":
			_held_for[slot] += delta
	_think -= delta
	if _think > 0.0:
		return
	_think = minf(THINK_EVERY, gadget_reaction)
	var best := -1
	var best_score := 0.0
	for slot in Powerups.HOLD:
		if not kart.can_use(slot) or _held_for[slot] < gadget_reaction:
			continue
		var score := AIGadgetTactics.score(self, kart.held[slot], speed)
		if score <= 0.0:
			continue
		score += minf(_held_for[slot] / HOLD_AT_MOST, 1.0) * 0.2
		if score > best_score:
			best_score = score
			best = slot
	if best >= 0 and _rng.randf() <= gadget_sense:
		controls.gadget[best] = true
		_held_for[best] = 0.0


func _worth_using(kind: String, speed: float) -> bool:
	return AIGadgetTactics.score(self, kind, speed) > 0.0


func _stuck_check(delta: float, speed: float, up: Vector3) -> void:
	# It's stuck against something, or on its back, or it isn't getting on
	# around the track. Upside down only counts when it isn't meant to be, so
	# not at the top of a loop. It's free again once it's a little further
	# around the track.
	var upside_down := up.y < 0.3 and not kart.sticking
	# Just after a reset it's pulling away from a standstill at half power,
	# which on ice takes a while, so that isn't being stuck.
	var pulling_away := kart.slowdown_left > 0.0 and not upside_down
	# Nor is waiting for a train.
	var waiting := (_waiting or traffic.queueing) and not upside_down
	var excused := kart.locked or pulling_away or waiting
	if waiting:
		_stuck = 0.0
		_tries = 0
	# Backing off or pulling away it isn't trying to get on, so that doesn't
	# count, and it starts counting afresh after.
	var busy := _backing > 0.0 or _leaving > 0.0
	var along := _along(_mark)
	if excused or busy or along > PROGRESS_STEP or along < -MOVED_BACK:
		_mark = offset
		_mark_time = 0.0
	else:
		_mark_time += delta
	var getting_nowhere := _mark_time > PROGRESS_TIME
	if not excused and not busy and (speed < 1.5 or upside_down or getting_nowhere):
		if _stuck == 0.0:
			_stuck_at = offset
		_stuck += delta
	elif _stuck > 0.0 and _along(_stuck_at) > FREE_AFTER:
		_stuck = 0.0
		_tries = 0
	# The right way up, against a wall or a barrier, it backs off once, the
	# way a person would. Against a kart it gets two goes, the second the
	# other way, before it resets.
	var may_try := _tries == 0 or (_tries < KART_TRIES and _away != 0.0)
	if not upside_down and may_try and _stuck > BACK_AFTER * (_tries + 1):
		_tries += 1
		_back_off()
	_wheel_gone = _wheel_gone + delta if _lost_a_wheel() and not kart.locked and not kart.held.has("repair") else 0.0
	if _stuck > STUCK_AFTER or _wheel_gone > WHEEL_GONE_FOR:
		_stuck = 0.0
		_wheel_gone = 0.0
		_tries = 0
		_backing = 0.0
		_leaving = 0.0
		controls.reset = true


## How far on around the track it is from there, the short way round the
## lap, in metres. Negative is behind.
func _along(from: float) -> float:
	return fposmod(offset - from + track.length * 0.5, track.length) - track.length * 0.5


## Gets clear of what it's stuck against. Against a wall it backs off,
## steering the other way. Against a kart it backs off if the kart's in
## front of it, or pulls away forward if it's behind, steering away from its
## side either way, so two karts stuck together go opposite ways. The second
## go it tries the other way.
func _back_off() -> void:
	var nearest: Kart = null
	for body in kart.get_colliding_bodies():
		if body is Kart and body != kart and (nearest == null or body.global_position.distance_to(kart.global_position) < nearest.global_position.distance_to(kart.global_position)):
			nearest = body
	_recover_from = nearest
	if nearest == null:
		_away = 0.0
		_backing = BACK_FOR
		return
	var gap := nearest.global_position - kart.global_position
	_away = 1.0 if gap.dot(kart.global_basis.x) > 0.0 else -1.0
	var forward := gap.dot(-kart.global_basis.z) < 0.0
	if _tries > 1:
		forward = not _went_forward
	_went_forward = forward
	if forward:
		_leaving = BACK_FOR
	else:
		_backing = BACK_FOR


## Whether any of its wheels have been knocked off.
func _lost_a_wheel() -> bool:
	for i in kart.lost:
		if KartDesign.is_wheel(kart.design.parts[i].id):
			return true
	return false
