class_name TowRope
extends MeshInstance3D

## A tow rope from one kart to the kart ahead of it. For a few seconds the kart
## on the end is pulled along towards a spot just behind the one it's caught
## onto, in its slipstream, a bit faster than it's going, and then it lets go
## with a short burst. The rope is drawn as a thin bar between them.

const TIME := 3.0
## How far behind the kart ahead it pulls towards, how much faster than it,
## and how hard.
const BEHIND := 4.0
const FASTER := 1.15
const PULL := 2200.0
## How far ahead a kart has to be for the rope to reach it.
const REACH := 60.0
const BURST := 1.0

var from: Kart
var to: Kart
var left := TIME


## A rope from this kart to the one ahead of it, or null if nobody's in reach.
static func throw(kart: Kart, ahead: Kart) -> TowRope:
	if ahead == null or not is_instance_valid(ahead) or ahead.global_position.distance_to(kart.global_position) > REACH:
		return null
	var rope := TowRope.new()
	rope.from = kart
	rope.to = ahead
	return rope


func _init() -> void:
	var bar := BoxMesh.new()
	bar.size = Vector3(0.16, 0.16, 1.0)
	mesh = bar
	material_override = PartVisuals.material(Color("#f2cd37"))
	top_level = true


func _ready() -> void:
	if from != null:
		from.tow = self


## The push the kart on the end gets this step.
func pull_on(kart: Kart) -> Vector3:
	if not is_instance_valid(to) or kart != from:
		return Vector3.ZERO
	var spot := to.global_position + to.global_basis.z * BEHIND
	var toward := spot - kart.global_position
	toward.y = 0.0
	if toward.length() < 1.0:
		return Vector3.ZERO
	var ahead_speed := maxf(to.linear_velocity.length(), 5.0)
	if kart.linear_velocity.dot(toward.normalized()) > ahead_speed * FASTER:
		return Vector3.ZERO
	return toward.normalized() * PULL


func _process(delta: float) -> void:
	left -= delta
	if left <= 0.0 or not is_instance_valid(from) or not is_instance_valid(to):
		if is_instance_valid(from):
			if from.tow == self:
				from.tow = null
				if not from.remote:
					from.boost_left = maxf(from.boost_left, BURST)
		queue_free()
		return
	var a := from.global_position + Vector3.UP * 0.6
	var b := to.global_position + Vector3.UP * 0.6
	var length := a.distance_to(b)
	if length < 0.1:
		visible = false
		return
	visible = true
	global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP).scaled_local(Vector3(1.0, 1.0, length)), (a + b) * 0.5)
