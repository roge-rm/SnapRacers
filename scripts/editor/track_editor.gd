class_name TrackEditor
extends Node3D

## The track editor. You build a course like a slot car set: every piece you
## pick clicks onto the end of the road, or after the piece you've picked
## out. Tap a piece of road to pick it out and take it out, change its
## surface or walls, or add more after it. Close it up finds the pieces to
## bring the road back around to the start. Landmarks from the drawer go
## wherever you drag them, as long as it's off the road.
##
## The course is laid out again after every change. Each kind of piece's road
## is made once and kept, so that's instant even on a phone, and a moment
## after you stop, the whole course is built properly, with its pillars and
## the start gantry. What you're working on is kept as you go, so it's there
## next time, like the kart in the garage.

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
var _ghost_look: StandardMaterial3D

var _fingers := {}
var _press_at := Vector2.ZERO
var _dragging := false
var _several_fingers := false
var _pinch_start := 0.0
var _pinch_distance_start := 0.0


func _ready() -> void:
	if FileAccess.file_exists(CURRENT):
		var data = JSON.parse_string(FileAccess.get_file_as_string(CURRENT))
		if data is Dictionary:
			course = CourseDesign.from_dict(data.get("course", {}))
			path = str(data.get("path", ""))
	if course == null or course.pieces.is_empty():
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
	_camera = Camera3D.new()
	# The course is seen from well back, so the near plane can be too. Right
	# up close it made the grass flicker through the road from up here.
	_camera.near = 1.0
	_camera.far = 6000.0
	add_child(_camera)
	_camera.make_current()

	ui = TrackEditorUI.new()
	add_child(ui)
	ui.piece_chosen.connect(add_piece)
	ui.landmark_chosen.connect(pick_up_landmark)
	ui.undo_pressed.connect(undo)
	ui.redo_pressed.connect(redo)
	ui.fit_pressed.connect(fit_view)
	ui.menu_pressed.connect(go_back)
	ui.new_pressed.connect(func() -> void:
		_remember()
		course = CourseDesign.starter()
		course.made_by = Game.player_name()
		path = ""
		_select(-1)
		_refresh()
		fit_view())
	ui.save_pressed.connect(save)
	ui.load_chosen.connect(load_course)
	ui.name_changed.connect(func(text: String) -> void:
		_remember()
		course.name = text
		_refresh())
	ui.laps_changed.connect(func(by: int) -> void:
		_remember()
		course.laps = clampi(course.laps + by, 1, 9)
		_refresh())
	ui.theme_chosen.connect(func(id: String) -> void:
		_remember()
		course.theme = id
		_refresh())
	ui.hills_chosen.connect(func(hills: float) -> void:
		_remember()
		course.hills = hills
		_refresh())
	ui.close_up_pressed.connect(close_up)
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
	_refresh()
	fit_view()


func go_back() -> void:
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


## Looks for pieces to join the end of the road back to the start. It can
## take a moment on a phone, so it works on another thread.
func close_up() -> void:
	if _closing != -1:
		return
	ui.set_hint("Working out how to close it up...")
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
	if _closer_result.is_empty():
		ui.toast("I couldn't find a way back from there. Try taking out the last few pieces.")
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
	_redo.append(course.to_dict())
	course = CourseDesign.from_dict(_undo.pop_back())
	_select(-1)
	_refresh()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(course.to_dict())
	course = CourseDesign.from_dict(_redo.pop_back())
	_select(-1)
	_refresh()


func _remember() -> void:
	_undo.append(course.to_dict())
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
	path = course.save(path if path.begins_with(CourseDesign.FOLDER) else "")
	ui.toast("Saved" if path != "" else "I couldn't save it")
	_refresh()
	return path


## Loads a course of yours, or a copy of one of the game's to build on.
func load_course(from: String) -> void:
	var loaded := CourseDesign.load_file(from)
	if loaded == null:
		ui.toast("I couldn't load that course")
		return
	_remember()
	course = loaded
	if course.made_by == "":
		course.made_by = Game.player_name()
	path = from if from.begins_with(CourseDesign.FOLDER) else ""
	_select(-1)
	_refresh()
	fit_view()


