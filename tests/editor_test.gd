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
	check(tiles.size() == 6, "the drawer starts on straights in length order (%d)" % tiles.size())
	tiles[3].pressed.emit()
	check(editor.course.pieces.size() == 2 and editor.course.pieces[1].length == 2, "tapping a piece clicks it onto the end")
	editor.ui._show_category(1)
	await frames(1)
	editor.ui._tiles.get_children()[43].pressed.emit()
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
	check(editor.ui._surfaces.has("mud"), "mud is on the list of surfaces")
	editor.ui._surfaces["mud"].pressed.emit()
	check(editor.course.pieces[1].get("surface") == "mud", "and its button makes the piece mud")
	editor.ui._surfaces["concrete"].pressed.emit()
	check(editor.course.pieces[1].get("surface") == "concrete", "concrete is offered for a picked out piece")
	editor.ui.surface_chosen.emit("dirt")
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
	await _controller(editor)
	await _paint(editor)
	await _ground(editor)
	_water(editor)

	# Saving.
	editor.course.name = "Editor Test Course"
	var path := editor.save()
	check(path != "" and FileAccess.file_exists(path), "it saves as a course of your own (%s)" % path)
	var saved := CourseDesign.load_file(path)
	check(saved.problems().is_empty() and saved.landmarks.size() == 1, "which loads back finished, landmark and all")

	# It shows up in the course lists.
	Game.show_tracks(Game.MODE_TIME_TRIAL)
	await frames(2)
	var mine := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("yours"))
	check(mine.size() == 1, "there's a card for your courses with the cups")
	if not mine.is_empty():
		mine[0].pressed.emit()
		await frames(2)
	var listed := screen().find_children("*", "Button", true, false).filter(func(b): return b.get_meta("track", "") == path)
	check(screen() is CourseGrid and listed.size() == 1, "and it's there behind it")

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

	await _splits()

	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	print("All editor checks passed." if failures == 0 else "%d editor checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The Splits tab, a split on the course and its outline on the map.
func _splits() -> void:
	var tab := -1
	for i in TrackEditorUI.CATEGORIES.size():
		if TrackEditorUI.CATEGORIES[i][0] == "Splits":
			tab = i
	editor.load_course("res://tests/data/split_course.json")
	check(editor.track.closes and editor.track.has_splits and editor.course.problems().is_empty(), "a course with a split loads finished")
	editor.ui._show_category(tab)
	await frames(1)
	var tiles := editor.ui._tiles.get_children()
	check(tab >= 0 and tiles.size() == 11 and tiles[0].get_meta("spec") == {"type": "split", "length": 2}, "the Splits tab has the split straight first of its 11 splits (%d)" % tiles.size())
	editor.insert_after = 0
	tiles[0].pressed.emit()
	check(int(editor.course.pieces[1].get("length", 0)) == 2 and editor.course.pieces[1].type == "split" and editor.course.pieces[2].type == "split", "tapping it puts a split in after the picked piece")
	editor.undo()
	editor.insert_after = -1
	editor._select(-1)
	var outline := CourseOutline.of_track(editor.track)
	var split: Dictionary = outline.splits[0] if outline.splits.size() == 1 else {}
	check(not split.is_empty() and Array(split.left).min() < -10.0 and Array(split.right).max() > 10.0 and absf(split.left[0]) < 0.01 and absf(split.left[-1]) < 0.01, "the course's outline has both branches, meeting at each end")
	check(outline.summary.contains("a split"), "and its summary mentions the split (%s)" % outline.summary)
	var saved := "user://editor_test_outline.json"
	CourseOutline._write(saved, outline)
	var back := CourseOutline._read(saved)
	DirAccess.remove_absolute(saved)
	check(back.get("splits", []).size() == 1 and back.splits[0].middle.size() == split.middle.size() and is_equal_approx(back.splits[0].right[10], snappedf(split.right[10], 0.1)), "a saved outline keeps its split")
	var preview := editor.ui._map_preview
	check(preview != null, "the editor has a map of the course")


## The editor with a controller (see TrackEditorPad).
func _controller(editor: TrackEditor) -> void:
	var pad: TrackEditorPad = editor.find_children("*", "TrackEditorPad", false, false)[0]
	pad._button(JOY_BUTTON_DPAD_DOWN)
	await frames(1)
	var focused := get_viewport().gui_get_focus_owner()
	check(focused != null and editor.ui._tiles.is_ancestor_of(focused), "the d-pad picks out a piece in the drawer")
	var tab: int = editor.ui._category
	var last_tile := editor.ui._tiles.get_child(3)
	last_tile.grab_focus()
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(2)
	check(editor.ui._category == tab + 1, "RB goes to the next tab")
	pad._button(JOY_BUTTON_LEFT_SHOULDER)
	await frames(2)
	check(get_viewport().gui_get_focus_owner() == editor.ui._tiles.get_child(3), "LB returns to the tile last used on that tab")
	editor.ui._show_category(TrackEditorUI.CATEGORIES.size())
	var pill: Button = editor.ui._group_pills[editor.ui._landmark_group]
	pill.grab_focus()
	check(not pad._button(JOY_BUTTON_DPAD_DOWN) and get_viewport().gui_get_focus_owner() == pill, "the d-pad leaves the group pills' navigation to the drawer")
	await frames(2)
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(2)
	check(editor.ui.painting() and get_viewport().gui_get_focus_owner() == null, "RB from Landmarks opens Paint with the stick on the brush")
	var brush_before: int = editor.ui.paint_brush
	pad._button(JOY_BUTTON_Y)
	check(editor.ui.paint_brush != brush_before, "Y changes the brush size")
	pad._button(JOY_BUTTON_X)
	check(editor.ui.paint_type == "", "X picks the eraser")
	pad._button(JOY_BUTTON_X)
	check(editor.ui.paint_type == "mud", "and X again the type before")
	editor.ui.paint_brush = 1
	var undo_before: int = editor._undo.size()
	pad._brush = editor.get_viewport().get_visible_rect().size * 0.5
	pad._button(JOY_BUTTON_A)
	var held: bool = editor._stroke
	var stop := InputEventJoypadButton.new()
	stop.button_index = JOY_BUTTON_A
	stop.pressed = false
	pad._input(stop)
	check(held and not editor._stroke, "holding A paints and letting go ends the stroke")
	check(editor._undo.size() <= undo_before + 1, "as one undo step at most")
	if editor._undo.size() > undo_before:
		editor.undo()
	pad._button(JOY_BUTTON_B)
	await frames(2)
	check(editor.ui._category == 0, "B leaves the Paint tab")
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(1)
	editor.ui._show_category(TrackEditorUI.CATEGORIES.size() + 1)
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(2)
	check(editor.ui.sculpting() and get_viewport().gui_get_focus_owner() == null, "RB from Paint opens Ground with the stick on the brush")
	editor.ui.ground_tool = "raise"
	pad._button(JOY_BUTTON_X)
	check(editor.ui.ground_tool == "lower", "X flips Raise to Lower")
	pad._button(JOY_BUTTON_X)
	check(editor.ui.ground_tool == "raise", "and back")
	var ground_brush: int = editor.ui.ground_brush
	pad._button(JOY_BUTTON_Y)
	check(editor.ui.ground_brush != ground_brush, "Y changes the ground brush size")
	undo_before = editor._undo.size()
	pad._brush = editor.get_viewport().get_visible_rect().size * 0.5
	pad._button(JOY_BUTTON_A)
	held = editor._stroke
	await frames(10)
	pad._input(stop)
	check(held and not editor._stroke and editor.course.ground != null, "holding A sculpts a ground map and letting go ends the stroke")
	check(editor._undo.size() == undo_before + 1, "as one undo step")
	editor.undo()
	check(editor.course.ground == null, "which undo takes back")
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(2)
	check(editor.ui._category == 0 and get_viewport().gui_get_focus_owner() == editor.ui._tiles.get_child(3), "RB wraps from Ground onto the remembered straight tile")
	editor.ui._show_category(tab)
	editor.ui.focus_palette()
	var pieces := editor.course.pieces.size()
	pad._button(JOY_BUTTON_Y)
	check(pad.on_road and editor.selected == pieces - 1, "Y goes onto the road at the last piece")
	pad._button(JOY_BUTTON_DPAD_LEFT)
	check(editor.selected == pieces - 2, "and left steps back a piece")
	pad._button(JOY_BUTTON_A)
	await frames(1)
	focused = get_viewport().gui_get_focus_owner()
	check(focused != null and editor.ui._actions.is_ancestor_of(focused), "A goes into its buttons")
	pad._button(JOY_BUTTON_B)
	await frames(1)
	check(pad.on_road and get_viewport().gui_get_focus_owner() == null, "and B comes back out onto the road")
	pad._button(JOY_BUTTON_X)
	check(editor.course.pieces.size() == pieces - 1, "X takes the piece out")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 1.0
	pad._input(trigger)
	trigger.axis_value = 0.0
	pad._input(trigger)
	check(editor.course.pieces.size() == pieces, "and LT undoes that")
	pad._button(JOY_BUTTON_B)
	check(not pad.on_road and editor.selected == -1, "B goes back to the drawer")
	editor.pick_up_landmark("barn")
	pad._button(JOY_BUTTON_X)
	check(editor._holding.angle == 15, "X turns a landmark in hand a step")
	pad._button(JOY_BUTTON_BACK)
	check(editor._holding.is_empty() and editor.course.landmarks.size() == 1, "and Back takes it away")


## Painting ground: a stroke is one undo step, the eraser and a stroke that
## starts on the same type erase, and the road keeps slime away. Water and
## lava have no tiles here: they're lakes and rivers on the Ground tab.
func _paint(editor: TrackEditor) -> void:
	var kept := editor.course.to_dict()
	editor.ui._show_category(TrackEditorUI.CATEGORIES.size() + 1)
	check(editor.ui.painting(), "the Paint tab opens")
	var tiles := editor.ui._tiles.get_children()
	check(tiles.size() == PaintedAreas.TYPES.size() - Waters.TYPES.size() + 3, "with a tile for each type but water and lava, the eraser, the brush and Done (%d)" % tiles.size())
	var far := editor.track.points[0] + Vector3(600.0, 0.0, 600.0)
	editor.ui.paint_type = "mud"
	editor.ui.paint_brush = 3
	var undo_before := editor._undo.size()
	editor.paint_begin(far)
	editor.paint_to(far + Vector3(24.0, 0.0, 0.0))
	editor.paint_to(far + Vector3(48.0, 0.0, 0.0))
	editor.paint_end()
	await frames(1)
	var painted := editor.course.paint.count()
	check(painted >= 15 and editor.course.paint.square_type(PaintedAreas.square_at(far.x + 24.0, far.z)) == "mud", "a drag paints mud (%d squares)" % painted)
	check(editor._undo.size() == undo_before + 1, "and the stroke is one undo step")
	check(editor.track.paint.count() == painted, "the course the editor builds from has it")
	editor.undo()
	check(editor.course.paint.is_empty(), "undo takes the whole stroke back")
	editor.redo()
	check(editor.course.paint.count() == painted, "and redo puts it back")
	# Undo in the middle of a stroke, like a trigger while A is held.
	editor.paint_begin(far + Vector3(0.0, 0.0, 48.0))
	editor.undo()
	var mid_undo := editor._undo.size()
	check(editor.course.paint.count() == painted, "undo in the middle of a stroke takes back what it painted so far")
	editor.paint_to(far + Vector3(24.0, 0.0, 48.0))
	check(editor._undo.size() == mid_undo + 1, "and the rest of the stroke is its own undo step")
	editor.paint_end()
	editor.undo()
	check(editor.course.paint.count() == painted, "which undo takes back")
	# A stroke that starts on the same type erases.
	editor.paint_begin(far + Vector3(24.0, 0.0, 0.0))
	editor.paint_end()
	check(editor.course.paint.square_type(PaintedAreas.square_at(far.x + 24.0, far.z)) == "", "a stroke starting on the same type erases")
	editor.ui.paint_type = "gravel"
	editor.paint_begin(far)
	editor.paint_end()
	check(editor.course.paint.square_type(PaintedAreas.square_at(far.x, far.z)) == "gravel", "another type paints over it")
	editor.ui.paint_type = ""
	var count := editor.course.paint.count()
	editor.paint_begin(far)
	editor.paint_end()
	check(editor.course.paint.count() < count, "the eraser erases")
	# Near the road.
	editor.ui.paint_type = "slime"
	editor.ui.paint_brush = 1
	var road := editor.track.points[3]
	var before := editor.course.paint.count()
	var undo_size := editor._undo.size()
	check(not editor.refused_squares(road).is_empty(), "squares on the road show red")
	editor.paint_begin(road)
	editor.paint_to(road + editor.track.rights[3] * 6.0)
	editor.paint_end()
	check(editor.course.paint.count() == before and editor._undo.size() == undo_size, "and aren't painted, with no undo step")
	# Past the most squares.
	var kept_paint := editor.course.paint
	var filled := PaintedAreas.new()
	for k in PaintedAreas.MOST_SQUARES:
		filled.set_square(PaintedAreas.square_at(far.x, far.z) + Vector2i(k % 40, 10 + k / 40), "mud")
	editor.course.paint = filled
	var spot := far + Vector3(0.0, 0.0, -200.0)
	check(editor.refused_squares(spot).size() == 1, "with the most squares painted the brush shows red")
	editor.paint_begin(spot)
	editor.paint_end()
	check(editor.course.paint.count() == PaintedAreas.MOST_SQUARES and editor.course.paint.square_type(PaintedAreas.square_at(spot.x, spot.z)) == "", "and paints no more")
	check(Sharing.validate_saved(Sharing.COURSE, editor.course.to_dict()).get("kind") == Sharing.COURSE, "a course with the most squares saves and loads")
	editor.course.paint = kept_paint
	editor._refresh()
	# A landmark over slime gets the red ring.
	editor.ui.paint_type = "slime"
	editor.paint_begin(far)
	editor.paint_end()
	check(not editor._clear_of_road({"prop": "barn", "at": [far.x, far.z], "facing": 0}), "a landmark over slime is refused like one on the road")
	editor.ui.paint_type = "mud"
	editor.paint_begin(far + Vector3(200.0, 0.0, 0.0))
	editor.paint_end()
	check(editor._clear_of_road({"prop": "barn", "at": [far.x + 200.0, far.z], "facing": 0}), "but not over mud")
	# Under a bridge.
	editor.course = CourseDesign.from_dict({"theme": "orchard", "start": [0, 0, 0, 0], "pieces": [{"type": "straight", "length": 2}, {"type": "ramp", "length": 4, "rise": 3}, {"type": "straight", "length": 4}, {"type": "ramp", "length": 4, "rise": -3}, {"type": "straight", "length": 2}]})
	editor._refresh()
	var top := 0
	for i in editor.track.points.size():
		if editor.track.points[i].y - editor.track.grounds[i] > editor.track.points[top].y - editor.track.grounds[top]:
			top = i
	var high := editor.track.points[top]
	editor.ui.paint_type = "slime"
	editor.ui.paint_brush = 1
	editor.paint_begin(high)
	editor.paint_end()
	check(editor.course.paint.square_type(PaintedAreas.square_at(high.x, high.z)) == "slime", "slime paints under a bridge")
	editor.ui._show_category(0)
	check(not editor.ui.painting(), "Done goes back to the first tab")
	editor.course = CourseDesign.from_dict(kept)
	editor._undo.clear()
	editor._refresh()


## Lakes and rivers on the Ground tab: Lake puts one down and drag moves its
## level, live, in one undo step, and a lake lowered dry goes; River draws
## one and a tap takes it away; Follow the valley runs one downhill; and the
## lava tile makes them lava.
func _water(editor: TrackEditor) -> void:
	var kept := editor.course.to_dict()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/ground_course.json"))
	data.erase("water")
	editor.course = CourseDesign.from_dict(data)
	editor._undo.clear()
	editor._refresh()
	editor.ui._show_category(TrackEditorUI.CATEGORIES.size() + 2)
	editor.ui.ground_tool = "lake"
	check(editor.water_tool(), "the Lake tool is a water tool")
	var hollow := Vector3(150.0, 0.0, -282.0)
	var ground := editor.course.ground.height_at(hollow.x, hollow.z)
	editor._dragging = false
	editor.paint_begin(hollow)
	editor.water_lift(1.0)
	var shown := editor._water_view != null and editor._water_view.visible
	var wet := editor._water_preview.wet_count(0)
	editor.water_lift(0.5)
	check(shown and editor._water_preview.wet_count(0) > wet, "a tap puts a lake in the hollow and lifting it shows its shore growing (%d to %d points)" % [wet, editor._water_preview.wet_count(0)])
	editor.paint_end()
	var bodies := editor.course.waters.bodies
	check(bodies.size() == 1 and bodies[0].kind == "lake" and bodies[0].type == "water" and is_equal_approx(bodies[0].level, ground + TrackEditor.LAKE_START + 1.5), "the lake's level is where it was lifted to (%.2f over %.2f)" % [bodies[0].level if not bodies.is_empty() else 0.0, ground])
	check(editor._undo.size() == 1 and editor.track.waters.bodies.size() == 1, "in one undo step, and the course built from it has it")
	editor.undo()
	check(editor.course.waters.is_empty(), "undo takes it away")
	editor.redo()
	editor.paint_begin(hollow)
	editor.water_lift(-30.0)
	editor.paint_end()
	check(editor.course.waters.is_empty() and editor._undo.size() == 2, "lowered till it's dry the lake goes, in one step")
	editor.undo()
	# A river drawn down the valley.
	editor.ui.ground_tool = "river"
	editor.ui.ground_brush = 3
	editor._dragging = true
	editor.paint_begin(Vector3(236.0, 0.0, -160.0))
	for x in range(220, 40, -10):
		editor.paint_to(Vector3(float(x), 0.0, -160.0))
	editor.paint_end()
	bodies = editor.course.waters.bodies
	var river: Dictionary = bodies[bodies.size() - 1] if not bodies.is_empty() else {}
	check(bodies.size() == 2 and river.get("kind") == "river" and river.points.size() >= 10 and is_equal_approx(river.points[0].z, GroundBrush.RIVER_WIDTHS[3]), "drawing with River lays a river %d points long" % (river.points.size() if not river.is_empty() else 0))
	check(editor._undo.size() == 2, "in one undo step")
	editor._dragging = false
	editor.paint_begin(Vector3(150.0, 0.0, -160.0))
	editor.paint_end()
	check(editor.course.waters.bodies.size() == 1, "a tap on it takes it away")
	# Follow the valley, as lava.
	editor.ui.ground_tool = "valley"
	editor.ui.toggle_water_type()
	var source := Vector3(205.0, 0.0, -255.0)
	editor.paint_begin(source)
	editor.paint_end()
	bodies = editor.course.waters.bodies
	var down := true
	if bodies.size() == 2:
		var points: PackedVector3Array = bodies[1].points
		for i in range(1, points.size()):
			down = down and editor.course.ground.height_at(points[i].x, points[i].y) <= editor.course.ground.height_at(points[i - 1].x, points[i - 1].y) + 0.3
	check(bodies.size() == 2 and bodies[1].type == "lava" and bodies[1].points.size() >= 3 and down, "Follow the valley runs a lava river downhill from where it's tapped")
	editor.ui.toggle_water_type()
	check(editor.ui.water_type == "water", "and the tile goes back to water")
	editor.ui._show_category(0)
	editor.course = CourseDesign.from_dict(kept)
	editor._undo.clear()
	editor._redo.clear()
	editor._refresh()


## Sculpting the ground: the first stroke bakes the hills into a map, a stroke
## is one undo step, picking hills clears the map, Level to road, the map
## growing with the course and the Ground tab hidden indoors.
func _ground(editor: TrackEditor) -> void:
	var kept := editor.course.to_dict()
	var ground_tab := TrackEditorUI.CATEGORIES.size() + 2
	editor.ui._show_category(ground_tab)
	check(editor.ui.sculpting() and not editor.ui.painting(), "the Ground tab opens")
	var tiles := editor.ui._tiles.get_children()
	check(tiles.size() == GroundBrush.TOOLS.size() + GroundBrush.WATER_TOOLS.size() + 3, "with a tile for each tool, water or lava, the brush and Done (%d)" % tiles.size())
	editor.ui.hills_chosen.emit(8.0)
	check(editor.course.ground == null and editor.course.hills == 8.0, "a course with rolling hills has no map yet")
	var k := editor.track.points.size() / 3
	var spot: Vector3 = editor.track.points[k] + editor.track.rights[k] * 70.0
	var away: Vector3 = editor.track.points[k] + editor.track.rights[k] * -70.0
	var hill_here := editor.track.ground_height(spot.x, spot.z)
	var hill_away := editor.track.ground_height(away.x, away.z)
	var undo_before := editor._undo.size()
	editor.ui.ground_tool = "raise"
	editor.ui.ground_brush = 3
	editor.paint_begin(spot)
	for i in 30:
		editor.sculpt_for(1.0 / 60.0)
	editor.paint_end()
	var map := editor.course.ground
	check(map != null, "the first stroke makes a ground map")
	check(map != null and absf(map.height_at(away.x, away.z) - hill_away) < 0.05, "with the hills baked in away from the brush (%.2f, %.2f)" % [map.height_at(away.x, away.z) if map != null else 0.0, hill_away])
	var raised := map.height_at(spot.x, spot.z) - hill_here if map != null else 0.0
	check(raised > 1.2 and raised < 1.8, "Raise lifts the ground about 2 m a second (%.2f m in 0.75 s)" % raised)
	check(editor._undo.size() == undo_before + 1, "the stroke is one undo step")
	check(editor.track.ground != null and editor.course.to_dict().has("ground") and not editor.course.to_dict().has("hills"), "the course keeps the map instead of the hills")
	editor.undo()
	check(editor.course.ground == null and editor.course.hills == 8.0, "undo goes back to the hills")
	editor.redo()
	check(editor.course.ground != null, "and redo brings the map back")
	# Picking hills clears the map, as one undo step.
	undo_before = editor._undo.size()
	editor.ui.hills_chosen.emit(0.0)
	check(editor.course.ground == null and editor.course.hills == 0.0 and editor._undo.size() == undo_before + 1, "picking Flat clears the map in one undo step")
	editor.undo()
	check(editor.course.ground != null, "which undo brings back")
	# Level to road: a hill raised beside the road comes back down to it.
	var on_ground := -1
	for i in range(0, editor.track.points.size(), 7):
		if editor.track.points[i].y - editor.track.grounds[i] < 0.1 and not editor.track.stickies[i]:
			on_ground = i
			break
	var road := editor.track.points[on_ground]
	var verge: Vector3 = road + editor.track.rights[on_ground] * (editor.course.width * 0.5 + 10.0)
	editor.paint_begin(verge)
	for i in 120:
		editor.sculpt_for(1.0 / 60.0)
	editor.paint_end()
	var before_level := editor.course.ground.height_at(verge.x, verge.z)
	editor.ui.ground_tool = "level"
	editor.paint_begin(verge)
	for i in 180:
		editor.sculpt_for(1.0 / 60.0)
	editor.paint_end()
	var level := editor.course.ground.height_at(verge.x, verge.z)
	# Within half a metre, as each point goes to the road nearest it, which
	# climbs with the hills.
	check(before_level - editor.track.grounds[on_ground] > 2.0 and absf(level - editor.track.grounds[on_ground]) < 0.5, "Level to road brings a raised verge back to the road in one stroke (%.2f to %.2f, road %.2f)" % [before_level, level, editor.track.grounds[on_ground]])
	# Flatten holds the height where the stroke starts.
	editor.ui.ground_tool = "flatten"
	var start_height := editor.course.ground.height_at(spot.x, spot.z)
	editor.paint_begin(spot)
	editor.paint_to(spot + Vector3(16.0, 0.0, 0.0))
	for i in 180:
		editor.sculpt_for(1.0 / 60.0)
	editor.paint_end()
	var flat := editor.course.ground.height_at(spot.x + 16.0, spot.z)
	check(absf(flat - start_height) < 0.3, "Flatten brings the ground to where the stroke started (%.2f, %.2f)" % [flat, start_height])
	# The ground's the brush's: the screen point under the middle lands on the map.
	var middle := editor.get_viewport().get_visible_rect().size * 0.5
	var landed := editor._ground_point(middle)
	check(absf(landed.y - editor.course.ground.height_at(landed.x, landed.z)) < 0.2, "a point on the screen lands on the map (%.2f, %.2f)" % [landed.y, editor.course.ground.height_at(landed.x, landed.z)])
	# The map grows to cover new road, keeping what was there.
	var old := editor.course.ground
	var old_points := old.cols * old.rows
	var raised_at := old.height_at(spot.x, spot.z)
	for i in 4:
		editor.add_piece({"type": "straight", "length": 4})
	var grown := editor.course.ground
	check(grown.cols * grown.rows > old_points and absf(grown.height_at(spot.x, spot.z) - raised_at) < 0.01, "the map grows with the course and keeps its heights (%d to %d points)" % [old_points, grown.cols * grown.rows])
	var box := Rect2(grown.origin, Vector2(grown.cols - 1, grown.rows - 1) * grown.cell)
	var covered := true
	for p in editor.track.points:
		covered = covered and box.grow(-100.0).has_point(Vector2(p.x, p.z))
	check(covered, "and covers the new road with room round it")
	# A spike under the road is a problem, shown in red.
	editor.ui.ground_tool = "raise"
	editor.ui.ground_brush = 5
	editor.paint_begin(road)
	for i in 300:
		editor.sculpt_for(1.0 / 60.0)
	editor.paint_end()
	var warnings := editor.course.warnings()
	check(warnings.has("The road can't climb that steeply here.") and editor.ui._problems_label.text.contains("climb that steeply"), "a sculpted spike under the road gets a warning on the card %s" % [warnings])
	check(editor._problem_view.visible and editor._problem_view.multimesh.instance_count > 0, "marked in red on the course")
	check(not editor.course.problems().has("The road can't climb that steeply here."), "which doesn't stop it being raced")
	# Indoors there's no Ground tab.
	editor.ui.theme_chosen.emit("hall_red")
	check(not editor.ui._rail[ground_tab].visible and not editor.ui.sculpting(), "an indoor course has no Ground tab")
	editor.ui._show_category(ground_tab - 1)
	check(editor.ui.next_tab(1) == 0, "and the tabs go round past it")
	editor.ui.theme_chosen.emit("sky")
	check(editor.ui._rail[ground_tab].visible, "up in the sky it's back")
	editor.ui._show_category(0)
	editor.course = CourseDesign.from_dict(kept)
	editor._undo.clear()
	editor._redo.clear()
	editor._refresh()
