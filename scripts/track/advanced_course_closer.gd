class_name AdvancedCourseCloser
extends RefCounted

## A bounded search over drawer pieces. Four occupied routes per exact pose
## are kept, so the beam and work limits can leave a valid return unfound.
const MAX_EXPANSIONS := 10000
const MAX_QUEUE := 40000
const MAX_TRANSITIONS := 250000
const MAX_PROXIMITY := 2000000
const ROUTES_PER_POSE := 4
const CELL := 24.0
const SAMPLE := 4.0
const CLEARANCE := 5.0

var expanded_count := 0
var course: CourseDesign
var _choices := TrackCatalogue.closer_choices()
var _pieces: Array[TrackPiece] = []
var _samples: Array[PackedVector3Array] = []
var _lengths: Array[float] = []
var _obstacles := {}
var _reach := 17.0
var _skip := 34.0
var _original_length := 0.0
var _max_displacement := 0.0
var _queries := 0
var _limited := false
var _heading := 0


func _init(for_course: CourseDesign) -> void:
	course = for_course


func find(most: int, budget: int) -> Array:
	expanded_count = 0
	if most <= 0 or budget <= 0 or course.pieces.is_empty():
		return []
	_heading = TrackPath.heading_of(course.start.basis)
	if _heading < 0 or not course.start.origin.is_finite():
		return []
	most = mini(most, 7)
	budget = mini(budget, MAX_EXPANSIONS)
	_reach = course.width + 2.0 * TrackPath.KERB + 1.0
	_skip = 2.0 * _reach
	_obstacles.clear()
	_pieces.clear()
	_samples.clear()
	_lengths.clear()
	_queries = 0
	_limited = false
	_original_length = 0.0
	_max_displacement = 0.0
	var cursor := ClosureCursor.start(_heading)
	var pose := Transform3D(course.start.basis, Vector3.ZERO)
	for spec in course.pieces:
		var piece := TrackPiece.from_spec(spec)
		cursor = ClosureCursor.advance(cursor, piece)
		if cursor.is_empty():
			return []
		var samples := _sample(piece)
		_add_shape(_obstacles, samples, pose, _original_length, piece.path_length())
		_original_length += piece.path_length()
		pose = TrackPath.advance_pose(pose, piece)
	if ClosureCursor.at_start(cursor, _heading):
		return []
	for spec in _choices:
		var piece := TrackPiece.from_spec(spec)
		_pieces.append(piece)
		_samples.append(_sample(piece))
		_lengths.append(piece.path_length())
		_max_displacement = maxf(_max_displacement, piece.exit().origin.length())
	# Nodes keep only a parent and a choice. Occupancy is rebuilt for the
	# expanded route, rather than copied into every queued child.
	var root := {"cursor": cursor, "parent": null, "choice": -1, "depth": 0, "length": 0.0}
	var heap := []
	_push(heap, [_guess(cursor), 0.0, 0, root])
	var seen := {ClosureCursor.key(cursor): 1}
	var count := 0
	var transitions := 0
	while not heap.is_empty() and expanded_count < budget:
		var node: Dictionary = _pop(heap)[3]
		expanded_count += 1
		if ClosureCursor.at_start(node.cursor, _heading):
			var path := _path(node)
			var done := course.duplicate_design()
			done.pieces.append_array(path)
			var track := done.track()
			if track.closes and track.clashes().is_empty():
				return path
			continue
		if node.depth >= most:
			continue
		var occupied := _history(node)
		pose = ClosureCursor.pose(node.cursor)
		for c in _choices.size():
			transitions += 1
			if transitions > MAX_TRANSITIONS:
				return []
			var next := ClosureCursor.advance(node.cursor, _pieces[c])
			if next[9] < 0:
				continue
			var depth: int = node.depth + 1
			var remaining := _guess(next)
			if depth + remaining > most:
				continue
			var goal := ClosureCursor.at_start(next, _heading)
			var key := ClosureCursor.key(next)
			if not goal and seen.get(key, 0) >= ROUTES_PER_POSE:
				continue
			var length: float = node.length + _lengths[c]
			var total := _original_length + length if goal else INF
			if not _clear(_samples[c], pose, _original_length + node.length, _lengths[c], occupied, total):
				if _limited:
					return []
				continue
			var child := {"cursor": next, "parent": node, "choice": c, "depth": depth, "length": length}
			if depth >= most and not goal:
				continue
			if heap.size() >= MAX_QUEUE:
				return []
			seen[key] = seen.get(key, 0) + 1
			count += 1
			_push(heap, [depth + remaining, length, count, child])
	return []


