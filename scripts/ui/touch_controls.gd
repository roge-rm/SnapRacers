class_name TouchControls
extends Control

## On-screen controls for a phone or tablet, with two ways to steer (see
## STEERING) picked in Settings.
##
## The steering stick sits on the left, two fifths of the way up the screen
## where your thumb holds the phone (a quarter in a split screen half, see
## HEIGHT). Put your thumb anywhere on it and the knob goes where your thumb
## is, and it springs back to the middle when you let go. On the right at the
## same height is a big GO button with the brake right under it, the gadget
## buttons up and to the left, a look back button up and to the right that
## you hold, and a small reset button up top. You can slide a finger from GO
## down to the brake without lifting it, which keeps the gas on too and slides
## the kart around a corner, up onto a gadget, which uses it and keeps GO
## held, or up onto look back, which looks behind you with the gas still on.
##
## Instead of the stick there can be a left and a right button that steer all
## the way while you hold them, and you can slide your thumb from one to the
## other.

## They all keep clear of a camera hole. They move in groups (the steering,
## the pedals with the gadgets and look back, and reset), each group sliding
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
## How high they can be set in Settings, from the bottom (the brake still
## stays on the screen, see _placed_buttons()) to three fifths up. A split
## screen half scales HEIGHT_SPLIT the same way.
const HEIGHT_LOWEST := 0.15
const HEIGHT_HIGHEST := 0.6
## How big they are, picked in Settings, against the biggest they get on a
## big screen (GO_MOST_CM).
const SIZES := {"small": "Small", "medium": "Medium", "large": "Large"}
const SIZE_SCALES := {"small": 0.8, "medium": 1.0, "large": 1.25}
## The most GO's and the stick's radius are on a phone or tablet, in cm, so a
## tablet's aren't twice a phone's and far apart. A Pixel 5 has GO 0.83 cm
## and the stick 1.08 cm, and these are about 15% more.
const GO_MOST_CM := 0.95
const STICK_MOST_CM := 1.25
## Each button's colour. Reset and the steering buttons are grey.
const BUTTON_COLOURS := {
	"gas": UiKit.GO_GREEN, "brake": UiKit.BRAKE_RED, "look": UiKit.LOOK_BLUE,
	"gadget0": UiKit.GADGET_PURPLE, "gadget1": UiKit.GADGET_PURPLE,
}
## How far look back and the gadgets sit from the middle of GO, in GO's
## radius, which leaves a small gap between them.
const REACH := 1.9

## How far up this one's controls sit (see HEIGHT).
var height := HEIGHT:
	set(value):
		height = value
		queue_redraw()
## "small", "medium" or "large" (see SIZES).
var control_size := "medium":
	set(value):
		control_size = value if SIZES.has(value) else "medium"
		_word_sizes.clear()
		queue_redraw()
## Canvas units in a cm on the screen, or 0 for no cap by size. Below 0 it's
## worked out from the screen (see units_per_cm()); tests set it.
var per_cm := -1.0
## "stick" or "buttons" (see STEERING).
var steering := "stick":
	set(value):
		steering = value if STEERING.has(value) else "stick"
		_stick_finger = -1
		queue_redraw()
## Whether they hide while a keyboard or controller is being used. Only
## where there's a touch screen to bring them back with, and always on a
## computer, where they wait for a touch (see shown_at_start).
var stand_aside := DisplayServer.is_touchscreen_available() or OS.has_feature("pc")
var steer := 0.0
var throttle := 0.0
var brake := 0.0
var reset := false
var look_back := false

## Buttons drawn over the controls. A touch that starts on one of these is
## left alone for the button.
var blockers: Array[Control] = []

