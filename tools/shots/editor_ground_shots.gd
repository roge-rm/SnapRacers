extends Node

## Pictures of the track editor's Ground tab on Trulli Turns: a hill being
## raised by touch, mid stroke with the quick ground and the brush ring, the
## full build after, the same by controller, and the course card with the
## hillshade under the map. Run it with its own XDG_DATA_HOME so the editor's
## autosave stays out of your profile:
##   XDG_DATA_HOME=/tmp/x DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 1280x720 res://tools/shots/editor_ground_shots.tscn
## Pictures go in /srv/downloads/temp/debug/snapracers/terrain/editor.

const OUT := "/srv/downloads/temp/debug/snapracers/terrain/editor"
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
	editor.load_course(Tracks.path_of("trulli_turns"))
	await _frames(30)
	var ui := editor.ui
	ui._show_category(TrackEditorUI.CATEGORIES.size() + 2)
	editor.fit_view()
	editor._zoom(0.7)
	await _frames(60)
	await _save("ground_tab_%s" % tag)
	# By touch: a finger down beside the road, dragged a little and held.
	var screen := get_viewport().get_visible_rect().size
	var at := screen * Vector2(0.62, 0.45)
	ui.ground_brush = 5
	ui._show_category(ui._category)
	_touch(at, true)
	for i in 8:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = at + Vector2(i * 6.0, 0.0)
		drag.relative = Vector2(6.0, 0.0)
		Input.parse_input_event(drag)
		await _frames(1)
	# Held for a few seconds: the brush goes by time, not frames.
	await get_tree().create_timer(4.0).timeout
	await _save("touch_sculpt_%s" % tag)
	_touch(at + Vector2(42.0, 0.0), false)
	await _frames(5)
	await get_tree().create_timer(1.5).timeout
	await _save("touch_built_%s" % tag)
	# By controller: Lower with the big brush, A held.
	PadFocus.using_pad = true
	var pad: TrackEditorPad = editor.find_children("*", "TrackEditorPad", false, false)[0]
	ui.ground_tool = "lower"
	ui.ground_brush = 5
	ui._show_category(ui._category)
	pad._brush = screen * Vector2(0.4, 0.6)
	pad._button(JOY_BUTTON_A)
	await get_tree().create_timer(3.0).timeout
	await _save("pad_sculpt_%s" % tag)
	var up := InputEventJoypadButton.new()
	up.button_index = JOY_BUTTON_A
	up.pressed = false
	pad._input(up)
	await get_tree().create_timer(1.5).timeout
	# The course card, with the hillshade under the map.
	ui._chip.pressed.emit()
	await _frames(30)
	await _save("overview_%s" % tag)
	get_tree().quit()


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at
	touch.pressed = down
	Input.parse_input_event(touch)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
