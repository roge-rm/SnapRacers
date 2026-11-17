extends Node

## Takes the driver screen (hair, then torso picked) and the garage (painting,
## a part picked) at three landscape sizes, with the colour drawer open and,
## where there is one, closed. Saved where the argument says. Needs a screen:
##   XDG_DATA_HOME=$PWD/build/colours-profile DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/colour_drawer_shots.tscn -- /some/folder

var OUT := "res://build/shots"
const SIZES := [Vector2i(2340, 1080), Vector2i(1280, 720), Vector2i(800, 450)]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	Game.show_driver()
	var builder: Node = await _screen(host, "DriverBuilder")
	for size in SIZES:
		window.size = size
		await get_tree().create_timer(1.0).timeout
		for slot in ["hair", "torso"]:
			builder.ui.show_slot(slot)
			await _shots(builder.ui, "driver_%s_%dx%d" % [slot, size.x, size.y])
	Game.show_garage()
	var garage: Node = await _screen(host, "Garage")
	await get_tree().create_timer(1.0).timeout
	garage.set_painting(true)
	for child in garage.get_children():
		if child is GaragePad:
			child.hop(Vector2.ZERO)
	for size in SIZES:
		window.size = size
		await get_tree().create_timer(1.0).timeout
		await _shots(garage.ui, "garage_paint_%dx%d" % [size.x, size.y])
	get_tree().quit()


func _screen(host: Node, kind: String) -> Node:
	while true:
		await get_tree().process_frame
		for child in host.get_children():
			if child.get_script() != null and child.get_script().get_global_name() == kind:
				return child
	return null


## One shot as it is, and one with the colour drawer put away if it has one.
func _shots(ui: Control, name: String) -> void:
	var drawer: Variant = null
	for key in ["_colours", "_painting"]:
		if ui.get(key) is ColourDrawer:
			drawer = ui.get(key)
	if drawer != null:
		drawer.set_open(true)
	await _save(name + ("_open" if drawer != null else ""))
	_report(ui, name)
	if drawer != null:
		drawer.set_open(false)
		await _save(name + "_closed")
		_report(ui, name + "_closed")
		drawer.set_open(true)


func _save(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])


## Prints where each panel is and any two that overlap.
func _report(ui: Control, name: String) -> void:
	var panels := {}
	for key in ["_toolbar", "_drawer", "_drawer_handle", "_chip", "_stats_chip", "_colours", "_painting", "_bottom"]:
		var panel: Variant = ui.get(key)
		if panel is Control and panel.is_visible_in_tree():
			panels[key] = panel.get_global_rect()
		if panel is ColourDrawer and panel.handle.is_visible_in_tree():
			panels["colour handle"] = panel.handle.get_global_rect()
	var clashes := []
	var keys := panels.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if panels[keys[i]].intersects(panels[keys[j]]):
				clashes.append("%s/%s" % [keys[i], keys[j]])
	print(name, " ", panels, " overlaps: ", clashes)
