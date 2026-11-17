class_name LevelCrossing
extends Node3D

## A railway across the road with a toy brick train going over it on a
## timetable (see TrainTimetable). Lights flash and barriers come down ahead
## of it, and it knocks any kart in its way off the rails.
##
## The rails run straight out from the road both ways, over the ground, into
## a tunnel each side. Where the train is comes only from the race clock
## (`time`), so it's the same on every device.
##
## The barrier arms on the way in are solid once they're most of the way
## down. A slow kart stops against one, and a fast one breaks it and loses
## some speed, the same as small scenery (see Kart.BREAK_SPEED). A broken arm
## stays broken, with its stump still going up and down. The arms on the way
## out are only for looks, so nobody's shut in on the rails.
##
## Everything is drawn with the scenery's brick material in a few MultiMeshes,
## the train included, so a crossing costs about six draw calls.
##
## Only a kart's own device knocks it (see NetRace), so remote karts are left
## alone here.

## Rail centres apart, and how big a rail is.
const GAUGE := 2.0
const RAIL := 0.22
## How high the tops of the rails are over the ground or the road.
const RAIL_TOP := 0.25
const SLEEPER_EVERY := 1.6
## Heights along the railway are kept this far apart, in metres.
const STEP := 2.0
## The rails run out this far each side of the road before the tunnel, or less
## where other road is in the way, but never less than LEAST_REACH.
const MOST_REACH := 100.0
const LEAST_REACH := 30.0
## The tunnel mouths: a block of stone this deep, wide and high with a hole
## for the train.
const PORTAL_DEPTH := 16.0
const PORTAL_WIDTH := 14.0
const PORTAL_HEIGHT := 10.0
const HOLE_WIDTH := 5.4
const HOLE_HEIGHT := 6.5
## Other road is kept this far from the rails, past its curbs, so the
## tunnels stay out of its runoff.
const ROAD_ROOM := TrackPath.KERB + Scenery.RUNOFF + PORTAL_WIDTH * 0.5 + 1.0
## How far across the train is from its middle, and how tall, for knocking
## karts. A kart is about KART_ROOM across from its middle.
const TRAIN_HALF := 1.8
const TRAIN_HEIGHT := 4.6
const KART_ROOM := 1.2
## The barriers stand this far along the road either side of the rails.
const BARRIER_AT := 7.0
## The arms on the way in are solid once they're this far down (see
## TrainTimetable.barriers()), so a moving arm never presses on a kart.
const SOLID_DOWN := 1.0
## A broken arm keeps this much of itself by the pivot, in metres.
const STUMP := 1.2
## The AI stops this far before the rails.
const STOP_BACK := 11.0
## A kart that's been hit isn't hit again for this long.
const HIT_EVERY := 1.5

const ENGINE_LENGTH := 10.0
const CARRIAGE_LENGTH := 8.0
const COUPLING := 0.8
const CARRIAGES := [Props.GREEN, Props.YELLOW, Props.BLUE]

const SLEEPER := Color("#6b4a32")
const STEEL := Color("#8d9095")
const PAD := Color("#3a3b3d")
const LAMP_OFF := Color("#5a1d1a")
const LAMP_ON := Color("#ff3b24")

var track: TrackPath
## Where along the lap the rails cross the middle of the road, in metres.
var offset := 0.0
## Which crossing this is on the course, so each has its own trains.
var index := 0
var timetable: TrainTimetable
## The race clock, in seconds from GO. A race sets it every step (see
## Race._physics_process()). Without a race the crossing keeps its own.
var time := 0.0
var own_clock := true
## The karts it can hit.
var karts: Array[Kart] = []

## Where the rails cross the middle of the road, on the ground, and which way
## the road and the railway go there, both level. `across` points to the
## right as you drive.
var middle := Vector3.ZERO
var along := Vector3.FORWARD
var across := Vector3.RIGHT
## How far the road and its curbs reach either side of the railway.
var road_half := 9.0
## How far the rails run each side: [left, right] as you drive.
var reach: Array[float] = [MOST_REACH, MOST_REACH]

var _ground: Callable
## Heights of the ground under the rails every STEP metres, from the far end
## of the left tunnel.
var _heights := PackedFloat32Array()
var _from := 0.0
var _hit_wait := {}
var _still: Batch
var _moving: Batch
## [group, length] for each car front to back, [pivot, group] for each
## barrier arm, and which box each lamp is.
var _cars: Array = []
## Each arm: { pivot, group, way_in, body, shape, solid, broken, length }.
var _arms: Array = []
var _lamps: Array = []
var _was_lit := false
## What the lamps and barrier arms last showed, so they're only changed when
## they change: 0 dark, 1 or 2 for which pair's lit.
var _lamps_showing := -1
var _arm_angle := -1.0
## Which cars are hidden in their tunnels.
var _car_hidden: Array[bool] = []
## Whether any camera can see the crossing, to leave the train be when not.
var _seen: VisibleOnScreenNotifier3D
## How far each kart reaches from its middle (see _reach_of()).
var _reaches := {}
var _bell_in := 0.0
var _horned := -1
var _bell: Node3D
var _engine_spot: Node3D
var _train_shown := true


