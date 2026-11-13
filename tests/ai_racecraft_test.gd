extends Node

## Racecraft in traffic (see AITrafficPlanner) and the slipstream every kart
## gets (see Kart._slipstream()): the passing side from the next bend,
## waiting behind before a pass, real passes without flicking from side to
## side, defending once a bend, being shaken or holding a grudge after a
## knock, steering round traps, a draft that's worth a little speed, driving
## round a kart stopped across the road at speed, going for a gap in a train
## and a field of karts racing a lap together without anyone resetting.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/ai_racecraft_test.tscn

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
	design = KartDesign.load_file("res://data/karts/stock/kart_kid.json")
	_traits()
	_decisions()
	_after_contact()
	await _traps()
	_clear()
	await get_tree().physics_frame
	if OS.has_environment("FIELD_TRACE"):
		for level in ["hard", "normal", "expert", "easy"]:
			await _field(level)
		get_tree().quit()
		return
	if OS.has_environment("DEFEND_TRACE"):
		await _defend()
		get_tree().quit()
		return
	if OS.has_environment("TRAIN_TRACE"):
		await _round_spun_kart()
		await _train()
		get_tree().quit()
		return
	if OS.has_environment("SLIP_TRACE"):
		await _slipstream()
		await _pass_into_bend()
		get_tree().quit()
		return
	await _slipstream()
	await _pass_into_bend()
	await _round_spun_kart()
	await _train()
	await _defend()
	for level in ["normal", "hard", "expert"]:
		await _field(level)
	print("All %d AI racecraft checks passed." % checks if failures == 0 else "%d of %d AI racecraft checks failed." % [failures, checks])
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


func _ai(kart: Kart, at: float, level := "normal", traits: DriverTraits = null) -> AIDriver:
	var ai := AIDriver.new()
	ai.kart = kart
	ai.track = track
	ai.offset = at
	kart.controls = ai.controls
	Difficulty.apply(ai, level, 0, 1, traits)
	ai.seed_line(77 + drivers.size())
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


## The same traits give the same racecraft, and they move it the right way.
func _traits() -> void:
	var make := func(level: String, traits: Dictionary) -> AIDriver:
		var ai := AIDriver.new()
		Difficulty.apply(ai, level, 0, 1, DriverTraits.from_dict(traits))
		return ai
	var patient: AIDriver = make.call("normal", {"patience": 1.0})
	var hasty: AIDriver = make.call("normal", {"patience": -1.0})
	var again: AIDriver = make.call("normal", {"patience": 1.0})
	check(patient.pass_wait > hasty.pass_wait and patient.pass_wait == again.pass_wait, "patience follows longer before a pass, the same every time (%.2f s against %.2f s)" % [patient.pass_wait, hasty.pass_wait])
	var bold: AIDriver = make.call("normal", {"aggression": 0.8})
	var meek: AIDriver = make.call("normal", {"aggression": -0.8})
	var easy: AIDriver = make.call("easy", {"aggression": 1.0})
	check(bold.defends and not meek.defends and not easy.defends, "only aggressive drivers defend, and never on Easy")
	var stock := DriverTraits.for_roster("thudd")
	var a := AIDriver.new()
	var b := AIDriver.new()
	Difficulty.apply(a, "hard", 2, 7, stock)
	Difficulty.apply(b, "hard", 2, 7, DriverTraits.for_driver("", CharacterDesign.load_file(DriverTraits.ROSTER + "/thudd.json").name))
	check(a.pass_wait == b.pass_wait and a.defends == b.defends and a.racecraft == b.racecraft, "a stock driver's racecraft is the same by name as by roster key")
	for ai in [patient, hasty, again, bold, meek, easy, a, b]:
		ai.free()


