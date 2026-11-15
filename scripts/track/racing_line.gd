class_name RacingLine
extends RefCounted

## The quick way around a course: how far right of the middle of the road to
## drive at each of the track's samples, in metres (left is negative). It runs
## wide into a bend, touches the inside at the apex and runs wide out, found by
## bending the line as little as the road lets it.
##
## Where the road is unusual (jumps, loops, corkscrews, wall rides) it keeps
## to the middle, and it eases over to the middle before them. Beside a drop
## with no wall it keeps further in from the edge.
##
## TrackPath makes one the first time it's asked for, after the layout is
## applied, and keeps it until the road is built again.

## From the road's edge line to a kart's middle. A kart is about 2.2 m across.
const MARGIN := 1.6
## The same beside a drop with no wall.
const OPEN_MARGIN := 3.2
## Road this far above the ground is road you could fall off, the same as
## TrackBuilder.RAISED.
const RAISED := 0.5
## How quickly it can move off the middle after a stretch where it has to
## keep to it, in metres across per metre along.
const EASE := 0.12
## It's worked out roughly on nodes this far apart first, then finer, which
## settles long straights in far fewer rounds.
const STEPS := [24.0, 12.0, 6.0]
const ROUNDS := [300, 100, 50]
## How far ahead and behind on a split it keeps clear of the island's edge,
## in metres (see _clear_noses()).
const NOSE_CLEAR := 12.0
## How far before and after a split it keeps to its branch's half of the
## road, in metres.
const SPLIT_LEAD := 30.0
## How far before a jump split's kicker its jump branch's line keeps to the
## middle of the branch, in metres.
const JUMP_LEAD := 12.0
## Over relaxation, which settles it quicker. Anything from 1 to 2 works.
const OMEGA := 1.6
## Stops a level once no node moves more than this in a round, in metres.
const SETTLED := 0.005

## Per track sample: the line's offset, its bend as one over its radius (like
## TrackPath.bend_at()), and the most it may go left and right. Through each
## split it takes the quicker branch.
var offsets := PackedFloat32Array()
var bends := PackedFloat32Array()
var lows := PackedFloat32Array()
var highs := PackedFloat32Array()
## The same for a line through the left branch of every split, then the
## right. Without splits both are the line above.
var side_offsets: Array[PackedFloat32Array] = []
var side_bends: Array[PackedFloat32Array] = []
var side_lows: Array[PackedFloat32Array] = []
var side_highs: Array[PackedFloat32Array] = []
## Where along the lap each split's middle is, in metres, in the order they
## come round, and which of them is nearest each sample. Empty without
## splits.
var split_mids := PackedFloat32Array()
var zones := PackedInt32Array()
## For each split, the quicker branch (0 left, 1 right) and about how many
## seconds it saves, from a rough lap with each line (see _times()).
var quicker := PackedInt32Array()
var gains := PackedFloat32Array()
## How long it took to work out, in microseconds.
var build_usec := 0

## The rough lap the branches are timed on: top speed and how hard it
## corners, speeds up and brakes, in m/s and m/s².
const TIME_TOP := 26.0
const TIME_GRIP := 9.0
const TIME_ACCEL := 5.0
const TIME_BRAKE := 8.0
## How much of the road's top speed a kart keeps on each surface, measured on
## the starter kart after 10 s on the gas from 22 m/s (road 25.8 m/s). Grip
## matters as much as drag, so drag alone can't give these. A surface not
## listed loses TIME_DRAG for each unit of its extra drag.
const TIME_SURFACE := {
	"asphalt": 1.0, "dirt": 0.98, "gravel": 1.0, "concrete": 1.0, "grass": 0.88,
	"mud": 0.93, "sand": 0.8, "ice": 0.58, "shallows": 0.73,
}
const TIME_DRAG := 0.04
## How much of its speed a kart keeps over a jump.
const TIME_JUMP := 0.9


