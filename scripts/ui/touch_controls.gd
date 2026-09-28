class_name TouchControls
extends Control

## On-screen controls for a phone or tablet. The steering stick sits in the
## bottom left corner and never moves. Put your thumb anywhere on it and the
## knob goes where your thumb is, so you can see how far you're steering. It
## springs back to the middle when you let go. On the right there's a big GO
## button with the brake beside it, the gadget buttons above them, and a
## small reset button up top. You can slide a finger from GO to brake without
## lifting it.

## How much of the stick's travel is a small steer. I made the middle gentle
## so small corrections are easy, and it still reaches full lock at the edge.
const STICK_CURVE := 0.6
## A thumb resting near the middle doesn't steer at all.
const STICK_DEADZONE := 0.06

var steer := 0.0
var throttle := 0.0
var brake := 0.0
var reset := false

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
var _finger_at := {} # finger index -> position


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## The stick's middle and radius. It's the same size as Apogee's, and it
## sits in the corner where your left thumb rests.
func _stick() -> Array:
	# In a split screen half it shrinks to fit next to the buttons.
	var r := minf(minf(size.y * 0.17, size.x * 0.16), 125.0)
	return [Vector2(r * 1.35, size.y - r * 1.35), r]


func _buttons() -> Dictionary:
	var s := size
	# These shrink in a narrow split screen half too, so the brake stays clear
	# of the stick.
	var r := minf(minf(s.y * 0.13, s.x * 0.1), 110.0)
	var out := {
		"gas": [Vector2(s.x - r * 1.5, s.y - r * 1.5), r],
		"brake": [Vector2(s.x - r * 3.9, s.y - r * 1.1), r * 0.75],
		"reset": [Vector2(s.x - r * 0.9, r * 0.9), r * 0.5],
	}
	if gadget_names[0] != "":
		out["gadget0"] = [Vector2(s.x - r * 1.3, s.y - r * 3.7), r * 0.62]
	if gadget_names[1] != "":
		out["gadget1"] = [Vector2(s.x - r * 3.1, s.y - r * 3.3), r * 0.62]
	return out


func _button_at(pos: Vector2) -> String:
	var buttons := _buttons()
	for name in buttons:
		# A little extra room around each button so thumbs don't miss.
		if pos.distance_to(buttons[name][0]) <= buttons[name][1] * 1.25:
			return name
	return ""


func _input(event: InputEvent) -> void:
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
			elif _stick_finger == -1 and event.position.distance_to(stick[0]) <= stick[1] * 1.5:
				# The whole stick is the target, plus some room around it, not
				# just the knob. Chasing a small knob with your thumb is what
				# makes touch controls feel broken.
				_stick_finger = event.index
				_move_knob(event.position)
		else:
			_fingers.erase(event.index)
			_finger_at.erase(event.index)
			if event.index == _stick_finger:
				_stick_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_move_knob(event.position)
		elif _fingers.has(event.index):
			_finger_at[event.index] = event.position
			var name := _button_at(event.position)
			if name == "gas" or name == "brake":
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
	steer = stick_to_steer(_knob)
	var held := _fingers.values()
	throttle = 1.0 if held.has("gas") else 0.0
	brake = 1.0 if held.has("brake") else 0.0
	reset = held.has("reset")
	queue_redraw()


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
	var labels := { "gas": "GO", "brake": "BRAKE", "reset": "RESET", "gadget0": gadget_names[0], "gadget1": gadget_names[1] }
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
		var font_size := int(radius * (0.3 if name.begins_with("gadget") else 0.4))
		var text: String = labels[name]
		var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var top_left := centre - text_size * 0.5 + Vector2(0.0, font_size * 0.8)
		draw_multiline_string(font, top_left, text, HORIZONTAL_ALIGNMENT_CENTER, text_size.x, font_size, -1, Color(0, 0, 0, 0.75))
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
