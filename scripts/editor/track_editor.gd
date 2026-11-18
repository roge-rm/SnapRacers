class_name TrackEditor
extends Node3D

## The track editor. You build a course like a slot car set, where every piece
## you pick clicks onto the end of the road or after the piece you've picked
## out. Tap a piece of road to take it out, change its surface or walls, or add
## more after it. Close it up finds the pieces to bring the road back around to
## the start. Landmarks from the drawer go wherever you drag them off the road.
##
## The course is laid out again after every change from each kind of piece's
## road, which is made once and kept, and a moment after you stop the whole
## course is built properly with its pillars and start gantry. What you're
## working on is kept as you go, like the kart in the garage.

const CURRENT := "user://current_course.json"
## How long after the last change the full course gets built, in seconds.
const IDLE_BUILD := 0.6
const MIN_DISTANCE := 50.0
const MAX_DISTANCE := 1800.0
const ORBIT_SPEED := 0.006
const DRAG_START := 12.0
const GRAB_RADIUS := 90.0
## Where landmarks are, for picking them out with a tap.
const LANDMARK_LAYER := 1 << 19
## A landmark keeps this far from the edge of the road, as well as its own
## room.
const LANDMARK_GAP := 3.0
const HIGHLIGHT := Color(0.702, 0.616, 1.0, 0.45)

## Each kind of piece's road, made once: key -> [mesh, collision shape].
static var _meshes := {}

var initial_path := ""
var back := Callable()
var _opening := false

var course: CourseDesign
## Where the course was last saved, or "" if it hasn't been.
var path := ""
var ui: TrackEditorUI
## The piece picked out, or -1.
var selected := -1
## New pieces go after this one, or at the end of the road when it's -1.
var insert_after := -1
var track: TrackPath

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _camera: Camera3D
var _yaw := 0.0
var _pitch := deg_to_rad(-55.0)
var _distance := 400.0
var _focus := Vector3.ZERO
var _focus_goal := Vector3.ZERO
var _following := false
var _ground: MeshInstance3D
## The sky and sun, which go with the course's theme.
var _sky: Node3D
var _sky_theme := ""
var _quick: Node3D
var _full: TrackBuilder
var _build_in := -1.0
var _marks: Node3D
var _end_marker: MeshInstance3D
var _highlight: StandardMaterial3D
## The landmark in hand: { "prop", "at", "facing", "index" } (index is -1 for
## a new one), or empty.
var _holding := {}
var _ghost: Node3D
var _closing := -1
var _closer_result: Array = []
var _closer_source: Dictionary = {}
var _ghost_look: StandardMaterial3D
var _join_spec: Dictionary = {}
var _join_source: Dictionary = {}
var _join_preview: MeshInstance3D

## Painting: the squares of the course as one flat mesh for while you paint
## and until the smooth ground is built, the squares under the brush, where
## the brush is, whether a stroke is going and what it does.
var _paint_view: MultiMeshInstance3D
var _brush_view: MultiMeshInstance3D
var _brush_at := Vector3.ZERO
var _stroke := false
var _stroke_erases := false
var _stroke_last := Vector3.ZERO
var _stroke_changed := false
var _stroke_undo := {}
## What the brush showed last (see _update_brush()).
var _brush_key := []

## Sculpting: the ground map drawn straight from its points while it's being
## worked on and until the full build, the ring round the brush laid on it,
## red marks where the course has a problem with its ground, the hills as a
## map for the brush before the first stroke makes one, the Flatten height
## and the road's levels for Level to road.
var _relief_view: MeshInstance3D
## The flat ground's own look, and the look it takes round a map: flat at
## the map's edge, drawn like the map so the map isn't lost under it.
var _ground_look: Material
var _far_look: ShaderMaterial
var _relief_heights: ImageTexture
var _relief_size := Vector2i.ZERO
var _ring: MeshInstance3D
var _ring_key := []
var _problem_view: MultiMeshInstance3D
var _unbaked: GroundMap
var _sculpt_target := 0.0
var _road_levels: GroundBrush.RoadLevels

var _fingers := {}
var _press_at := Vector2.ZERO
var _dragging := false
var _several_fingers := false
var _pinch_start := 0.0
var _pinch_distance_start := 0.0


func _init(from := "", leave := Callable()) -> void:
	initial_path = from
	back = leave


func _ready() -> void:
	_opening = initial_path != ""
	if initial_path != "":
		course = CourseDesign.load_file(initial_path)
		path = initial_path
	elif FileAccess.file_exists(CURRENT):
		var data = JSON.parse_string(FileAccess.get_file_as_string(CURRENT))
		if data is Dictionary:
			course = CourseDesign.from_dict(data.get("course", {}))
			path = str(data.get("path", ""))
	if course == null or (initial_path == "" and course.pieces.is_empty()):
		course = CourseDesign.starter()
		path = ""
	if course.made_by == "":
		course.made_by = Game.player_name()
	_sky = Node3D.new()
	add_child(_sky)
	_ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	_ground.mesh = plane
	_ground.position.y = -0.05
	add_child(_ground)
	_quick = Node3D.new()
	add_child(_quick)
	_marks = Node3D.new()
	add_child(_marks)
	_end_marker = MeshInstance3D.new()
	var arrow := PrismMesh.new()
	arrow.size = Vector3(6.0, 6.0, 0.6)
	_end_marker.mesh = arrow
	var arrow_look := StandardMaterial3D.new()
	arrow_look.albedo_color = MenuStyle.ACCENT
	arrow_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_end_marker.material_override = arrow_look
	add_child(_end_marker)
	_highlight = StandardMaterial3D.new()
	_highlight.albedo_color = HIGHLIGHT
	_highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint_view = _squares_view(0.25)
	_brush_view = _squares_view(0.5)
	_make_relief_view()
	_camera = Camera3D.new()
	# The course is seen from well back, so the near plane can be too, or the
	# grass flickers through the road.
	_camera.near = 1.0
	_camera.far = 6000.0
	add_child(_camera)
	_camera.make_current()

	ui = TrackEditorUI.new()
	add_child(ui)
	# A controller works the editor its own way (see TrackEditorPad).
	var pad := TrackEditorPad.new()
	pad.editor = self
	add_child(pad)
	ui.piece_chosen.connect(add_piece)
	ui.landmark_chosen.connect(pick_up_landmark)
	ui.undo_pressed.connect(undo)
	ui.redo_pressed.connect(redo)
	ui.fit_pressed.connect(fit_view)
	ui.menu_pressed.connect(go_back)
	ui.new_pressed.connect(func() -> void:
		_remember(true)
		course = CourseDesign.starter()
		course.made_by = Game.player_name()
		path = ""
		_select(-1)
		_refresh(true)
		fit_view())
	ui.save_pressed.connect(save)
	ui.load_chosen.connect(load_course)
	ui.share_pressed.connect(share)
	ui.name_changed.connect(func(text: String) -> void:
		_remember()
		course.name = text
		_refresh())
	ui.laps_changed.connect(func(by: int) -> void:
		_remember()
		course.laps = clampi(course.laps + by, 1, 9)
		_refresh())
	ui.map_rotation_changed.connect(rotate_map)
	ui.theme_chosen.connect(func(id: String) -> void:
		_remember()
		course.theme = id
		_refresh())
	ui.road_colour_chosen.connect(func(id: String) -> void:
		_remember()
		course.road_colour = id
		_refresh())
	ui.hills_chosen.connect(func(hills: float) -> void:
		# Picking hills clears a ground map, in the same undo step.
		_remember()
		course.hills = hills
		course.ground = null
		_refresh())
	ui.weather_chosen.connect(func(weather: String) -> void:
		_remember()
		course.weather = weather
		_refresh())
	ui.time_chosen.connect(func(time: String) -> void:
		_remember()
		course.time = time
		_refresh())
	ui.close_up_pressed.connect(close_up)
	ui.join_ends_pressed.connect(join_ends)
	ui.join_accepted.connect(accept_join)
	ui.join_cancelled.connect(cancel_join)
	ui.dimension_changed.connect(set_dimension)
	ui.setting_stepped.connect(step_setting)
	ui.delete_pressed.connect(delete_selected)
	ui.add_after_pressed.connect(func() -> void:
		insert_after = selected
		ui.set_hint("New pieces go in after piece %d" % (selected + 1))
		_refresh())
	ui.surface_chosen.connect(func(surface: String) -> void: _set_on_selected("surface", surface, "asphalt"))
	ui.edges_chosen.connect(func(edges: String) -> void: _set_on_selected("edges", edges, "auto"))
	ui.deselect_pressed.connect(_select.bind(-1))
	ui.turn_landmark_pressed.connect(func() -> void:
		if not _holding.is_empty():
			_holding.facing = (int(_holding.facing) + 1) % 4
			_show_ghost())
	ui.drop_landmark_pressed.connect(drop_landmark)
	ui.remove_landmark_pressed.connect(remove_landmark)
	ui.drive_pressed.connect(test_drive)
	ui.race_pressed.connect(race)
	_select(-1)
	_refresh(true)
	fit_view()
	_opening = false


