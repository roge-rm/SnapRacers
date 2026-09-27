class_name Garage
extends Node3D

## Where you build your kart.
##
## Pick a part from the bank and it follows your finger over the kart,
## clicking onto whatever you point at. Lift your finger to put it down. It
## shows red where it can't go, either because it's inside something or
## because nothing would hold it. With nothing in hand, touch a part to pick
## it out, then turn, move or remove it.
##
## One finger drags the view round when you're not holding anything. Two
## fingers always do, and pinching zooms. With a mouse, the right button turns
## the view and the wheel zooms.

const ORBIT_SPEED := 0.006
const DRAG_START := 14.0 # pixels a finger has to move before it counts as a drag
const MIN_DISTANCE := 3.0
const MAX_DISTANCE := 14.0
const UNDO_LIMIT := 100

var design: KartDesign
var ui: GarageUI
## On a touch screen the part is aimed a little above your finger, so your
## finger isn't covering it.
var finger_lift := 90.0 if DisplayServer.is_touchscreen_available() else 0.0

var _camera: Camera3D
var _yaw := deg_to_rad(215.0)
var _pitch := deg_to_rad(-32.0)
var _distance := 7.5
var _focus := Vector3.ZERO

var _parts_root: Node3D
var _part_nodes: Array[Node3D] = []
var _selected := -1

var _holding := ""
var _holding_rot := 0
var _ghost: Node3D
var _ghost_at := Vector3i.ZERO
var _ghost_ok := false

var _undo: Array[Dictionary] = []

var _fingers := {} # index -> position
var _press_at := Vector2.ZERO
var _dragging := false
var _several_fingers := false
var _pinch_start := 0.0
var _pinch_distance_start := 0.0


func _ready() -> void:
	design = Game.design.duplicate_design()
	SkyAndSun.add_to(self, 30.0, Color("#2b3440"))
	# Looking down on the kart catches a lot more light than the track camera
	# does, so the garage is lit a little more softly.
	for child in get_children():
		if child is DirectionalLight3D:
			child.light_energy = 0.8
		elif child is WorldEnvironment:
			# Plain white fill light rather than the blue sky's, which tinted the
			# baseplate blue.
			child.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			child.environment.ambient_light_color = Color("#e8e8e8")
			child.environment.ambient_light_energy = 0.45
			child.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_add_baseplate()
	_parts_root = Node3D.new()
	add_child(_parts_root)

	_focus = Grid.to_metres(Vector3(KartDesign.BUILD_SIZE.x * 0.5, 6.0, KartDesign.BUILD_SIZE.z * 0.5))
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.make_current()
	_place_camera()

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = GarageUI.new()
	layer.add_child(ui)
	ui.part_chosen.connect(_start_holding)
	ui.turn_pressed.connect(_turn)
	ui.remove_pressed.connect(_remove_selected)
	ui.pick_up_pressed.connect(_pick_up_selected)
	ui.undo_pressed.connect(_undo_last)
	ui.done_pressed.connect(_stop_holding)
	ui.new_pressed.connect(_new_kart)
	ui.save_pressed.connect(_save)
	ui.load_chosen.connect(_load)
	ui.drive_pressed.connect(_drive)
	ui.race_pressed.connect(_race)
	ui.menu_pressed.connect(_to_menu)
	ui.name_changed.connect(func(text: String) -> void: design.name = text)

	_rebuild()


# Changing the kart.

func _remember() -> void:
	_undo.append(design.to_dict())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()


func _undo_last() -> void:
	if _undo.is_empty():
		return
	design = KartDesign.from_dict(_undo.pop_back())
	_selected = -1
	_rebuild()


func _start_holding(id: String) -> void:
	_holding = id
	_holding_rot = 0
	_select(-1)
	_make_ghost()
	# Show it straight away, somewhere sensible, before the first touch.
	_aim_ghost(get_viewport().get_visible_rect().size * 0.5)
	_refresh_ui()


func _stop_holding() -> void:
	_holding = ""
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_refresh_ui()


func _turn() -> void:
	if _holding != "":
		if not KartDesign.is_wheel(_holding):
			_holding_rot = (_holding_rot + 1) % 4
			_make_ghost()
			_show_ghost()
	elif _selected != -1:
		var p: Dictionary = design.parts[_selected]
		if KartDesign.is_wheel(p.id):
			return
		# Turn it about its own middle, as near as the grid allows.
		var old := KartDesign.part_box(p.id, p.at, p.rot)
		var new_rot: int = (p.rot + 1) % 4
		var new_size := Grid.rotated_size(PartCatalog.get_part(p.id).size, new_rot)
		var centre := old.get_center()
		var at := Vector3i(roundi(centre.x - new_size.x * 0.5), p.at.y, roundi(centre.z - new_size.z * 0.5))
		if design.fits(p.id, at, new_rot, _selected):
			_remember()
			design.parts[_selected] = { "id": p.id, "at": at, "rot": new_rot }
			_rebuild()
		else:
			ui.toast("There's no room to turn it there.")


