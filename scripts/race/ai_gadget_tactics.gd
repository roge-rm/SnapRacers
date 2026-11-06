class_name AIGadgetTactics
extends RefCounted

## Scores visible opportunities using the same targets, ranges and launch
## geometry as the gadgets. Zero means hold the item.
static func score(ai: AIDriver, kind: String, speed: float) -> float:
	var kart := ai.kart
	if kart.locked:
		return 0.0
	match kind:
		"turbo", "big_turbo", "triple_turbo":
			var duration := Kart.TURBO_TIME
			if kind == "big_turbo":
				duration = Kart.BIG_TURBO_TIME
			elif kind == "triple_turbo":
				duration = Kart.TRIPLE_TURBO_TIME
			return 1.0 if _boost_safe(ai, speed, duration) else 0.0
		"cannon":
			return _cannon(ai)
		"homing":
			var target := BrickShot._kart_ahead(kart)
			if not _target(ai, target) or target.shield_left > 0.0:
				return 0.0
			var gap := target.global_position - kart.global_position
			var turn_time := (-kart.global_basis.z).angle_to(gap.normalized()) / BrickShot.TURN
			var closing := BrickShot.HOMING_SPEED - target.linear_velocity.dot(gap.normalized())
			if closing <= 2.0 or turn_time + gap.length() / closing > BrickShot.HOMING_LIFETIME * 0.8:
				return 0.0
			return 2.0
		"lightning":
			var race := kart.get_parent()
			if not race.has_method("standings"):
				return 0.0
			var victims := 0
			for racer in race.standings():
				if racer.kart == kart:
					break
				if is_instance_valid(racer.kart) and racer.kart.shield_left <= 0.0 and racer.kart.ghost_left <= 0.0 and racer.kart.zapped_left < 1.0:
					victims += 1
			return 2.0 + minf(victims, 4) * 0.2 if victims > 0 else 0.0
		"dropper", "marbles", "wall", "spikes":
			return _rear(ai, kind)
		"shockwave":
			var victims := 0
			var close := false
			for other in ai.others:
				if not _target(ai, other):
					continue
				var distance := kart.global_position.distance_to(other.global_position)
				if distance < Kart.SHOCK_REACH - 0.5:
					victims += 1
					close = close or distance < Kart.SHOCK_KNOCK_REACH
			if victims > 0:
				return 2.0 + minf(victims, 4) * 0.3 + (0.4 if close else 0.0)
			return 2.5 if _hazard_ahead(ai, Kart.SHOCK_REACH - 1.0, true) else 0.0
		"shield":
			if kart.shield_left > 0.0 or kart.ghost_left > 0.0:
				return 0.0
			if kart.zapped_left > 0.0:
				return 4.5
			return 4.0 if _incoming(ai) or _collision(ai, true) or _hazard_ahead(ai, maxf(5.0, speed * ai.gadget_planning)) else 0.0
		"repair":
			if kart.lost.is_empty():
				return 0.0
			if ai._lost_a_wheel() or kart.stats.steering == null or kart.stats.control <= 0.0 or (kart.stats.power <= 0.0 and kart.stats.thrust <= 0.0):
				return 5.0
			if kart.lost.size() >= 2:
				return 3.0
			for index in kart.lost:
				var part := PartCatalog.get_part(kart.design.parts[index].id)
				if part.get("power", 0.0) > 0.0 or part.get("thrust", 0.0) > 0.0 or part.get("kind", "") == "wing":
					return 3.0
			return 0.0
		"ghost":
			if kart.ghost_left > 0.0 or kart.shield_left > 0.0:
				return 0.0
			if _collision(ai, false) or _hazard_ahead(ai, maxf(5.0, speed * ai.gadget_planning)):
				return 3.0
			return 3.0 if ai._stuck > AIDriver.BACK_AFTER and not ai._waiting and ai._all_grounded() else 0.0
		"tow":
			if kart.tow != null or kart.boost_left > 0.0:
				return 0.0
			var target := TowRope.target(kart)
			if target == null:
				return 1.0 if _boost_safe(ai, speed, Kart.TURBO_TIME) else 0.0
			if not _target(ai, target) or not _grounded(kart) or not _grounded(target):
				return 0.0
			var gap := target.global_position - kart.global_position
			if absf(gap.dot(kart.global_basis.x)) > ai.track.width * 0.3:
				return 0.0
			var pull_speed := maxf(target.linear_velocity.dot(gap.normalized()), 5.0) * TowRope.FASTER
			if kart.linear_velocity.dot(gap.normalized()) >= pull_speed - 1.0:
				return 0.0
			return 1.8 if _road_safe(ai, maxf(speed, pull_speed), TowRope.TIME, 0.02, target) else 0.0
	return 0.0


static func _grounded(kart: Kart) -> bool:
	return not kart.wheels.is_empty() and kart.global_basis.y.y > 0.85 and kart.wheels.all(func(w): return w.grounded)


