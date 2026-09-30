class_name Garage
extends Node3D

## Where you build your kart.
##
## Drag a part from the drawer onto the kart, or tap it and it shows up on the
## kart as a see-through preview, green where it fits and red where it doesn't.
## Drag it or tap where it goes, then nudge it with the arrows (a stud at a
## time, and right is always right on the screen), Up and Down for a plate at a
## time, and Turn. Place puts it down and leaves you holding another, so you
## can put down a row.
##
## Tap a part on the kart to move, turn, copy or delete it. With Mirror on,
## anything you put down, delete or paint happens on the other side too. Paint
## mode colours whatever part you tap.
##
## One finger turns the view and two fingers slide and zoom it. With a mouse
## the right button turns it, the middle button slides it and the wheel zooms.

const ORBIT_SPEED := 0.006
const DRAG_START := 14.0 # pixels a finger has to move before it counts as a drag
const GRAB_RADIUS := 90.0 # how close to the preview a drag has to start to move it
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 16.0
const UNDO_LIMIT := 100
const VIEWS := {
	"front": [180.0, -14.0],
	"side": [90.0, -14.0],
	"top": [0.0, -88.0],
	"angle": [215.0, -32.0],
}

var design: KartDesign
var ui: GarageUI
## On a touch screen a part being dragged sits a little above your finger, so
## your finger isn't covering it.
var finger_lift := 90.0 if DisplayServer.is_touchscreen_available() else 0.0
var mirror := false

var _camera: Camera3D
var _yaw := deg_to_rad(215.0)
var _pitch := deg_to_rad(-32.0)
var _distance := 7.5
var _focus := Vector3.ZERO

var _parts_root: Node3D
var _part_nodes: Array[Node3D] = []
var _selected := -1
var _mode := GarageUI.Mode.IDLE

# The part being placed.
var _holding := ""
var _holding_rot := 0
var _holding_colour: Variant = null
var _ghost: Node3D
var _twin_ghost: Node3D
var _ghost_at := Vector3i.ZERO
var _ghost_ok := false
## When a part on the kart is being moved, where it came from, so Cancel can
## put it back.
var _moving := {}
## The finger dragging a part out of the bank, -1 for the mouse, or NO_DRAG.
const NO_DRAG := -2
var _bank_finger := NO_DRAG

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

var _fingers := {} # index -> position
var _press_at := Vector2.ZERO
var _dragging := false
var _moving_ghost := false
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
			# Plain white fill light, since the blue sky's tints the baseplate
			# blue.
			child.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			child.environment.ambient_light_color = Color("#e8e8e8")
			child.environment.ambient_light_energy = 0.45
			child.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_add_baseplate()
	_parts_root = Node3D.new()
	add_child(_parts_root)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = GarageUI.new()
	layer.add_child(ui)
	ui.part_chosen.connect(func(id: String) -> void: start_placing(id))
	ui.part_dragged.connect(_start_bank_drag)
	ui.nudged.connect(nudge)
	ui.raise_pressed.connect(func() -> void: lift(1))
	ui.lower_pressed.connect(func() -> void: lift(-1))
	ui.turn_pressed.connect(turn)
	ui.place_pressed.connect(place)
	ui.cancel_pressed.connect(cancel)
	ui.move_pressed.connect(move_selected)
	ui.copy_pressed.connect(copy_selected)
	ui.delete_pressed.connect(delete_selected)
	ui.deselect_pressed.connect(func() -> void: select(-1))
	ui.undo_pressed.connect(undo)
	ui.redo_pressed.connect(redo)
	ui.mirror_toggled.connect(set_mirror)
	ui.paint_toggled.connect(set_painting)
	ui.view_pressed.connect(show_view)
	ui.new_pressed.connect(_new_kart)
	ui.save_pressed.connect(_save)
	ui.load_chosen.connect(_load)
	ui.drive_pressed.connect(_drive)
	ui.race_pressed.connect(_race)
	ui.menu_pressed.connect(_to_menu)
	ui.name_changed.connect(func(text: String) -> void: design.name = text)

	var pictures := PartThumbnails.new()
	pictures.ready_for.connect(func(id: String, picture: Texture2D) -> void:
		ui.show_picture(id, picture)
		if id == _holding:
			ui.set_held_picture(picture))
	add_child(pictures)

	_rebuild()
	show_view("angle")


# Changing the kart.

func _remember() -> void:
	_undo.append(design.to_dict())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()


