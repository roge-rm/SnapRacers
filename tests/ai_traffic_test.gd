extends Node

## Focused decisions and real physics passes, plus a stopped queue.
var failures := 0
var checks := 0
var design: KartDesign
var track: TrackPath
var karts: Array[Kart] = []
var drivers: Array[AIDriver] = []


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	design = KartDesign.load_file("res://tests/data/legacy/starter.json")
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 14}]})
	_decisions()
	_clear()
	await get_tree().physics_frame
	await _pass("normal", false)
	await _pass("hard", true, true)
	await _pass("expert", true, true, true)
	await _queue()
	print("All %d AI traffic checks passed." % checks if failures == 0 else "%d of %d AI traffic checks failed." % [failures, checks])
	get_tree().quit(1 if failures else 0)


func _place(at: float, across: float, speed: float, frozen := true) -> Kart:
	var kart := Kart.new()
	kart.build(design)
	kart.transform = track.place_at(at, 0.05)
	kart.transform.origin += kart.transform.basis.x * across
	add_child(kart)
	kart.freeze = frozen
	kart.linear_velocity = track.forward_at(at) * speed
	for wheel in kart.wheels:
		wheel.grounded = true
	karts.append(kart)
	return kart


func _ai(kart: Kart, at: float, level := "normal") -> AIDriver:
	var ai := AIDriver.new()
	ai.kart = kart
	ai.track = track
	ai.offset = at
	kart.controls = ai.controls
	Difficulty.apply(ai, level, 0, 1)
	add_child(ai)
	ai.set_physics_process(false)
	ai.others = karts
	drivers.append(ai)
	return ai


func _clear() -> void:
	for ai in drivers:
		ai.kart = null
		ai.queue_free()
	for kart in karts:
		kart.queue_free()
	drivers.clear()
	karts.clear()


