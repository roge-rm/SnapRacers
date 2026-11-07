extends Node

## Run with an isolated XDG_DATA_HOME inside build/creations. Without
## --headless this checks every drawn frame and saves first/settled pictures.

const DEBUG := "/srv/downloads/temp/debug/snapracers/track-editor-first-scene"
var failures := 0
var editor: TrackEditor
var _drawn: Array = []
var _watch := false


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func put(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _ready() -> void:
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/creations/")):
		push_error("Set XDG_DATA_HOME to an isolated folder inside build/creations.")
		get_tree().quit(1)
		return
	var rendered := DisplayServer.get_name() != "headless"
	if rendered:
		DirAccess.make_dir_recursive_absolute(DEBUG)
		RenderingServer.frame_pre_draw.connect(_capture)
	else:
		get_tree().process_frame.connect(_capture)
	var saved := CourseDesign.load_file(Tracks.path_of("peach_pit"))
	saved.made_by = "First scene test"
	saved.hills = 7.0
	saved.start.origin = Vector3(240, 0, -160)
	saved.landmarks = [{"prop": "barn", "at": [100, 240], "facing": 1}]
	var source := CourseDesign.FOLDER + "/first-scene.json"
	put(source, saved.to_dict())
	var draft := {"path": "user://courses/unfinished.json", "course": CourseDesign.starter().to_dict()}
	put(TrackEditor.CURRENT, draft)
	var draft_text := FileAccess.get_file_as_string(TrackEditor.CURRENT)

	editor = TrackEditor.new(source, func() -> void: pass)
	add_child(editor)
	check(editor.path == source and editor.course.start == saved.start, "initial_path keeps the source identity and moved start")
	check(FileAccess.get_file_as_string(TrackEditor.CURRENT) == draft_text, "opening an explicit course preserves the existing draft")
	check(editor._full != null and editor._full.terrain != null and editor._marks.get_child_count() == 1, "hills, road boundaries and landmarks exist before the first draw")
	await _settled("initial-path", rendered)
	editor.queue_free()
	await frames(2)
	check(not is_instance_valid(editor), "leaving frees the complete editor scene")

	put(TrackEditor.CURRENT, {"path": source, "course": saved.to_dict()})
	var resumed := CourseDesign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(TrackEditor.CURRENT)).course)
	editor = TrackEditor.new()
	add_child(editor)
	check(editor.path == source and editor.course.to_dict() == resumed.to_dict(), "CURRENT resumes the whole draft and its source identity")
	await _settled("resume", rendered)
	var old: WeakRef = weakref(editor._full)
	editor.load_course(Tracks.path_of("peach_pit"))
	check(editor.path == "" and editor.track.closes, "loading a stock course still creates an editable copy")
	await _settled("load-course", rendered)
	check(old.get_ref() == null, "loading frees the previous full builder")
	old = weakref(editor._full)
	editor.ui.new_pressed.emit()
	check(editor.course.pieces.size() == 1 and editor.path == "", "New replaces the course and clears its saved path")
	await _settled("new-course", rendered)
	check(old.get_ref() == null, "New frees the previous full builder")

	editor.add_piece({"type": "straight", "length": 2})
	check(editor._full == null and editor._quick.visible and editor._build_in > 0, "an interactive edit still uses the immediate quick preview")
	editor._select(1)
	check(editor._quick.get_child(1).get_child(0).material_overlay == editor._highlight, "the quick preview retains the selected piece highlight")
	await get_tree().create_timer(TrackEditor.IDLE_BUILD * 0.5).timeout
	check(editor._full == null, "interactive full rebuilding waits for the idle interval")
	editor.add_piece({"type": "straight", "length": 1})
	await get_tree().create_timer(TrackEditor.IDLE_BUILD * 0.5).timeout
	check(editor._full == null, "another edit resets the idle interval")
	await get_tree().create_timer(TrackEditor.IDLE_BUILD + 0.1).timeout
	check(editor._full != null and not editor._quick.visible and editor._build_in < 0, "the edited course settles into one complete builder")
	check(editor._full != null and editor._full.get_children().any(func(body): return body.has_meta("piece") and int(body.get_meta("piece")) == 1 and body.get_child(0).material_overlay == editor._highlight), "the full rebuild retains the selected piece highlight")
	editor.fit_view()
	await _settled("edited", rendered)
	editor.queue_free()
	await frames(2)
	print("All editor first scene checks passed." if failures == 0 else "%d editor first scene checks failed." % failures)
	get_tree().quit(1 if failures else 0)


func _geometry(root: Node, into: Array) -> void:
	for child in root.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is MeshInstance3D and child.mesh != null:
			into.append([child.get_instance_id(), child.global_transform, child.get_aabb(), child.mesh.get_rid(), child.is_visible_in_tree()])
		elif child is CollisionShape3D and child.shape != null:
			into.append([child.get_instance_id(), child.global_transform, child.shape.get_rid()])
		_geometry(child, into)


func _snapshot() -> Array:
	var geometry: Array = []
	if editor._full != null:
		_geometry(editor._full, geometry)
	_geometry(editor._marks, geometry)
	return [editor._full.get_instance_id() if editor._full != null else 0,
		editor._quick.visible, editor._ground.visible, editor._camera.transform,
		editor._focus, editor._distance, editor._end_marker.transform, geometry]


func _capture() -> void:
	if _watch and is_instance_valid(editor) and editor.is_node_ready():
		_drawn.append(_snapshot())


func _settled(label: String, rendered: bool) -> void:
	var before := _snapshot()
	check(editor._full != null and not editor._quick.visible and not editor._ground.visible and editor._build_in < 0, label + " is complete with no pending build")
	editor._build_full()
	check(_snapshot() == before, label + " cannot add a duplicate full builder")
	_drawn = []
	_watch = true
	if rendered:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(DEBUG + "/" + label + "-first.png")
	await get_tree().create_timer(TrackEditor.IDLE_BUILD + 0.2).timeout
	if rendered:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(DEBUG + "/" + label + "-settled.png")
	_watch = false
	check(not _drawn.is_empty() and _drawn.all(func(draw): return draw == before), "%s geometry, ground, bounds and camera stay fixed from the first %s through the idle interval (%d frames)" % [label, "draw" if rendered else "frame", _drawn.size()])
	check(editor.get_children().filter(func(child): return child is TrackBuilder).size() == 1, label + " retains exactly one full builder")
