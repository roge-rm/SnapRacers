class_name TouchControls
extends Control

## On-screen controls for a phone or tablet, with two ways to steer (see
## STEERING) picked in Settings.
##
## The steering stick sits on the left, two fifths of the way up the screen
## where your thumb holds the phone (a quarter in a split screen half, see
## HEIGHT). Put your thumb anywhere on it and the knob goes where your thumb
## is, and it springs back to the middle when you let go. On the right at the
## same height is a big GO button with the brake right under it and the gadget
## buttons up and to the left, and a small reset button up top with a look back
## button under it that you hold. You can slide a finger from GO down to the
## brake without lifting it, or up onto a gadget, which uses it and keeps GO
## held.
##
## Instead of the stick there can be a left and a right button that steer all
## the way while you hold them, and you can slide your thumb from one to the
## other.

## They all keep clear of a camera hole. They move in groups (the steering,
## the pedals and gadgets, and reset with look back), each group sliding
## together by as little as clears the hole, so nothing ends up on top of
## anything else.

## The ways to steer, and what Settings calls them.
const STEERING := {"stick": "Stick", "buttons": "Buttons"}

## How much of the stick's travel is a small steer. I made the middle gentle
## so small corrections are easy, and it still reaches full lock at the edge.
const STICK_CURVE := 0.6
## A thumb resting near the middle doesn't steer at all.
const STICK_DEADZONE := 0.06

## How far up the screen the stick and GO sit, as a fraction of its height
## from the bottom: two fifths of the way on your own, and a quarter of the way
## up in each half of a split screen.
const HEIGHT := 0.4
const HEIGHT_SPLIT := 0.25

## How far up this one's controls sit (see HEIGHT).
var height := HEIGHT
## "stick" or "buttons" (see STEERING).
var steering := "stick":
	set(value):
		steering = value if STEERING.has(value) else "stick"
		_stick_finger = -1
		queue_redraw()
## Whether they hide while a keyboard or controller is being used. Only
## where there's a touch screen to bring them back with.
var stand_aside := DisplayServer.is_touchscreen_available()
var steer := 0.0
var throttle := 0.0
var brake := 0.0
var reset := false
var look_back := false

## Buttons drawn over the controls. A touch that starts on one of these is
## left alone for the button.
var blockers: Array[Control] = []

## What's on the gadget buttons above GO, set by the HUD. It's a name, or an
## empty string when there's no button there.
var gadget_names: Array[String] = ["", ""]
## Whether each gadget can be used right now (enough studs).
var gadget_ready: Array[bool] = [false, false]

var _reset_tapped := false
var _gadget_tapped: Array[bool] = [false, false]
var _stick_finger := -1
## Where the knob is, from -1 (full left) to 1 (full right).
var _knob := 0.0
var _fingers := {} # finger index -> button name
## Any camera holes, in this view's own units, checked now and then.
var _holes: Array[Rect2] = []
var _hole_check := 0.0
var _finger_at := {} # finger index -> position
## The gadget a finger holding GO has slid onto, so it's only used once each
## time the finger gets there.
var _slid_onto := {} # finger index -> gadget button name


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(delta: float) -> void:
	_hole_check -= delta
	if _hole_check > 0.0:
		return
	_hole_check = SafeArea.CHECK_EVERY
	var now := SafeArea.holes_in(get_viewport())
	if now != _holes:
		_holes = now
		queue_redraw()


## The stick's middle and radius, in the corner where your left thumb rests.
func _stick() -> Array:
	# In a split screen half it shrinks to fit next to the buttons.
	var r := minf(minf(size.y * 0.17, size.x * 0.16), 125.0)
	var stick := {"stick": [Vector2(r * 1.35, _middle(r)), r]}
	_clear_of_holes(stick, ["stick"])
	return stick.stick


func _buttons() -> Dictionary:
	var out := _placed_buttons()
	_clear_of_holes(out, ["left", "right"])
	_clear_of_holes(out, ["gas", "brake", "gadget0", "gadget1"])
	_clear_of_holes(out, ["reset", "look"])
	return out


## Slides this group of circles together by the least that clears every
## hole and keeps them all on the screen.
func _clear_of_holes(circles: Dictionary, group: Array) -> void:
	if _holes.is_empty():
		return
	var names := group.filter(func(n): return circles.has(n))
	var tries := [Vector2.ZERO]
	for n in names:
		var c: Vector2 = circles[n][0]
		var r: float = circles[n][1]
		for h in _holes:
			var hole := h.grow(SafeArea.CLEAR)
			tries.append(Vector2(hole.end.x + r - c.x, 0.0))
			tries.append(Vector2(hole.position.x - r - c.x, 0.0))
			tries.append(Vector2(0.0, hole.end.y + r - c.y))
			tries.append(Vector2(0.0, hole.position.y - r - c.y))
	tries.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length() < b.length())
	for move in tries:
		var fits := true
		for n in names:
			var c: Vector2 = circles[n][0] + move
			var r: float = circles[n][1]
			if c.x - r < 0.0 or c.x + r > size.x or c.y - r < 0.0 or c.y + r > size.y:
				fits = false
			for h in _holes:
				if c.distance_to(c.clamp(h.position, h.end)) < r:
					fits = false
		if fits:
			for n in names:
				circles[n][0] += move
			return


