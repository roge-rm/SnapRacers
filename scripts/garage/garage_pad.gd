class_name GaragePad
extends Node

## The garage with a controller.
##
## - Picking a part, the d-pad moves round the drawer, A takes the part, and LB
##   and RB go to the tab before or after. Y moves over to the kart, X turns
##   Mirror on and off, Back starts painting, and LT and RT undo and redo.
## - Holding a part, the d-pad or the left stick hops to the next dot that way
##   (or a stud, where there are none). A puts it down, X turns it, Y flips it,
##   LB puts it on another way, RB slides it, and LT and RT move it down and up
##   a plate. B puts it back.
## - On the kart, the d-pad hops from part to part. A moves the one picked
##   out, X turns it, Y copies it and Back deletes it. B goes back to the
##   drawer.
## - Painting, the d-pad hops from part to part, A paints it, and LB and RB
##   pick the colour. B stops.
##
## The right stick turns the camera round the kart. Pressing it in fits the
## kart in view, and pressing the left stick goes round the views. Start opens
## the file menu, and B from the drawer leaves the garage.

## How long a direction is held before it hops again, in seconds.
const REPEAT := 0.22
## How fast the right stick turns the camera, in pixels of drag a second.
const ORBIT := 700.0
const PUSH := 0.6
## How far round from straight ahead something can be to count as that way.
const CONE := 0.5

var garage: Garage
## Moving round the kart rather than the drawer.
var on_kart := false
## The part hopped to while painting.
var paint_at := -1

var _held := Vector2.ZERO
var _repeat_left := 0.0
var _triggers := { JOY_AXIS_TRIGGER_LEFT: false, JOY_AXIS_TRIGGER_RIGHT: false }
var _views := ["angle", "front", "side", "top"]


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and _triggers.has(event.axis):
		var down: bool = event.axis_value > PUSH
		if down and not _triggers[event.axis]:
			_trigger(event.axis == JOY_AXIS_TRIGGER_RIGHT)
		_triggers[event.axis] = down
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	PadFocus.using_pad = true
	var handled := _button(event.button_index)
	if handled:
		get_viewport().set_input_as_handled()


func _button(button: JoyButton) -> bool:
	var mode := garage._mode
	var dirs := { JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN, JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT }
	if dirs.has(button):
		if mode == GarageUI.Mode.IDLE and not on_kart:
			# The drawer's buttons move the focus themselves, once there is some.
			return _focus_drawer()
		hop(dirs[button])
		return true
	match button:
		JOY_BUTTON_A:
			match mode:
				GarageUI.Mode.PLACING:
					garage.place()
				GarageUI.Mode.SELECTED:
					garage.move_selected()
				GarageUI.Mode.PAINTING:
					if paint_at != -1:
						garage.paint(paint_at, garage.ui.paint_colour())
				_:
					if on_kart:
						hop(Vector2.ZERO)
					else:
						return false # the drawer's tile takes it
		JOY_BUTTON_B:
			match mode:
				GarageUI.Mode.PLACING:
					garage.cancel()
				GarageUI.Mode.SELECTED:
					garage.select(-1)
					_back_to_drawer()
				GarageUI.Mode.PAINTING:
					garage.set_painting(false)
					paint_at = -1
				_:
					if on_kart:
						_back_to_drawer()
					else:
						garage.go_back()
		JOY_BUTTON_X:
			match mode:
				GarageUI.Mode.PLACING, GarageUI.Mode.SELECTED:
					garage.turn()
				_:
					garage.set_mirror(not garage.mirror)
		JOY_BUTTON_Y:
			match mode:
				GarageUI.Mode.PLACING:
					garage.flip()
				GarageUI.Mode.SELECTED:
					garage.copy_selected()
				_:
					on_kart = true
					_release_focus()
					hop(Vector2.ZERO)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			var right := button == JOY_BUTTON_RIGHT_SHOULDER
			match mode:
				GarageUI.Mode.PLACING:
					garage.slide() if right else garage.way_on()
				GarageUI.Mode.PAINTING:
					garage.ui.next_colour(1 if right else -1)
				_:
					next_tab(1 if right else -1)
		JOY_BUTTON_BACK:
			match mode:
				GarageUI.Mode.SELECTED:
					garage.delete_selected()
					_back_to_drawer()
				GarageUI.Mode.IDLE:
					garage.set_painting(true)
					paint_at = -1
					hop(Vector2.ZERO)
				_:
					return false
		JOY_BUTTON_START:
			garage.ui._file_menu.popup_centered(Vector2i(320, 0))
		JOY_BUTTON_RIGHT_STICK:
			garage.show_view("fit")
		JOY_BUTTON_LEFT_STICK:
			var view: String = _views.pop_front()
			_views.append(view)
			garage.show_view(view)
		_:
			return false
	return true


