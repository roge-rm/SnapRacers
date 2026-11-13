class_name AITrafficPlanner
extends RefCounted

## Tries a few road lines and checks the whole move against moving karts.
## All distances are metres in the road frame, times are seconds. Across the
## road they're measured from the driver's own line (see AIDriver.line_at()),
## so karts on the line through a bend count as in the same lane.
const SAMPLE := 0.15
const HOLD_FOR := 1.2
const EDGE := 0.65
## Racecraft, scaled by AIDriver.racecraft. A bend this close, in seconds
## at its speed plus BEND_SEE metres, decides the passing side: the inside
## wins, and the outside only goes with OUTSIDE_SPEED m/s more than the kart
## it's passing. Up to SLIP_GAP metres behind a kart on a straight with more
## than SLIP_LEFT seconds to go, it tucks in to slipstream.
const BEND_SEE := 30.0
const BEND_TIME := 3.0
const OUTSIDE_SPEED := 4.0
const SLIP_GAP := 16.0
const SLIP_LEFT := 2.5
## A pass that gains nothing for this long, plus up to BEATEN_MORE seconds
## more the better its racecraft, or that drops back BEATEN_BACK metres from
## the closest it got, is beaten, and it tucks back in behind. Alongside it
## never gives up for lack of gain.
const BEATEN_AFTER := 1.5
const BEATEN_MORE := 1.5
const BEATEN_BACK := 4.0
## It commits to a pass on a side once its nose is this many metres from
## the kart's tail. Further back it's only setting the pass up.
const COMMIT_GAP := 3.0
## Closing on it this many m/s or more is reason enough to commit anywhere.
const CLOSING := 0.5
## Or able to go this many m/s quicker than it with the road clear.
const QUICKER := 1.5
## A committed rival that drops out of sight (round a tight bend, say) is
## still the rival for this long, in seconds.
const MISSING_FOR := 0.6
## How long it trusts another kart's sideways drift to carry on, in seconds.
const SIDE_SEE := 0.8
## A kart below OBSTACLE_SPEED m/s or OBSTACLE_SHARE of its own speed, or
## facing more than 60 degrees off the road, is driven round, not followed.
const OBSTACLE_SPEED := 5.0
const OBSTACLE_SHARE := 0.45
const OBSTACLE_HEADING := 0.5
## Alongside on the inside into a bend, a driver with this much racecraft
## or more counts on up to LATE_INSIDE more braking for it, more for
## aggressive ones.
const LATE_RACECRAFT := 0.6
const LATE_INSIDE := 0.12
## After getting past on the inside it keeps that side for this long, times
## its racecraft, so the kart it passed can't cut back underneath.
const COVER_FOR := 1.6
## Waiting to pass, it sits this share of the two karts' widths to the side
## it plans to pass on, to look past and be ready to go.
const PEEK := 0.35
## Defending, it moves this far toward the inside, for a kart this close
## behind and a bend coming up within DEFEND_TIME seconds.
const DEFEND_MOVE := 2.5
const DEFEND_BEHIND := 10.0
const DEFEND_TIME := 2.5
## Following, it keeps this many seconds more gap at the speed it's going,
## and this much more after a knock while it's shaken (see AIDriver.shaken).
const FOLLOW_TIME := 0.08
const SHAKEN_TIME := 0.25
const SHAKEN_ROOM := 0.5
## What a line over a trap costs in score, more than lines ever differ by.
const TRAP_COST := 200.0
var target := NAN
var speed_limit := INF
var queueing := false
var contact: Kart
var contact_left := 0.0
var _hold := 0.0
var _cooldown := 0.0
var _contact_gap := INF
var _offsets := {}
## The kart it's following or passing, how long it's been behind it, the
## side it's committed to passing on (1 right, -1 left, 0 none), how long
## until it tries again after a beaten pass, and its closest gap so far.
var _rival: Kart
var _behind_for := 0.0
var pass_side := 0
var _retry := 0.0
var _best_gap := INF
var _stall := 0.0
## The next bend: how far ahead it starts and which way it turns, 1 right.
var _bend := Vector2(INF, 0.0)
## The bend it's defended (where it starts along the track), the line it
## took and how many times it's defended, for the tests.
var _defended := NAN
var _defend_line := NAN
var _defending := false
var defends := 0
## Passes it's started, made (got past its rival), beaten (gave up) and
## lost (the rival got away), and of the started ones how many went for
## the inside of the next bend and how many pulled out of a slipstream,
## for the tests and tools/stock-karts/ai_laps.gd.
var attempts := 0
var made := 0
var beaten := 0
var lost := 0
var inside_moves := 0
var slip_pulls := 0
var fakes := 0
var _rival_ahead := INF
var _was_slipping := false
## How long its committed rival has been out of sight, whether it's already
## dummied one way this pass, the side it plans to pass on before it
## commits (1 right, -1 left), and how much more braking it counts on into
## the next bend (see AIDriver._drive()).
var _missing := 0.0
var _counting := false
var _faked := false
var plan_side := 0
var brake_bonus := 1.0
## After a pass on the inside: how long it keeps covering and the line it holds.
var _cover_left := 0.0
var _cover_line := NAN