static func _eligible(ai: AIDriver, other: Kart) -> bool:
	if not is_instance_valid(other) or other == ai.kart or other.ghost_left > 0.0:
		return false
	var up := ai.kart.global_basis.y
	if absf((other.global_position - ai.kart.global_position).dot(up)) > 2.5:
		return false
	return true


static func _target(ai: AIDriver, other: Kart) -> bool:
	return _eligible(ai, other) and _clear(ai.kart, ai.kart.global_position + ai.kart.global_basis.y * 0.7, other.global_position + other.global_basis.y * 0.7, other)


static func _clear(kart: Kart, from: Vector3, to: Vector3, target: PhysicsBody3D = null, mask := Kart.LAYER_WORLD | Kart.LAYER_HAZARD) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.exclude = [kart.get_rid()]
	if is_instance_valid(target):
		query.exclude = [kart.get_rid(), target.get_rid()]
	return kart.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _boost_safe(ai: AIDriver, speed: float, duration: float) -> bool:
	if ai.kart.boost_left > 0.0 or ai.kart.tow != null or speed < 8.0 or not _grounded(ai.kart):
		return false
	return _road_safe(ai, speed * 1.5, duration, 0.008)


static func _road_safe(ai: AIDriver, speed: float, duration: float, bend: float, ignore: Kart = null) -> bool:
	var kart := ai.kart
	var forward := -kart.global_basis.z
	if ai._waiting or ai._backing > 0.0 or ai._leaving > 0.0 or ai.controls.brake > 0.1 or ai.controls.throttle < 0.5:
		return false
	if forward.dot(ai.track.forward_at(ai.offset)) < 0.97 or kart.linear_velocity.dot(forward) < -0.5:
		return false
	var room := ai.track.width * 0.5 - kart.width() * 0.5 - 0.5
	if absf((kart.global_position - ai.track.point_at(ai.offset)).dot(ai.track.right_at(ai.offset))) > room:
		return false
	var reach := maxf(30.0, speed * duration + 15.0)
	var ahead := -4.0
	while ahead <= reach:
		var at := ai.offset + ahead
		if ai.track.bend_at(at) > bend or ai.track.piece_type_at(at) in ["jump", "loop", "corkscrew", "crossing"] or ai.track.up_at(at).dot(kart.global_basis.y) < 0.97:
			return false
		ahead += 4.0
	for other in ai.others:
		if other == ignore or not _target(ai, other):
			continue
		var gap := other.global_position - kart.global_position
		var relative := other.linear_velocity - forward * speed
		var time := clampf(-gap.dot(relative) / maxf(relative.length_squared(), 0.01), 0.0, duration)
		var closest := gap + relative * time
		if gap.dot(forward) > -3.0 and absf(closest.dot(forward)) < 5.0 and absf(closest.dot(kart.global_basis.x)) < (kart.width() + other.width()) * 0.5 + 0.8:
			return false
	var start := kart.global_position + kart.global_basis.y * 0.7
	for side in [-kart.width() * 0.5, 0.0, kart.width() * 0.5]:
		var shift: Vector3 = kart.global_basis.x * side
		if not _clear(kart, start + shift, start + shift + forward * reach):
			return false
	return not _hazard_ahead(ai, reach)


static func _cannon(ai: AIDriver) -> float:
	var kart := ai.kart
	var forward := -kart.global_basis.z
	var muzzle := kart.global_position + forward * 2.0 + kart.global_basis.y * 0.7
	var velocity := kart.linear_velocity + forward * BrickShot.SPEED
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * 0.25
	var best: Kart = null
	var best_time := INF
	for other in ai.others:
		if not _eligible(ai, other):
			continue
		var relative := velocity - other.linear_velocity
		var closing := relative.dot(forward)
		if closing < 2.0:
			continue
		var time := (other.global_position - muzzle).dot(forward) / closing
		if time < 0.04 or time > minf(BrickShot.LIFETIME, ai.gadget_planning) or time >= best_time:
			continue
		var hit := muzzle + relative * time + gravity * time * time * 0.5 - other.global_position
		var local := other.global_basis.inverse() * hit
		var margin := BrickShot.BALL_RADIUS * (1.0 - ai.gadget_confidence)
		if absf(local.x) > other.width() * 0.5 - ai.gadget_confidence * 0.3 + margin:
			continue
		var top := 0.5
		for part in other.stats.parts:
			top = maxf(top, part.centre.y + part.extent.y * 0.5)
		if local.y < 0.1 or local.y > top + margin:
			continue
		best = other
		best_time = time
	if best == null:
		return 0.0
	# Only the nearest plausible intercept needs physics queries. Eight short
	# segments bound the arc's sag to less than 2 cm between samples.
	var previous := muzzle
	var steps := clampi(ceili(best_time / 0.25), 1, 8)
	for step in range(1, steps + 1):
		var t := best_time * step / steps
		var point := muzzle + velocity * t + gravity * t * t * 0.5
		for side in [-BrickShot.BALL_RADIUS, 0.0, BrickShot.BALL_RADIUS]:
			var shift: Vector3 = kart.global_basis.x * side
			if not _clear(kart, previous + shift, point + shift, best):
				return 0.0
		previous = point
	return 2.2


