class_name ScrollButton
extends Button

## A button that can sit in a scrolling list. A drag that starts on it goes
## through to the list, so you can scroll by dragging anywhere, and the
## button only does its thing if the finger didn't move.

signal tapped

const DRAG := 20.0

var _press := Vector2.ZERO
var _moved := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	pressed.connect(func() -> void:
		if not _moved:
			tapped.emit())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_press = event.position
		_moved = false
	elif event is InputEventScreenDrag and event.position.distance_to(_press) > DRAG:
		_moved = true
