extends Node

## Takes a still of each shipped course for the main menu window, into
## art/ui/menu_races/<id>.jpg. A real race with an AI driving, HUD hidden.
## Needs the computer's own display:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/menu_stills.tscn
## After `--`, a course id shoots only that one. `force` overwrites stills
## that are already there.

const OUT := "res://art/ui/menu_races"
const SIZE := Vector2i(1280, 720)
const QUALITY := 0.85

var _karts: Array[String] = []


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func next_kart() -> String:
	if _karts.is_empty():
		_karts = Game.stock_keys()
		_karts.shuffle()
	return _karts.pop_back()


func _ready() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var force := args.has("force")
	args = args.filter(func(a): return a != "force")
	var ids: Array = Tracks.all() if args.is_empty() else args
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().mode = Window.MODE_WINDOWED
	await frames(5)
	get_window().size = SIZE
	await frames(10)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Sounds.hushed = true
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.set_weather("clear")
	Game.set_time_of_day("day")
	Game.racing_alone = true
	var done := 0
	for id in ids:
		id = str(id)
		var dest := "%s/%s.jpg" % [OUT, id]
		if not force and FileAccess.file_exists(dest):
			print("skip ", id)
			continue
		await shoot(id, dest)
		done += 1
	print("saved %d stills" % done)
	get_tree().quit()


func shoot(id: String, dest: String) -> void:
	var kart := next_kart()
	Game.set_kart_choice(kart)
	seed(id.hash())
	print("shoot ", id, " in ", kart)
	await Game.show_race(Tracks.path_of(id))
	var race := Game._screen as Race
	if race == null or not is_instance_valid(race):
		push_error("no race for %s" % id)
		return
	while is_instance_valid(race) and not race.started:
		await frames(5)
	if not is_instance_valid(race):
		push_error("race freed for %s" % id)
		return
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	for racer in race.racers:
		if racer.kart != driver.kart:
			driver.others.append(racer.kart)
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	var wait := 360 + absi(id.hash()) % 360
	await frames(wait)
	if not is_instance_valid(race):
		push_error("race freed for %s" % id)
		return
	for layer in race.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	if picture.get_size() != SIZE:
		picture.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	picture.save_jpg(ProjectSettings.globalize_path(dest), QUALITY)
	print("saved ", dest, " ", picture.get_size(), " after ", wait, " frames in ", kart)
