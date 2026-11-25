extends Node

## Pictures of the race as the player sees it, with the AI driving, in the
## weather and at the time of day asked for. It needs a screen, and saves in
## build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/race_shots.tscn -- peach_pit rain night [name] [seconds ...]
## SHOT_SIZE=2340x1080 takes them at that size instead of 1280 x 720.

const OUT := "res://build/shots"
## When to take them, in seconds of race time.
const AT := [8.0, 20.0, 35.0]

var host: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "peach_pit"
	var weather: String = args[1] if args.size() > 1 else "rain"
	var time: String = args[2] if args.size() > 2 else "night"
	var name: String = args[3] if args.size() > 3 else "%s_%s_%s" % [course.get_file().get_basename(), weather, time]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_size())
	seed(int(OS.get_environment("SEED")) if OS.has_environment("SEED") else 1)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	# GRAPHICS=ultra takes them at that graphics level.
	if OS.has_environment("GRAPHICS"):
		Game.set_graphics(OS.get_environment("GRAPHICS"))
	# KART=redline DRIVER=hattie picks a stock kart and roster driver for the player.
	if OS.has_environment("KART"):
		Game.settings.set_value("race", "kart", OS.get_environment("KART"))
	if OS.has_environment("DRIVER"):
		Game.character = Game.roster_driver(OS.get_environment("DRIVER")).duplicate_design()
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("controls", "player_1", "buttons")
	Game.settings.set_value("race", "weather", weather)
	Game.settings.set_value("race", "time", time)
	Game.racing_alone = true
	# A path to a course file works too.
	Game.show_race(course if course.contains("/") else Game.TRACKS + "/" + course + ".json")
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
	# On a computer the touch controls wait for a touch, so show them like on a phone.
	race.player.hud.touch.visible = true
	# BUILD_UP=1 shows the rain or snow as it is by the end of the race.
	if OS.has_environment("BUILD_UP"):
		race.build_up = float(OS.get_environment("BUILD_UP"))
	DirAccess.make_dir_recursive_absolute(OUT)
	var moments: Array = AT if args.size() <= 4 else Array(args.slice(4)).map(func(value): return float(value))
	for i in moments.size():
		while race.time < moments[i]:
			await get_tree().process_frame
		# Also works with --disable-render-loop for fast software-rendered shots.
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
		# On a big screen the window can come out bigger than asked; the UI
		# scales with it, so a smaller copy looks the same as 1280 x 720.
		var picture := get_viewport().get_texture().get_image()
		if picture.get_size() != _size():
			picture.resize(_size().x, _size().y, Image.INTERPOLATE_LANCZOS)
		picture.save_png("%s/race_%s_%d.png" % [OUT, name, i + 1])
	print("saved race_%s" % name)
	get_tree().quit()


func _size() -> Vector2i:
	if OS.has_environment("SHOT_SIZE"):
		var n := OS.get_environment("SHOT_SIZE").split("x")
		return Vector2i(int(n[0]), int(n[1]))
	return Vector2i(1280, 720)