func _placed_buttons() -> Dictionary:
	var s := size
	# These shrink in a narrow split screen half too, so the brake stays clear
	# of the stick.
	var r := minf(minf(s.y * 0.13, s.x * 0.1), 110.0)
	# GO, with the brake right under it, both kept on the screen.
	var drop := r * 1.95
	var y := minf(_middle(r), s.y - drop - r * 0.75 - r * 0.2)
	var out := {
		"gas": [Vector2(s.x - r * 1.5, y), r],
		"brake": [Vector2(s.x - r * 1.5, y + drop), r * 0.75],
		"reset": [Vector2(s.x - r * 0.9, r * 0.9), r * 0.5],
		"look": [Vector2(s.x - r * 0.9, r * 2.2), r * 0.5],
	}
	if steering == "buttons":
		# The left and right buttons sit where the stick would be, big enough
		# to find without looking.
		var arrow := minf(minf(s.y * 0.13, s.x * 0.1), 105.0)
		var ay := _middle(arrow * 1.3)
		out["left"] = [Vector2(arrow * 1.3, ay), arrow]
		out["right"] = [Vector2(arrow * 3.75, ay), arrow]
	# The gadgets go up and to the left of GO, where your thumb can slide
	# onto them without letting go of it.
	var small := r * 0.62
	if gadget_names[0] != "":
		out["gadget0"] = [Vector2(s.x - r * 2.25, y - r * 1.9), small]
	if gadget_names[1] != "":
		out["gadget1"] = [Vector2(s.x - r * 3.9, y - r * 1.2), small]
	return out


## How far down the screen the middle of the controls goes, for one this big.
## It's HEIGHT of the way up, but never so low it runs off the bottom.
func _middle(radius: float) -> float:
	return minf(size.y * (1.0 - height), size.y - radius)


func _button_at(pos: Vector2) -> String:
	var buttons := _buttons()
	for name in buttons:
		# A little extra room around each button so thumbs don't miss.
		if pos.distance_to(buttons[name][0]) <= buttons[name][1] * 1.25:
			return name
	return ""


