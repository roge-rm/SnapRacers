extends Node

## Takes the Settings screen into FOLDER as settings.png, on the Player tab or
## on TAB (0 to 3), in a window WIDTH x HEIGHT (1280 x 720 if left out).
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/settings_shot.tscn -- FOLDER [TAB [WIDTH HEIGHT]]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if not args.is_empty() else "res://build/shots"
	DirAccess.make_dir_recursive_absolute(folder)
	var tab: int = int(args[1]) if args.size() > 1 else 0
	var size := Vector2i(int(args[2]), int(args[3])) if args.size() > 3 else Vector2i(1280, 720)
	get_window().mode = Window.MODE_WINDOWED
	for i in 5:
		await get_tree().process_frame
	get_window().size = size
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	for i in 10:
		await get_tree().process_frame
	Game.show_settings()
	Game._screen._show_tab(tab)
	await get_tree().create_timer(1.0).timeout
	for i in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/settings.png")
	get_tree().quit()