## Planner decisions with frozen karts on a straight before a bend.
func _decisions() -> void:
	for way in ["right", "left"]:
		track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 10}, {"type": "curve", "size": 2, "turn": way}, {"type": "straight", "length": 10}]})
		track.width = 13.0
		var bend := _bend_start()
		var own := _place(bend - 40.0, 0.0, 20.0)
		var slow := _place(bend - 28.0, 0.0, 12.0)
		var ai := _ai(own, bend - 40.0, "expert")
		ai.offset = bend - 40.0
		var chosen := ai.traffic.plan(ai, 0.0, 0.033)
		var inside := 1.0 if way == "right" else -1.0
		check(chosen * inside > 1.0, "with both sides free it sets up on the inside of a %s bend (%.1f m)" % [way, chosen])
		_clear()
	# Not much quicker than the kart ahead, it waits a moment behind it first,
	# then goes. Far from a bend, so slipstreaming isn't what holds it.
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 30}]})
	track.width = 13.0
	var own := _place(100.0, 0.0, 14.0)
	var slow := _place(112.0, 0.0, 13.0)
	var ai := _ai(own, 100.0, "normal")
	ai.racecraft = 0.0
	# It couldn't go much faster than the kart ahead if it got by.
	ai.free_speed = 15.0
	var first := ai.traffic.plan(ai, 0.0, 0.033)
	var half := own.width()
	check(absf(first) < half * 0.9, "it follows a kart that isn't much slower for a moment (%.1f m across)" % first)
	var later := first
	for n in int((ai.pass_wait + 0.5) / 0.033):
		later = ai.traffic.plan(ai, 0.0, 0.033)
	check(absf(later) >= half * 0.9, "after %.1f s it pulls out to pass (%.1f m across)" % [ai.pass_wait, later])
	# On a long straight a good driver tucks in behind to slipstream.
	ai.racecraft = 1.0
	ai.traffic = AITrafficPlanner.new()
	for n in int((ai.pass_wait + 0.5) / 0.033):
		later = ai.traffic.plan(ai, 0.0, 0.033)
	check(absf(later) < half * 0.9 and ai.traffic._slipstreaming(ai, ai.traffic._find_rival(ai, ai.traffic._traffic(ai, 80.0), 0.0, 14.0, 2.0), 14.0), "an Expert tucks in to slipstream on a long straight (%.1f m across)" % later)
	# A grudge against that kart skips the waiting.
	ai.grudge = slow
	ai.grudge_left = 3.0
	ai.racecraft = 0.0
	ai.traffic = AITrafficPlanner.new()
	check(absf(ai.traffic.plan(ai, 0.0, 0.033)) >= half * 0.9, "a grudge against the kart ahead goes for the pass at once")
	_clear()


## After a knock from another kart a timid driver is shaken for a moment and
## leaves more room behind the kart ahead, and an aggressive one holds a
## grudge against the kart that hit it. A knock counts once, and both wear
## off.
func _after_contact() -> void:
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 30}]})
	track.width = 13.0
	var own := _place(100.0, 0.0, 16.0)
	var ahead := _place(110.0, 0.0, 12.0)
	var timid := _ai(own, 100.0, "normal", DriverTraits.from_dict({"aggression": -0.8}))
	var traffic := timid.traffic._traffic(timid, 80.0)
	var decel := AITrafficPlanner.braking(timid)
	var calm: float = timid.traffic._evaluate(timid, 0.0, 0.0, 16.0, 2.0, decel, traffic, NAN).limit
	timid.knocked_by(ahead)
	var wary: float = timid.traffic._evaluate(timid, 0.0, 0.0, 16.0, 2.0, decel, traffic, NAN).limit
	check(timid.shaken > 0.0 and timid.grudge == null, "a timid driver is shaken by a knock (%.1f s), with no grudge" % timid.shaken)
	check(wary < calm - 0.3, "shaken, it follows the kart ahead further back (%.1f m/s against %.1f)" % [wary, calm])
	timid._after_contact(0.5)
	var was := timid.shaken
	timid.knocked_by(ahead)
	check(timid.shaken == was, "still touching, the same knock doesn't shake it again")
	timid._after_contact(timid.shaken + 0.1)
	check(timid.shaken == 0.0, "and it gets over it")
	var bold := _ai(ahead, 110.0, "normal", DriverTraits.from_dict({"aggression": 0.8}))
	bold.knocked_by(own)
	check(bold.grudge == own and bold.grudge_left > 0.0 and bold.shaken == 0.0, "an aggressive driver holds a grudge against the kart that hit it (%.1f s)" % bold.grudge_left)
	bold._after_contact(bold.grudge_left + 0.1)
	check(bold.grudge == null, "and lets it go after a while")
	_clear()


