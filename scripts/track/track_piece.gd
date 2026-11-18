class_name TrackPiece
extends RefCounted

## One piece of track, the way it sits in its own space. It starts at the
## origin heading toward -Z, and `exit()` says where the next piece clicks on.
##
## Lengths use tiles 32 m long, with heights in levels of 3 m. Connectors
## are flat and level, with headings in steps of 15 degrees.
##
## The tiles are sized for the karts, which are about 1.6 times the size of
## real ones. The tightest bend is a real kart hairpin at that size, and the
## courses are as big for them as real kart circuits are for real karts.

const TILE := 32.0
## The size tiles were before the courses were made kart sized. A course file
## without a "grid" in it was made with these.
const OLD_TILE := 16.0
const LEVEL := 3.0
## Most a bend or offset climbs for its length, as rise over distance.
const MAX_SLOPE := 0.12
const ARC_ANGLES := [15, 30, 45, 60, 75, 90]
const ADJUSTABLE_TYPES := ["adjustable_straight", "adjustable_offset", "connector", "adjustable_split"]
const MAX_METRES := 512.0
const MAX_SHIFT := 256.0
## Pieces where the road parts round an island and joins up again.
const SPLIT_TYPES := ["split", "adjustable_split", "split_bend", "rough_split", "jump_split"]
## Splits whose branches aren't mirror images of each other. Their spec's
## "side" (or a split bend's "turn") says which way they go.
const UNEVEN_SPLITS := ["split_bend", "rough_split", "jump_split"]
## A split's branches at their narrowest, the island at its widest, and how
## far along the branches take to part, in metres. The ramp is for branches
## that move SPLIT_OUT out from the middle; further out takes longer.
const SPLIT_BRANCH := 10.0
const SPLIT_ISLAND := 12.0
const SPLIT_RAMP := 26.0
const SPLIT_OUT := (SPLIT_ISLAND + SPLIT_BRANCH) * 0.5
## Islands this wide or wider have branches as wide as the road.
const SPLIT_FULL_ISLAND := 24.0
## How long an adjustable split can be and how wide its island, in metres.
const SPLIT_LEAST_METRES := 64.0
const SPLIT_MOST_METRES := 256.0
const SPLIT_LEAST_ISLAND := 8.0
const SPLIT_MOST_ISLAND := 64.0
## The most of a split's length each ramp can take, so there's some straight
## between them.
const SPLIT_RAMP_SHARE := 0.45
## A split bend's outside branch, how far out from the middle line it runs,
## by size.
const BEND_SPLIT_OUT := {3: 6.0, 4: 6.0}
## How far the inside branch cuts toward that straight line, by size, so
## both branches take about as long.
const BEND_SPLIT_CUT := {3: 0.6, 4: 0.75}
## How far along a split bend's inside branch takes to part from the
## middle line, as a share of the bend's radius. The outside one takes
## longer still.
const BEND_SPLIT_RAMP := 0.7
## The rough split: its dirt branch, how wide it is, and the island between
## it and the tarmac branch that swings out.
const ROUGH_DIRT := 10.0
const ROUGH_ISLAND := 4.0
const ROUGH_TILES := 3
const JUMP_SPLIT_TILES := 4

var type := "straight"
## How many tiles long a straight, ramp, crest, jump or slant is.
var tiles := 1
## How many tiles a slant moves across, positive to the right.
var across := 0
## Dimensions of metre-sized pieces and the local connector control polygon.
var metres := 32.0
var shift := 0.0
var connector_end := Vector3.ZERO
var connector_heading := 0
var handles := Vector2.ONE
## -1 for a left bend, 1 for a right one, 0 for everything else.
var turn := 0
var radius := 0.0
## How many degrees an arc turns through. Legacy curves always turn 90.
var angle := 90
## How far a ramp climbs (or drops, if negative), in metres. Bends and
## slants can climb too, so a bridge can start anywhere.
var rise := 0.0
## How high a crest is, in metres.
var crest_height := 1.5
## How far a bend leans in at its middle, in radians.
var bank := 0.0
var surface := "asphalt"
## Walls down each side. On "auto" there's a wall only where you'd fall off
## (road up in the air, loops, wall rides and banked bends), and the rest runs
## out onto the grass like a real kart track. "walls" puts them all the way
## along, and "open" (or "left_open" or "right_open") leaves them off.
var edges := "auto"
## Whether each side can have a wall at all.
var wall_left := true
var wall_right := true
## A bend with a dirt patch inside it that you can cut across.
var cut := false
## Which way a loop steps across as it goes around, or a corkscrew rolls,
## 1 for right and -1 for left.
var side := 1
## Road you stick to at speed, like the inside of a loop or a steep wall.
var sticky := false
## A straight tile with a railway across its middle, where a train crosses
## the road (see LevelCrossing). Its spec says "crossing" for the type.
var crossing := false
## The same piece driven from its exit back to its start.
var inverted := false
var jump_reversed := false
## How wide a split's island gets in its middle, in metres.
var island := SPLIT_ISLAND