## The crossing at `at` metres along `path`. `ground` gives the height of the
## ground at (x, z).
func _init(path: TrackPath, at: float, number: int, ground: Callable, chance_seed := 0) -> void:
	track = path
	offset = at
	index = number
	_ground = ground
	name = "LevelCrossing%d" % number
	var flat := track.forward_at(at)
	flat.y = 0.0
	along = flat.normalized()
	across = along.cross(Vector3.UP).normalized()
	middle = track.point_at(at)
	road_half = track.width * 0.5 + TrackPath.KERB + 1.0
	reach = [_reach_to(-1.0), _reach_to(1.0)]
	_work_out_heights()
	use_seed(chance_seed)


## Starts the timetable for a race with this seed.
func use_seed(chance_seed: int) -> void:
	timetable = TrainTimetable.new(chance_seed, index, road_half, reach[0], reach[1])


## How far the rails can go out on one side (-1 left, 1 right) before they'd
## come near other road.
func _reach_to(side: float) -> float:
	return clampf(room(track, offset, side) - PORTAL_DEPTH - 2.0, LEAST_REACH, MOST_REACH)


## How far out from the middle of the road a railway at `at` metres along
## `path` can run on one side (-1 left, 1 right) before it comes near other
## road, up to the most it would ever need.
static func room(path: TrackPath, at: float, side: float) -> float:
	var flat := path.forward_at(at)
	flat.y = 0.0
	var right := flat.normalized().cross(Vector3.UP).normalized()
	var centre := path.point_at(at)
	var near: Array[Vector3] = []
	var most := MOST_REACH + PORTAL_DEPTH + 2.0
	var keep := most + ROAD_ROOM + path.width
	for k in path.points.size():
		var gap := absf(path.distances[k] - at)
		gap = minf(gap, path.length - gap)
		var p := path.points[k]
		if gap > 40.0 and Vector2(p.x - centre.x, p.z - centre.z).length() < keep:
			near.append(p)
	var s := path.width * 0.5
	while s < most:
		var spot := centre + right * side * s
		for p in near:
			if Vector2(p.x - spot.x, p.z - spot.z).length() < ROAD_ROOM + path.width * 0.5:
				return s
		s += STEP
	return most


## Whether there's no room for the railway and its tunnels on one side or the
## other of a crossing at `at` metres along `path`.
static func cramped(path: TrackPath, at: float) -> bool:
	var least := LEAST_REACH + PORTAL_DEPTH + 2.0
	return room(path, at, -1.0) < least or room(path, at, 1.0) < least


## Whether the road's up off the ground at `at`, after a ramp, so the rails
## couldn't meet it.
static func raised(path: TrackPath, at: float) -> bool:
	var p := path.point_at(at)
	return p.y - path.road_ground(p.x, p.z) > 1.0


## What's wrong with the crossings on `path`, as a sentence, or "" if nothing.
static func problem(path: TrackPath) -> String:
	for at in path.crossing_offsets():
		if raised(path, at):
			return "A level crossing has to be on road at ground level."
		if cramped(path, at):
			return "A level crossing needs open ground on both sides for its railway."
	return ""


func _work_out_heights() -> void:
	_from = -reach[0] - PORTAL_DEPTH
	var count := int((reach[1] + PORTAL_DEPTH - _from) / STEP) + 2
	_heights.resize(count)
	var road_tilt := track.right_at(offset).y
	for i in count:
		var s := _from + i * STEP
		var clamped := clampf(s, -reach[0], reach[1])
		if absf(clamped) <= road_half:
			_heights[i] = middle.y + road_tilt * clamped
		else:
			var at := middle + across * clamped
			_heights[i] = _ground.call(at.x, at.z)
	# Smooth the ground out so the train doesn't bob, leaving the road be.
	for _pass in 4:
		var smooth := _heights.duplicate()
		for i in range(1, count - 1):
			if absf(_from + i * STEP) > road_half + STEP:
				smooth[i] = _heights[i - 1] * 0.25 + _heights[i] * 0.5 + _heights[i + 1] * 0.25
		_heights = smooth


## How high the ground under the rails is, `s` metres along them from the
## middle of the road (to the right as you drive).
func height_at(s: float) -> float:
	var f := clampf((s - _from) / STEP, 0.0, _heights.size() - 1.001)
	var i := int(f)
	return lerpf(_heights[i], _heights[i + 1], f - i)


## The top of the rails at `s`, between them.
func rail_point(s: float) -> Vector3:
	var p := Vector3(middle.x, 0.0, middle.z) + across * s
	p.y = height_at(s) + RAIL_TOP
	return p


## Where along the lap the AI should have stopped by if it's waiting.
func stop_offset() -> float:
	return offset - STOP_BACK


## Spots to keep the scenery off: [from, to, half width] for each side's rails
## and tunnel.
func clear_lines() -> Array:
	var out := []
	for side: float in [-1.0, 1.0]:
		var far: float = reach[0 if side < 0.0 else 1]
		out.append([middle + across * side * road_half, middle + across * side * (far + PORTAL_DEPTH), PORTAL_WIDTH * 0.5 + 1.0])
	return out


