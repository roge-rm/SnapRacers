class_name CourseOutlineView
extends Control

## A course's layout drawn from above, fitted into the space it's given, for the
## cup and course cards. Higher road is drawn over lower road, so a bridge
## crosses over what's under it. There's a tick for the start line and a ring
## where there's a loop or a corkscrew.
##
## An outline that has to be worked out is left for a later frame, and only
## one is worked out each frame, so a screen full of them never stalls.

const EDGE := Color(0.0, 0.0, 0.0, 0.5)
const ROAD := Color(1.0, 1.0, 1.0, 0.9)
## How much higher one stretch of road has to be to be drawn on top.
const LEVEL := 2.0

var path := ""
## The colour for the start line and the loops.
var colour := MenuStyle.ACCENT
## How thick the road is drawn, in pixels.
var thickness := 3.0

var _outline := {}
static var _worked_out_on := -1


func _init(course := "", tint := MenuStyle.ACCENT) -> void:
	path = course
	colour = tint
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)
	if path != "" and CourseOutline.is_ready(path):
		_outline = CourseOutline.of(path)
	else:
		set_process(true)


func _process(_delta: float) -> void:
	if not _outline.is_empty() or path == "":
		set_process(false)
		return
	var frame := Engine.get_process_frames()
	if not CourseOutline.is_ready(path):
		if _worked_out_on == frame:
			return
		_worked_out_on = frame
	_outline = CourseOutline.of(path)
	set_process(false)
	queue_redraw()


func _draw() -> void:
	if _outline.is_empty():
		return
	var to_view := CourseOutline.fit(_outline, Rect2(Vector2.ZERO, size), thickness * 2.0 + 2.0)
	var line: PackedVector2Array = to_view * (_outline.line as PackedVector2Array)
	var heights: PackedFloat32Array = _outline.heights
	# The road in stretches at each level, drawn from the lowest up.
	var levels := {}
	var low := INF
	for h in heights:
		low = minf(low, h)
	var run := PackedVector2Array()
	var run_level := -1
	for i in line.size() - 1:
		var level := floori((maxf(heights[i], heights[i + 1]) - low) / LEVEL)
		if level != run_level and run.size() > 0:
			levels.get_or_add(run_level, []).append(run)
			run = PackedVector2Array([line[i]])
		elif run.is_empty():
			run.append(line[i])
		run_level = level
		run.append(line[i + 1])
	if run.size() > 1:
		levels.get_or_add(run_level, []).append(run)
	var order := levels.keys()
	order.sort()
	for level in order:
		for stretch in levels[level]:
			draw_polyline(stretch, EDGE, thickness * 2.2, true)
		for stretch in levels[level]:
			draw_polyline(stretch, ROAD, thickness, true)
	for at in _outline.loops:
		draw_arc(to_view * at, thickness * 2.4, 0.0, TAU, 20, colour, thickness * 0.8, true)
	var start: Vector2 = to_view * (_outline.start as Vector2)
	var across: Vector2 = _outline.across * thickness * 2.6
	draw_line(start - across, start + across, colour, thickness * 1.2, true)