func _remove_selected() -> void:
	if _selected == -1:
		return
	_remember()
	design.parts.remove_at(_selected)
	_selected = -1
	_rebuild()


func _pick_up_selected() -> void:
	if _selected == -1:
		return
	var p: Dictionary = design.parts[_selected]
	_remove_selected()
	_start_holding(p.id)
	_holding_rot = p.rot
	_make_ghost()
	_ghost_at = p.at
	_show_ghost()


func _put_down() -> void:
	if _holding == "" or not _ghost_ok:
		return
	_remember()
	design.parts.append({ "id": _holding, "at": _ghost_at, "rot": _holding_rot })
	_rebuild()
	# Keep holding the same part so you can put down a row of them.
	_show_ghost()


func _new_kart() -> void:
	_remember()
	design = KartDesign.new()
	design.name = "New kart"
	_selected = -1
	_rebuild()


func _save() -> void:
	if design.name.strip_edges() == "":
		design.name = "My kart"
	var path := design.save()
	ui.toast("Saved %s" % design.name if path != "" else "I couldn't save it.")


func _load(path: String) -> void:
	_remember()
	design = KartDesign.load_file(path)
	_selected = -1
	_stop_holding()
	_rebuild()


func _drive() -> void:
	if not design.problems().is_empty():
		return
	Game.keep_design(design)
	Game.show_drive()


func _race() -> void:
	if not design.problems().is_empty():
		return
	Game.keep_design(design)
	Game.show_race()


func _to_menu() -> void:
	Game.keep_design(design)
	Game.show_menu()


## Back puts down whatever you're holding first, then goes to the menu.
func go_back() -> void:
	if _holding != "":
		_stop_holding()
	else:
		_to_menu()


# Showing the kart.

func _rebuild() -> void:
	for child in _parts_root.get_children():
		child.queue_free()
	_part_nodes.clear()
	var stats := KartStats.compute(design)
	for i in design.parts.size():
		var node := _part_node(design.parts[i].id, design.parts[i].rot)
		node.position = _world_centre(design.parts[i].id, design.parts[i].at, design.parts[i].rot)
		_parts_root.add_child(node)
		_part_nodes.append(node)
	if stats.has_seat:
		# The stats put the kart's origin under the middle of it; put that back
		# onto the grid to find the seat.
		var driver := PartVisuals.make_driver()
		driver.position = stats.seat_top + Grid.to_metres(stats.origin_cell)
		_parts_root.add_child(driver)
	if _selected >= _part_nodes.size():
		_selected = -1
	if _selected != -1:
		PartVisuals.set_highlight(_part_nodes[_selected], true)
	ui.set_kart_name(design.name)
	ui.show_stats(stats, design.problems())
	_refresh_ui()


func _refresh_ui() -> void:
	var selected_name := ""
	var can_turn := false
	if _selected != -1:
		var id: String = design.parts[_selected].id
		selected_name = PartCatalog.get_part(id).get("name", id)
		can_turn = not KartDesign.is_wheel(id)
	if _holding != "":
		can_turn = not KartDesign.is_wheel(_holding)
	ui.set_mode(_holding, selected_name, can_turn, not _undo.is_empty())


func _part_node(id: String, rot: int) -> Node3D:
	var def := PartCatalog.get_part(id)
	var size := Grid.rotated_size(def.size, rot)
	return PartVisuals.make(def, Grid.to_metres(Vector3(size)))


func _world_centre(id: String, at: Vector3i, rot: int) -> Vector3:
	var size := Grid.rotated_size(PartCatalog.get_part(id).size, rot)
	return Grid.to_metres(Vector3(at) + Vector3(size) * 0.5)


func _select(index: int) -> void:
	if _selected != -1 and _selected < _part_nodes.size():
		PartVisuals.set_highlight(_part_nodes[_selected], false)
	_selected = index
	if _selected != -1:
		PartVisuals.set_highlight(_part_nodes[_selected], true)
	_refresh_ui()


