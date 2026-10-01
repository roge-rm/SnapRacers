class_name Garage
extends Node3D

## Where you build your kart.
##
## Drag a part from the drawer onto the kart, or tap it and it shows up on the
## kart as a see-through preview, red where it doesn't fit. Dots show every
## spot on the kart it could join: studs, bars, axles, holes, hinges and ball
## joints. Drag it or tap a dot and it snaps on there. Turn turns it about the
## joint, Flip turns it over, Way on puts it on by another of its own
## connectors, and Slide moves it along a bar or axle. The arrows still move
## it a stud at a time (right is always right on the screen), and Up and Down
## a plate at a time. Place puts it down and leaves you holding another, so
## you can put down a row.
##
## Tap a part on the kart to move, turn, copy or delete it, or drag it to
## move it. With Mirror on, anything you put down, delete or paint happens on
## the other side too. Paint mode colours whatever part you tap.
##
## One finger turns the view and two fingers slide and zoom it. With a mouse
## the right button turns it, the middle button slides it and the wheel zooms.

const ORBIT_SPEED := 0.006
const DRAG_START := 14.0 # pixels a finger has to move before it counts as a drag
const GRAB_RADIUS := 90.0 # how close to the preview a drag has to start to move it
const SNAP_RADIUS := 60.0 # how close to a dot a finger has to be to snap to it
## The colours of the dots, by what joins there.
const DOT_COLOURS := {
	"stud": Color("#b39dff"), "socket": Color("#b39dff"), "side": Color("#b39dff"), "clip": Color("#f2cd37"), "bar": Color("#f2cd37"),
	"pin": Color("#36aebf"), "hole": Color("#36aebf"), "axle": Color("#36aebf"), "axle_hole": Color("#36aebf"), "hub": Color("#36aebf"),
	"hinge_a": Color("#da8540"), "hinge_b": Color("#da8540"), "ball": Color("#da8540"), "cup": Color("#da8540"),
}
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

# The part being placed, and where it is: its place takes its own space to
# the kart's, in the fine unit (see KartDesign).
var _holding := ""
var _holding_colour: Variant = null
var _ghost_place := Transform3D.IDENTITY
var _ghost: Node3D
var _twin_ghost: Node3D
var _ghost_turn := Basis.IDENTITY
var _twin_turn := Basis.IDENTITY
var _ghost_ok := false
## The spot it's snapped onto and how (see Snap), or empty when it's just
## sitting on the grid.
var _spot := {}
var _way := {}
## The spots the part in hand could join, and the dots that show them.
var _spots := []
var _dots: MultiMeshInstance3D
var _dot_here: MeshInstance3D
## A drag on the picked out part moves it.
var _grab_selected := false
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
	_make_dots()

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
	ui.flip_pressed.connect(flip)
	ui.way_pressed.connect(way_on)
	ui.slide_pressed.connect(slide)
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


## Starts placing a part, turned by `turn`. It shows up where you're looking
## unless `at` says where, as a Transform3D place or a Vector3i spot on the
## grid.
func start_placing(id: String, turn := Basis.IDENTITY, colour: Variant = null, at: Variant = null) -> void:
	if _mode == GarageUI.Mode.PLACING and not _moving.is_empty():
		cancel()
	_holding = id
	_holding_colour = colour
	_spot = {}
	_way = {}
	ui.set_held_picture(PartThumbnails.picture(id))
	_set_mode(GarageUI.Mode.PLACING)
	_find_spots()
	if KartDesign.is_wheel(id):
		turn = Basis.IDENTITY
	if at is Transform3D:
		_ghost_place = at
	elif at is Vector3i:
		_ghost_place = KartDesign.box_place(id, turn, at)
	else:
		_ghost_place = KartDesign.box_place(id, turn, Vector3i.ZERO)
		_aim_ghost(_view_middle())
	_show_ghost()


func _stop_placing() -> void:
	_holding = ""
	_moving = {}
	_spot = {}
	_way = {}
	_spots = []
	_bank_finger = NO_DRAG
	for ghost in [_ghost, _twin_ghost]:
		if ghost != null:
			ghost.queue_free()
	_ghost = null
	_twin_ghost = null
	_show_dots()
	if _mode == GarageUI.Mode.PLACING:
		_set_mode(GarageUI.Mode.IDLE)


## Where the part in hand is on the stud grid: the front left bottom corner of
## its box.
func ghost_at() -> Vector3i:
	var low := KartDesign.fine_box(_holding, _ghost_place).position / Grid.UNIT_FINE
	return Vector3i(roundi(low.x), roundi(low.y), roundi(low.z))


