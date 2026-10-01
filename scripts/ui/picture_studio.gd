class_name PictureStudio
extends SubViewport

## A small view off the screen for taking a picture of one thing at a time, lit
## and seen from above at an angle, on a see-through background, framed so it
## fills the picture. The part and trophy pictures are taken in these.

## Something in it, or "" when it's free.
var key := ""
var _camera: Camera3D
var _stand: Node3D
var _frames := 0


## `shine` gives shiny things a sky to reflect, which metal needs to look
## like metal.
func _init(picture_size: Vector2i, shine := false) -> void:
	size = picture_size
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#e8e8e8")
	env.environment.ambient_light_energy = 0.55
	if shine:
		var sky := ProceduralSkyMaterial.new()
		sky.sky_top_color = Color("#a8c8ff")
		sky.sky_horizon_color = Color("#fff4e0")
		sky.ground_horizon_color = Color("#d8d0c0")
		sky.ground_bottom_color = Color("#3a3440")
		env.environment.sky = Sky.new()
		env.environment.sky.sky_material = sky
		env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 215.0, 0.0)
	sun.light_energy = 1.0
	add_child(sun)
	if shine:
		CharacterRig.add_toy_lights(self)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_camera)
	_stand = Node3D.new()
	add_child(_stand)


## Puts this in front of the camera to have its picture taken, from `from`.
func take(name_of: String, thing: Node3D, from := Vector3(1.0, 0.9, -1.3), fill := 0.88) -> void:
	key = name_of
	_frames = 0
	for child in _stand.get_children():
		child.queue_free()
	_stand.add_child(thing)
	frame(_camera, thing, from, fill, float(size.x) / float(size.y))
	render_target_update_mode = SubViewport.UPDATE_ONCE


## The picture once it's ready, or null.
func taken() -> Image:
	if key == "":
		return null
	_frames += 1
	# One frame to draw it, one more for the picture to be ready.
	if _frames < 3:
		return null
	var image := get_texture().get_image()
	if image == null or image.is_empty():
		key = ""
		return null
	return image


## Points the camera at a thing from `from`, close enough that it fills the
## picture.
static func frame(camera: Camera3D, thing: Node3D, from: Vector3, fill: float, aspect: float) -> void:
	var corners: Array[Vector3] = []
	for node in thing.find_children("*", "VisualInstance3D", true, false):
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
	camera.position = middle + from.normalized() * 10.0
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
	var span := high - low
	camera.size = maxf(maxf(span.y, span.x / aspect) / fill, 0.02)
