class_name LandmarkThumbnails
extends Node

## Takes a little picture of each landmark for the track editor's drawer, the
## same way the garage does its parts. Each one is built on its own in a small
## view off the screen and drawn once, and the pictures are kept while the game
## runs.

signal ready_for(prop: String, picture: Texture2D)

const SIZE := Vector2i(160, 120)

static var _pictures := {}

var _view: SubViewport
var _camera: Camera3D
var _stand: Node3D
var _queue: Array = []
var _current := ""
var _frames := 0


static func picture(prop: String) -> Texture2D:
	return _pictures.get(prop)


func _ready() -> void:
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
	env.environment.ambient_light_energy = 0.6
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 215.0, 0.0)
	_view.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_view.add_child(_camera)
	_stand = Node3D.new()
	_view.add_child(_stand)
	if DisplayServer.get_name() == "headless":
		set_process(false)


## Asks for pictures of these, which come back through ready_for.
func take(props: Array) -> void:
	for prop in props:
		if not _pictures.has(prop) and not _queue.has(prop):
			_queue.append(prop)


func _process(_delta: float) -> void:
	if _current != "":
		_frames += 1
		if _frames < 2:
			return
		var image := _view.get_texture().get_image()
		if image != null and not image.is_empty():
			_pictures[_current] = ImageTexture.create_from_image(image)
			ready_for.emit(_current, _pictures[_current])
		_current = ""
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	_frames = 0
	for child in _stand.get_children():
		child.queue_free()
	var kit := SceneryKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Props.add(kit, _current, Vector3.ZERO, rng, 0)
	var holder := Node3D.new()
	_stand.add_child(holder)
	kit.build(holder)
	var room: float = Props.ROOM.get(_current, 3.0)
	_camera.size = room * 2.8
	_camera.position = Vector3(1.0, 0.8, 1.2).normalized() * (room * 6.0 + 20.0) + Vector3(0.0, room * 0.4, 0.0)
	_camera.look_at(Vector3(0.0, room * 0.4, 0.0), Vector3.UP)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
