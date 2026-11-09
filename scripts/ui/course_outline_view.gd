class_name CourseOutlineView
extends Control

## A course's layout drawn from above, fitted into the space it's given, for the
## cup and course cards. Higher road is drawn over lower road, so a bridge
## crosses over what's under it. There's a tick for the start line and a ring
## where there's a loop or a corkscrew.
##
## An outline that has to be worked out is left for a later frame, and only
## one is worked out each frame, so a screen full of them never stalls.
##
## Antialiased lines are slow, and a screen of cards has dozens, so each
## outline is drawn once into a picture at the screen's pixel size and kept.
## The pictures wanted each frame are drawn together onto one sheet, a
## viewport that draws once and is kept on the GPU, so nothing is read back.
## An outline shows nothing until its picture's ready, a few frames at most,
## while the screen fades in. The splash makes the cup screen's (see
## SplashScreen._warm_cups()).

const EDGE := Color(0.0, 0.0, 0.0, 0.5)
const ROAD := Color(1.0, 1.0, 1.0, 0.9)
## How much higher one stretch of road has to be to be drawn on top.
const LEVEL := 2.0
## Most pixels of pictures kept, about 32 MB. The least used go first, but
## never one a view's drawing, so a big screen can go over.
const MOST_PIXELS := 8_000_000
## The biggest sheet of pictures, in pixels each way, and the most pictures
## drawn each frame, as each takes a millisecond or two. The rest wait for the
## next frame's sheet.
const SHEET := 2048
const PER_SHEET := 8
## Pixels between pictures on a sheet.
const SHEET_GAP := 2
## The pictures were drawn over clear black, so their colours are already
## multiplied by their alpha. This draws them that way and still fades them
## with the modulate.
const PREMULTIPLIED := """
shader_type canvas_item;
render_mode blend_premul_alpha;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() { COLOR = texture(TEXTURE, UV) * vec4(tint.rgb * tint.a, tint.a); }
"""

var path := ""
## The colour for the start line and the loops.
var colour := MenuStyle.ACCENT
## How thick the road is drawn, in pixels.
var thickness := 3.0

var _outline := {}
## The course's part of the picture key, worked out with the outline.
var _course_key := ""
## The key of the picture this view's drawing, which keeps it from being let go.
var _held := ""
static var _worked_out_on := -1
## Pictures of outlines by _picture_key(), least recently used first, with how
## many pixels they hold all together and the ones too big for a sheet.
static var _pictures := {}
static var _pixels_kept := 0
static var _failed := {}
## The sheet each picture is on, how many kept pictures each sheet holds and
## how many views in the tree are drawing each picture.
static var _sheet_of := {}
static var _on_sheet := {}
static var _users := {}
## The pictures wanted for the next sheet, by key: [outline, area, scale,
## thickness, colour, on screen, the views waiting].
static var _wanted := {}
static var _sheet_on := -1
static var _premultiplied: ShaderMaterial


func _init(course := "", tint := MenuStyle.ACCENT) -> void:
	path = course
	colour = tint
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_changed)
	# With the canvas_items stretch the screen's pixels per control pixel can
	# change without the control changing size.
	get_viewport().size_changed.connect(_changed)
	texture_filter = TEXTURE_FILTER_NEAREST
	if path != "" and CourseOutline.is_ready(path):
		_set_outline()
	set_process(true)


func _changed() -> void:
	queue_redraw()
	if path != "" or not _outline.is_empty():
		set_process(true)


## Updates the live preview of a course being edited.
func show_track(track: TrackPath) -> void:
	path = ""
	_outline = CourseOutline.of_track(track)
	_course_key = var_to_str(_outline).md5_text()
	_changed()


func _set_outline() -> void:
	_outline = CourseOutline.of(path)
	_course_key = CourseOutline._key(path)


