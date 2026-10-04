extends SceneTree

## Some stock karts parked at night with their lights on, looking at them
## from the front.

const OUT := "res://build/shots"
const KARTS := ["starter", "sparky", "trike", "chopper", "superbike", "scooter", "dirt_bike", "tourer"]

var _view: SubViewport


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 700))
	_view = SubViewport.new()
	_view.size = Vector2i(1600, 700)
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var night := Conditions.clear_day()
	night.time = "night"
	SkyAndSun.add_to(_view, 60.0, Color.TRANSPARENT, [], Color.TRANSPARENT, night)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("#55585c")
	ground.material_override = grey
	_view.add_child(ground)
	for i in KARTS.size():
		var kart := Kart.new()
		kart.freeze = true
		kart.build(KartDesign.load_file("res://data/karts/stock/%s.json" % KARTS[i]))
		kart.position = Vector3((i - (KARTS.size() - 1) * 0.5) * 3.2, 0.5, 0.0)
		_view.add_child(kart)
		kart.lights_on = true
	var camera := Camera3D.new()
	camera.fov = 40.0
	_view.add_child(camera)
	camera.look_at_from_position(Vector3(-4.0, 4.0, -15.0), Vector3(0.0, 0.3, 0.0), Vector3.UP)
	_run.call_deferred()


func _run() -> void:
	for frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	_view.get_texture().get_image().save_png(OUT + "/night_karts.png")
	print("saved night_karts.png")
	quit()