func undo() -> void:
	if _undo.is_empty():
		return
	_stop_placing()
	_redo.append(design.to_dict())
	design = KartDesign.from_dict(_undo.pop_back())
	_selected = -1
	_rebuild()


func redo() -> void:
	if _redo.is_empty():
		return
	_stop_placing()
	_undo.append(design.to_dict())
	design = KartDesign.from_dict(_redo.pop_back())
	_selected = -1
	_rebuild()


## Starts placing a part. It shows up where you're looking unless `at` says
## where.
func start_placing(id: String, rot := 0, colour: Variant = null, at: Variant = null) -> void:
	if _mode == GarageUI.Mode.PLACING and not _moving.is_empty():
		cancel()
	_holding = id
	_holding_rot = 0 if KartDesign.is_wheel(id) else rot
	_holding_colour = colour
	ui.set_held_picture(PartThumbnails.picture(id))
	_set_mode(GarageUI.Mode.PLACING)
	_make_ghosts()
	if at != null:
		_ghost_at = at
		_show_ghost()
	else:
		_aim_ghost(_view_middle())


func _stop_placing() -> void:
	_holding = ""
	_moving = {}
	_bank_finger = NO_DRAG
	for ghost in [_ghost, _twin_ghost]:
		if ghost != null:
			ghost.queue_free()
	_ghost = null
	_twin_ghost = null
	if _mode == GarageUI.Mode.PLACING:
		_set_mode(GarageUI.Mode.IDLE)


## Moves the part being placed one stud across the screen. `direction` is in
## screen terms: (1, 0) is right and (0, -1) is up, which is away from you.
func nudge(direction: Vector2i) -> void:
	if _holding == "":
		return
	var step := _screen_to_grid(direction)
	_ghost_at = _clamped(_ghost_at + step)
	_show_ghost()


## Moves the part being placed up or down a plate.
func lift(plates: int) -> void:
	if _holding == "":
		return
	_ghost_at = _clamped(_ghost_at + Vector3i(0, plates, 0))
	_show_ghost()


func turn() -> void:
	if _holding != "":
		if KartDesign.is_wheel(_holding):
			return
		# Turn it about its own middle, as near as the grid allows.
		var old := KartDesign.part_box(_holding, _ghost_at, _holding_rot)
		_holding_rot = (_holding_rot + 1) % 4
		var size := Grid.rotated_size(PartCatalog.get_part(_holding).size, _holding_rot)
		var centre := old.get_center()
		_ghost_at = _clamped(Vector3i(roundi(centre.x - size.x * 0.5), _ghost_at.y, roundi(centre.z - size.z * 0.5)))
		_make_ghosts()
		_show_ghost()
	elif _selected != -1:
		var p: Dictionary = design.parts[_selected]
		if KartDesign.is_wheel(p.id):
			return
		var old := KartDesign.part_box(p.id, p.at, p.rot)
		var new_rot: int = (p.rot + 1) % 4
		var new_size := Grid.rotated_size(PartCatalog.get_part(p.id).size, new_rot)
		var centre := old.get_center()
		var at := Vector3i(roundi(centre.x - new_size.x * 0.5), p.at.y, roundi(centre.z - new_size.z * 0.5))
		if design.fits(p.id, at, new_rot, _selected):
			_remember()
			var turned := p.duplicate()
			turned.at = at
			turned.rot = new_rot
			design.parts[_selected] = turned
			_rebuild()
		else:
			ui.toast("There's no room to turn it there.")


## Puts the part being placed down, and its mirror image too with Mirror on.
func place() -> void:
	if _holding == "":
		return
	if not _ghost_ok:
		Sounds.play("fx/nope")
		return
	Sounds.play("fx/snap", 0.0, randf_range(0.95, 1.05))
	# A move took its undo step when it started.
	if _moving.is_empty():
		_remember()
	var entry := { "id": _holding, "at": _ghost_at, "rot": _holding_rot }
	if _holding_colour != null:
		entry["color"] = _holding_colour
	design.parts.append(entry)
	var placed := design.parts.size() - 1
	if mirror and _moving.is_empty():
		var twin := mirrored(entry)
		if twin.at != entry.at and design.fits(twin.id, twin.at, twin.rot) and design.attaches(twin.id, twin.at, twin.rot):
			design.parts.append(twin)
	if not _moving.is_empty():
		# A part that was being moved is done, so pick it out where it landed.
		_moving = {}
		_stop_placing()
		_selected = placed
		_set_mode(GarageUI.Mode.SELECTED)
		_rebuild()
		return
	_rebuild()
	# Keep holding the same part, so you can put down a row of them.
	_show_ghost()


