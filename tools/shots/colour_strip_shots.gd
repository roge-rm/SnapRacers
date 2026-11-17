extends Node

## Takes the driver screen with a piece picked (hair, then clothes) at several
## landscape sizes, saved where the argument says. Needs a screen:
##   XDG_DATA_HOME=$PWD/build/colours-profile DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/colour_strip_shots.tscn -- /some/folder

var OUT := "res://build/shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_driver()
	var builder: Node = null
	while builder == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child.get_script() != null and child.get_script().get_global_name() == "DriverBuilder":
				builder = child
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	for size in [Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(800, 450)]:
		window.size = size
		await get_tree().create_timer(1.0).timeout
		for slot in ["hair", "torso"]:
			builder.ui.show_slot(slot)
			await get_tree().create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%dx%d.png" % [OUT, slot, size.x, size.y])
			var colours: Rect2 = builder.ui._colours.get_global_rect()
			var overlap := colours.intersects(builder.ui._bottom.get_global_rect())
			print(slot, " ", size, " colours ", colours, " bottom ", builder.ui._bottom.get_global_rect(), " overlap ", overlap)
	get_tree().quit()