func plan(ai: AIDriver, preferred: float, delta: float, wall_line := NAN) -> float:
	var kart := ai.kart
	var track := ai.track
	var right := track.right_at(ai.offset)
	var forward := track.forward_at(ai.offset)
	var here := (kart.global_position - track.point_at(ai.offset)).dot(right) - ai.line_at(ai.offset)
	var speed := maxf(kart.linear_velocity.dot(forward), 0.0)
	var margin := EDGE + (1.0 - minf(kart.stats.control, 1.0)) * 0.6 + (1.0 - kart.weather_grip) * 0.5
	# The road's edges from its line where it's aiming, or on a split its
	# own branch's.
	var mine := ai.line_at(ai._aim_or_here())
	var lane := ai.lane_at(ai._aim_or_here(), kart.width() * 0.5 + margin)
	var low := minf(lane.x - mine, 0.0)
	var high := maxf(lane.y - mine, 0.0)
	preferred = clampf(preferred, low, high)
	if is_finite(wall_line):
		wall_line = clampf(wall_line, low, high)
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
	_bend = _next_bend(ai, speed)
	var rival := _find_rival(ai, traffic, here, speed, horizon)
	_follow(ai, rival, delta, here)
	# Running in to a jump or a loop it keeps to its line, so no racecraft.
	var plain := ai._jump_run_in or ai._loop_within(AIDriver.LOOP_AHEAD)
	_cover_left = maxf(_cover_left - delta, 0.0)
	if plain:
		rival = {}
		_defending = false
		_cover_left = 0.0
	else:
		preferred = _defend(ai, traffic, preferred, here, speed, low, high)
		# Just past on the inside, it holds that side to shut the door.
		if _cover_left > 0.0 and not _defending:
			preferred = clampf(_cover_line, low, high)
	if not rival.is_empty() and pass_side == 0:
		plan_side = _plan_side(ai, rival)
	elif rival.is_empty():
		plan_side = 0
	if not rival.is_empty() and pass_side != 0:
		_dummy(ai, rival)
		_to_inside(ai, rival, speed)
		# The kart ahead has shut the side it was going for against the edge
		# before it got alongside: it goes for the other side.
		var need: float = (kart.width() + rival.width) * 0.5 + ai.traffic_clearance + 0.25
		var spot: float = rival.across + pass_side * need
		var other: float = rival.across - pass_side * need
		if rival.ahead > _front(kart) + rival.back and (spot < low - 0.3 or spot > high + 0.3) and other > low - 0.3 and other < high + 0.3:
			pass_side = -pass_side
			_stall = 0.0
	var choices: Array[float] = [preferred, clampf(here, low, high)]
	if is_finite(target):
		choices.append(clampf(target, low, high))
	for body: Dictionary in traffic:
		if body.ahead < -body.back - _front(kart) or body.ahead > minf(reach, speed * horizon + 15.0):
			continue
		var need: float = (kart.width() + body.width) * 0.5 + ai.traffic_clearance + 0.25
		choices.append(clampf(body.across - need, low, high))
		choices.append(clampf(body.across + need, low, high))
		# Three lines around the nearest relevant kart are enough on each side.
		if choices.size() >= 9:
			break
	if is_finite(wall_line):
		choices.append(clampf(wall_line, low, high))
	# Just either side of a trap ahead (see AIDriver._dodge_traps()).
	var band := ai.trap_band
	if is_finite(band.x):
		choices.append(clampf(band.x, low, high))
		choices.append(clampf(band.y, low, high))
	# Right behind it to slipstream, or a little to the side it plans to
	# pass on, to look past and be ready to go.
	if not rival.is_empty():
		var peek: float = (kart.width() + rival.width) * PEEK
		choices.append(clampf(rival.across, low, high))
		choices.append(clampf(rival.across - peek, low, high))
		choices.append(clampf(rival.across + peek, low, high))
	var holding := _holding_back(ai, rival, speed)
	var best := -INF
	var chosen := here
	var chosen_limit := 0.0
	var chosen_contact: Kart
	for across in choices:
		var result := _evaluate(ai, across, here, speed, horizon, decel, traffic, wall_line)
		if not result.safe:
			continue
		# Predicted progress favours an open passing lane. A held line wins small ties.
		var score: float = minf(result.future, speed + 5.0) * horizon - absf(across - here) * 0.65 * ai.traffic_move_cost - absf(across - preferred) * 0.9
		if is_finite(target) and absf(across - target) < 0.2 and _hold > 0.0:
			score += 1.8
		if result.contact != null:
			score -= 0.05
		if not rival.is_empty():
			score += _racecraft(ai, across, rival, speed, horizon, holding)
		# Over a trap it pops a tire or slides, worse than any wait.
		if is_finite(band.x) and across > band.x + 0.05 and across < band.y - 0.05:
			score -= TRAP_COST
		if score > best:
			best = score
			chosen = across
			chosen_limit = result.limit
			chosen_contact = result.contact
	# Off past the edge of where it may aim, among karts, every way back in
	# can cross one. It heads back in anyway at following speed, rather than
	# stopping dead in their way.
	if best == -INF:
		chosen = clampf(here, low, high)
		chosen_limit = _evaluate(ai, chosen, here, speed, horizon, decel, traffic, wall_line, true).limit
	if not is_finite(target) or absf(chosen - target) > 0.3:
		_hold = HOLD_FOR * ai.traffic_hold
	target = clampf(chosen, low, high)
	if chosen_contact != null and contact == null:
		contact = chosen_contact
		contact_left = ai.traffic_contact_time
		for body: Dictionary in traffic:
			if body.kart == contact:
				_contact_gap = body.ahead
	elif contact != null and chosen_contact != contact:
		_end_contact(ai)
	speed_limit = chosen_limit
	# Once it's started a pass on one side, close enough to make it, it
	# sticks to it. Going round a slow or spun kart isn't counted as a pass.
	if not rival.is_empty() and pass_side == 0 and rival.ahead < _front(kart) + rival.back + COMMIT_GAP and _worth_going(ai, rival, chosen, speed):
		pass_side = _side_of(ai, chosen, rival)
		_best_gap = rival.ahead
		_stall = 0.0
		_faked = false
		_counting = pass_side != 0 and not rival.slow
		if _counting:
			attempts += 1
			if _bend.x < speed * BEND_TIME + BEND_SEE and pass_side == int(_bend.y):
				inside_moves += 1
			if _was_slipping:
				slip_pulls += 1
	_was_slipping = not rival.is_empty() and pass_side == 0 and _slipstreaming(ai, rival, speed)
	brake_bonus = _late_inside(ai, rival, speed)
	# A stopped, aligned queue is waiting. A head-on driver still needs recovery.
	queueing = speed_limit < 1.0 and traffic.any(func(body: Dictionary) -> bool:
		return (ai._tries == 0 or body.kart != ai._recover_from) and body.ahead > 0.0 and body.ahead < _front(kart) + body.back + ai.traffic_clearance + 1.5 and absf(body.across - here) < (kart.width() + body.width) * 0.5 + ai.traffic_clearance and body.speed >= -0.5 and body.speed < 0.6 and body.heading > 0.9)
	return target


