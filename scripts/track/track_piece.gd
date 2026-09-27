class_name TrackPiece
extends RefCounted

## One piece of track, the way it sits in its own space: it starts at the
## origin heading toward -Z, and `exit()` says where the next piece clicks on.
##
## Everything lines up on a grid of tiles 16 m square, with heights in levels
## of 3 m. Every piece starts and ends in the middle of a tile edge, flat and
## level, so any piece can follow any other.

const TILE := 16.0
const LEVEL := 3.0

var type := "straight"
## How many tiles long a straight, ramp, crest or jump is.
var tiles := 1
## -1 for a left bend, 1 for a right one, 0 for everything else.
var turn := 0
var radius := 0.0
## How far a ramp climbs (or drops, if negative), in metres.
var rise := 0.0
## How high a crest is, in metres.
var crest_height := 1.5
## How far a bend leans in at its middle, in radians.
var bank := 0.0
var surface := "asphalt"
var wall_left := true
var wall_right := true
## A bend with a dirt patch inside it that you can cut across.
var cut := false
## Which way a loop steps across as it goes round: 1 right, -1 left.
var side := 1
## Road you stick to at speed, like the inside of a loop or a steep wall.
var sticky := false

# The loop: a run-in, the loop and a run-out. The loop tightens gradually on
# the way in and eases off on the way out, like a real one, instead of
# snapping from straight to a circle (which slammed karts into the road). It
# steps one tile across as it goes round, so the road coming out never runs
# into the road going in.
const LOOP_ARC := 80.0 # length of road round the loop itself, in metres
const LOOP_EASE := 0.2 # fraction of it spent tightening up, and easing off
const LOOP_IN := 16.0
const LOOP_STEP := TILE
const LOOP_SAMPLES := 400

## The loop's shape in its own plane, worked out once: for every step round
## it, (height, distance along, how far it has turned).
static var _loop_shape := PackedVector3Array()

## Bends banked steeper than this are wall rides, and stick.
const STICKY_BANK := deg_to_rad(40.0)

# The jump: a kicker, a gap and a landing ramp, in metres along the piece.
# The landing starts with a short run-up from the ground, so a kart that
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
		_:
			piece.type = "straight"
			piece.tiles = int(spec.get("length", 1))
	match str(spec.get("edges", "walls")):
		"open":
			piece.wall_left = false
			piece.wall_right = false
		"left_open":
			piece.wall_left = false
		"right_open":
			piece.wall_right = false
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
		"ramp":
			spec["length"] = tiles
			spec["rise"] = int(round(rise / LEVEL))
		"crest":
			spec["length"] = tiles
			spec["height"] = crest_height
		"straight":
			spec["length"] = tiles
		"loop":
			spec["side"] = "left" if side < 0 else "right"
	if surface != "asphalt":
		spec["surface"] = surface
	if not wall_left and not wall_right:
		spec["edges"] = "open"
	elif not wall_left:
		spec["edges"] = "left_open"
	elif not wall_right:
		spec["edges"] = "right_open"
	return spec


## About how far it is along the middle of the piece, in metres.
func path_length() -> float:
	if type == "curve":
		return radius * PI * 0.5
	if type == "loop":
		return LOOP_IN + LOOP_ARC + _loop_out()
	var run := tiles * TILE
	return sqrt(run * run + rise * rise)


## The point on the middle of the road, `t` of the way through the piece.
func point(t: float) -> Vector3:
	var run := tiles * TILE
	match type:
		"curve":
			var angle := t * PI * 0.5
			return Vector3(turn * (radius - radius * cos(angle)), 0.0, -radius * sin(angle))
		"ramp":
			return Vector3(0.0, rise * smoothstep(0.0, 1.0, t), -run * t)
		"crest":
			return Vector3(0.0, crest_height * pow(sin(PI * t), 2.0), -run * t)
		"jump":
			return Vector3(0.0, _jump_height(run * t), -run * t)
		"loop":
			return _loop_point(t)
	return Vector3(0.0, 0.0, -run * t)


static func _loop_profile() -> PackedVector3Array:
	if not _loop_shape.is_empty():
		return _loop_shape
	var step := LOOP_ARC / LOOP_SAMPLES
	var ease := func(u: float) -> float:
		return smoothstep(0.0, LOOP_EASE, u) * smoothstep(0.0, LOOP_EASE, 1.0 - u)
	# Scale the bend so the loop turns exactly once all the way round.
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
		# near the ground the way in and the way out are a whole tile apart.
		var across := side * LOOP_STEP * smoothstep(LOOP_EASE, 1.0 - LOOP_EASE, (along - LOOP_IN) / LOOP_ARC)
		return Vector3(across, at.x, -LOOP_IN - at.y)
	var end := shape[shape.size() - 1]
	return Vector3(side * LOOP_STEP, 0.0, -LOOP_IN - end.y - (along - LOOP_IN - LOOP_ARC))


## Which way is up off the road here, before any banking, in the piece's
## space. It's straight up everywhere except round a loop, where it points
## in toward the middle.
func up(t: float) -> Vector3:
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
	# Eases in and out, so the road never starts rolling (or, since banked
	# road leans up from its low edge, climbing) all at once. A sudden start
	# threw karts into the air on the way onto a wall ride.
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
	if type == "curve":
		return Transform3D(Basis(Vector3.UP, -turn * PI * 0.5), end)
	return Transform3D(Basis.IDENTITY, end)