func _trigger(right: bool) -> void:
	PadFocus.using_pad = true
	if garage._mode == GarageUI.Mode.PLACING:
		garage.lift(1 if right else -1)
	elif right:
		garage.redo()
	else:
		garage.undo()


## The drawer's tab before or after.
func next_tab(by: int) -> void:
	var ui := garage.ui
	ui._show_category(posmod(ui._category + by, GarageUI.CATEGORIES.size()))
	_focus_drawer.call_deferred(true)


func _focus_drawer(again := false) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and garage.ui._tiles.is_ancestor_of(focused) and not again:
		return false
	for tile in garage.ui._tiles.get_children():
		if tile is GarageUI.PartTile and not tile.is_queued_for_deletion():
			tile.grab_focus()
			return true
	return false


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _back_to_drawer() -> void:
	on_kart = false
	_focus_drawer(true)


## Hops the part in hand to the next dot this way on the screen, or picks
## out the next part on the kart this way. With no direction it's the one
## nearest the middle of the screen.
func hop(direction: Vector2) -> void:
	var camera := garage._camera
	var from := garage._view_middle()
	if garage._mode == GarageUI.Mode.PLACING:
		if garage._ghost != null and garage._ghost.visible:
			from = camera.unproject_position(garage._ghost.global_position)
		var spots := garage._spots.filter(func(s: Dictionary) -> bool: return not camera.is_position_behind(garage._dot_position(s)))
		var best := _nearest(spots.map(func(s): return camera.unproject_position(garage._dot_position(s))), from, direction)
		if best != -1 and garage.snap_to(spots[best]):
			return
		if direction != Vector2.ZERO:
			garage.nudge(Vector2i(roundi(direction.x), roundi(direction.y)))
		return
	var nodes := garage._part_nodes
	var now := garage._selected if garage._mode != GarageUI.Mode.PAINTING else paint_at
	if now != -1 and now < nodes.size():
		from = camera.unproject_position(nodes[now].global_position)
	var points := nodes.map(func(n: Node3D) -> Vector2: return camera.unproject_position(n.global_position))
	if now != -1:
		points[now] = Vector2.INF
	var pick := _nearest(points, from, direction)
	if pick == -1:
		return
	if garage._mode == GarageUI.Mode.PAINTING:
		if paint_at != -1 and paint_at < nodes.size():
			PartVisuals.set_highlight(nodes[paint_at], false)
		paint_at = pick
		PartVisuals.set_highlight(nodes[pick], true)
	else:
		garage.select(pick)


## The point nearest `from` that's roughly `direction` from it, or the
## nearest of all with no direction, as an index, or -1.
static func _nearest(points: Array, from: Vector2, direction: Vector2) -> int:
	var best := -1
	var best_cost := INF
	for i in points.size():
		var p: Vector2 = points[i]
		if not p.is_finite():
			continue
		var off := p - from
		var cost := off.length()
		if direction != Vector2.ZERO:
			if off.length() < 4.0:
				continue
			var along := off.normalized().dot(direction)
			if along < CONE:
				continue
			cost /= along
		if cost < best_cost:
			best_cost = cost
			best = i
	return best


## The sticks: the left one hops while it's held over, and the right one
## turns the camera.
func _process(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty() or garage == null:
		return
	var pad: int = pads[0]
	var right := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
	if right.length() > 0.2:
		garage._orbit(right * ORBIT * delta)
	var left := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	var way := Vector2.ZERO
	if left.length() > PUSH:
		way = Vector2(signf(left.x), 0.0) if absf(left.x) > absf(left.y) else Vector2(0.0, signf(left.y))
	if way == Vector2.ZERO or (garage._mode == GarageUI.Mode.IDLE and not on_kart):
		_held = Vector2.ZERO
		return
	if way != _held:
		_held = way
		_repeat_left = REPEAT
		hop(way)
		return
	_repeat_left -= delta
	if _repeat_left <= 0.0:
		_repeat_left = REPEAT
		hop(way)