## How quickly the driver's own line moves right, in metres across for each
## metre along.
static func line_slope(ai: AIDriver, at: float) -> float:
	return (ai.line_at(at + 2.0) - ai.line_at(at - 2.0)) * 0.25


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
		var line := ai.line_at(at)
		# Nearby hairpins and bridges are different pieces of road. Check both
		# their projection and the actual world separation before predicting.
		if absf(local.dot(road_up) - (ai.kart.global_position - origin).dot(track.up_at(ai.offset))) > 1.8 or forward.dot(track.forward_at(ai.offset)) < 0.65:
			continue
		if absf(gap.dot(track.forward_at(ai.offset)) - ahead) > maxf(6.0, absf(ahead) * 0.25):
			continue
		if gap.length() + 3.0 < absf(ahead) * 0.7:
			continue
		# "road" is across from the middle of the road, the rest from its line.
		var road := local.dot(track.right_at(at))
		var along := other.linear_velocity.dot(forward)
		# A kart turned across the road takes up its length across it, so its
		# size is measured along the road and across it, whichever way it faces.
		var heading := (-other.global_basis.z).dot(forward)
		var square := absf(other.global_basis.x.dot(forward))
		var half_wide := other.width() * 0.5
		var nose := _front(other)
		var tail := other.tail_length()
		var wide := 2.0 * (absf(other.global_basis.x.dot(track.right_at(at))) * half_wide + absf(other.global_basis.z.dot(track.right_at(at))) * (nose + tail) * 0.5)
		var front := absf(heading) * (nose if heading >= 0.0 else tail) + square * half_wide
		var back := absf(heading) * (tail if heading >= 0.0 else nose) + square * half_wide
		out.append({"kart": other, "ahead": ahead, "across": road - line, "road": road, "speed": along, "side": other.linear_velocity.dot(track.right_at(at)) - along * line_slope(ai, at), "width": maxf(wide, other.width()), "front": front, "back": back, "heading": heading, "slow": _obstacle(along, heading, ai.kart.linear_velocity.length())})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a.ahead) < absf(b.ahead))
	return out