## The editor has its own way of using a controller and the keys.
func own_controls() -> bool:
	return true


func go_back() -> void:
	cancel_join()
	if back.is_valid():
		back.call()
	else:
		Game.show_editors()


# Changing the course.

## Clicks a piece on after the picked out piece, or onto the end of the road.
func add_piece(spec: Dictionary) -> void:
	_drop_holding()
	_remember()
	var at := insert_after + 1 if insert_after >= 0 else course.pieces.size()
	course.pieces.insert(at, spec)
	if insert_after >= 0:
		insert_after = at
		selected = at
	Sounds.play("fx/snap", 0.0, randf_range(0.95, 1.05))
	_refresh()
	_follow(at)


func delete_selected() -> void:
	if selected < 0 or selected >= course.pieces.size():
		return
	_remember()
	course.pieces.remove_at(selected)
	Sounds.play("fx/unsnap")
	_select(-1)
	_refresh()


func _set_on_selected(key: String, value: String, plain: String) -> void:
	if selected < 0 or selected >= course.pieces.size():
		return
	_remember()
	var spec: Dictionary = course.pieces[selected]
	if value == plain:
		spec.erase(key)
	else:
		spec[key] = value
	ui.show_selection(selected, spec)
	_refresh()


func set_dimension(key: String, value: float) -> void:
	if selected < 0 or selected >= course.pieces.size() or key not in ["metres", "shift", "island"] or not is_finite(value):
		return
	var spec := TrackPiece.adjustable_spec(course.pieces[selected])
	if spec.is_empty() or (key == "shift" and spec.type != "adjustable_offset") or (key == "island" and spec.type != "adjustable_split"):
		return
	var split: bool = spec.type == "adjustable_split"
	var valid: bool
	match key:
		"metres":
			var least := TrackPiece.SPLIT_LEAST_METRES if split else 2.0 if spec.type == "adjustable_offset" else 0.25
			var most := TrackPiece.SPLIT_MOST_METRES if split else TrackPiece.MAX_METRES
			valid = value >= least and value <= most
		"island":
			valid = value >= TrackPiece.SPLIT_LEAST_ISLAND and value <= TrackPiece.SPLIT_MOST_ISLAND
		_:
			valid = absf(value) <= TrackPiece.MAX_SHIFT
	if not valid or is_equal_approx(float(spec.get(key, 0.0)), value):
		ui.show_selection(selected, course.pieces[selected])
		return
	spec[key] = value
	if not TrackPiece.from_spec(spec).safe_dimensions(course.width):
		if split:
			ui.toast("That island is too wide for its length. Make it longer or the island narrower.")
		else:
			ui.toast("That offset is too tight. Increase its length or reduce Sideways.")
		ui.show_selection(selected, course.pieces[selected])
		return
	_remember()
	course.pieces[selected] = spec
	ui.show_selection(selected, spec)
	_refresh()


## Moves the selected piece's rise, bank, height or hump length one step
## along what TrackCatalogue.steps allows.
func step_setting(key: String, direction: int) -> void:
	if selected < 0 or selected >= course.pieces.size():
		return
	var spec: Dictionary = course.pieces[selected].duplicate(true)
	var values := TrackCatalogue.steps(spec, key)
	if values.is_empty():
		return
	var now := TrackCatalogue.setting(spec, key)
	var at := 0
	for k in values.size():
		if absf(float(values[k]) - now) < absf(float(values[at]) - now):
			at = k
	var to := clampi(at + direction, 0, values.size() - 1)
	if to == at and absf(float(values[at]) - now) < 0.0001:
		return
	var value: float = values[to]
	var field := TrackCatalogue.setting_key(key)
	if key in ["rise", "bank"] and is_zero_approx(value):
		spec.erase(field)
	elif key == "hump":
		spec[field] = int(value)
	else:
		spec[field] = value
	_remember()
	course.pieces[selected] = spec
	ui.show_selection(selected, spec)
	_refresh()


func join_ends() -> void:
	cancel_join(false)
	if _closing != -1:
		ui.toast("Wait for Close it up to finish.")
		return
	if course.pieces.is_empty() or track.closes:
		return
	var end := course.start
	for spec in course.pieces:
		end = TrackPath.advance_pose(end, TrackPiece.from_spec(spec))
	if course.hills != 0.0 or absf(course.start.origin.y) > 0.001 or absf(end.origin.y) > 0.001:
		ui.toast("Join ends needs two ground-level ends on flat ground.")
		return
	var spec := TrackPiece.connector_spec(end.affine_inverse() * course.start, course.width)
	if spec.is_empty():
		ui.toast("These ends need more room for a smooth join.")
		return
	var proposed := course.duplicate_design()
	proposed.pieces.append(spec)
	var joined := proposed.track()
	if not joined.closes or not joined.clashes(5.0, true).is_empty():
		ui.toast("The proposed join runs into raised road or walls.")
		return
	_drop_holding()
	_select(-1)
	_join_spec = spec
	_join_source = course.to_dict().duplicate(true)
	_join_preview = MeshInstance3D.new()
	_join_preview.mesh = TrackBuilder.piece_mesh(spec, course.width, course.theme, course.road_colour)
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.25, 0.85, 1.0, 0.65)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.no_depth_test = true
	_join_preview.material_override = look
	_join_preview.transform = end
	add_child(_join_preview)
	ui.show_join_preview(true)
	_focus_goal = end.origin.lerp(course.start.origin, 0.5)
	_following = true


func cancel_join(restore_controls := true) -> void:
	var active := not _join_spec.is_empty()
	_join_spec = {}
	_join_source = {}
	if is_instance_valid(_join_preview):
		_join_preview.queue_free()
	_join_preview = null
	if is_instance_valid(ui):
		ui.show_join_preview(false, active and restore_controls)


func accept_join() -> void:
	if _join_spec.is_empty():
		return
	if course.to_dict() != _join_source:
		cancel_join()
		ui.toast("The layout changed. Try Join ends again.")
		return
	var spec := _join_spec.duplicate(true)
	cancel_join(false)
	_remember()
	course.pieces.append(spec)
	insert_after = -1
	_select(-1)
	_refresh()
	Sounds.play("fx/snap")