# The loop has a run in, the loop itself and a run out. It tightens gradually
# on the way in and eases off on the way out, and steps one tile across as it
# goes around so the road coming out never runs into the road going in.
const LOOP_ARC := 110.0 # length of road around the loop itself, in metres
const LOOP_EASE := 0.2 # how much of it is spent tightening up, and easing off
const LOOP_IN := 16.0
const LOOP_STEP := TILE
## How much of that it steps across up in the air. Any more and the loop
## twists into a corkscrew that karts fall off the top of. The rest is a
## gentle S on the ground coming out.
const LOOP_AIR_STEP := 18.0
const LOOP_SAMPLES := 400

## The loop's shape in its own plane, worked out once. For every step around
## it there's (height, distance along, how far it has turned).
static var _loop_shape := PackedVector3Array()

# The corkscrew is a roller coaster's: a straight run in, one roll all the way
# round, and a straight run out, three tiles along and one across. The roll
# turns the road about one line at an angle to the way in, slowly at first,
# then faster, then slowly again, so it never gets tight all at once. You ride
# on the inside of it without steering, and come out a tile across facing the
# way you went in.
const CORKSCREW_RUN := 8.0
const CORKSCREW_SAMPLES := 600
## The roll's shape, worked out once: where the road is and which way is up,
## for the right hand one, a step at a time from its start.
static var _cork_points := PackedVector3Array()
static var _cork_ups := PackedVector3Array()

## Bends banked steeper than this are wall rides, and stick.
const STICKY_BANK := deg_to_rad(40.0)
## How far a banked bend takes to lean all the way in or out, in metres.
const BANK_EASE := 24.0

# The jump has a kicker, a gap and a landing ramp, in metres along the piece.
# The landing starts with a short run up from the ground, so a kart that
# falls short into the gap can drive up it instead of hitting a wall.
const KICKER_END := 16.0
const KICKER_HEIGHT := 1.5
const LANDING_START := 26.0
const LANDING_TOP := 29.0
const LANDING_HEIGHT := 1.0
const LANDING_END := 44.0


static func from_spec(spec: Dictionary) -> TrackPiece:
	var piece := TrackPiece.new()
	piece.type = str(spec.get("type", "straight"))
	piece.surface = str(spec.get("surface", "asphalt"))
	match piece.type:
		"half_straight", "quarter_straight":
			pass
		"adjustable_straight", "adjustable_offset":
			piece.metres = float(spec.get("metres", 32.0))
			piece.shift = float(spec.get("shift", 0.0))
			if piece.type == "adjustable_offset":
				piece.rise = float(spec.get("rise", 0)) * LEVEL
		"adjustable_split":
			piece.metres = float(spec.get("metres", SPLIT_LEAST_METRES))
			piece.island = float(spec.get("island", SPLIT_ISLAND))
		"connector":
			var end: Array = spec.get("end", [0.0, -32.0])
			piece.connector_end = Vector3(float(end[0]), 0.0, float(end[1]))
			piece.connector_heading = int(spec.get("heading", 0))
			var lengths: Array = spec.get("handles", [10.0, 10.0])
			piece.handles = Vector2(float(lengths[0]), float(lengths[1]))
		"curve", "arc":
			piece.turn = -1 if str(spec.get("turn", "right")) == "left" else 1
			var size := int(spec.get("size", 2))
			piece.radius = (size - 0.5) * TILE
			piece.bank = deg_to_rad(float(spec.get("bank", 0.0)))
			if piece.type == "arc":
				piece.angle = int(spec.get("angle", 90))
				assert(piece.angle in ARC_ANGLES, "Arc angles must be 15, 30, 45, 60, 75 or 90 degrees")
				assert(size >= 1 and size <= 4, "Arc sizes must be 1 to 4")
				assert(not bool(spec.get("cut", false)), "Only legacy curves can have a shortcut")
			else:
				piece.cut = bool(spec.get("cut", false))
			piece.rise = float(spec.get("rise", 0)) * LEVEL
		"ramp":
			piece.tiles = int(spec.get("length", 2))
			piece.rise = float(spec.get("rise", 1)) * LEVEL
		"crest":
			piece.tiles = int(spec.get("length", 2))
			piece.crest_height = float(spec.get("height", 1.5))
		"jump":
			piece.tiles = 3
		"loop":
			piece.tiles = 3
			piece.side = -1 if str(spec.get("side", "right")) == "left" else 1
			piece.sticky = true
		"corkscrew":
			piece.tiles = 3
			piece.side = -1 if str(spec.get("side", "right")) == "left" else 1
			piece.across = piece.side
			piece.sticky = true
		"slant":
			piece.tiles = maxi(int(spec.get("length", 2)), 2)
			var shift := int(spec.get("across", 1))
			piece.across = -absi(shift) if str(spec.get("turn", "right")) == "left" else absi(shift)
			piece.rise = float(spec.get("rise", 0)) * LEVEL
		"crossing":
			piece.type = "straight"
			piece.tiles = 1
			piece.crossing = true
		"split":
			piece.tiles = maxi(int(spec.get("length", 2)), 2)
			piece.island = float(spec.get("island", SPLIT_ISLAND))
		"split_bend":
			piece.turn = -1 if str(spec.get("turn", "right")) == "left" else 1
			var bend_size := clampi(int(spec.get("size", 3)), 3, 4)
			piece.radius = (bend_size - 0.5) * TILE
		"rough_split":
			piece.tiles = ROUGH_TILES
			piece.side = -1 if str(spec.get("side", "right")) == "left" else 1
		"jump_split":
			piece.tiles = JUMP_SPLIT_TILES
			piece.side = -1 if str(spec.get("side", "right")) == "left" else 1
		_:
			piece.type = "straight"
			piece.tiles = int(spec.get("length", 1))
	piece.edges = str(spec.get("edges", "auto"))
	match piece.edges:
		"open":
			piece.wall_left = false
			piece.wall_right = false
		"left_open":
			piece.wall_left = false
		"right_open":
			piece.wall_right = false
		"walls":
			pass
		_:
			piece.edges = "auto"
	if piece.type in ["curve", "arc"] and absf(piece.bank) >= STICKY_BANK:
		piece.sticky = true
	piece.sticky = bool(spec.get("sticky", piece.sticky))
	# The inside of a cut bend is open, or there'd be nothing to cut across.
	if piece.cut:
		if piece.turn > 0:
			piece.wall_right = false
		else:
			piece.wall_left = false
	# A split lies on the ground and runs out onto grass both sides.
	if piece.is_split():
		piece.edges = "auto"
		piece.wall_left = false
		piece.wall_right = false
	return piece