func _init(track: TrackPath) -> void:
	var started := Time.get_ticks_usec()
	var count := track.points.size()
	offsets.resize(count)
	offsets.fill(0.0)
	lows.resize(count)
	lows.fill(0.0)
	highs.resize(count)
	highs.fill(0.0)
	_find_splits(track)
	var solved := count >= 8 and track.closes and track.length > 64.0
	for side in (2 if track.has_splits else 1):
		var side_low := lows.duplicate()
		var side_high := highs.duplicate()
		var line := offsets.duplicate()
		if solved:
			_bounds(track, side if track.has_splits else -1, side_low, side_high)
			line = _solve(track, side_low, side_high)
		side_offsets.append(line)
		side_lows.append(side_low)
		side_highs.append(side_high)
		side_bends.append(_measure_bends(track, line))
	if side_offsets.size() == 1:
		for list in [side_offsets, side_lows, side_highs, side_bends]:
			list.append(list[0])
	_time_splits(track)
	bends.resize(count)
	for k in count:
		var side := side_of(k)
		offsets[k] = side_offsets[side][k]
		bends[k] = side_bends[side][k]
		lows[k] = side_lows[side][k]
		highs[k] = side_highs[side][k]
	build_usec = Time.get_ticks_usec() - started


## Which branch's line to use at sample k: `branches` holds one pick for
## each split (see split_mids), and a split with none takes the quicker.
func side_of(k: int, branches := PackedInt32Array()) -> int:
	if zones.is_empty():
		return 0
	var zone := zones[k]
	if zone < branches.size() and branches[zone] >= 0:
		return branches[zone]
	return quicker[zone] if zone < quicker.size() else 1


## Each split's middle along the lap, and the split nearest each sample.
func _find_splits(track: TrackPath) -> void:
	if not track.has_splits:
		return
	var count := track.points.size()
	var piece := -1
	for k in count:
		if track.piece_of[k] != piece and track.split_sample(k):
			piece = track.piece_of[k]
			split_mids.append(fposmod(track.distances[k] + track.pieces[piece].path_length() * 0.5, track.length))
	zones.resize(count)
	for k in count:
		var best := INF
		for zone in split_mids.size():
			var gap := absf(fposmod(track.distances[k] - split_mids[zone] + track.length * 0.5, track.length) - track.length * 0.5)
			if gap < best:
				best = gap
				zones[k] = zone
	quicker.resize(split_mids.size())
	quicker.fill(1)
	gains.resize(split_mids.size())
	gains.fill(0.0)


## Times a rough lap on each side's line and, for each split, adds up the
## time over the stretch nearest it to see which branch is quicker.
func _time_splits(track: TrackPath) -> void:
	if split_mids.is_empty() or side_offsets[0] == side_offsets[1]:
		return
	var left := _times(track, side_offsets[0], side_bends[0], 0)
	var right := _times(track, side_offsets[1], side_bends[1], 1)
	var saved := PackedFloat32Array()
	saved.resize(split_mids.size())
	saved.fill(0.0)
	for k in zones.size():
		saved[zones[k]] += right[k] - left[k]
	for zone in saved.size():
		quicker[zone] = 1 if saved[zone] < 0.0 else 0
		# Rounded, so a device that adds up a hair differently picks the same.
		gains[zone] = snappedf(absf(saved[zone]), 0.01)


## Seconds from each sample to the next on this line, for a kart that tops
## out at TIME_TOP, corners at TIME_GRIP and speeds up and brakes at
## TIME_ACCEL and TIME_BRAKE, twice round so it carries over the start line.
## On a split it goes by branch `side`'s surface, and over a jump it loses
## a little on the landing.
func _times(track: TrackPath, line: PackedFloat32Array, line_bends: PackedFloat32Array, side := 0) -> PackedFloat32Array:
	var count := track.points.size()
	var gaps := PackedFloat32Array()
	var limits := PackedFloat32Array()
	gaps.resize(count)
	limits.resize(count)
	for k in count:
		var next := (k + 1) % count
		gaps[k] = (track.points[k] + track.rights[k] * line[k]).distance_to(track.points[next] + track.rights[next] * line[next])
		var grip := 1.0
		var top := TIME_TOP
		if track.split_sample(k):
			var surface := track.branch_surface(k, side)
			var feel: Array = track.grip_and_drag(surface)
			grip = feel[0]
			top *= TIME_SURFACE.get(surface, 1.0 - TIME_DRAG * (feel[1] - 1.0))
			if track.branch_lift(k, side) > 0.01 or not track.branch_solid(k, side):
				top *= TIME_JUMP
		limits[k] = minf(top, sqrt(TIME_GRIP * grip / maxf(line_bends[k], 0.0001)))
	var speeds := limits.duplicate()
	for n in count * 2:
		var k := n % count
		var next := (k + 1) % count
		speeds[next] = minf(speeds[next], sqrt(speeds[k] * speeds[k] + 2.0 * TIME_ACCEL * gaps[k]))
	for n in count * 2:
		var k := count - 1 - n % count
		var next := (k + 1) % count
		speeds[k] = minf(speeds[k], sqrt(speeds[next] * speeds[next] + 2.0 * TIME_BRAKE * gaps[k]))
	var out := PackedFloat32Array()
	out.resize(count)
	for k in count:
		out[k] = gaps[k] / maxf((speeds[k] + speeds[(k + 1) % count]) * 0.5, 1.0)
	return out