func _ready() -> void:
	_still = Batch.new()
	_moving = Batch.new()
	_lay_rails()
	_lay_portals()
	_lay_signals()
	_lay_train()
	var box := AABB(middle, Vector3.ZERO)
	for s in [-reach[0] - PORTAL_DEPTH, reach[1] + PORTAL_DEPTH]:
		box = box.expand(rail_point(s))
	box = box.grow(PORTAL_WIDTH).expand(middle + Vector3.UP * (PORTAL_HEIGHT + 8.0))
	_still.build(self, box)
	_moving.build(self, box)
	_seen = VisibleOnScreenNotifier3D.new()
	# The crossing sits at the origin, with everything placed in world space.
	_seen.aabb = box
	add_child(_seen)
	_bell = Node3D.new()
	add_child(_bell)
	_bell.global_position = middle + Vector3.UP * 3.0
	_engine_spot = Node3D.new()
	add_child(_engine_spot)
	_update(true)


func _physics_process(delta: float) -> void:
	if own_clock:
		time += delta
	for kart in _hit_wait.keys():
		_hit_wait[kart] -= delta
		if _hit_wait[kart] <= 0.0:
			_hit_wait.erase(kart)
	_knock_karts()
	_update(false)


# The train hitting karts.

## Knocks any kart of ours the train's on.
func _knock_karts() -> void:
	var k := timetable.train_at(time)
	if k < 0:
		return
	var front := timetable.head(k, time)
	var way := float(timetable.direction(k))
	for kart in karts:
		if not is_instance_valid(kart) or kart.remote or kart.ghost_left > 0.0 or _hit_wait.has(kart):
			continue
		var d := kart.global_position - middle
		var s := d.dot(across)
		var u := s * way
		var a := d.dot(along)
		if u > front + KART_ROOM or u < front - TrainTimetable.LENGTH - KART_ROOM:
			continue
		if absf(a) > TRAIN_HALF + KART_ROOM:
			continue
		var above := kart.global_position.y - rail_point(s).y
		if above < -2.0 or above > TRAIN_HEIGHT:
			continue
		var away := along * (signf(a) if a != 0.0 else -1.0)
		kart.struck_by_train(away, across * way)
		_hit_wait[kart] = HIT_EVERY


# Drawing it.

## Moves the train, the barriers and the lamps to where they are now.
func _update(force: bool) -> void:
	var lit := timetable.lights_on(time)
	var flash := fmod(maxf(time, 0.0), 1.0) < 0.5
	var showing := (1 if flash else 2) if lit else 0
	if showing != _lamps_showing or force:
		_lamps_showing = showing
		for i in _lamps.size():
			var on := lit and ((i % 2 == 0) == flash)
			_moving.recolour(_lamps[i], LAMP_ON if on else LAMP_OFF, SceneryKit.GLOW if on else SceneryKit.PLAIN)
	if lit:
		_bell_in -= get_physics_process_delta_time()
		if not _was_lit or _bell_in <= 0.0:
			_bell_in = 0.6
			Sounds.play_at("fx/crossing_bell", _bell, -8.0)
	_was_lit = lit
	var down := timetable.barriers(time)
	var angle := lerpf(deg_to_rad(84.0), 0.0, down)
	if angle != _arm_angle or force:
		_arm_angle = angle
		for arm: Dictionary in _arms:
			var frame: Transform3D = arm.pivot * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
			_moving.place_group(arm.group, frame)
			if arm.body != null:
				arm.body.transform = frame
	_harden_arms(down)
	var k := timetable.train_at(time)
	if k < 0:
		if _train_shown or force:
			for c in _cars.size():
				_moving.hide_group(_cars[c][0])
				_car_hidden[c] = true
			_train_shown = false
		return
	var way := float(timetable.direction(k))
	var front := timetable.head(k, time)
	var window := timetable.road_window(k)
	if _horned != k and time > window.x - 3.0 and time < window.x:
		_horned = k
		_engine_spot.global_position = rail_point((front - ENGINE_LENGTH * 0.5) * way) + Vector3.UP * 2.0
		Sounds.play_at("fx/train_horn", _engine_spot, -2.0)
	if not _seen.is_on_screen() and not force:
		return
	_train_shown = true
	var back := 0.0
	for c in _cars.size():
		var length: float = _cars[c][1]
		var s := (front - back - length * 0.5) * way
		back += length + COUPLING
		var past: float = reach[1] if s > 0.0 else reach[0]
		if absf(s) > past + length * 0.5 + 2.0:
			if not _car_hidden[c]:
				_moving.hide_group(_cars[c][0])
				_car_hidden[c] = true
			continue
		_car_hidden[c] = false
		var p_front := rail_point(s + way * length * 0.35)
		var p_back := rail_point(s - way * length * 0.35)
		var forward := (p_front - p_back).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var up := right.cross(forward)
		var where := Transform3D(Basis(right, up, -forward), (p_front + p_back) * 0.5)
		_moving.place_group(_cars[c][0], where)
		if c == 0:
			_engine_spot.global_position = where.origin + Vector3.UP * 2.0