## Moves the part being placed one stud across the screen. `direction` is in
## screen terms: (1, 0) is right and (0, -1) is up, which is away from you.
func nudge(direction: Vector2i) -> void:
	if _holding == "":
		return
	_shift(Vector3(_screen_to_grid(direction)) * Grid.UNIT_FINE)


## Moves the part being placed up or down a plate.
func lift(plates: int) -> void:
	if _holding == "":
		return
	_shift(Vector3(0.0, plates * Grid.PLATE_FINE, 0.0))


## Moves the part in hand off whatever spot it was snapped to.
func _shift(by: Vector3) -> void:
	_ghost_place.origin += by
	_ghost_place = _clamped(_holding, _ghost_place)
	_spot = {}
	_way = {}
	_show_ghost()


## Turns the part in hand a quarter turn about the joint it's on, or about
## its middle when it isn't snapped on anywhere. A part on the kart that's
## picked out turns about its middle.
func turn() -> void:
	if _holding != "":
		if KartDesign.is_wheel(_holding):
			return
		if not _spot.is_empty():
			var way := Snap.turned(design, _holding, _spot, _way)
			if not way.is_empty():
				_take_way(way)
				return
		_ghost_place = _turned_in_place(_holding, _ghost_place, Grid.yaw(1))
		_spot = {}
		_way = {}
		_show_ghost()
	elif _selected != -1:
		var p: Dictionary = design.parts[_selected]
		if KartDesign.is_wheel(p.id):
			return
		var place := _turned_in_place(p.id, KartDesign.place_of(p), Grid.yaw(1))
		if design.fits_place(p.id, place, _selected) and design.attaches_place(p.id, place, _selected):
			_remember()
			design.parts[_selected] = KartDesign.placed_entry(p.id, place, p.get("color"))
			_rebuild()
		else:
			ui.toast("There's no room to turn it there.")


## Turns the part in hand over.
func flip() -> void:
	if _holding == "":
		return
	if not _spot.is_empty():
		var way := Snap.flipped(design, _holding, _spot, _way)
		if way.is_empty():
			ui.toast("It only goes on one way up there.")
		else:
			_take_way(way)
		return
	_ghost_place = _turned_in_place(_holding, _ghost_place, Basis(Vector3.RIGHT, PI))
	_show_ghost()


## Puts the part in hand on the same spot by the next of its own connectors.
func way_on() -> void:
	if _holding == "" or _spot.is_empty():
		return
	var way := Snap.next_way(design, _holding, _spot, _way)
	if way.is_empty():
		ui.toast("It only goes on there one way.")
	else:
		_take_way(way)


## Slides the part in hand along the bar, axle or hinge it's on.
func slide() -> void:
	if _holding == "" or _spot.is_empty() or not Snap.slides(_spot, _way):
		return
	var way := Snap.slid(design, _holding, _spot, _way)
	_spot = way.spot
	_take_way(way)


func _take_way(way: Dictionary) -> void:
	_way = way
	_ghost_place = way.place
	_show_ghost()


## A part turned by `turn` about the middle of its box, kept on the grid.
func _turned_in_place(id: String, place: Transform3D, turn: Basis) -> Transform3D:
	var centre := KartDesign.fine_box(id, place).get_center() / Grid.UNIT_FINE
	var basis := Snap.exact(turn * place.basis)
	var size := Vector3(KartDesign.grid_size(id, basis))
	var at := Vector3i(roundi(centre.x - size.x * 0.5), roundi(centre.y - size.y * 0.5), roundi(centre.z - size.z * 0.5))
	return _clamped(id, KartDesign.box_place(id, basis, at))


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
	var entry := KartDesign.placed_entry(_holding, _ghost_place, _holding_colour)
	design.parts.append(entry)
	var placed := design.parts.size() - 1
	if mirror and _moving.is_empty():
		var twin := mirrored(entry)
		var twin_place := KartDesign.place_of(twin)
		if not twin_place.is_equal_approx(_ghost_place) and design.fits_place(twin.id, twin_place) and design.attaches_place(twin.id, twin_place):
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
	_find_spots()
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
	start_placing(p.id, KartDesign.place_of(p).basis, p.get("color"), KartDesign.place_of(p))
	_moving = { "index": index, "entry": p }
	_show_ghost()


