class_name Puddles
extends Node3D

## Puddles on the road in the rain. Driving through one there's even less
## grip than on the wet road, and the water drags. They're the same for the
## same seed, so everyone online has the same ones.
##
## Each one lies in a dip in the road shaped like a long blob with a wobbly
## edge, running along the road. Most lie along the road's edges, some out
## on the road and a few reach most of the way across it. The water fills
## each dip from its deepest point, so a puddle grows out from there and
## gets deeper as it goes, shallow at its edge. Where two run into each
## other they join into one body of water with one smooth edge.
##
## They build up over the race: every one is placed at the start, and each
## one starts filling at its own point in the race and is full GROW later
## (see grow()). The race passes in how far the leader's got, so a device
## only needs that one number to have the same puddles as the rest.
##
## They're not bodies a wheel can touch: a kart asks how deep the water is
## at a point (see factor_at()), so the road under them stays the road,
## sticky and all. The water's drawn from the very same depths.

## How many for every 100 m of road, from a light rain to a storm, and how
## big each is when full, in metres, before it's stretched along the road.
const PER_100M := [3.0, 6.0]
const SIZE := [3.5, 10.0]
## Shares of them that lie along an edge, and that reach across the road.
## The rest lie anywhere on it.
const AT_EDGE := 0.45
const ACROSS := 0.12
## The share that have one or two more running into them.
const BUDDIES := 0.35
## How much the edge wobbles in and out, for each of its first few bumps
## around, as a share of its size. The most it can stick out is all of
## these added up.
const WOBBLE := [0.08, 0.14, 0.1, 0.07, 0.05, 0.035]
## Small ripples in the shore, the same everywhere on the road: how deep,
## and how many to the metre, across two lots of ripples.
const RIPPLE := [0.05, 0.025]
const RIPPLE_SCALE := [1.2, 2.7]
## How far a puddle reaches is found by trying this many ways around it.
const AROUND := 48
## Water stops this far in from the road's edges, in metres, and gets this
## much shallower for every metre closer to that line, so it meets it in a
## straight shore.
const EDGE := 0.3
const EDGE_STEEP := 3.0
## Never where the road climbs, rolls or leaves the ground.
const NOT_ON := ["ramp", "jump", "loop", "corkscrew", "wallride", "bank"]
## For looking them up quickly, a grid of squares this big.
const CELL := 4.0
## Where in the race (0 at the start, 1 at the end) each one starts to fill,
## and how much of the race it takes to fill. A few have started before GO,
## so there's a little water from the start, and all are full by the end.
const STARTS := [-0.2, 0.65]
const GROW := 0.35
## Just started, one reaches out this much of its full size.
const SMALLEST := 0.3
## The build-up goes in steps this big, so every device steps together.
const STEP := 0.01
## How close, as a share of their reaches added up, two can be placed.
## Under 1 they run into each other.
const SPACING := 0.7
## Two bodies of water this near each other in depth, where they meet,
## are joined with a smooth neck (see _join()). Depth is 1 at a full
## puddle's middle.
const JOIN := 0.3
## Puddles that could touch are kept in different ones of this many slots,
## so the drawing can tell them apart (see _draw()). One that finds no free
## slot isn't laid.
const SLOTS := 4
## Each puddle's water counts as no shallower than this, so one far off is
## the same as none. A puddle's reach in the grid and the drawing goes out
## to where it gets this low (see _zone()). It's low enough that only real
## water joined together makes any.
const LOWEST := -0.4
## The water's drawn on a grid this fine, in metres, this high over the road.
const GRID := 0.6
const LIFT := 0.03
const WATER := Color("#34404c")

## The water: lit like the blocks, glassy with the pale sky in it, more so
## the flatter you look across it, and with rain rings on it. Each vertex
## has, for the puddle in each slot, which one it is in CUSTOM2 (below 0
## for none) and how far along and right of its middle it is in CUSTOM0 and
## CUSTOM1, in metres, and in UV.x how far in from EDGE it is. Those vary
## evenly across a triangle, so the shader works out each puddle's dip at
## every pixel just as factor_at() does, its wobble and size from `shapes`
## (see _shapes()). It's drawn in two passes split by depth, like the snow
## drifts: solid water that writes depth and takes shadows like the road,
## then a thin see-through rim fading to nothing at the shore.
const SHORE := 0.05
const WATER_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float level;
uniform sampler2D shapes : filter_nearest;
varying vec3 world;
varying vec4 along;
varying vec4 across;
varying flat vec4 which;
varying float road_in;
""" + BrickShaders.COMMON + """
float filled(float start) {
	float g = clamp((level - start) / GROW_SHARE, 0.0, 1.0);
	float r = mix(SMALLEST_SHARE, 1.0, g);
	return g > 0.0 ? r * r : -100.0;
}

float joined(float a, float b) {
	float h = max(JOIN_DEPTH - abs(a - b), 0.0) / JOIN_DEPTH;
	return max(a, b) + h * h * JOIN_DEPTH * 0.25;
}

float shore(vec3 p) {
	vec2 a = p.xz * RIPPLE_ONE;
	vec2 b = p.xz * RIPPLE_TWO;
	return RIPPLE_A * sin(a.x + 0.6 * a.y) * sin(a.y - 0.5 * a.x + 1.7) + RIPPLE_B * sin(b.x - 0.4 * b.y + 0.3) * sin(b.y + 0.7 * b.x);
}