func _lay_rails() -> void:
	var start := -reach[0] - PORTAL_DEPTH * 0.6
	var end: float = reach[1] + PORTAL_DEPTH * 0.6
	var s := start
	while s < end:
		var next := minf(s + STEP, end)
		var a := rail_point(s)
		var b := rail_point(next)
		var dir := (b - a).normalized()
		var right := dir.cross(Vector3.UP).normalized()
		var basis := Basis(right, right.cross(dir), -dir)
		for side: float in [-1.0, 1.0]:
			var mid := (a + b) * 0.5 + along * side * GAUGE * 0.5 - basis.y * RAIL * 0.5
			_still.box(Transform3D(basis, mid).scaled_local(Vector3(RAIL, RAIL, a.distance_to(b) + 0.05)), STEEL, SceneryKit.PLAIN)
		s = next
	# Sleepers off the road, and a dark pad across the road between the rails.
	s = start + SLEEPER_EVERY * 0.5
	while s < end:
		if absf(s) > road_half:
			var at := rail_point(s) - Vector3.UP * (RAIL_TOP - 0.02)
			var tilt := Basis.looking_at(across, Vector3.UP)
			_still.box(Transform3D(tilt, at).scaled_local(Vector3(GAUGE + 1.6, 0.24, 0.7)), SLEEPER, SceneryKit.PLAIN)
		s += SLEEPER_EVERY
	var pad := Basis.looking_at(across, Vector3.UP)
	var pad_at := Vector3(middle.x, middle.y + 0.07, middle.z)
	_still.box(Transform3D(pad, pad_at).scaled_local(Vector3(GAUGE + 2.4, 0.14, road_half * 2.0 - 2.0)), PAD, SceneryKit.SMOOTH)


func _lay_portals() -> void:
	var rock := Color("#9c8f7f")
	var top := Props.BRIGHT_GREEN
	if Scenery.THEMES.has(track.theme):
		rock = Color(Scenery.THEMES[track.theme].get("tunnel", "#9c8f7f"))
		top = Color(Scenery.THEMES[track.theme].get("ground", "#4b9f4a"))
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	add_child(body)
	for side: float in [-1.0, 1.0]:
		var far: float = reach[0 if side < 0.0 else 1]
		var mouth := rail_point(side * far) - Vector3.UP * RAIL_TOP
		# The portal's own frame: -Z goes into the tunnel, +X across.
		var inward := across * side
		var frame := Transform3D(Basis(inward.cross(Vector3.UP).normalized(), Vector3.UP, -inward), mouth)
		var wall := (PORTAL_WIDTH - HOLE_WIDTH) * 0.5
		var sink := 4.0
		for x: float in [-1.0, 1.0]:
			_part(_still, frame, Vector3(x * (HOLE_WIDTH + wall) * 0.5, (PORTAL_HEIGHT - sink) * 0.5, -PORTAL_DEPTH * 0.5), Vector3(wall, PORTAL_HEIGHT + sink, PORTAL_DEPTH), rock, SceneryKit.BRICK)
		_part(_still, frame, Vector3(0.0, (HOLE_HEIGHT + PORTAL_HEIGHT) * 0.5, -PORTAL_DEPTH * 0.5), Vector3(HOLE_WIDTH, PORTAL_HEIGHT - HOLE_HEIGHT, PORTAL_DEPTH), rock, SceneryKit.BRICK)
		# A grassy top, a lighter frame around the hole, and dark inside.
		_part(_still, frame, Vector3(0.0, PORTAL_HEIGHT + 0.3, -PORTAL_DEPTH * 0.5), Vector3(PORTAL_WIDTH + 0.6, 0.6, PORTAL_DEPTH + 0.6), top, SceneryKit.BRICK)
		var trim := rock.lightened(0.25)
		for x: float in [-1.0, 1.0]:
			_part(_still, frame, Vector3(x * (HOLE_WIDTH * 0.5 + 0.4), HOLE_HEIGHT * 0.5, 0.25), Vector3(0.8, HOLE_HEIGHT, 0.5), trim, SceneryKit.SMOOTH)
		_part(_still, frame, Vector3(0.0, HOLE_HEIGHT + 0.4, 0.25), Vector3(HOLE_WIDTH + 1.6, 0.8, 0.5), trim, SceneryKit.SMOOTH)
		# Stepped on top like a hill, and dark inside.
		_part(_still, frame, Vector3(0.0, PORTAL_HEIGHT + 1.6, -PORTAL_DEPTH * 0.5 - 1.0), Vector3(PORTAL_WIDTH - 4.0, 2.0, PORTAL_DEPTH - 4.0), top, SceneryKit.BRICK)
		_part(_still, frame, Vector3(0.0, PORTAL_HEIGHT + 3.2, -PORTAL_DEPTH * 0.5 - 2.0), Vector3(PORTAL_WIDTH - 8.0, 1.2, PORTAL_DEPTH - 8.0), top, SceneryKit.BRICK)
		var dark := Color("#202326")
		for x: float in [-1.0, 1.0]:
			_part(_still, frame, Vector3(x * (HOLE_WIDTH * 0.5 - 0.06), HOLE_HEIGHT * 0.5, -PORTAL_DEPTH * 0.5 - 0.3), Vector3(0.1, HOLE_HEIGHT, PORTAL_DEPTH - 0.6), dark, SceneryKit.PLAIN)
		_part(_still, frame, Vector3(0.0, HOLE_HEIGHT - 0.06, -PORTAL_DEPTH * 0.5 - 0.3), Vector3(HOLE_WIDTH, 0.1, PORTAL_DEPTH - 0.6), dark, SceneryKit.PLAIN)
		_part(_still, frame, Vector3(0.0, HOLE_HEIGHT * 0.5, -PORTAL_DEPTH + 1.0), Vector3(HOLE_WIDTH, HOLE_HEIGHT, 0.4), Props.BLACK, SceneryKit.PLAIN)
		_part(_still, frame, Vector3(0.0, -0.05, -PORTAL_DEPTH * 0.5), Vector3(HOLE_WIDTH, 0.2, PORTAL_DEPTH), Color("#2a2b2d"), SceneryKit.PLAIN)
		var shape := CollisionShape3D.new()
		var block := BoxShape3D.new()
		block.size = Vector3(PORTAL_WIDTH, PORTAL_HEIGHT + sink, PORTAL_DEPTH)
		shape.shape = block
		shape.transform = frame * Transform3D(Basis.IDENTITY, Vector3(0.0, (PORTAL_HEIGHT - sink) * 0.5, -PORTAL_DEPTH * 0.5))
		body.add_child(shape)