func _decisions() -> void:
	var own := _place(100.0, 0.0, 25.0)
	var leader := _place(135.0, 0.0, 5.0)
	var ai := _ai(own, 100.0)
	track.width = own.width() + 1.8
	var chosen := ai.traffic.plan(ai, 0.0, 0.033)
	check(ai.traffic.speed_limit < 24.0, "a boxed fast chaser brakes well before the old 8 m trigger (%.1f m/s at 35 m)" % ai.traffic.speed_limit)
	own.mass = 500.0
	var dry := AITrafficPlanner.braking(ai)
	own.mass *= 2.0
	check(AITrafficPlanner.braking(ai) < dry * 0.6, "braking distance uses current mass")
	own.weather_grip = 0.2
	check(AITrafficPlanner.braking(ai) < dry * 0.95, "slippery road limits braking traction")
	own.weather_grip = 1.0
	own.mass = own.stats.mass
	track.width = 13.0
	leader.position = track.place_at(111.0, 0.05).origin
	leader.linear_velocity = track.forward_at(111.0) * 8.0
	own.linear_velocity = track.forward_at(100.0) * 12.0
	ai.traffic = AITrafficPlanner.new()
	chosen = ai.traffic.plan(ai, 0.0, 0.033)
	check(absf(chosen) >= own.width() + ai.traffic_clearance - 0.05, "an ordinary pass uses both karts' widths and clean clearance")
	leader._width += 1.0
	ai.traffic = AITrafficPlanner.new()
	var wide := ai.traffic.plan(ai, 0.0, 0.033)
	check(absf(wide) > absf(chosen) + 0.4, "a wider opponent needs a wider passing line")
	leader._width -= 1.0
	own.stats.control = 0.4
	ai.traffic = AITrafficPlanner.new()
	var careful := ai.traffic.plan(ai, 6.0, 0.033)
	check(absf(careful) <= track.width * 0.5 - own.width() * 0.5 - 0.95, "poor steering keeps more room at the road edge")
	own.stats.control = 1.0
	ai.traffic = AITrafficPlanner.new()
	chosen = ai.traffic.plan(ai, 0.0, 0.033)
	var side := signf(chosen)
	var switches := 0
	for n in 40:
		chosen = ai.traffic.plan(ai, 0.0, 0.033)
		if signf(chosen) != side:
			switches += 1
	check(switches == 0, "passing intent holds its side across repeated plans")
	# The right-hand passing line has a fast kart coming from behind.
	var rear := _place(89.0, own.width() + 0.8, 24.0)
	ai.others = karts
	ai.traffic = AITrafficPlanner.new()
	chosen = ai.traffic.plan(ai, own.width() + 0.8, 0.033)
	check(chosen < 0.5, "a fast rear overtaker rules out the tempting right lane")
	# Crossing its present lane on the way to an empty endpoint is unsafe too.
	rear.position = track.place_at(99.0, 0.05).origin + track.right_at(99.0) * 1.7
	rear.linear_velocity = track.forward_at(99.0) * 12.0
	ai.traffic = AITrafficPlanner.new()
	chosen = ai.traffic.plan(ai, 4.0, 0.033)
	check(chosen <= 0.25, "a lane change checks the swept path past an alongside kart")
	# A changed hazard must break a held passing intention immediately.
	rear.position = track.place_at(101.0, 0.05).origin - track.right_at(101.0) * 2.0
	ai.traffic = AITrafficPlanner.new()
	ai.traffic.target = -3.0
	ai.traffic._hold = 1.0
	chosen = ai.traffic.plan(ai, 0.0, 0.033)
	check(chosen > -0.5, "an unsafe held pass is replanned immediately")
	# Recovery must pull away from its actual offender, without crossing it.
	leader.position = track.place_at(100.0, 0.05).origin + track.right_at(100.0) * 1.0
	leader.linear_velocity = track.forward_at(100.0) * 12.0
	rear.position += Vector3.UP * 15.0
	ai._recover_from = leader
	ai._tries = 1
	ai._stuck = 1.0
	ai.traffic = AITrafficPlanner.new()
	chosen = ai.traffic.plan(ai, 4.0, 0.033)
	check(chosen < 0.5, "recovery cannot cross its offender to reach an empty far lane")
	# A different stopped kart can still be a real queue during recovery.
	leader.position += track.right_at(100.0) * 5.0
	rear.position = track.place_at(104.0, 0.05).origin
	rear.linear_velocity = Vector3.ZERO
	own.linear_velocity = Vector3.ZERO
	var old_width := track.width
	track.width = 4.5
	ai.traffic = AITrafficPlanner.new()
	ai.traffic.plan(ai, 0.0, 0.033)
	ai._stuck_check(0.1, 0.0, Vector3.UP)
	check(ai.traffic.queueing and ai._stuck == 0.0 and ai._tries == 0 and ai._backing <= 0.0 and not ai.controls.reset, "a different stopped queue ends recovery without reversing or resetting")
	track.width = old_width
	own.linear_velocity = track.forward_at(100.0) * 12.0
	ai._tries = 0
	ai._stuck = 0.0
	ai._recover_from = null
	# An elevated kart over the same road cannot be a queue.
	leader.position = track.place_at(105.0, 0.05).origin + Vector3.UP * 8.0
	rear.position = track.place_at(106.0, 0.05).origin + Vector3.UP * 8.0
	ai.traffic = AITrafficPlanner.new()
	ai.traffic.plan(ai, 0.0, 0.033)
	check(is_inf(ai.traffic.speed_limit), "a kart on a bridge above does not block the road below")
	_clear()
	# Adjacent opposing sides of a real hairpin must retain their own projection.
	var old_track := track
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 4}, {"type": "curve", "size": 1, "turn": "right"}, {"type": "curve", "size": 1, "turn": "right"}, {"type": "straight", "length": 4}]})
	own = _place(60.0, 0.0, 15.0)
	leader = _place(track.length * 0.5 + 50.0, 0.0, 0.0)
	ai = _ai(own, 60.0)
	check(ai.traffic._traffic(ai, 200.0).is_empty(), "an adjacent hairpin branch is excluded by its road projection")
	_clear()
	track = old_track
	for level in ["easy", "normal", "hard", "expert"]:
		own = _place(100.0, 0.0, 11.4)
		leader = _place(99.0, own.width() - 0.10, 10.0)
		own.mass *= 1.6
		own.shield_left = 10.0
		leader.shield_left = 10.0
		ai = _ai(own, 100.0, level)
		var bodies := ai.traffic._traffic(ai, 50.0)
		check(not bodies.is_empty(), "%s contested opponent is seen" % level)
		var can_contact := ai.traffic._contact_safe(ai, bodies[0], bodies)
		check(can_contact == (level in ["hard", "expert"]), "%s contact policy follows difficulty and current mass" % level)
		ai.traffic.plan(ai, 0.0, 0.033)
		if level in ["hard", "expert"]:
			var crossing := LevelCrossing.new(track, 400.0, 0, func(_x, _z): return 0.0)
			crossing.offset = 400.0
			ai.crossings.append(crossing)
			check(ai.traffic._contact_safe(ai, bodies[0], bodies), "%s can contest a lane far from a crossing" % level)
			crossing.offset = ai.offset + 10.0
			check(not ai.traffic._contact_safe(ai, bodies[0], bodies), "%s avoids contact near a crossing" % level)
			ai.crossings.clear()
			crossing.free()
			var wall := BrickWall.new()
			add_child(wall)
			wall.set_physics_process(false)
			wall.global_position = track.point_at(400.0)
			AIDriver._walls = [wall]
			check(ai.traffic._contact_safe(ai, bodies[0], bodies), "%s can contest a lane far from a wall" % level)
			wall.global_position = track.point_at(ai.offset + 10.0)
			check(not ai.traffic._contact_safe(ai, bodies[0], bodies), "%s avoids contact near a standing wall" % level)
			for brick in wall._bricks:
				brick.freeze = false
			check(ai.traffic._contact_safe(ai, bodies[0], bodies), "%s ignores a dismantled wall when judging contact" % level)
			AIDriver._walls = []
			wall.queue_free()
			own.shield_left = 0.0
			check(not ai.traffic._contact_safe(ai, bodies[0], bodies), "%s keeps exposed unshielded wheels out of deliberate contact" % level)
			own.shield_left = 10.0
			check(ai.traffic.contact == leader, "%s selects a short progressive contested pass" % level)
			leader.lost[0] = true
			ai.traffic.plan(ai, 0.0, 0.033)
			check(ai.traffic.contact == null and ai.traffic._cooldown > 0.0, "%s aborts and cools down when the opponent is damaged" % level)
			leader.lost.clear()
			own.mass = leader.mass * 0.9
			check(not ai.traffic._contact_safe(ai, bodies[0], bodies), "%s yields when the masses are swapped" % level)
			own.mass = leader.mass * 1.6
			leader.linear_velocity = Vector3.ZERO
			bodies = ai.traffic._traffic(ai, 50.0)
			check(not ai.traffic._contact_safe(ai, bodies[0], bodies), "%s never shoves a stationary queue" % level)
			leader.linear_velocity = track.forward_at(99.0) * 10.0
			bodies = ai.traffic._traffic(ai, 50.0)
			own.position += track.right_at(100.0) * 3.5
			check(not ai.traffic._contact_safe(ai, bodies[0], bodies), "%s rejects contact without displacement room at an edge" % level)
			own.position -= track.right_at(100.0) * 3.5
			var third := _place(106.0, -3.0, 8.0)
			ai.others = karts
			bodies = ai.traffic._traffic(ai, 50.0)
			var opponent: Dictionary = bodies.filter(func(body: Dictionary) -> bool: return body.kart == leader)[0]
			check(not ai.traffic._contact_safe(ai, opponent, bodies), "%s rejects contact with a third kart in the recovery space" % level)
			third.position += Vector3.UP * 15.0
			ai._has_jump = 1
			# Force a jump run-in on the actual road pieces.
			var original_type: String = track.pieces[0].type
			track.pieces[0].type = "jump"
			check(not ai.traffic._contact_safe(ai, opponent, [opponent]), "%s rejects contact on a jump run-in" % level)
			track.pieces[0].type = original_type
		_clear()


