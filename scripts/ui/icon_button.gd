class_name IconButton
extends Button

## A small slanted button with a picture drawn on it. The pictures are drawn
## with lines instead of coming from an icon font, so they look the same
## everywhere the game runs.
##
## A toggle one fills with the accent colour while it's on.
##
## One in a toolbar or a drawer's rail has no box of its own, since the bar
## or the rail is its backing (see BuilderStyle.toolbar() and RailBox).

const SIZE := 48.0

var picture := ""
var on := false:
	set(value):
		on = value
		_style()
		queue_redraw()
		if get_parent() is RailBox:
			get_parent().queue_redraw()
## "" for a button on its own, "bar" in a toolbar or "rail" in a drawer's rail.
var look := "":
	set(value):
		look = value
		_style()
		queue_redraw()


## How far a rail tab's box leans, set by its RailBox to match the drawer.
var rail_lean := 0.0:
	set(value):
		if not is_equal_approx(rail_lean, value):
			rail_lean = value
			_style()


func _init(what: String, tip := "") -> void:
	picture = what
	tooltip_text = tip
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = FOCUS_ALL
	_style()


func _style() -> void:
	for state in UiKit.STATES:
		add_theme_stylebox_override(state, BuilderStyle.icon_box(state, on, SIZE, look, rail_lean))


