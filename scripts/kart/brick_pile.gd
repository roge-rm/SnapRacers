class_name BrickPile
extends RigidBody3D

## One of the loose bricks a brick dropper leaves behind, a handful of
## different sizes that tumble out the back and scatter. Karts hit them like
## anything else, so running into a pile at speed can knock your parts off.
## They clear away after a while.

const LIFETIME := 15.0
const SHRINK_TIME := 0.5
## Phones can't handle too many loose bodies, so past this many the oldest go
## first.
const MOST_AT_ONCE := 80
## How many bricks a drop leaves, five drops under MOST_AT_ONCE.
## They come out spread over SPREAD metres across, and are thrown out
## sideways at up to THROW times their distance from the middle, in m/s, so
## they cover most of the road with gaps between.
const COUNT := 16
const SPREAD := 3.4
const THROW := 3.0
## The sizes a dropped brick can be, in studs across and along, and how often
## one is a plate.
const SIZES := [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(1, 6), Vector2i(2, 6)]
const PLATE_CHANCE := 0.25
## How hard a shockwave throws bricks, in m/s at its middle, and how far
## round a cannonball's hit it throws them and how hard. A homing brick throws
## just the brick it hits.
const SHOCK_SPEED := 12.0
const CANNON_REACH := 3.0
const CANNON_SPEED := 14.0
const HOMING_SPEED := 8.0
const BRICK_HIGH := 0.45
const PLATE_HIGH := 0.18
## Kilograms a cubic metre, so a 2 by 4 brick is about 5 kg.
const DENSITY := 22.0
const COLOURS := [Color("#c4281c"), Color("#f2cd37"), Color("#0d69ab"), Color("#f2f3f2"), Color("#237841"), Color("#da8540"), Color("#a5ca18"), Color("#e4adc8"), Color("#68c3e2"), Color("#81007b"), Color("#1b2a34")]

static var _alive: Array[BrickPile] = []

var _age := 0.0


static func drop_behind(from: Kart) -> Array[BrickPile]:
	var out: Array[BrickPile] = []
	var back := from.global_basis.z
	var right := from.global_basis.x
	var up := from.global_basis.y
	# Sizes and colours from the kart's grid slot and how many things it's
	# dropped, which every machine counts the same since the drops arrive in
	# order, so every device drops the same pile.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([from.grid_slot, from.drops])
	from.drops += 1
	for i in COUNT:
		var studs: Vector2i = SIZES[rng.randi_range(0, SIZES.size() - 1)]
		var plate := rng.randf() < PLATE_CHANCE
		var size := Vector3(studs.x * Grid.STUD, PLATE_HIGH if plate else BRICK_HIGH, studs.y * Grid.STUD)
		var brick := BrickPile.new(size, COLOURS[rng.randi_range(0, COLOURS.size() - 1)])
		var spot := spot_of(i)
		var at := from.global_position + back * (2.3 + i * 0.1) + right * spot.x + up * spot.y
		brick.transform = Transform3D(from.global_basis.rotated(up, i * 0.9), at)
		# Thrown back and out, spinning, so they spread across the road and a
		# little along it.
		brick.linear_velocity = from.linear_velocity * 0.3 + right * spot.x * THROW + back * (i % 3) + up * (1.0 + spot.y)
		brick.angular_velocity = Vector3(sin(i * 2.1), cos(i * 1.7), sin(i * 3.3)) * 5.0
		out.append(brick)
	return out


## Where brick `i` of a drop comes out, as (right, up) in metres from behind
## the middle of the kart. Next ones go to different sides.
static func spot_of(i: int) -> Vector2:
	return Vector2(float((i * 7) % COUNT) / (COUNT - 1) * SPREAD - SPREAD * 0.5, 0.5 + (i % 4) * 0.25)


func _init(size := Vector3(0.5, BRICK_HIGH, 1.0), colour := Color("#c4281c")) -> void:
	mass = maxf(size.x * size.y * size.z * DENSITY, 0.6)
	collision_layer = Kart.LAYER_HAZARD
	collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS | Kart.LAYER_HAZARD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	var look := MeshInstance3D.new()
	look.mesh = MeshKit.rounded_box(size - Vector3.ONE * 0.01, 0.02)
	look.material_override = PartVisuals.material(colour)
	add_child(look)
	add_child(PartVisuals.make_studs(size, colour))


## Throws every loose brick and wall brick within `reach` of `at` away from it,
## at up to `speed` m/s, faster the closer it is, and knocks wall bricks
## free. Shockwaves and cannonballs use it. Every device has its own copy of
## the bricks and gets the same blasts, so it's done on each one.
static func blast(tree: SceneTree, at: Vector3, reach: float, speed: float) -> void:
	var bricks: Array[RigidBody3D] = []
	for pile in tree.get_nodes_in_group("brick_piles"):
		bricks.append(pile)
	for wall in tree.get_nodes_in_group("brick_walls"):
		bricks.append_array(wall.bricks())
	for brick in bricks:
		var away := brick.global_position - at
		var far := away.length()
		if far > reach:
			continue
		away.y = 0.0
		var out := away.normalized() if away.length() > 0.05 else Vector3.FORWARD
		var push := (out + Vector3.UP * 0.6).normalized() * speed * (1.0 - far / reach * 0.6)
		# A blast can come in the middle of a physics step, when a frozen
		# brick can't be let go, so it's thrown just after.
		throw.call_deferred(brick, push)


## Lets a brick go, if it was standing in a wall, and throws it along `push`.
static func throw(brick: Object, push: Vector3) -> void:
	if not is_instance_valid(brick) or brick.collision_layer == 0:
		return
	brick.freeze = false
	brick.linear_velocity += push
	brick.angular_velocity += Vector3(push.z, push.length() * 0.3, -push.x) * 0.5


func _ready() -> void:
	add_to_group("brick_piles")
	_alive.append(self)
	while _alive.size() > MOST_AT_ONCE:
		var oldest: BrickPile = _alive.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _exit_tree() -> void:
	_alive.erase(self)


func _physics_process(delta: float) -> void:
	_age += delta
	var left := LIFETIME - _age
	if left <= 0.0:
		queue_free()
	elif left < SHRINK_TIME:
		# Shrinking away, it stops getting in anyone's way.
		collision_layer = 0
		collision_mask = Kart.LAYER_WORLD
		var s := maxf(left / SHRINK_TIME, 0.01)
		for child in get_children():
			if child is Node3D and not child is CollisionShape3D:
				child.scale = Vector3.ONE * s
