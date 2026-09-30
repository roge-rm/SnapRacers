class_name CourseMap
extends Control

## A little map of the course in the corner of the race, faded so it doesn't
## get in the way, with your kart marked on it. Tapping it goes through its
## modes (see MODES), and each player's is remembered.

## The whole course with you on it, the same with everyone on it, a close
## up that turns with you, and hidden down to a small button.
const MODES := ["outline", "everyone", "close", "hidden"]
const NAMES := {"outline": "Map", "everyone": "Map with everyone", "close": "Close up map", "hidden": "Map hidden"}
const SIZE := 190.0
## How much of the course the close up shows across, in metres.
const CLOSE_ACROSS := 260.0
const HIDDEN_SIZE := 44.0
const LINE := Color(1.0, 1.0, 1.0, 0.6)
const EDGE := Color(0.0, 0.0, 0.0, 0.45)
const YOU := Color("#f2cd37")
const OTHERS := Color(1.0, 1.0, 1.0, 0.85)

signal changed(mode: String)

var track: TrackPath
var you: Kart
var karts: Array[Kart] = []
var mode := "outline":
	set(value):
		mode = value if MODES.has(value) else "outline"
		custom_minimum_size = Vector2.ONE * (HIDDEN_SIZE if mode == "hidden" else SIZE)
		queue_redraw()

## The course's middle line seen from above, as (x, z), and the box around it.
var _line := PackedVector2Array()
var _box := Rect2()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	mode = mode
	if track == null:
		return
	for k in range(0, track.points.size(), 3):
		_line.append(Vector2(track.points[k].x, track.points[k].z))
	_line.append(_line[0])
	_box = Rect2(_line[0], Vector2.ZERO)
	for p in _line:
		_box = _box.expand(p)


func _process(_delta: float) -> void:
	if mode != "hidden":
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if tapped:
		mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
		changed.emit(mode)
		accept_event()


func _draw() -> void:
	if mode == "hidden":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.25))
		var ring := PackedVector2Array()
		for k in 9:
			ring.append(size * 0.5 + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0) * 0.6) * size.x * 0.3)
		draw_polyline(ring, LINE, 3.0, true)
		return
	if track == null or _line.size() < 2:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.3))
	var to_map := _whole() if mode != "close" else _close_up()
	var shown := to_map * _line
	draw_polyline(shown, EDGE, 7.0, true)
	draw_polyline(shown, LINE, 3.5, true)
	# The start line, across the road.
	var start := to_map * _line[0]
	var across := (to_map * (_line[0] + Vector2(track.start.basis.x.x, track.start.basis.x.z) * 12.0)) - start
	draw_line(start - across, start + across, Color.WHITE, 3.0, true)
	if mode == "everyone":
		for kart in karts:
			if is_instance_valid(kart) and kart != you:
				draw_circle(to_map * Vector2(kart.global_position.x, kart.global_position.z), 4.5, OTHERS)
	if you != null:
		var at := to_map * Vector2(you.global_position.x, you.global_position.z)
		draw_circle(at, 8.0, Color.BLACK)
		draw_circle(at, 6.0, YOU)


## The whole course fitted into the map, north up.
func _whole() -> Transform2D:
	var margin := 14.0
	var fit := (SIZE - margin * 2.0) / maxf(_box.size.x, _box.size.y)
	var offset := Vector2(margin, margin) + (Vector2.ONE * (SIZE - margin * 2.0) - _box.size * fit) * 0.5
	return Transform2D(0.0, Vector2(fit, fit), 0.0, offset - _box.position * fit)


## A close up around your kart, turned so the way it's facing is up.
func _close_up() -> Transform2D:
	if you == null:
		return _whole()
	var fit := SIZE / CLOSE_ACROSS
	var facing := -you.global_basis.z
	var turn := -atan2(facing.x, -facing.z)
	var centre := Vector2(you.global_position.x, you.global_position.z)
	return Transform2D(0.0, Vector2.ONE * SIZE * 0.5) * Transform2D(turn, Vector2.ZERO) * Transform2D(0.0, Vector2(fit, fit), 0.0, -centre * fit)
