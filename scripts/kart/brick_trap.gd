class_name BrickTrap
extends StaticBody3D

## A trap dropped on the road behind a kart, lying flat on whatever's under
## it, until it's cleared away (see DropKeeper):
## - "marbles": round 1x1 bricks scattered all over, which roll under the
##   wheels, so whoever drives across them loses nearly all their grip and
##   slides;
## - "spikes": a cluster of little grey cones, which hold karts back hard
##   without making them slide, and pop a tire of one that hits them fast
##   (see Kart).
##
## Wheels feel it through the ground's "grip" and "drag", and a ghost drives
## over it as if it isn't there ("trap"). A shield slides the whole patch
## aside, and it stays where it comes to rest.

## Seconds it takes to shrink away.
const SHRINK_TIME := 0.5
## Clear space between the kart's tail and the nearest edge of the patch.
const DROP_GAP := 0.5
## For each kind: how far it reaches either side of its middle across the
## road and along it, the grip and drag on it, and how many pieces are
## scattered over it. Marbles are a wide oval across the road.
const KINDS := {
	"marbles": { "across": 3.4, "along": 2.6, "grip": 0.12, "drag": 0.6, "pieces": 48 },
	"spikes": { "across": 2.3, "along": 2.3, "grip": 0.85, "drag": 35.0, "pieces": 14 },
}
## Sides of the oval the patch's shape is made of.
const SIDES := 24
const MARBLE_COLOURS := BrickPile.COLOURS
## The little pieces marbles are made of: round and square 1x1 bricks, round
## plates, balls and 1x2 plates.
const MARBLE_SHAPES := ["round", "square", "round_plate", "ball", "plate_1x2"]
const SPIKE := Color("#635f61")

var kind := "marbles"
## Which drop it is (see DropKeeper.key_of()), or -1 when it wasn't dropped.
var drop_key := -1
## Seconds before it's gone. A DropKeeper decides that in a race.
var _left := DropKeeper.BACKSTOP
## How much of its size is left after karts have worn it, and how many of its
## pieces.
var _share := 1.0
## Slide left after a shield shove, in m/s, world space and horizontal.
var _slide := Vector3.ZERO
var _moving := false
var _falling := false
var _fall_speed := 0.0
## On sticky road it slides along the road and stays on it at any angle.
var _sticky := false
## Set when dropped onto the road, so it's fitted to it once it's in the world.
var _fit_on_ready := false
## Whether its pieces and shape are fitted to curved road rather than flat.
var _bent := false
var _look_seed := 0
## Nearby ground follows the patch's current plane. Larger drops use gravity.
const GROUND_STEP := 0.2
const GROUND_CLEAR := 0.01
## How fast a shield throws the patch, and how fast that slide dies, in m/s
## and m/s², so it moves a few metres and stops.
const SHOVE_SPEED := 9.0
const SHOVE_DAMP := 8.0
## Ground more than this far below the drop point, in metres, is fallen to.
const DROP_SNAP := 1.5
## How much road a split's branch keeps clear beside anything dropped on it,
## in metres, so a kart gets by.
const ROOM := 3.0
## Rim points with no ground under them before the patch slides off an edge,
## out of RIM_POINTS round the oval, and how fast it slides, in m/s.
const RIM_POINTS := 8
const RIM_MISSING := 2
const OVERHANG_SPEED := 3.0
## Steps, in metres, for following sticky road back from the kart round a
## loop or corkscrew, and how far either side of the road each step looks.
const MARCH_STEP := 0.5
const MARCH_REACH := 1.0
## On curved or twisting road the pieces and the patch's shape follow the road
## once any part of it is this far off flat, in metres, up to FIT_REACH.
const FIT_MIN := 0.03
const FIT_REACH := 0.8
## Rings out from the middle the fitted shape is made of, as shares of the oval.
const FIT_RINGS := [0.35, 0.7, 1.0]


