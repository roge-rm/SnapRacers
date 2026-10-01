class_name NudgePad
extends Control

## Four arrow buttons in a cross, for moving a part one stud at a time. Hold
## an arrow and it keeps going. It says which way was pressed as screen
## directions (right is (1, 0), up is (0, -1)), and the garage works out which
## way that is on the grid from where the camera's looking.

signal nudged(direction: Vector2i)

const ARROWS := {
	"up": [Vector2i(0, -1), Vector2(0.5, 0.0)],
	"down": [Vector2i(0, 1), Vector2(0.5, 1.0)],
	"left": [Vector2i(-1, 0), Vector2(0.0, 0.5)],
	"right": [Vector2i(1, 0), Vector2(1.0, 0.5)],
}

var _buttons := {}


func _init() -> void:
	custom_minimum_size = Vector2(170, 170)


func _ready() -> void:
	for name in ARROWS:
		var button := RepeatButton.new()
		button.custom_minimum_size = Vector2(58, 58)
		button.size = Vector2(58, 58)
		button.focus_mode = FOCUS_ALL
		for state in ["normal", "hover", "pressed"]:
			var round := StyleBoxFlat.new()
			round.bg_color = Color(1, 1, 1, 0.3 if state == "pressed" else 0.16)
			round.set_corner_radius_all(29)
			button.add_theme_stylebox_override(state, round)
		button.set_meta("arrow", name)
		button.fired.connect(func() -> void: nudged.emit(ARROWS[name][0]))
		button.draw.connect(_draw_arrow.bind(button))
		add_child(button)
		_buttons[name] = button
	resized.connect(_lay_out)
	_lay_out()


func _lay_out() -> void:
	for name in _buttons:
		var button: Button = _buttons[name]
		var anchor: Vector2 = ARROWS[name][1]
		button.position = (size - button.size) * anchor


## Draws a triangle on the button pointing its way.
func _draw_arrow(button: Button) -> void:
	var dir := Vector2(ARROWS[button.get_meta("arrow")][0])
	var middle := button.size * 0.5
	var side := Vector2(-dir.y, dir.x)
	var points := PackedVector2Array([middle + dir * 13.0, middle - dir * 9.0 + side * 12.0, middle - dir * 9.0 - side * 12.0])
	button.draw_colored_polygon(points, Color(1, 1, 1, 0.9))