## Spikes dropped on its line ahead: it steers round them, and the planner
## won't take a line over them.
func _traps() -> void:
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 30}]})
	track.width = 13.0
	var own := _place(100.0, 0.0, 20.0)
	var ai := _ai(own, 100.0, "normal")
	var trap := BrickTrap.new("spikes", 1)
	add_child(trap)
	var mine := ai.line_at(130.0)
	trap.global_position = track.point_at(130.0) + track.right_at(130.0) * mine
	await get_tree().physics_frame
	var shift := ai._dodge_traps(-own.global_basis.z)
	var reach: float = BrickTrap.KINDS.spikes.across + own.width() * 0.5
	check(is_finite(shift) and absf(shift) > reach, "it steers %.1f m over to miss spikes on its line" % shift)
	var planned := ai.traffic.plan(ai, 0.0, 0.033)
	check(planned <= ai.trap_band.x or planned >= ai.trap_band.y, "the planner keeps off the spikes even when told to drive its line (%.1f m)" % planned)
	trap.free()
	check(is_nan(ai._dodge_traps(-own.global_basis.z)), "with the spikes gone it keeps to its line")
	_clear()


## Where the first bend starts on the test track.
func _bend_start() -> float:
	var at := 0.0
	while track.bend_at(at) < 0.02:
		at += 1.0
	return at


## Full throttle down a long straight on its own, and then with a kart just
## ahead of it at the same speed: the draft is worth a little top speed. The
## kart ahead is moved like one online, to keep the gap the same.
func _slipstream() -> void:
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 50}]})
	track.width = 13.0
	var road := TrackBuilder.new(track)
	add_child(road)
	await get_tree().physics_frame
	var alone: float = await _top_speed(false)
	var drafting: float = await _top_speed(true)
	var gain := drafting - alone
	check(gain > 0.3 and gain < 1.5, "a kart 3 m behind another goes %.1f km/h faster at the top (%.1f against %.1f km/h)" % [gain * 3.6, drafting * 3.6, alone * 3.6])
	road.queue_free()
	await get_tree().physics_frame


func _top_speed(behind: bool) -> float:
	var kart := _place(60.0, 0.0, 0.0, false)
	var top := kart.stats.top_speed()
	for n in 20:
		await get_tree().physics_frame
	kart.linear_velocity = track.forward_at(60.0) * top * 0.97
	kart.controls.throttle = 1.0
	var ahead: Kart
	if behind:
		ahead = _place(70.0, 0.0, 0.0)
		ahead.remote = true
	var most := 0.0
	var seen := 0.0
	for n in 60 * 20:
		# Holds it straight down the middle, like a person would.
		var across := (kart.global_position - track.point_at(60.0)).dot(track.right_at(60.0))
		var off := (-kart.global_basis.z).signed_angle_to(track.forward_at(60.0), kart.global_basis.y)
		kart.controls.steer = clampf(-across * 0.15 - off * 3.0, -0.3, 0.3)
		if behind:
			var forward := -kart.global_basis.z
			ahead.global_transform = Transform3D(kart.global_basis, kart.global_position + forward * (3.0 + AITrafficPlanner._front(kart) + ahead.tail_length()))
			ahead.remote_velocity = kart.linear_velocity
		await get_tree().physics_frame
		seen = maxf(seen, kart.slipstream)
		most = kart.linear_velocity.dot(track.forward_at(60.0))
		if OS.has_environment("SLIP_TRACE") and n % 60 == 0:
			print("    %d s %.1f m/s at %s up %.2f top %.1f" % [n / 60, most, kart.global_position, kart.global_basis.y.y, top])
	if behind:
		check(seen > Kart.SLIP_MOST * 0.5, "the draft cuts the drag of a kart close behind (%.0f%%)" % (seen * 100.0))
	_clear()
	await get_tree().physics_frame
	return most


