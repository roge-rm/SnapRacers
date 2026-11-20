extends Node

## Times one AI driver at each level (see Difficulty) round a few courses on
## its own, to compare the levels. It drives as the middle of a field of
## seven, in the default stock kart, two laps from a standing start. Run it
## with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/ai_laps.tscn -- hairpin_hall
## Name courses and levels after -- to only do those. Each line it prints
## starts with LAPS, then the course, level, both laps, the total and resets.
## "lengths" prints how long every course is instead. "field" times every
## stock driver with their own traits (see DriverTraits) instead of one with
## none, each line starting with DRIVER, then the course, level, driver,
## second lap and resets.

const COURSES := ["hairpin_hall", "foundry_flats", "skylark_swoop", "lantern_lane"]
const LAPS := 2
const GIVE_UP := 500.0
const RANK := 3
const FIELD := 7
const QUEUE_GAP := 8.0
const SLOW_GAP := 25.0
## A kart going slower than this, in m/s, or facing more than 60 degrees
## off the road counts as slow for the held up time.
const SLOW_SPEED := 6.0

var host: Node
var _last: Race


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	Game.settings.set_value("race", "kart", Game.DEFAULT_STOCK)
	Records.use_file("user://ai_laps_records_%s.cfg" % OS.get_process_id())
	var args := Array(OS.get_cmdline_user_args())
	if args.has("lengths"):
		for file in DirAccess.get_files_at(Game.TRACKS):
			if file.ends_with(".json"):
				var t := TrackPath.load_file(Game.TRACKS + "/" + file)
				print("LENGTH %-20s %.0f m" % [file.get_basename(), t.length])
		get_tree().quit()
		return
	var courses: Array = args.filter(func(a): return a in Tracks.all())
	var levels: Array = args.filter(func(a): return a in Difficulty.LEVELS)
	if courses.is_empty():
		courses = COURSES
	if levels.is_empty():
		levels = Difficulty.LEVELS
	if args.has("race"):
		for course in courses:
			for level in levels:
				for n in int(OS.get_environment("RACES")) if OS.has_environment("RACES") else 1:
					var r: Array = await _race(course, level, n)
					print("RACE %s %s %d %.2f %.2f %d %d %.1f %.1f %d %d %d %d %d %d %d %d" % ([course, level, n] + r))
		get_tree().quit()
		return
	if args.has("field"):
		for course in courses:
			for level in levels:
				for key in Game.stock_driver_keys():
					var r: Array = await _time(course, level, key)
					print("DRIVER %s %s %s %.2f %d" % [course, level, key, r[1], r[2]])
		get_tree().quit()
		return
	for course in courses:
		for level in levels:
			var r: Array = await _time(course, level)
			print("LAPS %s %s %.2f %.2f %.2f %d" % [course, level, r[0], r[1], r[0] + r[1], r[2]])
	get_tree().quit()