func _keep() -> void:
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
		Game.show_kart_picker(Game.start_course.bind(Game.MODE_RACE, saved, true), Game.show_track_editor, true)


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


## Puts back a landmark that was picked up, if it's clear, or never mind.
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
	return true


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
	var at := Vector3(float(mark.at[0]), 0.0, float(mark.at[1]))
	node.position = at
	var kit := SceneryKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(course.name) + index
	Props.add(kit, str(mark.prop), Vector3.ZERO, rng, int(mark.get("facing", 0)))
	var look := Node3D.new()
	node.add_child(look)
	kit.build(look)
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = Props.ROOM.get(mark.prop, 3.0)
	shape.shape = ball
	shape.position.y = ball.radius * 0.5
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

func _refresh() -> void:
	track = course.track()
	_lay_out()
	_rebuild_landmarks()
	if _sky_theme != course.theme:
		# The sky, sun and ground the course will have when you race on it.
		_sky_theme = course.theme
		for child in _sky.get_children():
			child.queue_free()
		var look := Scenery.theme_named(course.theme)
		SkyAndSun.add_to(_sky, 400.0, Color.TRANSPARENT, look.get("sky", []))
		_ground.material_override = TrackBuilder.baseplate(Color(look.ground))
	var problems := course.problems()
	ui.show_course(course, track.length, problems, not track.closes and not course.pieces.is_empty())
	ui.set_undo_state(not _undo.is_empty(), not _redo.is_empty())
	_update_hint()
	_keep()
	# The whole course gets built properly once you stop for a moment.
	if _full != null:
		_full.queue_free()
		_full = null
	_quick.visible = true
	_ground.visible = true
	_build_in = IDLE_BUILD


## Puts each piece's road where it goes, from the ones already made.
func _lay_out() -> void:
	var nodes := _quick.get_children()
	for i in track.pieces.size():
		var spec: Dictionary = course.pieces[i]
		var key := "%s %s %s" % [JSON.stringify(spec), course.width, course.theme]
		if not _meshes.has(key):
			var mesh := TrackBuilder.piece_mesh(spec, course.width, course.theme)
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
		(body.get_child(0) as MeshInstance3D).mesh = _meshes[key][0]
		(body.get_child(1) as CollisionShape3D).shape = _meshes[key][1]
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
		pose = pose * TrackPiece.from_spec(course.pieces[i]).exit()
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
	if _following:
		_focus = _focus.lerp(_focus_goal, 1.0 - exp(-delta * 4.0))
		_place_camera()
		if _focus.distance_to(_focus_goal) < 0.5:
			_following = false


func _build_full() -> void:
	if track.pieces.is_empty():
		return
	_full = TrackBuilder.new(track)
	_full.scenery = "none"
	_full.sky = false
	add_child(_full)
	_quick.visible = false
	_ground.visible = false
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


## Where this screen point lands on the ground.
func _ground_point(pos: Vector2) -> Vector3:
	var from := _camera.project_ray_origin(pos)
	var dir := _camera.project_ray_normal(pos)
	if absf(dir.y) < 0.001:
		return _focus
	var t := -from.y / dir.y
	return from + dir * maxf(t, 0.0)


# Touches.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
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
			_start_pinch()
		return
	if not _fingers.has(event.index):
		return
	_fingers.erase(event.index)
	if _fingers.is_empty():
		if not _several_fingers and not _dragging:
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
	if not _dragging and event.position.distance_to(_press_at) > DRAG_START:
		_dragging = true
	if not _dragging:
		return
	# A landmark in hand follows your finger.
	if not _holding.is_empty() and _ghost != null and _camera.unproject_position(_ghost.global_position).distance_to(_press_at) < GRAB_RADIUS * 2.0:
		var at := _ground_point(event.position)
		_holding.at = [at.x, at.z]
		_ghost.position = Vector3(at.x, 0.0, at.z)
		_ghost_look.albedo_color = _ring_colour(_clear_of_road(_holding))
		_press_at = event.position
		return
	_orbit(event.relative)


func _start_pinch() -> void:
	var points: Array = _fingers.values()
	if points.size() >= 2:
		_pinch_start = _distance
		_pinch_distance_start = points[0].distance_to(points[1])
