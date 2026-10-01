class_name TrackPiece
extends RefCounted

## One piece of track, the way it sits in its own space. It starts at the
## origin heading toward -Z, and `exit()` says where the next piece clicks on.
##
## Everything lines up on a grid of tiles 32 m square, with heights in levels
## of 3 m. Every piece starts and ends in the middle of a tile edge, flat and
## level, so any piece can follow any other.
##
## The tiles are sized for the karts, which are about 1.6 times the size of
## real ones. The tightest bend is a real kart hairpin at that size, and the
## courses are as big for them as real kart circuits are for real karts.

const TILE := 32.0
## The size tiles were before the courses were made kart sized. A course file
## without a "grid" in it was made with these.
const OLD_TILE := 16.0
const LEVEL := 3.0

var type := "straight"
## How many tiles long a straight, ramp, crest, jump or slant is.
var tiles := 1
## How many tiles a slant moves across, positive to the right.
var across := 0
## -1 for a left bend, 1 for a right one, 0 for everything else.
var turn := 0
var radius := 0.0
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
		"curve":
			piece.turn = -1 if str(spec.get("turn", "right")) == "left" else 1
			var size := int(spec.get("size", 2))
			piece.radius = (size - 0.5) * TILE
			piece.bank = deg_to_rad(float(spec.get("bank", 0.0)))
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
	if piece.type == "curve" and absf(piece.bank) >= STICKY_BANK:
		piece.sticky = true
	piece.sticky = bool(spec.get("sticky", piece.sticky))
	# The inside of a cut bend is open, or there'd be nothing to cut across.
	if piece.cut:
		if piece.turn > 0:
			piece.wall_right = false
		else:
			piece.wall_left = false
	return piece


func to_spec() -> Dictionary:
	var spec := { "type": type }
	match type:
		"curve":
			spec["turn"] = "left" if turn < 0 else "right"
			spec["size"] = int(radius / TILE + 0.5)
			if bank != 0.0:
				spec["bank"] = rad_to_deg(bank)
			if cut:
				spec["cut"] = true
			if rise != 0.0:
				spec["rise"] = int(round(rise / LEVEL))
		"ramp":
			spec["length"] = tiles
			spec["rise"] = int(round(rise / LEVEL))
		"crest":
			spec["length"] = tiles
			spec["height"] = crest_height
		"straight":
			spec["length"] = tiles
		"loop", "corkscrew":
			spec["side"] = "left" if side < 0 else "right"
		"slant":
			spec["length"] = tiles
			spec["turn"] = "left" if across < 0 else "right"
			spec["across"] = absi(across)
			if rise != 0.0:
				spec["rise"] = int(round(rise / LEVEL))
	if surface != "asphalt":
		spec["surface"] = surface
	if edges != "auto" and not (cut and edges in ["left_open", "right_open"]):
		spec["edges"] = edges
	return spec


## Whether the walls go all the way along, wherever the road is.
func forced_walls() -> bool:
	return edges == "walls"


## About how far it is along the middle of the piece, in metres.
func path_length() -> float:
	if type == "curve":
		var arc := radius * PI * 0.5
		return sqrt(arc * arc + rise * rise)
	if type == "loop":
		return LOOP_IN + LOOP_ARC + _loop_out()
	if type == "corkscrew":
		_corkscrew_profile()
		return 2.0 * CORKSCREW_RUN + (_cork_points.size() - 1) * _cork_step
	if type == "slant":
		var total := 0.0
		for k in 32:
			total += point(k / 32.0).distance_to(point((k + 1) / 32.0))
		return total
	var run := tiles * TILE
	return sqrt(run * run + rise * rise)


## The point on the middle of the road, `t` of the way through the piece.
func point(t: float) -> Vector3:
	var run := tiles * TILE
	match type:
		"curve":
			var angle := t * PI * 0.5
			return Vector3(turn * (radius - radius * cos(angle)), rise * smoothstep(0.0, 1.0, t), -radius * sin(angle))
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
	if type != "curve":
		return 0.0
	# Eases in and out, so the road never starts rolling (or climbing, since
	# banked road leans up from its low edge) all at once, which would throw
	# karts into the air.
	return bank * pow(sin(PI * t), 2.0) * turn


## Whether there's road here. Only the jump has a gap.
func solid(t: float) -> bool:
	if type != "jump":
		return true
	var x := t * tiles * TILE
	return x <= KICKER_END or x >= LANDING_START


## Where the next piece starts, in this piece's space.
func exit() -> Transform3D:
	var end := point(1.0)
	if type == "loop":
		return Transform3D(Basis.IDENTITY, Vector3(side * LOOP_STEP, 0.0, -3.0 * TILE))
	if type == "slant" or type == "corkscrew":
		return Transform3D(Basis.IDENTITY, Vector3(across * TILE, rise, -tiles * TILE))
	if type == "curve":
		return Transform3D(Basis(Vector3.UP, -turn * PI * 0.5), end)
	return Transform3D(Basis.IDENTITY, end)
