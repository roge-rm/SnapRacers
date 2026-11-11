extends Node

## Takes one still of a race into art/ui/menu_race.jpg. The menu window uses
## art/ui/menu_races/<id>.jpg from tools/shots/menu_stills.tscn instead.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/menu_still.tscn
## After `--`, a course name picks the course and a number how many frames
## it drives first.

const OUT := "res://art/ui/menu_race.jpg"
const SIZE := Vector2i(1600, 900)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "windsurf_way"
	var wait := int(args[1]) if args.size() > 1 else 1100
	get_window().mode = Window.MODE_WINDOWED
	await frames(5)
	get_window().size = SIZE
	await frames(10)
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
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	await frames(wait)
	for layer in race.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	picture.save_jpg(ProjectSettings.globalize_path(OUT), 0.88)
	print("saved ", OUT, " ", picture.get_size())
	get_tree().quit()