## The four signal posts, one each side of the road either side of the rails,
## each with a crossbuck, two lamps and a striped barrier arm.
func _lay_signals() -> void:
	for before: float in [-1.0, 1.0]:
		for side: float in [-1.0, 1.0]:
			# Each post faces the traffic coming to it, with its arm reaching
			# from its side of the road to the middle.
			var facing := along * before
			var base := middle + along * before * BARRIER_AT + across * side * (track.width * 0.5 + 1.4)
			base.y = track.point_at(offset + before * BARRIER_AT).y
			var frame := Transform3D(Basis(Vector3.UP.cross(facing).normalized(), Vector3.UP, facing), base)
			_still.cylinder(Transform3D(frame.basis, base + Vector3.UP * 2.2).scaled_local(Vector3(0.36, 4.4, 0.36)), Props.WHITE, SceneryKit.SMOOTH)
			_still.cylinder(Transform3D(frame.basis, base + Vector3.UP * 0.2).scaled_local(Vector3(0.9, 0.4, 0.9)), Props.DARK_GREY, SceneryKit.SMOOTH)
			# The crossbuck, two white boards in an X.
			for lean: float in [-1.0, 1.0]:
				var board := frame.basis * Basis(Vector3.BACK, lean * PI * 0.25)
				_still.box(Transform3D(board, base + Vector3.UP * 4.0 + facing * 0.3).scaled_local(Vector3(2.4, 0.38, 0.1)), Props.WHITE, SceneryKit.SMOOTH)
				_still.box(Transform3D(board, base + Vector3.UP * 4.0 + facing * 0.24).scaled_local(Vector3(2.56, 0.5, 0.06)), Props.RED, SceneryKit.SMOOTH)
			# A black board with two lamps that flash in turn.
			_part(_still, frame, Vector3(0.0, 2.9, 0.22), Vector3(1.8, 0.7, 0.12), Props.BLACK, SceneryKit.SMOOTH)
			for x: float in [-0.55, 0.55]:
				_part(_still, frame, Vector3(x, 3.18, 0.42), Vector3(0.62, 0.1, 0.36), Props.BLACK, SceneryKit.SMOOTH)
				_lamps.append(_moving.box_index(frame * Transform3D(Basis.IDENTITY, Vector3(x, 2.9, 0.33)).scaled_local(Vector3(0.56, 0.56, 0.14)), LAMP_OFF, SceneryKit.PLAIN))
			# The arm, on a pivot by the post, reaching across the road when
			# it's down. It's drawn from its pivot, along +X.
			var toward := -across * side
			var pivot_at := base + Vector3.UP * 1.1 - facing * 0.45
			var arm_basis := Basis(toward, Vector3.UP, toward.cross(Vector3.UP).normalized())
			var pivot := Transform3D(arm_basis, pivot_at)
			var group := _moving.new_group()
			# The two arms meet in the middle of the road.
			var reach_out := track.width * 0.5 + 1.4
			var stripes := 7
			for n in stripes:
				var piece := reach_out / stripes
				_moving.box(Transform3D(Basis.IDENTITY, Vector3((n + 0.5) * piece, 0.0, 0.0)).scaled_local(Vector3(piece, 0.26, 0.14)), Props.RED if n % 2 == 0 else Props.WHITE, SceneryKit.PLAIN, group)
			_moving.box(Transform3D(Basis.IDENTITY, Vector3(-0.5, 0.0, 0.0)).scaled_local(Vector3(0.9, 0.5, 0.3)), Props.DARK_GREY, SceneryKit.PLAIN, group)
			_still.box(Transform3D(arm_basis, pivot_at - Vector3.UP * 0.55).scaled_local(Vector3(0.5, 1.1, 0.5)), Props.DARK_GREY, SceneryKit.SMOOTH)
			var arm := { "pivot": pivot, "group": group, "way_in": before < 0.0, "body": null, "shape": null, "solid": false, "broken": false }
			if arm.way_in:
				_arm_body(arm, reach_out)
			_arms.append(arm)


