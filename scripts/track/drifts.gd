class_name Drifts
extends Puddles

## Snow drifts on the road. They pile up over the race the same way puddles
## do (see Puddles.grow()): low and few at the start and deep by the end.
## The wind's way is picked from the seed, once a race, and the snow blows
## across the road with it in bunches of long tongues, with clear road
## between the bunches. Each tongue starts at the edge the wind comes from
## and runs along the wind, slanting across the road, some most of the way
## over and many only part way. It's thickest near that edge, a rounded
## crest with a sharp lip on its downwind side, and tapers off from there
## to a broad soft tip. Its edges fade into the road. Fine wisps of snow
## streak the road along the wind, in among the tongues and on the bare
## road between bunches, only to look at.
##
## Each tongue or wisp is one lump. spots[i] is [its middle when full, how
## far it reaches from there, start], and it grows out from its root at the
## road's edge.
##
## factor_at() is how deep the snow is at a point, from 0 to 1 of DEEP, and
## snow_at() also gives the pull toward a tongue's middle line. A kart drags
## through it and is pulled toward that line (see Kart).

## Bunches for every 100 m of road, from a light snow to a blizzard, and
## how many tongues and wisps in each.
const BUNCHES_PER_100M := [0.7, 1.4]
const BUNCH_TONGUES := [3, 7]
const BUNCH_WISPS := [2, 4]
## Bunches of wisps alone on the bare road for every 100 m, and how many
## wisps in each and how far along the road they spread, in metres.
const BARE_PER_100M := [0.5, 1.0]
const BARE_WISPS := [2, 3]
const BARE_SPREAD := 10.0
## How far apart the tongues in a bunch start along the road, in metres.
const TONGUE_GAP := [3.0, 8.0]
## How wide a tongue is at its root, in metres.
const TONGUE_WIDTH := [2.5, 5.0]
## How far across the road a tongue's tip gets, as a share of the road's
## width. More of them are short.
const TONGUE_REACH := [0.25, 0.95]
## A wisp's width and length in metres, and how high it is, as a share of
## DEEP.
const WISP_WIDTH := [0.6, 1.4]
const WISP_LENGTH := [10.0, 22.0]
const WISP_HIGH := 0.06
## How much a wisp shows over the road, as its alpha. Under CORE it's all
## see-through rim.
const WISP_SHOW := 0.45
## However the wind blows, a tongue runs at least this much across the road
## for each metre along it, and each one sways off the wind by up to this
## much, in radians.
const LEAST_SLANT := 0.5
const SWAY := 0.18
## Where there's ground beside the road, a tongue's root is this far past
## the edge.
const PAST_EDGE := 0.5
## Along a tongue, from its root (0) to its tip (1): where its crest is,
## where the lip below the crest ends, how high it is past the lip, and how
## wide it is at the tip, as shares. Across, it's rounded and its sides
## ease down to the road with no step.
const CREST := 0.25
const LIP := 0.32
const TAIL := 0.5
const TIP := 0.5
## When laying one, how far off the road's surface it may get before it's
## cut short, and how often that's checked along it, in metres.
const HUG := 0.1
const CLIP_STEP := 0.5
## A tongue cut shorter than this, in metres, isn't laid.
const LEAST_LONG := 3.0
## How close to a tongue's middle line, in metres, the pull toward it eases
## off, so a wheel on the crest isn't pulled back and forth.
const PULL_EASE := 1.0
## Bunches keep at least this far apart along the road.
const BUNCH_GAP := 8.0
## How high a full one is at its crest, in metres.
const DEEP := 0.4
## How steep the lumps look across and along, as a share of how steep the
## mesh is before it's stretched to size. Lit stretched flat, they'd hardly
## show on the road.
const SHADING := 0.06
const SHADING_ALONG := 0.02
const SNOW := Color("#f2f5f9")
## The colour low down and at the edges, shading up to SNOW on top. The
## edges are see-through too, so they fade into the road.
const RIM := Color("#ccd3dc")
const POWDER := Color("#dfe7f0")
## The colour of one on ice: a little darker than SNOW so it shows on the
## pale ice, and warm, which cancels the blue of RIM and the sky to plain
## grey. It's the instance colour, so the same shader draws both.
const ON_ICE := Color("#ddd8cf")
## For the AI: one at least this deep is worth going round.
const AVOID_DEPTH := 0.45
## A lump's drawn again once its reach is this far off what's drawn, in
## metres.
const REDRAW := 0.1