## A full race of eight AI drivers at `level`, the player's kart driven by
## one too, seeded by `n`. Gives [winner's time, the field's average time,
## resets, passes, seconds queued, seconds held up by a slow kart, pass
## attempts, made, beaten, lost, inside moves, slipstream pull outs,
## defends, dummies]. A pass is two karts within 30 m of each other on the road
## swapping places. Queued is a kart up to QUEUE_GAP metres behind another,
## in line with it and below 90% of the speed it could go. Held up is a kart
## below 60% of that with a kart up to SLOW_GAP metres ahead that's slow,
## spun or facing the wrong way. Both are kart seconds over the field.
func _race(course: String, level: String, n: int) -> Array:
	seed(4321 + n)
	Game.mode = Game.MODE_RACE
	Game.settings.set_value("race", "difficulty", level)
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race and child != _last and not child.is_queued_for_deletion():
				race = child
	_last = race
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	driver.others.assign(race.racers.map(func(r): return r.kart))
	Difficulty.apply(driver, level, RANK, FIELD)
	driver.seed_line(1234 + n)
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	var resets := [0]
	# INCIDENTS keeps what each kart was doing every quarter second and prints
	# the last few seconds of it when the race puts that kart back.
	var incidents := OS.has_environment("INCIDENTS")
	var history := {}
	# Why the AI asked for a reset itself, by racer, from its stuck and
	# lost wheel timers the step before.
	var why_reset := {}
	var timers := {}
	for racer in race.racers:
		history[racer] = []
		if incidents:
			racer.kart.gadget_used.connect(func(kind: String) -> void:
				print("  gadget %s %s at %.0f m, %.1f s in" % [racer.name, kind, racer.offset, race.time]))
			racer.kart.parts_lost.connect(func(indices: Array[int]) -> void:
				var wheels := indices.filter(func(i): return KartDesign.is_wheel(racer.kart.design.parts[i].id)).size()
				print("  parts %s lost %d (%d wheels) at %.0f m, %.1f s in: %s" % [racer.name, indices.size(), wheels, racer.offset, race.time, _incident_line(race, racer)]))
		racer.kart.was_reset.connect(func() -> void:
			resets[0] += 1
			var why: String = why_reset.get(racer, "off the course")
			why_reset.erase(racer)
			print("  reset %s at %.0f m on a %s, %.1f s in, %s" % [racer.name, racer.offset, race.track.piece_type_at(racer.offset), race.time, why])
			if incidents:
				for line in history[racer]:
					print("      " + line))
	var count := race.racers.size()
	var ahead := {}
	var passes := 0
	var queued := 0.0
	var held := 0.0
	var step := 1.0 / Engine.physics_ticks_per_second
	while race.time < GIVE_UP and not race.racers.all(func(r): return r.progress.finished):
		await get_tree().physics_frame
		if race.time >= 3.0:
			var held_up := _held_up(race)
			queued += held_up.x * step
			held += held_up.y * step
		for racer: Race.Racer in race.racers:
			if racer.ai == null:
				continue
			if racer.ai.controls.reset and not why_reset.has(racer):
				var was: Vector2 = timers.get(racer, Vector2.ZERO)
				why_reset[racer] = "lost a wheel" if was.y > was.x else "stuck"
			timers[racer] = Vector2(racer.ai._stuck, racer.ai._wheel_gone)
		if incidents and Engine.get_physics_frames() % 15 == 0:
			for racer: Race.Racer in race.racers:
				history[racer].append(_incident_line(race, racer))
				if history[racer].size() > 14:
					history[racer].pop_front()
		if race.time < 3.0:
			continue
		for i in count:
			for j in range(i + 1, count):
				var a: Race.Racer = race.racers[i]
				var b: Race.Racer = race.racers[j]
				if a.progress.finished or b.progress.finished:
					continue
				var gap := a.progress.distance() - b.progress.distance()
				var key := i * count + j
				var was: float = ahead.get(key, 0.0)
				if absf(gap) < 30.0 and was != 0.0 and signf(gap) != was:
					passes += 1
				ahead[key] = signf(gap)
	var times: Array = race.racers.filter(func(r): return r.progress.finished).map(func(r): return r.progress.finish_time)
	times.sort()
	var mean := 0.0
	for t in times:
		mean += t
	mean = mean / times.size() if not times.is_empty() else INF
	var counts := [0, 0, 0, 0, 0, 0, 0, 0]
	for racer: Race.Racer in race.racers:
		if racer.ai != null:
			var tp := racer.ai.traffic
			var each := [tp.attempts, tp.made, tp.beaten, tp.lost, tp.inside_moves, tp.slip_pulls, tp.defends, tp.fakes]
			for i in each.size():
				counts[i] += each[i]
	return [times[0] if not times.is_empty() else INF, mean, resets[0], passes, queued, held] + counts


## How many karts are queued and how many held up by a slow kart this
## step, as Vector2(queued, held up) (see _race()).
func _held_up(race: Race) -> Vector2:
	var out := Vector2.ZERO
	var track := race.track
	for racer: Race.Racer in race.racers:
		var ai := racer.ai
		if ai == null or racer.progress.finished or not is_finite(ai.free_speed) or ai.free_speed < 3.0:
			continue
		var k := racer.kart
		var v := k.linear_velocity.length()
		var at := racer.offset
		var across := (k.global_position - track.point_at(at)).dot(track.right_at(at))
		var in_queue := false
		var near_slow := false
		for other: Race.Racer in race.racers:
			if other == racer or other.progress.finished:
				continue
			var gap := other.progress.distance() - racer.progress.distance()
			if gap <= 0.0 or gap > SLOW_GAP:
				continue
			var o := other.kart
			var o_across := (o.global_position - track.point_at(other.offset)).dot(track.right_at(other.offset))
			var forward := track.forward_at(other.offset)
			var slow := o.linear_velocity.dot(forward) < SLOW_SPEED or (-o.global_basis.z).dot(forward) < 0.5
			if slow and v < ai.free_speed * 0.6:
				near_slow = true
			if gap < QUEUE_GAP + k.tail_length() and absf(o_across - across) < (k.width() + o.width()) * 0.5 + 0.3 and v < ai.free_speed * 0.9:
				in_queue = true
		out += Vector2(1.0 if in_queue else 0.0, 1.0 if near_slow else 0.0)
	return out