## How far left and right of the middle it may go at each sample. On a
## split it keeps to the branch `side` (0 left, 1 right).
func _bounds(track: TrackPath, side: int, low_of: PackedFloat32Array, high_of: PackedFloat32Array) -> void:
	var count := track.points.size()
	var half := track.width * 0.5
	for k in count:
		var piece := track.pieces[track.piece_of[k]]
		if not track.solids[k] or piece.type == "jump" or TrackPiece.turns_over(piece.type) or track.stickies[k]:
			continue
		# Same test the builder uses for road you could fall off.
		var raised := track.points[k].y - track.grounds[k] > RAISED or track.ups[k].y < 0.985
		var walls := piece.forced_walls() or raised
		var right := MARGIN if not raised or (walls and piece.wall_right) else OPEN_MARGIN
		var left := MARGIN if not raised or (walls and piece.wall_left) else OPEN_MARGIN
		high_of[k] = maxf(half - right, 0.0)
		low_of[k] = minf(-(half - left), 0.0)
		if side >= 0 and track.split_sample(k):
			var branch := track.branch_lefts[k] if side == 0 else track.branch_rights[k]
			low_of[k] = branch.x - branch.y * 0.5 + MARGIN
			high_of[k] = maxf(branch.x + branch.y * 0.5 - MARGIN, low_of[k])
	if side >= 0 and track.has_splits:
		_clear_noses(track, side, low_of, high_of)
		_straight_jumps(track, side, low_of, high_of)
	# An uneven split's branch can swing out faster than the easing allows,
	# so there it eases from the branch's middle.
	var base := PackedFloat32Array()
	base.resize(count)
	if side >= 0:
		for k in count:
			if track.split_sample(k) and track.pieces[track.piece_of[k]].type in TrackPiece.UNEVEN_SPLITS:
				base[k] = (track.branch_lefts[k] if side == 0 else track.branch_rights[k]).x
				low_of[k] -= base[k]
				high_of[k] -= base[k]
	# Ease out of the stretches it has to keep to the middle on, both ways
	# around, going around twice so it carries across the start line.
	var steps := PackedFloat32Array()
	steps.resize(count)
	for k in count:
		var next := (k + 1) % count
		steps[k] = EASE * ((track.distances[next] if next != 0 else track.length) - track.distances[k])
	for n in count * 2:
		var k := n % count
		var back := (k - 1 + count) % count
		high_of[k] = minf(high_of[k], high_of[back] + steps[back])
		low_of[k] = maxf(low_of[k], low_of[back] - steps[back])
	for n in count * 2:
		var k := count - 1 - n % count
		var ahead := (k + 1) % count
		high_of[k] = minf(high_of[k], high_of[ahead] + steps[k])
		low_of[k] = maxf(low_of[k], low_of[ahead] - steps[k])
	# Easing toward a branch from both ends can cross over; it takes the
	# middle there.
	for k in count:
		if low_of[k] > high_of[k]:
			low_of[k] = (low_of[k] + high_of[k]) * 0.5
			high_of[k] = low_of[k]
		low_of[k] += base[k]
		high_of[k] += base[k]