## Powder thrown up: at most this many puffs at once, only for karts this
## close to a race camera (metres), and only above this speed in m/s.
const PUFFS := 48
const POWDER_RANGE := 35.0
const POWDER_SPEED := 4.0
## Puffs a second from a kart at 20 m/s in a full drift, and how long each lasts.
const PUFF_RATE := 30.0
const PUFF_LIFE := 0.7

const POWDER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix, skip_vertex_transform;
varying vec2 shape;

void vertex() {
	// Each puff faces the camera, from its middle and size in INSTANCE_CUSTOM.
	vec3 middle = INSTANCE_CUSTOM.xyz;
	vec3 world = middle + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * INSTANCE_CUSTOM.w;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	shape = UV * 2.0 - 1.0;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * (1.0 - smoothstep(0.3, 1.0, length(shape)));
}
"""

## Lit like the blocks (see BrickShaders.BLOCK), soft and matt. Each lump is
## drawn in two passes split by the mesh's alpha: a solid core where it's at
## least CORE, which writes depth and takes shadows like the road, then its
## rim, see-through and fading to nothing at the edge so it melts into the
## road. The rim doesn't write depth, so one lump's clear rim never cuts
## into the next, and it's drawn before other see-through things, since it
## lies under them.
const CORE := 0.75
const DRIFT_SHADER := """
shader_type spatial;
render_mode cull_back;
varying vec3 world;
""" + BrickShaders.COMMON + """
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (COLOR.a < CORE_ALPHA) {
		discard;
	}
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	EMISSION = col * lamp_light(world) * 0.9;
}
"""
const RIM_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
varying vec3 world;
""" + BrickShaders.COMMON + """
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (COLOR.a >= CORE_ALPHA) {
		discard;
	}
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = col;
	ALPHA = COLOR.a / CORE_ALPHA;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	EMISSION = col * lamp_light(world) * 0.9;
}
"""

static var _lump: ArrayMesh
static var _powder_shader: Shader
static var _drift_material: ShaderMaterial

## The karts in the race, for the powder.
var karts: Array = []
## The flat way the wind blows from.
var wind := Vector3.FORWARD
## For each lump: where its root is, the flat way from root to tip, how wide
## at the root and how long when full (metres), how high it gets as a share
## of DEEP, and where along the road it was laid from (below 0 if it wasn't).
var _root: Array[Vector3] = []
var _dir: Array[Vector3] = []
var _wide: PackedFloat32Array = []
var _long: PackedFloat32Array = []
var _high: PackedFloat32Array = []
var _laid: PackedFloat32Array = []
## Whether it's only to look at, like a wisp.
var _only_looks: Array[bool] = []
var _powder: MultiMesh
## The lumps, drawn all at once, and how far each one reached when it was
## last drawn.
var _multi: MultiMesh
var _drawn: PackedFloat32Array = []
## Which way is up at each one, worked out once.
var _ups: Array[Vector3] = []
## Each puff as [middle, velocity, age].
var _puffs: Array = []
var _owed := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1
	_make_powder()


func _seed_key(chance_seed: int, track: TrackPath) -> Array:
	return [chance_seed, track.name, "snow"]