## A trap on the ground just behind this kart.
static func drop_behind(from: Kart, what := "marbles") -> BrickTrap:
	# From the kart's grid slot and how many things it's dropped, so every
	# device scatters the same pieces.
	var trap := BrickTrap.new(what, hash([from.grid_slot, from.drops]))
	trap.drop_key = DropKeeper.key_of(from)
	from.drops += 1
	# The entire patch must clear the kart, including long builds and rear wheels.
	var distance: float = from.rear_bumper_point().z + KINDS[trap.kind].along + DROP_GAP
	var space := from.get_world_3d().direct_space_state
	var place := ground_behind(from, distance, KINDS[trap.kind].across)
	var hit: Dictionary = place.hit
	var normal: Vector3 = hit.normal if not hit.is_empty() else Vector3.UP
	var forward := (-from.global_basis.z).slide(normal).normalized()
	if forward.length() < 0.1:
		forward = Vector3.FORWARD
	var ground: Vector3 = hit.position if not hit.is_empty() else place.at
	trap.transform = Transform3D(Basis.looking_at(forward, normal), ground + normal * 0.01)
	trap._moving = hit.is_empty()
	trap._falling = hit.is_empty()
	trap._sticky = place.sticky
	if trap._falling:
		trap.collision_layer = 0
	else:
		# Half over an edge, it slides off and falls. Otherwise it settles
		# onto the road once it's in the world.
		var off := trap._overhang(space, trap.transform)
		if off != Vector3.ZERO:
			trap._slide = off * OVERHANG_SPEED
			trap._moving = true
		else:
			trap._fit_on_ready = true
	return trap


## Where something dropped `distance` metres behind a kart lands, as "hit"
## (the ray hit on the road, empty when it has to fall), "at" (where it starts
## falling from) and "sticky". On sticky road it follows the road back round
## loops and corkscrews along the kart's own down. Anywhere else it looks
## straight down, and ground too steep to lie on or well below is fallen to.
## On a split, something `half` metres either side of its middle is moved
## over so it never closes off a branch (see clear_of_island()). Only the
## kart's place, the track and the world are used, so every device agrees.
static func ground_behind(from: Kart, distance: float, half := 0.0) -> Dictionary:
	var space := from.get_world_3d().direct_space_state
	var up := from.global_basis.y
	var query := PhysicsRayQueryParameters3D.create(from.global_position + up * 0.5, from.global_position - up * 1.5, Kart.LAYER_WORLD)
	var hit := road_hit(space, query)
	if not hit.is_empty() and hit.collider.get_meta("sticky", false):
		var at: Vector3 = hit.position
		up = hit.normal
		var back := from.global_basis.z.slide(up).normalized()
		var left := distance
		while left > 0.0:
			var step := minf(left, MARCH_STEP)
			left -= step
			var next := at + back * step
			query.from = next + up * MARCH_REACH
			query.to = next - up * MARCH_REACH
			hit = road_hit(space, query)
			if hit.is_empty() or hit.normal.dot(up) < 0.5:
				# Off the end of the road, it falls from there.
				return { "hit": {}, "at": next + back * left + up * 0.5, "sticky": false }
			at = hit.position
			up = hit.normal
			back = back.slide(up).normalized()
		var sticky: bool = hit.collider.get_meta("sticky", false)
		if sticky or hit.normal.y > 0.1:
			return { "hit": hit, "at": at, "sticky": sticky }
		return { "hit": {}, "at": at + up * 0.5, "sticky": false }
	var behind := from.global_position + from.global_basis.z * distance
	var race := from.get_parent()
	var track := (race.get("track") if race != null else null) as TrackPath
	if track != null and track.has_splits and half > 0.0:
		behind = clear_of_island(track, behind, half)
	query.from = behind + Vector3.UP * 2.0
	query.to = behind + Vector3.DOWN * 4.0
	hit = road_hit(space, query)
	# Ground well below the drop (a kart in the air, a drop off the side) is
	# reached by falling, not by snapping down to it.
	if not hit.is_empty() and (hit.position.y < behind.y - DROP_SNAP or hit.normal.y <= 0.1):
		hit = {}
	return { "hit": hit, "at": behind, "sticky": not hit.is_empty() and hit.collider.get_meta("sticky", false) }


## Where to put something `half` metres either side of `at` on a split so a
## kart still gets by it on the branch it's on: at least ROOM clear on one
## side or the other. Off a split it stays where it is. Moved over, it goes
## toward the island, where it can lie on the grass.
static func clear_of_island(track: TrackPath, at: Vector3, half: float) -> Vector3:
	var offset := track.offset_of(at)
	var middle := track.point_at(offset)
	if absf(middle.y - at.y) > 4.0:
		return at
	var lanes := track.lanes_at(offset)
	if lanes.size() < 2:
		return at
	var right := track.right_at(offset)
	var across := (at - middle).dot(right)
	var moved := across
	for side in 2:
		var lane: Vector2 = lanes[side]
		var lo := moved - half
		var hi := moved + half
		if hi <= lane.x or lo >= lane.y:
			continue
		if lo - lane.x >= ROOM or lane.y - hi >= ROOM:
			continue
		# Room down the outside of the branch, away from the island.
		moved = lane.x + ROOM + half if side == 0 else lane.y - ROOM - half
	return at + right * (moved - across)


