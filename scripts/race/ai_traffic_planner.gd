class_name AITrafficPlanner
extends RefCounted

## Tries a few road lines and checks the whole move against moving karts.
## All distances are metres in the road frame, times are seconds.
const SAMPLE := 0.15
const HOLD_FOR := 1.2
const EDGE := 0.65
var target := NAN
var speed_limit := INF
var queueing := false
var contact: Kart
var contact_left := 0.0
var _hold := 0.0
var _cooldown := 0.0
var _contact_gap := INF
var _offsets := {}


func plan(ai: AIDriver, preferred: float, delta: float, wall_line := NAN) -> float:
	var kart := ai.kart
	var track := ai.track
	var right := track.right_at(ai.offset)
	var forward := track.forward_at(ai.offset)
	var here := (kart.global_position - track.point_at(ai.offset)).dot(right)
	var speed := maxf(kart.linear_velocity.dot(forward), 0.0)
	var margin := EDGE + (1.0 - minf(kart.stats.control, 1.0)) * 0.6 + (1.0 - kart.weather_grip) * 0.5
	var edge := maxf(track.width * 0.5 - kart.width() * 0.5 - margin, 0.0)
	preferred = clampf(preferred, -edge, edge)
	if is_finite(wall_line):
		wall_line = clampf(wall_line, -edge, edge)
	_hold = maxf(_hold - delta, 0.0)
	_cooldown = maxf(_cooldown - delta, 0.0)
	var horizon := clampf(ai.traffic_planning, 1.0, 3.0)
	var decel := braking(ai)
	var reach := maxf(speed * horizon + 12.0, speed * speed / (2.0 * decel) + speed * ai.traffic_reaction + 12.0)
	var traffic := _traffic(ai, reach)
	# Contact belongs to one short pass. A spin, injury or loss of progress ends it.
	if is_instance_valid(contact):
		contact_left -= delta
		var found := false
		for body: Dictionary in traffic:
			if body.kart == contact:
				var gap: float = body.ahead
				found = contact_left > 0.0 and gap > -body.back - _front(kart) and gap < _contact_gap + 0.05 and _contact_safe(ai, body, traffic)
				_contact_gap = gap
				break
		if not found:
			_end_contact(ai)
	else:
		contact = null
	var choices: Array[float] = [preferred, clampf(here, -edge, edge)]
	if is_finite(target):
		choices.append(clampf(target, -edge, edge))
	for body: Dictionary in traffic:
		if body.ahead < -body.back - _front(kart) or body.ahead > minf(reach, speed * horizon + 15.0):
			continue
		var need: float = (kart.width() + body.width) * 0.5 + ai.traffic_clearance + 0.25
		choices.append(clampf(body.across - need, -edge, edge))
		choices.append(clampf(body.across + need, -edge, edge))
		# Three lines around the nearest relevant kart are enough on each side.
		if choices.size() >= 9:
			break
	if is_finite(wall_line):
		choices.append(clampf(wall_line, -edge, edge))
	var best := -INF
	var chosen := here
	var chosen_limit := 0.0
	var chosen_contact: Kart
	for across in choices:
		var result := _evaluate(ai, across, here, speed, horizon, decel, traffic, wall_line)
		if not result.safe:
			continue
		# Predicted progress favours an open passing lane. A held line wins small ties.
		var score: float = minf(result.future, speed + 5.0) * horizon - absf(across - here) * 0.65 - absf(across - preferred) * 0.9
		if is_finite(target) and absf(across - target) < 0.2 and _hold > 0.0:
			score += 1.8
		if result.contact != null:
			score -= 0.05
		if score > best:
			best = score
			chosen = across
			chosen_limit = result.limit
			chosen_contact = result.contact
	if not is_finite(target) or absf(chosen - target) > 0.3:
		_hold = HOLD_FOR
	target = clampf(chosen, -edge, edge)
	if chosen_contact != null and contact == null:
		contact = chosen_contact
		contact_left = ai.traffic_contact_time
		for body: Dictionary in traffic:
			if body.kart == contact:
				_contact_gap = body.ahead
	elif contact != null and chosen_contact != contact:
		_end_contact(ai)
	speed_limit = chosen_limit
	# A stopped, aligned queue is waiting. A head-on driver still needs recovery.
	queueing = speed_limit < 1.0 and traffic.any(func(body: Dictionary) -> bool:
		return (ai._tries == 0 or body.kart != ai._recover_from) and body.ahead > 0.0 and body.ahead < _front(kart) + body.back + ai.traffic_clearance + 1.5 and absf(body.across - here) < (kart.width() + body.width) * 0.5 + ai.traffic_clearance and body.speed >= -0.5 and body.speed < 0.6 and body.heading > 0.9)
	return target