## What's on the gadget buttons above GO, set by the HUD with show_gadget().
## It's a name, or an empty string when there's no button there.
var gadget_names: Array[String] = ["", ""]
## Whether each power-up can be used right now.
var gadget_ready: Array[bool] = [false, false]
## Which power-up is on each gadget button, for its picture (see
## PowerupIcons), and how many goes it has left.
var gadget_kinds: Array[String] = ["", ""]
var gadget_uses: Array[int] = [0, 0]

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
## What the last _update() drew, so it only redraws when that changes.
var _drawn := []
## Sizes worked out for the words on the buttons, by text and radius.
var _word_sizes := {}
## Draws the pictures on gadgets that can't be used yet, faded as a whole.
var _faded: Control
## The screen's dots per inch, read once, or SNAPRACERS_DPI on a computer to
## try a tablet's size.
static var _dpi := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_faded = Control.new()
	_faded.mouse_filter = MOUSE_FILTER_IGNORE
	_faded.modulate = Color(1, 1, 1, 0.4)
	add_child(_faded)
	_faded.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_faded.draw.connect(_draw_faded)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_word_sizes.clear()
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()


## How high the controls sit for a height picked in Settings, on your own or
## in a split screen half.
static func height_for(picked: float, split: bool) -> float:
	picked = clampf(picked, HEIGHT_LOWEST, HEIGHT_HIGHEST)
	return picked * HEIGHT_SPLIT / HEIGHT if split else picked


## A radius from the screen-share one, `fraction_r`, capped at `most_cm` when
## there's a size to go by, then scaled by `scale`. Smaller than Medium it
## shrinks, bigger it grows past the share.
static func fit(fraction_r: float, most_cm: float, units: float, scale: float) -> float:
	var base := fraction_r if units <= 0.0 else minf(fraction_r, most_cm * units)
	return base * scale


## Canvas units in a cm on the screen, or 0 when it's not known. Only on a
## phone or tablet, since a computer's dpi is often made up.
func units_per_cm() -> float:
	if per_cm >= 0.0:
		return per_cm
	if not is_inside_tree():
		return 0.0
	return units_per_cm_in(get_tree().root)


## The same for any screen, from its window.
static func units_per_cm_in(root: Window) -> float:
	if _dpi < 0.0:
		_dpi = 0.0
		var fake := OS.get_environment("SNAPRACERS_DPI")
		if fake.is_valid_float():
			_dpi = fake.to_float()
		elif OS.has_feature("mobile"):
			_dpi = float(DisplayServer.screen_get_dpi())
		if _dpi < 100.0 or _dpi > 1000.0:
			_dpi = 0.0
	if _dpi <= 0.0 or root == null:
		return 0.0
	var shown := root.get_visible_rect().size.y
	if shown <= 0.0 or root.size.y <= 0:
		return 0.0
	# Window pixels per canvas unit, from the stretch.
	var stretch := float(root.size.y) / shown
	return _dpi / 2.54 / stretch


## Sets what's on a gadget button, redrawing only when it's changed.
func show_gadget(slot: int, gadget_name: String, kind: String, uses: int, ready: bool) -> void:
	if gadget_names[slot] == gadget_name and gadget_kinds[slot] == kind and gadget_uses[slot] == uses and gadget_ready[slot] == ready:
		return
	gadget_names[slot] = gadget_name
	gadget_kinds[slot] = kind
	gadget_uses[slot] = uses
	gadget_ready[slot] = ready
	queue_redraw()


## Where the controls are drawn, as boxes, with room for both gadgets whether
## or not there's anything on them, for the HUD to keep its pills clear of.
func areas() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if size.y <= 0.0:
		return out
	var circles := _buttons(true)
	if steering == "stick":
		circles["stick"] = _stick()
	for name in circles:
		var r: float = circles[name][1]
		out.append(Rect2(circles[name][0] - Vector2(r, r), Vector2(r, r) * 2.0))
	return out


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
	var stick := {"stick": _stick_circle(_scale())}
	_clear_of_holes(stick, ["stick"])
	return stick.stick


## In a split screen half it shrinks to fit next to the buttons.
func _stick_circle(scale: float) -> Array:
	var r := fit(minf(minf(size.y * 0.17, size.x * 0.16), 125.0), STICK_MOST_CM, units_per_cm(), scale)
	return [Vector2(r * 1.35, _middle(r)), r]