func _guess(cursor: PackedInt64Array) -> int:
	var p := ClosureCursor.pose(cursor).origin
	var h := posmod(int(cursor[8]) - _heading, 24)
	var turns := float(mini(h, 24 - h)) / 6.0
	return ceili(maxf(p.length() / _max_displacement, maxf(turns, float(cursor[9]) / 2.0)) - 0.00000001)


func _path(node: Dictionary) -> Array:
	var out := []
	while node.choice >= 0:
		out.push_front(_choices[node.choice].duplicate(true))
		node = node.parent
	return out


func _sample(piece: TrackPiece) -> PackedVector3Array:
	var out := PackedVector3Array()
	var steps := maxi(1, ceili(piece.path_length() / SAMPLE))
	for k in range(steps + 1):
		out.append(piece.point(float(k) / steps))
	return out


func _history(node: Dictionary) -> Dictionary:
	var out := {}
	while node.choice >= 0:
		var c: int = node.choice
		_add_shape(out, _samples[c], ClosureCursor.pose(node.parent.cursor), _original_length + node.parent.length, _lengths[c])
		node = node.parent
	return out


func _add_shape(index: Dictionary, samples: PackedVector3Array, pose: Transform3D, along: float, length: float) -> void:
	var step := length / (samples.size() - 1)
	for i in range(samples.size() - 1):
		var a := pose * samples[i]
		var b := pose * samples[i + 1]
		var segment := [a, b, along + i * step, along + (i + 1) * step]
		for x in range(floori(minf(a.x, b.x) / CELL), floori(maxf(a.x, b.x) / CELL) + 1):
			for z in range(floori(minf(a.z, b.z) / CELL), floori(maxf(a.z, b.z) / CELL) + 1):
				var key := Vector2i(x, z)
				if not index.has(key):
					index[key] = []
				index[key].append(segment)


func _clear(samples: PackedVector3Array, pose: Transform3D, along: float, length: float, history: Dictionary, total: float) -> bool:
	var step := length / (samples.size() - 1)
	for i in range(samples.size() - 1):
		var a := pose * samples[i]
		var b := pose * samples[i + 1]
		var sa := along + i * step
		for x in range(floori((minf(a.x, b.x) - _reach) / CELL), floori((maxf(a.x, b.x) + _reach) / CELL) + 1):
			for z in range(floori((minf(a.z, b.z) - _reach) / CELL), floori((maxf(a.z, b.z) + _reach) / CELL) + 1):
				var cell := Vector2i(x, z)
				for index in [_obstacles, history]:
					for segment in index.get(cell, []):
						_queries += 1
						if _queries > MAX_PROXIMITY:
							_limited = true
							return false
						if sa + step - segment[2] < _skip:
							continue
						if total - (sa - segment[3]) < _skip:
							continue
						if _overlaps(a, b, segment[0], segment[1]):
							return false
	return true


func _overlaps(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> bool:
	var aa := Vector2(a.x, a.z)
	var bb := Vector2(b.x, b.z)
	var cc := Vector2(c.x, c.z)
	var dd := Vector2(d.x, d.z)
	var pair := Geometry2D.get_closest_points_between_segments(aa, bb, cc, dd)
	if pair[0].distance_to(pair[1]) >= _reach:
		return false
	var t := clampf((pair[0] - aa).dot(bb - aa) / maxf(aa.distance_squared_to(bb), 0.000001), 0.0, 1.0)
	var u := clampf((pair[1] - cc).dot(dd - cc) / maxf(cc.distance_squared_to(dd), 0.000001), 0.0, 1.0)
	return absf(lerpf(a.y, b.y, t) - lerpf(c.y, d.y, u)) < CLEARANCE


func _less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])))


func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var up := (i - 1) / 2
		if _less(heap[up], heap[i]):
			break
		var old: Array = heap[up]
		heap[up] = heap[i]
		heap[i] = old
		i = up


func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	while true:
		var small := i
		var left := i * 2 + 1
		var right := left + 1
		if left < heap.size() and _less(heap[left], heap[small]):
			small = left
		if right < heap.size() and _less(heap[right], heap[small]):
			small = right
		if small == i:
			break
		var old: Array = heap[small]
		heap[small] = heap[i]
		heap[i] = old
		i = small
	return top
