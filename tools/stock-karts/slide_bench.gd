extends Node

## Times a top AI driver (see Difficulty, Expert) round the tight courses, with
## and without sliding round the tightest bends, to see whether sliding saves
## time and how tight a bend should be to slide round. Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/slide_bench.tscn -- <bend> <time> [brake|turn] [kart] [course ...]
## A bend of 0 means no sliding at all. "brake" slides instead of braking for
## the bend, and "turn" brakes as usual and flicks into a slide at the turn in
## (see AIDriver.slide_mode). It prints each course's time, and the
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
	AIDriver.slide_mode = args[2] if args.size() > 2 else "brake"
	var kart: String = args[3] if args.size() > 3 else "starter"
	var courses: Array = args.slice(4) if args.size() > 4 else COURSES
	AIDriver.slide_bend = bend if bend > 0.0 else 99.0
	AIDriver.slide_time = time
	var total := 0.0
	var slides := 0
	for course in courses:
		var result: Array = await _time(kart, course, bend > 0.0)
		total += result[0]
		slides += result[2]
		print("%-16s %.2f s, %d resets, %d slides" % [course, result[0], result[1], result[2]])
	print("TOTAL bend %.3f time %.2f %s %s: %.2f s, %d slides" % [bend, time, AIDriver.slide_mode, kart, total, slides])
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
		was_sliding = race.player.kart.sliding
	var laps: Array = race.player.progress.lap_times.slice(0, LAPS)
	var total: float = laps.reduce(func(a, b): return a + b, 0.0) if laps.size() >= LAPS else GIVE_UP * 2.0
	return [total, resets[0], slides]