## The solid part of an arm on the way in: a box from the arm down to near
## the road, so it stops a kart whatever its height. It's off until the arm's
## down far enough.
func _arm_body(arm: Dictionary, length: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_HAZARD
	body.collision_mask = 0
	body.set_meta("barrier", self)
	body.set_meta("arm", _arms.size())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# A little longer than the arm, so the two overlap and nothing slips
	# between them.
	box.size = Vector3(length + 0.3, 0.95, 0.35)
	shape.shape = box
	shape.position = Vector3((length + 0.3) * 0.5, -0.33, 0.0)
	shape.disabled = true
	body.add_child(shape)
	add_child(body)
	body.transform = arm.pivot
	arm.body = body
	arm.shape = shape
	arm.length = length


## Makes the arms on the way in solid once they're all the way down, but not
## while a kart's under one, so an arm never shuts on a kart. A ghost going
## through a solid arm turns it off again until it's clear.
func _harden_arms(down: float) -> void:
	var shut := down >= SOLID_DOWN
	for arm: Dictionary in _arms:
		if arm.body == null or arm.broken:
			continue
		var want := shut and not _kart_under(arm, arm.solid)
		if want != arm.solid:
			arm.solid = want
			arm.shape.disabled = not want


## Whether a kart's in the way of an arm, or only a ghost if `ghosts_only`.
func _kart_under(arm: Dictionary, ghosts_only: bool) -> bool:
	var pivot: Transform3D = arm.pivot
	for kart in karts:
		if not is_instance_valid(kart) or (ghosts_only and kart.ghost_left <= 0.0):
			continue
		var r := _reach_of(kart) + 0.4
		var d := kart.global_position - pivot.origin
		var out := d.dot(pivot.basis.x)
		if out > -r and out < arm.length + r and absf(d.dot(pivot.basis.z)) < r:
			return true
	return false


## How far a kart's shapes reach from its middle, worked out once per kart.
func _reach_of(kart: Kart) -> float:
	if _reaches.has(kart):
		return _reaches[kart]
	var most := 1.0
	for child in kart.get_children():
		var shape := child as CollisionShape3D
		if shape == null or shape.shape == null:
			continue
		var half := 0.5
		if shape.shape is BoxShape3D:
			half = (shape.shape as BoxShape3D).size.length() * 0.5
		elif shape.shape is SphereShape3D:
			half = (shape.shape as SphereShape3D).radius
		elif shape.shape is CylinderShape3D:
			half = Vector2((shape.shape as CylinderShape3D).radius, (shape.shape as CylinderShape3D).height * 0.5).length()
		elif shape.shape is CapsuleShape3D:
			half = (shape.shape as CapsuleShape3D).height * 0.5
		most = maxf(most, Vector2(shape.position.x, shape.position.z).length() + half)
	_reaches[kart] = most
	return most


## From when the arms on the way in are solid for train `k` until they're
## not, as Vector2(from, until).
func arms_shut(k: int) -> Vector2:
	var w := timetable.road_window(k)
	var swing := TrainTimetable.BARRIER_SWING
	return Vector2(w.x - TrainTimetable.BARRIERS_BEFORE + swing * SOLID_DOWN, w.y + TrainTimetable.OPEN_AFTER + swing * (1.0 - SOLID_DOWN))


## Whether arm `arm` stops karts now.
func arm_solid(arm: int) -> bool:
	return arm >= 0 and arm < _arms.size() and _arms[arm].solid


func arm_broken(arm: int) -> bool:
	return arm >= 0 and arm < _arms.size() and _arms[arm].broken


## The arms on the way in, by number, for break_arm().
func arms_in() -> Array[int]:
	var out: Array[int] = []
	for i in _arms.size():
		if _arms[i].way_in:
			out.append(i)
	return out


## A kart going at `velocity` broke arm `arm`. Everything past the stump
## flies off as rubble (see WorldDamage), and it never stops a kart again.
## The kart's own device calls this and NetRace tells the others.
func break_arm(arm: int, velocity: Vector3) -> void:
	if arm < 0 or arm >= _arms.size() or _arms[arm].broken:
		return
	var a: Dictionary = _arms[arm]
	a.broken = true
	a.solid = false
	if a.shape != null:
		a.shape.set_deferred("disabled", true)
	var frame: Transform3D = a.pivot * Transform3D(Basis(Vector3.BACK, _arm_angle), Vector3.ZERO)
	var bits := _moving.break_off(a.group, STUMP)
	var damage := WorldDamage.in_tree(get_tree()) if is_inside_tree() else null
	if damage != null:
		for bit: Array in bits:
			bit[1] = frame * bit[1]
		damage.throw_off(bits, velocity, hash([index, arm]))
	Sounds.play_at("fx/bricks", a.body, -4.0)


## A box `size` big centred on `centre` in `frame`.
func _part(batch: Batch, frame: Transform3D, centre: Vector3, size: Vector3, colour: Color, surface: int, group := -1) -> void:
	batch.box((frame * Transform3D(Basis.IDENTITY, centre)).scaled_local(size), colour, surface, group)


## The engine and its carriages, each a group drawn from the middle of its
## wheels on the rails, front to -Z.
func _lay_train() -> void:
	var engine := _moving.new_group()
	_cars.append([engine, ENGINE_LENGTH])
	_engine(engine)
	for n in CARRIAGES.size():
		var car := _moving.new_group()
		_cars.append([car, CARRIAGE_LENGTH])
		_carriage(car, CARRIAGES[n])
	_car_hidden.resize(_cars.size())


func _engine(g: int) -> void:
	var m := _moving
	var half := ENGINE_LENGTH * 0.5
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	var axle := Basis(Vector3.BACK, PI * 0.5)
	# The frame and buffers.
	m.box(_at(Vector3(0.0, 1.05, 0.0), Vector3(2.8, 0.6, ENGINE_LENGTH)), Props.BLACK, SceneryKit.PLAIN, g)
	m.box(_at(Vector3(0.0, 1.05, -half - 0.15), Vector3(3.2, 0.7, 0.3)), Props.RED, SceneryKit.PLAIN, g)
	for x: float in [-1.1, 1.1]:
		m.cylinder(Transform3D(along_z, Vector3(x, 1.05, -half - 0.5)).scaled_local(Vector3(0.4, 0.4, 0.4)), Props.DARK_GREY, SceneryKit.PLAIN, g)
	# The cowcatcher, a yellow wedge under the front.
	m.box(Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(0.0, 0.55, -half - 0.35)).scaled_local(Vector3(2.6, 0.9, 0.9)), Props.YELLOW, SceneryKit.PLAIN, g)
	# The boiler, with yellow bands, a black smokebox and a chimney.
	m.cylinder(Transform3D(along_z, Vector3(0.0, 2.55, -1.2)).scaled_local(Vector3(2.4, 5.6, 2.4)), Props.RED, SceneryKit.PLAIN, g)
	for z in [-2.6, -0.4, 1.3]:
		m.cylinder(Transform3D(along_z, Vector3(0.0, 2.55, z)).scaled_local(Vector3(2.56, 0.28, 2.56)), Props.YELLOW, SceneryKit.PLAIN, g)
	m.cylinder(Transform3D(along_z, Vector3(0.0, 2.55, -4.3)).scaled_local(Vector3(2.5, 0.9, 2.5)), Props.BLACK, SceneryKit.PLAIN, g)
	m.cylinder(_at(Vector3(0.0, 4.1, -3.7), Vector3(0.9, 1.6, 0.9)), Props.BLACK, SceneryKit.PLAIN, g)
	m.cylinder(_at(Vector3(0.0, 4.95, -3.7), Vector3(1.3, 0.35, 1.3)), Props.BLACK, SceneryKit.PLAIN, g)
	m.cylinder(_at(Vector3(0.0, 3.85, -1.0), Vector3(1.0, 0.5, 1.0)), Props.YELLOW, SceneryKit.PLAIN, g)
	m.cylinder(_at(Vector3(0.0, 4.1, -1.0), Vector3(0.6, 0.3, 0.6)), Props.YELLOW, SceneryKit.PLAIN, g)
	# The headlamp, which shines when it's dark.
	m.box(_at(Vector3(0.0, 3.3, -4.85), Vector3(0.7, 0.55, 0.3)), Color("#fff1d6"), SceneryKit.LAMP, g)
	# The cab, with windows and a roof that sticks out.
	m.box(_at(Vector3(0.0, 2.85, 3.1), Vector3(3.2, 3.0, 3.4)), Props.RED, SceneryKit.PLAIN, g)
	m.box(_at(Vector3(0.0, 4.5, 3.1), Vector3(3.6, 0.3, 4.0)), Props.BLACK, SceneryKit.PLAIN, g)
	for x: float in [-1.62, 1.62]:
		m.box(_at(Vector3(x, 3.3, 3.0), Vector3(0.06, 1.1, 1.6)), Props.DARK_BLUE, SceneryKit.PLAIN, g)
	for x: float in [-0.8, 0.8]:
		m.box(_at(Vector3(x, 3.5, 1.38), Vector3(0.9, 0.8, 0.06)), Props.DARK_BLUE, SceneryKit.PLAIN, g)
	# Big driving wheels, red with black tires, and a rod along them.
	for x: float in [-1.3, 1.3]:
		for z in [-2.8, -0.7, 1.4]:
			m.cylinder(Transform3D(axle, Vector3(x, 0.8, z)).scaled_local(Vector3(1.6, 0.3, 1.6)), Props.BLACK, SceneryKit.PLAIN, g)
			m.cylinder(Transform3D(axle, Vector3(x * 1.03, 0.8, z)).scaled_local(Vector3(1.1, 0.32, 1.1)), Props.RED, SceneryKit.PLAIN, g)
		m.box(_at(Vector3(x * 1.1, 0.75, -0.7), Vector3(0.12, 0.18, 4.6)), Props.LIGHT_GREY, SceneryKit.PLAIN, g)
	m.cylinder(Transform3D(axle, Vector3(0.0, 0.5, 3.7)).scaled_local(Vector3(0.9, 2.7, 0.9)), Props.BLACK, SceneryKit.PLAIN, g)


