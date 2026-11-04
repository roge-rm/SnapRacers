class_name Podium
extends Node3D

## The podium at the end of a Grand Prix, put up on the cup's last course
## once the karts are cleared away (see Race.show_podium()).
##
## Three stepped blocks in the cup's colour with 1, 2 and 3 on their fronts,
## built from the same bricks as the rest of the scenery. The top three stand
## on them with their karts parked in front, and everyone else stands in a row
## either side. The camera sweeps in and then holds still.
##
## As it does, third, second and first jump up onto their steps, the cup's
## trophy comes down from above to the winner, who holds it up, and confetti
## falls in the cup's colours to a fanfare and a cheer. The rest of the
## field clap, except the last few, who sulk. A player who isn't on the
## steps stands at the front of the crowd with their place over them. Once it's over, or on a tap,
## a key or the skip button in the top left, `finished` is sent, and
## everything jumps to how it ends.
##
## It's laid out in its own space with the front facing +Z, and turned a
## whole number of quarter turns, like every prop, so the brick patterns
## line up with the world's.

signal finished

## How wide and deep each step is, and how tall, first, second and third.
const STEP_WIDTH := 1.5
const STEP_DEPTH := 1.3
const HEIGHTS := [0.8, 0.56, 0.38]
## Across from the middle, in the steps' widths, first, second and third.
const ACROSS := [0.0, -1.0, 1.0]
## The size of a square of the numbers on the fronts, which are 3 by 5.
const PIXEL := 0.06
## How far each kart is turned in from straight ahead, in degrees.
const TURNED := [0.0, -25.0, 25.0]
## How thick the plate under it all is, and its colour.
const BASE := 0.12
const BASE_COLOUR := Color("#a3a2a4")
## The gap between the people standing in the rows either side.
const SPACING := 0.6
## How far forward a player off the steps stands, in front of the rows, and
## how far over their hips their place tag sits.
const FRONT := 2.6
const TAG_HIGH := 0.75
## The tags are drawn under the standings, which are on layer 10.
const TAG_LAYER := 5
## How much of the screen's height is kept clear at the top and bottom when
## the camera fits everyone in.
const EDGE := 0.04
## How much room it needs around its middle, and how far from the middle its
## camera ends up at most.
const ROOM := 6.0
const CAMERA_OUT := 9.0
## How far back the camera can go on a narrow screen to fit everyone.
const CAMERA_FAR := 22.0
## How long taps and keys are ignored after it goes up, so a double tap on
## the last screen doesn't skip it.
const IGNORE_INPUT := 0.7
## The lamp over it after dark.
const LAMP_ENERGY := 3.0
const LAMP_RANGE := 10.0
## The camera's sweep in, then how long it holds still before `finished`.
const SWEEP := 4.0
const HOLD := 6.0
## How long the show runs before the standings come up, if nobody skips it.
const LENGTH := SWEEP + HOLD
## The show, in seconds after it goes up: when first, second and third jump
## onto their steps, and how long a jump takes. Before it they stand on the
## plate in front.
const LEAPS := [2.8, 2.0, 1.2]
const LEAP := 0.6
const WAITING := 0.75
## When the trophy starts down, when the winner's arms go up for it and
## when it's in their hand.
const TROPHY_FROM := 3.8
const REACH := 4.9
const TROPHY_IN := 5.6
## How high over the hand the trophy starts, how tall it is in the hand
## (a little taller than a head), how wide it can be there so it clears the
## head, and how big it can be next to the full size one.
const TROPHY_HIGH := 3.0
const TROPHY_TALL := 0.45
const TROPHY_WIDE := 0.25
const TROPHY_MOST := 0.26
## The bar under the trophy's plinth that sits in the winner's hand, in
## metres: its radius, a little under the hand's hole, its length and how
## far down it the hand holds.
const BAR_RADIUS := 0.016
const BAR_LENGTH := 0.075
const BAR_GRIP := 0.04
## A cup this light gets coloured trim on its steps and mixed confetti, so
## they show up against snow.
const VERY_LIGHT := 0.85
const TRIM := Color("#c4281c")
const MIXED := [Color("#c4281c"), Color("#0d69ab"), Color("#f5cd2f"), Color("#4b974b"), Color("#e04da0"), TrophyModel.GOLD]
## How loud the cheer is when it's skipped to over the fanfare.
const CHEER_SKIPPED := -4.0
## How many at the back of the field sulk.
const SULKING := 2
## When the fanfare starts.
const FANFARE := 0.3
## How long the confetti keeps coming once the trophy's in hand, how many
## bits are falling at once and how long each falls for.
const CONFETTI_FOR := 4.0
const CONFETTI := 260
const CONFETTI_LIFE := 4.5
## How long the camera takes to move over for the standings (see settle()).
const SETTLE := 0.8
## How much of the clear part's width the steps and karts fill then, and how
## high over the top step the camera is.
const SETTLE_FILL := 0.88
const SETTLE_HIGH := 3.5
## How tall a number is, row by row from the top, for 1, 2 and 3.
const DIGITS := {
	1: ["010", "110", "010", "010", "111"],
	2: ["111", "001", "111", "100", "111"],
	3: ["111", "001", "011", "001", "111"],
}
const DARK := Color("#1b2a34")

