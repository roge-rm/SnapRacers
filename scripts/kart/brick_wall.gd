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
const COLOURS := [Color("#c4281c"), Color("#f2cd37"), Color("#0d69ab"), Color("#f2f3f2")]

var _age := 0.0
var _bricks: Array[RigidBody3D] = []


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
	return wall


func _ready() -> void:
	# So the AI can steer round it.
	add_to_group("brick_walls")
	for row in HIGH:
		# Every other row is staggered half a brick, like a real wall.
		var shift := 0.5 * BRICK.x if row % 2 == 1 else 0.0
		for i in ACROSS:
			var brick := RigidBody3D.new()
			brick.mass = 8.0
			brick.collision_layer = Kart.LAYER_HAZARD
			brick.collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS | Kart.LAYER_HAZARD
			brick.freeze = true
			brick.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = BRICK
			shape.shape = box
			brick.add_child(shape)
			var colour: Color = COLOURS[(i + row) % COLOURS.size()]
			var look := MeshInstance3D.new()
			look.mesh = MeshKit.rounded_box(BRICK - Vector3.ONE * 0.01, 0.02)
			look.material_override = PartVisuals.material(colour)
			brick.add_child(look)
			brick.add_child(PartVisuals.make_studs(BRICK, colour))
			brick.position = Vector3((i - (ACROSS - 1) * 0.5) * BRICK.x + shift, BRICK.y * (row + 0.5) + 0.01, 0.0)
			add_child(brick)
			_bricks.append(brick)
	# Anything driving into it sets the bricks it hits loose.
	var feel := Area3D.new()
	feel.collision_layer = 0
	feel.collision_mask = Kart.LAYER_KARTS
	var reach := CollisionShape3D.new()
	var zone := BoxShape3D.new()
	zone.size = Vector3(BRICK.x * (ACROSS + 1), BRICK.y * HIGH, BRICK.z + 1.2)
	reach.shape = zone
	reach.position = Vector3(0.0, BRICK.y * HIGH * 0.5, 0.0)
	feel.add_child(reach)
	add_child(feel)
	feel.body_entered.connect(_hit_by)


func _hit_by(body: Node3D) -> void:
	if not body is Kart or body.ghost_left > 0.0:
		return
	for brick in _bricks:
		if brick.freeze and brick.global_position.distance_to(body.global_position) < 2.5:
			brick.set_deferred("freeze", false)


## Whether any of it is still standing, not all knocked down.
func standing() -> bool:
	return _bricks.any(func(brick: RigidBody3D) -> bool: return brick.freeze)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