## Stops placing. A part that was being moved goes back where it was.
func cancel() -> void:
	if not _moving.is_empty():
		# Nothing changed after all, so drop the undo step the move took.
		_undo.pop_back()
		design.parts.insert(_moving.index, _moving.entry)
		var back: int = _moving.index
		_moving = {}
		_stop_placing()
		_selected = back
		_set_mode(GarageUI.Mode.SELECTED)
		_rebuild()
		return
	_stop_placing()


func move_selected() -> void:
	if _selected == -1:
		return
	var p: Dictionary = design.parts[_selected]
	_remember()
	var index := _selected
	design.parts.remove_at(index)
	Sounds.play("fx/unsnap")
	_selected = -1
	_rebuild()
	start_placing(p.id, p.rot, p.get("color"), p.at)
	_moving = { "index": index, "entry": p }
	_show_ghost()


## Picks up a copy of the picked out part, turned and painted the same, beside
## it if there's room.
func copy_selected() -> void:
	if _selected == -1:
		return
	var p: Dictionary = design.parts[_selected]
	var size := Grid.rotated_size(PartCatalog.get_part(p.id).size, p.rot)
	var spot: Vector3i = p.at
	for offset in [Vector3i(size.x, 0, 0), Vector3i(-size.x, 0, 0), Vector3i(0, 0, size.z), Vector3i(0, 0, -size.z), Vector3i(0, size.y, 0)]:
		var at: Vector3i = p.at + offset
		if design.fits(p.id, at, p.rot) and design.attaches(p.id, at, p.rot):
			spot = at
			break
	start_placing(p.id, p.rot, p.get("color"), spot)


func delete_selected() -> void:
	if _selected == -1:
		return
	_remember()
	var gone: Dictionary = design.parts[_selected]
	design.parts.remove_at(_selected)
	Sounds.play("fx/unsnap")
	if mirror:
		var twin := find_part(mirrored(gone))
		if twin != -1:
			design.parts.remove_at(twin)
	_selected = -1
	_set_mode(GarageUI.Mode.IDLE)
	_rebuild()


## Paints a part, and its twin with Mirror on.
func paint(index: int, colour: Color) -> void:
	if index < 0 or index >= design.parts.size():
		return
	_remember()
	var twin := find_part(mirrored(design.parts[index])) if mirror else -1
	design.parts[index]["color"] = colour
	if twin != -1 and twin != index:
		design.parts[twin]["color"] = colour
	_rebuild()


func set_mirror(on: bool) -> void:
	mirror = on
	ui.set_mirror(on)
	_show_ghost()


func set_painting(on: bool) -> void:
	_stop_placing()
	select(-1)
	_set_mode(GarageUI.Mode.PAINTING if on else GarageUI.Mode.IDLE)


## Where a part would be as the mirror image of this one, across the middle
## of the kart from side to side.
static func mirrored(entry: Dictionary) -> Dictionary:
	var rot: int = posmod(4 - int(entry.rot), 4)
	var size := Grid.rotated_size(PartCatalog.get_part(entry.id).size, rot)
	var at: Vector3i = entry.at
	# A left handed part's twin is the right handed one.
	var id: String = PartCatalog.get_part(entry.id).get("mirror", entry.id)
	var twin := { "id": id, "at": Vector3i(KartDesign.BUILD_SIZE.x - at.x - size.x, at.y, at.z), "rot": rot }
	if entry.has("color"):
		twin["color"] = entry.color
	return twin


## The index of the part that's exactly this one, or -1.
func find_part(entry: Dictionary) -> int:
	for i in design.parts.size():
		var p: Dictionary = design.parts[i]
		if p.id == entry.id and p.at == entry.at and p.rot == entry.rot:
			return i
	return -1


func select(index: int) -> void:
	if _selected != -1 and _selected < _part_nodes.size():
		PartVisuals.set_highlight(_part_nodes[_selected], false)
	_selected = index
	if _selected != -1:
		PartVisuals.set_highlight(_part_nodes[_selected], true)
		_set_mode(GarageUI.Mode.SELECTED)
	elif _mode == GarageUI.Mode.SELECTED:
		_set_mode(GarageUI.Mode.IDLE)
	else:
		_refresh_ui()