func _draw() -> void:
	var c := Vector2(size) * 0.5
	var ink := UiKit.ON_ACCENT if on else (UiKit.FADED if disabled else UiKit.WHITE)
	var w := 3.0
	match picture:
		"close":
			draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), ink, w, true)
			draw_line(c + Vector2(9, -9), c + Vector2(-9, 9), ink, w, true)
		"undo", "redo":
			# A curve over the top with an arrowhead on the left end for undo,
			# or the right end for redo.
			draw_arc(c + Vector2(0, 4), 9.0, PI, TAU, 16, ink, w, true)
			var tip := c + Vector2(-9.0 if picture == "undo" else 9.0, 4)
			draw_line(tip, tip + Vector2(-5, -5), ink, w, true)
			draw_line(tip, tip + Vector2(5, -5), ink, w, true)
		"mirror":
			for y in range(-12, 13, 6):
				draw_line(c + Vector2(0, y), c + Vector2(0, y + 3), ink, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -8), c + Vector2(-4, 8), c + Vector2(-13, 8)]), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -8), c + Vector2(4, 8), c + Vector2(13, 8)]), ink)
		"paint":
			draw_line(c + Vector2(7, -10), c + Vector2(-3, 2), ink, 4.0, true)
			draw_circle(c + Vector2(-6, 7), 5.0, ink)
		"air":
			# Three gusts of wind, the middle one longer.
			for line in [[-8.0, -10.0, 6.0], [0.0, -13.0, 11.0], [8.0, -10.0, 4.0]]:
				var wave := PackedVector2Array()
				for i in 9:
					var x: float = lerpf(line[1], line[2], i / 8.0)
					wave.append(c + Vector2(x, line[0] + sin(i / 8.0 * TAU) * 2.0))
				draw_polyline(wave, ink, w, true)
		"camera":
			draw_rect(Rect2(c + Vector2(-12, -7), Vector2(24, 15)), ink, false, w)
			draw_circle(c + Vector2(0, 0.5), 4.0, ink)
			draw_rect(Rect2(c + Vector2(-5, -11), Vector2(10, 4)), ink)
		"pause":
			for x in [-6.0, 6.0]:
				draw_line(c + Vector2(x, -9), c + Vector2(x, 9), ink, 4.0)
		"more":
			for y in [-8.0, 0.0, 8.0]:
				draw_circle(c + Vector2(0, y), 2.8, ink)
		"plates":
			draw_rect(Rect2(c + Vector2(-12, 0), Vector2(24, 6)), ink)
			for x in [-8.0, -2.0, 4.0]:
				draw_rect(Rect2(c + Vector2(x, -3), Vector2(4, 3)), ink)
		"bricks":
			draw_rect(Rect2(c + Vector2(-11, -5), Vector2(22, 14)), ink)
			for x in [-7.0, 3.0]:
				draw_rect(Rect2(c + Vector2(x, -9), Vector2(5, 4)), ink)
		"slopes":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 9), c + Vector2(12, 9), c + Vector2(12, -8), c + Vector2(4, -8)]), ink)
			draw_rect(Rect2(c + Vector2(6, -12), Vector2(5, 4)), ink)
		"wings":
			draw_rect(Rect2(c + Vector2(-13, -8), Vector2(26, 5)), ink)
			for x in [-7.0, 5.0]:
				draw_line(c + Vector2(x, -3), c + Vector2(x, 10), ink, w)
			draw_line(c + Vector2(-13, -11), c + Vector2(-13, 0), ink, 2.0)
			draw_line(c + Vector2(13, -11), c + Vector2(13, 0), ink, 2.0)
		"rods":
			# A bar with a clip on it.
			draw_line(c + Vector2(-12, 9), c + Vector2(12, -9), ink, w, true)
			draw_arc(c + Vector2(-2, 1.5), 5.0, 0.0, TAU, 16, ink, 2.0, true)
			draw_line(c + Vector2(-5, 6), c + Vector2(-9, 11), ink, w, true)
		"bikes":
			draw_arc(c + Vector2(-8, 4), 6.0, 0.0, TAU, 16, ink, 2.0, true)
			draw_arc(c + Vector2(8, 4), 6.0, 0.0, TAU, 16, ink, 2.0, true)
			draw_line(c + Vector2(-8, 4), c + Vector2(-1, -3), ink, w, true)
			draw_line(c + Vector2(-1, -3), c + Vector2(6, -3), ink, w, true)
			draw_line(c + Vector2(8, 4), c + Vector2(5, -9), ink, w, true)
			draw_line(c + Vector2(2, -9), c + Vector2(8, -9), ink, w, true)
		"wheels":
			draw_arc(c, 11.0, 0.0, TAU, 24, ink, w, true)
			draw_circle(c, 4.0, ink)
		"engines":
			draw_rect(Rect2(c + Vector2(-10, -6), Vector2(20, 14)), ink, false, w)
			for x in [-5.0, 0.0, 5.0]:
				draw_line(c + Vector2(x, -6), c + Vector2(x, -12), ink, w)
		"gadgets":
			draw_colored_polygon(PackedVector2Array([c + Vector2(3, -13), c + Vector2(-7, 2), c + Vector2(0, 2), c + Vector2(-3, 13), c + Vector2(7, -2), c + Vector2(0, -2)]), ink)
		"extras":
			# A seat.
			draw_rect(Rect2(c + Vector2(-9, 2), Vector2(18, 5)), ink)
			draw_rect(Rect2(c + Vector2(4, -11), Vector2(5, 14)), ink)
		"head":
			# A brick figure head with its stud and two eyes.
			draw_rect(Rect2(c + Vector2(-9, -7), Vector2(18, 17)), ink, false, w)
			draw_rect(Rect2(c + Vector2(-4, -12), Vector2(8, 4)), ink)
			draw_circle(c + Vector2(-4, 0), 2.0, ink)
			draw_circle(c + Vector2(4, 0), 2.0, ink)
		"hair":
			draw_arc(c + Vector2(0, 6), 11.0, PI, TAU, 16, ink, w, true)
			for x in [-6.0, 0.0, 6.0]:
				draw_line(c + Vector2(x, -4), c + Vector2(x + 3, -11), ink, 2.5, true)
			draw_line(c + Vector2(-11, 6), c + Vector2(-11, 12), ink, w, true)
			draw_line(c + Vector2(11, 6), c + Vector2(11, 12), ink, w, true)
		"facial_hair":
			# A moustache.
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(-6, -5), c + Vector2(-13, -1), c + Vector2(-9, 3), c + Vector2(0, 1), c + Vector2(9, 3), c + Vector2(13, -1), c + Vector2(6, -5)]), ink)
		"neck":
			# A tie.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -11), c + Vector2(4, -11), c + Vector2(2, -6), c + Vector2(5, 8), c + Vector2(0, 13), c + Vector2(-5, 8), c + Vector2(-2, -6)]), ink)
		"back":
			# A backpack.
			draw_rect(Rect2(c + Vector2(-9, -8), Vector2(18, 20)), ink, false, w)
			draw_arc(c + Vector2(0, -8), 5.0, PI, TAU, 10, ink, w, true)
			draw_line(c + Vector2(-9, 2), c + Vector2(9, 2), ink, 2.0)
		"headgear":
			# A cap with its peak.
			draw_arc(c + Vector2(0, 4), 10.0, PI, TAU, 16, ink, w, true)
			draw_line(c + Vector2(-11, 4), c + Vector2(14, 4), ink, w, true)
			draw_circle(c + Vector2(0, -6), 2.0, ink)
		"torso":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -10), c + Vector2(7, -10), c + Vector2(11, 10), c + Vector2(-11, 10)]), ink)
		"arms":
			# An arm with the brick figure's bend and a C shaped hand.
			draw_line(c + Vector2(-8, -11), c + Vector2(-6, 2), ink, 5.0, true)
			draw_line(c + Vector2(-6, 2), c + Vector2(4, 6), ink, 5.0, true)
			draw_arc(c + Vector2(9, 6), 4.0, PI * 0.25, PI * 1.75, 12, ink, w, true)
		"legs":
			draw_rect(Rect2(c + Vector2(-10, -11), Vector2(20, 5)), ink)
			draw_rect(Rect2(c + Vector2(-10, -5), Vector2(9, 16)), ink)
			draw_rect(Rect2(c + Vector2(1, -5), Vector2(9, 16)), ink)
		"sit":
			# A steering wheel in front of a seat.
			draw_rect(Rect2(c + Vector2(-3, 4), Vector2(15, 5)), ink)
			draw_rect(Rect2(c + Vector2(8, -11), Vector2(4, 17)), ink)
			draw_arc(c + Vector2(-8, -4), 6.0, 0.0, TAU, 16, ink, 2.5, true)
		"dice":
			draw_rect(Rect2(c + Vector2(-11, -11), Vector2(22, 22)), ink, false, w)
			for spot in [Vector2(-5, -5), Vector2(0, 0), Vector2(5, 5)]:
				draw_circle(c + spot, 2.3, ink)
		"straights":
			# A stretch of road with a dashed line down the middle.
			draw_line(c + Vector2(-6, -12), c + Vector2(-6, 12), ink, w, true)
			draw_line(c + Vector2(6, -12), c + Vector2(6, 12), ink, w, true)
			for y in [-10.0, -2.0, 6.0]:
				draw_line(c + Vector2(0, y), c + Vector2(0, y + 4), ink, 2.0)
		"bends":
			draw_arc(c + Vector2(12, 12), 18.0, PI, PI * 1.5, 16, ink, w, true)
			draw_arc(c + Vector2(12, 12), 8.0, PI, PI * 1.5, 12, ink, w, true)
		"slants":
			var s_bend := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				s_bend.append(c + Vector2(lerpf(-7.0, 7.0, smoothstep(0.2, 0.8, t)), lerpf(12.0, -12.0, t)))
			draw_polyline(s_bend, ink, 7.0, true)
		"hills":
			var hump := PackedVector2Array()
			for k in 17:
				var t := k / 16.0
				hump.append(c + Vector2(lerpf(-13.0, 13.0, t), 8.0 - 14.0 * pow(sin(PI * t), 2.0)))
			draw_polyline(hump, ink, w, true)
			draw_line(c + Vector2(-13, 10), c + Vector2(13, 10), ink, 1.5)
		"banked":
			# A tilted road deck with a raised outside edge.
			var deck := PackedVector2Array([c + Vector2(-13, 6), c + Vector2(7, -5), c + Vector2(13, 2), c + Vector2(-7, 13), c + Vector2(-13, 6)])
			draw_polyline(deck, ink, w, true)
			draw_line(c + Vector2(-13, 6), c + Vector2(-13, -2), ink, w, true)
			draw_line(c + Vector2(-13, -2), c + Vector2(7, -13), ink, w, true)
			draw_line(c + Vector2(7, -13), c + Vector2(7, -5), ink, w, true)
		"stunts":
			draw_arc(c + Vector2(0, -2), 8.0, 0.0, TAU, 20, ink, w, true)
			draw_line(c + Vector2(-13, 7), c + Vector2(13, 7), ink, w, true)
		"landmarks":
			# A little tower with a pointed roof.
			draw_rect(Rect2(c + Vector2(-5, -4), Vector2(10, 16)), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -4), c + Vector2(8, -4), c + Vector2(0, -13)]), ink)
		"course":
			# A chequered flag.
			draw_line(c + Vector2(-9, -12), c + Vector2(-9, 12), ink, 2.5)
			for i in 3:
				for j in 2:
					if (i + j) % 2 == 0:
						draw_rect(Rect2(c + Vector2(-8 + i * 6, -11 + j * 6), Vector2(6, 6)), ink)
			draw_rect(Rect2(c + Vector2(-8, -11), Vector2(18, 12)), ink, false, 1.5)
		"fit":
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var at: Vector2 = c + corner * 11.0
				draw_line(at, at - Vector2(corner.x * 6.0, 0.0), ink, w)
				draw_line(at, at - Vector2(0.0, corner.y * 6.0), ink, w)
		"open":
			draw_line(c + Vector2(-4, -8), c + Vector2(4, 0), ink, w, true)
			draw_line(c + Vector2(4, 0), c + Vector2(-4, 8), ink, w, true)
		"shut":
			draw_line(c + Vector2(4, -8), c + Vector2(-4, 0), ink, w, true)
			draw_line(c + Vector2(-4, 0), c + Vector2(4, 8), ink, w, true)
		"skip":
			# Two arrowheads pointing right up against a bar.
			for x in [-11.0, -2.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(x, -8), c + Vector2(x + 9, 0), c + Vector2(x, 8)]), ink)
			draw_line(c + Vector2(9, -8), c + Vector2(9, 8), ink, w)