## With `anyway` it judges the line even when the move isn't safe.
func _evaluate(ai: AIDriver, across: float, here: float, speed: float, horizon: float, decel: float, traffic: Array[Dictionary], wall_line: float, anyway := false) -> Dictionary:
	var kart := ai.kart
	var own_front := _front(kart)
	var own_back := kart.tail_length()
	var limit := INF
	var future := INF
	var touching: Kart
	var reaction := ai.traffic_reaction + (1.0 - minf(kart.stats.control, 1.0)) * 0.3
	var side_speed := kart.linear_velocity.dot(ai.track.right_at(ai.offset)) - speed * line_slope(ai, ai.offset)
	var rate := clampf(speed * 0.14, 1.0, 3.2) * minf(kart.stats.control, 1.0) * sqrt(kart.weather_grip)
	for body: Dictionary in traffic:
		var half: float = (kart.width() + body.width) * 0.5
		var clearance := ai.traffic_clearance + maxf(1.0 - kart.stats.control, 0.0) * 0.4 + (1.0 - kart.weather_grip) * 0.4 + (SHAKEN_ROOM if ai.shaken > 0.0 else 0.0)
		# Recovery may pull past the kart it collided with, provided the
		# destination clears its footprint. Every other body is checked.
		if ai._tries > 0 and ai._stuck > 0.0 and body.kart == ai._recover_from and absf(across - body.across) > half + clearance and absf(across - body.across) >= absf(here - body.across) and (across - body.across) * (here - body.across) >= 0.0:
			continue
		var contact_ok: bool = absf(across - here) < 0.15 and absf(across - body.across) < half + 0.1 and (body.kart == contact or (_cooldown <= 0.0 and contact == null)) and _contact_safe(ai, body, traffic)
		var path_conflict := false
		var rear_conflict := false
		# The last time in the sweep it's still in line with the kart, at
		# whatever gap, so how long until it's moved clear of it.
		var in_line := -1.0
		var t := 0.0
		while t <= horizon + 0.01:
			# Include the current lateral motion while the driver reacts, then
			# sweep towards the new line instead of checking only its endpoint.
			var lateral := here + side_speed * minf(t, reaction)
			lateral = move_toward(lateral, across, rate * maxf(t - reaction, 0.0))
			var other_side: float = body.across + body.side * minf(t, SIDE_SEE)
			var longitudinal: float = body.ahead + (body.speed - speed) * t
			var front_gap: float = own_front + body.back + clearance
			var rear_gap: float = own_back + body.front + clearance
			if absf(lateral - other_side) < half + clearance:
				in_line = t
			if absf(lateral - other_side) < half + clearance and longitudinal < front_gap and longitudinal > -rear_gap:
				path_conflict = true
				if body.ahead <= 0.0 or body.speed > speed + 1.0:
					rear_conflict = true
			t += SAMPLE
		if contact_ok:
			touching = body.kart
			continue
		if path_conflict and absf(body.ahead) < own_front + body.back + clearance and absf(across - here) > 0.25:
			if not anyway and (absf(across - body.across) < absf(here - body.across) or (across - body.across) * (here - body.across) < 0.0):
				return {"safe": false}
		if rear_conflict:
			# Holding an existing lane is safer than swerving across a faster
			# kart. Existing overlap is handled by slowing and recovery.
			if absf(across - here) > 0.25 and not anyway:
				return {"safe": false}
		# Only the line it's judging counts: one that stays in line with the
		# kart follows it, and one moving out from behind it only has to be
		# slow enough to clear it before it gets there.
		var stays := in_line >= horizon - SAMPLE
		if body.ahead > 0.0 and (path_conflict or stays):
			var room: float = maxf(body.ahead - own_front - body.back - clearance - maxf(speed - body.speed, 0.0) * reaction - speed * (FOLLOW_TIME + (SHAKEN_TIME if ai.shaken > 0.0 else 0.0)), 0.0)
			var following := sqrt(maxf(body.speed, 0.0) ** 2 + 2.0 * decel * room)
			if not stays:
				following = maxf(following, maxf(body.speed, 0.0) + room / maxf(in_line, SAMPLE))
			limit = minf(limit, following)
			# At walking speed stop at a following gap instead of creeping into
			# an immobile queue, then accidentally using brake to reverse.
			if body.speed >= -0.5 and body.heading > 0.0 and body.speed < 0.6 and room < 0.8:
				limit = 0.0
		if body.ahead >= -own_back - body.front and absf(across - (body.across + body.side * minf(horizon, SIDE_SEE))) < half + clearance:
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
	var road := (kart.global_position - track.point_at(ai.offset)).dot(track.right_at(ai.offset))
	var here := road - ai.line_at(ai.offset)
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
		if track.piece_type_at(at) not in ["straight", "half_straight", "quarter_straight", "adjustable_straight"] or track.bend_at(at) > 0.01 or track.up_at(at).y < 0.98:
			return false
	# Both footprints need room for the lighter kart's lateral displacement.
	if maxf(absf(road) + kart.width() * 0.5, absf(body.road) + body.width * 0.5) + 1.5 > track.width * 0.5:
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


