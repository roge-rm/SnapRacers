class_name PartThumbnails
extends Node

## Takes a little picture of every part for the garage's drawer. Each part is
## set up on its own in a small view off the screen, lit and seen from above at
## an angle, framed to fill the picture, and drawn once.
##
## There's one of these for the whole game (Game.part_pictures). It starts
## during the splash, so the pictures are there by the time the garage opens,
## and it saves them, so after the first launch they load straight away. They're
## taken again when the parts change.

signal ready_for(id: String, picture: Texture2D)

const SIZE := Vector2i(160, 120)
const SAVED := "user://pictures/parts"
## Goes up when the pictures are taken differently, so the saved ones go.
const LOOK := 2
## How much of the picture a part fills.
const FILL := 0.88
## Dark parts would be lost on the drawer's dark tiles, so in the pictures
## they're never darker than this.
const DARKEST := 0.42
## How many pictures are taken at the same time.
const AT_ONCE := 8

static var _pictures := {}

var _views: Array[Studio] = []
var _queue: Array = []
var _stamp := ""


## The picture of a part, or null if it hasn't been taken yet.
static func picture(id: String) -> Texture2D:
	return _pictures.get(id)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# With no screen (the headless tests) there's nothing to take pictures with.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for i in AT_ONCE:
		var studio := Studio.new()
		add_child(studio)
		_views.append(studio)
	_stamp = _work_out_stamp()
	var keep := FileAccess.get_file_as_string(SAVED + "/stamp.txt") == _stamp
	if not keep:
		DirAccess.make_dir_recursive_absolute(SAVED)
		for file in DirAccess.get_files_at(SAVED):
			DirAccess.remove_absolute(SAVED + "/" + file)
	for id in PartCatalog.ids():
		if _pictures.has(id):
			continue
		if keep and _load(id):
			continue
		_queue.append(id)
	if not keep:
		var file := FileAccess.open(SAVED + "/stamp.txt", FileAccess.WRITE)
		if file != null:
			file.store_string(_stamp)


## Takes these parts' pictures next, like the ones on the tab just opened.
func hurry(ids: Array) -> void:
	var first := ids.filter(func(id: String) -> bool: return _queue.has(id))
	if first.is_empty():
		return
	_queue = first + _queue.filter(func(id: String) -> bool: return not first.has(id))
	set_process(DisplayServer.get_name() != "headless")


## What the parts are, so the saved pictures can tell if they've changed.
static func _work_out_stamp() -> String:
	var text := "%d %s" % [LOOK, ProjectSettings.get_setting("application/config/version", "")]
	for path in [PartCatalog.PATH, PartCatalog.MADE_PATH]:
		text += FileAccess.get_file_as_string(path)
	return text.md5_text()


func _load(id: String) -> bool:
	var path := "%s/%s.png" % [SAVED, id]
	if not FileAccess.file_exists(path):
		return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return false
	_pictures[id] = ImageTexture.create_from_image(image)
	return true


func _process(_delta: float) -> void:
	var busy := false
	for studio in _views:
		var done := studio.taken()
		if done != null:
			_pictures[studio.id] = ImageTexture.create_from_image(done)
			done.save_png("%s/%s.png" % [SAVED, studio.id])
			ready_for.emit(studio.id, _pictures[studio.id])
			studio.id = ""
		if studio.id == "" and not _queue.is_empty():
			studio.take(_queue.pop_front())
		busy = busy or studio.id != ""
	if not busy:
		set_process(false)


## Points the camera at the part from in front and to one side, where the
## shaping on slopes and noses shows, close enough that it fills the picture.
static func _frame(camera: Camera3D, made: Node3D) -> void:
	var corners: Array[Vector3] = []
	for node in made.find_children("*", "VisualInstance3D", true, false):
		var shown := node as VisualInstance3D
		var box := shown.get_aabb()
		for i in 8:
			corners.append(shown.global_transform * box.get_endpoint(i))
	if corners.is_empty():
		corners.append(Vector3.ZERO)
	var middle := Vector3.ZERO
	for corner in corners:
		middle += corner
	middle /= corners.size()
	camera.position = middle + Vector3(1.0, 0.9, -1.3).normalized() * 10.0
	camera.look_at(middle, Vector3.UP)
	# Where the corners land in the picture, to centre it and size it.
	var low := Vector2.INF
	var high := -Vector2.INF
	var to_camera := camera.global_transform.affine_inverse()
	for corner in corners:
		var seen := to_camera * corner
		low = low.min(Vector2(seen.x, seen.y))
		high = high.max(Vector2(seen.x, seen.y))
	var centre := (low + high) * 0.5
	camera.position += camera.basis.x * centre.x + camera.basis.y * centre.y
	var aspect := float(SIZE.x) / float(SIZE.y)
	var span := high - low
	camera.size = maxf(maxf(span.y, span.x / aspect) / FILL, 0.02)


## Lifts dark colours, so black tires and dark tiles show up in the drawer.
static func _lighten(made: Node3D) -> void:
	for node in made.find_children("*", "GeometryInstance3D", true, false):
		var shown := node as GeometryInstance3D
		var material := shown.material_override as StandardMaterial3D
		if material == null or material.albedo_color.v >= DARKEST:
			continue
		var lighter := material.duplicate() as StandardMaterial3D
		lighter.albedo_color.v = DARKEST
		shown.material_override = lighter


## A small view off the screen where one part at a time has its picture taken.
class Studio:
	extends SubViewport

	## The part in it, or "" when it's free.
	var id := ""
	var _camera: Camera3D
	var _stand: Node3D
	var _frames := 0

	func _init() -> void:
		size = SIZE
		own_world_3d = true
		transparent_bg = true
		render_target_update_mode = SubViewport.UPDATE_DISABLED
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color("#e8e8e8")
		env.environment.ambient_light_energy = 0.55
		add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50.0, 215.0, 0.0)
		sun.light_energy = 1.0
		add_child(sun)
		_camera = Camera3D.new()
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		add_child(_camera)
		_stand = Node3D.new()
		add_child(_stand)

	func take(part: String) -> void:
		id = part
		_frames = 0
		for child in _stand.get_children():
			child.queue_free()
		var def := PartCatalog.get_part(id)
		var made := PartVisuals.make(def, PartCatalog.fine_size(id) * Grid.FINE)
		_stand.add_child(made)
		PartThumbnails._lighten(made)
		PartThumbnails._frame(_camera, made)
		render_target_update_mode = SubViewport.UPDATE_ONCE

	## The picture once it's ready, or null.
	func taken() -> Image:
		if id == "":
			return null
		_frames += 1
		# One frame to draw it, one more for the picture to be ready.
		if _frames < 3:
			return null
		var image := get_texture().get_image()
		if image == null or image.is_empty():
			id = ""
			return null
		return image