## Lays the bunches. Every draw from `rng` happens in the same order on
## every device, so the same seed gives the same drifts.
func _scatter(rng: RandomNumberGenerator, track: TrackPath, amount: float) -> void:
	wind = Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
	var count := roundi(track.length / 100.0 * lerpf(BUNCHES_PER_100M[0], BUNCHES_PER_100M[1], amount))
	# Each bunch laid as [from, to] along the road.
	var taken: Array = []
	var lumps: Array = []
	var tries := 0
	while taken.size() < count and tries < count * 20:
		tries += 1
		var offset := rng.randf() * track.length
		var start := rng.randf_range(STARTS[0], STARTS[1])
		var bunch_seed := rng.randi()
		var bunch: Array = _lay_bunch(track, offset, start, bunch_seed)
		var span := _span(track, offset, bunch)
		if not _free(track, taken, span.x, span.y):
			continue
		taken.append([span.x, span.y])
		for l in bunch:
			l[6] = lumps.size()
			lumps.append(l)
	for l in _lay_bare(track, amount, rng.randi()):
		l[6] = lumps.size()
		lumps.append(l)
	# In the order they start, so the ones drawn are always the first few.
	lumps.sort_custom(func(a: Array, b: Array) -> bool: return a[5] < b[5] or (a[5] == b[5] and a[6] < b[6]))
	for l in lumps:
		_add_laid(l)