func to_spec() -> Dictionary:
	var spec := { "type": type }
	match type:
		"adjustable_straight", "adjustable_offset":
			spec.metres = metres
			if type == "adjustable_offset":
				spec.shift = shift
				if rise != 0.0:
					spec["rise"] = _levels()
		"adjustable_split":
			spec.metres = metres
			spec.island = island
		"connector":
			spec.end = [connector_end.x, connector_end.z]
			spec.heading = connector_heading
			spec.handles = [handles.x, handles.y]
		"curve", "arc":
			if type == "arc":
				spec["angle"] = angle
			spec["turn"] = "left" if turn < 0 else "right"
			spec["size"] = int(radius / TILE + 0.5)
			if bank != 0.0:
				spec["bank"] = rad_to_deg(bank)
			if cut:
				spec["cut"] = true
			if rise != 0.0:
				spec["rise"] = _levels()
		"ramp":
			spec["length"] = tiles
			spec["rise"] = _levels()
		"crest":
			spec["length"] = tiles
			spec["height"] = crest_height
		"straight":
			if crossing:
				spec["type"] = "crossing"
			else:
				spec["length"] = tiles
		"loop", "corkscrew":
			spec["side"] = "left" if side < 0 else "right"
		"slant":
			spec["length"] = tiles
			spec["turn"] = "left" if across < 0 else "right"
			spec["across"] = absi(across)
			if rise != 0.0:
				spec["rise"] = _levels()
		"split":
			spec["length"] = tiles
			if island != SPLIT_ISLAND:
				spec["island"] = island
		"split_bend":
			spec["turn"] = "left" if turn < 0 else "right"
			spec["size"] = int(radius / TILE + 0.5)
		"rough_split", "jump_split":
			spec["side"] = "left" if side < 0 else "right"
	if surface != "asphalt":
		spec["surface"] = surface
	if edges != "auto" and not (cut and edges in ["left_open", "right_open"]):
		spec["edges"] = edges
	return spec


## The rise in drawer levels, a whole number when it is one.
func _levels() -> float:
	var levels := rise / LEVEL
	return roundf(levels) if absf(levels - roundf(levels)) < 0.000001 else levels


## Whether the walls go all the way along, wherever the road is.
func forced_walls() -> bool:
	return edges == "walls"


func is_split() -> bool:
	return type in SPLIT_TYPES


## The road's branches `t` of the way through the piece, left then right, each
## as Vector2(how far right of the middle line its middle is, how wide it is),
## in metres, for a course whose road is `road` wide. Most pieces have one
## branch down the middle, given twice. A split's branches overlap at its ends
## and part round the island in between.
func branches(t: float, road: float) -> PackedVector2Array:
	if not is_split():
		return PackedVector2Array([Vector2(0.0, road), Vector2(0.0, road)])
	var run := path_length()
	var two := _forward_branches(run * (1.0 - t if inverted else t), run, road)
	# Driven the other way, the left branch is on the right.
	if inverted:
		return PackedVector2Array([Vector2(-two[1].x, two[1].y), Vector2(-two[0].x, two[0].y)])
	return two