## A ray's hit on the world, going through traps.
static func road_hit(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D) -> Dictionary:
	var skip := query.exclude
	var hit := space.intersect_ray(query)
	for i in 32:
		if hit.is_empty() or not hit.collider is BrickTrap:
			break
		query.exclude = query.exclude + [hit.rid]
		hit = space.intersect_ray(query)
	query.exclude = skip
	return hit


func _init(what := "marbles", look_seed := 0) -> void:
	kind = what if KINDS.has(what) else "marbles"
	var of: Dictionary = KINDS[kind]
	collision_layer = Kart.LAYER_WORLD
	set_meta("grip", of.grip)
	set_meta("drag", of.drag)
	set_meta("trap", kind)
	add_to_group("traps")
	_look_seed = look_seed
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _flat_oval()
	add_child(shape)
	var look := _pieces(null)
	look.name = "Look"
	add_child(look)


func _ready() -> void:
	var keeper := DropKeeper.find(get_tree())
	if keeper != null and drop_key >= 0:
		_left = INF
		keeper.add(self, drop_key)
	if _fit_on_ready:
		_fit_on_ready = false
		_fit()


## A flat oval, thin enough that nothing catches on its edge.
func _flat_oval() -> Shape3D:
	var oval := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for i in SIDES:
		var a := TAU * i / SIDES
		for y in [-0.02, 0.02]:
			points.append(Vector3(cos(a) * reach_across(), y, sin(a) * reach_along()))
	oval.points = points
	return oval


## How far the road is above the patch's plane at `local`, in metres, or NAN
## where there's no road facing the same way, like off its edge or on a wall.
func _road_height(space: PhysicsDirectSpaceState3D, local: Vector3) -> float:
	var up := global_basis.y.normalized()
	var at := global_transform * Vector3(local.x, 0.0, local.z)
	var query := PhysicsRayQueryParameters3D.create(at + up * FIT_REACH, at - up * FIT_REACH, Kart.LAYER_WORLD, [get_rid()])
	var hit := road_hit(space, query)
	if hit.is_empty() or hit.normal.dot(up) < 0.5:
		return NAN
	return (hit.position - global_position).dot(up) + GROUND_CLEAR


## Fits the pieces and the shape to curved or twisting road under the patch,
## like the top of a loop or a corkscrew, or puts them back flat if it's flat.
func _fit() -> void:
	var space := get_world_3d().direct_space_state
	var across := reach_across()
	var along := reach_along()
	var middle := _road_height(space, Vector3.ZERO)
	if is_nan(middle):
		middle = GROUND_CLEAR
	var rings: Array[PackedFloat32Array] = []
	var most := 0.0
	for k in FIT_RINGS.size():
		var r: float = FIT_RINGS[k]
		var ring := PackedFloat32Array()
		for i in SIDES:
			var a := TAU * i / SIDES
			var h := _road_height(space, Vector3(cos(a) * r * across, 0.0, sin(a) * r * along))
			# Past the road's edge it carries on from the ring inside.
			if is_nan(h):
				h = rings[k - 1][i] if k > 0 else middle
			ring.append(h)
			most = maxf(most, absf(h))
		rings.append(ring)
	if most < FIT_MIN:
		if _bent:
			_flatten()
		return
	_bent = true
	# The top of the patch as a fan of triangles over the road.
	var faces := PackedVector3Array()
	var top := 0.02
	var inner: Array[Vector3] = []
	for i in SIDES:
		inner.append(Vector3(0.0, middle + top, 0.0))
	for k in FIT_RINGS.size():
		var outer: Array[Vector3] = []
		for i in SIDES:
			var a := TAU * i / SIDES
			outer.append(Vector3(cos(a) * FIT_RINGS[k] * across, rings[k][i] + top, sin(a) * FIT_RINGS[k] * along))
		for i in SIDES:
			var j := (i + 1) % SIDES
			faces.append_array(PackedVector3Array([inner[i], outer[j], outer[i]]))
			if k > 0:
				faces.append_array(PackedVector3Array([inner[i], inner[j], outer[j]]))
		inner = outer
	var bent := ConcavePolygonShape3D.new()
	bent.backface_collision = true
	bent.set_faces(faces)
	$Shape.shape = bent
	var look := _pieces(space)
	var old := $Look
	remove_child(old)
	old.queue_free()
	look.name = "Look"
	add_child(look)


