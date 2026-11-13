extends Node

## AI drivers round a split. Each driver picks a branch for each split on
## each lap from its seed, the same every time; even branches split the
## field about half and half, and when one's quicker the higher levels take
## it more. Pick-up rows cover both branches, and puddles and drifts keep off
## the split. Then eight karts race two laps of a course with a split over a
## few seeds: both branches get used, nobody drives over the island, and lap
## times and resets are about the same as on the course with a plain
## straight there instead. Then the same on a course with a rough split, a
## jump split and a split bend, where one branch is quicker: Expert takes it
## most of the time, Easy and Normal take both.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/ai_split_test.tscn

const COURSE := "res://tests/data/split_course.json"
const KARTS := ["kart_kid", "night_shift", "zippy", "redline", "kart_kid", "streak", "night_shift", "volt"]
const RACES := [[11, "normal"], [12, "hard"], [13, "expert"]]
const UNEVEN := "res://tests/data/split_uneven_course.json"
const UNEVEN_RACES := [[21, "easy"], [22, "normal"], [23, "expert"]]
const LAPS := 2
## The longest a race may take, in seconds.
const GIVE_UP := 150.0
## A kart's middle this far past a branch's edge, over the island, counts,
## and so does crossing to the other branch, unless it's touched another
## kart in the last KNOCK_FOR seconds.
const OVER_BY := 0.5
const KNOCK_FOR := 1.0