## Looks for pieces to join the end of the road back to the start. It can
## take a moment on a phone, so it works on another thread.
func close_up() -> void:
	cancel_join()
	if _closing != -1:
		return
	ui.set_hint("Working out how to close it up...")
	_closer_source = course.to_dict().duplicate(true)
	_closer_result = []
	_closing = WorkerThreadPool.add_task(_closer(course.duplicate_design(), _closer_result))


## What looks for the pieces on the other thread. It's made away from the
## editor, so leaving while it works is fine.
static func _closer(working: CourseDesign, into: Array) -> Callable:
	return func() -> void: into.append_array(working.close_up())


func _exit_tree() -> void:
	if _closing != -1:
		WorkerThreadPool.wait_for_task_completion(_closing)
		_closing = -1


func _finish_closing() -> void:
	WorkerThreadPool.wait_for_task_completion(_closing)
	_closing = -1
	ui.set_hint("")
	if course.to_dict() != _closer_source:
		ui.toast("The layout changed. Try Close it up again.")
		return
	if _closer_result.is_empty():
		ui.show_close_failure()
		Sounds.play("fx/nope")
		return
	_remember()
	course.pieces.append_array(_closer_result)
	insert_after = -1
	_select(-1)
	Sounds.play("fx/snap")
	ui.toast("Closed up with %d piece%s" % [_closer_result.size(), "" if _closer_result.size() == 1 else "s"])
	_refresh()


func undo() -> void:
	if _undo.is_empty():
		return
	var step: Dictionary = _undo.pop_back()
	_redo.append(_snapshot(step.has("creation_path")))
	_restore(step)
	_restart_stroke()
	_select(-1)
	_refresh()


func redo() -> void:
	if _redo.is_empty():
		return
	var step: Dictionary = _redo.pop_back()
	_undo.append(_snapshot(step.has("creation_path")))
	_restore(step)
	_restart_stroke()
	_select(-1)
	_refresh()


## A stroke still going on through an undo or redo carries on as a new one,
## so the rest of it is its own undo step.
func _restart_stroke() -> void:
	if _stroke:
		_stroke_changed = false
		_stroke_undo = _snapshot()


func _snapshot(identity := false) -> Dictionary:
	var step := course.to_dict()
	if back.is_valid() and identity:
		step["creation_path"] = path
	return step


func _restore(step: Dictionary) -> void:
	course = CourseDesign.from_dict(step)
	if back.is_valid() and step.has("creation_path"):
		path = str(step.get("creation_path", ""))


func _remember(identity := false) -> void:
	_undo.append(_snapshot(identity))
	if _undo.size() > 100:
		_undo.pop_front()
	_redo.clear()


func _select(index: int) -> void:
	selected = index
	if index == -1:
		insert_after = -1
	ui.show_selection(index, course.pieces[index] if index >= 0 and index < course.pieces.size() else {})
	_apply_highlight()
	_update_hint()


func _update_hint() -> void:
	if not _holding.is_empty():
		ui.set_hint("Drag the landmark where you want it, off the road")
	elif insert_after >= 0:
		ui.set_hint("New pieces go in after piece %d" % (insert_after + 1))
	elif selected >= 0:
		ui.set_hint("")
	elif track != null and not track.closes:
		ui.set_hint("Tap a piece to click it onto the end of the road")
	else:
		ui.set_hint("")


# Files.

## Saves the course. A finished one gets its start line moved onto its
## longest straight first, where the grid has room.
func save() -> String:
	_drop_holding()
	if course.problems().is_empty():
		var moved := course.with_start_on_longest_straight()
		if JSON.stringify(moved.to_dict()) != JSON.stringify(course.to_dict()):
			_remember()
			course = moved
			_select(-1)
	if course.made_by == "":
		course.made_by = Game.player_name()
	if back.is_valid():
		var result := CreationLibrary.save(Sharing.COURSE, path if path != "" else Sharing.path_for(Sharing.COURSE, course.name), course.to_dict(), path != "")
		if result.has("why"):
			ui.toast(result.why)
			return ""
		path = result.path
	else:
		path = course.save(path if path.begins_with(CourseDesign.FOLDER) else "")
	ui.toast("Saved" if path != "" else "I couldn't save it")
	_refresh()
	return path


## Saves the course and sends it to someone else (see ShareWindow).
func share() -> void:
	if save() != "":
		ShareWindow.open(course.to_dict(), ui)


## Loads a course of yours, or a copy of one of the game's to build on.
func load_course(from: String) -> void:
	var loaded := CourseDesign.load_file(from)
	if loaded == null:
		ui.toast("I couldn't load that course")
		return
	_remember(true)
	course = loaded
	if course.made_by == "":
		course.made_by = Game.player_name()
	path = from if from.begins_with(CourseDesign.FOLDER) else ""
	_select(-1)
	_refresh(true)
	fit_view()


func _keep() -> void:
	if _opening:
		return
	var file := FileAccess.open(CURRENT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"path": path, "course": course.to_dict()}))


# Driving on it.

## Drives it on your own with no laps to count, then comes back here.
func test_drive() -> void:
	if not course.problems().is_empty():
		ui.toast("It needs to be finished before you can drive it")
		Sounds.play("fx/nope")
		return
	var saved := save()
	if saved != "":
		Game.start_course(Game.MODE_PRACTICE, saved, true)


func race() -> void:
	if not course.problems().is_empty():
		Sounds.play("fx/nope")
		return
	var saved := save()
	if saved != "":
		Game.mode = Game.MODE_RACE
		Game.show_race_setup(Game.start_course.bind(Game.MODE_RACE, saved, true), Game.show_track_editor, true, false, true)


# Landmarks.

func pick_up_landmark(prop: String) -> void:
	_select(-1)
	var ahead := _ground_point(get_viewport().get_visible_rect().size * 0.5)
	_holding = {"prop": prop, "at": [ahead.x, ahead.z], "facing": 0, "index": -1}
	_show_ghost()
	ui.show_landmark_in_hand(true)
	_update_hint()


func drop_landmark() -> void:
	if _holding.is_empty():
		return
	if not _clear_of_road(_holding):
		ui.toast("That's too close to the road")
		Sounds.play("fx/nope")
		return
	_remember()
	var mark := {"prop": _holding.prop, "at": [snappedf(_holding.at[0], 0.5), snappedf(_holding.at[1], 0.5)], "facing": _holding.facing}
	if int(_holding.index) >= 0:
		course.landmarks[int(_holding.index)] = mark
	else:
		course.landmarks.append(mark)
	_holding = {}
	Sounds.play("fx/drop")
	_show_ghost()
	ui.show_landmark_in_hand(false)
	_refresh()


func remove_landmark() -> void:
	if _holding.is_empty():
		return
	if int(_holding.index) >= 0:
		_remember()
		course.landmarks.remove_at(int(_holding.index))
	_holding = {}
	Sounds.play("fx/unsnap")
	_show_ghost()
	ui.show_landmark_in_hand(false)
	_refresh()


## Puts back a landmark that was picked up, if it's clear.
func _drop_holding() -> void:
	if _holding.is_empty():
		return
	_holding = {}
	_show_ghost()
	ui.show_landmark_in_hand(false)
	_refresh()


func _clear_of_road(mark: Dictionary) -> bool:
	var at := Vector2(float(mark.at[0]), float(mark.at[1]))
	var room: float = Props.ROOM.get(mark.prop, 3.0) + course.width * 0.5 + TrackPath.KERB + TrackBuilder.WALL_THICKNESS + LANDMARK_GAP
	for p in track.points:
		if Vector2(p.x, p.z).distance_to(at) < room:
			return false
	return not _in_paint(at, Props.ROOM.get(mark.prop, 3.0))


