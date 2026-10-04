extends Node

## Times a race's work each frame, to see what a slow phone or the web would
## struggle with. It races eight AI karts on a course for a while (or one on
## its own with "alone") and prints the game's time a frame and each physics
## step, and the real time a frame took.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/perf/race_perf.tscn -- peach_pit [alone] [weather=rain] [time=night]

const WARM_UP := 300
const MEASURE := 600

var host: Node


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "peach_pit"
	Game.racing_alone = true
	if args.size() > 1 and args[1] == "alone":
		Game.mode = Game.MODE_TIME_TRIAL
	# weather= and time= race in those (see Conditions).
	for arg in args:
		if arg.begins_with("weather=") or arg.begins_with("time="):
			var parts: PackedStringArray = arg.split("=")
			Game.settings.set_value("race", parts[0], parts[1])
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	while not race.started:
		await get_tree().process_frame
	for i in WARM_UP:
		await get_tree().physics_frame
	var process := 0.0
	var physics := 0.0
	var frames := 0
	var start := Time.get_ticks_usec()
	for i in MEASURE:
		await get_tree().process_frame
		process += Performance.get_monitor(Performance.TIME_PROCESS)
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		frames += 1
	var wall := (Time.get_ticks_usec() - start) / 1000.0 / frames
	print("PERF %s: process %.2f ms, physics %.2f ms a frame, %.2f ms of real time a frame, %d bodies active" % [course, process * 1000.0 / frames, physics * 1000.0 / frames, wall, Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	get_tree().quit()
