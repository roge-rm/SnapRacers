class_name RaceWindow
extends Control

## The slanted window beside the main menu's buttons, with a still of a race
## on that course and its name on a red ribbon. Each visit picks a course at
## random from the ones that come with the game. It sits on the right of the
## screen and keeps clear of `beside`.

const STILLS := "res://art/ui/menu_races"
## Screenshot tools can set this so the menu always shows the same course.
static var forced_id := ""

## How far it runs off the right edge.
const OFF_EDGE := 60.0

## What it keeps to the right of, like the column of buttons.
var beside: Control

var course_id := ""
var course_name := ""
var _picture: Texture2D

static var _bag: Array[String] = []
static var _last_id := ""
static var _rng: RandomNumberGenerator


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 1.0
	anchor_top = 0.2
	anchor_bottom = 0.88
	offset_right = OFF_EDGE


func _ready() -> void:
	show_course(forced_id if forced_id != "" else pick_id())


static func still_path(id: String) -> String:
	return "%s/%s.jpg" % [STILLS, id]


## Puts this course in the window, name and still together.
func show_course(id: String) -> void:
	course_id = id
	course_name = ""
	_picture = null
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


func _process(_delta: float) -> void:
	# Clear of the buttons, wherever a camera hole has pushed them.
	var left := 0.0
	if beside != null and is_instance_valid(beside):
		var row := beside.get_global_rect()
		left = maxf(0.0, row.end.x + 30.0 - get_parent_area_size().x * anchor_left)
	if not is_equal_approx(offset_left, left):
		offset_left = left


func _draw() -> void:
	var window := Rect2(Vector2.ZERO, Vector2(size.x, size.y - 16.0))
	if window.size.x < 100.0 or window.size.y < 100.0:
		return
	var corners := UiKit.slant_points(window)
	var shadow := PackedVector2Array()
	for at in corners:
		shadow.append(at + Vector2(10, 10))
	draw_colored_polygon(shadow, UiKit.SHADOW_COLOUR)
	if _picture != null:
		var shape := window.size.x / window.size.y
		var picture := Vector2(_picture.get_size()).aspect()
		var part := Rect2(0, 0, 1, 1)
		if shape > picture:
			part.size.y = picture / shape
			part.position.y = (1.0 - part.size.y) * 0.6
		else:
			part.size.x = shape / picture
			part.position.x = (1.0 - part.size.x) * 0.5
		var uvs := PackedVector2Array()
		for at in corners:
			uvs.append(part.position + part.size * (at / window.size))
		draw_polygon(corners, PackedColorArray([Color.WHITE]), uvs, _picture)
	else:
		draw_colored_polygon(corners, UiKit.INK.lightened(0.08))
	var edge := corners.duplicate()
	edge.append(corners[0])
	draw_polyline(edge, UiKit.YELLOW, 5.0, true)
	if course_name != "":
		var font := UiKit.font("heading")
		var wide := font.get_string_size(course_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 60.0
		var ribbon := Rect2(window.size.y * UiKit.LEAN * 0.25 + 30.0, size.y - 46.0, wide, 46.0)
		UiKit.draw_slant(self, Rect2(ribbon.position + UiKit.SHADOW, ribbon.size), UiKit.SHADOW_COLOUR)
		UiKit.draw_slant(self, ribbon, UiKit.RED)
		var base := ribbon.get_center().y + (font.get_ascent(26) - font.get_descent(26)) * 0.5
		draw_string(font, Vector2(ribbon.position.x + 28.0, base), course_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiKit.WHITE)