## Whether a kart going `along` m/s down the road and facing `heading` (1
## straight down it) is something to drive round rather than follow: stopped,
## spun, sideways, facing the wrong way or going far slower than `speed`.
static func _obstacle(along: float, heading: float, speed: float) -> bool:
	return heading < OBSTACLE_HEADING or along < maxf(OBSTACLE_SPEED, speed * OBSTACLE_SHARE)


## Which side of the kart it's following this line passes it on, 1 right,
## -1 left, or 0 for a line that stays behind it.
static func _side_of(ai: AIDriver, across: float, rival: Dictionary) -> int:
	var need: float = (ai.kart.width() + rival.width) * 0.5
	if absf(across - rival.across) < need * 0.9:
		return 0
	return 1 if across > rival.across else -1


## How far ahead the next bend starts and which way it goes, 1 right and
## -1 left, as Vector2(distance, way), or INF when there's none soon.
func _next_bend(ai: AIDriver, speed: float) -> Vector2:
	var track := ai.track
	var reach := minf(speed * BEND_TIME + BEND_SEE, 150.0)
	var ahead := 0.0
	while ahead <= reach:
		if track.bend_at(ai.offset + ahead) > 0.02 and not TrackPiece.turns_over(track.piece_type_at(ai.offset + ahead)):
			return Vector2(ahead, ai._turn_way(ai.offset + ahead + 6.0))
		ahead += 5.0
	return Vector2(INF, 0.0)