## A bunch of tongues and wisps from about `offset` on. Each lump is
## [root, dir, wide, long, high, start, order, laid from, only looks].
func _lay_bunch(track: TrackPath, offset: float, start: float, bunch_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = bunch_seed
	var lumps: Array = []
	var at := offset
	for k in rng.randi_range(BUNCH_TONGUES[0], BUNCH_TONGUES[1]):
		var here := fposmod(at, track.length)
		var side := _windward(track, here, rng.randf())
		var dir := _downwind(track, here, side, rng.randf_range(-SWAY, SWAY))
		var reach := lerpf(TONGUE_REACH[0], TONGUE_REACH[1], pow(rng.randf(), 1.5))
		var wide := rng.randf_range(TONGUE_WIDTH[0], TONGUE_WIDTH[1])
		var high := rng.randf_range(0.75, 1.0)
		var tongue := _tongue(track, here, side, dir, reach, wide, high, minf(start + rng.randf_range(-0.04, 0.04), STARTS[1]))
		if not tongue.is_empty():
			lumps.append(tongue)
		at += rng.randf_range(TONGUE_GAP[0], TONGUE_GAP[1])
	var span := at - offset
	for k in rng.randi_range(BUNCH_WISPS[0], BUNCH_WISPS[1]):
		var wisp := _wisp(track, fposmod(offset + rng.randf() * span, track.length), rng, start)
		if not wisp.is_empty():
			lumps.append(wisp)
	return lumps


## Bunches of wisps on their own, kept to flat road.
func _lay_bare(track: TrackPath, amount: float, bare_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = bare_seed
	var lumps: Array = []
	for b in roundi(track.length / 100.0 * lerpf(BARE_PER_100M[0], BARE_PER_100M[1], amount)):
		var offset := rng.randf() * track.length
		var start := rng.randf_range(STARTS[0], STARTS[1])
		for k in rng.randi_range(BARE_WISPS[0], BARE_WISPS[1]):
			var wisp := _wisp(track, fposmod(offset + rng.randf() * BARE_SPREAD, track.length), rng, start)
			if not wisp.is_empty():
				lumps.append(wisp)
	return lumps


## A wisp with its middle at `here` along the road, somewhere across it,
## cut short where it would leave flat road (see _clip()). Empty if there's
## too little of it left.
func _wisp(track: TrackPath, here: float, rng: RandomNumberGenerator, start: float) -> Array:
	var half := track.width * 0.5 - 0.3
	var across := rng.randf_range(-half + 1.0, half - 1.0)
	var dir := _downwind(track, here, _windward(track, here, rng.randf()), rng.randf_range(-SWAY, SWAY))
	var long := rng.randf_range(WISP_LENGTH[0], WISP_LENGTH[1])
	var wide := rng.randf_range(WISP_WIDTH[0], WISP_WIDTH[1])
	var right := track.right_at(here)
	# Kept on the road: no longer than fits across it from its middle.
	var slant := maxf(absf(dir.dot(right)), 0.01)
	long = minf(long, 2.0 * (half - absf(across)) / slant)
	var root := track.point_at(here) + right * across - dir * long * 0.5
	var wisp_start := minf(start + rng.randf_range(-0.03, 0.03), STARTS[1])
	var laid := track.offset_of(root, here, 30.0)
	if not _flat_road(track, laid):
		return []
	long = _clip(track, root, dir, long, laid, wide, true)
	if long < WISP_LENGTH[0] * 0.5:
		return []
	return [root, dir, wide, long, WISP_HIGH, wisp_start, 0, laid, true]


## The side the wind comes from here, 1 for the right. With the wind along
## the road it's either, by `pick`.
func _windward(track: TrackPath, offset: float, pick: float) -> float:
	var facing := track.right_at(offset).dot(wind)
	if absf(facing) > 0.05:
		return signf(facing)
	return 1.0 if pick < 0.5 else -1.0


## The flat way a tongue runs from the `side` edge here: with the wind, but
## always slanting into the road at least LEAST_SLANT, then swayed.
func _downwind(track: TrackPath, offset: float, side: float, sway: float) -> Vector3:
	var into := _flat(-track.right_at(offset) * side)
	var forward := _flat(track.forward_at(offset))
	var down := -wind
	var across := clampf(down.dot(into), LEAST_SLANT, 1.0)
	var along := down.dot(forward)
	var dir := into * across + forward * (1.0 if along >= 0.0 else -1.0) * sqrt(1.0 - across * across)
	return dir.normalized().rotated(Vector3.UP, sway)


## A tongue from the `side` edge at `offset`, running along `dir` until its
## tip is `reach` of the road's width across, or less where the road would
## leave it (see _clip()). Where there's no ground beside the road its root
## stays on the road. Empty if there's too little of it left.
func _tongue(track: TrackPath, offset: float, side: float, dir: Vector3, reach: float, wide: float, high: float, start: float) -> Array:
	var half := track.width * 0.5
	var right := track.right_at(offset)
	var into := _flat(-right * side)
	var cross := maxf(dir.dot(into), 0.2)
	var spread := absf(Vector3.UP.cross(dir).dot(into))
	var root_across := half + PAST_EDGE if _grounded(track, offset) else half - wide * 0.5 * spread - 0.1
	var long := (root_across - half + reach * track.width) / cross
	var root := track.point_at(offset) + right * side * root_across
	long = _clip(track, root, dir, long, offset, wide, false)
	if long < LEAST_LONG:
		return []
	return [root, dir, wide, long, high, start, 0, offset, false]


## How far a lump from `root` along `dir` can run, up to `long`, and still
## lie on the road: it stops before it crosses back off the road, where the
## road curves away under it, where the road's more than HUG off its flat,
## or where it isn't flat plain road. One `from_road` must start on it; any
## other may start beside it.
func _clip(track: TrackPath, root: Vector3, dir: Vector3, long: float, laid: float, wide: float, from_road: bool) -> float:
	var up := track.up_at(laid)
	var flat := (dir - up * dir.dot(up)).normalized()
	var half := track.width * 0.5
	var hint := laid
	var on := false
	var s := 0.0
	var good := 0.0
	while s <= long + 0.001:
		var point := root + flat * s
		var o := track.offset_of(point, hint, 20.0)
		hint = o
		var middle := track.point_at(o)
		var right := track.right_at(o)
		var across := (point - middle).dot(right)
		var inside := absf(across) < half - wide * _taper(s / long) * 0.25
		if inside:
			on = true
		elif on or from_road:
			break
		if absf((middle + right * across - point).dot(up)) > HUG or not _flat_road(track, o):
			break
		good = s
		s += CLIP_STEP
	return long if good >= long - CLIP_STEP else maxf(good, 0.0)


## How far along the road a bunch goes, as from and to, from each lump's
## root to its tip.
func _span(track: TrackPath, offset: float, bunch: Array) -> Vector2:
	var from := offset
	var to := offset
	for l in bunch:
		var laid: float = l[7]
		var half_wide: float = l[2] * 0.5
		for end in [l[0], l[0] + l[1] * l[3]]:
			var shift := track.offset_of(end, laid, 60.0) - offset
			shift -= track.length * roundf(shift / track.length)
			from = minf(from, offset + shift - half_wide)
			to = maxf(to, offset + shift + half_wide)
	return Vector2(from, to)


## Whether a bunch from `from` to `to` along the road would be on flat road
## and clear of the bunches laid already. The road's checked a little past
## its ends too.
func _free(track: TrackPath, taken: Array, from: float, to: float) -> bool:
	var at := from - 3.0
	while at < to + 3.0:
		if not _flat_road(track, fposmod(at, track.length)):
			return false
		at += 3.0
	if not _flat_road(track, fposmod(to + 3.0, track.length)):
		return false
	for t in taken:
		for shift in [-track.length, 0.0, track.length]:
			if from < t[1] + shift + BUNCH_GAP and to > t[0] + shift - BUNCH_GAP:
				return false
	return true


func _add_laid(l: Array) -> void:
	add_tongue_at(l[0], l[1], l[2], l[3], l[4], l[5], l[7], l[8])


## Lays a tongue now from the `side` edge at `offset`, slanting `slant`
## radians off straight across toward the way the road goes, its tip
## `reach` of the way across. Tests make their own this way.
func add_tongue(track: TrackPath, offset: float, side: float, reach: float, wide: float, start := -1.0, slant := 0.0) -> void:
	var into := _flat(-track.right_at(offset) * side)
	var dir := (into * cos(slant) + _flat(track.forward_at(offset)) * sin(slant)).normalized()
	var tongue := _tongue(track, offset, side, dir, reach, wide, 1.0, start)
	if not tongue.is_empty():
		_add_laid(tongue)


## Whether there's ground beside the road here for snow to lie on, not a
## drop or the open sky.
static func _grounded(track: TrackPath, offset: float) -> bool:
	if Scenery.theme_named(track.theme).get("void", false):
		return false
	var k := track._index_before(offset)
	return track.solids[k] and track.points[k].y - track.grounds[k] < TrackBuilder.RAISED


## Puts a lump here, its root at `root`, running along `dir`, `wide` at the
## root and `long` when full, `high` of DEEP at most, starting to grow at
## `start`, laid from `laid` along the road (below 0 if it wasn't). One
## that `only_looks` has no depth.
func add_tongue_at(root: Vector3, dir: Vector3, wide: float, long: float, high: float, start := -1.0, laid := -1.0, only_looks := false) -> void:
	var flat := _flat(dir)
	_root.append(root)
	_dir.append(flat)
	_wide.append(wide)
	_long.append(long)
	_high.append(high)
	_laid.append(laid)
	_only_looks.append(only_looks)
	var reach := Vector2(long * 0.5, wide * 0.5).length()
	_register(root + flat * long * 0.5, reach, start, reach if not only_looks else -1.0)
	_drawn.append(0.0)


## A drift this big, for tests: full depth at `middle` with the crest
## running north and south, `radius` to each side of it.
func add(middle: Vector3, radius: float, start := -1.0, _in_cells := true) -> void:
	var long := radius * 4.0
	add_tongue_at(middle - Vector3.RIGHT * long * CREST, Vector3.RIGHT, radius * 2.0, long, 1.0, start)


## How high a tongue is along it, from 0 at its root to 1 at its tip, as a
## share of its crest.
static func _along(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	if u < CREST:
		return 0.5 - 0.5 * cos(PI * u / CREST)
	if u < LIP:
		return lerpf(1.0, TAIL, smoothstep(CREST, LIP, u))
	return TAIL * pow(1.0 - (u - LIP) / (1.0 - LIP), 1.6)


## How high a tongue is across it, from its middle line (0) to its edge (1
## or -1), as a share of its height there.
static func _round(t: float) -> float:
	return 0.5 + 0.5 * cos(PI * clampf(t, -1.0, 1.0))


## How wide a tongue is along it, as a share of its root.
static func _taper(u: float) -> float:
	return 1.0 - (1.0 - TIP) * pow(clampf(u, 0.0, 1.0), 1.3)


## How deep the snow is at this point, 0 to 1, in w, and in xyz the flat
## pull toward the middle line of the tongue it's deepest in, easing to
## nothing over the last PULL_EASE metres to it.
func snow_at(point: Vector3) -> Vector4:
	var most := Vector4.ZERO
	for i in _cells.get(_cell(point), []):
		var grown := radius_now[i] / float(spots[i][1])
		if grown <= 0.0:
			continue
		var root := _root[i]
		if absf(point.y - root.y) >= 2.0:
			continue
		var dir := _dir[i]
		var dx := point.x - root.x
		var dz := point.z - root.z
		var u := (dx * dir.x + dz * dir.z) / (_long[i] * grown)
		if u <= 0.0 or u >= 1.0:
			continue
		var half_wide := _wide[i] * grown * _taper(u) * 0.5
		var v := dx * -dir.z + dz * dir.x
		if absf(v) >= half_wide:
			continue
		var depth := _along(u) * _round(v / half_wide) * _high[i] * growth(i)
		if depth > most.w:
			# The flat way from the middle line out to this side.
			var out := Vector3(-dir.z, 0.0, dir.x) * signf(v)
			var pull := -out * minf(absf(v) / PULL_EASE, 1.0)
			most = Vector4(pull.x, pull.y, pull.z, depth)
	return most


func factor_at(point: Vector3) -> float:
	return snow_at(point).w


## Whether one deep enough to go round is within `margin` of this point.
## Only the part that's at least a quarter as deep as its crest counts.
func in_the_way(point: Vector3, margin: float) -> bool:
	var low := _cell(point - Vector3.ONE * margin)
	var high := _cell(point + Vector3.ONE * margin)
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			for i in _cells.get(Vector2i(x, z), []):
				if not _worth_avoiding(i):
					continue
				var root := _root[i]
				if absf(point.y - root.y) >= 2.0:
					continue
				var grown := radius_now[i] / float(spots[i][1])
				var long := _long[i] * grown
				var dir := _dir[i]
				var dx := point.x - root.x
				var dz := point.z - root.z
				var along := dx * dir.x + dz * dir.z
				var across := absf(dx * -dir.z + dz * dir.x)
				if along > 0.08 * long - margin and along < 0.56 * long + margin and across < 0.42 * _wide[i] * grown * _taper(along / long) + margin:
					return true
	return false


func _worth_avoiding(i: int) -> bool:
	return not _only_looks[i] and growth(i) * _high[i] >= AVOID_DEPTH


## The lump's mesh height at x across (the root's width is 1) and u along.
static func _mesh_height(x: float, u: float) -> float:
	var half := _taper(u) * 0.5
	if absf(x) >= half:
		return 0.0
	return _along(u) * _round(x / half)


func _mesh() -> Mesh:
	return lump_mesh()


static func lump_mesh() -> Mesh:
	if _lump == null:
		# One lump: x across it from -0.5 to 0.5 at the root, narrowing to
		# the tip, z along from the root (0) to the tip (1), one high at the
		# crest. Pale blue-grey low down and white on top, and see-through
		# at the rim, more so toward the tip.
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var acrosses := [-0.5, -0.3, 0.0, 0.3, 0.5]
		var alongs := [0.0, CREST, LIP, 0.58, 0.8, 1.0]
		var shows_across := [0.0, 1.0, 1.0, 1.0, 0.0]
		var shows_along := [0.0, 1.0, 1.0, 1.0, 0.6, 0.0]
		var point := func(a: int, b: int) -> Array:
			var u: float = alongs[b]
			var x: float = acrosses[a] * _taper(u)
			var v := Vector3(x, _mesh_height(x, u), u)
			var colour := RIM.lerp(Color.WHITE, smoothstep(0.0, 0.6, v.y))
			colour.a = shows_across[a] * shows_along[b]
			return [v, colour]
		for a in acrosses.size() - 1:
			for b in alongs.size() - 1:
				var corners: Array = [point.call(a, b), point.call(a, b + 1), point.call(a + 1, b + 1), point.call(a + 1, b)]
				for c in [0, 2, 1, 0, 3, 2]:
					var v: Vector3 = corners[c][0]
					tool.set_color(corners[c][1])
					tool.set_normal(_lump_normal(v.x, v.z))
					tool.add_vertex(v)
		_lump = tool.commit()
	return _lump


## The lump's normal here, SHADING as steep as the mesh across and
## SHADING_ALONG along.
static func _lump_normal(x: float, u: float) -> Vector3:
	var e := 0.01
	var slope_across := (_mesh_height(x + e, u) - _mesh_height(x - e, u)) / (2.0 * e)
	var slope_along := (_mesh_height(x, minf(u + e, 1.0)) - _mesh_height(x, maxf(u - e, 0.0))) / (minf(u + e, 1.0) - maxf(u - e, 0.0))
	return Vector3(-slope_across * SHADING, 1.0, -slope_along * SHADING_ALONG).normalized()


## One lump drawn the way the drifts are, `size` across, along and high,
## for the splash to warm the shader up with.
static func sample(size: Vector3) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = lump_mesh()
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D(Basis.from_scale(size), Vector3.ZERO))
	multi.set_instance_color(0, SNOW)
	multi.set_instance_custom_data(0, Color(float(SceneryKit.DRIFT), 0.0, 0.0, 0.0))
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.material_override = drift_material()
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return draw


## Which way is up at this one.
func _up_of(i: int) -> Vector3:
	return _track.up_at(_laid[i] if _laid[i] >= 0.0 else _track.offset_of(spots[i][0]))


func _colour() -> Color:
	return SNOW


func _colour_of(i: int) -> Color:
	var colour := ON_ICE if _on_ice(i) else SNOW
	return Color(colour, WISP_SHOW) if _only_looks[i] else colour


## Whether the middle of this one, when full, lies on an ice piece.
func _on_ice(i: int) -> bool:
	if _track == null or _track.piece_of.is_empty():
		return false
	var at := _track.offset_of(spots[i][0], _laid[i], 30.0) if _laid[i] >= 0.0 else _track.offset_of(spots[i][0])
	return _track.pieces[_track.piece_of[_track._index_before(at)]].surface == "ice"


func _material() -> Material:
	return drift_material()


static func drift_material() -> Material:
	if _drift_material == null:
		var rim := ShaderMaterial.new()
		rim.shader = TrackBuilder.shader_for(RIM_SHADER.replace("CORE_ALPHA", str(CORE)))
		rim.render_priority = -1
		_drift_material = ShaderMaterial.new()
		_drift_material.shader = TrackBuilder.shader_for(DRIFT_SHADER.replace("CORE_ALPHA", str(CORE)))
		_drift_material.next_pass = rim
	return _drift_material


func _surface() -> int:
	return SceneryKit.DRIFT


## Puts one where it is at the size it is now, growing out from its root.
func _place(i: int) -> void:
	var grown := maxf(radius_now[i] / float(spots[i][1]), 0.01)
	var up := _ups[i]
	var dir := (_dir[i] - up * _dir[i].dot(up)).normalized()
	var across := up.cross(dir)
	var shape := Basis(across * _wide[i] * grown, up * maxf(DEEP * growth(i) * _high[i], 0.01), dir * _long[i] * grown)
	_multi.set_instance_transform(i, Transform3D(shape, _root[i] + up * 0.02))
	_drawn[i] = radius_now[i]


## Lumps lying on the road, drawn all at once.
func _draw() -> void:
	if spots.is_empty():
		return
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.use_custom_data = true
	_multi.mesh = _mesh()
	_multi.instance_count = spots.size()
	var shown := 0
	for i in spots.size():
		_ups.append(_up_of(i))
		_multi.set_instance_color(i, _colour_of(i))
		_multi.set_instance_custom_data(i, Color(float(_surface()), 0.0, 0.0, 0.0))
		_place(i)
		if radius_now[i] > 0.0:
			shown = i + 1
	_multi.visible_instance_count = shown
	# Sized to the whole lot full grown, since they grow while it's drawn.
	var box := AABB(spots[0][0], Vector3.ZERO)
	for s in spots:
		box = box.expand(s[0] + Vector3(s[1], 2.0, s[1])).expand(s[0] - Vector3(s[1], 0.5, s[1]))
	_multi.custom_aabb = box
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = _multi
	draw.material_override = _material()
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)


## Draws again the ones that have grown since they were last drawn.
func _show() -> void:
	if _multi == null:
		return
	var shown := 0
	var redraw := false
	for i in spots.size():
		if radius_now[i] > 0.0:
			shown = i + 1
		if absf(radius_now[i] - _drawn[i]) > REDRAW or (_drawn[i] == 0.0) != (radius_now[i] == 0.0):
			redraw = true
	if redraw:
		for i in shown:
			_place(i)
		_multi.visible_instance_count = shown


func _make_powder() -> void:
	if spots.is_empty():
		set_process(false)
		return
	if _powder_shader == null:
		_powder_shader = Shader.new()
		_powder_shader.code = POWDER_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_powder = MultiMesh.new()
	_powder.transform_format = MultiMesh.TRANSFORM_3D
	_powder.use_colors = true
	_powder.use_custom_data = true
	_powder.mesh = quad
	_powder.instance_count = PUFFS
	_powder.visible_instance_count = 0
	_powder.custom_aabb = _multi.custom_aabb.grow(4.0) if _multi != null else AABB()
	var look := ShaderMaterial.new()
	look.shader = _powder_shader
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = _powder
	draw.material_override = look
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)


