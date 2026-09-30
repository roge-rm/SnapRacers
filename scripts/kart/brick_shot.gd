class_name BrickShot
extends RigidBody3D

## A brick fired from a brick cannon. It flies fast and nearly flat, and the
## first kart it hits loses a part. It's gone after a couple of seconds either
## way.

const SPEED := 34.0
const LIFETIME := 2.5
## A homing brick flies a little slower and for longer, turning this fast
## toward its kart, in radians a second.
const HOMING_SPEED := 30.0
const HOMING_LIFETIME := 6.0
const TURN := 3.0

var shooter: Kart
## The kart a homing brick is after.
var chasing: Kart
var _age := 0.0
var _spent := false


static func fire(from: Kart, homing := false) -> BrickShot:
	var shot := BrickShot.new()
	shot.shooter = from
	if homing:
		shot.chasing = _kart_ahead(from)
		shot.gravity_scale = 0.0
	var forward := -from.global_basis.z
	var up := from.global_basis.y
	shot.transform = Transform3D(from.global_basis, from.global_position + forward * 2.0 + up * 0.7)
	shot.linear_velocity = from.linear_velocity + forward * SPEED
	return shot


func _init() -> void:
	mass = 2.0
	gravity_scale = 0.25
	collision_layer = Kart.LAYER_HAZARD
	collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	var size := Vector3(2.0, 3.0, 2.0) * Grid.UNIT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	add_child(PartVisuals.make({ "kind": "brick", "color": Color("#6b6f76") }, size))
	body_entered.connect(_on_hit)


func _on_hit(body: Node) -> void:
	if _spent or body == shooter:
		return
	if body is Kart:
		_spent = true
		# The hit arrives in the middle of a physics step, when shapes can't
		# change, so the part comes off just after. A kart driven on another
		# device loses it there instead, when its own copy of the brick hits.
		if not body.remote:
			body.knock_off_a_part.call_deferred()
		queue_free()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > (HOMING_LIFETIME if chasing != null else LIFETIME):
		queue_free()
		return
	# A homing brick turns toward the kart it's after, a little at a time.
	if chasing != null and is_instance_valid(chasing):
		var to := chasing.global_position + chasing.global_basis.y * 0.5 - global_position
		var heading := linear_velocity.normalized()
		var wanted := to.normalized()
		var turned := heading.slerp(wanted, minf(TURN * delta / maxf(heading.angle_to(wanted), 0.001), 1.0))
		linear_velocity = turned * HOMING_SPEED


## The kart just ahead of this one in the race, or null if it's in front. A
## kart that isn't in a race has nobody to chase.
static func _kart_ahead(from: Kart) -> Kart:
	# The race is asked without naming it, since Race needs the Game autoload
	# and the -s tests load karts without one.
	var race = from.get_parent()
	if race == null or not race.has_method("standings"):
		return null
	var order: Array = race.standings()
	for i in order.size():
		if order[i].kart == from:
			return order[i - 1].kart if i > 0 else null
	return null