## branches() as the piece was made, `x` metres along it.
func _forward_branches(x: float, run: float, road: float) -> PackedVector2Array:
	match type:
		"split_bend":
			var out: float = BEND_SPLIT_OUT.get(int(radius / TILE + 0.5), 8.0)
			var ramp := radius * BEND_SPLIT_RAMP
			var apart := minf(smoothstep(0.0, ramp * 1.6, x), smoothstep(0.0, ramp * 1.6, run - x))
			# The inside branch cuts toward the straight line between the
			# bend's ends, eased in so it doesn't kink where it leaves.
			var half := deg_to_rad(45.0)
			var cut: float = BEND_SPLIT_CUT.get(int(radius / TILE + 0.5), 1.0)
			var chord := (radius - radius * cos(half) / cos(x / radius - half)) * cut
			var ease := minf(smoothstep(0.0, ramp, x), smoothstep(0.0, ramp, run - x))
			var inside := Vector2(turn * chord * ease, lerpf(road, SPLIT_BRANCH, ease))
			var outside := Vector2(-turn * out * apart, lerpf(road, SPLIT_BRANCH, apart))
			return PackedVector2Array([inside, outside] if turn < 0 else [outside, inside])
		"rough_split":
			var dirt_at := road * 0.5 - ROUGH_DIRT * 0.5
			var tarmac_at := dirt_at - ROUGH_DIRT * 0.5 - ROUGH_ISLAND - SPLIT_BRANCH * 0.5
			var ramp := minf(SPLIT_RAMP * sqrt(absf(tarmac_at) / SPLIT_OUT), run * SPLIT_RAMP_SHARE)
			var apart := minf(smoothstep(0.0, ramp, x), smoothstep(0.0, ramp, run - x))
			# The dirt branch is on the other side from the way the tarmac goes.
			var dirt := Vector2(-side * dirt_at * apart, lerpf(road, ROUGH_DIRT, apart))
			var tarmac := Vector2(side * absf(tarmac_at) * apart, lerpf(road, SPLIT_BRANCH, apart))
			return PackedVector2Array([tarmac, dirt] if side < 0 else [dirt, tarmac])
	var branch := split_branch(road)
	var ramp := minf(split_ramp(road), run * SPLIT_RAMP_SHARE)
	var apart := minf(smoothstep(0.0, ramp, x), smoothstep(0.0, ramp, run - x))
	var wide := lerpf(road, branch, apart)
	var out := (island + branch) * 0.5 * apart
	return PackedVector2Array([Vector2(-out, wide), Vector2(out, wide)])


## Which branch, 0 left or 1 right as driven, is the odd one out: a rough
## split's dirt branch or a jump split's jump. -1 on other pieces.
func odd_branch() -> int:
	var forward := -1
	if type == "rough_split":
		forward = 1 if side < 0 else 0
	elif type == "jump_split":
		forward = 0 if side < 0 else 1
	if forward < 0:
		return -1
	return 1 - forward if inverted else forward


## The surface of one branch (0 left, 1 right): a rough split's dirt branch
## is dirt, and the rest is the piece's own.
func branch_surface(branch: int) -> String:
	return "dirt" if type == "rough_split" and branch == odd_branch() else surface


## How far along a jump split's jump branch its kicker starts, in metres.
## The jump sits in the middle, and is always driven kicker first.
func _split_jump_start() -> float:
	return (run_length() - LANDING_END) * 0.5


## How high a branch's road is above the middle line `t` of the way through
## the piece: a jump split's kicker and landing.
func branch_lift(t: float, branch: int) -> float:
	if type != "jump_split" or branch != odd_branch():
		return 0.0
	var x := run_length() * t - _split_jump_start()
	return _jump_height(x) if x > 0.0 and x < LANDING_END else 0.0


## Whether a branch has road here. Only a jump split's jump has a gap.
func branch_solid(t: float, branch: int) -> bool:
	if type != "jump_split" or branch != odd_branch():
		return true
	var x := run_length() * t - _split_jump_start()
	return x <= KICKER_END or x >= LANDING_START


## How wide a split's branches are where they're apart, for a course whose
## road is `road` wide: SPLIT_BRANCH round a small island, widening to the
## road's width round a big one.
func split_branch(road: float) -> float:
	var full := maxf(road, SPLIT_BRANCH)
	return lerpf(SPLIT_BRANCH, full, clampf((island - SPLIT_ISLAND) / (SPLIT_FULL_ISLAND - SPLIT_ISLAND), 0.0, 1.0))


## How far along a split's branches take to part, in metres, so the S they
## make is no tighter than the one round a SPLIT_ISLAND island.
func split_ramp(road: float) -> float:
	var out := (island + split_branch(road)) * 0.5
	return SPLIT_RAMP * sqrt(maxf(out, SPLIT_OUT) / SPLIT_OUT)


## About how far it is along the middle of the piece, in metres.
func path_length() -> float:
	if type == "curve":
		var arc := radius * PI * 0.5
		return sqrt(arc * arc + rise * rise)
	if type == "arc":
		var arc := radius * deg_to_rad(angle)
		return sqrt(arc * arc + rise * rise)
	if type == "split_bend":
		return radius * PI * 0.5
	if type == "loop":
		return LOOP_IN + LOOP_ARC + _loop_out()
	if type == "corkscrew":
		_corkscrew_profile()
		return 2.0 * CORKSCREW_RUN + (_cork_points.size() - 1) * _cork_step
	if type in ["slant", "adjustable_offset", "connector"]:
		var total := 0.0
		for k in 32:
			total += point(k / 32.0).distance_to(point((k + 1) / 32.0))
		return total
	var run := run_length()
	return sqrt(run * run + rise * rise)