## Picks up a copy of the picked out part, turned and painted the same, beside
## it if there's room.
func copy_selected() -> void:
	if _selected == -1:
		return
	var p: Dictionary = design.parts[_selected]
	var from := KartDesign.place_of(p)
	var size := KartDesign.fine_box(p.id, from).size
	var spot := from
	for offset in [Vector3(size.x, 0, 0), Vector3(-size.x, 0, 0), Vector3(0, 0, size.z), Vector3(0, 0, -size.z), Vector3(0, size.y, 0)]:
		var place := Transform3D(from.basis, from.origin + offset)
		if design.fits_place(p.id, place) and design.attaches_place(p.id, place):
			spot = place
			break
	start_placing(p.id, from.basis, p.get("color"), spot)


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
	# A left handed part's twin is the right handed one.
	var id: String = PartCatalog.get_part(entry.id).get("mirror", entry.id)
	return KartDesign.placed_entry(id, Snap.mirror_place(entry.id, KartDesign.place_of(entry)), entry.get("color"))


## The index of the part that's exactly this one, or -1.
func find_part(entry: Dictionary) -> int:
	var place := KartDesign.place_of(entry)
	for i in design.parts.size():
		var p: Dictionary = design.parts[i]
		if p.id == entry.id and KartDesign.place_of(p).is_equal_approx(place):
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
		var place := KartDesign.place_of(p)
		var node := _part_node(p.id, place.basis, p.get("color"))
		node.position = _world_centre(p.id, place)
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
	var moves := { "turn": true }
	if _mode == GarageUI.Mode.PLACING:
		what = PartCatalog.get_part(_holding).get("name", _holding)
		moves = {
			"turn": not KartDesign.is_wheel(_holding),
			"flip": true,
			"way": not _spot.is_empty(),
			"slide": not _spot.is_empty() and Snap.slides(_spot, _way),
		}
	elif _mode == GarageUI.Mode.SELECTED and _selected != -1:
		var id: String = design.parts[_selected].id
		what = PartCatalog.get_part(id).get("name", id)
		moves = { "turn": not KartDesign.is_wheel(id) }
	ui.set_mode(_mode, what, moves)
	ui.set_can_place(_ghost_ok)
	ui.set_history(not _undo.is_empty(), not _redo.is_empty())


func _part_node(id: String, basis: Basis, colour: Variant = null) -> Node3D:
	var def := PartCatalog.get_part(id)
	if colour != null:
		def = def.duplicate()
		def["color"] = colour
	var extent := (Transform3D(basis, Vector3.ZERO) * AABB(Vector3.ZERO, PartCatalog.fine_size(id))).size * Grid.FINE
	return PartVisuals.make_turned(def, extent, basis)


func _world_centre(id: String, place: Transform3D) -> Vector3:
	return place * (PartCatalog.fine_size(id) * 0.5) * Grid.FINE


## Remakes the part in hand and its twin when they've been turned.
func _make_ghosts() -> void:
	var twin_id: String = PartCatalog.get_part(_holding).get("mirror", _holding)
	var twin_turn := Snap.mirror_place(_holding, _ghost_place).basis
	if _ghost == null or not _ghost_turn.is_equal_approx(_ghost_place.basis):
		if _ghost != null:
			_ghost.queue_free()
		_ghost = _part_node(_holding, _ghost_place.basis, _holding_colour)
		_ghost_turn = _ghost_place.basis
		add_child(_ghost)
	if _twin_ghost == null or not _twin_turn.is_equal_approx(twin_turn):
		if _twin_ghost != null:
			_twin_ghost.queue_free()
		_twin_ghost = _part_node(twin_id, twin_turn, _holding_colour)
		_twin_turn = twin_turn
		add_child(_twin_ghost)


## Points the part being placed at whatever is under this screen position. It
## snaps onto the nearest dot there, or failing that sits on the grid where
## the finger is, the way bricks always have.
func _aim_ghost(screen_pos: Vector2) -> void:
	if _holding == "":
		return
	var hit := _cast(screen_pos)
	if snap_to(_spot_under(screen_pos, hit)):
		return
	if not hit.is_hit():
		return
	var basis := _ghost_place.basis
	var at := BuildMath.placement(hit, KartDesign.grid_size(_holding, basis))
	_ghost_place = _clamped(_holding, KartDesign.box_place(_holding, basis, BuildMath.nearest_cell(design, _holding, at, basis)))
	_spot = {}
	_way = {}
	_show_ghost()


## Snaps the part in hand onto a spot, the best way it fits there. Returns
## whether it went on.
func snap_to(spot: Dictionary) -> bool:
	if spot.is_empty() or _holding == "":
		return false
	var way := Snap.best(design, _holding, Snap.ways(_holding, spot, _ghost_place.basis, spot.at))
	if way.is_empty():
		return false
	_spot = spot
	_take_way(way)
	return true


