extends SceneTree

## Takes a picture of every stock kart, bike and trike, from in front and a
## little to one side, and puts them all on one sheet with their names. Like
## the other shots it needs a screen, and saves in /tmp/snapracers-build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . -s tools/shots/stock_shots.gd

const OUT := "/tmp/snapracers-build/shots"
const DIR := "res://data/karts/stock"
const TILE := Vector2i(480, 340)
## Only these, bigger, when named after --.
var only: Array = []
const COLUMNS := 5

var _sheet: Image
var _view: SubViewport
var _camera: Camera3D
var _stand: Node3D
var _label: Label


func _initialize() -> void:
	only = OS.get_cmdline_user_args()
	DisplayServer.window_set_size(TILE)
	_view = SubViewport.new()
	_view.size = TILE
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2b3440")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#e8e8e8")
	env.environment.ambient_light_energy = 0.55
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 215.0, 0.0)
	sun.light_energy = 0.9
	_view.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_view.add_child(_camera)
	_stand = Node3D.new()
	_view.add_child(_stand)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 26)
	_label.position = Vector2(12, 8)
	_view.add_child(_label)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var files := Array(DirAccess.get_files_at(DIR)).filter(func(f): return f.ends_with(".json") and (only.is_empty() or only.has(f.get_basename())))
	var rows := ceili(files.size() / float(COLUMNS))
	_sheet = Image.create(TILE.x * COLUMNS, TILE.y * rows, false, Image.FORMAT_RGBA8)
	_sheet.fill(Color("#2b3440"))
	for i in files.size():
		var design := KartDesign.load_file(DIR + "/" + files[i])
		for child in _stand.get_children():
			child.free()
		var model := KartModel.make(design)
		_stand.add_child(model)
		var box := KartModel.bounds(design)
		var middle := box.get_center()
		var reach := box.size.length()
		_camera.position = middle + Vector3(-0.75, 0.55, -1.0).normalized() * reach * (2.1 if only.is_empty() else 1.6)
		_camera.look_at(middle, Vector3.UP)
		_label.text = design.name
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := _view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		_sheet.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), Vector2i(i % COLUMNS, i / COLUMNS) * TILE)
	var name := "stock_all" if only.is_empty() else "stock_" + "_".join(only)
	_sheet.save_png("%s/%s.png" % [OUT, name])
	print("saved %s.png" % name)
	quit()
