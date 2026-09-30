class_name KartThumbnails
extends Node

## Takes a picture of a whole kart, from in front and a little to one side, for
## the kart picker. It works like PartThumbnails, one kart at a time in a small
## view off the screen, kept while the game runs.

signal ready_for(key: String, picture: Texture2D)

const SIZE := Vector2i(320, 200)

static var _pictures := {}

var _view: SubViewport
var _camera: Camera3D
var _stand: Node3D
var _queue: Array = []
var _current := ""
var _frames := 0
var _headless := false


## The picture kept under `key`, or null if it hasn't been taken yet.
static func picture(key: String) -> Texture2D:
	return _pictures.get(key)


## Forgets a picture, like when your own kart has changed since.
static func forget(key: String) -> void:
	_pictures.erase(key)


## Takes a picture of this kart, if there isn't one already, and says when
## it's ready through ready_for.
func take(key: String, design: KartDesign, driver: CharacterDesign = null) -> void:
	if _headless or _pictures.has(key) or _queue.any(func(job): return job[0] == key):
		return
	_queue.append([key, design, driver])
	set_process(true)


func _ready() -> void:
	# With no screen (the headless tests) there's nothing to take pictures with.
	_headless = DisplayServer.get_name() == "headless"
	_view = SubViewport.new()
	_view.size = SIZE
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#e8e8e8")
	env.environment.ambient_light_energy = 0.55
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 215.0, 0.0)
	sun.light_energy = 0.9
	_view.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_view.add_child(_camera)
	_stand = Node3D.new()
	_view.add_child(_stand)
	set_process(false)


func _process(_delta: float) -> void:
	if _current != "":
		_frames += 1
		# One frame to draw it, one more for the picture to be ready.
		if _frames < 2:
			return
		var image := _view.get_texture().get_image()
		if image != null and not image.is_empty():
			_pictures[_current] = ImageTexture.create_from_image(image)
			ready_for.emit(_current, _pictures[_current])
		_current = ""
	if _queue.is_empty():
		set_process(false)
		return
	var job: Array = _queue.pop_front()
	_current = job[0]
	_frames = 0
	for child in _stand.get_children():
		child.queue_free()
	_stand.add_child(KartModel.make(job[1], job[2]))
	var box := KartModel.bounds(job[1])
	var middle := box.get_center()
	# From in front, up a bit and off to the left, and big enough to fit the
	# kart whichever way it's longest.
	_camera.size = maxf(box.size.y * 1.6, maxf(box.size.x, box.size.z) * 0.95)
	_camera.position = middle + Vector3(-1.0, 0.75, -1.4).normalized() * 10.0
	_camera.look_at(middle, Vector3.UP)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