## The dot nearest this screen position, if there's one close enough that
## isn't hidden behind the kart.
func _spot_under(screen_pos: Vector2, hit: BuildMath.Hit) -> Dictionary:
	var eye := _camera.global_position
	var depth := INF
	if hit.is_hit() and hit.part != -1:
		depth = (Grid.to_metres(hit.point) - eye).length() + Grid.STUD
	var best := {}
	var best_distance := SNAP_RADIUS
	for spot in _spots:
		var at: Vector3 = _dot_position(spot)
		if _camera.is_position_behind(at) or (at - eye).length() > depth:
			continue
		var distance := _camera.unproject_position(at).distance_to(screen_pos)
		if distance < best_distance:
			best_distance = distance
			best = spot
	return best


func _show_ghost() -> void:
	if _holding == "":
		_refresh_ui()
		return
	_make_ghosts()
	_ghost_ok = design.fits_place(_holding, _ghost_place) and design.attaches_place(_holding, _ghost_place)
	_ghost.position = _world_centre(_holding, _ghost_place)
	_ghost.visible = true
	PartVisuals.set_ghost(_ghost, _ghost_ok)
	var twin := mirrored({ "id": _holding, "place": _ghost_place })
	var twin_place := KartDesign.place_of(twin)
	_twin_ghost.visible = mirror and _moving.is_empty() and not twin_place.is_equal_approx(_ghost_place)
	if _twin_ghost.visible:
		_twin_ghost.position = _world_centre(twin.id, twin_place)
		PartVisuals.set_ghost(_twin_ghost, design.fits_place(twin.id, twin_place))
	_show_dots()
	_refresh_ui()


## Keeps a part inside the build area.
func _clamped(id: String, place: Transform3D) -> Transform3D:
	var box := KartDesign.fine_box(id, place)
	var most := Vector3(KartDesign.BUILD_SIZE) * Grid.UNIT_FINE
	var shift := Vector3.ZERO
	for k in 3:
		if box.position[k] < 0.0:
			shift[k] = -box.position[k]
		elif box.end[k] > most[k]:
			shift[k] = most[k] - box.end[k]
	return Transform3D(place.basis, place.origin + shift)


# The dots for the spots a part could join.

func _make_dots() -> void:
	var shader := Shader.new()
	# Pulled a little toward the camera, so a dot on a face isn't lost in it.
	shader.code = """
shader_type spatial;
render_mode unshaded;
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z += 0.03;
	POSITION = PROJECTION_MATRIX * view;
}
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var ball := SphereMesh.new()
	ball.radius = 0.035
	ball.height = 0.07
	ball.radial_segments = 10
	ball.rings = 5
	ball.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = ball
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = multi
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)
	var here := SphereMesh.new()
	here.radius = 0.06
	here.height = 0.12
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	white.no_depth_test = true
	here.material = white
	_dot_here = MeshInstance3D.new()
	_dot_here.mesh = here
	_dot_here.visible = false
	add_child(_dot_here)


## Works out the spots the part in hand could join.
func _find_spots() -> void:
	_spots = Snap.spots_for(design, _holding) if _holding != "" else []


func _show_dots() -> void:
	var multi := _dots.multimesh
	multi.instance_count = _spots.size()
	for i in _spots.size():
		var spot: Dictionary = _spots[i]
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, _dot_position(spot)))
		multi.set_instance_color(i, DOT_COLOURS.get(spot.type, Color.WHITE))
	_dot_here.visible = not _spot.is_empty()
	if _dot_here.visible:
		_dot_here.position = _dot_position(_spot)


## Where a spot's dot goes, in metres: on the top of a stud, and just off the
## face for everything else.
func _dot_position(spot: Dictionary) -> Vector3:
	var out: float = 0.055 if spot.type == "stud" else 0.012
	return spot.at * Grid.FINE + spot.axis * out


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
		KEY_F:
			flip()
		KEY_T:
			way_on()
		KEY_S:
			slide()
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
			# And one on the part that's picked out moves that.
			_grab_selected = _mode == GarageUI.Mode.SELECTED and _selected != -1 and _camera.unproject_position(_part_nodes[_selected].global_position).distance_to(event.position) < GRAB_RADIUS
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
		_grab_selected = false
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
		if _grab_selected:
			_grab_selected = false
			move_selected()
			_moving_ghost = true
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