## Everyone, winner first, each [name, KartDesign, CharacterDesign].
var order: Array = []
var colour := Color("#c4281c")
## Where it stands: the middle of the ground under the steps, and how many
## quarter turns its front is turned from +Z.
var middle := Vector3.ZERO
var facing := 0
## How high the ground is anywhere (TrackBuilder.ground_at()), or null for
## level with `middle` all round, as on the road.
var ground: Variant = null
## The people playing, by name, with the colour their place tag is in,
## player 1 first. Set it before it goes into the scene.
var players := {}
## The place tags over the players off the steps, by place from 0.
var tags := {}
## The small skip button in the top left, gone once the show's over.
var skip_button: IconButton
## Each place's driver and kart, first place first, then the rest.
var drivers: Array[CharacterRig] = []
var karts: Array[Node3D] = []
var camera: Camera3D
## After dark it has a lamp over it. Set it before it goes into the scene.
var lit := false
## The cup's trophy, its "trophy" entry like { "top": "gear" }, and the colour
## of its plate. Set them before it goes into the scene.
var trophy_spec := {}
var trophy_colour := Color("#c4281c")
## The trophy once it's on its way down, and the confetti.
var trophy: Node3D
var confetti: CPUParticles3D
## The trophy's size next to the full size one, and the point on it, in its
## own space, that's in the winner's hand: the middle of the bar under it.
var trophy_size := 0.22
var trophy_grip := Vector3.ZERO
## Where first, second and third stand on their steps, in the world.
var _on_step: Array[Vector3] = []
## How far through the show it's got: who's jumped and reacted, whether the
## field are going, the trophy's in hand, and the sounds have played.
var _leapt := [false, false, false]
var _reacted := [false, false, false]
var _field := false
var _reached := false
var _landed := false
var _fanfare := false
## The fanfare and cheer, on the podium so they stop when it goes.
var _fanfare_player: AudioStreamPlayer
var _cheered := false
## When the confetti stops, in the show's time.
var _confetti_until := INF
var _time := 0.0
var _from: Transform3D
var _to: Transform3D
var _done := false
## How far out to the sides everything reaches.
var _reach := 0.0
## What the camera looks at, and how high it stands, in the podium's space.
var _look := Vector3.ZERO
var _top := 0.0
## How long since settle(), or -1 before it, and the camera's sideways
## shift then and at the end.
var _settled := -1.0
var _shift_from := 0.0
var _shift_to := 0.0
var _clear := 1.0


func _init(everyone: Array, cup_colour: Color, spot: Array, ground_at: Variant = null) -> void:
	name = "Podium"
	order = everyone
	colour = cup_colour
	middle = spot[0]
	facing = spot[1]
	ground = ground_at if spot.size() < 3 or spot[2] else null


## The cup's colour, from its entry in the cups file, or red for one that
## hasn't got one.
static func colour_of(cup: Dictionary) -> Color:
	return Color(str(cup.get("colour", "#c4281c")))


## Where the podium goes, as [middle, quarter turns, whether it's on the
## ground]: on clear, flat ground beside the road near the start line, facing
## the road, with small things there cleared away. Failing that, on the start
## straight just past the line.
static func find_spot(track: TrackPath, builder: TrackBuilder) -> Array:
	var scenery: Scenery = null
	for child in builder.get_children():
		if child is Scenery:
			scenery = child
	if scenery != null:
		var best := []
		var best_score := -INF
		for step in range(-10, 11):
			var along := step * 6.0
			var frame := track.frame_at(fposmod(along, track.length))
			for side in [1.0, -1.0]:
				var out: Vector3 = frame.basis.x * side
				out.y = 0.0
				out = out.normalized()
				for extra in range(0, 30, 3):
					var at := frame.origin + out * (track.width * 0.5 + ROOM + 8.0 + extra)
					at.y = builder.ground_at(at.x, at.z)
					var clutter := scenery.clutter_at(at, ROOM)
					if clutter < 0:
						continue
					var turns := _turns_toward(-out)
					var front := _turned(Vector3.BACK, turns)
					var view := scenery.clutter_at(at + front * CAMERA_OUT, 2.0, false)
					if view < 0:
						continue
					var spread := _bumpiness(at, builder.ground_at)
					if spread > 1.2:
						continue
					var score := -clutter * 1.5 - view - absf(along) * 0.12 - extra * 0.25 - spread * 4.0
					if score > best_score:
						best_score = score
						best = [at, turns, true]
		if not best.is_empty():
			for damage in builder.get_tree().get_nodes_in_group("world_damage"):
				damage.clear_around(best[0], ROOM + 1.0)
				damage.clear_around(best[0] + _turned(Vector3.BACK, best[1]) * CAMERA_OUT, 2.5)
			return best
	# On the road, facing back along it toward the line.
	var frame := track.frame_at(minf(30.0, track.length * 0.25))
	return [frame.origin, _turns_toward(frame.basis.z), false]


