extends Node

## A video of an AI race for judging how the AI drives. Your kart is driven
## by the AI too, and the camera follows the kart that started fourth, from
## far behind and then on the TV cameras. The course is a name in
## data/tracks or a res:// path. Run it with --write-movie; it prints
## the movie frame where the clip should start, and quits at the end.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --fixed-fps 30 --write-movie build/clip.avi res://tools/shots/ai_clip.tscn -- hairpin_hall normal [follow slot] [chase seconds] [tv seconds]

## Race time the clip starts at, a few seconds after the green light.
const FROM := 3.0
const BUSY_HOLD := 6.0
const BUSY_NEAR := 20.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "hairpin_hall"
	var level: String = args[1] if args.size() > 1 else "normal"
	# "slip" follows whichever kart is slipstreaming, and logs it.
	# "log5" follows the kart in slot 5 and logs the same way.
	# "busy" follows whichever kart has the most karts close round it,
	# looking again every BUSY_HOLD seconds.
	var busy := args.size() > 2 and args[2] == "busy"
	if busy:
		args[2] = "3"
	var slip := args.size() > 2 and (args[2] == "slip" or args[2].begins_with("log"))
	var hold := args.size() > 2 and args[2].begins_with("log")
	var follow := int(args[2].trim_prefix("log")) if hold else (3 if slip or args.size() <= 2 else int(args[2]))
	var chase := float(args[3]) if args.size() > 3 else 38.0
	var tv := float(args[4]) if args.size() > 4 else 14.0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	seed(1)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	Game.settings.set_value("race", "mirrored", false)
	Game.settings.set_value("race", "reversed", false)
	Game.settings.set_value("race", "difficulty", level)
	Game.racing_alone = true
	seed(1)
	Game.show_race(course if course.begins_with("res://") else Game.TRACKS + "/" + course + ".json")
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
	var target: Kart = race.racers[follow].kart
	print("CLIP field: ", race.racers.map(func(r): return r.name))
	print("CLIP following: ", race.racers[follow].name)
	race.camera.target = target
	race.camera.set_view("far")
	while race.time < FROM:
		await get_tree().process_frame
	print("CLIP_START_FRAME ", Engine.get_frames_drawn())
	var quiet := 0.0
	var place := 0
	var logged := 0.0
	var picked := -INF
	while race.time < FROM + chase:
		await get_tree().process_frame
		if busy and race.time - picked > BUSY_HOLD:
			picked = race.time
			var most := -1
			for racer in race.racers:
				var near := race.racers.filter(func(other): return other != racer and absf(other.progress.distance() - racer.progress.distance()) < BUSY_NEAR).size()
				if near > most:
					most = near
					target = racer.kart
			race.camera.target = target
			print("BUSY t=%.1f following %s with %d close" % [race.time, race.racers.filter(func(r): return r.kart == target)[0].name, most])
		if not slip:
			continue
		quiet = quiet + get_process_delta_time() if target.slipstream < 0.05 else 0.0
		if quiet > 1.0 and not hold:
			for racer in race.racers:
				if racer.kart.slipstream > 0.08 and racer.kart.slipstream > target.slipstream:
					target = racer.kart
					race.camera.target = target
					quiet = 0.0
		for racer in race.racers:
			if racer.kart == target and race.place_of(racer) != place:
				print("PASS t=%.1f frame=%d %s %d -> %d" % [race.time, Engine.get_frames_drawn(), racer.name, place, race.place_of(racer)])
				place = race.place_of(racer)
		if race.time - logged >= 0.5:
			logged = race.time
			print("ORDER t=%.1f %s" % [race.time, race.standings().map(func(r): return r.name)])
			for racer in race.racers:
				if racer.kart.slipstream > 0.05:
					print("SLIP t=%.1f frame=%d %s %.2f place %d%s" % [race.time, Engine.get_frames_drawn(), racer.name, racer.kart.slipstream, race.place_of(racer), " *" if racer.kart == target else ""])
	race.camera.set_view("tv")
	while race.time < FROM + chase + tv:
		await get_tree().process_frame
	print("CLIP_END_FRAME ", Engine.get_frames_drawn())
	get_tree().quit()