// The puddle `id`'s water here, u along it and v right of its middle.
float water(float id, float u, float v) {
	if (id < -0.5) {
		return LOWEST;
	}
	int row = int(id + 0.5);
	vec4 size = texelFetch(shapes, ivec2(3, row), 0);
	vec2 at = vec2(u * size.x, (v - size.z * u * u) * size.y);
	float r2 = dot(at, at);
	vec2 one = at / sqrt(max(r2, 1e-12));
	vec2 k = one;
	vec4 a = texelFetch(shapes, ivec2(0, row), 0);
	vec4 b = texelFetch(shapes, ivec2(1, row), 0);
	vec4 c = texelFetch(shapes, ivec2(2, row), 0);
	float far = 1.0 + dot(a.xy, k);
	k = vec2(k.x * one.x - k.y * one.y, k.y * one.x + k.x * one.y);
	far += dot(a.zw, k);
	k = vec2(k.x * one.x - k.y * one.y, k.y * one.x + k.x * one.y);
	far += dot(b.xy, k);
	k = vec2(k.x * one.x - k.y * one.y, k.y * one.x + k.x * one.y);
	far += dot(b.zw, k);
	k = vec2(k.x * one.x - k.y * one.y, k.y * one.x + k.x * one.y);
	far += dot(c.xy, k);
	k = vec2(k.x * one.x - k.y * one.y, k.y * one.x + k.x * one.y);
	far += dot(c.zw, k);
	return max(filled(size.w) - r2 / (far * far), LOWEST);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	along = CUSTOM0;
	across = CUSTOM1;
	which = CUSTOM2;
	road_in = UV.x;
}

