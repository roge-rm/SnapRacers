class_name GroundToolIcon
extends Control

## A picture for a Ground tab tile: the ground side on with what the tool
## does to it, or the brush's size as a ring.

const GROUND := Color("#6fbf5a")
const BEFORE := Color(1, 1, 1, 0.35)
const ROAD := Color("#8a8d86")
const ARROW := Color("#f2f2f2")

var tool := ""
var brush := 1


func _init(what: String, size_ := 1) -> void:
	tool = what
	brush = size_
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var w := minf(size.x - 24.0, 72.0)
	var left := c.x - w * 0.5
	var base := c.y + 14.0
	match tool:
		"brush":
			var radius := 6.0 + 4.0 * brush
			draw_arc(c + Vector2(0, 2), radius, 0.0, TAU, 32, ARROW, 3.0, true)
			draw_circle(c + Vector2(0, 2), 2.5, ARROW)
		"raise", "lower":
			var up := tool == "raise"
			_hump(left, w, base, 4.0, BEFORE)
			_hump(left, w, base, 18.0 if up else -10.0, GROUND)
			var x := c.x
			var y0 := base - (6.0 if up else 22.0)
			var y1 := base - (22.0 if up else 6.0)
			draw_line(Vector2(x, y0), Vector2(x, y1), ARROW, 3.0, true)
			var tip := Vector2(x, y1)
			var back := 6.0 if up else -6.0
			draw_line(tip, tip + Vector2(-5, back), ARROW, 3.0, true)
			draw_line(tip, tip + Vector2(5, back), ARROW, 3.0, true)
		"smooth":
			var rough := PackedVector2Array()
			var even := PackedVector2Array()
			for k in 17:
				var t := k / 16.0
				rough.append(Vector2(left + w * t, base - 8.0 - (6.0 if k % 2 == 0 else -2.0) * sin(PI * t)))
				even.append(Vector2(left + w * t, base - 8.0 - 4.0 * sin(PI * t)))
			draw_polyline(rough, BEFORE, 2.0, true)
			draw_polyline(even, GROUND, 4.0, true)
		"flatten":
			_hump(left, w, base, 18.0, BEFORE)
			var top := PackedVector2Array([Vector2(left, base), Vector2(left + w * 0.25, base - 10.0), Vector2(left + w * 0.75, base - 10.0), Vector2(left + w, base)])
			draw_polyline(top, GROUND, 4.0, true)
		"level":
			_hump(left, w, base, 16.0, BEFORE)
			# The road in the middle with the ground level with it either side.
			var road_y := base - 8.0
			draw_line(Vector2(left, road_y), Vector2(left + w, road_y), GROUND, 4.0, true)
			draw_rect(Rect2(Vector2(c.x - 12.0, road_y - 5.0), Vector2(24.0, 5.0)), ROAD)
	draw_line(Vector2(left, base + 4.0), Vector2(left + w, base + 4.0), Color(1, 1, 1, 0.15), 1.0)


## A smooth hill (or hollow, with a negative height) from `left` across `w`.
func _hump(left: float, w: float, base: float, tall: float, colour: Color) -> void:
	var line := PackedVector2Array()
	for k in 17:
		var t := k / 16.0
		line.append(Vector2(left + w * t, base - tall * pow(sin(PI * t), 2.0)))
	draw_polyline(line, colour, 4.0 if colour == GROUND else 2.0, true)