func _new_kart() -> void:
	_remember()
	_stop_placing()
	design = KartDesign.new()
	design.name = "New kart"
	_selected = -1
	_rebuild()
	show_view("fit")


func _save() -> void:
	if design.name.strip_edges() == "":
		design.name = "My kart"
	var path := design.save()
	ui.toast("Saved %s" % design.name if path != "" else "I couldn't save it.")


func _load(path: String) -> void:
	_remember()
	_stop_placing()
	design = KartDesign.load_file(path)
	_selected = -1
	_rebuild()
	show_view("fit")


func _drive() -> void:
	if not design.problems().is_empty():
		return
	Game.keep_design(design)
	Game.show_drive()


func _race() -> void:
	if not design.problems().is_empty():
		return
	Game.keep_design(design)
	Game.show_single_player()


func _to_menu() -> void:
	Game.keep_design(design)
	Game.show_editors()


## Back stops whatever you're doing first, then goes to the editors.
func go_back() -> void:
	if _mode == GarageUI.Mode.PLACING:
		cancel()
	elif _mode != GarageUI.Mode.IDLE:
		set_painting(false)
	else:
		_to_menu()


# Showing the kart.

func _set_mode(mode: GarageUI.Mode) -> void:
	_mode = mode
	_refresh_ui()


func _rebuild() -> void:
	for child in _parts_root.get_children():
		child.queue_free()
	_part_nodes.clear()
	var stats := KartStats.compute(design, {}, null, Game.character.mass())
	for i in design.parts.size():
		var p: Dictionary = design.parts[i]
		var node := _part_node(p.id, p.rot, p.get("color"))
		node.position = _world_centre(p.id, p.at, p.rot)
		_parts_root.add_child(node)
		_part_nodes.append(node)
	if stats.has_seat:
		# The stats put the kart's origin under the middle of it, so put that
		# back onto the grid to find the seat.
		var rig := CharacterRig.new(Game.character, true)
		rig.recline = stats.recline
		rig.lively = true
		rig.position = stats.seat_top + Grid.to_metres(stats.origin_cell)
		_parts_root.add_child(rig)
		# Hands on the steering wheel if there is one.
		for i in design.parts.size():
			if _part_nodes[i] is SteeringVisual:
				var wheel: SteeringVisual = _part_nodes[i]
				var grips := wheel.grips(0.0)
				var to_rig := rig.transform.affine_inverse() * wheel.transform
				rig.grip(to_rig * grips[0], to_rig * grips[1], to_rig.basis * grips[2], to_rig.basis * grips[3])
				break
	if _selected >= _part_nodes.size():
		_selected = -1
	if _selected != -1:
		PartVisuals.set_highlight(_part_nodes[_selected], true)
	elif _mode == GarageUI.Mode.SELECTED:
		_mode = GarageUI.Mode.IDLE
	ui.set_kart_name(design.name)
	ui.show_stats(stats, design.problems())
	_refresh_ui()


func _refresh_ui() -> void:
	var what := ""
	var can_turn := true
	if _mode == GarageUI.Mode.PLACING:
		what = PartCatalog.get_part(_holding).get("name", _holding)
		can_turn = not KartDesign.is_wheel(_holding)
	elif _mode == GarageUI.Mode.SELECTED and _selected != -1:
		var id: String = design.parts[_selected].id
		what = PartCatalog.get_part(id).get("name", id)
		can_turn = not KartDesign.is_wheel(id)
	ui.set_mode(_mode, what, can_turn)
	ui.set_can_place(_ghost_ok)
	ui.set_history(not _undo.is_empty(), not _redo.is_empty())


func _part_node(id: String, rot: int, colour: Variant = null) -> Node3D:
	var def := PartCatalog.get_part(id)
	if colour != null:
		def = def.duplicate()
		def["color"] = colour
	var size := Grid.rotated_size(def.size, rot)
	return PartVisuals.make(def, Grid.to_metres(Vector3(size)), rot)


func _world_centre(id: String, at: Vector3i, rot: int) -> Vector3:
	var size := Grid.rotated_size(PartCatalog.get_part(id).size, rot)
	return Grid.to_metres(Vector3(at) + Vector3(size) * 0.5)