## A quick Normal driver catches a slow one on a straight before a right
## bend: it passes within a few seconds, and doesn't flick from side to side.
func _pass_into_bend() -> void:
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 6}, {"type": "curve", "size": 2, "turn": "right"}, {"type": "straight", "length": 8}]})
	track.width = 13.0
	var road := TrackBuilder.new(track)
	add_child(road)
	var bend := _bend_start()
	var own := _place(20.0, 0.0, 0.0, false)
	var slow := _place(45.0, 0.0, 0.0, false)
	var ai := _ai(own, 20.0, "normal")
	ai.mistakes = 0.0
	var lead := _ai(slow, 45.0, "easy")
	lead.pace = 0.4
	lead.mistakes = 0.0
	for n in 30:
		await get_tree().physics_frame
	own.linear_velocity = track.forward_at(20.0) * 14.0
	slow.linear_velocity = track.forward_at(45.0) * 8.0
	ai.set_physics_process(true)
	lead.set_physics_process(true)
	var at := 20.0
	var lead_at := 45.0
	var flips := 0
	var was := 0
	var passed_after := -1.0
	var resets := 0
	for n in 60 * 20:
		await get_tree().physics_frame
		at = track.offset_of(own.global_position, at, 10.0)
		lead_at = track.offset_of(slow.global_position, lead_at, 10.0)
		ai.offset = at
		lead.offset = lead_at
		if ai.controls.reset or lead.controls.reset:
			resets += 1
		var gap := lead_at - at
		if gap > -6.0 and gap < 15.0:
			var across := (own.global_position - slow.global_position).dot(track.right_at(at))
			var now := 0 if absf(across) < 1.0 else (1 if across > 0.0 else -1)
			if now != 0:
				if was != 0 and now != was:
					flips += 1
				was = now
		if OS.has_environment("PASS_TRACE") and n % 30 == 0:
			print("    %.1f s gap %.1f own %.1f lead %.1f across %.1f side %d hold %s limit %.1f" % [n / 60.0, lead_at - at, own.linear_velocity.length(), slow.linear_velocity.length(), (own.global_position - slow.global_position).dot(track.right_at(at)), ai.traffic.pass_side, ai.traffic._holding_back(ai, ai.traffic._find_rival(ai, ai.traffic._traffic(ai, 80.0), 0.0, own.linear_velocity.length(), 2.0), own.linear_velocity.length()), ai.traffic.speed_limit])
		if passed_after < 0.0 and at > lead_at + own.tail_length() + AITrafficPlanner._front(slow) + 0.5:
			passed_after = n / 60.0
			break
	check(passed_after > 0.0 and passed_after < 10.0, "a quicker kart gets past a slow one by the bend (%.1f s, bend at %.0f m)" % [passed_after, bend])
	check(flips == 0, "it picks a side and keeps it (%d changes of side)" % flips)
	check(resets == 0, "nobody resets in the pass")
	_clear()
	road.queue_free()
	await get_tree().physics_frame


## A kart stopped across the road on a straight ahead: a Normal driver
## goes round it without dropping below 70% of the speed it had coming up.
func _round_spun_kart() -> void:
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 30}]})
	track.width = 13.0
	var road := TrackBuilder.new(track)
	add_child(road)
	var own := _place(40.0, 0.0, 0.0, false)
	var spun := _place(130.0, 0.0, 0.0)
	spun.transform = Transform3D(spun.transform.basis.rotated(spun.transform.basis.y, PI * 0.5), spun.transform.origin)
	var ai := _ai(own, 40.0, "normal")
	ai.mistakes = 0.0
	for n in 30:
		await get_tree().physics_frame
	own.linear_velocity = track.forward_at(40.0) * 16.0
	ai.set_physics_process(true)
	var at := 40.0
	var coming := -1.0
	var slowest := INF
	var past := false
	for n in 60 * 15:
		await get_tree().physics_frame
		at = track.offset_of(own.global_position, at, 10.0)
		ai.offset = at
		var v := own.linear_velocity.length()
		if coming < 0.0 and at > 130.0 - 40.0:
			coming = v
		if coming > 0.0:
			slowest = minf(slowest, v)
		if OS.has_environment("PASS_TRACE") and n % 15 == 0:
			print("    %.2f s at %.1f v %.1f limit %.1f across %.1f" % [n / 60.0, at, v, ai.traffic.speed_limit, (own.global_position - track.point_at(at)).dot(track.right_at(at))])
		if at > 130.0 + 4.0:
			past = true
			break
	check(past and slowest >= coming * 0.7, "it drives round a kart stopped across the road at %.0f%% of its speed or more (%.1f m/s against %.1f)" % [100.0 * slowest / maxf(coming, 0.01), slowest, coming])
	_clear()
	road.queue_free()
	await get_tree().physics_frame