## Back to a flat patch, to slide along.
func _flatten() -> void:
	_bent = false
	$Shape.shape = _flat_oval()
	var look := _pieces(null)
	var old := $Look
	remove_child(old)
	old.queue_free()
	look.name = "Look"
	add_child(look)


## The bricks scattered over it, baked into one mesh. With `space` each one
## sits on the road under it, otherwise on the patch's plane.
func _pieces(space: PhysicsDirectSpaceState3D) -> MeshInstance3D:
	var of: Dictionary = KINDS[kind]
	var across := reach_across()
	var along := reach_along()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([kind, _look_seed])
	var parts: Array[Node3D] = []
	# Worn, it keeps the first of the same pieces, drawn in closer.
	for i in ceili(of.pieces * _share):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.9
		var at := Vector3(cos(a) * r * across, 0.0, sin(a) * r * along)
		if space != null:
			var h := _road_height(space, at)
			at.y = 0.0 if is_nan(h) else h
		var piece := MeshInstance3D.new()
		if kind == "spikes":
			# A little grey cone on a round plate.
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.13
			cone.height = 0.3
			cone.radial_segments = 10
			piece.mesh = cone
			piece.position = at + Vector3.UP * 0.19
			piece.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
			piece.material_override = PartVisuals.material(SPIKE)
			var plate := MeshInstance3D.new()
			plate.mesh = MeshKit.rounded_cylinder(0.14, 0.06, 0.015, 12)
			plate.position = at + Vector3.UP * 0.03
			plate.material_override = PartVisuals.material(SPIKE.darkened(0.2))
			parts.append(plate)
		else:
			# A little piece of a random shape, some on their sides.
			var tipped := rng.randf() < 0.5
			var high := 0.2
			match MARBLE_SHAPES[rng.randi_range(0, MARBLE_SHAPES.size() - 1)]:
				"round":
					piece.mesh = MeshKit.rounded_cylinder(0.12, 0.2, 0.025, 14)
				"square":
					piece.mesh = MeshKit.rounded_box(Vector3(0.24, 0.2, 0.24), 0.025)
				"round_plate":
					piece.mesh = MeshKit.rounded_cylinder(0.12, 0.08, 0.02, 14)
					high = 0.08
					tipped = false
				"ball":
					var ball := SphereMesh.new()
					ball.radius = 0.12
					ball.height = 0.24
					ball.radial_segments = 12
					ball.rings = 6
					piece.mesh = ball
					high = 0.24
					tipped = false
				_:
					piece.mesh = MeshKit.rounded_box(Vector3(0.24, 0.08, 0.48), 0.02)
					high = 0.08
					tipped = false
			piece.position = at + Vector3.UP * (0.12 if tipped else high * 0.5)
			piece.rotation = Vector3(PI * 0.5 if tipped else 0.0, rng.randf() * TAU, 0.0)
			piece.material_override = PartVisuals.material(MARBLE_COLOURS[rng.randi_range(0, MARBLE_COLOURS.size() - 1)])
		parts.append(piece)
	var baked := KartMesh.bake(parts)
	for part in parts:
		part.free()
	return baked


## True when `at` is on the patch or close enough that the bubble meets it.
func overlaps_shield(at: Vector3) -> bool:
	var up := global_basis.y.normalized()
	if absf((at - global_position).dot(up)) > Kart.SHIELD_REACH:
		return false
	var away := (global_position - at).slide(up)
	var span := maxf(reach_across(), reach_along())
	return away.length() < Kart.SHIELD_REACH + span * 0.55


## Slides the patch off the kart along the road. One shove: it coasts to a
## stop and stays.
func shove_from(kart: Node3D) -> void:
	if _slide.length() > 0.5:
		return
	var up := global_basis.y.normalized()
	var away := (global_position - kart.global_position).slide(up)
	var side := kart.global_basis.x.slide(up)
	if side.length() < 0.1:
		side = global_basis.x.normalized()
	else:
		side = side.normalized()
	var forward := (-kart.global_basis.z).slide(up)
	if forward.length() < 0.1:
		forward = -global_basis.z.normalized()
	else:
		forward = forward.normalized()
	var lean := away.dot(side)
	if absf(lean) < 0.4:
		lean = 1.0
	var out := (side * signf(lean) + forward * 0.4).normalized()
	_slide = out * SHOVE_SPEED
	_moving = true
	if _bent:
		_flatten()


## Other patches aren't ground, including ones above or below this one. Sticky
## road holds it at any angle when `sticky` is set, other ground only if it
## faces up enough.
func _ground_between(from: Vector3, to: Vector3, sticky := false) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, Kart.LAYER_WORLD, [get_rid()])
	var hit := road_hit(get_world_3d().direct_space_state, query)
	if hit.is_empty():
		return {}
	if hit.normal.y > 0.1 or (sticky and hit.collider.get_meta("sticky", false)):
		return hit
	return {}