func _make_ghosts() -> void:
	for ghost in [_ghost, _twin_ghost]:
		if ghost != null:
			ghost.queue_free()
	_ghost = _part_node(_holding, _holding_rot, _holding_colour)
	add_child(_ghost)
	_ghost.visible = false
	_twin_ghost = _part_node(PartCatalog.get_part(_holding).get("mirror", _holding), posmod(4 - _holding_rot, 4), _holding_colour)
	add_child(_twin_ghost)
	_twin_ghost.visible = false


## Points the part being placed at whatever is under this screen position.
func _aim_ghost(screen_pos: Vector2) -> void:
	if _ghost == null:
		return
	var hit := BuildMath.cast(design, _camera.project_ray_origin(screen_pos) / Grid.UNIT, _camera.project_ray_normal(screen_pos) / Grid.UNIT)
	if not hit.is_hit():
		return
	var size := Grid.rotated_size(PartCatalog.get_part(_holding).size, _holding_rot)
	_ghost_at = BuildMath.nearest_spot(design, _holding, BuildMath.placement(hit, size), _holding_rot)
	_show_ghost()


func _show_ghost() -> void:
	if _ghost == null:
		_refresh_ui()
		return
	_ghost_ok = design.fits(_holding, _ghost_at, _holding_rot) and design.attaches(_holding, _ghost_at, _holding_rot)
	_ghost.position = _world_centre(_holding, _ghost_at, _holding_rot)
	_ghost.visible = true
	PartVisuals.set_ghost(_ghost, _ghost_ok)
	var twin := mirrored({ "id": _holding, "at": _ghost_at, "rot": _holding_rot })
	_twin_ghost.visible = mirror and _moving.is_empty() and twin.at != _ghost_at
	if _twin_ghost.visible:
		_twin_ghost.position = _world_centre(twin.id, twin.at, twin.rot)
		PartVisuals.set_ghost(_twin_ghost, design.fits(twin.id, twin.at, twin.rot))
	_refresh_ui()


## Keeps a spot inside the build area.
func _clamped(at: Vector3i) -> Vector3i:
	var size := Grid.rotated_size(PartCatalog.get_part(_holding).size, _holding_rot)
	var most := KartDesign.BUILD_SIZE - size
	return Vector3i(clampi(at.x, 0, most.x), clampi(at.y, 0, most.y), clampi(at.z, 0, most.z))


## Which way on the grid a screen direction goes, from where the camera is.
## Right on the screen is whichever grid direction looks most like right, and
## up on the screen is away from you along the ground (or up the screen, when
## looking straight down).
func _screen_to_grid(direction: Vector2i) -> Vector3i:
	var right := _camera.global_basis.x
	right.y = 0.0
	var away := -_camera.global_basis.z
	away.y = 0.0
	if away.length() < 0.3:
		away = _camera.global_basis.y
		away.y = 0.0
	var ground := right.normalized() * direction.x + away.normalized() * -direction.y
	if absf(ground.x) >= absf(ground.z):
		return Vector3i(signi(roundi(ground.x * 10.0)), 0, 0)
	return Vector3i(0, 0, signi(roundi(ground.z * 10.0)))


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


# The camera.

## Jumps to one of the views (front, side, top or angle), or fits the kart in
## view.
func show_view(view: String) -> void:
	if VIEWS.has(view):
		_yaw = deg_to_rad(VIEWS[view][0])
		_pitch = deg_to_rad(VIEWS[view][1])
	_frame_kart()


## Aims at the middle of the kart and backs off until it all fits.
func _frame_kart() -> void:
	var box := AABB(Grid.to_metres(Vector3(KartDesign.BUILD_SIZE.x * 0.5 - 4.0, 0.0, KartDesign.BUILD_SIZE.z * 0.5 - 5.0)), Grid.to_metres(Vector3(8, 6, 10)))
	for i in design.parts.size():
		var part_box := design.box_of(i)
		box = box.merge(AABB(Grid.to_metres(part_box.position), Grid.to_metres(part_box.size)))
	_focus = box.get_center()
	var radius := box.size.length() * 0.5
	_distance = clampf(radius / sin(deg_to_rad(_camera.fov * 0.5)) * 0.95, MIN_DISTANCE, MAX_DISTANCE)
	_place_camera()


func _place_camera() -> void:
	var offset := Vector3(0.0, 0.0, _distance).rotated(Vector3.RIGHT, _pitch).rotated(Vector3.UP, _yaw)
	_camera.position = _focus + offset
	_camera.look_at(_focus, Vector3.FORWARD if absf(_pitch) > deg_to_rad(80.0) else Vector3.UP)