## Three karts in a line at nearly the same pace before a bend: the one at
## the back goes for a gap within a few seconds instead of queueing.
func _train() -> void:
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 6}, {"type": "curve", "size": 2, "turn": "right"}, {"type": "straight", "length": 8}]})
	track.width = 13.0
	var road := TrackBuilder.new(track)
	add_child(road)
	var starts := [24.0, 17.0, 10.0]
	var ais: Array[AIDriver] = []
	for i in 3:
		var kart := _place(starts[i], 0.0, 0.0, false)
		var ai := _ai(kart, starts[i], "normal")
		ai.mistakes = 0.0
		ais.append(ai)
	# The two in front go a touch slower than the one at the back would.
	ais[0].pace *= 0.95
	ais[1].pace *= 0.95
	for n in 30:
		await get_tree().physics_frame
	for i in 3:
		karts[i].linear_velocity = track.forward_at(starts[i]) * 13.0
		ais[i].set_physics_process(true)
	var at := starts.duplicate()
	var rear := ais[2]
	var went := -1.0
	# Kart seconds the back one spends right behind another, in line with it.
	var queued := 0.0
	for n in 60 * 5:
		await get_tree().physics_frame
		for i in 3:
			at[i] = track.offset_of(karts[i].global_position, at[i], 10.0)
			ais[i].offset = at[i]
		for i in 2:
			var gap: float = at[i] - at[2]
			var across := (karts[i].global_position - karts[2].global_position).dot(track.right_at(at[2]))
			if gap > 0.0 and gap < 8.0 + karts[2].tail_length() and absf(across) < karts[2].width():
				queued += 1.0 / 60.0
				break
		if (OS.has_environment("PASS_TRACE") or OS.has_environment("TRAIN_TRACE")) and n % 15 == 0:
			var across_of := func(i: int) -> float: return (karts[i].global_position - track.point_at(at[i])).dot(track.right_at(at[i]))
			print("    %.2f s at %.1f/%.1f/%.1f across %.1f/%.1f/%.1f side %d plan %d target %.1f limit %.1f v %.1f stall %.1f" % [n / 60.0, at[0], at[1], at[2], across_of.call(0), across_of.call(1), across_of.call(2), rear.traffic.pass_side, rear.traffic.plan_side, rear.traffic.target, rear.traffic.speed_limit, karts[2].linear_velocity.length(), rear.traffic._stall])
		# Out of line with the kart in front of it, or past it.
		var beside := absf((karts[1].global_position - karts[2].global_position).dot(track.right_at(at[2]))) > karts[2].width()
		if went < 0.0 and (beside or at[2] > at[1]):
			went = n / 60.0
	check(went >= 0.0 and went < 4.0, "the kart at the back of a train pulls out for a gap (after %.1f s)" % went)
	check(queued < 2.0, "and doesn't sit in line behind the others (%.1f s of 5 queued)" % queued)
	_clear()
	road.queue_free()
	await get_tree().physics_frame


## An aggressive Hard driver with a quicker kart right behind it before a
## bend moves to the inside once, and doesn't weave.
func _defend() -> void:
	track = TrackPath.from_dict({"pieces": [{"type": "straight", "length": 4}, {"type": "curve", "size": 2, "turn": "right"}, {"type": "straight", "length": 4}, {"type": "curve", "size": 2, "turn": "left"}, {"type": "straight", "length": 6}]})
	track.width = 13.0
	var road := TrackBuilder.new(track)
	add_child(road)
	var front := _place(40.0, 0.0, 0.0, false)
	var back := _place(32.0, 0.0, 0.0, false)
	var defender := _ai(front, 40.0, "hard", DriverTraits.from_dict({"aggression": 1.0}))
	defender.pace = 0.8
	defender.mistakes = 0.0
	var attacker := _ai(back, 32.0, "hard")
	attacker.mistakes = 0.0
	for n in 30:
		await get_tree().physics_frame
	front.linear_velocity = track.forward_at(40.0) * 12.0
	back.linear_velocity = track.forward_at(32.0) * 13.0
	defender.set_physics_process(true)
	attacker.set_physics_process(true)
	var at := [40.0, 32.0]
	var turns := 0
	var last := 0.0
	var moved := 0.0
	var bends_seen := {}
	for n in 60 * 16:
		await get_tree().physics_frame
		at[0] = track.offset_of(front.global_position, at[0], 10.0)
		at[1] = track.offset_of(back.global_position, at[1], 10.0)
		defender.offset = at[0]
		attacker.offset = at[1]
		if track.bend_at(at[0]) > 0.02:
			bends_seen[snappedf(at[0], 100.0)] = true
		if OS.has_environment("DEFEND_TRACE") and n % 10 == 0:
			print("    %.2f s at %.0f/%.0f defending %s line %.2f target %.2f eased %.2f limit %.1f bend %.0f" % [n / 60.0, at[0], at[1], defender.traffic._defending, defender.traffic._defend_line, defender.traffic.target, defender._eased, defender.traffic.speed_limit, defender.traffic._bend.x])
		# Where its planner aims, while it's defending.
		if defender.traffic._defending:
			var step: float = defender.traffic.target - last
			if absf(step) > 0.2:
				if moved != 0.0 and signf(step) != signf(moved):
					turns += 1
				moved = step
		else:
			moved = 0.0
		last = defender.traffic.target
		if at[0] > track.length - 40.0:
			break
	var count := defender.traffic.defends
	check(count >= 1, "an aggressive Hard driver defends the inside with a kart behind (%d times)" % count)
	check(count <= 2, "it defends at most once a bend (%d times for 2 bends)" % count)
	check(turns == 0, "it doesn't weave while it defends (%d turns back)" % turns)
	_clear()
	road.queue_free()
	await get_tree().physics_frame


