class_name PartThumbnails
extends Node

## Takes a little picture of every part for the garage's drawer. Each part is
## set up on its own in a small view off the screen, lit and seen from above at
## an angle, and drawn once. The pictures are kept while the game runs, so the
## garage only takes them the first time, during the splash.

signal ready_for(id: String, picture: Texture2D)

const SIZE := Vector2i(160, 120)

static var _pictures := {}

var _view: SubViewport
var _camera: Camera3D
var _stand: Node3D
var _queue: Array = []
var _current := ""
var _frames := 0


## The picture of a part, or null if it hasn't been taken yet.
static func picture(id: String) -> Texture2D:
	return _pictures.get(id)


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
	env.environment.ambient_light_energy = 0.55
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 215.0, 0.0)
	sun.light_energy = 1.0
	_view.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_view.add_child(_camera)
	_stand = Node3D.new()
	_view.add_child(_stand)
	# With no screen (the headless tests) there's nothing to take pictures with.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for id in PartCatalog.ids():
		if not _pictures.has(id):
			_queue.append(id)


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
	_current = _queue.pop_front()
	_frames = 0
	for child in _stand.get_children():
		child.queue_free()
	var def := PartCatalog.get_part(_current)
	var extent := PartCatalog.fine_size(_current) * Grid.FINE
	_stand.add_child(PartVisuals.make(def, extent))
	var biggest := maxf(extent.x, maxf(extent.y, extent.z))
	if def.get("kind", "") == "wheel":
		biggest = maxf(biggest, float(def.get("radius", 0.3)) * 2.0)
	_camera.size = biggest * 1.5
	# From in front and to one side, where the shaping on slopes and noses
	# shows.
	_camera.position = Vector3(1.0, 0.9, -1.3).normalized() * 10.0
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
