extends Node

## The split straight: the road parts round a grass island and joins up again.
## A course with one builds, flat and on hills; each branch is road and the
## island is grass; a reset beside the island goes back on a branch; and a
## kart driven down each branch keeps going forward and finishes a lap. The
## other splits (the 96 m, wide, bends, rough and jump splits) build in all
## four layouts with road on each branch, grass on the island and the dirt or
## jump on the right branch.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/split_piece_test.tscn

## Builds the little square courses the split pictures use.
const MORE_COURSE := preload("res://tools/shots/split_more_shots.gd")
## The other splits, each checked in every layout.
const MORE := [
	{"type": "split", "length": 3},
	{"type": "split", "length": 4, "island": 38.0},
	{"type": "split_bend", "turn": "left", "size": 3},
	{"type": "split_bend", "turn": "right", "size": 4},
	{"type": "rough_split", "side": "left"},
	{"type": "rough_split", "side": "right"},
	{"type": "jump_split", "side": "left"},
	{"type": "jump_split", "side": "right"},
]
const PIECES := [
	{"type": "straight", "length": 1},
	{"type": "split", "length": 2},
	{"type": "curve", "turn": "right", "size": 2},
	{"type": "curve", "turn": "right", "size": 2},
	{"type": "straight", "length": 3},
	{"type": "curve", "turn": "right", "size": 2},
	{"type": "curve", "turn": "right", "size": 2},
]
## The longest a lap may take, in seconds.
const GIVE_UP := 120.0
## How fast the test driver goes, in m/s.
const PACE := 15.0

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var track := _course(0.0)
	check(track.closes and track.has_splits, "the course with a split closes")
	var spec := TrackPiece.from_spec({"type": "split", "length": 2}).to_spec()
	check(spec == {"type": "split", "length": 2}, "the split's spec round trips (%s)" % spec)
	var wide := TrackPiece.from_spec({"type": "split", "length": 3, "island": 8.0}).to_spec()
	check(wide == {"type": "split", "length": 3, "island": 8.0}, "a narrower island round trips (%s)" % wide)
	var plain := track.lanes_at(10.0)
	check(plain.size() == 1 and plain[0] == Vector2(-6.5, 6.5), "ordinary road is one lane as wide as the road (%s)" % plain)
	var middle := TrackPiece.TILE * 2.0
	var lanes := track.lanes_at(middle)
	check(lanes.size() == 2, "the middle of the split has two branches (%s)" % lanes)
	if lanes.size() == 2:
		check(is_equal_approx(lanes[1].x - lanes[0].y, 12.0) and is_equal_approx(lanes[0].y - lanes[0].x, 10.0), "the island is 12 m and the branches 10 m (%s)" % lanes)
		check(is_equal_approx(lanes[1].y, 16.0), "the split is 32 m across (%.2f)" % (lanes[1].y * 2.0))
	check(track.lanes_at(TrackPiece.TILE + 1.0).size() == 1 and track.lanes_at(TrackPiece.TILE * 3.0 - 1.0).size() == 1, "the branches meet at each end")
	check(not track.on_road_across(middle, 0.0) and track.on_road_across(middle, -11.0) and track.on_road_across(middle, 11.0), "the island isn't road and the branches are")
	var left := track.reset_spots(middle, -2.0)
	var right := track.reset_spots(middle, 2.0)
	check(left[0] < -6.0 and right[0] > 6.0, "a reset beside the island goes to the nearer branch (%.1f, %.1f)" % [left[0], right[0]])
	var on_branch := true
	for spot in left + right:
		on_branch = on_branch and track.on_road_across(middle, spot, 1.0)
	check(on_branch, "every reset spot by the island is on a branch")
	check(track.reset_spots(10.0, 3.0) == [0.0, -3.0, 3.0, -4.5, 4.5], "resets on ordinary road are as before")
	check(track.clashes().is_empty(), "the course doesn't clash with itself")
	# There's a line down each branch, and the quicker one is the default.
	var line := track.racing_line()
	var line_ok := line.split_mids.size() == 1
	for k in track.points.size():
		if track.split_sample(k) and track.lanes_of(k).size() == 2:
			var two := track.lanes_of(k)
			for side in 2:
				var at := line.side_offsets[side][k]
				line_ok = line_ok and at > two[side].x + 1.0 and at < two[side].y - 1.0
			line_ok = line_ok and line.offsets[k] == line.side_offsets[line.quicker[0]][k]
	check(line_ok, "a racing line down each branch through the split, %s the quicker by %.2f s" % [["left", "right"][line.quicker[0]], line.gains[0]])
	var middle_line := [track.line_offset_at(middle, PackedInt32Array([0])), track.line_offset_at(middle, PackedInt32Array([1]))]
	check(middle_line[0] < -6.0 and middle_line[1] > 6.0, "line_offset_at() follows the branch it's given (%.1f, %.1f)" % middle_line)

	for hills in [0.0, 8.0]:
		await _surfaces(hills)
	for more in MORE:
		var round_trip := TrackPiece.from_spec(more).to_spec()
		check(round_trip == more, "%s round trips (%s)" % [more, round_trip])
		for layout in [[false, false], [true, false], [false, true], [true, true]]:
			await _more(more, layout[0], layout[1])
	await _drive(-1)
	await _drive(1)
	print("All split piece checks passed." if failures == 0 else "%d split piece checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _course(hills: float) -> TrackPath:
	return TrackPath.from_dict({"name": "Split test", "theme": "orchard", "hills": hills, "pieces": PIECES})


## Rays down onto the built course: road on both branches all the way along,
## grass on the island, and nothing on top of the road.
func _surfaces(hills: float) -> void:
	var track := _course(hills)
	var builder := TrackBuilder.new(track)
	builder.sky = false
	add_child(builder)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := builder.get_world_3d().direct_space_state
	var name := "on hills" if hills > 0.0 else "flat"
	var missed := []
	var island_road := []
	var d := TrackPiece.TILE
	while d <= TrackPiece.TILE * 3.0:
		var lanes := track.lanes_at(d)
		for lane in lanes:
			for across in [lane.x + 0.6, (lane.x + lane.y) * 0.5, lane.y - 0.6]:
				var hit := _ray(space, track, d, across)
				if hit.is_empty() or hit.collider.get_meta("offroad", false) or hit.collider.get_meta("kerb", false) \
						or absf((hit.position - track.point_at(d)).dot(track.up_at(d)) - TrackBuilder.LIFT) > 0.05:
					missed.append("%.0f m, %.1f across" % [d, across])
		if lanes.size() == 2 and lanes[1].x - lanes[0].y > 4.0:
			var hit := _ray(space, track, d, (lanes[0].y + lanes[1].x) * 0.5)
			if hit.is_empty() or not hit.collider.get_meta("offroad", false):
				island_road.append("%.0f m" % d)
		d += 2.0
	check(missed.is_empty(), "%s: both branches are road all the way along %s" % [name, missed.slice(0, 4)])
	check(island_road.is_empty(), "%s: the island is grass %s" % [name, island_road.slice(0, 4)])
	var kerbs := 0
	for child in builder.get_children():
		if child is StaticBody3D and child.get_meta("kerb", false):
			kerbs += 1
	check(kerbs >= 4, "%s: the split has curbs outside and round the island (%d)" % [name, kerbs])
	builder.queue_free()
	await get_tree().physics_frame


## One of the other splits in a little square course, mirrored and reversed
## or not: rays down each branch find road (dirt on a rough split's dirt
## branch) except over a jump's gap, rays down the island's middle find
## grass, and the odd branch is on the side it should be.
func _more(spec: Dictionary, mirrored: bool, reversed: bool) -> void:
	var track := MORE_COURSE.course(spec)
	track.apply_layout(mirrored, reversed)
	var name := "%s%s%s" % [spec, " mirrored" if mirrored else "", " reversed" if reversed else ""]
	check(track.closes and track.clashes().is_empty(), "%s: closes without clashing" % name)
	var builder := TrackBuilder.new(track)
	builder.sky = false
	add_child(builder)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := builder.get_world_3d().direct_space_state
	var missed := []
	var island_road := []
	var wrong := []
	var gaps := 0
	var lifted := 0
	var odd_sides := {}
	for k in track.points.size():
		var lanes := track.lanes_of(k)
		if lanes.size() < 2:
			continue
		var d := track.distances[k]
		for side in 2:
			var surface := track.branch_surface(k, side)
			if surface != "asphalt":
				odd_sides[side] = true
			if track.branch_lift(k, side) > 0.3:
				odd_sides[side] = true
				lifted += 1
			if not track.branch_solid(k, side):
				odd_sides[side] = true
				gaps += 1
				continue
			# The road ends between samples at a jump's gap.
			var count := track.points.size()
			if not track.branch_solid((k + 1) % count, side) or not track.branch_solid((k - 1 + count) % count, side):
				continue
			var hit := _ray(space, track, d, (lanes[side].x + lanes[side].y) * 0.5)
			if hit.is_empty() or hit.collider.get_meta("offroad", false) or hit.collider.get_meta("kerb", false):
				missed.append("%.0f m %s" % [d, ["left", "right"][side]])
			elif str(hit.collider.get_meta("surface", "")) != surface:
				wrong.append("%.0f m %s" % [d, hit.collider.get_meta("surface", "")])
		if lanes[1].x - lanes[0].y > 4.0:
			var hit := _ray(space, track, d, (lanes[0].y + lanes[1].x) * 0.5)
			if hit.is_empty() or not hit.collider.get_meta("offroad", false):
				island_road.append("%.0f m" % d)
	check(missed.is_empty() and wrong.is_empty(), "%s: both branches are the right road all the way along %s %s" % [name, missed.slice(0, 4), wrong.slice(0, 4)])
	check(island_road.is_empty(), "%s: the island is grass %s" % [name, island_road.slice(0, 4)])
	if spec.type in ["rough_split", "jump_split"]:
		# The odd branch is on the spec's side for a jump and away from the
		# tarmac's side for a rough split, swapped once by a mirror or a
		# reverse and back again by both.
		var right: bool = (spec.side == "right") == (spec.type == "jump_split")
		if mirrored != reversed:
			right = not right
		check(odd_sides.keys() == [1 if right else 0], "%s: the odd branch is on the %s (%s)" % [name, "right" if right else "left", odd_sides.keys()])
	if spec.type == "jump_split":
		check(gaps > 0 and lifted > 0, "%s: the jump branch has a kicker and a gap (%d, %d)" % [name, lifted, gaps])
	builder.queue_free()
	await get_tree().physics_frame


func _ray(space: PhysicsDirectSpaceState3D, track: TrackPath, d: float, across: float) -> Dictionary:
	var at := track.point_at(d) + track.right_at(d) * across
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 6.0, at - Vector3.UP * 6.0)
	query.collision_mask = Kart.LAYER_WORLD
	return space.intersect_ray(query)