func _carriage(g: int, colour: Color) -> void:
	var m := _moving
	var half := CARRIAGE_LENGTH * 0.5
	var axle := Basis(Vector3.BACK, PI * 0.5)
	m.box(_at(Vector3(0.0, 0.95, 0.0), Vector3(2.8, 0.5, CARRIAGE_LENGTH)), Props.BLACK, SceneryKit.PLAIN, g)
	m.box(_at(Vector3(0.0, 2.55, 0.0), Vector3(3.2, 2.7, CARRIAGE_LENGTH - 0.4)), colour, SceneryKit.PLAIN, g)
	m.box(_at(Vector3(0.0, 4.07, 0.0), Vector3(3.4, 0.34, CARRIAGE_LENGTH)), Props.LIGHT_GREY, SceneryKit.PLAIN, g)
	# Studs along the roof, like a real brick.
	for x: float in [-0.8, 0.8]:
		for n in 5:
			m.cylinder(_at(Vector3(x, 4.34, -half + 0.8 + n * 1.6), Vector3(0.62, 0.2, 0.62)), Props.LIGHT_GREY, SceneryKit.PLAIN, g)
	# A row of windows down each side and a door at each end.
	for x: float in [-1.62, 1.62]:
		for n in 4:
			m.box(_at(Vector3(x, 2.95, -2.7 + n * 1.8), Vector3(0.06, 1.0, 1.2)), Props.DARK_BLUE, SceneryKit.PLAIN, g)
		m.box(_at(Vector3(x, 1.75, 0.0), Vector3(0.07, 0.18, CARRIAGE_LENGTH - 0.5)), Props.WHITE, SceneryKit.PLAIN, g)
	for z in [-half + 0.18, half - 0.18]:
		m.box(_at(Vector3(0.0, 2.4, z), Vector3(1.0, 2.0, 0.06)), Props.DARK_BLUE, SceneryKit.PLAIN, g)
	# Two little wheels each side on each bogie.
	for x: float in [-1.3, 1.3]:
		for z in [-2.9, -1.9, 1.9, 2.9]:
			m.cylinder(Transform3D(axle, Vector3(x, 0.5, z)).scaled_local(Vector3(0.9, 0.3, 0.9)), Props.BLACK, SceneryKit.PLAIN, g)
	# The coupling to the car in front.
	m.box(_at(Vector3(0.0, 1.0, -half - COUPLING * 0.5), Vector3(0.4, 0.3, COUPLING + 0.2)), Props.DARK_GREY, SceneryKit.PLAIN, g)


