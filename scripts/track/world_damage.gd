class_name WorldDamage
extends Node3D

## Draws the scenery a SceneryKit collected and lets karts break it. Each prop
## is a group of bricks. A small one (a tree, a post, a billboard, a fence)
## comes down whole when a kart hits it hard enough, and a big one (a house, a
## grandstand) only where it's hit: its bricks are split into chunks and the
## ones around the hit fly off, with the ones above them, leaving a hole. A
## hard hit on a tire stack knocks its top tires off, but the bottom of the
## stack stays, so a line of them still keeps karts from cutting across.
##
## What flies off is rubble: light loose bricks that tumble, land, and stay
## where they land until the race is over. Karts push them about. Only so many
## can move at once, for the phone, so past that the oldest stop moving and
## stay where they lie as scenery you can drive through.
##
## Everything's still drawn as one batch per shape, the scenery and the rubble
## each, with room left over in the scenery's for the chunks that stay up.

## How big a chunk a wall is split into where it's hit, at most, and how few
## it's split into at least along the way it's longest.
const CHUNK := 1.0
const MOST_SPLITS := 6
## Pieces that fly off are split into chunks no bigger than this.
const FLYING_CHUNK := 1.1
## How far around a hit on a big prop breaks, and how much further for every
## metre a second the kart was doing.
const REACH := 1.2
const REACH_PER_SPEED := 0.03
## How much rubble can move at once, and how much room the batches have.
const MOST_MOVING := 120
const ROOM_FOR_RUBBLE := 600
const ROOM_FOR_CHUNKS := 800
## How heavy rubble is for its size, in kilograms a cubic metre, and the
## lightest and heaviest a piece can be, so a kart pushes it about.
const DENSITY := 40.0
const LIGHTEST := 1.5
const HEAVIEST := 25.0
## A stack hit harder than this loses two tires instead of one.
const HARD_HIT := 18.0
## Below this, the pieces of rubble go.
const LOWEST := -60.0

const KINDS := ["box", "cylinder", "cone"]

## Each group: { name, small, tires, pieces: [[kind, index]], shapes: [CollisionShape3D] }.
var groups: Array = []

## For each kind, every instance's [transform, colour, surface, group].
var _instances := {}
var _scenery := {}
var _rubble_draw := {}
var _rubble_used := {}
## Every piece of rubble: [body or null, kind, index, size].
var _rubble: Array = []
var _moving: Array = []
var _body: StaticBody3D
var _cushion: StaticBody3D
var _rng := RandomNumberGenerator.new()
static var _bouncy: PhysicsMaterial
static var _gritty: PhysicsMaterial


## Builds what `kit` collected.
func _init(kit: SceneryKit) -> void:
	name = "Scenery"
	groups = kit.groups.duplicate(true)
	for group in groups:
		group["pieces"] = []
		group["shapes"] = []
	_instances = { "box": kit.boxes, "cylinder": kit.cylinders, "cone": kit.cones }
	for kind in KINDS:
		var list: Array = _instances[kind]
		for i in list.size():
			var group: int = list[i][3] if list[i].size() > 3 else -1
			if group >= 0:
				groups[group].pieces.append([kind, i])
		_scenery[kind] = _batch(kind, list.size() + (ROOM_FOR_CHUNKS if kind == "box" else 0))
		var multi: MultiMesh = _scenery[kind].multimesh
		multi.visible_instance_count = list.size()
		for i in list.size():
			_place(multi, i, list[i][0], list[i][1], list[i][2])
		_rubble_draw[kind] = _batch(kind, ROOM_FOR_RUBBLE)
		_rubble_draw[kind].multimesh.visible_instance_count = 0
		_rubble_used[kind] = 0
	if not kit.soft.is_empty():
		if _bouncy == null:
			_bouncy = PhysicsMaterial.new()
			_bouncy.bounce = 0.5
			_bouncy.friction = 0.2
		_cushion = StaticBody3D.new()
		# On the hazard layer, which karts hit but their wheels don't ride on,
		# or a kart would climb right up over the stacks.
		_cushion.collision_layer = Kart.LAYER_HAZARD
		_cushion.physics_material_override = _bouncy
		_cushion.set_meta("soft", true)
		_cushion.set_meta("breakable", self)
		add_child(_cushion)
		for thing in kit.soft:
			_shape_for(_cushion, thing[0], thing[1], thing[2] if thing.size() > 2 else -1)
	if not kit.solids.is_empty():
		_body = StaticBody3D.new()
		_body.collision_layer = Kart.LAYER_WORLD
		_body.set_meta("breakable", self)
		add_child(_body)
		for solid in kit.solids:
			_shape_for(_body, solid[0], solid[1], solid[2] if solid.size() > 2 else -1)


