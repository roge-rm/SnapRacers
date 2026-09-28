class_name DriverThumbnails
extends Node

## Takes the pictures on the driver screen's tiles. Each one is your driver
## as they are now, but wearing that tile's piece, seen from the front and a
## little to one side and cropped to that piece. So the hats show on your
## driver's head, in your driver's colours.
##
## A picture is taken in a small view off the screen, one at a time, and kept
## for as long as the game runs. Change a colour and the tiles get new
## pictures, but going back to an old look finds its pictures already taken.

signal ready_for(key: String, picture: Texture2D)

const SIZE := Vector2i(160, 120)
## For each piece, how high the middle of its picture is on the driver and
## how tall a slice of them the picture shows, in metres.
const FRAMES := {
	"head": [0.58, 0.38],
	"hair": [0.61, 0.52],
	"facial_hair": [0.53, 0.34],
	"headgear": [0.66, 0.6],
	"neck": [0.42, 0.32],
	"torso": [0.26, 0.5],
	"back": [0.28, 0.62],
	"arms": [0.22, 0.56],
	"legs": [-0.07, 0.52],
}

static var _pictures := {}

var _view: SubViewport
var _camera: Camera3D
var _stand: Node3D
var _queue: Array = []
var _current := ""
var _frames := 0
var _headless := false


## What a picture of this driver wearing this style of piece is kept under.
static func key_of(design: CharacterDesign, slot: String, style: String) -> String:
	var look := design.to_dict()
	look.erase("name")
	look[slot]["style"] = style
	return slot + " " + JSON.stringify(look, "", true)


## The picture for a tile, or null if it hasn't been taken yet. If it hasn't,
## it's added to the ones to take, and ready_for says when it's done.
func picture(design: CharacterDesign, slot: String, style: String) -> Texture2D:
	var key := key_of(design, slot, style)
	if _pictures.has(key):
		return _pictures[key]
	if not _headless and not _queue.any(func(job): return job[0] == key):
		var wearing := design.duplicate_design()
		wearing.set_piece(slot, style)
		_queue.append([key, wearing, slot])
		set_process(true)
	return null


## Forgets the pictures still waiting to be taken, when the tiles showing
## have changed and they aren't wanted any more.
func drop_waiting() -> void:
	_queue.clear()


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
	env.environment.ambient_light_color = Color("#e8e4f0")
	env.environment.ambient_light_energy = 0.55
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	# From over the camera's shoulder, so the face is lit.
	sun.rotation_degrees = Vector3(-35.0, 200.0, 0.0)
	sun.light_energy = 0.9
	_view.add_child(sun)
	CharacterRig.add_toy_lights(_view)
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
	var rig := CharacterRig.new(job[1], false)
	_stand.add_child(rig)
	var frame: Array = FRAMES.get(job[2], [0.2, 1.1])
	var middle := Vector3(0.0, frame[0], 0.0)
	# They face -Z, so the camera's out that way, a little to their right.
	# What's on their back is seen from behind, and for that I turn them
	# around instead of moving the camera, so the light still falls on what
	# the picture shows.
	_camera.size = frame[1]
	_stand.rotation.y = PI if job[2] == "back" else 0.0
	var from := Vector3(-0.45, 0.2 if job[2] == "back" else 0.12, -1.0)
	_camera.position = middle + from.normalized() * 3.0
	_camera.look_at(middle, Vector3.UP)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