## Drives a kart a lap down one branch (-1 left, 1 right), steering for the
## middle of that branch, and counts its laps like a race does.
func _drive(branch: int) -> void:
	var track := _course(0.0)
	var builder := TrackBuilder.new(track)
	builder.sky = false
	builder.scenery = "none"
	add_child(builder)
	var kart := Kart.new()
	kart.build(KartDesign.load_file("res://data/karts/stock/kart_kid.json"))
	var offset := track.length - 15.0
	kart.transform = track.place_at(offset, 0.3)
	add_child(kart)
	var controls := KartControls.new()
	kart.controls = controls
	var progress := RaceProgress.new(track.length, 1, offset)
	var name := "left" if branch < 0 else "right"
	var backwards := 0
	var off := 0
	var island := 0
	var split_frames := 0
	var resets := 0
	kart.was_reset.connect(func() -> void: resets += 1)
	kart.reset_to = func(_where: Vector3) -> Transform3D: return track.place_at(offset)
	var time := 0.0
	for tick in int(GIVE_UP * 60.0):
		await get_tree().physics_frame
		time += 1.0 / 60.0
		var was := offset
		offset = track.offset_near(kart.global_position, offset, 5.0, 40.0)
		progress.update(offset, time)
		if progress.finished:
			break
		var moved := fposmod(offset - was + track.length * 0.5, track.length) - track.length * 0.5
		if moved < -0.05:
			backwards += 1
		var across := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset))
		var i := track._index_before(offset)
		if track.split_sample(i):
			split_frames += 1
			if not track.on_road_across(offset, across, -0.3):
				off += 1
				var lanes := track.lanes_at(offset)
				if lanes.size() == 2 and across > lanes[0].y and across < lanes[1].x:
					island += 1
		_steer(kart, controls, track, offset, branch)
	check(progress.finished, "%s branch: a lap in %.1f s" % [name, time])
	check(split_frames > 60 and off == 0 and island == 0, "%s branch: on the branch all through the split (%d frames, %d off, %d on the island)" % [name, split_frames, off, island])
	check(backwards < 10 and resets == 0, "%s branch: always going forward (%d frames back, %d resets)" % [name, backwards, resets])
	kart.queue_free()
	builder.queue_free()
	await get_tree().physics_frame


## Steers for the middle of the chosen branch a little way ahead, at an easy
## pace.
func _steer(kart: Kart, controls: KartControls, track: TrackPath, offset: float, branch: int) -> void:
	var ahead := offset + 9.0
	var i := track._index_before(ahead)
	var across := track.branch_lefts[i].x if branch < 0 else track.branch_rights[i].x
	var target := track.point_at(ahead) + track.right_at(ahead) * across
	var forward := -kart.global_transform.basis.z
	var to := target - kart.global_position
	var angle := Vector2(forward.x, forward.z).angle_to(Vector2(to.x, to.z))
	controls.steer = clampf(angle * 2.5, -1.0, 1.0)
	var speed := kart.linear_velocity.dot(forward)
	controls.throttle = 1.0 if speed < PACE else 0.0
	controls.brake = 0.3 if speed > PACE + 3.0 else 0.0
