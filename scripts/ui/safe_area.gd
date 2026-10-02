class_name SafeArea
extends Node

## Keeps controls out from under a camera hole (a display cutout).
##
## The game draws right to the edges of the screen, hole and all, so anything
## where the hole is can't be seen or tapped. Add one of these to a screen and
## watch() the controls along its edges. Each one steps out of the hole's way
## by as little as it can. A panel as tall or wide as the screen gets shorter
## at the end the hole's at, and anything smaller slides along or down just
## past it. With no hole they stay where they were put.
##
## A hole partway down a side (where a phone's top middle hole ends up in
## landscape) would leave a tall panel only half its height, so a panel that
## can wraps around it instead. Its rows and columns given to flow() leave a
## gap where the hole is, so a row of buttons carries on past it.
##
## The phone can be turned either way up in landscape, which moves the hole to
## the other side, so it keeps checking.

## How far clear of the hole to keep, in the UI's own units.
const CLEAR := 6.0
## How often to look for the hole moving, in seconds.
const CHECK_EVERY := 0.5

## Holes to pretend there are, in screen pixels, for trying it out on a
## computer or in the tests. With none, it asks the phone.
static var pretend: Array[Rect2] = []

var _watched: Array[Control] = []
## Margin containers that widen their margin on the side a hole's on, and
## their margins as they were set, [left, top, right, bottom].
var _pads := {}
## The panels that wrap around a hole partway down instead of getting shorter.
var _wraps := {}
## The boxes that leave a gap for the hole, and which child to start from.
var _flows: Array[BoxContainer] = []
var _flow_from := {}
var _gaps := {}
var _fitting := false
var _again := false
## Each control's offsets as they were set, [left, top, right, bottom].
var _placed := {}
var _last_holes: Array[Rect2] = []
var _last_size := Vector2.ZERO
var _last_sizes := []
var _wait := 0.0


func _ready() -> void:
	name = "SafeArea"
	var fake := OS.get_environment("SNAPRACERS_CUTOUT")
	if fake != "" and pretend.is_empty():
		var n := fake.split_floats(",")
		if n.size() == 4:
			pretend.append(Rect2(n[0], n[1], n[2], n[3]))


## Keeps this control clear of any hole, from where it is now. A tall panel
## that `wraps` leaves a hole partway down to the boxes given to flow().
func watch(control: Control, wraps := false) -> void:
	_watched.append(control)
	if wraps:
		_wraps[control] = true
	_placed[control] = [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]
	_wait = 0.0


## A watched control has been moved on purpose, so it's kept clear of a hole
## from where it is now.
func moved(control: Control) -> void:
	if not _placed.has(control):
		return
	_placed[control] = [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]
	_wait = 0.0


## Makes this margin container widen its margin on the side a hole's on,
## so everything in it stays clear. Next to a hole in a corner the top or
## bottom margin grows, and next to one partway down a side that side's does.
func pad(margin: MarginContainer) -> void:
	var sides := []
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		sides.append(margin.get_theme_constant(side))
	_pads[margin] = sides
	_wait = 0.0


## Makes this box leave a gap where a hole is, before the first of its
## children (from `from` on) that would be under it.
func flow(box: BoxContainer, from := 0) -> void:
	_flows.append(box)
	_flow_from[box] = from
	_wait = 0.0


## The screen's size in pixels, which is what the holes are measured in.
## Headless there's no window, so it's the view's own size there.
static func screen_size(viewport: Viewport) -> Vector2:
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		window = viewport.get_visible_rect().size
	return window


## The holes, in the UI's own units.
func holes() -> Array[Rect2]:
	return holes_in(get_viewport())


## The holes in this viewport's own units. A split screen half is a viewport
## of its own, maybe turned around, so the holes are carried into it through
## the container it's shown in.
static func holes_in(viewport: Viewport) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if viewport == null:
		return out
	var holder := viewport.get_parent() as SubViewportContainer
	if holder != null:
		var into := holder.get_global_transform_with_canvas().affine_inverse()
		for hole in holes_in(holder.get_viewport()):
			var inside := into * hole
			if inside.intersects(Rect2(Vector2.ZERO, holder.size)):
				out.append(inside)
		return out
	var shown := viewport.get_visible_rect()
	var window := screen_size(viewport)
	var scale := shown.size / window
	var rects: Array = pretend if not pretend.is_empty() else DisplayServer.get_display_cutouts()
	for r in rects:
		var hole := Rect2(r)
		if hole.size.x > 0.0 and hole.size.y > 0.0:
			out.append(Rect2(shown.position + hole.position * scale, hole.size * scale))
	return out


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_EVERY
	var now := holes()
	var size := get_viewport().get_visible_rect().size
	# A control that's grown (a chip with a longer name, say) might reach a
	# hole it cleared before, so check again then too.
	var sizes := _watched.map(func(c: Control) -> Vector2: return c.size if is_instance_valid(c) else Vector2.ZERO)
	if now == _last_holes and size == _last_size and sizes == _last_sizes:
		return
	_last_sizes = sizes
	_last_holes = now
	_last_size = size
	refit()