static func _rear(ai: AIDriver, kind: String) -> float:
	var kart := ai.kart
	if not _grounded(kart):
		return 0.0
	var behind := BrickWall.BEHIND
	var half := BrickWall.HALF
	var along := 0.5
	var drift := Vector3.ZERO
	if kind in ["marbles", "spikes"]:
		half = BrickTrap.KINDS[kind].across
		along = BrickTrap.KINDS[kind].along
		behind = kart.rear_bumper_point().z + along + BrickTrap.DROP_GAP
	elif kind == "dropper":
		half = BrickPile.SPREAD * 0.5
		behind = 3.0
		along = 1.0
		drift = kart.linear_velocity * 0.3
	var forward := -kart.global_basis.z
	for other in ai.others:
		if not _target(ai, other) or not _grounded(other) or other.shield_left > 0.0 or forward.dot(-other.global_basis.z) < 0.6:
			continue
		var gap := other.global_position - kart.global_position
		if gap.dot(forward) >= -behind:
			continue
		var relative := other.linear_velocity - drift
		var closing := relative.dot(forward)
		if closing < (10.0 if kind == "spikes" else 3.0):
			continue
		var time := (-behind - along - gap.dot(forward) + other.bumper_point().z) / closing
		if time < 0.0 or time > ai.gadget_planning * 2.0:
			continue
		var crossing := gap + relative * time
		if absf(crossing.dot(kart.global_basis.x)) < half + other.width() * 0.3 - ai.gadget_confidence * 0.3 and absf(crossing.dot(kart.global_basis.y)) < 1.5:
			return 1.8
	return 0.0


## Predicts a collision from relative motion; being alongside alone is safe.
static func _collision(ai: AIDriver, include_rear: bool) -> bool:
	var kart := ai.kart
	for other in ai.others:
		if not _target(ai, other):
			continue
		var gap := other.global_position - kart.global_position
		if not include_rear and gap.dot(-kart.global_basis.z) < 0.0:
			continue
		var relative := other.linear_velocity - kart.linear_velocity
		var time := clampf(-gap.dot(relative) / maxf(relative.length_squared(), 0.01), 0.0, ai.gadget_planning)
		var closest := gap + relative * time
		var side := (kart.width() + other.width()) * 0.5 + 0.3
		if absf(closest.dot(kart.global_basis.x)) < side and absf(closest.dot(kart.global_basis.z)) < 4.5 and (time > 0.05 or gap.length() < 4.0):
			return true
	return false


static func _incoming(ai: AIDriver) -> bool:
	var kart := ai.kart
	for shot in kart.get_tree().get_nodes_in_group("gadget_shots"):
		if not is_instance_valid(shot) or shot.shooter == kart or shot._spent:
			continue
		var gap: Vector3 = shot.global_position - kart.global_position
		if gap.length() > 60.0 or not _clear(kart, kart.global_position + Vector3.UP * 0.7, shot.global_position, shot):
			continue
		if shot.homing and shot.chasing == kart:
			if gap.length() < BrickShot.HOMING_SPEED * ai.gadget_planning:
				return true
		var relative: Vector3 = shot.linear_velocity - kart.linear_velocity
		var time := -gap.dot(relative) / maxf(relative.length_squared(), 0.01)
		if time > 0.0 and time <= ai.gadget_planning and (gap + relative * time).length() < kart.width() * 0.5 + BrickShot.BALL_RADIUS + 0.5:
			return true
	return false


static func _hazard_ahead(ai: AIDriver, reach: float, blast_only := false) -> bool:
	var kart := ai.kart
	var forward := -kart.global_basis.z
	var groups := ["brick_walls", "brick_piles"] if blast_only else ["brick_walls", "brick_piles", "traps"]
	for group in groups:
		for hazard in kart.get_tree().get_nodes_in_group(group):
			if not is_instance_valid(hazard):
				continue
			if hazard is BrickWall and not hazard.standing():
				continue
			var gap: Vector3 = hazard.global_position - kart.global_position
			var ahead := gap.dot(forward)
			if ahead < -1.0 or ahead > reach or absf(gap.dot(kart.global_basis.y)) > 2.0:
				continue
			if blast_only and gap.length() > reach:
				continue
			var half := 0.7
			if hazard is BrickWall:
				half = BrickWall.HALF
			elif hazard is BrickTrap:
				half = BrickTrap.KINDS[hazard.kind].across
			if absf(gap.dot(kart.global_basis.x)) < half + kart.width() * 0.5:
				var body := hazard as PhysicsBody3D
				if _clear(kart, kart.global_position + kart.global_basis.y * 0.7, hazard.global_position + kart.global_basis.y * 0.7, body, Kart.LAYER_WORLD):
					return true
	return false
