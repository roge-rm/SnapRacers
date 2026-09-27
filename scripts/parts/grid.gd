class_name Grid
extends RefCounted

## Everything is built on the same grid. A stud is a quarter of a metre across
## and a plate is a tenth of a metre high, so a brick (three plates) is 0.3 m.
## That's the real brick ratio, just scaled up to kart size.

const STUD := 0.25
const PLATE := 0.1
const UNIT := Vector3(STUD, PLATE, STUD)


static func to_metres(cells: Vector3) -> Vector3:
	return cells * UNIT


## A part's size once it's been turned `rot` quarter turns. Odd turns swap
## its width and length.
static func rotated_size(size: Vector3i, rot: int) -> Vector3i:
	if posmod(rot, 2) == 1:
		return Vector3i(size.z, size.y, size.x)
	return size