## The forward run of a straight piece, in metres.
func run_length() -> float:
	if type in ["adjustable_straight", "adjustable_offset", "adjustable_split"]:
		return metres
	if type == "quarter_straight":
		return TILE * 0.25
	return TILE * 0.5 if type == "half_straight" else tiles * TILE


## The point on the middle of the road, `t` of the way through the piece.
func point(t: float) -> Vector3:
	if inverted:
		if type == "jump" and jump_reversed:
			var run := run_length()
			return Vector3(0.0, _jump_height(run * t), -run * t)
		var finish := _forward_exit()
		var turn_back := Basis(Vector3.UP, PI) * finish.basis.inverse()
		return turn_back * (_forward_point(1.0 - t) - finish.origin)
	return _forward_point(t)


func _forward_point(t: float) -> Vector3:
	var run := run_length()
	match type:
		"adjustable_offset":
			var u := clampf(t, 0.0, 1.0)
			var sideways := u * u * u * (10.0 + u * (-15.0 + 6.0 * u))
			return Vector3(shift * sideways, rise * smoothstep(0.0, 1.0, u), -metres * u)
		"connector":
			var a := Vector3.FORWARD * handles.x
			var b := connector_end - _connector_forward() * handles.y
			var u := 1.0 - t
			return 3.0 * u * u * t * a + 3.0 * u * t * t * b + t * t * t * connector_end
		"curve", "split_bend":
			var angle := t * PI * 0.5
			return Vector3(turn * (radius - radius * cos(angle)), rise * smoothstep(0.0, 1.0, t), -radius * sin(angle))
		"arc":
			var radians := t * deg_to_rad(angle)
			return Vector3(turn * radius * (1.0 - cos(radians)), rise * smoothstep(0.0, 1.0, t), -radius * sin(radians))
		"ramp":
			return Vector3(0.0, rise * smoothstep(0.0, 1.0, t), -run * t)
		"crest":
			return Vector3(0.0, crest_height * pow(sin(PI * t), 2.0), -run * t)
		"jump":
			return Vector3(0.0, _jump_height(run * t), -run * t)
		"loop":
			return _loop_point(t)
		"corkscrew":
			return _corkscrew_point(t)
		"slant":
			return Vector3(across * TILE * _slant_shift(t), rise * smoothstep(0.0, 1.0, t), -run * t)
	return Vector3(0.0, 0.0, -run * t)


# A slant runs diagonally across the grid and ends facing the way it started,
# `across` tiles over. It eases into the diagonal and out again over about a
# tile at each end, so a long slant is a proper diagonal straight and a short
# one is an S bend. Real kart tracks are full of these.
func _slant_shift(t: float) -> float:
	var ease := clampf(1.0 / tiles, 0.15, 0.5)
	var eased := func(u: float) -> float:
		# How far across by `u`, with the slope easing in like sin squared.
		if u < ease:
			return u * 0.5 - ease / TAU * sin(TAU * u / (ease * 2.0))
		return ease * 0.5 + (u - ease)
	var total := 1.0 - ease
	if t <= 0.5:
		return eased.call(t) / total
	return 1.0 - eased.call(1.0 - t) / total


static func _loop_profile() -> PackedVector3Array:
	if not _loop_shape.is_empty():
		return _loop_shape
	var step := LOOP_ARC / LOOP_SAMPLES
	var ease := func(u: float) -> float:
		return smoothstep(0.0, LOOP_EASE, u) * smoothstep(0.0, LOOP_EASE, 1.0 - u)
	# Scale the bend so the loop turns exactly once all the way around.
	var total := 0.0
	for i in LOOP_SAMPLES:
		total += ease.call((i + 0.5) / LOOP_SAMPLES) * step
	var scale := TAU / total
	var height := 0.0
	var along := 0.0
	var turned := 0.0
	_loop_shape.append(Vector3.ZERO)
	for i in LOOP_SAMPLES:
		var bend: float = ease.call((i + 0.5) / LOOP_SAMPLES) * scale
		var mid := turned + bend * step * 0.5
		height += sin(mid) * step
		along += cos(mid) * step
		turned += bend * step
		_loop_shape.append(Vector3(height, along, turned))
	return _loop_shape


## How far the road runs on after the loop, so the piece still ends on the
## grid three tiles on.
static func _loop_out() -> float:
	var shape := _loop_profile()
	return 3.0 * TILE - LOOP_IN - shape[shape.size() - 1].y


func _loop_at(along: float) -> Vector3:
	var shape := _loop_profile()
	var f := clampf(along / LOOP_ARC, 0.0, 1.0) * LOOP_SAMPLES
	var i := mini(int(f), LOOP_SAMPLES - 1)
	return shape[i].lerp(shape[i + 1], f - i)