## Throws up powder behind karts pushing through a drift near a camera, and
## moves the puffs along. It's only for looks, so it's not the same on
## every device.
func _process(delta: float) -> void:
	if _powder == null:
		return
	var cams := get_tree().get_nodes_in_group("race_cameras")
	for kart in karts:
		if not is_instance_valid(kart):
			continue
		var speed: float = kart.linear_velocity.length()
		var depth := factor_at(kart.global_position) if speed > POWDER_SPEED else 0.0
		if depth <= 0.05 or not _near(kart, cams):
			_owed.erase(kart)
			continue
		var owed: float = _owed.get(kart, 0.0) + PUFF_RATE * depth * speed / 20.0 * delta
		while owed >= 1.0 and _puffs.size() < PUFFS:
			owed -= 1.0
			var back: Vector3 = kart.global_basis.z
			var side: Vector3 = kart.global_basis.x * _rng.randf_range(-0.9, 0.9)
			var throw: Vector3 = kart.linear_velocity * 0.25 + Vector3.UP * _rng.randf_range(1.5, 3.0) + side * 1.5
			_puffs.append([kart.global_position + back * 0.6 + side + Vector3.UP * 0.2, throw, 0.0])
		_owed[kart] = minf(owed, 1.0)
	if _puffs.is_empty() and _powder.visible_instance_count == 0:
		return
	var i := 0
	while i < _puffs.size():
		var puff: Array = _puffs[i]
		puff[2] += delta
		if puff[2] >= PUFF_LIFE:
			_puffs.remove_at(i)
			continue
		puff[1] += Vector3.DOWN * 4.0 * delta
		puff[1] *= 1.0 - minf(2.0 * delta, 1.0)
		puff[0] += puff[1] * delta
		i += 1
	for n in _puffs.size():
		var puff: Array = _puffs[n]
		var t: float = puff[2] / PUFF_LIFE
		_powder.set_instance_custom_data(n, Color(puff[0].x, puff[0].y, puff[0].z, lerpf(0.5, 1.6, t)))
		_powder.set_instance_color(n, Color(POWDER, 1.0 - t * t))
	_powder.visible_instance_count = _puffs.size()


func _near(kart: Node3D, cams: Array) -> bool:
	if cams.is_empty():
		return false
	for cam in cams:
		if cam.target == kart or kart.global_position.distance_squared_to(cam.global_position) < POWDER_RANGE * POWDER_RANGE:
			return true
	return false
