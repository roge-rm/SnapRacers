extends Node

## Pictures of the selected piece panel with its Rise, Bank, Height and Length
## rows. Run it with its own XDG_DATA_HOME, once for each size (the 800 by 450 one with `-- small`):
##   XDG_DATA_HOME=build/creations/shots DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 800x450 res://tools/shots/editor_gap_shots.tscn [-- small]
## They're saved in /srv/downloads/temp/debug/snapracers/editor-gaps.

const OUT := "/srv/downloads/temp/debug/snapracers/editor-gaps"
var host: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	if "small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(800, 450)
		get_window().content_scale_size = Vector2i(800, 450)
		await get_tree().process_frame
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_track_editor()
	var editor: TrackEditor = null
	while editor == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is TrackEditor:
				editor = child
	editor.load_course("res://tests/data/split_course.json")
	await get_tree().process_frame
	var size := "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	var first := editor.course.pieces.size()
	editor.course.pieces.append({"type": "arc", "angle": 45, "turn": "left", "size": 3, "rise": 1, "bank": 22})
	editor.course.pieces.append({"type": "crest", "length": 3, "height": 3.0})
	editor.course.pieces.append({"type": "slant", "turn": "right", "length": 4, "across": 2, "rise": 2})
	editor._refresh()
	for pick in [["bend", first], ["hump", first + 1], ["offset", first + 2]]:
		editor._select(pick[1])
		await _shot("%s_%s" % [pick[0], size])
		print(size, " ", pick[0], " panel ", editor.ui._actions.get_global_rect())
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