func _loop_point(t: float) -> Vector3:
	var along := t * path_length()
	var shape := _loop_profile()
	if along <= LOOP_IN:
		return Vector3(0.0, 0.0, -along)
	if along < LOOP_IN + LOOP_ARC:
		var at := _loop_at(along - LOOP_IN)
		# It steps across up in the air, in the middle of the loop, so that
		# near the ground the way in and the way out are apart.
		var across := side * LOOP_AIR_STEP * smoothstep(LOOP_EASE, 1.0 - LOOP_EASE, (along - LOOP_IN) / LOOP_ARC)
		return Vector3(across, at.x, -LOOP_IN - at.y)
	var end := shape[shape.size() - 1]
	var out := along - LOOP_IN - LOOP_ARC
	var rest := smoothstep(0.0, 1.0, out / _loop_out())
	return Vector3(side * (LOOP_AIR_STEP + (LOOP_STEP - LOOP_AIR_STEP) * rest), 0.0, -LOOP_IN - end.y - out)


## Whether a piece of this type turns you upside down, so you need speed to
## get round it.
static func turns_over(piece_type: String) -> bool:
	return piece_type == "loop" or piece_type == "corkscrew"


static var _cork_step := 0.0


## Works out the roll. It turns the road about a flat line at an angle to the
## way in, by an amount that eases from nothing up to a full turn. The angle
## and the roll's length are picked so it ends one tile across and leaves
## CORKSCREW_RUN of straight at each end of the three tiles.
static func _corkscrew_profile() -> void:
	if not _cork_points.is_empty():
		return
	var along := 3.0 * TILE - 2.0 * CORKSCREW_RUN
	# For a roll 1 m long at each angle, how far across and along it ends. It
	# all grows in step with the length, so that picks the length too.
	var lo := 0.2
	var hi := 1.2
	var angle := 0.0
	var length := 0.0
	for i in 50:
		angle = (lo + hi) * 0.5
		var end := _roll_end(angle)
		length = TILE / end.x
		if -end.z * length > along:
			lo = angle
		else:
			hi = angle
	var axis := Vector3(sin(angle), 0.0, -cos(angle))
	_cork_step = length / CORKSCREW_SAMPLES
	var at := Vector3(0.0, 0.0, -CORKSCREW_RUN)
	_cork_points.append(at)
	_cork_ups.append(Vector3.UP)
	for i in CORKSCREW_SAMPLES:
		at += Vector3.FORWARD.rotated(axis, _rolled((i + 0.5) / CORKSCREW_SAMPLES)) * _cork_step
		_cork_points.append(at)
		_cork_ups.append(Vector3.UP.rotated(axis, _rolled((i + 1.0) / CORKSCREW_SAMPLES)))


## How far round the roll has turned `u` of the way along it.
static func _rolled(u: float) -> float:
	return TAU * u - sin(TAU * u)


## Where a roll 1 m long about a line at this angle ends up.
static func _roll_end(angle: float) -> Vector3:
	var axis := Vector3(sin(angle), 0.0, -cos(angle))
	var at := Vector3.ZERO
	for i in CORKSCREW_SAMPLES:
		at += Vector3.FORWARD.rotated(axis, _rolled((i + 0.5) / CORKSCREW_SAMPLES)) / CORKSCREW_SAMPLES
	return at


func _corkscrew_point(t: float) -> Vector3:
	_corkscrew_profile()
	var along := t * path_length()
	var roll := (_cork_points.size() - 1) * _cork_step
	var mirror := Vector3(side, 1.0, 1.0)
	if along <= CORKSCREW_RUN:
		return Vector3(0.0, 0.0, -along)
	if along < CORKSCREW_RUN + roll:
		var f := (along - CORKSCREW_RUN) / _cork_step
		var i := mini(int(f), _cork_points.size() - 2)
		return _cork_points[i].lerp(_cork_points[i + 1], f - i) * mirror
	return Vector3(side * TILE, 0.0, -3.0 * TILE + (path_length() - along))


## Which way is up off the road here, before any banking, in the piece's
## space. It's straight up everywhere except on a loop or a corkscrew, where
## it points in toward the middle.
func up(t: float) -> Vector3:
	if inverted:
		var finish := _forward_exit()
		return Basis(Vector3.UP, PI) * finish.basis.inverse() * _forward_up(1.0 - t)
	return _forward_up(t)


func _forward_up(t: float) -> Vector3:
	if type == "corkscrew":
		var along := t * path_length() - CORKSCREW_RUN
		var roll := (_cork_points.size() - 1) * _cork_step
		if along <= 0.0 or along >= roll:
			return Vector3.UP
		var f := along / _cork_step
		var i := mini(int(f), _cork_ups.size() - 2)
		return _cork_ups[i].slerp(_cork_ups[i + 1], f - i) * Vector3(side, 1.0, 1.0)
	if type != "loop":
		return Vector3.UP
	var along := t * path_length()
	if along <= LOOP_IN or along >= LOOP_IN + LOOP_ARC:
		return Vector3.UP
	var turned := _loop_at(along - LOOP_IN).z
	return Vector3(0.0, cos(turned), sin(turned))


