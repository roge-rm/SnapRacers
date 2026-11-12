class_name RaceWindow
extends Control

## The slanted window beside the main menu's buttons, with a still of a race
## on that course and its name on a red ribbon. Each visit picks a course at
## random from the ones that come with the game. MenuCluster sizes it.

const STILLS := "res://art/ui/menu_races"
## Screenshot tools can set this so the menu always shows the same course.
static var forced_id := ""

## How far it can run off the right edge when the cluster is a tight fit.
const OFF_EDGE := 60.0
## How wide it stays against its height.
const SHAPE := 1.43
## How tall it is on a 720-high screen.
const HIGH := 490.0
## Where the kart sits in a still, as a fraction of the picture.
const FOCUS := Vector2(0.5, 0.62)

var course_id := ""
var course_name := ""
## Off to leave it empty until show_course() or show_picture() is called.
var pick_at_random := true
## A whiter, thicker edge, for when it's a button and picked out.
var lit := false:
	set(value):
		lit = value
		queue_redraw()
## Game.SIDE_BY_SIDE or Game.FACE_TO_FACE fills the window with a drawing of
## two players sharing the screen that way, instead of a picture.
var split := "":
	set(value):
		split = value
		queue_redraw()
var _picture: Texture2D
## The picture is shown whole in the middle, like a trophy, rather than
## filling the window.
var _whole := false

static var _bag: Array[String] = []
static var _last_id := ""
static var _rng: RandomNumberGenerator


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	if pick_at_random:
		show_course(forced_id if forced_id != "" else pick_id())


static func still_path(id: String) -> String:
	return "%s/%s.jpg" % [STILLS, id]


## Puts this course in the window, name and still together.
func show_course(id: String) -> void:
	course_id = id
	course_name = ""
	_picture = null
	_whole = false
	if id != "":
		var file := FileAccess.open(Tracks.path_of(id), FileAccess.READ)
		if file != null:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary:
				course_name = str(data.get("name", "")).to_upper()
		var still := still_path(id)
		if ResourceLoader.exists(still):
			_picture = load(still)
	queue_redraw()


## Puts any picture in the window with this name under it. A `whole` one
## is shown all of it, in the middle, on the dark window.
func show_picture(picture: Texture2D, title: String, whole := false) -> void:
	course_id = ""
	course_name = title.to_upper()
	_picture = picture
	_whole = whole
	queue_redraw()