## The quarter turn whose front (+Z at none) points most along `dir`.
static func _turns_toward(dir: Vector3) -> int:
	if absf(dir.x) > absf(dir.z):
		return 1 if dir.x > 0.0 else 3
	return 0 if dir.z > 0.0 else 2


static func _turned(v: Vector3, turns: int) -> Vector3:
	return v.rotated(Vector3.UP, turns * PI * 0.5)


## How far up and down the ground goes across the podium's footprint.
static func _bumpiness(at: Vector3, ground_at: Callable) -> float:
	var low := INF
	var high := -INF
	for x in [-1.0, 0.0, 1.0]:
		for z in [-1.0, 0.0, 1.0]:
			var h: float = ground_at.call(at.x + x * ROOM * 0.7, at.z + z * ROOM * 0.7)
			low = minf(low, h)
			high = maxf(high, h)
	return high - low


func _ready() -> void:
	var kit := SceneryKit.new()
	# The steps sit as high as the ground is on average under them and reach
	# down into it, so none float on a slope.
	var top := 0.0
	var bottom := INF
	for x in [-1.5, 0.0, 1.5]:
		for z in [-0.5, 0.5]:
			var h := _ground_at(Vector3(x * STEP_WIDTH, 0.0, z * STEP_DEPTH))
			top += h / 6.0
			bottom = minf(bottom, h)
	bottom -= 0.3
	# A light grey plate under it all, so it stands out from the ground.
	# A pale cup's steps stand on a dark one instead, and get dark numbers.
	var pale := colour.get_luminance() > 0.6
	_box(kit, Vector3(0.0, bottom, 0.0), Vector3(STEP_WIDTH * 3.0 + 0.6, top - bottom + BASE, STEP_DEPTH + 0.6), DARK if pale else BASE_COLOUR, SceneryKit.BRICK)
	top += BASE
	var ink := DARK if pale else Color.WHITE
	for place in 3:
		var x: float = ACROSS[place] * STEP_WIDTH
		var height: float = top + HEIGHTS[place]
		_box(kit, Vector3(x, bottom, 0.0), Vector3(STEP_WIDTH, height - bottom, STEP_DEPTH), _step_tint(), SceneryKit.BRICK)
		if colour.get_luminance() > VERY_LIGHT:
			# A band round the top, standing a little proud of the sides.
			_box(kit, Vector3(x, height - 0.1, 0.0), Vector3(STEP_WIDTH + 0.03, 0.08, STEP_DEPTH + 0.03), TRIM, SceneryKit.PLAIN)
		_number(kit, place + 1, Vector3(x, height - HEIGHTS[place] * 0.5, STEP_DEPTH * 0.5), ink)
	kit.build(self)

	# The winner parks in the centre foreground, with second and third
	# angled out either side.
	var spots := _parking()
	_reach = STEP_WIDTH * 1.5 + 0.6
	var in_row := 0
	for place in order.size():
		var entry: Array = order[place]
		var rig := CharacterRig.new(entry[2], false)
		rig.lively = true
		rig.idle = false
		rig.name = "Driver%d" % (place + 1)
		var feet := Vector3.ZERO
		if place < 3:
			# On the plate in front of their step, to jump up later.
			var step := Vector3(ACROSS[place] * STEP_WIDTH, top + HEIGHTS[place], 0.0)
			_on_step.append(_placed(step + Vector3.UP * CharacterRig.FEET_BELOW, 0.0).origin)
			feet = Vector3(step.x, top, WAITING)
		elif players.has(entry[0]):
			# Player 1 on the left, player 2 on the right.
			feet = _in_front(-1.0 if players.keys().find(entry[0]) == 0 else 1.0)
			feet.y = _ground_at(feet)
		else:
			feet = _in_row(in_row)
			in_row += 1
			feet.y = _ground_at(feet)
			_reach = maxf(_reach, absf(feet.x) + 0.4)
		rig.transform = _placed(feet + Vector3.UP * CharacterRig.FEET_BELOW, 0.0)
		add_child(rig)
		drivers.append(rig)
		if place < 3:
			var kart := KartModel.make(entry[1], entry[2], false)
			kart.name = "Kart%d" % (place + 1)
			var box := KartModel.bounds(entry[1])
			var middle_at: Vector3 = spots[place][0]
			var where := _placed(middle_at, deg_to_rad(spots[place][1]))
			# The box's middle over the spot, and its bottom on the ground.
			var centre := box.get_center()
			where.origin -= where.basis * Vector3(centre.x, 0.0, centre.z)
			where.origin.y = _ground_at(middle_at) - box.position.y
			kart.transform = where
			add_child(kart)
			karts.append(kart)
			_reach = maxf(_reach, absf(middle_at.x) + _radius(box) + 0.3)

	if lit:
		var lamp := OmniLight3D.new()
		lamp.light_color = CourseLamps.COLOUR
		lamp.light_energy = LAMP_ENERGY
		lamp.omni_range = LAMP_RANGE
		lamp.shadow_enabled = false
		lamp.transform = _placed(Vector3(0.0, top + 3.5, 2.5), 0.0)
		add_child(lamp)

	var layer := CanvasLayer.new()
	layer.name = "Tags"
	layer.layer = TAG_LAYER
	add_child(layer)
	for place in range(3, order.size()):
		if players.has(order[place][0]):
			tags[place] = _make_tag(place, players[order[place][0]])
			# Hidden until the camera's set and it's placed.
			tags[place].visible = false
			layer.add_child(tags[place])

	# The skip button, clear of any camera hole.
	var corner := CanvasLayer.new()
	corner.name = "Skip"
	corner.layer = TAG_LAYER
	add_child(corner)
	skip_button = IconButton.new("skip")
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	skip_button.position = Vector2(24.0, 16.0)
	skip_button.pressed.connect(skip)
	corner.add_child(skip_button)
	var safe := SafeArea.new()
	corner.add_child(safe)
	safe.watch(skip_button)

	confetti = _make_confetti(top)
	add_child(confetti)
	Sounds.music("")

	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.05
	add_child(camera)
	_top = top
	_look = Vector3(0.0, top + 0.7, -0.4)
	var out := _seeing_all(_camera_distance(), top + SETTLE_HIGH)
	_to = _looking(Vector3(0.0, top + SETTLE_HIGH, out), _look)
	var start := Vector3(0.0, top + 7.0, out * 1.8).rotated(Vector3.UP, deg_to_rad(50.0))
	_from = _looking(start, _look)
	camera.global_transform = _from
	camera.make_current()
	_place_tags()


