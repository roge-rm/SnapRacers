class_name ColourPicker
extends HBoxContainer

## The custom colour picker: a square for lighter, darker and greyer, a strip
## for the hue, and a big preview. Drag on the strip and the square, or move
## the marker with the d-pad, the stick or the arrows. Use (or A) sends the
## colour, Cancel goes back. Both parts are drawn by shaders, so no pictures.

signal used(colour: Color)
signal cancelled

const FIELD := 220.0
const STRIP := 44.0
## How far a d-pad press moves a marker.
const STEP := 0.03

const STRIP_SHADER := """
shader_type canvas_item;
vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}
void fragment() {
	COLOR = vec4(hsv(UV.y, 1.0, 1.0), 1.0);
}
"""
const SQUARE_SHADER := """
shader_type canvas_item;
uniform float hue = 0.0;
vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}
void fragment() {
	COLOR = vec4(hsv(hue, UV.x, 1.0 - UV.y), 1.0);
}
"""

var hue := 0.0
var sat := 1.0
var val := 1.0

var _square: Field
var _strip: Field
var _preview: Panel
var _use: Button
var _look := StyleBoxFlat.new()


## The colour for a hue, saturation and value, each 0 to 1.
static func colour_of(h: float, s: float, v: float) -> Color:
	return Color.from_hsv(clampf(h, 0.0, 1.0), clampf(s, 0.0, 1.0), clampf(v, 0.0, 1.0))


func _init() -> void:
	add_theme_constant_override("separation", 14)
	_square = Field.new(false)
	_square.custom_minimum_size = Vector2(FIELD, FIELD)
	_square.changed.connect(func(at: Vector2) -> void:
		sat = at.x
		val = 1.0 - at.y
		_update())
	_square.accepted.connect(_use_it)
	add_child(_square)
	_strip = Field.new(true)
	_strip.custom_minimum_size = Vector2(STRIP, FIELD)
	_strip.changed.connect(func(at: Vector2) -> void:
		hue = at.y
		_update())
	_strip.accepted.connect(_use_it)
	add_child(_strip)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	add_child(side)
	_preview = Panel.new()
	_preview.custom_minimum_size = Vector2(130, 0)
	_preview.size_flags_vertical = SIZE_EXPAND_FILL
	_look.set_corner_radius_all(10)
	_look.set_border_width_all(3)
	_look.border_color = UiKit.WHITE
	_preview.add_theme_stylebox_override("panel", _look)
	side.add_child(_preview)
	_use = BuilderStyle.pill("Use", Color(UiKit.ACCENT, 0.9), BuilderStyle.ON_ACCENT, _use_it, 44.0)
	side.add_child(_use)
	_update()


## Starts from this colour.
func set_colour(colour: Color) -> void:
	hue = colour.h
	sat = colour.s
	val = colour.v
	_update()


func colour() -> Color:
	return colour_of(hue, sat, val)


func focus_square() -> void:
	_square.grab_focus()


func _use_it() -> void:
	used.emit(colour())


func _update() -> void:
	_look.bg_color = colour()
	_square.set_at(Vector2(sat, 1.0 - val))
	_strip.set_at(Vector2(0.0, hue))
	_square.shade.set_shader_parameter("hue", hue)


## A square or a strip with a marker. `at` is 0 to 1 across and down.
class Field extends Control:
	signal changed(at: Vector2)
	signal accepted

	var at := Vector2.ZERO
	var shade := ShaderMaterial.new()
	var _tall: bool
	var _drag := false
	var _marker := Control.new()

	func _init(strip: bool) -> void:
		_tall = strip
		focus_mode = FOCUS_ALL
		mouse_filter = MOUSE_FILTER_STOP
		var shader := Shader.new()
		shader.code = ColourPicker.STRIP_SHADER if strip else ColourPicker.SQUARE_SHADER
		shade.shader = shader
		var face := ColorRect.new()
		face.mouse_filter = MOUSE_FILTER_IGNORE
		face.material = shade
		add_child(face)
		face.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_marker.mouse_filter = MOUSE_FILTER_IGNORE
		_marker.draw.connect(_draw_marker)
		add_child(_marker)
		_marker.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		resized.connect(_marker.queue_redraw)
		focus_entered.connect(_marker.queue_redraw)
		focus_exited.connect(_marker.queue_redraw)

	func set_at(to: Vector2) -> void:
		at = to
		_marker.queue_redraw()

	func _draw_marker() -> void:
		var spot := Vector2(at.x * size.x, at.y * size.y)
		if _tall:
			var band := Rect2(-2.0, spot.y - 4.0, size.x + 4.0, 8.0)
			_marker.draw_rect(band, Color.BLACK, false, 3.0)
			_marker.draw_rect(band, UiKit.WHITE, false, 1.5)
		else:
			_marker.draw_circle(spot, 10.0, Color.BLACK, false, 3.0)
			_marker.draw_circle(spot, 10.0, UiKit.WHITE, false, 1.5)
		if has_focus():
			_marker.draw_rect(Rect2(Vector2.ZERO, size), UiKit.WHITE, false, 4.0)

	func _move_to(pos: Vector2) -> void:
		var to := Vector2(clampf(pos.x / maxf(size.x, 1.0), 0.0, 1.0), clampf(pos.y / maxf(size.y, 1.0), 0.0, 1.0))
		if _tall:
			to.x = 0.0
		set_at(to)
		changed.emit(to)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
			if _drag:
				_move_to(event.position)
			accept_event()
		elif event is InputEventMouseMotion and _drag:
			_move_to(event.position)
			accept_event()
		elif event.is_action_pressed("ui_accept"):
			accept_event()
			accepted.emit()
		else:
			_step(event)

	## The strip moves up and down, the square every way. A press that can't
	## move any further is left for the focus to move on.
	func _step(event: InputEvent) -> void:
		var by := Vector2.ZERO
		if event.is_action_pressed("ui_left", true):
			by = Vector2.LEFT
		elif event.is_action_pressed("ui_right", true):
			by = Vector2.RIGHT
		elif event.is_action_pressed("ui_up", true):
			by = Vector2.UP
		elif event.is_action_pressed("ui_down", true):
			by = Vector2.DOWN
		if by == Vector2.ZERO or (_tall and by.x != 0.0):
			return
		var to := (at + by * ColourPicker.STEP).clamp(Vector2.ZERO, Vector2.ONE)
		if to.is_equal_approx(at):
			return
		accept_event()
		set_at(to)
		changed.emit(to)
