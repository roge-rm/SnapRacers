extends Node

## Pictures of the colour palettes: the garage's with Recent, its More colours
## grid and custom picker, the same in a 960x540 window, and the driver
## screen's skin and hair and its picker. Needs a screen, and sets
## Recent, so run it with its own XDG_DATA_HOME. Saved where the argument says.
##   XDG_DATA_HOME=$PWD/build/colours-profile DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/colour_shots.tscn -- /some/folder

var OUT := "res://build/shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	Game.set_setting("paint", "recent", [])
	for hex in ["#3a8dde", "#e5534b", "#4fb35f", "#f39a4c", "#9a6fd6"]:
		ColourPalette.remember(Color(hex))
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_garage()
	var garage: Garage = await _screen(host, "Garage")
	await get_tree().create_timer(2.0).timeout
	garage.set_painting(true)
	await _save("garage_palette")
	garage.ui._palette.open_more()
	await _save("garage_more_colours")
	garage.ui._palette.close_more()
	garage.ui._palette.open_picker()
	await _save("garage_picker")
	garage.ui._palette.close_picker()
	var window := get_window()
	var big := window.size
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(960, 540)
	await get_tree().create_timer(1.0).timeout
	await _save("garage_palette_small")
	garage.ui._palette.open_more()
	await _save("garage_more_colours_small")
	garage.ui._palette.close_more()
	garage.ui._palette.open_picker()
	await _save("garage_picker_small")
	garage.ui._palette.close_picker()
	window.size = big
	await get_tree().create_timer(1.0).timeout
	Game.show_driver()
	var builder: Node = await _screen(host, "DriverBuilder")
	await get_tree().create_timer(2.0).timeout
	builder.ui.show_slot("head")
	await _save("driver_skin")
	builder.ui.show_slot("hair")
	await _save("driver_hair")
	builder.ui.show_slot("torso")
	await _save("driver_clothes")
	builder.ui._swatches.open_more()
	await _save("driver_more_colours")
	builder.ui._swatches.close_more()
	builder.ui._swatches.open_picker()
	await _save("driver_picker")
	get_tree().quit()


func _screen(host: Node, type: String) -> Node:
	while true:
		await get_tree().process_frame
		for child in host.get_children():
			if child.get_script() != null and child.get_script().get_global_name() == type:
				return child
	return null


func _save(name: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