func _jump_height(x: float) -> float:
	if x <= KICKER_END:
		return KICKER_HEIGHT * pow(x / KICKER_END, 2.0)
	if x < LANDING_START:
		# Across the gap there's no road, but the middle line still runs
		# through the air so the AI and lap counting can follow it.
		return lerpf(KICKER_HEIGHT, 0.0, (x - KICKER_END) / (LANDING_START - KICKER_END))
	if x < LANDING_TOP:
		return LANDING_HEIGHT * smoothstep(LANDING_START, LANDING_TOP, x)
	if x < LANDING_END:
		return LANDING_HEIGHT * (0.5 + 0.5 * cos(PI * (x - LANDING_TOP) / (LANDING_END - LANDING_TOP)))
	return 0.0


## How far the road leans here. Positive tips the right side down.
func bank_at(t: float) -> float:
	if type not in ["curve", "arc"]:
		return 0.0
	# Eases in and out, so the road never starts rolling (or climbing, since
	# banked road leans up from its low edge) all at once, which would throw
	# karts into the air.
	var lean := bank * pow(sin(PI * t), 2.0) * turn
	return -lean if inverted else lean


## Whether this is a banked bend that tilts around its middle (see
## lean_at()). Wall rides lean up from their low edge instead.
func tilts() -> bool:
	return type in ["curve", "arc"] and bank != 0.0 and not sticky


## How far the road leans `t` of the way through the piece, like bank_at().
## A banked bend that isn't a wall ride leans in over BANK_EASE metres from
## `from_lean` and back out to `to_lean`, so a short bend never leans all the
## way and a run of bends banked the same way stays leaning through the
## joins (see join_lean()).
func lean_at(t: float, from_lean := 0.0, to_lean := 0.0) -> float:
	if not tilts():
		return bank_at(t)
	var full := bank_at(0.5)
	var along := path_length()
	var into := lerpf(from_lean, full, smoothstep(0.0, BANK_EASE, t * along))
	var out := lerpf(to_lean, full, smoothstep(0.0, BANK_EASE, (1.0 - t) * along))
	return signf(full) * minf(absf(into), absf(out))


## How far the road leans where this piece meets `next`: the smaller of the
## two leans when both are banked bends leaning the same way, otherwise
## level.
func join_lean(next: TrackPiece) -> float:
	if not tilts() or not next.tilts():
		return 0.0
	var mine := bank_at(0.5)
	var theirs := next.bank_at(0.5)
	if mine * theirs <= 0.0:
		return 0.0
	return signf(mine) * minf(absf(mine), absf(theirs))


## Whether there's road here. Only the jump has a gap.
func solid(t: float) -> bool:
	if type != "jump":
		return true
	var x := t * tiles * TILE
	return x <= KICKER_END or x >= LANDING_START


## How much the exit turns, in signed Godot yaw steps of 15 degrees.
func heading_delta() -> int:
	var delta := _forward_heading_delta()
	return -delta if inverted else delta


func _forward_heading_delta() -> int:
	if type == "connector":
		return connector_heading
	if type == "curve" or type == "split_bend":
		return -turn * 6
	if type == "arc":
		return -turn * (angle / 15)
	return 0


## Where the next piece starts, in this piece's space.
func exit() -> Transform3D:
	if inverted:
		var finish := _forward_exit()
		var basis := Basis(Vector3.UP, -heading_delta() * PI / 12.0)
		var turn_back := Basis(Vector3.UP, PI) * finish.basis.inverse()
		return Transform3D(basis, turn_back * -finish.origin)
	return _forward_exit()


func _forward_exit() -> Transform3D:
	var end := _forward_point(1.0)
	if type == "connector":
		return Transform3D(Basis(Vector3.UP, connector_heading * PI / 12.0), end)
	if type == "loop":
		return Transform3D(Basis.IDENTITY, Vector3(side * LOOP_STEP, 0.0, -3.0 * TILE))
	if type == "slant" or type == "corkscrew":
		return Transform3D(Basis.IDENTITY, Vector3(across * TILE, rise, -tiles * TILE))
	if type == "curve" or type == "split_bend":
		return Transform3D(Basis(Vector3.UP, -turn * PI * 0.5), end)
	if type == "arc":
		return Transform3D(Basis(Vector3.UP, -turn * deg_to_rad(angle)), end)
	return Transform3D(Basis.IDENTITY, end)


## Reflects the piece through its local YZ plane.
func mirror() -> void:
	turn = -turn
	side = -side
	across = -across
	shift = -shift
	connector_end.x = -connector_end.x
	connector_heading = -connector_heading
	_swap_sides()


## Makes the piece run from its old exit back to its old start.
func invert() -> void:
	if inverted:
		return
	inverted = true
	jump_reversed = type == "jump"
	_swap_sides()