## Whether ground that sinks or burns is at the point or within `room` of it.
func _in_paint(at: Vector2, room: float) -> bool:
	if track != null and track.waters.has_real():
		track.waters.ensure(track)
		if track.waters.covered(Vector3(at.x, 0.0, at.y), room):
			return true
	var paint := Scenery.paint_of(track) if track != null else course.paint
	if not paint.has_deep():
		return false
	var spots := [Vector2.ZERO]
	for k in 8:
		spots.append(Vector2.from_angle(k * TAU / 8.0) * room)
	for spot: Vector2 in spots:
		var kind := paint.kind_at(at.x + spot.x, at.y + spot.y)
		if kind != "" and PaintedAreas.effect_of(kind) != "":
			return true
	return false


func _show_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _holding.is_empty():
		_rebuild_landmarks()
		return
	_ghost = _landmark_node(_holding, -1)
	add_child(_ghost)
	var ok := _clear_of_road(_holding)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	var room: float = Props.ROOM.get(_holding.prop, 3.0)
	disc.top_radius = room
	disc.bottom_radius = room
	disc.height = 0.2
	ring.mesh = disc
	_ghost_look = StandardMaterial3D.new()
	_ghost_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_look.albedo_color = _ring_colour(ok)
	ring.material_override = _ghost_look
	_ghost.add_child(ring)
	_rebuild_landmarks()


## One landmark, built of bricks, with something to tap it by.
func _landmark_node(mark: Dictionary, index: int) -> Node3D:
	var node := StaticBody3D.new()
	node.collision_layer = LANDMARK_LAYER
	node.collision_mask = 0
	node.set_meta("landmark", index)
	var at := Vector3(float(mark.at[0]), _ground_height(float(mark.at[0]), float(mark.at[1])), float(mark.at[1]))
	node.position = at
	var kit := SceneryKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(course.name) + index
	# Built where it stands, then moved back onto the body, so props seeded
	# by their spot look the same as in the race.
	Props.add(kit, str(mark.prop), at, rng, int(mark.get("facing", 0)))
	var look := Node3D.new()
	look.position = -at
	node.add_child(look)
	kit.build(look)
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = Props.ROOM.get(mark.prop, 3.0)
	shape.shape = ball
	shape.position.y = ball.radius * 0.5
	if mark.prop in Props.OFF_THE_GROUND:
		shape.position = kit.bounds().get_center() - at
	node.add_child(shape)
	return node


## Green where a landmark can go, red where it's too close to the road.
static func _ring_colour(ok: bool) -> Color:
	return Color(0.3, 1.0, 0.4, 0.4) if ok else Color(1.0, 0.3, 0.3, 0.5)


func _rebuild_landmarks() -> void:
	for child in _marks.get_children():
		child.queue_free()
	for i in course.landmarks.size():
		# The one in hand is shown as the ghost instead.
		if not _holding.is_empty() and int(_holding.index) == i:
			continue
		_marks.add_child(_landmark_node(course.landmarks[i], i))


# Laying the course out.

func rotate_map(by: float) -> void:
	_remember()
	course.map_rotation = fposmod(course.map_rotation + by, 360.0)
	_refresh()


func _refresh(immediate := false) -> void:
	cancel_join(false)
	track = course.track()
	# A ground map grows to cover new road.
	if course.ground != null:
		var bigger := GroundBrush.grown(course.ground, track)
		if bigger != null:
			course.ground = bigger
			track = course.track()
	_unbaked = null
	_lay_out()
	_rebuild_landmarks()
	if _sky_theme != course.theme:
		# The sky, sun and ground the course will have when you race on it.
		_sky_theme = course.theme
		for child in _sky.get_children():
			child.queue_free()
		var look := Scenery.theme_named(course.theme)
		SkyAndSun.add_to(_sky, 400.0, Color.TRANSPARENT, look.get("sky", []))
		_ground_look = TrackBuilder.ground_material(look)
		_ground.material_override = _ground_look
	var problems := course.problems(track)
	_show_problem_spots()
	ui.show_course(course, track.length, problems, not track.closes and not course.pieces.is_empty(), track, course.warnings(track))
	ui.set_undo_state(not _undo.is_empty(), not _redo.is_empty())
	_update_hint()
	_keep()
	# The whole course gets built properly once you stop for a moment.
	if _full != null:
		_full.queue_free()
		_full = null
	_quick.visible = true
	_show_squares(true)
	_show_relief()
	_build_in = IDLE_BUILD
	# A course being opened or replaced is complete before its first draw.
	if immediate:
		_build_full()


## Puts each piece's road where it goes, from the ones already made.
func _lay_out() -> void:
	var nodes := _quick.get_children()
	for i in track.pieces.size():
		var spec: Dictionary = course.pieces[i]
		var key := "%s %s %s %s" % [JSON.stringify(spec), course.width, course.theme, course.road_colour]
		var adjustable: bool = spec.get("type") in TrackPiece.ADJUSTABLE_TYPES
		if not adjustable and not _meshes.has(key):
			var mesh := TrackBuilder.piece_mesh(spec, course.width, course.theme, course.road_colour)
			_meshes[key] = [mesh, mesh.create_trimesh_shape() if mesh != null else null]
		var body: StaticBody3D
		if i < nodes.size():
			body = nodes[i]
		else:
			body = StaticBody3D.new()
			body.collision_layer = Kart.LAYER_WORLD
			var look := MeshInstance3D.new()
			look.material_override = TrackBuilder.road_material()
			body.add_child(look)
			body.add_child(CollisionShape3D.new())
			_quick.add_child(body)
		body.set_meta("piece", i)
		if adjustable:
			# Metric edits keep only the current mesh, rather than every prior value.
			if body.get_meta("mesh_key", "") != key:
				var mesh := TrackBuilder.piece_mesh(spec, course.width, course.theme, course.road_colour)
				(body.get_child(0) as MeshInstance3D).mesh = mesh
				(body.get_child(1) as CollisionShape3D).shape = mesh.create_trimesh_shape() if mesh != null else null
		else:
			(body.get_child(0) as MeshInstance3D).mesh = _meshes[key][0]
			(body.get_child(1) as CollisionShape3D).shape = _meshes[key][1]
		body.set_meta("mesh_key", key)
		body.transform = track.piece_starts[i]
	for i in range(track.pieces.size(), nodes.size()):
		nodes[i].queue_free()
	# The arrow shows where the next piece clicks on.
	var end := _insert_pose()
	_end_marker.visible = not track.closes or insert_after >= 0
	_end_marker.transform = end * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 1.5, -4.0))
	_apply_highlight()


## Where the next piece will click on.
func _insert_pose() -> Transform3D:
	var pose := course.start
	var upto := insert_after + 1 if insert_after >= 0 else course.pieces.size()
	for i in upto:
		pose = TrackPath.advance_pose(pose, TrackPiece.from_spec(course.pieces[i]))
	return pose


func _apply_highlight() -> void:
	for root in [_quick, _full]:
		if root == null:
			continue
		for body in root.get_children():
			if body is StaticBody3D and body.has_meta("piece"):
				for look in body.get_children():
					if look is MeshInstance3D:
						look.material_overlay = _highlight if int(body.get_meta("piece")) == selected else null


func _process(delta: float) -> void:
	if _closing != -1 and WorkerThreadPool.is_task_completed(_closing):
		_finish_closing()
	if _build_in > 0.0:
		_build_in -= delta
		if _build_in <= 0.0:
			_build_full()
	if ui.painting():
		_update_brush()
	elif _brush_view.visible:
		_brush_view.visible = false
	if ui.sculpting():
		if _stroke:
			sculpt_for(delta)
		_update_ring()
	elif _ring.visible:
		_ring.visible = false
	if _following:
		_focus = _focus.lerp(_focus_goal, 1.0 - exp(-delta * 4.0))
		_place_camera()
		if _focus.distance_to(_focus_goal) < 0.5:
			_following = false