func _input(event: InputEvent) -> void:
	# On something with a touch screen and a keyboard or controller too (a
	# laptop, or a phone with a controller), they step aside while you use
	# the keys or the controller, and come back when you touch the screen.
	if stand_aside:
		if (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and visible:
			visible = false
			_fingers.clear()
			_stick_finger = -1
			_update()
		elif event is InputEventScreenTouch and not visible:
			visible = true
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for blocker in blockers:
				if blocker.is_visible_in_tree() and blocker.get_global_rect().has_point(event.position):
					return
			var name := _button_at(event.position)
			if name == "reset":
				_reset_tapped = true
			elif name.begins_with("gadget"):
				_gadget_tapped[int(name.substr(6))] = true
			var stick := _stick()
			if name != "":
				_fingers[event.index] = name
				_finger_at[event.index] = event.position
			elif steering == "stick" and _stick_finger == -1 and event.position.distance_to(stick[0]) <= stick[1] * 1.5:
				# The whole stick is the target, plus some room around it, so
				# you never have to chase the knob with your thumb.
				_stick_finger = event.index
				_move_knob(event.position)
		else:
			_fingers.erase(event.index)
			_finger_at.erase(event.index)
			_slid_onto.erase(event.index)
			if event.index == _stick_finger:
				_stick_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_move_knob(event.position)
		elif _fingers.has(event.index):
			_finger_at[event.index] = event.position
			var name := _button_at(event.position)
			var was: String = _fingers[event.index]
			# Sliding from GO onto a gadget uses it, and GO stays held.
			if was == "gas" and name.begins_with("gadget"):
				if _slid_onto.get(event.index, "") != name:
					_slid_onto[event.index] = name
					_gadget_tapped[int(name.substr(6))] = true
			elif name != _slid_onto.get(event.index, ""):
				_slid_onto.erase(event.index)
			# A thumb can slide onto GO or brake, and between left and right.
			if name == "gas" or name == "brake":
				_fingers[event.index] = name
			elif (name == "left" or name == "right") and was in ["left", "right"]:
				_fingers[event.index] = name
	_update()


## Puts the knob under your thumb, as far across as it can go.
func _move_knob(at: Vector2) -> void:
	var stick := _stick()
	var travel: float = stick[1] * 0.68
	_knob = clampf((at.x - stick[0].x) / travel, -1.0, 1.0)


## True once for every tap on reset, however short. A quick tap can start and
## end between two physics steps, and then `reset` alone would never be seen.
func take_reset_tap() -> bool:
	var tapped := _reset_tapped
	_reset_tapped = false
	return tapped


## True once for every tap on a gadget button, like take_reset_tap().
func take_gadget_tap(slot: int) -> bool:
	var tapped := _gadget_tapped[slot]
	_gadget_tapped[slot] = false
	return tapped


func _update() -> void:
	if _stick_finger == -1:
		_knob = 0.0
	var held := _fingers.values()
	if steering == "buttons":
		steer = buttons_to_steer(held.has("left"), held.has("right"))
	else:
		steer = stick_to_steer(_knob)
	throttle = 1.0 if held.has("gas") else 0.0
	brake = 1.0 if held.has("brake") else 0.0
	reset = held.has("reset")
	look_back = held.has("look")
	queue_redraw()


## How much to steer with the buttons held. Both at once cancel out.
static func buttons_to_steer(left: bool, right: bool) -> float:
	return (1.0 if right else 0.0) - (1.0 if left else 0.0)


## How much to steer for the knob this far across. It's gentle in the middle
## and still gets to full lock at the edge.
static func stick_to_steer(knob: float) -> float:
	var amount := absf(knob)
	if amount < STICK_DEADZONE:
		return 0.0
	amount = inverse_lerp(STICK_DEADZONE, 1.0, amount)
	return signf(knob) * amount * lerpf(1.0 - STICK_CURVE, 1.0, amount)


func _draw() -> void:
	if size.y <= 0.0:
		return # not laid out yet
	var buttons := _buttons()
	var held := _fingers.values()
	var labels := { "gas": "GO", "brake": "BRAKE", "reset": "RESET", "look": "LOOK\nBACK", "gadget0": gadget_names[0], "gadget1": gadget_names[1], "left": "", "right": "" }
	var font := get_theme_default_font()
	for name in buttons:
		var centre: Vector2 = buttons[name][0]
		var radius: float = buttons[name][1]
		var alpha := 0.55 if held.has(name) else 0.28
		var ring := Color(1, 1, 1, 0.8)
		if name.begins_with("gadget"):
			# Gold when it can be used, faded when it can't.
			var ready: bool = gadget_ready[int(name.substr(6))]
			alpha = 0.45 if ready else 0.12
			ring = Color("#f2cd37") if ready else Color(1, 1, 1, 0.3)
		draw_circle(centre, radius, Color(1, 1, 1, alpha))
		draw_arc(centre, radius, 0.0, TAU, 48, ring, 3.0, true)
		var font_size := int(radius * (0.3 if name.begins_with("gadget") or name == "look" else 0.4))
		var text: String = labels[name]
		var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var top_left := centre - text_size * 0.5 + Vector2(0.0, font_size * 0.8)
		draw_multiline_string(font, top_left, text, HORIZONTAL_ALIGNMENT_CENTER, text_size.x, font_size, -1, Color(0, 0, 0, 0.75))
		if name == "left" or name == "right":
			# An arrow pointing the way it steers.
			var way := -1.0 if name == "left" else 1.0
			var tip := centre + Vector2(radius * 0.45 * way, 0.0)
			var back := centre - Vector2(radius * 0.3 * way, 0.0)
			var arrow_colour := Color(MenuStyle.ACCENT, 0.95) if held.has(name) else Color(0, 0, 0, 0.6)
			draw_colored_polygon(PackedVector2Array([tip, back + Vector2(0.0, -radius * 0.45), back + Vector2(0.0, radius * 0.45)]), arrow_colour)
	if steering == "buttons":
		return
	# The stick is a faint round pad with a groove across it, a dot in the
	# middle so you can find it, and the knob, which lights up while you're
	# holding it.
	var stick := _stick()
	var middle: Vector2 = stick[0]
	var r: float = stick[1]
	var travel := r * 0.68
	draw_circle(middle, r, Color(1, 1, 1, 0.16))
	draw_arc(middle, r, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 3.0, true)
	draw_line(middle - Vector2(travel, 0.0), middle + Vector2(travel, 0.0), Color(1, 1, 1, 0.3), 6.0, true)
	draw_circle(middle, r * 0.07, Color(1, 1, 1, 0.45))
	var holding := _stick_finger != -1
	var knob_colour := Color(MenuStyle.ACCENT, 0.9) if holding else Color(1, 1, 1, 0.5)
	draw_circle(middle + Vector2(_knob * travel, 0.0), r * 0.3, knob_colour)