func _swap_sides() -> void:
	var old_left := wall_left
	wall_left = wall_right
	wall_right = old_left
	if edges == "left_open":
		edges = "right_open"
	elif edges == "right_open":
		edges = "left_open"


func _connector_forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, connector_heading * PI / 12.0)


## Convert a drawer straight or offset without changing its endpoints or finish.
static func adjustable_spec(spec: Dictionary) -> Dictionary:
	var piece := from_spec(spec)
	var out := spec.duplicate(true)
	if piece.type in ["straight", "half_straight", "quarter_straight", "adjustable_straight"] and not piece.crossing:
		out = {"type": "adjustable_straight", "metres": piece.run_length()}
	elif piece.type in ["slant", "adjustable_offset"]:
		out = {"type": "adjustable_offset", "metres": piece.run_length(), "shift": piece.shift if piece.type == "adjustable_offset" else piece.across * TILE}
		if piece.rise != 0.0:
			out["rise"] = piece._levels()
	elif piece.type in ["split", "adjustable_split"]:
		out = {"type": "adjustable_split", "metres": piece.run_length(), "island": piece.island}
	else:
		return {}
	for key in ["surface", "edges"]:
		if spec.has(key):
			out[key] = spec[key]
	return out


## A local, level return to an existing connector, preserving both headings.
static func connector_spec(to: Transform3D, width: float) -> Dictionary:
	var yaw := atan2(to.basis.z.x, to.basis.z.z)
	var heading := roundi(yaw / (PI / 12.0))
	var basis := Basis(Vector3.UP, heading * PI / 12.0)
	var span := to.origin.length()
	if not to.origin.is_finite() or not to.basis.is_finite() or absf(to.origin.y) > 0.001 or span < 0.25 or span > MAX_METRES:
		return {}
	if basis.x.distance_to(to.basis.x) > 0.00001 or basis.y.distance_to(to.basis.y) > 0.00001 or basis.z.distance_to(to.basis.z) > 0.00001:
		return {}
	for factor in [0.3333333333, 0.5, 0.75, 1.0, 1.5]:
		var handle := maxf(0.05, span * factor)
		if handle > MAX_METRES:
			continue
		var spec := {"type": "connector", "end": [to.origin.x, to.origin.z], "heading": posmod(heading + 12, 24) - 12, "handles": [handle, handle]}
		if from_spec(spec).safe_connector(width):
			return spec
	return {}


## Reject cusps, reversing loops and bends tighter than the road can carry.
func safe_connector(width: float) -> bool:
	if type != "connector":
		return false
	var a := Vector3.FORWARD * handles.x
	var b := connector_end - _connector_forward() * handles.y
	# A monotone control polygon cannot hide a stationary reversal between samples.
	var chord := connector_end.normalized()
	for segment in [a, b - a, connector_end - b]:
		if segment.dot(chord) < -0.000001:
			return false
	var minimum_radius := maxf(width, 8.0)
	var samples := PackedVector2Array()
	for k in 97:
		var t := k / 96.0
		var u := 1.0 - t
		var velocity := 3.0 * u * u * a + 6.0 * u * t * (b - a) + 3.0 * t * t * (connector_end - b)
		var acceleration := 6.0 * u * (b - 2.0 * a) + 6.0 * t * (connector_end - 2.0 * b + a)
		var speed := velocity.length()
		if speed < 0.01:
			return false
		var bend := velocity.cross(acceleration).length()
		if bend > 0.000001 and speed * speed * speed / bend < minimum_radius:
			return false
		var p := point(t)
		samples.append(Vector2(p.x, p.z))
	for i in range(1, samples.size()):
		for j in range(i + 2, samples.size()):
			if Geometry2D.segment_intersects_segment(samples[i - 1], samples[i], samples[j - 1], samples[j]) != null:
				return false
	return true


## Whether edited metre dimensions leave enough radius for the road's width.
func safe_dimensions(width: float) -> bool:
	if type == "adjustable_straight":
		return true
	if type == "connector":
		return safe_connector(width)
	if type in UNEVEN_SPLITS:
		return true
	if is_split():
		var run := run_length()
		return run >= SPLIT_LEAST_METRES - 0.001 and run <= SPLIT_MOST_METRES + 0.001 \
			and island >= SPLIT_LEAST_ISLAND - 0.001 and island <= SPLIT_MOST_ISLAND + 0.001 \
			and split_ramp(width) <= run * SPLIT_RAMP_SHARE + 0.001
	if type != "adjustable_offset":
		return false
	if absf(rise) > MAX_SLOPE * path_length() + 0.001:
		return false
	for k in 97:
		var t := k / 96.0
		var velocity := Vector2(shift * 30.0 * t * t * (t - 1.0) * (t - 1.0), -metres)
		var acceleration := Vector2(shift * 60.0 * t * (1.0 - 3.0 * t + 2.0 * t * t), 0.0)
		var bend := absf(velocity.cross(acceleration))
		if bend > 0.000001 and pow(velocity.length(), 3.0) / bend < maxf(width, 8.0):
			return false
	return true