func _pass(level: String, contested: bool, stock := false, shielded := false) -> void:
	track.width = 13.0
	var road := TrackBuilder.new(track)
	add_child(road)
	var original := design
	if stock:
		design = KartDesign.load_file("res://data/karts/stock/night_shift.json")
	var own := _place(100.0, 0.0, 0.0, false)
	if stock:
		design = KartDesign.load_file("res://data/karts/stock/kart_kid.json")
	var separation := own.width() + 0.5 if contested else 0.0
	var leader := _place(99.0 if contested else 112.0, separation, 0.0, false)
	design = original
	var ai := _ai(own, 100.0, level)
	ai.pace = 1.0
	ai.mistakes = 0.0
	ai.slides = false
	if shielded:
		own.shield_left = 20.0
		leader.shield_left = 20.0
	# Let the suspension settle, then start both karts aligned and moving.
	for n in 30:
		await get_tree().physics_frame
	if contested:
		leader.position = own.position + track.right_at(100.0) * (_collision_edge(own, 1.0) + _collision_edge(leader, -1.0) + 0.02) + track.forward_at(100.0) * (-0.5 if stock else 0.1)
		leader.angular_velocity = Vector3.ZERO
		own.angular_velocity = Vector3.ZERO
	own.linear_velocity = track.forward_at(100.0) * (11.49 if contested else 12.0)
	leader.linear_velocity = track.forward_at(100.0) * (10.0 if contested else 8.0)
	if contested:
		leader.linear_velocity -= track.right_at(100.0) * 0.45
		check(not _bodies_overlap(own, leader), "%s starts with separated collision shapes" % level)
	ai._drive(1.0 / 30.0, own.linear_velocity.length())
	ai.set_physics_process(true)
	var own_at := 100.0
	var leader_at := 99.0 if contested else 112.0
	var contacts := 0
	var commits := 0
	var passed := false
	var resets := 0
	var most_contact_time := 0.0
	for n in 60 * 14:
		await get_tree().physics_frame
		own_at = track.offset_of(own.global_position, own_at, 10.0)
		leader_at = track.offset_of(leader.global_position, leader_at, 10.0)
		ai.offset = own_at
		var leader_speed := leader.linear_velocity.dot(track.forward_at(leader_at))
		leader.controls.throttle = 0.0 if leader_speed > (10.0 if contested else 8.0) else 0.30
		leader.controls.brake = 0.0
		if own.get_colliding_bodies().has(leader):
			contacts += 1
		if ai.traffic.contact == leader:
			commits += 1
			most_contact_time = maxf(most_contact_time, ai.traffic.contact_left)
		if ai.controls.reset:
			resets += 1
		if own_at > leader_at + own.tail_length() + AITrafficPlanner._front(leader) + 0.5:
			passed = true
			break
	check(passed, "%s %s pass gets fully ahead (%.1f m gap)" % [level, "contested" if contested else "clean", own_at - leader_at])
	check(resets == 0, "%s pass needs no reset" % level)
	if contested:
		check(commits > 0 and contacts > 0, "%s holds the contested lane with brief physical contact (%d contact frames, %d committed)" % [level, contacts, commits])
		check(own.global_basis.y.y > 0.9 and leader.global_basis.y.y > 0.9 and not ai._lost_a_wheel() and not _wheel_lost(leader), "%s %s contact leaves both karts upright with their wheels (up %.2f/%.2f, lost parts %d/%d)" % [level, "shielded" if shielded else "stock body", own.global_basis.y.y, leader.global_basis.y.y, own.lost.size(), leader.lost.size()])
		check(most_contact_time <= ai.traffic_contact_time, "%s contact commitment stays bounded" % level)
	else:
		check(contacts == 0, "Normal passes without touching the slower kart (%d contact frames)" % contacts)
	_clear()
	road.queue_free()
	await get_tree().physics_frame


