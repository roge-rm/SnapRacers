extends SceneTree

## The level crossing: the train's timetable is the same for the same seed and
## clock, the barriers are down before it gets to the road, a course says
## where its crossings are, the train knocks a kart off the rails, and the AI
## waits for it or beats it across without being hit or stopping for good.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/crossing_test.gd

const COURSE := {
	"name": "Crossing test", "theme": "orchard", "laps": 3,
	"pieces": [{"type": "straight", "length": 6}, {"type": "crossing"}, {"type": "straight", "length": 6}],
}
const DESIGN := "res://tests/data/legacy/starter.json"


class Runner:
	extends Node

	var failures := 0
	var track: TrackPath
	var crossing: LevelCrossing
	var kart: Kart
	var ai: AIDriver
	var phase := ""
	var frames := 0
	var start_time := 0.0
	var moved_from := Vector3.ZERO
	var lost_before := 0
	var hit := false
	var waited := false
	var passed_at := -1.0
	var offset := 0.0
	## [name, how long after the start the train's front reaches the road].
	var hits := [["plain", 0], ["shield", 1], ["ghost", 2], ["remote", 3]]
	var runs := [3.0, 5.0, 7.0, 9.0, 11.0, 13.0]
	## [name, metres back from the arm, speed, across the road, arms down].
	var arms := [["under", -1.2, 0.0, 2.0, true], ["late", 1.8, 5.0, 2.0, true], ["slow", 3.5, 6.0, -2.0, true], ["fast", 8.0, 20.0, -2.0, true], ["broken", 3.5, 6.0, -2.0, true], ["up", 3.5, 6.0, 2.0, false]]
	var arm_spec := []
	var top_speed := 0.0
	var pass_speed := -1.0
	var highest := -INF
	var ground_y := 0.0
	var waits := 0
	var arm_touches := 0
	var touching := false

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _ready() -> void:
		_timetable_checks()
		_course_checks()
		_clock_checks()
		track = TrackPath.from_dict(COURSE)
		var builder := TrackBuilder.new(track)
		builder.scenery = "none"
		add_child(builder)
		crossing = builder.crossings[0]
		crossing.own_clock = false
		crossing.time = -100.0
		check(builder.crossings.size() == 1, "the course has one crossing")
		check(absf(crossing.offset - (6 * TrackPiece.TILE + TrackPiece.TILE * 0.5)) < 1.5, "in the middle of its tile (%.1f m)" % crossing.offset)
		check(crossing.reach[0] >= LevelCrossing.LEAST_REACH and crossing.reach[1] == LevelCrossing.MOST_REACH, "with rails running out each side (%.0f, %.0f m)" % crossing.reach)
		_next_hit()

	func _timetable_checks() -> void:
		var a := TrainTimetable.new(1234, 0, 9.0, 100.0, 80.0)
		var b := TrainTimetable.new(1234, 0, 9.0, 100.0, 80.0)
		var same := true
		var t := -3.0
		while t < 900.0:
			var k := a.train_at(t)
			if k != b.train_at(t) or a.barriers(t) != b.barriers(t) or a.lights_on(t) != b.lights_on(t):
				same = false
			if k >= 0 and (a.head(k, t) != b.head(k, t) or a.direction(k) != b.direction(k)):
				same = false
			t += 0.37
		check(same, "the same seed and clock put the train in the same place")
		var other := TrainTimetable.new(1235, 0, 9.0, 100.0, 80.0)
		var next_one := TrainTimetable.new(1234, 1, 9.0, 100.0, 80.0)
		check(absf(other.arrival(0) - a.arrival(0)) > 0.01 and absf(next_one.arrival(0) - a.arrival(0)) > 0.01, "another seed or another crossing gets other trains")
		check(a.train_at(-3.0) < 0 and a.barriers(-3.0) == 0.0, "no train and barriers up at the countdown")
		var ok_down := true
		var ok_up := true
		var ok_apart := true
		var ok_dark := true
		var ways := {}
		for k in 15:
			var w := a.road_window(k)
			ways[a.direction(k)] = true
			if a.barriers(w.x - 0.01) != 1.0 or not a.lights_on(w.x - TrainTimetable.BARRIERS_BEFORE + 0.01):
				ok_down = false
			if a.barriers(w.x - TrainTimetable.LIGHTS_BEFORE + 0.5) != 0.0 or a.barriers(w.y) != 1.0:
				ok_down = false
			if a.barriers(w.y + TrainTimetable.OPEN_AFTER + TrainTimetable.BARRIER_SWING + 0.05) != 0.0:
				ok_up = false
			if absf(a.head(k, a.arrival(k))) > 0.001 or a.train_at(a.arrival(k)) != k:
				ok_apart = false
			# The next train only leaves its tunnel once this one's gone.
			var gone := a.arrival(k) + (a.reach_out(k) + TrainTimetable.LENGTH) / TrainTimetable.SPEED
			var out := a.arrival(k + 1) - a.reach_in(k + 1) / TrainTimetable.SPEED
			if out <= gone:
				ok_apart = false
			var between := (w.y + a.road_window(k + 1).x) * 0.5
			if a.lights_on(between) or a.train_at(between) >= 0:
				ok_dark = false
		check(ok_down, "the barriers are all the way down before every train gets to the road, and stay down")
		check(ok_up, "and go back up after it's gone")
		check(ok_apart, "one train at a time on the rails")
		check(ok_dark, "with the lights off between trains")
		check(ways.size() == 2, "trains come from both sides")

	# A client's train clock pulled towards the host's.
	func _clock_checks() -> void:
		var clock := TrainClock.new(-0.1)
		var dt := 1.0 / 60.0
		var host := 0.0
		# This device started a tenth of a second late and runs 10% slow.
		var worst_late := 0.0
		for frame in 600:
			host += dt
			clock.run(dt * 0.9)
			if frame % 3 == 0:
				clock.from_host(host - 0.03, 0.03)
			if frame >= 300:
				worst_late = maxf(worst_late, absf(host - clock.now))
		check(worst_late < 0.05, "a client's train clock keeps up with the host's (%.3f s apart at most)" % worst_late)
		clock.from_host(host + 5.0)
		clock.run(dt)
		check(absf(clock.now - (host + 5.0)) < 0.05, "and jumps when it's far out")

	func _course_checks() -> void:
		var path := TrackPath.from_dict(COURSE)
		check(path.crossing_offsets().size() == 1, "a crossing piece makes a crossing")
		var saved := path.to_dict()
		check(saved.pieces[1] == {"type": "crossing"}, "and saves as one (%s)" % [saved.pieces[1]])
		check(TrackPath.from_dict(saved).crossing_offsets() == path.crossing_offsets(), "and loads again in the same place")
		var design := CourseDesign.from_dict(COURSE)
		check(Sharing.buildable(design), "a course with a crossing can be shared")
		var old := TrackPath.load_file("res://data/tracks/peach_pit.json")
		check(old.crossing_offsets().is_empty(), "a course without one has none")
		check(CourseOutline.describe(path).contains("level crossing"), "the course list says it has a crossing")
		check(not design.problems().any(func(p): return p.contains("level crossing")), "a crossing out in the open has room")
		# A tight hairpin brings the road back a tile beside the crossing.
		var squeezed := COURSE.duplicate(true)
		squeezed.pieces = [{"type": "straight", "length": 3}, {"type": "crossing"}, {"type": "straight", "length": 3},
			{"type": "curve", "turn": "left", "size": 1}, {"type": "curve", "turn": "left", "size": 1}, {"type": "straight", "length": 8}]
		var tight := CourseDesign.from_dict(squeezed)
		check(tight.problems().any(func(p): return p.contains("level crossing")), "one with road too close beside it is a problem in the editor")
		check(not Sharing.buildable(tight), "and can't be shared")
		var up := COURSE.duplicate(true)
		up.pieces = [{"type": "straight", "length": 4}, {"type": "ramp", "length": 2, "rise": 1}, {"type": "straight", "length": 2}, {"type": "crossing"}, {"type": "straight", "length": 4}]
		var raised := CourseDesign.from_dict(up)
		check(raised.problems().any(func(p): return p.contains("ground level")), "one up a ramp is a problem in the editor")
		check(not Sharing.buildable(raised), "and can't be shared")
		var bad := []
		for file in DirAccess.get_files_at("res://data/tracks"):
			if file.ends_with(".json") and LevelCrossing.problem(TrackPath.load_file("res://data/tracks/" + file)) != "":
				bad.append(file)
		check(bad.is_empty(), "every built-in course's crossings have room %s" % [bad])

	func _spawn(at: float, across := 0.0) -> void:
		kart = Kart.new()
		kart.build(KartDesign.load_file(DESIGN))
		var where := track.place_at(at, 0.6)
		where.origin += track.right_at(at) * across
		kart.transform = where
		add_child(kart)
		crossing.karts.assign([kart])

	func _clear() -> void:
		if ai != null:
			ai.queue_free()
			ai = null
		if kart != null:
			kart.queue_free()
			kart = null
		crossing.karts.clear()

	# The train hitting a kart sat on the rails.

	func _next_hit() -> void:
		_clear()
		if hits.is_empty():
			_next_run()
			return
		var spec: Array = hits.pop_front()
		phase = spec[0]
		_spawn(crossing.offset, -2.0)
		frames = 0
		start_time = crossing.timetable.arrival(spec[1]) - 0.6
		match phase:
			"shield":
				kart.shield_left = 30.0
			"ghost":
				kart.start_ghost(30.0)
			"remote":
				kart.remote = true

	func _hit_step() -> void:
		frames += 1
		if frames == 40:
			moved_from = kart.global_position
			lost_before = kart.lost.size()
			crossing.time = start_time
		if frames <= 40:
			return
		crossing.time += get_physics_process_delta_time()
		if frames < 40 + 90:
			return
		var moved := kart.global_position.distance_to(moved_from)
		var lost := kart.lost.size() - lost_before
		match phase:
			"plain":
				check(lost == Kart.TRAIN_PARTS and moved > 6.0, "the train knocks %d parts off and shoves the kart off the rails (%d lost, %.1f m)" % [Kart.TRAIN_PARTS, lost, moved])
			"shield":
				check(lost == 0 and moved > 6.0, "a shield holds the parts on and still gets shoved (%d lost, %.1f m)" % [lost, moved])
			"ghost":
				check(lost == 0 and moved < 1.0, "a ghost goes through it (%d lost, %.1f m)" % [lost, moved])
			"remote":
				check(lost == 0 and moved < 1.0, "a remote kart is left to its own device")
		_next_hit()

	# Karts driving into the barrier arms on the way in.

	func _next_arm() -> void:
		_clear()
		if arms.is_empty():
			print("All crossing checks passed." if failures == 0 else "%d crossing checks failed." % failures)
			get_tree().quit(1 if failures > 0 else 0)
			return
		arm_spec = arms.pop_front()
		phase = "arm " + str(arm_spec[0])
		var shut := crossing.arms_shut(0)
		crossing.time = shut.x + 1.0 if arm_spec[4] else -100.0
		if arm_spec[0] == "under":
			crossing.time = shut.x - 1.5
		elif arm_spec[0] == "late":
			crossing.time = shut.x - TrainTimetable.BARRIER_SWING * 0.25 - 29.0 / 60.0
		highest = -INF
		var line := crossing.offset - LevelCrossing.BARRIER_AT
		_spawn(line - float(arm_spec[1]) - 1.2, float(arm_spec[3]))
		frames = 0
		pass_speed = -1.0
		lost_before = kart.lost.size()

	func _arm_step() -> void:
		frames += 1
		var line := crossing.offset - LevelCrossing.BARRIER_AT
		if arm_spec[0] == "under":
			_under_step()
			return
		if arm_spec[0] == "late":
			crossing.time += get_physics_process_delta_time()
		if frames < 30:
			# Settle on the wheels, then get going towards the arm.
			if frames == 29:
				ground_y = kart.global_position.y
				kart.linear_velocity = track.forward_at(line) * float(arm_spec[2])
				top_speed = kart.linear_velocity.length()
			return
		var at := track.offset_of(kart.global_position, line, 30.0)
		highest = maxf(highest, kart.global_position.y - ground_y)
		if pass_speed < 0.0 and at > line + 1.5:
			pass_speed = kart.linear_velocity.length()
		if frames < 30 + 150:
			return
		var arm: int = crossing.arms_in()[0 if float(arm_spec[3]) < 0.0 else 1]
		match arm_spec[0]:
			"late":
				check(at > line - 1.0 and highest < 0.4 and crossing.timetable.barriers(crossing.time) == 1.0, "a kart that gets under an arm coming down isn't stopped or thrown (%.1f m past, %.2f m up)" % [at - line, highest])
			"slow":
				check(crossing.arm_solid(arm) and at < line - 0.3 and kart.linear_velocity.length() < 0.5, "a slow kart stops against a barrier arm that's down (%.1f m short)" % (line - at))
			"fast":
				check(crossing.arm_broken(arm) and pass_speed > 0.0 and pass_speed < top_speed * 0.8, "a fast kart breaks the arm and slows down (%.1f m/s to %.1f)" % [top_speed, pass_speed])
				check(not crossing.arm_solid(arm) and crossing.arm_solid(crossing.arms_in()[1]), "and that arm's broken for good while the other's still solid")
			"broken":
				check(pass_speed > 0.0, "a broken arm doesn't stop karts (through at %.1f m/s)" % maxf(pass_speed, 0.0))
			"up":
				check(not crossing.arm_solid(arm) and pass_speed > 3.0, "an arm that's up doesn't stop karts (through at %.1f m/s)" % maxf(pass_speed, 0.0))
		_next_arm()

	## An arm coming down onto a kart sat under it stays out of its way.
	func _under_step() -> void:
		var arm: int = crossing.arms_in()[1]
		if frames == 30:
			moved_from = kart.global_position
		if frames > 30:
			crossing.time += get_physics_process_delta_time()
		if frames == 30 + 150:
			var moved := kart.global_position.distance_to(moved_from)
			check(crossing.timetable.barriers(crossing.time) == 1.0 and not crossing.arm_solid(arm) and moved < 0.3, "an arm coming down onto a kart doesn't shut on it or throw it (%.2f m)" % moved)
			kart.global_position -= track.forward_at(crossing.offset) * 5.0
		if frames == 30 + 155:
			check(crossing.arm_solid(arm), "and shuts once it's clear")
			kart.start_ghost(5.0)
			kart.global_position += track.forward_at(crossing.offset) * 5.0
		if frames == 30 + 160:
			check(not crossing.arm_solid(arm), "a ghost going through it turns it off till it's clear")
			_next_arm()

	# The AI coming up to the crossing with a train due.

	func _next_run() -> void:
		_clear()
		if runs.is_empty():
			check(waits >= 2, "the AI stopped for the train some of those times (%d)" % waits)
			check(arm_touches == 0, "and never ran into a barrier arm (%d times)" % arm_touches)
			_next_arm()
			return
		var due: float = runs.pop_front()
		phase = "ai %.0f" % due
		_spawn(8.0)
		ai = AIDriver.new()
		ai.kart = kart
		ai.track = track
		ai.line = 0.0
		ai.skill = 0.95
		ai.crossings.assign([crossing])
		kart.controls = ai.controls
		add_child(ai)
		offset = 8.0
		frames = 0
		hit = false
		waited = false
		passed_at = -1.0
		# The train's front gets to the road `due` seconds after it sets off.
		start_time = crossing.timetable.arrival(0) - due
		crossing.time = start_time

	func _run_step() -> void:
		var dt := get_physics_process_delta_time()
		frames += 1
		crossing.time += dt
		offset = track.offset_of(kart.global_position, offset, 40.0)
		ai.offset = offset
		ai.clock = crossing.time
		if crossing._hit_wait.has(kart):
			hit = true
		if ai._waiting:
			waited = true
		var line := crossing.offset - LevelCrossing.BARRIER_AT
		var solid := crossing.arms_in().any(func(a): return crossing.arm_solid(a))
		var near := solid and offset > line - 2.0 and offset < line + 1.0
		if near and not touching:
			arm_touches += 1
		touching = near
		if passed_at < 0.0 and offset > crossing.offset + 6.0 and offset < track.length - 20.0:
			passed_at = crossing.time
		var window := crossing.timetable.road_window(0)
		if passed_at >= 0.0 and crossing.time > passed_at + 1.0 or frames > 60 * 40:
			var late := passed_at - window.y
			check(not hit and passed_at >= 0.0 and (passed_at < window.x or late < 6.0), "%s s: the AI isn't hit and gets across (%s, %s)" % [phase, "waited" if waited else "went", "%.1f s after the train" % late if passed_at > window.x else "before it"])
			if waited:
				waits += 1
			_next_run()

	func _physics_process(_delta: float) -> void:
		if phase.begins_with("ai"):
			_run_step()
		elif phase.begins_with("arm"):
			_arm_step()
		elif phase != "":
			_hit_step()


func _initialize() -> void:
	root.add_child(Runner.new())