## The size scale in use. Large grows as far as everything still fits on the
## screen without touching, so it can come out smaller than its usual scale.
func _scale() -> float:
	var wanted: float = SIZE_SCALES[control_size]
	if wanted <= 1.0:
		return wanted
	var key := [size, height, wanted, steering, gadget_names, per_cm]
	if key != _scale_key:
		_scale_key = key
		_scale_found = 1.0
		var scale := wanted
		while scale > 1.0:
			var circles := _placed_buttons(true, scale)
			if steering == "stick":
				circles["stick"] = _stick_circle(scale)
			if _overlaps(circles).is_empty():
				_scale_found = scale
				break
			scale -= 0.01
	return _scale_found


var _scale_key := []
var _scale_found := 1.0


## The names of circles that run off the screen or sit on each other.
func _overlaps(circles: Dictionary) -> Array:
	var out := []
	for a in circles:
		var c: Vector2 = circles[a][0]
		var r: float = circles[a][1]
		if c.x - r < -0.5 or c.y - r < -0.5 or c.x + r > size.x + 0.5 or c.y + r > size.y + 0.5:
			out.append(a)
		for b in circles:
			if str(a) < str(b) and c.distance_to(circles[b][0]) < r + circles[b][1] - 0.5:
				out.append(a)
	return out


## Every button's middle and radius. With `all_gadgets` both gadget buttons
## are there even when there's nothing on them.
func _buttons(all_gadgets := false) -> Dictionary:
	var out := _placed_buttons(all_gadgets)
	_clear_of_holes(out, ["left", "right"])
	_clear_of_holes(out, ["gas", "brake", "gadget0", "gadget1", "look"])
	_clear_of_holes(out, ["reset"])
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


func _placed_buttons(all_gadgets := false, scale := -1.0) -> Dictionary:
	if scale < 0.0:
		scale = _scale()
	var s := size
	# These shrink in a narrow split screen half too, so the brake stays clear
	# of the stick.
	var units := units_per_cm()
	var r := fit(minf(minf(s.y * 0.13, s.x * 0.1), 110.0), GO_MOST_CM, units, scale)
	# GO, with the brake right under it, both kept on the screen.
	var drop := r * 1.95
	var y := minf(_middle(r), s.y - drop - r * 0.75 - r * 0.2)
	var gas := Vector2(s.x - r * 1.5, y)
	# Look back and the gadgets sit close around the top of GO, all the same
	# reach away, so a thumb can slide onto any of them and back without
	# letting go: look back up and to the right, the gadgets up and to the
	# left.
	var around := func(degrees: float) -> Vector2: return gas + Vector2.from_angle(deg_to_rad(degrees)) * r * REACH
	var out := {
		"gas": [gas, r],
		"brake": [Vector2(gas.x, y + drop), r * 0.75],
		"reset": [Vector2(s.x - r * 0.9, r * 0.9), r * 0.5],
		"look": [around.call(-67.0), r * 0.55],
	}
	if steering == "buttons":
		# The left and right buttons sit where the stick would be, big enough
		# to find without looking.
		var arrow := fit(minf(minf(s.y * 0.13, s.x * 0.1), 105.0), GO_MOST_CM, units, scale)
		var ay := _middle(arrow * 1.3)
		out["left"] = [Vector2(arrow * 1.3, ay), arrow]
		out["right"] = [Vector2(arrow * 3.75, ay), arrow]
	var small := r * 0.62
	if gadget_names[0] != "" or all_gadgets:
		out["gadget0"] = [around.call(-112.0), small]
	if gadget_names[1] != "" or all_gadgets:
		out["gadget1"] = [around.call(-157.0), small]
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


## Whether they're up at the start of a race. On a phone or tablet they
## are. On a computer, the Steam Deck too, they stay hidden until the screen's
## touched.
static func shown_at_start() -> bool:
	return DisplayServer.is_touchscreen_available() and not OS.has_feature("pc")