func _ready() -> void:
	if not groups.is_empty():
		add_to_group("world_damage")
	for kind in KINDS:
		add_child(_scenery[kind])
		add_child(_rubble_draw[kind])


func _batch(kind: String, room: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = SceneryKit.mesh_for(kind)
	multi.instance_count = room
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.material_override = SceneryKit.material()
	return draw


static func _place(multi: MultiMesh, i: int, where: Transform3D, colour: Color, surface: int) -> void:
	multi.set_instance_transform(i, where)
	multi.set_instance_color(i, colour)
	multi.set_instance_custom_data(i, Color(float(surface), 0.0, 0.0, 0.0))


func _shape_for(body: StaticBody3D, where: Transform3D, size: Vector3, group: int) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = where
	body.add_child(shape)
	if group >= 0:
		shape.set_meta("group", group)
		shape.set_meta("small", groups[group].small)
		groups[group].shapes.append(shape)
	return shape


## The scenery that can break in a race, or null.
static func in_tree(tree: SceneTree) -> WorldDamage:
	return tree.get_first_node_in_group("world_damage") as WorldDamage


## Whether a group comes down whole.
func is_small(group: int) -> bool:
	return group >= 0 and group < groups.size() and groups[group].small and not groups[group].tires


## The group a shape on one of the scenery's bodies belongs to, or -1, from a
## contact's shape index.
static func group_of(body: Object, shape_index: int) -> int:
	if not body is CollisionObject3D:
		return -1
	var owner_id: int = body.shape_find_owner(shape_index)
	var shape: Object = body.shape_owner_get_owner(owner_id) if owner_id >= 0 else null
	return shape.get_meta("group", -1) if shape != null else -1


## Breaks the scenery a kart hit at `at`, going at `velocity`.
func break_at(group: int, at: Vector3, velocity: Vector3) -> void:
	if group < 0 or group >= groups.size():
		return
	var g: Dictionary = groups[group]
	at = to_local(at)
	velocity = global_basis.inverse() * velocity
	_rng.seed = hash([group, g.pieces.size(), snappedf(at.x, 0.5), snappedf(at.z, 0.5)])
	var speed := velocity.length()
	if g.tires:
		_knock_tires(g, at, speed, velocity)
	elif g.small:
		_bring_down(g, velocity)
	else:
		_knock_hole(group, at, REACH + speed * REACH_PER_SPEED, velocity)


## The whole thing comes down.
func _bring_down(g: Dictionary, velocity: Vector3) -> void:
	for piece in g.pieces:
		var kind: String = piece[0]
		var i: int = piece[1]
		var inst: Array = _instances[kind][i]
		var where: Transform3D = inst[0]
		if where.basis.get_scale() == Vector3.ZERO:
			continue
		_hide(kind, i)
		if kind == "box":
			for chunk in _chunks(where, FLYING_CHUNK, 5):
				_fly("box", chunk, inst[1], inst[2], velocity)
		else:
			_fly(kind, where, inst[1], inst[2], velocity)
	for shape in g.shapes:
		shape.set_deferred("disabled", true)
	g.pieces.clear()


## The top tires come off the stacks near the hit.
func _knock_tires(g: Dictionary, at: Vector3, speed: float, velocity: Vector3) -> void:
	var lose := 2 if speed > HARD_HIT else 1
	var stacks := {}
	for piece in g.pieces:
		var where: Transform3D = _instances[piece[0]][piece[1]][0]
		if where.basis.get_scale() == Vector3.ZERO or Vector2(where.origin.x - at.x, where.origin.z - at.z).length() > 1.2:
			continue
		var key := Vector2i(roundi(where.origin.x * 4.0), roundi(where.origin.z * 4.0))
		stacks.get_or_add(key, []).append(piece)
	for key in stacks:
		var stack: Array = stacks[key]
		stack.sort_custom(func(a, b): return _instances[a[0]][a[1]][0].origin.y > _instances[b[0]][b[1]][0].origin.y)
		# The bottom one always stays.
		for n in mini(lose, stack.size() - 1):
			var piece: Array = stack[n]
			var inst: Array = _instances[piece[0]][piece[1]]
			var where: Transform3D = inst[0]
			_hide(piece[0], piece[1])
			_fly(piece[0], where, inst[1], inst[2], velocity)
			g.pieces.erase(piece)


## A hole where it's hit: the chunks within `reach` fly off, with everything
## above them, and the rest of each brick stays up.
func _knock_hole(group: int, at: Vector3, reach: float, velocity: Vector3) -> void:
	var g: Dictionary = groups[group]
	var room := Sphere.new(at, reach)
	var kept := []
	for piece in g.pieces.duplicate():
		var kind: String = piece[0]
		var i: int = piece[1]
		var inst: Array = _instances[kind][i]
		var where: Transform3D = inst[0]
		var box := AABB(where.origin - where.basis.get_scale() * 0.5, where.basis.get_scale())
		if where.basis.get_scale() == Vector3.ZERO or not room.touches(box):
			continue
		if kind != "box" or not _upright(where):
			# Round things and tipped ones (roofs) go whole, if they're not too
			# big to.
			if box.size.x <= FLYING_CHUNK * 2.0 and box.size.z <= FLYING_CHUNK * 2.0:
				g.pieces.erase(piece)
				_hide(kind, i)
				_fly(kind, where, inst[1], inst[2], velocity)
			continue
		g.pieces.erase(piece)
		_hide(kind, i)
		var count := _splits(box.size, CHUNK, MOST_SPLITS)
		var step := box.size / Vector3(count)
		# Which chunks go: the ones in reach, and everything above them.
		var going := {}
		for x in count.x:
			for z in count.z:
				var fall := false
				for y in count.y:
					var cell := AABB(box.position + step * Vector3(x, y, z), step)
					fall = fall or room.touches(cell)
					if fall:
						going[Vector3i(x, y, z)] = true
		var solid := _solid_for(g, where)
		for x in count.x:
			for z in count.z:
				# What's left of each column stands as one piece, solid if the
				# brick was.
				var run_from := -1
				for y in count.y + 1:
					var stays := y < count.y and not going.has(Vector3i(x, y, z))
					if stays and run_from < 0:
						run_from = y
					elif not stays and run_from >= 0:
						var bottom := box.position + step * Vector3(x, run_from, z)
						var size := step * Vector3(1, y - run_from, 1)
						var centre := Transform3D(Basis.IDENTITY, bottom + size * 0.5)
						kept.append(["box", centre.scaled_local(size), inst[1], inst[2], size if solid != null else null])
						run_from = -1
				for y in count.y:
					if going.has(Vector3i(x, y, z)):
						var cell_centre := box.position + step * (Vector3(x, y, z) + Vector3.ONE * 0.5)
						_fly("box", Transform3D(Basis.IDENTITY, cell_centre).scaled_local(step), inst[1], inst[2], velocity)
		if solid != null:
			solid.set_deferred("disabled", true)
	for k in kept:
		var index := _add_scenery(k[0], k[1], k[2], k[3], group)
		if index < 0:
			continue
		g.pieces.append([k[0], index])
		if k[4] != null and _body != null:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = k[4]
			shape.shape = box
			shape.transform = Transform3D(Basis.IDENTITY, k[1].origin)
			shape.set_meta("group", group)
			shape.set_meta("small", false)
			_body.add_child.call_deferred(shape)
			g.shapes.append(shape)


## The solid shape that goes with a brick of a group, if it has one.
func _solid_for(g: Dictionary, where: Transform3D) -> CollisionShape3D:
	for shape in g.shapes:
		if is_instance_valid(shape) and not shape.disabled and shape.transform.origin.distance_to(where.origin) < 0.01 and shape.get_parent() == _body:
			return shape
	return null


static func _upright(where: Transform3D) -> bool:
	var b := where.basis.orthonormalized()
	return b.x.is_equal_approx(Vector3.RIGHT) and b.y.is_equal_approx(Vector3.UP)


## How many chunks a box splits into along each way.
static func _splits(size: Vector3, chunk: float, most: int) -> Vector3i:
	return Vector3i(
		clampi(ceili(size.x / chunk - 0.01), 1, most),
		clampi(ceili(size.y / chunk - 0.01), 1, most),
		clampi(ceili(size.z / chunk - 0.01), 1, most))


## A box's chunks, as scaled transforms.
static func _chunks(where: Transform3D, chunk: float, most: int) -> Array:
	var size := where.basis.get_scale()
	var turn := where.basis.orthonormalized()
	var count := _splits(size, chunk, most)
	var step := size / Vector3(count)
	var out := []
	for x in count.x:
		for y in count.y:
			for z in count.z:
				var offset := -size * 0.5 + step * (Vector3(x, y, z) + Vector3.ONE * 0.5)
				out.append(Transform3D(turn, where.origin + turn * offset).scaled_local(step))
	return out


func _hide(kind: String, i: int) -> void:
	var inst: Array = _instances[kind][i]
	inst[0] = Transform3D(Basis.from_scale(Vector3.ZERO), inst[0].origin)
	_scenery[kind].multimesh.set_instance_transform(i, inst[0])


## Adds a brick that stays up after a hit, in the batch's spare room.
func _add_scenery(kind: String, where: Transform3D, colour: Color, surface: int, group: int) -> int:
	var multi: MultiMesh = _scenery[kind].multimesh
	var i := multi.visible_instance_count
	if i >= multi.instance_count:
		return -1
	multi.visible_instance_count = i + 1
	_instances[kind].append([where, colour, surface, group])
	_place(multi, i, where, colour, surface)
	return i


## Sends a brick flying off as rubble.
func _fly(kind: String, where: Transform3D, colour: Color, surface: int, velocity: Vector3) -> void:
	var used: int = _rubble_used[kind]
	var multi: MultiMesh = _rubble_draw[kind].multimesh
	if used >= multi.instance_count:
		return
	_rubble_used[kind] = used + 1
	multi.visible_instance_count = used + 1
	_place(multi, used, where, colour, surface)
	var size := where.basis.get_scale()
	var body := RigidBody3D.new()
	body.collision_layer = Kart.LAYER_RUBBLE
	body.collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS | Kart.LAYER_RUBBLE | Kart.LAYER_DEBRIS
	body.mass = clampf(size.x * size.y * size.z * DENSITY, LIGHTEST, HEAVIEST)
	body.set_meta("soft", true)
	if _gritty == null:
		_gritty = PhysicsMaterial.new()
		_gritty.friction = 0.8
		_gritty.bounce = 0.15
	body.physics_material_override = _gritty
	var shape := CollisionShape3D.new()
	if kind == "box":
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
	else:
		var round := CylinderShape3D.new()
		round.radius = size.x * 0.5 * (0.7 if kind == "cone" else 1.0)
		round.height = size.y
		shape.shape = round
	body.add_child(shape)
	body.transform = Transform3D(where.basis.orthonormalized(), where.origin)
	var spread := Vector3(_rng.randf_range(-2.0, 2.0), _rng.randf_range(1.0, 4.0), _rng.randf_range(-2.0, 2.0))
	body.linear_velocity = velocity * _rng.randf_range(0.3, 0.7) + spread
	body.angular_velocity = Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
	add_child.call_deferred(body)
	var piece := [body, kind, used, size]
	_rubble.append(piece)
	_moving.append(piece)
	while _moving.size() > MOST_MOVING:
		_settle(_moving.pop_front())


## A piece of rubble stops moving and stays where it lies.
func _settle(piece: Array) -> void:
	var body: RigidBody3D = piece[0]
	if body == null:
		return
	if is_instance_valid(body):
		_draw_rubble(piece)
		body.queue_free()
	piece[0] = null


func _draw_rubble(piece: Array) -> void:
	var body: RigidBody3D = piece[0]
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	_rubble_draw[piece[1]].multimesh.set_instance_transform(piece[2], body.global_transform.scaled_local(piece[3]))


func _physics_process(_delta: float) -> void:
	for piece in _moving.duplicate():
		var body: RigidBody3D = piece[0]
		if not is_instance_valid(body):
			_moving.erase(piece)
			continue
		if body.sleeping:
			continue
		_draw_rubble(piece)
		if body.is_inside_tree() and body.global_position.y < LOWEST:
			_moving.erase(piece)
			_rubble_draw[piece[1]].multimesh.set_instance_transform(piece[2], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			body.queue_free()
			piece[0] = null


## How many pieces of rubble there are, and how many can still move.
func rubble_count() -> Vector2i:
	return Vector2i(_rubble.size(), _moving.size())


## A ball, for which bricks a hit reaches.
class Sphere:
	var centre: Vector3
	var radius: float

	func _init(at: Vector3, r: float) -> void:
		centre = at
		radius = r

	func touches(box: AABB) -> bool:
		var nearest := centre.clamp(box.position, box.end)
		return nearest.distance_to(centre) <= radius