static func _at(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, centre).scaled_local(size)


## Boxes and cylinders drawn as one MultiMesh of each, with the scenery's
## material. A shape in a group is placed from its group's transform, so a
## whole car or arm moves at once.
class Batch:
	extends RefCounted

	## [kind, transform, colour, surface, group] for each shape.
	var shapes: Array = []
	## The indices of each group's shapes, by kind.
	var groups: Array = []
	var draws := {}
	var _counts := { "box": 0, "cylinder": 0 }

	func new_group() -> int:
		groups.append({ "box": [], "cylinder": [] })
		return groups.size() - 1

	func box(where: Transform3D, colour: Color, surface: int, group := -1) -> void:
		_add("box", where, colour, surface, group)

	func cylinder(where: Transform3D, colour: Color, surface: int, group := -1) -> void:
		_add("cylinder", where, colour, surface, group)

	## Adds a box on its own and says where it is, to recolour later.
	func box_index(where: Transform3D, colour: Color, surface: int) -> int:
		return _add("box", where, colour, surface, -1)

	func _add(kind: String, where: Transform3D, colour: Color, surface: int, group: int) -> int:
		var n: int = _counts[kind]
		_counts[kind] = n + 1
		shapes.append([kind, where, colour, surface, group])
		if group >= 0:
			groups[group][kind].append([n, where, colour, surface])
		return n

	## Takes the shapes in a group further out along X than `keep` out of it
	## and hides them, and says what they were: [kind, transform in the
	## group, colour, surface].
	func break_off(group: int, keep: float) -> Array:
		var out := []
		for kind in groups[group]:
			var multi: MultiMesh = draws.get(kind)
			var stay := []
			for part: Array in groups[group][kind]:
				var where: Transform3D = part[1]
				if where.origin.x <= keep:
					stay.append(part)
					continue
				out.append([kind, where, part[2], part[3]])
				multi.set_instance_transform(part[0], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			groups[group][kind] = stay
		return out

	func build(parent: Node3D, box: AABB) -> void:
		for kind in ["box", "cylinder"]:
			var list := shapes.filter(func(s): return s[0] == kind)
			if list.is_empty():
				continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = true
			multi.use_custom_data = true
			multi.mesh = SceneryKit.mesh_for(kind)
			multi.instance_count = list.size()
			# Compatibility draws a MultiMesh everywhere unless it's told how
			# big it is.
			multi.custom_aabb = box
			for i in list.size():
				multi.set_instance_transform(i, list[i][1])
				multi.set_instance_color(i, list[i][2])
				multi.set_instance_custom_data(i, Color(float(list[i][3]), 0.0, 0.0, 0.0))
			var draw := MultiMeshInstance3D.new()
			draw.multimesh = multi
			draw.material_override = SceneryKit.material()
			parent.add_child(draw)
			draws[kind] = multi

	func place_group(group: int, where: Transform3D) -> void:
		for kind in groups[group]:
			var multi: MultiMesh = draws.get(kind)
			for part in groups[group][kind]:
				multi.set_instance_transform(part[0], where * part[1])

	func hide_group(group: int) -> void:
		for kind in groups[group]:
			var multi: MultiMesh = draws.get(kind)
			for part in groups[group][kind]:
				multi.set_instance_transform(part[0], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

	func recolour(i: int, colour: Color, surface: int) -> void:
		var multi: MultiMesh = draws.get("box")
		multi.set_instance_color(i, colour)
		multi.set_instance_custom_data(i, Color(float(surface), 0.0, 0.0, 0.0))