## How far a kart's box reaches from its middle however it's turned.
func _radius(box: AABB) -> float:
	return Vector2(box.size.x, box.size.z).length() * 0.5


## Where each of the three karts is parked, [middle, yaw in degrees], first
## place first. Each is turned in toward the camera.
func _parking() -> Array:
	var r: Array = []
	for place in 3:
		r.append(_radius(KartModel.bounds(order[place][1])) if place < order.size() else 1.0)
	var side := maxf(STEP_WIDTH * 1.5 + 0.4, r[0] + maxf(r[1], r[2]) + 0.4)
	var forward := STEP_DEPTH * 0.5 + maxf(r[1], r[2]) + 0.4
	var second := Vector3(-side, 0.0, forward)
	var third := Vector3(side, 0.0, forward)
	var first := Vector3(0.0, 0.0, forward + r[0] * 0.5)
	return [[first, TURNED[0]], [second, TURNED[1]], [third, TURNED[2]]]


## Where the `n`th of the rest of the field stands, by turns either side of
## the steps, the nearest first.
func _in_row(n: int) -> Vector3:
	var side := -1.0 if n % 2 == 0 else 1.0
	return Vector3(side * (STEP_WIDTH * 1.5 + 0.5 + (n / 2) * SPACING), 0.0, -STEP_DEPTH * 0.5 - 0.9)


## Where a player off the steps stands, on the left or right.
func _in_front(side: float) -> Vector3:
	var forward := FRONT
	var spots := _parking()
	for place in mini(order.size(), 3):
		forward = maxf(forward, spots[place][0].z + _radius(KartModel.bounds(order[place][1])) + 0.6)
	return Vector3(side * (STEP_WIDTH * 1.5 + 0.2), 0.0, forward)