func _build_full() -> void:
	_build_in = -1.0
	if _full != null or track.pieces.is_empty():
		return
	_full = TrackBuilder.new(track)
	_full.scenery = "sea"
	_full.sky = false
	add_child(_full)
	_quick.visible = false
	_ground.visible = false
	_paint_view.visible = false
	_relief_view.visible = false
	_apply_highlight()


# The camera.

## Backs off until the whole course is in view.
func fit_view() -> void:
	if track == null or track.points.is_empty():
		return
	var box := AABB(track.points[0], Vector3.ZERO)
	for p in track.points:
		box = box.expand(p)
	for mark in course.landmarks:
		box = box.expand(Vector3(float(mark.at[0]), 0.0, float(mark.at[1])))
	_focus = box.get_center()
	_focus_goal = _focus
	_following = false
	var radius := maxf(box.size.length() * 0.5, 40.0)
	_distance = clampf(radius / sin(deg_to_rad(_camera.fov * 0.5)) * 0.9, MIN_DISTANCE, MAX_DISTANCE)
	_place_camera()


## Glides the view over to where the road's got to.
func _follow(index: int) -> void:
	if index < track.piece_starts.size():
		var end := _insert_pose()
		_focus_goal = end.origin
		_following = true


func _place_camera() -> void:
	var offset := Vector3(0.0, 0.0, _distance).rotated(Vector3.RIGHT, _pitch).rotated(Vector3.UP, _yaw)
	_camera.position = _focus + offset
	_camera.look_at(_focus, Vector3.UP)


func _orbit(by: Vector2) -> void:
	_yaw -= by.x * ORBIT_SPEED
	_pitch = clampf(_pitch - by.y * ORBIT_SPEED, deg_to_rad(-89.0), deg_to_rad(-10.0))
	_place_camera()


func _pan(by: Vector2) -> void:
	var scale := _distance * 0.0016
	var right := _camera.global_basis.x
	var ahead := Vector3(-right.z, 0.0, right.x)
	_focus += (-right * by.x - ahead * by.y) * scale
	_following = false
	_place_camera()


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	_place_camera()


## Where this screen point lands on the ground: the course's ground map, or
## the hills as a map on the Ground tab before there is one, or flat ground.
func _ground_point(pos: Vector2) -> Vector3:
	var from := _camera.project_ray_origin(pos)
	var dir := _camera.project_ray_normal(pos)
	if absf(dir.y) < 0.001:
		return _focus
	var map := course.ground if course.ground != null else _relief() if ui != null and ui.sculpting() else null
	if map == null or dir.y > -0.001:
		var t := -from.y / dir.y
		return from + dir * maxf(t, 0.0)
	# Marched along in 4 m steps between the map's highest and lowest, then
	# narrowed down to where it meets the ground.
	var low := INF
	var high := -INF
	for h in map.heights:
		low = minf(low, h)
		high = maxf(high, h)
	var t := maxf((high + 1.0 - from.y) / dir.y, 0.0)
	var last := maxf((low - 1.0 - from.y) / dir.y, t)
	var above := t
	while t <= last:
		var p := from + dir * t
		if p.y <= map.height_at(p.x, p.z):
			var below := t
			for i in 12:
				var middle := (above + below) * 0.5
				var q := from + dir * middle
				if q.y <= map.height_at(q.x, q.z):
					below = middle
				else:
					above = middle
			return from + dir * below
		above = t
		t += 4.0
	return from + dir * last


# Touches.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseMotion and ui.brushing() and not _stroke:
		move_brush(_ground_point(event.position))
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_DELETE, KEY_BACKSPACE:
				delete_selected()
			KEY_Z:
				if event.ctrl_pressed:
					redo() if event.shift_pressed else undo()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if ui.is_over_ui(event.position):
			return
		_fingers[event.index] = event.position
		if _fingers.size() == 1:
			_press_at = event.position
			_dragging = false
			_several_fingers = false
		else:
			_several_fingers = true
			paint_end()
			_start_pinch()
		return
	if not _fingers.has(event.index):
		return
	_fingers.erase(event.index)
	if _fingers.is_empty():
		if _stroke:
			paint_end()
		elif not _several_fingers and not _dragging:
			if ui.brushing():
				paint_begin(_ground_point(event.position))
				paint_end()
			else:
				_tap(event.position)
		_several_fingers = false
	else:
		_start_pinch()


func _tap(pos: Vector2) -> void:
	if not _holding.is_empty():
		# With a landmark in hand, a tap puts it there.
		var at := _ground_point(pos)
		_holding.at = [at.x, at.z]
		_show_ghost()
		return
	var hit := _cast(pos, Kart.LAYER_WORLD | LANDMARK_LAYER)
	if hit.is_empty():
		_select(-1)
		return
	var body: Object = hit.collider
	if body.has_meta("landmark") and int(body.get_meta("landmark")) >= 0:
		var index := int(body.get_meta("landmark"))
		var mark: Dictionary = course.landmarks[index]
		_select(-1)
		_holding = {"prop": mark.prop, "at": mark.at.duplicate(), "facing": int(mark.get("facing", 0)), "index": index}
		_show_ghost()
		ui.show_landmark_in_hand(true)
		_update_hint()
	elif body.has_meta("piece"):
		var index := int(body.get_meta("piece"))
		_select(-1 if index == selected else index)
		if selected >= 0:
			Sounds.play("fx/pick")
	else:
		_select(-1)


func _cast(pos: Vector2, mask: int) -> Dictionary:
	var from := _camera.project_ray_origin(pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + _camera.project_ray_normal(pos) * 4000.0, mask)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _fingers.has(event.index):
		return
	_fingers[event.index] = event.position
	if _fingers.size() >= 2:
		var points: Array = _fingers.values()
		var spread: float = points[0].distance_to(points[1])
		if _pinch_distance_start > 0.0 and spread > 0.0:
			_distance = clampf(_pinch_start * _pinch_distance_start / spread, MIN_DISTANCE, MAX_DISTANCE)
		_pan(event.relative / _fingers.size())
		return
	if ui.brushing():
		# One finger paints or sculpts, from where it first went down.
		_dragging = true
		var at := _ground_point(event.position)
		if not _stroke:
			paint_begin(_ground_point(_press_at))
		# With the Lake tool, up and down raise and lower its level.
		if water_tool() and ui.ground_tool == "lake":
			water_lift(-event.relative.y * LIFT_PER_PIXEL)
			return
		paint_to(at)
		return
	if not _dragging and event.position.distance_to(_press_at) > DRAG_START:
		_dragging = true
	if not _dragging:
		return
	# A landmark in hand follows your finger.
	if not _holding.is_empty() and _ghost != null and _camera.unproject_position(_ghost.global_position).distance_to(_press_at) < GRAB_RADIUS * 2.0:
		var at := _ground_point(event.position)
		_holding.at = [at.x, at.z]
		_ghost.position = Vector3(at.x, _ground_height(at.x, at.z), at.z)
		_ghost_look.albedo_color = _ring_colour(_clear_of_road(_holding))
		_press_at = event.position
		return
	_orbit(event.relative)


# Painting.

## A flat mesh of squares, each its own colour, for showing painted ground
## quickly.
func _squares_view(height: float) -> MultiMeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * PaintedAreas.CELL
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = look
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = plane
	var view := MultiMeshInstance3D.new()
	view.multimesh = multi
	view.position.y = height
	view.visible = false
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view