## The kart close ahead in its way that it's following or passing, or {}.
## One it's passing stays its rival until it's fully past.
func _find_rival(ai: AIDriver, traffic: Array[Dictionary], here: float, speed: float, horizon: float) -> Dictionary:
	var kart := ai.kart
	var nearest := {}
	for body: Dictionary in traffic:
		if body.kart == _rival and pass_side != 0 and body.ahead > -kart.tail_length() - body.front - 0.5:
			return body
		if body.ahead <= 0.0 or body.ahead > speed * horizon + 15.0 or body.heading < 0.7:
			continue
		var half: float = (kart.width() + body.width) * 0.5
		if absf(body.across - here) > half + ai.traffic_clearance + 1.0:
			continue
		if nearest.is_empty() or body.ahead < nearest.ahead:
			nearest = body
	return nearest


## Keeps up how long it's followed its rival and whether a pass is made or
## beaten. `here` is where it is across from its line.
func _follow(ai: AIDriver, rival: Dictionary, delta: float, here: float) -> void:
	_retry = maxf(_retry - delta, 0.0)
	# Mid pass, a rival out of sight for a moment is still there.
	if rival.is_empty() and pass_side != 0 and is_instance_valid(_rival) and _missing < MISSING_FOR:
		_missing += delta
		return
	_missing = 0.0
	if pass_side != 0 and (rival.is_empty() or rival.kart != _rival):
		if _rival_ahead < 0.0:
			if _counting:
				made += 1
			# Got by on the inside: a good or aggressive driver shuts the door.
			if pass_side == int(_bend.y) and (ai.racecraft >= 0.8 or (ai.racecraft >= 0.5 and ai.traits.aggression > 0.3)):
				_cover_left = COVER_FOR * ai.racecraft
				_cover_line = here
		elif _counting:
			lost += 1
	_rival_ahead = rival.ahead if not rival.is_empty() else INF
	if rival.is_empty():
		_rival = null
		pass_side = 0
		_behind_for = 0.0
		return
	if rival.kart != _rival:
		_rival = rival.kart
		_behind_for = 0.0
		pass_side = 0
	_behind_for += delta
	if pass_side != 0:
		var alongside: bool = rival.ahead < _front(ai.kart) + rival.back
		if rival.ahead < _best_gap - 0.3:
			_best_gap = rival.ahead
			_stall = 0.0
		elif not alongside and (_bend.x > ai.kart.linear_velocity.length() * BEND_TIME + BEND_SEE or ai.track.bend_at(ai.offset) > 0.02):
			# Short of the braking zone it's going for it keeps at it, as
			# that's where the pass is made.
			_stall += delta
		if _stall > BEATEN_AFTER + BEATEN_MORE * ai.racecraft or rival.ahead > _best_gap + BEATEN_BACK:
			if _counting and rival.ahead > _best_gap + BEATEN_BACK:
				lost += 1
			elif _counting:
				beaten += 1
			pass_side = 0
			_retry = ai.pass_wait * 0.6
			_behind_for = 0.0