func _queue() -> void:
	track.width = 4.5
	var road := TrackBuilder.new(track)
	add_child(road)
	var own := _place(60.0, 0.0, 0.0, false)
	var leader := _place(112.0, 0.0, 0.0, false)
	leader.locked = true
	var ai := _ai(own, 60.0)
	ai.pace = 1.0
	for n in 30:
		await get_tree().physics_frame
	own.linear_velocity = track.forward_at(60.0) * 20.0
	ai.set_physics_process(true)
	var at := 60.0
	var contacts := 0
	var resets := 0
	var backwards := 0
	var waited := 0
	var brake_at := -1.0
	for n in 60 * 12:
		await get_tree().physics_frame
		at = track.offset_of(own.global_position, at, 10.0)
		ai.offset = at
		if own.get_colliding_bodies().has(leader):
			contacts += 1
		if ai.controls.reset:
			resets += 1
		if own.linear_velocity.dot(track.forward_at(at)) < -0.15:
			backwards += 1
		if ai.traffic.queueing and own.linear_velocity.length() < 0.7:
			waited += 1
		if brake_at < 0.0 and ai.controls.brake > 0.0:
			brake_at = 112.0 - at
	check(brake_at > 8.0, "a 20 m/s approach to a queue brakes early (%.1f m ahead)" % brake_at)
	check(contacts == 0, "a boxed stationary queue stops without contact (%d frames)" % contacts)
	check(waited > 120 and own.linear_velocity.length() < 0.7, "the driver waits stationary for the queue (%d frames)" % waited)
	check(backwards == 0 and resets == 0, "waiting never reverses or triggers stuck resets (%d reverse frames, %d resets)" % [backwards, resets])
	_clear()
	road.queue_free()
	await get_tree().physics_frame


func _bodies_overlap(a: Kart, b: Kart) -> bool:
	for mine in a.get_children():
		if not mine is CollisionShape3D:
			continue
		var mine_box: AABB = mine.global_transform * mine.shape.get_debug_mesh().get_aabb()
		for theirs in b.get_children():
			if not theirs is CollisionShape3D:
				continue
			var their_box: AABB = theirs.global_transform * theirs.shape.get_debug_mesh().get_aabb()
			if mine_box.intersects(their_box):
				return true
	return false


func _collision_edge(kart: Kart, side: float) -> float:
	var edge := 0.0
	for child in kart.get_children():
		if child is CollisionShape3D:
			var box: AABB = child.transform * child.shape.get_debug_mesh().get_aabb()
			edge = maxf(edge, box.end.x if side > 0.0 else -box.position.x)
	return edge


func _wheel_lost(kart: Kart) -> bool:
	for index in kart.lost:
		if KartDesign.is_wheel(kart.design.parts[index].id):
			return true
	return false