## A place tag like "5th" in the player's colour.
func _make_tag(place: int, tint: Color) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.name = "Tag%d" % (place + 1)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", UiKit.pad(UiKit.slant(tint), 14, 2, UiKit.LEAN, 36.0))
	var label := Label.new()
	label.text = RaceHud.ordinal(place + 1)
	label.add_theme_font_override("font", UiKit.font("heading"))
	label.add_theme_font_size_override("font_size", UiKit.LEAD)
	label.add_theme_color_override("font_color", UiKit.INK)
	tag.add_child(label)
	return tag


## Where the top of a player's tag is in the world.
func _tag_point(place: int) -> Vector3:
	return drivers[place].global_position + Vector3.UP * TAG_HIGH


## Keeps each tag over its player's head, hidden when they're off screen or
## it would be under the standings.
func _place_tags() -> void:
	if tags.is_empty():
		return
	var view := get_viewport().get_visible_rect().size
	for place in tags:
		var tag: Control = tags[place]
		var at := _tag_point(place)
		var size := tag.get_combined_minimum_size()
		var point := camera.unproject_position(at)
		tag.size = size
		tag.position = (point - Vector2(size.x * 0.5, size.y)).round()
		# Kept on screen sideways while their head is.
		tag.position.x = clampf(tag.position.x, 0.0, view.x - size.x)
		var box := Rect2(tag.position, size)
		var shown := not camera.is_position_behind(at) and Rect2(Vector2.ZERO, view).has_point(point) and box.position.y >= 0.0
		if _settled >= 0.0 and (_clear >= 1.0 or box.end.x > view.x * _clear):
			shown = false
		tag.visible = shown


## How far out the camera stops, so everyone fits across the screen, or
## across the part of its width that's `clear` from the left.
func _camera_distance(clear := 1.0) -> float:
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16.0, 9.0)
	var aspect := size.x * clear / maxf(size.y, 1.0)
	var across := atan(tan(deg_to_rad(camera.fov) * 0.5) * aspect)
	var near := STEP_DEPTH
	var spots := _parking()
	for place in karts.size():
		near = maxf(near, spots[place][0].z + _radius(KartModel.bounds(order[place][1])))
	var out := _reach / tan(across) * 1.1 + near
	# The players in front are nearer the camera, so they need more room.
	for place in tags:
		var local := _in_front(-1.0)
		out = maxf(out, (absf(local.x) + 0.5) / tan(across) * 1.1 + local.z)
	return minf(out, CAMERA_FAR)


## `out`, or further out if that leaves anyone in front, or their tag, off
## the top or bottom of the screen, with the camera at `high`.
func _seeing_all(out: float, high: float) -> float:
	var points := _core_points() + _front_points()
	if points.is_empty() or not is_inside_tree():
		return out
	var was := camera.global_transform
	var height := get_viewport().get_visible_rect().size.y
	while out < CAMERA_FAR:
		camera.global_transform = _looking(Vector3(0.0, high, out), _look)
		var fits := true
		for p in points:
			var y := camera.unproject_position(p).y
			fits = fits and y > height * EDGE and y < height * (1.0 - EDGE)
		if fits:
			break
		out = minf(out + 0.25, CAMERA_FAR)
	camera.global_transform = was
	return out


## The feet of the players off the steps and the tops of their tags.
func _front_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for place in tags:
		points.append(drivers[place].global_position - Vector3.UP * CharacterRig.FEET_BELOW)
		# The tag's top corners, roughly, as it's wider than a head.
		var across := _turned(Vector3.RIGHT, facing) * 0.35
		points.append(_tag_point(place) + Vector3.UP * 0.15 - across)
		points.append(_tag_point(place) + Vector3.UP * 0.15 + across)
	return points


## The ground's height at a point in the podium's own space, in the world.
func _ground_at(local: Vector3) -> float:
	if ground == null:
		return middle.y
	var at := middle + _turned(local, facing)
	return (ground as Callable).call(at.x, at.z)


## A transform in the world for a point in the podium's own space, facing
## its front, turned `yaw` more.
func _placed(local: Vector3, yaw: float) -> Transform3D:
	var at := middle + _turned(Vector3(local.x, 0.0, local.z), facing)
	at.y = local.y
	# Drivers and karts face -Z, so they're turned around to face the front.
	return Transform3D(Basis(Vector3.UP, PI + facing * PI * 0.5 + yaw), at)


func _looking(local: Vector3, at: Vector3) -> Transform3D:
	var from := middle + _turned(Vector3(local.x, 0.0, local.z), facing)
	from.y = local.y
	var to := middle + _turned(Vector3(at.x, 0.0, at.z), facing)
	to.y = at.y
	return Transform3D.IDENTITY.translated(from).looking_at(to, Vector3.UP)


