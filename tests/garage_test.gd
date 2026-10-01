extends Node

## Uses the garage the way a player would, and checks what happens to the
## kart: placing parts from the bank and nudging them into place, snapping
## them onto the dots and turning, flipping and sliding them there, mirror,
## moving, copying, painting and deleting parts, undo and redo, and the camera
## views.
##
## It runs as a scene instead of a -s script, because the screens use the
## Game autoload and -s scripts can't see autoloads. Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/garage_test.tscn

## A free spot on top of the starter's chassis, and its mirror image across
## the middle of the kart.
const SPOT := Vector3i(7, 3, 11)
const TWIN := Vector3i(11, 3, 11)
const OLD_STARTER := "res://tests/data/old_starter.json"

var failures := 0
var garage: Garage
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A pretend touch, straight to the garage. The headless window is tiny and
## stretched, so a touch pushed through the viewport lands somewhere else.
func touch(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = pressed
	garage._unhandled_input(event)


## Where a grid position shows up on the screen.
func screen_of(cell: Vector3) -> Vector2:
	return get_viewport().get_camera_3d().unproject_position(Grid.to_metres(cell))


func count(id: String, at: Vector3i) -> int:
	return garage.design.parts.filter(func(p): return p.id == id and p.at == at).size()


## Nothing sits under a camera hole, wherever it is: the panels step out of
## the way or wrap around it, and go back when it's gone.
func _camera_hole() -> void:
	var ui: GarageUI = garage.ui
	var safe: SafeArea = ui.find_children("SafeArea", "SafeArea", false, false)[0]
	var drawer_height: float = ui._drawer.size.y
	var window := SafeArea.screen_size(get_viewport())
	# Holes like a phone's, in the corners and partway down the left side, a
	# tenth of the screen's height across.
	var across := window.y * 0.1
	var spots := {
		"top left": Vector2(0.0, 0.0), "bottom left": Vector2(0.0, window.y - across),
		"top right": Vector2(window.x - across, 0.0), "partway down the left": Vector2(across * 0.3, window.y * 0.3),
	}
	for spot in spots:
		SafeArea.pretend = [Rect2(spots[spot], Vector2(across, across))]
		safe.refit()
		await frames(8)
		var hole: Rect2 = safe.holes()[0]
		var drawer: Rect2 = ui._drawer.get_global_rect()
		var under := []
		for button in ui.find_children("*", "BaseButton", true, false):
			if not button.is_visible_in_tree():
				continue
			var rect: Rect2 = button.get_global_rect()
			# Tiles scrolled out of the drawer can't be seen anyway.
			if ui._drawer.is_ancestor_of(button):
				rect = rect.intersection(drawer)
			if rect.has_area() and rect.intersects(hole):
				under.append(button.tooltip_text if button.tooltip_text != "" else button.name)
		check(under.is_empty(), "with a camera hole %s, no button's under it %s" % [spot, under])
		if spot == "partway down the left":
			check(ui._drawer.size.y > drawer_height * 0.95, "and the drawer wraps around it instead of getting shorter")
	SafeArea.pretend = []
	safe.refit()
	await frames(8)
	check(is_equal_approx(ui._drawer.size.y, drawer_height), "with no hole the drawer's back to full height")


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	# Start from the starter kart as it was built before parts had their own
	# connectors, which also checks a kart saved back then still works, and
	# not from whatever an earlier run left as the kart being worked on.
	Game.design = KartDesign.load_file(OLD_STARTER)
	Game.show_garage()
	await frames(3)
	garage = host.get_child(host.get_child_count() - 1)
	check(garage is Garage, "the game opens in the garage")
	garage.finger_lift = 0.0
	var parts := garage.design.parts.size()
	check(parts == KartDesign.load_file(OLD_STARTER).parts.size(), "with the old starter kart in it (%d parts)" % parts)
	await _bank()
	await _placing(parts)
	await _mirror_and_paint(parts)
	await _moving(parts)
	await _snapping(parts)
	await _controller(parts)
	await _camera()
	await _camera_hole()
	garage.ui.drive_pressed.emit()
	await frames(6)
	check(host.get_child(host.get_child_count() - 1) is TestDrive, "drive takes the kart out to the track")
	print("All garage checks passed." if failures == 0 else "%d garage checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _bank() -> void:
	var tiles := garage.ui.find_children("*", "Button", true, false).filter(func(b): return b is GarageUI.PartTile)
	var plates := PartCatalog.ids().filter(func(id): return GarageUI.category_of(PartCatalog.get_part(id)) == 0).size()
	check(tiles.size() == plates and plates > 20, "the bank starts on the plates and tiles (%d of %d)" % [tiles.size(), plates])
	# Every part is in one of the drawer's tabs, and every tab has something.
	var shown := {}
	for i in GarageUI.CATEGORIES.size():
		garage.ui._show_category(i)
		await frames(1)
		var ids: Array = garage.ui.find_children("*", "Button", true, false).filter(func(b): return b is GarageUI.PartTile and not b.is_queued_for_deletion()).map(func(b): return b.id)
		check(not ids.is_empty(), "the %s tab has parts in it" % GarageUI.CATEGORIES[i][0])
		for id in ids:
			shown[id] = true
	var missing := PartCatalog.ids().filter(func(id): return not shown.has(id))
	check(missing.is_empty(), "every part is in the drawer somewhere %s" % [missing])
	garage.ui._show_category(6)
	await frames(1)
	var extras: Array = garage.ui.find_children("*", "Button", true, false).filter(func(b): return b is GarageUI.PartTile).map(func(b): return b.id)
	check(extras.has("steering_wheel") and extras.has("seat"), "extras have the seat and the steering wheel %s" % [extras])
	garage.ui._show_category(1)


func _placing(parts: int) -> void:
	garage.ui.part_chosen.emit("brick_2x2")
	check(garage._mode == GarageUI.Mode.PLACING and garage._ghost.visible, "tapping a part in the bank shows it on the kart")
	garage.start_placing("brick_2x2", Basis.IDENTITY, null, SPOT)
	check(garage._ghost_ok, "it fits in the free spot on the chassis")
	garage.ui.place_pressed.emit()
	check(garage.design.parts.size() == parts + 1 and count("brick_2x2", SPOT) == 1, "Place puts it down")
	check(garage._mode == GarageUI.Mode.PLACING, "and you're still holding one, to put down a row")
	# Nudging moves it a stud at a time, and back again.
	var before := garage.ghost_at()
	garage.ui.nudged.emit(Vector2i(1, 0))
	var moved := garage.ghost_at() - before
	check(absi(moved.x) + absi(moved.z) == 1 and moved.y == 0, "an arrow moves it one stud (%s)" % moved)
	garage.ui.nudged.emit(Vector2i(-1, 0))
	check(garage.ghost_at() == before, "and the other arrow moves it back")
	garage.ui.raise_pressed.emit()
	check(garage.ghost_at().y == before.y + 1, "Up moves it up a plate")
	garage.ui.lower_pressed.emit()
	check(garage.ghost_at().y == before.y, "and Down back down")
	garage.ui.turn_pressed.emit()
	check(garage._ghost_place.basis.is_equal_approx(Grid.yaw(1)), "Turn turns it")
	garage.ui.cancel_pressed.emit()
	check(garage._mode == GarageUI.Mode.IDLE and garage.design.parts.size() == parts + 1, "Cancel stops without putting anything else down")
	garage.ui.undo_pressed.emit()
	check(garage.design.parts.size() == parts, "undo takes the brick back off")
	garage.ui.redo_pressed.emit()
	check(garage.design.parts.size() == parts + 1, "and redo puts it back")
	garage.ui.undo_pressed.emit()

	# Dragging a part out of the bank onto the kart.
	garage.ui.part_dragged.emit("brick_1x2", 0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = screen_of(Vector3(10, 3, 12))
	garage._input(drag)
	var lift := InputEventScreenTouch.new()
	lift.index = 0
	lift.position = drag.position
	lift.pressed = false
	garage._input(lift)
	check(garage._mode == GarageUI.Mode.PLACING and garage._ghost.visible and garage.ghost_at().y >= 3, "dragging a part out of the bank drops it on the kart (%s)" % garage.ghost_at())
	garage.cancel()


func _mirror_and_paint(parts: int) -> void:
	garage.ui.mirror_toggled.emit(true)
	check(garage.mirror, "Mirror turns on")
	garage.start_placing("brick_2x2", Basis.IDENTITY, null, SPOT)
	check(garage._twin_ghost.visible, "and shows where the other one goes")
	garage.place()
	garage.cancel()
	check(count("brick_2x2", SPOT) == 1 and count("brick_2x2", TWIN) == 1, "putting one down puts its twin down on the other side")
	garage.ui.paint_toggled.emit(true)
	check(garage._mode == GarageUI.Mode.PAINTING, "Paint starts painting")
	var blue := Color("#0d69ab")
	garage.paint(garage.find_part(KartDesign.grid_entry("brick_2x2", SPOT, 0)), blue)
	var painted: Array = garage.design.parts.filter(func(p): return p.id == "brick_2x2" and p.get("color", Color.BLACK).is_equal_approx(blue))
	check(painted.size() == 2, "painting one paints its twin too (%d)" % painted.size())
	garage.ui.paint_toggled.emit(false)
	garage.select(garage.find_part(KartDesign.grid_entry("brick_2x2", SPOT, 0)))
	check(garage._mode == GarageUI.Mode.SELECTED, "picking a part out shows its buttons")
	garage.ui.delete_pressed.emit()
	check(count("brick_2x2", SPOT) == 0 and count("brick_2x2", TWIN) == 0 and garage.design.parts.size() == parts, "deleting one deletes its twin")
	garage.ui.mirror_toggled.emit(false)


func _moving(parts: int) -> void:
	# Touching the engine picks it out.
	var engine := garage.design.parts.map(func(p): return p.id).find("engine_small")
	var p: Dictionary = garage.design.parts[engine]
	var middle := Vector3(p.at) + Vector3(Grid.rotated_size(PartCatalog.get_part(p.id).size, p.rot)) * Vector3(0.5, 1.0, 0.5)
	touch(screen_of(middle), true)
	touch(screen_of(middle), false)
	check(garage._selected != -1, "touching a part on the kart picks it out (%s)" % (garage.design.parts[garage._selected].id if garage._selected != -1 else "nothing"))
	var picked: Dictionary = garage.design.parts[garage._selected]
	var undo_steps := garage._undo.size()
	garage.ui.move_pressed.emit()
	check(garage._mode == GarageUI.Mode.PLACING and garage.design.parts.size() == parts - 1, "Move lifts it off to move it")
	garage.nudge(Vector2i(0, -1))
	garage.ui.cancel_pressed.emit()
	check(garage.design.parts.size() == parts and count(picked.id, picked.at) == 1, "and Cancel puts it back where it was")
	check(garage._undo.size() == undo_steps, "without an undo step for nothing")
	garage.ui.copy_pressed.emit()
	check(garage._mode == GarageUI.Mode.PLACING and garage._holding == picked.id, "Copy picks up another one the same")
	garage.cancel()
	garage.select(-1)


func _camera() -> void:
	garage.show_view("top")
	check(garage._pitch < deg_to_rad(-80.0), "the top view looks down on the kart")
	# From above with the front up the screen, right on the screen is +X.
	garage.start_placing("brick_1x2", Basis.IDENTITY, null, SPOT)
	var before := garage.ghost_at()
	garage.nudge(Vector2i(1, 0))
	check(garage.ghost_at() - before == Vector3i(1, 0, 0), "from the top, the right arrow moves it right (%s)" % (garage.ghost_at() - before))
	garage.nudge(Vector2i(0, -1))
	check(garage.ghost_at() - before == Vector3i(1, 0, -1), "and the up arrow moves it toward the front")
	garage.cancel()
	garage.show_view("front")
	check(is_equal_approx(garage._yaw, PI), "the front view looks at the front")
	var far := garage._distance
	garage.show_view("fit")
	check(garage._distance > 2.0 and garage._distance < 16.0 and is_equal_approx(garage._distance, far), "and fit frames the whole kart (%.1f m)" % garage._distance)


## The free spot on the kart at this point, in the fine unit, from the ones
## the part in hand could join.
func spot_at(at: Vector3) -> Dictionary:
	for spot in garage._spots:
		if spot.at.distance_to(at) < 0.5:
			return spot
	return {}


func _snapping(parts: int) -> void:
	garage.show_view("top")
	garage.ui.part_chosen.emit("p_curve_2x2")
	check(not garage._spots.is_empty() and garage._dots.multimesh.instance_count == garage._spots.size(), "holding a part shows dots where it could join (%d)" % garage._spots.size())
	check(garage._spots.all(func(s): return s.type == "stud"), "and a curve only joins studs")
	# The free stud on the chassis at SPOT, tapped the way a finger would.
	var stud := spot_at((Vector3(SPOT) + Vector3(0.5, 0.0, 0.5)) * Grid.UNIT_FINE)
	check(not stud.is_empty(), "there's a dot on a free stud of the chassis")
	garage._aim_ghost(get_viewport().get_camera_3d().unproject_position(garage._dot_position(stud)))
	check(not garage._spot.is_empty() and garage._spot.at == stud.at, "tapping the dot snaps the curve onto it")
	check(garage._ghost_ok, "and it fits there")
	var on := func() -> bool: return (garage._ghost_place * garage._way.own.at).distance_to(stud.at) < 0.5
	var before: Transform3D = garage._ghost_place
	var own: int = garage._way.own.index
	garage.ui.way_pressed.emit()
	check(garage._way.own.index != own and on.call() and not garage._ghost_place.is_equal_approx(before), "Way on puts it on the same stud by another of its sockets")
	before = garage._ghost_place
	garage.ui.turn_pressed.emit()
	check(not garage._ghost_place.basis.is_equal_approx(before.basis) and on.call(), "Turn turns it about the stud")
	before = garage._ghost_place
	garage.ui.flip_pressed.emit()
	check(garage._ghost_place.is_equal_approx(before), "Flip leaves it, since it can't go on a stud upside down")
	check(garage.ui._slide.disabled, "and there's nothing to slide it along")
	garage.ui.place_pressed.emit()
	check(garage.design.parts.size() == parts + 1, "Place puts it on")
	garage.cancel()

	# A clip slides along a bar.
	var handle := Vector3i(12, 3, 11)
	garage.start_placing("p_plate_handle_1x2", Basis.IDENTITY, null, handle)
	check(garage._ghost_ok, "a plate with a handle fits on the chassis")
	garage.place()
	garage.cancel()
	garage.start_placing("p_plate_clip_1x1")
	var bars := garage._spots.filter(func(s): return s.type == "bar")
	check(not bars.is_empty(), "and a clip can go on its handle (%d dots)" % bars.size())
	if not bars.is_empty():
		check(garage.snap_to(bars[0]) and Snap.slides(garage._spot, garage._way), "it snaps onto the handle")
		check(not garage.ui._slide.disabled, "and can slide")
		var from: Vector3 = garage._ghost_place.origin
		garage.ui.slide_pressed.emit()
		var moved: Vector3 = garage._ghost_place.origin - from
		check(is_equal_approx(moved.length(), Snap.SLIDE) and absf(moved.normalized().dot(bars[0].axis)) > 0.99, "Slide moves it along the handle (%s)" % moved)
		for i in 20:
			garage.slide()
		check(KartDesign.joined({ "id": "p_plate_clip_1x1", "place": garage._ghost_place }, garage.design.parts[garage.design.parts.size() - 1]), "and past the end it goes back, still on the handle")
	garage.cancel()
	check(garage.design.parts.size() == parts + 2, "with the curve and the handle on")

	# Dragging a part that's picked out moves it.
	var curve := garage.design.parts.size() - 2
	garage.select(curve)
	await frames(1)
	var at := get_viewport().get_camera_3d().unproject_position(garage._part_nodes[curve].global_position)
	touch(at, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = at + Vector2(40, 0)
	drag.relative = Vector2(40, 0)
	garage._unhandled_input(drag)
	check(garage._mode == GarageUI.Mode.PLACING and not garage._moving.is_empty() and garage._holding == "p_curve_2x2", "dragging a picked out part picks it up to move it")
	touch(drag.position, false)
	garage.cancel()
	check(garage.design.parts.size() == parts + 2, "and Cancel puts it back")
	garage.ui.undo_pressed.emit()
	garage.ui.undo_pressed.emit()
	check(garage.design.parts.size() == parts, "undo takes them both off")


## The garage with a controller (see GaragePad).
func _controller(parts: int) -> void:
	var pad: GaragePad = garage.find_children("*", "GaragePad", false, false)[0]
	garage.select(-1)
	pad.on_kart = false
	pad._button(JOY_BUTTON_DPAD_DOWN)
	await frames(1)
	var focused := get_viewport().gui_get_focus_owner()
	check(focused is GarageUI.PartTile, "the d-pad picks out a part in the drawer (%s)" % focused)
	var tab := garage.ui._category
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(2)
	check(garage.ui._category == (tab + 1) % GarageUI.CATEGORIES.size() and get_viewport().gui_get_focus_owner() is GarageUI.PartTile, "RB goes to the next tab, still picking out a part")
	pad._button(JOY_BUTTON_LEFT_SHOULDER)
	await frames(2)

	garage.ui.part_chosen.emit("p_curve_2x2")
	pad._button(JOY_BUTTON_DPAD_RIGHT)
	check(not garage._spot.is_empty(), "holding a part, the d-pad hops it onto a dot")
	var turned_from: Basis = garage._ghost_place.basis
	pad._button(JOY_BUTTON_X)
	check(not garage._ghost_place.basis.is_equal_approx(turned_from), "X turns it")
	var high := garage.ghost_at().y
	pad._trigger(true)
	check(garage.ghost_at().y == high + 1, "RT lifts it a plate")
	pad._trigger(false)
	pad._button(JOY_BUTTON_DPAD_RIGHT)
	var ok := garage._ghost_ok
	pad._button(JOY_BUTTON_A)
	check(not ok or garage.design.parts.size() == parts + 1, "A puts it down where it fits")
	pad._button(JOY_BUTTON_B)
	check(garage._mode == GarageUI.Mode.IDLE, "B puts the part in hand back")
	if garage.design.parts.size() > parts:
		garage.undo()

	pad._button(JOY_BUTTON_Y)
	check(pad.on_kart and garage._mode == GarageUI.Mode.SELECTED, "Y goes over to the kart and picks out a part")
	var first := garage._selected
	pad._button(JOY_BUTTON_DPAD_LEFT)
	pad._button(JOY_BUTTON_DPAD_UP)
	check(garage._selected != -1 and garage._selected != first, "the d-pad hops to another part (%d to %d)" % [first, garage._selected])
	pad._button(JOY_BUTTON_BACK)
	check(garage.design.parts.size() == parts - 1 and not pad.on_kart, "Back deletes it")
	pad._trigger(false)
	check(garage.design.parts.size() == parts, "and LT undoes that")

	pad._button(JOY_BUTTON_BACK)
	check(garage._mode == GarageUI.Mode.PAINTING and pad.paint_at != -1, "Back in the drawer starts painting, with a part picked out")
	var colour := garage.ui.paint_colour()
	pad._button(JOY_BUTTON_RIGHT_SHOULDER)
	check(not garage.ui.paint_colour().is_equal_approx(colour), "RB picks the next colour")
	var target := pad.paint_at
	pad._button(JOY_BUTTON_A)
	check(garage.design.parts[target].get("color", Color.BLACK).is_equal_approx(garage.ui.paint_colour()), "and A paints the part")
	garage.undo()
	pad._button(JOY_BUTTON_B)
	check(garage._mode == GarageUI.Mode.IDLE, "B stops painting")
