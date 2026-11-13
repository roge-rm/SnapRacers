extends Node

## Takes the Settings screen (Player tab) into FOLDER as settings.png.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/settings_shot.tscn -- FOLDER

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if not args.is_empty() else "res://build/shots"
	DirAccess.make_dir_recursive_absolute(folder)
	get_window().size = Vector2i(1280, 720)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	for i in 10:
		await get_tree().process_frame
	Game.show_settings()
	await get_tree().create_timer(1.0).timeout
	for i in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/settings.png")
	get_tree().quit()