## Four karts from the grid race a lap of a real course at `level` with
## nobody resetting.
func _field(level: String) -> void:
	track = TrackPath.load_file("res://data/tracks/hairpin_hall.json")
	track.apply_layout(false, false)
	track.racing_line()
	var road := TrackBuilder.new(track)
	add_child(road)
	var offsets: Array[float] = []
	var gone: Array[float] = []
	var resets := [0]
	var stock := ["kart_kid", "night_shift", "kart_kid", "night_shift"]
	for i in 4:
		design = KartDesign.load_file("res://data/karts/stock/%s.json" % stock[i])
		var kart := Kart.new()
		kart.build(design)
		kart.transform = track.grid_slot(i)
		add_child(kart)
		karts.append(kart)
		offsets.append(track.offset_of(kart.global_position))
		gone.append(0.0)
		var k := i
		kart.was_reset.connect(func() -> void:
			resets[0] += 1
			print("    reset kart %d at %.0f m" % [k, offsets[k]]))
		kart.reset_to = func(_where: Vector3) -> Transform3D: return track.place_at(offsets[k])
		var ai := AIDriver.new()
		ai.kart = kart
		ai.track = track
		Difficulty.apply(ai, level, i, 4, DriverTraits.from_name("field %d" % i))
		ai.seed_line(500 + i)
		kart.controls = ai.controls
		add_child(ai)
		drivers.append(ai)
	design = KartDesign.load_file("res://data/karts/stock/kart_kid.json")
	for ai in drivers:
		ai.others = karts
	var done := false
	for tick in 60 * 200:
		await get_tree().physics_frame
		done = true
		for i in karts.size():
			var was := offsets[i]
			offsets[i] = track.offset_of(karts[i].global_position, was, 30.0)
			gone[i] += fposmod(offsets[i] - was + track.length * 0.5, track.length) - track.length * 0.5
			drivers[i].offset = offsets[i]
			done = done and gone[i] >= track.length
			var d := drivers[i]
			if OS.has_environment("FIELD_TRACE") and d._stuck > 0.9 and int(d._stuck * 60.0) % 30 == 0:
				var near := PackedStringArray()
				for j in karts.size():
					if j != i:
						var gap := karts[j].global_position - karts[i].global_position
						near.append("%d:%.1f/%.1f %.1fm/s" % [j, gap.dot(-karts[i].global_basis.z), gap.dot(karts[i].global_basis.x), karts[j].linear_velocity.length()])
				print("    stuck %d %.2f at %.0f: %.1f m/s gas %.1f brake %.1f steer %.2f back %.1f leave %.1f tries %d limit %.1f queue %s side %d eased %.1f target %.1f touching %d near %s" % [i, d._stuck, offsets[i], karts[i].linear_velocity.length(), d.controls.throttle, d.controls.brake, d.controls.steer, d._backing, d._leaving, d._tries, d.traffic.speed_limit, d.traffic.queueing, d.traffic.pass_side, d._eased, d.traffic.target, karts[i].get_colliding_bodies().size(), " ".join(near)])
			if d.controls.reset:
				print("    resetting %d at %.0f m (%s): %.1f m/s up %.2f stuck %.1f tries %d nowhere %.1f wheel %.1f queue %s limit %.1f touching %d" % [i, offsets[i], track.piece_type_at(offsets[i]), karts[i].linear_velocity.length(), karts[i].global_basis.y.y, d._stuck, d._tries, d._mark_time, d._wheel_gone, d.traffic.queueing, d.traffic.speed_limit, karts[i].get_colliding_bodies().size()])
		if done:
			break
	check(done and resets[0] == 0, "%s: four karts race a lap of Hairpin Hall together, %d resets" % [level, resets[0]])
	_clear()
	road.queue_free()
	await get_tree().physics_frame
