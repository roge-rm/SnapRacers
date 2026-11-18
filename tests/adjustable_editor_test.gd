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


## A split's Length and Island, as an adjustable split.
func _split(editor: TrackEditor) -> void:
	var was := editor.course
	var split_course := CourseDesign.new()
	split_course.name = "Adjustable split"
	split_course.pieces = [{"type": "straight", "length": 1}, {"type": "split", "length": 2}, {"type": "straight", "length": 1}]
	editor.course = split_course
	editor._select(-1)
	editor._refresh()
	editor._select(1)
	check(editor.ui._dimension_rows.visible and editor.ui._island_row.visible and not editor.ui._sideways_row.visible and editor.ui._length.value == 64.0 and editor.ui._island.value == 12.0, "a split offers Length and Island in metres")
	check(editor.ui._length.min_value == 64.0 and editor.ui._length.max_value == 256.0 and editor.ui._island.min_value == 8.0 and editor.ui._island.max_value == 64.0, "a split's Length runs 64 to 256 m and Island 8 to 64 m")
	var third := editor.track.piece_starts[2]
	editor.ui._island.value = 14.0
	check(editor.course.pieces[1] == {"type": "adjustable_split", "metres": 64.0, "island": 14.0}, "a new island width makes it an adjustable split (%s)" % editor.course.pieces[1])
	var narrow: Dictionary = editor.course.pieces[1].duplicate()
	editor.set_dimension("island", 40.0)
	check(editor.course.pieces[1] == narrow, "an island too wide for its length is refused")
	editor.ui._length.value = 160.0
	check(editor.track.piece_starts[2].origin.distance_to(third.origin + Vector3(0, 0, -96)) < 0.001, "stretching it to 160 m moves the road after it on")
	editor.set_dimension("island", 40.0)
	check(editor.course.pieces[1].island == 40.0 and editor.track.has_splits, "and then a 40 m island fits")
	var lanes := editor.track.lanes_of(editor.track.piece_of.find(1) + 80)
	check(lanes.size() == 2 and lanes[1].x - lanes[0].y > 39.0 and lanes[0].y - lanes[0].x > 12.9, "its branches go round a 40 m island at the road's full width (%s)" % lanes)
	var wide: Dictionary = editor.course.pieces[1].duplicate()
	editor.set_dimension("metres", 300.0)
	editor.set_dimension("metres", 63.0)
	editor.set_dimension("island", 70.0)
	editor.set_dimension("island", 6.0)
	check(editor.course.pieces[1] == wide, "lengths and islands out of range leave it alone")
	editor.undo()
	check(editor.course.pieces[1].metres == 160.0 and editor.course.pieces[1].island == 14.0, "undo takes the island back")
	editor._select(0)
	check(not editor.ui._island_row.visible, "a straight has no Island")
	editor.course = was
	editor._select(-1)
	editor._refresh()


## Rise, Bank, Height and hump Length steps in the selected piece panel.
func _steps(editor: TrackEditor) -> void:
	var was := editor.course
	var stepped := CourseDesign.new()
	stepped.name = "Stepped"
	stepped.pieces = [{"type": "straight", "length": 1}, {"type": "arc", "angle": 45, "turn": "left", "size": 2}, {"type": "crest", "length": 3, "height": 3.0}, {"type": "slant", "turn": "right", "length": 4, "across": 2}, {"type": "curve", "turn": "left", "size": 1}]
	editor.course = stepped
	editor._select(-1)
	editor._refresh()
	editor._select(1)
	var rise: Dictionary = editor.ui._steppers.rise
	check(rise.row.visible and editor.ui._steppers.bank.row.visible and not editor.ui._steppers.height.row.visible, "a bend has Rise and Bank, not Height")
	editor.step_setting("rise", 1)
	editor.step_setting("rise", 1)
	check(is_equal_approx(float(editor.course.pieces[1].rise), 1.0) and rise.value.text == "+3 m", "two Rise steps of 1.5 m make 3 m")
	for k in 6:
		editor.step_setting("rise", 1)
	check(is_equal_approx(float(editor.course.pieces[1].rise), 1.5) and rise.more.disabled, "Rise stops at 12 percent of the bend's length (4.5 m)")
	editor.step_setting("bank", 1)
	editor.step_setting("bank", 1)
	check(is_equal_approx(float(editor.course.pieces[1].bank), 15.0), "Bank steps 0, 8, 15")
	for k in 3:
		editor.step_setting("rise", -1)
	check(not editor.course.pieces[1].has("rise"), "Rise at 0 leaves no rise in the piece")
	check(TrackCatalogue.makeable(editor.course.pieces[1]), "a stepped bend is still makeable")
	editor._select(2)
	check(editor.ui._steppers.height.row.visible and editor.ui._steppers.hump.row.visible and not rise.row.visible, "a hump has Height and Length")
	editor.step_setting("height", 1)
	editor.step_setting("hump", -1)
	check(is_equal_approx(float(editor.course.pieces[2].height), 3.3) and editor.course.pieces[2].length == 2, "Height goes up 0.3 m and the hump shortens to 64 m")
	editor._select(3)
	editor.step_setting("rise", 1)
	check(is_equal_approx(float(editor.course.pieces[3].rise), 0.5), "an offset takes a rise")
	editor.set_dimension("metres", 150.0)
	check(editor.course.pieces[3].type == "adjustable_offset" and is_equal_approx(float(editor.course.pieces[3].rise), 0.5) and editor.ui._steppers.rise.row.visible, "an adjustable offset keeps its rise")
	check(TrackPiece.from_spec(editor.course.pieces[3]).exit().origin.y > 1.4, "and its road climbs")
	editor._select(4)
	for k in 5:
		editor.step_setting("rise", 1)
	check(is_equal_approx(float(editor.course.pieces[4].rise), 1.0), "a tight 90 degree bend climbs 3 m at most")
	check(not TrackCatalogue.makeable({"type": "curve", "turn": "left", "size": 1, "rise": 2}) and TrackCatalogue.makeable({"type": "slant", "turn": "left", "length": 4, "across": 2, "rise": -4}), "makeable follows the slope limit")
	editor.course = was
	editor._select(-1)
	editor._refresh()


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
	await _steps(editor)
	await _split(editor)
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