func _orbit(by: Vector2) -> void:
	_yaw -= by.x * ORBIT_SPEED
	_pitch = clampf(_pitch - by.y * ORBIT_SPEED, deg_to_rad(-88.0), deg_to_rad(-3.0))
	_place_camera()


func _pan(by: Vector2) -> void:
	var scale := _distance * 0.0016
	_focus += (-_camera.global_basis.x * by.x + _camera.global_basis.y * by.y) * scale
	_place_camera()


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	_place_camera()


func _view_middle() -> Vector2:
	return get_viewport().get_visible_rect().size * Vector2(0.5, 0.55)


## Keeps a picked out part's actions beside it as the view moves.
func _process(_delta: float) -> void:
	if _selected != -1 and _selected < _part_nodes.size():
		var node := _part_nodes[_selected]
		ui.set_selection_anchor(_camera.unproject_position(node.global_position))


# Touches.

func _start_bank_drag(id: String, finger: int) -> void:
	start_placing(id)
	_bank_finger = finger


## Follows a part being dragged out of the bank. The bank's tile has the
## touch, so this listens before the panels get it.
func _input(event: InputEvent) -> void:
	if _bank_finger == NO_DRAG:
		return
	var pos := Vector2.INF
	var released := false
	if event is InputEventScreenDrag and event.index == _bank_finger:
		pos = event.position
	elif event is InputEventScreenTouch and event.index == _bank_finger and not event.pressed:
		pos = event.position
		released = true
	elif event is InputEventMouseMotion and _bank_finger == -1:
		pos = event.position
	elif event is InputEventMouseButton and _bank_finger == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pos = event.position
		released = true
	if pos == Vector2.INF:
		return
	if not ui.is_over_bank(pos):
		_aim_ghost(pos - Vector2(0.0, finger_lift))
	if released:
		_bank_finger = NO_DRAG
		# Let go back over the drawer, so never mind.
		if ui.is_over_bank(pos):
			cancel()


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
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_pan(event.relative)
	elif event is InputEventKey and event.pressed:
		_on_key(event)


func _on_key(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_LEFT:
			nudge(Vector2i(-1, 0))
		KEY_RIGHT:
			nudge(Vector2i(1, 0))
		KEY_UP:
			nudge(Vector2i(0, -1))
		KEY_DOWN:
			nudge(Vector2i(0, 1))
		KEY_PAGEUP:
			lift(1)
		KEY_PAGEDOWN:
			lift(-1)
		KEY_R:
			turn()
		KEY_ENTER, KEY_KP_ENTER:
			place()
		KEY_M:
			if not event.echo:
				set_mirror(not mirror)
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
		KEY_Z:
			if event.ctrl_pressed and not event.echo:
				redo() if event.shift_pressed else undo()
		KEY_Y:
			if event.ctrl_pressed and not event.echo:
				redo()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if ui.is_over_ui(event.position):
			return
		_fingers[event.index] = event.position
		if _fingers.size() == 1:
			_press_at = event.position
			_dragging = false
			_several_fingers = false
			# A drag that starts on the part being placed moves it. Anywhere
			# else it turns the view.
			_moving_ghost = _ghost != null and _ghost.visible and _camera.unproject_position(_ghost.global_position).distance_to(event.position) < GRAB_RADIUS
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
		_moving_ghost = false
	else:
		_start_pinch()


func _tap(pos: Vector2) -> void:
	match _mode:
		GarageUI.Mode.PLACING:
			_aim_ghost(pos)
		GarageUI.Mode.PAINTING:
			var hit := _cast(pos)
			if hit.is_hit() and hit.part != -1:
				paint(hit.part, ui.paint_colour())
		_:
			var hit := _cast(pos)
			select(hit.part if hit.is_hit() else -1)


func _cast(pos: Vector2) -> BuildMath.Hit:
	return BuildMath.cast(design, _camera.project_ray_origin(pos) / Grid.UNIT, _camera.project_ray_normal(pos) / Grid.UNIT)


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
	if _moving_ghost:
		_aim_ghost(event.position - Vector2(0.0, finger_lift))
	else:
		_orbit(event.relative)


func _start_pinch() -> void:
	var points: Array = _fingers.values()
	if points.size() >= 2:
		_pinch_start = _distance
		_pinch_distance_start = points[0].distance_to(points[1])