## Which way the patch hangs over an edge, along its plane and normalised,
## when enough of its rim has no ground under it. Zero when it's well
## supported.
func _overhang(space: PhysicsDirectSpaceState3D, place: Transform3D) -> Vector3:
	var up := place.basis.y.normalized()
	var off := Vector3.ZERO
	var missing := 0
	for i in RIM_POINTS:
		var a := TAU * i / RIM_POINTS
		var rim := place * Vector3(cos(a) * reach_across() * 0.8, 0.0, sin(a) * reach_along() * 0.8)
		var query := PhysicsRayQueryParameters3D.create(rim + up * FIT_REACH, rim - up * FIT_REACH, Kart.LAYER_WORLD, [get_rid()])
		var hit := road_hit(space, query)
		if hit.is_empty() or hit.normal.dot(up) <= 0.5:
			missing += 1
			off += rim - place.origin
	off = off.slide(up)
	if missing < RIM_MISSING or off.length() < 0.01:
		return Vector3.ZERO
	return off.normalized()


func _land(hit: Dictionary) -> void:
	var normal: Vector3 = hit.normal
	var forward := (-global_basis.z).slide(normal).normalized()
	if forward.length() < 0.1:
		forward = Vector3.RIGHT.cross(normal).normalized()
	global_transform = Transform3D(Basis.looking_at(forward, normal), hit.position + normal * GROUND_CLEAR)
	_falling = false
	_fall_speed = 0.0
	_sticky = hit.collider.get_meta("sticky", false)
	collision_layer = Kart.LAYER_WORLD


func _move(delta: float) -> void:
	var before := global_position
	var velocity := _slide
	var up := global_basis.y.normalized()
	if not _falling:
		velocity = _slide.slide(up)
	var next := before + velocity * delta
	if not _falling:
		# On sticky road it keeps to the road along its own down, like a kart.
		var down := -up if _sticky else Vector3.DOWN
		var support := _ground_between(next - down * GROUND_STEP, next + down * GROUND_STEP, _sticky)
		if not support.is_empty():
			_land(support)
			if _sticky:
				# Round a loop it keeps its speed along the road.
				_slide = _slide.slide(support.normal).normalized() * _slide.length()
			# Still hanging over an edge, it keeps sliding off it.
			if _slide.length() < OVERHANG_SPEED:
				var off := _overhang(get_world_3d().direct_space_state, global_transform)
				if off != Vector3.ZERO:
					_slide = off * OVERHANG_SPEED
		else:
			_falling = true
			_sticky = false
			_fall_speed = velocity.y
			collision_layer = 0
	if _falling:
		_fall_speed -= KartStats.gravity() * delta
		next.y = before.y + _fall_speed * delta
		var landing := _ground_between(Vector3(next.x, before.y + GROUND_CLEAR, next.z), next - Vector3.UP * GROUND_CLEAR)
		if _fall_speed <= 0.0 and not landing.is_empty():
			_land(landing)
		else:
			global_position = next
	_slide = _slide.move_toward(Vector3.ZERO, SHOVE_DAMP * delta)
	if _slide.length() <= 0.15:
		_slide = Vector3.ZERO
		_moving = _falling
		# At rest on curved road it settles onto it.
		if not _moving:
			_fit()


## How far it reaches either side of its middle across the road and along
## it now, in metres.
func reach_across() -> float:
	return KINDS[kind].across * _share


func reach_along() -> float:
	return KINDS[kind].along * _share


## Worn down by `hits` karts out of `of`: smaller, with fewer pieces.
func wear_to(hits: int, of: int) -> void:
	var share := 1.0 - float(hits) / (of + 1)
	if share >= _share or _left <= SHRINK_TIME:
		return
	_share = share
	if _bent:
		_fit()
	else:
		_flatten()


## Shrinks away and goes.
func fade() -> void:
	if _left <= SHRINK_TIME:
		return
	_left = SHRINK_TIME
	collision_layer = 0
	remove_from_group("traps")


func _physics_process(delta: float) -> void:
	if _moving:
		_move(delta)
	_left -= delta
	if _left <= 0.0:
		queue_free()
	elif _left < SHRINK_TIME:
		# Nothing feels it while it shrinks.
		collision_layer = 0
		$Look.scale = Vector3.ONE * maxf(_left / SHRINK_TIME, 0.01)