func _process(_delta: float) -> void:
	if path == "" and _outline.is_empty():
		set_process(false)
		return
	if _outline.is_empty():
		var frame := Engine.get_process_frames()
		if not CourseOutline.is_ready(path):
			if _worked_out_on == frame:
				return
			_worked_out_on = frame
		_set_outline()
		queue_redraw()
		return
	# The headless tests have no GPU to draw pictures with.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var key := _picture_key()
	# With no room there's nothing to draw until it's resized (see _changed()).
	if key == "" or _pictures.has(key) or _failed.has(key):
		set_process(false)
		queue_redraw()
		return
	var pixels := _pixels()
	if pixels.x > SHEET or pixels.y > SHEET:
		_failed[key] = true
		set_process(false)
		queue_redraw()
		return
	if _wanted.is_empty():
		_make_sheet.call_deferred(get_tree().root)
	if _wanted.has(key):
		_wanted[key][5] = _wanted[key][5] or _on_screen()
		if not _wanted[key][6].has(self):
			_wanted[key][6].append(self)
	else:
		_wanted[key] = [_outline, size, _scale(), thickness, colour, _on_screen(), [self]]


func _on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	return get_viewport().get_visible_rect().intersects(get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size))


## How many screen pixels there are to one of this control's, from the
## stretch alone, so a card that grows for a moment when it's pressed doesn't
## make pictures at sizes in between.
func _scale() -> float:
	var viewport := get_viewport()
	return maxf(viewport.get_final_transform().get_scale().x * viewport.get_canvas_transform().get_scale().x, 0.01)


func _pixels() -> Vector2i:
	return Vector2i((size * _scale()).round())


## Which picture this outline needs now, or "" if it has no room.
func _picture_key() -> String:
	var pixels := _pixels()
	if pixels.x < 1 or pixels.y < 1:
		return ""
	return "%s %d %d %s %s" % [_course_key, pixels.x, pixels.y, colour.to_html(), thickness]


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_hold("")


## Marks the picture this view's drawing as in use, letting go of the last one.
func _hold(key: String) -> void:
	if key == _held:
		return
	if _held != "":
		_users[_held] -= 1
		if _users[_held] <= 0:
			_users.erase(_held)
	_held = key
	if key != "":
		_users[key] = _users.get(key, 0) + 1


func _draw() -> void:
	if _outline.is_empty():
		_hold("")
		return
	var key := _picture_key()
	if key == "":
		_hold("")
		return
	var picture: Texture2D = _pictures.get(key)
	if picture != null:
		# Last used goes last, so it's the last to go.
		_pictures.erase(key)
		_pictures[key] = picture
		_hold(key)
		if material != _material():
			material = _material()
		draw_texture_rect(picture, Rect2(Vector2.ZERO, Vector2(_pixels()) / _scale()), false)
		return
	_hold("")
	if material != null:
		material = null
	# Lines only where there's no GPU to make pictures, or it's too big for one.
	if DisplayServer.get_name() == "headless" or _failed.has(key):
		_paint(self, _outline, size, 1.0, thickness, colour)
	else:
		set_process(true)


## Draws every wanted picture onto one sheet, the ones on screen first, and
## keeps the sheet. Called at the end of the frame they were wanted in, so the
## sheet's drawn that same frame.
static func _make_sheet(root: Node) -> void:
	var keys := _wanted.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _wanted[a][5] and not _wanted[b][5])
	var spots := {}
	var x := 0
	var y := 0
	var row := 0
	var wide := 0
	for key: String in keys:
		var pixels := Vector2i((_wanted[key][1] * _wanted[key][2]).round())
		if x > 0 and x + pixels.x > SHEET:
			x = 0
			y += row + SHEET_GAP
			row = 0
		if y + pixels.y > SHEET or spots.size() >= PER_SHEET:
			break
		spots[key] = Rect2i(Vector2i(x, y), pixels)
		x += pixels.x + SHEET_GAP
		row = maxi(row, pixels.y)
		wide = maxi(wide, x)
	_sheet_on = Engine.get_process_frames()
	var sheet := SubViewport.new()
	sheet.transparent_bg = true
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ONCE
	sheet.size = Vector2i(maxi(wide, 1), maxi(y + row, 1))
	var painter := Node2D.new()
	var jobs := []
	for key: String in spots:
		jobs.append([spots[key].position] + _wanted[key].slice(0, 5))
	painter.draw.connect(func() -> void:
		for job in jobs:
			_paint(painter, job[1], job[2], job[3], job[4], job[5], Vector2(job[0])))
	sheet.add_child(painter)
	root.add_child(sheet)
	_on_sheet[sheet] = 0
	var waiting := []
	for key: String in spots:
		var picture := AtlasTexture.new()
		picture.atlas = sheet.get_texture()
		picture.region = Rect2(spots[key])
		_keep(key, picture, sheet)
		waiting.append_array(_wanted[key][6])
	for view in waiting:
		if is_instance_valid(view):
			view.queue_redraw()
	# The views still waiting ask again next frame.
	_wanted.clear()


