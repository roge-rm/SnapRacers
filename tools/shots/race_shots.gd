extends Node

## Pictures of the race as the player sees it, with the AI driving, in the
## weather and at the time of day asked for. It needs a screen, and saves in
## build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/race_shots.tscn -- peach_pit rain night [name]

const OUT := "res://build/shots"
## When to take them, in seconds of race time.
const AT := [8.0, 20.0, 35.0]

var host: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "peach_pit"
	var weather: String = args[1] if args.size() > 1 else "rain"
	var time: String = args[2] if args.size() > 2 else "night"
	var name: String = args[3] if args.size() > 3 else "%s_%s_%s" % [course, weather, time]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	seed(1)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", weather)
	Game.settings.set_value("race", "time", time)
	Game.racing_alone = true
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
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in AT.size():
		while race.time < AT[i]:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/race_%s_%d.png" % [OUT, name, i + 1])
	print("saved race_%s" % name)
	get_tree().quit()