## On a split it keeps as far from the island's edge as it'll need to be
## NOSE_CLEAR metres either way, so it's out on its branch before the nose
## and doesn't cut across it as the branches part or join, and it keeps to
## its branch's side SPLIT_LEAD either side of the split.
func _clear_noses(track: TrackPath, side: int, low_of: PackedFloat32Array, high_of: PackedFloat32Array) -> void:
	var count := track.points.size()
	var edge := high_of.duplicate() if side == 0 else low_of.duplicate()
	for k in count:
		if not track.split_sample(k):
			# Coming up to a split, or just out of one, it keeps to its
			# branch's half of the road.
			var near := false
			for way in [-1, 1]:
				var n := track._index_before(track.distances[k] + way * SPLIT_LEAD)
				near = near or track.split_sample(n) or track.split_sample((n + 1) % count)
			if near:
				if side == 0:
					high_of[k] = minf(high_of[k], 0.0)
				else:
					low_of[k] = maxf(low_of[k], 0.0)
			continue
		for way in [-1, 1]:
			var n := k
			while true:
				n = (n + way + count) % count
				if n == k or not track.split_sample(n) or absf(fposmod(track.distances[n] - track.distances[k] + track.length * 0.5, track.length) - track.length * 0.5) > NOSE_CLEAR:
					break
				if side == 0:
					high_of[k] = minf(high_of[k], edge[n])
				else:
					low_of[k] = maxf(low_of[k], edge[n])
		if low_of[k] > high_of[k]:
			if side == 0:
				high_of[k] = low_of[k]
			else:
				low_of[k] = high_of[k]


## Down a jump split's jump branch it keeps to the middle of the branch,
## from JUMP_LEAD before the kicker to the end of the landing, the way it
## keeps to the middle of a jump.
func _straight_jumps(track: TrackPath, side: int, low_of: PackedFloat32Array, high_of: PackedFloat32Array) -> void:
	var count := track.points.size()
	for k in count:
		if not track.split_sample(k):
			continue
		var jumping := false
		var n := k
		while track.distances[n] - track.distances[k] <= JUMP_LEAD and track.piece_of[n] == track.piece_of[k]:
			if not track.branch_flat(n, side):
				jumping = true
				break
			n += 1
			if n >= count:
				break
		if jumping:
			var branch := track.branch_lefts[k] if side == 0 else track.branch_rights[k]
			low_of[k] = branch.x
			high_of[k] = branch.x