## Whether any outline on screen is waiting to be worked out or drawn.
static func busy() -> bool:
	var frame := Engine.get_process_frames()
	return not _wanted.is_empty() or _sheet_on >= frame - 1 or _worked_out_on >= frame - 1


static func _keep(key: String, picture: AtlasTexture, sheet: SubViewport) -> void:
	var pixels := int(picture.region.size.x * picture.region.size.y)
	# Pictures in use and the ones just put on this sheet stay.
	for old: String in _pictures.keys():
		if _pixels_kept + pixels <= MOST_PIXELS:
			break
		if not _users.has(old) and _sheet_of[old] != sheet:
			_let_go(old)
	_pictures[key] = picture
	_sheet_of[key] = sheet
	_on_sheet[sheet] += 1
	_pixels_kept += pixels


## Forgets a picture, and its sheet once none of the sheet's pictures are kept.
static func _let_go(key: String) -> void:
	var gone: AtlasTexture = _pictures[key]
	_pixels_kept -= int(gone.region.size.x * gone.region.size.y)
	_pictures.erase(key)
	var sheet: SubViewport = _sheet_of[key]
	_sheet_of.erase(key)
	_on_sheet[sheet] -= 1
	if _on_sheet[sheet] <= 0:
		_on_sheet.erase(sheet)
		if is_instance_valid(sheet):
			sheet.queue_free()


static func _material() -> ShaderMaterial:
	if _premultiplied == null:
		var shader := Shader.new()
		shader.code = PREMULTIPLIED
		_premultiplied = ShaderMaterial.new()
		_premultiplied.shader = shader
	return _premultiplied


## Draws the outline into `area` on `item`, `scale` times as big, with its
## corner at `corner` in item pixels.
static func _paint(item: CanvasItem, outline: Dictionary, area: Vector2, scale: float, width: float, tint: Color, corner := Vector2.ZERO) -> void:
	item.draw_set_transform(corner, 0.0, Vector2.ONE * scale)
	var to_view := CourseOutline.fit(outline, Rect2(Vector2.ZERO, area), width * 2.0 + 2.0)
	var all: PackedVector2Array = to_view * (outline.line as PackedVector2Array)
	var all_heights: PackedFloat32Array = outline.heights
	# Points closer than a pixel to the last one kept are left out. A kept
	# point takes the highest of those it stands for, so bridges stay on top.
	var line := PackedVector2Array([all[0]])
	var heights := PackedFloat32Array([all_heights[0]])
	var high := -INF
	var apart := 1.0 / (scale * scale)
	for i in range(1, all.size()):
		high = maxf(high, all_heights[i])
		if i == all.size() - 1 or all[i].distance_squared_to(line[line.size() - 1]) >= apart:
			line.append(all[i])
			heights.append(high)
			high = -INF
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
			item.draw_polyline(stretch, EDGE, width * 2.2, true)
		for stretch in levels[level]:
			item.draw_polyline(stretch, ROAD, width, true)
	for at in outline.loops:
		item.draw_arc(to_view * at, width * 2.4, 0.0, TAU, 20, tint, width * 0.8, true)
	var start: Vector2 = to_view * (outline.start as Vector2)
	var across: Vector2 = outline.across * width * 2.6
	item.draw_line(start - across, start + across, tint, width * 1.2, true)
	item.draw_set_transform(Vector2.ZERO)

