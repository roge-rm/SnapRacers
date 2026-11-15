extends Node

## Times the kart picker: how long it takes to open and how long until every
## card has its picture, on a first visit, a second visit and after picking
## another driver. It needs a screen. To see a first launch, give it an empty
## data folder. Give it a file name to save a picture of the first visit,
## and "splash" to start with the splash, which gets the pictures ready.
##   XDG_DATA_HOME=<empty folder> DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --rendering-driver opengl3 --path . res://tools/perf/picker_perf.tscn [-- picture.png] [splash]

var host: Node


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	host = Node.new()
	add_child(host)
	var args := Array(OS.get_cmdline_user_args())
	var from := Time.get_ticks_msec()
	Game.start(host, args.has("splash"))
	while not Game._screen is MainMenu:
		await get_tree().process_frame
	print("menu up after %d ms" % (Time.get_ticks_msec() - from))
	for i in 10:
		await get_tree().process_frame
	await _visit("first visit")
	var shot: Array = args.filter(func(arg: String) -> bool: return arg.ends_with(".png"))
	if not shot.is_empty():
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot[0])
	Game.show_menu()
	for i in 10:
		await get_tree().process_frame
	await _visit("second visit")
	var picker := Game._screen as KartPicker
	var other := "stock:brickley" if Game.driver_choice() != "stock:brickley" else "stock:fizz"
	var picked_at := Time.get_ticks_msec()
	picker.pick_driver(other)
	await _all_in(picker, picked_at, "other driver")
	get_tree().quit()


func _visit(what: String) -> void:
	var from := Time.get_ticks_msec()
	Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true))
	var picker := Game._screen as KartPicker
	await get_tree().process_frame
	print("%s: opened in %d ms" % [what, Time.get_ticks_msec() - from])
	await _all_in(picker, from, what)


func _all_in(picker: KartPicker, from: int, what: String) -> void:
	var longest := 0
	var last := Time.get_ticks_msec()
	var frames := 0
	while true:
		await get_tree().process_frame
		frames += 1
		var now := Time.get_ticks_msec()
		longest = maxi(longest, now - last)
		last = now
		var missing := 0
		for key in picker._cards:
			if KartThumbnails.picture(key + picker._look) == null:
				missing += 1
		if missing == 0 or now - from > 120000:
			break
	print("%s: %d pictures in after %d ms, %d frames, longest frame %d ms" % [what, picker._cards.size(), Time.get_ticks_msec() - from, frames, longest])
