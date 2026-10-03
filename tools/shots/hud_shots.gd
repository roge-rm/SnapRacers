extends Node

## Takes a picture of the race screen with everything it can show at once: a
## lap time just done, a quick note, and the slowdown after a reset. Name the
## clock's place after the course: top, right or corner (see RaceHud.clock_at).
## It needs a screen, and saves in build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/hud_shots.tscn -- hairpin_hall top

const OUT := "res://build/shots"


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "hairpin_hall"
	RaceHud.clock_at = args[1] if args.size() > 1 else "right"
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.racing_alone = true
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await frames(10)
	var kart := race.player.kart
	var driver := AIDriver.new()
	driver.kart = kart
	driver.track = race.track
	race.add_child(driver)
	race.player.ai = driver
	kart.controls = driver.controls
	await frames(600)
	race.player.progress.lap_times.append(58.42)
	kart.slowdown_left = Kart.RESET_SLOWDOWN_TIME * 0.6
	race.player.hud.flash("Chase camera")
	await frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/hud_%s.png" % [OUT, RaceHud.clock_at])
	print("saved ", RaceHud.clock_at)
	get_tree().quit()