## Puts squares in a view: each one is [square, colour].
func _fill_squares(view: MultiMeshInstance3D, squares: Array) -> void:
	var multi := view.multimesh
	multi.instance_count = squares.size()
	for i in squares.size():
		var middle := PaintedAreas.middle_of(squares[i][0])
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(middle.x, 0.0, middle.y)))
		multi.set_instance_color(i, squares[i][1])


## Shows the course's squares flat, or hides them.
func _show_squares(on: bool) -> void:
	var squares := []
	if on:
		for square: Vector2i in course.paint.squares:
			var colour: Color = PaintedAreas.TYPES[course.paint.squares[square]].colour
			squares.append([square, Color(colour, 0.9)])
	_fill_squares(_paint_view, squares)
	_paint_view.visible = on and not squares.is_empty()


## The type the brush paints, "" for the eraser.
func _brush_type() -> String:
	return ui.paint_type


## The squares under the brush at a point.
func _brush_squares(at: Vector3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var middle := PaintedAreas.square_at(at.x, at.z)
	var reach := 1 if ui.paint_brush >= 3 else 0
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			out.append(middle + Vector2i(dx, dz))
	return out


## Squares the brush can't paint in right now, from where the brush is.
func refused_squares(at: Vector3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var type := _brush_type()
	if type == "" or _stroke_erases:
		return out
	var full := course.paint.full()
	for square in _brush_squares(at):
		if not course.paint.squares.has(square) and (full or not PaintedAreas.within(square)):
			out.append(square)
		elif not PaintedAreas.allowed(square, type, track):
			out.append(square)
	return out


## Shows the squares under the brush: the type's colour, or red where it
## won't paint. It's only worked out again when what it shows can change.
func _update_brush() -> void:
	var key := [PaintedAreas.square_at(_brush_at.x, _brush_at.z), _brush_type(), ui.paint_brush, _stroke_erases, track, course.paint.full()]
	_brush_view.visible = true
	if key == _brush_key:
		return
	_brush_key = key
	var squares := []
	var refused := refused_squares(_brush_at)
	var type := _brush_type()
	var erasing := type == "" or _stroke_erases
	var colour := Color(1, 1, 1, 0.55) if erasing else Color(PaintedAreas.TYPES[type].colour, 0.6)
	for square in _brush_squares(_brush_at):
		squares.append([square, Color(1.0, 0.2, 0.2, 0.7) if refused.has(square) else colour])
	_fill_squares(_brush_view, squares)


## Moves the brush to a point on the ground.
func move_brush(at: Vector3) -> void:
	_brush_at = at


## Starts a stroke at a point, on the Paint tab or the Ground tab (see
## sculpt_begin()). Paint erases if the eraser's picked or the first square
## is already the picked type.
func paint_begin(at: Vector3) -> void:
	if not _stroke and water_tool():
		water_begin(at)
		return
	if not _stroke and ui.sculpting():
		sculpt_begin(at)
		return
	if _stroke or not ui.painting():
		return
	_stroke = true
	_stroke_changed = false
	_brush_at = at
	var type := _brush_type()
	_stroke_erases = type == "" or course.paint.square_type(PaintedAreas.square_at(at.x, at.z)) == type
	_stroke_undo = _snapshot()
	_stroke_last = at
	paint_to(at)


## Paints along from where the stroke was to a point.
func paint_to(at: Vector3) -> void:
	if not _stroke:
		return
	if water_tool():
		water_to(at)
		return
	if ui.sculpting():
		_brush_at = at
		_stroke_last = at
		return
	var type := "" if _stroke_erases else _brush_type()
	var gap := _stroke_last.distance_to(at)
	var steps := maxi(1, ceili(gap / (PaintedAreas.CELL * 0.5)))
	var changed := 0
	for k in range(1, steps + 1):
		var spot := _stroke_last.lerp(at, float(k) / steps)
		changed += course.paint.paint_at(spot.x, spot.z, type, ui.paint_brush, track)
	_stroke_last = at
	_brush_at = at
	if changed == 0:
		return
	if not _stroke_changed:
		# The first change is the step undo goes back over.
		_stroke_changed = true
		_undo.append(_stroke_undo)
		if _undo.size() > 100:
			_undo.pop_front()
		_redo.clear()
		ui.set_undo_state(true, false)
		if _full != null:
			_full.queue_free()
			_full = null
		_quick.visible = true
		_show_relief()
	_show_squares(true)


## Ends the stroke and builds the smooth ground.
func paint_end() -> void:
	if not _stroke:
		return
	if water_tool():
		water_end()
		return
	_stroke = false
	_stroke_erases = false
	if _stroke_changed:
		_stroke_changed = false
		_refresh()


# Sculpting.

## A tap with the brush works it for this long, in seconds.
const TAP := 0.25
## The ring round the brush, how far above the ground and how thick for each
## metre the camera's back.
const RING_LIFT := 0.4
const RING_THICK := 0.004
const RELIEF_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D heights : filter_nearest;
const float PUSH = 8.0;
uniform vec2 origin;
uniform float cell;
uniform ivec2 size;
// Picked as sRGB and turned linear below, since the phone's renderer doesn't
// convert a source_color hint.
uniform vec3 colour = vec3(0.3, 0.6, 0.3);
varying float height;

float map_point(ivec2 at) {
	return texelFetch(heights, clamp(at, ivec2(0), size - ivec2(1)), 0).r;
}

float map_height(vec2 xz) {
	vec2 f = clamp((xz - origin) / cell, vec2(0.0), vec2(size - ivec2(1)));
	ivec2 i = ivec2(floor(f));
	vec2 a = f - vec2(i);
	return mix(mix(map_point(i), map_point(i + ivec2(1, 0)), a.x), mix(map_point(i + ivec2(0, 1)), map_point(i + ivec2(1, 1)), a.x), a.y);
}

void vertex() {
	vec2 xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	height = map_height(xz);
	VERTEX.y = height;
	float e = cell * 0.5;
	NORMAL = normalize(vec3(map_height(xz - vec2(e, 0.0)) - map_height(xz + vec2(e, 0.0)), 2.0 * e, map_height(xz - vec2(0.0, e)) - map_height(xz + vec2(0.0, e))));
	// Drawn as if a few metres further away, so road cut into a hill still
	// shows through it before the full build cuts the ground.
	vec3 seen = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seen *= 1.0 + PUSH / max(length(seen), 1.0);
	POSITION = PROJECTION_MATRIX * vec4(seen, 1.0);
}

void fragment() {
	// Faint lines every 2 m up, so the slopes read from above.
	float line = 1.0 - smoothstep(0.0, fwidth(height) * 1.5, abs(fract(height * 0.5 + 0.5) - 0.5) * 2.0);
	vec3 base = pow(colour, vec3(2.2));
	ALBEDO = mix(base, base * 0.6, line * 0.6);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""


func _make_relief_view() -> void:
	_relief_view = MeshInstance3D.new()
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = RELIEF_SHADER
	_relief_view.material_override = look
	_relief_view.visible = false
	_far_look = ShaderMaterial.new()
	_far_look.shader = look.shader
	# Moved up or down to the map's edge by the shader.
	_ground.extra_cull_margin = GroundBrush.MOST
	_relief_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_relief_view)
	_ring = MeshInstance3D.new()
	_ring.mesh = ImmediateMesh.new()
	var ring_look := StandardMaterial3D.new()
	ring_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_look.vertex_color_use_as_albedo = true
	ring_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_look.no_depth_test = true
	ring_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = ring_look
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_problem_view = MultiMeshInstance3D.new()
	var post := CylinderMesh.new()
	post.top_radius = 5.0
	post.bottom_radius = 5.0
	post.height = 8.0
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.2, 0.2, 0.55)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.no_depth_test = true
	post.material = red
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = post
	_problem_view.multimesh = multi
	_problem_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_problem_view)