func _input(event: InputEvent) -> void:
	# On something with a touch screen and a keyboard or controller too (a
	# laptop, or a phone with a controller), they step aside while you use
	# the keys or the controller, a stick or trigger pushed too, and come back
	# when you touch the screen. On a computer a click, which comes as a touch
	# as well (emulate_touch_from_mouse), doesn't bring them back. In split
	# screen only this player's controller reaches here (see Race.SplitHalf).
	if stand_aside:
		var pc := OS.has_feature("pc")
		var pushed := event is InputEventJoypadMotion and absf(event.axis_value) > 0.5 and not Controllers.ignored.has(event.device)
		if ((event is InputEventKey or event is InputEventJoypadButton) and event.pressed or pushed) and visible:
			visible = false
			_fingers.clear()
			_stick_finger = -1
			_update()
		elif event is InputEventScreenTouch and not visible and not (pc and event.device == InputEvent.DEVICE_ID_EMULATION):
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
			if was in ["gas", "gas_look"] and name.begins_with("gadget"):
				if _slid_onto.get(event.index, "") != name:
					_slid_onto[event.index] = name
					_gadget_tapped[int(name.substr(6))] = true
			elif name != _slid_onto.get(event.index, ""):
				_slid_onto.erase(event.index)
			# A thumb can slide onto GO or brake, and between left and right.
			# Sliding from GO onto brake keeps the gas on as well, which puts
			# the kart into a slide (see Kart.sliding), and back onto GO goes
			# back to plain gas.
			if name == "brake" and was in ["gas", "slide", "gas_look"]:
				_fingers[event.index] = "slide"
			# Sliding from GO onto look back looks behind with the gas still
			# on, until the thumb slides back onto GO or lets go.
			elif name == "look" and was in ["gas", "gas_look"]:
				_fingers[event.index] = "gas_look"
			elif name == "gas" or name == "brake":
				_fingers[event.index] = name
			elif was == "gas_look" and name == "":
				# Between look back and GO it's still GO.
				_fingers[event.index] = "gas"
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
	if held.has("slide"):
		held.append_array(["gas", "brake"])
	if held.has("gas_look"):
		held.append_array(["gas", "look"])
	if steering == "buttons":
		steer = buttons_to_steer(held.has("left"), held.has("right"))
	else:
		steer = stick_to_steer(_knob)
	throttle = 1.0 if held.has("gas") else 0.0
	brake = 1.0 if held.has("brake") else 0.0
	reset = held.has("reset")
	look_back = held.has("look")
	var drawn := [_knob, _stick_finger != -1, held]
	if drawn != _drawn:
		_drawn = drawn
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
	_faded.queue_redraw()
	if size.y <= 0.0:
		return # not laid out yet
	var buttons := _buttons()
	var held := _fingers.values()
	if held.has("slide"):
		held.append_array(["gas", "brake"])
	if held.has("gas_look"):
		held.append_array(["gas", "look"])
	var font := UiKit.font("title")
	for name in buttons:
		var centre: Vector2 = buttons[name][0]
		var radius: float = buttons[name][1]
		var lit: bool = held.has(name)
		var colour: Color = BUTTON_COLOURS.get(name, UiKit.BUTTON_GREY)
		var ready := true
		if name.begins_with("gadget"):
			ready = gadget_ready[int(name.substr(6))]
		_round_button(centre, radius, colour if ready else UiKit.BUTTON_GREY, lit, ready, name.begins_with("gadget"))
		var ink := Color(UiKit.WHITE, 1.0 if ready else 0.5)
		match name:
			"gas", "brake":
				_words(font, centre, "GO" if name == "gas" else "BRAKE", radius, colour.darkened(0.5))
			"look", "reset":
				UiKit.draw_icon(self, name, centre, radius * 1.05, ink, 3.2)
			"left", "right":
				# An arrow pointing the way it steers.
				var way := -1.0 if name == "left" else 1.0
				var tip := centre + Vector2(radius * 0.45 * way, 0.0)
				var back := centre - Vector2(radius * 0.3 * way, 0.0)
				var arrow := PackedVector2Array([tip, back + Vector2(0.0, -radius * 0.45), back + Vector2(0.0, radius * 0.45)])
				draw_colored_polygon(arrow, UiKit.YELLOW if lit else UiKit.WHITE)
				arrow.append(tip)
				draw_polyline(arrow, Color(UiKit.INK, 0.6), 2.0, true)
			_:
				var slot := int(name.substr(6))
				if gadget_kinds[slot] != "":
					# One that can't be used yet is drawn faded by _draw_faded().
					if ready:
						_gadget_picture(self, slot, centre, radius)
				else:
					_words(font, centre, gadget_names[slot], radius * 0.6, colour.darkened(0.5))
	if steering == "buttons":
		return
	# The stick is a faint round pad with a white rim, marks either side for
	# how far it goes, and the knob, which lights up yellow while you're
	# holding it.
	var stick := _stick()
	var middle: Vector2 = stick[0]
	var r: float = stick[1]
	var travel := r * 0.68
	draw_circle(middle, r, Color(UiKit.WHITE, 0.16))
	draw_arc(middle, r - 2.0, 0.0, TAU, 64, Color(UiKit.WHITE, 0.5), 3.0, true)
	for x in [-0.6, -0.4, 0.4, 0.6]:
		draw_line(middle + Vector2(r * x, -8.0), middle + Vector2(r * x, 8.0), Color(UiKit.WHITE, 0.35), 3.0)
	var holding := _stick_finger != -1
	var knob := middle + Vector2(_knob * travel, 0.0)
	draw_circle(knob, r * 0.3, Color(UiKit.YELLOW, 0.9) if holding else Color(UiKit.WHITE, 0.5))
	draw_arc(knob, r * 0.3, 0.0, TAU, 40, Color(UiKit.INK, 0.5), 2.0, true)