## Whether it waits behind its rival for now instead of pulling out: it
## isn't much quicker and it's not followed it long enough yet, or it's
## tucked in on a straight to slipstream until near the end of it. Not
## once a pass has started, nor with a grudge against that kart.
func _holding_back(ai: AIDriver, rival: Dictionary, speed: float) -> bool:
	if rival.is_empty() or pass_side != 0 or rival.slow or (ai.grudge == rival.kart and ai.grudge_left > 0.0):
		return false
	if _quicker(ai, rival, speed) < 3.0 and (_behind_for < ai.pass_wait or _retry > 0.0):
		return true
	return _slipstreaming(ai, rival, speed)


## How much quicker it is than its rival, in m/s: going now, or could go
## with the road clear, whichever is more.
static func _quicker(ai: AIDriver, rival: Dictionary, speed: float) -> float:
	var kart := ai.kart
	var could := minf(ai.free_speed, kart.stats.top_speed() * pow(maxf(kart.push, 0.0), 0.4))
	return maxf(speed, could) - rival.speed


func _slipstreaming(ai: AIDriver, rival: Dictionary, speed: float) -> bool:
	return ai.racecraft >= 0.4 and rival.ahead < SLIP_GAP and _quicker(ai, rival, speed) < 3.0 and _bend.x > speed * SLIP_LEFT + 25.0 and ai.track.bend_at(ai.offset) < AIDriver.STRAIGHT_BEND


## What racecraft adds to a line's score with a rival ahead.
func _racecraft(ai: AIDriver, across: float, rival: Dictionary, speed: float, horizon: float, holding: bool) -> float:
	var way := _side_of(ai, across, rival)
	var gain: float = maxf(speed + 5.0 - maxf(rival.speed, 0.0), 0.0) * horizon
	# A slow or spun kart: any side with room, held once picked.
	if rival.slow:
		if way == 0:
			return -1.0
		return -4.0 if pass_side != 0 and way != pass_side else 0.5
	if way == 0:
		var add := 0.0
		if holding and absf(across - rival.across) < 0.2 and _slipstreaming(ai, rival, speed):
			add += ai.racecraft
		# Waiting, it sits a little to the side it plans to pass on, to look
		# past and be ready to go.
		elif plan_side != 0 and signf(across - rival.across) == plan_side and absf(across - rival.across) > 0.2:
			add += (0.6 if holding else 0.3) * maxf(ai.racecraft, 0.3)
		return add
	if holding:
		return -gain - 1.0
	# No flicking from one side to the other mid pass.
	if pass_side != 0 and way != pass_side:
		return -gain - 4.0
	var score := 1.0 if way == pass_side else 0.0
	if pass_side == 0 and way == plan_side:
		score += ai.racecraft
	var see := speed * BEND_TIME + BEND_SEE
	if _bend.x < see:
		var near := 1.0 - _bend.x / see
		if way == int(_bend.y):
			score += 2.0 * ai.racecraft * near
		elif not _faked and speed - rival.speed < OUTSIDE_SPEED * (1.0 - 0.3 * ai.traits.aggression):
			score -= (gain + 2.0) * ai.racecraft * near
	return score


## Where it plans to pass the kart ahead, 1 right or -1 left, set up a bend
## early: on the inside into the next bend's braking zone (from the end of a
## straight it drafts there first, see _slipstreaming()), underneath out of
## the bend it's in, where its exit is better, or else on whichever side of
## the road has more room beside that kart.
func _plan_side(ai: AIDriver, rival: Dictionary) -> int:
	if _bend.y != 0.0:
		return int(_bend.y)
	if ai.track.bend_at(ai.offset) > 0.02 and not TrackPiece.turns_over(ai.track.piece_type_at(ai.offset)):
		return int(ai._turn_way(ai.offset))
	return 1 if rival.road < 0.0 else -1