## The ground the brush works on: the course's map, or the hills made into
## one (not kept on the course until a stroke changes it). Null with no road.
func _relief() -> GroundMap:
	if course.ground != null:
		return course.ground
	if _unbaked == null and track != null:
		_unbaked = GroundBrush.bake(track)
	return _unbaked


## How high the ground is here, as the editor shows it.
func _ground_height(x: float, z: float) -> float:
	return course.ground.height_at(x, z) if course.ground != null else 0.0


## The map drawn from its points in place of the flat ground until the full
## build, or the flat ground when there's no map. The flat ground stays out
## past the map's edge, a metre under its lowest edge point.
func _show_relief() -> void:
	var void_theme: bool = Scenery.theme_named(course.theme).get("void", false)
	var map := course.ground
	var showing := _full == null
	_ground.visible = showing and not void_theme
	_relief_view.visible = showing and map != null
	var colour := Color(Scenery.theme_named(course.theme).get("ground", "#4b9f4a"))
	if map == null:
		_ground.material_override = _ground_look
		return
	var rim := INF
	for x in map.cols:
		rim = minf(rim, minf(map.height_of(x, 0), map.height_of(x, map.rows - 1)))
	for z in map.rows:
		rim = minf(rim, minf(map.height_of(0, z), map.height_of(map.cols - 1, z)))
	var far := Image.create_from_data(1, 1, false, Image.FORMAT_RF, PackedFloat32Array([rim - 1.0]).to_byte_array())
	_far_look.set_shader_parameter("heights", ImageTexture.create_from_image(far))
	_far_look.set_shader_parameter("origin", Vector2.ZERO)
	_far_look.set_shader_parameter("cell", 1.0)
	_far_look.set_shader_parameter("size", Vector2i.ONE)
	_far_look.set_shader_parameter("colour", colour)
	_ground.material_override = _far_look
	var image := Image.create_from_data(map.cols, map.rows, false, Image.FORMAT_RF, map.heights.to_byte_array())
	var size := Vector2i(map.cols, map.rows)
	if _relief_heights == null or size != _relief_size:
		_relief_heights = ImageTexture.create_from_image(image)
		_relief_size = size
		var plane := PlaneMesh.new()
		plane.size = Vector2(map.cols - 1, map.rows - 1) * map.cell
		plane.subdivide_width = map.cols - 2
		plane.subdivide_depth = map.rows - 2
		_relief_view.mesh = plane
	else:
		_relief_heights.update(image)
	var half := Vector2(map.cols - 1, map.rows - 1) * map.cell * 0.5
	_relief_view.position = Vector3(map.origin.x + half.x, 0.0, map.origin.y + half.y)
	# The mesh is flat, so it's culled by a box as tall as the map can be.
	_relief_view.custom_aabb = AABB(Vector3(-half.x, -GroundBrush.MOST, -half.y), Vector3(half.x * 2.0, GroundBrush.MOST * 2.0, half.y * 2.0))
	var look: ShaderMaterial = _relief_view.material_override
	look.set_shader_parameter("heights", _relief_heights)
	look.set_shader_parameter("origin", map.origin)
	look.set_shader_parameter("cell", map.cell)
	look.set_shader_parameter("size", size)
	look.set_shader_parameter("colour", colour)


## Starts sculpting at a point with the Ground tab's tool. A course with no
## map gets one from its hills when the stroke first changes something.
func sculpt_begin(at: Vector3) -> void:
	if _stroke or not ui.sculpting():
		return
	_stroke = true
	_stroke_changed = false
	_brush_at = at
	_stroke_last = at
	_stroke_undo = _snapshot()
	var map := _relief()
	_sculpt_target = map.height_at(at.x, at.z) if map != null else 0.0
	_road_levels = null
	sculpt_for(TAP)


## Works the brush where it is for `seconds`, while a stroke's going.
func sculpt_for(seconds: float) -> void:
	if not _stroke or not ui.sculpting() or water_tool():
		return
	var map := _relief()
	if map == null:
		return
	if ui.ground_tool == "level" and _road_levels == null:
		_road_levels = GroundBrush.RoadLevels.new(track)
	if not GroundBrush.work(map, ui.ground_tool, Vector2(_brush_at.x, _brush_at.z), ui.ground_brush, seconds, _sculpt_target, _road_levels):
		return
	if course.ground == null:
		course.ground = map
		_unbaked = null
	if not _stroke_changed:
		# The first change is the step undo goes back over.
		_stroke_changed = true
		_undo.append(_stroke_undo)
		if _undo.size() > 100:
			_undo.pop_front()
		_redo.clear()
		ui.set_undo_state(true, false)
		if _full != null:
			_full.queue_free()
			_full = null
		_quick.visible = true
		_build_in = -1.0
	_show_relief()
	_ring_key = []


# Lakes and rivers.

## How far a lake's level moves for each pixel dragged up or down.
const LIFT_PER_PIXEL := 0.03
## How far apart a drawn river's points go, in metres.
const RIVER_GAP := 12.0
## A new lake starts this far over the ground where it's put.
const LAKE_START := 1.0

## The lake or river in course.waters being worked on, or -1.
var _water_body := -1
## A river being drawn, as (x, z, width).
var _river_points := PackedVector3Array()
## The lakes and rivers settled on the course's map, for the live shoreline,
## and the views of it and of a river being drawn.
var _water_preview: Waters
var _water_view: MeshInstance3D
var _water_line: MeshInstance3D


## Whether the Ground tab's Lake, River or Follow the valley tool is picked.
func water_tool() -> bool:
	return ui != null and ui.sculpting() and ui.ground_tool in GroundBrush.WATER_TOOLS


## Starts a stroke with a water tool. Lake: a tap on a lake picks it, a tap
## elsewhere puts a new one there, and dragging up and down moves its level.
## River: drawing lays a river along the stroke, and a tap on one takes it
## away. Follow the valley: a tap starts a river there that runs down the
## ground. Each stroke is one undo step.
func water_begin(at: Vector3) -> void:
	_stroke = true
	_stroke_changed = false
	_stroke_undo = _snapshot()
	_brush_at = at
	_stroke_last = at
	_river_points = PackedVector3Array()
	_water_body = -1
	var map := _relief()
	if map == null:
		return
	var flat := Vector2(at.x, at.z)
	_settle_preview()
	var hit := _water_preview.body_at(flat.x, flat.y)
	var width: float = GroundBrush.RIVER_WIDTHS.get(ui.ground_brush, 12.0)
	var full := course.waters.bodies.size() >= Waters.MOST_BODIES
	match ui.ground_tool:
		"lake":
			if hit >= 0 and course.waters.bodies[hit].kind == "lake":
				_water_body = hit
			elif full:
				ui.toast("That's as many lakes and rivers as a course can have.")
			else:
				_first_water_change()
				course.waters.bodies.append(Waters.make_lake(ui.water_type, flat, map.height_at(flat.x, flat.y) + LAKE_START))
				_water_body = course.waters.bodies.size() - 1
				_water_changed()
		"river":
			if hit >= 0 and course.waters.bodies[hit].kind == "river":
				_water_body = hit
			_river_points.append(Vector3(flat.x, flat.y, width))
			_show_river_line()
		"valley":
			if full:
				ui.toast("That's as many lakes and rivers as a course can have.")
				return
			var area := Rect2(map.origin, Vector2(map.cols - 1, map.rows - 1) * map.cell)
			var points := Waters.follow_valley(map.height_at, flat, width, area)
			if points.size() >= 2:
				_first_water_change()
				course.waters.bodies.append(Waters.make_river(ui.water_type, points))
				_water_body = course.waters.bodies.size() - 1
				_water_changed()