## Coarse to fine: each level starts from the one before and bends the line
## less, a node at a time, keeping each node between its bounds.
func _solve(track: TrackPath, low_of: PackedFloat32Array, high_of: PackedFloat32Array) -> PackedFloat32Array:
	var count := track.points.size()
	var level_offsets := PackedFloat32Array()
	var level_size := 0
	for level in STEPS.size():
		var nodes := maxi(16, roundi(track.length / STEPS[level]))
		var spacing := track.length / nodes
		var centres := PackedVector2Array()
		var normals := PackedVector2Array()
		var low := PackedFloat32Array()
		var high := PackedFloat32Array()
		centres.resize(nodes)
		normals.resize(nodes)
		low.resize(nodes)
		low.fill(-INF)
		high.resize(nodes)
		high.fill(INF)
		for i in nodes:
			var d := i * spacing
			var p := track.point_at(d)
			centres[i] = Vector2(p.x, p.z)
			var r := track.right_at(d)
			var flat := Vector2(r.x, r.z)
			normals[i] = flat.normalized() if flat.length_squared() > 0.01 else Vector2.ZERO
		# Each node keeps inside the bounds of every sample nearest to it.
		for k in count:
			var i := roundi(track.distances[k] / spacing) % nodes
			low[i] = maxf(low[i], low_of[k])
			high[i] = minf(high[i], high_of[k])
		var o := PackedFloat32Array()
		o.resize(nodes)
		for i in nodes:
			var start := 0.0
			if level_size > 0:
				var at := float(i) * level_size / nodes
				var a := int(at) % level_size
				start = lerpf(level_offsets[a], level_offsets[(a + 1) % level_size], at - floorf(at))
			if normals[i] == Vector2.ZERO:
				low[i] = 0.0
				high[i] = 0.0
			o[i] = clampf(start, low[i], high[i])
		var at_line := PackedVector2Array()
		at_line.resize(nodes)
		for i in nodes:
			at_line[i] = centres[i] + normals[i] * o[i]
		var weights := PackedFloat32Array()
		weights.resize(nodes)
		for round_ in ROUNDS[level]:
			# Each second difference is weighted by one over its spacing cubed,
			# which turns it into bend squared times length, or nodes bunched
			# up on the inside of a bend would look straighter than they are.
			# They're worked out once a round, which is close enough.
			var gap_before := at_line[nodes - 1].distance_to(at_line[0])
			for i in nodes:
				var gap_after := at_line[i].distance_to(at_line[(i + 1) % nodes])
				var h := maxf((gap_before + gap_after) * 0.5, 0.1)
				weights[i] = 1.0 / (h * h * h)
				gap_before = gap_after
			var moved := 0.0
			for i in nodes:
				var lo := low[i]
				var hi := high[i]
				if hi <= lo:
					continue
				# Where this node would leave the least bend over the three
				# second differences it's part of.
				var i1 := (i - 1 + nodes) % nodes
				var j1 := (i + 1) % nodes
				var a1 := at_line[i1]
				var b1 := at_line[j1]
				var w_before := weights[i1]
				var w_here := 4.0 * weights[i]
				var w_after := weights[j1]
				var target := (w_before * (a1 * 2.0 - at_line[(i - 2 + nodes) % nodes]) + w_here * (a1 + b1) * 0.5 \
					+ w_after * (b1 * 2.0 - at_line[(i + 2) % nodes])) / (w_before + w_here + w_after)
				var was := o[i]
				var now := clampf(was + OMEGA * ((target - centres[i]).dot(normals[i]) - was), lo, hi)
				o[i] = now
				at_line[i] = centres[i] + normals[i] * now
				moved = maxf(moved, absf(now - was))
			if moved < SETTLED:
				break
		level_offsets = o
		level_size = nodes
	# Out to every sample along a smooth curve through the finest nodes.
	var out := PackedFloat32Array()
	out.resize(count)
	var spacing := track.length / level_size
	for k in count:
		var at := track.distances[k] / spacing
		var a := int(at) % level_size
		var t := at - floorf(at)
		var p0 := level_offsets[(a - 1 + level_size) % level_size]
		var p1 := level_offsets[a]
		var p2 := level_offsets[(a + 1) % level_size]
		var p3 := level_offsets[(a + 2) % level_size]
		var smooth := 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t)
		out[k] = clampf(smooth, low_of[k], high_of[k])
	return out


## How much the line itself bends at each sample, across the road the way
## TrackPath._bend_between() measures the middle, but over the line's own
## length, so a wide sweeping line counts as a gentler bend.
func _measure_bends(track: TrackPath, line_offsets: PackedFloat32Array) -> PackedFloat32Array:
	var count := track.points.size()
	var out := PackedFloat32Array()
	out.resize(count)
	var line := PackedVector3Array()
	line.resize(count)
	for k in count:
		line[k] = track.points[k] + track.rights[k] * line_offsets[k]
	var half_span := TrackPath.BEND_SPAN * 0.5
	for k in count:
		var a := track._index_before(track.distances[k] - half_span)
		var b := track._index_before(track.distances[k] + half_span)
		var up := track.ups[k]
		var ta := line[(a + 1) % count] - line[(a - 1 + count) % count]
		var tb := line[(b + 1) % count] - line[(b - 1 + count) % count]
		ta = ta - up * ta.dot(up)
		tb = tb - up * tb.dot(up)
		var along := 0.0
		var j := a
		while j != b:
			var next := (j + 1) % count
			along += line[j].distance_to(line[next])
			j = next
		if ta.length_squared() < 0.000001 or tb.length_squared() < 0.000001 or along < 0.5:
			out[k] = track._bends[k] if k < track._bends.size() else 0.0
			continue
		out[k] = absf(ta.signed_angle_to(tb, up)) / along
	return out
