extends Node

## Pictures of a seaside course in the track editor: the whole course, and
## lower views across it from two sides. Give it a course file after --. Run
## it with its own XDG_DATA_HOME so the editor's autosave stays out of your
## profile:
##   XDG_DATA_HOME=build/creations/shots DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 1600x720 res://tools/shots/beach_shots.tscn -- res://data/tracks/coral_cove.json
## They're saved in /srv/downloads/temp/debug/snapracers/beach, named after
## the file.

const OUT := "/srv/downloads/temp/debug/snapracers/beach"
var host: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	var args := OS.get_cmdline_user_args()
	var from: String = args[0] if not args.is_empty() else "res://data/tracks/coral_cove.json"
	var name := "editor_" + from.get_file().get_basename()
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
	editor.load_course(from)
	editor.fit_view()
	await _shot(name)
	editor._pitch = deg_to_rad(-22.0)
	editor._yaw = deg_to_rad(35.0)
	editor._distance *= 0.6
	editor._place_camera()
	await _shot(name + "_low")
	editor._yaw = deg_to_rad(215.0)
	editor._place_camera()
	await _shot(name + "_low_back")
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
