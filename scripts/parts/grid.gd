class_name Grid
extends RefCounted

## Everything is built on the same grid. A stud is a quarter of a metre across
## and a plate is a tenth of a metre high, so a brick (three plates) is 0.3 m.
## That's the real brick ratio, just scaled up to kart size.
##
## Where parts sit is kept in a finer unit, a twentieth of a stud, so a stud
## is 20 of them and a plate 8, and every right angle turn of a part stays
## exact. Each part is turned one of the 24 ways a box can be turned.

const STUD := 0.25
const PLATE := 0.1
const UNIT := Vector3(STUD, PLATE, STUD)
## The fine unit, in metres, and a stud and a plate in it.
const FINE := 0.0125
const STUD_FINE := 20
const PLATE_FINE := 8
const UNIT_FINE := Vector3(STUD_FINE, PLATE_FINE, STUD_FINE)

static var _turns: Array[Basis] = []


static func to_metres(cells: Vector3) -> Vector3:
	return cells * UNIT


## A part's size once it's been turned `rot` quarter turns. Odd turns swap
## its width and length.
static func rotated_size(size: Vector3i, rot: int) -> Vector3i:
	if posmod(rot, 2) == 1:
		return Vector3i(size.z, size.y, size.x)
	return size


## A part's size in the fine unit, before it's turned.
static func fine_size(size: Vector3i) -> Vector3:
	return Vector3(size) * UNIT_FINE


## The turn for `rot` quarter turns, the way parts have always turned:
## clockwise seen from above.
static func yaw(rot: int) -> Basis:
	return turns()[posmod(rot, 4)]


## All 24 ways a part can be turned. The first four are the quarter turns
## about up, in order.
static func turns() -> Array[Basis]:
	if not _turns.is_empty():
		return _turns
	for rot in 4:
		_turns.append(Basis(Vector3.UP, -rot * PI * 0.5).orthonormalized())
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for x in axes:
		for y in axes:
			if absf(x.dot(y)) > 0.5:
				continue
			var b := Basis(x, y, x.cross(y))
			if not _turns.any(func(t: Basis) -> bool: return t.is_equal_approx(b)):
				_turns.append(b)
	return _turns


## Which of the 24 turns this is, or -1 if it isn't one of them.
static func turn_index(basis: Basis) -> int:
	var all := turns()
	for i in all.size():
		if (all[i].x - basis.x).length() < 0.01 and (all[i].y - basis.y).length() < 0.01:
			return i
	return -1
