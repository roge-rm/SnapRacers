extends Node

## Times a top AI driver (see Difficulty, Expert) round the tight courses, with
## and without sliding round the tightest bends, to see whether sliding saves
## time and how tight a bend should be to slide round. Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/slide_bench.tscn -- <bend> <kick> [kart] [course ...]
## A bend of 0 means no sliding at all, and kick is how long the AI holds
## the brake to start a slide (see AIDriver). It prints each course's time, and the
## total, on the last line.

const COURSES := ["hairpin_hall", "windsurf_way", "blue_lagoon", "bucketwheel_bend"]
const LAPS := 2
const GIVE_UP := 400.0

var host: Node
var _last: Race


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	var args := OS.get_cmdline_user_args()
	var bend := float(args[0]) if args.size() > 0 else 0.0
	var time := float(args[1]) if args.size() > 1 else 0.45
	# SLIDE_CORNER and SLIDE_SCRUB try other kinds of slide (see Kart).
	if OS.has_environment("SLIDE_CORNER"):
		Kart.slide_corner = float(OS.get_environment("SLIDE_CORNER"))
	if OS.has_environment("SLIDE_SCRUB"):
		Kart.slide_scrub = float(OS.get_environment("SLIDE_SCRUB"))
	if OS.has_environment("SLIDE_PLAN"):
		AIDriver.slide_plan = float(OS.get_environment("SLIDE_PLAN"))
	var kart: String = args[2] if args.size() > 2 else "starter"
	var courses: Array = args.slice(3) if args.size() > 3 else COURSES
	AIDriver.slide_bend = bend if bend > 0.0 else 99.0
	AIDriver.slide_time = time
	var total := 0.0
	var slides := 0
	for course in courses:
		var result: Array = await _time(kart, course, bend > 0.0)
		total += result[0]
		slides += result[2]
		print("%-16s %.2f s, %d resets, %d slides" % [course, result[0], result[1], result[2]])
	print("TOTAL bend %.3f kick %.2f %s, corner %.2f scrub %.2f plan %.2f: %.2f s, %d slides" % [bend, time, kart, Kart.slide_corner, Kart.slide_scrub, AIDriver.slide_plan, total, slides])
	get_tree().quit()


## Two laps, as [time, resets, how many slides].
func _time(key: String, course: String, sliding: bool) -> Array:
	Game.settings.set_value("race", "kart", key)
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
	driver.skill = 0.99
	driver.slides = sliding
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	var resets := [0]
	race.player.kart.was_reset.connect(func() -> void: resets[0] += 1)
	var slides := 0
	var was_sliding := false
	while race.player.progress.lap_times.size() < LAPS and race.time < GIVE_UP:
		await get_tree().physics_frame
		if race.player.kart.sliding and not was_sliding:
			slides += 1
		# LAP_TRACE prints where it is and how fast every half second, to
		# compare runs.
		if OS.has_environment("LAP_TRACE") and Engine.get_physics_frames() % 30 == 0:
			print("    LAP %.1f %.0f %.1f %s" % [race.time, race.player.offset, race.player.kart.linear_velocity.length(), race.player.kart.sliding])
		# SLIDE_TRACE prints how each slide goes, ten times a second.
		var k := race.player.kart
		if OS.has_environment("SLIDE_TRACE") and (k.sliding or was_sliding) and Engine.get_physics_frames() % 6 == 0:
			var off_line := (k.global_position - race.track.point_at(race.player.offset)).dot(race.track.right_at(race.player.offset))
			print("    %.0f m: %.1f m/s, %s, steer %+.2f, bend %.3f, %+.1f m across, tail %.0f" % [race.player.offset, k.linear_velocity.length(), "kick" if k.slide_kick else ("held" if k.sliding else "out"), k.controls.steer, race.track.bend_at(race.player.offset), off_line, rad_to_deg((-k.global_basis.z).signed_angle_to(k.linear_velocity, k.global_basis.y))])
		was_sliding = race.player.kart.sliding
	var laps: Array = race.player.progress.lap_times.slice(0, LAPS)
	var total: float = laps.reduce(func(a, b): return a + b, 0.0) if laps.size() >= LAPS else GIVE_UP * 2.0
	return [total, resets[0], slides]