## A box in the podium's own space standing on `bottom`.
func _box(kit: SceneryKit, bottom: Vector3, size: Vector3, tint: Color, surface: int) -> void:
	var at := middle + _turned(Vector3(bottom.x, 0.0, bottom.z), facing)
	at.y = bottom.y
	var turned := size if facing % 2 == 0 else Vector3(size.z, size.y, size.x)
	kit.box(at, turned, tint, surface, false)


## A number on a step's front, its middle at `at`, in squares standing a
## little proud of it.
func _number(kit: SceneryKit, n: int, at: Vector3, ink: Color) -> void:
	var rows: Array = DIGITS[n]
	for row in rows.size():
		for column in 3:
			if rows[row][column] != "1":
				continue
			var square := at + Vector3((column - 1) * PIXEL, (2 - row) * PIXEL - PIXEL * 0.5, 0.01)
			_box(kit, square, Vector3(PIXEL, PIXEL, 0.04), ink, SceneryKit.PLAIN)


func _process(delta: float) -> void:
	_time += delta
	_run_show()
	if _time >= _confetti_until:
		confetti.emitting = false
	if _settled >= 0.0:
		_settled += delta
		var s := clampf(_settled / SETTLE, 0.0, 1.0)
		var smooth := s * s * (3.0 - 2.0 * s)
		var turned := _from.basis.get_rotation_quaternion().slerp(_to.basis.get_rotation_quaternion(), smooth)
		camera.global_transform = Transform3D(Basis(turned), _from.origin.lerp(_to.origin, smooth))
		camera.h_offset = lerpf(_shift_from, _shift_to, smooth)
		_place_tags()
		return
	var t := clampf(_time / SWEEP, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var from := _from.origin.lerp(_to.origin, eased)
	var turn := _from.basis.get_rotation_quaternion().slerp(_to.basis.get_rotation_quaternion(), eased)
	camera.global_transform = Transform3D(Basis(turn), from)
	_place_tags()
	if _time >= SWEEP + HOLD:
		finish()


## Moves the show on to where it should be by now.
func _run_show() -> void:
	if _done:
		return
	if not _fanfare and _time >= FANFARE:
		_fanfare = true
		_fanfare_player = _play("fx/podium")
	for place in _on_step.size():
		if not _leapt[place] and _time >= LEAPS[place]:
			_leap(place, false)
		if _leapt[place] and not _reacted[place] and _time >= LEAPS[place] + LEAP + 0.05:
			_react(place)
	if not _field and _time >= LEAPS.min():
		_start_field()
	if order.is_empty():
		return
	if trophy == null and _time >= TROPHY_FROM:
		_make_trophy()
	if not _reached and _time >= REACH:
		_reached = true
		drivers[0].raise_arms()
	if trophy != null and not _landed:
		if _time >= TROPHY_IN:
			_land(false)
		else:
			# Down from above, slowing, and spinning round to face the front.
			var s := clampf((_time - TROPHY_FROM) / (TROPHY_IN - TROPHY_FROM), 0.0, 1.0)
			var eased := 1.0 - (1.0 - s) * (1.0 - s)
			var to := _trophy_in_hand()
			var spin := Basis(Vector3.UP, (1.0 - eased) * TAU * 1.5)
			trophy.global_transform = Transform3D(spin * to.basis, to.origin + Vector3.UP * TROPHY_HIGH * (1.0 - eased))


## Everything at once, as the show ends: the top three up on their steps,
## the winner holding the trophy, the field clapping and sulking and the
## confetti coming down.
func _end_show() -> void:
	_fanfare = true
	for place in _on_step.size():
		_leap(place, true)
		if not _reacted[place]:
			_react(place)
	_start_field()
	if order.is_empty():
		return
	if trophy == null:
		_make_trophy()
	_reached = true
	if not _landed:
		_land(true)


func _leap(place: int, now: bool) -> void:
	_leapt[place] = true
	var rig := drivers[place]
	if now:
		rig.leap(_on_step[place], 0.0)
	elif rig.position.distance_to(_on_step[place]) > 0.01:
		rig.leap(_on_step[place], LEAP)


## Once up on their step: second and third clap, and the winner cheers
## until the trophy comes.
func _react(place: int) -> void:
	_reacted[place] = true
	var rig := drivers[place]
	if place == 0:
		if not _reached:
			rig.cheer(REACH - _time)
	else:
		rig.clap(INF)


## The rest of the field clap, and the last few sulk.
func _start_field() -> void:
	if _field:
		return
	_field = true
	for place in range(3, drivers.size()):
		if place >= drivers.size() - SULKING:
			drivers[place].sulk(INF)
		else:
			drivers[place].clap(INF)


func _make_trophy() -> void:
	trophy = TrophyModel.make(trophy_spec, trophy_colour, "gold")
	var box := AABB()
	for piece in TrophyModel.pieces(trophy_spec, trophy_colour, "gold"):
		box = box.merge(piece.box)
	trophy_size = minf(minf(TROPHY_TALL / box.end.y, TROPHY_WIDE / box.size.x), TROPHY_MOST)
	trophy.scale = Vector3.ONE * trophy_size
	# A bar down from the middle of the plinth for the hand to hold, the way
	# a toy figure's trophy plugs into its hand.
	var bar := MeshInstance3D.new()
	bar.name = "Bar"
	var rod := CylinderMesh.new()
	rod.top_radius = BAR_RADIUS / trophy_size
	rod.bottom_radius = rod.top_radius
	rod.height = BAR_LENGTH / trophy_size
	bar.mesh = rod
	bar.material_override = PartVisuals.material(TrophyModel.PLINTH)
	bar.position.y = -rod.height * 0.5
	trophy.add_child(bar)
	trophy_grip = Vector3(0.0, -BAR_GRIP / trophy_size, 0.0)
	add_child(trophy)
	var to := _trophy_in_hand()
	trophy.global_transform = Transform3D(to.basis, to.origin + Vector3.UP * TROPHY_HIGH)


## Where the trophy is once the winner's holding it up.
func _trophy_in_hand() -> Transform3D:
	return drivers[0].hold_transform(Vector3.ONE * trophy_size, trophy_grip)


## The trophy into the winner's hand, with confetti and a cheer.
func _land(now: bool) -> void:
	_landed = true
	trophy.scale = Vector3.ONE * trophy_size
	drivers[0].hold(trophy, trophy_grip, now)
	confetti.emitting = true
	_confetti_until = _time + CONFETTI_FOR
	_cheer(now)


## The crowd cheers, once. Skipped to while the fanfare's still going, the
## fanfare stops and the cheer comes in a little quieter.
func _cheer(skipped: bool) -> void:
	if _cheered:
		return
	_cheered = true
	var level := 0.0
	if skipped and is_instance_valid(_fanfare_player) and _fanfare_player.playing:
		_fanfare_player.stop()
		level = CHEER_SKIPPED
	_play("fx/cheer", level)


## Plays a sound once on the podium itself, so it stops when the podium's
## freed.
func _play(sound: String, level := 0.0) -> AudioStreamPlayer:
	var stream := Sounds.stream(sound)
	if stream == null or Sounds.hushed or not Sounds.audible():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = Sounds.EFFECTS_BUS
	player.volume_db = level
	player.finished.connect(player.queue_free)
	player.autoplay = true
	add_child(player)
	return player


## The steps' colour: the cup's, or a little darker for a very light cup.
func _step_tint() -> Color:
	return colour.darkened(0.25) if colour.get_luminance() > VERY_LIGHT else colour


## Confetti over the steps, in the cup's colours with white and gold, each
## bit fluttering as it falls. It starts once the trophy's in hand.
func _make_confetti(top: float) -> CPUParticles3D:
	var bits := CPUParticles3D.new()
	bits.name = "Confetti"
	bits.emitting = false
	bits.amount = CONFETTI
	bits.lifetime = CONFETTI_LIFE
	bits.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bits.emission_box_extents = Vector3(STEP_WIDTH * 2.0, 0.2, 1.4)
	bits.direction = Vector3.UP
	bits.spread = 70.0
	bits.initial_velocity_min = 0.4
	bits.initial_velocity_max = 1.6
	# Falling against the air, so they drift down slowly.
	bits.gravity = Vector3(0.0, -2.4, 0.0)
	bits.damping_min = 1.4
	bits.damping_max = 1.9
	bits.particle_flag_rotate_y = true
	bits.angle_min = -180.0
	bits.angle_max = 180.0
	bits.angular_velocity_min = -540.0
	bits.angular_velocity_max = 540.0
	bits.scale_amount_min = 0.7
	bits.scale_amount_max = 1.2
	var shape := QuadMesh.new()
	shape.size = Vector2(0.11, 0.07)
	var paper := StandardMaterial3D.new()
	paper.vertex_color_use_as_albedo = true
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.roughness = 0.8
	paper.metallic_specular = 0.2
	shape.material = paper
	bits.mesh = shape
	var colours := Gradient.new()
	colours.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colours.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8])
	colours.colors = PackedColorArray([colour, Color.WHITE, TrophyModel.GOLD, colour.lightened(0.4)])
	if colour.get_luminance() > VERY_LIGHT:
		colours.offsets = PackedFloat32Array(range(MIXED.size()).map(func(i): return float(i) / MIXED.size()))
		colours.colors = PackedColorArray(MIXED)
	bits.color_initial_ramp = colours
	bits.transform = _placed(Vector3(0.0, top + 2.8, 0.4), 0.0)
	return bits