## Puts every watched control back where it was set, then moves any that
## are under a hole and opens gaps in the boxes that flow. It waits a frame
## between steps for the layout to catch up, so it's done a few frames later.
func refit() -> void:
	if _fitting:
		_again = true
		return
	_fitting = true
	_again = true
	while _again and is_inside_tree():
		_again = false
		for box in _gaps:
			if is_instance_valid(_gaps[box]):
				_gaps[box].custom_minimum_size = Vector2.ZERO
		for margin in _pads:
			if is_instance_valid(margin):
				var sides: Array = _pads[margin]
				for i in 4:
					margin.add_theme_constant_override(["margin_left", "margin_top", "margin_right", "margin_bottom"][i], sides[i])
		for control in _watched:
			if is_instance_valid(control):
				var at: Array = _placed[control]
				control.offset_left = at[0]
				control.offset_top = at[1]
				control.offset_right = at[2]
				control.offset_bottom = at[3]
		await get_tree().process_frame
		var now := holes()
		var screen := get_viewport().get_visible_rect()
		for control in _watched:
			if is_instance_valid(control):
				for hole in now:
					_step_aside(control, hole.grow(CLEAR), screen)
		for margin in _pads:
			if is_instance_valid(margin):
				for hole in now:
					_widen(margin, hole.grow(CLEAR))
		for box in _flows:
			await get_tree().process_frame
			if is_instance_valid(box):
				for hole in now:
					_make_room(box, hole.grow(CLEAR))
	_fitting = false


## Widens a margin to clear a hole.
func _widen(margin: MarginContainer, hole: Rect2) -> void:
	var rect := margin.get_global_rect()
	if not rect.intersects(hole):
		return
	var corner := hole.end.y < rect.position.y + rect.size.y * 0.35 or hole.position.y > rect.end.y - rect.size.y * 0.35
	var side: String
	var need: float
	if corner:
		var at_top := hole.get_center().y < rect.get_center().y
		side = "margin_top" if at_top else "margin_bottom"
		need = hole.end.y - rect.position.y if at_top else rect.end.y - hole.position.y
	else:
		var at_left := hole.get_center().x < rect.get_center().x
		side = "margin_left" if at_left else "margin_right"
		need = hole.end.x - rect.position.x if at_left else rect.end.x - hole.position.x
	margin.add_theme_constant_override(side, maxi(margin.get_theme_constant(side), ceili(need)))


## Opens a gap in a box where the hole is.
func _make_room(box: BoxContainer, hole: Rect2) -> void:
	if not box.is_visible_in_tree():
		return
	var vertical := box is VBoxContainer
	var from: int = _flow_from[box]
	for child in box.get_children():
		if child == _gaps.get(box) or not child is Control or not child.visible or child.get_index() < from:
			continue
		var rect: Rect2 = child.get_global_rect()
		if not rect.intersects(hole):
			continue
		var gap: Control = _gaps.get(box)
		if gap == null or not is_instance_valid(gap):
			gap = Control.new()
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(gap)
			_gaps[box] = gap
		box.move_child(gap, child.get_index())
		# The gap takes up the room the child would have had under the hole,
		# less the space the box already puts between them.
		var between := float(box.get_theme_constant("separation"))
		if vertical:
			gap.custom_minimum_size = Vector2(0.0, maxf(hole.end.y - rect.position.y - between, 0.0))
		else:
			gap.custom_minimum_size = Vector2(maxf(hole.end.x - rect.position.x - between, 0.0), 0.0)
		return


func _step_aside(control: Control, hole: Rect2, screen: Rect2) -> void:
	var rect := control.get_global_rect()
	if not rect.intersects(hole):
		return
	# A panel down the whole side (the drawer) gets shorter at the hole's end,
	# unless the hole's partway down and the panel wraps around it instead.
	if rect.size.y > screen.size.y * 0.6 and rect.size.x < screen.size.x * 0.6:
		var near_top := hole.end.y < rect.position.y + rect.size.y * 0.35
		var near_bottom := hole.position.y > rect.end.y - rect.size.y * 0.35
		if near_top:
			control.offset_top += hole.end.y - rect.position.y
		elif near_bottom:
			control.offset_bottom -= rect.end.y - hole.position.y
		elif not _wraps.has(control):
			control.offset_left += hole.end.x - rect.position.x
		return
	# One along the whole top or bottom gets narrower at the hole's end.
	if rect.size.x > screen.size.x * 0.6 and rect.size.y < screen.size.y * 0.6:
		if hole.get_center().x < rect.get_center().x:
			control.offset_left += hole.end.x - rect.position.x
		else:
			control.offset_right -= rect.end.x - hole.position.x
		return
	# Anything else slides the shortest way clear that stays on the screen.
	var moves := [
		Vector2(hole.position.x - rect.end.x, 0.0),
		Vector2(hole.end.x - rect.position.x, 0.0),
		Vector2(0.0, hole.position.y - rect.end.y),
		Vector2(0.0, hole.end.y - rect.position.y),
	]
	var best := Vector2.ZERO
	for move in moves:
		var moved := Rect2(rect.position + move, rect.size)
		if not screen.encloses(moved):
			continue
		if best == Vector2.ZERO or move.length() < best.length():
			best = move
	control.offset_left += best.x
	control.offset_right += best.x
	control.offset_top += best.y
	control.offset_bottom += best.y
