extends SceneTree

## Drives karts at a corkscrew. One is fast enough to stick to it all the way
## round and come out the right way up, and the other crawls in and should
## slide back down instead of sticking.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/corkscrew_test.gd


class Runner:
	extends Node

	var track: TrackPath
	var fast: Kart
	var slow: Kart
	var ai: AIDriver
	var fast_offset := 2.0
	var tick := 0
	var failures := 0
	var fast_top := 0.0
	var slow_top := 0.0
	## How far upside down the fast kart went, as the lowest its up pointed.
	var fast_lowest_up := 1.0
	var fast_stuck_frames := 0
	var roll_start := 0.0
	var roll_end := 0.0
	var lost_on_roll := -1

	func _ready() -> void:
		track = TrackPath.from_dict({ "pieces": [
			{ "type": "straight", "length": 5 },
			{ "type": "corkscrew", "side": "right" },
			{ "type": "straight", "length": 4 },
		] })
		add_child(TrackBuilder.new(track))
		for k in track.points.size():
			if track.piece_of[k] == 1 and roll_start == 0.0:
				roll_start = track.distances[k]
			if track.piece_of[k] == 2 and roll_end == 0.0:
				roll_end = track.distances[k]

		fast = Kart.new()
		fast.build(KartDesign.load_file("res://data/karts/stock/starter.json"))
		fast.transform = track.place_at(2.0, 0.05)
		add_child(fast)
		ai = AIDriver.new()
		ai.kart = fast
		ai.track = track
		fast.controls = ai.controls
		add_child(ai)

	## The slow one starts just short of the corkscrew once the fast one is
	## well clear, and creeps in.
	func add_slow() -> void:
		slow = Kart.new()
		slow.build(KartDesign.load_file("res://data/karts/stock/starter.json"))
		slow.transform = track.place_at(roll_start - 6.0, 0.05)
		add_child(slow)
		slow.controls.throttle = 0.12

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _physics_process(_delta: float) -> void:
		tick += 1
		fast_offset = track.offset_of(fast.global_position, fast_offset, 30.0)
		ai.offset = fast_offset
		fast_top = maxf(fast_top, fast.global_position.y)
		fast_lowest_up = minf(fast_lowest_up, fast.global_basis.y.y)
		if tick == 60 * 20:
			add_slow()
		if slow != null:
			slow_top = maxf(slow_top, slow.global_position.y)
		if fast.sticking:
			fast_stuck_frames += 1
		if lost_on_roll < 0 and fast_offset > roll_end + 10.0:
			lost_on_roll = fast.lost.size()
		if OS.has_environment("CORKSCREW_DEBUG") and tick % 5 == 0 and tick < 60 * 14:
			var road_up := track.up_at(fast_offset)
			var road_fwd := track.forward_at(fast_offset)
			var side_off := (fast.global_position - track.point_at(fast_offset)).dot(track.right_at(fast_offset))
			var slip := rad_to_deg((-fast.global_basis.z).angle_to(fast.linear_velocity))
			print("t %.2f off %.1f spd %.1f stick %s up off %.0f°, heading off %.0f°, slip %.0f°, %.1f m to the side, steer %.2f, brake %.1f, grounded %d, loads %s, lengths %s" % [tick / 60.0, fast_offset, fast.linear_velocity.length(), fast.sticking, rad_to_deg(fast.global_basis.y.angle_to(road_up)), rad_to_deg((-fast.global_basis.z).angle_to(road_fwd)), slip, side_off, ai.controls.steer, ai.controls.brake, fast.wheels.filter(func(w): return w.grounded).size(), fast.wheels.map(func(w): return int(w.load)), fast.wheels.map(func(w): return snappedf(w.length, 0.01))])
		if tick == 60 * 28:
			check(fast_top > 11.0, "the fast kart goes right over the top of the corkscrew (%.1f m up)" % fast_top)
			check(fast_lowest_up < -0.8, "upside down on the way (up.y %.2f at the top)" % fast_lowest_up)
			check(fast_offset > roll_end + 10.0, "and comes out the other end (%.0f m along, the corkscrew ends at %.0f)" % [fast_offset, roll_end])
			check(fast.global_basis.y.y > 0.9, "the right way up (up.y %.2f)" % fast.global_basis.y.y)
			check(fast_stuck_frames > 30, "sticking to the road on the way round (%d frames)" % fast_stuck_frames)
			check(lost_on_roll == 0, "without losing any parts (%d lost)" % lost_on_roll)
			check(slow_top < 9.0, "the slow kart doesn't make it round (%.1f m up at most)" % slow_top)
			check(slow.global_position.y < 3.0, "and ends up back at the bottom (%.1f m up)" % slow.global_position.y)
			print("All corkscrew checks passed." if failures == 0 else "%d corkscrew checks failed." % failures)
			get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