func _make_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = _part_node(_holding, _holding_rot)
	add_child(_ghost)
	_ghost.visible = false


## Points the part you're holding at whatever is under this screen position.
func _aim_ghost(screen_pos: Vector2) -> void:
	if _ghost == null:
		return
	var hit := BuildMath.cast(design, _camera.project_ray_origin(screen_pos) / Grid.UNIT, _camera.project_ray_normal(screen_pos) / Grid.UNIT)
	if not hit.is_hit():
		_ghost.visible = false
		_ghost_ok = false
		return
	var size := Grid.rotated_size(PartCatalog.get_part(_holding).size, _holding_rot)
	_ghost_at = BuildMath.nearest_spot(design, _holding, BuildMath.placement(hit, size), _holding_rot)
	_show_ghost()


func _show_ghost() -> void:
	if _ghost == null:
		return
	_ghost_ok = design.fits(_holding, _ghost_at, _holding_rot) and design.attaches(_holding, _ghost_at, _holding_rot)
	_ghost.position = _world_centre(_holding, _ghost_at, _holding_rot)
	_ghost.visible = true
	PartVisuals.set_ghost(_ghost, _ghost_ok)


func _add_baseplate() -> void:
	var size := KartDesign.BUILD_SIZE
	var extent := Grid.to_metres(Vector3(size.x, 1, size.z))
	var def := { "kind": "plate", "color": Color("#5d6873") }
	var plate := PartVisuals.make(def, extent)
	plate.position = Vector3(extent.x * 0.5, -extent.y * 0.5, extent.z * 0.5)
	add_child(plate)

	var front := Label3D.new()
	front.text = "FRONT"
	front.font_size = 96
	front.pixel_size = 0.004
	front.modulate = Color("#f2cd37")
	front.outline_size = 16
	front.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	front.position = Vector3(extent.x * 0.5, 0.06, -0.35)
	add_child(front)


# The camera and touches.

func _place_camera() -> void:
	var offset := Vector3(0.0, 0.0, _distance).rotated(Vector3.RIGHT, _pitch).rotated(Vector3.UP, _yaw)
	_camera.position = _focus + offset
	_camera.look_at(_focus, Vector3.UP)


func _orbit(by: Vector2) -> void:
	_yaw -= by.x * ORBIT_SPEED
	_pitch = clampf(_pitch - by.y * ORBIT_SPEED, deg_to_rad(-85.0), deg_to_rad(-5.0))
	_place_camera()


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	_place_camera()


func _aim_point(pos: Vector2) -> Vector2:
	return pos - Vector2(0.0, finger_lift)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.1)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_orbit(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_turn()
			KEY_DELETE, KEY_BACKSPACE:
				_remove_selected()
			KEY_Z:
				if event.ctrl_pressed:
					_undo_last()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if ui.is_over_ui(event.position):
			return
		_fingers[event.index] = event.position
		if _fingers.size() == 1:
			_press_at = event.position
			_dragging = false
			_several_fingers = false
			if _holding != "":
				_aim_ghost(_aim_point(event.position))
		else:
			_several_fingers = true
			_start_pinch()
		return

	if not _fingers.has(event.index):
		return
	_fingers.erase(event.index)
	if _fingers.is_empty():
		if not _several_fingers:
			if _holding != "":
				_put_down()
			elif not _dragging:
				_pick_at(event.position)
		_several_fingers = false
	else:
		_start_pinch()


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _fingers.has(event.index):
		return
	_fingers[event.index] = event.position
	if _fingers.size() >= 2:
		var points: Array = _fingers.values()
		var spread: float = points[0].distance_to(points[1])
		if _pinch_distance_start > 0.0 and spread > 0.0:
			_distance = clampf(_pinch_start * _pinch_distance_start / spread, MIN_DISTANCE, MAX_DISTANCE)
		_orbit(event.relative / _fingers.size())
		return
	if _holding != "":
		_aim_ghost(_aim_point(event.position))
		return
	if not _dragging and event.position.distance_to(_press_at) > DRAG_START:
		_dragging = true
	if _dragging:
		_orbit(event.relative)


func _start_pinch() -> void:
	var points: Array = _fingers.values()
	if points.size() >= 2:
		_pinch_start = _distance
		_pinch_distance_start = points[0].distance_to(points[1])


func _pick_at(pos: Vector2) -> void:
	var hit := BuildMath.cast(design, _camera.project_ray_origin(pos) / Grid.UNIT, _camera.project_ray_normal(pos) / Grid.UNIT)
	_select(hit.part if hit.is_hit() else -1)