## Skips to the end, unless it only just went up.
func skip() -> void:
	if _time >= IGNORE_INPUT:
		finish()


## Skips to the end.
func finish() -> void:
	if _done:
		return
	_end_show()
	_done = true
	if is_instance_valid(skip_button):
		skip_button.get_parent().queue_free()
		skip_button = null
	finished.emit()


## Moves the camera from wherever it is to hold still on everyone, fitted
## into the part of the screen's width that's `clear` from the left, for the
## standings over the rest.
func settle(clear := 1.0) -> void:
	finish()
	_clear = clear
	_from = camera.global_transform
	_shift_from = camera.h_offset
	_aim()
	_settled = 0.0
	if not get_viewport().size_changed.is_connected(_resized):
		get_viewport().size_changed.connect(_resized)


func _exit_tree() -> void:
	var port := get_viewport()
	if port != null and port.size_changed.is_connected(_resized):
		port.size_changed.disconnect(_resized)


## Fits the camera again for the window's new size, without moving it on.
func _resized() -> void:
	if _settled < 0.0:
		return
	_from = camera.global_transform
	_shift_from = camera.h_offset
	_aim()
	_settled = SETTLE
	camera.global_transform = _to
	camera.h_offset = _shift_to


## Works out where the camera ends up, `_to` and `_shift_to`, for the
## screen's size now.
func _aim() -> void:
	# Close enough that the steps, karts and any players in front fill most of
	# the clear part. The rows either side can go off its edges.
	var points := _core_points() + _front_points()
	var was_shift := camera.h_offset
	var fit := _fit(points, _top + SETTLE_HIGH)
	var out := _seeing_all(fit[0], _top + SETTLE_HIGH)
	if out > fit[0]:
		fit = _fit(points, _top + SETTLE_HIGH, out)
	camera.h_offset = was_shift
	_to = _looking(Vector3(0.0, _top + SETTLE_HIGH, fit[0]), _look)
	_shift_to = fit[1]


