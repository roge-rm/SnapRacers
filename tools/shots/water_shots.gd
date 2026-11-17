extends Node

## Pictures of lakes and rivers. With no argument, the test course
## (tests/data/ground_course.json) by day: the lake in its hollow, the river's
## rapids and the bridge over it, and the lava lake. "night" does the lava lake
## at night, a course id like peach_pit races that course to see its old water
## turned into lakes, and "editor" shows the Lake and River tools. It needs a
## screen and its own XDG_DATA_HOME:
##   XDG_DATA_HOME=/tmp/x DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/water_shots.tscn -- night
## They're saved in /srv/downloads/temp/debug/snapracers/terrain/water/.

const FOLDER := "/srv/downloads/temp/debug/snapracers/terrain/water"
const SOURCE := "res://tests/data/ground_course.json"
const COURSE := "user://water_shots.json"

var race: Race


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var args := OS.get_cmdline_user_args()
	var what: String = args[0] if not args.is_empty() else "day"
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	if what == "editor":
		await _editor(host)
		get_tree().quit()
		return
	var path := COURSE
	if what in ["day", "night"]:
		var file := FileAccess.open(COURSE, FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string(SOURCE))
		file.close()
	else:
		path = Tracks.path_of(what)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "night" if what == "night" else "day")
	Game.racing_alone = true
	Game.show_race(path)
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await get_tree().physics_frame
	race.hud.visible = false
	var at := func(x: float, z: float, up: float) -> Vector3:
		return Vector3(x, race.builder.ground_at(x, z) + up, z)
	var views := []
	match what:
		"day":
			views = [
				["lake", at.call(110.0, -230.0, 18.0), at.call(150.0, -282.0, 0.0)],
				["lake_low", at.call(195.0, -300.0, 4.0), at.call(140.0, -278.0, 0.0)],
				["rapids", at.call(140.0, -130.0, 14.0), at.call(105.0, -162.0, 0.0)],
				["river_bridge", at.call(60.0, -140.0, 8.0), at.call(0.0, -160.0, 0.0)],
				["river_above", at.call(120.0, -60.0, 120.0), at.call(100.0, -170.0, 0.0)],
				["lava_day", at.call(90.0, -10.0, 16.0), at.call(130.0, -40.0, 0.0)],
			]
		"night":
			views = [["lava_night", at.call(90.0, -10.0, 16.0), at.call(130.0, -40.0, 0.0)],
				["river_night", at.call(60.0, -140.0, 8.0), at.call(0.0, -160.0, 0.0)]]
		_:
			# The course from above, and from beside each lake.
			var box := AABB(race.track.points[0], Vector3.ZERO)
			for p in race.track.points:
				box = box.expand(p)
			var mid := box.get_center()
			views = [["%s_above" % what, mid + Vector3(0.0, box.size.length() * 0.7, box.size.z * 0.5), mid]]
			var n := 0
			for body: Dictionary in race.track.waters.bodies:
				if body.kind != "lake" or n >= 3:
					continue
				var c: Vector2 = body.at
				views.append(["%s_lake%d" % [what, n], at.call(c.x - 40.0, c.y + 40.0, 18.0), at.call(c.x, c.y, 0.0)])
				n += 1
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	race.add_child(cam)
	cam.current = true
	for view: Array in views:
		cam.look_at_from_position(view[1], view[2], Vector3.UP)
		cam.near = 0.05 if view[1].distance_to(view[2]) < 150.0 else 2.0
		for i in 45:
			await get_tree().process_frame
		await _save(view[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COURSE))
	get_tree().quit()


## The editor's Ground tab on the test course: a lake being raised in the
## hollow, a river being drawn, and both after.
func _editor(host: Node) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	data.erase("water")
	var file := FileAccess.open(COURSE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	Game.show_track_editor()
	var editor: TrackEditor = null
	while editor == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is TrackEditor:
				editor = child
	editor.load_course(COURSE)
	await _frames(30)
	var ui := editor.ui
	ui._show_category(TrackEditorUI.CATEGORIES.size() + 2)
	editor.fit_view()
	editor._focus = Vector3(140.0, 0.0, -220.0)
	editor._zoom(0.55)
	await _frames(60)
	ui.ground_tool = "lake"
	ui._show_category(ui._category)
	editor._dragging = true
	editor.paint_begin(Vector3(150.0, 0.0, -282.0))
	for i in 10:
		editor.water_lift(0.2)
		await _frames(2)
	await _frames(20)
	await _save("editor_lake")
	editor.paint_end()
	ui.ground_tool = "river"
	ui._show_category(ui._category)
	editor.paint_begin(Vector3(236.0, 0.0, -160.0))
	for x in range(226, 30, -10):
		editor.paint_to(Vector3(float(x), 0.0, -160.0 + 5.0 * sin(x / 37.0)))
		await _frames(1)
	await _frames(20)
	await _save("editor_river")
	editor.paint_end()
	await get_tree().create_timer(2.0).timeout
	await _frames(30)
	await _save("editor_built")
	ui.toggle_water_type()
	ui.ground_tool = "valley"
	ui._show_category(ui._category)
	await _frames(10)
	await _save("editor_lava_tiles")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COURSE))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [FOLDER, name])
	print("saved ", name)
