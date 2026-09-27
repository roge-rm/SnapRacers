class_name TouchControls
extends Control

## On-screen controls for a phone or tablet. Put your left thumb down anywhere
## on the left half and slide it sideways to steer. On the right there's a big
## gas button with the brake beside it, and a small reset button up top.
## Sliding a finger from gas to brake works without lifting it.

const STICK_RANGE := 120.0

var steer := 0.0
var throttle := 0.0
var brake := 0.0
var reset := false

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_at := Vector2.ZERO
var _fingers := {} # finger index -> button name
var _finger_at := {} # finger index -> position


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _buttons() -> Dictionary:
	var s := size
	var r := minf(s.y * 0.13, 110.0)
	return {
		"gas": [Vector2(s.x - r * 1.5, s.y - r * 1.5), r],
		"brake": [Vector2(s.x - r * 3.9, s.y - r * 1.1), r * 0.75],
		"reset": [Vector2(s.x - r * 0.9, r * 0.9), r * 0.5],
	}


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
			var name := _button_at(event.position)
			if name != "":
				_fingers[event.index] = name
				_finger_at[event.index] = event.position
			elif event.position.x < size.x * 0.5 and _stick_finger == -1:
				_stick_finger = event.index
				_stick_origin = event.position
				_stick_at = event.position
		else:
			_fingers.erase(event.index)
			_finger_at.erase(event.index)
			if event.index == _stick_finger:
				_stick_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_stick_at = event.position
		elif _fingers.has(event.index):
			_finger_at[event.index] = event.position
			var name := _button_at(event.position)
			if name == "gas" or name == "brake":
				_fingers[event.index] = name
	_update()


func _update() -> void:
	steer = 0.0
	if _stick_finger != -1:
		steer = clampf((_stick_at.x - _stick_origin.x) / STICK_RANGE, -1.0, 1.0)
	var held := _fingers.values()
	throttle = 1.0 if held.has("gas") else 0.0
	brake = 1.0 if held.has("brake") else 0.0
	reset = held.has("reset")
	queue_redraw()


func _draw() -> void:
	if size.y <= 0.0:
		return # not laid out yet
	var buttons := _buttons()
	var held := _fingers.values()
	var labels := { "gas": "GO", "brake": "BRAKE", "reset": "RESET" }
	var font := get_theme_default_font()
	for name in buttons:
		var centre: Vector2 = buttons[name][0]
		var radius: float = buttons[name][1]
		var alpha := 0.55 if held.has(name) else 0.28
		draw_circle(centre, radius, Color(1, 1, 1, alpha))
		draw_arc(centre, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 3.0, true)
		var font_size := int(radius * 0.4)
		var text_size := font.get_string_size(labels[name], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, centre + Vector2(-text_size.x * 0.5, font_size * 0.35), labels[name], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.75))
	if _stick_finger != -1:
		draw_arc(_stick_origin, STICK_RANGE, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
		var knob := _stick_origin + Vector2(steer * STICK_RANGE, 0.0)
		draw_circle(knob, 40.0, Color(1, 1, 1, 0.55))