static func braking(ai: AIDriver) -> float:
	var kart := ai.kart
	var traction := kart.stats.cornering() * KartStats.gravity() * kart.weather_grip
	for wheel in kart.wheels:
		traction = minf(traction, kart.stats.cornering() * KartStats.gravity() * kart.weather_grip * lerpf(1.0, Kart.HYDRO_GRIP, wheel.planing) * lerpf(1.0, Kart.WATER_GRIP, wheel.water) * lerpf(1.0, Kart.DRIFT_GRIP, wheel.snow))
	return maxf(minf(Kart.BRAKE_FORCE / maxf(kart.mass, 1.0), traction) * (0.65 + 0.2 * minf(kart.stats.control, 1.0)), 0.4)


func _traffic(ai: AIDriver, reach: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var track := ai.track
	if _offsets.size() > ai.others.size() + 4:
		_offsets.clear()
	var origin := track.point_at(ai.offset)
	for other in ai.others:
		if not is_instance_valid(other) or other == ai.kart or other.ghost_left > 0.0:
			continue
		var gap := other.global_position - ai.kart.global_position
		if gap.length() > reach + track.width:
			continue
		var key := other.get_instance_id()
		var at := track.offset_of(other.global_position, _offsets.get(key, -1.0), 20.0)
		if track.point_at(at).distance_to(other.global_position) > track.width + 4.0:
			at = track.offset_of(other.global_position)
		_offsets[key] = at
		var ahead := fposmod(at - ai.offset + track.length * 0.5, track.length) - track.length * 0.5
		if absf(ahead) > reach:
			continue
		var local := other.global_position - track.point_at(at)
		var road_up := track.up_at(at)
		var forward := track.forward_at(at)
		# Nearby hairpins and bridges are different pieces of road. Check both
		# their projection and the actual world separation before predicting.
		if absf(local.dot(road_up) - (ai.kart.global_position - origin).dot(track.up_at(ai.offset))) > 1.8 or forward.dot(track.forward_at(ai.offset)) < 0.65:
			continue
		if absf(gap.dot(track.forward_at(ai.offset)) - ahead) > maxf(6.0, absf(ahead) * 0.25):
			continue
		if gap.length() + 3.0 < absf(ahead) * 0.7:
			continue
		out.append({"kart": other, "ahead": ahead, "across": local.dot(track.right_at(at)), "speed": other.linear_velocity.dot(forward), "side": other.linear_velocity.dot(track.right_at(at)), "width": other.width(), "front": _front(other), "back": other.tail_length(), "heading": (-other.global_basis.z).dot(forward)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a.ahead) < absf(b.ahead))
	return out


func _evaluate(ai: AIDriver, across: float, here: float, speed: float, horizon: float, decel: float, traffic: Array[Dictionary], wall_line: float) -> Dictionary:
	var kart := ai.kart
	var own_front := _front(kart)
	var own_back := kart.tail_length()
	var limit := INF
	var future := INF
	var touching: Kart
	var reaction := ai.traffic_reaction + (1.0 - minf(kart.stats.control, 1.0)) * 0.3
	var side_speed := kart.linear_velocity.dot(ai.track.right_at(ai.offset))
	var rate := clampf(speed * 0.14, 1.0, 3.2) * minf(kart.stats.control, 1.0) * sqrt(kart.weather_grip)
	for body: Dictionary in traffic:
		var half: float = (kart.width() + body.width) * 0.5
		var clearance := ai.traffic_clearance + maxf(1.0 - kart.stats.control, 0.0) * 0.4 + (1.0 - kart.weather_grip) * 0.4
		# Recovery may pull past the kart it collided with, provided the
		# destination clears its footprint. Every other body is checked.
		if ai._tries > 0 and ai._stuck > 0.0 and body.kart == ai._recover_from and absf(across - body.across) > half + clearance and absf(across - body.across) >= absf(here - body.across) and (across - body.across) * (here - body.across) >= 0.0:
			continue
		var contact_ok: bool = absf(across - here) < 0.15 and absf(across - body.across) < half + 0.1 and (body.kart == contact or (_cooldown <= 0.0 and contact == null)) and _contact_safe(ai, body, traffic)
		var path_conflict := false
		var rear_conflict := false
		var t := 0.0
		while t <= horizon + 0.01:
			# Include the current lateral motion while the driver reacts, then
			# sweep towards the new line instead of checking only its endpoint.
			var lateral := here + side_speed * minf(t, reaction)
			lateral = move_toward(lateral, across, rate * maxf(t - reaction, 0.0))
			var other_side: float = body.across + body.side * t
			var longitudinal: float = body.ahead + (body.speed - speed) * t
			var front_gap: float = own_front + body.back + clearance
			var rear_gap: float = own_back + body.front + clearance
			if absf(lateral - other_side) < half + clearance and longitudinal < front_gap and longitudinal > -rear_gap:
				path_conflict = true
				if body.ahead <= 0.0 or body.speed > speed + 1.0:
					rear_conflict = true
			t += SAMPLE
		if contact_ok:
			touching = body.kart
			continue
		if path_conflict and absf(body.ahead) < own_front + body.back + clearance and absf(across - here) > 0.25:
			if absf(across - body.across) < absf(here - body.across) or (across - body.across) * (here - body.across) < 0.0:
				return {"safe": false}
		if rear_conflict:
			# Holding an existing lane is safer than swerving across a faster
			# kart. Existing overlap is handled by slowing and recovery.
			if absf(across - here) > 0.25:
				return {"safe": false}
		if body.ahead > 0.0 and (path_conflict or absf(here - body.across) < half + clearance):
			var room: float = maxf(body.ahead - own_front - body.back - clearance - maxf(speed - body.speed, 0.0) * reaction, 0.0)
			var following := sqrt(maxf(body.speed, 0.0) ** 2 + 2.0 * decel * room)
			limit = minf(limit, following)
			# At walking speed stop at a following gap instead of creeping into
			# an immobile queue, then accidentally using brake to reverse.
			if body.speed >= -0.5 and body.heading > 0.0 and body.speed < 0.6 and room < 0.8:
				limit = 0.0
		if body.ahead >= -own_back - body.front and absf(across - (body.across + body.side * horizon)) < half + clearance:
			future = minf(future, maxf(body.speed, 0.0))
	# The wall's chosen end remains a preference, but traffic still checks
	# the move. Waiting in front of the wall is allowed when that end is busy.
	if is_finite(wall_line) and absf(across - wall_line) > 0.3:
		future = 0.0
		for wall in AIDriver._walls:
			if not is_instance_valid(wall) or not wall.standing():
				continue
			var gap: Vector3 = wall.global_position - kart.global_position
			var ahead := gap.dot(ai.track.forward_at(ai.offset))
			if ahead > 0.0 and ahead < AIDriver.SEE_WALL:
				limit = minf(limit, sqrt(2.0 * decel * maxf(ahead - own_front - 2.0 - speed * reaction, 0.0)))
	return {"safe": true, "limit": limit, "future": future, "contact": touching}


func _contact_safe(ai: AIDriver, body: Dictionary, traffic: Array[Dictionary]) -> bool:
	if ai.traffic_mass_ratio <= 0.0 or ai._backing > 0.0 or ai._leaving > 0.0 or ai._stuck > 0.0:
		return false
	var kart := ai.kart
	var other: Kart = body.kart
	var track := ai.track
	var speed := kart.linear_velocity.dot(track.forward_at(ai.offset))
	var closing: float = speed - body.speed
	var half: float = (kart.width() + body.width) * 0.5
	var here := (kart.global_position - track.point_at(ai.offset)).dot(track.right_at(ai.offset))
	if kart.mass < other.mass * ai.traffic_mass_ratio or body.speed < 2.0 or closing < 0.3 or closing > ai.traffic_contact_closing:
		return false
	# Only hold an already contested lane while going past. Never aim a
	# nose at a rear bumper or move into somebody to start contact.
	if absf(here - body.across) < half - 0.18 or absf(here - body.across) > half + 0.25 or absf(body.ahead) > 1.5:
		return false
	if (body.ahead + body.front + kart.tail_length() + 0.5) / closing > minf(3.0, ai.traffic_planning + ai.traffic_contact_time):
		return false
	var way: float = signf(body.across - here)
	if not _armoured(kart, way) or not _armoured(other, -way):
		return false
	if not _stable(kart, track.forward_at(ai.offset), ai.traffic_contact_side) or not _stable(other, track.forward_at(ai.offset), ai.traffic_contact_side):
		return false
	if ai._loop_within(AIDriver.LOOP_RUN_IN) or ai._jump_within(AIDriver.JUMP_RUN_IN):
		return false
	var reach := speed * ai.traffic_planning + LevelCrossing.STOP_BACK
	for crossing in ai.crossings:
		var ahead := -ai._along(crossing.offset)
		if ahead > -LevelCrossing.BARRIER_AT - kart.tail_length() and ahead < reach:
			return false
	for wall in AIDriver._walls:
		if not is_instance_valid(wall) or not wall.standing():
			continue
		var gap: Vector3 = wall.global_position - kart.global_position
		var ahead := gap.dot(track.forward_at(ai.offset))
		if ahead > -kart.tail_length() - BrickWall.BEHIND and ahead < reach and absf(gap.dot(track.right_at(ai.offset))) < track.width * 0.5 + BrickWall.HALF and absf(gap.dot(track.up_at(ai.offset))) < 2.0:
			return false
	for ahead in [0.0, 8.0, speed * ai.traffic_planning]:
		var at: float = ai.offset + ahead
		if track.piece_type_at(at) not in ["straight", "half_straight"] or track.bend_at(at) > 0.01 or track.up_at(at).y < 0.98:
			return false
	# Both footprints need room for the lighter kart's lateral displacement.
	if maxf(absf(here) + kart.width() * 0.5, absf(body.across) + body.width * 0.5) + 1.5 > track.width * 0.5:
		return false
	for third: Dictionary in traffic:
		if third.kart != other and absf(third.ahead) < maxf(12.0, absf(third.speed - speed) * ai.traffic_planning + 5.0):
			return false
	return true


static func _stable(kart: Kart, forward: Vector3, side: float) -> bool:
	if kart.ghost_left > 0.0 or kart.sliding or kart.slowdown_left > 0.0 or kart.zapped_left > 0.0 or not kart.lost.is_empty() or kart.global_basis.y.y < 0.96 or kart.weather_grip < 0.95 or kart.angular_velocity.length() > 0.25:
		return false
	if (-kart.global_basis.z).dot(forward) < 0.985 or absf(kart.linear_velocity.dot(kart.global_basis.x)) > side:
		return false
	for wheel in kart.wheels:
		if not wheel.grounded or wheel.water > 0.05 or wheel.snow > 0.05 or wheel.planing > 0.05 or wheel.offroad:
			return false
	return not kart.wheels.is_empty()


func _end_contact(ai: AIDriver) -> void:
	contact = null
	contact_left = 0.0
	_cooldown = ai.traffic_contact_cooldown


static func _front(kart: Kart) -> float:
	return maxf(-kart.bumper_point().z, 0.5)


static func _armoured(kart: Kart, side: float) -> bool:
	if kart.shield_left > 0.6:
		return true
	var wheel_edge := 0.0
	var body_edge := 0.0
	for wheel in kart.wheels:
		wheel_edge = maxf(wheel_edge, wheel.rest.x * side + wheel.radius * Kart.WHEEL_BODY)
	for part in kart.stats.parts:
		if part.def.kind != "wheel" and absf(part.centre.z) < part.extent.z * 0.5 + 0.75:
			body_edge = maxf(body_edge, part.centre.x * side + part.extent.x * 0.5)
	# Exposed wheel spheres catch before the body can rub past. A solid side
	# or an active shield has to protect them for deliberate contact.
	return body_edge >= wheel_edge + 0.02