## Whether a line beside its rival is a pass worth committing to. A slow
## or spun kart, or one it has a grudge against, always is. In a bend it
## waits for the exit, and it doesn't go while it's the slower of the two.
## With a bend's braking zone coming up only the inside is, as both brake
## there. Otherwise it has to be able to go quicker than the kart here, and
## be closing on it, a good deal quicker or pulling out of the draft.
func _worth_going(ai: AIDriver, rival: Dictionary, chosen: float, speed: float) -> bool:
	if rival.slow or (ai.grudge == rival.kart and ai.grudge_left > 0.0):
		return true
	if ai.track.bend_at(ai.offset) > 0.02 or speed < rival.speed - 1.0:
		return false
	if _bend.x < speed * BEND_TIME + BEND_SEE:
		return _side_of(ai, chosen, rival) == int(_bend.y)
	var could := minf(ai.free_speed, ai.kart.stats.top_speed() * pow(maxf(ai.kart.push, 0.0), 0.4))
	if could < rival.speed + CLOSING:
		return false
	return speed - rival.speed > CLOSING or could - rival.speed > QUICKER or _was_slipping


## Mid pass, the kart ahead moving across to cover the side it's going for:
## a good or aggressive driver switches to the other side, once a pass.
func _dummy(ai: AIDriver, rival: Dictionary) -> void:
	if _faked or rival.slow or ai.racecraft < 0.5 or (ai.racecraft < 0.85 and ai.traits.aggression <= 0.3):
		return
	if rival.ahead < _front(ai.kart) + rival.back or rival.ahead > _front(ai.kart) + rival.back + COMMIT_GAP:
		return
	# Moving across fast enough to be in the way within half a second.
	var half: float = (ai.kart.width() + rival.width) * 0.5
	if rival.side * pass_side > 1.0 and absf(rival.across + rival.side * 0.5 - target) < half + 0.2:
		pass_side = -pass_side
		_faked = true
		_stall = 0.0
		if _counting:
			fakes += 1


## Committed on the outside of a bend that's now close, and not alongside
## yet, it moves its pass to the inside, unless it's much quicker.
func _to_inside(ai: AIDriver, rival: Dictionary, speed: float) -> void:
	if _faked or rival.slow or _bend.y == 0.0 or pass_side == int(_bend.y) or _bend.x > speed * BEND_TIME + BEND_SEE:
		return
	if rival.ahead < _front(ai.kart) + rival.back or speed - rival.speed >= OUTSIDE_SPEED:
		return
	pass_side = int(_bend.y)
	_stall = 0.0


## How much more braking it counts on into the next bend: alongside its
## rival on the inside, a good driver brakes later to make the pass stick.
func _late_inside(ai: AIDriver, rival: Dictionary, speed: float) -> float:
	if rival.is_empty() or pass_side == 0 or rival.slow or ai.racecraft < LATE_RACECRAFT or pass_side != int(_bend.y):
		return 1.0
	if _bend.x > speed * BEND_TIME + BEND_SEE:
		return 1.0
	var kart := ai.kart
	if rival.ahead > _front(kart) + rival.back + 3.0 or rival.ahead < -kart.tail_length() - rival.front:
		return 1.0
	return 1.0 + LATE_INSIDE * ai.racecraft * clampf(0.75 + 0.5 * ai.traits.aggression, 0.5, 1.25)


## An aggressive driver with a kart close behind takes the inside before a
## bend, once a bend, and holds it until the bend.
func _defend(ai: AIDriver, traffic: Array[Dictionary], preferred: float, here: float, speed: float, low: float, high: float) -> float:
	if not ai.defends:
		return preferred
	if _defending:
		if ai._along(_defended) < -2.0:
			return clampf(_defend_line, low, high)
		_defending = false
	if _bend.x > speed * DEFEND_TIME + 15.0 or _bend.x < 12.0 or _bend.y == 0.0:
		return preferred
	var at := fposmod(ai.offset + _bend.x, ai.track.length)
	if is_finite(_defended) and absf(fposmod(at - _defended + ai.track.length * 0.5, ai.track.length) - ai.track.length * 0.5) < 30.0:
		return preferred
	for body: Dictionary in traffic:
		if body.ahead < 0.0 and body.ahead > -DEFEND_BEHIND and absf(body.across - here) < 3.5 and body.speed > speed - 1.0:
			_defended = at
			_defend_line = clampf(here + _bend.y * DEFEND_MOVE, low, high)
			_defending = true
			defends += 1
			return _defend_line
	return preferred
