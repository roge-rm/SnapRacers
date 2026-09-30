class_name CourseCloser
extends RefCounted

## Finds pieces to finish a course off, from the end of the road back around
## to the start, facing the right way and at ground level.
##
## Every piece starts and ends in the middle of a tile edge, facing along the
## grid, so where the road's got to is always one of a small number of
## places: which half tile it's at, which of four ways it faces, and which
## level it's on. That makes it a search over a grid. It tries the fewest
## pieces first, guided by how far there is still to go, and keeps out of
## tiles the road already uses unless it's two levels above or below them.
## Anything it finds gets a proper check for the road running into itself
## before it's offered.

## The pieces it can use. Ramps only get used if the end of the road is up
## off the ground.
const CHOICES := [
	{"type": "straight", "length": 1}, {"type": "straight", "length": 2},
	{"type": "straight", "length": 3}, {"type": "straight", "length": 4},
	{"type": "curve", "turn": "left", "size": 1}, {"type": "curve", "turn": "right", "size": 1},
	{"type": "curve", "turn": "left", "size": 2}, {"type": "curve", "turn": "right", "size": 2},
	{"type": "curve", "turn": "left", "size": 3}, {"type": "curve", "turn": "right", "size": 3},
	{"type": "slant", "turn": "left", "length": 2, "across": 1}, {"type": "slant", "turn": "right", "length": 2, "across": 1},
	{"type": "slant", "turn": "left", "length": 3, "across": 1}, {"type": "slant", "turn": "right", "length": 3, "across": 1},
]
const DOWN := {"type": "ramp", "length": 2, "rise": -1}
const HALF := TrackPiece.TILE * 0.5

var course: CourseDesign
## Each choice's way out and the points along its middle, in its own space.
var _exits: Array[Transform3D] = []
var _samples: Array[PackedVector3Array] = []
var _choices: Array = []
## Tiles the road already uses, Vector2i -> the levels it's at there.
var _taken := {}


func _init(for_course: CourseDesign) -> void:
	course = for_course
	_choices = CHOICES.duplicate()
	_choices.append(DOWN)
	for spec in _choices:
		var piece := TrackPiece.from_spec(spec)
		_exits.append(piece.exit())
		var points := PackedVector3Array()
		# Not the very ends, which sit on the edge between two tiles.
		var steps := maxi(3, ceili(piece.path_length() / 4.0))
		for k in range(1, steps):
			points.append(piece.point(float(k) / steps))
		_samples.append(points)


## The pieces to add, or [] if nothing up to `most` pieces long fits.
func find(most: int, budget: int) -> Array:
	if course.pieces.is_empty() or course.track().closes:
		return []
	# The tiles the road already uses. The very ends of each piece sit on the
	# edge between two tiles, so they're left out, or the tile just behind the
	# start line would look taken.
	var end := Transform3D.IDENTITY
	for spec in course.pieces:
		var piece := TrackPiece.from_spec(spec)
		var steps := maxi(3, ceili(piece.path_length() / 2.0))
		for k in range(1, steps):
			var at := end * piece.point(float(k) / steps)
			_take(_tile_of(at), _level_of(at.y))
		end = end * piece.exit()

	# A queue of [how good it looks, a counter to keep it steady, the node],
	# where a node is [pose, pieces so far, tiles those pieces use, length].
	var heap := []
	var count := 0
	_push(heap, [_guess(end), 0, [end, [], [], 0.0]])
	var seen := {}
	var tried := 0
	while not heap.is_empty() and tried < budget:
		var node: Array = _pop(heap)[2]
		tried += 1
		var pose: Transform3D = node[0]
		var path: Array = node[1]
		if _is_start(pose):
			var done := course.duplicate_design()
			done.pieces.append_array(path)
			var check := done.track()
			if check.closes and check.clashes().is_empty():
				return path
			continue
		if path.size() >= most:
			continue
		var key := _key(pose)
		if seen.get(key, 99) <= path.size():
			continue
		seen[key] = path.size()
		var level := _level_of(pose.origin.y)
		for c in _choices.size():
			var spec: Dictionary = _choices[c]
			if spec == DOWN and level <= 0:
				continue
			var next := pose * _exits[c]
			if next.origin.y < -0.5:
				continue
			var tiles := []
			var clear := true
			for local in _samples[c]:
				var at := pose * local
				var tile := _tile_of(at)
				var lvl := _level_of(at.y)
				if _blocked(tile, lvl) or _in_path(node[2], tile, lvl):
					clear = false
					break
				tiles.append([tile, lvl])
			if not clear:
				continue
			count += 1
			var more: Array = path.duplicate()
			more.append(spec.duplicate())
			var used: Array = node[2] + tiles
			var length: float = node[3] + _samples[c].size()
			_push(heap, [more.size() + _guess(next) + length * 0.0001, count, [next, more, used, length]])
	return []


func _is_start(pose: Transform3D) -> bool:
	return pose.origin.length() < 0.5 and (-pose.basis.z).dot(Vector3.FORWARD) > 0.99


## At least how many more pieces it will take from here, with enough to cover
## the distance (a piece goes four tiles at most), enough curves to face the
## right way and enough ramps to get back down.
func _guess(pose: Transform3D) -> float:
	var flat := Vector2(pose.origin.x, pose.origin.z)
	var distance := ceilf((absf(flat.x) + absf(flat.y)) / (4.0 * TrackPiece.TILE))
	var turns := posmod(_heading(pose), 4)
	var turning := float(mini(turns, 4 - turns))
	var levels := float(maxi(_level_of(pose.origin.y), 0))
	return maxf(distance, turning) + levels


func _heading(pose: Transform3D) -> int:
	var f := -pose.basis.z
	return roundi(atan2(f.x, -f.z) / (PI * 0.5))


func _key(pose: Transform3D) -> Vector4i:
	return Vector4i(roundi(pose.origin.x / HALF), roundi(pose.origin.z / HALF), posmod(_heading(pose), 4), _level_of(pose.origin.y))


static func _tile_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + HALF) / TrackPiece.TILE), floori(p.z / TrackPiece.TILE))


static func _level_of(y: float) -> int:
	return roundi(y / TrackPiece.LEVEL)


func _take(tile: Vector2i, level: int) -> void:
	if not _taken.has(tile):
		_taken[tile] = []
	if not _taken[tile].has(level):
		_taken[tile].append(level)


## Whether road is already in this tile within a level of this one.
func _blocked(tile: Vector2i, level: int) -> bool:
	for other in _taken.get(tile, []):
		if absi(other - level) < 2:
			return true
	return false


func _in_path(used: Array, tile: Vector2i, level: int) -> bool:
	for u in used:
		if u[0] == tile and absi(u[1] - level) < 2:
			return true
	return false


# A small heap, so the most promising way on comes out first.

func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var up := (i - 1) / 2
		if _less(heap[up], heap[i]):
			break
		var t = heap[up]
		heap[up] = heap[i]
		heap[i] = t
		i = up


func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var small := i
			if l < heap.size() and _less(heap[l], heap[small]):
				small = l
			if r < heap.size() and _less(heap[r], heap[small]):
				small = r
			if small == i:
				break
			var t = heap[small]
			heap[small] = heap[i]
			heap[i] = t
			i = small
	return top


func _less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
