extends Node

## A picture of the track editor's Paint tab with a lake and a lava pit
## painted beside Peach Pit, a stroke being dragged, and the same with red
## squares under the brush. Run it with its own XDG_DATA_HOME so the editor's
## autosave stays out of your profile:
##   XDG_DATA_HOME=/tmp/x DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 1280x720 res://tools/shots/editor_paint_shots.tscn
## Pictures go in /srv/downloads/temp/debug/snapracers/0.16/paint/m3.

const OUT := "/srv/downloads/temp/debug/snapracers/0.16/paint/m3"
var host: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var size := DisplayServer.window_get_size()
	var tag := "%dx%d" % [size.x, size.y]
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
	editor.load_course(Tracks.path_of("peach_pit"))
	await _frames(30)
	var ui := editor.ui
	ui._show_category(TrackEditorUI.CATEGORIES.size() + 1)
	# A lake and a lava pit on the open side of the course.
	var box := AABB(editor.track.points[0], Vector3.ZERO)
	for p in editor.track.points:
		box = box.expand(p)
	var middle := box.get_center()
	var lake := Vector3(box.position.x - 70.0, 0.0, middle.z)
	var pit := Vector3(box.end.x + 70.0, 0.0, middle.z)
	ui.paint_brush = 3
	ui.paint_type = "water"
	_stroke(editor, lake, Vector3(0, 0, 70))
	_stroke(editor, lake + Vector3(24, 0, 0), Vector3(0, 0, 70))
	ui.paint_type = "lava"
	_stroke(editor, pit, Vector3(0, 0, 50))
	_stroke(editor, pit + Vector3(24, 0, 0), Vector3(0, 0, 50))
	ui.paint_type = "water"
	editor._camera.global_position = editor._camera.global_position
	editor.fit_view()
	await _frames(120)
	editor.move_brush(editor.track.points[10])
	await _frames(5)
	await _save("paint_tab_%s" % tag)
	# Mid stroke: the flat squares, before the smooth ground is built.
	ui.paint_type = "lava"
	editor.paint_begin(pit + Vector3(48, 0, 0))
	editor.paint_to(pit + Vector3(48, 0, 40))
	await _frames(5)
	await _save("stroke_%s" % tag)
	editor.paint_end()
	get_tree().quit()


func _stroke(editor: TrackEditor, from: Vector3, along: Vector3) -> void:
	editor.paint_begin(from)
	editor.paint_to(from + along)
	editor.paint_end()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
