extends SceneTree

## Drives karts at a loop. One is fast enough to stick to it all the way
## around, and the other crawls in and should drop off instead of sticking.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/loop_test.gd


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
	var fast_stuck_frames := 0
	var loop_end := 0.0
	var loop_start := 0.0

	func _ready() -> void:
		track = TrackPath.from_dict({ "pieces": [
			{ "type": "straight", "length": 5 },
			{ "type": "loop", "side": "right" },
			{ "type": "straight", "length": 4 },
		] })
		add_child(TrackBuilder.new(track))
		for k in track.points.size():
			if track.piece_of[k] == 1 and loop_start == 0.0:
				loop_start = track.distances[k]
			if track.piece_of[k] == 2 and loop_end == 0.0:
				loop_end = track.distances[k]

		var design := KartDesign.load_file("res://data/karts/starter.json")
		fast = Kart.new()
		fast.build(design)
		fast.transform = track.place_at(2.0, 0.05)
		add_child(fast)
		ai = AIDriver.new()
		ai.kart = fast
		ai.track = track
		fast.controls = ai.controls
		add_child(ai)

	## The slow one starts just short of the loop once the fast one is well
	## clear, and creeps in.
	func add_slow() -> void:
		slow = Kart.new()
		slow.build(KartDesign.load_file("res://data/karts/starter.json"))
		slow.transform = track.place_at(loop_start - 6.0, 0.05)
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
		if tick == 60 * 11:
			add_slow()
		if slow != null:
			slow_top = maxf(slow_top, slow.global_position.y)
		if fast.sticking:
			fast_stuck_frames += 1
		if OS.has_environment("LOOP_DEBUG") and tick == 60 * 6:
			for body in fast.get_colliding_bodies():
				var info := []
				for child in body.get_children():
					if child is CollisionShape3D:
						var aabb := AABB()
						if child.shape is ConcavePolygonShape3D:
							var faces: PackedVector3Array = child.shape.get_faces()
							aabb = AABB(faces[0], Vector3.ZERO)
							for f in faces:
								aabb = aabb.expand(f)
						info.append([child.shape.get_class(), child.global_position, aabb])
				print("BODY %s metas %s index %d shapes %s" % [body.name, body.get_meta_list(), body.get_index(), info])
		if OS.has_environment("LOOP_DEBUG") and tick % 5 == 0 and fast_offset > 95.0 and fast_offset < 200.0 and tick < 60 * 10:
			print("L off %.1f y %.1f spd %.1f fwd %.1f stick %s grounded %d lengths %s loads %s colliding %d thr %.1f brk %.1f up %s" % [fast_offset, fast.global_position.y, fast.linear_velocity.length(), fast.forward_speed, fast.sticking, fast.wheels.filter(func(w): return w.grounded).size(), fast.wheels.map(func(w): return snappedf(w.length, 0.01)), fast.wheels.map(func(w): return int(w.load)), fast.get_contact_count(), ai.controls.throttle, ai.controls.brake, fast.global_basis.y.snapped(Vector3.ONE*0.01)])
		if false:
			print("t %.2f off %.1f pos %s spd %.1f thr %.1f brk %.1f steer %.2f up %s colliding %s" % [tick / 60.0, fast_offset, fast.global_position.snapped(Vector3.ONE * 0.1), fast.linear_velocity.length(), ai.controls.throttle, ai.controls.brake, ai.controls.steer, fast.global_basis.y.snapped(Vector3.ONE * 0.01), fast.get_colliding_bodies().map(func(b): return b.name)])
		if tick == 60 * 19:
			check(fast_top > 17.0, "the fast kart goes right over the top of the loop (%.1f m up)" % fast_top)
			check(fast_offset > loop_end + 10.0, "and comes out the other side (%.0f m along, the loop ends at %.0f)" % [fast_offset, loop_end])
			check(fast.global_basis.y.y > 0.9, "the right way up (up.y %.2f)" % fast.global_basis.y.y)
			check(fast_stuck_frames > 60, "sticking to the road on the way around (%d frames)" % fast_stuck_frames)
			check(fast.lost.is_empty(), "without losing any parts (%d lost)" % fast.lost.size())
			check(slow_top < 12.0, "the slow kart doesn't make it around (%.1f m up at most)" % slow_top)
			check(slow.global_position.y < 3.0, "and ends up back at the bottom (%.1f m up)" % slow.global_position.y)
			print("All loop checks passed." if failures == 0 else "%d loop checks failed." % failures)
			get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
