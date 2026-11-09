class_name CourseMap
extends Control

## A little map of the course in the corner of the race, faded so it doesn't
## get in the way, with your kart and dimmer CPU dots marked on it. Tapping
## it goes through its modes (see MODES), and each player's is remembered.
##
## With two on one phone there's one map between them, bigger, on the line
## between their halves, with each of them marked in their own colour (see
## `players`). It has no close up, since that follows one kart.

## The whole course with you and the CPU on it, the same with every other
## human player too, a close up that turns with you, and hidden down to a
## small button.
const MODES := ["outline", "everyone", "close", "hidden"]
const NAMES := {"outline": "Map", "everyone": "Map with everyone", "close": "Close up map", "hidden": "Map hidden"}
const SIZE := 190.0
## How much of the course the close up shows across, in metres.
const CLOSE_ACROSS := 260.0
const HIDDEN_SIZE := 44.0
const LINE := Color(UiKit.WHITE, 0.85)
const EDGE := Color(0.0, 0.0, 0.0, 0.5)
const YOU := UiKit.YELLOW
const OTHERS := Color(UiKit.WHITE, 0.85)
const CPU := Color(UiKit.WHITE, 0.6)
const START := UiKit.RED
## The dark ring round a kart's dot.
const DOT_EDGE := UiKit.INK
## The dark square behind the map, so the course stands out over the race,
## with the panels' thin light edge.
const BACKING := Color(0.0, 0.0, 0.0, 0.3)
## Fainter on the shared map in split screen, where it sits over both views.
const SHARED_BACKING := Color(0.0, 0.0, 0.0, 0.05)

signal changed(mode: String)

var track: TrackPath
var you: Kart
var karts: Array[Kart] = []
var cpu_karts: Array[Kart] = []
## For a map two people share: their karts, each marked in its colour, as
## [kart, colour].
var players: Array = []
## How big it is across.
var across := SIZE
var mode := "outline":
	set(value):
		mode = value if MODES.has(value) and not (value == "close" and shared()) else "outline"
		custom_minimum_size = Vector2.ONE * (HIDDEN_SIZE if mode == "hidden" else across)
		queue_redraw()

## The course's middle line seen from above, as (x, z), and the box around it.
var _line := PackedVector2Array()
var _outline := {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	mode = mode
	if track == null:
		return
	_outline = CourseOutline.of_track(track)
	_line = _outline.line


func _process(_delta: float) -> void:
	if mode != "hidden":
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if tapped:
		mode = next_mode()
		changed.emit(mode)
		accept_event()


func shared() -> bool:
	return not players.is_empty()


## The mode after this one, leaving out the close up on a shared map.
func next_mode() -> String:
	var next: String = MODES[(MODES.find(mode) + 1) % MODES.size()]
	if next == "close" and shared():
		next = MODES[(MODES.find(next) + 1) % MODES.size()]
	return next


func _draw() -> void:
	if mode == "hidden":
		draw_rect(Rect2(Vector2.ZERO, size), BACKING)
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.EDGE, false, 1.0)
		var ring := PackedVector2Array()
		for k in 9:
			ring.append(size * 0.5 + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0) * 0.6) * size.x * 0.3)
		draw_polyline(ring, LINE, 3.0, true)
		return
	if track == null or _line.size() < 2:
		return
	draw_rect(Rect2(Vector2.ZERO, size), SHARED_BACKING if shared() else BACKING)
	if not shared():
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.EDGE, false, 1.0)
	var to_map := _whole() if mode != "close" else _close_up()
	var shown := to_map * _line
	# A bigger map has thicker lines and dots to go with it.
	var thick := maxf(1.0, across / SIZE)
	draw_polyline(shown, EDGE, 7.0 * thick, true)
	draw_polyline(shown, LINE, 3.5 * thick, true)
	# The start line, across the road.
	var start := to_map * _line[0]
	var tick := (to_map * (_line[0] + Vector2(track.start.basis.x.x, track.start.basis.x.z) * 12.0)) - start
	draw_line(start - tick * thick, start + tick * thick, START, 3.0 * thick, true)
	var marked: Array = players.map(func(p): return p[0])
	# Draw opponents first so the brighter human markers stay on top.
	for kart in karts:
		if not is_instance_valid(kart) or kart == you or marked.has(kart):
			continue
		var cpu := cpu_karts.has(kart)
		if cpu or mode == "everyone":
			draw_circle(to_map * Vector2(kart.global_position.x, kart.global_position.z), 4.5 * thick, CPU if cpu else OTHERS)
	for player in players:
		var kart: Kart = player[0]
		if is_instance_valid(kart):
			var spot := to_map * Vector2(kart.global_position.x, kart.global_position.z)
			draw_circle(spot, 9.0 * thick, DOT_EDGE)
			draw_circle(spot, 7.0 * thick, player[1])
	if you != null:
		var at := to_map * Vector2(you.global_position.x, you.global_position.z)
		draw_circle(at, 8.0, DOT_EDGE)
		draw_circle(at, 6.0, YOU)


## The whole course fitted into the map at its saved orientation.
func _whole() -> Transform2D:
	return CourseOutline.fit(_outline, Rect2(Vector2.ZERO, Vector2.ONE * across), 14.0)


## A close up around your kart, turned so the way it's facing is up.
func _close_up() -> Transform2D:
	if you == null:
		return _whole()
	var fit := across / CLOSE_ACROSS
	var facing := -you.global_basis.z
	var turn := -atan2(facing.x, -facing.z)
	var centre := Vector2(you.global_position.x, you.global_position.z)
	return Transform2D(0.0, Vector2.ONE * across * 0.5) * Transform2D(turn, Vector2.ZERO) * Transform2D(0.0, Vector2(fit, fit), 0.0, -centre * fit)