## One line of what a kart's doing for INCIDENTS: where, how fast, which
## karts it's touching and what its racecraft is up to.
func _incident_line(race: Race, racer: Race.Racer) -> String:
	var k := racer.kart
	var at := racer.offset
	var across := (k.global_position - race.track.point_at(at)).dot(race.track.right_at(at))
	var touching: Array = []
	for body in k.get_colliding_bodies():
		if not body is Kart:
			touching.append(str(body.name).left(10))
		else:
			for other: Race.Racer in race.racers:
				if other.kart == body:
					touching.append(other.name)
	var near: Array = []
	for other: Race.Racer in race.racers:
		if other != racer and absf(other.offset - at) < 12.0:
			var o := (other.kart.global_position - race.track.point_at(other.offset)).dot(race.track.right_at(other.offset))
			near.append("%s%+.0f/%+.1f" % [other.name.left(3), other.offset - at, o])
	var s := "%.2f %.0f m %s across %+.1f v %.1f air %s zap %.1f hit[%s] near[%s]" % [race.time, at, race.track.piece_type_at(at), across, k.linear_velocity.length(), not k.wheels.any(func(w): return w.grounded), k.zapped_left, ",".join(touching), " ".join(near)]
	var ai := racer.ai
	if ai != null:
		var tp := ai.traffic
		s += " | side %d def %s shaken %.1f grudge %s slip %.2f lim %.1f thr %.1f brk %.1f str %+.2f eased %+.1f jump %s stuck %.1f wheel %.1f lost %d" % [tp.pass_side, tp._defending, ai.shaken, ai.grudge != null, k.slipstream, tp.speed_limit, ai.controls.throttle, ai.controls.brake, ai.controls.steer, ai._eased, ai._jump_run_in, ai._stuck, ai._wheel_gone, k.lost.size()]
	return s


## Both laps' times and how many resets, as [first, second, resets].
## With `key` it drives as that stock driver, with their traits.
func _time(course: String, level: String, key := "") -> Array:
	Game.mode = Game.MODE_TIME_TRIAL
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race and child != _last and not child.is_queued_for_deletion():
				race = child
	_last = race
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	driver.others.assign([race.player.kart])
	Difficulty.apply(driver, level, RANK, FIELD, DriverTraits.for_roster(key) if key != "" else null)
	if OS.has_environment("LINE_TRUST"):
		AIDriver.LINE_TRUST = float(OS.get_environment("LINE_TRUST"))
	if driver.has_method("seed_line"):
		driver.call("seed_line", 1234)
	race.add_child(driver)
	driver._rng.seed = 1234
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	var resets := [0]
	race.player.kart.was_reset.connect(func() -> void:
		resets[0] += 1
		print("  reset at %.0f m on a %s, %.1f s in" % [race.player.offset, race.track.piece_type_at(race.player.offset), race.time]))
	var trace := OS.has_environment("LAP_TRACE")
	# How far off its own line it drives, and how long off the road, on the
	# second lap.
	var miss := [0.0, 0.0, 0.0, 0.0]
	var splits := []
	while race.player.progress.lap_times.size() < LAPS and race.time < GIVE_UP:
		await get_tree().physics_frame
		if race.player.progress.lap_times.size() == 1:
			var at := race.player.offset
			var across := (race.player.kart.global_position - race.track.point_at(at)).dot(race.track.right_at(at))
			var by := absf(across - driver.line_at(at))
			miss[0] += by * by
			miss[1] = maxf(miss[1], by)
			miss[2] += 1.0
			if absf(across) > race.track.width * 0.5 + 0.3:
				miss[3] += 1.0 / 60.0
			# SPLITS prints the time every 100 m round the second lap.
			if OS.has_environment("SPLITS") and splits.size() <= int(at / 100.0):
				splits.append(race.time)
		# LAP_TRACE prints where it is every half second: offset, speed, how far
		# right of the middle it is and where its line is.
		if trace and Engine.get_physics_frames() % int(OS.get_environment("LAP_TRACE")) == 0:
			var k := race.player.kart
			var at := race.player.offset
			var across := (k.global_position - race.track.point_at(at)).dot(race.track.right_at(at))
			var mine: float = driver.call("line_at", at) if driver.has_method("line_at") else 0.0
			print("    %.1f s %.0f m %.1f m/s across %+.1f line %+.1f bend %.3f lb %.3f %s gas %.1f brake %.1f steer %+.2f" % [race.time, at, k.linear_velocity.length(), across, mine, race.track.bend_at(at), race.track.line_bend_at(at), race.track.piece_type_at(at), k.controls.throttle, k.controls.brake, k.controls.steer])
	var laps: Array = race.player.progress.lap_times
	if not splits.is_empty():
		var parts := PackedStringArray()
		for i in range(1, splits.size()):
			parts.append("%.1f" % (splits[i] - splits[i - 1]))
		print("  SPLITS " + " ".join(parts))
	print("  off its line %.2f m on average, %.1f m at most, %.1f s off the road" % [sqrt(miss[0] / maxf(miss[2], 1.0)), miss[1], miss[3]])
	if laps.size() < LAPS:
		return [INF, INF, resets[0]]
	return [laps[0], laps[1], resets[0]]
