extends Node

## Uses the track editor the way a player would: clicking pieces on, undo and
## redo, picking a piece out and taking it out, closing the course up,
## putting a landmark down, saving, loading one of the game's courses to
## build on, and racing on what you've built, then coming back.
##
## It runs as a scene, because the screens use the Game autoload:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/editor_test.tscn

var failures := 0
var host: Node
var editor: TrackEditor


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func screen() -> Node:
	return host.get_child(host.get_child_count() - 1)


func _ready() -> void:
	# Start from a new course, not whatever was left from last time.
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_track_editor()
	await frames(3)
	editor = screen()
	check(editor is TrackEditor, "the track editor opens")
	check(editor.course.pieces.size() == 1 and not editor.track.closes, "with a new course: a straight to start from")

	# Clicking pieces onto the end.
	var tiles := editor.ui._tiles.get_children()
	check(tiles.size() == 4, "the drawer starts on the straights (%d)" % tiles.size())
	tiles[1].pressed.emit()
	check(editor.course.pieces.size() == 2 and editor.course.pieces[1].length == 2, "tapping a piece clicks it onto the end")
	editor.ui._show_category(1)
	await frames(1)
	editor.ui._tiles.get_children()[3].pressed.emit()
	check(editor.course.pieces[2].type == "curve" and editor.course.pieces[2].turn == "right", "and a bend after that")
	await frames(2)
	check(editor._quick.get_child_count() == 3, "each piece is laid out straight away (%d)" % editor._quick.get_child_count())
	editor.undo()
	check(editor.course.pieces.size() == 2, "undo takes the bend back off")
	editor.redo()
	check(editor.course.pieces.size() == 3, "and redo puts it back")

	# Picking a piece out, changing it and adding after it.
	editor._select(1)
	editor.ui.surface_chosen.emit("dirt")
	check(editor.course.pieces[1].get("surface") == "dirt", "a picked out piece can be made dirt")
	editor.ui.add_after_pressed.emit()
	editor.add_piece({"type": "straight", "length": 1})
	check(editor.course.pieces.size() == 4 and editor.course.pieces[2].length == 1, "added after it, a piece goes in the middle")
	editor._select(2)
	editor.delete_selected()
	check(editor.course.pieces.size() == 3, "and taking a piece out closes the gap")
	editor._select(-1)

	# The full build a moment after the last change.
	await get_tree().create_timer(TrackEditor.IDLE_BUILD + 0.3).timeout
	check(editor._full != null and not editor._quick.visible, "a moment later the whole course is built properly")

	# Closing it up.
	editor.add_piece({"type": "straight", "length": 3})
	editor.close_up()
	# It works on another thread, so wait on the clock (the frames here run
	# as fast as they can).
	var give_up := Time.get_ticks_msec() + 20000
	while editor._closing != -1 and Time.get_ticks_msec() < give_up:
		await frames(1)
	check(editor.track.closes, "Close it up joins the road back to the start")
	check(editor.course.problems().is_empty(), "and it's ready to race %s" % [editor.course.problems()])

	# A landmark: not on the road, but beside it is fine.
	editor.pick_up_landmark("barn")
	editor._holding.at = [editor.track.points[5].x, editor.track.points[5].z]
	editor.drop_landmark()
	check(editor.course.landmarks.is_empty(), "a landmark can't go down on the road")
	# Somewhere off to one side, clear of the rest of the road too.
	for reach: float in [-40.0, 40.0, -70.0, 70.0]:
		var beside: Vector3 = editor.track.points[5] + editor.track.rights[5] * reach
		editor._holding.at = [beside.x, beside.z]
		if editor._clear_of_road(editor._holding):
			break
	editor.drop_landmark()
	check(editor.course.landmarks.size() == 1, "but it can beside it")

	# Saving.
	editor.course.name = "Editor Test Course"
	var path := editor.save()
	check(path != "" and FileAccess.file_exists(path), "it saves as a course of your own (%s)" % path)
	var saved := CourseDesign.load_file(path)
	check(saved.problems().is_empty() and saved.landmarks.size() == 1, "which loads back finished, landmark and all")

	# It shows up in the course lists.
	Game.show_tracks(Game.MODE_TIME_TRIAL)
	await frames(2)
	var listed := screen().find_children("*", "Button", true, false).filter(func(b): return b.get_meta("track", "") == path)
	check(listed.size() == 1, "and it's in the course list under your courses")

	# Racing on it from the editor comes back to the editor.
	Game.show_track_editor()
	await frames(3)
	editor = screen()
	check(editor.path == path and editor.course.name == "Editor Test Course", "back in the editor, the same course is there")
	Game.start_course(Game.MODE_PRACTICE, path, true)
	await frames(30)
	check(screen() is Race and screen().track.closes, "test driving it starts a race on it")
	screen().leave()
	await frames(3)
	check(screen() is TrackEditor, "and leaving goes back to the editor")
	editor = screen()

	# Loading one of the game's courses gives you a copy to build on.
	editor.load_course(Tracks.path_of("peach_pit"))
	check(editor.course.name == "Peach Pit" and editor.path == "", "loading one of the game's courses gives you a copy")
	check(editor.track.closes and editor.course.problems().is_empty(), "which is finished already")

	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	print("All editor checks passed." if failures == 0 else "%d editor checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
