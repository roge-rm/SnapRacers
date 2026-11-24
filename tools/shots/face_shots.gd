extends Node

## Close-ups of the newer faces in every mood, and the driver screen's face
## drawer with each group open. Saved where the argument says. Needs a screen:
##   XDG_DATA_HOME=$PWD/build/creations/faces DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/face_shots.tscn -- /some/folder

const FACES := ["plain", "no_mouth", "unamused", "cat", "blank", "kiss"]
const TILE := Vector2i(360, 400)
var OUT := "res://build/shots/faces"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	await _close_ups()
	await _drawer()
	get_tree().quit()


func _close_ups() -> void:
	var view := SubViewport.new()
	view.size = TILE
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	SkyAndSun.add_to(view, 20.0, BuilderStyle.BACKGROUND)
	for child in view.get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			child.environment.ambient_light_color = Color("#e8e8e8")
			child.environment.ambient_light_energy = 0.38
			child.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	CharacterRig.add_toy_lights(view)
	var camera := Camera3D.new()
	camera.fov = 28.0
	view.add_child(camera)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(10, 6)
	view.add_child(label)
	var middle := Vector3(0.0, 0.88, 0.0)
	camera.position = middle + Vector3(-0.2, 0.05, -1.0).normalized() * 1.1
	camera.look_at(middle, Vector3.UP)
	var shots := []
	for face in FACES:
		for mood in [""] + FacePrint.MOODS:
			var design := CharacterDesign.from_dict({"name": face, "head": {"style": face, "color": "#f2cd37"}, "hair": {"style": "none"}, "torso": {"style": "tee", "color": "#0d69ab"}, "arms": {"style": "long_sleeves", "color": "#0d69ab"}, "legs": {"style": "trousers", "color": "#0d69ab"}})
			var rig := CharacterRig.new(design, false)
			rig.position = Vector3(0.0, CharacterRig.FEET_BELOW, 0.0)
			view.add_child(rig)
			await get_tree().process_frame
			rig.set_process(false)
			rig._face.material_override = CharacterRig._new_face_material(FacePrint.paint_image(design.face(), design.skin(), CharacterRig.HEAD_RADIUS, CharacterRig.HEAD_HEIGHT, "none", FacePrint.INK, mood))
			label.text = "%s %s" % [face, mood]
			for frame in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := view.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			shots.append(image)
			rig.free()
	var columns := 1 + FacePrint.MOODS.size()
	var out := Image.create(TILE.x * columns, TILE.y * FACES.size(), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, TILE), Vector2i(i % columns * TILE.x, i / columns * TILE.y))
	out.save_png(OUT + "/new_faces_moods.png")
	view.queue_free()


func _drawer() -> void:
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(2340, 1080)
	Game.show_driver()
	var builder: Node = null
	while builder == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is DriverBuilder:
				builder = child
	await get_tree().create_timer(1.0).timeout
	builder.ui.show_slot("head")
	await _save("drawer_faces")
	for group in ["eyes", "brows", "mouth", "extras"]:
		builder.ui.show_face_group(group)
		await _save("drawer_" + group)
	# A face built from parts.
	builder._change_face("eyes", "half")
	builder._change_face("mouth", "cat")
	builder._change_face("extras", ["freckles"])
	builder.ui.show_face_group("mouth")
	await _save("drawer_built_face")
	builder.ui.show_face_group("faces")
	await _save("drawer_faces_built")


func _save(name: String) -> void:
	await get_tree().create_timer(1.2).timeout
	# Facing the camera, with the turntable held still.
	for builder in get_tree().root.find_children("*", "DriverBuilder", true, false):
		builder._turntable.rotation.y = PI
		builder._last_touch = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