## A course id from the ones that come with the game. One shuffled pass
## through the lot, so two visits in a row aren't the same course.
static func pick_id(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		if _rng == null:
			_rng = RandomNumberGenerator.new()
			_rng.randomize()
		rng = _rng
	if _bag.is_empty():
		_fill_bag(rng)
	if _bag.is_empty():
		return ""
	var id: String = _bag.pop_back()
	_last_id = id
	return id


static func _fill_bag(rng: RandomNumberGenerator) -> void:
	_bag.clear()
	for id in Tracks.all():
		_bag.append(str(id))
	for i in range(_bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = swap
	if _bag.size() > 1 and _bag.back() == _last_id:
		var last := _bag.size() - 1
		_bag[last] = _bag[0]
		_bag[0] = _last_id


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var window := Rect2(Vector2.ZERO, Vector2(size.x, size.y - 16.0))
	if window.size.x < 100.0 or window.size.y < 100.0:
		return
	var corners := UiKit.slant_points(window)
	var shadow := PackedVector2Array()
	for at in corners:
		shadow.append(at + Vector2(10, 10))
	draw_colored_polygon(shadow, UiKit.SHADOW_COLOUR)
	var ribbon := _ribbon(window)
	if _picture != null and _whole:
		draw_colored_polygon(corners, UiKit.INK.lightened(0.08))
		var room := Rect2(window.position + Vector2(window.size.y * UiKit.LEAN * 0.5, 12.0), Vector2(window.size.x - window.size.y * UiKit.LEAN, window.size.y - 12.0 - (40.0 if ribbon.size.x > 0.0 else 12.0)))
		var shape := Vector2(_picture.get_size())
		var fit := minf(room.size.x / shape.x, room.size.y / shape.y)
		draw_texture_rect(_picture, Rect2(room.get_center() - shape * fit * 0.5, shape * fit), false)
	elif _picture != null:
		var part := _cover(Vector2(_picture.get_size()).aspect(), window.size.x / window.size.y)
		var uvs := PackedVector2Array()
		for at in corners:
			uvs.append(part.position + part.size * (at / window.size))
		draw_polygon(corners, PackedColorArray([Color.WHITE]), uvs, _picture)
	else:
		draw_colored_polygon(corners, UiKit.INK.lightened(0.08))
		if split != "":
			_draw_split(window, corners)
	var edge := corners.duplicate()
	edge.append(corners[0])
	draw_polyline(edge, UiKit.WHITE if lit else UiKit.YELLOW, 7.0 if lit else 5.0, true)
	if ribbon.size.x > 0.0:
		var font := UiKit.font("heading")
		UiKit.draw_slant(self, Rect2(ribbon.position + UiKit.SHADOW, ribbon.size), UiKit.SHADOW_COLOUR)
		UiKit.draw_slant(self, ribbon, UiKit.RED)
		var base := ribbon.get_center().y + (font.get_ascent(26) - font.get_descent(26)) * 0.5
		draw_string(font, Vector2(ribbon.position.x + 28.0, base), course_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiKit.WHITE)


## The largest slice of the still that fills the window, with the kart in the
## middle.
func _cover(picture: float, shape: float) -> Rect2:
	var high := minf(1.0, minf(2.0 * FOCUS.y, 2.0 * (1.0 - FOCUS.y)))
	var wide := high * shape / picture
	if wide > 1.0:
		wide = 1.0
		high = wide * picture / shape
	return Rect2(
		clampf(FOCUS.x - wide * 0.5, 0.0, 1.0 - wide),
		clampf(FOCUS.y - high * 0.5, 0.0, 1.0 - high),
		wide,
		high)


## The course name, centred in the view at the bottom of the box.
func _ribbon(window: Rect2) -> Rect2:
	if course_name == "":
		return Rect2()
	var font := UiKit.font("heading")
	var wide := font.get_string_size(course_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 60.0
	var left := clampf(window.size.x * 0.5 - wide * 0.5, 0.0, maxf(window.size.x - wide, 0.0))
	return Rect2(left, size.y - 46.0, wide, 46.0)


# ------------------------------------------------------- two on one screen

## The window as the screen, split in two halves, one per player: left and
## right side by side, or top and bottom face to face with the top one
## turned round.
func _draw_split(window: Rect2, corners: PackedVector2Array) -> void:
	var middle := window.get_center()
	if split == Game.FACE_TO_FACE:
		var half := Rect2(window.position, Vector2(window.size.x, window.size.y * 0.5))
		_draw_half(half, corners, 1, true, window)
		_draw_half(Rect2(half.position + Vector2(0, half.size.y), half.size), corners, 0, false, window)
		draw_line(Vector2(_left(middle.y, window), middle.y), Vector2(_right(middle.y, window), middle.y), UiKit.INK, 6.0)
	else:
		var half := Rect2(window.position, Vector2(window.size.x * 0.5, window.size.y))
		_draw_half(half, corners, 0, false, window)
		_draw_half(Rect2(half.position + Vector2(half.size.x, 0), half.size), corners, 1, false, window)
		draw_line(Vector2(middle.x, window.position.y), Vector2(middle.x, window.end.y), UiKit.INK, 6.0)


## Where the slanted window's left and right edges are at this height.
func _left(y: float, window: Rect2) -> float:
	var shift := minf(window.size.y * UiKit.LEAN, window.size.x * 0.5)
	return window.position.x + shift * (1.0 - (y - window.position.y) / window.size.y)


func _right(y: float, window: Rect2) -> float:
	var shift := minf(window.size.y * UiKit.LEAN, window.size.x * 0.5)
	return window.end.x - shift * (y - window.position.y) / window.size.y


## One player's half of the screen: sky, grass, a road to the horizon and
## their kart, with a P tag, cut to the window. `flip` turns it upside down.
func _draw_half(rect: Rect2, corners: PackedVector2Array, player: int, flip: bool, window: Rect2) -> void:
	var clip := Geometry2D.intersect_polygons(corners, _box(rect))
	if clip.is_empty():
		return
	var area: PackedVector2Array = clip[0]
	# Points in the half as fractions, with v going down its own screen.
	var at := func(u: float, v: float) -> Vector2:
		var p := Vector2(u * rect.size.x, v * rect.size.y)
		return rect.end - p if flip else rect.position + p
	# The middle of what shows of the half, across, at a height in it.
	var mid := func(v: float) -> float:
		var y: float = at.call(0.0, v).y
		var a := maxf(_left(y, window), rect.position.x)
		var b := minf(_right(y, window), rect.end.x)
		var u := ((a + b) * 0.5 - rect.position.x) / rect.size.x
		return 1.0 - u if flip else u
	var horizon := 0.4
	_fill(area, _quad(at, 0.0, 0.0, 1.0, horizon), Color("#7cc3ef"))
	_fill(area, _quad(at, 0.0, horizon, 1.0, 1.0), Color("#3f9e45"))
	var near := minf(0.7, 1.1 * rect.size.y / rect.size.x)
	var far := near * 0.08
	var top: float = mid.call(horizon)
	var bottom: float = mid.call(1.0)
	_fill(area, PackedVector2Array([
		at.call(top - far * 0.5, horizon), at.call(top + far * 0.5, horizon),
		at.call(bottom + near * 0.5, 1.0), at.call(bottom - near * 0.5, 1.0)]), Color("#3c4048"))
	# The kart, a body with wheels under it and a white helmet.
	var colour: Color = UiKit.PLAYERS[player]
	var kart_v := Vector2(0.15 * near / 0.7, 0.0)
	kart_v.y = kart_v.x * rect.size.x / rect.size.y * 0.7
	var foot := 0.92
	var centre: float = mid.call(foot - kart_v.y)
	var left := centre - kart_v.x * 0.5
	_fill(area, _quad(at, left - kart_v.x * 0.12, foot - kart_v.y * 0.45, left + kart_v.x * 1.12, foot), UiKit.INK)
	_fill(area, _quad(at, left, foot - kart_v.y, left + kart_v.x, foot - kart_v.y * 0.2), colour)
	draw_circle(at.call(centre, foot - kart_v.y * 1.15), kart_v.y * rect.size.y * 0.38, Color.WHITE)
	# The P tag in the half's top left, as its player sees it.
	var font := UiKit.font("heading")
	var size_px := clampi(int(rect.size.y * 0.09), 18, 30)
	var tag_size := Vector2(size_px * 2.7, size_px * 1.5)
	var corner: Vector2
	if flip:
		var y := rect.end.y - 16.0
		corner = Vector2(minf(_right(y, window), rect.end.x) - 16.0, y)
	else:
		var y := rect.position.y + 16.0
		corner = Vector2(maxf(_left(y, window), rect.position.x) + 16.0, y)
	draw_set_transform(corner, PI if flip else 0.0, Vector2.ONE)
	var tag := Rect2(Vector2.ZERO, tag_size)
	UiKit.draw_slant(self, tag, colour)
	var base := tag.get_center().y + (font.get_ascent(size_px) - font.get_descent(size_px)) * 0.5
	var words := "P%d" % (player + 1)
	var wide := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(font, Vector2(tag.get_center().x - wide * 0.5, base), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UiKit.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _quad(at: Callable, u0: float, v0: float, u1: float, v1: float) -> PackedVector2Array:
	return PackedVector2Array([at.call(u0, v0), at.call(u1, v0), at.call(u1, v1), at.call(u0, v1)])


func _box(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## Draws the part of `shape` inside `area`.
func _fill(area: PackedVector2Array, shape: PackedVector2Array, colour: Color) -> void:
	for piece in Geometry2D.intersect_polygons(area, shape):
		draw_colored_polygon(piece, colour)