## Draws a river on along the stroke.
func water_to(at: Vector3) -> void:
	_brush_at = at
	_stroke_last = at
	if ui.ground_tool != "river" or _river_points.is_empty():
		return
	var last := _river_points[_river_points.size() - 1]
	if Vector2(last.x, last.y).distance_to(Vector2(at.x, at.z)) >= RIVER_GAP and _river_points.size() < Waters.MOST_POINTS:
		_river_points.append(Vector3(at.x, at.z, last.z))
		_show_river_line()


## Moves the picked lake's level up or down by `metres`.
func water_lift(metres: float) -> void:
	if not _stroke or _water_body < 0 or _water_body >= course.waters.bodies.size():
		return
	var lake: Dictionary = course.waters.bodies[_water_body]
	if lake.kind != "lake" or metres == 0.0:
		return
	_first_water_change()
	lake.level = clampf(lake.level + metres, -GroundBrush.MOST, GroundBrush.MOST)
	# Only this lake fills again while its level moves; the rest settle at the
	# stroke's end.
	_water_changed(_water_body)


## Ends the stroke: a drawn river goes in, a tapped one comes out, and a lake
## left with no water in it is taken away.
func water_end() -> void:
	_stroke = false
	if ui.ground_tool == "lake" and _stroke_changed and _water_preview != null and _water_preview.cols >= 2:
		_water_preview.bodies = Waters.from_dict(course.waters.to_dict()).bodies
		_water_preview.resettle()
	if ui.ground_tool == "river":
		var drawn := _river_points.size() >= 2
		if drawn and course.waters.bodies.size() < Waters.MOST_BODIES:
			_first_water_change()
			course.waters.bodies.append(Waters.make_river(ui.water_type, _river_points))
		elif not drawn and not _dragging and _water_body >= 0:
			_first_water_change()
			course.waters.bodies.remove_at(_water_body)
	elif ui.ground_tool == "lake" and _water_body >= 0 and _water_preview != null and _water_preview.wet_count(_water_body) == 0:
		_first_water_change()
		course.waters.bodies.remove_at(_water_body)
	_river_points = PackedVector3Array()
	_water_body = -1
	if _water_line != null:
		_water_line.visible = false
	if _water_view != null:
		_water_view.visible = false
	if _stroke_changed:
		_stroke_changed = false
		_refresh()


## The first change in a stroke: the step undo goes back over, and the map
## the water sits in if the course had none.
func _first_water_change() -> void:
	if _stroke_changed:
		return
	if course.ground == null:
		course.ground = _relief()
		_unbaked = null
	_stroke_changed = true
	_undo.append(_stroke_undo)
	if _undo.size() > 100:
		_undo.pop_front()
	_redo.clear()
	ui.set_undo_state(true, false)
	if _full != null:
		_full.queue_free()
		_full = null
	_quick.visible = true
	_build_in = -1.0
	_show_relief()


## Settles the course's lakes and rivers on its map, for the live shoreline.
func _settle_preview() -> void:
	var map := _relief()
	_water_preview = Waters.from_dict(course.waters.to_dict())
	if map == null or track == null or track.points.is_empty():
		return
	_water_preview.settle_with(track, map.height_at)


## Settles the lakes again after a change and shows the one being worked on.
## With `only` a lake, just that one fills again at its new level.
func _water_changed(only := -1) -> void:
	if _water_preview == null or _water_preview.cols < 2:
		_settle_preview()
	elif only >= 0 and only < _water_preview.bodies.size() and _water_preview.bodies.size() == course.waters.bodies.size():
		_water_preview.bodies[only].level = course.waters.bodies[only].level
		_water_preview.reflood(only)
	else:
		_water_preview.bodies = Waters.from_dict(course.waters.to_dict()).bodies
		_water_preview.resettle()
	if _water_view == null:
		_water_view = MeshInstance3D.new()
		var look := StandardMaterial3D.new()
		look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		look.vertex_color_use_as_albedo = true
		look.albedo_color = Color(1, 1, 1, 0.85)
		look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		look.cull_mode = BaseMaterial3D.CULL_DISABLED
		_water_view.material_override = look
		_water_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_water_view)
	var b := _water_body
	var mesh: ArrayMesh = null
	if b >= 0 and b < _water_preview.bodies.size():
		mesh = _water_preview.lake_mesh(b) if _water_preview.bodies[b].kind == "lake" else _water_preview.river_mesh(b)
	_water_view.mesh = mesh
	_water_view.visible = mesh != null


## The line of a river being drawn, on the ground.
func _show_river_line() -> void:
	if _water_line == null:
		_water_line = MeshInstance3D.new()
		_water_line.mesh = ImmediateMesh.new()
		_water_line.material_override = _ring.material_override
		_water_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_water_line)
	var mesh: ImmediateMesh = _water_line.mesh
	mesh.clear_surfaces()
	_water_line.visible = _river_points.size() >= 2
	if _river_points.size() < 2:
		return
	var colour: Color = Waters.colours(ui.water_type)[0]
	var map := _relief()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _river_points.size():
		var p := _river_points[i]
		var a := Vector2(_river_points[maxi(i - 1, 0)].x, _river_points[maxi(i - 1, 0)].y)
		var c := Vector2(_river_points[mini(i + 1, _river_points.size() - 1)].x, _river_points[mini(i + 1, _river_points.size() - 1)].y)
		var side := (c - a).normalized().orthogonal() * p.z * 0.5
		for s in [-1.0, 1.0]:
			var spot: Vector2 = Vector2(p.x, p.y) + side * s
			mesh.surface_set_color(colour)
			mesh.surface_add_vertex(Vector3(spot.x, (map.height_at(spot.x, spot.y) if map != null else 0.0) + RING_LIFT, spot.y))
	mesh.surface_end()


## Lays the ring round the brush on the ground, red past the map's edge.
## Only made again when the brush, its size or the ground under it changes.
func _update_ring() -> void:
	var map := _relief()
	var radius: float = GroundBrush.WIDTHS.get(ui.ground_brush, 8.0) * 0.5
	var key := [_brush_at, radius, _distance, map, ui.ground_tool]
	_ring.visible = true
	if key == _ring_key:
		return
	_ring_key = key
	var inside := map != null and Rect2(map.origin, Vector2(map.cols - 1, map.rows - 1) * map.cell).has_point(Vector2(_brush_at.x, _brush_at.z))
	var colour := Color(1, 1, 1, 0.9) if inside else Color(1.0, 0.3, 0.3, 0.9)
	var thick := maxf(_distance * RING_THICK, 0.5)
	var mesh: ImmediateMesh = _ring.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in 49:
		var way := Vector2.from_angle(k * TAU / 48.0)
		for r in [radius - thick * 0.5, radius + thick * 0.5]:
			var spot: Vector2 = Vector2(_brush_at.x, _brush_at.z) + way * r
			var y := (map.height_at(spot.x, spot.y) if map != null else 0.0) + RING_LIFT
			mesh.surface_set_color(colour)
			mesh.surface_add_vertex(Vector3(spot.x, y, spot.y))
	mesh.surface_end()


## Red marks where the road's too steep for the ground or water's dug in.
func _show_problem_spots() -> void:
	var spots := course.ground_problem_spots(track)
	var multi := _problem_view.multimesh
	multi.instance_count = spots.size()
	for i in spots.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, spots[i] + Vector3.UP * 4.0))
	_problem_view.visible = not spots.is_empty()


func _start_pinch() -> void:
	var points: Array = _fingers.values()
	if points.size() >= 2:
		_pinch_start = _distance
		_pinch_distance_start = points[0].distance_to(points[1])
