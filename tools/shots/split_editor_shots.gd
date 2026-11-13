extends Node

## Pictures of splits in the editor and on the race map: the Splits drawer,
## a split just put in, an adjustable split stretched with a wide island, and
## the race map whole and close up. Run it with its own XDG_DATA_HOME so the
## editor's autosave stays out of your profile:
##   XDG_DATA_HOME=build/creations/shots DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 1600x720 res://tools/shots/split_editor_shots.tscn
## They're saved in /srv/downloads/temp/debug/snapracers/split-pieces/editor.

const OUT := "/srv/downloads/temp/debug/snapracers/split-pieces/editor"
var host: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
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
	var tab := TrackEditorUI.CATEGORIES.map(func(c): return c[0]).find("Splits")
	editor.ui._show_category(tab)
	editor.fit_view()
	await _shot("palette")

	# A second split put in after the first straight, picked out.
	editor.insert_after = 0
	editor.ui._tiles.get_child(0).pressed.emit()
	editor.insert_after = -1
	editor._select(1)
	_look(editor, 1, 140.0)
	await _shot("placing")

	# Stretched to 160 m with a 40 m island.
	editor.ui._length.value = 160.0
	editor.ui._island.value = 40.0
	_look(editor, 1, 240.0)
	await _shot("stretched")
	editor._select(-1)
	await get_tree().create_timer(TrackEditor.IDLE_BUILD + 0.5).timeout
	await _shot("stretched_built")

	# On the race map, with both splits.
	editor.course.name = "Split map shot"
	var path := editor.save()
	Game.start_course(Game.MODE_PRACTICE, path, true)
	for i in 60:
		await get_tree().process_frame
	var maps := host.find_children("*", "CourseMap", true, false)
	for map: CourseMap in maps:
		map.mode = "outline"
	await _shot("minimap")
	# Puts your kart just before the first split, so the close up shows it.
	for map: CourseMap in maps:
		map.mode = "close"
		if map.you != null:
			var split := 0
			while split < map.track.piece_of.size() and not map.track.pieces[map.track.piece_of[split]].is_split():
				split += 1
			var at := maxi(split - 6, 0)
			var spot: Vector3 = map.track.points[at]
			var ahead: Vector3 = map.track.points[mini(at + 1, map.track.points.size() - 1)]
			map.you.freeze = true
			map.you.global_transform = Transform3D(Basis.looking_at(ahead - spot, Vector3.UP), spot + Vector3.UP)
	await _shot("minimap_close")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	host.queue_free()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit()


## Looks down on piece `index` from `distance` metres.
func _look(editor: TrackEditor, index: int, distance: float) -> void:
	var start := editor.track.piece_of.find(index)
	var end := editor.track.piece_of.rfind(index)
	editor._focus = (editor.track.points[start] + editor.track.points[end]) * 0.5
	editor._focus_goal = editor._focus
	editor._following = false
	editor._distance = distance
	editor._place_camera()


func _shot(name: String) -> void:
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