var failures := 0
var track: TrackPath
var builder: TrackBuilder
var karts: Array[Kart] = []
var drivers: Array[AIDriver] = []


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	track = _course(true)
	_picks()
	await _props()
	var with_split := []
	var without := []
	var ran := []
	for race in RACES:
		# SPLIT_RACE=n runs only that one, and UNEVEN_ONLY=1 none of them.
		if OS.has_environment("UNEVEN_ONLY"):
			break
		if OS.has_environment("SPLIT_RACE") and RACES.find(race) != int(OS.get_environment("SPLIT_RACE")):
			continue
		ran.append(race)
		with_split.append(await _race(true, race[0], race[1]))
		# SPLIT_ONLY=1 skips the races without it, for a quicker look.
		without.append(await _race(false, race[0], race[1]) if not OS.has_environment("SPLIT_ONLY") else with_split[-1])
	var sides := [0, 0]
	var over := 0.0
	var crossed := 0
	var resets := [0, 0]
	var times := [0.0, 0.0]
	var finished := true
	for i in with_split.size():
		var a: Dictionary = with_split[i]
		var b: Dictionary = without[i]
		print("    %s seed %d: %d left, %d right, %.2f s over the island, %d and %d resets, laps %.1f s and %.1f s" % [ran[i][1], ran[i][0], a.sides[0], a.sides[1], a.over, a.resets, b.resets, a.lap, b.lap])
		sides[0] += a.sides[0]
		sides[1] += a.sides[1]
		over += a.over
		crossed += a.crossed
		resets[0] += a.resets
		resets[1] += b.resets
		times[0] += a.lap
		times[1] += b.lap
		finished = finished and a.finished and b.finished
	if not ran.is_empty():
		check(finished, "every kart finishes %d laps with and without the split" % LAPS)
		check(sides[0] >= 4 and sides[1] >= 4, "both branches get used (%d left, %d right)" % sides)
		check(crossed == 0 and over == 0.0, "nobody drives across the island (%d times) or onto it unless shoved (%.2f s)" % [crossed, over])
		check(resets[0] <= resets[1] + 1, "no more resets than without the split (%d, %d)" % resets)
		check(times[0] <= times[1] * 1.06, "laps take about as long as without the split (%.1f s, %.1f s)" % [times[0] / RACES.size(), times[1] / RACES.size()])
	await _uneven()
	print("All AI split checks passed." if failures == 0 else "%d AI split checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The course, or with plain road where each split was.
func _course(split: bool, file := COURSE) -> TrackPath:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not split:
		for i in data.pieces.size():
			var spec: Dictionary = data.pieces[i]
			if spec.type == "split_bend":
				data.pieces[i] = {"type": "curve", "turn": spec.turn, "size": spec.size}
			elif spec.type in TrackPiece.SPLIT_TYPES:
				data.pieces[i] = {"type": "straight", "length": TrackPiece.from_spec(spec).tiles}
	var path := TrackPath.from_dict(data)
	path.racing_line()
	return path


## The same seed picks the same branches, even branches split about half
## and half, and a quicker branch is taken more the higher the level.
func _picks() -> void:
	var line := track.racing_line()
	check(line.split_mids.size() == 1 and line.zones.size() == track.points.size(), "the course has one split (%d)" % line.split_mids.size())
	var a := _driver("normal", 7)
	var b := _driver("normal", 7)
	var same := true
	for visit in 40:
		same = same and a.pick_branch(0, visit) == b.pick_branch(0, visit)
	check(same, "the same seed picks the same branches")
	var was_gain := line.gains[0]
	var was_quicker := line.quicker[0]
	line.gains[0] = 0.0
	var right := 0
	var tries := 0
	for level in Difficulty.LEVELS:
		for seed in 50:
			var ai := _driver(level, seed)
			for visit in 4:
				right += ai.pick_branch(0, visit)
				tries += 1
			ai.free()
	check(absf(float(right) / tries - 0.5) < 0.08, "even branches split the field about half and half (%d of %d right)" % [right, tries])
	line.gains[0] = 1.0
	line.quicker[0] = 0
	var shares := {}
	for level in Difficulty.LEVELS:
		var quick := 0
		for seed in 100:
			var ai := _driver(level, seed)
			for visit in 4:
				quick += 1 if ai.pick_branch(0, visit) == 0 else 0
			ai.free()
		shares[level] = quick / 400.0
	check(shares.expert == 1.0 and shares.hard > 0.85 and shares.normal > 0.6 and shares.normal < 0.85 and shares.easy > 0.5 and shares.easy < shares.normal, "a quicker branch is taken more the higher the level (%s)" % shares)
	line.gains[0] = was_gain
	line.quicker[0] = was_quicker
	a.free()
	b.free()


## Eight karts race the uneven course at each level, and again with plain
## road there.
func _uneven() -> void:
	var line := _course(true, UNEVEN).racing_line()
	var gains := []
	for zone in line.gains.size():
		gains.append("%s %.2f s" % [["left", "right"][line.quicker[zone]], line.gains[zone]])
	check(line.split_mids.size() == 3 and Array(line.gains).all(func(g: float) -> bool: return g >= AIDriver.BRANCH_EVEN), "the uneven course has three splits, each with a quicker branch (%s)" % ", ".join(gains))
	var shares := {}
	var over := 0.0
	var crossed := 0
	var resets := [0, 0]
	var finished := true
	for race in UNEVEN_RACES:
		# UNEVEN_RACE=n runs only that one.
		if OS.has_environment("UNEVEN_RACE") and UNEVEN_RACES.find(race) != int(OS.get_environment("UNEVEN_RACE")):
			continue
		var a := await _race(true, race[0], race[1], UNEVEN, GIVE_UP * 1.5)
		var b := await _race(false, race[0], race[1], UNEVEN, GIVE_UP * 1.5)
		print("    uneven %s seed %d: %d of %d down the quicker branch, %.2f s over the island, %d and %d resets, laps %.1f s and %.1f s" % [race[1], race[0], a.uneven[1], a.uneven[0], a.over, a.resets, b.resets, a.lap, b.lap])
		shares[race[1]] = float(a.uneven[1]) / maxf(a.uneven[0], 1.0)
		over += a.over
		crossed += a.crossed
		resets[0] += a.resets
		resets[1] += b.resets
		finished = finished and a.finished and b.finished
	check(finished, "every kart finishes the uneven course with and without its splits")
	check(shares.expert >= 0.7, "Expert takes the quicker branch most of the time (%.2f)" % shares.expert)
	check(shares.easy > 0.0 and shares.easy < 1.0 and shares.normal > 0.0 and shares.normal < 1.0, "Easy and Normal take both branches (%.2f, %.2f)" % [shares.easy, shares.normal])
	check(crossed == 0 and over == 0.0, "nobody crosses or drives on an uneven split's island (%d times, %.2f s)" % [crossed, over])
	check(resets[0] <= resets[1] + 1, "no more resets than without the uneven splits (%d, %d)" % resets)


func _driver(level: String, seed: int) -> AIDriver:
	var ai := AIDriver.new()
	ai.track = track
	Difficulty.apply(ai, level, seed % 8, 8, DriverTraits.from_name("split %d" % seed))
	ai.seed_line(seed)
	return ai


## Pick-up rows go across both branches, and puddles and drifts are all on
## the road and off the split.
func _props() -> void:
	var boxes := PowerupField.new(track)
	add_child(boxes)
	var on_road := true
	var on_split := 0
	for spot: Transform3D in boxes.spots:
		var at := track.offset_of(spot.origin)
		var across := (spot.origin - track.point_at(at)).dot(track.right_at(at))
		on_road = on_road and track.on_road_across(at, across, 1.0)
		if track.lanes_at(at).size() > 1:
			on_split += 1
	check(on_road and on_split == 6, "pick-up boxes are on the road, three on each branch of the split (%d)" % on_split)
	boxes.queue_free()
	var puddles_ok := true
	var drifts_ok := true
	var counts := [0, 0]
	for seed in 4:
		var puddles := Puddles.new(track, seed, 1.0)
		for middle in puddles._middle:
			var at := track.offset_of(middle)
			var across := (middle - track.point_at(at)).dot(track.right_at(at))
			puddles_ok = puddles_ok and track.on_road_across(at, across) and not track.split_sample(track._index_before(at))
			counts[0] += 1
		puddles.free()
		var drifts := Drifts.new(track, seed, 1.0)
		for i in drifts._root.size():
			var tip: Vector3 = drifts._root[i] + drifts._dir[i] * drifts._long[i]
			var along := 0.0
			while along <= drifts._long[i]:
				var point: Vector3 = drifts._root[i] + drifts._dir[i] * along
				drifts_ok = drifts_ok and not track.split_sample(track._index_before(track.offset_of(point)))
				along += 1.0
			var at := track.offset_of(tip)
			drifts_ok = drifts_ok and track.on_road_across(at, (tip - track.point_at(at)).dot(track.right_at(at)), -0.5)
			counts[1] += 1
		drifts.free()
	check(puddles_ok and counts[0] > 0, "puddles are on the road and off the split (%d)" % counts[0])
	check(drifts_ok and counts[1] > 0, "drifts are on the road and off the split (%d)" % counts[1])
	await get_tree().physics_frame


## Eight karts race LAPS laps from the grid. Returns how many times round the
## split went down each branch, seconds a kart spent over the island, resets,
## the average lap and whether they all finished.
func _race(split: bool, seed: int, level: String, file := COURSE, give_up := GIVE_UP) -> Dictionary:
	track = _course(split, file)
	var line := track.racing_line()
	builder = TrackBuilder.new(track)
	builder.sky = false
	add_child(builder)
	var offsets: Array[float] = []
	var gone: Array[float] = []
	var starts: Array[float] = []
	var done: Array[float] = []
	var resets := [0]
	for i in KARTS.size():
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/stock/%s.json" % KARTS[i]))
		kart.transform = track.grid_slot(i)
		add_child(kart)
		karts.append(kart)
		var at := track.offset_of(kart.global_position)
		offsets.append(at)
		gone.append(0.0)
		starts.append(at - track.length if at > track.length * 0.5 else at)
		done.append(-1.0)
		var k := i
		kart.was_reset.connect(func() -> void:
			resets[0] += 1
			print("    kart %d reset at %.0f m (%s)" % [k, offsets[k], track.piece_type_at(offsets[k])]))
		kart.reset_to = func(_where: Vector3) -> Transform3D:
			var spot := track.place_at(offsets[k])
			var across := (karts[k].global_position - track.point_at(offsets[k])).dot(track.right_at(offsets[k]))
			spot.origin += spot.basis.x * track.reset_spots(offsets[k], across)[0]
			return spot
		var ai := AIDriver.new()
		ai.kart = kart
		ai.track = track
		Difficulty.apply(ai, level, i, KARTS.size(), DriverTraits.from_name("split %d" % i))
		ai.seed_line(seed * 100 + i)
		kart.controls = ai.controls
		add_child(ai)
		drivers.append(ai)
	for ai in drivers:
		ai.others = karts
	var sides := [0, 0]
	# Times through a split where one branch is quicker, and how many of
	# those down the quicker one.
	var uneven := [0, 0]
	# Which branch each kart is on this time through the split, or -1.
	var through: Array[int] = []
	through.resize(KARTS.size())
	through.fill(-1)
	var over := 0.0
	# Seconds over the island by piece and place, for working out why.
	var overs := {}
	var crossed := 0
	var knocked: Array[int] = []
	knocked.resize(KARTS.size())
	knocked.fill(-1000)
	var tick := 0
	while tick < int(give_up * 60.0) and done.has(-1.0):
		await get_tree().physics_frame
		tick += 1
		for i in karts.size():
			var kart := karts[i]
			var was := offsets[i]
			offsets[i] = track.offset_of(kart.global_position, was, 30.0)
			gone[i] += fposmod(offsets[i] - was + track.length * 0.5, track.length) - track.length * 0.5
			drivers[i].offset = offsets[i]
			drivers[i].lap = floori((starts[i] + gone[i]) / track.length)
			if done[i] < 0.0 and starts[i] + gone[i] >= track.length * LAPS:
				done[i] = tick / 60.0
			if not split:
				continue
			var lanes := track.lanes_at(offsets[i])
			if lanes.size() < 2:
				through[i] = -1
				continue
			var across := (kart.global_position - track.point_at(offsets[i])).dot(track.right_at(offsets[i]))
			var grounded := kart.wheels.any(func(w) -> bool: return w.grounded)
			if kart.get_colliding_bodies().any(func(b) -> bool: return b is Kart):
				knocked[i] = tick
			# Shoved there by another kart doesn't count as driving there.
			if grounded and across > lanes[0].y + OVER_BY and across < lanes[1].x - OVER_BY and tick - knocked[i] > KNOCK_FOR * 60:
				over += 1.0 / 60.0
				var where := "%s %d m" % [track.piece_type_at(offsets[i]), int(offsets[i] / 10.0) * 10]
				if OS.has_environment("OVER_DEBUG"):
					print("      kart %d at %.1f m across %.1f lanes %s branch %d" % [i, offsets[i], across, lanes, drivers[i].branches[track.racing_line().zones[track._index_before(offsets[i])]]])
				overs[where] = overs.get(where, 0.0) + 1.0 / 60.0
			if lanes[1].x - lanes[0].y > 3.5:
				var on := 1 if across > (lanes[0].y + lanes[1].x) * 0.5 else 0
				if through[i] < 0:
					through[i] = on
					sides[on] += 1
					var zone := line.zones[track._index_before(offsets[i])]
					if line.gains[zone] >= AIDriver.BRANCH_EVEN:
						uneven[0] += 1
						uneven[1] += 1 if on == line.quicker[zone] else 0
				elif through[i] != on and tick - knocked[i] <= KNOCK_FOR * 60:
					through[i] = on
				elif through[i] != on:
					through[i] = on
					crossed += 1
					print("    %.1f s kart %d crossed the island at %.0f m" % [tick / 60.0, i, offsets[i]])
	if not overs.is_empty():
		print("    over the island: %s" % overs)
	var lap := 0.0
	for t in done:
		lap += (t if t > 0.0 else give_up) / LAPS
	var out := {"uneven": uneven, "sides": sides, "over": over, "crossed": crossed, "resets": resets[0], "lap": lap / done.size(), "finished": not done.has(-1.0)}
	for ai in drivers:
		ai.kart = null
		ai.queue_free()
	for kart in karts:
		kart.queue_free()
	builder.queue_free()
	karts.clear()
	drivers.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return out
