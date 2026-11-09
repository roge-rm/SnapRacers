extends Node

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var course := CourseDesign.new()
	course.name = "Adjustable editor test"
	course.pieces = [{"type": "straight", "length": 2}, {"type": "curve", "turn": "right", "size": 2}, {"type": "slant", "length": 3, "across": 1}]
	var path := "user://courses/adjustable_editor_test.json"
	course.save(path)
	var editor := TrackEditor.new(path)
	add_child(editor)
	await get_tree().process_frame
	editor._select(0)
	check(editor.ui._dimension_rows.visible and not editor.ui._sideways_row.visible and editor.ui._length.value == 64.0, "selected drawer straight has Length in metres")
	var before := editor.course.to_dict()
	var undo_count := editor._undo.size()
	var old_second := editor.track.piece_starts[1]
	editor.ui._length.value = 63.125
	check(editor.course.pieces[0].type == "adjustable_straight" and editor.course.pieces[0].metres == 63.125, "numeric length converts the selected preset to an adjustable straight")
	check(editor.track.piece_starts[1].origin.distance_to(old_second.origin + Vector3(0, 0, 0.875)) < 0.0001 and editor.course.pieces[1] == before.pieces[1], "length edit moves the following chain without changing its pieces")
	var draft: Variant = JSON.parse_string(FileAccess.get_file_as_string(TrackEditor.CURRENT))
	check(draft.course.pieces[0].metres == 63.125 and editor._undo.size() == undo_count + 1, "dimension edit autosaves and adds one undo step")
	editor.undo()
	check(editor.course.to_dict() == before, "undo restores the original preset and course")
	editor.redo()
	check(editor.course.pieces[0].metres == 63.125, "redo restores the metric dimension")
	editor._select(0)
	var cache_size := TrackEditor._meshes.size()
	for n in 24:
		editor.set_dimension("metres", 60.0 + n * 0.125)
	check(TrackEditor._meshes.size() == cache_size, "repeated metric edits do not retain prior meshes in the shared cache")
	editor._select(2)
	check(editor.ui._sideways_row.visible and editor.ui._sideways.value == 32.0, "selected offset exposes Length and signed Sideways")
	editor.set_dimension("shift", -8.125)
	check(editor.course.pieces[2].type == "adjustable_offset" and editor.course.pieces[2].shift == -8.125, "offset crosses left and retains its metre precision")
	var safe := editor.course.to_dict()
	editor.set_dimension("metres", NAN)
	editor.set_dimension("shift", 300)
	check(editor.course.to_dict() == safe, "nonfinite and out-of-range dimensions leave the course unchanged")
	editor._select(1)
	check(not editor.ui._dimension_rows.visible, "bends do not offer unsupported dimension editing")
	var join_course := CourseDesign.new()
	join_course.name = "Join preview"
	for n in 4:
		join_course.pieces.append({"type": "curve", "turn": "right", "size": 2})
		if n < 3:
			join_course.pieces.append({"type": "straight", "length": 2})
	editor.course = join_course
	editor._select(-1)
	editor._refresh()
	before = editor.course.to_dict()
	var saved_draft := FileAccess.get_file_as_string(TrackEditor.CURRENT)
	undo_count = editor._undo.size()
	editor.ui._card.show()
	editor.join_ends()
	check(not editor._join_spec.is_empty() and editor._join_preview != null and editor.ui._join_actions.visible, "Join ends shows an actual connector mesh and acceptance controls")
	check(editor.course.to_dict() == before and editor._undo.size() == undo_count and FileAccess.get_file_as_string(TrackEditor.CURRENT) == saved_draft, "preview leaves course, undo history and draft untouched")
	editor.cancel_join()
	check(editor._join_spec.is_empty() and not editor.ui._join_actions.visible and editor.course.to_dict() == before and editor.ui._card.visible and editor.ui._join_ends.has_focus(), "Cancel removes only the proposed join and restores the course controls and focus")
	editor.join_ends()
	editor.accept_join()
	check(editor.track.closes and editor.course.pieces[-1].type == "connector" and editor._undo.size() == undo_count + 1, "Use join appends one exact connector as one undo step")
	editor.undo()
	check(editor.course.to_dict() == before and not editor.track.closes, "undo removes the accepted join exactly")
	editor.redo()
	check(editor.track.closes, "redo restores the join")
	editor.undo()
	editor.join_ends()
	editor.rotate_map(15)
	check(editor._join_spec.is_empty() and not editor.ui._join_actions.visible, "a course refresh cancels a stale proposal")
	editor.join_ends()
	editor.course.pieces.append({"type": "quarter_straight"})
	var count := editor.course.pieces.size()
	editor.accept_join()
	check(editor.course.pieces.size() == count and editor._join_spec.is_empty(), "accept refuses a proposal after an unrefreshed course change")
	editor.course = join_course.duplicate_design()
	editor.course.hills = 8.0
	editor._refresh()
	editor.join_ends()
	check(editor._join_spec.is_empty(), "terrain-following joins are refused without changing road")
	editor.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)
	print("%d adjustable editor checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
