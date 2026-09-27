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
	return Vector3(0.0, 0.0, -run * t)


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
	return bank * sin(PI * t) * turn


## Whether there's road here. Only the jump has a gap.
func solid(t: float) -> bool:
	if type != "jump":
		return true
	var x := t * tiles * TILE
	return x <= KICKER_END or x >= LANDING_START


## Where the next piece starts, in this piece's space.
func exit() -> Transform3D:
	var end := point(1.0)
	if type == "curve":
		return Transform3D(Basis(Vector3.UP, -turn * PI * 0.5), end)
	return Transform3D(Basis.IDENTITY, end)
