extends Node

## The Settings Player tab and the kart picker with the tag colour set to
## PICK (default 2), into FOLDER. Use its own XDG_DATA_HOME, on a real screen:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/tag_colour_shots.tscn -- FOLDER [PICK]


func _shoot(path: String) -> void:
	for i in 4:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if not args.is_empty() else "res://build/shots"
	DirAccess.make_dir_recursive_absolute(folder)
	get_window().mode = Window.MODE_WINDOWED
	for i in 5:
		await get_tree().process_frame
	get_window().size = Vector2i(1280, 720)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	for i in 10:
		await get_tree().process_frame
	Game.set_tag_pick(int(args[1]) if args.size() > 1 else 2)
	Game.show_settings()
	Game._screen._show_tab(0)
	await get_tree().create_timer(1.0).timeout
	await _shoot(folder + "/tag_settings.png")
	for node in Game._screen.find_children("*", "Button", true, false):
		if node.has_meta("pick") and node.get_meta("pick") == (int(args[1]) + 1) % 8 if args.size() > 1 else node.has_meta("pick") and node.get_meta("pick") == 3:
			node.grab_focus()
	await get_tree().create_timer(0.5).timeout
	await _shoot(folder + "/tag_settings_focus.png")
	Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true, 1))
	await get_tree().create_timer(1.0).timeout
	await _shoot(folder + "/tag_kart_picker.png")
	get_tree().quit()
