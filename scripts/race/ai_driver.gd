class_name AIDriver
extends Node

## Drives a kart round a track.
##
## It aims at a point on the track a little way ahead (further the faster it's
## going) and steers toward it. For speed it looks down the road for bends,
## works out how fast its own kart can take each one from how well it grips,
## and brakes in time to be at that speed when it gets there. If it's stuck
## or upside down for a couple of seconds it resets, same as a player would.

## How close to its kart's limit it dares to corner. 1 is flat out.
@export var skill := 0.92
## How far right of the middle of the road it likes to drive, in metres.
@export var line := 0.0

const BRAKING := 8.0 # m/s² it counts on when planning to slow down
const LOOK_NEAR := 7.0
const LOOK_FAR := 26.0
const STUCK_AFTER := 2.5
const SEE_AHEAD := 12.0 # how far ahead it watches for karts in its way
const KART_ROOM := 2.8 # how far to the side a kart has to be to be out of the way

var kart: Kart
var track: TrackPath
## The other karts, so it can go round them.
var others: Array[Kart] = []
## Where the kart is along the track. The race keeps this up to date.
var offset := 0.0
var controls := KartControls.new()

var _stuck := 0.0


func _physics_process(delta: float) -> void:
	if kart == null or track == null:
		return
	controls.reset = false
	var speed := kart.linear_velocity.length()

	# Steering.
	var look := clampf(5.0 + speed * 0.55, LOOK_NEAR, LOOK_FAR)
	var target := track.point_at(offset + look) + track.right_at(offset + look) * (line + _dodge())
	var up := kart.global_basis.y
	var to_target := target - kart.global_position
	to_target -= up * to_target.dot(up)
	var facing := -kart.global_basis.z
	var angle := facing.signed_angle_to(to_target, up)
	var limit := Kart.MAX_STEER * lerpf(1.0, Kart.HIGH_SPEED_STEER, clampf(speed / 28.0, 0.0, 1.0))
	controls.steer = clampf(-angle / limit * 1.2, -1.0, 1.0)

	# Speed: the slowest it needs to be for anything coming up, allowing
	# room to brake.
	var grip := kart.stats.cornering() * KartStats.gravity() * skill
	var allowed := INF
	var ahead := 4.0
	while ahead <= 64.0:
		var bend := track.bend_at(offset + ahead)
		if bend > 0.002:
			var corner := sqrt(grip / bend)
			allowed = minf(allowed, sqrt(corner * corner + 2.0 * BRAKING * ahead))
		ahead += 4.0
	var here := track.bend_at(offset + 2.0)
	if here > 0.002:
		allowed = minf(allowed, sqrt(grip / here))

	if speed > allowed + 1.5:
		controls.throttle = 0.0
		controls.brake = 1.0
	elif speed > allowed:
		controls.throttle = 0.2
		controls.brake = 0.0
	else:
		controls.throttle = 1.0
		controls.brake = 0.0

	_stuck_check(delta, speed, up)


## How far to move over to get round a kart close ahead, in metres to the
## right. It goes whichever way is further from the kart and still on the
## road.
func _dodge() -> float:
	var facing := -kart.global_basis.z
	var right := kart.global_basis.x
	var half_road := track.width * 0.5 - 1.5
	var here := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset))
	for other in others:
		if other == kart:
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


func _stuck_check(delta: float, speed: float, up: Vector3) -> void:
	# Stuck against something, or on its back.
	if not kart.locked and (speed < 1.5 or up.y < 0.3):
		_stuck += delta
	else:
		_stuck = 0.0
	if _stuck > STUCK_AFTER:
		_stuck = 0.0
		controls.reset = true