void fragment() {
	float w0 = water(which.x, along.x, across.x);
	float w1 = water(which.y, along.y, across.y);
	float w2 = water(which.z, along.z, across.z);
	float w3 = water(which.w, along.w, across.w);
	float depth = min(joined(joined(joined(w0, w1), w2), w3) + shore(world), road_in * EDGE_STEEPNESS);
	float rim = max(RIM_DEPTH, fwidth(depth) * 1.5);
	PASS_TEST
	// Rain rings, one at a time in each cell, spreading and fading.
	vec2 p = world.xz / 0.8;
	vec2 cell = floor(p);
	vec2 at = fract(p) - 0.5 - (vec2(hash(cell), hash(cell + 3.1)) - 0.5) * 0.5;
	float t = fract(TIME * 0.8 + hash(cell + 7.7));
	float ring = (1.0 - smoothstep(0.0, 0.05, abs(length(at) - t * 0.4))) * (1.0 - t) * wet;
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 sky_tint = vec3(0.42, 0.5, 0.6);
	float deep = smoothstep(0.0, 0.5, depth);
	vec3 col = mix(pow(WATER_COLOUR, vec3(2.2)), sky_tint, (0.4 + 0.15 * glance) * mix(0.75, 1.0, deep));
	col *= 1.0 + 0.25 * ring;
	ALBEDO = col;
	// Less shine looking flat across it, or long puddles far off go white.
	ROUGHNESS = mix(0.1, 0.45, glance);
	SPECULAR = mix(0.45, 0.15, glance);
	EMISSION = col * lamp_light(world) * 0.9;
}
"""

static var _water_shader: Shader
static var _rim_shader: Shader

## Each one as [middle, how far it can reach from there when full, where it
## starts filling].
var spots: Array = []
## How far the build-up's got, from 0 to 1. It only ever goes up.
var level := 0.0
## How far each one reaches now, 0 until it's started.
var radius_now: PackedFloat32Array = []
var _cells := {}
var _track: TrackPath
## Each puddle's shape: the flat way along it, half its length and width,
## how much it bends with the road (one over the radius, right positive),
## how far right of the road's middle its own middle is, its wobble (see
## _lay()), its slot and where along the road it lies (below 0 if it wasn't
## laid on one).
var _middle: PackedVector3Array = []
var _way: Array[Vector3] = []
var _half_long: PackedFloat32Array = []
var _half_wide: PackedFloat32Array = []
var _bend: PackedFloat32Array = []
var _from_middle: PackedFloat32Array = []
var _wobble: Array[PackedFloat32Array] = []
## The most each one's wobble can push its edge out, as a share.
var _most_out: PackedFloat32Array = []
## How far from its middle each one's water can be over LOWEST, squared.
var _zone2: PackedFloat32Array = []
## How full each one is now (see _filled()).
var _fill: PackedFloat64Array = []
## How far each one's own way across can be off from the drawing's, near
## it, in metres, with a little over for in between the grid's points (see
## _add_run()). With it a point's known to be far enough from EDGE without
## looking it up on the road.
var _slack: PackedFloat32Array = []
## Water stops EDGE in from the road's edge, this far from its middle.
var _edge := INF
## The drawing's grid (see _add_run()), in runs along the road, each as
## [how far apart its rows are, where each row's middle is, which way is
## right along each row]. Each puddle's run, and the row its middle's at.
var _runs: Array = []
var _run_of: PackedInt32Array = []
var _run_row: PackedFloat32Array = []
var _slot: PackedInt32Array = []
var _offset: PackedFloat32Array = []
var _look: ShaderMaterial
## For factor_at(), kept so it doesn't make new ones each time: the puddles
## near the point, and where it is in each.
var _close := PackedFloat64Array()
var _close_ids := PackedInt32Array()


func _init(track: TrackPath = null, chance_seed := 0, amount := 0.0) -> void:
	if track == null:
		return
	_track = track
	_edge = track.width * 0.5 - EDGE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_seed_key(chance_seed, track))
	_scatter(rng, track, amount)
	_level_sizes()
	_draw()


## Places them all from the seeded `rng`, `amount` from a light rain to a
## storm. Every draw from it happens in the same order on every device.
func _scatter(rng: RandomNumberGenerator, track: TrackPath, amount: float) -> void:
	var count := roundi(track.length / 100.0 * lerpf(PER_100M[0], PER_100M[1], amount))
	var edge := track.width * 0.5 - EDGE
	# Its middle stays far enough in that the edge doesn't make it shallower
	# there.
	var inside := edge - 1.0 / EDGE_STEEP - 0.1
	var placed: Array = []
	# Where each placed one's middle is on the grid, for the spacing check.
	var near := {}
	var tries := 0
	while placed.size() < count and tries < count * 20:
		tries += 1
		# The lowest of a few spots, so they gather in the dips.
		var offset := rng.randf() * track.length
		for k in 2:
			var other := rng.randf() * track.length
			if _dip(track, other) < _dip(track, offset):
				offset = other
		var size := rng.randf_range(SIZE[0], SIZE[1])
		var kind := rng.randf()
		var wide: float
		var long: float
		var across: float
		if kind < ACROSS:
			wide = track.width * rng.randf_range(0.6, 0.85)
			long = wide * rng.randf_range(0.7, 1.1)
			across = rng.randf_range(-0.12, 0.12) * track.width
		elif kind < ACROSS + AT_EDGE:
			wide = size * rng.randf_range(0.4, 0.6)
			long = size * rng.randf_range(1.5, 2.3)
			across = (1.0 if rng.randf() < 0.5 else -1.0) * (inside - wide * 0.5 * rng.randf_range(0.0, 0.5))
		else:
			wide = size * rng.randf_range(0.5, 0.75)
			long = size * rng.randf_range(1.2, 1.8)
			across = rng.randf_range(-1.0, 1.0) * maxf(edge - wide * 0.5, 0.0)
		var start := rng.randf_range(STARTS[0], STARTS[1])
		var group := [_lay(rng, track, offset, long, wide, clampf(across, -inside, inside), start, edge)]
		# Some have one or two more running into them, ahead or behind.
		if rng.randf() < BUDDIES:
			for k in rng.randi_range(1, 2):
				var ahead := (1.0 if rng.randf() < 0.5 else -1.0)
				var their_long := long * rng.randf_range(0.5, 0.9)
				var their_wide := wide * rng.randf_range(0.6, 1.0)
				var along := ahead * (long + their_long) * 0.5 * rng.randf_range(0.45, 0.75)
				var shift := clampf(across + rng.randf_range(-0.3, 0.3) * wide, -inside, inside)
				group.append(_lay(rng, track, fposmod(offset + along, track.length), their_long, their_wide, shift, minf(start + rng.randf_range(-0.04, 0.04), STARTS[1]), edge))
		var fits := true
		for p in group:
			fits = fits and _flat_along(track, p[3], p[1]) and not _crowded(near, placed, p[0], p[1])
		if not fits:
			continue
		for p in group:
			var key := _cell(p[0])
			if not near.has(key):
				near[key] = []
			near[key].append(placed.size())
			placed.append(p)
	# In the order they start, then the order they were placed.
	for i in placed.size():
		placed[i].append(i)
	placed.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2] or (a[2] == b[2] and a[10] < b[10]))
	for p in placed:
		var bend := _bend_at(track, p[3])
		add_shaped(p[0], p[4], p[5], p[6], p[2], p[9], bend, p[7], p[3])


## One puddle at `offset` along the road and `across` right of its middle,
## `long` and `wide`, with its wobble drawn from `rng`, as [middle, reach,
## start, offset, way, half long, half wide, across, edge, wobble].
func _lay(rng: RandomNumberGenerator, track: TrackPath, offset: float, long: float, wide: float, across: float, start: float, edge: float) -> Array:
	var wobble := PackedFloat32Array()
	for w in WOBBLE:
		var turn := rng.randf() * TAU
		var bump: float = w * rng.randf_range(0.5, 1.0)
		wobble.append(cos(turn) * bump)
		wobble.append(sin(turn) * bump)
	var way := _flat(track.forward_at(offset))
	var middle := track.point_at(offset) + _right(way) * across
	return [middle, _reach(long * 0.5, wide * 0.5, _rim_of(wobble)), start, offset, way, long * 0.5, wide * 0.5, across, edge, wobble]


## How far from its middle one this big with this edge reaches when full.
static func _reach(half_long: float, half_wide: float, rim: PackedFloat32Array) -> float:
	var most := 0.0
	for n in AROUND:
		var turn := -PI + TAU * n / AROUND
		most = maxf(most, rim[n] * Vector2(half_long * cos(turn), half_wide * sin(turn)).length())
	return most


## How far the edge of one with this wobble reaches out at each of AROUND
## steps around it, from behind (-PI) and back, as a share of its size.
## Bump k goes around k times, so its angle's cosine and sine come from
## turning the first one k times.
static func _rim_of(wobble: PackedFloat32Array) -> PackedFloat32Array:
	var rim := PackedFloat32Array()
	for n in AROUND + 1:
		var turn := -PI + TAU * n / AROUND
		var c := cos(turn)
		var s := sin(turn)
		var ck := c
		var sk := s
		var out := 1.0
		for k in WOBBLE.size():
			out += wobble[2 * k] * ck + wobble[2 * k + 1] * sk
			var next := ck * c - sk * s
			sk = ck * s + sk * c
			ck = next
		rim.append(out)
	return rim


## How far below the road either side of it this point is, in metres.
static func _dip(track: TrackPath, offset: float) -> float:
	return track.point_at(offset).y - 0.5 * (track.point_at(offset - 10.0).y + track.point_at(offset + 10.0).y)


## Whether the road here is flat and plain enough to have one on it.
static func _flat_road(track: TrackPath, offset: float) -> bool:
	return not NOT_ON.has(track.piece_type_at(offset)) and track.up_at(offset).y >= 0.97 and not track.pieces[track.piece_of[track._index_before(offset)]].sticky


## Whether the road's flat and plain for `half` either way of here.
static func _flat_along(track: TrackPath, offset: float, half: float) -> bool:
	var at := -half
	while at < half:
		if not _flat_road(track, fposmod(offset + at, track.length)):
			return false
		at += 2.0
	return _flat_road(track, fposmod(offset + half, track.length))


## How much the road bends here, one over its radius, right positive.
static func _bend_at(track: TrackPath, offset: float) -> float:
	var back := _flat(track.forward_at(offset - 2.0))
	var ahead := _flat(track.forward_at(offset + 2.0))
	return (ahead - back).dot(_right(_flat(track.forward_at(offset)))) / 4.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


## The flat way to the right of the flat way `way`.
static func _right(way: Vector3) -> Vector3:
	return Vector3(-way.z, 0.0, way.x)


## Whether one reaching this far from here would be too close to one already
## placed. `near` has where their middles are on the grid.
func _crowded(near: Dictionary, placed: Array, middle: Vector3, reach: float) -> bool:
	var most := SIZE[1] * 2.0
	var low := _cell(middle - Vector3.ONE * (reach + most))
	var high := _cell(middle + Vector3.ONE * (reach + most))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			for j in near.get(Vector2i(x, z), []):
				if placed[j][0].distance_to(middle) < (placed[j][1] + reach) * SPACING:
					return true
	return false


## A round one here, this big when full, starting to fill at `start`.
## Tests make their own this way.
func add(middle: Vector3, radius: float, start := -1.0, in_cells := true) -> void:
	var still := PackedFloat32Array()
	still.resize(WOBBLE.size() * 2)
	add_shaped(middle, Vector3.FORWARD, radius, radius, start, still, 0.0, 0.0, -1.0, in_cells)


## Puts one here running along `way`, half `half_long` long and half
## `half_wide` wide, bending `bend` with the road, its middle `from_middle`
## right of the road's, laid at `offset` along the road. Left out if it
## can't have a slot (see SLOTS).
func add_shaped(middle: Vector3, way: Vector3, half_long: float, half_wide: float, start: float, wobble: PackedFloat32Array, bend := 0.0, from_middle := 0.0, offset := -1.0, in_cells := true) -> void:
	# Kept to what radius_now can hold, so a full one's is exactly the same.
	var reach: float = PackedFloat32Array([_reach(half_long, half_wide, _rim_of(wobble))])[0]
	var most_out := 1.0
	for k in WOBBLE.size():
		most_out += Vector2(wobble[2 * k], wobble[2 * k + 1]).length()
	var zone := _zone(half_long, half_wide, bend, most_out)
	# Two in the same slot are kept far enough apart that their water's
	# never over LOWEST in the same square of the drawing.
	var cover := zone + GRID * 2.0
	var taken := []
	for i in spots.size():
		if _middle[i].distance_to(middle) < sqrt(_zone2[i]) + GRID * 2.0 + cover:
			taken.append(_slot[i])
	var slot := 0
	while taken.has(slot):
		slot += 1
	if slot >= SLOTS:
		return
	_register(middle, reach, start, cover if in_cells else -1.0)
	_middle.append(middle)
	_way.append(_flat(way))
	_half_long.append(half_long)
	_half_wide.append(half_wide)
	_bend.append(bend)
	_from_middle.append(from_middle)
	_wobble.append(wobble)
	_most_out.append(most_out)
	_zone2.append(zone * zone)
	_fill.append(_filled(spots.size() - 1))
	_slack.append(0.0)
	_run_of.append(-1)
	_run_row.append(0.0)
	_slot.append(slot)
	_offset.append(offset)


## How far from its middle, in metres, one this shape can have water over
## LOWEST: where it's that low its edge is sqrt(1 - LOWEST) times as far out.
static func _zone(half_long: float, half_wide: float, bend: float, most_out: float) -> float:
	var out := sqrt(1.0 - LOWEST) * most_out
	var long := out * half_long
	return Vector2(long, out * half_wide + absf(bend) * long * long * 0.5).length()


## Keeps one reaching this far from `middle` when full, in the grid out to
## `cover` from it (none if that's below 0).
func _register(middle: Vector3, reach: float, start: float, cover: float) -> void:
	spots.append([middle, reach, start])
	radius_now.append(_size_now(spots.size() - 1))
	if cover < 0.0:
		return
	var low := _cell(middle - Vector3(cover, 0.0, cover))
	var high := _cell(middle + Vector3(cover, 0.0, cover))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var key := Vector2i(x, z)
			if not _cells.has(key):
				_cells[key] = []
			_cells[key].append(spots.size() - 1)


## Builds up to this far through the race, from 0 to 1. It never goes back,
## and goes in STEPs, so any device given the same progress has exactly the
## same puddles.
func grow(progress: float) -> void:
	var now := stepped(progress)
	if now <= level:
		return
	level = now
	_level_sizes()
	_show()


## Shows the water at `level`.
func _show() -> void:
	if _look != null:
		_look.set_shader_parameter("level", level)
		_look.next_pass.set_shader_parameter("level", level)


## Progress rounded down to a STEP. Online it goes as a whole number of
## STEPs (see steps_of()), and comes back exactly the same.
static func stepped(progress: float) -> float:
	return from_steps(steps_of(progress))


static func steps_of(progress: float) -> int:
	return floori(clampf(progress, 0.0, 1.0) / STEP + 0.0001)


static func from_steps(steps: int) -> float:
	return steps * STEP


## How grown this one is now, from 0 (not started) to 1 (full size).
func growth(i: int) -> float:
	return clampf((level - spots[i][2]) / GROW, 0.0, 1.0)


## How deep the dip of this one is at this point, 1 at its middle, 0 at its
## edge when full and below 0 outside.
func _dip_at(i: int, point: Vector3) -> float:
	return 1.0 - _spread(i, point)


## How far out this point is in this one, squared, as a share of how far
## its edge is that way: 0 at its middle and 1 on its edge when full. The
## shader works it out the same way (see WATER_SHADER).
func _spread(i: int, point: Vector3) -> float:
	var middle := _middle[i]
	var dx := point.x - middle.x
	var dz := point.z - middle.z
	var way := _way[i]
	var u := dx * way.x + dz * way.z
	var x := u / _half_long[i]
	var y := (dz * way.x - dx * way.z - _bend[i] * 0.5 * u * u) / _half_wide[i]
	var r2 := x * x + y * y
	# Bump k of the wobble goes around k times, so its cosine and sine come
	# from turning the first one k times.
	var r := sqrt(maxf(r2, 1e-12))
	var c := x / r
	var s := y / r
	var ck := c
	var sk := s
	var wobble := _wobble[i]
	var out := 1.0 + wobble[0] * ck + wobble[1] * sk
	for k in range(2, WOBBLE.size() * 2, 2):
		var next := ck * c - sk * s
		sk = sk * c + ck * s
		ck = next
		out += wobble[k] * ck + wobble[k + 1] * sk
	return r2 / (out * out)


## How full this one's dip is now: 0 empty, 1 full. The water fills it from
## the bottom, so it reaches out the square root of this, SMALLEST of the
## way as it starts.
func _filled(i: int) -> float:
	var g := growth(i)
	var r := lerpf(SMALLEST, 1.0, g)
	return r * r if g > 0.0 else -100.0


## The small ripples in the shore at this point (see RIPPLE).
static func _shore(p: Vector3) -> float:
	var ax: float = p.x * RIPPLE_SCALE[0]
	var az: float = p.z * RIPPLE_SCALE[0]
	var bx: float = p.x * RIPPLE_SCALE[1]
	var bz: float = p.z * RIPPLE_SCALE[1]
	return RIPPLE[0] * sin(ax + 0.6 * az) * sin(az - 0.5 * ax + 1.7) + RIPPLE[1] * sin(bx - 0.4 * bz + 0.3) * sin(bz + 0.7 * bx)


## Two bodies of water's depths joined smoothly where they're close, so
## where two puddles meet there's one edge with no seam.
static func _join(a: float, b: float) -> float:
	var h := maxf(JOIN - absf(a - b), 0.0) / JOIN
	return maxf(a, b) + h * h * JOIN * 0.25


## How deep the water is at this point, from 0 outside a puddle to 1 in the
## middle of a full one, and shallow near its edge. It's what's drawn. A
## kart asks for each wheel every physics step, so it does as little as it
## can where there's no water.
func factor_at(point: Vector3) -> float:
	var here = _cells.get(_cell(point))
	if here == null:
		return 0.0
	# First where each puddle near is in its own shape, keeping those whose
	# water could be over LOWEST here in _close.
	var count := 0
	var could := LOWEST
	for i: int in here:
		var fill := _fill[i]
		if fill <= LOWEST:
			continue
		var middle := _middle[i]
		var dx := point.x - middle.x
		var dz := point.z - middle.z
		if dx * dx + dz * dz >= _zone2[i] or absf(point.y - middle.y) >= 2.0:
			continue
		# As in _spread().
		var way := _way[i]
		var u := dx * way.x + dz * way.z
		var across := dz * way.x - dx * way.z - _bend[i] * 0.5 * u * u
		var x := u / _half_long[i]
		var y := across / _half_wide[i]
		var r2 := x * x + y * y
		# The deepest its wobble could make it here.
		var most_out := _most_out[i]
		var top := fill - r2 / (most_out * most_out)
		if top <= LOWEST:
			continue
		could = maxf(could, top)
		if _close.size() < (count + 1) * 4:
			_close.resize((count + 1) * 4)
			_close_ids.resize(count + 1)
		_close_ids[count] = i
		_close[count * 4] = x
		_close[count * 4 + 1] = y
		_close[count * 4 + 2] = r2
		_close[count * 4 + 3] = across
		count += 1
	# Joined and with ripples water can come up by JOIN at most.
	if could <= -JOIN:
		return 0.0
	# The water in each slot, as in the shader.
	var w0 := LOWEST
	var w1 := LOWEST
	var w2 := LOWEST
	var w3 := LOWEST
	var most := LOWEST
	var deepest := -1
	# The least it can be in from EDGE here, going by each puddle near.
	var room := -INF
	for n in count:
		var i := _close_ids[n]
		var r2 := _close[n * 4 + 2]
		var r := sqrt(maxf(r2, 1e-12))
		var c := _close[n * 4] / r
		var s := _close[n * 4 + 1] / r
		var wobble := _wobble[i]
		var out := 1.0 + wobble[0] * c + wobble[1] * s
		var ck := c * c - s * s
		var sk := s * c + c * s
		out += wobble[2] * ck + wobble[3] * sk
		var next := ck * c - sk * s
		sk = sk * c + ck * s
		ck = next
		out += wobble[4] * ck + wobble[5] * sk
		next = ck * c - sk * s
		sk = sk * c + ck * s
		ck = next
		out += wobble[6] * ck + wobble[7] * sk
		next = ck * c - sk * s
		sk = sk * c + ck * s
		ck = next
		out += wobble[8] * ck + wobble[9] * sk
		next = ck * c - sk * s
		sk = sk * c + ck * s
		ck = next
		out += wobble[10] * ck + wobble[11] * sk
		var w := maxf(_fill[i] - r2 / (out * out), LOWEST)
		var t := absf(_from_middle[i] + _close[n * 4 + 3])
		room = maxf(room, _edge - maxf(t, GRID * 2.0) - _slack[i])
		var slot := _slot[i]
		if slot == 0:
			w0 = maxf(w0, w)
		elif slot == 1:
			w1 = maxf(w1, w)
		elif slot == 2:
			w2 = maxf(w2, w)
		else:
			w3 = maxf(w3, w)
		if w > most:
			most = w
			deepest = i
	if most <= -JOIN:
		return 0.0
	# The joins, as in _join().
	var h := maxf(JOIN - absf(w0 - w1), 0.0) / JOIN
	var depth := maxf(w0, w1) + h * h * JOIN * 0.25
	h = maxf(JOIN - absf(depth - w2), 0.0) / JOIN
	depth = maxf(depth, w2) + h * h * JOIN * 0.25
	h = maxf(JOIN - absf(depth - w3), 0.0) / JOIN
	depth = minf(maxf(depth, w3) + h * h * JOIN * 0.25 + _shore(point), 1.0)
	if depth <= 0.0:
		return 0.0
	# Only near enough to EDGE does it get shallower there.
	if room * EDGE_STEEP < depth:
		depth = minf(depth, _road_in(deepest, point) * EDGE_STEEP)
	return maxf(depth, 0.0)


## How far in from EDGE this point is, near this puddle, worked out across
## the triangle of the drawing's grid it's in the way the drawing does. INF
## if the puddle's not drawn.
func _road_in(i: int, point: Vector3) -> float:
	if _run_of[i] < 0:
		return INF
	var run: Array = _runs[_run_of[i]]
	var step: float = run[0]
	var mids: PackedVector3Array = run[1]
	var rights: PackedVector3Array = run[2]
	var middle := _middle[i]
	var way := _way[i]
	var dx := point.x - middle.x
	var dz := point.z - middle.z
	var u := dx * way.x + dz * way.z
	var t := _from_middle[i] + dz * way.x - dx * way.z - _bend[i] * 0.5 * u * u
	# Its row, about: on the inside of a bend the road's middle goes further.
	var last := mids.size() - 2
	var a := clampi(floori(_run_row[i] + u / maxf(1.0 - _bend[i] * t, 0.3) / step), 0, last)
	# Then exactly, between the lines across the road the rows lie on.
	for n in 50:
		if a < last and _ahead(point, mids[a + 1], rights[a + 1]):
			a += 1
		elif a > 0 and not _ahead(point, mids[a], rights[a]):
			a -= 1
		else:
			break
	var near := mids[a]
	var near_right := rights[a]
	var far := mids[a + 1]
	var far_right := rights[a + 1]
	t = (point - near).dot(near_right)
	var columns := ceili(_edge * 2.0 / GRID)
	var b := clampi(floori((t + _edge) / (_edge * 2.0) * columns), 0, columns - 1)
	var t0 := -_edge + _edge * 2.0 * b / columns
	var t1 := -_edge + _edge * 2.0 * (b + 1) / columns
	# The first triangle has the corner at (a, t0), the second the one at
	# (a + 1, t1). Both have the other two.
	var corner := near + near_right * t1
	var ahead := far + far_right * t0
	var weights := _weights(point, near + near_right * t0, ahead, corner)
	if weights.x >= 0.0:
		return _edge - absf(t0) * weights.x - absf(t0) * weights.y - absf(t1) * weights.z
	weights = _weights(point, far + far_right * t1, ahead, corner)
	return _edge - absf(t1) * weights.x - absf(t0) * weights.y - absf(t1) * weights.z


## Whether this point's ahead of the line across the road through `middle`
## along `right`.
static func _ahead(point: Vector3, middle: Vector3, right: Vector3) -> bool:
	return (point.x - middle.x) * right.z - (point.z - middle.z) * right.x > 0.0


## How much each corner of the triangle a, b, c counts for at this point,
## seen from above.
static func _weights(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var bx := b.x - a.x
	var bz := b.z - a.z
	var cx := c.x - a.x
	var cz := c.z - a.z
	var px := point.x - a.x
	var pz := point.z - a.z
	var area := bx * cz - bz * cx
	var wb := (px * cz - pz * cx) / area
	var wc := (bx * pz - bz * px) / area
	return Vector3(1.0 - wb - wc, wb, wc)


func _seed_key(chance_seed: int, track: TrackPath) -> Array:
	return [chance_seed, track.name]


func _level_sizes() -> void:
	for i in spots.size():
		radius_now[i] = _size_now(i)
	for i in _fill.size():
		_fill[i] = _filled(i)


## How far this one reaches now: SMALLEST of the way as it starts, and 0
## before.
func _size_now(i: int) -> float:
	var g := growth(i)
	return spots[i][1] * lerpf(SMALLEST, 1.0, g) if g > 0.0 else 0.0


static func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


## The water, as one mesh over the road wherever there could be a puddle,
## in a grid laid along the road. Each run of road with puddles on it gets
## a strip of grid, and only the squares that could hold water are kept.
func _draw() -> void:
	if spots.is_empty():
		return
	var length := _track.length
	# Each one's stretch of road, then those that overlap joined up.
	var stretches: Array = []
	for i in spots.size():
		if _offset[i] >= 0.0:
			var reach := _along_reach(i, _track.width * 0.5 - EDGE)
			stretches.append([_offset[i] - reach, _offset[i] + reach, [i]])
	stretches.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var runs: Array = []
	for s in stretches:
		if not runs.is_empty() and s[0] <= runs[-1][1]:
			runs[-1][1] = maxf(runs[-1][1], s[1])
			runs[-1][2].append_array(s[2])
		else:
			runs.append(s.duplicate(true))
	# The last one may run on past the end into the first.
	if runs.size() > 1 and runs[-1][1] - length >= runs[0][0]:
		runs[0][0] = runs[-1][0] - length
		runs[0][1] = maxf(runs[0][1], runs[-1][1] - length)
		runs[0][2].append_array(runs[-1][2])
		runs.pop_back()
	var arrays := _empty_arrays()
	var edge := _track.width * 0.5 - EDGE
	for run in runs:
		_add_run(arrays, run[0], run[1], run[2], edge)
	if (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
		return
	var draw := MeshInstance3D.new()
	draw.mesh = _mesh_of(arrays)
	_look = new_look(_shapes())
	_show()
	draw.material_override = _look
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)


## How far along the road from its middle the grid has to go for this one,
## out to where the drawing looks for it (see _add_run()). On the inside of
## a bend the road's middle goes further than the puddle does.
func _along_reach(i: int, edge: float) -> float:
	return (sqrt(_zone2[i]) + GRID * 2.0) / maxf(1.0 - absf(_bend[i]) * edge, 0.4) + GRID


## Lays the grid along the road from `from` to `to` with these puddles on
## it, keeping the squares where water could be and only their corners.
## Each square has one puddle for each slot, the one that comes nearest
## having water there; a corner with another one there gets a vertex of
## its own for that square.
func _add_run(arrays: Array, from: float, to: float, which: Array, edge: float) -> void:
	var length := _track.length
	var along := ceili((to - from) / GRID) + 1
	var across := ceili(edge * 2.0 / GRID) + 1
	# Each grid point's place, up and how far in from EDGE, and for each slot
	# the puddle near enough there to look at and its dip when full. A point
	# no puddle's near is left out: it's too far from them all for water.
	var count := along * across
	var places := PackedVector3Array()
	var ups := PackedVector3Array()
	var ins := PackedFloat32Array()
	var ids := PackedInt32Array()
	var dips := PackedFloat32Array()
	var keep := PackedByteArray()
	var done := PackedByteArray()
	places.resize(count)
	ups.resize(count)
	ins.resize(count)
	ids.resize(count * SLOTS)
	ids.fill(-1)
	dips.resize(count * SLOTS)
	dips.fill(-INF)
	keep.resize(count)
	done.resize(count)
	# The puddles that reach each row, and how far each one's looked for:
	# a square further from it than that can't have its water.
	var rows: Array = []
	rows.resize(along)
	var step := (to - from) / (along - 1)
	var near_enough := {}
	var mids := PackedVector3Array()
	var rights := PackedVector3Array()
	for a in along:
		var s := fposmod(from + step * a, length)
		mids.append(_track.point_at(s))
		rights.append(_track.right_at(s))
	_runs.append([step, mids, rights])
	for i in which:
		var middle := _offset[i] - from
		middle -= length * roundf((middle - (to - from) * 0.5) / length)
		_run_of[i] = _runs.size() - 1
		_run_row[i] = middle / step
		var reach := _along_reach(i, edge)
		near_enough[i] = sqrt(_zone2[i]) + GRID * 2.0
		for a in range(maxi(ceili((middle - reach) / step), 0), mini(floori((middle + reach) / step), along - 1) + 1):
			if rows[a] == null:
				rows[a] = []
			rows[a].append(i)
	# A square's kept if a corner's close enough to having water that the
	# joins and the ripples in the shore could bring it there, or it's by a
	# puddle's middle, where a small one could be all inside it.
	var wet := -JOIN
	for a in along:
		var near = rows[a]
		if near == null:
			continue
		var middle := mids[a]
		var right := rights[a]
		var up := _track.up_at(fposmod(from + step * a, length))
		for b in across:
			var t := -edge + edge * 2.0 * b / (across - 1)
			var c := a * across + b
			var point := middle + right * t
			for i in near:
				var reach: float = near_enough[i]
				if absf(_from_middle[i] - t) >= reach or absf(point.y - _middle[i].y) >= 2.0:
					continue
				var dx := point.x - _middle[i].x
				var dz := point.z - _middle[i].z
				var far := dx * dx + dz * dz
				if far >= reach * reach:
					continue
				# Only where its water could be over LOWEST in a square
				# touching this point.
				var way := _way[i]
				var u := dx * way.x + dz * way.z
				var across_it := dz * way.x - dx * way.z - _bend[i] * 0.5 * u * u
				var x := u / _half_long[i]
				var y := across_it / _half_wide[i]
				var out := sqrt(1.0 - LOWEST) * _most_out[i] + GRID * 1.5 / minf(_half_long[i], _half_wide[i])
				if x * x + y * y < out * out:
					_slack[i] = maxf(_slack[i], absf(_from_middle[i] + across_it - t) + 0.05)
				var d := _dip_at(i, point)
				var k: int = c * SLOTS + _slot[i]
				if d > dips[k]:
					dips[k] = d
					ids[k] = i
				if d >= wet or far < GRID * GRID * 2.25:
					keep[c] = 1
			places[c] = point + up * LIFT
			ups[c] = up
			ins[c] = edge - absf(t)
			done[c] = 1
	# Each grid point's vertex in the mesh, made when first used.
	var number := PackedInt32Array()
	number.resize(count)
	number.fill(-1)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var corners := PackedInt32Array([0, 0, 0, 0])
	var chosen := PackedInt32Array([-1, -1, -1, -1])
	var made := PackedInt32Array([0, 0, 0, 0])
	for a in along - 1:
		if rows[a] == null or rows[a + 1] == null:
			continue
		for b in across - 1:
			var c := a * across + b
			corners[0] = c
			corners[1] = c + across
			corners[2] = c + 1
			corners[3] = c + across + 1
			if keep[c] + keep[c + 1] + keep[c + across] + keep[c + across + 1] == 0:
				continue
			if done[c] + done[c + 1] + done[c + across] + done[c + across + 1] < 4:
				continue
			# The puddle for each slot: the one with the deepest dip at a corner.
			for k in SLOTS:
				var best := -INF
				chosen[k] = -1
				for corner in corners:
					if dips[corner * SLOTS + k] > best:
						best = dips[corner * SLOTS + k]
						chosen[k] = ids[corner * SLOTS + k]
			for n in 4:
				var corner := corners[n]
				var same := true
				for k in SLOTS:
					same = same and ids[corner * SLOTS + k] == chosen[k]
				if not same:
					made[n] = _add_vertex(arrays, places[corner], ups[corner], ins[corner], chosen)
				else:
					if number[corner] < 0:
						number[corner] = _add_vertex(arrays, places[corner], ups[corner], ins[corner], chosen)
					made[n] = number[corner]
			indices.append(made[0])
			indices.append(made[1])
			indices.append(made[2])
			indices.append(made[2])
			indices.append(made[1])
			indices.append(made[3])
	arrays[Mesh.ARRAY_INDEX] = indices


## Adds a vertex lifted to `place`, `road_in` from EDGE, with these puddles
## in its slots, and gives its number.
func _add_vertex(arrays: Array, place: Vector3, up: Vector3, road_in: float, which: PackedInt32Array) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var point := place - up * LIFT
	verts.append(place)
	arrays[Mesh.ARRAY_NORMAL].append(up)
	arrays[Mesh.ARRAY_TEX_UV].append(Vector2(road_in, 0.0))
	for k in SLOTS:
		var i := which[k]
		var u := 0.0
		var v := 0.0
		if i >= 0:
			var dx := point.x - _middle[i].x
			var dz := point.z - _middle[i].z
			var way := _way[i]
			u = dx * way.x + dz * way.z
			v = dz * way.x - dx * way.z
		arrays[Mesh.ARRAY_CUSTOM0].append(u)
		arrays[Mesh.ARRAY_CUSTOM1].append(v)
		arrays[Mesh.ARRAY_CUSTOM2].append(float(i))
	arrays[Mesh.ARRAY_VERTEX] = verts
	return verts.size() - 1


## Each puddle's wobble and size for the shader, a row of four for each:
## its six bumps two to a pixel, then one over half its length and width,
## half its bend and when it starts to fill.
func _shapes() -> ImageTexture:
	var data := PackedFloat32Array()
	for i in spots.size():
		data.append_array(_wobble[i])
		data.append_array([1.0 / _half_long[i], 1.0 / _half_wide[i], _bend[i] * 0.5, spots[i][2]])
	return shapes_of(data, spots.size())


static func shapes_of(data: PackedFloat32Array, count: int) -> ImageTexture:
	var image := Image.create_from_data(4, count, false, Image.FORMAT_RGBAF, data.to_byte_array())
	return ImageTexture.create_from_image(image)


static func _empty_arrays() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	arrays[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array()
	arrays[Mesh.ARRAY_CUSTOM2] = PackedFloat32Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return arrays


static func _mesh_of(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
	return mesh


## A new material for the water with these shapes (see _shapes()), solid
## then its see-through rim.
static func new_look(shapes: ImageTexture) -> ShaderMaterial:
	if _water_shader == null:
		var code := WATER_SHADER.replace("GROW_SHARE", str(GROW)).replace("SMALLEST_SHARE", str(SMALLEST)).replace("JOIN_DEPTH", str(JOIN)).replace("EDGE_STEEPNESS", str(EDGE_STEEP)).replace("RIM_DEPTH", str(SHORE)).replace("LOWEST", str(LOWEST))
		code = code.replace("RIPPLE_ONE", str(RIPPLE_SCALE[0])).replace("RIPPLE_TWO", str(RIPPLE_SCALE[1])).replace("RIPPLE_A", str(RIPPLE[0])).replace("RIPPLE_B", str(RIPPLE[1]))
		code = code.replace("WATER_COLOUR", "vec3(%s, %s, %s)" % [WATER.r, WATER.g, WATER.b])
		_water_shader = TrackBuilder.shader_for(code.replace("PASS_TEST", "if (depth < rim) {\n\t\tdiscard;\n\t}"))
		var rim := code.replace("render_mode cull_back;", "render_mode blend_mix, depth_draw_never, cull_back;")
		_rim_shader = TrackBuilder.shader_for(rim.replace("PASS_TEST", "if (depth <= 0.0 || depth >= rim) {\n\t\tdiscard;\n\t}\n\tALPHA = depth / rim;"))
	var rim_look := ShaderMaterial.new()
	rim_look.shader = _rim_shader
	rim_look.render_priority = -1
	rim_look.set_shader_parameter("shapes", shapes)
	var look := ShaderMaterial.new()
	look.shader = _water_shader
	look.next_pass = rim_look
	look.set_shader_parameter("shapes", shapes)
	return look


## A round puddle `radius` across, full, drawn the way the puddles are, for
## the splash to warm the shader up with.
static func water_sample(radius: float) -> MeshInstance3D:
	var arrays := _empty_arrays()
	var n := 9
	for a in n:
		for b in n:
			var x := (a / float(n - 1) * 2.0 - 1.0) * radius * 1.2
			var z := (b / float(n - 1) * 2.0 - 1.0) * radius * 1.2
			arrays[Mesh.ARRAY_VERTEX].append(Vector3(x, 0.0, z))
			arrays[Mesh.ARRAY_NORMAL].append(Vector3.UP)
			arrays[Mesh.ARRAY_TEX_UV].append(Vector2(10.0, 0.0))
			arrays[Mesh.ARRAY_CUSTOM0].append_array([x, 0.0, 0.0, 0.0])
			arrays[Mesh.ARRAY_CUSTOM1].append_array([z, 0.0, 0.0, 0.0])
			arrays[Mesh.ARRAY_CUSTOM2].append_array([0.0, -1.0, -1.0, -1.0])
	for a in n - 1:
		for b in n - 1:
			var v := a * n + b
			arrays[Mesh.ARRAY_INDEX].append_array([v, v + n, v + 1, v + 1, v + n, v + n + 1])
	var shape := PackedFloat32Array()
	shape.resize(12)
	shape.append_array([1.0 / radius, 1.0 / radius, 0.0, -1.0])
	var draw := MeshInstance3D.new()
	draw.mesh = _mesh_of(arrays)
	var look := new_look(shapes_of(shape, 1))
	look.set_shader_parameter("level", 1.0)
	look.next_pass.set_shader_parameter("level", 1.0)
	draw.material_override = look
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return draw
