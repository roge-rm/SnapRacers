extends Node

## Pictures of the kart picker: with no saved karts, with some, scrolled to
## the stock karts, and player 1 and 2 of two, at 1280x720 and 960x540, into
## FOLDER.
## Run it with its own XDG_DATA_HOME, on a real screen:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/kart_picker_shots.tscn -- FOLDER

const SIZES := {"": Vector2i(1280, 720), "_narrow": Vector2i(960, 540)}
const SAVED := [["Red Rocket", 0], ["Mud Hopper", 4], ["Night Owl", 8]]

var _folder := "res://build/shots"
var host: Node


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_folder = args[0]
	DirAccess.make_dir_recursive_absolute(_folder)
	get_window().mode = Window.MODE_WINDOWED
	await frames(5)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await frames(10)
	Game.settings.set_value("race", "driver", "stock:brickley")
	Game.set_kart_choice(Game.OWN_KART)
	for path in KartDesign.saved_paths():
		DirAccess.remove_absolute(path)
	for suffix in SIZES:
		get_window().size = SIZES[suffix]
		await frames(10)
		Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true))
		await _shoot("kart_none" + suffix)
	var stock := Game.stock_keys()
	for entry in SAVED:
		var kart := Game.stock_kart(stock[entry[1] % stock.size()])
		kart.name = entry[0]
		kart.save()
	for suffix in SIZES:
		get_window().size = SIZES[suffix]
		await frames(10)
		Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true))
		await _shoot("kart_some" + suffix)
		await _scroll_to("STOCK KARTS")
		await _shoot("kart_some_stock" + suffix)
		Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, true, 1))
		await _shoot("kart_two_p1" + suffix)
		Game._swap(KartPicker.new(Game.show_menu, Game.show_menu, false, 2))
		await _shoot("kart_two_p2" + suffix)
	get_tree().quit()


## Scrolls the page so the heading with this text is at the top.
func _scroll_to(text: String) -> void:
	var scroll: ScrollContainer = get_tree().root.find_children("*", "ScrollContainer", true, false)[0]
	for label in get_tree().root.find_children("*", "Label", true, false):
		if label.text.to_upper() == text and label.is_visible_in_tree():
			scroll.scroll_vertical = int(label.global_position.y - scroll.global_position.y + scroll.scroll_vertical - 8)
			break
	await frames(5)


func _shoot(which: String) -> void:
	for i in 900:
		await get_tree().process_frame
		var busy := false
		for node in get_tree().root.find_children("*", "KartThumbnails", true, false):
			busy = busy or node.is_processing()
		if i >= 10 and not busy:
			break
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	picture.save_png("%s/%s.png" % [_folder, which])
	print("saved ", which, " ", picture.get_size())