## The pictures on gadgets that can't be used yet, drawn on _faded so each
## fades as a whole.
func _draw_faded() -> void:
	if size.y <= 0.0:
		return
	var buttons := _buttons()
	for slot in gadget_kinds.size():
		var name := "gadget%d" % slot
		if buttons.has(name) and gadget_kinds[slot] != "" and not gadget_ready[slot]:
			_gadget_picture(_faded, slot, buttons[name][0], buttons[name][1])


## A gadget's power-up picture, with how many goes are left when there's more
## than one.
func _gadget_picture(item: CanvasItem, slot: int, centre: Vector2, radius: float) -> void:
	PowerupIcons.draw(item, gadget_kinds[slot], centre, radius * 1.15)
	if gadget_uses[slot] > 1:
		var count := "x%d" % gadget_uses[slot]
		var digits := UiKit.font("digits")
		var at := centre + Vector2(radius * 0.25, radius * 0.75)
		item.draw_string_outline(digits, at, count, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.BADGE, 5, UiKit.BADGE_OUTLINE)
		item.draw_string(digits, at, count, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.BADGE, UiKit.YELLOW)


## A see-through round button in its colour with a light rim, so the road
## shows through it, stronger while it's held and fainter when it can't be
## used.
func _round_button(centre: Vector2, radius: float, colour: Color, lit: bool, ready: bool, gadget: bool) -> void:
	var alpha := 0.28
	if lit:
		alpha = 0.55
	elif gadget:
		alpha = 0.45 if ready else 0.12
	var face := colour.lightened(0.2) if lit else colour
	draw_circle(centre, radius, Color(face, alpha))
	var rim := UiKit.WHITE if lit else colour.lightened(0.5)
	draw_arc(centre, radius - 1.5, 0.0, TAU, 48, Color(rim, 0.8 if ready else 0.3), 3.0, true)


## Upright white words in the middle of a button, as big as fit across it.
func _words(font: Font, centre: Vector2, text: String, radius: float, edge: Color) -> void:
	if text == "":
		return
	var key := "%s|%s" % [text, radius]
	if not _word_sizes.has(key):
		var font_size := int(radius * 0.55)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if wide > radius * 1.5:
			font_size = int(font_size * radius * 1.5 / wide)
			wide = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_word_sizes[key] = [font_size, Vector2(-wide * 0.5, font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.35)]
	var font_size: int = _word_sizes[key][0]
	var at: Vector2 = centre + _word_sizes[key][1]
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(4, font_size / 7), edge)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiKit.WHITE)