## The corners of the steps and the parked karts, in the world.
func _core_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for x in [-1.5, 1.5]:
		for z in [-0.5, 0.5]:
			points.append(_placed(Vector3(x * STEP_WIDTH, _top, z * STEP_DEPTH), 0.0).origin)
	for place in karts.size():
		var box := KartModel.bounds(order[place][1])
		for i in 8:
			points.append(karts[place].global_transform * box.get_endpoint(i))
	return points


## How far out the camera goes in front of the steps, at `high`, so `points`
## fill most of the clear part of the screen's width, or `out` if it's given,
## and how far it's shifted sideways to put their middle in the clear part's
## middle without turning. Measured through the camera, as the karts are
## in front of the steps, and a sideways shift moves
## nearer things more.
func _fit(points: Array[Vector3], high: float, out := -1.0) -> Array:
	var was := camera.global_transform
	var size := get_viewport().get_visible_rect().size
	var half_across := tan(deg_to_rad(camera.fov) * 0.5) * size.x / maxf(size.y, 1.0)
	var fixed := out > 0.0
	if not fixed:
		out = CAMERA_OUT
	var shift := 0.0
	# How near the camera the nearest of them are, which the scaling turns on.
	var near := STEP_DEPTH if tags.is_empty() else FRONT + 0.3
	for i in 8:
		camera.global_transform = _looking(Vector3(0.0, high, out), _look)
		camera.h_offset = shift
		var low := INF
		var top := -INF
		for p in points:
			var x := camera.unproject_position(p).x
			low = minf(low, x)
			top = maxf(top, x)
		var centre := (low + top) / size.x - 1.0
		var away := camera.global_position.distance_to(_placed(_look, 0.0).origin)
		shift += (centre - (_clear - 1.0)) * away * half_across
		if not fixed:
			out = clampf((out - near) * (top - low) / size.x / (_clear * SETTLE_FILL) + near, near + 2.0, CAMERA_FAR)
	camera.global_transform = was
	return [out, shift]


## Whether the camera has stopped moving.
func still() -> bool:
	return _settled >= SETTLE


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var tapped: bool = event is InputEventScreenTouch and event.pressed
	var clicked: bool = event is InputEventMouseButton and event.pressed
	var key: bool = (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.is_echo()
	if (tapped or clicked or key) and _time >= IGNORE_INPUT:
		get_viewport().set_input_as_handled()
		finish()
