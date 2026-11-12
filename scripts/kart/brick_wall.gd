class_name BrickWall
extends Node3D

## A wall of bricks dropped across the road behind a kart, two high and about
## half the road wide. The bricks stay put until a kart drives into them, and
## then they tumble, knocking it about like any bricks would. They clear
## away after a while.

const LIFETIME := 15.0
const BRICK := Vector3(1.0, 0.55, 0.5)
const ACROSS := 6
const HIGH := 2
const BEHIND := 3.5
## Half the wall's width, from the middle to the end of the longer row.
const HALF := (ACROSS + 0.5) * BRICK.x * 0.5
const COLOURS := BrickPile.COLOURS
## How far past the kart's sides a brick still counts as in its way, in metres.
const PATH_MARGIN := 0.6
const BRICK_MASS := 3.0
## How much of its speed into the wall a kart keeps as it breaks through.
const KEEP := 0.5
## How fast the bricks fly off a slow kart, in m/s at least.
const FLING_LEAST := 4.0
## Seconds the bricks a kart broke off go through it, so it isn't left
## stranded on top of them.
const CLEAR_FOR := 1.0

## Picks each brick's colour. Every machine seeds it the same way for the same
## drop, so the walls look alike online.
var colour_seed := 0
var _age := 0.0
var _bricks: Array[RigidBody3D] = []
var _feel: Area3D
## [kart, brick, seconds left] for each brick going through the kart that broke it.
var _clearing: Array = []


## A wall on the ground just behind this kart, square to the way it's going.
static func drop_behind(from: Kart) -> BrickWall:
	var wall := BrickWall.new()
	var behind := from.global_position + from.global_basis.z * BEHIND
	var space := from.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(behind + Vector3.UP * 2.0, behind + Vector3.DOWN * 4.0, Kart.LAYER_WORLD)
	var hit := space.intersect_ray(query)
	var ground: Vector3 = hit.position if not hit.is_empty() else behind
	var forward := -from.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.1:
		forward = Vector3.FORWARD
	wall.transform = Transform3D(Basis.looking_at(forward.normalized(), Vector3.UP), ground)
	# From the kart's grid slot and how many walls it's dropped, which every
	# machine counts the same since the drops arrive in order.
	wall.colour_seed = hash([from.grid_slot, from.drops])
	from.drops += 1
	return wall


func _ready() -> void:
	# So the AI can steer round it.
	add_to_group("brick_walls")
	var rng := RandomNumberGenerator.new()
	rng.seed = colour_seed
	for row in HIGH:
		# Every other row is staggered half a brick, like a real wall.
		var shift := 0.5 * BRICK.x if row % 2 == 1 else 0.0
		for i in ACROSS:
			var brick := RigidBody3D.new()
			brick.mass = BRICK_MASS
			brick.collision_layer = Kart.LAYER_HAZARD
			brick.collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS | Kart.LAYER_HAZARD
			brick.freeze = true
			brick.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = BRICK
			shape.shape = box
			brick.add_child(shape)
			var colour: Color = COLOURS[rng.randi_range(0, COLOURS.size() - 1)]
			brick.set_meta("colour", colour)
			var look := MeshInstance3D.new()
			look.mesh = MeshKit.rounded_box(BRICK - Vector3.ONE * 0.01, 0.02)
			look.material_override = PartVisuals.material(colour)
			brick.add_child(look)
			brick.add_child(PartVisuals.make_studs(BRICK, colour))
			brick.position = Vector3((i - (ACROSS - 1) * 0.5) * BRICK.x + shift, BRICK.y * (row + 0.5) + 0.01, 0.0)
			add_child(brick)
			_bricks.append(brick)
	# Anything driving into it sets the bricks in its way loose. It reaches
	# 1.2 m either side so a fast kart is felt a step or two before it touches.
	var feel := Area3D.new()
	feel.collision_layer = 0
	feel.collision_mask = Kart.LAYER_KARTS
	var reach := CollisionShape3D.new()
	var zone := BoxShape3D.new()
	zone.size = Vector3(BRICK.x * (ACROSS + 1), BRICK.y * HIGH, BRICK.z + 2.4)
	reach.shape = zone
	reach.position = Vector3(0.0, BRICK.y * HIGH * 0.5, 0.0)
	feel.add_child(reach)
	add_child(feel)
	_feel = feel


## Knocks flying the bricks in the way of each kart that drives into it, at
## any speed, and takes half its speed. Every machine works this out from
## its own karts, like the tumbling bricks themselves.
func _knock_loose() -> void:
	for body in _feel.get_overlapping_bodies():
		# A ghost goes through and leaves the wall standing. A shield throws
		# the bricks itself, from the kart.
		if not body is Kart or body.ghost_left > 0.0 or body.shield_left > 0.0:
			continue
		var kart: Kart = body
		var local := global_transform.affine_inverse() * kart.global_position
		var reach := kart.width() * 0.5 + PATH_MARGIN
		var in_way := _bricks.filter(func(brick: RigidBody3D) -> bool: return brick.freeze and absf(brick.position.x - local.x) < reach)
		if in_way.is_empty():
			continue
		var going := kart.linear_velocity.dot(global_basis.z)
		# Which way through it's going, or facing when it's barely moving.
		var way := going if absf(going) > 0.5 else -kart.global_basis.z.dot(global_basis.z)
		var along := global_basis.z * (1.0 if way >= 0.0 else -1.0)
		var speed := absf(going)
		# The bricks fly on ahead and out to the sides, off its line, so it
		# isn't left climbing over them.
		var fling := maxf(speed, FLING_LEAST)
		for i in in_way.size():
			var brick: RigidBody3D = in_way[i]
			var off := brick.position.x - local.x
			var side := signf(off) if absf(off) > 0.1 else (1.0 if i % 2 == 0 else -1.0)
			BrickPile.throw.call_deferred(brick, along * fling * 0.5 + global_basis.x * side * fling * 0.9 + Vector3.UP * 2.0)
			kart.add_collision_exception_with(brick)
			_clearing.append([kart, brick, CLEAR_FOR])
		kart.linear_velocity -= global_basis.z * going * (1.0 - KEEP)


## The bricks it's made of.
func bricks() -> Array[RigidBody3D]:
	return _bricks


## Whether any of it is still standing, not all knocked down.
func standing() -> bool:
	return _bricks.any(func(brick: RigidBody3D) -> bool: return brick.freeze)


func _physics_process(delta: float) -> void:
	if _feel != null and standing():
		_knock_loose()
	for i in range(_clearing.size() - 1, -1, -1):
		var entry: Array = _clearing[i]
		entry[2] -= delta
		if entry[2] <= 0.0:
			if is_instance_valid(entry[0]) and is_instance_valid(entry[1]):
				entry[0].remove_collision_exception_with(entry[1])
			_clearing.remove_at(i)
	_age += delta
	if _age > LIFETIME:
		queue_free()
